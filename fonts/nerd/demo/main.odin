package main

import "core:fmt"
import "core:log"
import "core:math"
import "core:strings"
import rl "vendor:raylib"

import "../ocsv"
import "../"

Demo_State :: struct {
    selected_icon: int,
    hover_icon: int,
    animation_time: f32,
    show_tooltips: bool,
    bg_color: rl.Color,
    text_color: rl.Color,
    accent_color: rl.Color,
}

demo_state: Demo_State
ui_ctx:     nerd.UI_Context
icons:      [dynamic]nerd.Icon_Info

main :: proc() {
    context.logger = log.create_console_logger(lowest = log.Level.Info, opt = log.Options{.Level, .Terminal_Color, .Short_File_Path, .Line} | log.Full_Timestamp_Opts )
    defer log.destroy_console_logger(context.logger)

    rl.InitWindow(1200, 800, "Nerd Font Demo")
    defer rl.CloseWindow()
    
    rl.SetWindowState({.WINDOW_RESIZABLE})
    rl.SetTargetFPS(60)
    
    // Read the CSV file
    filename := "assets/icons.csv"
    csv_data, err := ocsv.read_file(filename)
    if err != .None {
        log.infof("Failed to read CSV: %v\n", err)
        return
    }
    log.infof("Read %d rows from '%s'\n", len(csv_data), filename)

    if len(csv_data) < 2 {
        log.info("CSV file doesn't have enough data")
        return
    }
    // First row is the header
    header := csv_data[0]
    log.infof("Headers: %v\n", header)

    // Convert data rows to Font_Symbol
    symbols: [dynamic]nerd.Font_Symbol
    defer delete(symbols)

    for i := 1; i < len(csv_data); i += 1 {
        sym: nerd.Font_Symbol
        conv_err := ocsv.row_to_struct(csv_data[i], &sym, header)
        if conv_err != .None {
            log.infof("Failed to convert row %d to FontSymbol struct: %v\n", i, conv_err)
            continue
        }
        append(&symbols, sym)
    }
    fmt.printf("Converted %d rows to FontSymbol structs\n", len(symbols))

    // Load icons from csv
   icons = nerd.load_icons_from_csv(symbols[:])
    defer {
        for icon in icons {
            delete(icon.icon)
            delete(icon.fallback)
            delete(icon.name)
            delete(icon.description)
        }
        delete(icons)
    }
    // Init demo
    demo_state = Demo_State{
        selected_icon = -1,
        hover_icon = -1,
        animation_time = 0,
        show_tooltips = true,
        bg_color = rl.Color{45, 45, 45, 255},
        text_color = rl.Color{220, 220, 220, 255},
        accent_color = rl.Color{100, 150, 255, 255},
    }
    // Load font with symbols
    nerd.ui_load_font(&ui_ctx, "assets/nerd.ttf", 32, symbols[:])
    defer nerd.ui_unload_font(&ui_ctx)
    
    for !rl.WindowShouldClose() {
        demo_state.animation_time += rl.GetFrameTime()
        // Draw
        rl.BeginDrawing()
        rl.ClearBackground(rl.Color{25, 25, 25, 255})
        
        // Title
        title :: "Dynamic Nerd Font Icon Demo"
        title_size := rl.MeasureTextEx(ui_ctx.font, title, 36, 0)
        title_x := (f32(rl.GetScreenWidth()) - title_size.x) / 2
        rl.DrawTextEx(ui_ctx.font, title, {title_x, 20}, 36, 0, demo_state.accent_color)
        
        // Draw components
        draw_icon_grid()
        draw_info_panel()
        draw_tooltip()
        draw_controls()
        
        fps_text := fmt.ctprintf("FPS: %d", rl.GetFPS())
        rl.DrawTextEx(ui_ctx.font, fps_text, {f32(rl.GetScreenWidth()) - 100, 10}, 16, 0, rl.Color{100, 100, 100, 255})

        rl.EndDrawing()
    }
}

