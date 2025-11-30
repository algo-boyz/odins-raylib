package main

import "base:runtime"
import "core:math"
import rl "vendor:raylib"

WIDTH :: 800
HEIGHT :: 600
FPS :: 60
BG_COLOR :: rl.Color{24, 24, 24, 255}
MAX_POINTS :: 100
LINE_THICKNESS :: 2.5
CIRCLE_RADIUS :: 5

points_to_delete: [MAX_POINTS]rl.Vector2
points_to_delete_count: int

@(require_results)
get_min_x :: proc(points: []rl.Vector2) -> rl.Vector2 {
    if len(points) == 0 {
        return {}
    }
    p := points[0]
    for point in points[1:] {
        if point.x < p.x {
            p = point
        }
    }
    return p
}

@(require_results)
get_max_x :: proc(points: []rl.Vector2) -> rl.Vector2 {
    if len(points) == 0 {
        return {}
    }
    p := points[0]
    for point in points[1:] {
        if point.x > p.x {
            p = point
        }
    }
    return p
}

@(require_results)
is_vector_on_side_of_line :: proc(p1, p2, p: rl.Vector2) -> bool {
    d := (p.x - p1.x) * (p2.y - p1.y) - (p.y - p1.y) * (p2.x - p1.x)
    // 0 -> on the line, otherwise on one side
    return d > 0
}

@(require_results)
distance_to_line :: proc(p1, p2, p: rl.Vector2) -> f32 {
    num := (p2.y - p1.y) * p.x - (p2.x - p1.x) * p.y + p2.x * p1.y - p2.y * p1.x
    den_sq := math.pow(p2.y - p1.y, 2) + math.pow(p2.x - p1.x, 2)
    d := abs(num) / math.sqrt(den_sq)
    return d
}

@(require_results)
most_distant_vector_to_line :: proc(points: []rl.Vector2, min, max: rl.Vector2) -> rl.Vector2 {
    // Assumes len(points) > 0, guaranteed by caller (solve_hull)
    v := points[0]
    d1 := distance_to_line(min, max, points[0])

    for point in points[1:] {
        d2 := distance_to_line(min, max, point)
        if d1 < d2 {
            d1 = d2
            v = point
        }
    }
    return v
}

vectors_on_side_of_line :: proc(points: []rl.Vector2, side_points: []rl.Vector2, side_points_count: ^int, min, max: rl.Vector2) {
    for point in points {
        if is_vector_on_side_of_line(min, max, point) {
            side_points[side_points_count^] = point
            side_points_count^ += 1
        }
    }
}

solve_hull :: proc(points: []rl.Vector2, min_x, max_x: rl.Vector2) {
    side_points: [MAX_POINTS]rl.Vector2
    side_points_count := 0
    
    // Pass full array as slice
    vectors_on_side_of_line(points, side_points[:], &side_points_count, min_x, max_x)

    if side_points_count == 0 {
        rl.DrawLineEx(min_x, max_x, LINE_THICKNESS, rl.LIGHTGRAY)
        points_to_delete[points_to_delete_count] = min_x
        points_to_delete_count += 1
    } else {
        // Create slice of only valid points
        active_side_points := side_points[:side_points_count]
        
        p_most_distant := most_distant_vector_to_line(active_side_points, min_x, max_x)

        solve_hull(active_side_points, min_x, p_most_distant)
        solve_hull(active_side_points, p_most_distant, max_x)
    }
}

@(require_results)
vectors_are_equal :: proc(v1, v2: rl.Vector2) -> bool {
    return v1 == v2
}

delete_vector_from_array :: proc(points: []rl.Vector2, count: ^int, v: rl.Vector2) {
    // Find idx of vector
    i := 0
    for ; i < count^; i += 1 {
        if vectors_are_equal(points[i], v) {
            break
        }
    }

    // If found (i != count^), shift elements left
    if i != count^ {
        for k in i..<(count^ - 1) {
            points[k] = points[k + 1]
        }
        count^ -= 1
    }
}

