package pathgrid

import pq "core:container/priority_queue"
import "core:math"
import "core:mem"
import "core:slice"

DEFAULT_PATHFINDER_BUFFER_SIZE :: 128 * mem.Kilobyte

IVector2 :: [2]i32

/*
// TODO: Implement this someday.
AStar_Diagonal_Mode :: enum {
	Always,
	Never,
	AtLeastOneWalkable,
	OnlyIfNoObstacles,
}
*/

heuristic_euclidean :: proc(a, b: IVector2) -> f32 {
	dx := f32(math.abs(b.x - a.x))
	dy := f32(math.abs(b.y - a.y))
	return math.sqrt(dx * dx + dy * dy)
}
heuristic_manhattan :: proc(a, b: IVector2) -> f32 {
	dx := f32(math.abs(b.x - a.x))
	dy := f32(math.abs(b.y - a.y))
	return dx + dy
}
heuristic_octile :: proc(a, b: IVector2) -> f32 {
	dx := f32(math.abs(b.x - a.x))
	dy := f32(math.abs(b.y - a.y))
	F :: math.SQRT_TWO - 1
	return (dx < dy) ? (F * dx + dy) : (F * dy + dx)
}
heuristic_chebyshev :: proc(a, b: IVector2) -> f32 {
	dx := f32(math.abs(b.x - a.x))
	dy := f32(math.abs(b.y - a.y))
	return math.max(dx, dy)
}

AStar_Grid :: struct {
	region:            struct {
		min, max: IVector2,
	},
	blocked_points:    map[IVector2]struct {},
	cost_points:       map[IVector2]f32,
	compute_heuristic: proc(a, b: IVector2) -> f32,
	alloc:             struct {
		bytes: []byte,
		arena: mem.Arena,
	},
}

astar_grid_init :: proc(
	asg: ^AStar_Grid,
	heuristic := heuristic_euclidean,
	allocator := context.allocator,
	buffer_size := DEFAULT_PATHFINDER_BUFFER_SIZE,
) {
	asg.alloc.bytes = make([]byte, DEFAULT_PATHFINDER_BUFFER_SIZE, allocator)
	mem.arena_init(&asg.alloc.arena, asg.alloc.bytes)

	asg.blocked_points = make(type_of(asg.blocked_points), allocator = allocator)
	asg.cost_points = make(type_of(asg.cost_points), allocator = allocator)
	asg.compute_heuristic = heuristic
}

astar_grid_destroy :: proc(asg: ^AStar_Grid) {
	delete(asg.blocked_points)
	delete(asg.cost_points)
	delete(asg.alloc.bytes)
}


@(private = "file")
_point_neighbors :: #force_inline proc(p: IVector2) -> [8]IVector2 {
	return(
		 {
			p + {-1, -1},
			p + {0, -1},
			p + {1, -1},
			p + {-1, 0},
			p + {1, 0},
			p + {-1, 1},
			p + {0, 1},
			p + {1, 1},
		} \
	)
}

@(private = "file")
_neighbors_walkable :: #force_inline proc(
	asg: ^AStar_Grid,
	p: IVector2,
	allocator := context.allocator,
) -> []IVector2 {
	_filter :: proc(p: IVector2) -> bool {
		asg := (cast(^AStar_Grid)context.user_ptr)
		return _in_bounds(asg, p) && _is_walkable(asg, p)
	}
	context.user_ptr = asg
	rn := _point_neighbors(p)
	return slice.filter(rn[:], _filter, allocator)
}

@(private = "file")
_in_bounds :: #force_inline proc(asg: ^AStar_Grid, p: IVector2) -> bool {
	return(
		(p.x >= asg.region.min.x && p.x < asg.region.max.x) &&
		(p.y >= asg.region.min.y && p.y < asg.region.max.y) \
	)
}

@(private = "file")
_is_walkable :: #force_inline proc(asg: ^AStar_Grid, p: IVector2) -> bool {
	return p not_in asg.blocked_points
}

@(private = "file")
_get_cost :: #force_inline proc(asg: ^AStar_Grid, p: IVector2) -> f32 {
	return asg.cost_points[p] or_else 0.
}


//
//
@(private = "file")
_Astar_Node :: struct {
	point: IVector2,
	cost:  f32,
}
@(private = "file")
_cmp_node :: proc(a, b: _Astar_Node) -> bool {return a.cost < b.cost}
//
//


