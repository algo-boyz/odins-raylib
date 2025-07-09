package main

import rl "vendor:raylib"
import "core:fmt"
import "core:math"
import "core:math/rand"
import "core:strings"


current_gravity:f32= INITIAL_GRAVITY
max_gravity_reached := false
current_velocity_limit:f32 = INITIAL_VELOCITY_LIMIT

// Constants from Game class
GRAVITY_INCREASE :: 0.15
FUEL_CONSUMPTION_INCREASE :: 1.0
EXPLOSION_SCALE :: 1.0
EXPLOSION_PLAYBACK_SPEED :: 4 // frames delay
EXPLOSION_FRAMES_PER_LINE :: 5
EXPLOSION_LINES :: 5
TERRAIN_POINTS_COUNT :: 40

MIN_TERRAIN_HEIGHT_FROM_BOTTOM :: 250 // gameScreenHeight - minTerrainHeight from C++
MAX_TERRAIN_HEIGHT_FROM_BOTTOM :: 50  // gameScreenHeight - maxTerrainHeight from C++

Game :: struct {
	start_time:        bool,
	is_exit_menu:      bool,
	lost_window_focus: bool,
	game_over:         bool,
	game_won:          bool,
	playing_music:     bool,

	screen_scale:      f32,
	target_render_tex: rl.RenderTexture2D,
	font:              rl.Font,

	lives:             int,
	level:             int,
	input_delay:       f64,

	player_lander:     ^Lander,

	bg_music:          rl.Music,
	music_started:     bool,

	// --- Starfield replaces bg_texture ---
	starfield:         ^Starfield,

	terrain_texture:     rl.Texture2D,
	explosion_texture:   rl.Texture2D,

	explosion_active:         bool,
	explosion_completed:      bool,
	explosion_frames_counter: int,
	explosion_current_frame:  int,
	explosion_current_line:   int,
	explosion_frame_rec:      rl.Rectangle,
	explosion_pos:            rl.Vector2,

	terrain_points: [TERRAIN_POINTS_COUNT]rl.Vector2,

	thrust_timeout: f64,
}

init_game :: proc(game_width, game_height: int) -> ^Game {
	g := new(Game)
	g.start_time = true
	g.music_started = false
	g.explosion_active = false
	g.explosion_completed = false
	g.explosion_frames_counter = 0
	g.explosion_current_frame = 0
	g.explosion_current_line = 0
	g.explosion_pos = {0, 0}
	g.game_won = false
	g.thrust_timeout = 0.1

	g.target_render_tex = rl.LoadRenderTexture(screen_width, screen_height)
	rl.SetTextureFilter(g.target_render_tex.texture, .BILINEAR)

	g.font = rl.LoadFontEx("assets/OpenSansRegular.ttf", 64, nil, 0)

	g.bg_music = rl.LoadMusicStream("assets/music.mp3")
	rl.SetMusicVolume(g.bg_music, MUSIC_VOLUME)

	// --- Initialize Starfield instead of loading a background texture ---
	g.starfield = init_starfield(game_width, game_height)

	g.terrain_texture = rl.LoadTexture("assets/moon_surface.png")
	if g.terrain_texture.id != 0 {
		rl.SetTextureWrap(g.terrain_texture, .REPEAT)
	}
	g.explosion_texture = rl.LoadTexture("assets/explosion.png")
	if g.explosion_texture.id != 0 {
		frame_w := f32(g.explosion_texture.width / EXPLOSION_FRAMES_PER_LINE)
		frame_h := f32(g.explosion_texture.height / EXPLOSION_LINES)
		g.explosion_frame_rec = rl.Rectangle{0, 0, frame_w, frame_h}
	}
	g.playing_music = false
	init_game_state(g)
	return g
}

