package main

import "core:fmt"
import rl "vendor:raylib"

circle_transition :: proc(radius: i32, screen_width: i32, screen_height: i32, col: rl.Color) {
    xc := screen_width / 2
    yc := screen_height / 2
    // Draw masked circle transition
    for y in 0..<screen_height {
        for x in 0..<screen_width {
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
    screen_width  : i32 = 800
    screen_height : i32 = 450
    radius, state :i32
    
    rl.InitWindow(screen_width, screen_height, "Circle Transition")
    defer rl.CloseWindow()
    rl.SetTargetFPS(60)

    for !rl.WindowShouldClose() {
        // Grow and shrink radius
        if state == 0 && radius < i32(f32(screen_width) / 1.5) {
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
        circle_transition(radius, screen_width, screen_height, rl.BLACK)
        rl.EndDrawing()
    }
}