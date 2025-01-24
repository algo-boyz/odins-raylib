// This is some signed distance field drawing experiments. You can draw hills.
// It's very inefficient and runs on CPU. But the basic ideas are there.

package game

import "core:math/linalg"
import "core:math/noise"
import "base:intrinsics"
import "core:math"
import rl "vendor:raylib"

Vec2 :: rl.Vector2

PixelWindowHeight :: 180
GridWidth :: 320
GridHeight :: 180

Brush :: enum {
	Circle,
	Square,
}

ColorGrass :: rl.Color { 100, 200, 100, 255 }
ColorDarkGrass :: rl.Color { 15, 116, 70, 255 }
ColorMud :: rl.Color { 156, 79, 79, 255 }
ColorDark :: rl.Color { 76, 53, 83, 255 }

camera_pos: Vec2

// All values in this one is set to 32 by default
sdf: [GridWidth][GridHeight]f32

// Change with mouse wheel
radius: f32

// Change with keyboard key 1 and 2
brush: Brush

main :: proc() {
	rl.SetConfigFlags({.WINDOW_RESIZABLE})
	rl.InitWindow(1280, 720, "SDF terrain painter")
	rl.SetWindowPosition(200, 200)
	rl.SetTargetFPS(500)
	
	radius = 10

	for x in 0..<GridWidth {
		for y in 0..<GridHeight {
			sdf[x][y] = 32
		}
	}

	for !rl.WindowShouldClose() {
		update()
	}

	rl.CloseWindow()
}

update :: proc() {
	// Circle and square brush. Press 1 and 2 to change.
	if rl.IsKeyPressed(.ONE) {
		brush = .Circle
	}

	if rl.IsKeyPressed(.TWO) {
		brush = .Square
	}

	rl.BeginDrawing()
	
	camera := rl.Camera2D {
		zoom = f32(rl.GetScreenHeight())/PixelWindowHeight,
	}

	rl.BeginMode2D(camera)

	if rl.IsKeyDown(.SPACE) {
		// Hold space to see the actual SDF
		rl.ClearBackground(ColorGrass)
		for x in 0..<GridWidth {
			for y in 0..<GridHeight {
				s := sdf[x][y]
				c: rl.Color

				if s > 0 {
					c = {0, u8(s*7.9), 0, 255}
				} else {
					c = {u8(s*7.9), 0, 0, 255}
				}

				rl.DrawPixelV({f32(x), f32(y)}, c)
			}
		}
	} else {
		// Draw pretty hills based on SDF

		rl.ClearBackground(ColorGrass)
		for x in 0..<GridWidth {
			for y in 0..<GridHeight {
				s := sdf[x][y]

				p := vec2_from_int(x, y)
  				n := sdf_calculate_normal(p)
  				//rl.DrawLineV(p, p + n, rl.RED)

  				d := n.y

  				r1 := remap(d, -1, 1, 0, 1)

  				n2d := remap(noise.noise_2d(0, {f64(p.x), f64(p.y)}/6), -1, 1, 0, 1)
  				n22d := remap(noise.noise_2d(0, {f64(p.x), f64(p.y)}/10), -1, 1, 0, 1)

  				r := remap(r1, 0.2, 0.8, 2.5, 14)

				if s > 0 && s < r {
					c := ColorMud

					if s > r * 0.5 {
						if r > 5 && (s > r * 0.75 || n2d*(remap(14-s, 0, 10, 0, 1)) < 0.2){
							c = ColorDark
						}
					}

					rl.DrawPixelV(p, c)
				}

				if s > -2 && s < 5*remap(d, 0, 1, 0.2, 1) {
					if (s > -1 && s < 2) || n22d*(remap(14-s, 0, 10, 0, 1)) > 0.8 {
						rl.DrawPixelV(p, ColorDarkGrass)
					}
				}

				if s > r * 0.9 && s < r + 1 {
					if remap(d, 0, 1, 0, 0.5) > 0 && n22d*(remap(s, 0, 14, 0, 1)) < 0.5 {
						rl.DrawPixelV(p, ColorDarkGrass)
					}
				}
			}
		}
	}

	bp := vec2_floor(brush_pos(camera))
	r := radius
	radius += rl.GetMouseWheelMove()

	// These two procs are the ones that the brushes use to draw into the SDF
	sdf_circle :: proc(p: Vec2, r: f32) -> f32 {
		return linalg.length(p)-r
	}

	sdf_box :: proc(p: Vec2, b: Vec2) -> f32 {
    	d := linalg.abs(p) - b
    	return linalg.length(linalg.max(d, 0)) + min(max(d.x, d.y), 0)
	}

	smin :: proc(a, b, k: f32) -> f32 {
		h := max(k - abs(a - b), 0.0) / k
		return min(a, b) - h * h * h * k / 6.0
	}

	smax :: proc(a, b, k: f32) -> f32 {
		k := k * 1.4
		h := max(k - abs(a - b), 0.0)
		return max(a, b) + h * h * h / (6.0 * k * k)
	}

	switch brush {
	case .Circle:
		for i := bp.y-r; i <= bp.y+r; i+=1 {
			for j := bp.x; (j-bp.x)*(j-bp.x) + (i-bp.y)*(i-bp.y) < r*r; j-=1 {
				p := Vec2{j, i}
				if r-linalg.length(p-bp) < 2 {
					rl.DrawPixelV({j, i}, rl.WHITE)
				}
			}
			for j := bp.x+1; (j-bp.x)*(j-bp.x) + (i-bp.y)*(i-bp.y) < r*r; j+=1 {
				p := Vec2{j, i}
				if r-linalg.length(p-bp) < 2 {
					rl.DrawPixelV({j, i}, rl.WHITE)
				}
			}
		}

		if rl.IsMouseButtonDown(.LEFT) {
			for x in 0..<GridWidth {
				for y in 0..<GridHeight {
					sdf[x][y] = clamp(smin(sdf[x][y], sdf_circle(vec2_from_int(x,y) - bp, r), 1), -32, 32)
				}
			}
		}

		if rl.IsMouseButtonDown(.RIGHT) {
			for x in 0..<GridWidth {
				for y in 0..<GridHeight {
					sdf[x][y] = clamp(smax(sdf[x][y], -sdf_circle(vec2_from_int(x,y) - bp, r),1), -32, 32)
				}
			}
		}
	case .Square:
		rect := rl.Rectangle {
			bp.x - r,
			bp.y - r,
			r*2,
			r*2,
		}
		rl.DrawRectangleLinesEx(rect, 1, rl.WHITE)
		
		if rl.IsMouseButtonDown(.LEFT) {
			for x in 0..<GridWidth {
				for y in 0..<GridHeight {
					sdf[x][y] = clamp(smin(sdf[x][y], sdf_box(vec2_from_int(x,y) - bp, {r, r}), 1), -32, 32)
				}
			}
		}

		if rl.IsMouseButtonDown(.RIGHT) {
			for x in 0..<GridWidth {
				for y in 0..<GridHeight {
					sdf[x][y] = clamp(smax(sdf[x][y], -sdf_box(vec2_from_int(x,y) - bp, {r, r}),1), -32, 32)
				}
			}
		}
	}

	rl.EndMode2D()

	rl.EndDrawing()
}

