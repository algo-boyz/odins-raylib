package main

import "base:runtime"
import rl "vendor:raylib"
import rlgl "vendor:raylib/rlgl"

screen_width :: 800
screen_height :: 450

// Generate cubemap (6 faces) from equirectangular (panorama) texture
gen_texture_cubemap :: proc(shader: rl.Shader, panorama: rl.Texture2D, size: i32, format: rl.PixelFormat) -> rl.TextureCubemap {
    cubemap: rl.TextureCubemap
    rlgl.DisableBackfaceCulling()     // Disable backface culling to render inside the cube
    // Setup framebuffer
    rbo := rlgl.LoadTextureDepth(size, size, true)
    id: i32
    cubemap.id = rlgl.LoadTextureCubemap(&id, size, i32(format))
    fbo := rlgl.LoadFramebuffer(screen_width, screen_height)
    rlgl.FramebufferAttach(fbo, rbo, i32(rlgl.FramebufferAttachType.DEPTH), i32(rlgl.FramebufferAttachTextureType.RENDERBUFFER), 0)
    rlgl.FramebufferAttach(fbo, cubemap.id, i32(rlgl.FramebufferAttachType.COLOR_CHANNEL0), i32(rlgl.FramebufferAttachTextureType.CUBEMAP_POSITIVE_X), 0)
    // Check if framebuffer is complete
    if rlgl.FramebufferComplete(fbo) {
        rl.TraceLog(.INFO, "FBO: [ID %i] Framebuffer created", fbo)
    }
    rlgl.EnableShader(shader.id)
    // Define projection matrix and send it to shader
    mat_fbo_projection := rl.MatrixPerspective(90.0 * rl.DEG2RAD, 1.0, rlgl.CULL_DISTANCE_NEAR, rlgl.CULL_DISTANCE_FAR)
    rlgl.SetUniformMatrix(shader.locs[rl.ShaderLocationIndex.MATRIX_PROJECTION], mat_fbo_projection)
    // Define view matrix for every side of the cubemap
    fbo_views := [6]rl.Matrix {
        rl.MatrixLookAt({0, 0, 0}, {1, 0, 0}, {0, -1, 0}),
        rl.MatrixLookAt({0, 0, 0}, {-1, 0, 0}, {0, -1, 0}),
        rl.MatrixLookAt({0, 0, 0}, {0, 1, 0}, {0, 0, 1}),
        rl.MatrixLookAt({0, 0, 0}, {0, -1, 0}, {0, 0, -1}),
        rl.MatrixLookAt({0, 0, 0}, {0, 0, 1}, {0, -1, 0}),
        rl.MatrixLookAt({0, 0, 0}, {0, 0, -1}, {0, -1, 0}),
    }
    rlgl.Viewport(0, 0, size, size)   // Set viewport to current fbo dimensions
    // Activate and enable texture for drawing to cubemap faces
    rlgl.ActiveTextureSlot(0)
    rlgl.EnableTexture(panorama.id)
    for i := 0; i < 6; i += 1 {
        // Set the view matrix for the current cube face
        rlgl.SetUniformMatrix(shader.locs[rl.ShaderLocationIndex.MATRIX_VIEW], fbo_views[i])
        // Select the current cubemap face attachment for the fbo
        rlgl.FramebufferAttach(
            fbo,
            cubemap.id,
            i32(rlgl.FramebufferAttachType.COLOR_CHANNEL0),
            i32(rlgl.FramebufferAttachTextureType.CUBEMAP_POSITIVE_X) + i32(i),
            0
        )
        rlgl.EnableFramebuffer(fbo)
        // Load and draw a cube
        rlgl.ClearScreenBuffers()
        rlgl.LoadDrawCube()
    }
    // Unload framebuffer and reset state
    rlgl.DisableShader()
    rlgl.DisableTexture()
    rlgl.DisableFramebuffer()
    rlgl.UnloadFramebuffer(fbo)
    // Reset viewport dimensions to default
    rlgl.Viewport(0, 0, rlgl.GetFramebufferWidth(), rlgl.GetFramebufferHeight())
    rlgl.EnableBackfaceCulling()
    cubemap.width = size
    cubemap.height = size
    cubemap.mipmaps = 1
    cubemap.format = format
    return cubemap
}

main :: proc() {
    rl.InitWindow(screen_width, screen_height, "raylib [models] example - skybox loading and drawing")
    camera := rl.Camera {
        position = {0.0, 0.0, 0.0},  // Center of the cube
        target = {1.0, 0.0, 0.0},    // Looking in some direction
        up = {0.0, 1.0, 0.0},
        fovy = 45.0,
        projection = rl.CameraProjection.PERSPECTIVE,
    }
    // Load skybox model
    cube := rl.GenMeshCube(1.0, 1.0, 1.0)
    skybox := rl.LoadModelFromMesh(cube)
    // Load skybox shader
    skybox.materials[0].shader = rl.LoadShader("assets/skybox.vs", "assets/skybox.fs")
    val := rl.MaterialMapIndex.CUBEMAP
    rl.SetShaderValue(
        skybox.materials[0].shader,
        rl.GetShaderLocation(skybox.materials[0].shader, "environmentMap"),
        rawptr(&val),
        rl.ShaderUniformDataType.INT,
    )
    do_gamma:f32
    vflipped:f32
    rl.SetShaderValue(
        skybox.materials[0].shader,
        rl.GetShaderLocation(skybox.materials[0].shader, "doGamma"),
        rawptr(&do_gamma),
        rl.ShaderUniformDataType.FLOAT,
    )
    rl.SetShaderValue(
        skybox.materials[0].shader,
        rl.GetShaderLocation(skybox.materials[0].shader, "vflipped"),
        rawptr(&vflipped),
        rl.ShaderUniformDataType.FLOAT,
    )
    // Load cubemap shader
    shader_cubemap := rl.LoadShader("assets/cubemap.vs", "assets/cubemap.fs")
    equirectangular_map := i32(0)
    rl.SetShaderValue(
        shader_cubemap,
        rl.GetShaderLocation(shader_cubemap, "equirectangularMap"),
        rawptr(&equirectangular_map),
        rl.ShaderUniformDataType.FLOAT,
    )
    img := rl.LoadImage("assets/skybox.png")
    skybox.materials[0].maps[rl.MaterialMapIndex.CUBEMAP].texture = rl.LoadTextureCubemap(img, rl.CubemapLayout.AUTO_DETECT)
    rl.UnloadImage(img)
    // rl.DisableCursor()
    rl.SetTargetFPS(60)
    for !rl.WindowShouldClose() {
        rl.UpdateCamera(&camera, .FIRST_PERSON)
        rl.BeginDrawing()
        defer rl.EndDrawing()
        rl.ClearBackground(rl.BLACK)
        rl.BeginMode3D(camera)
        {
            // We are inside the cube, disable backface culling
            rlgl.DisableBackfaceCulling()
            rlgl.DisableDepthMask()
            rl.DrawModel(skybox, {0, 0, 0}, -1.0, rl.WHITE)
            rlgl.EnableBackfaceCulling()
            rlgl.EnableDepthMask()
            rl.DrawGrid(10, 1.0)
        }
        rl.EndMode3D()
        rl.DrawFPS(10, 10)
    }
    rl.UnloadShader(skybox.materials[0].shader)
    rl.UnloadTexture(skybox.materials[0].maps[rl.MaterialMapIndex.CUBEMAP].texture)
    rl.UnloadModel(skybox)
    rl.CloseWindow()
}