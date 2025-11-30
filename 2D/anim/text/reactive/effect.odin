package reactive

import rl "vendor:raylib"
import "core:math"
import "core:fmt"
import "core:slice"

Config :: struct {
    WIDTH:  i32,
    HEIGHT: i32,
    title:         cstring,
    fps:           i32,
    background:    rl.Color,
    debug_mode:    bool,
}

DEFAULT_CONFIG :: Config{
    WIDTH  = 800,
    HEIGHT = 450,
    title         = "Interactive Text System",
    fps           = 60,
    background    = rl.BLACK,
    debug_mode    = true,
}

TextAnimationType :: enum {
    NONE,
    PULSE,
    BOUNCE,
    WAVE,
    SHAKE,
    GROW_SHRINK,
}

TextColorMode :: enum {
    STATIC,
    HSV_CYCLE,
    RAINBOW_WAVE,
    BRIGHTNESS_PULSE,
}

TextElement :: struct {
    // Core properties
    text:           cstring,
    position:       rl.Vector2,
    font_size:      f32,
    base_color:     rl.Color,
    
    // Animation properties
    animation_type: TextAnimationType,
    animation_speed: f64,
    color_mode:     TextColorMode,
    color_speed:    f64,
    
    // Interactive properties
    clickable:      bool,
    hoverable:      bool,
    hover_scale:    f32,
    click_scale:    f32,
    
    // Internal state
    scale:          f32,
    rotation:       f64,
    current_color:  rl.Color,
    color_hue:      f64,
    is_hovered:     bool,
    is_clicked:     bool,
    bounds:         rl.Rectangle,
    
    // Callbacks
    on_hover:       proc(element: ^TextElement),
    on_click:       proc(element: ^TextElement),
    on_release:     proc(element: ^TextElement),
}

// Text element creation helpers
make_text_element :: proc(text: cstring, x, y: f32, font_size: f32 = 30) -> TextElement {
    element := TextElement{
        text = text,
        position = {x, y},
        font_size = font_size,
        base_color = rl.WHITE,
        animation_type = .PULSE,
        animation_speed = 2.0,
        color_mode = .HSV_CYCLE,
        color_speed = 1.0,
        clickable = true,
        hoverable = true,
        hover_scale = 1.1,
        click_scale = 1.2,
        scale = 1.0,
        rotation = 0.0,
        current_color = rl.WHITE,
        color_hue = 0.0,
    }
    
    // Calculate bounds
    text_size := rl.MeasureTextEx(rl.GetFontDefault(), text, font_size, 1)
    element.bounds = {
        x = x,
        y = y,
        width = text_size.x,
        height = text_size.y,
    }
    
    return element
}

make_centered_text :: proc(text: cstring, screen_w, screen_h: i32, font_size: f32 = 30) -> TextElement {
    text_size := rl.MeasureTextEx(rl.GetFontDefault(), text, font_size, 1)
    x := f32(screen_w) / 2 - text_size.x / 2
    y := f32(screen_h) / 2 - text_size.y / 2
    return make_text_element(text, x, y, font_size)
}

// Text element update logic
update_text_element :: proc(element: ^TextElement, dt: f64) {
    mouse_pos := rl.GetMousePosition()
    
    // Update hover state
    was_hovered := element.is_hovered
    element.is_hovered = element.hoverable && rl.CheckCollisionPointRec(mouse_pos, element.bounds)
    
    // Handle hover callbacks
    if element.is_hovered && !was_hovered && element.on_hover != nil {
        element.on_hover(element)
    }
    
    // Update click state
    was_clicked := element.is_clicked
    if element.clickable && element.is_hovered && rl.IsMouseButtonPressed(.LEFT) {
        element.is_clicked = true
        if element.on_click != nil {
            element.on_click(element)
        }
    } else if element.is_clicked && rl.IsMouseButtonReleased(.LEFT) {
        element.is_clicked = false
        if element.on_release != nil {
            element.on_release(element)
        }
    }
    
    // Update animations
    update_text_animation(element, dt)
    update_text_color(element, dt)
    
    // Update scale based on interaction
    target_scale: f32 = 1.0
    if element.is_clicked {
        target_scale = element.click_scale
    } else if element.is_hovered {
        target_scale = element.hover_scale
    }
    
    // Smooth scale transition
    element.scale = rl.Lerp(element.scale, target_scale, f32(dt * 8.0))
}