init_game_state :: proc(g: ^Game) {
	g.is_exit_menu = false
	g.lost_window_focus = false
	g.game_over = false
	g.game_won = false
	g.explosion_completed = false

	g.screen_scale = min(f32(rl.GetScreenWidth()) / f32(screen_width), 
	                                f32(rl.GetScreenHeight()) / f32(screen_height))

	g.lives = 3
	g.level = 1
	g.input_delay = 0.3
	g.playing_music = true

	g.player_lander = init_lander(screen_width, screen_height)
	randomize_starfield_movement(g.starfield, g.level)
	randomize_terrain(g) // Generates terrain and sets player_landing_pad_x
	set_terrain_reference(g.player_lander, &g.terrain_points[0], TERRAIN_POINTS_COUNT)

	// Reset global game parameters tied to levels
	current_gravity = INITIAL_GRAVITY
	max_gravity_reached = false
	current_velocity_limit = INITIAL_VELOCITY_LIMIT
	fuel_consumption = initial_fuel_consumption
}

reset_game :: proc(g: ^Game) {
	g.lives = 3
	g.level = 1
	current_gravity = INITIAL_GRAVITY
	max_gravity_reached = false
	current_velocity_limit = INITIAL_VELOCITY_LIMIT
	fuel_consumption = initial_fuel_consumption
	
	g.explosion_completed = false
	g.game_won = false
	g.game_over = false
	g.playing_music = true

	reset(g.player_lander, screen_width, screen_height)
    randomize_starfield_movement(g.starfield, g.level)
	randomize_terrain(g) // Will also update lander's landing_pad_x
	set_terrain_reference(g.player_lander, &g.terrain_points[0], TERRAIN_POINTS_COUNT)
}


game_update :: proc(g: ^Game, dt: f32) {
	if dt == 0 { return }

	g.screen_scale = min(f32(rl.GetScreenWidth()) / f32(screen_width), f32(rl.GetScreenHeight()) / f32(screen_height))
	update_ui_state(g)

	running := !g.start_time && !g.lost_window_focus && !g.is_exit_menu && !g.game_over && !g.game_won

	if !g.start_time && !g.music_started && g.playing_music {
		fmt.println("Start background music")
		rl.PlayMusicStream(g.bg_music)
		g.music_started = true
		when DEBUG { fmt.println("Started background music") }
	}

	if g.music_started && g.playing_music {
		rl.UpdateMusicStream(g.bg_music)
		if g.lost_window_focus || g.is_exit_menu || g.game_over || g.game_won {
			rl.PauseMusicStream(g.bg_music)
		} else {
			rl.ResumeMusicStream(g.bg_music)
		}
	}

	if running {
		// --- Update starfield every frame ---
		update_starfield(g)

		// Optional: Add a key to toggle star colors, for example 'C'
		if rl.IsKeyPressed(.C) {
			g.starfield.colors_on = !g.starfield.colors_on
		}

		thrusting_input, rotating_left_input, rotating_right_input: bool

		thrusting_input = rl.IsKeyDown(.UP) || rl.IsKeyDown(.W)
		rotating_left_input = rl.IsKeyDown(.RIGHT) || rl.IsKeyDown(.D)
		rotating_right_input = rl.IsKeyDown(.LEFT) || rl.IsKeyDown(.A)

		if rl.IsKeyPressed(.M) {
			g.playing_music = !g.playing_music
			if g.playing_music {
				if g.music_started { rl.ResumeMusicStream(g.bg_music) } else { rl.PlayMusicStream(g.bg_music); g.music_started = true }
			} else {
				rl.PauseMusicStream(g.bg_music)
			}
		}

		update(g.player_lander, dt, thrusting_input, rotating_left_input, rotating_right_input)


		if is_landed(g.player_lander) || is_crashed(g.player_lander) {
			if is_crashed(g.player_lander) {
				if !g.explosion_active && !g.explosion_completed {
					start_explosion(g, get_crash_pos_x(g.player_lander), get_crash_pos_y(g.player_lander))
				}
				g.explosion_completed = true; // Prevent re-processing after crash action

				if g.lives <= 1 {
					g.game_over = true
				} else {
					g.lives -= 1
					reset(g.player_lander, screen_width, screen_height)
					randomize_terrain(g)
					set_terrain_reference(g.player_lander, &g.terrain_points[0], TERRAIN_POINTS_COUNT)
					g.explosion_completed = false // Reset for next attempt
				}
			// Landed successfully
			} else if is_landed(g.player_lander) {
				// Proceed to next level on Enter
				proceed_action := rl.IsKeyPressed(.ENTER)
				if rl.GetTime() - get_landing_time(g.player_lander) > g.input_delay && proceed_action {
					win_level := 15
					if g.level >= win_level {
						g.game_won = true
						return
					}
					// Advance level
					current_gravity += GRAVITY_INCREASE
					if current_gravity > MAX_GRAVITY {
						current_gravity = MAX_GRAVITY
						max_gravity_reached = true
					}
					if max_gravity_reached {
						fuel_consumption += FUEL_CONSUMPTION_INCREASE
						if fuel_consumption > MAX_FUEL_CONSUMPTION {
							fuel_consumption = MAX_FUEL_CONSUMPTION
						}
					}
					g.level += 1
					reset(g.player_lander, screen_width, screen_height)
					randomize_starfield_movement(g.starfield, g.level)
					randomize_terrain(g)
					set_terrain_reference(g.player_lander, &g.terrain_points[0], TERRAIN_POINTS_COUNT)
				}
			}
		}
	}
}

