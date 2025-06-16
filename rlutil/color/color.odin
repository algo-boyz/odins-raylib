package color

import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:math/rand"
import "core:strconv"
import rl "vendor:raylib"

add :: proc(a, b: rl.Color) -> rl.Color {
    a := linalg.array_cast(a, i32)
    b := linalg.array_cast(b, i32)

    c := linalg.clamp(a + b, 0, 255)
    return rl.Color(linalg.array_cast(c, u8))
}

// Subtract two colors
sub :: proc(a, b: rl.Color) -> rl.Color {
	a := linalg.array_cast(a, i32)
	b := linalg.array_cast(b, i32)

	c := linalg.clamp(a - b, 0, 255)
	return rl.Color(linalg.array_cast(c, u8))
}

blend :: proc(c1, c2: rl.Color, amount: f32, use_alpha: bool) -> rl.Color {
	r := amount * (f32(c1.r) / 255) + (1 - amount) * (f32(c2.r) / 255)
	g := amount * (f32(c1.g) / 255) + (1 - amount) * (f32(c2.g) / 255)
	b := amount * (f32(c1.b) / 255) + (1 - amount) * (f32(c2.b) / 255)
	a := amount * (f32(c1.a) / 255) + (1 - amount) * (f32(c2.a) / 255)

	return rl.Color {
		u8(r * 255),
		u8(g * 255),
		u8(b * 255),
		u8(use_alpha ? u8(a * 255) : 255),
	}
}

// Blend two colors by a given amount (0.0 to 1.0)
blend_by :: proc(a, b: rl.Color, amount: f32) -> (result: rl.Color) {
	if amount < 0 || amount > 1 {
		panic("blend_by: amount must be between 0.0 and 1.0")
	}
	r := f32(a.r) * (1 - amount) + f32(b.r) * amount
	g := f32(a.g) * (1 - amount) + f32(b.g) * amount
	b := f32(a.b) * (1 - amount) + f32(b.b) * amount

	return rl.Color{
		u8(r),
		u8(g),
		u8(b),
		a.a,
	}
}

// Convert a color to grayscale
to_grayscale :: proc(color : rl.Color) -> rl.Color {
	gray := u8((f32(color.r) + f32(color.g) + f32(color.b)) / 3)
	return rl.Color{
		gray,
		gray,
		gray,
		color.a,
	}
}

// Convert a color to black or white based on its brightness
to_bw :: proc(a: rl.Color) -> rl.Color {
	return max(a.r, a.g, a.b) < 125 ? rl.WHITE : rl.BLACK
}

// Generate a gradient of colors between start and end color
gradient :: proc(start, end: rl.Color, n : int, colors: ^[]rl.Color) {
    for i in 0 ..< n {
        f := f32(i) / f32(n)
        colors[i] = rl.Color{
			start.r + u8(f32(end.r) - f32(start.r) * f),
			start.g + u8(f32(end.g) - f32(start.g) * f),
			start.b + u8(f32(end.b) - f32(start.b) * f),
			255,
        }
    }
}

// Convert a color component from sRGB to linear RGB
srgb :: proc(component: f32) -> f32 {
    return (component / 255 <= 0.03928) ? component / 255 / 12.92 : math.pow((component / 255 + 0.055) / 1.055, 2.4)
}

// Calculate the relative luminance of a color
luminance :: proc(color: rl.Color) -> f32 {
    return(
        ((0.2126 * srgb(cast(f32)color.r)) +
            (0.7152 * srgb(cast(f32)color.g)) +
            (0.0722 * srgb(cast(f32)color.b))) / 255)
}

// Calculate the contrast ratio between two colors
contrast :: proc(fg, bg: rl.Color) -> f32 {
    l1 := luminance(fg)
    l2 := luminance(bg)
    return (max(l1, l2) + 0.05) / (min(l1, l2) + 0.05)
}

// Darken a color by a given amount
darken :: proc(color : rl.Color, amount : int = 20) -> rl.Color {
	return rl.Color{
		u8(math.max(0, cast(int)color.r - amount)),
		u8(math.max(0, cast(int)color.g - amount)),
		u8(math.max(0, cast(int)color.b - amount)),
		color.a,
	}
}

// Lighten a color by a given amount
lighten :: proc(color : rl.Color, amount : int = 20) -> rl.Color {
	return rl.Color{
		u8(math.min(255, cast(int)color.r + amount)),
		u8(math.min(255, cast(int)color.g + amount)),
		u8(math.min(255, cast(int)color.b + amount)),
		color.a,
	}
}

// Set the alpha value of a color (transparency)
set_alpha :: proc(color : rl.Color, val : f32) -> rl.Color {
	return rl.Color{
		color.r,
		color.g,
		color.b,
		u8(math.clamp(val * 255, 0, 255)),
	}
}

// Blend the color with a given alpha value
fade :: proc(color : rl.Color, alpha : f32) -> rl.Color {
	if alpha < 0 || alpha > 1 {
		panic("fade: alpha must be between 0.0 and 1.0")
	}
	return rl.Color{
		color.r,
		color.g,
		color.b,
		u8(cast(f32)color.a * alpha),
	}
}

// Convert a color to a hex string
to_hex :: proc(color : rl.Color) -> string {
	return fmt.tprintf("#%02x%02x%02x%02x", color.r, color.g, color.b, color.a)
}

// Convert a hex string to a color
from_hex :: proc(hex: string) -> (color: rl.Color, ok: bool) {
	if len(hex) != 7 && len(hex) != 9 {
		return rl.Color{}, false
	}
	r_val, r_ok:= strconv.parse_int(hex[1:3], 16)
	g_val, g_ok:= strconv.parse_int(hex[3:5], 16)
	b_val, b_ok:= strconv.parse_int(hex[5:7], 16)
	if !r_ok|| !g_ok|| !b_ok{
		return rl.Color{}, false
	}
	a:u8
	if len(hex) == 9 {
		a_val, a_ok:= strconv.parse_int(hex[7:9], 16)
		if !a_ok{
			return rl.Color{}, false
		}
		a = u8(a_val)
	} else {
		a = 255
	}
	return rl.Color{u8(r_val), u8(g_val), u8(b_val), a}, true
}
