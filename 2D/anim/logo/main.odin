package logo

import "core:c"
import rl "vendor:raylib"

State :: enum {
	Blink,
	Top_Left_Sides,
	Right_Bottom_Sides,
	Letters,
	Zoom_Out,
	Fade_Out,
	Loaded,
}

LOGO_TEXT :: "Odin"
POWERED_BY_TEXT :: "powered by"

animate :: proc(
	fps: i32 = 60,
	background_color: rl.Color = rl.RAYWHITE,
	logo_color: rl.Color = rl.BLACK,
	square_stroke_width: i32 = 16,
	powered_by_custom_font: ^rl.Font = nil,
	powered_by_font_size_factor: f32 = 3,
	powered_by_spacing: f32 = 8,
) {
	// Settings
	square_growth_rate := square_stroke_width / 4
	square_side := square_stroke_width * square_stroke_width
	square_side_no_overlap := square_side - square_stroke_width

	powered_by_font := powered_by_custom_font^ if powered_by_custom_font != nil else rl.GetFontDefault()
	powered_by_font_size := f32(powered_by_font.baseSize) * powered_by_font_size_factor
	powered_by_dimensions := rl.MeasureTextEx(powered_by_font, POWERED_BY_TEXT, powered_by_font_size, powered_by_spacing)

	state := State.Blink
	frames_counter: uint
	top_side: i32 = square_stroke_width
	left_side, bottom_side, right_side: i32
	letters_count: i32
	powered_by_alpha: f32
	alpha: f32 = 1

	// Render textures
	square_rec := rl.LoadRenderTexture(square_side, square_side)
	defer rl.UnloadRenderTexture(square_rec)
	logo_rec := rl.LoadRenderTexture(square_side, square_side)
	defer rl.UnloadRenderTexture(logo_rec)

	// Positioning
	width, height, last_screen_width, last_screen_height: i32
	center: rl.Vector2
	logo_pos: [2]i32
	logo_pos_offset := square_side / 2
	powered_by_pos: rl.Vector2
	powered_by_pos_offset := rl.Vector2{
		powered_by_dimensions.x / 2,
		powered_by_dimensions.y + powered_by_spacing,
	}

	// Camera
	cam := rl.Camera2D{zoom = 1.0}

	rl.SetTargetFPS(fps)

	logo_loop: for !rl.WindowShouldClose() {
		// Skip on Enter or tap
		if rl.IsKeyPressed(.ENTER) || rl.IsGestureDetected(.TAP) {
			state = .Loaded
		}

		switch state {
		case .Blink:
			frames_counter += 1
			if frames_counter == 60 {
				state = .Top_Left_Sides
				frames_counter = 0
			}

		case .Top_Left_Sides:
			top_side += square_growth_rate
			left_side += square_growth_rate
			if top_side == square_side {
				state = .Right_Bottom_Sides
			}

		case .Right_Bottom_Sides:
			right_side += square_growth_rate

			if right_side == square_side_no_overlap {
				state = .Letters

				// Render completed square
				rl.BeginTextureMode(square_rec)
				defer rl.EndTextureMode()

				rl.DrawRectangle(0, 0, top_side, square_stroke_width, logo_color)
				rl.DrawRectangle(0, square_stroke_width, square_stroke_width, left_side, logo_color)
				rl.DrawRectangle(square_side_no_overlap, square_stroke_width, square_stroke_width, right_side, logo_color)
				rl.DrawRectangle(square_stroke_width, square_side_no_overlap, bottom_side, square_stroke_width, logo_color)
			} else {
				bottom_side += square_growth_rate
			}

		case .Letters:
			frames_counter += 1
			if frames_counter == 8 {
				letters_count += 1
				frames_counter = 0
			}

			if letters_count >= 10 {
				state = .Zoom_Out

				// Render completed logo
				rl.BeginTextureMode(logo_rec)
				defer rl.EndTextureMode()

				rl.DrawTextureRec(
					square_rec.texture,
					{0, 0, f32(square_rec.texture.width), -f32(square_rec.texture.height)},
					{0, 0},
					rl.WHITE,
				)
				rl.DrawText(LOGO_TEXT, 84, 176, 50, logo_color)

				// Initialize camera and powered by position for zoom out
				cam.target = center
				cam.offset = center
				powered_by_pos = {
					center.x - powered_by_pos_offset.x,
					f32(logo_pos.y) - powered_by_pos_offset.y,
				}
			}

		case .Zoom_Out:
			cam.zoom -= 0.0025
			if cam.zoom <= 0.85 {
				state = .Fade_Out
			} else {
				powered_by_alpha = min(powered_by_alpha + 0.02, 1)
			}

		case .Fade_Out:
			alpha -= 0.02
			if alpha <= 0 {
				state = .Loaded
			}

		case .Loaded:
		}

		width = rl.GetScreenWidth()
		height = rl.GetScreenHeight()

		// Update positions on screen resize
		if width != last_screen_width || height != last_screen_height {
			center = {f32(width) / 2, f32(height) / 2}
			logo_pos = {i32(center.x) - logo_pos_offset, i32(center.y) - logo_pos_offset}

			// Update camera and powered by position if in zoom/fade states
			if cam.zoom < 1 {
				cam.target = center
				cam.offset = center
				powered_by_pos = {
					center.x - powered_by_pos_offset.x,
					f32(logo_pos.y) - powered_by_pos_offset.y,
				}
			}

			last_screen_width = width
			last_screen_height = height
		}

		rl.BeginDrawing()
		rl.ClearBackground(background_color)

		switch state {
		case .Blink:
			if (frames_counter / 15) % 2 != 0 {
				rl.DrawRectangle(logo_pos.x, logo_pos.y, square_stroke_width, square_stroke_width, logo_color)
			}

		case .Top_Left_Sides:
			rl.DrawRectangle(logo_pos.x, logo_pos.y, top_side, square_stroke_width, logo_color)
			rl.DrawRectangle(logo_pos.x, logo_pos.y + square_stroke_width, square_stroke_width, left_side, logo_color)

		case .Right_Bottom_Sides:
			rl.DrawRectangle(logo_pos.x, logo_pos.y, top_side, square_stroke_width, logo_color)
			rl.DrawRectangle(logo_pos.x, logo_pos.y + square_stroke_width, square_stroke_width, left_side, logo_color)
			rl.DrawRectangle(logo_pos.x + square_side_no_overlap, logo_pos.y + square_stroke_width, square_stroke_width, right_side, logo_color)
			rl.DrawRectangle(logo_pos.x + square_stroke_width, logo_pos.y + square_side_no_overlap, bottom_side, square_stroke_width, logo_color)

		case .Letters:
			rl.DrawTextureRec(
				square_rec.texture,
				{0, 0, f32(square_rec.texture.width), -f32(square_rec.texture.height)},
				{f32(logo_pos.x), f32(logo_pos.y)},
				rl.WHITE,
			)
			rl.DrawText(rl.TextSubtext(LOGO_TEXT, 0, letters_count), logo_pos.x + 84, logo_pos.y + 176, 50, logo_color)

		case .Zoom_Out:
			rl.BeginMode2D(cam)
			defer rl.EndMode2D()

			rl.DrawTextEx(powered_by_font, POWERED_BY_TEXT, powered_by_pos, powered_by_font_size, powered_by_spacing, rl.Fade(logo_color, powered_by_alpha))
			rl.DrawTextureRec(
				logo_rec.texture,
				{0, 0, f32(logo_rec.texture.width), -f32(logo_rec.texture.height)},
				{f32(logo_pos.x), f32(logo_pos.y)},
				rl.WHITE,
			)

		case .Fade_Out:
			rl.BeginMode2D(cam)
			defer rl.EndMode2D()

			rl.DrawTextEx(powered_by_font, POWERED_BY_TEXT, powered_by_pos, powered_by_font_size, powered_by_spacing, rl.Fade(logo_color, alpha))
			rl.DrawTextureRec(
				logo_rec.texture,
				{0, 0, f32(logo_rec.texture.width), -f32(logo_rec.texture.height)},
				{f32(logo_pos.x), f32(logo_pos.y)},
				rl.Fade(rl.WHITE, alpha),
			)

		case .Loaded:
			break logo_loop
		}

		rl.EndDrawing()
	}
}

main :: proc() {
	rl.InitWindow(800, 450, "Logo Animation")
	defer rl.CloseWindow()

	animate()
}
