package rlutil

import "core:strings"
import rl "vendor:raylib"

set_clipboard :: proc(text: string) -> (ok: bool) {
    // Try and convert the text string to cstring
    c_str, err := strings.clone_to_cstring(text, context.temp_allocator)
    if err == .None  {
        rl.SetClipboardText(c_str)
        return true
    }
    return false
}

get_clipboard :: proc() -> (text: string, ok: bool) {
    // Try and convert the cstring handed to us from raylib to a string
    c_str := rl.GetClipboardText()
    if c_str == nil || len(c_str) == 0 {
        ok = false
        return
    }
    clipboard_text, err := strings.clone_from_cstring(c_str, context.temp_allocator)
    text = clipboard_text
    ok = err == .None
    return
}
