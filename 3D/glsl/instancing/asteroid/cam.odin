// A first-person camera implementation for Raylib in Odin
package main

import rl "vendor:raylib"
import "core:math"

// --- Camera constants ---
MOVEMENT_SPEED :: 30.0
MOUSE_SENSITIVITY :: 15.0

// Camera_FP holds all state for our first-person camera
Camera_FP :: struct {
    view:            rl.Camera3D,
    current_speed:   f32,
    front:           rl.Vector3,
    right:           rl.Vector3,
    up:              rl.Vector3,
    yaw:             f32,
    pitch:           f32,
    zoom:            f32,
    constrain_pitch: bool,
}

// load_camera initializes and returns a new first-person camera
load_camera :: proc() -> Camera_FP {
    camera: Camera_FP
    
    // Set non-zero default values
    camera.current_speed = MOVEMENT_SPEED
    camera.front = {0.0, 0.0, -1.0}
    camera.right = {1.0, 0.0, 0.0}
    camera.up = {0.0, 1.0, 0.0}
    camera.yaw = -90.0
    camera.pitch = 0.0
    camera.zoom = 45.0
    camera.constrain_pitch = true

    // Define the underlying raylib camera
    camera.view = rl.Camera3D{
        position = {0.0, 0.0, 0.0},
        target = {0.0, 0.0, 0.0},
        up = {0.0, 1.0, 0.0},
        fovy = 45.0,
        projection = .PERSPECTIVE,
    }

    return camera
}

// update_camera_vectors calculates the front vector from the Camera's (updated) Euler Angles
update_camera_vectors :: proc(camera: ^Camera_FP) {
    // Calculate the new Front vector
    front: rl.Vector3
    front.x = math.cos(camera.yaw * rl.DEG2RAD) * math.cos(camera.pitch * rl.DEG2RAD)
    front.y = math.sin(camera.pitch * rl.DEG2RAD)
    front.z = math.sin(camera.yaw * rl.DEG2RAD) * math.cos(camera.pitch * rl.DEG2RAD)
    camera.front = rl.Vector3Normalize(front)

    // Also re-calculate the right and up vector.
    // Normalize the vectors, because their length gets closer to 0
    // the more you look up or down which results in slower movement.
    world_up: rl.Vector3 = {0, 1, 0}
    camera.right = rl.Vector3Normalize(rl.Vector3CrossProduct(camera.front, world_up))
    camera.up = rl.Vector3Normalize(rl.Vector3CrossProduct(camera.right, camera.front))
}

// update_mouse_movement adjusts yaw and pitch to look around and constrains pitch(up and down).
update_mouse_movement :: proc(camera: ^Camera_FP, xoffset, yoffset: f32) {
    x_offset := xoffset * MOUSE_SENSITIVITY * rl.GetFrameTime()
    y_offset := yoffset * MOUSE_SENSITIVITY * rl.GetFrameTime()

    camera.yaw += x_offset
    camera.pitch -= y_offset // Reversed since y-coordinates go from bottom to top

    // Make sure that when pitch is out of bounds, screen doesn't get flipped.
    if camera.constrain_pitch {
        camera.pitch = math.clamp(camera.pitch, -89.0, 89.0)
    }
    
    // Update Front, Right and Up Vectors using the updated Euler angles
    update_camera_vectors(camera)
}

// update_zoom modifies the camera's field of view based on scroll wheel input
update_zoom :: proc(camera: ^Camera_FP, yoffset: f32) {
    // Odin's math.clamp is perfect for this
    camera.view.fovy = math.clamp(camera.view.fovy - yoffset, 1.0, 45.0)
}

// get_movement calculates the movement vector based on keyboard input.
get_movement :: proc(camera: ^Camera_FP, dt: f32) -> rl.Vector3 {
    direction := rl.Vector3{} // Zero-initialized by default

    if rl.IsKeyDown(.W) {
        direction += camera.front
    }
    if rl.IsKeyDown(.S) {
        direction += -camera.front
    }
    if rl.IsKeyDown(.A) {
        direction += -camera.right
    }
    if rl.IsKeyDown(.D) {
        direction += camera.right
    }

    if rl.IsKeyDown(.SPACE) {
        direction += camera.up
    }
    if rl.IsKeyDown(.LEFT_SHIFT) {
        direction += -camera.up
    }

    return direction * (camera.current_speed * dt)
}

// update_camera is the main update procedure for the camera.
// It takes a pointer to the camera to modify it.
update_camera :: proc(camera: ^Camera_FP, mouse_delta: rl.Vector2, dt: f32) {
    // Speed up/slow down
    if rl.IsKeyPressed(.LEFT_CONTROL) {
        camera.current_speed = MOVEMENT_SPEED * 2.0
    }
    if rl.IsKeyPressed(.LEFT_CONTROL) {
        camera.current_speed = MOVEMENT_SPEED
    }

    // --- Flying first person camera movement ---
    movement_delta := get_movement(camera, dt)
    camera.view.position += movement_delta

    // --- Look around using mouse movement ---
    if mouse_delta.x != 0 || mouse_delta.y != 0 {
        update_mouse_movement(camera, mouse_delta.x, mouse_delta.y)
    }
    
    // Update the camera's target to be where it's looking
    camera.view.target = camera.view.position + camera.front

    // --- Zoom in and out with the scroll wheel ---
    scroll_y := rl.GetMouseWheelMove()
    if scroll_y != 0 {
        update_zoom(camera, scroll_y)
    }
}
