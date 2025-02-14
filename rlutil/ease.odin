package rlutil

import "core:math"

ease_out_cubic :: proc(t: f32) -> f32 {
    return 1 - math.pow(1 - t, 3)
}

ease_out_quad :: proc(t: f32) -> f32 {
    return 1 - (1 - t) * (1 - t)
}

ease_in_quad :: proc(t: f32) -> f32 {
    if t > 1.0 {
        return 1.0
    }
    return t * t
}