update_ui_state :: proc(g: ^Game) {
	if rl.WindowShouldClose() || (rl.IsKeyPressed(.ESCAPE) && !exit_requested) {
		exit_requested = true
		g.is_exit_menu = true
		return
	}
	if rl.IsKeyPressed(.ENTER) && (rl.IsKeyDown(.LEFT_ALT) || rl.IsKeyDown(.RIGHT_ALT)) {
		if rl.IsWindowFullscreen() {
			rl.ToggleFullscreen()
			// Restore original window size if needed after exiting fullscreen
			// rl.SetWindowSize(window_width, window_height) 
		} else {
			// Set to monitor size before toggling
			// monitor := rl.GetCurrentMonitor()
			// rl.SetWindowSize(rl.GetMonitorWidth(monitor), rl.GetMonitorHeight(monitor))
			rl.ToggleFullscreen() // Enter fullscreen
		}
	}
	if g.start_time {
		if rl.IsKeyPressed(.ENTER) || rl.IsKeyPressed(.KP_ENTER) { g.start_time = false }
	}
	if exit_requested {
		if rl.IsKeyPressed(.Y) {
			exit_window = true
		} else if rl.IsKeyPressed(.N) || rl.IsKeyPressed(.ESCAPE) {
			exit_requested = false
			g.is_exit_menu = false
		}
	}
	g.lost_window_focus = !rl.IsWindowFocused()

	if rl.IsKeyPressed(.ENTER) {
		if g.game_won || g.game_over {
			reset_game(g)
		}
	}
}

game_draw :: proc(g: ^Game) {
	rl.BeginTextureMode(g.target_render_tex)
	rl.ClearBackground(black)

	// --- Draw the dynamic starfield background ---
	draw_starfield(g)

	draw_terrain(g)
	draw(g.player_lander)
	draw_explosion(g)
	draw_ui_elements(g)

	rl.EndTextureMode()

	rl.BeginDrawing()
	rl.ClearBackground(black)
	render_tex_src := rl.Rectangle{0, 0, f32(g.target_render_tex.texture.width), -f32(g.target_render_tex.texture.height)}
	render_tex_dest := rl.Rectangle{
		(f32(rl.GetScreenWidth()) - (f32(screen_width) * g.screen_scale)) * 0.5,
		(f32(rl.GetScreenHeight()) - (f32(screen_height) * g.screen_scale)) * 0.5,
		f32(screen_width) * g.screen_scale,
		f32(screen_height) * g.screen_scale,
	}
	rl.DrawTexturePro(g.target_render_tex.texture, render_tex_src, render_tex_dest, {0, 0}, 0.0, rl.WHITE)
	rl.EndDrawing()
}
SUBDIVISIONS :: 20

