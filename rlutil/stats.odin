package rlutil

import "core:math/rand"

// chance returns true with the given probability
chance :: proc(probability: f64) -> bool {
    // if random value is less than the probability
    return rand.float64() < clamp(probability, 0.0, 1.0)
}

in_range :: proc(value, min_val, max_val : i32) -> bool
{
	if value > min_val && value < max_val do return true
	return false
}