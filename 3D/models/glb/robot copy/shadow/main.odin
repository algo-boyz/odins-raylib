package main

import rl "vendor:raylib"
import "vendor:raylib/rlgl"
import "core:fmt"
import "core:strings"

SHADOWMAP_RESOLUTION :: 1024

load_shadowmap_render_texture :: proc(width, height: i32) -> rl.RenderTexture2D {
    target := rl.RenderTexture2D{}
    
    target.id = rlgl.LoadFramebuffer(width, height) // Load an empty framebuffer
    target.texture.width = width
    target.texture.height = height
    
    if target.id > 0 {
        rlgl.EnableFramebuffer(target.id)
        
        // Create depth texture
        // We don't need a color texture for the shadowmap
        target.depth.id = rlgl.LoadTextureDepth(width, height, false)
        target.depth.width = width
        target.depth.height = height
        target.depth.format = rl.PixelFormat(19) // 24BIT DEPTH
        target.depth.mipmaps = 1
        
        // Attach depth texture to FBO
        rlgl.FramebufferAttach(target.id, target.depth.id, i32(rlgl.FramebufferAttachType.DEPTH), i32(rlgl.FramebufferAttachTextureType.TEXTURE2D), 0)
        
        // Check if fbo is complete with attachments (valid)
        if rlgl.FramebufferComplete(target.id) {
            rl.TraceLog(rl.TraceLogLevel.INFO, "FBO: [ID %i] Framebuffer object created successfully", target.id)
        }
        
        rlgl.DisableFramebuffer()
    } else {
        rl.TraceLog(rl.TraceLogLevel.WARNING, "FBO: Framebuffer object can not be created")
    }
    
    return target
}

unload_shadowmap_render_texture :: proc(target: rl.RenderTexture2D) {
    if target.id > 0 {
        // NOTE: Depth texture/renderbuffer is automatically
        // queried and deleted before deleting framebuffer
        rlgl.UnloadFramebuffer(target.id)
    }
}

draw_scene :: proc(cube, robot: rl.Model) {
    rl.DrawModelEx(cube, {0, 0, 0}, {0, 1, 0}, 0.0, {10, 1, 10}, rl.BLUE)
    rl.DrawModelEx(cube, {1.5, 1.0, -1.5}, {0, 1, 0}, 0.0, {1, 1, 1}, rl.WHITE)
    rl.DrawModelEx(robot, {0, 0.5, 0}, {0, 1, 0}, 0.0, {1, 1, 1}, rl.RED)
}

