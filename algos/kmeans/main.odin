package kmeans

import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:math/rand"
import "core:time"
import rl "vendor:raylib"

K :: 5
SAMPLE_R :: 4
MEAN_R :: SAMPLE_R * 2
MIN_X : f32 : -20
MAX_X : f32 :  20
MIN_Y : f32 : -20
MAX_Y : f32 :  20
COLORS := [9]rl.Color{
    rl.YELLOW, rl.PINK, rl.BROWN, rl.GREEN, rl.LIME, rl.SKYBLUE, rl.PURPLE, rl.VIOLET, rl.BEIGE,
}

// Add state tracking for educational purposes
State :: enum {
    INITIAL,
    ASSIGNING,
    UPDATING_MEANS,
    CONVERGED,
}

AppState :: struct {
    clusters: [K][dynamic]rl.Vector2,
    means: [dynamic]rl.Vector2,
    old_means: [dynamic]rl.Vector2, // Track previous means for convergence
    cluster: [dynamic]rl.Vector2,
    current_state: State,
    iteration: int,
    auto_step: bool,
    step_timer: f32,
    show_connections: bool,
    show_voronoi: bool,
    converged: bool,
}

gen_cluster :: proc(center: rl.Vector2, radius: f32, count: int, samples: ^[dynamic]rl.Vector2) {
    for i in 0..<count {
        angle := rand.float32() * 2 * math.PI
        mag := rand.float32()
        append(samples, rl.Vector2{
            center.x + math.cos(angle) * mag * radius,
            center.y + math.sin(angle) * mag * radius,
        })
    }
}

project_sample :: proc(sample: rl.Vector2) -> rl.Vector2 {
    nx := (sample.x - MIN_X) / (MAX_X - MIN_X)
    ny := (sample.y - MIN_Y) / (MAX_Y - MIN_Y)
    w := f32(rl.GetScreenWidth())
    h := f32(rl.GetScreenHeight())
    
    return {nx * w, h - ny * h}
}

regen_cluster :: proc(app: ^AppState) {
    clear(&app.cluster)
    clear(&app.means)
    clear(&app.old_means)
    
    // Generate more interesting cluster patterns
    gen_cluster({}, 10, 100, &app.cluster)
    gen_cluster({MIN_X * 0.5, MAX_Y * 0.5}, 5, 100, &app.cluster)
    gen_cluster({MAX_X * 0.5, MAX_Y * 0.5}, 5, 100, &app.cluster)
    gen_cluster({MIN_X * 0.5, MIN_Y * 0.5}, 5, 100, &app.cluster)
    gen_cluster({MAX_X * 0.5, MIN_Y * 0.5}, 5, 100, &app.cluster)
    
    // Initialize means randomly
    for i in 0..<K {
        mean := rl.Vector2{
            linalg.lerp(MIN_X, MAX_X, rand.float32()),
            linalg.lerp(MIN_Y, MAX_Y, rand.float32()),
        }
        append(&app.means, mean)
        append(&app.old_means, mean)
    }
    
    app.current_state = .INITIAL
    app.iteration = 0
    app.converged = false
}

recluster :: proc(app: ^AppState) {
    // Clear all clusters
    for i in 0..<K {
        clear(&app.clusters[i])
    }
    
    // Assign each point to nearest mean
    for point in app.cluster {
        min_dist: f32 = math.F32_MAX
        nearest_k: int

        for j in 0..<K {
            if j >= len(app.means) do continue
            mean := app.means[j]
            dist := rl.Vector2LengthSqr(point - mean)
            if dist < min_dist {
                min_dist = dist
                nearest_k = j
            }
        }
        append(&app.clusters[nearest_k], point)
    }
    app.current_state = .ASSIGNING
}

update_means :: proc(app: ^AppState) {
    // Store old means for convergence check
    copy(app.old_means[:], app.means[:])
    
    convergence_threshold: f32 = 0.1
    max_movement: f32 = 0
    
    for i in 0..<K {
        if len(app.clusters[i]) > 0 {
            sum := rl.Vector2{0, 0}
            for point in app.clusters[i] {
                sum += point // Fixed the += operator
            }
            new_mean := rl.Vector2{
                sum.x / f32(len(app.clusters[i])),
                sum.y / f32(len(app.clusters[i])),
            }
            
            // Check movement for convergence
            movement := rl.Vector2Length(new_mean - app.means[i])
            max_movement = max(max_movement, movement)
            
            app.means[i] = new_mean
        } else {
            // If cluster is empty, reinitialize mean randomly
            app.means[i].x = linalg.lerp(MIN_X, MAX_X, rand.float32())
            app.means[i].y = linalg.lerp(MIN_Y, MAX_Y, rand.float32())
        }
    }
    
    app.current_state = .UPDATING_MEANS
    app.iteration += 1
    
    // Check for convergence
    if max_movement < convergence_threshold {
        app.converged = true
        app.current_state = .CONVERGED
    }
}

