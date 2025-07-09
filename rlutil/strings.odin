package rlutil

import "core:fmt"
import "core:math"
import "core:strings"
import "core:unicode/utf8"
import rl "vendor:raylib"

// Returns approximate width, in pixels, of a string written in the given font.
// Based off of Raylib's DrawText functions
str_width :: proc(font: rl.Font, font_size: f32, text: string) -> int {
    scale_factor := font_size / f32(font.baseSize)
    max_width, line_width, byte_count:int
    codepoint:rune
    for i := 0; i < len(text); {
        codepoint, byte_count = utf8.decode_rune_in_string(text[i:])
        if codepoint == utf8.RUNE_ERROR {
            byte_count = 1
        }
        idx := rl.GetGlyphIndex(font, codepoint)
        if codepoint == '\n' {
            max_width = max(line_width, max_width)
            line_width = 0
        } else {
            if font.glyphs[idx].advanceX == 0 {
                line_width += int(font.recs[idx].width * scale_factor)
            } else {
                line_width += int(font.glyphs[idx].advanceX * i32(scale_factor))
            }
        }
        i += byte_count
    }
    return max(line_width, max_width)
}

// Checks if the character is a continuation byte in UTF-8 encoding.
// In UTF-8, any byte where the top two bits are 10 (binary 0x80 in hexadecimal) is a continuation byte.
is_utf8_continuation_byte :: proc(char : rune) -> bool {
    return char & 0xc0 == 0x80
}

char_to_ascii :: proc(char : rune) -> int {
    return min(int(char), 127)
}

concat :: proc(string_inp: ..string, allocator := context.allocator) -> string {
    builder := strings.builder_make(0, 10, allocator)

    for str in string_inp do strings.write_string(&builder, str)

    return strings.to_string(builder)
}

concat_c :: proc(c_str: ..cstring) -> cstring {
    builder := strings.builder_make()
    defer strings.builder_destroy(&builder)

    for str in c_str do strings.write_string(&builder, string(str))

    return strings.to_cstring(&builder)
}
