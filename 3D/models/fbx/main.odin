package ufbx_assets

import "base:runtime"
import "core:fmt"
import "core:math"
import la "core:math/linalg"
import "core:time"

import rl "vendor:raylib"

import fbx "./ufbx"

load_mesh :: proc() -> (indices: []u32, positions: [][3]f32, normals: [][3]f32, uvs: [][2]f32) {
    // Load the .fbx file
    opts := fbx.Load_Opts{}
    err := fbx.Error{}
    scene := fbx.load_file("assets/suzanne.fbx", &opts, &err)
    if scene == nil {
        fmt.printf("%s\n", err.description.data)
        panic("Failed to load")
    }
    // Retrieve the first mesh
    mesh: ^fbx.Mesh
    for i in 0 ..< scene.nodes.count {
        node := scene.nodes.data[i]
        if node.is_root || node.mesh == nil { continue }
        mesh = node.mesh
        break
    }

    // Unpack / triangulate the index data
    index_count := 3 * mesh.num_triangles
    indices = make([]u32, index_count)
    off := u32(0)
    for i in 0 ..< mesh.faces.count {
        face := mesh.faces.data[i]
        tris := fbx.catch_triangulate_face(nil, &indices[off], uint(index_count), mesh, face)
        off += 3 * tris
    }

    // Unpack the vertex data
    vertex_count := mesh.num_indices
    positions = make([][3]f32, vertex_count)
    normals = make([][3]f32, vertex_count)
    uvs = make([][2]f32, vertex_count)

    for i in 0..< vertex_count {
        pos := mesh.vertex_position.values.data[mesh.vertex_position.indices.data[i]]
        norm := mesh.vertex_normal.values.data[mesh.vertex_normal.indices.data[i]]
        uv := mesh.vertex_uv.values.data[mesh.vertex_uv.indices.data[i]]
        positions[i] = {f32(pos.x), f32(pos.y), f32(pos.z)}
        normals[i] = {f32(norm.x), f32(norm.y), f32(norm.z)}
        uvs[i] = {f32(uv.x), f32(uv.y)}
    }

    // Free the fbx data
    fbx.free_scene(scene)

    return
}

WIDTH :: 1200
HEIGHT :: 920

main :: proc() {
    shader := rl.LoadShader("assets/shader.vert", "assets/shader.frag")

    fmt.println("Loading mesh...")
    // Load mesh data from the fbx
    indices, positions, normals, uvs := load_mesh()

    // Create mesh for Raylib
    mesh := rl.Mesh{}
    mesh.vertexCount = i32(len(positions))
    mesh.triangleCount = i32(len(indices)) / 3
    
    // Convert arrays to the format Raylib expects
    vertices_float := make([]f32, len(positions) * 3)
    normals_float := make([]f32, len(normals) * 3)
    uvs_float := make([]f32, len(uvs) * 2)
    indices_u16 := make([]u16, len(indices))
    
    for i := 0; i < len(positions); i += 1 {
        vertices_float[i * 3 + 0] = positions[i].x
        vertices_float[i * 3 + 1] = positions[i].y
        vertices_float[i * 3 + 2] = positions[i].z
        
        normals_float[i * 3 + 0] = normals[i].x
        normals_float[i * 3 + 1] = normals[i].y
        normals_float[i * 3 + 2] = normals[i].z
    }
    
    for i := 0; i < len(uvs); i += 1 {
        uvs_float[i * 2 + 0] = uvs[i].x
        uvs_float[i * 2 + 1] = uvs[i].y
    }

    // Convert indices to u16
    for i := 0; i < len(indices); i += 1 {
        if indices[i] > 65535 {
            panic("Mesh has too many vertices for 16-bit indices")
        }
        indices_u16[i] = u16(indices[i])
    }

    // Upload vertex data
    mesh.vertices = raw_data(vertices_float)
    mesh.normals = raw_data(normals_float)
    mesh.texcoords = raw_data(uvs_float)
    mesh.indices = raw_data(indices_u16)

    // Initialize Raylib
    rl.InitWindow(WIDTH, HEIGHT, "odin-ufbx")
    defer rl.CloseWindow()

    rl.SetTargetFPS(60)

    // Create material and model
    material := rl.LoadMaterialDefault()
    defer rl.UnloadMaterial(material)

    model := rl.LoadModelFromMesh(mesh)
    defer rl.UnloadModel(model)

    // Setup camera
    camera := rl.Camera3D{
        position = {3, 0, 3},
        target = {0, 0, 0},
        up = {0, 1, 0},
        fovy = 45,
        projection = .PERSPECTIVE,
    }

    sw: time.Stopwatch
    time.stopwatch_start(&sw)
    rl.SetTargetFPS(60)
    target := rl.LoadRenderTexture(WIDTH, HEIGHT)
    if target.id == 0 {
        fmt.println("Failed to create render texture")
        return
    }
    // Main game loop
    for !rl.WindowShouldClose() {
        d := time.stopwatch_duration(sw)
        t := time.duration_seconds(d)
        
        // Update camera position
        camera.position.x = 3.0 * math.sin(f32(t))
        camera.position.z = 3.0 * math.cos(f32(t))

        rl.BeginDrawing()

        rl.BeginTextureMode(target)
            rl.ClearBackground(rl.BLACK)
            rl.BeginMode3D(camera)
                rl.DrawModelEx(
                    model,
                    {0, 0, 0},
                    {1, 0, 0},
                    -90,
                    {1, 1, 1},
                    rl.WHITE,
                )
            rl.EndMode3D()
        rl.EndTextureMode()

        // Then render the final result to the screen
        rl.BeginDrawing()
            rl.ClearBackground(rl.BLACK)
            rl.BeginShaderMode(shader)
                // Use target.texture instead of target.depth
                rl.DrawTextureRec(target.texture,
                    rl.Rectangle{ 0, 0, f32(target.texture.width), f32(-target.texture.height) },
                    rl.Vector2{ 0, 0 },
                    rl.WHITE)
            rl.EndShaderMode()
            rl.DrawFPS(10, 10)
        rl.EndDrawing()
    }
    rl.UnloadModel(model)
    rl.UnloadRenderTexture(target)
    rl.CloseWindow()
}