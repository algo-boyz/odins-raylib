package main

import rl "vendor:raylib"
import "core:fmt"
import "core:math"
import "core:math/rand"

thrust_force :: 2.5
rotation_speed_val :: 1.0
initial_fuel_consumption :: 10.0
fuel_consumption:f32 = initial_fuel_consumption
COLLISION_SCALE :: 0.8

Lander :: struct {
	pos:           rl.Vector2,
	velocity:      rl.Vector2,
	angle:         f32,
	fuel:          f32,
	landed:        bool,
	crashed:       bool,
	size:          rl.Vector2, // width, height
	landing_pad_x: f32,
	landing_time:  f64,
	crash_pos:     rl.Vector2,

	thrust_music:  rl.Music,
	land_sound:    rl.Sound,
	crash_sound:   rl.Sound,
	was_thrusting: bool,
	was_rotating:  bool,

	terrain:       [^]rl.Vector2, // ptr to first element of terrain points
	terrain_points_count: int,

	texture:       rl.Texture2D,
	flame_texture: rl.Texture2D,
}

init_lander :: proc(screen_width, screen_height: int) -> ^Lander {
    l := new(Lander)

    // --- Step 1: Call LoadMusicStream and store in a local variable ---
    fmt.println("DEBUG: Calling rl.LoadMusicStream for thrust.mp3...")
    temp_thrust_music: rl.Music // Local variable
    temp_thrust_music = rl.LoadMusicStream("assets/thrust.mp3")
    fmt.println("DEBUG: rl.LoadMusicStream call completed.")

    // --- Step 2: Check the local variable directly ---
    // This tests if the struct returned by LoadMusicStream is immediately problematic.
    fmt.println("DEBUG: Attempting to access temp_thrust_music.stream.buffer...")
    // Catch potential panic/segfault here with a separate print
    // (Note: Odin doesn't have try-catch like some languages for segfaults,
    // but this helps isolate if the next line is the one)
    // fmt.printf("DEBUG: temp_thrust_music.stream address: %p\n", &temp_thrust_music.stream) // If this prints, .stream is somewhat accessible
    // fmt.printf("DEBUG: temp_thrust_music.stream.buffer value: %p\n", temp_thrust_music.stream.buffer) // This is the critical read

    // The actual check:
    if temp_thrust_music.stream.buffer == nil {
        fmt.println("DEBUG: temp_thrust_music.stream.buffer IS nil.")
        // This means Raylib indicated failure to load the buffer, even if other logs seemed ok.
        // The game should handle this gracefully (e.g., no thrust sound).
    } else {
        fmt.println("DEBUG: temp_thrust_music.stream.buffer IS NOT nil.")
        fmt.printf("    -> temp_thrust_music.stream.buffer points to: %p\n", temp_thrust_music.stream.buffer)
        fmt.printf("    -> temp_thrust_music.frameCount: %v\n", temp_thrust_music.frameCount)
    }
    fmt.println("DEBUG: Access to temp_thrust_music fields completed.")

    // --- Step 3: Assign to the Lander's field and check again ---
    fmt.println("DEBUG: Assigning temp_thrust_music to l.thrust_music...")
    l.thrust_music = temp_thrust_music
    fmt.println("DEBUG: Assignment to l.thrust_music completed.")

    // --- Step 4: Check the field in the Lander struct ---
    // This tests if the assignment or the Lander struct's field access is the problem.
    fmt.println("DEBUG: Attempting to access l.thrust_music.stream.buffer...")
    if l.thrust_music.stream.buffer == nil { // This was the original crashing line
        fmt.println("DEBUG: l.thrust_music.stream.buffer IS nil.")
    } else {
        fmt.println("DEBUG: l.thrust_music.stream.buffer IS NOT nil.")
        fmt.printf("    -> l.thrust_music.stream.buffer points to: %p\n", l.thrust_music.stream.buffer)
    }
    fmt.println("DEBUG: Access to l.thrust_music fields completed.")

    // Load other assets (these were presumably fine or not reached yet)
    l.land_sound = rl.LoadSound("assets/land.mp3")
    if l.land_sound.stream.buffer == nil {
        when DEBUG { fmt.eprintln("Failed to load land sound: assets/land.mp3") }
    } else {
        when DEBUG { fmt.println("Successfully loaded land sound") }
        rl.SetSoundVolume(l.land_sound, 1.0)
    }

    l.crash_sound = rl.LoadSound("assets/crash.mp3")
    if l.crash_sound.stream.buffer == nil {
        when DEBUG { fmt.eprintln("Failed to load crash sound: assets/crash.mp3") }
    } else {
        when DEBUG { fmt.println("Successfully loaded crash sound") }
        rl.SetSoundVolume(l.crash_sound, 0.33)
    }

    // Set volume and looping for thrust_music only if it was successfully loaded and buffer is not nil
    if l.thrust_music.stream.buffer != nil {
        rl.SetMusicVolume(l.thrust_music, 0.33)
        l.thrust_music.looping = true
    } else {
        when DEBUG { fmt.eprintln("Skipping SetMusicVolume/looping for thrust_music as buffer is nil.")}
    }


	l.texture = rl.LoadTexture("assets/lander.png")
	if l.texture.id == 0 {
		when DEBUG {
			fmt.eprintln("Failed to load lander texture: assets/lander.png")
		}
	} else {
		when DEBUG {
			fmt.println("Successfully loaded lander texture")
		}
	}

	l.flame_texture = rl.LoadTexture("assets/blueflame.png")
	if l.flame_texture.id == 0 {
		when DEBUG {
			fmt.eprintln("Failed to load flame texture: assets/blueflame.png")
		}
	} else {
		when DEBUG {
			fmt.println("Successfully loaded flame texture")
		}
	}
	
    l.was_thrusting = false
    l.was_rotating = false
    reset(l, screen_width, screen_height)
    return l
}

