package falling_sands

import "core:fmt"
import "core:math/rand"
import rl "vendor:raylib"

// making falling sand simulations - https://jason.today/falling-sand
Particles :: enum {
	None,
	Sand,
	Rock,
	Water,
	Steam,
	Fire,
}

Particle :: struct {
	color:     rl.Color, // color of the particle
	type:      Particles, // type of the particle
	updated:   bool, // Flag to prevent multiple updates per frame
	disp_rate: int, // how quickly the particle moves horizontally
	health:    f32, // Health of the particle
}

// Constants
SCREEN_WIDTH :: 800
SCREEN_HEIGHT :: 600
FPS :: 120
CELL_SIZE :: 4
ROWS: int : int(SCREEN_HEIGHT / CELL_SIZE)
COLS: int : int(SCREEN_WIDTH / CELL_SIZE)

// Colors
GREY :: rl.Color{29, 29, 29, 255}
LIGHT_GREY :: rl.Color{55, 55, 55, 255}
SAND_COLOR :: rl.Color{167, 137, 82, 255}
ROCK_COLOR :: rl.Color{115, 104, 101, 255}
WATER_COLOR :: rl.Color{43, 103, 179, 255}
STEAM_COLOR :: rl.Color{180, 156, 151, 255}

// Variables
cells: [ROWS][COLS]Particle // array for all the particles on screen
p_type: [5]Particles // array containing all the particle enum types
p_num: u8 // index for the p_type array 
m_pos: rl.Vector2 // mouse position
paused: bool // checks if paused
showFPS: bool // shows the fps
brush_size: int // size of the brush

main :: proc() {
	rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "Falling Sands Simulation")
	rl.SetTargetFPS(FPS)
	defer rl.CloseWindow()

	init()
	rl.HideCursor()

	for !rl.WindowShouldClose() do updateGame()
}

// Initialize game state
init :: proc() {
	for &row in cells {
		for &cell in row {
			cell = Particle{LIGHT_GREY, .None, false, 0, 1}
		}
	}

	p_num = 0
	p_type = {.Sand, .Rock, .Water, .Steam, .Fire}
	paused = false
	showFPS = false
	brush_size = 3
}

// Handle controls
controls :: proc() {
	m_pos = rl.GetMousePosition()
	row := int(m_pos.y / CELL_SIZE)
	col := int(m_pos.x / CELL_SIZE)

	if is_within_bounds(row, col) {
		if rl.IsMouseButtonDown(.LEFT) {
			apply_brush(row, col, 'a', p_type[p_num])
		}
		if rl.IsMouseButtonPressed(.RIGHT) {
			apply_brush(row, col, 'e')
		}
	}

	if rl.IsKeyPressed(.R) {
		init()
	}

	if rl.IsKeyPressed(.T) {
		p_num = (p_num + 1) %% len(p_type)
	}

	if rl.IsKeyPressed(.SPACE) {
		paused = !paused
	}

	if rl.IsKeyPressed(.F) {
		showFPS = !showFPS
	}

	if rl.IsKeyPressed(.A) {
		brush_size *= 2
	}

	if rl.IsKeyPressed(.D) {
		if brush_size > 1 {
			brush_size /= 2
		}
	}
}

// Update game
updateGame :: proc() {
	controls()
	if !paused {
		run()
	}
	draw()
}

// Draw all elements
draw :: proc() {
	rl.BeginDrawing()
	defer rl.EndDrawing()
	rl.ClearBackground(GREY)

	draw_grid()
	draw_brush()

	if showFPS {
		rl.DrawFPS(10, 10)
	}
}

// Draw particles
draw_grid :: proc() {
	for row in 0 ..< ROWS {
		for col in 0 ..< COLS {
			particle := cells[row][col]

			if particle.type != .None {
				rl.DrawRectangle(
					i32(col * CELL_SIZE),
					i32(row * CELL_SIZE),
					CELL_SIZE,
					CELL_SIZE,
					particle.color,
				)
			}
		}
	}
}