get_responsive_layout :: proc() -> (grid_cols: int, icon_size: int, padding: int, start_x: int, start_y: int, panel_x: int, panel_width: int) {
    WIDTH := int(rl.GetScreenWidth())
    
    // 1. Define Panel Dimensions & Anchor to Right
    // Set fixed width for the panel or percentage
    panel_width = 300
    right_margin := 20
    panel_gap := 40 // Gap between grid and panel
    
    // Calc Panel X (Anchored to right side)
    panel_x = WIDTH - panel_width - right_margin
    
    // 2. Define Icon Size based on available resolution
    if WIDTH < 800 {
        icon_size = 40
        padding = 10
        // Shrink panel on small screens
        panel_width = 240
        panel_x = WIDTH - panel_width - right_margin
    } else if WIDTH < 1200 {
        icon_size = 50
        padding = 15
    } else {
        icon_size = 60
        padding = 20
    }
    
    // 3. Calculate Grid Columns based on REMAINING space to the left
    // Available width = Panel position - Gap - Left Margin
    left_margin := 20
    available_grid_width := panel_x - panel_gap - left_margin
    
    // Formula: cols * size + (cols - 1) * padding <= available_width
    // Simplified: cols * (size + padding) <= available_width + padding
    cell_total_width := icon_size + padding
    grid_cols = (available_grid_width + padding) / cell_total_width
    
    // Safety check to ensure at least 1 column
    if grid_cols < 1 { grid_cols = 1 }
    
    // 4. Center grid within "Left Zone"
    actual_grid_width := grid_cols * cell_total_width - padding
    
    // Center logic: Left Margin + (Available Space - Actual Used Space) / 2
    start_x = left_margin + (available_grid_width - actual_grid_width) / 2
    start_y = 100
    
    return
}

draw_icon_grid :: proc() {
    grid_cols, icon_size, padding, start_x, start_y, _, _ := get_responsive_layout()
    
    mouse_pos := rl.GetMousePosition()
    demo_state.hover_icon = -1
    
    for i in 0..<len(icons) {
        col := i % grid_cols
        row := i / grid_cols
        
        x := start_x + col * (icon_size + padding)
        y := start_y + row * (icon_size + padding)
        
        // Check if mouse is hovering over this icon
        icon_rect := rl.Rectangle{f32(x), f32(y), f32(icon_size), f32(icon_size)}
        is_hovering := rl.CheckCollisionPointRec(mouse_pos, icon_rect)
        is_selected := demo_state.selected_icon == i
        
        if is_hovering {
            demo_state.hover_icon = i
            if rl.IsMouseButtonPressed(.LEFT) {
                demo_state.selected_icon = i
            }
        }
        // Draw background
        bg_color := demo_state.bg_color
        if is_selected {
            bg_color = demo_state.accent_color
        } else if is_hovering {
            bg_color = rl.Color{60, 60, 60, 255}
        }
        rl.DrawRectangleRounded(icon_rect, 0.1, 8, bg_color)
        
        // Draw icon or fallback
        icon_color := demo_state.text_color
        if is_selected {
            icon_color = rl.WHITE
        }
        // Add subtle animation
        scale := f32(1.0)
        if is_hovering || is_selected {
            scale = 1.0 + 0.1 * math.sin(demo_state.animation_time * 8.0)
        }
        // Choose icon or fallback text
        display_text := ui_ctx.has_nerd_font ? strings.clone_to_cstring(icons[i].icon) : strings.clone_to_cstring(icons[i].fallback)
        defer delete(display_text)
        
        icon_font_size := i32(f32(ui_ctx.font_size) * scale * 0.8) // Slightly smaller to fit better
        
        text_size := rl.MeasureTextEx(ui_ctx.font, display_text, f32(icon_font_size), 0)
        
        icon_x := f32(x) + (f32(icon_size) - text_size.x) / 2
        icon_y := f32(y) + (f32(icon_size) - text_size.y) / 2
        
        rl.DrawTextEx(ui_ctx.font, display_text, {icon_x, icon_y}, f32(icon_font_size), 0, icon_color)
        
        // Draw border
        border_color := rl.Color{80, 80, 80, 255}
        if is_selected {
            border_color = rl.WHITE
        } else if is_hovering {
            border_color = rl.Color{120, 120, 120, 255}
        }
        rl.DrawRectangleRoundedLines(icon_rect, 0.1, 8, border_color)
    }
}