reset :: proc(l: ^Lander, screen_width, screen_height: int) {
	l.pos.x = f32(screen_width) / 2.0
	l.pos.y = 50.0
	l.velocity.x = 0.0
	l.velocity.y = 0.0
	l.angle = 0.0
	l.fuel = 100.0
	l.landed = false
	l.crashed = false
	l.crash_pos = {0,0}

	l.size.y = 60.0 // height

	if l.texture.id != 0 {
		l.size.x = l.size.y * (f32(l.texture.width) / f32(l.texture.height))
	} else {
		l.size.x = 20.0 // width
	}

	l.landing_pad_x = 100.0 + rand.float32() * (f32(screen_width) - 200.0)
	l.landing_time = 0.0
	rl.StopMusicStream(l.thrust_music)
	l.was_thrusting = false
	l.was_rotating = false
}

set_terrain_reference :: proc(l: ^Lander, terrain_ptr: [^]rl.Vector2, num_points: int) {
	l.terrain = terrain_ptr
	l.terrain_points_count = num_points
}

update :: proc(l: ^Lander, dt: f32, thrusting_input, rotating_left_input, rotating_right_input: bool) {
	if l.landed || l.crashed {
		return
	}

	l.velocity.y += current_gravity * dt
	is_rotating := (rotating_left_input || rotating_right_input) && l.fuel > 0
	should_play_thrust_sound := (thrusting_input || is_rotating) && l.fuel > 0

	if thrusting_input && l.fuel > 0 {
		angle_rad := l.angle * rl.DEG2RAD
		l.velocity.x += math.sin(angle_rad) * thrust_force * dt
		l.velocity.y -= math.cos(angle_rad) * thrust_force * dt
		l.fuel = max(0.0, l.fuel - fuel_consumption * dt)
	}

	if is_rotating {
		if rotating_left_input {
			l.angle = math.mod_f32(l.angle + rotation_speed_val, 360.0)
		}
		if rotating_right_input {
			l.angle = math.mod_f32(l.angle - rotation_speed_val, 360.0)
            // Ensure positive modulo result, fmod can be negative
            if l.angle < 0 { l.angle += 360 } 
		}
		l.fuel = max(0.0, l.fuel - (fuel_consumption * 0.5 * dt))
	}
	if should_play_thrust_sound {
		if !l.was_thrusting && !l.was_rotating {
			rl.PlayMusicStream(l.thrust_music)
			when DEBUG { fmt.println("Started playing thrust music") }
		} else {
			rl.ResumeMusicStream(l.thrust_music)
		}
		rl.UpdateMusicStream(l.thrust_music)
		l.was_thrusting = true
		l.was_rotating = true
	} else if l.was_thrusting || l.was_rotating {
		rl.PauseMusicStream(l.thrust_music)
		l.was_thrusting = false
		l.was_rotating = false
		when DEBUG { fmt.println("Paused thrust music") }
	}
	l.pos.x += l.velocity.x
	l.pos.y += l.velocity.y

	// Screen bounds
	l.pos.x = max(0.0, min(f32(screen_width) - l.size.x, l.pos.x))
	if l.pos.y < 0.0 {
		l.pos.y = 0.0
		l.velocity.y = 0.0
	}

	// Collision
	scaled_width := l.size.x * COLLISION_SCALE
	scaled_height := l.size.y * COLLISION_SCALE

	// Collision rectangle is centered on lander's main rectangle
	collision_rect_pos_x := l.pos.x + (l.size.x - scaled_width) / 2 // Center scaled rect
	collision_rect_pos_y := l.pos.y + (l.size.y - scaled_height) / 2

	// Collision rectangle starts at the lander's top-left (l.pos) but scaled
	collision_rect := rl.Rectangle{l.pos.x, l.pos.y, scaled_width, scaled_height}
    collision_bottom := collision_rect.y + collision_rect.height
    center_x := collision_rect.x + collision_rect.width / 2.0
    center_y := collision_rect.y + collision_rect.height / 2.0

	if l.terrain != nil && l.terrain_points_count > 1 {
		for i := 0; i < l.terrain_points_count - 1; i += 1 {
			p1 := l.terrain[i]
			p2 := l.terrain[i+1]

			if center_x >= p1.x && center_x <= p2.x {
				t_param := (center_x - p1.x) / (p2.x - p1.x)
				terrain_height_at_center_x := p1.y * (1 - t_param) + p2.y * t_param

				if collision_bottom >= terrain_height_at_center_x {
					// Collision occurred
					on_landing_pad := abs(center_x - l.landing_pad_x) <= 50.0
					correct_pad_height := abs(terrain_height_at_center_x - (f32(screen_height) - 50.0)) < 1.0 // pad is at y = gameScreenHeight - 50
					safe_velocity_x := abs(l.velocity.x) < current_velocity_limit
					safe_velocity_y := abs(l.velocity.y) < current_velocity_limit
					
					// Normalized angle for landing check
                    // For 0 degrees (upright), it means 0. For 350 degrees (-10), it's -10. For 10 degrees, it's 10.
					normalized_angle := l.angle
                    if normalized_angle > 180 { normalized_angle -= 360 } // Quick way to get to [-180, 180] if angle is [0, 360)

					safe_angle := abs(normalized_angle) < 15.0

					if on_landing_pad && correct_pad_height && safe_velocity_x && safe_velocity_y && safe_angle {
						l.landed = true
						l.landing_time = rl.GetTime()
						rl.StopMusicStream(l.thrust_music)
						if l.land_sound.stream.buffer != nil { rl.PlaySound(l.land_sound) }
						when DEBUG { fmt.println("Land sound played") }
						l.was_thrusting = false // Reset sound flags
						l.was_rotating = false
					} else {
						l.crashed = true
						rl.StopMusicStream(l.thrust_music)
						if l.crash_sound.stream.buffer != nil { rl.PlaySound(l.crash_sound) }
						when DEBUG {
							reason := ""
							if !on_landing_pad { reason = "missed pad" }
							else if !correct_pad_height { reason = "wrong pad height (terrain error)"}
							else if !safe_velocity_x { reason = "too fast X" }
							else if !safe_velocity_y { reason = "too fast Y" }
							else if !safe_angle { reason = "bad angle" }
							else { reason = "hit terrain" }
							fmt.printf("Crash sound played - %s\n", reason)
						}
						l.crash_pos.x = center_x
						l.crash_pos.y = center_y
						l.was_thrusting = false
						l.was_rotating = false
					}
                    // Adjust lander Y position post-collision
					l.pos.y = terrain_height_at_center_x - scaled_height
					break // Collision handled
				}
			}
		}
	}
}

