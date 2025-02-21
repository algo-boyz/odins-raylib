package rlutil

import its "base:intrinsics"
import "core:fmt"
import "core:mem"
import rl "vendor:raylib"

WindowSettings :: struct {
    width:  i32,
    height: i32,
    title:  cstring,
    fps:    i32,
    flags:  rl.ConfigFlags,
    fixed_timestep: bool,                  // Enable fixed timestep updates
    update_rate: f32,                      // default: 50 updates per second
    max_updates_per_frame: int,
}

// Looking for an easy way to structure your game loop? This function is for you.
// Now with optional fixed timestep support - just set fixed_timestep = true in settings!
run :: proc(
    world: ^$M,
    init: proc(world: ^M),
    update: proc(world: ^M, dt: f32),
    render: proc(world: ^M),
    cleanup: proc(world: ^M),
    settings: WindowSettings,
) where its.type_is_struct(M) {
    tracking_allocator: mem.Tracking_Allocator
    mem.tracking_allocator_init(&tracking_allocator, context.allocator)
    defer mem.tracking_allocator_destroy(&tracking_allocator)
    context.allocator = mem.tracking_allocator(&tracking_allocator)
    defer {
        cleanup(world)
        for _, leak in tracking_allocator.allocation_map {
            fmt.printfln(" %v leaked %m", leak.location, leak.size)
        }
        for bad_free in tracking_allocator.bad_free_array {
            fmt.printfln(" %v allocation %p freed badly", bad_free.location, bad_free.memory)
        }
    }

    init(world)
    rl.SetConfigFlags(settings.flags)
    rl.InitWindow(settings.width, settings.height, settings.title)
    defer rl.CloseWindow()
    rl.InitAudioDevice()
    defer rl.CloseAudioDevice()
    rl.SetTargetFPS(settings.fps)

    accumulator:f32

    for !rl.WindowShouldClose() {
        frame_time := rl.GetFrameTime()

        if settings.fixed_timestep {
            // Fixed timestep update
            accumulator += frame_time
            update_count := 0

            for accumulator >= settings.update_rate && update_count < settings.max_updates_per_frame {
                update(world, settings.update_rate)
                accumulator -= settings.update_rate
                update_count += 1
            }
            // If we hit max updates, drain any remaining time
            if update_count >= settings.max_updates_per_frame {
                accumulator = 0
            }
        } else {
            // Variable timestep update
            update(world, frame_time)
        }
        rl.BeginDrawing()
        render(world)
        rl.EndDrawing()
        free_all(context.temp_allocator)
    }
}

/* Example use:

package main
import rlu "rlutil"

World :: struct {
    settings: rlu.WindowSettings
    <your fields>
}

init :: proc(w: ^World) {}
update :: proc(w: ^World, dt: f32) {}
render :: proc(w: ^World) {}
cleanup :: proc(w: ^World) {}

main :: proc() {
    w: World
    rlu.run(&w, init, update, render, cleanup, rlu.WindowSettings {
        width = 1280,
        height = 720,
        title = "Raylib example",
        fps = 60,
        flags = {.VSYNC_HINT, .WINDOW_RESIZABLE, .MSAA_4X_HINT},
        fixed_timestep = true,  // Enable fixed timestep updates
        update_rate = 1.0/50.0, // (Unity-like)
        max_updates_per_frame = 5, // Prevent spiral of death
    })
}
*/