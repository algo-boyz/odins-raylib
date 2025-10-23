package main

import "core:fmt"
import "core:math"
import "core:os"
import "core:strings"
import "core:strconv"
import rl "vendor:raylib"
import "vendor:raylib/rlgl"

HEIGHT :: 800
WIDTH :: 800
FPS :: 75
MAX_DISTANCE :: 50.0
SPEED :: 4.5
ROT_AMOUNT :: 6.0
WAIT_TIME :: 0.7
RAD :: 4

// Angle offsets for the three sensor rays
ANGLE_OFFSETS := [3]f32{-30.0, 0.0, 30.0}

Map :: struct {
    data: [dynamic][dynamic]i32,
    width: int,
    height: int,
    cell_size: int,
}
game_map: Map

cutoff: [3]bool
show := true
togg := false
wait_timer: f64 = 0

Car :: struct {
    position: rl.Vector2,
    rotation: f32,
    rect: rl.Rectangle,
    origin: rl.Vector2,
    color: rl.Color,
    dist: [3]rl.Vector2,
    angle_rad: [3]f32,
}

make_car :: proc(rect: rl.Rectangle, position: rl.Vector2, origin: rl.Vector2, color: rl.Color) -> Car {
    return Car{
        position = position,
        rotation = 0.0,
        rect = rect,
        origin = origin,
        color = color,
    }
}

// Init map with given dimensions
init_map :: proc(width, height: int) {
    game_map.width = width
    game_map.height = height
    game_map.cell_size = HEIGHT / max(width, height)
    
    rows := max(width, height)
    game_map.data = make([dynamic][dynamic]i32, rows)
    for i in 0..<rows {
        game_map.data[i] = make([dynamic]i32, rows)
        for j in 0..<rows {
            game_map.data[i][j] = 0
        }
    }
}

cleanup_map :: proc() {
    for i in 0..<len(game_map.data) {
        delete(game_map.data[i])
    }
    delete(game_map.data)
}

// Parse PPM header and return dimensions
parse_ppm_header :: proc(content: string) -> (width, height: int, data_start: int, ok: bool) {
    lines := strings.split_lines(content)
    defer delete(lines)
    
    if len(lines) < 4 {
        fmt.println("Invalid PPM file format - too few lines")
        return 0, 0, 0, false
    }
    line_idx: int
    
    // Read magic number
    magic := strings.trim_space(lines[line_idx])
    if magic != "P3" {
        fmt.println("Unsupported PPM format:", magic, "(only P3 supported)")
        return 0, 0, 0, false
    }
    line_idx += 1
    
    // Skip comments
    for line_idx < len(lines) && strings.has_prefix(strings.trim_space(lines[line_idx]), "#") {
        line_idx += 1
    }
    
    if line_idx >= len(lines) {
        fmt.println("Invalid PPM file - no dimensions found")
        return 0, 0, 0, false
    }
    
    // Read dims
    dimension_parts := strings.fields(strings.trim_space(lines[line_idx]))
    defer delete(dimension_parts)
    
    if len(dimension_parts) != 2 {
        fmt.println("Invalid dimensions format")
        return 0, 0, 0, false
    }
    
    w, w_ok := strconv.parse_int(dimension_parts[0])
    h, h_ok := strconv.parse_int(dimension_parts[1])
    
    if !w_ok || !h_ok || w <= 0 || h <= 0 {
        fmt.println("Invalid dimensions:", dimension_parts[0], "x", dimension_parts[1])
        return 0, 0, 0, false
    }
    
    line_idx += 1
    
    // Skip comments again
    for line_idx < len(lines) && strings.has_prefix(strings.trim_space(lines[line_idx]), "#") {
        line_idx += 1
    }
    
    if line_idx >= len(lines) {
        fmt.println("Invalid PPM file - no max value found")
        return 0, 0, 0, false
    }
    
    // Read max color value (we don't use it but it's required for PPM format)
    _, max_ok := strconv.parse_int(strings.trim_space(lines[line_idx]))
    if !max_ok {
        fmt.println("Invalid max color value")
        return 0, 0, 0, false
    }
    line_idx += 1
    
    return w, h, line_idx, true
}

