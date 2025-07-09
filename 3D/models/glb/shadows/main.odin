package main

import rl "vendor:raylib"
import "core:fmt"
import sm "shadow"

// Scene data structure
SceneData :: struct {
    cube:        rl.Model,
    robot:       rl.Model,
    animations:  [^]rl.ModelAnimation,
    anim_count:  i32,
    frame_count: i32,
}

// Scene rendering function
draw_scene :: proc(user_data: rawptr) {
    if user_data == nil do return
    
    scene := cast(^SceneData)user_data
    
    // Draw ground plane
    rl.DrawModelEx(scene.cube, {0, 0, 0}, {0, 1, 0}, 0.0, {10, 1, 10}, rl.BLUE)
    
    // Draw small cube
    rl.DrawModelEx(scene.cube, {1.5, 1.0, -1.5}, {0, 1, 0}, 0.0, {1, 1, 1}, rl.WHITE)
    
    // Draw animated robot
    rl.DrawModelEx(scene.robot, {0, 0.5, 0}, {0, 1, 0}, 0.0, {1, 1, 1}, rl.RED)
}

main :: proc() {
    // Initialization
    screen_width: i32 = 800
    screen_height: i32 = 450
    
    rl.SetConfigFlags({.MSAA_4X_HINT})
    rl.InitWindow(screen_width, screen_height, "Shadowmapping Package Example")
    defer rl.CloseWindow()
    
    // Set up camera
    cam := rl.Camera3D{
        position = {10.0, 10.0, 10.0},
        target = {0, 0, 0},
        up = {0, 1, 0},
        fovy = 45.0,
        projection = .PERSPECTIVE,
    }
    
    // Initialize shadow system
    shadow_system, shadow_ok := sm.init_shadow_system("assets/shadow.vs", "assets/shadow.fs")
    if !shadow_ok {
        fmt.println("Failed to initialize shadow system!")
        return
    }
    defer sm.destroy_shadow_system(&shadow_system)
    
    // Load skinning shader
    skinningShader := rl.LoadShader("assets/skinning.vs", "assets/skinning.fs")
    defer rl.UnloadShader(skinningShader)

    // Load scene models
    scene_data := SceneData{}
    scene_data.cube = rl.LoadModelFromMesh(rl.GenMeshCube(1.0, 1.0, 1.0))
    defer rl.UnloadModel(scene_data.cube)
    
    scene_data.robot = rl.LoadModel("assets/robot.glb")
    defer rl.UnloadModel(scene_data.robot)
    
    scene_data.robot.materials[0].shader = skinningShader

    scene_data.animations = rl.LoadModelAnimations("assets/robot.glb", &scene_data.anim_count)
    defer rl.UnloadModelAnimations(scene_data.animations, scene_data.anim_count)
    
    // Apply shadow shader to models
    sm.apply_shadow_shader(&shadow_system, &scene_data.cube)
    sm.apply_shadow_shader(&shadow_system, &scene_data.robot)
    
    // Light control parameters
    light_speed: f32 = 3.0
    
    rl.SetTargetFPS(60)
    
    for !rl.WindowShouldClose() {
        dt := rl.GetFrameTime()
        
        // Update camera
        rl.UpdateCamera(&cam, .ORBITAL)
        
        // Update robot animation
        scene_data.frame_count += 1
        if scene_data.anim_count > 0 {
            scene_data.frame_count %= scene_data.animations[0].frameCount
            rl.UpdateModelAnimation(scene_data.robot, scene_data.animations[0], scene_data.frame_count)
        }
        
        // Control light direction with arrow keys
        current_light := sm.get_light_direction(&shadow_system)
        target_light := current_light
        
        if rl.IsKeyDown(.LEFT) && target_light.x < 0.6 {
            target_light.x += light_speed * dt
        }
        if rl.IsKeyDown(.RIGHT) && target_light.x > -0.6 {
            target_light.x -= light_speed * dt
        }
        if rl.IsKeyDown(.UP) && target_light.z < 0.6 {
            target_light.z += light_speed * dt
        }
        if rl.IsKeyDown(.DOWN) && target_light.z > -0.6 {
            target_light.z -= light_speed * dt
        }
        
        // Smooth light interpolation
        sm.interpolate_light_direction(&shadow_system, target_light, 5.0, dt)
        
        // Optional: Change light color with number keys
        if rl.IsKeyPressed(.ONE) {
            sm.update_light_color(&shadow_system, rl.WHITE)
        }
        if rl.IsKeyPressed(.TWO) {
            sm.update_light_color(&shadow_system, rl.RED)
        }
        if rl.IsKeyPressed(.THREE) {
            sm.update_light_color(&shadow_system, rl.BLUE)
        }
        
        // Render everything
        rl.BeginDrawing()
        rl.ClearBackground(rl.RAYWHITE)
        
        // Render scene with shadows
        sm.render_with_shadows(&shadow_system, cam, draw_scene, &scene_data)
        
        // UI
        rl.DrawText("Shadowmapping Package Example", 10, 10, 20, rl.DARKGRAY)
        rl.DrawText("Arrow keys: Move light", 10, 35, 16, rl.GRAY)
        rl.DrawText("1/2/3: Change light color", 10, 55, 16, rl.GRAY)
        rl.DrawText("Mouse: Rotate camera", 10, 75, 16, rl.GRAY)
        
        // Show current light direction
        light_dir := sm.get_light_direction(&shadow_system)
        light_text := fmt.ctprintf("Light: (%.2f, %.2f, %.2f)", light_dir.x, light_dir.y, light_dir.z)
        rl.DrawText(light_text, 10, screen_height - 25, 16, rl.DARKGREEN)
        
        if rl.IsKeyPressed(.F) {
            rl.TakeScreenshot("shadowmap_example.png")
        }
        
        rl.EndDrawing()
    }
}

// Alternative example: Custom shadow configuration
example_custom_config :: proc() {
    // Create custom shadow configuration
    custom_config := sm.ShadowConfig{
        resolution     = 2048,  // Higher resolution shadows
        light_distance = 20.0,  // Further light distance
        light_fov      = 15.0,  // Tighter light cone
        ambient        = {0.2, 0.2, 0.3, 1.0}, // Slightly blue ambient
        texture_slot   = 5,     // Different texture slot
    }
    
    // Create custom light
    custom_light := sm.DirectionalLight{
        direction = {0.5, -0.8, 0.3},
        color     = rl.Color{255, 220, 180, 255}, // Warm light
    }
    
    // Initialize with custom settings
    shadow_system, ok := sm.init_shadow_system_with_config(
        "assets/shadow.vs", 
        "assets/shadow.fs",
        custom_config,
        custom_light
    )
    
    if ok {
        fmt.println("Custom shadow system initialized!")
        // Use shadow_system...
        sm.destroy_shadow_system(&shadow_system)
    }
}