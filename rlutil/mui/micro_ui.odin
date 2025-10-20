package gui

import "core:fmt"
import "core:strings"
import rl "vendor:raylib"
import mu "vendor:microui"

f32_slider :: proc(ctx: ^mu.Context, label: string, value: ^f32, low, high: f32, color1, color2: rl.Color) -> mu.Result_Set {
    mu.push_id_uintptr(ctx, transmute(uintptr)value)
    defer mu.pop_id(ctx)
    
    // Create semi-transparent versions of the colors
    tinted_color1 := rl.ColorAlpha(color1, 0.2)
    tinted_color2 := rl.ColorAlpha(color2, 0.2)
    
    // Store original colors
    orig_base := ctx.style.colors[.BASE]
    orig_border := ctx.style.colors[.BORDER]
    
    // Set custom colors for the slider
    if color2.r == 0 && color2.g == 0 && color2.b == 0 {
        // Single color mode
        ctx.style.colors[.BASE] = transmute(mu.Color)tinted_color1
    } else {
        // Gradient mode - we'll use color1 for now, the actual gradient will be drawn in the render callback
        ctx.style.colors[.BASE] = transmute(mu.Color)tinted_color2
    }
    
    // Make border semi-transparent
    ctx.style.colors[.BORDER] = transmute(mu.Color)rl.ColorAlpha(rl.BLACK, 0)
    
    // Draw the slider
    result := mu.slider(ctx, value, low, high, 0, append_label(label), {mu.Opt.AUTO_SIZE})
    
    // Restore original colors
    ctx.style.colors[.BASE] = orig_base
    ctx.style.colors[.BORDER] = orig_border
    
    return result
}

i32_slider :: proc(ctx: ^mu.Context, value: ^int, low, high: int, color: rl.Color) -> mu.Result_Set {
    mu.push_id_uintptr(ctx, transmute(uintptr)value)
    defer mu.pop_id(ctx)
    
    @(static) tmp: f32
    tmp = f32(value^)
    
    // Create semi-transparent version of the color
    tinted_color := rl.ColorAlpha(color, 0.2)
    
    // Store original colors
    orig_base := ctx.style.colors[.BASE]
    orig_border := ctx.style.colors[.BORDER]
    
    // Set custom colors
    ctx.style.colors[.BASE] = transmute(mu.Color)tinted_color
    ctx.style.colors[.BORDER] = transmute(mu.Color)rl.ColorAlpha(rl.BLACK, 0)
    
    result := mu.slider(ctx, &tmp, f32(low), f32(high), 0, "%.0f", {.ALIGN_CENTER})
    
    // Restore original colors
    ctx.style.colors[.BASE] = orig_base
    ctx.style.colors[.BORDER] = orig_border
    
    value^ = int(tmp)
    return result
}

append_label :: proc(label: string) -> string {
    label := fmt.tprintf("%s    ", label)
    fmt_str: strings.Builder
    strings.write_string(&fmt_str, label)
    strings.write_string(&fmt_str, "\t\t%.02f")
    return strings.to_string(fmt_str)
}