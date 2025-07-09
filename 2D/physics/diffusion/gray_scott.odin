package main

import rl "vendor:raylib"
import "core:math"
import "core:fmt"

WIDTH :: 1200
HEIGHT :: 800
CELL_SIDE :: 5
LEN_COL :: HEIGHT / CELL_SIDE
LEN_ROW :: WIDTH / CELL_SIDE

Cell :: struct {
    A, B: f32,  // Concentration of chemical A/B
}

Pattern :: struct {
    name: cstring,
    f, k: f32,
}

patterns := [15]Pattern{
    {"Mitosis", 0.0367, 0.0649},
    {"Coral Growth", 0.0545, 0.062},
    {"Fingerprint", 0.055, 0.062},
    {"Spirals", 0.018, 0.051},
    {"Worms", 0.078, 0.061},
    {"Maze", 0.029, 0.057},
    {"Bubbles", 0.098, 0.057},
    {"Spots and Loops", 0.039, 0.058},
    {"Waves", 0.014, 0.054},
    {"Splotches", 0.026, 0.051},
    {"Solitons", 0.03, 0.06},
    {"Dots", 0.05, 0.065},
    {"Stripes", 0.025, 0.06},
    {"Cross Waves", 0.012, 0.045},
    {"Mixed", 0.022, 0.051},
}

grid: [LEN_ROW][LEN_COL]Cell
temp_grid: [LEN_ROW][LEN_COL]Cell
pause: bool = false
current_pattern: int = 1  // Start with Coral Growth
show_dropdown: bool = false
dropdown_scroll: int = 0

// Reaction-diffusion params
D_A: f32 = 1.0
D_B: f32 = 0.5
f: f32 = 0.0545  // Feed rate
k: f32 = 0.062   // Kill rate

// Shader for luminescent effect
luminescent_shader: rl.Shader
time_uniform: i32

main :: proc() {
    flags := rl.ConfigFlags { 
        rl.ConfigFlag.MSAA_4X_HINT,
        rl.ConfigFlag.WINDOW_RESIZABLE,
    }
    rl.SetConfigFlags(flags) 
    rl.InitWindow(WIDTH, HEIGHT, "Chemical Reaction Diffusion Simulation")
    defer rl.CloseWindow()
    rl.SetTargetFPS(60)

    luminescent_shader = rl.LoadShaderFromMemory(nil, fragment_shader_code)
    time_uniform = rl.GetShaderLocation(luminescent_shader, "time")
    defer rl.UnloadShader(luminescent_shader)

    reset_grid()
    set_pattern(current_pattern)

    for !rl.WindowShouldClose() {
        rl.BeginDrawing()
        rl.ClearBackground(rl.BLACK)
            
            // Update shader time
            time_value := f32(rl.GetTime())
            rl.SetShaderValue(luminescent_shader, time_uniform, &time_value, rl.ShaderUniformDataType.FLOAT)
            // Luminescent effect
            rl.BeginShaderMode(luminescent_shader)
                draw_grid()
            rl.EndShaderMode()

            draw_ui()
        rl.EndDrawing()

        if !pause do simulate()
        handle_input()
    }
}

laplacian_func :: proc(x, y: int, is_chemical_a: bool) -> f32 {
    left := (x == 0) ? LEN_ROW - 1 : x - 1
    right := (x == LEN_ROW - 1) ? 0 : x + 1
    up := (y == 0) ? LEN_COL - 1 : y - 1
    down := (y == LEN_COL - 1) ? 0 : y + 1
    
    if is_chemical_a {
        return (0.2 * (grid[right][y].A + grid[left][y].A + grid[x][down].A + grid[x][up].A) +
                0.05 * (grid[left][up].A + grid[right][up].A + grid[left][down].A + grid[right][down].A) - grid[x][y].A)
    } else {
        return (0.2 * (grid[right][y].B + grid[left][y].B + grid[x][down].B + grid[x][up].B) +
                0.05 * (grid[left][up].B + grid[right][up].B + grid[left][down].B + grid[right][down].B) - grid[x][y].B)
    }
}

