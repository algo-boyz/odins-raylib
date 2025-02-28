package tsp

// BruteForce
solve_brute_force :: proc(cities: []City) -> [][]City {
    return generate_permutations(cities)
}

generate_permutations :: proc(cities: []City) -> [][]City {
    if len(cities) == 0 do return nil
    
    permutations := make([dynamic][]City)
    stack := make([dynamic]int)
    defer delete(stack)
    
    // Create initial route and stack
    root_city := cities[0]
    root_route := make([]City, len(cities))
    copy(root_route, cities)
    n := len(root_route)
    
    // Initialize stack
    for i := 0; i < n; i += 1 {
        append(&stack, 0)
    }
    
    // Add initial route
    first_route := make([]City, len(root_route))
    copy(first_route, root_route)
    append(&permutations, first_route)
    
    i := 0
    for i < n {
        if stack[i] < i {
            // Swap elements based on parity
            if i % 2 == 0 {
                root_route[0], root_route[i] = root_route[i], root_route[0]
            } else {
                root_route[stack[i]], root_route[i] = root_route[i], root_route[stack[i]]
            }
            
            // Add new permutation
            new_route := make([]City, len(root_route))
            copy(new_route, root_route)
            append(&permutations, new_route)
            
            stack[i] += 1
            i = 0
        } else {
            stack[i] = 0
            i += 1
        }
    }
    
    // Filter permutations to only keep those starting with root_city
    output := make([dynamic][]City)
    
    for perm in permutations {
        if perm[0] == root_city {
            append(&output, perm)
        } else {
            delete(perm) // Clean up unused permutations
        }
    }
    delete(permutations)
    
    result := make([][]City, len(output))
    copy(result[:], output[:])
    delete(output)
    
    return result
}

when ODIN_TEST {
    test_brute_force :: proc(t: ^testing.T) {
        city_a := new_city(0.0, 0.0)
        city_b := new_city(10.0, 0.0)
        city_c := new_city(5.0, 5.0)
        city_d := new_city(15.0, 8.0)
        city_e := new_city(8.0, 31.0)
        
        // Test with 3 cities
        {
            cities := []City{city_a, city_b, city_c}
            result := solve_brute_force(cities)
            testing.expect(t, len(result) == 2)
            defer {
                for route in result do delete(route)
                delete(result)
            }
        }
        
        // Test with 4 cities
        {
            cities := []City{city_a, city_b, city_c, city_d}
            result := solve_brute_force(cities)
            testing.expect(t, len(result) == 6)
            defer {
                for route in result do delete(route)
                delete(result)
            }
        }
        
        // Test with 5 cities
        {
            cities := []City{city_a, city_b, city_c, city_d, city_e}
            result := solve_brute_force(cities)
            testing.expect(t, len(result) == 24)
            defer {
                for route in result do delete(route)
                delete(result)
            }
        }
    }
}