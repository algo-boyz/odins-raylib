package qlearn

import "core:fmt"
import "core:math"
import "core:mem"
import "core:strings"
import rl "vendor:raylib"

// Cell types for the grid world
Cell_Type :: enum {
    EMPTY,
    WALL,
    GOAL,
    AGENT,
    OBSTACLE,
    START,
}

// Color scheme for visualization
Color_Scheme :: struct {
    empty_cell:       rl.Color,
    wall_cell:        rl.Color,
    goal_cell:        rl.Color,
    agent_color:      rl.Color,
    obstacle_color:   rl.Color,
    start_cell:       rl.Color,
    grid_lines:       rl.Color,
    text_color:       rl.Color,
    background:       rl.Color,
    q_value_positive: rl.Color,
    q_value_negative: rl.Color,
    trail_color:      rl.Color,
}

// Layout configuration
Layout_Config :: struct {
    margin:      i32,
    panel_height: i32,
    grid_area:   rl.Rectangle,
}

// Text rendering configuration
Text_Config :: struct {
    font:         rl.Font,
    font_size,
    line_spacing: i32,
    font_loaded:  bool,
}

// Visualization configuration
Visualization_Config :: struct {
    WIDTH,
    HEIGHT,
    fps_target,
    cell_size:     i32,
    show_q,
    show_grid,
    show_fps:      bool,
    grid_cols, grid_rows: i32, // Added grid dimensions for proper layout calculation
}

// Main visualization state
Visualization_State :: struct {
    config: Visualization_Config,
    colors: Color_Scheme,
    layout: Layout_Config,
    text:   Text_Config,
}
// Global visualization state
g_vis_state: ^Visualization_State

// Create default color scheme
create_default_color_scheme :: proc() -> Color_Scheme {
    return Color_Scheme{
        empty_cell       = rl.LIGHTGRAY,
        wall_cell        = rl.DARKGRAY,
        goal_cell        = rl.GREEN,
        agent_color      = rl.BLUE,
        obstacle_color   = rl.RED,
        start_cell       = rl.YELLOW,
        grid_lines       = rl.GRAY,
        text_color       = rl.BLACK,
        background       = rl.RAYWHITE,
        q_value_positive = rl.LIME,
        q_value_negative = rl.PINK,
        trail_color      = rl.SKYBLUE,
    }
}

// Get cell rectangle for drawing
get_cell_rect :: proc(vis: ^Visualization_State, x, y: i32) -> rl.Rectangle {
    if vis == nil do return rl.Rectangle{0, 0, 0, 0}
    
    cell_size := f32(vis.config.cell_size)
    start_x := vis.layout.grid_area.x
    start_y := vis.layout.grid_area.y
    
    return rl.Rectangle{
        x = start_x + f32(x) * cell_size,
        y = start_y + f32(y) * cell_size,
        width = cell_size,
        height = cell_size,
    }
}

// Draw a single cell
draw_cell :: proc(vis: ^Visualization_State, x, y: i32, cell_type: Cell_Type) {
    if vis == nil do return
    
    cell_rect := get_cell_rect(vis, x, y)
    cell_color: rl.Color
    
    switch cell_type {
    case .EMPTY:
        cell_color = vis.colors.empty_cell
    case .WALL:
        cell_color = vis.colors.wall_cell
    case .GOAL:
        cell_color = vis.colors.goal_cell
    case .AGENT:
        cell_color = vis.colors.agent_color
    case .OBSTACLE:
        cell_color = vis.colors.obstacle_color
    case .START:
        cell_color = vis.colors.start_cell
    case:
        cell_color = vis.colors.empty_cell
    }
    rl.DrawRectangleRec(cell_rect, cell_color)
    
    // Draw cell border if grid is enabled
    if vis.config.show_grid {
        rl.DrawRectangleLinesEx(cell_rect, 1, vis.colors.grid_lines)
    }
}

// Draw the entire grid world
draw_grid_world :: proc(vis: ^Visualization_State, world: ^Grid) {
    if world == nil || vis == nil do return
    
    // Draw all cells
    for y in 0..<world.height {
        for x in 0..<world.width {
            cell_type := world.grid[y][x]
            draw_cell(vis, x, y, cell_type)
        }
    }
    // Draw grid lines if enabled
    if vis.config.show_grid {
        draw_grid_lines(vis, world)
    }
}

