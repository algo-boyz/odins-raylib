package cursor

import rl "vendor:raylib"
import "timer"

// Cursor manager handles automatic cursor hide
CursorManager :: struct {
    hide_timer:    timer.Timer,
    is_visible:    bool,
    timeout:       f32,
}

// Creates a new cursor manager with specified timeout
new :: proc(timeout_seconds: f32) -> CursorManager {
    manager := CursorManager{
        hide_timer = timer.new(),
        is_visible = true,
        timeout    = timeout_seconds,
    }
    timer.set(&manager.hide_timer, timeout_seconds)
    return manager
}

// Updates the cursor manager - call every frame
update :: proc(manager: ^CursorManager, delta_time: f32) {
    mouse_delta := rl.GetMouseDelta()
    
    // If mouse moved, show cursor and reset timer
    if mouse_delta.x != 0.0 || mouse_delta.y != 0.0 {
        if !manager.is_visible {
            show_cursor(manager)
        }
        timer.set(&manager.hide_timer, manager.timeout)
    }
    
    // Update timer
    timer.tick(&manager.hide_timer, delta_time)
    
    // Hide cursor if timer is done
    if timer.is_done(&manager.hide_timer) && manager.is_visible {
        hide_cursor(manager)
    }
}

// Manually show the cursor
show_cursor :: proc(manager: ^CursorManager) {
    rl.ShowCursor()
    manager.is_visible = true
}

// Manually hide the cursor
hide_cursor :: proc(manager: ^CursorManager) {
    rl.HideCursor()
    manager.is_visible = false
}

// Check if cursor is currently visible
is_visible :: proc(manager: ^CursorManager) -> bool {
    return manager.is_visible
}

// Change the timeout duration
set_timeout :: proc(manager: ^CursorManager, timeout_seconds: f32) {
    manager.timeout = timeout_seconds
    timer.set(&manager.hide_timer, timeout_seconds)
}