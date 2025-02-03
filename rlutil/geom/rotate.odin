package geom

import "core:math"
import rl "vendor:raylib"

// todo https://thenumb.at/Exponential-Rotations/

// This function takes a local (x, y) position and rotates it by a given angle.
rotate_point :: proc(x, y: f32, angle: f32) -> rl.Vector2 {
    rad := angle * (math.PI / 180)  // Convert degrees to radians
    cos_a := math.cos(rad)
    sin_a := math.sin(rad)
    return rl.Vector2{
        x * cos_a - y * sin_a,
        x * sin_a + y * cos_a,
    }
}