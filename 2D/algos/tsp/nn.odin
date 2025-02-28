package tsp

import "core:math"

// NearestNeighbor

// Select the nearest city from remaining cities
select_nearest :: proc(from: City, left: []City) -> int {
    distance := distance_between(from.position, left[0].position)
    lowest := 0
    
    for city, index in left {
        temp := distance_between(from.position, city.position)
        if temp < distance {
            distance = temp
            lowest = index
        }
    }
    
    return lowest
}

solve_nearest_neighbor :: proc(cities: []City) -> [][]City {
    routes := make([dynamic][]City)
    
    for city, index in cities {
        // Create temporary copy of cities
        temp := make([dynamic]City)
        defer delete(temp)
        append(&temp, ..cities[:])
        
        // Initialize route
        route := make([dynamic]City)
        start := temp[index]
        append(&route, start)
        ordered_remove(&temp, index)
        
        // Build route by selecting nearest neighbors
        for len(temp) > 0 {
            lowest := select_nearest(start, temp[:])
            append(&route, temp[lowest])
            start = temp[lowest]
            ordered_remove(&temp, lowest)
        }
        
        // Convert dynamic array to slice and add to routes
        route_slice := make([]City, len(route))
        copy(route_slice[:], route[:])
        append(&routes, route_slice)
        delete(route)
    }
    
    // Convert routes to final result
    result := make([][]City, len(routes))
    copy(result[:], routes[:])
    delete(routes)
    return result
}

when ODIN_TEST {
    test_nearest_neighbor :: proc(t: ^testing.T) {
        city_a := new_city(0.0, 0.0)
        city_b := new_city(10.0, 0.0)
        city_c := new_city(5.0, 5.0)
        city_d := new_city(15.0, 8.0)
        city_e := new_city(8.0, 31.0)
        
        cities := []City{city_a, city_b, city_c}
        
        routes := solve_nearest_neighbor(&nn, cities)
        testing.expect(t, len(routes) == 3)
        
        cities_four := []City{city_a, city_b, city_c, city_d}
        routes_four := solve_nearest_neighbor(&nn, cities_four)
        testing.expect(t, len(routes_four) == 4)
        
        cities_five := []City{city_a, city_b, city_c, city_d, city_e}
        routes_five := solve_nearest_neighbor(&nn, cities_five)
        testing.expect(t, len(routes_five) == 5)
        
        defer {
            for route in routes do delete(route)
            delete(routes)
            for route in routes_four do delete(route)
            delete(routes_four)
            for route in routes_five do delete(route)
            delete(routes_five)
        }
    }
}