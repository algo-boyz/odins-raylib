package fluid

import "core:fmt"
import "core:math"
import rl "vendor:raylib"

WIN_WIDTH :: 1200
WIN_HEIGHT :: 800
CELL_SIZE :: 20
NUM_COLS :: 100
NUM_ROWS :: 40
ITERATIONS :: 10

MaxValue: f32 = 1.0
MinValue: f32 = 0.005
MaxCompress: f32 = 0.25
MinFlow: f32 = 0.01  // Increased from 0.005 to prevent tiny flows
MaxFlow: f32 = 4.0
FlowSpeed: f32 = 1.0
FLOW_STABLE_THRESHOLD :: 60
SETTLE_EPSILON :: 0.02  // Increased more to force settling
SIGNIFICANT_FLOW :: 0.02  // Only unsettle neighbors for significant flows

HORIZONTAL_DIFFUSION_STRENGTH :: 0.2  // Lowered from 0.5 for gentler smoothing
HORIZONTAL_FLOW_DIVISOR :: 4.0        // Reverted from 2.0 for ~2x slower lateral spread
HORIZONTAL_EPSILON :: 0.005           // Smaller threshold for horizontal dampening (was SETTLE_EPSILON*2=0.04)
DIFFUSION_ITERATIONS :: 1             // Reduced from 3 for less aggressive post-flow diffusion

RENDER_FLOATING_LIQUID :: false
RENDER_DOWN_FLOWING_LIQUID :: true

Cell_Type :: enum {
    blank,
    solid,
}

Flow_Direction_Bit :: enum u8 {
    Down = 1 << 0,
    Left = 1 << 1,
    Right = 1 << 2,
    Up = 1 << 3,
}

Cell :: struct {
    liquid: f32,
    type: Cell_Type,
    settled: bool,
    settle_count: i32,
    flow_dir: u8,
    last_flow_dir: u8,
    flow_stable: i32,
    oscillation_detect: i32,  // Counter for detecting oscillations
}

calculate_vertical_flow_value :: proc(remaining: f32, dest_liquid: f32) -> f32 {
    sum: f32 = remaining + dest_liquid
    v: f32 = 0.0
    if sum <= MaxValue {
        v = MaxValue
    } else if sum < 2 * MaxValue + MaxCompress {
        v = (MaxValue * MaxValue + sum * MaxCompress) / (MaxValue + MaxCompress)
    } else {
        v = (sum + MaxCompress) / 2.0
    }
    return v
}

add_liquid :: proc(cell: ^Cell, amount: f32) {
    cell.liquid += amount
    cell.settled = false
    cell.settle_count = 0
}

displace :: proc(liquid_amount: f32, x: int, y: int, grid: ^[NUM_COLS][NUM_ROWS]Cell) {
    if liquid_amount <= MinValue {
        return
    }

    if y + 1 < NUM_ROWS {
        dest := &grid[x][y + 1]
        if dest.type == .blank {
            add_liquid(dest, liquid_amount)
            return
        }
    }

    left_open := x - 1 >= 0 && grid[x - 1][y].type == .blank
    right_open := x + 1 < NUM_COLS && grid[x + 1][y].type == .blank
    num_sides := (left_open ? 1 : 0) + (right_open ? 1 : 0)
    if num_sides > 0 {
        side_amount := liquid_amount / f32(num_sides)
        if left_open {
            add_liquid(&grid[x - 1][y], side_amount)
        }
        if right_open {
            add_liquid(&grid[x + 1][y], side_amount)
        }
        return
    }

    if y - 1 >= 0 {
        dest := &grid[x][y - 1]
        if dest.type == .blank {
            add_liquid(dest, liquid_amount)
            return
        }
    }
}

