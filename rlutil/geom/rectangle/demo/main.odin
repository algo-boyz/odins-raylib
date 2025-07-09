package main

import "core:fmt"
import "core:math"
import rl "vendor:raylib"
import rec "../"

SCREEN_WIDTH :: 1200
SCREEN_HEIGHT :: 800

State :: struct {
    mouse_pos: rl.Vector2,
    dragging_rect: bool,
    drag_offset: rl.Vector2,
    selected_demo: int,
    base_rect: rec.Rec,
    secondary_rect: rec.Rec,
    padding_amount: f32,
    cut_amount: f32,
    animation_time: f32,
}

main :: proc() {
    rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "Rectangle Utilities Demo")
    rl.SetTargetFPS(60)
    
    state := State{
        base_rect = {200, 200, 300, 200},
        secondary_rect = {600, 300, 200, 150},
        padding_amount = 20,
        cut_amount = 40,
        selected_demo = 0,
    }
    
    for !rl.WindowShouldClose() {
        update(&state)
        draw(&state)
    }
    
    rl.CloseWindow()
}

update :: proc(state: ^State) {
    state.mouse_pos = rl.GetMousePosition()
    state.animation_time += rl.GetFrameTime()
    
    // Handle demo selection
    if rl.IsKeyPressed(.ONE) do state.selected_demo = 0
    if rl.IsKeyPressed(.TWO) do state.selected_demo = 1
    if rl.IsKeyPressed(.THREE) do state.selected_demo = 2
    if rl.IsKeyPressed(.FOUR) do state.selected_demo = 3
    if rl.IsKeyPressed(.FIVE) do state.selected_demo = 4
    if rl.IsKeyPressed(.SIX) do state.selected_demo = 5
    if rl.IsKeyPressed(.SEVEN) do state.selected_demo = 6
    if rl.IsKeyPressed(.EIGHT) do state.selected_demo = 7
    
    // Handle mouse wheel for parameters
    wheel := rl.GetMouseWheelMove()
    if wheel != 0 {
        switch state.selected_demo {
        case 2: // Padding demo
            state.padding_amount = max(0, state.padding_amount + wheel * 5)
        case 4, 5: // Cut demos
            state.cut_amount = max(10, state.cut_amount + wheel * 5)
        }
    }
    
    // Handle rectangle dragging
    if rl.IsMouseButtonPressed(.LEFT) {
        if rec.is_point_in_rectangle(state.mouse_pos, state.base_rect) {
            state.dragging_rect = true
            state.drag_offset = {state.mouse_pos.x - state.base_rect.x, state.mouse_pos.y - state.base_rect.y}
        }
    }
    
    if rl.IsMouseButtonReleased(.LEFT) {
        state.dragging_rect = false
    }
    
    if state.dragging_rect {
        state.base_rect.x = state.mouse_pos.x - state.drag_offset.x
        state.base_rect.y = state.mouse_pos.y - state.drag_offset.y
    }
}

draw :: proc(state: ^State) {
    rl.BeginDrawing()
    rl.ClearBackground(rl.RAYWHITE)
    
    // Draw title and instructions
    rl.DrawText("Rectangle Utilities Demo", 10, 10, 30, rl.DARKBLUE)
    rl.DrawText("Press 1-8 to switch demos | Mouse wheel to adjust parameters | Drag rectangles", 10, 50, 20, rl.GRAY)
    
    // Draw current demo info
    demo_names := []string{
        "1. Point in Rectangle",
        "2. Rectangle Overlap",
        "3. Rectangle Padding",
        "4. Rectangle Intersection",
        "5. Rectangle Cutting",
        "6. Rectangle Center & Extensions",
        "7. Rectangle Alignment",
        "8. Rectangle Scaling & Distance",
    }
    
    rl.DrawText(fmt.ctprintf("Current Demo: %s", demo_names[state.selected_demo]), 10, 80, 24, rl.DARKGREEN)
    
    switch state.selected_demo {
    case 0: draw_point_in_rect_demo(state)
    case 1: draw_overlap_demo(state)
    case 2: draw_padding_demo(state)
    case 3: draw_intersection_demo(state)
    case 4: draw_cutting_demo(state)
    case 5: draw_center_extension_demo(state)
    case 6: draw_alignment_demo(state)
    case 7: draw_scaling_distance_demo(state)
    }
    
    rl.EndDrawing()
}

