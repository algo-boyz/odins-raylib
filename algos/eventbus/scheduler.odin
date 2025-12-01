package eventbus

import "core:encoding/uuid"
import "core:sync"

EventData :: struct {
    name: string,
    data: any,
}

Listener :: struct {
    id:        uuid.Identifier,
    method:    proc(data: ^EventData, user_data: rawptr),
    user_data: rawptr,
}

EventBus :: struct {
    id:            uuid.Identifier,
    name:          string,

    // Main storage: event_name (owned) → list of listeners
    listeners:     map[string][dynamic]Listener,

    // Reverse mapping so we can unsubscribe by ID only
    listener_to_event: map[uuid.Identifier]string,

    lock:          sync.Recursive_Mutex, // Reentrant = safe for nested dispatch
    use_lock:      bool,
}

new_bus :: proc(name: string, concurrent := false) -> ^EventBus {
    bus := new(EventBus)
    bus.id = uuid.generate_v4()
    bus.name = name
    bus.listeners = make(map[string][dynamic]Listener)
    bus.listener_to_event = make(map[uuid.Identifier]string)
    bus.use_lock = concurrent
    return bus
}

destroy_bus :: proc(bus: ^EventBus) {
    if bus == nil do return

    if bus.use_lock {
        sync.lock(&bus.lock)
        defer sync.unlock(&bus.lock)
    }
    // First clear all listener arrays
    for key, &list in bus.listeners {
        delete(list)
    }
    delete(bus.listeners)
    delete(bus.listener_to_event)
    free(bus)
}

subscribe :: proc(bus: ^EventBus, event_name: string, callback: proc(^EventData, rawptr), user_data: rawptr = nil) -> uuid.Identifier {
    if bus.use_lock {
        sync.lock(&bus.lock)
        defer sync.unlock(&bus.lock)
    }
    if event_name not_in bus.listeners {
        bus.listeners[event_name] = make([dynamic]Listener)
    }
    id := uuid.generate_v4()
    append(&bus.listeners[event_name], Listener{id = id, method = callback, user_data = user_data})
    bus.listener_to_event[id] = event_name

    return id
}

// Now you can unsubscribe using ONLY the ID — safe and reliable
unsubscribe :: proc(bus: ^EventBus, id: uuid.Identifier) -> bool {
    if bus.use_lock {
        sync.lock(&bus.lock)
        defer sync.unlock(&bus.lock)
    }
    event_key, found := bus.listener_to_event[id]
    if !found do return false

    if list, ok := &bus.listeners[event_key]; ok {
        for i := 0; i < len(list); i += 1 {
            if list[i].id == id {
                unordered_remove(list, i)

                // Clean up if empty
                if len(list) == 0 {
                    free(list)
                    delete(event_key, context.allocator)
                    delete_key(&bus.listeners, event_key)
                }
                delete_key(&bus.listener_to_event, id)
                return true
            }
        }
    }
    return false
}

dispatch :: proc(bus: ^EventBus, event_name: string, payload: any = nil) {
    if bus == nil do return

    listeners_snapshot: []Listener = nil

    if bus.use_lock {
        sync.lock(&bus.lock)
    }
    defer if bus.use_lock {
        sync.unlock(&bus.lock)
    }
    if list, found := bus.listeners[event_name]; found {
        listeners_snapshot = make([]Listener, len(list), context.temp_allocator)
        copy(listeners_snapshot, list[:])
    }
    if listeners_snapshot == nil do return

    event_data := EventData{
        name = event_name,
        data = payload,
    }
    for listener in listeners_snapshot {
        listener.method(&event_data, listener.user_data)
    }
}

// Optional helper for cleaner syntax with typed payloads
subscribe_t :: proc(bus: ^EventBus, event_name: string, $T: typeid, callback: proc(data: ^T)) -> uuid.Identifier {
    wrapper := proc(ed: ^EventData, _: rawptr) {
        if data, ok := ed.data.(^T); ok {
            callback(data)
        }
    }
    return subscribe(bus, event_name, wrapper)
}