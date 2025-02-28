package main

import "core:fmt"
import "core:math"
import "tsp"
import rl "vendor:raylib"

Solution :: struct {
    cities: []tsp.City,
    distance: f32,
}

main :: proc() {
    width :: 1280
    height :: 720
    
    rl.InitWindow(width, height, "The travelling salesman")
    defer rl.CloseWindow()
    
    // Load texture
    texture := rl.LoadTexture("assets/usa.png")
    defer rl.UnloadTexture(texture)
    
    rl.SetTargetFPS(60)
    preset := tsp.new_preset(texture)
    tsp.create_usa_cities(&preset, tsp.PresetSize.Small)

    defer delete(preset.cities)

    current_algorithm := tsp.Algorithm.NN
    
    routes := tsp.solve_nearest_neighbor(preset.cities)
    defer delete(routes)
    
    total_routes := len(routes)
    best_route_idx := tsp.choose_best(routes)
    current_route_idx := 0
    
    drawing := true
    
    for !rl.WindowShouldClose() {
        // Handle input
        if rl.IsKeyPressed(.SPACE) {
            switch current_algorithm {
            case .Brute:
                current_algorithm = .NN
            case .NN:
                current_algorithm = .Christofides
            case .Christofides:
                current_algorithm = .ACO
            case .ACO:
                if len(preset.cities) > 5 {
                    current_algorithm = .Brute //NN
                } else {
                    current_algorithm = .Brute
                }
            }
        }
        
        if rl.IsKeyPressed(.ENTER) {
            // Clean up previous routes
            delete(routes)
            
            switch current_algorithm {
            case .Brute:
                routes = tsp.solve_brute_force(preset.cities)
            case .NN:
                routes = tsp.solve_nearest_neighbor(preset.cities)
            case .Christofides:
                routes = tsp.solve_christofides(preset.cities)
            case .ACO:
                aco := tsp.new_aco(len(preset.cities), 100)
                routes = tsp.solve_aco(&aco, preset.cities)
            }
            
            total_routes = len(routes)
            best_route_idx = tsp.choose_best(routes)
            current_route_idx = 0
        }
        
        if rl.IsKeyPressed(.S) {
            drawing = !drawing
        }
        
        // Drawing
        rl.BeginDrawing()
        defer rl.EndDrawing()
        
        rl.ClearBackground(rl.WHITE)
        rl.DrawTexture(texture, 0, 0, rl.WHITE)

        // Draw current route
        path := drawing ? routes[current_route_idx] : routes[best_route_idx]
        
        tsp.draw_path(tsp.new_path(path))
        
        // Draw UI text
        rl.DrawText(
            fmt.ctprintf("Total distance: %.2f", tsp.calculate_total_distance(path) / 100.0),
            0, 0, 20, rl.BLACK,
        )
        rl.DrawText(
            fmt.ctprintf("Current route index: %d / %d", current_route_idx + 1, total_routes),
            0, 24, 20, rl.BLACK,
        )
        rl.DrawText(
            fmt.ctprintf("Best route index: %d %s", best_route_idx + 1, preset.cities[best_route_idx + 1].name),
            0, 48, 20, rl.BLACK,
        )
        rl.DrawText(
            fmt.ctprintf("Algorithm: %s", tsp.algo_to_string(current_algorithm)),
            0, 72, 20, rl.BLACK,
        )
        
        if drawing {
            current_route_idx = (current_route_idx + 1) % total_routes
        }
    }
}