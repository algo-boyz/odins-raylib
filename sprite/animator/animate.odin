package animator

import rl "vendor:raylib"

// Animator for Raylib is a simple tool used to animate sprite-sheets.
Animator :: struct {
    name: string,
    sprite: rl.Texture2D,
    frame_rec: rl.Rectangle,
    
    framerate: u32,
    columns: u32,
    rows: u32,
    
    frame_width: f32,
    frame_height: f32,
    
    playback_position: u32,
    current_frame: u32,
    current_row: u32,
    current_column: u32,
    
    time_remaining_frames_counter: f32,
    delay_frames_counter: u32,
    
    flip_h: bool,
    flip_v: bool,
    reverse: bool,
    can_loop: bool,
    continuous: bool,
    paused: bool,
    has_started_playing: bool,
    is_animation_finished: bool,
}

/// <summary>Creates an animator instance.</summary>
/// <param name="AnimatorName">A name the animator will be identified by.</param>
/// <param name="NumOfFramesPerRow">The amount of frames/columns in a row.</param>
/// <param name="NumOfRows">The amount of rows in the sprite sheet.</param>
/// <param name="Speed">The animation speed in frames per second.</param>
/// <param name="bPlayInReverse">Should the animator play the sprite in reverse play mode?</param>
/// <param name="bContinuous">Should the animator automatically go to the next row in the sprite sheet?</param>
/// <param name="bLooping">Should the animator loop indefinitely?</param>
new_animator :: proc(animator_name: string, frames_per_row: u32, num_rows: u32, speed: u32, play_in_reverse: bool, continuous: bool, looping: bool) -> Animator {
    return Animator{
        name = animator_name,
        framerate = max(speed, 1),
        columns = frames_per_row,
        rows = max(num_rows, 1),
        reverse = play_in_reverse,
        can_loop = looping,
        continuous = continuous,
    }
}

/// <summary>Assigns a sprite for the animator to use. (This should be called once)</summary>
/// <param name="Sprite">The sprite the animator will use.</param>
assign_sprite :: proc(using animator: ^Animator, texture: rl.Texture2D) {
    animator.sprite = texture
    restart(animator)
}

/// <summary>Changes the sprite the animator is using.</summary>
/// <param name="NewSprite">The new sprite the animator will change to. Will reset to beginning frame.</param>
/// <param name="NumOfFramesPerRow">The amount of frames/columns in a row.</param>
/// <param name="NumOfRows">The amount of rows in the sprite sheet.</param>
/// <param name="Speed">The animation speed in frames per second.</param>
/// <param name="DelayInSeconds">The amount of time (in seconds) to change to the new sprite. A value of 0.0f is instant/no delay.</param>
/// <param name="bPlayInReverse">Should the animator play the new sprite in reverse play mode?</param>
/// <param name="bContinuous">Should the animator automatically go to the next row in the sprite sheet?</param>
/// <param name="bLooping">Should the animator loop indefinitely?</param>
reset_frame_rec :: proc(using animator: ^Animator) {
    frame_rec.width = flip_h ? -f32(sprite.width) / f32(columns) : f32(sprite.width) / f32(columns)
    frame_rec.height = flip_v ? -f32(sprite.height) / f32(rows) : f32(sprite.height) / f32(rows)
    frame_width = frame_rec.width
    frame_height = frame_rec.height
    frame_rec.x = reverse && continuous ? f32(sprite.width) - frame_width : 0
    frame_rec.y = reverse && continuous ? f32(sprite.height) - frame_height : 0
    
    current_frame = reverse ? columns - 1 : 0
    current_row = reverse ? rows - 1 : 0
    current_column = reverse ? columns - 1 : 0
}

next_row :: proc(using animator: ^Animator) {
    frame_rec.y += frame_height
    
    if frame_rec.y >= f32(sprite.height) {
        if can_loop {
            frame_rec.y = 0
            current_row = 0
        } else {
            frame_rec.y = f32(sprite.height)
            current_row = rows - 1
        }
        reset_timer(animator)
    } else {
        current_row += 1
    }
    
    time_remaining_frames_counter = f32(get_total_time_in_frames(animator)) - 
        (f32(get_total_time_in_frames(animator)) / f32(rows)) * f32(current_row)
}