// Draw brush 
draw_brush :: proc() {
	col := int(m_pos.x / CELL_SIZE)
	row := int(m_pos.y / CELL_SIZE)

	brush_size := i32(brush_size * CELL_SIZE)
	color: rl.Color

	#partial switch p_type[p_num] {
	case .Sand:
		color = SAND_COLOR
	case .Rock:
		color = ROCK_COLOR
	case .Water:
		color = WATER_COLOR
	case .Steam:
		color = STEAM_COLOR
	case .Fire:
		color = rl.ORANGE
	}

	rl.DrawRectangle(i32(col * CELL_SIZE), i32(row * CELL_SIZE), brush_size, brush_size, color)
}

// brush that allows you to add or remove particles
apply_brush :: proc(row, col: int, type: rune, particle: Particles = .None) {
	for r in 0 ..< brush_size {
		for c in 0 ..< brush_size {
			c_row := row + r
			c_col := col + c

			if is_within_bounds(c_row, c_col) {
				if type == 'e' {
					remove_particle(c_row, c_col)
				} else if type == 'a' {
					add_particle(c_row, c_col, particle)
				}
			}
		}
	}
}

// Creates rand collors using hsv values
rand_color :: proc(h1, h2, s1, s2, v1, v2: f32) -> rl.Color {
	hue := rand.float32_uniform(h1, h2)
	saturation := rand.float32_uniform(s1, s2)
	value := rand.float32_uniform(v1, v2)
	return rl.ColorFromHSV(hue, saturation, value)
}

// set particles color
set_color :: proc(particle: Particles) -> rl.Color {
	#partial switch particle {
	case .None:
		return LIGHT_GREY
	case .Sand:
		return rand_color(37, 42, .5, .7, .6, .7)
	case .Rock:
		return rand_color(8, 12, .1, .15, .3, .5)
	case .Water:
		return rand_color(213, 214, .75, .76, .70, .71)
	case .Steam:
		return rand_color(10, 18, .05, .15, .60, .64)
	case .Fire:
		return rand_color(30, 42, .80, .95, .80, .90)
	}
	return LIGHT_GREY
}

// Utility functions
is_within_bounds :: proc(row, col: int) -> bool {
	return (row >= 0 && row < ROWS) && (col >= 0 && col < COLS)
}

// checks if cells is in bounds and not .None
is_empty_cell :: proc(row, col: int) -> bool {
	return is_within_bounds(row, col) && cells[row][col].type == .None
}

// adds particles
add_particle :: proc(row, col: int, type: Particles) {
	if is_empty_cell(row, col) {
		rate := set_dispersion_rate(cells[row][col])
		if type != .Rock {
			if rand.float32() < 0.15 {
				cells[row][col] = Particle{set_color(type), type, false, rate, 1}
			}
		} else {
			cells[row][col] = Particle{set_color(type), type, false, rate, 1}
		}
	}
}

// removes particles
remove_particle :: proc(row, col: int) {
	if !is_empty_cell(row, col) {
		cells[row][col] = Particle{LIGHT_GREY, .None, false, 0, 0}
	}
}

// sets particles disp rate
set_dispersion_rate :: proc(particle: Particle) -> int {
	#partial switch particle.type {
	case .None:
		return 0
	case .Water:
		return 5
	case .Sand:
		return 1
	case .Rock:
		return 0
	case .Steam:
		return 7
	case .Fire:
		return 5
	case:
		return 0
	}
	return 0
}

// controls movement horizontally based on the disp_rate
disp_movement :: proc(row, col, mod: int) {
	col := col
	moves := 0
	max_moves := cells[row][col].disp_rate

	for moves < max_moves {
		cell := cells[row][col]
		new_col := col + mod
		if is_empty_cell(row, new_col) {
			swap_particles(row, col, row, new_col)
			col = new_col
			moves += 1
		} else {
			return
		}
	}
}

