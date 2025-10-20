package main

import "core:c"
import "core:math/rand"
import "core:mem"
import rl "vendor:raylib"

// Raindrop represents a single rain drop with position, lifetime, and visual properties
Raindrop :: struct {
    coords: rl.Vector2,
    life_time: int,
    radius: f32,
    alpha: u8,
}

// randomInt returns a random integer in the range [minimum, maximum]
randomInt :: proc(minimum, maximum: int) -> int {
    return minimum + rand.int_max(maximum - minimum + 1)
}

// randomFloat returns a random float in the range [minimum, maximum]
randomFloat :: proc(minimum, maximum: f32) -> f32 {
    scale := rand.float32()
    return minimum + scale * (maximum - minimum)
}

// spreadDrop updates a raindrop's properties as it expands over time
spreadDrop :: proc(drop: ^Raindrop) {
    drop.life_time += 1
    if drop.life_time > 0 {
        RADIUS_PER_FRAME :: 0.5
        ALPHA_PER_FRAME :: 2
        
        drop.radius += RADIUS_PER_FRAME
        if drop.alpha < ALPHA_PER_FRAME {
            drop.alpha = 0
        } else {
            drop.alpha -= ALPHA_PER_FRAME
        }
    }
}

// resetDrop reinitializes a raindrop with new random properties
resetDrop :: proc(drop: ^Raindrop, screen_x, screen_y: i32) {
    drop.coords.x = randomFloat(0.0, f32(screen_x))
    drop.coords.y = randomFloat(0.0, f32(screen_y))
    drop.radius = 0.0
    drop.alpha = 0xFF
    
    // Negative values means delay before appearing on screen
    MIN_DELAY :: -80
    MAX_DELAY :: -5
    drop.life_time = randomInt(MIN_DELAY, MAX_DELAY)
}

main :: proc() {
    DEFAULT_WIDTH :: 640
    DEFAULT_HEIGHT :: 480
    PIXELS_PER_DROP :i32 = 10000
    
    water_color := rl.Color{0x02, 0x25, 0x2D, 0xFF}
    
    cur_width :i32 = DEFAULT_WIDTH
    cur_height :i32 = DEFAULT_HEIGHT
    
    // Will be triggered at the start of the loop since they're different from cur_width/height
    prev_width :i32 = 0
    prev_height :i32 = 0
    
    drop_amount :i32 = 0
    drops := make([]Raindrop, 1)
    
    rl.SetConfigFlags({.WINDOW_RESIZABLE, .VSYNC_HINT})
    rl.InitWindow(DEFAULT_WIDTH, DEFAULT_HEIGHT, "Rain.")
    rl.SetWindowMinSize(320, 240)
    rl.SetTargetFPS(60)
    
    for !rl.WindowShouldClose() {
        cur_width = rl.GetScreenWidth()
        cur_height = rl.GetScreenHeight()
        
        if cur_width != prev_width || cur_height != prev_height {
            drop_amount = cur_width * cur_height / PIXELS_PER_DROP
            
            // Resize our drops slice to accommodate the new window size
            delete(drops)
            drops = make([]Raindrop, drop_amount)
            
            for i:i32; i < drop_amount; i += 1 {
                resetDrop(&drops[i], cur_width, cur_height)
            }
        }
        
        for i:i32; i < drop_amount; i += 1 {
            if drops[i].alpha != 0 {
                spreadDrop(&drops[i])
            } else {
                resetDrop(&drops[i], cur_width, cur_height)
            }
        }
        
        rl.BeginDrawing()
        rl.ClearBackground(water_color)
        
        for i:i32; i < drop_amount; i += 1 {
            if drops[i].life_time > 0 {
                rl.DrawCircleLinesV(
                    drops[i].coords,
                    drops[i].radius,
                    rl.Color{0xFF, 0xFF, 0xFF, drops[i].alpha},
                )
            }
        }
        
        rl.EndDrawing()
        
        prev_width = cur_width
        prev_height = cur_height
    }
    
    delete(drops)
}