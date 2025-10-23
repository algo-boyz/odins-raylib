package main

import "core:fmt"
import "core:math"
import "core:math/rand"
import "core:mem" 
import rl "vendor:raylib"

MAX_RUNS :: 200
MAX_CODE :: 1200
MAX_ARC  :: 64

Terrain :: enum i32 {
	GROUND       = 0,
	TREE         = 1,
	AI1    = 2,
	AI2    = 3,
	GOAL         = 4,
	GOALREACHED  = 5,
}

// Initial map layout
// 1=border (TREE), 2=ai unit, 3=defensiveunit, 4=objective
map_layout :: [10][10]Terrain{
	{.TREE, .TREE, .TREE, .TREE, .TREE, .TREE, .TREE, .TREE, .TREE, .TREE},
	{.TREE, .GROUND, .GROUND, .GROUND, .GROUND, .GROUND, .GROUND, .GROUND, .GROUND, .TREE},
	{.TREE, .GROUND, .GROUND, .GROUND, .AI2, .GROUND, .GROUND, .GOAL, .GROUND, .TREE},
	{.TREE, .GROUND, .GROUND, .AI2, .GROUND, .GROUND, .AI2, .GROUND, .GROUND, .TREE},
	{.TREE, .GROUND, .GROUND, .GROUND, .GROUND, .GROUND, .GROUND, .GROUND, .GROUND, .TREE},
	{.TREE, .AI1, .GROUND, .GROUND, .GROUND, .GROUND, .GROUND, .AI2, .GROUND, .TREE},
	{.TREE, .GROUND, .AI1, .GROUND, .GROUND, .GROUND, .GROUND, .GROUND, .GROUND, .TREE},
	{.TREE, .GROUND, .GROUND, .GROUND, .GROUND, .GROUND, .GROUND, .AI1, .GROUND, .TREE},
	{.TREE, .GROUND, .GROUND, .GROUND, .GROUND, .GROUND, .GROUND, .AI1, .GROUND, .TREE},
	{.TREE, .TREE, .TREE, .TREE, .TREE, .TREE, .TREE, .TREE, .TREE, .TREE},
}

map_state: [10][10]Terrain

Code :: struct {
	position: rl.Vector2,
	move:     rl.Vector2,
}

arr_code: [MAX_CODE]Code

Code_Arc :: struct {
	position: [MAX_CODE]rl.Vector2,
	move:     [MAX_CODE]rl.Vector2,
	score:    i32,
}

arr_codearc: [MAX_ARC]Code_Arc
arr_temparc: [MAX_ARC]Code_Arc

WIDTH,
HEIGHT,
tile_width,
tile_height: i32
map_width:   i32 = 10
map_height:  i32 = 10

