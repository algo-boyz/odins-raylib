package main

import "core:fmt"
import "core:mem"
import "core:time"
import "core:crypto"
import "../"

Payload :: struct {
    level:    int,
    new_rank: string,
}

// free is a group, so we can't pass it directly
raw_free :: proc(p: rawptr) {
    free(p)
}

on_level_up :: proc(e: ^events.EventData, user_data: rawptr) {
    payload := cast(^Payload)e.data
    
    fmt.printf("[GAME] Level %d (%s)\n", payload.level, payload.new_rank)
}

main :: proc() {
    track: mem.Tracking_Allocator
    mem.tracking_allocator_init(&track, context.allocator)
    context.allocator = mem.tracking_allocator(&track)
    context.random_generator = crypto.random_generator()
    defer {
        if len(track.allocation_map) > 0 {
            fmt.printf("\nLeaks: %v\n", len(track.allocation_map))
             for _, entry in track.allocation_map {
                fmt.printf("- %v bytes @ %v\n", entry.size, entry.location)
            }
        }
        mem.tracking_allocator_destroy(&track)
    }
    global_bus := events.new_event_bus(worker_count = 2)
    defer events.destroy_event_bus(global_bus)

    events.subscribe(global_bus, "level_up", on_level_up)

    fmt.println("--- Dispatching")

    // Sending Heap Data

    payload_ptr := new_clone(Payload{ 5, "Knight" }) // Alloc heap
    
    // Pass raw_free to free the payload after dispatch
    events.dispatch(global_bus, "level_up", payload_ptr, raw_free)

    payload_ptr_2 := new_clone(Payload{ 99, "King" })
    events.dispatch(global_bus, "level_up", payload_ptr_2, raw_free)
    
    time.sleep(200 * time.Millisecond) // Wait for workers to finish
    fmt.println("--- Done")
}