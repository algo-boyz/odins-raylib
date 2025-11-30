package scroll

import rl "vendor:raylib"
import "core:strings"
import "core:fmt"

ScrollText :: struct {
    text:               string,
    current_char_index: i32,
    timer:              f32,
    char_delay:         f32,
    is_complete:        bool,
}

ScrollTextConfig :: struct {
    text:       string,
    char_delay: f32,
}

// Create a new ScrollText instance
create :: proc(config: ScrollTextConfig) -> ScrollText {
    return ScrollText{
        text = config.text,
        current_char_index = 0,
        timer = 0.0,
        char_delay = config.char_delay,
        is_complete = false,
    }
}

// Update the scroll text animation
update :: proc(scroll_text: ^ScrollText, delta_time: f32) {
    if scroll_text.is_complete do return
    
    scroll_text.timer += delta_time
    
    if scroll_text.current_char_index < i32(len(scroll_text.text)) && 
       scroll_text.timer >= scroll_text.char_delay {
        scroll_text.current_char_index += 1
        scroll_text.timer = 0.0
        
        if scroll_text.current_char_index >= i32(len(scroll_text.text)) {
            scroll_text.is_complete = true
        }
    }
}

// Reset the scroll text to beginning
reset :: proc(scroll_text: ^ScrollText) {
    scroll_text.current_char_index = 0
    scroll_text.timer = 0.0
    scroll_text.is_complete = false
}

// Set the animation speed
set_speed :: proc(scroll_text: ^ScrollText, char_delay: f32) {
    scroll_text.char_delay = max(char_delay, 0.01)
}

// Get the currently displayed text
get_displayed_text :: proc(scroll_text: ScrollText) -> string {
    if scroll_text.current_char_index <= 0 do return ""
    return scroll_text.text[:scroll_text.current_char_index]
}

// Check if animation is complete
is_complete :: proc(scroll_text: ScrollText) -> bool {
    return scroll_text.is_complete
}

// Get progress as percentage (0.0 to 1.0)
get_progress :: proc(scroll_text: ScrollText) -> f32 {
    if len(scroll_text.text) == 0 do return 1.0
    return f32(scroll_text.current_char_index) / f32(len(scroll_text.text))
}

// Draw simple scroll text at position
draw :: proc(scroll_text: ScrollText, position: rl.Vector2, font_size: i32, color: rl.Color) {
    displayed_text := get_displayed_text(scroll_text)
    if len(displayed_text) == 0 do return
    
    displayed_cstring := strings.clone_to_cstring(displayed_text)
    defer delete(displayed_cstring)
    
    rl.DrawText(displayed_cstring, i32(position.x), i32(position.y), font_size, color)
}

// Draw scroll text with word wrapping
draw_wrapped :: proc(scroll_text: ScrollText, position: rl.Vector2, font_size: i32, color: rl.Color, max_width: i32) {
    displayed_text := get_displayed_text(scroll_text)
    if len(displayed_text) == 0 do return
    
    draw_wrapped_text(displayed_text, position, font_size, color, max_width)
}

// Draw scroll text with blinking cursor
draw_with_cursor :: proc(scroll_text: ScrollText, position: rl.Vector2, font_size: i32, color: rl.Color, max_width: i32) {
    displayed_text := get_displayed_text(scroll_text)
    
    if len(displayed_text) > 0 {
        draw_wrapped_text(displayed_text, position, font_size, color, max_width)
    }
    // Draw blinking cursor if not complete
    if !scroll_text.is_complete {
        cursor_timer := rl.GetTime()
        if int(cursor_timer * 2) % 2 == 0 {
            // Calculate cursor position (simplified)
            cursor_pos := calculate_cursor_position(displayed_text, position, font_size, max_width)
            rl.DrawText("_", i32(cursor_pos.x), i32(cursor_pos.y), font_size, color)
        }
    }
}

// Draw wrapped text with word wrap logic that handles line breaks
draw_wrapped_text :: proc(text: string, position: rl.Vector2, font_size: i32, color: rl.Color, max_width: i32) {
    words := strings.split(text, " ")
    defer delete(words)
    
    current_line := ""
    y_offset: f32 = 0
    line_height := f32(font_size + 5)
    
    for word in words {
        test_line := current_line
        if len(current_line) > 0 {
            test_line = strings.concatenate({current_line, " ", word})
        } else {
            test_line = word
        }
        test_cstring := strings.clone_to_cstring(test_line)
        text_width := rl.MeasureText(test_cstring, font_size)
        delete(test_cstring)
        
        if text_width > max_width && len(current_line) > 0 {
            // Draw current line and start new one
            line_cstring := strings.clone_to_cstring(current_line)
            rl.DrawText(line_cstring, i32(position.x), i32(position.y + y_offset), font_size, color)
            delete(line_cstring)
            
            current_line = word
            y_offset += line_height
        } else {
            current_line = test_line
        }
    }
    // Draw the last line
    if len(current_line) > 0 {
        line_cstring := strings.clone_to_cstring(current_line)
        rl.DrawText(line_cstring, i32(position.x), i32(position.y + y_offset), font_size, color)
        delete(line_cstring)
    }
}

// Calculate cursor position based on current text and font size
calculate_cursor_position :: proc(text: string, position: rl.Vector2, font_size: i32, max_width: i32) -> rl.Vector2 {
    words := strings.split(text, " ")
    defer delete(words)
    
    current_line := ""
    y_offset: f32 = 0
    line_height := f32(font_size + 5)
    
    for word in words {
        test_line := current_line
        if len(current_line) > 0 {
            test_line = strings.concatenate({current_line, " ", word})
        } else {
            test_line = word
        }
        test_cstring := strings.clone_to_cstring(test_line)
        text_width := rl.MeasureText(test_cstring, font_size)
        delete(test_cstring)
        
        if text_width > max_width && len(current_line) > 0 {
            current_line = word
            y_offset += line_height
        } else {
            current_line = test_line
        }
    }
    // Get width of current line for cursor position
    line_cstring := strings.clone_to_cstring(current_line)
    line_width := rl.MeasureText(line_cstring, font_size)
    delete(line_cstring)
    
    return {position.x + f32(line_width), position.y + y_offset}
}