draw_terrain :: proc(g: ^Game) {
    if g.terrain_texture.id == 0 { // Fallback if no texture
        for i := 0; i < TERRAIN_POINTS_COUNT - 1; i += 1 {
            p1 := g.terrain_points[i]
            p2 := g.terrain_points[i+1]
            rl.DrawLineV(p1, p2, rl.GRAY)

            p1_bottom := rl.Vector2{p1.x, f32(screen_height)}
            p2_bottom := rl.Vector2{p2.x, f32(screen_height)}
            
            rl.DrawTriangle(p1, p2, p1_bottom, rl.DARKGRAY)
            rl.DrawTriangle(p2, p2_bottom, p1_bottom, rl.DARKGRAY)
        }
        return
    }

    rl.SetTextureFilter(g.terrain_texture, .BILINEAR)
    rl.SetTextureWrap(g.terrain_texture, .REPEAT) // Important for source.x = x1 logic

    tex_w := f32(g.terrain_texture.width)  // Full width of the texture image
    tex_h := f32(g.terrain_texture.height) // Full height of the texture image

    if tex_w == 0 || tex_h == 0 { return }

    for i := 0; i < TERRAIN_POINTS_COUNT - 1; i += 1 {
        p1_segment := g.terrain_points[i]
        p2_segment := g.terrain_points[i+1]
        
        segment_width_on_screen := p2_segment.x - p1_segment.x
        if segment_width_on_screen < 1.0 { 
            continue 
        }

        for j := 0; j < SUBDIVISIONS; j += 1 {
            t1 := f32(j) / f32(SUBDIVISIONS)
            t2 := f32(j + 1) / f32(SUBDIVISIONS)

            // Calculate sub-segment points (x1_sub, y1_sub) and (x2_sub, y2_sub) on screen
            x1_sub := p1_segment.x + t1 * segment_width_on_screen
            x2_sub := p1_segment.x + t2 * segment_width_on_screen
            y1_sub := p1_segment.y + t1 * (p2_segment.y - p1_segment.y)
            y2_sub := p1_segment.y + t2 * (p2_segment.y - p1_segment.y)

            // --- Revised Source Rectangle Calculation ---
            source: rl.Rectangle
            subdivision_width_on_screen := x2_sub - x1_sub

            source.x = x1_sub // Use the screen x-coord of the subdivision's start.
                              // TextureWrap.REPEAT will handle tiling if x1_sub goes beyond tex_w.
            source.y = 0.0
            source.width = subdivision_width_on_screen // Sample a part of texture as wide as the subdivision.
            source.height = tex_h                      // Use the full height of the texture image.
            
            // Destination rectangle calculation
            y_top_dest := math.min(y1_sub, y2_sub)
            height_dest := f32(screen_height) - y_top_dest
            
            // Ensure width and height are positive for the dest rectangle
            width_dest_check := subdivision_width_on_screen
            if width_dest_check < 0 { width_dest_check = 0 }
            if height_dest < 0 { height_dest = 0 }

            dest := rl.Rectangle{x1_sub, y_top_dest, width_dest_check, height_dest}

            // Draw the texture for this sub-segment
            // Ensure source width is also positive (it should be if width_dest_check is)
            if dest.width > 0 && dest.height > 0 && source.width > 0 {
                 rl.DrawTexturePro(
                    g.terrain_texture,
                    source,
                    dest,
                    {0,0}, 
                    0.0,   
                    rl.WHITE,
                )
            }
        }
    }
    
    // Draw the outline
    for i := 0; i < TERRAIN_POINTS_COUNT - 1; i += 1 {
        rl.DrawLineV(g.terrain_points[i], g.terrain_points[i+1], rl.Color{0,0,0,150})
    }
}

draw_centered_text :: proc(font: rl.Font, text: cstring, y_pos: f32, font_size: f32, spacing: f32, color: rl.Color, box_dims: rl.Vector2 = {0,0}, box_color: rl.Color = black) {
	text_size := rl.MeasureTextEx(font, text, font_size, spacing)
	pos_x := (f32(screen_width) - text_size.x) / 2
	
	if box_dims.x > 0 && box_dims.y > 0 { // Draw background box if dimensions provided
		box_x := (f32(screen_width) - box_dims.x) / 2
		box_y_val := y_pos - (box_dims.y - font_size)/2 - 5
		rl.DrawRectangleRounded(rl.Rectangle{box_x, box_y_val, box_dims.x, box_dims.y}, 0.2, 10, box_color)
	}
	rl.DrawTextEx(font, text, {pos_x, y_pos}, font_size, spacing, color)
}

