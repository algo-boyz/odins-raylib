package main

import "core:fmt"
import "core:math"
import "core:math/rand"
import "core:strings"
import rl "vendor:raylib"
import mu "vendor:microui"
import "conf"
import "../../gui/microui/rlmu"

// based on: Create Life From Simple Rules - https://www.youtube.com/watch?v=0Kx4Y9TVMGg
SimState :: struct {
    settings: ^conf.Settings,
    power_matrix: [4][4]f32,  // Powers between colors
    radius_matrix: [4][4]f32, // Interaction radii between colors
    show_gui: bool,
    show_settings: bool,
}

// Create a group of particles with same color and return it in a ColorGroup vector
create_points :: proc(num: int, color: rl.Color) -> conf.ColorGroup {
    group: conf.ColorGroup
    group.color = color
    group.count = num
    
    resize(&group.positions, num)
    resize(&group.velocities, num)
    
    for i := 0; i < num; i += 1 {
        group.positions[i] = {
            rand.float32_range(0, f32(rl.GetScreenWidth())),
            rand.float32_range(0, f32(rl.GetScreenHeight())),
        }
        group.velocities[i] = {0, 0}
    }
    
    return group
}

// compute the interaction between two groups of particles
interaction :: proc(group1: ^conf.ColorGroup, group2: ^conf.ColorGroup, g: f32, radius: f32, settings: ^conf.Settings) {
    G :: -0.01
    g := g * G
    
    for i := 0; i < len(group1.positions); i += 1 {
        fx, fy: f32
        
        for j := 0; j < len(group2.positions); j += 1 {
            if group1.positions[i] != group2.positions[j] {
                dx := group1.positions[i].x - group2.positions[j].x
                dy := group1.positions[i].y - group2.positions[j].y
                d2 := dx * dx + dy * dy
                
                if d2 < radius * radius {
                    force := 1.0 / math.sqrt_f32(d2)
                    fx += dx * force
                    fy += dy * force
                }
            }
        }
        
        if settings.wall_repel > 0 {
            if group1.positions[i].x < settings.wall_repel {
                group1.velocities[i].x += (settings.wall_repel - group1.positions[i].x) * 0.1
            }
            if group1.positions[i].y < settings.wall_repel {
                group1.velocities[i].y += (settings.wall_repel - group1.positions[i].y) * 0.1
            }
            if group1.positions[i].x > f32(settings.bound_width) - settings.wall_repel {
                group1.velocities[i].x += (f32(settings.bound_width) - settings.wall_repel - group1.positions[i].x) * 0.1
            }
            if group1.positions[i].y > f32(settings.bound_height) - settings.wall_repel {
                group1.velocities[i].y += (f32(settings.bound_height) - settings.wall_repel - group1.positions[i].y) * 0.1
            }
        }
        
        group1.velocities[i].x = (group1.velocities[i].x + fx * g) * (1.0 - settings.viscosity)
        group1.velocities[i].y = (group1.velocities[i].y + fy * g) * (1.0 - settings.viscosity) + settings.gravity
        
        group1.positions[i].x += group1.velocities[i].x
        group1.positions[i].y += group1.velocities[i].y
        
        if settings.bounded {
            group1.positions[i].x = clamp(group1.positions[i].x, 0, f32(settings.bound_width))
            group1.positions[i].y = clamp(group1.positions[i].y, 0, f32(settings.bound_height))
        }
    }
}

randomize :: proc(state: ^SimState) {
    for i := 0; i < 4; i += 1 {
        for j := 0; j < 4; j += 1 {
            state.power_matrix[i][j] = rand.float32_range(-100, 100) * 0.8
            state.radius_matrix[i][j] = rand.float32_range(10, 200) * 0.6
        }
    }
}

restart :: proc(group: ^conf.ColorGroup) {
    for i := 0; i < group.count; i += 1 {
        group.positions[i] = {
            rand.float32_range(0, f32(rl.GetScreenWidth())),
            rand.float32_range(0, f32(rl.GetScreenHeight())),
        }
        group.velocities[i] = {0, 0}
    }
}

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

draw_color_interactions :: proc(ctx: ^mu.Context, state: ^SimState, color_index: int, label: string) {
    if .ACTIVE in mu.header(ctx, label) {
        mu.layout_row(ctx, { -1 }, 0)
        
        colors := [4]rl.Color{rl.RED, rl.GREEN, rl.WHITE, rl.YELLOW}
        for i := 0; i < 4; i += 1 {
            // Power slider with color gradient
            f32_slider(ctx, "Power", &state.power_matrix[color_index][i], -100, 100, colors[i], colors[i])
            
            // Radius slider with color gradient
            f32_slider(ctx, "Radius", &state.radius_matrix[color_index][i], 10, 500, colors[i], colors[i])
        }
    }
}