set_type :: proc(cell: ^Cell, t: Cell_Type, x: int, y: int, grid: ^[NUM_COLS][NUM_ROWS]Cell) {
    changed := t != cell.type
    old_liquid := cell.liquid
    cell.type = t
    if t == .solid {
        if old_liquid > MinValue {
            displace(old_liquid, x, y, grid)
        }
        cell.liquid = 0
    }
    if changed {
        unsettle_neighbors(x, y, grid)
    }
}

unsettle_neighbors :: proc(x: int, y: int, grid: ^[NUM_COLS][NUM_ROWS]Cell) {
    if x - 1 >= 0 {
        n := &grid[x - 1][y]
        n.settled = false
        n.settle_count = 0
    }
    if x + 1 < NUM_COLS {
        n := &grid[x + 1][y]
        n.settled = false
        n.settle_count = 0
    }
    if y - 1 >= 0 {
        n := &grid[x][y - 1]
        n.settled = false
        n.settle_count = 0
    }
    if y + 1 < NUM_ROWS {
        n := &grid[x][y + 1]
        n.settled = false
        n.settle_count = 0
    }
}

do_simulate :: proc(grid: ^[NUM_COLS][NUM_ROWS]Cell) {
    for x in 0 ..< NUM_COLS {
        for y in 0 ..< NUM_ROWS {
            if grid[x][y].settled {
                grid[x][y].flow_dir = 0
            }
        }
    }

    diffs: [NUM_COLS][NUM_ROWS]f32
    for i in 0 ..< NUM_COLS {
        for j in 0 ..< NUM_ROWS {
            diffs[i][j] = 0
        }
    }

    for x in 0 ..< NUM_COLS {
        for y in 0 ..< NUM_ROWS {
            cell := &grid[x][y]
            if cell.type == .solid {
                cell.liquid = 0
                continue
            }
            if cell.settled {
                continue
            }
            if cell.liquid == 0 {
                continue
            }
            if cell.liquid < MinValue {
                cell.liquid = 0
                continue
            }

            old_flow_dir := cell.flow_dir
            cell.flow_dir = 0
            start_value := cell.liquid
            remaining_value := start_value

            // FLOW DOWN
            flow: f32 = 0
            if y + 1 < NUM_ROWS {
                bottom_cell := &grid[x][y + 1]
                if bottom_cell.type == .blank {
                    target_v := calculate_vertical_flow_value(remaining_value, bottom_cell.liquid)
                    flow = target_v - bottom_cell.liquid
                    if bottom_cell.liquid > 0 && flow > MinFlow {
                        flow *= FlowSpeed
                    }
                    flow = math.max(flow, 0)
                    flow = math.min(flow, math.min(MaxFlow, remaining_value))
                    if flow > 0 {
                        remaining_value -= flow
                        diffs[x][y] -= flow
                        diffs[x][y + 1] += flow
                        cell.flow_dir |= u8(Flow_Direction_Bit.Down)
                        bottom_cell.settled = false
                        bottom_cell.settle_count = 0
                    }
                }
            }
            if remaining_value < MinValue {
                diffs[x][y] -= remaining_value
                continue
            }

            // HORIZONTAL FLOWS (Left + Right, symmetric)
            horizontal_excess: f32 = 0
            left_flow: f32 = 0
            right_flow: f32 = 0

            if x - 1 >= 0 {
                left_cell := &grid[x - 1][y]
                if left_cell.type == .blank {
                    diff := remaining_value - left_cell.liquid
                    if math.abs(diff) >= HORIZONTAL_EPSILON {  // Reduced threshold for smoother equalization
                        potential_flow := diff / HORIZONTAL_FLOW_DIVISOR  // Slower: /4.0 for less lateral spread
                        left_flow = math.max(0, math.min(MaxFlow, potential_flow))
                        if left_flow > MinFlow {
                            left_flow *= FlowSpeed
                        }
                        horizontal_excess += left_flow  // Track total horizontal outflow for remaining calc
                    }
                }
            }

            if x + 1 < NUM_COLS {
                right_cell := &grid[x + 1][y]
                if right_cell.type == .blank {
                    diff := remaining_value - right_cell.liquid
                    if math.abs(diff) >= HORIZONTAL_EPSILON {
                        potential_flow := diff / HORIZONTAL_FLOW_DIVISOR
                        right_flow = math.max(0, math.min(MaxFlow, potential_flow))
                        if right_flow > MinFlow {
                            right_flow *= FlowSpeed
                        }
                        horizontal_excess += right_flow
                    }
                }
            }

            // Apply horizontal flows (subtract total excess first, then add to neighbors)
            if horizontal_excess > 0 {
                remaining_value -= horizontal_excess
                diffs[x][y] -= horizontal_excess

                if left_flow > 0 {
                    diffs[x - 1][y] += left_flow
                    grid[x - 1][y].settled = false
                    grid[x - 1][y].settle_count = 0
                    cell.flow_dir |= u8(Flow_Direction_Bit.Left)
                }
                if right_flow > 0 {
                    diffs[x + 1][y] += right_flow
                    grid[x + 1][y].settled = false
                    grid[x + 1][y].settle_count = 0
                    cell.flow_dir |= u8(Flow_Direction_Bit.Right)
                }
            }

            if remaining_value < MinValue {
                diffs[x][y] -= remaining_value
                continue
            }

            // FLOW UP
            if y - 1 >= 0 {
                top_cell := &grid[x][y - 1]
                if top_cell.type == .blank {
                    target_v := calculate_vertical_flow_value(remaining_value, top_cell.liquid)
                    flow = remaining_value - target_v
                    if flow > MinFlow {
                        flow *= FlowSpeed
                    }
                    flow = math.max(flow, 0)
                    flow = math.min(flow, math.min(MaxFlow, remaining_value))
                    if flow > 0 {
                        remaining_value -= flow
                        diffs[x][y] -= flow
                        diffs[x][y - 1] += flow
                        cell.flow_dir |= u8(Flow_Direction_Bit.Up)
                        top_cell.settled = false
                        top_cell.settle_count = 0
                    }
                }
            }
            if remaining_value < MinValue {
                diffs[x][y] -= remaining_value
                continue
            }

            // Detect oscillations (alternating flow patterns)
            is_horizontal := (cell.flow_dir & (u8(Flow_Direction_Bit.Left) | u8(Flow_Direction_Bit.Right))) != 0
            old_horizontal := (old_flow_dir & (u8(Flow_Direction_Bit.Left) | u8(Flow_Direction_Bit.Right))) != 0
            if is_horizontal && old_horizontal && cell.flow_dir != old_flow_dir {
                cell.oscillation_detect += 1
                if cell.oscillation_detect > 5 {
                    // Force settle if oscillating
                    cell.settled = true
                    cell.flow_dir = 0
                    continue
                }
            } else {
                cell.oscillation_detect = 0
            }

            // Update flow stable
            curr_dir := cell.flow_dir
            if curr_dir == cell.last_flow_dir && curr_dir != 0 {
                cell.flow_stable += 1
            } else {
                cell.flow_stable = 0
                cell.last_flow_dir = curr_dir
            }

            // Settle check
            flowed_amount := start_value - remaining_value
            if math.abs(flowed_amount) < SETTLE_EPSILON {
                cell.settle_count += 1
                if cell.settle_count >= 5 {  // Reduced from 10 for faster settling
                    cell.settled = true
                    cell.last_flow_dir = 0
                    cell.flow_stable = 0
                }
            } else {
                cell.settle_count = 0
                // Only unsettle neighbors for significant flows
                if math.abs(flowed_amount) > SIGNIFICANT_FLOW {
                    unsettle_neighbors(x, y, grid)
                }
            }
        }
    }

    // Apply diffs
    for x in 0 ..< NUM_COLS {
        for y in 0 ..< NUM_ROWS {
            cell := &grid[x][y]
            cell.liquid += diffs[x][y]
            if cell.type == .blank && cell.liquid < MinValue {
                cell.liquid = 0
                cell.settled = false
                cell.settle_count = 0
            }
        }
    }

    // Horizontal diffusion pass (after main apply, for final equalization) - conserving, blank-only
    for _ in 0 ..< DIFFUSION_ITERATIONS {
        for y in 0 ..< NUM_ROWS {
            temp_liquid: [NUM_COLS]f32
            for x in 0 ..< NUM_COLS {
                temp_liquid[x] = grid[x][y].liquid
            }

            for x in 0 ..< NUM_COLS {
                if grid[x][y].type != .blank {
                    continue
                }
                left_x := x - 1
                right_x := x + 1
                has_left := left_x >= 0 && grid[left_x][y].type == .blank
                has_right := right_x < NUM_COLS && grid[right_x][y].type == .blank
                num_adj := (has_left ? 1 : 0) + (has_right ? 1 : 0)
                if num_adj == 0 {
                    continue
                }
                left_l: f32 = has_left ? temp_liquid[left_x] : 0
                right_l: f32 = has_right ? temp_liquid[right_x] : 0
                avg_adj := (left_l + right_l) / f32(num_adj)
                diff := temp_liquid[x] - avg_adj
                flow_amount := diff * HORIZONTAL_DIFFUSION_STRENGTH / f32(num_adj)
                temp_liquid[x] -= flow_amount * f32(num_adj)
                if has_left {
                    temp_liquid[left_x] += flow_amount
                }
                if has_right {
                    temp_liquid[right_x] += flow_amount
                }
            }

            // Set back only to blanks
            for x in 0 ..< NUM_COLS {
                if grid[x][y].type == .blank {
                    grid[x][y].liquid = temp_liquid[x]
                    if grid[x][y].liquid < MinValue {
                        grid[x][y].liquid = 0
                        grid[x][y].settled = false
                        grid[x][y].settle_count = 0
                    } else {
                        grid[x][y].settled = false
                        grid[x][y].settle_count = 0
                    }
                }
            }
        }
    }
}

