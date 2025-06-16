package main

import "core:math"
import rl "vendor:raylib"

Vector4 :: struct {
    x, y, z, w: f32,
}

main :: proc() {
    rl.InitWindow(800, 800, "Tesseract")
    defer rl.CloseWindow()
    
    camera := rl.Camera3D{
        position = {4, 4, 4},
        target = {0, 0, 0},
        up = {0, 0, 1},
        fovy = 50.0,
        projection = .PERSPECTIVE,
    }
    
    // Find the coordinates by setting XYZW to +-1
    tesseract := [16]Vector4{
        {1,  1,  1,  1}, {1,  1,  1, -1},
        {1,  1, -1,  1}, {1,  1, -1, -1},
        {1, -1,  1,  1}, {1, -1,  1, -1},
        {1, -1, -1,  1}, {1, -1, -1, -1},
        {-1,  1,  1,  1}, {-1,  1,  1, -1},
        {-1,  1, -1,  1}, {-1,  1, -1, -1},
        {-1, -1,  1,  1}, {-1, -1,  1, -1},
        {-1, -1, -1,  1}, {-1, -1, -1, -1},
    }
    
    for !rl.WindowShouldClose() {
        rl.BeginDrawing()        
        rl.ClearBackground(rl.BLACK)
        rl.BeginMode3D(camera)
        defer rl.EndMode3D()
        
        rotation := rl.DEG2RAD * 45.0 * rl.GetTime()
        transformed: [16]rl.Vector3
        w_values: [16]f32
        
        // Transform all points
        for p, i in tesseract {
            // Create mutable copy of the point
            point := p
            
            // Rotate the XW part of the vector
            xw_rot := rl.Vector2Rotate({point.x, point.w}, f32(rotation))
            point.x = xw_rot.x
            point.w = xw_rot.y
            
            // Projection from XYZW to XYZ from perspective point (0, 0, 0, 3)
            // Essentially: Trace a ray from (0, 0, 0, 3) > p and continue until W = 0
            c := 3.0 / (3.0 - point.w)
            point.x *= c
            point.y *= c
            point.z *= c
            
            // Split XYZ coordinate and W values for drawing later
            transformed[i] = {point.x, point.y, point.z}
            w_values[i] = point.w
        }
        
        // Draw the tesseract
        for p1, i in tesseract {
            // Draw spheres to indicate the W value
            rl.DrawSphere(transformed[i], math.abs(w_values[i] * 0.1), rl.DARKBLUE)
            
            // Connect points that differ by exactly one coordinate
            for p2, j in tesseract {
                // Count how many coordinates are the same
                same_coords := int(p1.x == p2.x) + 
                             int(p1.y == p2.y) + 
                             int(p1.z == p2.z) + 
                             int(p1.w == p2.w)
                
                // Draw only when differing by 1 coordinate and avoid duplicates
                if same_coords == 3 && i < j {
                    rl.DrawLine3D(transformed[i], transformed[j], rl.BLUE)
                }
            }
        }
        rl.EndDrawing()
    }
}