package geom

import "core:math/linalg"
import rl "vendor:raylib"


// Check if a position is within the grid
is_valid_position :: proc(grid_width, grid_height, x, y: int) -> bool {
    return x >= 0 && x < grid_width && y >= 0 && y < grid_height
}

// vector2_distance calculates the distance between two vectors in 2D space
vector2_distance :: proc(v1, v2: rl.Vector2) -> f32 {
    dx := v2.x - v1.x
    dy := v2.y - v1.y
    return linalg.sqrt(dx * dx + dy * dy)
}