draw_hull :: proc(points: []rl.Vector2, count: int) {
    // Copy original
    temp_count := count
    temp_points: [MAX_POINTS]rl.Vector2
    copy(temp_points[:], points[:count])
    
    // Create a slice of the active temp points
    active_temp_points := temp_points[:temp_count]

    min_x := get_min_x(active_temp_points)
    max_x := get_max_x(active_temp_points)

    solve_hull(active_temp_points, min_x, max_x)
    solve_hull(active_temp_points, max_x, min_x)

    for i in 0..<points_to_delete_count {
        delete_vector_from_array(temp_points[:], &temp_count, points_to_delete[i])
    }

    points_to_delete_count = 0
    points_to_delete := rl.Vector2{}

    if temp_count >= 2 {
        draw_hull(temp_points[:], temp_count)
    }
}

main :: proc() {
    points: [MAX_POINTS]rl.Vector2
    points_count := 0

    font_size :: 20

    button_compute := rl.Rectangle{
        x = 0,
        y = HEIGHT - font_size * 2,
        width = 180,
        height = f32(font_size * 2),
    }
    button_compute_text :: "Compute layers"
    button_compute_pressed := false
    button_compute_color: rl.Color

    button_reset := rl.Rectangle{
        x = WIDTH - 75,
        y = HEIGHT - font_size * 2,
        width = 75,
        height = f32(font_size * 2),
    }
    button_reset_text :: "Reset"

    rl.SetTraceLogLevel(.WARNING)
    rl.InitWindow(WIDTH, HEIGHT, "Convex Layers")
    rl.SetTargetFPS(FPS)

    for !rl.WindowShouldClose() {
        if button_compute_pressed {
            button_compute_color = rl.RED
        } else {
            button_compute_color = rl.LIGHTGRAY
        }

        mouse_pos := rl.GetMousePosition()

        // Add points
        if rl.IsMouseButtonPressed(rl.MouseButton.LEFT) &&
           !rl.CheckCollisionPointRec(mouse_pos, button_compute) &&
           !rl.CheckCollisionPointRec(mouse_pos, button_reset) {
            
            if points_count >= MAX_POINTS {
                points_count = 0
                points := rl.Vector2{}
            }
            if points_count < MAX_POINTS {
                points[points_count] = mouse_pos
                points_count += 1
            }
        }
        // Reset btn
        if rl.CheckCollisionPointRec(mouse_pos, button_reset) && 
           rl.IsMouseButtonPressed(rl.MouseButton.LEFT) && 
           points_count > 0 {
            
            points_count = 0
            points := rl.Vector2{}
            button_compute_pressed = false
        }

        rl.BeginDrawing()
        {
            rl.ClearBackground(BG_COLOR)

            // Draw compute btn
            rl.DrawRectangleRec(button_compute, button_compute_color)
            if rl.CheckCollisionPointRec(mouse_pos, button_compute) && points_count > 2 {
                rl.DrawRectangleLinesEx(button_compute, 5.0, rl.BLACK)
            }
            rl.DrawText(button_compute_text, i32(button_compute.x) + font_size / 2, i32(button_compute.y) + font_size / 2, font_size, rl.BLACK)

            // Draw reset btn
            rl.DrawRectangleRec(button_reset, rl.LIGHTGRAY)
            if rl.CheckCollisionPointRec(mouse_pos, button_reset) && points_count > 0 {
                rl.DrawRectangleLinesEx(button_reset, 5.0, rl.BLACK)
            }
            rl.DrawText(button_reset_text, i32(button_reset.x) + font_size / 2, i32(button_reset.y) + font_size / 2, font_size, rl.BLACK)

            // Draw points
            for i in 0..<points_count {
                point_color := rl.LIGHTGRAY
                if rl.CheckCollisionPointCircle(mouse_pos, points[i], CIRCLE_RADIUS) {
                    if rl.IsMouseButtonDown(rl.MouseButton.RIGHT) {
                        point_color = rl.PURPLE
                        points[i] = mouse_pos
                    }
                }
                rl.DrawCircle(i32(points[i].x), i32(points[i].y), CIRCLE_RADIUS, point_color)
            }

            if button_compute_pressed || 
               (rl.CheckCollisionPointRec(mouse_pos, button_compute) && rl.IsMouseButtonPressed(rl.MouseButton.LEFT) && points_count > 2) {
                
                draw_hull(points[:], points_count)
                button_compute_pressed = true
            }
        }
        rl.EndDrawing()
    }
    rl.CloseWindow()
}