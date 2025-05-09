package rlutil

import "core:math"

ease_out_circ :: proc(t: $T) -> T where intrinsics.type_is_numeric(T) {
    return math.sqrt(1 - math.pow(t - 1, 2))
}

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

ease_out_elastic :: proc(t: $T) -> T where intrinsics.type_is_numeric(T) {
    c4: T = (2 * math.PI) / 3
    if t == 0 {
        return 0
    } else if t == 1 {
        return 1
    } else {
        return math.pow(2, -10 * t) * math.sin_f32((t * 10 - 0.75) * c4) + 1
    }
}

ease_in_quint :: proc(t: $T) -> T where intrinsics.type_is_numeric(T) {
    return math.pow(t, 5)
}

ease_out_bounce :: proc(t: $T) -> T where intrinsics.type_is_numeric(T) {
    t := t
    n1: T = 7.5625
    d1: T = 2.75
    if (t < 1 / d1) {
        return n1 * t * t
    } else if (t < 2 / d1) {
        t -= 1.5 / d1
        return n1 * (t) * t + 0.75
    } else if (t < 2.5 / d1) {
        t -= 2.25 / d1
        return n1 * (t) * t + 0.9375
    } else {
        t -= 2.625 / d1
        return n1 * (t) * t + 0.984375
    }
}

ease_in_out_quint :: proc(t: f32) -> f32 {
    return t < 0.5 ? 16 * t * t * t * t * t : 1 - math.pow(-2 * t + 2, 5) / 2
}

ease_in_out_back :: proc(t: f64) -> f64 {
    c1 := 1.70158
    c2 := c1 * 1.525

    if t < 0.5 {
        return (math.pow(2 * t, 2) * ((c2 + 1) * 2 * t - c2)) / 2
    } else {
        return (math.pow(2 * t - 2, 2) * ((c2 + 1) * (t * 2 - 2) + c2) + 2) / 2
    }
}