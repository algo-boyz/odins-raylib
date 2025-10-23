package rlutil

import "base:intrinsics"
import "core:math"
import "core:math/rand"
import "core:testing"

// Utility to check if a value is within a range
in_range :: proc(value, min_val, max_val: $T) -> bool where intrinsics.type_is_numeric(T) {
	if value > min_val && value < max_val do return true
	return false
}

// Percentile calculation for a sorted slice
percentile :: proc(sorted_slice: $A/[]$T, frac: T) -> T where intrinsics.type_is_numeric(T) {
	idx_numeric := frac * T(len(sorted_slice) - 1)
	idx := int(idx_numeric)
	remainder := idx_numeric - T(idx) // Fixed remainder calculation
	return math.lerp(remainder, sorted_slice[idx], sorted_slice[idx + 1])
}

// Power function u32
@(require_results)
pow_u32 :: proc(base, exp: u32) -> u32 {
	if exp == 0 do return 1
	return u32(expo_fast(i64(base), exp))
}

// Power function i32
@(require_results)
pow_i32 :: proc(base, exp: i32) -> f32 {
	if exp < 0 do return 1.0 / f32(expo_fast(i64(base), u32(-exp)))
	return f32(expo_fast(i64(base), u32(exp)))
}

// Generic power function
@(require_results)
pow :: proc{ pow_u32, pow_i32 }

// Fast exponentiation
expo_fast :: proc(base: i64, exp: u32) -> i64 {
	current_exp := exp
	current_base := base
	res := i64(1)
	for current_exp > 0 {
		if current_exp & 1 == 1 {
			res *= current_base
		}
		current_base *= current_base
		current_exp >>= 1
	}
	return res
}

/*
Fast inverse square root (Quake III algo)
NOTE: Purely for nostalgia, Odin's math lib provides efficient alternatives
*/
q_rsqrt :: proc(num: f32) -> f32 {
    i: i32
    x2, y: f32
    threehalfs: f32 = 1.5
    x2 = num * 0.5
    y = num
    i = (^i32)(&y)^            // Bit hack
    i = 0x5f3759df - (i >> 1)  // Magic number
    y = (^f32)(&i)^
    return y * (threehalfs - (x2 * y * y))
}


@(test)
pow_test :: proc(t: ^testing.T) {
	testing.expect_value(t, pow(u32(2), u32(3)), u32(8))
	testing.expect_value(t, pow(i32(2), i32(-2)), f32(0.25))
}

@(test)
fast_expo_test :: proc(t: ^testing.T) {
	testing.expect_value(t, expo_fast(3, 3), 27)
}