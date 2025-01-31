package color

import "core:math"
import rl "vendor:raylib"

// hsv_to_rgb converts a color from HSV (Hue, Saturation, Value) to RGB color space
// Input vec3 should be:
//   x (hue): 0.0 to 1.0
//   y (saturation): 0.0 to 1.0
//   z (value): 0.0 to 1.0
// Returns RGB values in range 0.0 to 1.0
hsv_to_rgb :: proc(hsv: rl.Vector3) -> rl.Vector3 {
    h := hsv.x
    s := hsv.y
    v := hsv.z

    // Compute intermediate values
    h_prime := fract(h) * 6.0
    c := v * s
    x := c * (1.0 - abs(fract(h_prime / 2.0) * 2.0 - 1.0))
    m := v - c

    // Initialize RGB values
    r, g, b: f32

    // Calculate RGB based on hue section
    switch section := int(h_prime); section {
        case 0:
            r = c; g = x; b = 0
        case 1:
            r = x; g = c; b = 0
        case 2:
            r = 0; g = c; b = x
        case 3:
            r = 0; g = x; b = c
        case 4:
            r = x; g = 0; b = c
        case 5:
            r = c; g = 0; b = x
        case:
            r = 0; g = 0; b = 0
    }

    return rl.Vector3{r + m, g + m, b + m}
}

// fract returns the fractional part of a number
fract :: proc(x: f32) -> f32 {
    return x - math.floor(x)
}