// change particle
change_particle :: proc(row, col, r, c, chance: int, typeof, typeto: Particles) {
	if is_within_bounds(row + r, col + c) {
		s_part := cells[row + r][col + c]

		if s_part.type == typeof {
			remove_particle(row, col)
			remove_particle(row + r, col + c)
			if chance == 0 do add_particle(row, col, typeto)
		}
	}
}

// Swap two particles
swap_particles :: proc(row1, col1, row2, col2: int) {
	if is_within_bounds(row1, col1) && is_within_bounds(row2, col2) {
		temp := cells[row1][col1]
		cells[row1][col1] = cells[row2][col2]
		cells[row2][col2] = temp

		cells[row1][col1].updated = true
		cells[row2][col2].updated = true
	}
}

// Moves particles. If 'b' move down, if 'd' move diagonally, if 'h' move horizontally 
move_particle :: proc(row, col: int, type: rune, dirs: []int = {}) {
	if is_empty_cell(row, col) {
		if cells[row][col].updated do return
	}

	switch type {
	case 'b':
		if is_empty_cell(row + 1, col) {
			swap_particles(row, col, row + 1, col)
		}
	case 'a':
		if is_empty_cell(row - 1, col) {
			swap_particles(row, col, row - 1, col)
		}
	case 'd':
		for dir in dirs {
			new_col := col + dir

			if !is_within_bounds(row, new_col) || cells[row][new_col].type == .Rock do continue

			// **Move Diagonally if the space is empty**
			if is_empty_cell(row + 1, new_col) {
				swap_particles(row, col, row + 1, new_col)
			}
		}
	case 'r':
		for dir in dirs {
			new_col := col + dir

			if !is_within_bounds(row, new_col) || cells[row][new_col].type == .Rock do continue

			// **Move Diagonally if the space is empty**
			if is_empty_cell(row - 1, new_col) {
				swap_particles(row, col, row - 1, new_col)
			}
		}
	case 'h':
		for dir in dirs {
			disp_movement(row, col, dir)
		}
	}
}

// Update sand particle with desired logic
update_sand :: proc(row, col: int) {
	if !is_within_bounds(row, col) || cells[row][col].type != .Sand {
		return
	} else {
		cells[row][col].disp_rate = set_dispersion_rate(cells[row][col])

		// **Swap with Water Directly Below**
		if is_within_bounds(row + 1, col) {
			s_part := cells[row + 1][col]

			if (s_part.type == .Water || s_part.type == .Steam) && !s_part.updated {
				swap_particles(row, col, row + 1, col)
			}
		}
	}

	if cells[row][col].updated {
		return // Skip if already updated
	}

	// **Attempt to Move Down**
	move_particle(row, col, 'b')

	// **Attempt Diagonal Movement into Empty Spaces Only**
	directions: []int = {-1, 1}
	rand.shuffle(directions)

	move_particle(row, col, 'd', directions)


	// **No Movement Possible**
	cells[row][col].updated = true
}

// Update water particle
update_water :: proc(row, col: int) {
	if !is_within_bounds(row, col) || cells[row][col].type != .Water {
		return
	} else {
		cells[row][col].disp_rate = set_dispersion_rate(cells[row][col])
	}

	if cells[row][col].updated {
		return // Skip if already updated
	}

	// **Attempt to Move Down**
	move_particle(row, col, 'b')

	directions := []int{-1, 1}
	rand.shuffle(directions)

	// **Attempt Diagonal Movement**
	move_particle(row, col, 'd', directions)

	// **Move Horizontally if Possible**
	move_particle(row, col, 'h', directions)

	// **No Movement Possible**
	cells[row][col].updated = true
}

