package geom

import "core:math"
import rl "vendor:raylib"

center_pos :: proc() -> rl.Vector2 {
    return rl.Vector2{
        f32(rl.GetScreenWidth()) / 2,
        f32(rl.GetScreenHeight()) / 2,
    }
}