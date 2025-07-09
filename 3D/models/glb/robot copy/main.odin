package main

import "core:math"
import "core:math/linalg"
import rl "vendor:raylib"

State :: struct {
	position:        rl.Vector3,
	rotation:        f32, // Current rotation
	target_rotation: f32, // Desired rotation
	velocity:        rl.Vector3,
	move_speed:      f32,
	run_speed_mult:  f32, // Multiplier for running speed
	turn_speed:      f32,
}

// This array helps us remember the animation names and their indices.
// It is paired with the `KeyAction` struct below.
Animations :: [14]string{
	"Robot_Dance",    // 0
	"Robot_Punch",      // 1
	"Robot_Wave",     // 2
	"Robot_WalkJump", // 3
	"Robot_Walking",  // 4
	"Robot_ThumbsUp", // 5
	"Robot_Standing", // 6
	"Robot_Sitting",  // 7
	"Robot_Running",  // 8
	"Robot_Yes",    // 9
	"Robot_No",       // 10
	"Robot_Jump",     // 11
	"Robot_Idle",     // 12
	"Robot_Death",    // 13
}

// Helper struct to map keyboard keys to one-shot animation indices
KeyAction :: struct {
	key:          rl.KeyboardKey,
	action_index: i32,
}

main :: proc() {
	rl.InitWindow(1024, 768, "3D Model Animation Example")
	defer rl.CloseWindow()

	// Initialize state
	state := State{
		position        = {0, 0, 0},
		rotation        = 0,
		target_rotation = 0,
		velocity        = {0, 0, 0},
		move_speed      = 0.08,
		run_speed_mult  = 2.0,
		turn_speed      = 5,
	}

	// Load model and animations
	model := rl.LoadModel("assets/robot.glb")
	defer rl.UnloadModel(model)

	anim_count: i32
	animations := rl.LoadModelAnimations("assets/robot.glb", &anim_count)
	defer rl.UnloadModelAnimations(animations, anim_count)

	// --- Animation State Variables ---
	anim_frame: i32 = 0
	is_moving := false
	is_running := false
	is_sitting := false
	current_action: i32 = -1 // Index for the current one-shot action, -1 for none

	// Map keys to their one-shot animation index from the Animations array
	one_shot_actions := [?]KeyAction{
		{.X, 0},     // Dance
		{.ENTER, 1}, // Yes
		{.R, 2},     // Wave
		{.V, 3},     // WalkJump
		{.Y, 5},     // ThumbsUp
		{.THREE, 9}, // Punch
		{.N, 10},    // No
		{.SPACE, 11},// Jump
		{.SEVEN, 13},// Death
	}

	// Setup camera
	camera_distance := f32(8)
	camera_height := f32(4)
	camera := rl.Camera{
		position   = {0, camera_height, -camera_distance},
		target     = {0, 2, 0},
		up         = {0, 1, 0},
		fovy       = 45,
		projection = .PERSPECTIVE,
	}

	rl.SetTargetFPS(60)

	for !rl.WindowShouldClose() {
		// --- Input Handling ---
		move_dir := rl.Vector3{0, 0, 0}

		// Check for one-shot actions
		for action in one_shot_actions {
			if rl.IsKeyPressed(action.key) {
				current_action = action.action_index
				anim_frame = 0 // Reset animation
				is_sitting = false // Stand up to perform an action
			}
		}

		// Check for sitting toggle
		if rl.IsKeyPressed(.DOWN) {
			is_sitting = !is_sitting
			current_action = -1 // Cancel any other action
			anim_frame = 0
		}

		// Movement input
		if rl.IsKeyDown(.W) do move_dir.z = 1
		if rl.IsKeyDown(.S) do move_dir.z = -1
		if rl.IsKeyDown(.A) do move_dir.x = -1
		if rl.IsKeyDown(.D) do move_dir.x = 1

		is_moving = move_dir.x != 0 || move_dir.z != 0
		is_running = is_moving && rl.IsKeyDown(.LEFT_SHIFT)
		
		// Moving cancels sitting
		if is_moving do is_sitting = false


		// --- State Updates ---
		if is_moving {
			length := math.sqrt(move_dir.x*move_dir.x + move_dir.z*move_dir.z)
			move_dir.x /= length
			move_dir.z /= length

			state.target_rotation = math.atan2(move_dir.x, move_dir.z) * rl.RAD2DEG

			current_move_speed := state.move_speed
			if is_running do current_move_speed *= state.run_speed_mult

			state.velocity.x = move_dir.x * current_move_speed
			state.velocity.z = move_dir.z * current_move_speed
		} else {
			state.velocity = {0, 0, 0}
		}

		// Smooth rotation
		if state.rotation != state.target_rotation {
			diff := state.target_rotation - state.rotation
			if diff > 180 do diff -= 360
			if diff < -180 do diff += 360
			if abs(diff) < state.turn_speed {
				state.rotation = state.target_rotation
			} else {
				state.rotation += math.sign(diff) * state.turn_speed
			}
			state.rotation = linalg.mod(state.rotation + 360, 360)
		}

		// Update position (only if not sitting)
		if !is_sitting {
			state.position.x += state.velocity.x
			state.position.z += state.velocity.z
		}

		// --- Animation Logic ---
		if anim_count > 0 {
			current_anim: rl.ModelAnimation
			
			// Priority 1: One-shot actions
			if current_action != -1 {
				current_anim = animations[current_action]
			// Priority 2: Sustained states (sitting)
			} else if is_sitting {
				current_anim = animations[7] // Robot_Sitting
			// Priority 3: Locomotion (running/walking)
			} else if is_running {
				current_anim = animations[8] // Robot_Running
			} else if is_moving {
				current_anim = animations[4] // Robot_Walking
			// Priority 4: Default state
			} else {
				current_anim = animations[12] // Robot_Idle
			}

			// Update and loop/reset animation
			anim_frame += 1
			rl.UpdateModelAnimation(model, current_anim, anim_frame)
			
			if anim_frame >= current_anim.frameCount {
				anim_frame = 0
				// If a one-shot action finished, reset to no action
				if current_action != -1 {
					current_action = -1
				}
			}
		}

		// --- Camera and Model Transform ---
		model.transform = rl.MatrixRotateY(state.rotation * rl.DEG2RAD)
		angle := state.rotation * rl.DEG2RAD
		camera.position = {
			state.position.x - math.sin(angle) * camera_distance,
			state.position.y + camera_height,
			state.position.z - math.cos(angle) * camera_distance,
		}
		camera.target = {state.position.x, state.position.y + 2, state.position.z}

		// --- Render ---
		rl.BeginDrawing()
		rl.ClearBackground(rl.RAYWHITE)
		rl.BeginMode3D(camera)
			rl.DrawModel(model, state.position, 1, rl.WHITE)
			rl.DrawGrid(20, 1)
		rl.EndMode3D()

		rl.DrawText("ROBOT CONTROLS", 10, 10, 20, rl.DARKGRAY)
		rl.DrawText("- WASD to Move, L-Shift to Run", 10, 40, 20, rl.LIME)
		rl.DrawText("- Down Arrow to Sit/Stand", 10, 65, 20, rl.LIME)
		rl.DrawText("- [SPACE] Jump", 10, 90, 20, rl.SKYBLUE)
		rl.DrawText("- [R] Wave, [Y] Thumbs Up", 10, 115, 20, rl.SKYBLUE)
		rl.DrawText("- [X] Dance, [3] Punch", 10, 140, 20, rl.SKYBLUE)
		rl.DrawText("- [Enter] Yes, [N] No", 10, 165, 20, rl.SKYBLUE)

		rl.EndDrawing()
	}
}