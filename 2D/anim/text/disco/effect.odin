package disco

import "core:fmt"
import "core:math/rand"
import "core:strings"
import rl "vendor:raylib"

// Configuration for disco text effects
Config :: struct {
    text:              string,
    position:          rl.Vector2,
    font_size:         f32,
    base_color:        rl.Color,
    highlight_color:   rl.Color,
    sparkle_interval:  f32,
    highlight_chance:  int, // 1 in N chance of highlighting
    font:              rl.Font,
}

// State of disco text animation
State :: struct {
    config:            Config,
    sparkle_timer:     f32,
    is_highlighting:   bool,
}

// Create new disco text with default config
create :: proc(text: string, position: rl.Vector2, font_size: f32 = 50) -> State {
    return State{
        config = Config{
            text = text,
            position = position,
            font_size = font_size,
            base_color = rl.YELLOW,
            highlight_color = rl.GOLD,
            sparkle_interval = 0.1,
            highlight_chance = 5, // 1 in 5 chance
            font = rl.GetFontDefault(),
        },
        sparkle_timer = 0.0,
        is_highlighting = false,
    }
}

// Create disco text with custom config
create_custom :: proc(config: Config) -> State {
    return State{
        config = config,
        sparkle_timer = 0.0,
        is_highlighting = false,
    }
}

// Update disco text animation
update :: proc(disco: ^State, delta_time: f32) {
    disco.sparkle_timer += delta_time
    
    if disco.sparkle_timer >= disco.config.sparkle_interval {
        disco.sparkle_timer = 0.0
        disco.is_highlighting = rand.int_max(disco.config.highlight_chance) == 0
    }
}

// Draw disco text (centered at position)
draw_centered :: proc(disco: ^State) {
    current_color := disco.is_highlighting ? disco.config.highlight_color : disco.config.base_color
    c_text := fmt.ctprintf("%s", disco.config.text)
    text_size := rl.MeasureTextEx(disco.config.font, c_text, disco.config.font_size, 1)
    centered_position := rl.Vector2{
        disco.config.position.x - text_size.x / 2,
        disco.config.position.y - text_size.y / 2,
    }
    
    rl.DrawTextEx(disco.config.font, c_text, centered_position, disco.config.font_size, 1, current_color)
}

// Draw disco text at exact position (top-left corner)
draw :: proc(disco: ^State) {
    current_color := disco.is_highlighting ? disco.config.highlight_color : disco.config.base_color
    rl.DrawTextEx(disco.config.font, fmt.ctprintf("%s", disco.config.text), disco.config.position, disco.config.font_size, 1, current_color)
}

// Set disco text colors
set_colors :: proc(disco: ^State, base: rl.Color, highlight: rl.Color) {
    disco.config.base_color = base
    disco.config.highlight_color = highlight
}

// Set sparkle timing
set_timing :: proc(disco: ^State, interval: f32, chance: int) {
    disco.config.sparkle_interval = interval
    disco.config.highlight_chance = chance
}

// Get current color (useful for custom drawing)
get_current_color :: proc(disco: ^State) -> rl.Color {
    return disco.is_highlighting ? disco.config.highlight_color : disco.config.base_color
}

// Set custom font
set_font :: proc(disco: ^State, font: rl.Font) {
    disco.config.font = font
}

// Update text content
set_text :: proc(disco: ^State, text: string) {
    disco.config.text = text
}

// Update position
set_position :: proc(disco: ^State, position: rl.Vector2) {
    disco.config.position = position
}