package typewriter

import "core:strings"
import "core:unicode/utf8"
import "core:fmt"
import "core:math"
import rl "vendor:raylib"

// Configuration for typewriter animation
TypewriterConfig :: struct {
    chars_per_second:    f32,    // Animation speed
    glow_intensity:      f32,    // Glow effect intensity (0.0 - 1.0)
    glow_radius:         f32,    // Glow radius multiplier
    sound_enabled:       bool,   // Whether to play typing sounds
    skip_space_sounds:   bool,   // Skip sounds for space characters
}

// Individual typewriter instance
Typewriter :: struct {
    strings:             []string,
    current_string:      i32,
    current_char:        i32,
    total_chars_shown:   i32,
    animation_timer:     f32,
    x_pos:               i32,
    y_pos:               i32,
    line_height:         i32,
    font_size:           i32,
    text_color:          rl.Color,
    glow_color:          rl.Color,
    sound:               rl.Sound,
    config:              TypewriterConfig,
    is_complete:         bool,
    glow_pulse_timer:    f32,    // For pulsing glow effect
}

// Default configuration
DEFAULT_TYPEWRITER_CONFIG :: TypewriterConfig{
    chars_per_second = 15.0,
    glow_intensity = 0.8,
    glow_radius = 1.5,
    sound_enabled = true,
    skip_space_sounds = true,
}

// Initialize a typewriter instance
init_typewriter :: proc(strings: []string, x, y, font_size: i32, text_color, glow_color: rl.Color, sound: rl.Sound, config: TypewriterConfig) -> Typewriter {
    return Typewriter{
        strings = strings,
        current_string = 0,
        current_char = 0,
        total_chars_shown = 0,
        animation_timer = 0.0,
        x_pos = x,
        y_pos = y,
        line_height = font_size + 5,
        font_size = font_size,
        text_color = text_color,
        glow_color = glow_color,
        sound = sound,
        config = config,
        is_complete = false,
        glow_pulse_timer = 0.0,
    }
}

// Update typewriter animation
update_typewriter :: proc(tw: ^Typewriter, delta_time: f32) {
    if tw.is_complete do return
    
    tw.animation_timer += delta_time
    tw.glow_pulse_timer += delta_time * 3.0 // Faster pulse for glow
    
    chars_per_frame := tw.config.chars_per_second * delta_time
    
    if tw.animation_timer >= (1.0 / tw.config.chars_per_second) {
        tw.animation_timer = 0.0
        
        if tw.current_string < i32(len(tw.strings)) {
            current_text := tw.strings[tw.current_string]
            
            if tw.current_char < i32(len(current_text)) {
                // Play sound for non-space characters
                if tw.config.sound_enabled {
                    char_to_check := current_text[tw.current_char]
                    if !tw.config.skip_space_sounds || char_to_check != ' ' {
                        rl.PlaySound(tw.sound)
                    }
                }
                
                tw.current_char += 1
                tw.total_chars_shown += 1
            } else {
                // Move to next string
                tw.current_string += 1
                tw.current_char = 0
                
                // Check if we've completed all strings
                if tw.current_string >= i32(len(tw.strings)) {
                    tw.is_complete = true
                }
            }
        }
    }
}

// Draw completed text with glow effect on the last visible character
draw_typewriter :: proc(tw: ^Typewriter) {
    if len(tw.strings) == 0 do return
    
    current_y := tw.y_pos
    chars_drawn := 0
    
    // Draw each string
    for string_idx in 0..<len(tw.strings) {
        if i32(string_idx) > tw.current_string do break
        
        current_text := tw.strings[string_idx]
        chars_to_draw := len(current_text)
        
        // For the current string being typed, limit characters
        if i32(string_idx) == tw.current_string {
            chars_to_draw = int(tw.current_char)
        }
        
        if chars_to_draw > 0 {
            // Get substring to display
            text_to_draw := current_text[:chars_to_draw]
            c_string := strings.clone_to_cstring(text_to_draw)
            defer delete(c_string)
            
            // Draw main text
            rl.DrawText(c_string, tw.x_pos, current_y, tw.font_size, tw.text_color)
            
            // Draw glow effect on the last character if this is the current string being typed
            if i32(string_idx) == tw.current_string && chars_to_draw > 0 && !tw.is_complete {
                draw_glow_effect(tw, text_to_draw, current_y)
            }
        }
        
        current_y += tw.line_height
        chars_drawn += chars_to_draw
    }
}

// Draw glowing effect on the last character
draw_glow_effect :: proc(tw: ^Typewriter, text: string, y_pos: i32) {
    if len(text) == 0 do return
    
    // Calculate position of the last character
    text_width := rl.MeasureText(strings.clone_to_cstring(text), tw.font_size)
    last_char := text[len(text)-1:]
    last_char_width := rl.MeasureText(strings.clone_to_cstring(last_char), tw.font_size)
    
    last_char_x := tw.x_pos + text_width - last_char_width
    
    // Create pulsing glow effect
    pulse_factor := (math.sin(tw.glow_pulse_timer) + 1.0) * 0.5 // 0.0 to 1.0
    glow_alpha := u8(tw.config.glow_intensity * pulse_factor * 255.0)
    
    // Create glow color with varying alpha
    glow_color_pulsing := rl.Color{
        tw.glow_color.r,
        tw.glow_color.g,
        tw.glow_color.b,
        glow_alpha,
    }
    
    // Draw multiple layers for glow effect
    glow_layers := 3
    for i in 1..=glow_layers {
        layer_alpha := glow_alpha / u8(i * 2)
        layer_size := i32(f32(tw.font_size) * (1.0 + f32(i) * tw.config.glow_radius * 0.1))
        
        layer_color := rl.Color{
            tw.glow_color.r,
            tw.glow_color.g,
            tw.glow_color.b,
            layer_alpha,
        }
        
        // Draw slightly larger text for glow layers
        rl.DrawText(
            strings.clone_to_cstring(last_char),
            last_char_x - i32(i),
            y_pos,
            layer_size,
            layer_color
        )
        rl.DrawText(
            strings.clone_to_cstring(last_char),
            last_char_x + i32(i),
            y_pos,
            layer_size,
            layer_color
        )
        rl.DrawText(
            strings.clone_to_cstring(last_char),
            last_char_x,
            y_pos - i32(i),
            layer_size,
            layer_color
        )
        rl.DrawText(
            strings.clone_to_cstring(last_char),
            last_char_x,
            y_pos + i32(i),
            layer_size,
            layer_color
        )
    }
    
    // Draw the bright center character
    bright_color := rl.Color{
        min(255, tw.glow_color.r + u8(pulse_factor * 100)),
        min(255, tw.glow_color.g + u8(pulse_factor * 100)),
        min(255, tw.glow_color.b + u8(pulse_factor * 100)),
        255,
    }
    
    rl.DrawText(
        strings.clone_to_cstring(last_char),
        last_char_x,
        y_pos,
        tw.font_size,
        bright_color
    )
}

// Check if typewriter animation is complete
is_typewriter_complete :: proc(tw: ^Typewriter) -> bool {
    return tw.is_complete
}

// Reset typewriter to start animation again
reset_typewriter :: proc(tw: ^Typewriter) {
    tw.current_string = 0
    tw.current_char = 0
    tw.total_chars_shown = 0
    tw.animation_timer = 0.0
    tw.glow_pulse_timer = 0.0
    tw.is_complete = false
}