draw :: proc(l: ^Lander) {
	if l.crashed {
		// Lander itself doesn't draw if crashed. Game's DrawExplosion will handle visuals.
		return
	}
	if l.texture.id == 0 { return }


	source_rect := rl.Rectangle{0, 0, f32(l.texture.width), f32(l.texture.height)}
	// Destination rect: x, y is center for DrawTexturePro with origin at center
	dest_rect := rl.Rectangle{l.pos.x + l.size.x / 2, l.pos.y + l.size.y / 2, l.size.x, l.size.y}
	origin := rl.Vector2{l.size.x / 2, l.size.y / 2}
	rl.DrawTexturePro(l.texture, source_rect, dest_rect, origin, l.angle, rl.WHITE)

	// Draw flame if thrusting and has fuel
	if !l.crashed && (l.was_thrusting || l.was_rotating) && l.fuel > 0 && l.flame_texture.id != 0 {
		flame_height_ratio :: 0.4
		flame_height := l.size.y * flame_height_ratio
		aspect_ratio := f32(l.flame_texture.width) / f32(l.flame_texture.height)
		flame_width := flame_height * aspect_ratio
		
		lander_center := rl.Vector2{l.pos.x + l.size.x / 2, l.pos.y + l.size.y / 2}

		// Flame offset calculation
		flame_offset_val :: 10.0
		offset_distance := -l.size.y/2.0 + flame_offset_val // Relative to lander's origin (center)

		angle_rad := l.angle * rl.DEG2RAD
		// Flame position needs to be rotated around lander's origin
		// This positions the *top-center* of the flame. The origin for DrawTexturePro needs to be flameWidth/2, 0
		flame_pos_x := lander_center.x + math.sin(angle_rad) * offset_distance
		flame_pos_y := lander_center.y - math.cos(angle_rad) * offset_distance
		
		flame_source_rect := rl.Rectangle{0, 0, f32(l.flame_texture.width), f32(l.flame_texture.height)}
		// flameDest for DrawTexturePro takes center of rotation. If origin is top-center of flame,
		// then flame_pos_x, flame_pos_y are the coordinates for this origin.
		flame_dest_rect := rl.Rectangle{flame_pos_x, flame_pos_y, flame_width, flame_height}
		flame_origin := rl.Vector2{flame_width / 2, 0} // Rotate around top-center of flame sprite

		rl.DrawTexturePro(l.flame_texture, flame_source_rect, flame_dest_rect, flame_origin, l.angle, rl.WHITE)
	}
}