draw_connections :: proc(app: ^AppState) {
    if !app.show_connections do return
    
    // Draw lines from each point to its assigned mean
    for i in 0..<K {
        if i >= len(app.means) do continue
        
        color := COLORS[i % len(COLORS)]
        faded_color := rl.Color{color.r, color.g, color.b, 50}
        
        mean_proj := project_sample(app.means[i])
        
        for point in app.clusters[i] {
            point_proj := project_sample(point)
            rl.DrawLineV(point_proj, mean_proj, faded_color)
        }
    }
}

draw_voronoi :: proc(app: ^AppState) {
    if !app.show_voronoi do return
    
    // Simple voronoi visualization - draw boundaries
    w := rl.GetScreenWidth()
    h := rl.GetScreenHeight()
    
    for x in 0..<w {
        for y in 0..<h {
            if x % 4 != 0 || y % 4 != 0 do continue // Sparse sampling for performance
            
            // Convert screen coords back to world coords
            world_x := MIN_X + (f32(x) / f32(w)) * (MAX_X - MIN_X)
            world_y := MAX_Y - (f32(y) / f32(h)) * (MAX_Y - MIN_Y)
            world_point := rl.Vector2{world_x, world_y}
            
            // Find nearest mean
            min_dist: f32 = math.F32_MAX
            nearest_k: int
            
            for j in 0..<K {
                if j >= len(app.means) do continue
                dist := rl.Vector2LengthSqr(world_point - app.means[j])
                if dist < min_dist {
                    min_dist = dist
                    nearest_k = j
                }
            }
            
            color := COLORS[nearest_k % len(COLORS)]
            faded_color := rl.Color{color.r, color.g, color.b, 20}
            rl.DrawPixel(i32(x), i32(y), faded_color)
        }
    }
}

draw_ui :: proc(app: ^AppState) {
    // Draw instructions and state
    y_offset: i32 = 10
    
    rl.DrawText("K-Means Clustering Demo", 10, y_offset, 20, rl.WHITE)
    y_offset += 30
    
    // Controls
    rl.DrawText("Controls:", 10, y_offset, 16, rl.LIGHTGRAY)
    y_offset += 20
    rl.DrawText("R - Regenerate data", 10, y_offset, 14, rl.WHITE)
    y_offset += 18
    rl.DrawText("SPACE - Toggle auto-step", 10, y_offset, 14, rl.WHITE)
    y_offset += 18
    rl.DrawText("S - Manual step", 10, y_offset, 14, rl.WHITE)
    y_offset += 18
    rl.DrawText("C - Toggle connections", 10, y_offset, 14, rl.WHITE)
    y_offset += 18
    rl.DrawText("V - Toggle Voronoi", 10, y_offset, 14, rl.WHITE)
    y_offset += 25
    
    // Current state
    state_text: cstring
    switch app.current_state {
    case .INITIAL: state_text = "INITIAL - Press S or SPACE to start"
    case .ASSIGNING: state_text = "ASSIGNING points to nearest means"
    case .UPDATING_MEANS: state_text = "UPDATING mean positions"
    case .CONVERGED: state_text = "CONVERGED - Algorithm finished!"
    }
    
    rl.DrawText(fmt.ctprintf("State: %s", state_text), 10, y_offset, 14, rl.YELLOW)
    y_offset += 18
    rl.DrawText(fmt.ctprintf("Iteration: %d", app.iteration), 10, y_offset, 14, rl.WHITE)
    y_offset += 18
    
    if app.converged {
        rl.DrawText("✓ Converged!", 10, y_offset, 14, rl.GREEN)
    }
    
    // Legend
    legend_x: i32 = rl.GetScreenWidth() - 200
    legend_y: i32 = 10
    rl.DrawText("Legend:", legend_x, legend_y, 16, rl.LIGHTGRAY)
    legend_y += 25
    
    for i in 0..<K {
        color := COLORS[i % len(COLORS)]
        rl.DrawCircle(legend_x + 10, legend_y + 8, SAMPLE_R, color)
        rl.DrawText(fmt.ctprintf("Cluster %d (%d points)", i + 1, len(app.clusters[i])), 
                   legend_x + 25, legend_y, 14, rl.WHITE)
        legend_y += 20
    }
    
    legend_y += 10
    rl.DrawCircle(legend_x + 10, legend_y + 8, MEAN_R, rl.WHITE)
    rl.DrawText("Cluster Centers", legend_x + 25, legend_y, 14, rl.WHITE)
}

