package geom

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