// Helper to find depth from actual liquid surface (with sub-cell precision)
find_surface_depth :: proc(x: int, y: int, grid: ^[NUM_COLS][NUM_ROWS]Cell) -> f32 {
    depth: f32 = 0.0
    // Trace upward, accumulating liquid amounts for smooth gradient
    for check_y := y - 1; check_y >= 0; check_y -= 1 {
        check_cell := grid[x][check_y]
        // Stop at air/empty space (the surface)
        if check_cell.type == .blank && check_cell.liquid <= MinValue {
            break
        }
        // Accumulate liquid amount (skip solids)
        if check_cell.type == .blank && check_cell.liquid > MinValue {
            depth += check_cell.liquid
        }
    }
    return depth
}

draw_grid :: proc() {
    for i in 0 ..< NUM_COLS + 1 {
        x := i32(i * CELL_SIZE)
        rl.DrawLine(x, 0, x, WIN_HEIGHT, rl.BLACK)
    }
    for j in 0 ..< NUM_ROWS + 1 {
        y := i32(j * CELL_SIZE)
        rl.DrawLine(0, y, WIN_WIDTH, y, rl.BLACK)
    }
}

draw_solids :: proc(grid: ^[NUM_COLS][NUM_ROWS]Cell) {
    for i in 0 ..< NUM_COLS {
        for j in 0 ..< NUM_ROWS {
            if grid[i][j].type == .solid {
                x := i32(i * CELL_SIZE)
                y := i32(j * CELL_SIZE)
                rl.DrawRectangle(x, y, CELL_SIZE, CELL_SIZE, rl.BLACK)
            }
        }
    }
}

