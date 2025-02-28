package tsp

import "core:math"
import "core:math/rand"

Aco :: struct {
    ants: int,
    iterations: int,
}

Trail :: struct {
    table: [][]f32,
    alpha: f32,
    beta: f32,
}

Pheromone :: struct {
    table: [][]f32,
    pheromone_strength: f32,
    Q: f32,
    evaporation: f32,
}

Probability :: struct {
    table: [][]f32,
}

new_aco :: proc(ants, iterations: int) -> Aco {
    return Aco{
        ants = ants,
        iterations = iterations,
    }
}

new_trail :: proc(size: int) -> Trail {
    table := make([][]f32, size)
    for i := 0; i < size; i += 1 {
        table[i] = make([]f32, size)
    }
    
    return Trail{
        table = table,
        alpha = 1.0,
        beta = 4.0,
    }
}

new_pheromone :: proc(size: int) -> Pheromone {
    table := make([][]f32, size)
    for i := 0; i < size; i += 1 {
        table[i] = make([]f32, size)
        for j := 0; j < size; j += 1 {
            table[i][j] = i == j ? 0.0 : 1.0
        }
    }
    
    return Pheromone{
        table = table,
        pheromone_strength = 1.0,
        Q = 4.0,
        evaporation = 0.3,
    }
}

new_probability :: proc(size: int) -> Probability {
    table := make([][]f32, size)
    for i := 0; i < size; i += 1 {
        table[i] = make([]f32, size)
    }
    
    return Probability{table = table}
}

init_trail :: proc(trail: ^Trail, pheromone: ^Pheromone, distances: [][]f32) {
    for i := 0; i < len(trail.table); i += 1 {
        for j := 0; j < len(trail.table[i]); j += 1 {
            if i == j do continue
            trail.table[i][j] = math.pow(pheromone.table[i][j], trail.alpha) * 
                               math.pow(distances[i][j], trail.beta)
        }
    }
}

reduce_trail :: proc(trail: ^Trail, visited: []int) {
    for i := 0; i < len(trail.table); i += 1 {
        for j := 0; j < len(trail.table[i]); j += 1 {
            if contains(visited, j) {
                trail.table[i][j] = 0.0
                continue
            }
            if i == j do continue
        }
    }
}

update_pheromone :: proc(pheromone: ^Pheromone, route: []int, length: f32) {
    delta := pheromone.Q / length
    current := route[0]
    
    for index in route[1:] {
        pheromone.table[current][index] = ((1.0 - pheromone.evaporation) * 
                                         pheromone.table[current][index]) + delta
        pheromone.table[index][current] = ((1.0 - pheromone.evaporation) * 
                                         pheromone.table[index][current]) + delta
        current = index
    }
    
    // Complete the cycle back to start
    pheromone.table[current][route[0]] = ((1.0 - pheromone.evaporation) * 
                                        pheromone.table[current][route[0]]) + delta
    pheromone.table[route[0]][current] = ((1.0 - pheromone.evaporation) * 
                                        pheromone.table[route[0]][current]) + delta
}

best_route :: proc(pheromone: ^Pheromone, start: int) -> []int {
    route := make([dynamic]int)
    append(&route, start)
    
    for len(route) != len(pheromone.table) {
        last := route[len(route)-1]
        lowest:f32 = -math.F32_MAX
        current := 0
        
        for index := 0; index < len(pheromone.table[last]); index += 1 {
            if contains(route[:], index) do continue
            
            if lowest < pheromone.table[last][index] {
                current = index
                lowest = pheromone.table[last][index]
            }
        }
        
        append(&route, current)
    }
    
    result := make([]int, len(route))
    copy(result[:], route[:])
    delete(route)
    return result
}

update_probability :: proc(probability: ^Probability, trail: ^Trail) {
    for i := 0; i < len(probability.table); i += 1 {
        row_sum: f32 = 0
        for v in trail.table[i] do row_sum += v
        
        for j := 0; j < len(probability.table[i]); j += 1 {
            if i == j do continue
            
            probability.table[i][j] = row_sum == 0 ? 0.0 : trail.table[i][j] / row_sum
        }
    }
}

solve_aco :: proc(aco: ^Aco, cities: []City) -> [][]City {
    routes := make([dynamic][]City)
    distances := new_adjacency_matrix(cities)
    defer delete(distances)
    
    scale_distances(distances, 100.0)
    size := len(cities)
    
    pheromone := new_pheromone(size)
    trail := new_trail(size)
    probability := new_probability(size)
    defer {
        delete(pheromone.table)
        delete(trail.table)
        delete(probability.table)
    }
    
    init_trail(&trail, &pheromone, distances)
    update_probability(&probability, &trail)
    
    for i := 0; i < aco.iterations; i += 1 {
        visited_routes := make([dynamic][]int)
        
        for ant := 0; ant < aco.ants; ant += 1 {
            visited := make([dynamic]int)
            append(&visited, ant)
            
            for len(visited) != aco.ants {
                rd := rand.float32()
                sum: f32 = 0
                last := visited[len(visited)-1]
                
                for i := 0; i < len(probability.table[last]); i += 1 {
                    sum += probability.table[last][i]
                    
                    if rd < sum {
                        reduce_trail(&trail, visited[:])
                        update_probability(&probability, &trail)
                        append(&visited, i)
                        break
                    }
                }
            }
            
            route := make([]int, len(visited))
            copy(route[:], visited[:])
            append(&visited_routes, route)
            delete(visited)
            
            init_trail(&trail, &pheromone, distances)
            update_probability(&probability, &trail)
        }
        
        route := convert_to_cities(visited_routes, cities)
        length := calculate_total_distance(route) / 100.0
        append(&routes, route)
        
        for visited in visited_routes {
            update_pheromone(&pheromone, visited, length)
        }
        
        init_trail(&trail, &pheromone, distances)
        update_probability(&probability, &trail)
        
        for route in visited_routes do delete(route)
        delete(visited_routes)
    }
    
    // Add best routes
    bests := make([dynamic][]int)
    for ant := 0; ant < aco.ants; ant += 1 {
        append(&bests, best_route(&pheromone, ant))
    }
    route := convert_to_cities(bests, cities)
    append(&routes, route)

    result := make([][]City, len(routes))
    copy(result[:], routes[:])
    delete(routes)
    delete(bests)
    return result
}

when ODIN_TEST {
    test_aco :: proc(t: ^testing.T) {
        city_a := new_city(0.0, 0.0)
        city_b := new_city(10.0, 0.0)
        city_c := new_city(5.0, 5.0)
        city_d := new_city(4.0, 8.0)
        city_e := new_city(8.0, 3.0)
        
        cities := []City{city_a, city_b, city_c, city_d, city_e}
        aco := new_aco(len(cities), 100)
        
        routes := solve_aco(&aco, cities)
        testing.expect(t, len(routes) == len(cities) * 100 + len(cities))
        
        defer {
            for route in routes do delete(route)
            delete(routes)
        }
    }
}