main :: proc() {
	WIDTH = 800
	HEIGHT = 600

	tile_width = cast(i32)math.ceil(cast(f32)WIDTH / cast(f32)map_width)
	tile_height = cast(i32)math.ceil(cast(f32)HEIGHT / cast(f32)map_height)

	rl.InitWindow(WIDTH, HEIGHT, "Genetic Algorithm Pacman style")
	rl.SetTargetFPS(60)

	genetic_algorithm()
	pos: int

	for !rl.WindowShouldClose() {

		if rl.IsKeyPressed(.R) || pos > MAX_CODE - 2 {
			genetic_algorithm()
			pos = 0
		}
		if pos == 0 {
			// Restore map
			map_state = map_layout
		}

		// Execute script for current frame
		current_code_pos := arr_code[pos].position
		current_code_move := arr_code[pos].move
		
		map_y := cast(i32)current_code_pos.y
		map_x := cast(i32)current_code_pos.x

        if map_y >= 0 && map_y < map_height && map_x >= 0 && map_x < map_width {
            if map_state[map_y][map_x] == .AI1 {
                p := current_code_pos
                m := current_code_move
                np := rl.Vector2{p.x + m.x, p.y + m.y}

                // Ensure new pos within bounds
                np_y := cast(i32)np.y
                np_x := cast(i32)np.x

                if np_y >= 0 && np_y < map_height && np_x >= 0 && np_x < map_width {
                    target_cell_type := map_state[np_y][np_x]

                    #partial switch target_cell_type {
                    case .GOAL:
                        map_state[np_y][np_x] = .GOALREACHED
                    case .GROUND:
                        map_state[np_y][np_x] = .AI1
                        map_state[cast(int)p.y][cast(int)p.x] = .GROUND
                    case .AI2:
                        map_state[np_y][np_x] = .AI1
                        map_state[cast(int)p.y][cast(int)p.x] = .GROUND
                    case: // Other cases: TREE, AI1, GOALREACHED - no move or specific interaction
                    }
                }
            }
        }

		pos += 1
		if pos > MAX_CODE - 1 {
			pos = 0
		}

		rl.BeginDrawing()
		rl.ClearBackground(rl.RAYWHITE)

		// Draw map
		for y in 0..<map_height {
			for x in 0..<map_width {
				cell := map_state[y][x]
				rect_x := cast(f32)(x * tile_width)
				rect_y := cast(f32)(y * tile_height)
				f_tile_width := cast(f32)tile_width
				f_tile_height := cast(f32)tile_height

				switch cell {
				case .TREE:
					rl.DrawRectangle(x * tile_width, y * tile_height, tile_width, tile_height, rl.Color{40, 90, 20, 255})
					rl.DrawCircle(cast(i32)(rect_x + f_tile_width / 1.5), cast(i32)(rect_y + f_tile_height / 1.5), f_tile_width / 5, rl.Color{20, 50, 20, 255})
					rl.DrawRectangle(cast(i32)(rect_x + f_tile_width / 2.2), cast(i32)(rect_y + f_tile_height / 2), cast(i32)(f_tile_width / 8), cast(i32)(f_tile_height / 3), rl.BROWN)
					rl.DrawCircle(cast(i32)(rect_x + f_tile_width / 2), cast(i32)(rect_y + f_tile_height / 3), f_tile_width / 4, rl.Color{120, 250, 20, 255})
					rl.DrawCircle(cast(i32)(rect_x + f_tile_width / 2.2), cast(i32)(rect_y + f_tile_height / 4), f_tile_width / 9, rl.Color{220, 255, 220, 155})
				case .GROUND:
					rl.DrawRectangle(x * tile_width, y * tile_height, tile_width, tile_height, rl.DARKGREEN)
					rl.DrawRectangle(x * tile_width + 5, y * tile_height + 10, 2, 1, rl.GREEN)
					rl.DrawRectangle(x * tile_width + tile_width / 6, y * tile_height + tile_height / 6, 2, 1, rl.GREEN)
					rl.DrawRectangle(cast(i32)(rect_x + f_tile_width / 1.5), cast(i32)(rect_y + f_tile_height / 1.5), 2, 1, rl.GREEN)
					rl.DrawRectangle(cast(i32)(rect_x + f_tile_width / 2), cast(i32)(rect_y + f_tile_height / 2), 2, 1, rl.GREEN)
				case .AI1:
					rl.DrawRectangle(x * tile_width, y * tile_height, tile_width, tile_height, rl.BLUE)
					rl.DrawText("AI", x * tile_width + tile_width / 4, y * tile_height + tile_height / 4, 40, rl.BLACK)
				case .AI2:
					rl.DrawRectangle(x * tile_width, y * tile_height, tile_width, tile_height, rl.RED)
					rl.DrawText("F", x * tile_width + tile_width / 3, y * tile_height + tile_height / 4, 40, rl.WHITE)
				case .GOAL:
					rl.DrawRectangle(x * tile_width, y * tile_height, tile_width, tile_height, rl.WHITE)
					rl.DrawText("City", x * tile_width + tile_width / 4, y * tile_height + tile_height / 4, 26, rl.BLACK)
				case .GOALREACHED:
					rl.DrawRectangle(x * tile_width, y * tile_height, tile_width, tile_height, rl.YELLOW)
					rl.DrawText("Captured", x * tile_width + 4, y * tile_height + tile_height / 4, 16, rl.BLACK)
				}
			}
		}
		rl.DrawText("Press 'R' to restart simulation (Autorun = on)", 10, 10, 26, rl.BLACK)
		rl.DrawText("Press 'R' to restart simulation (Autorun = on)", 9, 9, 26, rl.WHITE)
		rl.EndDrawing()
	}
	rl.CloseWindow()
}

genetic_algorithm :: proc() {
	// First run - populate initial generation
	for z in 0..<MAX_ARC {
		// Create random script
		for i in 0..<MAX_CODE {
			arr_code[i].position = rl.Vector2{
				rand.float32_range(0, f32(map_width)),
				rand.float32_range(0, f32(map_height)),
            }
            arr_code[i].position = rl.Vector2{
                rand.float32_range(0, 11), // 0 to 10 for x
                rand.float32_range(0, 11), // 0 to 10 for y
            }
			arr_code[i].move = rl.Vector2{
				rand.float32_range(-1, 2), // -1, 0, 1
				rand.float32_range(-1, 2), // -1, 0, 1
			}
		}

		map_state = map_layout
		execute_script()
		score := get_score()
		store_script(i32(z), score)
	}

	for t in 0..<MAX_RUNS {
		sort_arc()
		mutate_and_new()

		for z in 0..<MAX_ARC {
			map_state = map_layout
			get_script(i32(z))
			execute_script()
			
			score := get_score()
			arr_codearc[z].score = score
		}
	}

	// After all runs, load the best script for playing
	map_state = map_layout // Restore map for the final best script visualization
	get_script(0) // Load the champion
}

