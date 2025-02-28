package rlutil

import rl "vendor:raylib"

cam2D_follow :: proc(cam: ^rl.Camera2D, target_x, target_y: f32) {
	cam.target = rl.Vector2{target_x, target_y}
}

cam2D_follow_lerp :: proc(
	cam: ^rl.Camera2D,
	target_x, target_y, lerp_amount: f32,
) {
	desired_target := rl.Vector2 {
		target_x - (f32(rl.GetScreenWidth()) / 2) / cam.zoom,
		target_y - (f32(rl.GetScreenHeight()) / f32(1.5)) / cam.zoom,
	}

	cam.target.x += (desired_target.x - cam.target.x) * lerp_amount
	cam.target.y += (desired_target.y - cam.target.y) * lerp_amount
}

clamp_cam2D :: proc(cam: ^rl.Camera2D, world_width, world_height: f32) {
	half_screen_width := (f32(rl.GetScreenWidth()) / 2) / cam.zoom
	half_screen_height := (f32(rl.GetScreenHeight()) / 2) / cam.zoom

	cam.target.x = max(
		half_screen_width,
		min(cam.target.x, world_width - half_screen_width),
	)
	cam.target.y = max(
		half_screen_height,
		min(cam.target.y, world_height - half_screen_height),
	)
}

clamp_cam2D_target :: proc(
	cam: ^rl.Camera2D,
	target_x, target_y, world_width, world_height: f32,
) {
	half_screen_width := (f32(rl.GetScreenWidth()) / (2 * cam.zoom))
	half_screen_height := (f32(rl.GetScreenHeight()) / (2 * cam.zoom))

	cam.target.x = max(
		half_screen_width,
		min(target_x, world_width - half_screen_width),
	)
	cam.target.y = max(
		half_screen_height,
		min(target_y, world_height - half_screen_height),
	)
}