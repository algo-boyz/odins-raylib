package main

import "core:fmt"
import "core:math"
import "core:math/rand"
import "base:runtime"

import rl "vendor:raylib"

TerrainType :: enum {
    Plains,
    Hills,
    Mountains,
    Marsh,
    Forest,
    Water,
}

TerrainModifiers :: struct {
    range_extend:  i32,
    attack_bonus:  f32,
    defense_bonus: f32,
    movement_cost: f32,
}

Terrain :: struct {
    type_:     TerrainType,
    modifiers: TerrainModifiers,
    texture:   rl.Texture2D,
}

terrain_modifiers_from_type :: proc(t: TerrainType) -> TerrainModifiers {
    switch t {
    case .Plains:    return {0, 0.1, 0.0, 1.0}
    case .Hills:     return {1, 0.3, 0.2, 1.5}
    case .Mountains: return {1, 0.1, 0.3, 2.0}
    case .Marsh:     return {0, 0.0, -0.1, 2.0}
    case .Forest:    return {0, 0.2, 0.1, 1.5}
    case .Water:     return {-100, -1.0, -0.2, 2.0}
    }
    return {}
}

texture_path :: proc(t: TerrainType) -> string {
    switch t {
    case .Plains:    return "assets/plain/plain.png"
    case .Hills:     return "assets/hills/hills.png"
    case .Mountains: return "assets/mountains/mountains.png"
    case .Marsh:     return "assets/marsh/marsh.png"
    case .Forest:    return "assets/forest/forest.png"
    case .Water:     return "assets/water/water.png"
    }
    return ""
}

TerrainManager :: struct {
    cache: map[TerrainType]^Terrain,
}

terrain_manager_init :: proc(tm: ^TerrainManager) {
    using rl
    for t in TerrainType {
        path := texture_path(t)
        tex  := LoadTexture(fmt.ctprint(path))
        if tex.id == 0 {
            fmt.printf("WARNING: could not load %s\n", path)
        }
        terr := new(Terrain)
        terr.type_      = t
        terr.modifiers  = terrain_modifiers_from_type(t)
        terr.texture    = tex
        tm.cache[t] = terr
    }
}

terrain_manager_get :: proc(tm: ^TerrainManager, t: TerrainType) -> ^Terrain {
    return tm.cache[t]
}

terrain_manager_destroy :: proc(tm: ^TerrainManager) {
    using rl
    for _, terr in tm.cache {
        UnloadTexture(terr.texture)
        free(terr)
    }
    delete(tm.cache)
}

Tile :: struct {
    position: rl.Vector2,
    terrain:  ^Terrain,
}

TerrainDistribution :: struct {
    plains:    f32,
    hills:     f32,
    mountains: f32,
    marsh:     f32,
    forest:    f32,
    water:     f32,
}

Map :: struct {
    rows:                   i32,
    cols:                   i32,
    tiles:                  [][]Tile,
    terrain_manager:        TerrainManager,
    terrain_compatibility:  map[TerrainType]map[TerrainType]f32,
}

map_create :: proc(rows, cols: i32, distribution: TerrainDistribution, k_cluster: int) -> Map {
    m := Map{rows = rows, cols = cols}
    terrain_manager_init(&m.terrain_manager)
    _init_terrain_compatibility(&m)
    _init_tiles(&m)
    _random_fill_map(&m, distribution)
    _cluster_terrains(&m, k_cluster)
    return m
}

map_destroy :: proc(m: ^Map) {
    for col in m.tiles {
        delete(col)
    }
    delete(m.tiles)
    
    // Clean up compatibility maps
    for _, inner_map in m.terrain_compatibility {
        delete(inner_map)
    }
    delete(m.terrain_compatibility)
    
    terrain_manager_destroy(&m.terrain_manager)
}

map_get_tile :: proc(m: ^Map, pos: rl.Vector2) -> ^Tile {
    return &m.tiles[int(pos.x)][int(pos.y)]
}

_init_tiles :: proc(m: ^Map) {
    m.tiles = make([][]Tile, m.cols)
    for col in 0..<m.cols {
        m.tiles[col] = make([]Tile, m.rows)
        for row in 0..<m.rows {
            m.tiles[col][row].position = rl.Vector2{f32(col), f32(row)}
        }
    }
}

