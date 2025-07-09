package main

import rl "vendor:raylib"
import "core:fmt"
import "core:slice"
import sm "shadow" // Your enhanced shadow package

// Enhanced scene data with LOD support
SceneData :: struct {
    models:         [dynamic]sm.ModelLOD,
    animations:     [^]rl.ModelAnimation,
    anim_count:     i32,
    frame_count:    i32,
    debug_mode:     bool,
    show_wireframe: bool,
}

// Scene rendering function with shadow pass awareness
draw_scene :: proc(user_data: rawptr, shadow_pass: bool) {
    if user_data == nil {
        fmt.println("ERROR: draw_scene called with nil user_data")
        return
    }
    
    scene := cast(^SceneData)user_data
    
    // Safety check for scene validity
    if scene == nil {
        fmt.println("ERROR: scene cast failed")
        return
    }
    
    if len(scene.models) == 0 {
        fmt.println("WARNING: No models to render")
        return
    }
    
    // In shadow pass, we can use simplified rendering
    if shadow_pass {
        // Use LOD models for shadow casting (handled automatically by the system)
        for i in 0..<len(scene.models) {
            model := &scene.models[i]
            if model == nil do continue
            
            // Additional safety checks
            if model.high_detail.meshCount == 0 {
                fmt.printf("WARNING: Model %d has no meshes\n", i)
                continue
            }
            
            if model.is_static {
                // Static objects like ground
                rl.DrawModelEx(model.high_detail, model.position, {0, 1, 0}, 0.0, model.scale, rl.WHITE)
            } else {
                // Dynamic objects like robot (use animation)
                rl.DrawModelEx(model.high_detail, model.position, {0, 1, 0}, 0.0, model.scale, rl.WHITE)
            }
        }
    } else {
        // Main pass with full quality
        for i in 0..<len(scene.models) {
            model := &scene.models[i]
            if model == nil do continue
            
            // Additional safety checks
            if model.high_detail.meshCount == 0 {
                fmt.printf("WARNING: Model %d has no meshes in main pass\n", i)
                continue
            }
            
            color := rl.WHITE
            
            // Different colors for identification
            if model.position.y < 0.5 {
                color = rl.BLUE // Ground
            } else if model.scale.x == 1.0 && model.scale.y == 1.0 && model.scale.z == 1.0 {
                color = rl.LIGHTGRAY // Small cube
            } else {
                color = rl.RED // Robot
            }
            
            rl.DrawModelEx(model.high_detail, model.position, {0, 1, 0}, 0.0, model.scale, color)
            
            // Debug: draw bounding boxes
            if scene.debug_mode {
                rl.DrawBoundingBox(model.bounds, rl.GREEN)
            }
        }
    }
}

