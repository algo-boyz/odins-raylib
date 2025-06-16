package rlutil

import rl "vendor:raylib"

// inbetween checks if a value is between values a and b
inbetween :: proc "contextless" (val, a, b: f32) -> bool {
    return a <= val && val <= b
}

// closesTo returns the value that is closest to val (a or b)
closesTo :: proc "contextless" (val, a, b: f32) -> f32 {
    diffA := abs(val - a)
    diffB := abs(val - b)
    if diffA < diffB { return a }
    return b
}

nearly_eq :: proc{
    nearly_eq_scalar,
    nearly_eq_vector,
    nearly_eq_color,
}

nearly_eq_scalar :: proc(a, b: f32, precision: f32 = 0.0001) -> bool {
    return abs(a - b) < precision
}

nearly_eq_vector :: proc(a, b: $A/[$N]f32, precision: f32 = 0.0001) -> bool #no_bounds_check {
    for i in 0..<N {
        if !nearly_eq_scalar(a[i], b[i], precision) do return false
    }
    return true
}

nearly_eq_color :: proc(a, b: rl.Color, precision: f32 = 0.0001) -> bool {
    return nearly_eq_scalar(f32(a.r), f32(b.r), precision) &&
           nearly_eq_scalar(f32(a.g), f32(b.g), precision) &&
           nearly_eq_scalar(f32(a.b), f32(b.b), precision) &&
           nearly_eq_scalar(f32(a.a), f32(b.a), precision)
}

