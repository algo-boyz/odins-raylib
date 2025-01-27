// Original source by Alfie Hiscox: https://github.com/alfiehiscox/dda-impl/blob/main/main.odin
package main

import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:mem"
import "core:os"
import rl "vendor:raylib"

IVector2 :: [2]i32

CELL_SIZE: rl.Vector2 : {16, 16}

MAP_SIZE: IVector2 : {32, 32}

CIRCLE_RAD :: 5

grid := [i32(MAP_SIZE.x * MAP_SIZE.y)]int{}

main :: proc() {
	default := context.allocator
	tracking_allocator: mem.Tracking_Allocator
	mem.tracking_allocator_init(&tracking_allocator, default)
	defer mem.tracking_allocator_destroy(&tracking_allocator)
	context.allocator = mem.tracking_allocator(&tracking_allocator)
	defer print_memory_usage(&tracking_allocator)

	rl.InitWindow(MAP_SIZE.x * i32(CELL_SIZE.x), MAP_SIZE.y * i32(CELL_SIZE.y), "dda impl")
	defer rl.CloseWindow()
	rl.SetTargetFPS(60)

	player := rl.Vector2{0, 0}

	for !rl.WindowShouldClose() {
		delta := rl.GetFrameTime()
		mouse := rl.GetMousePosition()
		mouse_cell := mouse / CELL_SIZE
		cell := IVector2{i32(mouse_cell.x), i32(mouse_cell.y)}

		if rl.IsKeyDown(.W) do player.y -= 25 * delta
		if rl.IsKeyDown(.A) do player.x -= 25 * delta
		if rl.IsKeyDown(.S) do player.y += 25 * delta
		if rl.IsKeyDown(.D) do player.x += 25 * delta

		if rl.IsMouseButtonDown(.LEFT) {
			grid[cell.y * i32(MAP_SIZE.x) + cell.x] = 1
		}

		// DDA Implementation 
		ray_start := player
		ray_dir := linalg.normalize(mouse_cell - player)

		ray_unit_step_size := rl.Vector2 {
			math.sqrt(1 + (ray_dir.y / ray_dir.x) * (ray_dir.y / ray_dir.x)),
			math.sqrt(1 + (ray_dir.x / ray_dir.y) * (ray_dir.x / ray_dir.y)),
		}

		// Which tile we're currently in
		map_check: IVector2 = {i32(ray_start.x), i32(ray_start.y)}

		//// x = length of ray in accumulated columns 
		//// y = lenght of ray in accumulated rows 
		ray_length_in_1d: rl.Vector2

		//// The x and y directions we walk 
		step: IVector2

		if ray_dir.x < 0 {
			step.x = -1
			ray_length_in_1d.x = (ray_start.x - f32(map_check.x)) * ray_unit_step_size.x
		} else {
			step.x = 1
			ray_length_in_1d.x = (f32(map_check.x + 1) - ray_start.x) * ray_unit_step_size.x
		}

		if ray_dir.y < 0 {
			step.y = -1
			ray_length_in_1d.y = (ray_start.y - f32(map_check.y)) * ray_unit_step_size.y
		} else {
			step.y = 1
			ray_length_in_1d.y = (f32(map_check.y + 1) - ray_start.y) * ray_unit_step_size.y
		}

		tile_found := false
		max_distance: f32 = 1000
		distance: f32 = 0

		for !tile_found && (distance < max_distance) {

			if ray_length_in_1d.x < ray_length_in_1d.y {
				map_check.x += step.x
				distance = ray_length_in_1d.x
				ray_length_in_1d.x += ray_unit_step_size.x
			} else {
				map_check.y += step.y
				distance = ray_length_in_1d.y
				ray_length_in_1d.y += ray_unit_step_size.y
			}

			if map_check.x >= 0 &&
			   map_check.x < MAP_SIZE.x &&
			   map_check.y >= 0 &&
			   map_check.y < MAP_SIZE.y {
				if grid[map_check.y * MAP_SIZE.x + map_check.x] == 1 {
					tile_found = true
				}
			}

		}

		intersection: rl.Vector2
		if tile_found {
			intersection = ray_start + ray_dir * distance
		}

		rl.BeginDrawing()

		rl.ClearBackground(rl.BLACK)

		for y := 0; y < int(MAP_SIZE.y); y += 1 {
			for x := 0; x < int(MAP_SIZE.x); x += 1 {
				cell := grid[y * int(MAP_SIZE.x) + x]
				if cell == 1 {
					rl.DrawRectangleV(rl.Vector2{f32(x), f32(y)} * CELL_SIZE, CELL_SIZE, rl.BLUE)
				} else {
					rl.DrawRectangleLines(
						i32(f32(x) * CELL_SIZE.x),
						i32(f32(y) * CELL_SIZE.y),
						i32(CELL_SIZE.x),
						i32(CELL_SIZE.y),
						rl.DARKGRAY,
					)
				}
			}
		}

		rl.DrawLineV(player * CELL_SIZE, mouse, rl.WHITE)
		rl.DrawCircleV(mouse, CIRCLE_RAD, rl.WHITE)
		rl.DrawCircleV(player * CELL_SIZE, CIRCLE_RAD, rl.RED)
		if tile_found do rl.DrawCircleV(intersection * CELL_SIZE, CIRCLE_RAD, rl.GREEN)

		rl.EndDrawing()
	}

}

print_memory_usage :: proc(tracking_allocator: ^mem.Tracking_Allocator, stats := false) {
	if stats {
		fmt.eprintfln("Total Allocated        : ", tracking_allocator.total_memory_allocated)
		fmt.eprintfln("Total Freed            : ", tracking_allocator.total_memory_freed)
		fmt.eprintfln("Total Allocation Count : ", tracking_allocator.total_free_count)
		fmt.eprintfln("Total Free Count       : ", tracking_allocator.total_free_count)
		fmt.eprintfln("Current Allocations    : ", tracking_allocator.current_memory_allocated)
		fmt.eprintln()
	}

	if len(tracking_allocator.allocation_map) > 0 {
		fmt.eprintln("Memory Leaks: ")
		for _, entry in tracking_allocator.allocation_map {
			fmt.eprintf(" - Leaked %d @ %v\n", entry.size, entry.location)
		}
	}

	if len(tracking_allocator.bad_free_array) > 0 {
		fmt.eprintln("Bad Frees: ")
		for entry in tracking_allocator.bad_free_array {
			fmt.eprintf(" - Bad Free %p @ %v\n", entry.memory, entry.location)
		}
	}
}