draw_ui :: proc(ctx: ^mu.Context, state: ^SimState) {
    // Show GUI toggle button only when both menus are hidden
    if !state.show_gui && !state.show_settings {
        if mu.begin_window(ctx, "GUI", mu.Rect{20, 20, 300, 800}, {mu.Opt.NO_TITLE, mu.Opt.NO_CLOSE, mu.Opt.NO_RESIZE, mu.Opt.NO_FRAME}) {
            defer mu.end_window(ctx)
            if .SUBMIT in mu.button(ctx, "Menu", .NONE, {mu.Opt.ALIGN_CENTER, mu.Opt.NO_FRAME}) {
                state.show_gui = true
            }
        }
        return
    }

    // Main menu
    if state.show_gui {
        if mu.begin_window(ctx, "MAIN", mu.Rect{20, 20, 300, 800}, {mu.Opt.NO_TITLE, mu.Opt.NO_CLOSE, mu.Opt.NO_RESIZE, mu.Opt.NO_FRAME}) {
            defer mu.end_window(ctx)
            mu.layout_row(ctx, { -1 }, 0)
            
            if .SUBMIT in mu.button(ctx, "Hide", .NONE, {mu.Opt.ALIGN_CENTER, mu.Opt.NO_FRAME}) {
                state.show_gui = false
            }
            
            if .SUBMIT in mu.button(ctx, "Restart", .NONE, {mu.Opt.ALIGN_CENTER, mu.Opt.NO_FRAME}) {
                restart(&state.settings.green)
                restart(&state.settings.red)
                restart(&state.settings.white)
                restart(&state.settings.yellow)
            }
            
            if .SUBMIT in mu.button(ctx, "Randomize", .NONE, {mu.Opt.ALIGN_CENTER, mu.Opt.NO_FRAME}) {
                randomize(state)
            }

            if .SUBMIT in mu.button(ctx, "Settings", .NONE, {mu.Opt.ALIGN_CENTER, mu.Opt.NO_FRAME}) {
                state.show_gui = false
                state.show_settings = true
            }
        }
    }

    // Settings menu
    if state.show_settings {
        if mu.begin_window(ctx, "SETTINGS", mu.Rect{20, 20, 300, 800}, {mu.Opt.NO_TITLE, mu.Opt.NO_CLOSE, mu.Opt.NO_FRAME}) {
            defer mu.end_window(ctx)
            
            mu.layout_row(ctx, { -1 }, 0)
            if .SUBMIT in mu.button(ctx, "Back", .NONE, {mu.Opt.ALIGN_CENTER, mu.Opt.NO_FRAME}) {
                state.show_settings = false
                state.show_gui = true
            }

            // if !state.settings.synced {
            if .SUBMIT in mu.button(ctx, "Save", .NONE, {mu.Opt.ALIGN_CENTER, mu.Opt.NO_FRAME}) {
                conf.save_settings(conf.SETTINGS_FILE, state.settings) // todo display error
            }

            mu.layout_row(ctx, { -1 }, 0)
            f32_slider(ctx, "Viscos", &state.settings.viscosity, 0, 1, rl.BLUE, rl.BLACK)
            f32_slider(ctx, "Gravit", &state.settings.gravity, -1, 1, rl.BLUE, rl.BLACK)
            f32_slider(ctx, "Repuls", &state.settings.wall_repel, 0, 100, rl.BLUE, rl.BLACK)
            mu.checkbox(ctx, "Bounded", &state.settings.bounded)
            mu.checkbox(ctx, "Motion Blur", &state.settings.motion_blur)
            
            // Particle counts
            if .ACTIVE in mu.header(ctx, "Particle Counts") {
                mu.layout_row(ctx, { -1 }, 0)
                i32_slider(ctx, &state.settings.green.count, 0, 1000, rl.GREEN)
                i32_slider(ctx, &state.settings.red.count, 0, 1000, rl.RED)
                i32_slider(ctx, &state.settings.white.count, 0, 1000, rl.WHITE)
                i32_slider(ctx, &state.settings.yellow.count, 0, 1000, rl.YELLOW)
            }

            // Color interactions
            draw_color_interactions(ctx, state, 0, "RED")
            draw_color_interactions(ctx, state, 1, "GREEN")
            draw_color_interactions(ctx, state, 2, "WHITE")
            draw_color_interactions(ctx, state, 3, "YELLOW")
        }
    }
}

append_label :: proc(label: string) -> string {
    label := fmt.tprintf("%s    ", label)
    fmt_str: strings.Builder
    strings.write_string(&fmt_str, label)
    strings.write_string(&fmt_str, "\t\t%.02f")
    return strings.to_string(fmt_str)
}