handle_input :: proc(grid: ^[NUM_COLS][NUM_ROWS]Cell, prev_col: ^int, prev_row: ^int) {
    mouse_pos := rl.GetMousePosition()
    col := int(mouse_pos.x / CELL_SIZE)
    row := int(mouse_pos.y / CELL_SIZE)

    if rl.IsMouseButtonDown(.LEFT) {
        if col > 0 && col < NUM_COLS - 1 && row > 0 && row < NUM_ROWS - 1 {
            if col != prev_col^ || row != prev_row^ {
                current_type := grid[col][row].type
                new_type := current_type == Cell_Type.blank ? Cell_Type.solid : Cell_Type.blank
                set_type(&grid[col][row], new_type, col, row, grid)
                prev_col^ = col
                prev_row^ = row
            }
        }
    } else {
        prev_col^ = -1
        prev_row^ = -1
    }

    if rl.IsMouseButtonDown(.RIGHT) {
        if 0 <= col && col < NUM_COLS && 0 <= row && row < NUM_ROWS && grid[col][row].type == .blank {
            add_liquid(&grid[col][row], 5.0)
        }
    }
}

draw_fluid :: proc(grid: ^[NUM_COLS][NUM_ROWS]Cell, flow_textures: [16]rl.Texture2D) {
    for i in 0 ..< NUM_COLS {
        for j in 0 ..< NUM_ROWS {
            cell := grid[i][j]
            if cell.type != .blank {
                continue
            }
            liquid := cell.liquid

            color := rl.Color{0, 0, 0, 255}
            draw_liquid := false

            if liquid > MinValue {
                // Use new depth calculation
                depth := find_surface_depth(i, j, grid)
                depth_factor := math.min(f32(depth) / 10.0, 1.0)

                blue_r: f32 = 0.4
                blue_g: f32 = 0.6
                blue_b: f32 = 1.0
                dark_r: f32 = 0.0
                dark_g: f32 = 0.2
                dark_b: f32 = 0.5
                col_r := blue_r + depth_factor * (dark_r - blue_r)
                col_g := blue_g + depth_factor * (dark_g - blue_g)
                col_b := blue_b + depth_factor * (dark_b - blue_b)
                color = rl.Color{
                    u8(math.clamp(col_r * 255, 0, 255)),
                    u8(math.clamp(col_g * 255, 0, 255)),
                    u8(math.clamp(col_b * 255, 0, 255)),
                    255,
                }
                draw_liquid = true
            }

            if draw_liquid {
                height_norm := f32(math.min(1.0, liquid))
                height_f := height_norm * f32(CELL_SIZE)
                hide := false
                if !RENDER_FLOATING_LIQUID && j + 1 < NUM_ROWS {
                    bottom := grid[i][j + 1]
                    if bottom.type == .blank && bottom.liquid <= 0.99 {
                        hide = true
                    }
                }
                if hide {
                    height_f = 0
                    height_norm = 0
                }
                full := false
                if RENDER_DOWN_FLOWING_LIQUID && j - 1 >= 0 {
                    top := grid[i][j - 1]
                    if top.liquid > 0.01 || (top.flow_dir & u8(Flow_Direction_Bit.Down)) != 0 {  // Lowered from 0.05 for subtler upper streams
                        full = true
                    }
                }
                if full {
                    height_f = f32(CELL_SIZE)
                    height_norm = 1.0
                }
                if height_f > 0 {
                    x := i32(i * CELL_SIZE)
                    y_bottom := i32((j + 1) * CELL_SIZE)
                    y_top := y_bottom - i32(height_f)
                    rl.DrawRectangle(x, y_top, CELL_SIZE, i32(height_f), color)

                    // Interpolate with right neighbor for sloped edge
                    if i + 1 < NUM_COLS {
                        right_cell := grid[i + 1][j]
                        right_liquid := right_cell.liquid
                        right_height_norm := f32(math.min(1.0, right_liquid))
                        right_height_f := right_height_norm * f32(CELL_SIZE)
                        right_hide := false
                        if !RENDER_FLOATING_LIQUID && j + 1 < NUM_ROWS {
                            right_bottom := grid[i + 1][j + 1]
                            if right_bottom.type == .blank && right_bottom.liquid <= 0.99 {
                                right_hide = true
                            }
                        }
                        if right_hide {
                            right_height_f = 0
                            right_height_norm = 0
                        }
                        right_full := false
                        if RENDER_DOWN_FLOWING_LIQUID && j - 1 >= 0 {
                            right_top := grid[i + 1][j - 1]
                            if right_top.liquid > 0.01 || (right_top.flow_dir & u8(Flow_Direction_Bit.Down)) != 0 {  // Matching lowered threshold
                                right_full = true
                            }
                        }
                        if right_full {
                            right_height_f = f32(CELL_SIZE)
                            right_height_norm = 1.0
                        }

                        if math.abs(right_height_norm - height_norm) > 0.01 {
                            right_x := i32((i + 1) * CELL_SIZE)
                            right_y_top := y_bottom - i32(right_height_f)
                            rl.DrawLineEx(
                                rl.Vector2{f32(x + CELL_SIZE), f32(y_top)},
                                rl.Vector2{f32(right_x), f32(right_y_top)},
                                2.0,  // Thickness for anti-step
                                color,
                            )
                        }
                    }
                }

                x := i32(i * CELL_SIZE)
                y := i32(j * CELL_SIZE)
                line_color := rl.Color{0, 0, 0, 128}
                rl.DrawRectangleLines(x, y, CELL_SIZE, CELL_SIZE, line_color)
            }

            if cell.flow_dir != 0 && cell.flow_stable < FLOW_STABLE_THRESHOLD {
                index := i32(
                    ((cell.flow_dir & 1) != 0 ? u8(4) : 0) |
                    ((cell.flow_dir & 2) != 0 ? u8(8) : 0) |
                    ((cell.flow_dir & 4) != 0 ? u8(2) : 0) |
                    ((cell.flow_dir & 8) != 0 ? u8(1) : 0),
                )
                if index >= 0 && index < 16 {
                    tex := flow_textures[index]
                    if tex.id != 0 {
                        scale := f32(CELL_SIZE) / f32(tex.width)
                        pos := rl.Vector2{f32(i32(i * CELL_SIZE)), f32(i32(j * CELL_SIZE))}
                        tint := rl.Color{255, 255, 255, 204}
                        rl.DrawTextureEx(tex, pos, 0.0, scale, tint)
                    }
                }
            }
        }
    }
}

