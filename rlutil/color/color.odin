package color

import "core:math"
import "core:math/rand"
import rl "vendor:raylib"

// CSS 1 Colors
White := rl.Color{ 255, 255, 255, 255}
Silver := rl.Color{ 192, 192, 192, 255}
Gray := rl.Color{ 128, 128, 128, 255}
BLACK := rl.Color{ 0, 0, 0, 255}
Red := rl.Color{ 255, 0, 0, 255}
Maroon := rl.Color{ 128, 0, 0, 255}
Lime := rl.Color{ 0, 255, 0, 255}
Green := rl.Color{ 0, 128, 0, 255}
Blue := rl.Color{ 0, 0, 255, 255}
Navy := rl.Color{ 0, 0, 128, 255}
Yellow := rl.Color{ 255, 255, 0, 255}
Orange := rl.Color{ 255, 165, 0, 255}
Olive := rl.Color{ 128, 128, 0, 255}
Purple := rl.Color{ 128, 0, 128, 255}
Fuchsia := rl.Color{ 255, 0, 255, 255}
Teal := rl.Color{ 0, 128, 128, 255}
Aqua := rl.Color{ 0, 255, 255, 255}

// CSS3 colors

// Reds
IndianRed := rl.Color{ 205, 92, 92, 255}
LightCoral := rl.Color{ 240, 128, 128, 255}
Salmon := rl.Color{ 250, 128, 114, 255}
DarkSalmon := rl.Color{ 233, 150, 122, 255}
LightSalmon := rl.Color{ 255, 160, 122, 255}
Crimson := rl.Color{ 220, 20, 60, 255}
FireBrick := rl.Color{ 178, 34, 34, 255}
DarkRed := rl.Color{ 139, 0, 0, 255}                                         

// Pinks 
Pink := rl.Color{ 255, 192, 203, 255}
LightPink := rl.Color{ 255, 182, 193, 255}
HotPink := rl.Color{ 255, 105, 180, 255}
DeepPink := rl.Color{ 255, 20, 147, 255}
MediumVioletRed := rl.Color{ 199, 21, 133, 255}
PaleVioletRed := rl.Color{ 219, 112, 147, 255}

// Oranges
Coral := rl.Color{ 255, 127, 80, 255}
Tomato := rl.Color{ 255, 99, 71, 255}
OrangeRed := rl.Color{ 255, 69, 0, 255}
DarkOrange := rl.Color{ 255, 140, 0, 255}       

// Yellows           
Gold := rl.Color{ 255, 215, 0, 255}
LightYellow := rl.Color{ 255, 255, 224, 255}
LemonChiffon := rl.Color{ 255, 250, 205, 255}
LightGoldenrodYellow := rl.Color{ 250, 250, 210, 255}
PapayaWhip := rl.Color{ 255, 239, 213, 255}
Moccasin := rl.Color{ 255, 228, 181, 255}
PeachPuff := rl.Color{ 255, 218, 185, 255}
PaleGoldenrod := rl.Color{ 238, 232, 170, 255}
Khaki := rl.Color{ 240, 230, 140, 255}
DarkKhaki := rl.Color{ 189, 183, 107, 255}

// Purples   
Lavender := rl.Color{ 230, 230, 250, 255}
Thistle := rl.Color{ 216, 191, 216, 255}
Plum := rl.Color{ 221, 160, 221, 255}
Violet := rl.Color{ 238, 130, 238, 255}
Orchid := rl.Color{ 218, 112, 214, 255}
Magenta := rl.Color{ 255, 0, 255, 255}
MediumOrchid := rl.Color{ 186, 85, 211, 255}
MediumPurple := rl.Color{ 147, 112, 219, 255}
BlueViolet := rl.Color{ 138, 43, 226, 255}
DarkViolet := rl.Color{ 148, 0, 211, 255}
DarkOrchid := rl.Color{ 153, 50, 204, 255}
DarkMagenta := rl.Color{ 139, 0, 139, 255}
RebeccaPurple := rl.Color{ 102, 51, 153, 255}
Indigo := rl.Color{ 75, 0, 130, 255}
MediumSlateBlue := rl.Color{ 123, 104, 238, 255}
SlateBlue := rl.Color{ 106, 90, 205, 255}
DarkSlateBlue := rl.Color{ 72, 61, 139, 255}

// Greens
GreenYellow := rl.Color{ 173, 255, 47, 255}
Chartreuse := rl.Color{ 127, 255, 0, 255}
LawnGreen := rl.Color{ 124, 252, 0, 255}
LimeGreen := rl.Color{ 50, 205, 50, 255}
PaleGreen := rl.Color{ 152, 251, 152, 255}                                
LightGreen := rl.Color{ 144, 238, 144, 255}
MediumSpringGreen := rl.Color{ 0, 250, 154, 255}
SpringGreen := rl.Color{ 0, 255, 127, 255}
MediumSeaGreen := rl.Color{ 60, 179, 113, 255}
SeaGreen := rl.Color{ 46, 139, 87, 255}
ForestGreen := rl.Color{ 34, 139, 34, 255}
DarkGreen := rl.Color{ 0, 100, 0, 255}
YellowGreen := rl.Color{ 154, 205, 50, 255}
OliveDrab := rl.Color{ 107, 142, 35, 255}
DarkOliveGreen := rl.Color{ 85, 107, 47, 255}
MediumAquamarine := rl.Color{ 102, 205, 170, 255}
DarkSeaGreen := rl.Color{ 143, 188, 143, 255}
LightSeaGreen := rl.Color{ 32, 178, 170, 255}
DarkCyan := rl.Color{ 0, 139, 139, 255}