draw_point_in_rect_demo :: proc(state: ^State) {
    // Draw the rectangle
    color := rec.is_point_in_rectangle(state.mouse_pos, state.base_rect) ? rl.GREEN : rl.BLUE
    rl.DrawRectangleRec(state.base_rect, rl.Fade(color, 0.3))
    rl.DrawRectangleLinesEx(state.base_rect, 2, color)
    
    // Draw mouse position
    rl.DrawCircleV(state.mouse_pos, 5, rl.RED)
    
    // Draw closest point on edge
    closest := rec.closest_point_on_edge(state.base_rect, state.mouse_pos)
    rl.DrawCircleV(closest, 3, rl.ORANGE)
    rl.DrawLineV(state.mouse_pos, closest, rl.ORANGE)
    
    // Draw distance
    distance := rec.distance_to_point(state.base_rect, state.mouse_pos)
    
    // Draw status
    status := rec.is_point_in_rectangle(state.mouse_pos, state.base_rect) ? "INSIDE" : "OUTSIDE"
    rl.DrawText(fmt.ctprintf("Mouse is %s rectangle", status), 10, 120, 20, rl.BLACK)
    rl.DrawText(fmt.ctprintf("Distance to rectangle: %.1f", distance), 10, 150, 16, rl.GRAY)
    rl.DrawText("Orange dot shows closest point on edge", 10, 180, 16, rl.GRAY)
}

draw_overlap_demo :: proc(state: ^State) {
    // Draw both rectangles
    overlap := rec.overlaps(state.base_rect, state.secondary_rect)
    color1 := overlap ? rl.GREEN : rl.BLUE
    color2 := overlap ? rl.GREEN : rl.PURPLE
    
    rl.DrawRectangleRec(state.base_rect, rl.Fade(color1, 0.3))
    rl.DrawRectangleLinesEx(state.base_rect, 2, color1)
    
    rl.DrawRectangleRec(state.secondary_rect, rl.Fade(color2, 0.3))
    rl.DrawRectangleLinesEx(state.secondary_rect, 2, color2)
    
    // Draw status and additional info
    status := overlap ? "OVERLAPPING" : "NOT OVERLAPPING"
    rl.DrawText(fmt.ctprintf("Rectangles are %s", status), 10, 120, 20, rl.BLACK)
    
    // Show if one contains the other
    contains1 := rec.contains_rect(state.base_rect, state.secondary_rect)
    contains2 := rec.contains_rect(state.secondary_rect, state.base_rect)
    if contains1 {
        rl.DrawText("Blue rectangle contains purple rectangle", 10, 150, 16, rl.GRAY)
    } else if contains2 {
        rl.DrawText("Purple rectangle contains blue rectangle", 10, 150, 16, rl.GRAY)
    } else {
        rl.DrawText("Drag the blue rectangle to test overlap!", 10, 150, 16, rl.GRAY)
    }
}

draw_padding_demo :: proc(state: ^State) {
    // Draw original rectangle
    rl.DrawRectangleRec(state.base_rect, rl.Fade(rl.BLUE, 0.3))
    rl.DrawRectangleLinesEx(state.base_rect, 2, rl.BLUE)
    
    // Draw outward padded rectangle
    padded_out := rec.pad(state.base_rect, state.padding_amount)
    rl.DrawRectangleRec(padded_out, rl.Fade(rl.GREEN, 0.2))
    rl.DrawRectangleLinesEx(padded_out, 2, rl.GREEN)
    
    // Draw inward padded rectangle
    padded_in := rec.pad_inward(state.base_rect, state.padding_amount)
    if rec.is_valid(padded_in) {
        rl.DrawRectangleRec(padded_in, rl.Fade(rl.RED, 0.4))
        rl.DrawRectangleLinesEx(padded_in, 2, rl.RED)
    }
    
    // Draw padding info
    rl.DrawText(fmt.ctprintf("Padding: %.1f pixels", state.padding_amount), 10, 120, 20, rl.BLACK)
    rl.DrawText(fmt.ctprintf("Area - Original: %.1f, Outward: %.1f, Inward: %.1f", 
                rec.area(state.base_rect), rec.area(padded_out), rec.area(padded_in)), 10, 150, 16, rl.GRAY)
    rl.DrawText("Use mouse wheel to adjust padding!", 10, 180, 16, rl.GRAY)
    rl.DrawText("Blue = Original, Green = Outward, Red = Inward", 10, 210, 16, rl.GRAY)
}

