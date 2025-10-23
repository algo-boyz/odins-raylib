package vres

import rl "vendor:raylib"
import "core:fmt"
import "core:math"

// V-Resolution
VirtualRes :: struct {
    // Config
    v_width, v_height: i32,
    // Runtime state
    scale:          f32,
    fullscreen:     bool,
    window_pos,
    window_size,
    // Rendering
    v_bounds,
    v_mouse_pos,
    real_mouse_pos: rl.Vector2,
    v_rect:         rl.Rectangle,
    canvas:         rl.RenderTexture2D,
}

VRES_BOUNDS :: proc(vres: ^VirtualRes) -> rl.Vector2 { return vres.v_bounds }
VRES_RECT   :: proc(vres: ^VirtualRes) -> rl.Rectangle { return vres.v_rect }
VRES_MOUSE  :: proc(vres: ^VirtualRes) -> rl.Vector2 { return vres.v_mouse_pos }

init :: proc(vres: ^VirtualRes, width, height: i32, window_title: cstring) {
    vres.v_width = width
    vres.v_height = height
    // Setup window
    rl.SetConfigFlags({.VSYNC_HINT, .WINDOW_RESIZABLE})
    rl.InitWindow(width, height, window_title)
    rl.SetWindowMinSize(width, height)
    // Store window state
    vres.window_pos  = rl.GetWindowPosition()
    vres.window_size = {f32(rl.GetScreenWidth()), f32(rl.GetScreenHeight())}
    // Create render texture
    vres.canvas = rl.LoadRenderTexture(width, height)
    rl.SetTextureFilter(vres.canvas.texture, .POINT)
    // Precompute constants
    vres.v_bounds = {f32(width), f32(height)}
    vres.v_rect   = {0, 0, f32(width), -f32(height)}
}

destroy :: proc(vres: ^VirtualRes) {
    rl.UnloadRenderTexture(vres.canvas)
}

// Call once per frame
update :: proc(vres: ^VirtualRes) {
    // Handle window resize glitch
    if rl.IsWindowResized() {
        pos := rl.GetWindowPosition()
        rl.SetWindowPosition(i32(pos.x) + 1, i32(pos.y) + 1)
        rl.SetWindowPosition(i32(pos.x) - 1, i32(pos.y) - 1)
    }
    calc_scale(vres)
    locate_mouse(vres)
}

toggle_fullscreen :: proc(vres: ^VirtualRes) {
    vres.fullscreen = !vres.fullscreen
    if vres.fullscreen {
        // Store current window state
        vres.window_pos  = rl.GetWindowPosition()
        vres.window_size = {f32(rl.GetScreenWidth()), f32(rl.GetScreenHeight())}
        // Switch to fullscreen
        monitor := rl.GetCurrentMonitor()
        mon_pos := rl.GetMonitorPosition(monitor)
        rl.SetWindowPosition(i32(mon_pos.x), i32(mon_pos.y))
        rl.SetWindowSize(rl.GetMonitorWidth(monitor), rl.GetMonitorHeight(monitor))
        rl.SetWindowState({.WINDOW_UNDECORATED})
    } else {
        // Restore window mode
        rl.ClearWindowState({.WINDOW_UNDECORATED})
        rl.SetWindowSize(i32(vres.window_size.x), i32(vres.window_size.y))
        rl.SetWindowPosition(i32(vres.window_pos.x), i32(vres.window_pos.y))
    }
}

calc_scale :: proc(vres: ^VirtualRes) {
    // Handle fullscreen toggle - CHANGE THIS KEY AS NEEDED
    if rl.GetKeyPressed() == .F1 {
        toggle_fullscreen(vres)
    }
    // Calc scale to fit screen
    screen_w, screen_h := f32(rl.GetScreenWidth()), f32(rl.GetScreenHeight())
    v_w, v_h := f32(vres.v_width), f32(vres.v_height)
    
    vres.scale = math.min(screen_w / v_w, screen_h / v_h)
    vres.scale = math.floor(vres.scale) // Integer scaling
}

locate_mouse :: proc(vres: ^VirtualRes) {
    vres.real_mouse_pos = rl.GetMousePosition()
    // Convert mouse pos to virtual coordinates
    screen_w, screen_h := f32(rl.GetScreenWidth()), f32(rl.GetScreenHeight())
    v_w, v_h := f32(vres.v_width * i32(vres.scale)), f32(vres.v_height * i32(vres.scale))
    
    offset_x := (screen_w - v_w) * 0.5
    offset_y := (screen_h - v_h) * 0.5
    
    vres.v_mouse_pos.x = (vres.real_mouse_pos.x - offset_x) / vres.scale
    vres.v_mouse_pos.y = (vres.real_mouse_pos.y - offset_y) / vres.scale
    
    // Clamp pos to virtual resolution bounds
    vres.v_mouse_pos = rl.Vector2Clamp(vres.v_mouse_pos, {0, 0}, vres.v_bounds)
}

begin_drawing :: proc(vres: ^VirtualRes) {
    rl.BeginTextureMode(vres.canvas)
    rl.ClearBackground(rl.BLACK)
}

end_drawing :: proc(vres: ^VirtualRes) {
    rl.EndTextureMode()
    // Draw virtual canvas to screen
    rl.BeginDrawing()
    rl.ClearBackground(rl.BLACK)
    draw_to_screen(vres)
}

draw_to_screen :: proc(vres: ^VirtualRes) {
    screen_w, screen_h := f32(rl.GetScreenWidth()), f32(rl.GetScreenHeight())
    v_w, v_h := f32(vres.v_width * i32(vres.scale)), f32(vres.v_height * i32(vres.scale))
    
    draw_rect := rl.Rectangle{
        (screen_w - v_w) * 0.5,
        (screen_h - v_h) * 0.5,
        v_w,
        v_h,
    }
    rl.DrawTexturePro(
        vres.canvas.texture, 
        vres.v_rect, 
        draw_rect, 
        {0, 0}, 
        0.0, 
        rl.WHITE
    )
}

finish_frame :: proc(vres: ^VirtualRes) {
    rl.EndDrawing()
}

is_key_pressed :: proc(key: rl.KeyboardKey) -> bool {
    return rl.IsKeyPressed(key)
}

get_mouse_button :: proc(button: rl.MouseButton) -> bool {
    return rl.IsMouseButtonDown(button)
}

get_scale :: proc(vres: ^VirtualRes) -> f32 {
    return vres.scale
}

get_virtual_width :: proc(vres: ^VirtualRes) -> i32 {
    return vres.v_width
}

get_virtual_height :: proc(vres: ^VirtualRes) -> i32 {
    return vres.v_height
}