simulate :: proc() {
    for row in 0..<LEN_ROW {
        for column in 0..<LEN_COL {
            a := grid[row][column].A
            b := grid[row][column].B
            // Reaction-diffusion equations
            temp_grid[row][column].A = clamp(
                a + (D_A * laplacian_func(row, column, true) - a * b * b + f * (1 - a)),
                0, 1
            )
            temp_grid[row][column].B = clamp(
                b + (D_B * laplacian_func(row, column, false) + a * b * b - (k + f) * b),
                0, 1
            )
        }
    }
    // Swap grids
    for i in 0..<LEN_ROW {
        for j in 0..<LEN_COL {
            grid[i][j] = temp_grid[i][j]
        }
    }
}

draw_grid :: proc() {
    for row in 0..<LEN_ROW {
        for column in 0..<LEN_COL {
            // Create luminescent blue effect based on chemical B concentration
            a := grid[row][column].A
            b := grid[row][column].B
            intensity := b * 255
            blue_glow := u8(clamp(intensity * 1.5, 0, 255))
            green_glow := u8(clamp(intensity * 0.8, 0, 255))
            red_glow := u8(clamp(intensity * 0.3, 0, 255))
            cell_color := rl.Color{red_glow, green_glow, blue_glow, 255}
            rl.DrawRectangle(
                i32(row * CELL_SIDE),
                i32(column * CELL_SIDE),
                CELL_SIDE,
                CELL_SIDE,
                cell_color
            )
        }
    }
}

draw_ui :: proc() {
    rl.DrawRectangle(10, 10, 280, 200, rl.Color{0, 0, 0, 200})
    rl.DrawRectangleLines(10, 10, 280, 200, rl.WHITE)
    rl.DrawText("Gray-Scott Diffusion", 20, 20, 16, rl.WHITE)
    
    pattern_text := fmt.ctprintf("Pattern: %s", patterns[current_pattern].name)
    rl.DrawText(pattern_text, 20, 50, 14, rl.WHITE)
    
    // Dropdown button
    dropdown_rect := rl.Rectangle{20, 70, 200, 25}
    dropdown_color := show_dropdown ? rl.Color{100, 100, 100, 255} : rl.Color{60, 60, 60, 255}
    rl.DrawRectangleRec(dropdown_rect, dropdown_color)
    rl.DrawRectangleLinesEx(dropdown_rect, 1, rl.WHITE)
    rl.DrawText("Select Pattern", 25, 77, 12, rl.WHITE)

    start_pause_text :cstring = pause ? "Start" : "Pause"
    start_pause_color := pause ? rl.Color{0, 150, 0, 255} : rl.Color{150, 150, 0, 255}
    
    rl.DrawRectangle(20, 140, 80, 30, start_pause_color)
    rl.DrawRectangleLines(20, 140, 80, 30, rl.WHITE)
    rl.DrawText(start_pause_text, 35, 150, 14, rl.WHITE)
    
    rl.DrawRectangle(110, 140, 80, 30, rl.Color{150, 0, 0, 255})
    rl.DrawRectangleLines(110, 140, 80, 30, rl.WHITE)
    rl.DrawText("Reset", 135, 150, 14, rl.WHITE)
    
    // Instructions
    rl.DrawText("Click/Drag to add chemical B", 20, 180, 12, rl.GRAY)
    rl.DrawText("Space to Pause/Resume", 20, 195, 12, rl.GRAY)
    
    // Dropdown list (draw last to ensure it's on top)
    if show_dropdown {
        dropdown_height := f32(min(len(patterns) * 25, 200))
        list_rect := rl.Rectangle{20, 95, 200, dropdown_height}
        // Draw solid background with strong opacity
        rl.DrawRectangleRec(list_rect, rl.Color{20, 20, 20, 255})
        // Draw border
        rl.DrawRectangleLinesEx(list_rect, 2, rl.WHITE)
        // Draw shadow effect
        shadow_rect := rl.Rectangle{22, 97, 200, dropdown_height}
        rl.DrawRectangleRec(shadow_rect, rl.Color{0, 0, 0, 100})
        // Draw items
        for i in 0..<len(patterns) {
            item_y := 95 + i * 25 - dropdown_scroll * 25
            if item_y >= 95 && item_y < 95 + int(dropdown_height) {
                item_rect := rl.Rectangle{20, f32(item_y), 200, 25}
                // Highlight current selection
                if i == current_pattern {
                    rl.DrawRectangleRec(item_rect, rl.Color{0, 120, 215, 255})
                }
                // Highlight hover effect
                mouse_pos := rl.GetMousePosition()
                if rl.CheckCollisionPointRec(mouse_pos, item_rect) && show_dropdown {
                    if i != current_pattern {
                        rl.DrawRectangleRec(item_rect, rl.Color{80, 80, 80, 255})
                    }
                }
                rl.DrawText(patterns[i].name, 25, i32(item_y + 5), 12, rl.WHITE)
            }
        }
    }
}

