package main

import "core:math"
import rl "vendor:raylib"
import "vendor:raylib/rlgl"
import geom "../../rlutil/geom"

WIDTH :: 1250
HEIGHT :: 750

// Segment represents a single segment in a kinematic chain
Segment :: struct {
    a, b:      rl.Vector2,
    len:       f32,
    angle:     f32,
    thickness: f32,
}

// Create a new segment in the chain
segment_create :: proc(x, y, len, angle, thickness: f32) -> Segment {
    seg := Segment{
        a = rl.Vector2{x, y},
        len = len,
        angle = angle,
        thickness = thickness,
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

// Draw segment with texture mapped across entire flag - renders both sides
segment_draw :: proc(seg: ^Segment, texture: rl.Texture2D, segment_index: i32, total_segments: i32) {
    // Calculate texture coordinates for this segment
    u_start := f32(segment_index) / f32(total_segments)
    u_end := f32(segment_index + 1) / f32(total_segments)
    
    // Calculate quad vertices
    p1 := rl.Vector2{seg.a.x, seg.a.y - seg.thickness * 0.5}
    p2 := rl.Vector2{seg.a.x, seg.a.y + seg.thickness * 0.5}
    p3 := rl.Vector2{seg.b.x, seg.b.y + seg.thickness * 0.5}
    p4 := rl.Vector2{seg.b.x, seg.b.y - seg.thickness * 0.5}
    
    rlgl.SetTexture(texture.id)
    
    // Draw front face (normal texture orientation)
    rlgl.Begin(rlgl.QUADS)
    rlgl.Color4ub(255, 255, 255, 255)
    
    rlgl.TexCoord2f(u_start, 0.0)
    rlgl.Vertex2f(p1.x, p1.y)
    
    rlgl.TexCoord2f(u_start, 1.0)
    rlgl.Vertex2f(p2.x, p2.y)
    
    rlgl.TexCoord2f(u_end, 1.0)
    rlgl.Vertex2f(p3.x, p3.y)
    
    rlgl.TexCoord2f(u_end, 0.0)
    rlgl.Vertex2f(p4.x, p4.y)
    rlgl.End()
    
    // Draw back face (horizontally flipped texture)
    rlgl.Begin(rlgl.QUADS)
    rlgl.Color4ub(255, 255, 255, 255)
    
    // Reverse vertex order for back face and flip texture horizontally
    rlgl.TexCoord2f(u_end, 0.0)
    rlgl.Vertex2f(p4.x, p4.y)
    
    rlgl.TexCoord2f(u_end, 1.0)
    rlgl.Vertex2f(p3.x, p3.y)
    
    rlgl.TexCoord2f(u_start, 1.0)
    rlgl.Vertex2f(p2.x, p2.y)
    
    rlgl.TexCoord2f(u_start, 0.0)
    rlgl.Vertex2f(p1.x, p1.y)
    rlgl.End()
    
    rlgl.SetTexture(0)
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
seg_collection_add :: proc(collection: ^SegCollection, x, y, len, angle, thickness: f32) {
    seg := segment_create(x, y, len, angle, thickness)
    append(&collection.segments, seg)
}

// Make the entire chain go to a target position
seg_collection_goto_pos :: proc(collection: ^SegCollection, tx, ty: f32, texture: rl.Texture2D) {
    if len(collection.segments) == 0 do return
    
    total_segments := i32(len(collection.segments))
    
    // Forward pass - make each segment follow the one before it
    pos := segment_follow(&collection.segments[0], tx, ty)
    for i in 1..<len(collection.segments) {
        pos = segment_follow(&collection.segments[i], pos.x, pos.y)
    }
    
    // Backward pass - update and draw from last to first
    last := len(collection.segments) - 1
    segment_update(&collection.segments[last])
    segment_draw(&collection.segments[last], texture, i32(last), total_segments)
    
    for i := last - 1; i >= 0; i -= 1 {
        // Connect this segment to the previous one
        collection.segments[i].a.x = collection.segments[i + 1].b.x
        collection.segments[i].a.y = collection.segments[i + 1].b.y
        
        segment_update(&collection.segments[i])
        segment_draw(&collection.segments[i], texture, i32(i), total_segments)
    }
}

// Show all segments in the collection
seg_collection_draw :: proc(collection: ^SegCollection, texture: rl.Texture2D) {
    total_segments := i32(len(collection.segments))
    for &seg, i in collection.segments {
        segment_draw(&seg, texture, i32(i), total_segments)
    }
}

// Clean up the collection
seg_collection_destroy :: proc(collection: ^SegCollection) {
    delete(collection.segments)
}

main :: proc() {
    rl.InitWindow(WIDTH, HEIGHT, "Flag Inverse Kinematics")
    defer rl.CloseWindow()
    rl.SetTargetFPS(60)
    
    // Load the race flag texture
    flag_texture := rl.LoadTexture("us_flag.png")
    defer rl.UnloadTexture(flag_texture)
    
    // Create segment collection
    segments := new_seg_collection()
    defer seg_collection_destroy(&segments)
    
    // Add segments to create a flag-like chain
    flag_width :f32 = 200.0
    flag_height :f32 = 60.0  // Increased height to make it more flag-like
    
    for i in 0..<50 {
        seg_length := flag_width / 50.0
        thickness := flag_height
        seg_collection_add(&segments, 0, 0, seg_length, 0, thickness)
    }
    
    for !rl.WindowShouldClose() {
        rl.BeginDrawing()
        defer rl.EndDrawing()
        rl.ClearBackground(rl.LIGHTGRAY)
        
        // Draw title
        rl.DrawText("Flag Inverse Kinematics", 10, 10, 20, rl.BLACK)
        rl.DrawText("Move mouse to control the flag", 10, 35, 16, rl.DARKGRAY)
        
        // Chain follows mouse
        mouse_pos := rl.GetMousePosition()
        seg_collection_goto_pos(&segments, mouse_pos.x, mouse_pos.y, flag_texture)
    }
}