package color

import "core:math"
import "core:math/rand"
import rl "vendor:raylib"

// GOLDEN_RATIO := (math.sqrt_f32(5) + 1) / 2
GOLDEN_RATIO :: 0.618033988749895

rand_rgb :: proc() -> rl.Color {
	return {
		u8(rand.float32() * 255),
		u8(rand.float32() * 255),
		u8(rand.float32() * 255),
		255,
	}
}

rand_hsluv :: proc(s := f64(1), l := f64(0.5)) -> rl.Color {
	hue := rand.float64() * 360
	r, g, b := hsluv_to_rgb(hue, s * 100, l * 100)
	return { u8(r * 255), u8(g * 255), u8(b * 255), 255 }
}

rand_hsluv_golden :: proc(s := f64(1), l := f64(0.5)) -> rl.Color {
	hue := math.mod(rand.float64() + GOLDEN_RATIO, 1) * 360
	r, g, b := hsluv_to_rgb(hue, s * 100, l * 100)
	return { u8(r * 255), u8(g * 255), u8(b * 255), 255 }
}