handle_input :: proc() {
    mouse_pos := rl.GetMousePosition()
    
    if rl.IsMouseButtonPressed(rl.MouseButton.LEFT) {
        // Check dropdown button
        if mouse_pos.x >= 20 && mouse_pos.x <= 220 && mouse_pos.y >= 70 && mouse_pos.y <= 95 {
            show_dropdown = !show_dropdown
        } else if show_dropdown && mouse_pos.x >= 20 && mouse_pos.x <= 220 && mouse_pos.y >= 95 {
            // Select pattern from dropdown
            dropdown_height := f32(min(len(patterns) * 25, 200))
            if mouse_pos.y < 95 + dropdown_height {
                selected := int((mouse_pos.y - 95) / 25) + dropdown_scroll
                if selected >= 0 && selected < len(patterns) {
                    current_pattern = selected
                    set_pattern(current_pattern)
                    show_dropdown = false
                }
            }
        } else if mouse_pos.x >= 20 && mouse_pos.x <= 100 && mouse_pos.y >= 140 && mouse_pos.y <= 170 {
            pause = !pause
        } else if mouse_pos.x >= 110 && mouse_pos.x <= 190 && mouse_pos.y >= 140 && mouse_pos.y <= 170 {
            reset_grid()
        } else {
            // Close dropdown if clicking elsewhere
            show_dropdown = false
        }
    }
    // Add chemical B on mouse drag
    if rl.IsMouseButtonDown(rl.MouseButton.LEFT) && !show_dropdown {
        x := int(mouse_pos.x / CELL_SIDE)
        y := int(mouse_pos.y / CELL_SIDE)
        if x >= 0 && x < LEN_ROW && y >= 0 && y < LEN_COL {
            // Add chemical B in a small area around mouse
            for dx in -2..=2 {
                for dy in -2..=2 {
                    nx := x + dx
                    ny := y + dy
                    if nx >= 0 && nx < LEN_ROW && ny >= 0 && ny < LEN_COL {
                        grid[nx][ny].B = 1.0
                    }
                }
            }
        }
    }
    // Keyboard shortcuts
    if rl.IsKeyPressed(rl.KeyboardKey.SPACE) {
        pause = !pause
    }
    if rl.IsKeyPressed(rl.KeyboardKey.ENTER) {
        reset_grid()
    }
    if rl.IsKeyPressed(rl.KeyboardKey.ONE) do set_pattern(0)
    if rl.IsKeyPressed(rl.KeyboardKey.TWO) do set_pattern(1)
    if rl.IsKeyPressed(rl.KeyboardKey.THREE) do set_pattern(2)
    if rl.IsKeyPressed(rl.KeyboardKey.FOUR) do set_pattern(3)
    if rl.IsKeyPressed(rl.KeyboardKey.FIVE) do set_pattern(4)
}

// Set pattern parameters
set_pattern :: proc(pattern_index: int) {
    if pattern_index >= 0 && pattern_index < len(patterns) {
        current_pattern = pattern_index
        f = patterns[pattern_index].f
        k = patterns[pattern_index].k
    }
}

// Reset grid to initial state
reset_grid :: proc() {
    for i in 0..<LEN_ROW {
        for j in 0..<LEN_COL {
            grid[i][j] = {1, 0}
            temp_grid[i][j] = {1, 0}
        }
    }
}

fragment_shader_code :: `
#version 330

in vec2 fragTexCoord;
in vec4 fragColor;
uniform float time;
out vec4 finalColor;

void main() {
    vec3 color = fragColor.rgb;
    float intensity = (color.r + color.g + color.b) / 3.0;
    
    // Luminescent blue glow effect
    vec3 glowColor = vec3(0.2, 0.6, 1.0);
    vec3 enhanced = color + glowColor * intensity * (1.0 + 0.3 * sin(time * 2.0));
    
    // Subtle pulse effect
    float pulse = 1.0 + 0.1 * sin(time * 4.0);
    enhanced *= pulse;
    
    finalColor = vec4(enhanced, fragColor.a);
}
`