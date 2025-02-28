package tsp

import fmt "core:fmt"
import rl "vendor:raylib"

Path :: struct {
    route: []City,
    total_distance: f32,
}

new_path :: proc(cities: []City) -> Path {
    route := make([]City, len(cities))
    copy(route, cities)
    return Path{route = route}
}

draw_path :: proc(path: Path) {
    if len(path.route) < 1 do return
    
    // Draw cities and numbers
    for &city, i in path.route {
        draw_city(city, i)
    }
    
    // Draw lines between cities
    prev := path.route[0]
    for &city in path.route[1:] {
        rl.DrawLineEx(
            {prev.position.x, prev.position.y},
            {city.position.x, city.position.y},
            1,
            rl.BLACK,
        )
        prev = city
    }
    
    // Draw line back to start
    start := path.route[0]
    rl.DrawLineEx(
        {prev.position.x, prev.position.y},
        {start.position.x, start.position.y},
        1,
        rl.BLACK,
    )
}