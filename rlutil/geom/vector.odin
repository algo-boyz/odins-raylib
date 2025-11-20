package geom

import "core:math"
import rl "vendor:raylib"

vec2_magnitude :: proc(v: rl.Vector2) -> f32 {
    return math.sqrt(v.x*v.x + v.y*v.y)
}

// Sets the magnitude (length) of a vector
vec2_set_magnitude :: proc(v: rl.Vector2, mag: f32) -> rl.Vector2 {
	len := rl.Vector2Length(v)
	if len == 0 {
		return {mag, 0} // Or some other default
	}
	return v * mag / len
}

// Gets the heading (angle) of a vector in radians
vec2_heading :: proc(v: rl.Vector2) -> f32 {
	return math.atan2(v.y, v.x)
}

vec2_angle :: proc(v: rl.Vector2) -> f32 {
    if v.x == 0 do return 0
    return math.atan2(v.y, v.x)
}

// Creates a vector from an angle
vec2_from_angle :: proc(angle: f32) -> rl.Vector2 {
	return {math.cos(angle), math.sin(angle)}
}

// Vector2 helper functions
vec2_normalize :: proc(v: rl.Vector2) -> rl.Vector2 {
    length := vec2_length(v)
    if length == 0 do return {0, 0}
    return {v.x / length, v.y / length}
}

vec2_length :: proc(v: rl.Vector2) -> f32 {
    return math.sqrt(v.x * v.x + v.y * v.y)
}

vec2_set_length :: proc(v: rl.Vector2, length: f32) -> rl.Vector2 {
    normalized := vec2_normalize(v)
    return {normalized.x * length, normalized.y * length}
}

vec2_distance :: proc(a, b: rl.Vector2) -> f32 {
    return vec2_length(a - b)
}

// Set distance between two points
vec2_set_distance :: proc(current_point, anchor: rl.Vector2, distance: f32) -> rl.Vector2 {
    to_anchor := current_point - anchor
    if vec2_length(to_anchor) == 0 do return current_point
    to_anchor = vec2_set_length(to_anchor, distance)
    return to_anchor + anchor
}

vec2_lerp :: proc(a, b: rl.Vector2, t: f32) -> rl.Vector2 {
    return {a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t}
}

// Verlet integration
vec2_verlet_integrate :: proc(cur_pt, prev_pt: ^rl.Vector2) {
    temp := cur_pt^
    cur_pt^ = cur_pt^ + (cur_pt^ - prev_pt^)
    prev_pt^ = temp
}