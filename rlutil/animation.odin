package rlutil

import rl "vendor:raylib"

Animation :: struct {
	texture:       rl.Texture2D,
	frame_width:   f32,
	frame_height:  f32,
	num_frame:     f32,
	frame_time:    f32,
	current_frame: f32,
	elapsed_time:  f32,
	start_frame:   f32,
	end_frame:     f32,
}

create_animation :: proc(
	texture: rl.Texture2D,
	frame_width, frame_height, num_frames: f32,
	frame_time: f32,
	start_frame, end_frame: f32,
) -> ^Animation {
	animation := new(Animation)
	if animation == nil {
		return nil
	}
	animation.texture = texture
	animation.frame_width = frame_width
	animation.frame_height = frame_height
	animation.num_frame = num_frames
	animation.frame_time = frame_time
	animation.current_frame = start_frame
	animation.elapsed_time = 0.0
	animation.start_frame = start_frame
	animation.end_frame = end_frame

	return animation
}

run_animation :: proc(anim: ^Animation, dt: f32, looped: bool) {
	anim.elapsed_time += dt
	if anim.elapsed_time >= anim.frame_time {
		anim.elapsed_time -= anim.frame_time
		anim.current_frame += 1
		if anim.current_frame > anim.end_frame {
			if looped {
				anim.current_frame = anim.start_frame
			} else {
				anim.current_frame = anim.end_frame
			}
		}
	}
}

render_animation :: proc(
	anim: ^Animation,
	dest_x, dest_y: f32,
	rotation: f32,
	flip_x, flip_y: bool,
) {
	source := rl.Rectangle {
		x      = anim.current_frame * anim.frame_width,
		y      = 0,
		width  = anim.frame_width,
		height = anim.frame_height,
	}
	if flip_x {
		source.width *= -1
	} else if flip_y {
		source.height *= -1
	}
	dest := rl.Rectangle {
		x      = dest_x,
		y      = dest_y,
		width  = anim.frame_width,
		height = anim.frame_height,
	}
	rl.DrawTexturePro(
		anim.texture,
		source,
		dest,
		rl.Vector2{0, 0},
		rotation,
		rl.WHITE,
	)
}

reset_animation :: proc(anim: ^Animation) {
	anim.current_frame = anim.start_frame
	anim.elapsed_time = 0.0
}
