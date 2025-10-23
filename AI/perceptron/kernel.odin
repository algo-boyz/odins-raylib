package main

import "core:fmt"
import "core:math"
import "core:math/rand"
import "core:time"
import rl "vendor:raylib"
import "vendor:raylib/rlgl"

SCREEN_WIDTH :: 800
SCREEN_HEIGHT :: 450
NUM_POINTS :: 2000
SPLINE_SAMPLES :: 15
NUM_FEATURES :: 2
BUDGET :: 50
GAMMA :: 0.00005
TRAINING_STEPS :: 1000

RBF_Params :: struct {
    gamma: f32,
}

Perceptron :: struct {
    support_vectors: [dynamic]rl.Vector3,
    budget: int,
    params: RBF_Params,
}

rbf_kernel :: proc(x1, x2: rl.Vector3, params: RBF_Params) -> f32 {
    sum: f32 = 0
    for i in 0..<NUM_FEATURES {
        diff := x1[i] - x2[i]
        sum += diff * diff
    }
    return math.exp_f32(-sum * params.gamma)
}

predict :: proc(p: ^Perceptron, input: rl.Vector3) -> f32 {
    y: f32 = 0
    for sv in p.support_vectors {
        y += sv[NUM_FEATURES] * rbf_kernel(sv, input, p.params)
    }
    return y
}

is_misclassified :: proc(p: ^Perceptron, input: rl.Vector3) -> bool {
    return predict(p, input) * input[NUM_FEATURES] <= 0
}

train :: proc(p: ^Perceptron, input: rl.Vector3) {
    if is_misclassified(p, input) {
        append(&p.support_vectors, input)
    }
    
    if len(p.support_vectors) == p.budget + 1 {
        idx := rand.int_max(p.budget)
        ordered_remove(&p.support_vectors, idx)
    }
}

accuracy :: proc(p: ^Perceptron, data: []rl.Vector3) -> f32 {
    num_correct: int
    total: int = len(data)
    
    for i in 0..<total {
        if !is_misclassified(p, data[i]) {
            num_correct += 1
        }
    }
    return f32(num_correct) / f32(total)
}

f :: proc(x: f32) -> f32 {
    return 0.001 * x * x + 0.05 * x + 1
}

// Convert world coordinates to screen coordinates
world_to_screen :: proc(x, y: f32) -> (i32, i32) {
    screen_x := i32(x + f32(SCREEN_WIDTH)/2)
    screen_y := i32(f32(SCREEN_HEIGHT)/2 - y)  // Flip Y for screen coords
    return screen_x, screen_y
}

