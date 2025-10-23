package viewport

import rl "vendor:raylib"

// Viewport manages window and graphics initialization
Viewport :: struct {
    WIDTH:  i32,
    HEIGHT: i32,
    title:         string,
}

// Configuration for viewport initialization
Config :: struct {
    title:         cstring,
    WIDTH:  i32,
    HEIGHT: i32,
    max_fps:       u32,
}

// Creates and initializes a new viewport
init :: proc(config: Config) -> Viewport {
    if config.max_fps > 300 {
        panic("Max FPS must be equal to or less than 300")
    }
    
    rl.InitWindow(config.WIDTH, config.HEIGHT, config.title)
    rl.SetTargetFPS(i32(config.max_fps))
    
    return Viewport{
        WIDTH  = config.WIDTH,
        HEIGHT = config.HEIGHT,
        title         = string(config.title),
    }
}

// Convenience function for simple initialization
init_simple :: proc(title: cstring, width, height: i32, fps: u32 = 60) -> Viewport {
    return init({
        title = title,
        WIDTH = width,
        HEIGHT = height,
        max_fps = fps,
    })
}

// Changes the window title
change_title :: proc(viewport: ^Viewport, new_title: cstring) {
    rl.SetWindowTitle(new_title)
    viewport.title = string(new_title)
}

// Gets the current mouse position
get_mouse_position :: proc(viewport: ^Viewport) -> rl.Vector2 {
    return rl.GetMousePosition()
}

// Loads a texture from file
load_texture :: proc(viewport: ^Viewport, filename: cstring) -> rl.Texture2D {
    return rl.LoadTexture(filename)
}

// Gets the viewport dimensions
get_dimensions :: proc(viewport: ^Viewport) -> (width: i32, height: i32) {
    return viewport.WIDTH, viewport.HEIGHT
}

// Gets the center point of the viewport
get_center :: proc(viewport: ^Viewport) -> rl.Vector2 {
    return {f32(viewport.WIDTH) / 2.0, f32(viewport.HEIGHT) / 2.0}
}

// Checks if a point is within the viewport bounds
is_point_in_bounds :: proc(viewport: ^Viewport, point: rl.Vector2) -> bool {
    return point.x >= 0 && point.x < f32(viewport.WIDTH) &&
           point.y >= 0 && point.y < f32(viewport.HEIGHT)
}

// Cleans up resources - should be called with defer
cleanup :: proc() {
    rl.CloseWindow()
}