// Draw grid lines
draw_grid_lines :: proc(vis: ^Visualization_State, world: ^Grid) {
    if vis == nil || world == nil do return
    
    cell_size := f32(vis.config.cell_size)
    start_x := vis.layout.grid_area.x
    start_y := vis.layout.grid_area.y
    grid_width := f32(world.width) * cell_size
    grid_height := f32(world.height) * cell_size
    
    // Draw vertical lines
    for x in 0..=world.width {
        line_x := start_x + f32(x) * cell_size
        rl.DrawLine(
            i32(line_x), i32(start_y),
            i32(line_x), i32(start_y + grid_height),
            vis.colors.grid_lines,
        )
    }
    // Draw horizontal lines
    for y in 0..=world.height {
        line_y := start_y + f32(y) * cell_size
        rl.DrawLine(
            i32(start_x), i32(line_y),
            i32(start_x + grid_width), i32(line_y),
            vis.colors.grid_lines,
        )
    }
}

// Draw agent at specified position
draw_agent :: proc(vis: ^Visualization_State, pos: Position) {
    if vis == nil do return
    
    cell_rect := get_cell_rect(vis, pos.x, pos.y)
    
    // Draw agent as a circle in the center of the cell
    center_x := cell_rect.x + cell_rect.width / 2
    center_y := cell_rect.y + cell_rect.height / 2
    radius := f32(vis.config.cell_size) * 0.3 // Agent is 30% of cell size
    
    rl.DrawCircle(i32(center_x), i32(center_y), radius, vis.colors.agent_color)
    // Draw agent border
    rl.DrawCircleLines(i32(center_x), i32(center_y), radius, rl.BLACK)
}

// Draw goal at specified position
draw_goal :: proc(vis: ^Visualization_State, pos: Position) {
    if vis == nil do return
    
    cell_rect := get_cell_rect(vis, pos.x, pos.y)
    
    // Draw goal as a filled rectangle with special pattern
    rl.DrawRectangleRec(cell_rect, vis.colors.goal_cell)
    
    // Draw goal symbol (star-like pattern)
    center_x := cell_rect.x + cell_rect.width / 2
    center_y := cell_rect.y + cell_rect.height / 2
    size := f32(vis.config.cell_size) * 0.4
    
    // Draw cross pattern for goal
    rl.DrawLineEx(
        rl.Vector2{center_x - size/2, center_y},
        rl.Vector2{center_x + size/2, center_y},
        3, rl.DARKGREEN,
    )
    rl.DrawLineEx(
        rl.Vector2{center_x, center_y - size/2},
        rl.Vector2{center_x, center_y + size/2},
        3, rl.DARKGREEN,
    )
}

// Draw walls in the grid world
draw_walls :: proc(vis: ^Visualization_State, world: ^Grid) {
    if world == nil || vis == nil do return
    
    for y in 0..<world.height {
        for x in 0..<world.width {
            if world.grid[y][x] == .WALL {
                cell_rect := get_cell_rect(vis, x, y)
                rl.DrawRectangleRec(cell_rect, vis.colors.wall_cell)
                // Add some texture to walls
                rl.DrawRectangleLinesEx(cell_rect, 2, rl.BLACK)
            }
        }
    }
}

// Convert Q-value to color for visualization
q_value_to_color :: proc(q_value, min_q, max_q: f32) -> rl.Color {
    if g_vis_state == nil do return rl.WHITE
    
    if max_q == min_q do return g_vis_state.colors.empty_cell
    
    // Normalize Q-value to 0-1 range
    normalized := (q_value - min_q) / (max_q - min_q)
    
    // Interpolate between negative and positive colors
    if normalized < 0.5 {
        // Interpolate from negative to neutral (gray)
        t := normalized * 2
        return rl.Color{
            u8(f32(g_vis_state.colors.q_value_negative.r) * (1 - t) + 128 * t),
            u8(f32(g_vis_state.colors.q_value_negative.g) * (1 - t) + 128 * t),
            u8(f32(g_vis_state.colors.q_value_negative.b) * (1 - t) + 128 * t),
            180,
        }
    } else {
        // Interpolate from neutral (gray) to positive
        t := (normalized - 0.5) * 2
        return rl.Color{
            u8(128 * (1 - t) + f32(g_vis_state.colors.q_value_positive.r) * t),
            u8(128 * (1 - t) + f32(g_vis_state.colors.q_value_positive.g) * t),
            u8(128 * (1 - t) + f32(g_vis_state.colors.q_value_positive.b) * t),
            180,
        }
    }
}

