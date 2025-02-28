package blender

import "core:math"

import rl "vendor:raylib"
import rlgl "vendor:raylib/rlgl"

// based on: https://github.com/grplyler/raylib-blender-camera

BLENDER_GREY :: rl.Color{135, 136, 136, 255}
BLENDER_DARK_GREY :: rl.Color{58, 58, 58, 255}
BLENDER_WIRE :: rl.Color{78, 78, 78, 255}

Camera :: struct {
    camera: rl.Camera,
    previous_mouse_position: rl.Vector2,
    is_mouse_dragging: bool,
    zoom: f32,
    zoom_speed: f32,
    move_speed: f32,
    move_speed_fast: f32,
    move_speed_slow: f32,
    pan_speed: f32,
    rotation_speed: f32,
    free_fly_rotation_speed: f32,
    free_fly: bool,
    // pitch limits to prevent gimbal lock
    min_pitch: f32,
    max_pitch: f32,
    current_pitch: f32,
}

camera_init :: proc() -> Camera {
    return Camera{
        camera = rl.Camera{
            position = {10.0, 10.0, 10.0},
            target = {0.0, 0.0, 0.0},
            up = {0.0, 1.0, 0.0},
            fovy = 45.0,
            projection = rl.CameraProjection.PERSPECTIVE,
        },
        previous_mouse_position = {0, 0},
        is_mouse_dragging = false,
        move_speed = 0.2,
        move_speed_fast = 0.4,
        move_speed_slow = 0.1,
        free_fly_rotation_speed = 0.001,
        free_fly = true,
        rotation_speed = 0.005,  // Reduced for smoother trackpad control
        pan_speed = 0.005,      // Reduced for smoother trackpad control
        zoom_speed = 0.2,       // Adjusted for trackpad zoom
        min_pitch = -89.5 * math.PI / 180.0,  // Just shy of -90 degrees
        max_pitch = 89.5 * math.PI / 180.0,   // Just shy of 90 degrees
        current_pitch = 0.0,
    }
}

draw_grid_ex :: proc(slices: int, spacing: f32) {
    half_slices := slices / 2
    rlgl.Begin(rlgl.LINES)
    for i := -half_slices; i <= half_slices; i += 1 {
        if i == 0 {
            rlgl.Color3f(0.5, 0.5, 0.5)
            rlgl.Color3f(0.5, 0.5, 0.5)
            rlgl.Color3f(0.5, 0.5, 0.5)
            rlgl.Color3f(0.5, 0.5, 0.5)
        } else {
            rlgl.Color3f(0.3, 0.3, 0.3)
            rlgl.Color3f(0.3, 0.3, 0.3)
            rlgl.Color3f(0.3, 0.3, 0.3)
            rlgl.Color3f(0.3, 0.3, 0.3)
        }
        rlgl.Vertex3f(f32(i) * spacing, 0.0, f32(-half_slices) * spacing)
        rlgl.Vertex3f(f32(i) * spacing, 0.0, f32(half_slices) * spacing)
        rlgl.Vertex3f(f32(-half_slices) * spacing, 0.0, f32(i) * spacing)
        rlgl.Vertex3f(f32(half_slices) * spacing, 0.0, f32(i) * spacing)
    }
    rlgl.End()
}

