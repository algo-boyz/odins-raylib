package rlutil

import "core:fmt"
import "core:strings"
import rl "vendor:raylib"

default_escape_rune         :: '\\'
default_code_start_rune     :: '<'
default_code_end_rune       :: '>'
default_command_separator   :: ","
default_args_separator_rune :: ':'

// Escapes text by replacing code start runes with it's escaped version
text_escaped :: proc (text: string, allocator := context.allocator) -> (result: string, was_allocation: bool) {
    old := strings.builder_make(context.temp_allocator)
    fmt.sbprint(&old, default_code_start_rune)

    new := strings.builder_make(context.temp_allocator)
    fmt.sbprint(&new, default_escape_rune, default_code_start_rune, sep="")

    return strings.replace_all(text, strings.to_string(old), strings.to_string(new), allocator)
}

Text_Line :: struct {
    line:        cstring,
    line_height: f32,
    line_width:  f32,
    line_offset: f32,
}

// Splits text into lines on the newline character separator
text_split_by_newlines :: proc(text: string) -> [dynamic]Text_Line {
    lines_str := strings.split(text, "\n")
    text_lines := make([dynamic]Text_Line)

    for line in lines_str {
        append(&text_lines, Text_Line{line = fmt.ctprintf("%s", line) })
    }
    if strings.has_suffix(text, "\n") {
        append(&text_lines, Text_Line{line = ""})
    }
    return text_lines
}

// Capitalizes the first letter of each word in the string
capitalize :: proc(str: string) -> string {
	builder := strings.builder_make(context.temp_allocator)

	words := strings.split(str, " ", context.temp_allocator)

	for word in words {
		strings.write_string(&builder, strings.to_pascal_case(word, context.temp_allocator))
		strings.write_string(&builder, " ")
	}
	return strings.to_string(builder)
}

// Draws text centered at the given position / orientation
draw_centered_text :: proc "contextless" (text: cstring, posX, posY: i32, rot, fontSize: f32, tint: rl.Color) {
    spacing := fontSize / 10
    textSize := rl.MeasureTextEx(rl.GetFontDefault(), text, fontSize, spacing)
    pivot := textSize / 2
    rl.DrawTextPro(rl.GetFontDefault(), text, {f32(posX), f32(posY)}, pivot, rot, fontSize, spacing, tint)
}

// Draws text right-aligned at the given position
draw_right_text :: proc "contextless" (text: cstring, posX, posY: i32, rot, fontSize: f32, tint: rl.Color) {
    spacing := fontSize / 10
    textSize := rl.MeasureTextEx(rl.GetFontDefault(), text, fontSize, spacing)
    pivot := textSize
    pivot.y *= 0.5
    rl.DrawTextPro(rl.GetFontDefault(), text, {f32(posX), f32(posY)}, pivot, rot, fontSize, spacing, tint)
}

// Returns a checkmark rune if true, otherwise a space
print_bool :: proc(truthy: bool) -> rune {
	if truthy {
		return '✔'
	} else {
		return ' '
	}
}