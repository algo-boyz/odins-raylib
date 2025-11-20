package main

import "core:math"
import "core:strconv"
import "core:strings"
import rl "vendor:raylib"

SPEED :: 400

// Parse rgba string to Color
rgba_to_color :: proc(rgba: string, alpha: u8 = 255) -> rl.Color {
    if !strings.has_prefix(rgba, "rgb(") || !strings.has_suffix(rgba, ")") {
        return {0, 0, 0, 255}
    }
    // Extract content inside rgb(...)
    content := rgba[4:len(rgba)-1]
    values := strings.split(content, ",")
    
    if len(values) < 3 {
        return {0, 0, 0, 255}
    }
    r, r_ok := strconv.parse_int(strings.trim_space(values[0]))
    g, g_ok := strconv.parse_int(strings.trim_space(values[1]))
    b, b_ok := strconv.parse_int(strings.trim_space(values[2]))
    
    if !r_ok || !g_ok || !b_ok {
        return {0, 0, 0, 255}
    }
    return {u8(r), u8(g), u8(b), alpha}
}

Chain :: struct {
    positions: [dynamic]rl.Vector2,
    radii: [8]i32,
    velocity: rl.Vector2,
}

chain_init :: proc(chain: ^Chain) {
    chain.radii = {30, 50, 40, 30, 20, 15, 10, 5}
    chain.velocity = {0, 0}
    // Init positions
    append(&chain.positions, rl.Vector2{100, 100})
    
    for i in 1..<len(chain.radii) {
        prev_pos := chain.positions[i-1]
        if i > 4 {
            append(&chain.positions, rl.Vector2{prev_pos.x - 20, prev_pos.y})
        } else {
            append(&chain.positions, rl.Vector2{prev_pos.x - 50, prev_pos.y})
        }
    }
}

chain_update :: proc(chain: ^Chain, delta_time: f32) {
    mouse_pos := rl.GetMousePosition()
    direction := mouse_pos - chain.positions[0]
    
    normalized_dir := rl.Vector2Normalize(direction)
    
    // Calculate angles for constraint checking
    v1 := chain.positions[0] - chain.positions[1]
    v2 := chain.positions[1] - chain.positions[2]
    angle := rl.Vector2Angle(v1, v2)
    
    vel := normalized_dir
    
    // Rotate v2 90 degrees to get perpendicular direction
    v2_perp := rl.Vector2Normalize(rl.Vector2{-v2.y, v2.x})
    
    // Project velocity onto perpendicular direction
    perp_component := rl.Vector2DotProduct(vel, v2_perp)
    perp_velocity := v2_perp * perp_component
    
    // Apply constraints based on angle
    if angle > math.PI / 2 {
        chain.velocity = perp_velocity
    }
    if angle < -math.PI / 2 {
        chain.velocity = perp_velocity
    }
    
    distance_from_mouse := rl.Vector2Distance(mouse_pos, chain.positions[0])
    
    if distance_from_mouse > 200 {
        chain.velocity = normalized_dir * SPEED
    } else {
        if rl.Vector2Length(chain.velocity) > 1.0 {
            decel_dir := rl.Vector2Normalize(chain.velocity)
            chain.velocity = chain.velocity - (decel_dir * 300 * delta_time)
        } else {
            chain.velocity = {0, 0}
        }
    }
    chain.positions[0] += chain.velocity * delta_time
    
    // Update following segments
    for i in 1..<len(chain.positions) {
        direction_child := chain.positions[i-1] - chain.positions[i]
        normalized_dir_child := rl.Vector2Normalize(direction_child)
        velocity_child := normalized_dir_child * SPEED
        
        if rl.Vector2Distance(chain.positions[i-1], chain.positions[i]) > 40 {
            chain.positions[i] += velocity_child * delta_time
        }
    }
}

