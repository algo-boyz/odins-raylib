package demo

import "rlmu"
import "core:fmt"
import "core:strings"
import rl "vendor:raylib"
import mu "vendor:microui"

log_sb := strings.builder_make()
log_updated := false

log_input_text := make_slice([]u8, 128)
log_input_text_len : int

bg : [3]u8 = { 90, 95, 100 }

main :: proc() {
    // rl.SetWindowState({ .WINDOW_RESIZABLE })
    rl.InitWindow(720, 600, "Odin/Raylib/microui Demo")
    defer rl.CloseWindow()

    ctx := rlmu.init_scope() // same as calling, `rlmu.init(); defer rlmu.destroy()`

    for !rl.WindowShouldClose() {
        defer free_all(context.temp_allocator)

        rl.BeginDrawing(); defer rl.EndDrawing()
        rl.ClearBackground({ bg.r, bg.g, bg.b, 255 })
        
        rlmu.begin_scope()  // same as calling, `rlmu.begin(); defer rlmu.end()`

        style_window(ctx)
        test_window(ctx)
        log_window(ctx)
    } 
}

style_window :: proc(ctx : ^mu.Context) {
    Style_Color :: struct {
        label: string, 
        type: mu.Color_Type
    }
    
    @(static)
    colors := [?]Style_Color {
        { "text:",         .TEXT         },
        { "border:",       .BORDER       },
        { "windowbg:",     .WINDOW_BG    },
        { "titlebg:",      .TITLE_BG     },
        { "titletext:",    .TITLE_TEXT   },
        { "panelbg:",      .PANEL_BG     },
        { "button:",       .BUTTON       },
        { "buttonhover:",  .BUTTON_HOVER },
        { "buttonfocus:",  .BUTTON_FOCUS },
        { "base:",         .BASE         },
        { "basehover:",    .BASE_HOVER   },
        { "basefocus:",    .BASE_FOCUS   },
        { "scrollbase:",   .SCROLL_BASE  },
        { "scrollthumb:",  .SCROLL_THUMB },
    }
    
    if mu.begin_window(ctx, "Style Editor", mu.Rect { 350, 250, 300, 240 }) {
        defer mu.end_window(ctx)

        slider_width := i32(f32(mu.get_current_container(ctx).body.w) * 0.14)
        mu.layout_row(ctx, { 80, slider_width, slider_width, slider_width, slider_width, -1 }, 0)
        for i in 0..<len(colors) {
            color_type := colors[i].type
            color := &ctx.style.colors[color_type]

            mu.label(ctx, colors[i].label)
            u8_slider(ctx, &color.r, 0, 255)
            u8_slider(ctx, &color.g, 0, 255)
            u8_slider(ctx, &color.b, 0, 255)
            u8_slider(ctx, &color.a, 0, 255)
            
            mu.draw_rect(ctx, mu.layout_next(ctx), color^)
        }
    }
}