main :: proc() {
    rl.SetConfigFlags({.MSAA_4X_HINT})
    rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "raylib example - kernel perceptron")
    defer rl.CloseWindow()

    seed := rand.create(u64(time.now()._nsec))
    rng := rand.default_random_generator(&seed)
    
    perceptron: Perceptron = {
        budget = BUDGET,
        params = {gamma = GAMMA},
    }
    reserve(&perceptron.support_vectors, BUDGET)
    
    // Generate training data in WORLD COORDINATES
    training: [NUM_POINTS]rl.Vector3
    for i in 0..<NUM_POINTS {
        x := rand.float32_range(-f32(SCREEN_WIDTH)/2, f32(SCREEN_WIDTH)/2)
        y := rand.float32_range(-f32(SCREEN_HEIGHT)/2, f32(SCREEN_HEIGHT)/2)
        label: f32 = y > f(x) ? 1 : -1
        training[i] = {x, y, label}
    }
    
    // Generate spline points in WORLD COORDINATES
    points: [SPLINE_SAMPLES]rl.Vector2
    x_step := f32(SCREEN_WIDTH) / f32(SPLINE_SAMPLES - 1)
    for i in 0..<SPLINE_SAMPLES {
        x := f32(i) * x_step - f32(SCREEN_WIDTH)/2
        points[i] = {x, f(x)}
    }
    
    fmt.println("Initial training...")
    for i in 0..<TRAINING_STEPS {
        train(&perceptron, training[i % NUM_POINTS])
        if i % 100 == 0 {
            acc := accuracy(&perceptron, training[:])
            fmt.printf("Step %d: %.1f%% accuracy\n", i, acc * 100)
        }
    }
    
    accuracy_val: f32 = accuracy(&perceptron, training[:])
    count: int = TRAINING_STEPS
    show_info: bool
    
    rl.SetTargetFPS(60)
    
    for !rl.WindowShouldClose() {
        // Toggle info panel with 'I' key
        if rl.IsKeyPressed(.I) {
            show_info = !show_info
        }

        train(&perceptron, training[count % NUM_POINTS])
        count += 1
        
        if count % 100 == 0 {
            accuracy_val = accuracy(&perceptron, training[:])
        }
        
        rl.BeginDrawing()
        defer rl.EndDrawing()
        
        rl.ClearBackground(rl.RAYWHITE)
        
        // Draw decision boundary (quadratic curve)
        spline_points: [SPLINE_SAMPLES]rl.Vector2
        for i in 0..<SPLINE_SAMPLES {
            sx, sy := world_to_screen(points[i].x, points[i].y)
            spline_points[i] = {f32(sx), f32(sy)}
        }
        rl.DrawLineStrip(&spline_points[0], i32(SPLINE_SAMPLES), rl.Color{0, 0, 0, 255})  // Black boundary
        
        // Draw TRAINING POINTS (in layers for proper visibility)
        // Layer 1: True labels (outer circles)
        for data_point in training {
            sx, sy := world_to_screen(data_point[0], data_point[1])
            
            if data_point[NUM_FEATURES] > 0 {
                rl.DrawCircle(sx, sy, 5, rl.Color{70, 130, 220, 255})  // Blue (positive class)
            } else {
                rl.DrawCircle(sx, sy, 5, rl.Color{255, 140, 0, 255})   // Orange (negative class)
            }
        }
        
        // Layer 2: Predictions (inner circles)
        for data_point in training {
            sx, sy := world_to_screen(data_point[0], data_point[1])
            prediction: f32 = predict(&perceptron, data_point)
            
            if prediction > 0 {
                rl.DrawCircle(sx, sy, 3, rl.Color{0, 200, 255, 255})   // Cyan (predicted positive)
            } else {
                rl.DrawCircle(sx, sy, 3, rl.Color{255, 80, 80, 255})   // Coral red (predicted negative)
            }
        }
        
        // Layer 3: Misclassified indicators (thick borders)
        for data_point in training {
            if is_misclassified(&perceptron, data_point) {
                sx, sy := world_to_screen(data_point[0], data_point[1])
                rl.DrawCircleLines(sx, sy, 7, rl.Color{255, 0, 255, 255})  // Magenta border
            }
        }
        
        // Layer 4: Support vectors (distinctive markers)
        for sv in perceptron.support_vectors {
            sx, sy := world_to_screen(sv[0], sv[1])
            // Draw a distinctive cross/star pattern
            rl.DrawCircle(sx, sy, 9, rl.Color{255, 215, 0, 255})       // Gold fill
            rl.DrawCircleLines(sx, sy, 9, rl.Color{0, 0, 0, 255})      // Black outline
            // Add small inner dot for emphasis
            rl.DrawCircle(sx, sy, 3, rl.Color{0, 0, 0, 255})
        }
        
        // Draw info panel with semi-transparent background
        if show_info {
            panel_x: i32 = 10
            panel_y: i32 = 10
            panel_width: i32 = 420
            panel_height: i32 = 200
            
            // Semi-transparent dark background
            rl.DrawRectangle(panel_x, panel_y, panel_width, panel_height, rl.Color{0, 0, 0, 180})
            
            // Accuracy text
            accuracy_text := fmt.ctprintf("Accuracy: %.1f%% (%d/%d support vectors)", 
                                       accuracy_val * 100, len(perceptron.support_vectors), BUDGET)
            rl.DrawText(accuracy_text, panel_x + 10, panel_y + 10, 20, rl.Color{255, 255, 255, 255})
            
            // Legend with color indicators
            y_offset: i32 = panel_y + 40
            rl.DrawCircle(panel_x + 20, y_offset + 8, 9, rl.Color{255, 215, 0, 255})
            rl.DrawCircleLines(panel_x + 20, y_offset + 8, 9, rl.Color{0, 0, 0, 255})
            rl.DrawCircle(panel_x + 20, y_offset + 8, 3, rl.Color{0, 0, 0, 255})
            rl.DrawText("Support Vectors (gold with black center)", panel_x + 40, y_offset, 16, rl.Color{255, 255, 255, 255})
            
            y_offset += 25
            rl.DrawCircle(panel_x + 20, y_offset + 8, 5, rl.Color{70, 130, 220, 255})
            rl.DrawText("True positive class (blue outer)", panel_x + 40, y_offset, 16, rl.Color{255, 255, 255, 255})
            
            y_offset += 25
            rl.DrawCircle(panel_x + 20, y_offset + 8, 5, rl.Color{255, 140, 0, 255})
            rl.DrawText("True negative class (orange outer)", panel_x + 40, y_offset, 16, rl.Color{255, 255, 255, 255})
            
            y_offset += 25
            rl.DrawCircle(panel_x + 20, y_offset + 8, 3, rl.Color{0, 200, 255, 255})
            rl.DrawText("Predicted positive (cyan inner)", panel_x + 40, y_offset, 16, rl.Color{255, 255, 255, 255})
            
            y_offset += 25
            rl.DrawCircle(panel_x + 20, y_offset + 8, 3, rl.Color{255, 80, 80, 255})
            rl.DrawText("Predicted negative (coral inner)", panel_x + 40, y_offset, 16, rl.Color{255, 255, 255, 255})
            
            y_offset += 25
            rl.DrawCircleLines(panel_x + 20, y_offset + 8, 7, rl.Color{255, 0, 255, 255})
            rl.DrawText("Misclassified (magenta border)", panel_x + 40, y_offset, 16, rl.Color{255, 255, 255, 255})
        } else {
            // Show minimal hint when panel is hidden
            rl.DrawRectangle(10, 10, 180, 30, rl.Color{0, 0, 0, 180})
            rl.DrawText("Press 'I' for info", 20, 15, 16, rl.Color{255, 255, 255, 255})
        }
    }
}