package main

import "core:math"
import rl "vendor:raylib"

// Types and Structures
QuadChild :: enum {
    TL, // top-left
    BL, // bottom-left 
    BR, // bottom-right
    TR, // top-right
    COUNT,
}

Camera :: struct {
    pos: rl.Vector2,
    fov: f32,
}

Quadtree :: struct {
    min: rl.Vector2,
    max: rl.Vector2,
    childs: [QuadChild.COUNT]^Quadtree,
}

// Global Variables
SCREEN_WIDTH :: 512
SCREEN_HEIGHT :: 512

// State
state := struct {
    quad_depth: int,
    quad_size: int,
    root: ^Quadtree,
    camera: Camera,
    cam_speed: f32,
    cam_fov: f32,
    view_line: f32,
    fl, fr: rl.Vector2, // frustum left/right planes
}{
    quad_depth = 6,
    quad_size = 512,
    cam_speed = 2,
    cam_fov = 60.0,
    view_line = 300,
}

create_camera :: proc(x, y, fov: f32) -> Camera {
    return Camera{
        pos = {x, y},
        fov = fov,
    }
}

point_in_frustum_left :: proc(cam: Camera, px, py: f32) -> bool {
    return (-(px - cam.pos.x) * (state.fl.y - cam.pos.y) + 
            (py - cam.pos.y) * (state.fl.x - cam.pos.x) >= 0.0)
}

point_in_frustum_right :: proc(cam: Camera, px, py: f32) -> bool {
    return (-(px - cam.pos.x) * (state.fr.y - cam.pos.y) + 
            (py - cam.pos.y) * (state.fr.x - cam.pos.x) <= 0.0)
}

create_quadtree :: proc(xmin, ymin, xmax, ymax: f32, depth: int) -> ^Quadtree {
    qt := new(Quadtree)
    qt.min = {xmin, ymin}
    qt.max = {xmax, ymax}
    
    if depth > 0 {
        xavg := (xmin + xmax) * 0.5
        yavg := (ymin + ymax) * 0.5
        new_depth := depth - 1
        
        qt.childs[QuadChild.TL] = create_quadtree(xmin, ymin, xavg, yavg, new_depth)
        qt.childs[QuadChild.BL] = create_quadtree(xmin, yavg, xavg, ymax, new_depth)
        qt.childs[QuadChild.BR] = create_quadtree(xavg, yavg, xmax, ymax, new_depth)
        qt.childs[QuadChild.TR] = create_quadtree(xavg, ymin, xmax, yavg, new_depth)
    }
    
    return qt
}

free_quadtree :: proc(qt: ^Quadtree) {
    if qt == nil do return
    
    for child in qt.childs {
        if child != nil {
            free_quadtree(child)
        }
    }
    free(qt)
}

quad_in_frustum :: proc(qt: ^Quadtree, cam: Camera) -> bool {
    // left plane
    inside := 0
    if point_in_frustum_left(cam, qt.min.x, qt.min.y) do inside += 1 // top-left
    if point_in_frustum_left(cam, qt.min.x, qt.max.y) do inside += 1 // bottom-left
    if point_in_frustum_left(cam, qt.max.x, qt.min.y) do inside += 1 // top-right
    if point_in_frustum_left(cam, qt.max.x, qt.max.y) do inside += 1 // bottom-right
    if inside == 0 do return false

    // right plane
    inside = 0
    if point_in_frustum_right(cam, qt.min.x, qt.min.y) do inside += 1
    if point_in_frustum_right(cam, qt.min.x, qt.max.y) do inside += 1
    if point_in_frustum_right(cam, qt.max.x, qt.min.y) do inside += 1
    if point_in_frustum_right(cam, qt.max.x, qt.max.y) do inside += 1
    if inside == 0 do return false

    return true
}

