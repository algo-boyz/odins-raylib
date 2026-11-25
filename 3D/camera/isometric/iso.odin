
package isometric

import "core:math"
import rl "vendor:raylib"

Camera :: struct {
    camera: rl.Camera3D,
    target: rl.Vector3,
    azimuth: f32,
    elevation: f32,
    view_height: f32,
    min_view_height: f32,
    max_view_height: f32,
    follow_speed: f32,
    pan_speed: f32,
    follows: bool,
    dragging: bool,
    previous_mouse: rl.Vector2,
}

DEFAULT_AZIMUTH :: 45.0
DEFAULT_ELEVATION :: 38.0
DEFAULT_VIEW_HEIGHT :: 32.0

camera_init :: proc(
    target: rl.Vector3 = {0, 0, 0},
    view_height: f32 = DEFAULT_VIEW_HEIGHT,
) -> Camera {
    c := Camera{
        target = target,
        azimuth = DEFAULT_AZIMUTH,
        elevation = DEFAULT_ELEVATION,
        view_height = view_height,
        min_view_height = 10.0,
        max_view_height = 70.0,
        follow_speed = 8.0,
        pan_speed = 1.0,
        follows = false,
    }

    c.camera.up = {0, 1, 0}
    c.camera.fovy = view_height
    c.camera.projection = rl.CameraProjection.ORTHOGRAPHIC

    camera_rebuild(&c)
    return c
}

camera_rebuild :: proc(c: ^Camera) {
    az := c.azimuth * math.PI / 180.0
    el := c.elevation * math.PI / 180.0

    distance := max(c.view_height * 1.5, 30.0)
    horizontal := distance * math.cos(el)

    c.camera.position = {
        c.target.x + horizontal * math.sin(az),
        c.target.y + distance * math.sin(el),
        c.target.z + horizontal * math.cos(az),
    }

    c.camera.target = c.target
    c.camera.fovy = c.view_height
    c.camera.projection = rl.CameraProjection.ORTHOGRAPHIC
}

camera_follow :: proc(
    c: ^Camera,
    target: rl.Vector3,
    dt: f32,
) {
    if !c.follows do return

    alpha := 1.0 - math.exp(-c.follow_speed * dt)

    c.target.x += (target.x - c.target.x) * alpha
    c.target.y += (target.y - c.target.y) * alpha
    c.target.z += (target.z - c.target.z) * alpha

    camera_rebuild(c)
}

camera_update :: proc(c: ^Camera, dt: f32) {
    wheel := rl.GetMouseWheelMove()

    if wheel != 0 {
        c.view_height = math.clamp(
            c.view_height - wheel * 2.0,
            c.min_view_height,
            c.max_view_height,
        )
    }

    mouse := rl.GetMousePosition()

    shift_down := rl.IsKeyDown(rl.KeyboardKey.LEFT_SHIFT) ||
              rl.IsKeyDown(rl.KeyboardKey.RIGHT_SHIFT)

    if shift_down && rl.IsMouseButtonDown(rl.MouseButton.LEFT) {
        if !c.dragging {
            c.previous_mouse = mouse
            c.dragging = true
        } else {
            delta := mouse - c.previous_mouse
            c.previous_mouse = mouse

            aspect := f32(rl.GetScreenWidth()) /
                max(f32(rl.GetScreenHeight()), 1.0)

            world_per_pixel := c.view_height /
                max(f32(rl.GetScreenHeight()), 1.0)

            az := c.azimuth * math.PI / 180.0

            right := rl.Vector3{
                math.cos(az), 0, -math.sin(az),
            }

            forward := rl.Vector3{
                -math.sin(az), 0, -math.cos(az),
            }

            pan_x := -delta.x * world_per_pixel * aspect
            pan_z := delta.y * world_per_pixel

            c.target += right * pan_x + forward * pan_z
        }
    } else {
        c.dragging = false
    }

    camera_rebuild(c)
}
