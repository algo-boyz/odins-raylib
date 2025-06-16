package color

import "core:math"
import "core:math/rand"
import rl "vendor:raylib"

// GOLDEN_RATIO := (math.sqrt_f32(5) + 1) / 2
GOLDEN_RATIO :: 0.618033988749895

// Generate an array of random colors
random_colors :: proc(n : int, colors: ^[]rl.Color) {
    for index in 0 ..< n {
        colors[index] = rl.Color{
			cast(u8)rand.float32_uniform(0, 255),
			cast(u8)rand.float32_uniform(0, 255),
			cast(u8)rand.float32_uniform(0, 255),
			255,
        }
    }
}

// rand returns a random color between the given low and high colors.
random :: proc(low := rl.BLACK, high := rl.WHITE) -> rl.Color {
    return {
        random_u8(low.r, high.r),
        random_u8(low.g, high.g),
        random_u8(low.b, high.b),
        255,
    }
}

random_rgb :: proc() -> rl.Color {
	return {
		u8(rand.float32() * 255),
		u8(rand.float32() * 255),
		u8(rand.float32() * 255),
		255,
	}
}

random_hsluv :: proc(s := f64(1), l := f64(0.5)) -> rl.Color {
	hue := rand.float64() * 360
	r, g, b := hsluv_to_rgb(hue, s * 100, l * 100)
	return { u8(r * 255), u8(g * 255), u8(b * 255), 255 }
}

random_hsluv_golden :: proc(s := f64(1), l := f64(0.5)) -> rl.Color {
	hue := math.mod(rand.float64() + GOLDEN_RATIO, 1) * 360
	r, g, b := hsluv_to_rgb(hue, s * 100, l * 100)
	return { u8(r * 255), u8(g * 255), u8(b * 255), 255 }
}

random_u8 :: proc(low, high: u8) -> u8 {
	if low == high do return low
	return u8(rand.int_max(int(high - low))) + low
}