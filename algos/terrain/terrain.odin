package main

import "core:fmt"
import rl "vendor:raylib"

TerrainType :: enum {
    Plains,
    Hills,
    Mountains,
    Marsh,
    Forest,
    Water,
    Urban,
}

TerrainModifiers :: struct {
    range_extend: i32,
    attack_bonus: f32,
    defense_bonus: f32,
    movement_cost: f32,
}

Terrain :: struct {
    type_: TerrainType,
    modifiers: TerrainModifiers,
    texture: rl.Texture2D, // loaded by TerrainManager
}

terrain_modifiers_from_type :: proc(t: TerrainType) -> TerrainModifiers {
    switch t {
    case .Plains:   return {0, 0.1, 0.0, 1.0}
    case .Hills:    return {1, 0.3, 0.2, 1.5}
    case .Mountains:return {1, 0.1, 0.3, 2.0}
    case .Marsh:    return {0, 0.0, -0.1, 2.0}
    case .Forest:   return {0, 0.2, 0.1, 1.5}
    case .Water:    return {-100, -1.0, -0.2, 2.0}
    case .Urban:    return {0, 0.0, 0.0, 1.0}
    }
    return {}
}

terrain_name :: proc(t: TerrainType) -> string {
    switch t {
    case .Plains:   return "Plain"
    case .Hills:    return "Hills"
    case .Mountains:return "Mountains"
    case .Marsh:    return "Marsh"
    case .Forest:   return "Forest"
    case .Water:    return "Water"
    case .Urban:    return "Urban"
    }
    return ""
}

texture_path :: proc(t: TerrainType) -> string {
    switch t {
    case .Plains:   return "assets/plain/plain.png"
    case .Hills:    return "assets/hills/hills.png"
    case .Mountains:return "assets/mountains/mountains.png"
    case .Marsh:    return "assets/marsh/marsh.png"
    case .Forest:   return "assets/forest/forest.png"
    case .Water:    return "assets/water/water.png"
    case .Urban:    return "assets/urban/urban.png"
    }
    return ""
}

// ---------------------------------------------------------------------
// Terrain manager (singleton – one per program)
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