draw_info_panel :: proc() {
    _, _, _, _, _, panel_x, panel_width := get_responsive_layout()
    
    panel_y := 100
    panel_height := 350 // Increased height for more info
    
    panel_rect := rl.Rectangle{f32(panel_x), f32(panel_y), f32(panel_width), f32(panel_height)}
    rl.DrawRectangleRounded(panel_rect, 0.05, 8, rl.Color{30, 30, 30, 200})
    rl.DrawRectangleRoundedLines(panel_rect, 0.05, 8, rl.Color{80, 80, 80, 255})
    
    if demo_state.selected_icon >= 0 && demo_state.selected_icon < len(icons) {
        icon_info := icons[demo_state.selected_icon]
        
        // Draw large icon
        large_icon_size := i32(72)
        display_text := ui_ctx.has_nerd_font ? strings.clone_to_cstring(icon_info.icon) : strings.clone_to_cstring(icon_info.fallback)
        defer delete(display_text)
        
        large_text_size := rl.MeasureTextEx(ui_ctx.font, display_text, f32(large_icon_size), 0)
        large_icon_x := f32(panel_x) + (f32(panel_width) - large_text_size.x) / 2
        large_icon_y := f32(panel_y) + 30
        
        rl.DrawTextEx(ui_ctx.font, display_text, {large_icon_x, large_icon_y}, f32(large_icon_size), 0, demo_state.accent_color)
        
        // Draw name and description
        name_y := large_icon_y + large_text_size.y + 20
        desc_y := name_y + 30
        
        name_cstr := strings.clone_to_cstring(icon_info.name)
        defer delete(name_cstr)
        desc_cstr := strings.clone_to_cstring(icon_info.description)
        defer delete(desc_cstr)
        
        rl.DrawTextEx(ui_ctx.font, name_cstr, {f32(panel_x) + 20, name_y}, 20, 0, rl.WHITE)
        rl.DrawTextEx(ui_ctx.font, desc_cstr, {f32(panel_x) + 20, desc_y}, 14, 0, rl.Color{180, 180, 180, 255})
        
        // Draw unicode info
        unicode_text := fmt.ctprintf("Unicode: %s", icon_info.icon)
        unicode_y := desc_y + 40
        rl.DrawTextEx(ui_ctx.font, unicode_text, {f32(panel_x) + 20, unicode_y}, 12, 0, rl.Color{120, 120, 120, 255})
        
        // Fallback info
        fallback_text := fmt.ctprintf("Fallback: %s", strings.clone_to_cstring(icon_info.fallback))
        fallback_y := unicode_y + 20
        rl.DrawTextEx(ui_ctx.font, fallback_text, {f32(panel_x) + 20, fallback_y}, 12, 0, rl.Color{120, 120, 120, 255})
        
        // Font status
        font_status:cstring = ui_ctx.has_nerd_font ? "Nerd Font: Loaded" : "Nerd Font: Not found"
        font_status_y := fallback_y + 25
        status_color := ui_ctx.has_nerd_font ? rl.GREEN : rl.Color{255, 150, 50, 255}
        rl.DrawTextEx(ui_ctx.font, font_status, {f32(panel_x) + 20, font_status_y}, 12, 0, status_color)
        
        // CSV info
        csv_info := fmt.ctprintf("Loaded from CSV (%d total icons)", len(icons))
        csv_y := font_status_y + 25
        rl.DrawTextEx(ui_ctx.font, csv_info, {f32(panel_x) + 20, csv_y}, 12, 0, rl.Color{100, 150, 255, 255})
    } else {
        // Draw instructions
        instructions :: "Click an icon to see details"
        text_size := rl.MeasureTextEx(ui_ctx.font, instructions, 20, 0)
        text_x := f32(panel_x) + (f32(panel_width) - text_size.x) / 2
        text_y := f32(panel_y) + (f32(panel_height) - text_size.y) / 2
        rl.DrawTextEx(ui_ctx.font, instructions, {text_x, text_y}, 20, 0, rl.Color{120, 120, 120, 255})
    }
}

