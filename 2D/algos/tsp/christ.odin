package tsp

import "core:math"
import "core:container/queue"

// Christofides

// Pair represents an edge between two vertices
Pair :: struct {
    first, second: int,
}

new_pair :: proc(a, b: int) -> Pair {
    return Pair{first = a, second = b}
}

// Prim's algorithm to find Minimum Spanning Tree
prims :: proc(cities: []City, root: int) -> []Pair {
    mat := new_adjacency_matrix(cities)
    defer delete(mat)
    
    edges := make([dynamic]Pair)
    visited := make([dynamic]int)
    append(&visited, root)
    defer delete(visited)
    
    lowest:f32 = math.F32_MAX
    temp_col := root
    temp_row := root
    
    for len(visited) != len(cities) {
        lowest = math.F32_MAX
        
        for row := 0; row < len(mat); row += 1 {
            if contains(visited[:], row) do continue
            
            for visit in visited {
                for col := 0; col < len(mat[row]); col += 1 {
                    if col != visit do continue
                    
                    if lowest > mat[row][visit] && mat[row][visit] != 0.0 {
                        lowest = mat[row][visit]
                        temp_col = row
                        temp_row = visit
                    }
                }
            }
        }
        
        append(&edges, new_pair(temp_row, temp_col))
        append(&visited, temp_col)
    }
    
    result := make([]Pair, len(edges))
    copy(result[:], edges[:])
    delete(edges)
    return result
}

// Calculate degree of each vertex
degree :: proc(edges: []Pair) -> map[int]int {
    degrees := make(map[int]int)
    
    for edge in edges {
        degrees[edge.first] += 1
        degrees[edge.second] += 1
    }
    
    return degrees
}

// Find minimum weight perfect matching
minimum_weight_matching :: proc(odd_cities: []City) -> []Pair {
    pairs := make([dynamic]Pair)
    mat := new_adjacency_matrix(odd_cities)
    defer delete(mat)
    
    lowest:f32 = math.F32_MAX
    temp_col := 0
    temp_row := 0
    
    skip_row := make([dynamic]int)
    skip_col := make([dynamic]int)
    defer delete(skip_row)
    defer delete(skip_col)
    
    for row := 0; row < len(mat); row += 1 {
        if contains(skip_row[:], row) do continue
        
        lowest = math.F32_MAX
        for col := 0; col < len(mat[row]); col += 1 {
            if contains(skip_col[:], col) do continue
            
            if lowest > mat[row][col] && mat[row][col] != 0.0 {
                lowest = mat[row][col]
                temp_row = row
                temp_col = col
            }
        }
        
        append(&skip_row, temp_row)
        append(&skip_row, temp_col)
        append(&skip_col, temp_row)
        append(&skip_col, temp_col)
        
        append(&pairs, new_pair(temp_col, temp_row))
    }
    
    result := make([]Pair, len(pairs))
    copy(result[:], pairs[:])
    delete(pairs)
    return result
}

// Update matching indices
update_mwm_indexes :: proc(mwm: []Pair, odd_degree: map[int]int) {
    min_index := max(int)
    for k in odd_degree {
        min_index = min(min_index, k)
    }
    for &pair in mwm {
        pair.first += min_index
        pair.second += min_index
    }
}

// Combine MST and matching edges
unite :: proc(mspt, matching: []Pair) -> []Pair {
    result := make([]Pair, len(mspt) + len(matching))
    copy(result[:len(mspt)], mspt)
    copy(result[len(mspt):], matching)
    return result
}

// Create Euler tour from combined edges
euler_tour :: proc(united: []Pair, cities: []City) -> []City {
    tour := make([dynamic]City)
    visited := make([dynamic]int)
    defer delete(visited)
    
    for pair in united {
        if !contains(visited[:], pair.first) {
            append(&tour, cities[pair.first])
            append(&visited, pair.first)
        }
        
        if !contains(visited[:], pair.second) {
            append(&tour, cities[pair.second])
            append(&visited, pair.second)
        }
    }
    
    result := make([]City, len(tour))
    copy(result[:], tour[:])
    delete(tour)
    return result
}

// Modified solve_christofides to handle type mismatches
solve_christofides :: proc(cities: []City) -> [][]City {
    routes := make([dynamic][]City)  // Change to [dynamic][]City instead of [dynamic][]int
    
    for i := 0; i < len(cities); i += 1 {
        // Find MST using Prim's algorithm
        mspt := prims(cities, i)
        
        // Calculate vertex degrees
        degrees := degree(mspt)
        
        // Find vertices with odd degree
        odd_vertices := make(map[int]int)
        for k, v in degrees {
            if v % 2 == 1 {
                odd_vertices[k] = v
            }
        }
        
        // Get cities for odd degree vertices
        odd_cities := convert_odd_vertices_to_cities(odd_vertices, cities)
        
        // Find minimum weight matching
        mwm := minimum_weight_matching(odd_cities)
        delete(odd_cities)
        
        // Update matching indices
        update_mwm_indexes(mwm, odd_vertices)
        delete(odd_vertices)
        
        // Combine MST and matching
        united := unite(mspt, mwm)
        delete(mspt)
        delete(mwm)
        
        // Create Euler tour
        route := euler_tour(united, cities)
        delete(united)
        
        append(&routes, route)  // append []City to [dynamic][]City
        delete(degrees)
    }
    
    result := make([][]City, len(routes))
    copy(result[:], routes[:])  // copy from [dynamic][]City to [][]City
    delete(routes)
    return result
}

when ODIN_TEST {
    test_christofides :: proc(t: ^testing.T) {
        city_a := new_city(5.0, 5.0)
        city_b := new_city(4.0, 6.0)
        city_c := new_city(6.0, 6.0)
        city_d := new_city(4.0, 4.0)
        city_e := new_city(6.0, 4.0)
        
        cities := []City{city_a, city_b, city_c, city_d, city_e}
        routes := solve_christofides(&christofides, cities)
        testing.expect(t, len(routes) == len(cities))
        
        defer {
            for route in routes do delete(route)
            delete(routes)
        }
    }
    
    test_prims :: proc(t: ^testing.T) {
        city_a := new_city(0.0, 0.0)
        city_b := new_city(10.0, 0.0)
        city_c := new_city(5.0, 5.0)
        
        cities := []City{city_a, city_b, city_c}
        result := prims(cities, 0)
        
        expected := []Pair{
            new_pair(0, 2),
            new_pair(2, 1),
        }
        
        testing.expect(t, len(result) == len(expected))
        for i := 0; i < len(result); i += 1 {
            testing.expect(t, result[i] == expected[i])
        }
        
        delete(result)
    }
    
    test_minimum_weight_matching :: proc(t: ^testing.T) {
        city_a := new_city(5.0, 5.0)
        city_b := new_city(4.0, 6.0)
        city_c := new_city(6.0, 6.0)
        city_d := new_city(4.0, 4.0)
        
        cities := []City{city_a, city_b, city_c, city_d}
        result := minimum_weight_matching(cities)
        
        testing.expect(t, len(result) == 2)
        delete(result)
    }
}