main :: proc() {
    app := AppState{}
    // Init dynamic arrays
    for i in 0..<K {
        app.clusters[i] = make([dynamic]rl.Vector2)
    }
    app.means = make([dynamic]rl.Vector2)
    app.old_means = make([dynamic]rl.Vector2)
    app.cluster = make([dynamic]rl.Vector2)
    defer {
        for i in 0..<K {
            delete(app.clusters[i])
        }
        delete(app.means)
        delete(app.old_means)
        delete(app.cluster)
    }
    app.step_timer = 0
    app.show_connections = false
    app.show_voronoi = false
    
    regen_cluster(&app)
    
    rl.SetConfigFlags({.WINDOW_RESIZABLE})
    rl.InitWindow(1200, 800, "K-means Clustering")
    defer rl.CloseWindow()
    rl.SetTargetFPS(60)
    
    for !rl.WindowShouldClose() {
        dt := rl.GetFrameTime()
        
        // Handle input
        if rl.IsKeyPressed(.R) {
            regen_cluster(&app)
        }
        if rl.IsKeyPressed(.SPACE) {
            app.auto_step = !app.auto_step
        }
        if rl.IsKeyPressed(.S) && !app.converged {
            if app.current_state == .INITIAL || app.current_state == .UPDATING_MEANS {
                recluster(&app)
            } else if app.current_state == .ASSIGNING {
                update_means(&app)
            }
        }
        if rl.IsKeyPressed(.C) {
            app.show_connections = !app.show_connections
        }
        if rl.IsKeyPressed(.V) {
            app.show_voronoi = !app.show_voronoi
        }
        // Auto-stepping logic
        if app.auto_step && !app.converged {
            app.step_timer += dt
            if app.step_timer >= 1.5 { // 1.5 second delay between steps
                app.step_timer = 0
                
                if app.current_state == .INITIAL || app.current_state == .UPDATING_MEANS {
                    recluster(&app)
                } else if app.current_state == .ASSIGNING {
                    update_means(&app)
                }
            }
        }
        rl.BeginDrawing()
        rl.ClearBackground({0x18, 0x18, 0x18, 0xFF})
        
        // Draw Voronoi diagram first (background)
        draw_voronoi(&app)
        // Draw connections from points to means
        draw_connections(&app)
        
        // Draw all data points
        for i in 0..<K {
            color := COLORS[i % len(COLORS)]
            
            // Draw points in this cluster
            for point in app.clusters[i] {
                projected := project_sample(point)
                rl.DrawCircleV(projected, SAMPLE_R, color)
                
                // Draw a border to make points more visible
                rl.DrawCircleLinesV(projected, SAMPLE_R, rl.BLACK)
            }
        }
        // Draw cluster centers (means)
        for i in 0..<K {
            if i >= len(app.means) do continue
            
            color := COLORS[i % len(COLORS)]
            projected_mean := project_sample(app.means[i])
            
            // Draw mean with a distinctive look
            rl.DrawCircleV(projected_mean, MEAN_R, color)
            rl.DrawCircleLinesV(projected_mean, MEAN_R, rl.BLACK)
            rl.DrawCircleLinesV(projected_mean, MEAN_R - 2, rl.WHITE)
            
            // Show movement of means if updating
            if app.current_state == .UPDATING_MEANS && i < len(app.old_means) {
                old_proj := project_sample(app.old_means[i])
                rl.DrawLineEx(old_proj, projected_mean, 3, rl.WHITE)
                rl.DrawCircleV(old_proj, 3, rl.GRAY)
            }
        }
        draw_ui(&app)
        rl.EndDrawing()
    }
}