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

/* TODO

package dmcore

import glsl "core:math/linalg/glsl"
import "core:math"

import "core:fmt"

Camera :: struct {
    position: v3,
    rotation: f32,

    orthoSize: f32,

    near, far, f32,

    aspect: f32,
}

CreateCamera :: proc(orthoSize, aspect:f32, near:f32 = 0.0001, far:f32 = 10000) -> Camera {
    return Camera {
        orthoSize = orthoSize,
        aspect = aspect,
        near = near,
        far = far,
        position = {0, 0, 1},
    }
}


// @TODO: actual view matrix...
GetViewMatrix :: proc(camera: Camera) -> mat4 {
    view := glsl.mat4Translate(-camera.position) * glsl.mat4Rotate({0, 0, 1}, camera.rotation * math.RAD_PER_DEG)
    return view
}

Mat4OrthoZTO :: proc(left, right, bottom, top, near, far: f32) -> (m: mat4) {
    m[0, 0] = +2 / (right - left)
    m[1, 1] = +2 / (top - bottom)
    m[2, 2] = -1 / (far - near)
    m[0, 3] = -(right + left)   / (right - left)
    m[1, 3] = -(top   + bottom) / (top - bottom)
    m[2, 3] = -near / (far - near)
    m[3, 3] = 1
    return m
}

// @TODO: support perspective projection
GetProjectionMatrixZTO :: proc(camera: Camera) -> mat4 {
    orthoHeight := camera.orthoSize
    orthoWidth  := camera.aspect * orthoHeight

    proj := Mat4OrthoZTO(-orthoWidth, orthoWidth, 
                         -orthoHeight, orthoHeight, 
                          camera.near, camera.far)

    return proj 
}

GetProjectionMatrixNTO :: proc(camera: Camera) -> mat4 {
    orthoHeight := camera.orthoSize
    orthoWidth  := camera.aspect * orthoHeight

    proj := glsl.mat4Ortho3d(-orthoWidth, orthoWidth, 
                             -orthoHeight, orthoHeight, 
                              camera.near, camera.far)

    return proj
}

GetVPMatrix :: proc(camera: Camera) -> mat4 {
    orthoHeight := camera.orthoSize
    orthoWidth  := camera.aspect * orthoHeight

    proj := glsl.mat4Ortho3d(-orthoWidth, orthoWidth, 
                             -orthoHeight, orthoHeight, 
                              camera.near, camera.far)

    view := GetViewMatrix(camera)

    return proj * view
}

GetCameraSize :: proc(camera: Camera) -> (size: v2) {
    size.y = camera.orthoSize * 2
    size.x = camera.aspect * size.y

    return
}


WorldToScreenPoint :: proc(pos: v2) -> iv2 {
    p := GetVPMatrix(renderCtx.camera) * v4{pos.x, pos.y, 0, 1}
    p.xyz /= p.w

    p = p * 0.5 + 0.5
    p.y = 1 - p.y

    return {
        i32(p.x * f32(renderCtx.frameSize.x)),
        i32(p.y * f32(renderCtx.frameSize.y)),
    }
}

WorldToClipSpace :: proc(camera: Camera, point: v3) -> v3 {
    p := GetVPMatrix(camera) * v4{point.x, point.y, point.z, 1}
    p.xyz /= p.w

    return p.xyz
}

ScreenToWorldSpace :: proc {
    ScreenToWorldSpaceCtx,
    ScreenToWorldSpaceImpl,
    ScreenToWorldSpaceCam,
}

ScreenToWorldSpaceImpl :: proc(point: iv2) -> v3 {
    return ScreenToWorldSpaceCtx(renderCtx.camera, point, renderCtx.frameSize)
}

ScreenToWorldSpaceCtx :: proc(camera: Camera, point: iv2, screenSize: iv2) -> v3 {
    clip := v2{f32(point.x) / f32(screenSize.x), f32(point.y) / f32(screenSize.y)}
    clip = clip * 2 - 1

    // @TODO: I don't understand why it works....
    vp := GetVPMatrix(camera)
    p := glsl.inverse(vp) * v4{clip.x, -clip.y, 0, 1}

    return v3{p.x, p.y, p.z}
}

ScreenToWorldSpaceCam :: proc(camera: Camera, point: iv2) -> v3{
    return ScreenToWorldSpaceCtx(camera, point, renderCtx.frameSize)
}

GetCameraBounds :: proc(camera: Camera) -> Bounds2D {
    orthoHeight := camera.orthoSize
    orthoWidth  := camera.aspect * orthoHeight

    return Bounds2D {
        left  = camera.position.x - orthoWidth,
        right = camera.position.x + orthoWidth,
        bot   = camera.position.y - orthoHeight,
        top   = camera.position.y + orthoHeight,
    }
}

ControlCamera :: proc(camera: ^Camera) {
    horizontal := GetAxis(.A, .D)
    vertical   := GetAxis(.W, .S)

    camera.position += {horizontal, -vertical, 0} * f32(time.deltaTime)
}

IsInsideCamera :: proc {
    IsInsideCamera_Rect,
    IsInsideCamera_Sprite,
}

IsInsideCamera_Rect :: proc(camera: Camera, rect: Rect) -> bool {
    a := v2{rect.x,              rect.y}
    b := v2{rect.x,              rect.y + rect.height}
    c := v2{rect.x + rect.width, rect.y}
    d := v2{rect.x + rect.width, rect.y + rect.width}

    ac := WorldToClipSpace(camera, ToV3(a))
    bc := WorldToClipSpace(camera, ToV3(b))
    cc := WorldToClipSpace(camera, ToV3(c))
    dc := WorldToClipSpace(camera, ToV3(d))

    // fmt.println(ac, bc, cc, dc)
    
    IsInRange :: #force_inline proc(point: v3) -> bool {
        return (point.x >= -1 && point.x <= 1) &&
               (point.y >= -1 && point.y <= 1) &&
               (point.z >= -1 && point.z <= 1)
    }

    return IsInRange(ac) ||
           IsInRange(bc) ||
           IsInRange(cc) ||
           IsInRange(dc)
}

IsInsideCamera_Sprite :: proc(camera: Camera, position: v2, sprite: Sprite) -> bool {
    size := GetSpriteSize(sprite)

    offset := sprite.origin * size
    return IsInsideCamera_Rect(camera, {position.x - offset.x, position.y - offset.y, size.x, size.y})
}
*/