render_quadtree :: proc(qt: ^Quadtree, cam: Camera, depth: int) {
    if !quad_in_frustum(qt, cam) do return
    
    if depth > 1 {
        xavg := (qt.min.x + qt.max.x) * 0.5
        yavg := (qt.min.y + qt.max.y) * 0.5
        
        rl.DrawLine(i32(xavg), i32(qt.min.y), i32(xavg), i32(qt.max.y), rl.GRAY)
        rl.DrawLine(i32(qt.min.x), i32(yavg), i32(qt.max.x), i32(yavg), rl.GRAY)
        
        new_depth := depth - 1
        render_quadtree(qt.childs[QuadChild.TL], cam, new_depth)
        render_quadtree(qt.childs[QuadChild.BL], cam, new_depth)
        render_quadtree(qt.childs[QuadChild.BR], cam, new_depth)
        render_quadtree(qt.childs[QuadChild.TR], cam, new_depth)
    } else {
        rl.DrawRectangle(
            i32(qt.min.x), 
            i32(qt.min.y), 
            i32(qt.max.x - qt.min.x), 
            i32(qt.max.y - qt.min.y), 
            rl.LIGHTGRAY,
        )
        rl.DrawRectangleLines(
            i32(qt.min.x - 1), 
            i32(qt.min.y - 1), 
            i32(qt.max.x - qt.min.x + 1), 
            i32(qt.max.y - qt.min.y + 1), 
            rl.GRAY,
        )
    }
}

update_and_draw :: proc() {
    // Update camera position
    if rl.IsKeyDown(.LEFT) {
        state.camera.pos.x -= state.cam_speed
    } else if rl.IsKeyDown(.RIGHT) {
        state.camera.pos.x += state.cam_speed
    }
    
    if rl.IsKeyDown(.UP) {
        state.camera.pos.y -= state.cam_speed
    } else if rl.IsKeyDown(.DOWN) {
        state.camera.pos.y += state.cam_speed
    }

    // Camera angle
    mouse_pos := rl.GetMousePosition()
    px := mouse_pos.x - state.camera.pos.x
    py := mouse_pos.y - state.camera.pos.y
    angle := math.atan2_f32(py, px)
    cam_fov_rad := (state.camera.fov / 2.0) * math.RAD_PER_DEG
    
    cam_dir := rl.Vector2{
        state.camera.pos.x + (state.view_line * 0.5) * math.cos_f32(angle),
        state.camera.pos.y + (state.view_line * 0.5) * math.sin_f32(angle),
    }

    // Update frustum positions
    state.fl = {
        state.camera.pos.x + state.view_line * math.cos_f32(angle - cam_fov_rad),
        state.camera.pos.y + state.view_line * math.sin_f32(angle - cam_fov_rad),
    }
    
    state.fr = {
        state.camera.pos.x + state.view_line * math.cos_f32(angle + cam_fov_rad),
        state.camera.pos.y + state.view_line * math.sin_f32(angle + cam_fov_rad),
    }

    // Draw
    rl.BeginDrawing()
    defer rl.EndDrawing()

    rl.ClearBackground(rl.WHITE)

    // Draw quadtree
    render_quadtree(state.root, state.camera, state.quad_depth)
    rl.DrawRectangleLines(
        i32(state.root.min.x),
        i32(state.root.min.y),
        i32(state.root.max.x - state.root.min.x),
        i32(state.root.max.y - state.root.min.y),
        rl.RED,
    )

    // Draw frustum planes
    rl.DrawLine(
        i32(state.camera.pos.x),
        i32(state.camera.pos.y),
        i32(state.fl.x),
        i32(state.fl.y),
        rl.GREEN,
    )
    rl.DrawLine(
        i32(state.camera.pos.x),
        i32(state.camera.pos.y),
        i32(state.fr.x),
        i32(state.fr.y),
        rl.RED,
    )

    // Draw camera
    rl.DrawLine(
        i32(state.camera.pos.x),
        i32(state.camera.pos.y),
        i32(cam_dir.x),
        i32(cam_dir.y),
        rl.YELLOW,
    )
    rl.DrawCircle(
        i32(state.camera.pos.x),
        i32(state.camera.pos.y),
        10,
        rl.BLUE,
    )
}

main :: proc() {
    rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "raylib: quadtree")
    defer rl.CloseWindow()

    rl.SetTargetFPS(60)

    // Initialize state
    state.camera = create_camera(f32(state.quad_size)/2, f32(state.quad_size)/2, state.cam_fov)
    state.root = create_quadtree(0, 0, f32(state.quad_size), f32(state.quad_size), state.quad_depth)
    defer free_quadtree(state.root)

    for !rl.WindowShouldClose() {
        update_and_draw()
    }
}