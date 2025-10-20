package snowfall

import "core:math"
import "core:math/rand"
import "core:time"
import "core:slice"
import rl "vendor:raylib"

// based on: https://raku-advent.blog/2023/12/08/day-8-make-it-snow-2-0-the-snowfall-strikes-back/

WIDTH :: 1024
HEIGHT :: 768
BOUNDS :: 4.0

// Snowflake represents a single snowflake
Snowflake :: struct {
    falling: bool,
    pos:     rl.Vector2,
    weight:  f32,
}
snowflake_texture: rl.Texture2D

// SnowfallAccumulator tracks where snow accumulates
SnowfallAccumulator :: struct {
    pixels: [WIDTH * HEIGHT]bool,
}

accumulator: SnowfallAccumulator

fill_pixel :: proc(acc: ^SnowfallAccumulator, x, y: i32, scale: f32) {
    range := i32(BOUNDS * scale)
    for x_offset in -range..=range {
        for y_offset in -range..=range {
            px := x + x_offset
            py := y + y_offset
            if py > 0 && px > 0 && px < WIDTH && py < HEIGHT {
                idx := py * WIDTH + px
                if idx >= 0 && idx < len(acc.pixels) {
                    acc.pixels[idx] = true
                }
            }
        }
    }
}

check_pixel :: proc(acc: ^SnowfallAccumulator, x, y: i32) -> bool {
    if x < 0 || x >= WIDTH || y < 0 || y >= HEIGHT {
        return false
    }
    idx := y * WIDTH + x
    if idx >= 0 && idx < len(acc.pixels) {
        return acc.pixels[idx]
    }
    return false
}

// SnowfallLayer represents a layer of snowflakes with different scales and behaviors
SnowfallLayer :: struct {
    snowflakes:    [dynamic]Snowflake,
    wind:          rl.Vector2,
    scale:         f32,
    layer_num:     i32,
    started:       bool,
    last_update, last_spawn:          time.Time,
    update_interval, spawn_interval:  time.Duration,
}

create_snowfall_layer :: proc(scale: f32, layer_num: i32) -> SnowfallLayer {
    layer := SnowfallLayer{
        snowflakes   = make([dynamic]Snowflake),
        scale        = scale,
        layer_num    = layer_num,
        wind = rl.Vector2{
            1.001 + (2.5 * scale) * (rand.int_max(2) == 0 ? -1 : 1),
            1.02,
        },
        started = false,
        last_update = time.now(),
        last_spawn = time.now(),
        update_interval = time.Duration(((f64(scale) + 0.5) / 30.0 + f64(layer_num) / 1000.0) * 1000.0) * time.Millisecond,
        spawn_interval = time.Duration((f64(scale) + f64(layer_num) / 50.0) * 1000.0) * time.Millisecond,
    }
    // Don't fill - let them spawn naturally
    return layer
}

fill_snowflakes :: proc(layer: ^SnowfallLayer) {
    count := rand.int_max(8) + 1
    positions := make([dynamic]i32)
    defer delete(positions)
    
    // Pick random x positions across screen width
    for i in 0..<count {
        x := rand.int_max(WIDTH)
        append(&positions, i32(x))
    }
    for x in positions {
        y := f32(rand.int_max(16)) // Start near top
        weight := f32(rand.int_max(5) + 1) * layer.scale
        
        snowflake := Snowflake{
            falling = true,
            pos = rl.Vector2{f32(x), y},
            weight = weight,
        }
        append(&layer.snowflakes, snowflake)
    }
}