draw_ui_elements :: proc(g: ^Game) {
    draw_centered_text(g.font, "Moonlander", 10, 34, 2, rl.WHITE)

	// Fuel Warnings
	can_show_warnings := !g.start_time && !g.lost_window_focus &&
	                     !g.is_exit_menu && !g.game_over && !g.game_won &&
	                     !is_landed(g.player_lander) && !is_crashed(g.player_lander)
	if can_show_warnings {
		fuel_percentage := get_fuel(g.player_lander)
		alpha := (math.sin(f32(rl.GetTime()) * 4.0) + 1.0) * 0.3 + 0.4 // Pulsing alpha

		warning_text:cstring
		warning_color := rl.Color{}
		if fuel_percentage <= 0.0 {
			warning_text = "Out of Fuel!"
			warning_color = rl.RED
		} else if fuel_percentage < 35.0 {
			warning_text = "Warning! Low Fuel"
			warning_color = yellow
		}

		if warning_text != "" {
			text_size := rl.MeasureTextEx(g.font, warning_text, 28, 2)
			box_w := text_size.x + 40
			box_h := text_size.y + 20
			box_x := f32(screen_width)/2 - box_w/2
			box_y := f32(screen_height)/2 - 110
			
			rl.DrawRectangle(i32(box_x), i32(box_y), i32(box_w), i32(box_h), rl.Fade(black, 0.7))
			rl.DrawRectangleLines(i32(box_x), i32(box_y), i32(box_w), i32(box_h), rl.Fade(warning_color, alpha))
			rl.DrawTextEx(g.font, warning_text, {box_x + 20, box_y + 10}, 28, 2, warning_color)
		}
	}
	// Game State Messages
	msg_y := f32(screen_height / 2)
	msg_box_h :: 70.0
    msg_box_w:f32 = 500.0
    
	if exit_requested {
        msg_box_w = 600
		draw_centered_text(g.font, "Are you sure you want to exit? [Y/N]", msg_y, 25, 2, yellow, {msg_box_w, msg_box_h}, black)
	} else if g.start_time {
		welcome_box_h :: 430.0
        welcome_box_w :: 650.0
		welcome_box_y_offset := -180.0
		welcome_box_y_center := msg_y - 25 // Roughly center the box
        
        // Draw background box for welcome message
        box_x_welcome := (f32(screen_width) - welcome_box_w) / 2
        box_y_welcome := welcome_box_y_center - welcome_box_h / 2 + 25
		rl.DrawRectangleRounded(rl.Rectangle{box_x_welcome, box_y_welcome, welcome_box_w, welcome_box_h}, 0.2, 10, black)

		current_y := box_y_welcome + 20
		draw_centered_text(g.font, "Welcome to Moonlander", current_y, 30, 2, rl.GREEN)
		current_y += 40
		
		obj_lines := [?]cstring{
			"The objective is to land on the landing pad while",
			"carefully managing landing speed and angle.",
			"", // Placeholder for level goal
			"Each level you will face tougher gravity",
			"and fuel restrictions.",
		}
		win_level_str := "15"
		obj_lines[2] = fmt.ctprintf("Try to get to level %s to beat the game.", win_level_str)

		for line in obj_lines {
			draw_centered_text(g.font, line, current_y, 25, 1, rl.WHITE)
			current_y += 30
		}
		current_y += 10 // Extra space

		draw_centered_text(g.font, "Controls: Arrow Up/W for thrust", current_y, 25, 1, yellow)
		current_y += 30
		draw_centered_text(g.font, "Arrow Left/A and Right/D to rotate", current_y, 25, 1, yellow)
		current_y += 30
		draw_centered_text(g.font, "M to toggle music, ESC to exit", current_y, 25, 1, yellow)
		current_y += 40
		draw_centered_text(g.font, "Press Enter to play", current_y, 25, 2, rl.GREEN)

	} else if g.lost_window_focus {
		draw_centered_text(g.font, "Game paused, focus window to continue", msg_y, 25, 2, yellow, {msg_box_w, msg_box_h}, black)
	} else if g.game_over {
		game_over_text :: "Game over, tap to play again"
		draw_centered_text(g.font, game_over_text, msg_y, 25, 2, yellow, {msg_box_w, msg_box_h}, black)
	} else if g.game_won {
        congrats_box_h :: 90.0
		win_level_str := "10"
		congrats_text :: "Congratulations! You completed all levels!"
		draw_centered_text(g.font, congrats_text, msg_y - 15, 25, 2, rl.GREEN, {650, congrats_box_h}, black)
		play_again_text :: "Press Enter to play again"
		draw_centered_text(g.font, play_again_text, msg_y + 15, 25, 2, rl.WHITE) // No separate box for this line
	} else if is_landed(g.player_lander) {
        landed_box_h :: 90.0
		draw_centered_text(g.font, "Landing Successful!", msg_y - 15, 25, 2, rl.GREEN, {msg_box_w, landed_box_h}, black)
		next_level_text :: "Press Enter for next level"
		draw_centered_text(g.font, next_level_text, msg_y + 15, 25, 2, rl.WHITE)
	} else if is_crashed(g.player_lander) && g.lives > 0 {
        crashed_box_h :: 100.0
		crash_reason_str := get_crash_reason(g)
		crash_text_full := fmt.ctprintf("Crashed! %s", crash_reason_str)
		draw_centered_text(g.font, crash_text_full, msg_y - 5, 25, 2, rl.RED, {msg_box_w, crashed_box_h}, black)
		try_again_text :: "Press Enter to try again"
		draw_centered_text(g.font, try_again_text, msg_y + 25, 25, 2, rl.WHITE)
	}

	// Stats Display (top-right)
	right_margin :: 20
	line_h :: 30
	start_y :: 10
	font_sz_stats :: 25.0
	font_sp_stats :: 1.0

	draw_stat :: proc(font: rl.Font, text: cstring, line_num: int, color: rl.Color) {
		size := rl.MeasureTextEx(font, text, font_sz_stats, font_sp_stats)
		pos := rl.Vector2{f32(screen_width - int(size.x) - right_margin), f32(start_y + line_h * line_num)}
		rl.DrawTextEx(font, text, pos, font_sz_stats, font_sp_stats, color)
	}

	draw_stat(g.font, fmt.ctprintf("Level: %d", g.level), 0, rl.WHITE)
	draw_stat(g.font, fmt.ctprintf("Lives: %d", g.lives), 1, rl.WHITE)
	
	fuel_val := get_fuel(g.player_lander)
	fuel_color := rl.WHITE
	draw_stat(g.font, fmt.ctprintf("Fuel: %.1f", fuel_val), 2, fuel_color)
	
	draw_stat(g.font, fmt.ctprintf("Fuel Use: %.3f", fuel_consumption), 3, rl.WHITE)

	vel_x := get_velocity_x(g.player_lander)
	vel_y := get_velocity_y(g.player_lander)
	vel_color := rl.WHITE
	if abs(vel_x) >= current_velocity_limit || abs(vel_y) >= current_velocity_limit {
		vel_color = rl.RED
	}
	draw_stat(g.font, fmt.ctprintf("Velocity X: %.1f Y: %.1f", vel_x, vel_y), 4, vel_color)

	angle_val := get_angle(g.player_lander)
    normalized_angle := angle_val
    if normalized_angle > 180 { normalized_angle -= 360 } // clamp to [-180, 180]
	angle_color := rl.WHITE
	if abs(normalized_angle) >= 15.0 {
		angle_color = rl.RED
	}
	draw_stat(g.font, fmt.ctprintf("Angle: %.1f", angle_val), 5, angle_color)
	draw_stat(g.font, fmt.ctprintf("Gravity: %.3f", current_gravity), 6, rl.WHITE)

	// Music toggle text
	music_status_text := fmt.ctprintf("Press M to toggle music (%s)", "ON" if g.playing_music else "OFF")
	music_text_size := rl.MeasureTextEx(g.font, music_status_text, 25, 1)
	music_pos_x := (f32(screen_width) - music_text_size.x) / 2
	music_pos_y := f32(screen_height - 30)
	rl.DrawTextEx(g.font, music_status_text, {music_pos_x, music_pos_y}, 25, 1, rl.WHITE)
}