// Load map from PPM file
load_map :: proc(filename: string) -> bool {
    file_path := fmt.tprintf("assets/%s.ppm", filename)
    
    data, file_ok := os.read_entire_file(file_path)
    if !file_ok {
        fmt.println("Cannot open file:", file_path)
        return false
    }
    defer delete(data)
    
    content := string(data)
    width, height, data_start_line, header_ok := parse_ppm_header(content)
    if !header_ok {
        return false
    }
    
    fmt.println("Map dimensions:", width, "x", height)
    
    // Init map with parsed dimensions
    init_map(width, height)
    
    // Parse pixel data
    lines := strings.split_lines(content)
    defer delete(lines)
    
    // Collect all RGB values
    rgb_values: [dynamic]int
    defer delete(rgb_values)
    
    for line_idx := data_start_line; line_idx < len(lines); line_idx += 1 {
        line := strings.trim_space(lines[line_idx])
        if line == "" do continue
        
        values := strings.fields(line)
        defer delete(values)
        
        for value in values {
            if parsed_value, parse_ok := strconv.parse_int(strings.trim_space(value)); parse_ok {
                append(&rgb_values, parsed_value)
            }
        }
    }
    
    // Convert RGB triplets to binary map (using only red channel)
    pixel_count := 0
    expected_pixels := width * height
    
    // Calculate centering offsets
    map_size := max(width, height)
    offset_x := (map_size - width) / 2
    offset_y := (map_size - height) / 2
    
    for i := 0; i < len(rgb_values) && pixel_count < expected_pixels; i += 3 {
        if i + 2 < len(rgb_values) { // Ensure we have R, G, B
            red := rgb_values[i]
            // Skip green and blue components (rgb_values[i+1] and rgb_values[i+2])
            
            // Convert linear pixel index to 2D coordinates
            pixel_y := pixel_count / width
            pixel_x := pixel_count % width
            
            // Apply centering offset
            map_y := pixel_y + offset_y
            map_x := pixel_x + offset_x
            
            // Set map value (white = 255 becomes wall = 1, black = 0 becomes empty = 0)
            if map_y >= 0 && map_y < len(game_map.data) && map_x >= 0 && map_x < len(game_map.data[0]) {
                game_map.data[map_y][map_x] = 1 if red == 255 else 0
            }
            
            pixel_count += 1
        }
    }
    
    fmt.printf("Successfully loaded %d pixels into %dx%d map (cell size: %d)\n", 
               pixel_count, len(game_map.data), len(game_map.data[0]), game_map.cell_size)
    
    return pixel_count == expected_pixels
}

update_car :: proc(car: ^Car, x: f32, y: f32, rot: f32) {
    car.position.x = x
    car.position.y = y
    car.origin.x = car.rect.width / 2
    car.origin.y = car.rect.height / 2
    car.rotation = rot
    car.rect = {car.position.x, car.position.y, car.rect.width, car.rect.height}
    
    // Calc raycast distance for each ray
    for i in 0..<3 {
        car.angle_rad[i] = math.to_radians(rot + ANGLE_OFFSETS[i])
        n: f32 = 0
        
        tx := x
        ty := y
        
        for n < MAX_DISTANCE {
            tx = x + n * math.cos(car.angle_rad[i])
            ty = y + n * math.sin(car.angle_rad[i])
            
            gx := i32(tx / f32(game_map.cell_size))
            gy := i32(ty / f32(game_map.cell_size))
            
            if gx < 0 || gy < 0 || gx >= i32(len(game_map.data[0])) || gy >= i32(len(game_map.data)) {
                break
            }
            if game_map.data[gy][gx] == 1 {
                break
            }
            n += 1
        }
        
        car.dist[i].x = x + n * math.cos(car.angle_rad[i])
        car.dist[i].y = y + n * math.sin(car.angle_rad[i])
        
        cutoff[i] = (n == MAX_DISTANCE)
    }
    
    // Draw rays if enabled
    if show {
        rlgl.SetLineWidth(3.0)
        for i in 0..<3 {
            ray_color := rl.GREEN if cutoff[i] else rl.RED
            rl.DrawLine(i32(car.rect.x), i32(car.rect.y), i32(car.dist[i].x), i32(car.dist[i].y), ray_color)
            rl.DrawCircleV(car.dist[i], RAD, ray_color)
        }
        rlgl.SetLineWidth(1.0)
    }
    
    // Draw car
    rl.DrawRectanglePro(car.rect, car.origin, car.rotation, rl.ORANGE)
}

draw_grid :: proc() {
    for i in 0..<WIDTH {
        if i % game_map.cell_size == 0 {
            rl.DrawLine(i32(i), 0, i32(i), HEIGHT, rl.DARKGRAY)
        }
    }
    for i in 0..<HEIGHT {
        if i % game_map.cell_size == 0 {
            rl.DrawLine(0, i32(i), WIDTH, i32(i), rl.DARKGRAY)
        }
    }
}

