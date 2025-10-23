package main

import "base:intrinsics"
import "core:fmt"
import "core:math/bits"
import "core:math/rand"
import "core:time"
import rl "vendor:raylib"
import bm "../"

BIT_WIDTH :: 8

Demo :: struct {
    origin: bm.Matrix,
    steps: [4]bm.Matrix,
    current_step: int,
    max_steps: int,
    is_animating: bool,
    animation_timer: f32,
    animation_speed: f32,
    completed: bool,
}

init :: proc(demo: ^Demo) {
    bm.matrix_init(&demo.origin)
    bm.matrix_copy(&demo.steps[0], &demo.origin)
    
    // Pre-calculate transpose steps
    calculate_steps(demo)
    
    demo.current_step = 0
    demo.max_steps = 3
    demo.is_animating = false
    demo.animation_timer = 0
    demo.animation_speed = 2
    demo.completed = false
}

calculate_steps :: proc(demo: ^Demo) {
    temp_matrix := demo.origin
    step_idx := 1
    swap_width := BIT_WIDTH
    
    for swap_width != 1 {
        swap_width >>= 1
        bm.matrix_transpose_step(&temp_matrix, swap_width)
        if step_idx < len(demo.steps) {
            bm.matrix_copy(&demo.steps[step_idx], &temp_matrix)
            step_idx += 1
        }
    }
}

start_animation :: proc(demo: ^Demo) {
    if !demo.is_animating && !demo.completed {
        demo.is_animating = true
        demo.current_step = 0
        demo.animation_timer = 0
    }
}

next_step :: proc(demo: ^Demo) {
    if demo.is_animating {
        demo.current_step += 1
        if demo.current_step > demo.max_steps {
            demo.is_animating = false
            demo.current_step = demo.max_steps
            demo.completed = true
        }
        demo.animation_timer = 0
    }
}

reset :: proc(demo: ^Demo) {
    init(demo)
}

update :: proc(demo: ^Demo, delta_time: f32) {
    if demo.is_animating {
        demo.animation_timer += delta_time
        if demo.animation_timer >= demo.animation_speed {
            next_step(demo)
        }
    }
}

// Visualization constants and data
CELL_SIZE :: 30
MARGIN :: 25
WIDTH: i32 = (BIT_WIDTH * CELL_SIZE + MARGIN) * 5 + MARGIN
HEIGHT: i32 = BIT_WIDTH * CELL_SIZE + MARGIN * 3 + 200

LABEL_SIZE :: 14

colors := [8]rl.Color{
    {167, 87, 168, 255},   // A - Purple
    {183, 110, 121, 255},  // B - Pink  
    {199, 133, 74, 255},   // C - Orange
    {215, 156, 27, 255},   // D - Yellow
    {167, 87, 168, 255},   // E - Light Purple
    {247, 202, 184, 255},  // F - Peach
    {103, 225, 137, 255},  // G - Green
    {119, 248, 90, 255},   // H - Bright Green
}

// Demo visualization
draw_matrix :: proc(m: ^bm.Matrix, start_x, start_y: i32, step: int) {
    for row in 0..<BIT_WIDTH {
        pattern := m.data[row]
        for col in 0..<BIT_WIDTH {
            x := start_x + i32(col) * CELL_SIZE
            y := start_y + i32(row) * CELL_SIZE
            
            // Color based on original row
            original_row := m.origins[row][col]
            color := colors[original_row % len(colors)]
            bit_txt := fmt.aprintf("%c%d", 'A' + original_row, col + 1)
            defer delete(bit_txt)
            
            rl.DrawRectangle(x, y, CELL_SIZE - 2, CELL_SIZE - 2, color)
            
            // Draw the bit text centered
            text_width := rl.MeasureText(cstring(raw_data(bit_txt)), 12)
            text_x := x + CELL_SIZE/2 - text_width/2
            text_y := y + CELL_SIZE/2 - 6
            rl.DrawText(cstring(raw_data(bit_txt)), text_x, text_y, 12, rl.WHITE)
        }
    }
    // Draw grid lines
    for i in 0..=BIT_WIDTH {
        x := start_x + i32(i) * CELL_SIZE
        y1 := start_y
        y2 := start_y + BIT_WIDTH * CELL_SIZE
        rl.DrawLine(x, y1, x, y2, rl.GRAY)
        
        y := start_y + i32(i) * CELL_SIZE
        x1 := start_x
        x2 := start_x + BIT_WIDTH * CELL_SIZE
        rl.DrawLine(x1, y, x2, y, rl.GRAY)
    }
}