_init_terrain_compatibility :: proc(m: ^Map) {
    m.terrain_compatibility = make(map[TerrainType]map[TerrainType]f32)
    
    // Plains compatibility
    plains_map := make(map[TerrainType]f32)
    plains_map[.Plains] = 0.85
    plains_map[.Hills] = 0.5
    plains_map[.Mountains] = 0.2
    plains_map[.Marsh] = 0.3
    plains_map[.Forest] = 0.5
    plains_map[.Water] = 0.3
    m.terrain_compatibility[.Plains] = plains_map
    
    // Hills compatibility
    hills_map := make(map[TerrainType]f32)
    hills_map[.Hills] = 0.85
    hills_map[.Plains] = 0.5
    hills_map[.Mountains] = 0.8
    hills_map[.Marsh] = 0.1
    hills_map[.Forest] = 0.4
    hills_map[.Water] = 0.4
    m.terrain_compatibility[.Hills] = hills_map
    
    // Mountains compatibility
    mountains_map := make(map[TerrainType]f32)
    mountains_map[.Mountains] = 0.9
    mountains_map[.Plains] = 0.5
    mountains_map[.Hills] = 0.8
    mountains_map[.Marsh] = 0.05
    mountains_map[.Forest] = 0.3
    mountains_map[.Water] = 0.5
    m.terrain_compatibility[.Mountains] = mountains_map
    
    // Marsh compatibility
    marsh_map := make(map[TerrainType]f32)
    marsh_map[.Marsh] = 0.85
    marsh_map[.Plains] = 0.3
    marsh_map[.Hills] = 0.1
    marsh_map[.Mountains] = 0.05
    marsh_map[.Forest] = 0.7
    marsh_map[.Water] = 0.7
    m.terrain_compatibility[.Marsh] = marsh_map
    
    // Forest compatibility
    forest_map := make(map[TerrainType]f32)
    forest_map[.Forest] = 1.0
    forest_map[.Plains] = 0.5
    forest_map[.Hills] = 0.4
    forest_map[.Mountains] = 0.3
    forest_map[.Marsh] = 0.7
    forest_map[.Water] = 0.3
    m.terrain_compatibility[.Forest] = forest_map
    
    // Water compatibility
    water_map := make(map[TerrainType]f32)
    water_map[.Water] = 0.8
    water_map[.Plains] = 0.3
    water_map[.Hills] = 0.4
    water_map[.Mountains] = 0.5
    water_map[.Marsh] = 0.7
    water_map[.Forest] = 0.3
    m.terrain_compatibility[.Water] = water_map
}

_get_compatibility :: proc(m: ^Map, a, b: TerrainType) -> f32 {
    if outer, ok := m.terrain_compatibility[a]; ok {
        if comp, ok2 := outer[b]; ok2 {
            return comp
        }
    }
    return 0.0
}


_get_neighbors :: proc(m: ^Map, pos: rl.Vector2) -> [dynamic]rl.Vector2 {
    x := int(pos.x)
    y := int(pos.y)
    
    neighbors := make([dynamic]rl.Vector2, 0, 8)
    
    for i in -1..=1 {
        for j in -1..=1 {
            if i == 0 && j == 0 do continue
            
            nx := x + i
            ny := y + j
            
            if nx >= 0 && nx < int(m.cols) && ny >= 0 && ny < int(m.rows) {
                append(&neighbors, rl.Vector2{f32(nx), f32(ny)})
            }
        }
    }
    
    return neighbors
}

_random_fill_map :: proc(m: ^Map, dist: TerrainDistribution) {
    n := int(m.rows * m.cols)
    
    // Calculate amounts
    forest_amt := int(dist.forest * f32(n))
    hills_amt := int(dist.hills * f32(n))
    marsh_amt := int(dist.marsh * f32(n))
    mountains_amt := int(dist.mountains * f32(n))
    water_amt := int(dist.water * f32(n))
    plains_amt := n - (forest_amt + hills_amt + marsh_amt + mountains_amt + water_amt)
    
    // Build terrain array
    terrains := make([dynamic]^Terrain, 0, n)
    defer delete(terrains)
    
    for _ in 0..<forest_amt do append(&terrains, terrain_manager_get(&m.terrain_manager, .Forest))
    for _ in 0..<hills_amt do append(&terrains, terrain_manager_get(&m.terrain_manager, .Hills))
    for _ in 0..<marsh_amt do append(&terrains, terrain_manager_get(&m.terrain_manager, .Marsh))
    for _ in 0..<mountains_amt do append(&terrains, terrain_manager_get(&m.terrain_manager, .Mountains))
    for _ in 0..<water_amt do append(&terrains, terrain_manager_get(&m.terrain_manager, .Water))
    for _ in 0..<plains_amt do append(&terrains, terrain_manager_get(&m.terrain_manager, .Plains))
    
    // Shuffle
    rand.shuffle(terrains[:])
    
    // Assign to tiles
    idx := 0
    for col in 0..<m.cols {
        for row in 0..<m.rows {
            m.tiles[col][row].terrain = terrains[idx]
            idx += 1
        }
    }
}

