package astar

import "core:fmt"
import "core:mem"
import "core:testing"

when ODIN_TEST {

	grid: Grid

	_grid_init :: proc(size := DEFAULT_PATHFINDER_BUFFER_SIZE) {
		grid_init(&grid, heuristic_euclidean, context.allocator, size)
	}
	_grid_destroy :: proc() {
		grid_destroy(&grid)
	}

	@(test)
	init :: proc(t: ^testing.T) {
		_grid_init()
		defer _grid_destroy()
		assert(grid.alloc.bytes != nil)
	}

	@(test)
	destroy :: proc(t: ^testing.T) {
		_grid_init()
		block(&grid, {5, 5})
		set_cost(&grid, {4, 4}, 1.0)

		_grid_destroy()
		assert(len(grid.blocked_points) == 0)
		assert(len(grid.cost_points) == 0)
	}


	@(test)
	reachability :: proc(t: ^testing.T) {
		_grid_init()
		defer _grid_destroy()

		grid.region.min = {0, 0}
		grid.region.max = {12, 12}

		blocked_points: [8]IVector2 =  {
			{4, 4},
			{5, 4},
			{6, 4},
			{4, 5},
			{6, 5},
			{4, 6},
			{5, 6},
			{6, 6},
		}
		for p in blocked_points {
			block(&grid, p)
		}

		path: []IVector2
		ok: bool

		// Unreachable point.
		path, ok = get_path(&grid, {3, 3}, {5, 5}, path_alloc = context.temp_allocator)
		assert(!ok)
		assert(len(path) == 0)

		// Reachable point.
		path, ok = get_path(&grid, {0, 0}, {11, 11}, path_alloc = context.temp_allocator)
		assert(ok)
		assert(len(path) == 14)
	}

	@(test)
	max_distance :: proc(t: ^testing.T) {
		_grid_init()
		defer _grid_destroy()

		grid.region.min = {0, 0}
		grid.region.max = {12, 12}

		blocked_points: [8]IVector2 =  {
			{4, 4},
			{5, 4},
			{6, 4},
			{4, 5},
			{6, 5},
			{4, 6},
			{5, 6},
			{6, 6},
		}
		for p in blocked_points {
			block(&grid, p)
		}

		path: []IVector2
		ok: bool

		// Test max distances.
		path, ok = get_path(&grid, {0, 0}, {11, 11}, 3.0, context.temp_allocator)
		assert(!ok)
		path, ok = get_path(&grid, {0, 0}, {11, 11}, 14.0, context.temp_allocator)
		assert(!ok)
		path, ok = get_path(&grid, {0, 0}, {11, 11}, 15.0, context.temp_allocator)
		assert(ok)
	}

}