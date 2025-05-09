package main

import "base:runtime"
import "core:fmt"
import "core:slice"
import rl "vendor:raylib"
// todo: https://github.com/pross1312/Procedural-animation/blob/main/main.cpp
WIDTH  :: 1280
HEIGHT :: 720

Link :: struct {
    position: rl.Vector2,
    size: f32,
}

Chain :: struct {
    joints: [dynamic]Link,
    link_size: f32,
}

new_chain :: proc(chain_size: int, link_size: f32) -> (chain: Chain) {
    chain.link_size = link_size
    chain.joints, _ = runtime.make_dynamic_array_len([dynamic]Link, cast(int)(link_size))

    first_joint := Link {
        position = rl.Vector2{
            cast(f32)(WIDTH / 2 - 150), 
            cast(f32)(HEIGHT / 2)
        },
        size = 8,
    }
    append(&chain.joints, first_joint)

    for i in 1..<chain_size {
        prev_joint := chain.joints[i-1]
        next_joint := Link {
            position = rl.Vector2{
                prev_joint.position.x + link_size, 
                cast(f32)(HEIGHT / 2)
            },
            size = 8,
        }
        append(&chain.joints, next_joint)
    }

    return chain
}

update_position :: proc(chain: ^Chain) {
    next_pos := chain.joints[0].position

    if rl.IsKeyDown(rl.KeyboardKey.UP) {
        next_pos.y -= 5
    }
    if rl.IsKeyDown(rl.KeyboardKey.DOWN) {
        next_pos.y += 5
    }
    if rl.IsKeyDown(rl.KeyboardKey.LEFT) {
        next_pos.x -= 5
    }
    if rl.IsKeyDown(rl.KeyboardKey.RIGHT) {
        next_pos.x += 5
    }

    chain.joints[0].position = rl.Vector2MoveTowards(
        chain.joints[0].position, 
        next_pos, 
        5
    )
    
    move_body(chain)
}

move_body :: proc(chain: ^Chain) {
    for i in 1..<len(chain.joints) {
        constraint_distance(&chain.joints[i-1], &chain.joints[i], chain.link_size)
    }
}

constraint_distance :: proc(head, tail: ^Link, link_size: f32) {
    delta := head.position - tail.position
    current_distance := rl.Vector2Length(delta)
    
    if current_distance == 0 do return

    scale := link_size / current_distance
    direction := rl.Vector2 {
        delta.x * scale,
        delta.y * scale,
    }
    
    tail.position = head.position - direction
}

main :: proc() {
    rl.InitWindow(WIDTH, HEIGHT, "Procedural Animation - [Odin + Raylib]")
    defer rl.CloseWindow()

    chain := new_chain(8, 50)
    defer delete(chain.joints)

    rl.SetTargetFPS(60)

    for !rl.WindowShouldClose() {
        update_position(&chain)

        rl.BeginDrawing()
        rl.ClearBackground(rl.DARKGRAY)

        for joint in chain.joints {
            rl.DrawCircleV(joint.position, joint.size, rl.WHITE)
        }

        rl.EndDrawing()
    }
}