_cluster_terrains :: proc(m: ^Map, k: int) {
    n := int(m.rows * m.cols)
    iterations := n * k
    
    temperature := 0.75
    final_temp := 0.001
    cold_rate := math.pow(final_temp / temperature, 1.0 / f64(iterations))
    
    for iter in 0..<iterations {
        // Pick random tile
        x1 := rand.int_max(int(m.cols))
        y1 := rand.int_max(int(m.rows))
        pos1 := rl.Vector2{f32(x1), f32(y1)}
        
        // Pick random neighbor
        neighbors := _get_neighbors(m, pos1)
        if len(neighbors) == 0 {
            delete(neighbors)
            continue
        }
        
        neighbor_idx := rand.int_max(len(neighbors))
        pos2 := neighbors[neighbor_idx]
        x2 := int(pos2.x)
        y2 := int(pos2.y)
        delete(neighbors)
        
        // Get terrains
        terrain1 := m.tiles[x1][y1].terrain
        terrain2 := m.tiles[x2][y2].terrain
        
        if terrain1 == terrain2 do continue
        
        // Calculate happiness before swap
        prev1 := _calculate_happiness(m, pos1)
        prev2 := _calculate_happiness(m, pos2)
        
        // Swap terrains
        m.tiles[x1][y1].terrain = terrain2
        m.tiles[x2][y2].terrain = terrain1
        
        // Calculate happiness after swap
        new1 := _calculate_happiness(m, pos1)
        new2 := _calculate_happiness(m, pos2)
        
        delta := (new1 - prev1) + (new2 - prev2)
        
        // Accept or reject swap
        if delta <= 0.0 && rand.float32() >= f32(math.exp(f64(delta) / temperature)) {
            // Reject: swap back
            m.tiles[x1][y1].terrain = terrain1
            m.tiles[x2][y2].terrain = terrain2
        }
        
        temperature *= cold_rate
    }
}

_calculate_happiness :: proc(m: ^Map, pos: rl.Vector2) -> f32 {
    neighbors := _get_neighbors(m, pos)
    defer delete(neighbors)
    
    if len(neighbors) == 0 do return 0.0
    
    happiness: f32 = 0.0
    tile_type := m.tiles[int(pos.x)][int(pos.y)].terrain.type_
    
    for neighbor in neighbors {
        nx := int(neighbor.x)
        ny := int(neighbor.y)
        neighbor_type := m.tiles[nx][ny].terrain.type_
        happiness += _get_compatibility(m, tile_type, neighbor_type)
    }
    
    happiness /= f32(len(neighbors))
    return happiness
}

SCREEN_WIDTH  :: 1200
SCREEN_HEIGHT :: 800
TILE_SIZE     :: 24

main :: proc() {
    rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "Terrain Generator")
    rl.SetTargetFPS(60)

    map_rows := i32(SCREEN_HEIGHT / TILE_SIZE)
    map_cols := i32(SCREEN_WIDTH / TILE_SIZE)

    // Default balanced distribution
    distribution := TerrainDistribution{
        plains    = 0.35,
        hills     = 0.15,
        mountains = 0.10,
        marsh     = 0.10,
        forest    = 0.20,
        water     = 0.10,
    }
    
    k_cluster := 12  // Clustering intensity

    game_map := map_create(map_rows, map_cols, distribution, k_cluster)

    cam: rl.Camera2D
    cam.zoom = 1.0

    for !rl.WindowShouldClose() {
        // Camera movement
        if rl.IsKeyDown(.LEFT)  do cam.target.x -= 400 * rl.GetFrameTime()
        if rl.IsKeyDown(.RIGHT) do cam.target.x += 400 * rl.GetFrameTime()
        if rl.IsKeyDown(.UP)    do cam.target.y -= 400 * rl.GetFrameTime()
        if rl.IsKeyDown(.DOWN)  do cam.target.y += 400 * rl.GetFrameTime()

        // Adjust clustering intensity
        regenerate := false
        if rl.IsKeyPressed(.MINUS) || rl.IsKeyPressed(.KP_SUBTRACT) {
            k_cluster = max(1, k_cluster - 1)
            regenerate = true
        }
        if rl.IsKeyPressed(.EQUAL) || rl.IsKeyPressed(.KP_ADD) {
            k_cluster = min(20, k_cluster + 1)
            regenerate = true
        }

        // Regenerate
        if rl.IsKeyPressed(.R) {
            regenerate = true
        }

        if regenerate {
            map_destroy(&game_map)
            game_map = map_create(map_rows, map_cols, distribution, k_cluster)
        }

        // Draw
        rl.BeginDrawing()
        rl.ClearBackground(rl.BLACK)

        rl.BeginMode2D(cam)
        for col in 0..<game_map.cols {
            for row in 0..<game_map.rows {
                tile := &game_map.tiles[col][row]
                terr := tile.terrain
                dst := rl.Rectangle{
                    f32(col) * TILE_SIZE,
                    f32(row) * TILE_SIZE,
                    TILE_SIZE,
                    TILE_SIZE,
                }
                src := rl.Rectangle{
                    0, 0,
                    f32(terr.texture.width),
                    f32(terr.texture.height),
                }
                rl.DrawTexturePro(terr.texture, src, dst, {0, 0}, 0, rl.WHITE)
            }
        }
        rl.EndMode2D()

        // UI
        rl.DrawFPS(10, 10)
        rl.DrawText("Arrows: Pan | R: Regenerate | +/- : Adjust Clustering", 10, 30, 20, rl.LIGHTGRAY)
        rl.DrawText(fmt.ctprintf("Clustering: %d (iterations: %d)", k_cluster, k_cluster * int(map_rows * map_cols)), 10, 55, 20, rl.YELLOW)

        rl.EndDrawing()
    }

    map_destroy(&game_map)
    rl.CloseWindow()
}