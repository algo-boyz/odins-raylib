package eventbus

import "core:sync"
import "core:thread"
import "core:strings"
import "core:mem"
import "core:container/queue" 
import "core:encoding/uuid"

EventData :: struct {
    name: string,
    data: rawptr,
}

Listener :: struct {
    id:        uuid.Identifier,
    method:    proc(data: ^EventData, user_data: rawptr),
    user_data: rawptr,
}

// A task for the worker threads
EventTask :: struct {
    name:      string,        // Owned: Must be deleted by worker
    payload:   rawptr,        // Owned: Must be freed by worker using free_proc
    free_proc: proc(rawptr),  // Function pointer to free the payload
}

EventBus :: struct {
    // Identity
    id:                uuid.Identifier,
    // Listener
    listeners_lock:    sync.Recursive_Mutex, 
    listeners:         map[string][dynamic]Listener,
    listener_to_event: map[uuid.Identifier]string,
    // Concurrency
    queue_lock:        sync.Mutex,
    queue_cond:        sync.Cond,
    // Ring Buffer for O(1) ops
    task_queue:        queue.Queue(EventTask), 
    
    allocator:         mem.Allocator,
    threads:           [dynamic]^thread.Thread,
    running:           bool,
}

new_event_bus :: proc(worker_count := 2) -> ^EventBus {
    bus := new(EventBus)
    bus.id = uuid.generate_v4()
    bus.allocator = context.allocator
    
    bus.listeners = make(map[string][dynamic]Listener)
    bus.listener_to_event = make(map[uuid.Identifier]string)
    
    queue.init(&bus.task_queue)
    bus.running = true
    
    if worker_count > 0 {
        bus.threads = make([dynamic]^thread.Thread, worker_count)
        for i in 0..<worker_count {
            bus.threads[i] = thread.create_and_start_with_data(bus, worker_proc)
        }
    }
    return bus
}

destroy_event_bus :: proc(bus: ^EventBus) {
    if bus == nil do return

    // 1. Stop Workers
    sync.lock(&bus.queue_lock)
    bus.running = false
    sync.cond_broadcast(&bus.queue_cond)
    sync.unlock(&bus.queue_lock)

    // 2. Join Threads
    for t in bus.threads {
        thread.join(t)
        thread.destroy(t)
    }
    delete(bus.threads)

    // 3. Clean pending tasks
    // If we shut down with items in the queue, clean them.
    for queue.len(bus.task_queue) > 0 {
        task := queue.pop_front(&bus.task_queue)
        delete(task.name)
        if task.free_proc != nil && task.payload != nil {
            task.free_proc(task.payload)
        }
    }
    queue.destroy(&bus.task_queue)
    
    // 4. Clean Listeners
    for key, &list in bus.listeners {
        delete(list)
        delete(key) 
    }
    delete(bus.listeners)
    delete(bus.listener_to_event)
    free(bus)
}

worker_proc :: proc(data: rawptr) {
    bus := cast(^EventBus)data
    context.allocator = bus.allocator
    for {
        // Prevent memory leaks in long-running threads
        free_all(context.temp_allocator)

        sync.lock(&bus.queue_lock)
        
        // Wait while queue is empty
        for bus.running && queue.len(bus.task_queue) == 0 {
            sync.cond_wait(&bus.queue_cond, &bus.queue_lock)
        }
        if !bus.running && queue.len(bus.task_queue) == 0 {
            sync.unlock(&bus.queue_lock)
            return 
        }
        // O(1) Pop
        task := queue.pop_front(&bus.task_queue)
        sync.unlock(&bus.queue_lock)

        process_event(bus, &task)

        // Name cloned in dispatch
        delete(task.name)
        
        // If user provided a heap payload and a way to free it
        if task.free_proc != nil && task.payload != nil {
            task.free_proc(task.payload)
        }
    }
}

process_event :: proc(bus: ^EventBus, task: ^EventTask) {
    listeners_snapshot: []Listener = nil

    sync.lock(&bus.listeners_lock)
    if list, found := bus.listeners[task.name]; found {
        // temp_allocator safe here because it's reset in worker loop
        listeners_snapshot = make([]Listener, len(list), context.temp_allocator)
        copy(listeners_snapshot, list[:])
    }
    sync.unlock(&bus.listeners_lock)

    if listeners_snapshot == nil do return

    event_data := EventData{ name = task.name, data = task.payload }
    
    for listener in listeners_snapshot {
        listener.method(&event_data, listener.user_data)
    }
}

// For heap memory, pass `free` (or your custom free). 
// For stack/static memory, pass `nil` -> NOTE: you own the lifetime
dispatch :: proc(bus: ^EventBus, event_name: string, payload: rawptr = nil, free_cb: proc(rawptr) = nil) {
    sync.lock(&bus.queue_lock)
    defer sync.unlock(&bus.queue_lock)

    // Clone string so task owns it
    name_clone := strings.clone(event_name)

    task := EventTask{
        name = name_clone,
        payload = payload,
        free_proc = free_cb,
    }
    // O(1) Push
    queue.push_back(&bus.task_queue, task)
    sync.cond_signal(&bus.queue_cond)
}

subscribe :: proc(bus: ^EventBus, event_name: string, callback: proc(^EventData, rawptr), user_data: rawptr = nil) -> uuid.Identifier {
    sync.lock(&bus.listeners_lock)
    defer sync.unlock(&bus.listeners_lock)

    key := event_name
    if event_name not_in bus.listeners {
        key = strings.clone(event_name) 
        bus.listeners[key] = make([dynamic]Listener)
    } else {
        for k in bus.listeners {
            if k == event_name {
                key = k
                break
            }
        }
    }
    id := uuid.generate_v4()
    append(&bus.listeners[key], Listener{id = id, method = callback, user_data = user_data})
    bus.listener_to_event[id] = key 
    return id
}

unsubscribe :: proc(bus: ^EventBus, id: uuid.Identifier) -> bool {
    sync.lock(&bus.listeners_lock)
    defer sync.unlock(&bus.listeners_lock)

    event_key, found := bus.listener_to_event[id]
    if !found do return false

    if list, ok := &bus.listeners[event_key]; ok {
        for i := 0; i < len(list); i += 1 {
            if list[i].id == id {
                unordered_remove(list, i)
                if len(list) == 0 {
                    free(list)
                    delete(event_key) 
                    delete_key(&bus.listeners, event_key)
                }
                delete_key(&bus.listener_to_event, id)
                return true
            }
        }
    }
    return false
}