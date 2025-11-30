package main

import "base:runtime"
import "core:fmt"
import "core:log"
import "core:math/rand"
import "core:strings"
import "core:time"
import "core:unicode/utf8"

import rl "vendor:raylib"

import "../../../rlutil/gif"

TYPE_EFFECT_SPEED :: 5     // Much faster typing (was 17)
JUMBLE_SECONDS    :: 4     // Slightly longer jumble phase for drama
JUMBLE_LOOP_SPEED :: 25    // Faster jumbling for more frenetic feel
REVEAL_LOOP_SPEED :: 45    // Slightly faster reveal

auto_decrypt := true  // Skip manual input for movie authenticity
mask_blank   := true
color_on     := true  
fg   := rl.BLUE      // Classic green terminal color like in Sneakers

rng: runtime.Random_Generator

// ASCII-only character table for better font compatibility
// Focuses on characters that look "computery" and decrypt-like
CHAR_COUNT :: 94
charTable := [CHAR_COUNT]cstring{
    "!", "\"", "#", "$", "%", "&", "'", "(", ")", "*", "+", ",", "-", ".",
    "/", ":", ";", "<", "=", ">", "?", "@", "[", "\\", "]", "^", "_", "`",
    "{", "|", "}", "~",
    "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M",
    "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z",
    "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m",
    "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z",
    "0", "1", "2", "3", "4", "5", "6", "7", "8", "9",
}

get_rand_char :: proc() -> cstring {
    return charTable[u64(rand.float32_range(0, CHAR_COUNT, rng))]
}

CharAttr :: struct {
    source: cstring,
    mask: cstring,
    is_space: bool,
    reveal_time: int,
    x, y: int,
    width: int,
}

EffectState :: enum {
    TYPING,
    WAIT_INPUT,
    JUMBLING,
    REVEALING,
    DONE,
}

curr_effect_state: EffectState = .TYPING
typing_char_idx: int
typing_timer: int
jumble_timer: int
jumble_update_timer: int
reveal_timer: int
flash_timer: int      // New: for screen flash effects
screen_flash: bool    // New: flash state

WIDTH  :: 800
HEIGHT :: 600
font_size :: 20
font: rl.Font
nms: [dynamic]CharAttr

effect_set_fg_color :: proc(color_name: string) {
    switch color_name {
    case "white":   fg = rl.WHITE
    case "yellow":  fg = rl.YELLOW
    case "magenta": fg = rl.MAGENTA
    case "blue":    fg = rl.BLUE
    case "green":   fg = rl.GREEN
    case "red":     fg = rl.RED
    case "cyan":    fg = rl.SKYBLUE
    case:           fg = rl.GREEN // Default to classic green
    }
}

prepare_display_chars :: proc(input_string: string, avg_char_width: int) {
    delete(nms)
    nms = make([dynamic]CharAttr, len(input_string))

    curr_char_col: int
    curr_char_row: int

    lines := strings.split(input_string, "\n")
    total_content_height := len(lines) * font_size
    start_y_offset := (HEIGHT - total_content_height) / 2

    for r in input_string {
        char_str := fmt.ctprintf("%c", r)
        if char_str == "\n" {
            curr_char_row += 1
            curr_char_col = 0
            continue
        }
        
        px_x := curr_char_col * avg_char_width
        px_y := start_y_offset + (curr_char_row * font_size)
        char_px_width := int(rl.MeasureTextEx(font, char_str, f32(font_size), 0).x)

        is_space_char_for_masking := char_str == " "
        
        // More dramatic reveal timing - some chars reveal very quickly, others take longer
        reveal_base := int(rand.float32_range(500, 6000, rng))
        // Add some clustering - chars near each other tend to reveal closer in time
        cluster_offset := int(rand.float32_range(-200, 200, rng))
        reveal_time := max(0, reveal_base + cluster_offset)
        
        attr := CharAttr{
            source      = char_str,
            mask        = get_rand_char(),
            is_space    = is_space_char_for_masking && !mask_blank,
            reveal_time = reveal_time,
            x           = px_x,
            y           = px_y,
            width       = char_px_width,
        }
        append(&nms, attr)
        curr_char_col += 1
    }
}