draw_map :: proc() {
    for i in 0..<len(game_map.data) {
        for j in 0..<len(game_map.data[i]) {
            if game_map.data[i][j] == 1 {
                x := i32(j * game_map.cell_size)
                y := i32(i * game_map.cell_size)
                size := i32(game_map.cell_size)
                rl.DrawRectangle(x, y, size, size, rl.DARKGRAY)
            }
        }
    }
}

// Movement
forward :: proc(position: ^rl.Vector2, rotation: f32) {
    angle_rad := math.to_radians(rotation)
    position.x += math.cos(angle_rad) * SPEED
    position.y += math.sin(angle_rad) * SPEED
}

backward :: proc(position: ^rl.Vector2, rotation: f32) {
    angle_rad := math.to_radians(rotation)
    position.x -= math.cos(angle_rad) * SPEED
    position.y -= math.sin(angle_rad) * SPEED
}

turn_right :: proc(rotation: ^f32) {
    rotation^ -= ROT_AMOUNT
}

turn_left :: proc(rotation: ^f32) {
    rotation^ += ROT_AMOUNT
}

shake_it :: proc(position: ^rl.Vector2, rotation: ^f32, old_pos: rl.Vector2, old_rot: f32) {
    if (old_pos.x == position.x && old_pos.y == position.y) || abs(old_rot - rotation^) == ROT_AMOUNT {
        if wait_timer == 0 {
            wait_timer = rl.GetTime()
        }
        if rl.GetTime() - wait_timer > WAIT_TIME {
            if togg {
                rotation^ += 20
                for i in 0..<4 {
                    backward(position, rotation^)
                }
                togg = !togg
            } else {
                rotation^ -= 20
                for i in 0..<4 {
                    backward(position, rotation^)
                }
                togg = !togg
            }
        }
    } else {
        wait_timer = 0
    }
}

main :: proc() {
    fname := "map4"
    
    if !load_map(fname) {
        fmt.println("Failed to load map:", fname)
        return
    }
    defer cleanup_map()
    
    // Initial car setup
    position := rl.Vector2{WIDTH - 70, HEIGHT - 20}
    rect := rl.Rectangle{position.x, position.y, 30, 15}
    origin := rl.Vector2{rect.width / 2, rect.height / 2}
    rotation: f32 = -120.0
    
    car := make_car(rect, position, origin, rl.RED)
    
    rl.SetTargetFPS(FPS)
    rl.InitWindow(WIDTH, HEIGHT, "AI Race")
    defer rl.CloseWindow()
    
    for !rl.WindowShouldClose() {
        rl.BeginDrawing()
        defer rl.EndDrawing()
        
        rl.ClearBackground(rl.BLACK)
        
        draw_map()
        
        // Manual control
        if rl.IsKeyDown(.A) do turn_right(&rotation)
        if rl.IsKeyDown(.D) do turn_left(&rotation)
        if rl.IsKeyDown(.W) do forward(&position, rotation)
        if rl.IsKeyDown(.S) do backward(&position, rotation)
        if rl.IsKeyPressed(.SPACE) do show = !show
        
        if rl.IsKeyDown(.R) {
            mouse_pos := rl.GetMousePosition()
            position.x = mouse_pos.x
            position.y = mouse_pos.y
        }
        
        // Store old position and rotation for shake detection
        old_pos := position
        old_rot := rotation
        
        // Autonomous logic
        if cutoff[1] { // Middle ray is clear
            forward(&position, rotation)
            if !cutoff[0] && cutoff[2] do turn_left(&rotation)   // Left blocked, right clear
            if cutoff[0] && !cutoff[2] do turn_right(&rotation)  // Right blocked, left clear
        } else {
            if !cutoff[0] {
                turn_left(&rotation)  // Left is clear
            } else if !cutoff[2] {
                turn_right(&rotation) // Right is clear
            } else if !cutoff[1] {
                // Middle blocked, choose direction
                if togg {
                    turn_right(&rotation)
                    togg = !togg
                } else {
                    turn_left(&rotation)
                    togg = !togg
                }
            }
        }
        
        // If all rays are blocked, oscillate
        if !cutoff[0] && !cutoff[1] && !cutoff[2] {
            if togg {
                rotation += ROT_AMOUNT
                togg = !togg
            } else {
                rotation -= ROT_AMOUNT
                togg = !togg
            }
        }
        // If stuck, shake aggressively
        shake_it(&position, &rotation, old_pos, old_rot)
        
        update_car(&car, position.x, position.y, rotation)
    }
}