randomize_terrain :: proc(g: ^Game) {
	segment_w := f32(screen_width) / f32(TERRAIN_POINTS_COUNT - 1)
	// Heights are from top of screen. min_h is "higher" on screen (smaller Y value).
	min_h := f32(screen_height) - MIN_TERRAIN_HEIGHT_FROM_BOTTOM
	max_h := f32(screen_height) - MAX_TERRAIN_HEIGHT_FROM_BOTTOM
	
	// Update lander's target landing_pad_x, as terrain gen depends on it
	landing_pad_center_x := get_landing_pad_x(g.player_lander)
	landing_pad_half_w :f32 = 50.0
	landing_pad_terrain_y := f32(screen_height - 50) // Y of the flat part

	for i := 0; i < TERRAIN_POINTS_COUNT; i += 1 {
		x := f32(i) * segment_w
		y: f32

		// Check if current x is within the landing pad influence zone
		in_pad_zone_left_slope  := x >= landing_pad_center_x - landing_pad_half_w - segment_w && x < landing_pad_center_x - landing_pad_half_w
		in_pad_zone_right_slope := x > landing_pad_center_x + landing_pad_half_w && x <= landing_pad_center_x + landing_pad_half_w + segment_w
		in_pad_flat_area      := x >= landing_pad_center_x - landing_pad_half_w && x <= landing_pad_center_x + landing_pad_half_w
		
		if in_pad_flat_area {
			y = landing_pad_terrain_y
		} else if in_pad_zone_left_slope {
			// Slope down to pad from left
            t := ( (landing_pad_center_x - landing_pad_half_w) - x) / segment_w; // t is 1 at start of slope, 0 at edge of pad
            y = landing_pad_terrain_y + t * t * 10.0; // Quadratic rise from pad height

		} else if in_pad_zone_right_slope {
			// Slope up from pad to right
            t := (x - (landing_pad_center_x + landing_pad_half_w)) / segment_w; // t is 0 at edge of pad, 1 at end of slope
            y = landing_pad_terrain_y + t * t * 10.0; // Quadratic rise
		}else {
			y = rand.float32_range(min_h, max_h)
		}
		g.terrain_points[i] = {x, y}
	}

	// Smooth terrain (simple pass, excluding pad area)
	smoothed_points: [TERRAIN_POINTS_COUNT]rl.Vector2
	for i := 0; i < TERRAIN_POINTS_COUNT; i += 1 { smoothed_points[i] = g.terrain_points[i] }

	// Two passes of smoothing
	for pass := 0; pass < 2; pass += 1 {
		for i := 1; i < TERRAIN_POINTS_COUNT - 1; i += 1 {
			x := g.terrain_points[i].x
            // Skip smoothing if near/on landing pad zone
            is_near_pad := (x >= landing_pad_center_x - landing_pad_half_w - segment_w && 
                            x <= landing_pad_center_x + landing_pad_half_w + segment_w)
			if is_near_pad {
				if pass == 0 { // On first pass, copy original to smoothed if near pad
                    smoothed_points[i].y = g.terrain_points[i].y
                } // On second pass, it will use the (already set) pad values from previous points.
				continue
			}
            // Read from g.terrain_points on first pass, from smoothed_points on second pass (for stability)
            source_array := g.terrain_points if pass == 0 else smoothed_points

			smoothed_points[i].y = (source_array[i-1].y + source_array[i].y + source_array[i+1].y) / 3.0
		}
        // After each pass (except the last, if more passes were added), copy smoothed back to terrain_points
        // For two passes, first pass smooths g.terrain -> smoothed_points
        // Second pass smooths smoothed_points -> smoothed_points (again, but reading from its previous state)
        // Then finally copy to g.terrain_points
        if pass == 0 {
            for i := 0; i < TERRAIN_POINTS_COUNT; i += 1 { g.terrain_points[i] = smoothed_points[i] }
        }
	}
    // Final copy from smoothed_points to g.terrain_points after all passes
    for i := 0; i < TERRAIN_POINTS_COUNT; i += 1 { g.terrain_points[i] = smoothed_points[i] }
}

