package main

import "core:math"
import rl "vendor:raylib"
import "rlight"

main :: proc() {
	rl.SetConfigFlags({rl.ConfigFlag.VSYNC_HINT, rl.ConfigFlag.BORDERLESS_WINDOWED_MODE})
	rl.InitWindow(1280, 720, "Orbiting Lights")
	camera := rl.Camera3D {
		position   = {10, 10, 10},
		target     = {},
		up         = {0, 1, 0},
		fovy       = 45.0,
		projection = rl.CameraProjection.PERSPECTIVE,
	}

	model := rl.LoadModelFromMesh(rl.GenMeshTorus(0.4, 5, 32, 64))
	defer rl.UnloadModel(model)

	shader := rl.LoadShader(
		"assets/light.vs",
		"assets/light.fs",
	)
	
	// Apply the shader to the model's material
	model.materials[0].shader = shader

	view_pos := rl.GetShaderLocation(shader, "viewPos")

	// Set Ambient light level
	ambient_light_loc: rl.Vector4 = {0.1, 0.1, 0.1, 1.0} // Reduced ambient for more dramatic lighting
	ambient_loc := rl.GetShaderLocation(shader, "ambient")
	rl.SetShaderValue(shader, ambient_loc, &ambient_light_loc, rl.ShaderUniformDataType.VEC4)

	// Create multiple orbiting lights
	lights := make([dynamic]rlight.Light)
	defer delete(lights)
	
	// Light toggle states
	light_enabled := [4]bool{true, true, true, true}
	
	// Light 1: Red light
	red_light := rlight.create_light(rlight.LightType.POINT, {8, 3, 0}, {0, 0, 0}, rl.RED, shader, 0)
	append(&lights, red_light)
	
	// Light 2: Blue light
	blue_light := rlight.create_light(rlight.LightType.POINT, {0, 3, 8}, {0, 0, 0}, rl.BLUE, shader, 1)
	append(&lights, blue_light)
	
	// Light 3: Green light
	green_light := rlight.create_light(rlight.LightType.POINT, {-8, 3, 0}, {0, 0, 0}, rl.GREEN, shader, 2)
	append(&lights, green_light)
	
	// Light 4: Yellow light orbiting at different height
	yellow_light := rlight.create_light(rlight.LightType.POINT, {0, 8, 0}, {0, 0, 0}, rl.YELLOW, shader, 3)
	append(&lights, yellow_light)

	rl.SetTargetFPS(120)
	
	time: f32 = 0

	for !rl.WindowShouldClose() {
		rl.BeginDrawing()
		rl.ClearBackground(rl.BLANK)

		dt := rl.GetFrameTime()
		time += dt

		// Handle light toggle input
		if rl.IsKeyPressed(rl.KeyboardKey.ONE) {
			light_enabled[0] = !light_enabled[0]
		}
		if rl.IsKeyPressed(rl.KeyboardKey.TWO) {
			light_enabled[1] = !light_enabled[1]
		}
		if rl.IsKeyPressed(rl.KeyboardKey.THREE) {
			light_enabled[2] = !light_enabled[2]
		}
		if rl.IsKeyPressed(rl.KeyboardKey.FOUR) {
			light_enabled[3] = !light_enabled[3]
		}

		// Rotate the torus
		model.transform = model.transform * rl.MatrixRotateX(1 * dt)

		// Update orbiting lights positions
		orbit_radius: f32 = 8
		orbit_height: f32 = 3
		
		// Light 1: Red - orbits horizontally
		lights[0].position = {
			orbit_radius * math.cos(time * 1.0),
			orbit_height,
			orbit_radius * math.sin(time * 1.0),
		}
		
		// Light 2: Blue - orbits horizontally, offset by 90 degrees
		lights[1].position = {
			orbit_radius * math.cos(time * 1.0 + math.PI/2),
			orbit_height,
			orbit_radius * math.sin(time * 1.0 + math.PI/2),
		}
		
		// Light 3: Green - orbits horizontally, offset by 180 degrees
		lights[2].position = {
			orbit_radius * math.cos(time * 1.0 + math.PI),
			orbit_height,
			orbit_radius * math.sin(time * 1.0 + math.PI),
		}
		
		// Light 4: Yellow - orbits vertically in a different plane, faster
		lights[3].position = {
			orbit_radius * 0.7 * math.sin(time * 1.5),
			orbit_height + 3 * math.cos(time * 1.5),
			orbit_radius * 0.7 * math.cos(time * 1.5),
		}

		// Update all light values in shader, but set disabled lights to black
		for light, i in lights {
			modified_light := light
			if !light_enabled[i] {
				// Set light color to black to effectively disable it
				modified_light.color = {0, 0, 0, 1}
			}
			rlight.update_light_values(shader, modified_light)
		}

		rl.SetShaderValue(shader, view_pos, &camera.position, rl.ShaderUniformDataType.VEC3)

		rl.BeginMode3D(camera)
		
		// Draw the main torus
		rl.DrawModel(model, rl.Vector3{}, 1.0, rl.WHITE) // Changed to white to show colored lighting better
		
		// Draw small spheres to visualize light positions (dimmed if disabled)
		for light, i in lights {
			if light_enabled[i] {
				light_color := rl.Color{u8(light.color.r * 255), u8(light.color.g * 255), u8(light.color.b * 255), 255}
				rl.DrawSphere(light.position, 0.2, light_color)
			} else {
				// Draw dimmed sphere for disabled lights
				light_color := rl.Color{u8(light.color.r * 50), u8(light.color.g * 50), u8(light.color.b * 50), 255}
				rl.DrawSphere(light.position, 0.15, light_color)
			}
		}
		
		rl.EndMode3D()

		rl.DrawFPS(10, 10)
		rl.DrawText("Let there be light..", 10, 40, 20, rl.WHITE)
		
		// Draw light toggle status
		y_offset: i32 = 70
		for i in 0..<4 {
			status_text := light_enabled[i] ? "ON" : "OFF"
			color := light_enabled[i] ? rl.GREEN : rl.RED
			text := rl.TextFormat("Light %d (%c): %s", i+1, '1'+i, status_text)
			rl.DrawText(text, 10, y_offset + i32(i * 25), 20, color)
		}
		rl.DrawText("Press 1-4 to toggle lights", 10, y_offset + 100, 16, rl.GRAY)
		
		rl.EndDrawing()
	}
	rl.CloseWindow()
}