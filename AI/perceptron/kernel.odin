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
    
    rl.SetTargetFPS(60)
    
    for !rl.WindowShouldClose() {
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
        rl.DrawLineStrip(&spline_points[0], i32(SPLINE_SAMPLES), rl.Color{50, 50, 50, 255})  // Dark gray
        
        // Draw SUPPORT VECTORS (Large magenta circles with black outline)
        for sv in perceptron.support_vectors {
            sx, sy := world_to_screen(sv[0], sv[1])
            rl.DrawCircleLines(sx, sy, 10, rl.Color{0, 0, 0, 255})         // Black outline
            rl.DrawCircle(sx, sy, 8, rl.Color{255, 0, 255, 255})           // Bright magenta fill
        }
        
        // Draw TRAINING POINTS
        for data_point in training {
            sx, sy := world_to_screen(data_point[0], data_point[1])
            
            // TRUE LABEL (outer circle - larger, DARK colors)
            true_color: rl.Color
            if data_point[NUM_FEATURES] > 0 {
                true_color = rl.Color{0, 100, 0, 255}      // Dark green (positive class)
            } else {
                true_color = rl.Color{139, 0, 0, 255}      // Dark red (negative class)
            }
            rl.DrawCircle(sx, sy, 6, true_color)
            
            // PREDICTION (inner circle - smaller, BRIGHT colors)
            prediction_color: rl.Color
            is_correct := !is_misclassified(&perceptron, data_point)
            prediction: f32 = predict(&perceptron, data_point)
            
            if prediction > 0 {
                if is_correct {
                    prediction_color = rl.Color{0, 255, 0, 255}      // Bright green (correct positive)
                } else {
                    prediction_color = rl.Color{139, 0, 0, 255}     // Dark red (wrong positive)
                }
            } else {
                if is_correct {
                    prediction_color = rl.Color{255, 0, 0, 255}     // Bright red (correct negative)
                } else {
                    prediction_color = rl.Color{0, 100, 0, 255}     // Dark green (wrong negative)
                }
            }
            rl.DrawCircle(sx, sy, 4, prediction_color)
            
            // MISCLASSIFIED border (thick bright red outline)
            if is_misclassified(&perceptron, data_point) {
                rl.DrawCircleLines(sx, sy, 8, rl.Color{255, 0, 0, 255})
            }
        }
        
        // Draw UI with updated legend
        accuracy_text := fmt.ctprintf("Accuracy: %.1f%% (%d/%d support vectors)", 
                                   accuracy_val * 100, len(perceptron.support_vectors), BUDGET)
        rl.DrawText(accuracy_text, 10, 10, 20, rl.Color{40, 40, 40, 255})
        
        // Updated legend with consistent colors
        rl.DrawText("█ Large magenta circles = Support Vectors", 10, 40, 16, rl.Color{255, 0, 255, 255})
        rl.DrawText("█ Dark green/red (outer) = True labels", 10, 60, 16, rl.Color{40, 40, 40, 255})
        rl.DrawText("█ Bright green/red (inner) = Predictions", 10, 80, 16, rl.Color{40, 40, 40, 255})
        rl.DrawText("█ Bright green = Correct positive prediction", 10, 100, 16, rl.Color{0, 255, 0, 255})
        rl.DrawText("█ Bright red = Correct negative prediction", 10, 120, 16, rl.Color{255, 0, 0, 255})
        rl.DrawText("█ Dark green/red (inner) = Wrong predictions", 10, 140, 16, rl.Color{139, 0, 0, 255})
        rl.DrawText("█ Thick red border = Misclassified points", 10, 160, 16, rl.Color{255, 0, 0, 255})
    }
}
    