// Draw Q-values visualization
draw_q_values :: proc(vis: ^Visualization_State, world: ^Grid, agent: ^Q_Agent) {
    if agent == nil || world == nil || vis == nil || !vis.config.show_q do return
    
    // Find min and max Q-values for normalization
    min_q: f32 = 999999
    max_q: f32 = -999999
    
    for state in 0..<agent.num_states {
        // Only consider valid grid positions for min/max Q-value calculation
        pos := state_to_position(world, state)
        if pos.x >= 0 && pos.x < world.width && pos.y >= 0 && pos.y < world.height {
            if world.grid[pos.y][pos.x] != .WALL {
                for action in 0..<agent.num_actions {
                    q_val := agent.q_table[state][action]
                    if q_val < min_q do min_q = q_val
                    if q_val > max_q do max_q = q_val
                }
            }
        }
    }
    // Handle case where all Q-values are the same
    if min_q == max_q {
        min_q -= 1.0 // Arbitrary small value to make range non-zero
        max_q += 1.0
    }

    // Draw Q-value heatmap
    for y in 0..<world.height {
        for x in 0..<world.width {
            if world.grid[y][x] != .WALL {
                state := y * world.width + x
                
                if int(state) < agent.num_states {
                    // Find maximum Q-value for this state
                    max_q_state:f32 = -math.F32_MAX // Use negative infinity
                    best_action := Action.UP // Default to UP
                    
                    for action in 0..<agent.num_actions {
                        q_val := agent.q_table[state][action]
                        if q_val > max_q_state {
                            max_q_state = q_val
                            best_action = Action(action)
                        }
                    }
                    // Draw Q-value as background color
                    cell_rect := get_cell_rect(vis, x, y)
                    q_color := q_value_to_color(max_q_state, min_q, max_q)
                    rl.DrawRectangleRec(cell_rect, q_color)
                    
                    // Draw policy arrow showing best action (centered and rotating in place)
                    center_x := cell_rect.x + cell_rect.width / 2
                    center_y := cell_rect.y + cell_rect.height / 2
                    arrow_size := f32(vis.config.cell_size) * 0.25 // Made slightly smaller
                    
                    // Calculate direction vector for the action
                    direction := rl.Vector2{0, 0}
                    #partial switch best_action {
                    case .UP:
                        direction = rl.Vector2{0, -1}
                    case .DOWN:
                        direction = rl.Vector2{0, 1}
                    case .LEFT:
                        direction = rl.Vector2{-1, 0}
                    case .RIGHT:
                        direction = rl.Vector2{1, 0}
                    }
                    
                    // Create arrow points centered around the center point
                    arrow_center := rl.Vector2{center_x, center_y}
                    
                    // Arrow shaft goes from back to front, centered on the cell center
                    start := rl.Vector2{
                        arrow_center.x - direction.x * arrow_size * 0.5,
                        arrow_center.y - direction.y * arrow_size * 0.5,
                    }
                    end := rl.Vector2{
                        arrow_center.x + direction.x * arrow_size * 0.5,
                        arrow_center.y + direction.y * arrow_size * 0.5,
                    }
                    
                    // Draw arrow shaft
                    rl.DrawLineEx(start, end, 3, rl.BLACK)
                    
                    // Draw arrowhead at the end point
                    arrowhead_len := f32(6) // length of arrowhead lines
                    arrowhead_width := f32(3) // half-width of arrowhead base
                    
                    arrowhead1 := rl.Vector2{
                        end.x - direction.x * arrowhead_len + direction.y * arrowhead_width,
                        end.y - direction.y * arrowhead_len - direction.x * arrowhead_width,
                    }
                    arrowhead2 := rl.Vector2{
                        end.x - direction.x * arrowhead_len - direction.y * arrowhead_width,
                        end.y - direction.y * arrowhead_len + direction.x * arrowhead_width,
                    }
                    rl.DrawLineEx(end, arrowhead1, 2, rl.BLACK)
                    rl.DrawLineEx(end, arrowhead2, 2, rl.BLACK)
                    
                    // Draw Q-value text if cell is large enough
                    if vis.config.cell_size > 50 { // Adjust threshold based on new font size
                        q_text := fmt.tprintf("%.2f", max_q_state)
                        // Use a smaller font for Q-values compared to general text
                        q_font_size := f32(vis.text.font_size) * 0.7 // 70% of main font size
                        text_measure := rl.MeasureTextEx(vis.text.font, strings.clone_to_cstring(q_text), q_font_size, f32(vis.text.line_spacing))
                        
                        // Position text in bottom portion of cell to avoid arrow
                        text_x := (cell_rect.x + (cell_rect.width - text_measure.x) / 2) - 20
                        text_y := (cell_rect.y + cell_rect.height * 0.75 - text_measure.y / 2) - 6
                        
                        rl.DrawTextEx(
                            vis.text.font,
                            strings.clone_to_cstring(q_text),
                            rl.Vector2{text_x, text_y},
                            q_font_size,
                            f32(vis.text.line_spacing),
                            vis.colors.text_color,
                        )
                    }
                }
            }
        }
    }
}