test_window :: proc(ctx: ^mu.Context) {
    if mu.begin_window(ctx, "Demo Window", mu.Rect { 40, 40, 300, 450 }) {
        defer mu.end_window(ctx)

        win := mu.get_current_container(ctx)
        win.rect.w = max(win.rect.w, 240)
        win.rect.h = max(win.rect.h, 300)
    
        /* window info */
        if .ACTIVE in mu.header(ctx, "Window Info") {
            win = mu.get_current_container(ctx)
            mu.layout_row(ctx, { 54, -1 }, 0)

            mu.label(ctx,"Position:")
            mu.label(ctx, fmt.tprintf("%d, %d", win.rect.x, win.rect.y))

            mu.label(ctx, "Size:")
            mu.label(ctx, fmt.tprintf("%d, %d", win.rect.w, win.rect.h))
        }
    
        /* labels + buttons */
        if .ACTIVE in mu.header(ctx, "Test Buttons", { .EXPANDED }) {
            mu.layout_row(ctx, { 86, -110, -1 }, 0)

            mu.label(ctx, "Test buttons 1:")
            if .SUBMIT in mu.button(ctx, "Button 1") do write_log("Pressed button 1") 
            if .SUBMIT in mu.button(ctx, "Button 2") do write_log("Pressed button 2") 

            mu.label(ctx, "Test buttons 2:")
            if .SUBMIT in mu.button(ctx, "Button 3") do write_log("Pressed button 3")
            if .SUBMIT in mu.button(ctx, "Popup") do mu.open_popup(ctx, "Test Popup")

            if mu.begin_popup(ctx, "Test Popup") {
                defer mu.end_popup(ctx)
                if .SUBMIT in mu.button(ctx, "Hello") do write_log("Hello")
                if .SUBMIT in mu.button(ctx, "World") do write_log("World")
            }
        }
    
        /* tree */
        if .ACTIVE in mu.header(ctx, "Tree and Text", { .EXPANDED }) {
            mu.layout_row(ctx, { 140, -1 }, 0)
            {
                mu.layout_begin_column(ctx)
                defer mu.layout_end_column(ctx)

                if .ACTIVE in mu.begin_treenode(ctx, "Test 1") {
                    defer mu.end_treenode(ctx)

                    if .ACTIVE in mu.begin_treenode(ctx, "Test 1a") {
                        defer mu.end_treenode(ctx)

                        mu.label(ctx, "Hello")
                        mu.label(ctx, "world")
                    }
                    if .ACTIVE in mu.begin_treenode(ctx, "Test 1b") {
                        defer mu.end_treenode(ctx)

                        if .SUBMIT in mu.button(ctx, "Button 1") do write_log("Pressed button 1")
                        if .SUBMIT in mu.button(ctx, "Button 2") do write_log("Pressed button 2")
                    }
                }
                if .ACTIVE in mu.begin_treenode(ctx, "Test 2") {
                    mu.layout_row(ctx, { -1 }, 0)
                    defer mu.end_treenode(ctx)

                    if .SUBMIT in mu.button(ctx, "Button 3") do write_log("Pressed button 3")
                    if .SUBMIT in mu.button(ctx, "Button 4") do write_log("Pressed button 4")
                    if .SUBMIT in mu.button(ctx, "Button 5") do write_log("Pressed button 5")
                    if .SUBMIT in mu.button(ctx, "Button 6") do write_log("Pressed button 6")
                }
                if .ACTIVE in mu.begin_treenode(ctx, "Test 3") {
                    defer mu.end_treenode(ctx)

                    @static checks : [3]bool = { true, false, true }
                    mu.checkbox(ctx, "Checkbox 1", &checks[0])
                    mu.checkbox(ctx, "Checkbox 2", &checks[1])
                    mu.checkbox(ctx, "Checkbox 3", &checks[2])
                }
            }
            
            {
                mu.layout_begin_column(ctx)
                defer mu.layout_end_column(ctx)

                mu.layout_row(ctx, { -1 }, 0)
                mu.text(ctx, "Lorem ipsum dolor sit amet, consectetur adipiscing " +
                    "elit. Maecenas lacinia, sem eu lacinia molestie, mi risus faucibus " +
                    "ipsum, eu varius magna felis a nulla."
                )
            }
        }
    
        /* background color sliders */
        if .ACTIVE in mu.header(ctx, "Background Color", { .EXPANDED }) {
            mu.layout_row(ctx, { -78, -1 }, 74)

            /* sliders */
            mu.layout_begin_column(ctx)
            mu.layout_row(ctx, { 46, -1 }, 0)
            mu.label(ctx, "Red:")
            u8_slider(ctx, &bg[0], 0, 255)
            mu.label(ctx, "Green:")
            u8_slider(ctx, &bg[1], 0, 255)
            mu.label(ctx, "Blue:")
            u8_slider(ctx, &bg[2], 0, 255)
            mu.layout_end_column(ctx)

            /* color preview */
            r := mu.layout_next(ctx)
            mu.draw_rect(ctx, r, { bg[0], bg[1], bg[2], 255 })
            mu.draw_control_text(ctx, fmt.tprintf("#%02X%02X%02X", bg[0], bg[1], bg[2]), r, .TEXT, { .ALIGN_CENTER })
        }
    }
}

log_window :: proc (ctx : ^mu.Context) {
    if mu.begin_window(ctx, "Log Window", mu.Rect{ 350, 40, 300, 200 }) {
        defer mu.end_window(ctx)

        /* output text panel */
        mu.layout_row(ctx, { -1 }, -25)
        mu.begin_panel(ctx, "Log Output")
        panel := mu.get_current_container(ctx)
        mu.layout_row(ctx, { -1 }, -1)
        mu.text(ctx, strings.to_string(log_sb))
        mu.end_panel(ctx)
        if log_updated {
            panel.scroll.y = panel.content_size.y
            log_updated = false
        }
    
        /* input textbox + submit button */
        submitted := false
        mu.layout_row(ctx, { -70, -1 }, 0)

        if .SUBMIT in mu.textbox(ctx, log_input_text, &log_input_text_len) {
            mu.set_focus(ctx, ctx.last_id)
            submitted = true
        }
        if .SUBMIT in mu.button(ctx, "Submit") {
            submitted = true
        }

        if submitted == true {
            write_log(string(log_input_text[:log_input_text_len]))
            log_input_text_len = 0
        }
    }
}

write_log :: proc(text: string) {
    if strings.builder_len(log_sb) != 0 {
        // Append newline if log isn't empty
        fmt.sbprint(&log_sb, "\n")
    }
    fmt.sbprint(&log_sb, text)
    log_updated = true
}

u8_slider :: proc(ctx: ^mu.Context, value: ^u8, low, high: int) -> mu.Result_Set {
    mu.push_id_uintptr(ctx, transmute(uintptr)value)
    defer mu.pop_id(ctx)

    @(static) tmp: f32
    tmp = f32(value^)
    res := mu.slider(ctx, &tmp, f32(low), f32(high), 0, "%.f", { .ALIGN_CENTER })
    value ^= u8(tmp)
    return res
}