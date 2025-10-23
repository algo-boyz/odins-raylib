package geom

import "core:math"
import "core:math/rand"
import rl "vendor:raylib"

random_points :: proc(n  : int = 10, min_x: f32, min_y: f32, max_x: f32, max_y:f32, points : ^[]rl.Vector2) {
    for i in 0 ..< n {
        x := rand.float32_uniform(min_x, max_x)
        y := rand.float32_uniform(min_y, max_y)
        p := rl.Vector2{x, y}
        points[i] = p
    }
}

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