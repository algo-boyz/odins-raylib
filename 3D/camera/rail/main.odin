package main

import "core:fmt"
import "core:math"
import "core:math/linalg"
import rl "vendor:raylib"

SCREEN_WIDTH:  i32 = 1200
SCREEN_HEIGHT: i32 = 900
cursor_captured: bool = true

Rail :: struct {
    camera:     rl.Camera3D,
    path:       []rl.Vector3,
    path_length: i32,
    path_time:  f32,
    speed:      f32,
    yaw:        f32, // Left/right rotation
    pitch:      f32, // Up/down rotation
}

rails_camera: Rail

trek := []rl.Vector3{
    {0, 3, -10}, // Start behind
    {0, 3, 0},   // Move forward to center
    {10, 3, 0},  // Turn right
    {10, 3, 10}, // End forward
}

init_cam :: proc() -> rl.Camera3D {
    camera: rl.Camera3D
    // -L/+R - -D/+U - -In/+Out
    camera.position = {0, 0, 8}
    camera.target = {0, 0, 1}
    camera.up = {0, 1, 0}
    camera.fovy = 50.0
    camera.projection = .PERSPECTIVE

    return camera
}

init_rail :: proc(camera: rl.Camera3D) -> Rail {
    rail: Rail
    rail.camera = camera
    rail.speed = 0.1
    return rail
}

look_direction :: proc(r: Rail) -> rl.Vector3 {
    v: rl.Vector3
    v.x = math.cos(r.pitch) * math.cos(r.yaw)
    v.y = math.sin(r.pitch)
    v.z = math.cos(r.pitch) * math.sin(r.yaw)
    return v
}

toggle_cursor :: proc() {
    cursor_captured = !cursor_captured
    if cursor_captured {
        rl.DisableCursor()
    } else {
        rl.EnableCursor()
    }
}

draw_axis :: proc() {
    // Add some grid lines on the ground
    for i in -10..=10 {
        rl.DrawLine3D({f32(i), 0, -10}, {f32(i), 0, 10}, rl.LIGHTGRAY)
        rl.DrawLine3D({-10, 0, f32(i)}, {10, 0, f32(i)}, rl.LIGHTGRAY)
    }

    l: f32 = 100
    // X-axis (Red)
    rl.DrawLine3D({-l, 0, 0}, {l, 0, 0}, rl.RED)
    // Y-axis (Green)
    rl.DrawLine3D({0, -l, 0}, {0, l, 0}, rl.GREEN)
    // Z-axis (Blue)
    rl.DrawLine3D({0, 0, -l}, {0, 0, l}, rl.BLUE)
}

draw_cube :: proc() {
    rl.DrawCube({0.0, 1.0, 0.0}, 2.0, 2.0, 2.0, rl.MAROON)
    rl.DrawCube({5.0, 2.0, 0.0}, 2.0, 1.0, 1.0, rl.BLUE)
}

draw :: proc(c: rl.Camera3D) {
    rl.ClearBackground(rl.WHITE)

    rl.BeginMode3D(c)
    draw_axis()
    draw_cube()
    rl.EndMode3D()
}

// DEBUG
debug_cursor :: proc(pos: rl.Vector2) {
    mouse := rl.GetMousePosition()
    buf := fmt.ctprintf("x: %.0f, y: %.0f", mouse.x, mouse.y)
    rl.DrawText(buf, i32(pos.x), i32(pos.y), 22, rl.BLACK)
}

debug_path :: proc(pos: rl.Vector2) {
    buf := fmt.ctprintf("path_time: %.3f", rails_camera.path_time)
    rl.DrawText(buf, i32(pos.x), i32(pos.y), 22, rl.BLACK)
}

debug_cam :: proc(c: ^Rail, pos: rl.Vector2) {
    buf1 := fmt.ctprintf("x: %.3f, y: %.3f, z: %.3f",
        c.camera.position.x, c.camera.position.y, c.camera.position.z)
    rl.DrawText(buf1, i32(pos.x), i32(pos.y), 22, rl.BLACK)

    buf2 := fmt.ctprintf("yaw: %.3f, pitch: %.3f, speed: %.3f",
        c.yaw, c.pitch, c.speed)
    rl.DrawText(buf2, i32(pos.x), i32(pos.y) + 20, 22, rl.BLACK)
}

debug_trek :: proc() {
    mouse := rl.GetMousePosition()
    rl.DrawLine(0, i32(mouse.y), SCREEN_WIDTH, i32(mouse.y), rl.LIGHTGRAY)
    rl.DrawLine(i32(mouse.x), 0, i32(mouse.x), SCREEN_HEIGHT, rl.LIGHTGRAY)
}

debug :: proc() {
    // debug_cursor({10, 10})
    debug_path({10, 10})
    debug_cam(&rails_camera, {10, 30})
    // debug_trek()
}

// EXECUTION

init_game :: proc() {
    rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "ZBoard")
    rails_camera = init_rail(init_cam())
    rl.SetTargetFPS(60)
    rl.DisableCursor()
}

update_frame :: proc() {
    if cursor_captured {
        rails_camera.path_time += rl.GetFrameTime() * rails_camera.speed
        path_step := i32(rails_camera.path_time) % 4
        t := rails_camera.path_time - f32(i32(rails_camera.path_time))

        // Handle mouse input for looking around
        mouse_delta := rl.GetMouseDelta()
        rails_camera.yaw += mouse_delta.x * 0.002
        rails_camera.pitch -= mouse_delta.y * 0.002 // Negative for natural feel

        // Clamp pitch so you can't flip upside down
        rails_camera.pitch = clamp(rails_camera.pitch, -1.5, 1.5)

        new_dir := look_direction(rails_camera)

        rails_camera.camera.position = linalg.lerp(trek[path_step], trek[(path_step + 1) % 4], t)
        rails_camera.camera.target = rails_camera.camera.position + new_dir
    }
    // To get the cursor back:
    if rl.IsKeyPressed(.F9) {
        toggle_cursor()
    }
    rl.BeginDrawing()
    rl.ClearBackground(rl.RAYWHITE)

    draw(rails_camera.camera)

    debug()

    rl.EndDrawing()
}

main :: proc() {
    init_game()
    for !rl.WindowShouldClose() {
        update_frame()
    }
}