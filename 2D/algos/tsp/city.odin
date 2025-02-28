package tsp

import "core:fmt"
import rl "vendor:raylib"

vec2 :: rl.Vector2

City :: struct {
    position: vec2,
    size: f32,
    name: string,
}

new_city :: proc(name: string, x, y: f32) -> City {
    return City{
        position = vec2{x, y},
        size = 5.0,
        name = name,
    }
}

PresetSize :: enum {
    Tiny,
    Small,
    Medium,
    Large,
}

Preset :: struct {
    texture: rl.Texture2D,
    cities: []City,
}

new_preset :: proc(texture: rl.Texture2D) -> Preset {
    return Preset{
        texture = texture,
        cities = make([]City, 0),
    }
}

draw_city :: proc(city: City, idx: int) {
    rl.DrawCircleV({city.position.x, city.position.y}, city.size, rl.BLACK)
    
    rl.DrawText(
        fmt.ctprintf("%d %s", idx+1, city.name),
        i32(city.position.x) + 5,
        i32(city.position.y) + 5,
        15,
        rl.RED,
    )
}

// Convert route indices to cities
convert_to_cities :: proc(routes: [dynamic][]int, cities: []City) -> []City {
    // If this is called with empty routes, return an empty array
    if len(routes) == 0 {
        return make([]City, 0)
    }
    
    // Take the first route (or best route) and convert its indices to cities
    route := routes[0]
    result := make([]City, len(route))
    
    for i := 0; i < len(route); i += 1 {
        result[i] = cities[route[i]]
    }
    
    return result
}

// Convert odd vertices to cities
convert_odd_vertices_to_cities :: proc(odd_vertices: map[int]int, cities: []City) -> []City {
    result := make([dynamic]City)
    
    for vertex_idx, _ in odd_vertices {
        append(&result, cities[vertex_idx])
    }
    
    final := make([]City, len(result))
    copy(final[:], result[:])
    delete(result)
    return final
}

create_usa_cities :: proc(using preset: ^Preset, size: PresetSize) {
    if cities != nil do delete(cities)
    
    switch size {
    case .Tiny:
        cities = make([]City, 5)
        cities[0] = new_city("Seattle", 224.7490, 90.3880)  // Washington Seattle
        cities[1] = new_city("Orlando", 940.3322, 580.6557) // Florida Orlando
        cities[2] = new_city("Houston", 652.1351, 557.8151) // Texas Houston
        cities[3] = new_city("Chicago", 782.6872, 269.3301) // Illinois Chicago
        cities[4] = new_city("New York", 1022.2527, 260.7585) // New York
        
    case .Small:
        cities = make([]City, 8)
        cities[0] = new_city("Seattle", 224.7490, 90.3880)  // Washington Seattle
        cities[1] = new_city("LA", 215.0522, 411.2437) // LA California
        cities[2] = new_city("Oklahoma", 609.9511, 429.0715) // Oklahoma City
        cities[3] = new_city("Orlando", 940.3322, 580.6557) // Florida Orlando
        cities[4] = new_city("Mt Helena", 377.8781, 151.6298) // Montana Helena
        cities[5] = new_city("Houston", 652.1351, 557.8151) // Texas Houston
        cities[6] = new_city("Chicago", 782.6872, 269.3301) // Illinois Chicago
        cities[7] = new_city("New York", 1022.2527, 260.7585) // New York
        
    case .Medium:
        cities = make([]City, 11)
        cities[0] = new_city("Seattle", 224.7490, 90.3880)  // Washington Seattle
        cities[1] = new_city("Phoenix", 330.4484, 440.0740) // Arizona Phoenix
        cities[2] = new_city("LA", 215.0522, 411.2437) // LA California
        cities[3] = new_city("Oklahoma", 609.9511, 429.0715) // Oklahoma City
        cities[4] = new_city("Denver", 483.7392, 315.9903) // Colorado Denver
        cities[5] = new_city("Orlando", 940.3322, 580.6557) // Florida Orlando
        cities[6] = new_city("Atlanta", 870.7490, 450.3880) // Georgia Atlanta
        cities[7] = new_city("Mt Helena", 377.8781, 151.6298) // Montana Helena
        cities[8] = new_city("Houston", 652.1351, 557.8151) // Texas Houston
        cities[9] = new_city("Chicago", 782.6872, 269.3301) // Illinois Chicago
        cities[10] = new_city("New York", 1022.2527, 260.7585) // New York
        
    case .Large:
        cities = make([]City, 17)
        cities[0] = new_city("Seattle", 224.7490, 90.3880)  // Washington Seattle
        cities[1] = new_city("Birmingham", 815.5207, 460.8025) // Alabama Birmingham
        cities[2] = new_city("Phoenix", 330.4484, 440.0740) // Arizona Phoenix
        cities[3] = new_city("Lt Rock", 710.7465, 435.2896) // Little Rock Arkansas
        cities[4] = new_city("LA", 215.0522, 411.2437) // LA California
        cities[5] = new_city("Oklahoma", 609.9511, 429.0715) // Oklahoma City
        cities[6] = new_city("Denver", 483.7392, 315.9903) // Colorado Denver
        cities[7] = new_city("Hartford", 1040.7658, 230.6734) // Connecticut Hartford
        cities[8] = new_city("Wilmington", 984.7391, 417.5398) // North Carolina Wilmington
        cities[8] = new_city("Orlando", 940.3322, 580.6557) // Florida Orlando
        cities[10] = new_city("Atlanta", 870.7490, 450.3880) // Georgia Atlanta
        cities[11] = new_city("Portland", 220.6150, 146.2023) // Oregon Portland
        cities[12] = new_city("Mt Helena", 377.8781, 151.6298) // Montana Helena
        cities[13] = new_city("Houston", 652.1351, 557.8151) // Texas Houston
        cities[14] = new_city("Albuquerque", 440.3656, 422.3301) // New Mexico Albuquerque
        cities[15] = new_city("Chicago", 782.6872, 269.3301) // Illinois Chicago
        cities[16] = new_city("New York", 1022.2527, 260.7585) // New York
    }
}