main :: proc() {
    cell_grid: [NUM_COLS][NUM_ROWS]Cell
    for i in 0 ..< NUM_COLS {
        for j in 0 ..< NUM_ROWS {
            is_border := i == 0 || i == NUM_COLS - 1 || j == 0 || j == NUM_ROWS - 1
            cell_grid[i][j] = Cell{
                liquid = 0,
                type = is_border ? .solid : .blank,
                settled = false,
                settle_count = 0,
                flow_dir = 0,
                last_flow_dir = 0,
                flow_stable = 0,
                oscillation_detect = 0,
            }
        }
    }

    rl.InitWindow(WIN_WIDTH, WIN_HEIGHT, "Cellular Automata Fluid Sim2D")
    rl.SetTargetFPS(60)

    flow_textures: [16]rl.Texture2D
    for i in 0 ..< 16 {
        flow_textures[i] = rl.LoadTexture(fmt.ctprintf("../assets/%d.png", i))
    }
    defer {
        for tex in flow_textures {
            rl.UnloadTexture(tex)
        }
    }

    prev_col : int = -1
    prev_row : int = -1

    for !rl.WindowShouldClose() {
        handle_input(&cell_grid, &prev_col, &prev_row)
        for _ in 0 ..< ITERATIONS {
            do_simulate(&cell_grid)
        }

        rl.BeginDrawing()
        rl.ClearBackground(rl.RAYWHITE)
        draw_solids(&cell_grid)
        draw_fluid(&cell_grid, flow_textures)
        rl.EndDrawing()
    }

    rl.CloseWindow()
}