update_text_animation :: proc(element: ^TextElement, dt: f64) {
    time := rl.GetTime()
    
    switch element.animation_type {
    case .NONE:
        // No animation
        
    case .PULSE:
        if element.is_hovered {
            pulse := math.sin(time * element.animation_speed) * 0.1
            element.scale += f32(pulse)
        }
        
    case .BOUNCE:
        bounce := abs(math.sin(time * element.animation_speed)) * 0.2
        element.scale += f32(bounce)
        
    case .WAVE:
        wave := math.sin(time * element.animation_speed) * 0.15
        element.scale += f32(wave)
        
    case .SHAKE:
        if element.is_hovered {
            shake_x := (math.sin(time * element.animation_speed * 10) * 2)
            shake_y := (math.cos(time * element.animation_speed * 10) * 2)
            element.position.x += f32(shake_x)
            element.position.y += f32(shake_y)
        }
        
    case .GROW_SHRINK:
        grow := math.sin(time * element.animation_speed) * 0.3 + 1.0
        element.scale = f32(grow)
    }
    
    // Update rotation
    element.rotation += dt * 30 // 30 degrees per second
    if element.rotation > 360.0 {
        element.rotation -= 360.0
    }
}

update_text_color :: proc(element: ^TextElement, dt: f64) {
    switch element.color_mode {
    case .STATIC:
        element.current_color = element.base_color
        
    case .HSV_CYCLE:
        element.color_hue += element.color_speed * dt * 60
        if element.color_hue > 360.0 {
            element.color_hue -= 360.0
        }
        element.current_color = rl.ColorFromHSV(f32(element.color_hue), 1.0, 1.0)
        
    case .RAINBOW_WAVE:
        time := rl.GetTime()
        hue := math.sin(time * element.color_speed) * 180 + 180
        element.current_color = rl.ColorFromHSV(f32(hue), 0.8, 1.0)
        
    case .BRIGHTNESS_PULSE:
        time := rl.GetTime()
        brightness := math.sin(time * element.color_speed) * 0.3 + 0.7
        element.current_color = rl.ColorBrightness(element.base_color, f32(brightness))
    }
    
    // Apply hover brightness
    if element.is_hovered {
        element.current_color = rl.ColorBrightness(element.current_color, 0.2)
    }
}

// Text element rendering
draw_text_element :: proc(element: ^TextElement) {
    // Calculate scaled position to maintain center
    text_size := rl.MeasureTextEx(rl.GetFontDefault(), element.text, element.font_size, 1)
    scaled_size := rl.Vector2{text_size.x * element.scale, text_size.y * element.scale}
    
    draw_pos := rl.Vector2{
        element.position.x + (text_size.x - scaled_size.x) / 2,
        element.position.y + (text_size.y - scaled_size.y) / 2,
    }
    
    // Draw with rotation if needed
    if element.rotation != 0.0 {
        origin := rl.Vector2{scaled_size.x / 2, scaled_size.y / 2}
        center_pos := rl.Vector2{draw_pos.x + origin.x, draw_pos.y + origin.y}
        
        rl.DrawTextPro(
            rl.GetFontDefault(),
            element.text,
            center_pos,
            origin,
            f32(element.rotation),
            element.font_size * element.scale,
            1,
            element.current_color
        )
    } else {
        rl.DrawTextEx(
            rl.GetFontDefault(),
            element.text,
            draw_pos,
            element.font_size * element.scale,
            1,
            element.current_color
        )
    }
}

TextManager :: struct {
    elements: [dynamic]TextElement,
    config:   Config,
}

make_text_manager :: proc(config: Config = DEFAULT_CONFIG) -> TextManager {
    return TextManager{
        elements = make([dynamic]TextElement),
        config = config,
    }
}

add_text :: proc(manager: ^TextManager, element: TextElement) -> ^TextElement {
    append(&manager.elements, element)
    return &manager.elements[len(manager.elements) - 1]
}

update_text_manager :: proc(manager: ^TextManager) {
    dt := rl.GetFrameTime()
    for &element in manager.elements {
        update_text_element(&element, f64(dt))
    }
}

draw_text_manager :: proc(manager: ^TextManager) {
    for &element in manager.elements {
        draw_text_element(&element)
    }
    
    if manager.config.debug_mode {
        draw_debug_info(manager)
    }
}

draw_debug_info :: proc(manager: ^TextManager) {
    y_offset: i32 = 10
    for &element, i in manager.elements {
        debug_text := fmt.ctprintf(
            "[%d] H:%v C:%v S:%.2f R:%.1f", 
            i,
            element.is_hovered, 
            element.is_clicked, 
            element.scale,
            element.rotation
        )
        rl.DrawText(debug_text, 10, y_offset, 16, rl.GRAY)
        y_offset += 20
    }
}

cleanup_text_manager :: proc(manager: ^TextManager) {
    delete(manager.elements)
}