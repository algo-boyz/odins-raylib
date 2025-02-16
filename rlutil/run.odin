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
}

// Looking for an easy way to structure your game loop? This function is for you.
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
    for !rl.WindowShouldClose() {
        dt := rl.GetFrameTime()
        update(world, dt)
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
	rlu.run(&m, init, update, render, cleanup, rlu.WindowSettings {
		width = 1280,
		height = 720,
		title = "Raylib example",
		fps = 60,
		flags = {.VSYNC_HINT, .WINDOW_RESIZABLE, .MSAA_4X_HINT},
	})
}

*/