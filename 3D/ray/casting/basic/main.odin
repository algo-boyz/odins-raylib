package main

import "core:fmt"
import "core:math"

import rl "vendor:raylib"

WINDOW_WIDTH :: 1280
WINDOW_HEIGHT :: 720
RAY_LENGTH :: 1200
WALL_THICKNESS :: 10
DEBUG :: false

ray :: struct {
	start:  rl.Vector2,
	dir:    rl.Vector2,
	length: f32,
}

wall :: struct {
	start: rl.Vector2,
	end:   rl.Vector2,
}

walls: [dynamic]wall
rays: [dynamic]ray
verticies: [dynamic]rl.Vector2
triangles: [dynamic]i32
light_texture: rl.Texture2D
mask: rl.RenderTexture2D
screen: rl.RenderTexture2D
shader: rl.Shader

main :: proc() {
	rl.SetConfigFlags({.MSAA_4X_HINT, .VSYNC_HINT})
	rl.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "Odin Raylib Template")
	rl.DisableCursor()

	shader = rl.LoadShader("", "assets/shaders/screenspacemask.fs")
	defer rl.UnloadShader(shader)

	screen = rl.LoadRenderTexture(WINDOW_WIDTH, WINDOW_HEIGHT)
	defer rl.UnloadRenderTexture(screen)

	mask = rl.LoadRenderTexture(WINDOW_WIDTH, WINDOW_HEIGHT)
	defer rl.UnloadRenderTexture(mask)

	light_texture = rl.LoadTexture("assets/textures/light-01.png")
	defer rl.UnloadTexture(light_texture)

	screen_texture_location := rl.GetShaderLocation(shader, "texture0")
	mask_texture_location := rl.GetShaderLocation(shader, "texture1")

	initialize_level()

	for (!rl.WindowShouldClose()) {
		clear(&rays)
		clear(&verticies)
		clear(&triangles)

		center := rl.GetMousePosition()
		cast_rays(center)

		// render game screen to render texture
		rl.BeginTextureMode(screen)
		rl.ClearBackground(rl.BLACK)

		// draw walls
		for w in walls {
			rl.DrawLineEx(w.start, w.end, WALL_THICKNESS, rl.BLUE)
		}

		// draw light sprite
		rl.DrawTexturePro(
			light_texture,
			{0, 0, f32(light_texture.width), f32(light_texture.height)},
			{center.x, center.y, 1024 * 2, 1024 * 2},
			{f32(light_texture.width), f32(light_texture.height)},
			0,
			rl.Fade(rl.RED, 0.75),
		)

		rl.EndTextureMode()

		// draw mask render texture
		rl.BeginTextureMode(mask)
		rl.ClearBackground(rl.BLACK)

		for i := 0; i < len(triangles); i += 3 {
			a := triangles[i] // center
			b := triangles[i + 1] // first edge
			c := triangles[i + 2] // second edge
			rl.DrawTriangle(verticies[a], verticies[b], verticies[c], rl.WHITE)
		}

		rl.EndTextureMode()

		// draw final render texture to the screen with screen + mask applied.
		rl.BeginDrawing()
		rl.ClearBackground(rl.BLACK)

		rl.BeginShaderMode(shader)

		rl.SetShaderValueTexture(shader, screen_texture_location, screen.texture)
		rl.SetShaderValueTexture(shader, mask_texture_location, mask.texture)

		rl.DrawTextureRec(
			screen.texture,
			{0, 0, f32(screen.texture.width), f32(-screen.texture.height)},
			{0, 0},
			rl.WHITE,
		)

		rl.EndShaderMode()

		fps := fmt.ctprintf("FPS: %v", i32(1.0 / rl.GetFrameTime()))
		rl.DrawText(fps, 20, 20, 20, rl.WHITE)

		if DEBUG {debug_walls()}

		rl.EndDrawing()
	}

	initialize_level :: proc() {
		append(
			&walls,
			wall{start = {0, 0}, end = {WINDOW_WIDTH, 0}},
			wall{start = {WINDOW_WIDTH, 0}, end = {WINDOW_WIDTH, WINDOW_HEIGHT}},
			wall{start = {WINDOW_WIDTH, WINDOW_HEIGHT}, end = {0, WINDOW_HEIGHT}},
			wall{start = {0, WINDOW_HEIGHT}, end = {0, 0}},
			wall{start = {400, 100}, end = {600, 100}},
			wall{start = {600, 100}, end = {600, 300}},
			wall{start = {600, 300}, end = {400, 300}},
			wall{start = {400, 300}, end = {400, 100}},
			wall{start = {800, 500}, end = {800, 600}},
			wall{start = {800, 500}, end = {1000, 500}},
			wall{start = {1000, 500}, end = {1000, 300}},
			wall{start = {200, 500}, end = {600, 500}},
			wall{start = {600, 500}, end = {600, 600}},
		)
	}

	cast_rays :: proc(center_point: rl.Vector2) {
		append(&verticies, center_point)

		// cast rays in a circle around center
		for i := 0; i < 360; i += 1 {
			ray: ray = {
				start  = center_point,
				dir    = angle_to_direction(f32(i)),
				length = RAY_LENGTH,
			}

			append(&rays, ray)
		}

		// check for wall collisions with rays
		for ray in rays {
			closest_collision_point: rl.Vector2
			found_collision: bool = false
			min_distance: f32 = ray.length

			for w in walls {
				collision_point: rl.Vector2

				if rl.CheckCollisionLines(
					ray.start,
					ray.start + ray.dir * ray.length,
					w.start,
					w.end,
					&collision_point,
				) {
					distance := rl.Vector2Distance(ray.start, collision_point)

					// find collision with the wall closest to the center of the ray
					if distance < min_distance {
						closest_collision_point = collision_point
						min_distance = distance
						found_collision = true
					}
				}
			}

			// draw ray until hit collision
			if found_collision {
				append(&verticies, closest_collision_point)
			} else { 	// otherwise, draw ray at full length
				append(&verticies, ray.start + ray.dir * ray.length)
			}
		}

		// set up triangles
		for i := 0; i < len(verticies) - 2; i += 1 {
			a := i32(0)
			b := i32(i + 2)
			c := i32(i + 1)
			append(&triangles, a, b, c)
		}

		// create last triangle to close the loop
		append(&triangles, i32(0), i32(1), i32(len(verticies) - 1))
	}

	angle_to_direction :: proc(angle_in_deg: f32) -> rl.Vector2 {
		angle_in_rad := math.to_radians_f32(angle_in_deg)
		return rl.Vector2{math.cos(angle_in_rad), math.sin(angle_in_rad)}
	}

	debug_walls :: proc() {
		for w in walls {
			rl.DrawCircleV(w.start, 5.0, rl.RED)
			rl.DrawCircleV(w.end, 5.0, rl.RED)

			startPos := fmt.ctprintf("x: %v, y: %v", i32(w.start.x), i32(w.start.y))
			rl.DrawText(startPos, i32(w.start.x), i32(w.start.y), 10.0, rl.WHITE)

			endPos := fmt.ctprintf("x: %v, y: %v", i32(w.end.x), i32(w.end.y))
			rl.DrawText(endPos, i32(w.end.x), i32(w.end.y), 10.0, rl.WHITE)
		}
	}
}
