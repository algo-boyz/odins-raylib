package rlutil

import "core:fmt"
import "core:math"
import "core:strings"
import "core:unicode/utf8"
import rl "vendor:raylib"

// Returns the approximate width, in pixels, of a string written in the given font.
// Based off of Raylib's DrawText functions
get_string_width :: proc(font: rl.Font, font_size: f32, text: string) -> int {
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