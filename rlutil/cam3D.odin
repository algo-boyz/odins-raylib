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

get_primary_ray :: proc(
    cam_local_point: rl.Vector3,
    cam_origin: ^rl.Vector3,
    cam_look_at: ^rl.Vector3
) -> rl.Ray {
    fwd := rl.Vector3Normalize(cam_look_at^ - cam_origin^)
    up := rl.Vector3{0.0, 1.0, 0.0}
    right := rl.Vector3Normalize(rl.Vector3CrossProduct(up, fwd))
    up = rl.Vector3Normalize(rl.Vector3CrossProduct(fwd, right))

    return rl.Ray{cam_origin^, rl.Vector3Normalize(fwd + (up * cam_local_point.y) + (right * cam_local_point.x))}
}

// Analytical surface-ray intersection routines
// more info: http://www.scratchapixel.com/old/lessons/3d-basic-lessons/lesson-7-intersecting-simple-shapes/ray-sphere-intersection/

Sphere :: struct {
    position:   rl.Vector3,
    radius:   f32,
    material: u32, // or whatever type you're using for material IDs
}

Plane :: struct {
    direction: rl.Vector3, // plane normal
    distance:  f32,        // distance to origin
    material:  u32,
}

Hit :: struct {
    t:           f32,
    material_id: u32,
    position:    rl.Vector3,
    normal:      rl.Vector3,
}

// Sphere intersection from outside
intersect_sphere :: proc(ray: rl.Ray, sphere: Sphere, hit: ^Hit) {
    rc := sphere.position - ray.position
    radius2 := sphere.radius * sphere.radius
    tca := rl.Vector3DotProduct(rc, ray.direction)
    
    if tca < 0.0 do return
    
    d2 := rl.Vector3DotProduct(rc, rc) - tca * tca
    if d2 > radius2 do return
    
    thc := math.sqrt(radius2 - d2)
    t0 := tca - thc
    t1 := tca + thc
    
    if t0 < 0.0 do t0 = t1
    if t0 > hit.t do return
    
    impact := ray.position + ray.direction * t0
    
    hit.t = t0
    hit.material_id = sphere.material
    hit.position = impact
    hit.normal = (impact - sphere.position) / sphere.radius
}

// Sphere intersection from inside
intersect_sphere_from_inside :: proc(ray: rl.Ray, sphere: Sphere, hit: ^Hit) {
    rc := sphere.position - ray.position
    radius2 := sphere.radius * sphere.radius
    tca := rl.Vector3DotProduct(rc, ray.direction)
    d2 := rl.Vector3DotProduct(rc, rc) - tca * tca
    thc := math.sqrt(radius2 - d2)
    t0 := tca - thc
    t1 := tca + thc
    
    impact := ray.position + ray.direction * t0
    hit.t = t0
    hit.material_id = sphere.material
    hit.position = impact
    hit.normal = (impact - sphere.position) / sphere.radius
}

// Plane intersection
intersect_plane :: proc(ray: rl.Ray, plane: Plane, hit: ^Hit) {
    denom := rl.Vector3DotProduct(plane.direction, ray.direction)
    if denom < 1e-6 do return
    
    // P0 is a point on the plane, calculated from plane normal and distance
    P0 := plane.direction * plane.distance
    t := rl.Vector3DotProduct(P0 - ray.position, plane.direction) / denom
    
    if t < 0.0 || t > hit.t do return
    
    hit.t = t
    hit.material_id = plane.material
    hit.position = ray.position + ray.direction * t
    
    // Face forward equivalent - flip normal if it's facing away from ray
    if rl.Vector3DotProduct(plane.direction, ray.direction) > 0 {
        hit.normal = -plane.direction
    } else {
        hit.normal = plane.direction
    }
}

camera_view_mat :: proc(camera: rl.Camera) -> rl.Matrix {
	return rl.MatrixLookAt(camera.position, camera.target, camera.up);
}

camera_proj_mat :: proc(camera:  rl.Camera, aspect, near, far: f32) -> rl.Matrix {
	return rl.MatrixPerspective(camera.fovy * rl.DEG2RAD, aspect, near, far);
}