previous_row :: proc(using animator: ^Animator) {
    frame_rec.y -= frame_height
    
    if frame_rec.y < 0 {
        frame_rec.y = f32(sprite.height) - frame_height
        current_row = rows - 1
        reset_timer(animator)
    } else {
        current_row -= 1
    }
    
    if !reverse {
        time_remaining_frames_counter = f32(get_total_time_in_frames(animator)) - 
            (f32(get_total_time_in_frames(animator)) / f32(rows)) * f32(current_row)
    }
}

previous_frame :: proc(using animator: ^Animator) {
    if !is_animation_finished {
        current_frame -= 1
        current_column -= 1
    }
    
    if can_loop {
        if current_frame == 0 || current_frame > columns {
            if continuous {
                previous_row(animator)
                go_to_column(animator, columns - 1)
            } else {
                go_to_column(animator, columns - 1)
            }
        }
    } else {
        if current_frame == 0 || current_frame > columns {
            if continuous {
                current_frame = 0
                current_column = 0
                
                if !is_at_first_frame(animator) {
                    previous_row(animator)
                    go_to_column(animator, columns - 1)
                } else {
                    is_animation_finished = true
                }
            } else {
                is_animation_finished = true
                go_to_column(animator, 0)
            }
        }
    }
}

/// <summary>Flips the sprite-sheet horizontally or vertically, or both.</summary>
/// <param name="bHorizontalFlip">Flips the sprite sheet horizontally. DOES NOT WORK, set this to false.</param>
/// <param name="bVerticalFlip">Flips the sprite sheet vertically.</param>
flip_sprite :: proc(using animator: ^Animator, horizontal_flip: bool, vertical_flip: bool) {
    flip_h = horizontal_flip
    flip_v = !flip_v
    
    if horizontal_flip && vertical_flip {
        frame_rec.width *= -1
        frame_rec.height *= -1
    } else if horizontal_flip {
        frame_rec.width *= -1
    } else if vertical_flip {
        frame_rec.height *= -1
    }
}

	// /// <summary>Set whether the animator should loop or not.</summary>
	// /// <param name="bLooping">Should the animator loop?</param>
	// void SetLooping(bool bLooping);

	// /// <summary>Set whether the animator should go to the next row in the sprite sheet or not.</summary>
	// /// <param name="bIsContinuous">Should the animator continue to the next row?</param>
	// void SetContinuous(bool bIsContinuous);

	// /// <summary>Set a new framerate the animator will use.</summary>
	// /// <param name="NewFramerate">The new speed of animation.</param>
	// void SetFramerate(unsigned int NewFramerate);

	// /// <summary>Jump to a frame in the sprite-sheet.</summary>
	// /// <param name="FrameNumber">The frame number in the sprite sheet. (Zero-based)</param>
	// void GoToFrame(unsigned int FrameNumber);

/// <summary>Jump to a row in the sprite-sheet.</summary>
/// <param name="RowNumber">The row number in the sprite sheet. (Zero-based)</param>
go_to_row :: proc(using animator: ^Animator, row_number: u32) {
    if row_number >= rows {
        frame_rec.y = f32(rows - 1) * frame_height
        current_row = rows - 1
        time_remaining_frames_counter = f32(get_total_time_in_frames(animator))
    } else if rows >= 1 {
        frame_rec.y = row_number == 0 ? 0 : f32(row_number) * frame_height
        current_row = row_number
        time_remaining_frames_counter = f32(get_total_time_in_frames(animator) - (row_number * columns + columns))
    }
}

