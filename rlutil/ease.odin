package rlutil

import "core:math"

ease_out_cubic :: proc(t: f32) -> f32 {
    return 1 - math.pow(1 - t, 3)
}