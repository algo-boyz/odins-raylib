package texture

import rl "vendor:raylib"

// Draw background with texture over full width and height of screen
draw :: proc(bg: Background, width, height: i32) {
    if !bg.loaded do return
    
    dest_rect := rl.Rectangle{0, 0, f32(width), f32(height)}
    src_rect := rl.Rectangle{0, 0, f32(bg.texture.width), f32(bg.texture.height)}
    rl.DrawTexturePro(bg.texture, src_rect, dest_rect, {0, 0}, 0, rl.WHITE)
}

// Render text at specified position with optional rotation and flipping
render :: proc(tex: rl.Texture2D, tex_x, tex_y, rotation: f32, flip_x, flip_y: bool) {
	origin_x := f32(tex.width) / 2
	origin_y := f32(tex.height) / 2
	scale_x: f32
	if flip_x {
		scale_x = -1.0
	} else {
		scale_x = 1.0
	}
	scale_y: f32
	if flip_y {
		scale_y = -1.0
	} else {
		scale_y = 1.0
	}
	rl.DrawTexturePro(
		tex,
		rl.Rectangle{0, 0, f32(tex.width), f32(tex.height)}, // Source entire texture
		rl.Rectangle {
			tex_x,
			tex_y,
			f32(tex.width) * scale_x,
			f32(tex.height) * scale_y,
		}, // Destination
		rl.Vector2{origin_x, origin_y}, // Rotate around center of texture
		rotation,
		rl.WHITE,
	)
}

render_sub_texture :: proc(tex: rl.Texture2D, src_rect, dest_rect: rl.Rectangle, rotation: f32, flip_x, flip_y: bool) {
	origin_x := f32(tex.width) / 2
	origin_y := f32(tex.height) / 2
	scale_x: f32
	if flip_x {
		scale_x = -1.0
	} else {
		scale_x = 1.0
	}
	scale_y: f32
	if flip_y {
		scale_y = -1.0
	} else {
		scale_y = 1.0
	}
	rl.DrawTexturePro(
		tex,
		src_rect,
		dest_rect,
		rl.Vector2{origin_x, origin_y},
		rotation,
		rl.WHITE,
	)
}