// Get global visualization state (for external access)
get_visualization_state :: proc() -> ^Visualization_State {
    return g_vis_state
}

// init_visualization now takes grid_width and grid_height to properly calculate layout
init_visualization :: proc(WIDTH, HEIGHT, cell_size, grid_width, grid_height: i32) -> ^Visualization_State {
    // Only initialize if g_vis_state is nil, to prevent re-initialization
    if g_vis_state == nil {
        g_vis_state = new(Visualization_State)
        if g_vis_state == nil {
            fmt.println("Error: Failed to allocate visualization state")
            // Handle error, maybe exit or panic
            return nil
        }
        
        // Initialize basic configuration
        g_vis_state.config.WIDTH = WIDTH
        g_vis_state.config.HEIGHT = HEIGHT
        g_vis_state.config.cell_size = cell_size
        g_vis_state.config.show_q = true
        g_vis_state.config.show_grid = true
        g_vis_state.config.show_fps = true
        g_vis_state.config.fps_target = 60
        g_vis_state.config.grid_cols = grid_width  // Store grid dimensions
        g_vis_state.config.grid_rows = grid_height // Store grid dimensions
        
        // Init color scheme
        g_vis_state.colors = create_default_color_scheme()
        
        // Init text renderer
        // Load custom font
        font_path := strings.clone_to_cstring("../../assets/JetbrainsMono-Regular.ttf") // Make sure this path is correct
        g_vis_state.text.font = rl.LoadFont(font_path)
        if (g_vis_state.text.font.texture.id == 0) { // Check if font loading failed
            fmt.println("Warning: Failed to load JetbrainsMono-Regular.ttf, using default font.")
            g_vis_state.text.font = rl.GetFontDefault()
            g_vis_state.text.font_loaded = false
        } else {
            g_vis_state.text.font_loaded = true
        }
        delete(font_path) // Free the C string

        g_vis_state.text.font_size = 24 // Increased font size for main text
        g_vis_state.text.line_spacing = 3
        
        // Calculate required grid dimensions based on the provided grid_width and grid_height
        required_grid_width := f32(g_vis_state.config.grid_cols) * f32(cell_size)
        required_grid_height := f32(g_vis_state.config.grid_rows) * f32(cell_size)

        // Set a reasonable margin around the grid
        min_margin:i32 = 20
        g_vis_state.layout.margin = min_margin

        // Define a desired panel height for text information
        // This is a rough estimate; it might need fine-tuning based on actual text content
        estimated_panel_height := i32(f32(g_vis_state.text.font_size) * 4 + f32(min_margin)) // 4 lines of text + margin
        g_vis_state.layout.panel_height = estimated_panel_height

        // Calculate maximum available grid area, reserving space for top margin and bottom panel
        max_grid_width := f32(WIDTH - 2 * min_margin)
        max_grid_height := f32(HEIGHT - min_margin - g_vis_state.layout.panel_height - min_margin) // Top margin, panel, bottom margin
        
        // Adjust cell size if the grid is too large for the screen
        if required_grid_width > max_grid_width || required_grid_height > max_grid_height {
            // Recalculate cell_size to fit the grid within the available space
            scale_w := max_grid_width / f32(g_vis_state.config.grid_cols)
            scale_h := max_grid_height / f32(g_vis_state.config.grid_rows)
            g_vis_state.config.cell_size = i32(math.min(scale_w, scale_h))
            required_grid_width = f32(g_vis_state.config.grid_cols) * f32(g_vis_state.config.cell_size)
            required_grid_height = f32(g_vis_state.config.grid_rows) * f32(g_vis_state.config.cell_size)
            fmt.printf("Adjusted cell size to %d to fit grid on screen.\n", g_vis_state.config.cell_size)
        }

        // Center the grid horizontally
        grid_start_x := f32(min_margin) + (max_grid_width - required_grid_width) / 2
        
        // Position the grid vertically below the top margin and above the info panel
        grid_start_y := f32(min_margin) + (max_grid_height - required_grid_height) / 2
        
        g_vis_state.layout.grid_area = rl.Rectangle{
            x = grid_start_x,
            y = grid_start_y,
            width = required_grid_width,
            height = required_grid_height,
        }
        
        rl.InitWindow(WIDTH, HEIGHT, "RL Agent Visualization")
        rl.SetTargetFPS(g_vis_state.config.fps_target)
    }
    fmt.printf("Graphics initialized: %dx%d with cell size %d\n", WIDTH, HEIGHT, g_vis_state.config.cell_size)
    return g_vis_state
}