astar_get_path :: proc(
	asg: ^AStar_Grid,
	from, to: IVector2,
	max_distance := max(f32),
	path_alloc := context.allocator,
) -> (
	path: []IVector2,
	ok: bool,
) {
	area: pq.Priority_Queue(_Astar_Node)
	neighbors: []IVector2
	visitors: map[IVector2]IVector2
	current_cost: map[IVector2]f32
	found_path: bool

	// Early returns for invalid points.
	if !_in_bounds(asg, from) {return}
	if !_in_bounds(asg, to) {return}
	if !_is_walkable(asg, to) {return}

	tmp_alloc := mem.arena_allocator(&asg.alloc.arena)

	// Always clear the allocator after a return.
	defer free_all(tmp_alloc)

	// Early return if there are no valid exits on either side of this point.
	neighbors = _neighbors_walkable(asg, from, tmp_alloc)
	if len(neighbors) < 1 {return}
	neighbors = _neighbors_walkable(asg, to, tmp_alloc)
	if len(neighbors) < 1 {return}
	// Clean out the last 2  allocations before we start.
	free_all(tmp_alloc)

	//
	// Priority queue to store node info
	pq.init(&area, _cmp_node, pq.default_swap_proc(_Astar_Node), allocator = tmp_alloc)
	pq.push(&area, _Astar_Node{from, 0.})

	// Visitor map to track where each point was entered from
	visitors = make(type_of(visitors), allocator = tmp_alloc)
	visitors[from] = from

	// Cost map to track grid point costs
	current_cost = make(type_of(current_cost), allocator = tmp_alloc)
	current_cost[from] = 0

	for pq.len(area) > 0 {
		// Pop the top node.
		current := pq.pop(&area).point
		// Break if we hit the goal.
		if current == to {
			found_path = true
			break
		}

		// Skip to the next point if this spot is further than the maximum distance by heuristic.
		if asg.compute_heuristic(from, current) > max_distance {continue}

		// Check all walkable neighbors. (No need for OOB check; this function does it.)
		neighbors = _neighbors_walkable(asg, current, tmp_alloc)
		for n in neighbors {
			// Check if cost exists in the map already.
			new_cost := current_cost[current] //+ ((math.abs(n.x) + math.abs(n.y)) > 1 ? 1.45 : 1.0)
			this_cost, next_exists := current_cost[n]

			// If the cost didn't exist or if the new one is less than the last:
			if !next_exists || new_cost < this_cost {
				// Set the cost of this point.
				current_cost[n] = new_cost

				// Current overall cost + heuristic + cost of this map cell if any.
				dist := asg.compute_heuristic(n, to)
				mod := _get_cost(asg, n)
				// Push this point and cost to the node queue.
				pq.push(&area, _Astar_Node{n, new_cost + dist + mod})

				// Mark off that we visited this neighbor from the central point.
				visitors[n] = current
			}
		}
	}

	// Early return if we didn't find the path.
	if !found_path {return}

	// Make a dynamic array of points to represent the path.
	pdyn := make([dynamic]IVector2, path_alloc)
	current := to
	// Work backwards from the goal point.
	for current != from {
		append(&pdyn, current)
		current, ok = visitors[current]
		assert(ok)
	}

	// Reverse so it comes back start -> finish.
	slice.reverse(pdyn[:])
	return pdyn[:], true
}


astar_grid_clear :: proc(asg: ^AStar_Grid) {
	clear(&asg.blocked_points)
	clear(&asg.cost_points)
}

astar_block :: proc(asg: ^AStar_Grid, p: IVector2) {
	if !_in_bounds(asg, p) {return}
	asg.blocked_points[p] = {}
}
astar_unblock :: proc(asg: ^AStar_Grid, p: IVector2) {
	if !_in_bounds(asg, p) {return}
	delete_key(&asg.blocked_points, p)
}
astar_set_cost :: proc(asg: ^AStar_Grid, p: IVector2, c: f32 = 0.) {
	if !_in_bounds(asg, p) {return}
	asg.cost_points[p] = c
}
astar_delete_cost :: proc(asg: ^AStar_Grid, p: IVector2) {
	if !_in_bounds(asg, p) {return}
	delete_key(&asg.cost_points, p)
}