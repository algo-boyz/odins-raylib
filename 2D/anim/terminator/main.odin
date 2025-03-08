package main

import "core:strings"
import "core:unicode/utf8"
import "core:fmt"
import rl "vendor:raylib"

StrData :: struct {
    strings:             []string,
    number_of_strings_drawn: i32,
    number_of_strings:   i32,
    current_index:       i32,
    frames_counter:      i32,
    last_index:          i32,
    x_pos:               i32,
    y_pos:               i32,
    y_pos_start:         i32,
    size_text:           i32,
    color:               rl.Color,
    sound:               rl.Sound,
}

screen_width :: 1280
screen_height :: 720

get_remaining_chars :: proc(text: string, current_fps, current_frame_counter: i32, current_string_index, last_index: ^i32) -> i32 {
    size_string := len(text)
    current_string_index^ = current_frame_counter / 10
    last_index^ = i32(size_string) - current_string_index^
    return last_index^
}

check_if_character_is :: proc(str: string, character: rune, index_string: int) -> bool {
    if len(str) > 0 && index_string < len(str) {
        r, _ := utf8.decode_rune(transmute([]u8)str[index_string:])
        return r == character
    }
    return false
}

draw_all_strings :: proc(string_data: ^StrData) -> i32 {
    for i:i32; i < string_data.number_of_strings; i += 1 {
        rl.DrawText(
            strings.clone_to_cstring(string_data.strings[i]), 
            i32(string_data.x_pos), 
            i32(string_data.y_pos_start + (i * string_data.size_text)), 
            i32(string_data.size_text), 
            string_data.color
        )
    }
    return 0
}

draw_sequence_of_strings :: proc(string_data: ^StrData, color: rl.Color, size_text: i32) -> i32 {
    // Check if we've completed all strings
    if string_data.number_of_strings_drawn >= string_data.number_of_strings {
        return 0
    }
    if string_data.last_index != 0 {
        string_data.frames_counter += 2
        subtext := rl.TextSubtext(
            strings.clone_to_cstring(string_data.strings[string_data.number_of_strings_drawn]), 
            0, 
            i32(string_data.frames_counter / 10)
        )
        rl.DrawText(
            subtext, 
            i32(string_data.x_pos), 
            i32(string_data.y_pos), 
            i32(size_text), 
            color
        )
        last_index: i32
        current_index: i32
        remaining_chars := get_remaining_chars(
            string_data.strings[string_data.number_of_strings_drawn], 
            rl.GetFPS(), 
            string_data.frames_counter, 
            &current_index, 
            &last_index
        )
        string_data.current_index = current_index
        string_data.last_index = last_index
        // Only play sound when adding a new non empty (SPACE) character (every 10 frames)
        current_char_index := string_data.frames_counter / 10
        current_string := string_data.strings[string_data.number_of_strings_drawn]
        if string_data.frames_counter % 10 == 0 && current_char_index > 0 && current_char_index <= i32(len(current_string)) {
            // Get the actual character at the current index
            if current_char_index - 1 < i32(len(current_string)) {
                if current_string[current_char_index - 1] != ' ' {
                    rl.PlaySound(string_data.sound)
                }
            }
        }
        if remaining_chars == 0 {
            string_data.number_of_strings_drawn += 1
            string_data.last_index = -1
            string_data.frames_counter = 0
            string_data.y_pos += size_text
        }
    }
    // Draw completed strings
    for i:i32; i < string_data.number_of_strings_drawn; i += 1 {
        rl.DrawText(
            strings.clone_to_cstring(string_data.strings[i]), 
            i32(string_data.x_pos), 
            i32(string_data.y_pos_start + (i * size_text)), 
            i32(size_text), 
            color
        )
    }
    // Return 0 if all strings have been drawn, -1 otherwise
    if string_data.number_of_strings_drawn == string_data.number_of_strings {
        return 0
    }
    return -1
}

main :: proc() {    
    rl.InitWindow(screen_width, screen_height, "T-800")
    rl.SetTargetFPS(60)

    bg := rl.LoadImage("assets/terminator.jpg")
    rl.ImageResize(&bg, screen_width, screen_height)
    tex := rl.LoadTextureFromImage(bg)
    rl.UnloadImage(bg)

    rl.InitAudioDevice()
    fx_ogg := rl.LoadSound("assets/terminal.ogg")

    frames_counter := 0

    status     := "LOADING TRAJECTORY:"
    empty      := "********************"
    location   := "5430 543 7980 10930                          3430 343 3430"
    objective  := "PRIORITY OVERRIDE                         MULTI TARGET"
    information := []string{status, empty, location, objective}
    details := []string{"THREAT ASSESSMENT", "SELECT ALL", "TERMINATION OVERRIDE", "TARGETS ONLY"}
    
    arr := []StrData{
        StrData{
            strings = information,
            number_of_strings = i32(len(information)),
            last_index = -1,
            x_pos = 110,
            y_pos = 100,
            y_pos_start = 100,
            current_index = -1,
            color = rl.RAYWHITE,
            size_text = 30,
            sound = fx_ogg,
        }, 
        StrData{
            strings = details,
            number_of_strings = i32(len(details)),
            last_index = -1,
            x_pos = 110,
            y_pos = 540,
            y_pos_start = 540,
            current_index = -1,
            color = rl.GREEN,
            size_text = 30,
            sound = fx_ogg,
        }
    }
    for !rl.WindowShouldClose() {
        rl.BeginDrawing()
        rl.ClearBackground(rl.BLACK)
        rl.DrawTexture(tex, 0, 0, rl.WHITE)
        if draw_sequence_of_strings(&arr[0], rl.RAYWHITE, 30) == 0 {
            draw_all_strings(&arr[0])
            if draw_sequence_of_strings(&arr[1], rl.GREEN, 30) == 0 {
                draw_all_strings(&arr[0])
                draw_all_strings(&arr[1])
            }
        }
        rl.EndDrawing()
    }
    rl.UnloadSound(fx_ogg)
    rl.CloseAudioDevice()
    rl.CloseWindow()
}