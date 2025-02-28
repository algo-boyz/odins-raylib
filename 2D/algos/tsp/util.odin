package tsp

import "core:fmt"
import "core:math"
import rl "vendor:raylib"

distance_between :: proc(v1, v2: vec2) -> f32 {
    dx := v2.x - v1.x
    dy := v2.y - v1.y
    return math.sqrt(dx * dx + dy * dy)
}

calculate_total_distance :: proc(cities: []City) -> f32 {
    if len(cities) < 2 do return 0
    
    total := f32(0)
    prev := cities[0]
    
    for city in cities[1:] {
        total += distance_between(prev.position, city.position)
        prev = city
    }
    
    // Add distance back to start
    total += distance_between(prev.position, cities[0].position)
    return total
}

new_adjacency_matrix :: proc(cities: []City) -> [][]f32 {
    n := len(cities)
    mat := make([][]f32, n)
    
    for i := 0; i < n; i += 1 {
        mat[i] = make([]f32, n)
        for j := 0; j < n; j += 1 {
            if i == j {
                mat[i][j] = 0
                continue
            }
            mat[i][j] = distance_between(cities[i].position, cities[j].position)
        }
    }
    
    return mat
}

scale_distances :: proc(distances: [][]f32, scale_factor: f32) {
    for row in distances {
        for j := 0; j < len(row); j += 1 {
            row[j] /= scale_factor
        }
    }
}

choose_best :: proc(routes: [][]City) -> int {
    if len(routes) == 0 do return -1
    
    best_idx := 0
    best_distance := calculate_total_distance(routes[0])
    
    for route, i in routes[1:] {
        distance := calculate_total_distance(route)
        if distance < best_distance {
            best_distance = distance
            best_idx = i + 1
        }
    }
    
    return best_idx
}

contains :: proc(arr: []int, val: int) -> bool {
    for i := 0; i < len(arr); i += 1 {
        if arr[i] == val do return true
    }
    return false
}