main :: proc() {

    seed := rand.create(u64(time.now()._nsec))
    rng  = rand.default_random_generator(&seed)

    rec := gif.new_recorder("preview.gif", 12, 600)
    defer gif.recorder_cleanup(&rec)
    rl.InitWindow(WIDTH, HEIGHT, "SNEAKERS - Decryption Sequence")
    defer rl.CloseWindow()
    rl.SetTargetFPS(60)
    
    font = rl.LoadFontEx("../../../fonts/JetBrainsMono-Regular.ttf", font_size, nil, 0)
    if font.texture.id == 0 {
        log.warn("Could not load JetBrainsMono-Regular.ttf. Using default font.")
        font = rl.GetFontDefault()
    }
    defer rl.UnloadFont(font)

    avg_char_width := int(rl.MeasureTextEx(font, "M", f32(font_size), 0).x)
    term_cols_approx := WIDTH / avg_char_width

    // More authentic 1992 computer system text
    head1_left     := "SETEC ASTRONOMY SECURE TERMINAL"
    head1_right    := "Node: 7734-Alpha"
    head2_center   := "CLASSIFIED ACCESS LEVEL 7"
    head3_center   := "Federal Reserve Wire Transfer Protocol"
    head4_center   := "========== DECRYPTION IN PROGRESS =========="
    head5_center   := "ACCESSING ENCRYPTED FINANCIAL RECORDS..."
    
    // More realistic 1992-style menu options
    menu1          := ">> Initiating cryptographic key exchange"
    menu2          := ">> Bypassing authentication protocols" 
    menu3          := ">> Establishing secure channel: Port 2048"
    menu4          := ">> Downloading transaction records..."
    menu5          := ">> Verifying digital signatures"
    menu6          := ">> Decrypting payload data streams"
    
    foot1_center   := "CAUTION: UNAUTHORIZED ACCESS DETECTED"
    foot2_center   := "TRACE INITIATED - CONNECTION WILL BE SEVERED"

    display_builder := strings.builder_make()

    // Build the display text
    strings.write_string(&display_builder, head1_left)
    runes_needed_line1 := term_cols_approx - utf8.rune_count_in_string(head1_left) - utf8.rune_count_in_string(head1_right)
    for i := 0; i < runes_needed_line1; i += 1 {
        strings.write_byte(&display_builder, ' ')
    }
    strings.write_string(&display_builder, head1_right)
    strings.write_string(&display_builder, "\n\n")

    center_and_append :: proc(builder: ^strings.Builder, text: string, total_cols: int) {
        text_len := utf8.rune_count_in_string(text)
        runes := (total_cols - text_len) / 2
        for i := 0; i < runes; i += 1 {
            strings.write_byte(builder, ' ')
        }
        strings.write_string(builder, text)
        strings.write_string(builder, "\n")
    }

    center_and_append(&display_builder, head2_center, term_cols_approx)
    strings.write_string(&display_builder, "\n")
    center_and_append(&display_builder, head3_center, term_cols_approx)
    strings.write_string(&display_builder, "\n")
    center_and_append(&display_builder, head4_center, term_cols_approx)
    center_and_append(&display_builder, head5_center, term_cols_approx)
    strings.write_string(&display_builder, "\n")

    base_indent_chars := 2

    indent_and_append :: proc(builder: ^strings.Builder, text: string, indent_chars: int) {
        for i := 0; i < indent_chars; i += 1 {
            strings.write_byte(builder, ' ')
        }
        strings.write_string(builder, text)
        strings.write_string(builder, "\n")
    }
    
    indent_and_append(&display_builder, menu1, base_indent_chars)
    indent_and_append(&display_builder, menu2, base_indent_chars)
    indent_and_append(&display_builder, menu3, base_indent_chars)
    indent_and_append(&display_builder, menu4, base_indent_chars)
    indent_and_append(&display_builder, menu5, base_indent_chars)
    indent_and_append(&display_builder, menu6, base_indent_chars)
    strings.write_string(&display_builder, "\n")

    center_and_append(&display_builder, foot1_center, term_cols_approx)
    strings.write_string(&display_builder, "\n")
    center_and_append(&display_builder, foot2_center, term_cols_approx)

    prepare_display_chars(strings.clone_from_bytes(display_builder.buf[:]), avg_char_width)

    for !rl.WindowShouldClose() {
                gif.recorder_update(&rec)

        delta_ms := int(rl.GetFrameTime() * 1000)
        
        // Handle screen flash timing
        flash_timer += delta_ms
        if flash_timer >= 100 { // Flash every 100ms during jumbling
            screen_flash = !screen_flash
            flash_timer = 0
        }
        
        rl.BeginDrawing()
        
        // Dynamic background color for more dramatic effect
        bg_color := rl.BLACK
        if curr_effect_state == .JUMBLING && screen_flash {
            bg_color = rl.Color{5, 5, 15, 255} // Very dark blue flash
        }
        rl.ClearBackground(bg_color)

        switch curr_effect_state {
        case .TYPING:
            typing_timer += delta_ms
            for typing_timer >= TYPE_EFFECT_SPEED {
                if typing_char_idx < len(nms) {
                    typing_char_idx += 1
                    typing_timer -= TYPE_EFFECT_SPEED
                } else {
                    // Skip WAIT_INPUT for movie authenticity - go straight to jumbling
                    curr_effect_state = .JUMBLING
                    jumble_timer = 0
                    jumble_update_timer = 0
                    break
                }
            }
            
            for i := 0; i < typing_char_idx; i += 1 {
                char_attr := &nms[i]
                if char_attr.is_space {
                    rl.DrawTextEx(font, char_attr.source, rl.Vector2{f32(char_attr.x), f32(char_attr.y)}, f32(font_size), 0, rl.WHITE)
                } else {
                    rl.DrawTextEx(font, char_attr.mask, rl.Vector2{f32(char_attr.x), f32(char_attr.y)}, f32(font_size), 0, rl.WHITE)
                }
            }

        case .WAIT_INPUT:
            // This state is now skipped, but keeping for completeness
            for char_attr_ptr in nms {
                char_attr := char_attr_ptr
                if char_attr.is_space {
                    rl.DrawTextEx(font, char_attr.source, rl.Vector2{f32(char_attr.x), f32(char_attr.y)}, f32(font_size), 0, rl.WHITE)
                } else {
                    rl.DrawTextEx(font, char_attr.mask, rl.Vector2{f32(char_attr.x), f32(char_attr.y)}, f32(font_size), 0, rl.WHITE)
                }
            }

        case .JUMBLING:
            jumble_timer += delta_ms
            jumble_update_timer += delta_ms
            
            if jumble_update_timer >= JUMBLE_LOOP_SPEED {
                jumble_update_timer -= JUMBLE_LOOP_SPEED
                for i := 0; i < len(nms); i += 1 {
                    char_attr := &nms[i]
                    if !char_attr.is_space {
                        char_attr.mask = get_rand_char()
                    }
                }
            }
            
            // Add intensity-based color variation during jumbling
            jumble_intensity := f32(jumble_timer) / f32(JUMBLE_SECONDS * 1000)
            mask_color := rl.WHITE
            if jumble_intensity > 0.7 {
                mask_color = rl.Color{255, 255, 200, 255} // Slight yellow tint as it gets intense
            }
            
            for char_attr_ptr in nms {
                char_attr := char_attr_ptr
                if char_attr.is_space {
                    rl.DrawTextEx(font, char_attr.source, rl.Vector2{f32(char_attr.x), f32(char_attr.y)}, f32(font_size), 0, rl.WHITE)
                } else {
                    rl.DrawTextEx(font, char_attr.mask, rl.Vector2{f32(char_attr.x), f32(char_attr.y)}, f32(font_size), 0, mask_color)
                }
            }
            
            if jumble_timer >= (JUMBLE_SECONDS * 1000) {
                curr_effect_state = .REVEALING
                reveal_timer = 0
            }

        case .REVEALING:
            reveal_timer += delta_ms
            
            if reveal_timer >= REVEAL_LOOP_SPEED {
                reveal_timer -= REVEAL_LOOP_SPEED
                for i := 0; i < len(nms); i += 1 {
                    char_attr := &nms[i]
                    if char_attr.is_space {
                        continue
                    }
                    
                    if char_attr.reveal_time > 0 {
                        // More aggressive mask changing as reveal approaches
                        change_probability := 3
                        if char_attr.reveal_time < 1000 {
                            change_probability = 2  // Change more frequently
                        }
                        if char_attr.reveal_time < 300 {
                            change_probability = 1  // Change almost every frame
                        }
                        
                        if int(rand.float32_range(0, f32(change_probability + 1), rng)) == 0 {
                            char_attr.mask = get_rand_char()
                        }
                        
                        char_attr.reveal_time -= REVEAL_LOOP_SPEED
                        if char_attr.reveal_time < 0 {
                            char_attr.reveal_time = 0
                        }
                    }
                }
            }
            
            revealed_count: int
            for char_attr_ptr in nms {
                char_attr := char_attr_ptr
                if char_attr.is_space {
                    rl.DrawTextEx(font, char_attr.source, rl.Vector2{f32(char_attr.x), f32(char_attr.y)}, f32(font_size), 0, rl.WHITE)
                    revealed_count += 1
                } else if char_attr.reveal_time > 0 {
                    // Still masked - add slight flicker to masks close to revealing
                    mask_color := rl.WHITE
                    if char_attr.reveal_time < 200 {
                        if int(rand.float32_range(0, 3, rng)) == 0 {
                            mask_color = rl.Color{200, 255, 200, 255} // Slight green tint
                        }
                    }
                    rl.DrawTextEx(font, char_attr.mask, rl.Vector2{f32(char_attr.x), f32(char_attr.y)}, f32(font_size), 0, mask_color)
                } else {
                    // Revealed
                    draw_color := rl.WHITE
                    if color_on {
                        draw_color = fg
                    }
                    rl.DrawTextEx(font, char_attr.source, rl.Vector2{f32(char_attr.x), f32(char_attr.y)}, f32(font_size), 0, draw_color)
                    revealed_count += 1
                }
            }
            
            if revealed_count == len(nms) {
                curr_effect_state = .DONE
            }

        case .DONE:
            for char_attr_ptr in nms {
                char_attr := char_attr_ptr
                draw_color := rl.WHITE
                if color_on && !char_attr.is_space {
                    draw_color = fg
                }
                rl.DrawTextEx(font, char_attr.source, rl.Vector2{f32(char_attr.x), f32(char_attr.y)}, f32(font_size), 0, draw_color)
            }
            // Add "DECRYPTION COMPLETE" message
            complete_text :: "DECRYPTION COMPLETE - ACCESS GRANTED"
            complete_width := rl.MeasureTextEx(font, complete_text, f32(font_size), 0).x
            rl.DrawTextEx(font, complete_text, rl.Vector2{f32(WIDTH/2) - complete_width/2, f32(HEIGHT - font_size*2)}, f32(font_size), 0, rl.GREEN)
        }
        rl.EndDrawing()
    }
}