main :: proc() {
    // Initialization
    screen_width: i32 = 800
    screen_height: i32 = 450
    
    rl.SetConfigFlags({.MSAA_4X_HINT})
    // Shadows are a HUGE topic, and this example shows an extremely simple implementation of the shadowmapping algorithm,
    // which is the industry standard for shadows. This algorithm can be extended in a ridiculous number of ways to improve
    // realism and also adapt it for different scenes. This is pretty much the simplest possible implementation.
    rl.InitWindow(screen_width, screen_height, "raylib [shaders] example - shadowmap")
    defer rl.CloseWindow()
    
    cam := rl.Camera3D{
        position = {10.0, 10.0, 10.0},
        target = {0, 0, 0},
        up = {0, 1, 0},
        fovy = 45.0,
        projection = .PERSPECTIVE,
    }
    
    // Load shaders
    vs_path := fmt.ctprint("../assets/shadow.vs")
    fs_path := fmt.ctprint("../assets/shadow.fs")
    
    shadow_shader := rl.LoadShader(vs_path, fs_path)
    defer rl.UnloadShader(shadow_shader)
    
    shadow_shader.locs[rl.ShaderLocationIndex.VECTOR_VIEW] = rl.GetShaderLocation(shadow_shader, "viewPos")

    light_dir := rl.Vector3Normalize({0.35, -1.0, -0.35})
    light_color := rl.WHITE
    light_color_normalized := rl.ColorNormalize(light_color)
    
    light_dir_loc := rl.GetShaderLocation(shadow_shader, "lightDir")
    light_col_loc := rl.GetShaderLocation(shadow_shader, "lightColor")
    rl.SetShaderValue(shadow_shader, light_dir_loc, &light_dir, .VEC3)
    rl.SetShaderValue(shadow_shader, light_col_loc, &light_color_normalized, .VEC4)
    
    ambient_loc := rl.GetShaderLocation(shadow_shader, "ambient")
    ambient := [4]f32{0.1, 0.1, 0.1, 1.0}
    rl.SetShaderValue(shadow_shader, ambient_loc, &ambient, .VEC4)
    
    light_vp_loc := rl.GetShaderLocation(shadow_shader, "lightVP")
    shadow_map_loc := rl.GetShaderLocation(shadow_shader, "shadowMap")
    shadow_map_resolution := SHADOWMAP_RESOLUTION
    rl.SetShaderValue(shadow_shader, rl.GetShaderLocation(shadow_shader, "shadowMapResolution"), &shadow_map_resolution, .INT)
    
    shadow_shader.locs[rl.ShaderLocationIndex.MATRIX_MODEL] = rl.GetShaderLocation(shadow_shader, "matModel");
    shadow_shader.locs[rl.ShaderLocationIndex.VECTOR_VIEW] = rl.GetShaderLocation(shadow_shader, "viewPos");

    // Load models
    cube := rl.LoadModelFromMesh(rl.GenMeshCube(1.0, 1.0, 1.0))
    defer rl.UnloadModel(cube)
    cube.materials[0].shader = shadow_shader
    
    robot := rl.LoadModel("../assets/robot.glb")
    defer rl.UnloadModel(robot)
    
    for i in 0..<robot.materialCount {
        robot.materials[i].shader = shadow_shader
    }

    anim_count: i32
    robot_animations := rl.LoadModelAnimations("../assets/robot.glb", &anim_count)
    defer rl.UnloadModelAnimations(robot_animations, anim_count)
    
    shadow_map := load_shadowmap_render_texture(SHADOWMAP_RESOLUTION, SHADOWMAP_RESOLUTION)
    defer unload_shadowmap_render_texture(shadow_map)
    // robot.materials[0].maps[rl.MaterialMapIndex.ALBEDO].texture = shadow_map.texture;
    
    // For the shadowmapping algorithm, we will be rendering everything from the light's point of view
    light_cam := rl.Camera3D{
        position = light_dir * -15.0,
        target = {0, 0, 0},
        up = {0, 1, 0},
        fovy = 20.0,
        projection = .ORTHOGRAPHIC, // Use an orthographic projection for directional lights
    }
    
    rl.SetTargetFPS(60)
    fc: i32 = 0
    
    for !rl.WindowShouldClose() {
        dt := rl.GetFrameTime()
        
        camera_pos := cam.position

        rl.SetShaderValue(shadow_shader, shadow_shader.locs[rl.ShaderLocationIndex.VECTOR_VIEW], &camera_pos, .VEC3)
        rl.UpdateCamera(&cam, .ORBITAL)
        
        fc += 1
        fc %= robot_animations[0].frameCount
        rl.UpdateModelAnimation(robot, robot_animations[0], fc)
        
        camera_speed: f32 = 0.05
        if rl.IsKeyDown(.LEFT) {
            if light_dir.x < 0.6 {
                light_dir.x += camera_speed * 60.0 * dt
            }
        }
        if rl.IsKeyDown(.RIGHT) {
            if light_dir.x > -0.6 {
                light_dir.x -= camera_speed * 60.0 * dt
            }
        }
        if rl.IsKeyDown(.UP) {
            if light_dir.z < 0.6 {
                light_dir.z += camera_speed * 60.0 * dt
            }
        }
        if rl.IsKeyDown(.DOWN) {
            if light_dir.z > -0.6 {
                light_dir.z -= camera_speed * 60.0 * dt
            }
        }
        light_dir = rl.Vector3Normalize(light_dir)
        light_cam.position = light_dir * -15.0
        rl.SetShaderValue(shadow_shader, light_dir_loc, &light_dir, .VEC3)
        
        rl.BeginDrawing()        
        // First, render all objects into the shadowmap
        // The idea is, we record all the objects' depths (as rendered from the light source's point of view) in a buffer
        // Anything that is "visible" to the light is in light, anything that isn't is in shadow
        // We can later use the depth buffer when rendering everything from the player's point of view
        // to determine whether a given point is "visible" to the light
        
        // Record light matrices for future use
        light_view: rl.Matrix
        light_proj: rl.Matrix
        
        rl.BeginTextureMode(shadow_map)
        {
            rl.ClearBackground(rl.WHITE)
            rl.BeginMode3D(light_cam)
            {
                light_view = rlgl.GetMatrixModelview()
                light_proj = rlgl.GetMatrixProjection()
                draw_scene(cube, robot)
            }
            rl.EndMode3D()

        }
        rl.EndTextureMode()

        light_proj_view := light_proj * light_view

        rl.ClearBackground(rl.RAYWHITE)
        
        rl.SetShaderValueMatrix(shadow_shader, light_vp_loc, light_proj_view)
        
        rlgl.EnableShader(shadow_shader.id)
        slot: i32 = 10 // Any in 0 to 15, but 0 will probably be taken up
        rlgl.ActiveTextureSlot(10)
        rlgl.EnableTexture(shadow_map.depth.id)
        rlgl.SetUniform(shadow_map_loc, &slot, i32(rl.ShaderUniformDataType.INT), 1)
        
        rl.BeginMode3D(cam)
        {
            // Draw the same exact thing that we drew in the shadowmap
            draw_scene(cube, robot)
        }
        rl.EndMode3D()

        rl.DrawText("Shadows in raylib using the shadowmapping algorithm!", screen_width - 320, screen_height - 20, 10, rl.GRAY)
        rl.DrawText("Use the arrow keys to rotate the light!", 10, 10, 30, rl.RED)
        
        if rl.IsKeyPressed(.F) {
            rl.TakeScreenshot("shaders_shadowmap.png")
        }
        rl.EndDrawing()
    }
}