main :: proc() {
    rl.InitWindow(900, 600, "Particle Life")
    defer rl.CloseWindow()
    
    ctx := rlmu.init_scope()
    
    rl.SetTargetFPS(60)
    
    // Initialize simulation state
    s: SimState
    settings, err  := conf.load_settings(conf.SETTINGS_FILE, context.temp_allocator)
    if err != nil {
        fmt.println("Error loading settings: ", err)
        fmt.println("Using default settings")

    }
    s.settings = &settings
    // Create initial particle groups
    s.settings.green = create_points(300, rl.GREEN)
    s.settings.red = create_points(300, rl.RED)
    s.settings.white = create_points(300, rl.WHITE)
    s.settings.yellow = create_points(300, rl.YELLOW)
    defer delete(s.settings.green.positions)
    defer delete(s.settings.green.velocities)
    defer delete(s.settings.red.positions)
    defer delete(s.settings.red.velocities)
    defer delete(s.settings.white.positions)
    defer delete(s.settings.white.velocities)
    defer delete(s.settings.yellow.positions)
    defer delete(s.settings.yellow.velocities)
    
    randomize(&s)
    
    for !rl.WindowShouldClose() {
        defer free_all(context.temp_allocator)
        
        if rl.IsKeyPressed(.SPACE) {
            randomize(&s)
        }
        if rl.IsKeyPressed(.TAB) {
            s.show_gui = !s.show_gui
            s.show_settings = false
        }         
        if rl.IsKeyPressed(.S) {
            s.show_settings = !s.show_settings
            s.show_gui = false
        }
        // Particle interactions
        interaction(&s.settings.red, &s.settings.red, s.power_matrix[0][0], s.radius_matrix[0][0], s.settings)
        interaction(&s.settings.red, &s.settings.green, s.power_matrix[0][1], s.radius_matrix[0][1], s.settings)
        interaction(&s.settings.red, &s.settings.white, s.power_matrix[0][2], s.radius_matrix[0][2], s.settings)
        interaction(&s.settings.red, &s.settings.yellow, s.power_matrix[0][3], s.radius_matrix[0][3], s.settings)
        
        interaction(&s.settings.green, &s.settings.red, s.power_matrix[1][0], s.radius_matrix[1][0], s.settings)
        interaction(&s.settings.green, &s.settings.green, s.power_matrix[1][1], s.radius_matrix[1][1], s.settings)
        interaction(&s.settings.green, &s.settings.white, s.power_matrix[1][2], s.radius_matrix[1][2], s.settings)
        interaction(&s.settings.green, &s.settings.yellow, s.power_matrix[1][3], s.radius_matrix[1][3], s.settings)
        
        interaction(&s.settings.white, &s.settings.red, s.power_matrix[2][0], s.radius_matrix[2][0], s.settings)
        interaction(&s.settings.white, &s.settings.green, s.power_matrix[2][1], s.radius_matrix[2][1], s.settings)
        interaction(&s.settings.white, &s.settings.white, s.power_matrix[2][2], s.radius_matrix[2][2], s.settings)
        interaction(&s.settings.white, &s.settings.yellow, s.power_matrix[2][3], s.radius_matrix[2][3], s.settings)
        
        interaction(&s.settings.yellow, &s.settings.red, s.power_matrix[3][0], s.radius_matrix[3][0], s.settings)
        interaction(&s.settings.yellow, &s.settings.green, s.power_matrix[3][1], s.radius_matrix[3][1], s.settings)
        interaction(&s.settings.yellow, &s.settings.white, s.power_matrix[3][2], s.radius_matrix[3][2], s.settings)
        interaction(&s.settings.yellow, &s.settings.yellow, s.power_matrix[3][3], s.radius_matrix[3][3], s.settings)

        // Draw
        rl.BeginDrawing()
        defer rl.EndDrawing()

        if s.settings.motion_blur {
            rl.ClearBackground(rl.ColorAlpha(rl.BLACK, 0.1))
        } else {
            rl.ClearBackground(rl.BLACK)
        }

        // Draw particles
        for i := 0; i < s.settings.red.count; i += 1 {
            rl.DrawPixelV(s.settings.red.positions[i], s.settings.red.color)
        }
        for i := 0; i < s.settings.green.count; i += 1 {
            rl.DrawPixelV(s.settings.green.positions[i], s.settings.green.color)
        }
        for i := 0; i < s.settings.white.count; i += 1 {
            rl.DrawPixelV(s.settings.white.positions[i], s.settings.white.color)
        }
        for i := 0; i < s.settings.yellow.count; i += 1 {
            rl.DrawPixelV(s.settings.yellow.positions[i], s.settings.yellow.color)
        }

        // Draw UI
        rlmu.begin_scope()
        ctx.style.colors[.WINDOW_BG] = transmute(mu.Color)rl.ColorAlpha(rl.BLACK, 0.7)
        draw_ui(ctx, &s)
    }
}