mutate_and_new :: proc() {
	// Mutate a portion of the population (from index 3 up to MAX_ARC-6)
	for z in 3..<(MAX_ARC - 5) {
        max := cast(f32)MAX_CODE
		start_mutation_index := int(rand.float32_range(max / 4, (max / 1.5) + 1))
		for i in start_mutation_index..<MAX_CODE {
			arr_codearc[z].position[i] = rl.Vector2{rand.float32_range(0, 11), rand.float32_range(0, 11)}
			arr_codearc[z].move[i] = rl.Vector2{rand.float32_range(-1, 2), rand.float32_range(-1, 2)}
		}
	}

	for z in (MAX_ARC - 5)..<MAX_ARC {
		for i in 0..<MAX_CODE {
			arr_codearc[z].position[i] = rl.Vector2{rand.float32_range(0, 11), rand.float32_range(0, 11)}
			arr_codearc[z].move[i] = rl.Vector2{rand.float32_range(-1, 2), rand.float32_range(-1, 2)}
		}
	}
}

// sort_arc sorts arr_codearc by score in descending order and replicates top 3.
sort_arc :: proc() {
	// Find indices of the top 3 scores
	top3_indices: [3]i32

	// Simple bubble sort to get top 3
    current_pos := 0
    checked_indices: [MAX_ARC]bool

    for i in 0..<MAX_ARC {
        max_idx := i
        for j in (i+1)..<MAX_ARC {
            if arr_codearc[j].score > arr_codearc[max_idx].score {
                max_idx = j
            }
        }
        arr_codearc[i], arr_codearc[max_idx] = arr_codearc[max_idx], arr_codearc[i] // Swap
    }

    for j in 0..<3 {
        // Deep copy for position and move arrays
        arr_temparc[j].score = arr_codearc[j].score
        for i in 0..<MAX_CODE {
            arr_temparc[j].position[i] = arr_codearc[j].position[i]
            arr_temparc[j].move[i] = arr_codearc[j].move[i]
        }
    }

    i_rep := 0
    for i_rep < MAX_ARC - 8 {
        for k in 0..<3 {
            if i_rep + k < MAX_ARC { // Boundary check
                arr_codearc[i_rep+k].score = arr_temparc[k].score
                for j_code in 0..<MAX_CODE {
                    arr_codearc[i_rep+k].position[j_code] = arr_temparc[k].position[j_code]
                    arr_codearc[i_rep+k].move[j_code] = arr_temparc[k].move[j_code]
                }
            }
        }
        i_rep += 3
    }
}


get_script :: proc(z: i32) {
	if z < 0 || z >= MAX_ARC { return }

	for i in 0..<MAX_CODE {
		arr_code[i].move = arr_codearc[z].move[i]
		arr_code[i].position = arr_codearc[z].position[i]
	}
}

store_script :: proc(z: i32, score: i32) {
	if z < 0 || z >= MAX_ARC { return }

	arr_codearc[z].score = score
	for i in 0..<MAX_CODE {
		arr_codearc[z].move[i] = arr_code[i].move
		arr_codearc[z].position[i] = arr_code[i].position
	}
}

