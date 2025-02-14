package main

import "core:math"
import rl "vendor:raylib"

State :: struct {
    position: rl.Vector3,
    rotation: f32,  // Current rotation
    target_rotation: f32,  // Desired rotation
    velocity: rl.Vector3,
    move_speed: f32,
    turn_speed: f32,
}

main :: proc() {
    rl.InitWindow(800, 600, "3D Model Example")
    defer rl.CloseWindow()

    // Initialize state
    state := State{
        position = {0, 0, 0},
        rotation = 0,
        target_rotation = 0,
        velocity = {0, 0, 0},
        move_speed = 0.1,
        turn_speed = 5,
    }

    // Load and setup model
    model := rl.LoadModel("assets/robot.glb")
    defer rl.UnloadModel(model)
    
    // Load animations
    anim_count: i32
    animations := rl.LoadModelAnimations("assets/robot.glb", &anim_count)
    defer rl.UnloadModelAnimations(animations, anim_count)
    
    anim_frame: i32 = 0
    is_moving := false

    // Setup camera with initial offset
    camera_distance := f32(6)  // Distance from character
    camera_height := f32(3)    // Height above character
    
    camera := rl.Camera{
        position = {0, camera_height, -camera_distance},  // Start behind character
        target = {0, 2, 0},
        up = {0, 1, 0},
        fovy = 45,
        projection = .PERSPECTIVE,
    }

    rl.SetTargetFPS(60)

    for !rl.WindowShouldClose() {
        move_dir := rl.Vector3{0, 0, 0}

        // Input handling
        if rl.IsKeyDown(.W) {
            move_dir = {0, 0, 1}
            is_moving = true
        } else if rl.IsKeyDown(.S) {
            move_dir = {0, 0, -1}
            is_moving = true
        } else {
            is_moving = false
        }

        if rl.IsKeyDown(.A) {
            move_dir.x -= 1
            is_moving = true
        }
        if rl.IsKeyDown(.D) {
            move_dir.x += 1
            is_moving = true
        }

        // Calculate movement and rotation
        if is_moving {
            // Normalize movement direction
            if move_dir.x != 0 || move_dir.z != 0 {
                length := math.sqrt(move_dir.x * move_dir.x + move_dir.z * move_dir.z)
                move_dir.x /= length
                move_dir.z /= length

                // Calculate target rotation based on movement direction
                state.target_rotation = math.atan2(move_dir.x, move_dir.z) * rl.RAD2DEG
            }

            // Apply velocity based on current rotation
            angle := state.rotation * rl.DEG2RAD
            state.velocity.x = move_dir.x * state.move_speed
            state.velocity.z = move_dir.z * state.move_speed
        } else {
            state.velocity = {0, 0, 0}
        }

        // Smoothly interpolate current rotation towards target rotation
        if state.rotation != state.target_rotation {
            // Calculate shortest rotation direction
            diff := state.target_rotation - state.rotation
            if diff > 180 do diff -= 360
            if diff < -180 do diff += 360

            // Apply smooth rotation
            if abs(diff) < state.turn_speed {
                state.rotation = state.target_rotation
            } else {
                state.rotation += math.sign(diff) * state.turn_speed
            }

            // Keep rotation in [0, 360) range
            if state.rotation >= 360 do state.rotation -= 360
            if state.rotation < 0 do state.rotation += 360
        }

        // Update position
        state.position.x += state.velocity.x
        state.position.z += state.velocity.z

        // Update animation if moving
        if is_moving && anim_count > 0 {
            rl.UpdateModelAnimation(model, animations[2], anim_frame)
            anim_frame += 1
            if anim_frame >= animations[0].frameCount do anim_frame = 0
        }

        // Update model transform
        model_matrix := rl.Matrix(1)
        model_matrix = model_matrix * rl.MatrixRotateY(state.rotation * rl.DEG2RAD)
        model_matrix *= rl.MatrixTranslate(state.position.x, state.position.y, state.position.z)
        model.transform = model_matrix

        // Update camera position to follow behind character
        angle := state.rotation * rl.DEG2RAD
        camera.position = {
            state.position.x - math.sin(angle) * camera_distance,
            camera_height,
            state.position.z - math.cos(angle) * camera_distance,
        }
        
        // Update camera target to look at character
        camera.target = {
            state.position.x,
            2,  // Look at model's center
            state.position.z,
        }

        // Render
        rl.BeginDrawing()
        rl.ClearBackground(rl.RAYWHITE)
        
        rl.BeginMode3D(camera)
            rl.DrawModel(model, state.position, 1, rl.WHITE)
            rl.DrawGrid(10, 1)
        rl.EndMode3D()

        rl.DrawText("Controls: WASD - Move", 10, 10, 20, rl.DARKGRAY)
        
        rl.EndDrawing()
    }
}