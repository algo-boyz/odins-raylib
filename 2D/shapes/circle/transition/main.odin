package main

import "core:fmt"
import rl "vendor:raylib"

circle_transition :: proc(radius: i32, WIDTH: i32, HEIGHT: i32, col: rl.Color) {
    xc := WIDTH / 2
    yc := HEIGHT / 2
    // Draw masked circle transition
    for y in 0..<HEIGHT {
        for x in 0..<WIDTH {
            // Calculate distance from center
            dx := abs(x - xc)
            dy := abs(y - yc)
            // Check if point is outside the circle
            if dx * dx + dy * dy > radius * radius {
                rl.DrawPixel(x, y, col)
            }
        }
    }
}

main :: proc() {
    WIDTH  : i32 = 800
    HEIGHT : i32 = 450
    radius, state :i32
    
    rl.InitWindow(WIDTH, HEIGHT, "Circle Transition")
    defer rl.CloseWindow()
    rl.SetTargetFPS(60)

    for !rl.WindowShouldClose() {
        // Grow and shrink radius
        if state == 0 && radius < i32(f32(WIDTH) / 1.5) {
            radius += 10
        } else {
            state = 1
        }
        if state == 1 && radius > 0 {
            radius -= 10
        } else {
            state = 0
        }
        rl.BeginDrawing()
        rl.ClearBackground(rl.RAYWHITE)
        circle_transition(radius, WIDTH, HEIGHT, rl.BLACK)
        rl.EndDrawing()
    }
}