// Updates snowflake positions
update_snowfall_layer :: proc(layer: ^SnowfallLayer) {
    if !layer.started {
        return
    }
    now := time.now()
    
    if time.since(layer.last_update) >= layer.update_interval {
        layer.last_update = now
        
        for &flake in layer.snowflakes {
            if !flake.falling {
                continue
            }
            // Update position - much slower movement
            flake.pos.y += (flake.weight + layer.scale) * 0.5 + layer.wind.y * 0.3 // Reduced speed
            flake.pos.x += (1 + layer.wind.x + (0.05 * f32(rand.int_max(2) + 1))) * 0.2 // Much slower horizontal
            
            // Wrap horizontally
            if flake.pos.x > WIDTH {
                flake.pos.x -= WIDTH
            }
            if flake.pos.x < 0 {
                flake.pos.x += WIDTH
            }
            // Check for collision with ground or accumulated snow
            if flake.pos.y >= HEIGHT || check_pixel(&accumulator, i32(flake.pos.x), i32(flake.pos.y)) {
                size := BOUNDS * layer.scale
                flake.pos.y = HEIGHT - size
                
                // Find a clear spot to land - move up until clear
                for check_pixel(&accumulator, i32(flake.pos.x), i32(flake.pos.y)) {
                    flake.pos.y -= size
                    if flake.pos.y < 0 {
                        break
                    }
                }
                // Original uses Bool.pick for three choices: -size, 0, or +size
                offset_choice := rand.int_max(3)
                switch offset_choice {
                case 0: 
                    if rand.int_max(2) == 0 { // Bool.pick equivalent
                        flake.pos.x -= size
                    }
                case 1: 
                    if rand.int_max(2) == 0 { // Bool.pick equivalent  
                        // no change (0)
                    }
                case 2: flake.pos.x += size
                }
                // Ensure position is valid
                flake.pos.x = clamp(flake.pos.x, 0, WIDTH - 1)
                
                fill_pixel(&accumulator, i32(flake.pos.x), i32(flake.pos.y), layer.scale)
                flake.falling = false
            }
        }
    } // Spawn new snowflakes
    if time.since(layer.last_spawn) >= layer.spawn_interval {
        layer.last_spawn = now
        fill_snowflakes(layer)
    }
}

render_snowfall_layer :: proc(layer: ^SnowfallLayer) {
    for &flake in layer.snowflakes {
        rl.DrawTextureEx(snowflake_texture, flake.pos, 0, layer.scale, rl.WHITE)
    }
}

start_snowfall_layer :: proc(layer: ^SnowfallLayer) {
    layer.started = true
}

destroy_snowfall_layer :: proc(layer: ^SnowfallLayer) {
    delete(layer.snowflakes)
}

// SnowfallRenderer manages multiple layers of snow
SnowfallRenderer :: struct {
    layers: [dynamic]SnowfallLayer,
}

new_renderer :: proc() -> SnowfallRenderer {
    scales := []f32{0.1, 0.2, 0.25, 0.3, 0.33, 0.36, 0.4, 0.5}
    
    renderer := SnowfallRenderer{
        layers = make([dynamic]SnowfallLayer),
    }
    for scale, i in scales {
        layer := create_snowfall_layer(scale, i32(i))
        append(&renderer.layers, layer)
    }
    return renderer
}

start_snowfall :: proc(renderer: ^SnowfallRenderer) {
    for &layer in renderer.layers {
        start_snowfall_layer(&layer)
    }
}

update_snowfall :: proc(renderer: ^SnowfallRenderer) {
    for &layer in renderer.layers {
        update_snowfall_layer(&layer)
    }
}

render_snowfall :: proc(renderer: ^SnowfallRenderer) {
    for &layer in renderer.layers {
        render_snowfall_layer(&layer)
    }
}

destroy_renderer :: proc(renderer: ^SnowfallRenderer) {
    for &layer in renderer.layers {
        destroy_snowfall_layer(&layer)
    }
    delete(renderer.layers)
}

// Creates a simple asterisk texture for snowflakes
init_snowflake_texture :: proc() {
    img := rl.ImageText("*", 32, rl.WHITE)
    snowflake_texture = rl.LoadTextureFromImage(img)
    rl.UnloadImage(img)
}

main :: proc() {
    rl.InitWindow(WIDTH, HEIGHT, "Snowy")
    defer rl.CloseWindow()
    rl.SetTargetFPS(60)
    
    init_snowflake_texture()
    defer rl.UnloadTexture(snowflake_texture)
    
    renderer := new_renderer()
    defer destroy_renderer(&renderer)
    
    start_snowfall(&renderer)
    
    for !rl.WindowShouldClose() {
        update_snowfall(&renderer)
        
        rl.BeginDrawing()
        rl.ClearBackground(rl.BLACK)
        render_snowfall(&renderer)
        rl.EndDrawing()
    }
}