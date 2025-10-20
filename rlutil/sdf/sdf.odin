package main

import "core:math"
import "core:math/linalg"
import rl "vendor:raylib"

vec2_abs :: proc(v: rl.Vector2) -> rl.Vector2 {
    return {abs(v.x), abs(v.y)}
}

vec2_max :: proc(a, b: rl.Vector2) -> rl.Vector2 {
    return {max(a.x, b.x), max(a.y, b.y)}
}

// Basic 2D SDF functions
circle :: proc(p: rl.Vector2, radius: f32) -> f32 {
    return rl.Vector2Length(p) - radius
}

box :: proc(p: rl.Vector2, size: rl.Vector2) -> f32 {
    d := vec2_abs(p) - size
    return rl.Vector2Length(vec2_max(d, {0, 0})) + min(max(d.x, d.y), 0.0)
}

rounded_box :: proc(p: rl.Vector2, size: rl.Vector2, radius: f32) -> f32 {
    d := vec2_abs(p) - size + radius
    return rl.Vector2Length(vec2_max(d, {0, 0})) + min(max(d.x, d.y), 0.0) - radius
}

intersection :: proc(a, b: f32) -> f32 {
    return max(a, b)
}

difference :: proc(a, b: f32) -> f32 {
    return max(a, -b)
}

smooth_union :: proc(a, b, k: f32) -> f32 {
    h := clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0)
    return linalg.lerp(b, a, h) - k * h * (1.0 - h)
}

// Scene definition
scene_sdf :: proc(p: rl.Vector2) -> f32 {
    // Example: circle and box combined
    circle := circle(p - {200, 200}, 50)
    box := box(p - {300, 300}, {40, 60})
    return smooth_union(circle, box, 20)
}

// Raymarching for 2D
raymarch_2d :: proc(origin, direction: rl.Vector2, max_steps: int = 64, max_distance: f32 = 1000) -> (distance: f32) {
    for step in 0..<max_steps {
        current_pos := origin + direction * distance
        d := scene_sdf(current_pos)
        
        if d < 0.01 { // Hit threshold
            return distance
        }
        distance += d
        
        if distance > max_distance {
            break
        }
    }
    return -1 // Miss
}

// Render SDF as heightfield/contour
render_field :: proc(WIDTH, HEIGHT: i32) {
    for y in 0..<HEIGHT {
        for x in 0..<WIDTH {
            p := rl.Vector2{f32(x), f32(y)}
            d := scene_sdf(p)
            
            // Visualize distance field
            color: rl.Color
            if d < 0 {
                // Inside - red tint
                intensity := u8(clamp(-d * 5, 0, 255))
                color = {intensity, 0, 0, 255}
            } else {
                // Outside - blue gradient
                intensity := u8(clamp(255 - d * 2, 0, 255))
                color = {0, 0, intensity, 255}
            }
            
            rl.DrawPixel(x, y, color)
        }
    }
}

/*
main :: proc() {
    WIDTH: i32 = 800
    HEIGHT: i32 = 600
    
    rl.InitWindow(WIDTH, HEIGHT, "Odin SDF Demo")
    rl.SetTargetFPS(60)
    
    for !rl.WindowShouldClose() {
        rl.BeginDrawing()
        rl.ClearBackground(rl.BLACK)
        
        // Render the SDF field
        render_field(WIDTH, HEIGHT)
        
        // Draw some debug info
        rl.DrawText("SDF Visualization", 10, 10, 20, rl.WHITE)
        rl.DrawText("Red = Inside, Blue = Outside", 10, 35, 16, rl.WHITE)
        
        rl.EndDrawing()
    }
    rl.CloseWindow()
}
*/