/// <summary>Jump to a column in the current row.</summary>
/// <param name="ColumnNumber">The column number in the sprite sheet. (Zero-based)</param>
go_to_column :: proc(using animator: ^Animator, column_number: u32) {
    if column_number >= columns {
        frame_rec.x = f32(columns - 1) * frame_width
        current_column = columns - 1
        current_frame = columns - 1
        time_remaining_frames_counter = f32(get_total_time_in_frames(animator)) - f32(current_row * columns)
    } else if columns >= 1 {
        frame_rec.x = column_number == 0 ? 0 : f32(column_number) * frame_width
        current_column = column_number
        current_frame = column_number
        time_remaining_frames_counter = f32(get_total_time_in_frames(animator)) - f32(current_row * columns) - f32(column_number)
    }
}

next_frame :: proc(using animator: ^Animator) {
    if !is_animation_finished {
        current_frame += 1
        current_column += 1
    }
    
    if can_loop {
        if current_frame > columns - 1 {
            if continuous {
                next_row(animator)
                go_to_column(animator, 0)
            } else {
                go_to_column(animator, 0)
            }
        }
    } else {
        if current_frame > columns - 1 {
            if continuous {
                current_frame = columns - 1
                current_column = columns - 1
                
                if !is_at_last_frame(animator) {
                    next_row(animator)
                    go_to_column(animator, 0)
                } else {
                    is_animation_finished = true
                }
            } else {
                is_animation_finished = true
                go_to_column(animator, columns - 1)
            }
        }
    }
}

play :: proc(using animator: ^Animator) {
    if !paused {
        playback_position += 1
        
        if !is_animation_finished {
            countdown_in_frames(animator)
        }
        
        if playback_position > u32(rl.GetFPS()) / framerate {
            playback_position = 0
            
            if reverse {
                previous_frame(animator)
            } else {
                next_frame(animator)
            }
        }
        
        if !is_animation_finished {
            frame_rec.x = f32(current_frame) * frame_width
        }
        
        has_started_playing = false
    }
}

start :: proc(using animator: ^Animator) {
    unpause(animator)
    if !has_started_playing {
        has_started_playing = true
    }
}

stop :: proc(using animator: ^Animator) {
    playback_position = 0
    current_column = 0
    current_frame = 0
    current_row = 0
    has_started_playing = true
    is_animation_finished = true
    
    reset_frame_rec(animator)
    reset_timer(animator)
    pause(animator)
}

pause :: proc(using animator: ^Animator, toggle := false) {
    if toggle {
        paused = !paused
        has_started_playing = !paused
    } else {
        paused = true
        has_started_playing = false
    }
}

unpause :: proc(using animator: ^Animator) {
    paused = false
    has_started_playing = true
}

// Helper functions
is_at_first_frame :: proc(using animator: ^Animator) -> bool {
    return continuous ? is_at_first_row(animator) && is_at_first_column(animator) : is_at_first_column(animator)
}

is_at_last_frame :: proc(using animator: ^Animator) -> bool {
    return continuous ? is_at_last_row(animator) && is_at_last_column(animator) : is_at_last_column(animator)
}

is_at_first_row :: proc(using animator: ^Animator) -> bool {
    return current_row == 0
}

is_at_last_row :: proc(using animator: ^Animator) -> bool {
    return current_row == rows - 1
}

is_at_first_column :: proc(using animator: ^Animator) -> bool {
    return current_column == 0
}

is_at_last_column :: proc(using animator: ^Animator) -> bool {
    return current_column == columns - 1
}

get_total_time_in_frames :: proc(using animator: ^Animator) -> u32 {
    return continuous ? columns * rows : columns
}

countdown_in_frames :: proc(using animator: ^Animator) {
    if time_remaining_frames_counter != 0 {
        time_remaining_frames_counter -= rl.GetFrameTime() < 0.01 ? f32(framerate) * rl.GetFrameTime() : 0
    }
    
    if time_remaining_frames_counter <= 0 {
        time_remaining_frames_counter = 0
    }
}

reset_timer :: proc(using animator: ^Animator) {
    time_remaining_frames_counter = f32(get_total_time_in_frames(animator))
}

restart :: proc(using animator: ^Animator) {
    reset_frame_rec(animator)
    reset_timer(animator)
    has_started_playing = true
}