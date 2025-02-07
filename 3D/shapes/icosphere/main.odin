package main

import "core:math"
import rl "vendor:raylib"

screenWidth:i32 = 800
screenHeight:i32 = 450

main :: proc() {
    rl.InitWindow(screenWidth, screenHeight, "Earth")

    camera : rl.Camera3D
    camera.position    = rl.Vector3{0.0, 5.0, 15.0} 
    camera.target     = rl.Vector3{0.0, 0.0, 0.0}
    camera.up         = rl.Vector3{0.0, 1.0, 0.0}
    camera.fovy       = 45.0
    camera.projection = rl.CameraProjection.PERSPECTIVE

    sphere_position := rl.Vector3{0.0, 0.0, 0.0}
    subdivisions:u8 = 0  // Start with basic icosahedron
    radius:f32 = 2.0
    // generate initial sphere vertices
    sphere_vertices := generate_icosphere(subdivisions)

    rl.SetTargetFPS(60)

    for !rl.WindowShouldClose() {
        rl.UpdateCamera(&camera, rl.CameraMode.FREE)
        if rl.IsKeyPressed(rl.KeyboardKey.Z) {
            camera.target = rl.Vector3{0.0, 0.0, 0.0}
        }
        // Handle subdivision level changes
        regen := false
        if rl.IsKeyPressed(rl.KeyboardKey.P) && subdivisions < 9 {
            subdivisions += 1
            radius += 1
            regen = true
        } 
        if rl.IsKeyPressed(rl.KeyboardKey.M) && subdivisions > 0 {
            subdivisions -= 1
            radius -= 1
            regen = true
        }
        // Regenerate sphere if subdivision level changed
        if regen {
            delete(sphere_vertices)
            sphere_vertices = generate_icosphere(subdivisions)
        }
        rl.BeginDrawing()
        rl.ClearBackground(rl.BLACK)
        rl.BeginMode3D(camera)
        draw_icosphere(sphere_vertices[:], sphere_position, radius, rl.BLUE)
        rl.EndMode3D()
        rl.DrawFPS(10, 10)
        rl.DrawText(rl.TextFormat("Subdivisions: %d ( P to increase, M to decrease )", subdivisions), 10, 420, 20, rl.YELLOW)
        rl.DrawText(rl.TextFormat("Triangle count: %d", len(sphere_vertices)/3), 10, 390, 20, rl.GREEN)
        rl.EndDrawing()
    }
    delete(sphere_vertices)
    rl.CloseWindow()
}

// Recursive method for subdividing each face of a polygon.
sub_divide_triangle :: proc(vertices: ^[dynamic]rl.Vector3, a, b, c: rl.Vector3, depth: u8) {
    // If we've reached the end, push the triangle face onto the vertices list and stop recursing.
    if (depth == 0)
    {
        append(vertices, a)
        append(vertices, b)
        append(vertices, c)
        return
    }
    /** For each triangle that's passed in, split it into 4 triangles and recursively subdivide those.
     *           a
     *           /\
     *          /  \
     *     ab  /----\  ca
     *        / \  / \
     *       /   \/   \
     *    b ------------ c
     *           bc
     */
    ab := rl.Vector3Normalize(a + b)
    bc := rl.Vector3Normalize(b + c)
    ca := rl.Vector3Normalize(c + a)
    sub_divide_triangle(vertices, a, ab, ca, depth - 1);
    sub_divide_triangle(vertices, b, bc, ab, depth - 1);
    sub_divide_triangle(vertices, ab, bc, ca, depth - 1);
    sub_divide_triangle(vertices, c, ca, bc, depth - 1);
}

/*
Generates a set of vertices for a regular unit-size triangulated icosphere.
The returned vertices form a triangle mesh that forms an approximation of a sphere.

subdivision_depth is currently capped at 9 just for sanity purposes. Here are the triangle counts at each depth:
  0 -> 20           5 -> 20480
  1 -> 80           6 -> 81920
  2 -> 320          7 -> 327680
  3 -> 1280         8 -> 1310720
  4 -> 5120         9 -> 5242880
Generally a depth of 3-6 will be sufficient for most purposes.
*/
generate_icosphere :: proc(subdivision_depth: u8) -> [dynamic]rl.Vector3 {
    ICOSAHEDRON_FACES :: 20

    // Define vertices and face indices of a regular icosahedron
    t := (1.0 + math.sqrt_f32(5.0)) / 2.0
    
    icosahedron_vertices := [12]rl.Vector3{
        {-1, t, 0}, {1, t, 0}, {-1, -t, 0}, {1, -t, 0},
        {0, -1, t}, {0, 1, t}, {0, -1, -t}, {0, 1, -t},
        {t, 0, -1}, {t, 0, 1}, {-t, 0, -1}, {-t, 0, 1}
    }

    face_indices := [ICOSAHEDRON_FACES][3]int{
        {0, 11, 5}, {0, 5, 1}, {0, 1, 7}, {0, 7, 10}, {0, 10, 11},
        {1, 5, 9}, {5, 11, 4}, {11, 10, 2}, {10, 7, 6}, {7, 1, 8},
        {3, 9, 4}, {3, 4, 2}, {3, 2, 6}, {3, 6, 8}, {3, 8, 9},
        {4, 9, 5}, {2, 4, 11}, {6, 2, 10}, {8, 6, 7}, {9, 8, 1}
    }

    capped_depth := min(subdivision_depth, 9)
    sphere_vertices := make([dynamic]rl.Vector3, 0, ICOSAHEDRON_FACES * 3 * int(math.pow(4, f64(capped_depth))))

    for face in 0..<ICOSAHEDRON_FACES {
        v1 := rl.Vector3Normalize(icosahedron_vertices[face_indices[face][0]])
        v2 := rl.Vector3Normalize(icosahedron_vertices[face_indices[face][1]])
        v3 := rl.Vector3Normalize(icosahedron_vertices[face_indices[face][2]])
        
        sub_divide_triangle(
            &sphere_vertices,
            v1, v2, v3,
            capped_depth,
        )
    }
    return sphere_vertices
}

draw_icosphere :: proc(vertices: []rl.Vector3, center: rl.Vector3, radius: f32, color: rl.Color) {
    solid_color := color
    solid_color.a = 200  // Make faces slightly transparent
    // Draw triangles
    for i := 0; i < len(vertices); i += 3 {
        v1 := vertices[i] * radius + center
        v2 := vertices[i + 1] * radius + center
        v3 := vertices[i + 2] * radius + center
        rl.DrawTriangle3D(v1, v2, v3, solid_color)
    }
    // Draw wireframe
    wire_color := rl.BLACK
    for i := 0; i < len(vertices); i += 3 {
        v1 := vertices[i] * radius + center
        v2 := vertices[i + 1] * radius + center
        v3 := vertices[i + 2] * radius + center
        rl.DrawLine3D(v1, v2, wire_color)
        rl.DrawLine3D(v2, v3, wire_color)
        rl.DrawLine3D(v3, v1, wire_color)
    }
}