// Update steam particle
update_steam :: proc(row, col: int) {
	if !is_within_bounds(row, col) || cells[row][col].type != .Steam {
		return
	} else {
		// fmt.println(cells[row][col].disp_rate)
		cells[row][col].disp_rate = set_dispersion_rate(cells[row][col])
		cells[row][col].health -= rand.float32_uniform(.00001, .001)

		// Condense to water 
		side := rand.choice(([]int){-1, 1})
		chance := rand.int_max(20)
		// **Condense with Water Above**
		change_particle(row, col, -1, 0, chance, .Water, .Water)
		// **Condense with Water Side**
		change_particle(row, col, 0, side, chance, .Water, .Water)
		// **Condense with Water Side**
		change_particle(row, col, 0, -side, chance, .Water, .Water)
	}

	if cells[row][col].updated {
		return // Skip if already updated
	}

	// chance to condense on health 0
	if cells[row][col].health <= 0 {
		remove_particle(row, col)
		if rand.int_max(20) == 0 do add_particle(row, col, .Water)
	}

	// **Attempt to Move Up**
	move_particle(row, col, 'a')

	// **Attempt Diagonal Movement**
	directions := []int{-1, 1}
	rand.shuffle(directions)

	move_particle(row, col, 'd', directions)
	move_particle(row, col, 'r', directions)

	// **Move Horizontally if Possible**
	move_particle(row, col, 'h', directions)

	// **No Movement Possible**
	cells[row][col].updated = true
}

// Update fire particle
update_fire :: proc(row, col: int) {
	if !is_within_bounds(row, col) || cells[row][col].type != .Fire {
		return
	} else {
		cells[row][col].disp_rate = set_dispersion_rate(cells[row][col])
		cells[row][col].health -= rand.float32_uniform(.0001, .002)

		// Transform to steam
		side := rand.choice(([]int){-1, 1})
		// chance := rand.int_max(20)

		// **Water Above**
		change_particle(row, col, -1, 0, 0, .Water, .Steam)
		// **Water Below**
		change_particle(row, col, 1, 0, 0, .Water, .Steam)
		// **Water Side**
		change_particle(row, col, 0, side, 0, .Water, .Steam)
		// **Water Side**
		change_particle(row, col, 0, -side, 0, .Water, .Steam)
	}

	if cells[row][col].updated {
		return // Skip if already updated
	}

	// on health 0
	if cells[row][col].health <= 0 {
		remove_particle(row, col)
	}

	// // **Attempt Diagonal Movement**
	directions := []int{-1, 1}
	rand.shuffle(directions)

	move_particle(row, col, 'd', directions)
	move_particle(row, col, 'r', directions)

	// **No Movement Possible**
	cells[row][col].updated = true
}

// Update particle positions
update_particle :: proc(row, col: int) {
	particle := &cells[row][col]
	if particle.type == .None || particle.updated {
		return // Skip empty or already updated particles
	}

	#partial switch particle.type {
	case .Sand:
		update_sand(row, col)
	case .Water:
		update_water(row, col)
	case .Steam:
		update_steam(row, col)
	case .Fire:
		update_fire(row, col)
	case:
		particle.updated = true
	}
}

// Simulation passes for particles
simulate :: proc(type: Particles) {
	for row := ROWS - 1; row >= 0; row -= 1 {
		if row %% 2 == 0 {
			for col in 0 ..< COLS {
				if cells[row][col].type == type {
					update_particle(row, col)
				}
			}
		} else {
			for col := COLS - 1; col >= 0; col -= 1 {
				if cells[row][col].type == type {
					update_particle(row, col)
				}
			}
		}
	}
}

// run simulation
run :: proc() {
	// **Reset update flags**
	for &row in cells {
		for &cell in row {
			cell.updated = false
		}
	}

	// **First Pass: Update Sand Particles**
	simulate(.Sand)

	// **Second Pass: Update Water Particles**
	simulate(.Water)

	// **Third Pass: Update Steam Particles**
	simulate(.Steam)

	// **Third Pass: Update Fire Particles**
	simulate(.Fire)
}