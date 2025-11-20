package main

import "core:math"
import rl "vendor:raylib"

import geom "../../rlutil/geom"

// Segment represents a single segment in a kinematic chain
Segment :: struct {
    a, b:      rl.Vector2,
    len:       f32,
    angle:     f32,
    thickness: f32,
    index:     i32, // For checkered pattern calculation
}

// Create a new segment in the chain
segment_create :: proc(x, y, len, angle, thickness: f32, index: i32) -> Segment {
    seg := Segment{
        a = rl.Vector2{x, y},
        len = len,
        angle = angle,
        thickness = thickness,
        index = index,
    }
    segment_update(&seg)
    return seg
}

// Make segment follow a target
segment_follow :: proc(seg: ^Segment, tx, ty: f32) -> rl.Vector2 {
    target := rl.Vector2{tx, ty}
    dir := target - seg.a
    seg.angle = geom.vec2_angle(dir)
    
    seg.a.x = target.x - seg.len * math.cos(seg.angle)
    seg.a.y = target.y - seg.len * math.sin(seg.angle)
    
    return seg.a
}

// Calculate end point of the segment
segment_calculate_b :: proc(seg: ^Segment) {
    seg.b.x = seg.a.x + seg.len * math.cos(seg.angle)
    seg.b.y = seg.a.y + seg.len * math.sin(seg.angle)
}

segment_update :: proc(seg: ^Segment) {
    segment_calculate_b(seg)
}

// Draw segment with checkered F1 flag pattern
segment_draw :: proc(seg: ^Segment) {
    start := rl.Vector2{seg.a.x, seg.a.y}
    end := rl.Vector2{seg.b.x, seg.b.y}
    
    // Calculate checkered pattern
    // Use segment index and position to determine if square should be black or white
    checker_size :f32= 8.0 // Size of each checker square
    
    // Calculate perpendicular vector for thickness
    perp_x := -math.sin(seg.angle) * seg.thickness * 0.5
    perp_y := math.cos(seg.angle) * seg.thickness * 0.5
    
    // Create quad vertices for the segment
    quad_points := [4]rl.Vector2{
        {start.x + perp_x, start.y + perp_y},
        {start.x - perp_x, start.y - perp_y},
        {end.x - perp_x, end.y - perp_y},
        {end.x + perp_x, end.y + perp_y},
    }
    
    // Draw filled segment with checkered pattern
    steps := i32(seg.len / 2) + 1
    for i in 0..<steps {
        t := f32(i) / f32(steps - 1)
        
        // Interpolate along the segment
        current_pos := rl.Vector2{
            start.x + (end.x - start.x) * t,
            start.y + (end.y - start.y) * t,
        }
        
        // Calculate checker pattern based on segment index and position
        checker_x := i32(current_pos.x / checker_size)
        checker_y := i32(current_pos.y / checker_size)
        segment_checker := seg.index / 10 // Group segments for pattern
        
        // Determine if this should be black or white
        is_black := (checker_x + checker_y + segment_checker) % 2 == 0
        
        color := rl.WHITE
        if is_black {
            color = rl.BLACK
        }
        
        // Draw small rectangle at this position
        rect_size := seg.thickness * 0.8
        rl.DrawRectangle(
            i32(current_pos.x - rect_size * 0.5),
            i32(current_pos.y - rect_size * 0.5),
            i32(rect_size),
            i32(rect_size),
            color,
        )
    }
    
    // Draw outline for better definition
    rl.DrawLineEx(start, end, 1.0, rl.GRAY)
}

// SegCollection manages a collection of segments
SegCollection :: struct {
    segments: [dynamic]Segment,
}

// Create a new segment collection
new_seg_collection :: proc() -> SegCollection {
    return SegCollection{
        segments = make([dynamic]Segment),
    }
}

// Add a segment to the collection
seg_collection_add :: proc(collection: ^SegCollection, x, y, length, angle, thickness: f32) {
    append(&collection.segments, segment_create(x, y, length, angle, thickness, i32(len(collection.segments))))
}

// Make the entire chain go to a target position
seg_collection_goto_pos :: proc(collection: ^SegCollection, tx, ty: f32) {
    if len(collection.segments) == 0 do return
    
    // Forward pass - make each segment follow the one before it
    pos := segment_follow(&collection.segments[0], tx, ty)
    for i in 1..<len(collection.segments) {
        pos = segment_follow(&collection.segments[i], pos.x, pos.y)
    }
    // Backward pass - update and draw from last to first
    last := len(collection.segments) - 1
    segment_update(&collection.segments[last])
    segment_draw(&collection.segments[last])
    
    for i := last - 1; i >= 0; i -= 1 {
        // Connect this segment to the previous one
        collection.segments[i].a.x = collection.segments[i + 1].b.x
        collection.segments[i].a.y = collection.segments[i + 1].b.y
        
        segment_update(&collection.segments[i])
        segment_draw(&collection.segments[i])
    }
}

// Show all segments in the collection
seg_collection_draw :: proc(collection: ^SegCollection) {
    for &seg in collection.segments {
        segment_draw(&seg)
    }
}

// Clean up the collection
seg_collection_destroy :: proc(collection: ^SegCollection) {
    delete(collection.segments)
}

main :: proc() {
    rl.InitWindow(1200, 750, "Inverse Kinematics Tentacle")
    defer rl.CloseWindow()
    rl.SetTargetFPS(60)
    
    // Create segment collection
    segments := new_seg_collection()
    defer seg_collection_destroy(&segments)
    
    // Add segments to create a chain
    for i in 0..<200 {
        thickness := f32(i / 5 + 2) // Gradually increase thickness
        seg_collection_add(&segments, 0, 0, 2, 0, thickness)
    }
    for !rl.WindowShouldClose() {
        rl.BeginDrawing()
        rl.ClearBackground(rl.LIGHTGRAY)
        
        // Draw title
        rl.DrawText("Inverse Kinematics", 10, 10, 20, rl.BLACK)
        rl.DrawText("Move mouse to control the kraken", 10, 35, 16, rl.DARKGRAY)
        
        // Chain follows mouse
        mouse_pos := rl.GetMousePosition()
        seg_collection_goto_pos(&segments, mouse_pos.x, mouse_pos.y)
        rl.EndDrawing()
    }
}