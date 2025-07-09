package main

import rl "vendor:raylib"
import "core:fmt"
import "core:math/linalg"
import sm "shadow" // Your enhanced shadow package

// The SceneData struct now correctly holds a dynamic array of ModelLODs.
SceneData :: struct {
	models:      [dynamic]sm.ModelLOD,
	animations:  [^]rl.ModelAnimation,
	anim_count:  i32,
	frame_count: i32,
}

// Helper to update the light color uniform in the shader
update_light_color :: proc(system: ^sm.ShadowSystem, color: rl.Color) {
	system.light.color = color
	light_color_normalized := rl.ColorNormalize(system.light.color)
	rl.SetShaderValue(system.shader, system.light_col_loc, &light_color_normalized, .VEC4)
}

main :: proc() {
	// --- Initialization ---
	screen_width: i32 = 1280
	screen_height: i32 = 720

	rl.SetConfigFlags({.MSAA_4X_HINT, .VSYNC_HINT})
	rl.InitWindow(screen_width, screen_height, "Enhanced Shadowmapping Demo")
	defer rl.CloseWindow()

	// --- Camera Setup ---
	cam := rl.Camera3D{
		position   = {10.0, 10.0, 10.0},
		target     = {0, 0, 0},
		up         = {0, 1, 0},
		fovy       = 45.0,
		projection = .PERSPECTIVE,
	}

	// --- Shadow System Initialization ---
	// Using the outdoor preset for a more impressive initial scene
	outdoor_config := sm.get_outdoor_config()
	light := sm.DirectionalLight{
		direction = rl.Vector3Normalize({0.5, -1.0, -0.5}),
		color     = rl.WHITE,
	}

	shadow_system, shadow_ok := sm.init_shadow_system_with_config("assets/shadow.vs", "assets/shadow.fs", outdoor_config, light)
	if !shadow_ok {
		fmt.println("FATAL: Failed to initialize shadow system!")
		return
	}
	defer sm.destroy_shadow_system(&shadow_system)

	// --- Scene Setup ---
	scene_data := SceneData{}
	defer {
		for model in scene_data.models {
			// Unload high_detail model. Shadow caster is an alias and doesn't need separate unloading.
			rl.UnloadModel(model.high_detail)
		}
		delete(scene_data.models)
		// Unload animations if they were loaded
		if scene_data.animations != nil {
			rl.UnloadModelAnimations(scene_data.animations, scene_data.anim_count)
		}
	}


	// Load models and create ModelLODs
	cube_model := rl.LoadModelFromMesh(rl.GenMeshCube(1.0, 1.0, 1.0))
	robot_model := rl.LoadModel("assets/robot.glb")

	// Apply the shadow shader to all materials of the loaded models
	sm.apply_shadow_shader(&shadow_system, &cube_model)
	sm.apply_shadow_shader(&shadow_system, &robot_model)

	// Load robot animations
	scene_data.animations = rl.LoadModelAnimations("assets/robot.glb", &scene_data.anim_count)

	// Create a ground plane (static)
	ground := sm.create_model_lod(cube_model, {0, -1, 0}, {20, 0.5, 20}, true)
	append(&scene_data.models, ground)

	// Create the main robot (dynamic)
	robot := sm.create_model_lod(robot_model, {0, 0, 0}, {0.8, 0.8, 0.8}, false)
	append(&scene_data.models, robot)

	// Create some other cubes in the scene
	cube1 := sm.create_model_lod(cube_model, {-5, 0.5, 5}, {1, 1, 1}, true)
	append(&scene_data.models, cube1)
	cube2 := sm.create_model_lod(cube_model, {5, 1.5, -3}, {2, 3, 1}, true)
	append(&scene_data.models, cube2)
	cube3 := sm.create_model_lod(cube_model, {4, 0.5, 8}, {1, 1, 4}, true)
	append(&scene_data.models, cube3)


	rl.SetTargetFPS(144) // Set a high target to test dynamic quality scaling

	// --- Main Game Loop ---
	for !rl.WindowShouldClose() {
		dt := rl.GetFrameTime()

		// --- Update ---

		// Update shadow system (handles dynamic quality scaling, jitter, etc.)
		sm.update_shadow_system(&shadow_system, dt)

		// Update camera
		rl.UpdateCamera(&cam, .ORBITAL)

		// Update robot animation
		if scene_data.anim_count > 0 {
			scene_data.frame_count = (scene_data.frame_count + 1) % scene_data.animations[0].frameCount
			// The ModelLOD for the robot is at index 1 in our models array
			rl.UpdateModelAnimation(scene_data.models[1].high_detail, scene_data.animations[0], scene_data.frame_count)
		}

		// Control light direction with arrow keys
		light_speed: f32 = 0.5
		current_light_dir := shadow_system.light.direction
		target_light_dir := current_light_dir

		if rl.IsKeyDown(.LEFT)  { target_light_dir.x += light_speed * dt }
		if rl.IsKeyDown(.RIGHT) { target_light_dir.x -= light_speed * dt }
		if rl.IsKeyDown(.UP)    { target_light_dir.z += light_speed * dt }
		if rl.IsKeyDown(.DOWN)  { target_light_dir.z -= light_speed * dt }
        
		// Smoothly interpolate light direction for smoother shadow movement
		interp_factor := 1.0 - linalg.exp(-10.0 * dt) // Frame-rate independent damping
		interp_light_dir := linalg.lerp(current_light_dir, target_light_dir, interp_factor)
		sm.update_light(&shadow_system, interp_light_dir)

		// Change light color with number keys
		if rl.IsKeyPressed(.ONE)   { update_light_color(&shadow_system, rl.WHITE) }
		if rl.IsKeyPressed(.TWO)   { update_light_color(&shadow_system, rl.Color{255, 180, 180, 255}) } // Warm Light
		if rl.IsKeyPressed(.THREE) { update_light_color(&shadow_system, rl.Color{180, 200, 255, 255}) } // Cool Light
        
        // --- Render ---
		rl.BeginDrawing()
		rl.ClearBackground(rl.SKYBLUE)

		// The modern render call handles everything, including LODs for shadows
		sm.render_with_shadows_lod(&shadow_system, cam, scene_data.models[:])

		// --- UI ---
		rl.DrawFPS(10, 10)
		rl.DrawText("Enhanced Shadowmapping Demo", 10, 40, 20, rl.DARKGRAY)
		rl.DrawText("Arrow keys: Move light", 10, 65, 16, rl.GRAY)
		rl.DrawText("1/2/3: Change light color", 10, 85, 16, rl.GRAY)
		rl.DrawText("Mouse: Rotate camera", 10, 105, 16, rl.GRAY)

		// Show current light direction
		light_dir := shadow_system.light.direction
		light_text := fmt.ctprintf("Light Dir: (%.2f, %.2f, %.2f)", light_dir.x, light_dir.y, light_dir.z)
		rl.DrawText(light_text, 10, screen_height - 50, 16, rl.DARKGREEN)
        
        // Show current shadow resolution
        res_text := fmt.ctprintf("Shadow Res: %dpx (Quality: %.2f)", 
                                 shadow_system.config.current_resolution, 
                                 shadow_system.config.quality_level)
		rl.DrawText(res_text, 10, screen_height - 30, 16, rl.DARKGREEN)

		if rl.IsKeyPressed(.F) {
			rl.TakeScreenshot("shadowmap_demo.png")
            sm.save_shadow_map_debug(&shadow_system, "shadowmap_depth.png")
		}

		rl.EndDrawing()
	}
}