draw_tooltip :: proc() {
    if demo_state.hover_icon >= 0 && demo_state.hover_icon < len(icons) && demo_state.show_tooltips {
        mouse_pos := rl.GetMousePosition()
        tooltip_text := strings.clone_to_cstring(icons[demo_state.hover_icon].name)
        defer delete(tooltip_text)
        
        tooltip_font_size :: 16
        text_size := rl.MeasureTextEx(ui_ctx.font, tooltip_text, tooltip_font_size, 0)
        tooltip_padding :: 8
        
        tooltip_width := text_size.x + tooltip_padding * 2
        tooltip_height := text_size.y + tooltip_padding * 2
        
        tooltip_x := mouse_pos.x + 10
        tooltip_y := mouse_pos.y - tooltip_height - 10
        
        // Keep tooltip on screen
        if tooltip_x + tooltip_width > f32(rl.GetScreenWidth()) {
            tooltip_x = mouse_pos.x - tooltip_width - 10
        }
        if tooltip_y < 0 {
            tooltip_y = mouse_pos.y + 10
        }
        tooltip_rect := rl.Rectangle{tooltip_x, tooltip_y, tooltip_width, tooltip_height}
        rl.DrawRectangleRounded(tooltip_rect, 0.2, 8, rl.Color{20, 20, 20, 240})
        rl.DrawRectangleRoundedLines(tooltip_rect, 0.2, 8, rl.Color{80, 80, 80, 255})
        
        text_x := tooltip_x + tooltip_padding
        text_y := tooltip_y + tooltip_padding
        rl.DrawTextEx(ui_ctx.font, tooltip_text, {text_x, text_y}, tooltip_font_size, 0, rl.WHITE)
    }
}

draw_controls :: proc() {
    HEIGHT := rl.GetScreenHeight()
    controls_y := HEIGHT - 150
    
    // Toggle tooltips
    checkbox_size :: 20
    checkbox_x :: 50
    checkbox_y := controls_y
    
    checkbox_rect := rl.Rectangle{f32(checkbox_x), f32(checkbox_y), checkbox_size, checkbox_size}
    rl.DrawRectangleRec(checkbox_rect, rl.Color{40, 40, 40, 255})
    rl.DrawRectangleLinesEx(checkbox_rect, 2, rl.Color{100, 100, 100, 255})
    
    if demo_state.show_tooltips {
        check_text:cstring = "✓"
        rl.DrawTextEx(ui_ctx.font, check_text, {f32(checkbox_x + 2), f32(checkbox_y - 2)}, 16, 0, rl.GREEN)
    }
    if rl.CheckCollisionPointRec(rl.GetMousePosition(), checkbox_rect) {
        if rl.IsMouseButtonPressed(.LEFT) {
            demo_state.show_tooltips = !demo_state.show_tooltips
        }
    }
    // Instructions
    instructions_y := controls_y + 40
    rl.DrawTextEx(ui_ctx.font, "Instructions:", {50, f32(instructions_y)}, 16, 0, demo_state.accent_color)
    rl.DrawTextEx(ui_ctx.font, "• Click icons to select and view details", {70, f32(instructions_y + 25)}, 14, 0, demo_state.text_color)
    rl.DrawTextEx(ui_ctx.font, "• Hover over icons to see names (if tooltips enabled)", {70, f32(instructions_y + 45)}, 14, 0, demo_state.text_color)
    rl.DrawTextEx(ui_ctx.font, "• Press ESC to exit", {70, f32(instructions_y + 65)}, 14, 0, demo_state.text_color)
}