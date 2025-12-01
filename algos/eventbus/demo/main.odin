package main

import "core:crypto"
import "core:fmt"
import "core:mem"
import events "../"

LevelUpPayload :: struct {
    level:    int,
    new_rank: string,
}

AchievementPayload :: struct {
    title:  string,
    points: int,
}

// A generic logger that just prints the event name
on_log_event :: proc(e: ^events.EventData, user_data: rawptr) {
    fmt.printf("[LOG] Event received: %s\n", e.name)
}

// A specific handler for Level Up events
on_level_up :: proc(e: ^events.EventData, user_data: rawptr) {
    // 1. Check if the payload is actually the type we expect
    if payload, ok := e.data.(LevelUpPayload); ok {
        fmt.printf("[GAME] CONGRATS! Reached Level %d (%s)\n", payload.level, payload.new_rank)
    } else {
        fmt.println("[GAME] Error: Received level_up event with wrong data type.")
    }
}

// A handler that uses user_data (Context)
on_score_change :: proc(e: ^events.EventData, user_data: rawptr) {
    // Cast the rawptr user_data back to what we know it is
    player_name := cast(^string)user_data
    
    // We expect the payload to be an integer (score)
    if score, ok := e.data.(int); ok {
        fmt.printf("[UI] Updating Scoreboard for %s: %d\n", player_name^, score)
    }
}

main :: proc() {
    track: mem.Tracking_Allocator
    context.random_generator = crypto.random_generator()
    mem.tracking_allocator_init(&track, context.allocator)
    context.allocator = mem.tracking_allocator(&track)

    defer {
        if len(track.allocation_map) > 0 {
            fmt.printf("\n%v allocations not freed\n", len(track.allocation_map))
            for _, entry in track.allocation_map {
                fmt.printf("- %v bytes @ %v\n", entry.size, entry.location)
            }
        }
        mem.tracking_allocator_destroy(&track)
    }

    fmt.println("--- Starting Event Bus Demo\n")

    // Create the Bus
    // We use concurrent=true just to be safe, though this demo is single threaded
    global_bus := events.new_bus("global", concurrent = true)
    
    // Ensure we clean up the bus at the end
    defer events.destroy_bus(global_bus)

    // Sub 1: Generic Logger
    sub_id_log := events.subscribe(global_bus, "level_up", on_log_event)
    
    // Sub 2: Specific Logic
    events.subscribe(global_bus, "level_up", on_level_up)

    // Sub 3: With Context (User Data)
    p1_name := "Hero123"
    events.subscribe(global_bus, "score_updated", on_score_change, &p1_name)
    
    fmt.println("\n--- Dispatching First Round\n")

    // Dispatching 'level_up' with struct payload
    lvl_data := LevelUpPayload{ level = 5, new_rank = "Knight" }
    events.dispatch(global_bus, "level_up", lvl_data)

    // Dispatching 'score_updated' with int payload
    events.dispatch(global_bus, "score_updated", 100)

    fmt.println("\n--- Unsubscribing Logger\n")
    events.unsubscribe(global_bus, sub_id_log)

    // Dispatch Again
    // The logger should NOT fire, but the game logic handler should still fire.
    
    fmt.println("\n--- Dispatching Second Round\n")
    lvl_data_2 := LevelUpPayload{ level = 6, new_rank = "Paladin" }
    events.dispatch(global_bus, "level_up", lvl_data_2)

    fmt.println("\n--- End of Demo\n")
}