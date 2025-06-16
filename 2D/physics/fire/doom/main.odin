package main

import rl "vendor:raylib"
import "core:math/rand"

FIRE_WIDTH  :: 320
FIRE_HEIGHT :: 168
SCALE: i32 = 2  // Scale up the fire for better visibility

// Color palette matching the original Doom fire
palette := [37]rl.Color{
    {7,   7,   7,   255},  // Almost black
    {31,  7,   7,   255},
    {47,  15,  7,   255},
    {71,  15,  7,   255},
    {87,  23,  7,   255},
    {103, 31,  7,   255},
    {119, 31,  7,   255},
    {143, 39,  7,   255},
    {159, 47,  7,   255},
    {175, 63,  7,   255},
    {191, 71,  7,   255},
    {199, 71,  7,   255},
    {223, 79,  7,   255},
    {223, 87,  7,   255},
    {223, 87,  7,   255},
    {215, 95,  7,   255},
    {215, 95,  7,   255},
    {215, 103, 15,  255},
    {207, 111, 15,  255},
    {207, 119, 15,  255},
    {207, 127, 15,  255},
    {207, 135, 23,  255},
    {199, 135, 23,  255},
    {199, 143, 23,  255},
    {199, 151, 31,  255},
    {191, 159, 31,  255},
    {191, 159, 31,  255},
    {191, 167, 39,  255},
    {191, 167, 39,  255},
    {191, 175, 47,  255},
    {183, 175, 47,  255},
    {183, 183, 47,  255},
    {183, 183, 55,  255},
    {207, 207, 111, 255},
    {223, 223, 159, 255},
    {239, 239, 199, 255},
    {255, 255, 255, 255},  // White
}

Fire :: struct {
    pixels: [FIRE_WIDTH * FIRE_HEIGHT]int,
}

spread_fire :: proc(fire: ^Fire, src: int) {
    pixel := fire.pixels[src]
    if pixel == 0 {
        if src >= FIRE_WIDTH {  // Ensure we don't go out of bounds
            fire.pixels[src - FIRE_WIDTH] = 0
        }
    } else {
        rand_idx := int(rand.float32() * 3.0)
        dst := src - rand_idx + 1
        // Bounds checking
        if dst >= FIRE_WIDTH && dst < len(fire.pixels) {  // Ensure destination is within bounds
            new_pixel := pixel - (rand_idx & 1)
            if new_pixel >= 0 {
                dst_idx := dst - FIRE_WIDTH
                if dst_idx >= 0 && dst_idx < len(fire.pixels) {  // Double check final index
                    fire.pixels[dst_idx] = new_pixel
                }
            }
        }
    }
}

update_fire :: proc(fire: ^Fire) {
    for x := 0; x < FIRE_WIDTH; x += 1 {
        for y := 1; y < FIRE_HEIGHT; y += 1 {
            spread_fire(fire, y * FIRE_WIDTH + x)
        }
    }
}

init_fire :: proc(fire: ^Fire) {
    // Initialize all pixels to 0 (darkest color)
    for i := 0; i < len(fire.pixels); i += 1 {
        fire.pixels[i] = 0
    }
    // Set bottom row to maximum intensity (white)
    for i := 0; i < FIRE_WIDTH; i += 1 {
        fire.pixels[(FIRE_HEIGHT-1)*FIRE_WIDTH + i] = len(palette)-1
    }
}

main :: proc() {
    fire := new(Fire)
    defer free(fire)
    
    init_fire(fire)
    
    rl.InitWindow(FIRE_WIDTH * SCALE, FIRE_HEIGHT * SCALE, "DOOM Fire Effect")
    defer rl.CloseWindow()
    
    rl.SetTargetFPS(60)
    for !rl.WindowShouldClose() {
        // Update fire simulation
        update_fire(fire)

        // Draw
        rl.BeginDrawing()
        rl.ClearBackground(rl.BLACK)

        // Draw fire pixels
        for y:i32; y < FIRE_HEIGHT; y += 1 {
            for x:i32; x < FIRE_WIDTH; x += 1 {
                pixel_idx := fire.pixels[y * FIRE_WIDTH + x]
                color := palette[pixel_idx]
                rl.DrawRectangle(
                    x * SCALE, 
                    y * SCALE, 
                    SCALE, 
                    SCALE, 
                    color,
                )
            }
        }
        rl.EndDrawing()
    }
}