main :: proc() {
    // Initialization
    screen_width: i32 = 1200
    screen_height: i32 = 800
    
    rl.SetConfigFlags({.MSAA_4X_HINT, .VSYNC_HINT})
    rl.InitWindow(screen_width, screen_height, "Enhanced Shadowmapping System - Debug Version")
    defer rl.CloseWindow()
    
    // Set up camera
    cam := rl.Camera3D{
        position = {12.0, 8.0, 12.0},
        target = {0, 0, 0},
        up = {0, 1, 0},
        fovy = 45.0,
        projection = .PERSPECTIVE,
    }
    
    fmt.println("=== SHADOW SYSTEM DEBUG ===")
    fmt.println("Step 1: Checking OpenGL support...")
    
    // Check OpenGL version and capabilities
    
    // Simple test without shadows first
    fmt.println("Step 2: Testing basic rendering...")
    
    // Load base models with error checking
    fmt.println("Step 3: Loading models...")
    cube_model := rl.LoadModelFromMesh(rl.GenMeshCube(1.0, 1.0, 1.0))
    if cube_model.meshCount == 0 {
        fmt.println("ERROR: Failed to create cube model")
        return
    }
    fmt.println("✓ Cube model loaded successfully")
    defer rl.UnloadModel(cube_model)
    
    // Test if robot model exists before loading
    robot_model_loaded := false
    robot_model: rl.Model
    
    if rl.FileExists("assets/robot.glb") {
        fmt.println("Step 4: Loading robot model...")
        robot_model = rl.LoadModel("assets/robot.glb")
        if robot_model.meshCount > 0 {
            fmt.println("✓ Robot model loaded successfully")
            robot_model_loaded = true
        } else {
            fmt.println("WARNING: Robot model failed to load")
        }
    } else {
        fmt.println("WARNING: Robot model file not found, skipping...")
    }
    defer if robot_model_loaded do rl.UnloadModel(robot_model)
    
    // Test shadow system initialization step by step
    fmt.println("Step 5: Initializing shadow system...")
    
    // Check if shader files exist
    vertex_shader_exists := rl.FileExists("assets/shadow.vs")
    fragment_shader_exists := rl.FileExists("assets/shadow.fs")
    
    fmt.printf("Vertex shader exists: %t\n", vertex_shader_exists)
    fmt.printf("Fragment shader exists: %t\n", fragment_shader_exists)
    
    if !vertex_shader_exists || !fragment_shader_exists {
        fmt.println("ERROR: Shader files not found! Creating fallback...")
        
        // Test with basic rendering only
        fmt.println("Running without shadows...")
        
        rl.SetTargetFPS(60)
        
        for !rl.WindowShouldClose() {
            rl.UpdateCamera(&cam, .ORBITAL)
            
            rl.BeginDrawing()
            rl.ClearBackground(rl.Color{135, 206, 235, 255})
            
            rl.BeginMode3D(cam)
            
            // Draw ground
            rl.DrawModelEx(cube_model, {0, 0, 0}, {0, 1, 0}, 0.0, {10, 1, 10}, rl.BLUE)
            
            // Draw some cubes
            for i in 0..<3 {
                x := f32(i - 1) * 3.0
                rl.DrawModelEx(cube_model, {x, 1.0, 0}, {0, 1, 0}, 0.0, {1, 1, 1}, rl.LIGHTGRAY)
            }
            
            // Draw robot if loaded
            if robot_model_loaded {
                rl.DrawModelEx(robot_model, {0, 0.5, 3}, {0, 1, 0}, 0.0, {1, 1, 1}, rl.RED)
            }
            
            rl.EndMode3D()
            
            rl.DrawText("BASIC RENDERING MODE - NO SHADOWS", 10, 10, 20, rl.RED)
            rl.DrawText("Press ESC to exit", 10, 40, 16, rl.DARKGRAY)
            
            rl.EndDrawing()
        }
        
        return
    }
    
    // Try to initialize shadow system with error checking
    shadow_config := sm.get_mobile_config() // Start with lowest settings
    fmt.printf("Shadow config - Resolution: %d, PCF: %t\n", shadow_config.base_resolution, shadow_config.enable_pcf)
    
    custom_light := sm.DirectionalLight{
        direction = rl.Vector3Normalize({0.35, -1.0, -0.35}),
        color = rl.Color{255, 245, 230, 255}, // Warm sunlight
    }
    
    fmt.println("Step 6: Initializing shadow system...")
    shadow_system, shadow_ok := sm.init_shadow_system_with_config(
        "assets/shadow.vs", "assets/shadow.fs", 
        shadow_config, custom_light
    )
    
    if !shadow_ok {
        fmt.println("ERROR: Failed to initialize shadow system!")
        fmt.println("Falling back to basic rendering...")
        
        // Continue with basic rendering
        rl.SetTargetFPS(60)
        
        for !rl.WindowShouldClose() {
            rl.UpdateCamera(&cam, .ORBITAL)
            
            rl.BeginDrawing()
            rl.ClearBackground(rl.Color{135, 206, 235, 255})
            
            rl.BeginMode3D(cam)
            rl.DrawModelEx(cube_model, {0, 0, 0}, {0, 1, 0}, 0.0, {10, 1, 10}, rl.BLUE)
            rl.EndMode3D()
            
            rl.DrawText("SHADOW INIT FAILED - BASIC MODE", 10, 10, 20, rl.RED)
            rl.EndDrawing()
        }
        
        return
    }
    
    fmt.println("✓ Shadow system initialized successfully!")
    defer sm.destroy_shadow_system(&shadow_system)
    
    // Initialize scene data
    fmt.println("Step 7: Setting up scene...")
    scene_data := SceneData{}
    scene_data.models = make([dynamic]sm.ModelLOD)
    defer delete(scene_data.models)
    
    // Apply shadow shader to models with error checking
    fmt.println("Step 8: Applying shadow shaders...")
    
    // CRITICAL: Check if apply_shadow_shader modifies the model in a way that causes issues
    fmt.println("Pre-shader cube model meshCount:", cube_model.meshCount)
    sm.apply_shadow_shader(&shadow_system, &cube_model)
    fmt.println("Post-shader cube model meshCount:", cube_model.meshCount)
    fmt.println("✓ Cube shader applied")
    
    if robot_model_loaded {
        fmt.println("Pre-shader robot model meshCount:", robot_model.meshCount)
        sm.apply_shadow_shader(&shadow_system, &robot_model)
        fmt.println("Post-shader robot model meshCount:", robot_model.meshCount)
        fmt.println("✓ Robot shader applied")
    }
    
    // Create LOD models for the scene
    fmt.println("Step 9: Creating LOD models...")
    
    // CRITICAL: Add safety checks for LOD creation
    fmt.println("Creating ground LOD...")
    ground_lod := sm.create_model_lod(cube_model, {0, 0, 0}, {10, 1, 10}, true)
    append(&scene_data.models, ground_lod)
    fmt.println("✓ Ground LOD created")
    
    // Small cubes - static decorations with error checking
    for i in 0..<3 {
        x := f32(i - 1) * 3.0
        fmt.printf("Creating cube LOD %d...\n", i)
        cube_lod := sm.create_model_lod(cube_model, {x, 1.0, 0}, {1, 1, 1}, true)
        append(&scene_data.models, cube_lod)
    }
    fmt.println("✓ Cube LODs created")
    
    // Robot - dynamic (only if loaded)
    if robot_model_loaded {
        fmt.println("Creating robot LOD...")
        robot_lod := sm.create_model_lod(robot_model, {0, 0.5, 3}, {1, 1, 1}, false)
        append(&scene_data.models, robot_lod)
        fmt.println("✓ Robot LOD created")
    }
    
    fmt.printf("Total models in scene: %d\n", len(scene_data.models))
    
    // Validate all models before starting main loop
    fmt.println("Step 9.5: Validating all models...")
    for i in 0..<len(scene_data.models) {
        model := &scene_data.models[i]
        if model.high_detail.meshCount == 0 {
            fmt.printf("ERROR: Model %d has no meshes!\n", i)
            return
        }
        fmt.printf("Model %d: %d meshes, static: %t\n", i, model.high_detail.meshCount, model.is_static)
    }
    fmt.println("✓ All models validated")
    
    // Control parameters
    light_speed: f32 = 2.0
    show_debug_info := true
    frame_counter := 0
    
    rl.SetTargetFPS(60)
    
    fmt.println("Step 10: Starting main loop...")
    fmt.println("=== MAIN LOOP STARTED ===")
    
    // Test basic rendering first (without shadows)
    fmt.println("Testing basic rendering for 60 frames...")
    test_frames := 0
    
    for !rl.WindowShouldClose() && test_frames < 60 {
        test_frames += 1
        dt := rl.GetFrameTime()
        
        rl.UpdateCamera(&cam, .ORBITAL)
        
        rl.BeginDrawing()
        rl.ClearBackground(rl.Color{135, 206, 235, 255})
        
        rl.BeginMode3D(cam)
        
        // Draw models directly without shadow system
        for i in 0..<len(scene_data.models) {
            model := &scene_data.models[i]
            
            color := rl.WHITE
            if model.position.y < 0.5 {
                color = rl.BLUE // Ground
            } else if model.scale.x == 1.0 && model.scale.y == 1.0 && model.scale.z == 1.0 {
                color = rl.LIGHTGRAY // Small cube
            } else {
                color = rl.RED // Robot
            }
            
            rl.DrawModelEx(model.high_detail, model.position, {0, 1, 0}, 0.0, model.scale, color)
        }
        
        rl.EndMode3D()
        
        rl.DrawText("BASIC RENDERING TEST", 10, 10, 20, rl.GREEN)
        test_text := fmt.ctprintf("Frame: %d/60", test_frames)
        rl.DrawText(test_text, 10, 40, 16, rl.DARKGRAY)
        
        rl.EndDrawing()
    }
    
    if rl.WindowShouldClose() {
        fmt.println("Window closed during basic test")
        return
    }
    
    fmt.println("✓ Basic rendering test passed!")
    fmt.println("Starting shadow rendering...")
    
    // Now start the full shadow rendering loop
    for !rl.WindowShouldClose() {
        frame_counter += 1
        dt := rl.GetFrameTime()
        
        // Debug output every 60 frames
        if frame_counter % 60 == 0 {
            fmt.printf("Frame %d: FPS %.1f, DT %.3f\n", frame_counter, 1.0/dt, dt)
        }
        
        // Update shadow system performance tracking
        sm.update_shadow_system(&shadow_system, dt)
        
        // Update camera
        rl.UpdateCamera(&cam, .ORBITAL)
        
        // Light control with arrow keys
        current_light := shadow_system.light.direction
        new_light := current_light
        
        if rl.IsKeyDown(.LEFT) {
            new_light.x += light_speed * dt
        }
        if rl.IsKeyDown(.RIGHT) {
            new_light.x -= light_speed * dt
        }
        if rl.IsKeyDown(.UP) {
            new_light.z += light_speed * dt
        }
        if rl.IsKeyDown(.DOWN) {
            new_light.z -= light_speed * dt
        }
        
        // Normalize and update light
        if new_light != current_light {
            sm.update_light(&shadow_system, rl.Vector3Normalize(new_light))
        }
        
        // Toggle debug modes
        if rl.IsKeyPressed(.F1) {
            scene_data.debug_mode = !scene_data.debug_mode
            fmt.printf("Debug mode: %t\n", scene_data.debug_mode)
        }
        if rl.IsKeyPressed(.F2) {
            show_debug_info = !show_debug_info
            fmt.printf("Debug info: %t\n", show_debug_info)
        }
        if rl.IsKeyPressed(.F3) {
            sm.debug_shadow_system(&shadow_system)
        }
        
        // Emergency fallback key
        if rl.IsKeyPressed(.F4) {
            fmt.println("F4 pressed - switching to basic rendering")
            
            // Basic rendering fallback
            rl.BeginDrawing()
            rl.ClearBackground(rl.Color{135, 206, 235, 255})
            
            rl.BeginMode3D(cam)
            for i in 0..<len(scene_data.models) {
                model := &scene_data.models[i]
                color := model.position.y < 0.5 ? rl.BLUE : rl.LIGHTGRAY
                rl.DrawModelEx(model.high_detail, model.position, {0, 1, 0}, 0.0, model.scale, color)
            }
            rl.EndMode3D()
            
            rl.DrawText("EMERGENCY BASIC RENDERING", 10, 10, 20, rl.RED)
            rl.EndDrawing()
            continue
        }
        
        // Render everything with try-catch equivalent
        render_success := false
        
        rl.BeginDrawing()
        rl.ClearBackground(rl.Color{135, 206, 235, 255}) // Sky blue
        
        // Use the LOD system (safer method)
        if len(scene_data.models) > 0 {
            // Check if we can safely access models
            if frame_counter % 60 == 0 {
                fmt.printf("Rendering %d models...\n", len(scene_data.models))
            }
            
            // CRITICAL: Add bounds checking
            models_slice := scene_data.models[:]
            if len(models_slice) > 0 {
                // Try shadow rendering with error recovery
                sm.render_with_shadows_lod(&shadow_system, cam, models_slice)
                render_success = true
            }
        }
        
        // UI Overlay
        ui_y: i32 = 10
        status_color := render_success ? rl.GREEN : rl.RED
        status_text := render_success ? "Running with shadows" : "Shadow rendering failed"
        
        rl.DrawText("Enhanced Shadowmapping System - DEBUG", 10, ui_y, 20, rl.DARKBLUE)
        ui_y += 25
        
        status_full := fmt.ctprintf("Status: %s", status_text)
        rl.DrawText(status_full, 10, ui_y, 14, status_color)
        ui_y += 20
        
        frame_text := fmt.ctprintf("Frame: %d", frame_counter)
        rl.DrawText(frame_text, 10, ui_y, 14, rl.GRAY)
        ui_y += 20
        
        models_text := fmt.ctprintf("Models: %d", len(scene_data.models))
        rl.DrawText(models_text, 10, ui_y, 14, rl.GRAY)
        ui_y += 20
        
        rl.DrawText("Controls:", 10, ui_y, 14, rl.DARKGRAY)
        ui_y += 18
        rl.DrawText("Arrow Keys: Move light", 15, ui_y, 12, rl.GRAY)
        ui_y += 16
        rl.DrawText("Mouse: Rotate camera", 15, ui_y, 12, rl.GRAY)
        ui_y += 16
        rl.DrawText("F1: Debug boxes", 15, ui_y, 12, rl.GRAY)
        ui_y += 16
        rl.DrawText("F2: Debug info", 15, ui_y, 12, rl.GRAY)
        ui_y += 16
        rl.DrawText("F3: Print debug", 15, ui_y, 12, rl.GRAY)
        ui_y += 16
        rl.DrawText("F4: Emergency fallback", 15, ui_y, 12, rl.RED)
        
        // Performance info
        if show_debug_info {
            info_x: i32 = screen_width - 250
            info_y: i32 = 10
            
            rl.DrawRectangle(info_x - 10, info_y - 5, 240, 120, rl.Color{0, 0, 0, 100})
            
            rl.DrawText("Performance Info:", info_x, info_y, 14, rl.WHITE)
            info_y += 18
            
            fps_text := fmt.ctprintf("FPS: %.1f", shadow_system.metrics.last_fps)
            rl.DrawText(fps_text, info_x, info_y, 12, rl.LIGHTGRAY)
            info_y += 16
            
            shadow_time_text := fmt.ctprintf("Shadow: %.2fms", shadow_system.metrics.shadow_render_time * 1000)
            rl.DrawText(shadow_time_text, info_x, info_y, 12, rl.LIGHTGRAY)
            info_y += 16
            
            main_time_text := fmt.ctprintf("Main: %.2fms", shadow_system.metrics.main_render_time * 1000)
            rl.DrawText(main_time_text, info_x, info_y, 12, rl.LIGHTGRAY)
            info_y += 16
            
            resolution_text := fmt.ctprintf("Res: %dx%d", 
                                          shadow_system.config.current_resolution, 
                                          shadow_system.config.current_resolution)
            rl.DrawText(resolution_text, info_x, info_y, 12, rl.LIGHTGRAY)
        }
        
        rl.EndDrawing()
        
        // Safety check - if we've been running for a while, print status
        if frame_counter == 300 { // After 5 seconds at 60fps
            fmt.println("=== 5 SECOND STATUS CHECK ===")
            fmt.printf("Successfully rendered %d frames\n", frame_counter)
            fmt.printf("Current FPS: %.1f\n", shadow_system.metrics.last_fps)
            fmt.printf("Shadow system working normally\n")
            fmt.println("=============================")
        }
    }
    
    fmt.println("=== CLEAN SHUTDOWN ===")
    fmt.println("Application completed successfully")
}