draw_labels :: proc(start_x, start_y: i32) {
    // Row labels (A-H)
    for i in 0..<BIT_WIDTH {
        label := fmt.aprintf("%c", 'A' + i)
        defer delete(label)
        y := start_y + i32(i) * CELL_SIZE + CELL_SIZE/2 - 8
        rl.DrawText(cstring(raw_data(label)), start_x - 25, y, LABEL_SIZE, rl.WHITE)
    }
    // Column labels (1-8)
    for i in 0..<BIT_WIDTH {
        label := fmt.aprintf("%d", i + 1)
        defer delete(label)
        x := start_x + i32(i) * CELL_SIZE + CELL_SIZE/2 - 6
        y := start_y + BIT_WIDTH * CELL_SIZE + 5
        rl.DrawText(cstring(raw_data(label)), x, y, LABEL_SIZE, rl.WHITE)
    }
}

draw_color_legend :: proc(start_x, start_y: i32) {
    for i in 0..<BIT_WIDTH {
        x := start_x + i32(i * 80)
        y := start_y + 25
        
        rl.DrawRectangle(x, y, 20, 20, colors[i])
        rl.DrawRectangleLines(x, y, 20, 20, rl.WHITE)
        
        label := fmt.aprintf("Row %c", 'A' + i)
        defer delete(label)
        rl.DrawText(cstring(raw_data(label)), x + 25, y + 3, 12, rl.WHITE)
    }
}

draw :: proc(demo: ^Demo) {
    rl.BeginDrawing()
    rl.ClearBackground({30, 30, 40, 255})
    rl.DrawText("Educational Bit Matrix Transpose", 10, 10, 24, rl.WHITE)
    start_y: i32 = 80
    matrices_to_show := demo.current_step + 1
    if !demo.is_animating && !demo.completed {
        matrices_to_show = 1
    }
    available_width := WIDTH - 2 * MARGIN
    mat_width: i32 = BIT_WIDTH * CELL_SIZE
    spacing := (available_width - i32(matrices_to_show) * mat_width) / i32(matrices_to_show + 1)
    
    step_names := []string{"Source", "Swap 4x4", "Swap 2x2", "Swap 1x1 - transposed"}
    
    for i in 0..<matrices_to_show {
        x := MARGIN + spacing + i32(i) * (mat_width + spacing)
        // Draw step label
        label_txt := step_names[i]
        if i == demo.max_steps {
            label_txt = step_names[3]
        }
        rl.DrawText(cstring(raw_data(label_txt)), x, start_y, 18, rl.WHITE)
        
        // Highlight current step
        if demo.is_animating && i == demo.current_step {
            rl.DrawRectangleLines(x - 5, start_y + 25, mat_width + 10, mat_width + 10, rl.YELLOW)
        }
        // Draw matrix
        y := start_y + 30
        draw_matrix(&demo.steps[i], x, y, i)
        if i == 0 {
            draw_labels(x, y)
        }
    }
    // Draw info text
    info_y := start_y + BIT_WIDTH * CELL_SIZE + 90
    curr_step_txt := ""
    
    if !demo.is_animating && !demo.completed {
        curr_step_txt = "Press T to begin transpose animation"
    } else if demo.completed {
        curr_step_txt = "Press R to reset"
    } else {
        switch demo.current_step {
        case 0:
            curr_step_txt = "8x8 bit matrix"
        case 1:
            curr_step_txt = "Step 1: Swap 4x4 blocks across main diagonal"
        case 2:
            curr_step_txt = "Step 2: Swap 2x2 blocks within each quadrant"
        case 3:
            curr_step_txt = "Step 3: Swap 1x1 blocks (individual bits) - matrix transposed!"
        }
    }
    rl.DrawText(cstring(raw_data(curr_step_txt)), 10, info_y, 18, rl.YELLOW)
    
    draw_color_legend(10, info_y + 30)
    rl.EndDrawing()
}

main :: proc() {
    rl.InitWindow(WIDTH, HEIGHT, "Bit Matrix Transpose")
    rl.SetTargetFPS(60)

    demo: Demo
    init(&demo)
    
    for !rl.WindowShouldClose() {
        if rl.IsKeyPressed(.T) {
            if !demo.is_animating && !demo.completed {
                start_animation(&demo)
            } else if demo.is_animating {
                next_step(&demo)
            }
        }
        if rl.IsKeyPressed(.R) {
            reset(&demo)
        }   
        update(&demo, rl.GetFrameTime())
        draw(&demo)
    }
    rl.CloseWindow()
}