cleanup :: proc(l: ^Lander) {
	rl.UnloadMusicStream(l.thrust_music)
	if l.land_sound.stream.buffer != nil { rl.UnloadSound(l.land_sound) }
	if l.crash_sound.stream.buffer != nil { rl.UnloadSound(l.crash_sound) }
	if l.texture.id != 0 { rl.UnloadTexture(l.texture) }
	if l.flame_texture.id != 0 { rl.UnloadTexture(l.flame_texture) }
	// 'l' will be freed by whoever allocated it
}

get_fuel :: proc(l: ^Lander) -> f32 { return l.fuel }
get_velocity_x :: proc(l: ^Lander) -> f32 { return l.velocity.x }
get_velocity_y :: proc(l: ^Lander) -> f32 { return l.velocity.y }
get_angle :: proc(l: ^Lander) -> f32 { return l.angle }
get_landing_pad_x :: proc(l: ^Lander) -> f32 { return l.landing_pad_x }
get_landing_time :: proc(l: ^Lander) -> f64 { return l.landing_time }
get_x :: proc(l: ^Lander) -> f32 { return l.pos.x }
get_y :: proc(l: ^Lander) -> f32 { return l.pos.y }
get_width :: proc(l: ^Lander) -> f32 { return l.size.x }
get_height :: proc(l: ^Lander) -> f32 { return l.size.y }
get_crash_pos_x :: proc(l: ^Lander) -> f32 { return l.crash_pos.x }
get_crash_pos_y :: proc(l: ^Lander) -> f32 { return l.crash_pos.y }
is_landed :: proc(l: ^Lander) -> bool { return l.landed }
is_crashed :: proc(l: ^Lander) -> bool { return l.crashed }