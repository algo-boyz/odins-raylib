package main

import rl "vendor:raylib"

main :: proc() {
    screenWidth:i32 = 800
    screenHeight:i32 = 450

    rl.InitWindow(screenWidth, screenHeight, "Earth")

    camera : rl.Camera3D
    camera.position    = rl.Vector3{0.0, 5.0, 15.0} 
    camera.target      = rl.Vector3{0.0, 0.0, 0.0}
    camera.up          = rl.Vector3{0.0, 1.0, 0.0}
    camera.fovy        = 45.0
    camera.projection  = rl.CameraProjection.PERSPECTIVE

    cubePosition := rl.Vector3{0.0, 0.0, 0.0}
    subdivisions:i32  // Start with basic cube
    radius:i32 = 2

    rl.SetTargetFPS(60)

    for !rl.WindowShouldClose() {
        // Update
        rl.UpdateCamera(&camera, rl.CameraMode.FREE)
        if rl.IsKeyPressed(rl.KeyboardKey.Z) {
            camera.target = rl.Vector3{0.0, 0.0, 0.0}
        }
        // Handle mouse wheel for subdivision level
        if rl.IsKeyPressed(rl.KeyboardKey.P) {
            subdivisions = clamp(subdivisions + 1, 0, 7)
            radius = clamp(radius + 1, 2, 8)
        } 
        if rl.IsKeyPressed(rl.KeyboardKey.M) {
            subdivisions = clamp(subdivisions - 1, 0, 7)
            radius = clamp(radius - 1, 2, 8)
        }
        // Draw
        rl.BeginDrawing()
        rl.ClearBackground(rl.BLACK)

        rl.BeginMode3D(camera)

        DrawCubeSphere(cubePosition, f32(radius), subdivisions, rl.BLUE)
        // rl.DrawGrid(10, 1.0)

        rl.EndMode3D()

        rl.DrawText(rl.TextFormat("Radius: %d / Subdivisions: %d ( P to increase, M to decrease )", radius, subdivisions), 10, 420, 20, rl.YELLOW)
        rl.DrawFPS(10, 10)

        rl.EndDrawing()
    }

    rl.CloseWindow()
}

DrawCubeSphere :: proc(center: rl.Vector3, radius: f32, subdivisions: i32, color: rl.Color) {
    cubeVertices := []rl.Vector3{
        {-1.0, -1.0, -1.0}, {1.0, -1.0, -1.0},
        {1.0, 1.0, -1.0}, {-1.0, 1.0, -1.0},
        {-1.0, -1.0, 1.0}, {1.0, -1.0, 1.0},
        {1.0, 1.0, 1.0}, {-1.0, 1.0, 1.0},
    };

    cubeIndices := []i32{
        0, 1, 2,   0, 2, 3,  // Front
        5, 4, 7,   5, 7, 6,  // Back
        4, 0, 3,   4, 3, 7,  // Left
        1, 5, 6,   1, 6, 2,  // Right
        3, 2, 6,   3, 6, 7,  // Top
        4, 5, 1,   4, 1, 0,  // Bottom
    };

    // Perform subdivisions
    for i:i32 = 0; i < subdivisions; i += 1 {
        subdividedVertices, subdividedIndices := subdivide(cubeVertices, cubeIndices, radius);
        cubeVertices = subdividedVertices;
        cubeIndices = subdividedIndices;
    }

    // Draw solid faces with slightly transparent color for better wireframe visibility
    solid_color := color;
    solid_color.a = 200;  // Make faces slightly transparent
    for i := 0; i < len(cubeIndices); i += 3 {
        v1 := cubeVertices[cubeIndices[i]] + center;
        v2 := cubeVertices[cubeIndices[i + 1]] + center;
        v3 := cubeVertices[cubeIndices[i + 2]] + center;

        rl.DrawTriangle3D(v1, v2, v3, solid_color);
    }

    // Draw all triangle edges (including internal ones)
    wireColor := rl.BLACK;
    for i := 0; i < len(cubeIndices); i += 3 {
        v1 := cubeVertices[cubeIndices[i]] + center;
        v2 := cubeVertices[cubeIndices[i + 1]] + center;
        v3 := cubeVertices[cubeIndices[i + 2]] + center;

        rl.DrawLine3D(v1, v2, wireColor);
        rl.DrawLine3D(v2, v3, wireColor);
        rl.DrawLine3D(v3, v1, wireColor);
    }
}

subdivide :: proc(vertices: []rl.Vector3, indices: []i32, radius: f32) -> ([]rl.Vector3, []i32) {
    newVertices := make_map(map[rl.Vector3]i32, context.allocator)
    // Calculate the new size: each triangle (3 indices) becomes 4 triangles (12 indices)
    newIndicesSize := (len(indices) / 3) * 12
    newIndices := make([]i32, newIndicesSize)
    
    newIndexCount := 0
    for i := 0; i < len(indices); i += 3 {
        v1 := vertices[indices[i]]
        v2 := vertices[indices[i + 1]]
        v3 := vertices[indices[i + 2]]

        m1 := mid_point(v1, v2)
        m2 := mid_point(v2, v3)
        m3 := mid_point(v3, v1)

        i1 := add_vertex(&newVertices, v1, radius)
        i2 := add_vertex(&newVertices, v2, radius)
        i3 := add_vertex(&newVertices, v3, radius)
        im1 := add_vertex(&newVertices, m1, radius)
        im2 := add_vertex(&newVertices, m2, radius)
        im3 := add_vertex(&newVertices, m3, radius)

        // Add four triangles for this face
        indexOffset := i * 4  // For each original triangle (i), we create 4 new ones
        
        // First triangle
        newIndices[newIndexCount] = i1
        newIndices[newIndexCount + 1] = im1
        newIndices[newIndexCount + 2] = im3
        
        // Second triangle
        newIndices[newIndexCount + 3] = im1
        newIndices[newIndexCount + 4] = i2
        newIndices[newIndexCount + 5] = im2
        
        // Third triangle (middle)
        newIndices[newIndexCount + 6] = im1
        newIndices[newIndexCount + 7] = im2
        newIndices[newIndexCount + 8] = im3
        
        // Fourth triangle
        newIndices[newIndexCount + 9] = im3
        newIndices[newIndexCount + 10] = im2
        newIndices[newIndexCount + 11] = i3
        
        newIndexCount += 12
    }

    finalVertices := make([]rl.Vector3, len(newVertices))
    for vertex, index in newVertices {
        finalVertices[index - 1] = vertex
    }

    return finalVertices, newIndices
}

add_vertex :: proc(newVertices: ^map[rl.Vector3]i32, v: rl.Vector3, radius: f32) -> i32 {
    normalized := normalize(v, radius);
    if index := newVertices[normalized]; index > 0 {
        return index - 1; // Return existing vertex index
    }
    index := i32(len(newVertices))
    newVertices[normalized] = index + 1
    return index;
};

mid_point :: proc(v1, v2: rl.Vector3) -> rl.Vector3 {
    return (v1 + v2) * 0.5
}

normalize :: proc(v: rl.Vector3, radius: f32) -> rl.Vector3 {
    length := rl.Vector3Length(v)
    if length > 0 {
        return v * (radius / length)
    }
    return v
}