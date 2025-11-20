package main

import "core:math"
import rl "vendor:raylib"
import geom "../../rlutil/geom"

create_checkered_texture :: proc(width, height, checker_size: i32) -> rl.Texture2D {
    image := rl.GenImageColor(width, height, rl.WHITE)
    
    // Create a checkered pattern
    for y in 0..<height {
        for x in 0..<width {
            checker_x := x / checker_size
            checker_y := y / checker_size
            
            if (checker_x + checker_y) % 2 == 1 {
                rl.ImageDrawPixel(&image, x, y, rl.BLACK)
            }
        }
    }
    texture := rl.LoadTextureFromImage(image)
    rl.UnloadImage(image)
    return texture
}

// Single segment in a kinematic chain
Segment :: struct {
    len, angle, thickness: f32,
    a, b:      rl.Vector2,
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

// Draw textured segment
segment_draw :: proc(seg: ^Segment, texture: rl.Texture2D) {
    // Calculate perpendicular vector for thickness
    perp_x := -math.sin(seg.angle) * seg.thickness * 0.5
    perp_y := math.cos(seg.angle) * seg.thickness * 0.5
    // Create quad vertices for textured segment
    dst := rl.Rectangle{
        x = seg.a.x,
        y = seg.a.y,
        width = seg.len,
        height = seg.thickness,
    }
    src := rl.Rectangle{
        x = 0,
        y = 0,
        width = f32(texture.width),
        height = f32(texture.height),
    }
    origin := rl.Vector2{0, seg.thickness * 0.5}
    
    // Draw textured rectangle rotated along segment angle
    rl.DrawTexturePro(texture, src, dst, origin, seg.angle * 180.0 / math.PI, rl.WHITE)
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
    append(&collection.segments, segment_create(x, y, len, angle, thickness))
}

// Make the entire chain go to a target position
seg_collection_goto_pos :: proc(collection: ^SegCollection, tx, ty: f32, texture: rl.Texture2D) {
    if len(collection.segments) == 0 do return
    
    // Forward pass - make each segment follow the one before it
    pos := segment_follow(&collection.segments[0], tx, ty)
    for i in 1..<len(collection.segments) {
        pos = segment_follow(&collection.segments[i], pos.x, pos.y)
    }
    // Backward pass - update and draw from last to first
    last := len(collection.segments) - 1
    segment_update(&collection.segments[last])
    segment_draw(&collection.segments[last], texture)
    
    for i := last - 1; i >= 0; i -= 1 {
        // Connect this segment to the previous one
        collection.segments[i].a.x = collection.segments[i + 1].b.x
        collection.segments[i].a.y = collection.segments[i + 1].b.y
        
        segment_update(&collection.segments[i])
        segment_draw(&collection.segments[i], texture)
    }
}

// Show all segments in the collection
seg_collection_draw :: proc(collection: ^SegCollection, texture: rl.Texture2D) {
    for &seg in collection.segments {
        segment_draw(&seg, texture)
    }
}

// Clean up collection
seg_collection_destroy :: proc(collection: ^SegCollection) {
    delete(collection.segments)
}

main :: proc() {
    rl.InitWindow(1250, 750, "Inverse Kinematics snake")
    defer rl.CloseWindow()
    rl.SetTargetFPS(60)
    
    // Create checkered flag texture
    flag_texture := create_checkered_texture(64, 64, 8)
    defer rl.UnloadTexture(flag_texture)
    
    // Create segment collection
    segments := new_seg_collection()
    defer seg_collection_destroy(&segments)
    
    // Add segments to create a chain
    for i in 0..<100 {
        thickness := f32(20 + i/5) // Gradually increase thickness
        seg_collection_add(&segments, 0, 0, 8, 0, thickness)
    }    
    for !rl.WindowShouldClose() {
        rl.BeginDrawing()
        defer rl.EndDrawing()
        rl.ClearBackground(rl.LIGHTGRAY)
        
        // Draw title
        rl.DrawText("Inverse Kinematics", 10, 10, 20, rl.BLACK)
        rl.DrawText("Move mouse to control the flag", 10, 35, 16, rl.DARKGRAY)
        
        // Chain follows mouse
        mouse_pos := rl.GetMousePosition()
        seg_collection_goto_pos(&segments, mouse_pos.x, mouse_pos.y, flag_texture)
    }
}