// Blues            
Cyan := rl.Color{ 0, 255, 255, 255}
LightCyan := rl.Color{ 224, 255, 255, 255}
PaleTurquoise := rl.Color{ 175, 238, 238, 255}
Aquamarine := rl.Color{ 127, 255, 212, 255}
Turquoise := rl.Color{ 64, 224, 208, 255}
MediumTurquoise := rl.Color{ 72, 209, 204, 255}
DarkTurquoise := rl.Color{ 0, 206, 209, 255}
CadetBlue := rl.Color{ 95, 158, 160, 255}
SteelBlue := rl.Color{ 70, 130, 180, 255}
LightSteelBlue := rl.Color{ 176, 196, 222, 255}
PowderBlue := rl.Color{ 176, 224, 230, 255}
LightBlue := rl.Color{ 173, 216, 230, 255}
SkyBlue := rl.Color{ 135, 206, 235, 255}
LightSkyBlue := rl.Color{ 135, 206, 250, 255}
DeepSkyBlue := rl.Color{ 0, 191, 255, 255}
DodgerBlue := rl.Color{ 30, 144, 255, 255}
CornflowerBlue := rl.Color{ 100, 149, 237, 255}
RoyalBlue := rl.Color{ 65, 105, 225, 255}
MediumBlue := rl.Color{ 0, 0, 205, 255}
DarkBlue := rl.Color{ 0, 0, 139, 255}
MidnightBlue := rl.Color{ 25, 25, 112, 255}

// Browns       
Cornsilk := rl.Color{ 255, 248, 220, 255}
BlanchedAlmond := rl.Color{ 255, 235, 205, 255}
Bisque := rl.Color{ 255, 228, 196, 255}
NavajoWhite := rl.Color{ 255, 222, 173, 255}
Wheat := rl.Color{ 245, 222, 179, 255}                                 
BurlyWood := rl.Color{ 222, 184, 135, 255}
Tan := rl.Color{ 210, 180, 140, 255}
RosyBrown := rl.Color{ 188, 143, 143, 255}
SandyBrown := rl.Color{ 244, 164, 96, 255}
Goldenrod := rl.Color{ 218, 165, 32, 255}
DarkGoldenrod := rl.Color{ 184, 134, 11, 255}
Peru := rl.Color{ 205, 133, 63, 255}
Chocolate := rl.Color{ 210, 105, 30, 255}
SaddleBrown := rl.Color{ 139, 69, 19, 255}
Sienna := rl.Color{ 160, 82, 45, 255}
Brown := rl.Color{ 165, 42, 42, 255}

// Whites
Snow := rl.Color{ 255, 250, 250, 255}
Honeydew := rl.Color{ 240, 255, 240, 255}
MintCream := rl.Color{ 245, 255, 250, 255}
Azure := rl.Color{ 240, 255, 255, 255}
AliceBlue := rl.Color{ 240, 248, 255, 255}
GhostWhite := rl.Color{ 248, 248, 255, 255}
WhiteSmoke := rl.Color{ 245, 245, 245, 255}
Seashell := rl.Color{ 255, 245, 238, 255}
Beige := rl.Color{ 245, 245, 220, 255}
OldLace := rl.Color{ 253, 245, 230, 255}
FloralWhite := rl.Color{ 255, 250, 240, 255}
Ivory := rl.Color{ 255, 255, 240, 255}
AntiqueWhite := rl.Color{ 250, 235, 215, 255}
Linen := rl.Color{ 250, 240, 230, 255}
LavenderBlush := rl.Color{ 255, 240, 245, 255}
MistyRose := rl.Color{ 255, 228, 225, 255}

// Grays
Gainsboro := rl.Color{ 220, 220, 220, 255}
LightGray := rl.Color{ 211, 211, 211, 255}
LightGrey := rl.Color{ 211, 211, 211, 255}
DarkGray := rl.Color{ 169, 169, 169, 255}
Grey := rl.Color{ 128, 128, 128, 255}                                     
DimGray := rl.Color{ 105, 105, 105, 255}
LightSlateGray := rl.Color{ 119, 136, 153, 255}
SlateGray := rl.Color{ 112, 128, 144, 255}
DarkSlateGray := rl.Color{ 47, 79, 79, 255}

color_blend :: proc(c1, c2: rl.Color, amount: f32, use_alpha: bool) -> rl.Color {
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

color_blend_amount :: proc(a, b: rl.Color, t: f32) -> (result: rl.Color) {
	result.a = a.a
	result.r = u8((1.0 - t) * f32(b.r) + t * f32(a.r))
	result.g = u8((1.0 - t) * f32(b.g) + t * f32(a.g))
	result.b = u8((1.0 - t) * f32(b.b) + t * f32(a.b))
	return
}

color_alpha :: proc(color: rl.Color, alpha: f32) -> (res: rl.Color) {
	res = color
	res.a = u8(alpha * 255)
	return
}

color_to_bw :: proc(a: rl.Color) -> rl.Color {
	return max(a.r, a.g, a.b) < 125 ? rl.WHITE : rl.BLACK
}

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

@(private)
srgb :: proc(component: f32) -> f32 {
    return (component / 255 <= 0.03928) ? component / 255 / 12.92 : math.pow((component / 255 + 0.055) / 1.055, 2.4)
}

luminance :: proc(color: rl.Color) -> f32 {
    return(
        ((0.2126 * srgb(cast(f32)color.r)) +
            (0.7152 * srgb(cast(f32)color.g)) +
            (0.0722 * srgb(cast(f32)color.b))) / 255)
}

@(private)
contrast :: proc(fg, bg: rl.Color) -> f32 {
    l1 := luminance(fg)
    l2 := luminance(bg)
    return (max(l1, l2) + 0.05) / (min(l1, l2) + 0.05)
}

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