camera_update :: proc(bcamera: ^Camera) {
    wheel_move := rl.GetMouseWheelMove()
    mouse_position := rl.GetMousePosition()
    mouse_delta := rl.Vector2{
        mouse_position.x - bcamera.previous_mouse_position.x,
        mouse_position.y - bcamera.previous_mouse_position.y,
    }
    
    middle_mouse_down := rl.IsMouseButtonDown(.MIDDLE)
    right_mouse_down := rl.IsMouseButtonDown(.RIGHT)
    is_dragging := middle_mouse_down || right_mouse_down
    left_shift_down := rl.IsKeyDown(.LEFT_SHIFT)
    
    if rl.IsKeyPressed(.F) && left_shift_down {
        bcamera.free_fly = !bcamera.free_fly
    }

    if !bcamera.free_fly {
        direction := rl.Vector3Normalize(bcamera.camera.target - bcamera.camera.position)
        
        if wheel_move != 0 {
            zoom_delta := direction * (wheel_move * bcamera.zoom_speed)
            bcamera.camera.position += zoom_delta
        }

        if is_dragging {
            if left_shift_down {
                right := rl.Vector3Normalize(rl.Vector3CrossProduct(direction, bcamera.camera.up))
                up := rl.Vector3Normalize(rl.Vector3CrossProduct(right, direction))
                pan := right * (mouse_delta.x * bcamera.pan_speed) + 
                       up * (-mouse_delta.y * bcamera.pan_speed)
                bcamera.camera.position += pan
                bcamera.camera.target += pan
            } else {
                orbit_radius := rl.Vector3Length(bcamera.camera.position - bcamera.camera.target)
                
                // Calculate potential new pitch
                new_pitch := bcamera.current_pitch + mouse_delta.y * bcamera.rotation_speed
                
                // Clamp pitch to prevent gimbal lock
                bcamera.current_pitch = clamp(new_pitch, bcamera.min_pitch, bcamera.max_pitch)
                
                // Apply yaw rotation around global Y axis
                yaw := rl.QuaternionFromAxisAngle({0, 1, 0}, mouse_delta.x * bcamera.rotation_speed)
                
                // Get the right vector for pitch rotation
                right := rl.Vector3Normalize(rl.Vector3CrossProduct(direction, bcamera.camera.up))
                
                // Apply constrained pitch around right vector
                pitch := rl.QuaternionFromAxisAngle(right, mouse_delta.y * bcamera.rotation_speed)
                
                // Combine rotations
                rotation := pitch * yaw
                
                // Get vector from target to camera
                cam_to_target := bcamera.camera.position - bcamera.camera.target
                
                // Apply rotation while maintaining distance
                rotated := rl.Vector3Transform(cam_to_target, rl.QuaternionToMatrix(rotation))
                
                // Update camera position
                new_position := bcamera.camera.target + rotated
                
                // Verify the new position won't cause gimbal lock
                new_direction := rl.Vector3Normalize(bcamera.camera.target - new_position)
                up_dot := math.abs(rl.Vector3DotProduct(new_direction, {0, 1, 0}))
                
                // Only update if we're not too close to the poles
                if up_dot < 0.99 {
                    bcamera.camera.position = new_position
                }
            }
        }
    } else {
        // Free fly mode
        fly_speed := bcamera.move_speed
        if left_shift_down {
            fly_speed = bcamera.move_speed_fast
        }
        if rl.IsKeyDown(.LEFT_CONTROL) {
            fly_speed = bcamera.move_speed_slow
        }

        forward := rl.Vector3Normalize(bcamera.camera.target - bcamera.camera.position)
        right := rl.Vector3Normalize(rl.Vector3CrossProduct(bcamera.camera.up, forward))

        if rl.IsKeyDown(.W) {
            bcamera.camera.position = bcamera.camera.position + (forward * fly_speed)
        }
        if rl.IsKeyDown(.S) {
            bcamera.camera.position = bcamera.camera.position - (forward * fly_speed)
        }
        if rl.IsKeyDown(.A) {
            bcamera.camera.position = bcamera.camera.position + (right * fly_speed)
        }
        if rl.IsKeyDown(.D) {
            bcamera.camera.position = bcamera.camera.position - (right * fly_speed)
        }
        if rl.IsKeyDown(.E) {
            bcamera.camera.position = bcamera.camera.position + (bcamera.camera.up * fly_speed)
        }
        if rl.IsKeyDown(.Q) {
            bcamera.camera.position = bcamera.camera.position - (bcamera.camera.up * fly_speed)
        }

        // Update rotation
        yaw_quat := rl.QuaternionFromAxisAngle(bcamera.camera.up, -mouse_delta.x * bcamera.free_fly_rotation_speed)
        pitch_quat := rl.QuaternionFromAxisAngle(
            rl.Vector3CrossProduct(
                bcamera.camera.up,
                rl.Vector3Normalize(bcamera.camera.target - bcamera.camera.position),
            ),
            mouse_delta.y * bcamera.free_fly_rotation_speed,
        )
        q := pitch_quat * yaw_quat

        direction := bcamera.camera.target - bcamera.camera.position
        direction = rl.Vector3Transform(direction, rl.QuaternionToMatrix(q))
        bcamera.camera.target = bcamera.camera.position + direction
    }

    bcamera.previous_mouse_position = mouse_position
}

// main :: proc() {
//     screen_width :: 800
//     screen_height :: 450

//     rl.InitWindow(screen_width, screen_height, "Blender Camera")
//     defer rl.CloseWindow()

//     bcam := camera_init()
//     cube_position := rl.Vector3{0, 0, 0}

//     rl.SetTargetFPS(60)
//     rl.DisableCursor()

//     for !rl.WindowShouldClose() {
//         camera_update(&bcam)

//         rl.BeginDrawing()
//         defer rl.EndDrawing()

//         rl.ClearBackground(BLENDER_DARK_GREY)

//         rl.BeginMode3D(bcam.camera)
//         {
//             rl.DrawCube(cube_position, 2, 2, 2, BLENDER_GREY)
//             rl.DrawCubeWires(cube_position, 2, 2, 2, rl.ORANGE)
//             draw_grid_ex(20, 1)
//         }
//         rl.EndMode3D()

//         if bcam.free_fly {
//             rl.DrawText("Blender Camera Mode: FREE_FLY", 10, 10, 20, BLENDER_GREY)
//         } else {
//             rl.DrawText("Blender Camera Mode: GIMBAL_ORBIT", 10, 10, 20, BLENDER_GREY)
//         }
//         rl.DrawFPS(10, screen_height - 30)
//     }
// }
