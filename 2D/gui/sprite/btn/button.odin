package btn

import rl "vendor:raylib"

Btn_State :: enum {
    NORMAL = 0,
    HOVER  = 1,
    PRESSED = 2,
}

Btn :: struct {
    bounds:         rl.Rectangle,
    texture:        rl.Texture2D,
    sound:          rl.Sound,
    frame_height:   f32,
    state:          Btn_State,
    clicked:        bool,
    enabled:        bool,
    text:           cstring,
    text_color:     rl.Color,
    font_size:      i32,
}

// Init a button
init :: proc(texture: rl.Texture2D, sound: rl.Sound, x, y: f32, text: cstring = "") -> Btn {
    frame_height := f32(texture.height / 3)
    return Btn{
        bounds = rl.Rectangle{x, y, f32(texture.width), frame_height},
        texture = texture,
        sound = sound,
        frame_height = frame_height,
        state = .NORMAL,
        clicked = false,
        enabled = true,
        text = text,
        text_color = rl.BLACK,
        font_size = 20,
    }
}

// Update button state and handle input
update :: proc(button: ^Btn) {
    if !button.enabled {
        button.state = .NORMAL
        button.clicked = false
        return
    }
    mouse_point := rl.GetMousePosition()
    button.clicked = false
    
    if rl.CheckCollisionPointRec(mouse_point, button.bounds) {
        if rl.IsMouseButtonDown(rl.MouseButton.LEFT) {
            button.state = .PRESSED
        } else {
            button.state = .HOVER
        }
        if rl.IsMouseButtonReleased(rl.MouseButton.LEFT) {
            button.clicked = true
            if button.sound.frameCount > 0 {
                rl.PlaySound(button.sound)
            }
        }
    } else {
        button.state = .NORMAL
    }
}

// Draw the button
draw :: proc(button: ^Btn) {
    // Calculate source rectangle based on button state
    source_rec := rl.Rectangle{
        0, 
        f32(button.state) * button.frame_height, 
        f32(button.texture.width), 
        button.frame_height,
    }
    // Draw button texture
    tint := button.enabled ? rl.WHITE : rl.Color{200, 200, 200, 255}
    rl.DrawTextureRec(button.texture, source_rec, {button.bounds.x, button.bounds.y}, tint)
    // Draw text if provided
    if button.text != "" {
        text_width := rl.MeasureText(button.text, button.font_size)
        text_x := button.bounds.x + (button.bounds.width - f32(text_width)) / 2
        text_y := button.bounds.y + (button.bounds.height - f32(button.font_size)) / 2
        
        text_color := button.enabled ? button.text_color : rl.Color{100, 100, 100, 255}
        rl.DrawText(button.text, i32(text_x), i32(text_y), button.font_size, text_color)
    }
}

// Check if button was clicked this frame
is_clicked :: proc(button: ^Btn) -> bool {
    return button.clicked
}

// Set button enabled/disabled state
set_enabled :: proc(button: ^Btn, enabled: bool) {
    button.enabled = enabled
}

// Set button text properties
set_text :: proc(button: ^Btn, text: cstring, color: rl.Color = rl.BLACK, font_size: i32 = 20) {
    button.text = text
    button.text_color = color
    button.font_size = font_size
}