draw_intersection_demo :: proc(state: ^State) {
    // Draw both rectangles
    rl.DrawRectangleRec(state.base_rect, rl.Fade(rl.BLUE, 0.3))
    rl.DrawRectangleLinesEx(state.base_rect, 2, rl.BLUE)
    
    rl.DrawRectangleRec(state.secondary_rect, rl.Fade(rl.PURPLE, 0.3))
    rl.DrawRectangleLinesEx(state.secondary_rect, 2, rl.PURPLE)
    
    // Draw intersection
    intersection := rec.intersects(state.base_rect, state.secondary_rect)
    if rec.is_valid(intersection) {
        rl.DrawRectangleRec(intersection, rl.Fade(rl.RED, 0.6))
        rl.DrawRectangleLinesEx(intersection, 3, rl.RED)
        
        rl.DrawText(fmt.ctprintf("Intersection area: %.1f", rec.area(intersection)), 10, 150, 16, rl.GRAY)
    } else {
        rl.DrawText("No intersection", 10, 150, 16, rl.GRAY)
    }
    
    rl.DrawText("Blue + Purple = Red (Intersection)", 10, 120, 20, rl.BLACK)
    rl.DrawText("Drag rectangles to see intersection area!", 10, 180, 16, rl.GRAY)
}

draw_cutting_demo :: proc(state: ^State) {
    // Create a copy for cutting operations
    work_rect := state.base_rect
    
    // Draw original rectangle outline
    rl.DrawRectangleLinesEx(state.base_rect, 1, rl.GRAY)
    
    // Perform cuts and draw results
    top_cut := rec.cut_top(&work_rect, state.cut_amount)
    rl.DrawRectangleRec(top_cut, rl.Fade(rl.RED, 0.7))
    rl.DrawRectangleLinesEx(top_cut, 2, rl.RED)
    
    bottom_cut := rec.cut_bottom(&work_rect, state.cut_amount)
    rl.DrawRectangleRec(bottom_cut, rl.Fade(rl.GREEN, 0.7))
    rl.DrawRectangleLinesEx(bottom_cut, 2, rl.GREEN)
    
    left_cut := rec.cut_left(&work_rect, state.cut_amount)
    rl.DrawRectangleRec(left_cut, rl.Fade(rl.BLUE, 0.7))
    rl.DrawRectangleLinesEx(left_cut, 2, rl.BLUE)
    
    right_cut := rec.cut_right(&work_rect, state.cut_amount)
    rl.DrawRectangleRec(right_cut, rl.Fade(rl.PURPLE, 0.7))
    rl.DrawRectangleLinesEx(right_cut, 2, rl.PURPLE)
    
    // Draw remaining center
    rl.DrawRectangleRec(work_rect, rl.Fade(rl.YELLOW, 0.5))
    rl.DrawRectangleLinesEx(work_rect, 2, rl.ORANGE)
    
    rl.DrawText(fmt.ctprintf("Cut amount: %.1f pixels", state.cut_amount), 10, 120, 20, rl.BLACK)
    rl.DrawText("Red=Top, Green=Bottom, Blue=Left, Purple=Right, Yellow=Center", 10, 150, 16, rl.GRAY)
    rl.DrawText("Use mouse wheel to adjust cut amount!", 10, 180, 16, rl.GRAY)
}

draw_center_extension_demo :: proc(state: ^State) {
    // Draw main rectangle
    rl.DrawRectangleRec(state.base_rect, rl.Fade(rl.BLUE, 0.3))
    rl.DrawRectangleLinesEx(state.base_rect, 2, rl.BLUE)
    
    // Draw center point
    center_x, center_y := rec.center_point(state.base_rect)
    center := rl.Vector2{center_x, center_y}
    rl.DrawCircleV(center, 8, rl.RED)
    
    // Draw all corners
    corners := rec.corners(state.base_rect)
    for corner, i in corners {
        rl.DrawCircleV(corner, 4, rl.ORANGE)
    }
    
    // Animate extensions
    pulse := math.sin(state.animation_time * 2) * 0.5 + 0.5
    extension_amount := pulse * 50 + 20
    
    // Create a copy for extension
    work_rect := state.base_rect
    top_extension := rec.extend_top(&work_rect, extension_amount)
    rl.DrawRectangleRec(top_extension, rl.Fade(rl.GREEN, 0.6))
    rl.DrawRectangleLinesEx(top_extension, 2, rl.GREEN)
    
    // Draw right section
    work_rect2 := state.base_rect
    right_section := rec.take_right(&work_rect2, 80)
    rl.DrawRectangleRec(right_section, rl.Fade(rl.PURPLE, 0.6))
    rl.DrawRectangleLinesEx(right_section, 2, rl.PURPLE)
    
    rl.DrawText("Red dot = Center point, Orange dots = Corners", 10, 120, 20, rl.BLACK)
    rl.DrawText("Green = Animated top extension", 10, 150, 16, rl.GRAY)
    rl.DrawText("Purple = Right section (80px)", 10, 180, 16, rl.GRAY)
    rl.DrawText(fmt.ctprintf("Perimeter: %.1f", rec.perimeter(state.base_rect)), 10, 210, 16, rl.GRAY)
}