chain_draw :: proc(chain: ^Chain) {
    num_points := len(chain.radii) * 2 + 4
    points := make([]rl.Vector2, num_points)
    defer delete(points)
    
    count := 0
    count_left := len(chain.radii) * 2 + 3
    
    // Calculate outline points
    normal := chain.positions[0] - chain.positions[1]
    angle := rl.Vector2Angle(normal, rl.Vector2{1, 0})
    
    x := f32(chain.radii[0]) * math.cos(-angle)
    y := f32(chain.radii[0]) * math.sin(-angle)
    points[count] = rl.Vector2{chain.positions[0].x + x, chain.positions[0].y + y}
    points[count_left] = rl.Vector2{chain.positions[0].x + x, chain.positions[0].y + y}
    count += 1
    count_left -= 1
    
    x = f32(chain.radii[0]) * math.cos(-angle + math.PI/4)
    y = f32(chain.radii[0]) * math.sin(-angle + math.PI/4)
    points[count] = rl.Vector2{chain.positions[0].x + x, chain.positions[0].y + y}
    count += 1
    
    x = f32(chain.radii[0]) * math.cos(-angle - math.PI/4)
    y = f32(chain.radii[0]) * math.sin(-angle - math.PI/4)
    points[count_left] = rl.Vector2{chain.positions[0].x + x, chain.positions[0].y + y}
    count_left -= 1
    
    // Generate body outline points
    for i in 0..<len(chain.positions) {
        if i < len(chain.positions) - 1 {
            normal = chain.positions[i] - chain.positions[i+1]
            angle = rl.Vector2Angle(normal, rl.Vector2{1, 0})
            
            x = f32(chain.radii[i]) * math.cos(-angle - math.PI/2)
            y = f32(chain.radii[i]) * math.sin(-angle - math.PI/2)
            points[count_left] = rl.Vector2{chain.positions[i].x + x, chain.positions[i].y + y}
            count_left -= 1
            
            x = f32(chain.radii[i]) * math.cos(-angle + math.PI/2)
            y = f32(chain.radii[i]) * math.sin(-angle + math.PI/2)
            points[count] = rl.Vector2{chain.positions[i].x + x, chain.positions[i].y + y}
            count += 1
        } else {
            normal = chain.positions[i-1] - chain.positions[i]
            angle = rl.Vector2Angle(normal, rl.Vector2{1, 0})
            
            x = f32(chain.radii[i]) * math.cos(-angle - math.PI/2)
            y = f32(chain.radii[i]) * math.sin(-angle - math.PI/2)
            points[count_left] = rl.Vector2{chain.positions[i].x + x, chain.positions[i].y + y}
            count_left -= 1
            
            x = f32(chain.radii[i]) * math.cos(-angle + math.PI/2)
            y = f32(chain.radii[i]) * math.sin(-angle + math.PI/2)
            points[count] = rl.Vector2{chain.positions[i].x + x, chain.positions[i].y + y}
            count += 1
        }
    }
    // Draw the creature
    rl.DrawSplineCatmullRom(raw_data(points), i32(num_points), 20, rgba_to_color("rgb(255, 227, 187)", 255))
    
    // Draw circles for body segments
    for i in 0..<len(chain.positions) {
        rl.DrawCircle(
            i32(chain.positions[i].x), 
            i32(chain.positions[i].y), 
            f32(chain.radii[i] + 5),
            rgba_to_color("rgb(255, 166, 115)", 255)
        )
    }
    // Draw additional spline layers
    rl.DrawSplineCatmullRom(raw_data(points), i32(num_points), 17, rgba_to_color("rgb(255, 166, 115)", 255))
    
    // Draw head segment
    if num_points >= 2 {
        rl.DrawSplineSegmentCatmullRom(
            points[num_points-2], 
            points[num_points-1], 
            points[0], 
            points[1], 
            10, 
            rgba_to_color("rgb(255, 79, 15)", 255)
        )
    }
}

chain_destroy :: proc(chain: ^Chain) {
    delete(chain.positions)
}

main :: proc() {
    rl.SetConfigFlags({.MSAA_4X_HINT})
    rl.InitWindow(1700, 900, "Procedural Animation")
    defer rl.CloseWindow()

    chain: Chain
    chain_init(&chain)
    defer chain_destroy(&chain)

    for !rl.WindowShouldClose() {
        dt := rl.GetFrameTime()
        chain_update(&chain, dt)

        rl.BeginDrawing()
        rl.ClearBackground(rgba_to_color("rgb(3, 166, 161)", 250))
        
        rl.DrawFPS(10, 10)
        chain_draw(&chain)
        
        rl.EndDrawing()
    }
}