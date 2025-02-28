package  main

import rl "vendor:raylib"
import rlu "../../../../rlutil"
import "core:math"
import "core:fmt"
import "core:mem"

WORLD_SIZE :: 800
CHUNK_SIZE :: 50
NUM_CHUNKS :: WORLD_SIZE / CHUNK_SIZE

World :: struct {
    chunks: [NUM_CHUNKS*NUM_CHUNKS]Chunk,
    entities: map[int]^Entity,
    settings: rlu.WindowSettings
}

Chunk :: struct {
    entities: [dynamic]int,
    position: [2]int
}

get_chunk_index :: proc(x, y: int) -> int {
    return clamp(y, 0, NUM_CHUNKS-1) * NUM_CHUNKS + clamp(x, 0, NUM_CHUNKS-1)
}

get_chunk_coords :: proc(position: [2]f32) -> (x, y: f32) {
    x = position.x / CHUNK_SIZE
    y = position.y / CHUNK_SIZE
    return clamp(x, 0, NUM_CHUNKS-1), clamp(y, 0, NUM_CHUNKS-1)
}

init :: proc(w: ^World) {
    for i in 0..<NUM_CHUNKS*NUM_CHUNKS {
        chunk := &w.chunks[i]
        chunk.entities = make([dynamic]int)
        chunk.position = [2]int{i % NUM_CHUNKS, i / NUM_CHUNKS}
    }
    w.entities = make(map[int]^Entity)

    add_entity(w, [2]f32{21, 51})
    add_entity(w, [2]f32{40, 45})
    add_entity(w, [2]f32{50, 59})

    fmt.printfln("entities in chunk: %v", get_entities_in_chunk(w, 0))
}

update :: proc(w: ^World, dt: f32) {
    for index in w.entities {
        e, ok := w.entities[index]
        if !ok do continue
        
        e.position.x += e.velocity.x
        e.position.y += e.velocity.y

        if e.position.x >= (1000 - 32/2) || e.position.x <= 32/2 {
            e.velocity.x *= -1
        }
        if e.position.y >= (1000 - 32/2) || e.position.y <= 32/2 { 
            e.velocity.y *= -1
        }
        move_entity(w, e)
    }
}

render :: proc(w: ^World) {
    rl.ClearBackground(rl.BLACK)
    
    for index in w.entities {
        e, ok := w.entities[index]
        rl.DrawRectanglePro(rl.Rectangle{
            x = e.position.x,
            y = e.position.y,
            width = 32,
            height = 32
        }, {16,16}, 0, rl.RED)
    }
}

cleanup :: proc(w: ^World) {
    // rm all chunk dynamic arrays
    for i in 0..<NUM_CHUNKS*NUM_CHUNKS {
        delete(w.chunks[i].entities)
    }
    for _, entity in w.entities {
        free(entity)
    }
    delete(w.entities)
}

main :: proc() {
	world: World
	rlu.run(&world, init, update, render, cleanup, rlu.WindowSettings{
		width = 1200,
		height = 900,
		title = "sort, sweep & prune",
		fps = 60,
		flags = {.VSYNC_HINT, .WINDOW_RESIZABLE, .MSAA_4X_HINT},
        fixed_timestep = true,
        update_rate = 1.0/50.0,
        max_updates_per_frame = 10,
	})
}