destroy_visualization :: proc(vis: ^Visualization_State) {
    // This is essentially a wrapper around cleanup_graphics, ensuring it only runs once
    // and clears the global state.
    cleanup_graphics()
}

cleanup_graphics :: proc() {
    if g_vis_state != nil {
        if g_vis_state.text.font_loaded {
            rl.UnloadFont(g_vis_state.text.font)
        }
        // Freeing the memory allocated by new()
        mem.free(g_vis_state) // Assuming 'new' allocates from default allocator
        g_vis_state = nil
        rl.CloseWindow() // Close the Raylib window
    }
}

// Draw FPS counter in the top-right corner
draw_fps_counter :: proc(vis: ^Visualization_State) {
    if vis == nil || !vis.config.show_fps do return
    
    // Get current FPS
    current_fps := rl.GetFPS()
    
    // Create FPS text
    fps_text := fmt.tprintf("FPS: %d", current_fps)
    
    // Calculate text dimensions using custom font
    font_size: f32 = f32(vis.text.font_size - 4) // Slightly smaller for FPS
    text_measure := rl.MeasureTextEx(vis.text.font, strings.clone_to_cstring(fps_text), font_size, f32(vis.text.line_spacing))
    
    // Position in top-right corner with some padding
    padding: i32 = 10
    text_x := i32(f32(vis.config.WIDTH) - text_measure.x - f32(padding))
    text_y := padding
    
    // Draw background rectangle for better visibility
    bg_rect := rl.Rectangle{
        x = f32(text_x - 5),
        y = f32(text_y - 2),
        width = text_measure.x + 10,
        height = text_measure.y + 4,
    }
    // Color based on FPS perf
    bg_color: rl.Color
    text_color: rl.Color

    if current_fps >= vis.config.fps_target - 5 {
        // Good performance - green
        bg_color = rl.Color{0, 150, 0, 200}  // Semi-transparent
        text_color = rl.WHITE
    } else if current_fps >= vis.config.fps_target - 15 {
        // Moderate performance - yellow
        bg_color = rl.Color{200, 200, 0, 200}
        text_color = rl.BLACK
    } else {
        // Poor performance - red
        bg_color = rl.Color{200, 0, 0, 200}
        text_color = rl.WHITE
    }
    rl.DrawRectangleRec(bg_rect, bg_color)
    rl.DrawRectangleLinesEx(bg_rect, 1, rl.BLACK)
    rl.DrawTextEx(vis.text.font, strings.clone_to_cstring(fps_text), rl.Vector2{f32(text_x), f32(text_y)}, font_size, f32(vis.text.line_spacing), text_color)
    
    // Optional: Draw additional performance info if FPS is low
    if current_fps < vis.config.fps_target - 15 {
        warning_text := "LOW FPS"
        warning_measure := rl.MeasureTextEx(vis.text.font, strings.clone_to_cstring(warning_text), f32(vis.text.font_size - 8), f32(vis.text.line_spacing))
        warning_x := i32(f32(vis.config.WIDTH) - warning_measure.x - f32(padding))
        warning_y := text_y + i32(text_measure.y) + 5
        warning_bg := rl.Rectangle{
            x = f32(warning_x - 3),
            y = f32(warning_y - 1),
            width = warning_measure.x + 6,
            height = warning_measure.y + 2,
        }
        rl.DrawRectangleRec(warning_bg, rl.Color{255, 100, 100, 180})
        rl.DrawTextEx(
            vis.text.font,
            strings.clone_to_cstring(warning_text),
            rl.Vector2{f32(warning_x), f32(warning_y)},
            f32(vis.text.font_size - 8),
            f32(vis.text.line_spacing),
            rl.Color{139, 0, 0, 255},
        )
    }
}