get_score :: proc() -> i32 {
	score: i32

	// Count enemies left
	num_enemies_left, players_left: i32
	for y in 0..<map_height {
		for x in 0..<map_width {
			if map_state[y][x] == .AI2 {
				num_enemies_left += 1
			}
			if map_state[y][x] == .AI1 {
				players_left += 1
			}
		}
	}

	// Was the goal taken?
	objective_success: bool
	goal_position: rl.Vector2

	for y in 0..<map_height {
		for x in 0..<map_width {
			if map_state[y][x] == .GOALREACHED {
				objective_success = true
			}
			// If multiple goals, this might be an issue.
			// Assuming one primary goal for distance calculation.
			if map_state[y][x] == .GOAL || map_state[y][x] == .GOALREACHED {
				goal_position.x = cast(f32)x
				goal_position.y = cast(f32)y
			}
		}
	}
	
	// Count AI1 and distance to target
	avg_dist: f32 = 0
	num_ai_units := 0
	distance_unit: [114]i32
	
	if players_left > 0 { // Avoid division by zero if no players_left
		for y in 0..<map_height {
			for x in 0..<map_width {
				if map_state[y][x] == .AI1 {
					if num_ai_units < len(distance_unit) { // Boundary check for distance_unit
						dist_to_goal := euclidean_distance(goal_position.x, goal_position.y, cast(f32)x, cast(f32)y)
						distance_unit[num_ai_units] = cast(i32)(dist_to_goal * 2)
						avg_dist += dist_to_goal * 2
						num_ai_units += 1
					}
				}
			}
		}
        if num_ai_units > 0 { // Check num_ai_units before division
		    avg_dist = avg_dist / cast(f32)num_ai_units
        } else {
            avg_dist = 999 // Or some other penalty if no AI units found but players_left > 0 (should not happen)
        }
	} else {
        avg_dist = 9999 // High penalty if no players left
    }

	score = (100 - (num_enemies_left * 25)) * 2
	score += (100 - cast(i32)(avg_dist * 5))
	if objective_success {
		score += 75
	}

	// If every unit is close then extra score
	all_close := true
	if num_ai_units > 0 { // Check if there are units to evaluate
		for i in 0..<num_ai_units {
            if i < len(distance_unit) { // Ensure index is within bounds
			    if distance_unit[i] > 4 {
				    all_close = false
				    break
			    }
            } else { // Should not happen if num_ai_units is tracked correctly
                all_close = false; break;
            }
		}
	} else { // No units, so not "all close" in a meaningful way, or could be true if no units required to be close
        all_close = false // Assuming if no units, they are not "all close" to goal
    }
	if all_close {
		score += 100
	}
	return score
}

execute_script :: proc() {
	for i in 0..<MAX_CODE {
		// Original position of the unit for this step in the script
		scripted_pos_y := cast(i32)arr_code[i].position.y
		scripted_pos_x := cast(i32)arr_code[i].position.x

        // Check if the position is valid and if an AI1 unit is actually there
        // (it might have moved or been destroyed in a previous step of this same script execution)
        if scripted_pos_y >=0 && scripted_pos_y < map_height &&
           scripted_pos_x >=0 && scripted_pos_x < map_width &&
           map_state[scripted_pos_y][scripted_pos_x] == .AI1 {
            
            p := arr_code[i].position // Current position of the unit for this command
            m := arr_code[i].move     // Move to be applied
            np := rl.Vector2{p.x + m.x, p.y + m.y} // New potential position

            np_y := cast(i32)np.y
            np_x := cast(i32)np.x

            // Check if new position is within map boundaries
            if np_y >= 0 && np_y < map_height && np_x >= 0 && np_x < map_width {
                target_cell_type := map_state[np_y][np_x]
                
                // Current unit's actual position (might have changed from scripted_pos if map is dynamic within script exec)
                // For this model, assume unit is at p.
                unit_curr_y := cast(i32)p.y
                unit_curr_x := cast(i32)p.x

                #partial switch target_cell_type {
                case .GOAL:
                    map_state[np_y][np_x] = .GOALREACHED
                    // Unit moves, original spot becomes ground (if it was the one moving)
                    map_state[unit_curr_y][unit_curr_x] = .GROUND 
                case .GROUND:
                    map_state[np_y][np_x] = .AI1
                    map_state[unit_curr_y][unit_curr_x] = .GROUND
                case .AI2:
                    neigh: int
                    // Check 8 neighbours around the *new position* (np) for friendly units
                    check_y: i32
                    check_x: i32
                    for dy in -1..=1 {
                        for dx in -1..=1 {
                            if dy == 0 && dx == 0 { continue } // Skip self

                            check_y = np_y + i32(dy)
                            check_x = np_x + i32(dx)
                            if check_y >= 0 && check_y < map_height &&
                               check_x >= 0 && check_x < map_width &&
                               map_state[check_y][check_x] == .AI1 {
                                neigh +=1
                            }
                        }
                    }
                    
                    limit_rand := 10 - (neigh * 2)
                    random_draw: int
                    if limit_rand < 0 {
                        random_draw = 0
                    } else {
                        random_draw = rand.int_max(limit_rand + 1) 
                    }

                    if random_draw < 4 { // Attacker (AI1) wins
                        map_state[np_y][np_x] = .AI1
                        map_state[unit_curr_y][unit_curr_x] = .GROUND
                    } else { // Defender (AI2) wins, attacker unit is destroyed
                        map_state[unit_curr_y][unit_curr_x] = .GROUND
                    }
                case: // TREE, AI1 (moving onto own unit), GOALREACHED - typically no move or interaction
                }
            }
        }
	}
}

euclidean_distance :: proc(x1, y1, x2, y2: f32) -> f32 {
	dx := x1 - x2
	dy := y1 - y2
	return math.sqrt((dx * dx) + (dy * dy))
}