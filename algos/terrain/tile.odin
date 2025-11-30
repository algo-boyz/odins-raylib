package main

import rl "vendor:raylib"

Tile :: struct {
    position: rl.Vector2,
    terrain:  ^Terrain,
}

tile_set_terrain :: proc(t: ^Tile, terrain: ^Terrain) {
    t.terrain = terrain
}

tile_get_terrain :: proc(t: ^Tile) -> ^Terrain {
    return t.terrain
}