package main

import lg "core:math/linalg"
import rl "vendor:raylib"

MAX_POINTS :: 10

Polygon :: struct {
    points: [MAX_POINTS]rl.Vector2,
    point_count: int,
    center: rl.Vector2,
    origin: rl.Vector2,
    size: f32,
}

load_shape :: proc(poly: ^Polygon, shape_nr: int) {
    shape_idx := shape_nr % 1
    switch shape_idx {
    case 0:
        points := [4]rl.Vector2{
            {1, 0},
            {0, 1},
            {-1, 0},
            {0, -1},
        }
        poly.point_count = 4
        for i := 0; i < poly.point_count; i += 1 {
            poly.points[i] = points[i]
        }
    }
    
    // Compute center
    poly.center = {}
    for i := 0; i < poly.point_count; i += 1 {
        poly.center = poly.center + poly.points[i]
    }
    poly.center = poly.center * (1/f32(poly.point_count))
}

transform :: proc(poly: ^Polygon, point: rl.Vector2) -> rl.Vector2 {
    return poly.origin +  rl.Vector2{point.x * poly.size, point.y * -poly.size}
}

inv_transform :: proc(poly: ^Polygon, point: rl.Vector2) -> rl.Vector2 {
    translated := point - poly.origin
    return {translated.x / poly.size, translated.y / -poly.size}
}

get_winding_degrees :: proc(poly: ^Polygon, point: rl.Vector2) -> f32 {
    winding: f32 = 0
    for i := 0; i < poly.point_count; i += 1 {
        u := poly.points[i]
        v := poly.points[(i + 1) % poly.point_count]
        pu := rl.Vector2Normalize(u - point)
        pv := rl.Vector2Normalize(v - point)
        
        angle := lg.acos(rl.Vector2DotProduct(pu, pv))
        winding += angle
    }
    return winding * rl.RAD2DEG
}

is_point_inside :: proc(poly: ^Polygon, point: rl.Vector2) -> bool {
    return get_winding_degrees(poly, point) >= 359.9
}

draw_polygon :: proc(poly: ^Polygon, filled: bool) {
    // Draw edges
    for i := 0; i < poly.point_count; i += 1 {
        u := poly.points[i]
        v := poly.points[(i + 1) % poly.point_count]
        rl.DrawLineV(transform(poly, u), transform(poly, v), rl.BLUE)
    }
    
    // Prepare points for triangle fan
    fan := make([dynamic]rl.Vector2, 0, MAX_POINTS + 2)
    defer delete(fan)
    
    append(&fan, transform(poly, poly.center))
    
    for i := 0; i < poly.point_count; i += 1 {
        append(&fan, transform(poly, poly.points[i]))
        rl.DrawCircleV(fan[len(fan)-1], 5, rl.GREEN)
    }
    append(&fan, fan[1])  // Close the fan
    
    if filled {
        rl.DrawTriangleFan(raw_data(fan), i32(len(fan)), rl.Fade(rl.BLUE, 0.2))
    }
}

draw_angle_lines :: proc(poly: ^Polygon, point: rl.Vector2) {
    p := transform(poly, point)
    angles := make([dynamic]f32, poly.point_count)
    defer delete(angles)
    
    winding: f32 = 0
    
    for i := 0; i < poly.point_count; i += 1 {
        u := poly.points[i]
        v := poly.points[(i + 1) % poly.point_count]
        pu := rl.Vector2Normalize(u - point)
        pv := rl.Vector2Normalize(v - point)
        
        angle := lg.acos(rl.Vector2DotProduct(pu, pv))
        angles[i] = angle
        winding += angle
        rl.DrawLineV(p, transform(poly, u), rl.Fade(rl.RED, 0.8))
    }
    
    for i := 0; i < poly.point_count; i += 1 {
        u := transform(poly, poly.points[i])
        v := transform(poly, poly.points[(i + 1) % poly.point_count])
        avg := (p + (u + v)) * 0.333
        
        angle_text := rl.TextFormat("%.0f", angles[i] * rl.RAD2DEG)
        rl.DrawText(angle_text, i32(avg.x), i32(avg.y - 20), 20, rl.MAGENTA)
    }
    
    winding_text := rl.TextFormat("%.0f", winding * rl.RAD2DEG)
    rl.DrawText(winding_text, i32(p.x - 15), i32(p.y - 20), 20, rl.MAGENTA)
}

main :: proc() {
    rl.InitWindow(800, 800, "PointIn")
    defer rl.CloseWindow()
    
    polygon := Polygon{
        origin = {400, 400},
        size = 250,
    }
    load_shape(&polygon, 0)
    
    for !rl.WindowShouldClose() {
        mouse_local := inv_transform(&polygon, rl.GetMousePosition())
        inside := is_point_inside(&polygon, mouse_local)
        
        rl.BeginDrawing()
        rl.ClearBackground(rl.BLACK)
        
        draw_polygon(&polygon, inside)
        draw_angle_lines(&polygon, mouse_local)
        
        rl.EndDrawing()
    }
}