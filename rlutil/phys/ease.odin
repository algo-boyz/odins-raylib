package phys

import "base:intrinsics"
import "core:math"

ease_in_sine :: proc(x: $T) -> T where intrinsics.type_is_numeric(T) {
	return 1 - math.cos((x * math.PI) / 2)
}

ease_out_sine :: proc(x: $T) -> T where intrinsics.type_is_numeric(T) {
	return math.sin((x * math.PI) / 2)
}

ease_in_out_sine :: proc(x: $T) -> T where intrinsics.type_is_numeric(T) {
	return -(math.cos(math.PI * x) - 1) / 2
}

ease_in_cubic :: proc(x: $T) -> T where intrinsics.type_is_numeric(T) {
	return x * x * x
}

ease_out_cubic :: proc(t: $T) -> T where intrinsics.type_is_numeric(T) {
    return 1 - math.pow(1 - t, 3)
}

ease_in_out_cubic :: proc(x: $T) -> T where intrinsics.type_is_numeric(T) {
	return x < 0.5 ? 4 * x * x * x : 1 - math.pow(-2 * x + 2, 3) / 2
}

ease_in_circ :: proc(x: $T) -> T where intrinsics.type_is_numeric(T) {
	return 1 - math.sqrt(1 - x * x)
}

ease_out_circ :: proc(t: $T) -> T where intrinsics.type_is_numeric(T) {
    return math.sqrt(1 - math.pow(t - 1, 2))
}

ease_in_out_circ :: proc(x: $T) -> T where intrinsics.type_is_numeric(T) {
	return x < 0.5 ? (1 - math.sqrt(1 - math.pow(2 * x, 2))) / 2 : (math.sqrt(1 - math.pow(-2 * x + 2, 2)) + 1) / 2
}

ease_in_elastic :: proc(x: $T) -> T where intrinsics.type_is_numeric(T) {
	c4 :: (2 * math.PI) / 3
	return x == 0 ? 0 : x == 1 ? 1 : -math.pow(2, 10 * x - 10) * math.sin((x * 10 - 10.75) * c4)
}

ease_out_elastic :: proc(x: $T) -> T where intrinsics.type_is_numeric(T) {
	c4 :: (2 * math.PI) / 3
	return x == 0 ? 0 : x == 1 ? 1 : math.pow(2, -10 * x) * math.sin((x * 10 - 0.75) * c4) + 1
}

ease_in_out_elastic :: proc(x: $T) -> T where intrinsics.type_is_numeric(T) {
	c5 :: (2 * math.PI) / 4.5
	return x == 0 ? 0 : x == 1 ? 1 : x < 0.5 ? -(math.pow(2, 20 * x - 10) * math.sin((20 * x - 11.125) * c5)) / 2 : (math.pow(2, -20 * x + 10) * math.sin((20 * x - 11.125) * c5)) / 2 + 1
}

ease_in_quad :: proc(t: $T) -> T where intrinsics.type_is_numeric(T) {
    if t > 1.0 {
        return 1.0
    }
    return t * t
}

ease_out_quad :: proc(t: $T) -> T where intrinsics.type_is_numeric(T) {
    return 1 - (1 - t) * (1 - t)
}

ease_in_out_quad :: proc(x: $T) -> T where intrinsics.type_is_numeric(T) {
	return x < 0.5 ? 2 * x * x : 1 - math.pow(-2 * x + 2, 2) / 2
}

ease_in_quint :: proc(t: $T) -> T where intrinsics.type_is_numeric(T) {
    return math.pow(t, 5)
}

ease_out_quint :: proc(x: $T) -> T where intrinsics.type_is_numeric(T) {
	return 1 - math.pow(1 - x, 5)
}

ease_in_out_quint :: proc(t: $T) -> T where intrinsics.type_is_numeric(T) {
    return t < 0.5 ? 16 * t * t * t * t * t : 1 - math.pow(-2 * t + 2, 5) / 2
}

ease_in_quart :: proc(x: $T) -> T where intrinsics.type_is_numeric(T) {
	return x * x * x * x
}

ease_out_quart :: proc(x: $T) -> T where intrinsics.type_is_numeric(T) {
	return 1 - math.pow(1 - x, 4)
}

ease_in_out_quart :: proc(x: $T) -> T where intrinsics.type_is_numeric(T) {
	return x < 0.5 ? 8 * x * x * x * x : 1 - math.pow(-2 * x + 2, 4) / 2
}

ease_in_expo :: proc(x: $T) -> T where intrinsics.type_is_numeric(T) {
	return x == 0 ? 0 : math.pow(2, 10 * x - 10)
}

ease_out_expo :: proc(x: $T) -> T where intrinsics.type_is_numeric(T) {
	return x == 1 ? 1 : 1 - math.pow(2, -10 * x)
}

ease_in_out_expo :: proc(x: $T) -> T where intrinsics.type_is_numeric(T) {
	return x == 0 ? 0 : x == 1 ? 1 : x < 0.5 ? math.pow(2, 20 * x - 10) / 2 : (2 - math.pow(2, -20 * x + 10)) / 2
}

ease_in_bounce :: proc(x: $T) -> T where intrinsics.type_is_numeric(T) {
	return 1 - ease_out_bounce(1 - x)
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

ease_in_out_bounce :: proc(x: $T) -> T where intrinsics.type_is_numeric(T) {
	return x < 0.5 ? (1 - ease_out_bounce(1 - 2 * x)) / 2 : (1 + ease_out_bounce(2 * x - 1)) / 2
}

ease_in_back :: proc(x: $T) -> T where intrinsics.type_is_numeric(T) {
	c1 :: 1.70158
	c3 :: c1 + 1
	return c3 * x * x * x - c1 * x * x
}

ease_out_back :: proc(x: $T) -> T where intrinsics.type_is_numeric(T) {
	c1 :: 1.70158
	c3 :: c1 + 1
	return 1 + c3 * math.pow(x - 1, 3) + c1 * math.pow(x - 1, 2)
}

ease_in_out_back :: proc(t: $T) -> T where intrinsics.type_is_numeric(T) {
    c1: T = 1.70158
    c2 := c1 * 1.525

    if t < 0.5 {
        return (math.pow(2 * t, 2) * ((c2 + 1) * 2 * t - c2)) / 2
    } else {
        return (math.pow(2 * t - 2, 2) * ((c2 + 1) * (t * 2 - 2) + c2) + 2) / 2
    }
}