get_sdf_val :: proc(p: Vec2) -> f32 {
	return sdf[int(clamp(p.x, 0, GridWidth-1))][int(clamp(p.y, 0, GridHeight-1))]
}

// Calculate normal of surface based on nearby SDF values. This is essentially the gradient
// at a point, but as you see I skew it to pick points further away downward. That was an 
// attempt to make hills that are near each other in the Y direction look better.
sdf_calculate_normal :: proc(p: Vec2) -> Vec2 {
	s1 := linalg.normalize0(Vec2{
		get_sdf_val(p + {2, 0}) - get_sdf_val(p - {2, 0}),
		get_sdf_val(p + {0, 2}) - get_sdf_val(p - {0, 4}),
	})

	s2 := linalg.normalize0(Vec2{
		get_sdf_val(p + {4, 0}) - get_sdf_val(p - {4, 0}),
		get_sdf_val(p + {0, 4}) - get_sdf_val(p - {0, 8}),
	})

	return (s1 + s2) /2
}

remap :: proc "contextless" (old_value, old_min, old_max, new_min, new_max: $T) -> (x: T) where intrinsics.type_is_numeric(T), !intrinsics.type_is_array(T) {
	remapped := math.remap(old_value, old_min, old_max, new_min, new_max)
	return clamp(remapped, new_min, new_max)
}

brush_pos :: proc(c: rl.Camera2D) -> Vec2 {
	mp := rl.GetMousePosition()
	return rl.GetScreenToWorld2D(mp, c)
}

vec2_from_int :: proc(x: int, y: int) -> Vec2 {
	return { f32(x), f32(y) }
}

vec2_floor :: proc(p: Vec2) -> Vec2 {
	return { math.floor(p.x), math.floor(p.y) }
}