draw_explosion :: proc(g: ^Game) {
	if !g.explosion_active { return }
	if g.explosion_texture.id == 0 { return }

	g.explosion_frames_counter += 1
	if g.explosion_frames_counter > EXPLOSION_PLAYBACK_SPEED {
		g.explosion_current_frame += 1
		g.explosion_frames_counter = 0

		if g.explosion_current_frame >= EXPLOSION_FRAMES_PER_LINE {
			g.explosion_current_frame = 0
			g.explosion_current_line += 1

			if g.explosion_current_line >= EXPLOSION_LINES {
				// Explosion finished
				g.explosion_current_line = 0 // Reset for next time
				g.explosion_active = false
				return
			}
		}
	}
	// Update frame rect for current animation frame
	g.explosion_frame_rec.x = g.explosion_frame_rec.width * f32(g.explosion_current_frame)
	g.explosion_frame_rec.y = g.explosion_frame_rec.height * f32(g.explosion_current_line)

	scaled_w := g.explosion_frame_rec.width * EXPLOSION_SCALE
	scaled_h := g.explosion_frame_rec.height * EXPLOSION_SCALE
	
	// Draw centered at explosion_pos
	dest_rect := rl.Rectangle {
		g.explosion_pos.x,
		g.explosion_pos.y,
		scaled_w,
		scaled_h,
	}
    // Origin is top-left for DrawTexturePro
	rl.DrawTexturePro(g.explosion_texture, g.explosion_frame_rec, dest_rect, {0,0}, 0.0, rl.WHITE)
}

