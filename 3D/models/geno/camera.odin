package geno

import "core:fmt"
import "core:mem"

import rl "vendor:raylib"

// Basic Orbit Camera with simple controls
OrbitCamera :: struct {
    cam3d: rl.Camera3D,
    azimuth: f32,
    altitude: f32,
    distance: f32,
    offset: rl.Vector3,
}

orbit_camera_init :: proc(camera: ^OrbitCamera) {
    mem.zero(&camera.cam3d, size_of(rl.Camera3D))
    camera.cam3d.position = rl.Vector3{2.0, 3.0, 5.0}
    camera.cam3d.target = rl.Vector3{-0.5, 1.0, 0.0}
    camera.cam3d.up = rl.Vector3{0.0, 1.0, 0.0}
    camera.cam3d.fovy = 45.0
    camera.cam3d.projection = rl.CameraProjection.PERSPECTIVE

    camera.azimuth = 0.0
    camera.altitude = 0.4
    camera.distance = 4.0
    camera.offset = rl.Vector3{}
}

orbit_camera_update_input :: proc(camera: ^OrbitCamera, target: rl.Vector3) {
    // Get mouse delta once
    mouse_delta := rl.GetMouseDelta()
    dt := rl.GetFrameTime()
    
    // Then use the stored values
    azimuth_delta := rl.IsKeyDown(rl.KeyboardKey.LEFT_CONTROL) && rl.IsMouseButtonDown(rl.MouseButton.LEFT) ? mouse_delta.x : 0.0
    altitude_delta := rl.IsKeyDown(rl.KeyboardKey.LEFT_CONTROL) && rl.IsMouseButtonDown(rl.MouseButton.LEFT) ? mouse_delta.y : 0.0
    offset_delta_x := rl.IsKeyDown(rl.KeyboardKey.LEFT_CONTROL) && rl.IsMouseButtonDown(rl.MouseButton.RIGHT) ? mouse_delta.x : 0.0
    offset_delta_y := rl.IsKeyDown(rl.KeyboardKey.LEFT_CONTROL) && rl.IsMouseButtonDown(rl.MouseButton.RIGHT) ? mouse_delta.y : 0.0
    
    orbit_camera_update(
        camera,
        target,
        azimuth_delta,
        altitude_delta,
        offset_delta_x,
        offset_delta_y,
        rl.GetMouseWheelMove(),
        dt,
    )
}

orbit_camera_update :: proc(
    camera: ^OrbitCamera,
    target: rl.Vector3,
    azimuth_delta: f32,
    altitude_delta: f32,
    offset_delta_x: f32,
    offset_delta_y: f32,
    mouse_wheel: f32,
    dt: f32,
) {
    camera.azimuth += 1.0 * dt * -azimuth_delta
    camera.altitude = clamp(camera.altitude + 1.0 * dt * altitude_delta, 0.0, 0.4 * rl.PI)
    camera.distance = clamp(camera.distance + 20.0 * dt * -mouse_wheel, 0.1, 100.0)
    
    rotation_azimuth := rl.QuaternionFromAxisAngle(rl.Vector3{0, 1, 0}, camera.azimuth)
    position := rl.Vector3RotateByQuaternion(rl.Vector3{0, 0, camera.distance}, rotation_azimuth)
    axis := rl.Vector3Normalize(rl.Vector3CrossProduct(position, rl.Vector3{0, 1, 0}))

    rotation_altitude := rl.QuaternionFromAxisAngle(axis, camera.altitude)

    local_offset := rl.Vector3{dt * offset_delta_x, dt * -offset_delta_y, 0.0}
    local_offset = rl.Vector3RotateByQuaternion(local_offset, rotation_azimuth)

    // camera.offset = camera.offset + rl.Vector3RotateByQuaternion(local_offset, rotation_altitude)
    new_offset := camera.offset + rl.Vector3RotateByQuaternion(local_offset, rotation_altitude)
    
    // Add bounds checking
    max_offset := f32(100.0) // Adjust this value as needed
    camera.offset = {
        clamp(new_offset.x, -max_offset, max_offset),
        clamp(new_offset.y, -max_offset, max_offset),
        clamp(new_offset.z, -max_offset, max_offset),
    }
    camera_target := camera.offset + target
    eye := camera_target + rl.Vector3RotateByQuaternion(position, rotation_altitude)

    camera.cam3d.target = camera_target
    camera.cam3d.position = eye
    // fmt.printf("Offset: %v, Target: %v, Camera Target: %v\n", camera.offset, target, camera_target)
}
