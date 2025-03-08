package rlutil

import "core:fmt"
import "core:math"
import "core:strings"
import rl "vendor:raylib"
import rlgl "vendor:raylib/rlgl"

// Modified version of Raylib's GetWorldToScreen(), but returns the
// NDC coordinates so we know what's behind the camera.
get_world_to_ndc :: proc(position: rl.Vector3, camera: rl.Camera) -> rl.Vector3 {
    width := rl.GetScreenWidth()
    height := rl.GetScreenHeight()
    // Calculate projection matrix (from perspective instead of frustum)
    mat_proj := rl.Matrix(1)
    if camera.projection == rl.CameraProjection.PERSPECTIVE {
        // Calculate projection matrix from perspective
        mat_proj = rl.MatrixPerspective(
            camera.fovy * rl.DEG2RAD,
            f32(width) / f32(height),
            rlgl.CULL_DISTANCE_NEAR,
            rlgl.CULL_DISTANCE_FAR,
        )
    } else if camera.projection == rl.CameraProjection.ORTHOGRAPHIC {
        aspect := f32(width) / f32(height)
        top := camera.fovy / 2.0
        right := top * aspect
        // Calculate projection matrix from orthographic
        mat_proj = rl.MatrixOrtho(
            -right,
            right,
            -top,
            top,
            rlgl.CULL_DISTANCE_NEAR,
            rlgl.CULL_DISTANCE_FAR,
        )
    }
    // Calculate view matrix from camera look at (and transpose it)
    mat_view := rl.MatrixLookAt(camera.position, camera.target, camera.up)
    // Convert world position vector to quaternion
    world_pos := transmute(quaternion128)[4]f32{position.x, position.y, position.z, 1.0}
    // Transform world position to view
    world_pos = rl.QuaternionTransform(world_pos, mat_view)
    // Transform result to projection (clip space position)
    world_pos = rl.QuaternionTransform(world_pos, mat_proj)
    // Calculate normalized device coordinates (inverted y)
    return rl.Vector3{
        world_pos.x / world_pos.w,
        -world_pos.y / world_pos.w,
        world_pos.z / world_pos.w,
    }
}