package main

import "core:math/rand"
import rl "vendor:raylib"

WIDTH :: 600
HEIGHT :: 400
STARS :: 200
SCROLL_SPEED :: 10

Star :: struct {
    x: f32,  // The stars coordinates
    y: f32,  // on screen
    z: f32,  // Star field depth or distance from camera
}

randf :: proc() -> f32 {
    return rand.float32_range(0, 1)
}

main :: proc() {
    rl.InitWindow(WIDTH, HEIGHT, "To the stars - parallax starfield")
    defer rl.CloseWindow()
    rl.SetTargetFPS(60)
    
    stars: [STARS]Star
    
    // RANDOMISE STAR POSITIONS
    for i in 0..<STARS {
        stars[i].x = f32(rl.GetRandomValue(0, WIDTH))
        stars[i].y = f32(rl.GetRandomValue(0, HEIGHT))
        stars[i].z = randf()
    }
    for !rl.WindowShouldClose() {
        // SCROLL THE STARS
        for i in 0..<STARS {
            stars[i].x -= SCROLL_SPEED * (stars[i].z / 1)
            
            if stars[i].x <= 0 {  // Check if the star has gone off screen
                stars[i].x += WIDTH
                stars[i].y = f32(rl.GetRandomValue(0, HEIGHT))
            }
        }
        rl.BeginDrawing()
        rl.ClearBackground({0, 0, 0, 255})

        for i in 0..<STARS {
            x := i32(stars[i].x)
            y := i32(stars[i].y)
            
            rl.DrawPixel(x, y, rl.WHITE)
        }
        rl.EndDrawing()
    }
}