start_explosion :: proc(g: ^Game, x, y: f32) {
	if g.explosion_texture.id == 0 { return }
	g.explosion_active = true
	g.explosion_current_frame = 0
	g.explosion_current_line = 0
	g.explosion_frames_counter = 0

	scaled_w := g.explosion_frame_rec.width * EXPLOSION_SCALE
	scaled_h := g.explosion_frame_rec.height * EXPLOSION_SCALE

	// Store top-left position for drawing the explosion sprite
	g.explosion_pos.x = x - scaled_w / 2.0
	g.explosion_pos.y = y - scaled_h / 2.0
}

get_crash_reason :: proc(g: ^Game) -> string {
	p_lander := g.player_lander
	if !is_crashed(p_lander) { return "" }

	vx := abs(get_velocity_x(p_lander))
	vy := abs(get_velocity_y(p_lander))
	
    angle_val := get_angle(p_lander)
    normalized_angle_val := angle_val
    if normalized_angle_val > 180 { normalized_angle_val -= 360 }
	bad_angle := abs(normalized_angle_val) >= 15.0

	high_vel_x := vx >= current_velocity_limit
	high_vel_y := vy >= current_velocity_limit

	lander_center_x := get_x(p_lander) + (get_width(p_lander) * COLLISION_SCALE / 2.0)
	near_pad := abs(lander_center_x - get_landing_pad_x(p_lander)) <= 50.0

	if !near_pad { return "Missed the landing pad!" }
	if bad_angle && (high_vel_x || high_vel_y) { return "Bad angle and too fast!"}
	if bad_angle { return "Bad landing angle!" }
	if high_vel_x && high_vel_y { return "Too fast - both horizontal and vertical!" }
	if high_vel_x { return "Too fast - horizontal velocity!" }
	if high_vel_y { return "Too fast - vertical velocity!" }
	
	return "Something went wrong!"
}

destroy_game :: proc(g: ^Game) {
	if g.player_lander != nil {
		cleanup(g.player_lander)
		free(g.player_lander)
	}
	rl.UnloadRenderTexture(g.target_render_tex)
	rl.UnloadFont(g.font)
	rl.UnloadMusicStream(g.bg_music)
	if g.terrain_texture.id != 0 { rl.UnloadTexture(g.terrain_texture) }
	if g.explosion_texture.id != 0 { rl.UnloadTexture(g.explosion_texture) }
}