draw_alignment_demo :: proc(state: ^State) {
    // Draw reference rectangle (secondary_rect)
    rl.DrawRectangleRec(state.secondary_rect, rl.Fade(rl.GRAY, 0.3))
    rl.DrawRectangleLinesEx(state.secondary_rect, 2, rl.GRAY)
    
    // Create small rectangles to show different alignments
    small_rect := rec.Rec{0, 0, 60, 40}
    
    // Center alignment
    centered := small_rect
    rec.center_on(&centered, state.secondary_rect)
    rl.DrawRectangleRec(centered, rl.Fade(rl.RED, 0.7))
    rl.DrawRectangleLinesEx(centered, 2, rl.RED)
    
    // Left alignment
    left_aligned := small_rect
    rec.align_left(&left_aligned, state.secondary_rect)
    rec.align_center_y(&left_aligned, state.secondary_rect)
    rl.DrawRectangleRec(left_aligned, rl.Fade(rl.BLUE, 0.7))
    rl.DrawRectangleLinesEx(left_aligned, 2, rl.BLUE)
    
    // Right alignment
    right_aligned := small_rect
    rec.align_right(&right_aligned, state.secondary_rect)
    rec.align_center_y(&right_aligned, state.secondary_rect)
    rl.DrawRectangleRec(right_aligned, rl.Fade(rl.GREEN, 0.7))
    rl.DrawRectangleLinesEx(right_aligned, 2, rl.GREEN)
    
    // Top alignment
    top_aligned := small_rect
    rec.align_top(&top_aligned, state.secondary_rect)
    rec.align_center_x(&top_aligned, state.secondary_rect)
    rl.DrawRectangleRec(top_aligned, rl.Fade(rl.PURPLE, 0.7))
    rl.DrawRectangleLinesEx(top_aligned, 2, rl.PURPLE)
    
    // Bottom alignment
    bottom_aligned := small_rect
    rec.align_bottom(&bottom_aligned, state.secondary_rect)
    rec.align_center_x(&bottom_aligned, state.secondary_rect)
    rl.DrawRectangleRec(bottom_aligned, rl.Fade(rl.ORANGE, 0.7))
    rl.DrawRectangleLinesEx(bottom_aligned, 2, rl.ORANGE)
    
    rl.DrawText("Gray = Reference Rectangle", 10, 120, 20, rl.BLACK)
    rl.DrawText("Red = Centered, Blue = Left, Green = Right", 10, 150, 16, rl.GRAY)
    rl.DrawText("Purple = Top, Orange = Bottom", 10, 180, 16, rl.GRAY)
}

draw_scaling_distance_demo :: proc(state: ^State) {
    // Draw original rectangle
    rl.DrawRectangleRec(state.base_rect, rl.Fade(rl.BLUE, 0.3))
    rl.DrawRectangleLinesEx(state.base_rect, 2, rl.BLUE)
    
    // Animate scaling
    pulse := math.sin(state.animation_time * 1.5) * 0.3 + 1.0
    scaled := rec.scale(state.base_rect, pulse)
    rl.DrawRectangleRec(scaled, rl.Fade(rl.GREEN, 0.3))
    rl.DrawRectangleLinesEx(scaled, 2, rl.GREEN)
    
    // Different aspect ratio
    aspect_fitted := rec.fit_aspect_ratio(state.base_rect, 1.0) // Square aspect
    rl.DrawRectangleRec(aspect_fitted, rl.Fade(rl.PURPLE, 0.3))
    rl.DrawRectangleLinesEx(aspect_fitted, 2, rl.PURPLE)
    
    // Non-uniform scaling
    non_uniform := rec.scale_xy(state.base_rect, 0.8, 1.2)
    rl.DrawRectangleRec(non_uniform, rl.Fade(rl.ORANGE, 0.3))
    rl.DrawRectangleLinesEx(non_uniform, 2, rl.ORANGE)
    
    // Draw mouse position and distance
    rl.DrawCircleV(state.mouse_pos, 5, rl.RED)
    distance := rec.distance_to_point(state.base_rect, state.mouse_pos)
    
    rl.DrawText("Blue = Original, Green = Animated Scale", 10, 120, 20, rl.BLACK)
    rl.DrawText("Purple = Square Aspect, Orange = Non-uniform Scale", 10, 150, 16, rl.GRAY)
    rl.DrawText(fmt.ctprintf("Mouse distance to rectangle: %.1f", distance), 10, 180, 16, rl.GRAY)
    rl.DrawText(fmt.ctprintf("Scale factor: %.2f", pulse), 10, 210, 16, rl.GRAY)
}