package main

import "core:fmt"
import "core:math"
import ln "core:math/linalg"
import "core:math/rand"
import "core:reflect"
import "core:simd"
import "core:time"
import "core:slice"

import rl "vendor:raylib"
import tracy "odin-tracy"

TRACY_ENABLE :: #config(TRACY_ENABLE, ODIN_DEBUG)

ONEF32 :: simd.f32x8(1)
ONEU32 :: simd.u32x8(1)
ZEROF32 :: simd.f32x8(0)
ZEROU32 :: simd.u32x8(0)

N :: 2e2 // this is going to be multiplied by 8
SUBSTEPS :: 4  // Reduced from 8
DT :: 3e-4
G :: simd.f32x8(1000)

CVec2 :: [2]simd.f32x8

ParticleCluster :: struct {
	pos:     CVec2,
	pos_old: CVec2,
	accel:   CVec2,
	radius:  simd.f32x8,
}

// Spatial partitioning structures
GridCell :: struct {
	cluster_indices: [dynamic]int,
}

SpatialGrid :: struct {
	cells: []GridCell,
	cell_size: f32,
	grid_width: int,
	grid_height: int,
}

random_simd :: proc(min, max: f32) -> simd.f32x8 {
	tmp: [8]f32
	for i in 0 ..< 8 {
		tmp[i] = rand.float32_range(min, max)
	}
	return simd.from_array(tmp)
}

random_cluster :: proc(window_dims, lim_vel: [2]f32, dt: f32) -> ParticleCluster {
	pos := CVec2{random_simd(0, window_dims.x), random_simd(0, window_dims.y)}
	vel := CVec2{random_simd(lim_vel.x, lim_vel.y), random_simd(lim_vel.x, lim_vel.y)}
	return {pos = pos, pos_old = pos - (vel * simd.f32x8(dt)), accel = 0, radius = random_simd(3, 3)}
}

Particles :: struct {
	clusters: []ParticleCluster,
	spatial_grid: SpatialGrid,
}

W_DIMS: [2]f32 = {1200, 900}

init_spatial_grid :: proc(grid: ^SpatialGrid, world_dims: [2]f32, max_radius: f32) {
	grid.cell_size = max_radius * 2  // Cell size should be at least 2x max diameter
	grid.grid_width = int(math.ceil(world_dims.x / grid.cell_size))
	grid.grid_height = int(math.ceil(world_dims.y / grid.cell_size))
	
	total_cells := grid.grid_width * grid.grid_height
	grid.cells = make([]GridCell, total_cells)
	
	for &cell in grid.cells {
		cell.cluster_indices = make([dynamic]int, 0, 16)
	}
}

cleanup_spatial_grid :: proc(grid: ^SpatialGrid) {
	for &cell in grid.cells {
		delete(cell.cluster_indices)
	}
	delete(grid.cells)
}

clear_spatial_grid :: proc(grid: ^SpatialGrid) {
	for &cell in grid.cells {
		clear(&cell.cluster_indices)
	}
}

get_grid_index :: proc(grid: ^SpatialGrid, pos: [2]f32) -> int {
	x := int(pos.x / grid.cell_size)
	y := int(pos.y / grid.cell_size)
	x = clamp(x, 0, grid.grid_width - 1)
	y = clamp(y, 0, grid.grid_height - 1)
	return y * grid.grid_width + x
}

update_spatial_grid :: proc(grid: ^SpatialGrid, clusters: []ParticleCluster) {
	clear_spatial_grid(grid)
	
	for cluster_idx in 0..<len(clusters) {
		cluster := &clusters[cluster_idx]
		
		// Use average position to place cluster in grid (avoid duplicates)
		avg_pos := [2]f32{
			simd.reduce_add_ordered(cluster.pos.x) / 8,
			simd.reduce_add_ordered(cluster.pos.y) / 8,
		}
		
		grid_idx := get_grid_index(grid, avg_pos)
		append(&grid.cells[grid_idx].cluster_indices, cluster_idx)
	}
}

get_nearby_clusters :: proc(grid: ^SpatialGrid, pos: [2]f32, radius: f32) -> []int {
	// Get all clusters in the same and adjacent cells
	nearby_clusters := make([dynamic]int, 0, 64)
	defer delete(nearby_clusters)
	
	cell_x := int(pos.x / grid.cell_size)
	cell_y := int(pos.y / grid.cell_size)
	
	// Check 3x3 grid around the particle
	for dy in -1..=1 {
		for dx in -1..=1 {
			nx := cell_x + dx
			ny := cell_y + dy
			
			if nx >= 0 && nx < grid.grid_width && ny >= 0 && ny < grid.grid_height {
				cell_idx := ny * grid.grid_width + nx
				for cluster_idx in grid.cells[cell_idx].cluster_indices {
					// Avoid duplicates
					found := false
					for existing in nearby_clusters {
						if existing == cluster_idx {
							found = true
							break
						}
					}
					if !found {
						append(&nearby_clusters, cluster_idx)
					}
				}
			}
		}
	}
	
	return slice.clone(nearby_clusters[:])
}

// Collision detection between two clusters (particle by particle)
check_cluster_collision :: proc(cluster1: ^ParticleCluster, cluster2: ^ParticleCluster, resp_coef: f32) {
	if cluster1 == cluster2 do return
	
	// Check each particle in cluster1 against each particle in cluster2
	for i in 0..<8 {
		pos1 := [2]f32{simd.extract(cluster1.pos.x, i), simd.extract(cluster1.pos.y, i)}
		r1 := simd.extract(cluster1.radius, i)
		
		for j in 0..<8 {
			pos2 := [2]f32{simd.extract(cluster2.pos.x, j), simd.extract(cluster2.pos.y, j)}
			r2 := simd.extract(cluster2.radius, j)
			
			v := pos1 - pos2
			dist2 := v.x * v.x + v.y * v.y
			min_dist := r1 + r2
			
			if dist2 < min_dist * min_dist && dist2 > math.F32_EPSILON {
				dist := math.sqrt(dist2)
				n := v / dist
				
				mass_ratio_1 := r1 / (r1 + r2)
				mass_ratio_2 := r2 / (r1 + r2)
				delta := 0.5 * resp_coef * (dist - min_dist)
				
				calc1 := n * (mass_ratio_2 * delta)
				calc2 := n * (mass_ratio_1 * delta)
				
				cluster1.pos.x = simd.replace(cluster1.pos.x, i, pos1.x - calc1.x)
				cluster1.pos.y = simd.replace(cluster1.pos.y, i, pos1.y - calc1.y)
				cluster2.pos.x = simd.replace(cluster2.pos.x, j, pos2.x + calc2.x)
				cluster2.pos.y = simd.replace(cluster2.pos.y, j, pos2.y + calc2.y)
			}
		}
	}
}

// Self-collision within a cluster (optimized)
check_self_collision :: proc(cluster: ^ParticleCluster, resp_coef: f32) {
	for i in 0..<8 {
		for j in i+1..<8 {
			pos1 := [2]f32{simd.extract(cluster.pos.x, i), simd.extract(cluster.pos.y, i)}
			pos2 := [2]f32{simd.extract(cluster.pos.x, j), simd.extract(cluster.pos.y, j)}
			r1 := simd.extract(cluster.radius, i)
			r2 := simd.extract(cluster.radius, j)
			
			v := pos1 - pos2
			dist2 := v.x * v.x + v.y * v.y
			min_dist := r1 + r2
			
			if dist2 < min_dist * min_dist && dist2 > math.F32_EPSILON {
				dist := math.sqrt(dist2)
				n := v / dist
				
				mass_ratio_1 := r1 / (r1 + r2)
				mass_ratio_2 := r2 / (r1 + r2)
				delta := 0.5 * resp_coef * (dist - min_dist)
				
				calc1 := n * (mass_ratio_2 * delta)
				calc2 := n * (mass_ratio_1 * delta)
				
				cluster.pos.x = simd.replace(cluster.pos.x, i, pos1.x - calc1.x)
				cluster.pos.y = simd.replace(cluster.pos.y, i, pos1.y - calc1.y)
				cluster.pos.x = simd.replace(cluster.pos.x, j, pos2.x + calc2.x)
				cluster.pos.y = simd.replace(cluster.pos.y, j, pos2.y + calc2.y)
			}
		}
	}
}

main :: proc() {
	tracy.SetThreadName("main")
	ps := Particles {
		clusters = make([]ParticleCluster, N),
	}
	defer delete(ps.clusters)
	
	// Init spatial grid
	init_spatial_grid(&ps.spatial_grid, W_DIMS, 24.0)  // Increased cell size
	defer cleanup_spatial_grid(&ps.spatial_grid)
	
	R :: 8
	y := f32(R * 3)
	x := f32(R * 3)
	for i in 0 ..< N {
		pos_x: [8]f32
		pos_y: [8]f32
		for k in 0 ..< 8 {
			pos_x[k] = x
			pos_y[k] = y
			x += R * 3
			if x >= W_DIMS.x {
				x = R * 3
				y += R * 3
			}
		}
		pos := CVec2{simd.from_array(pos_x), simd.from_array(pos_y)} + CVec2{random_simd(-1, 1), random_simd(-1, 1)}
		ps.clusters[i].pos = pos
		ps.clusters[i].pos_old = pos
		ps.clusters[i].accel = 0
		ps.clusters[i].radius = simd.f32x8(R)
	}

	rl.InitWindow(i32(W_DIMS.x), i32(W_DIMS.y), "Optimized SIMD Verlet Physics")
	defer rl.CloseWindow()
	rl.SetTargetFPS(60)

	buffer := rl.LoadRenderTexture(i32(W_DIMS.x), i32(W_DIMS.y))
	defer rl.UnloadRenderTexture(buffer)

	for !rl.WindowShouldClose() && !rl.IsKeyPressed(.ESCAPE) {
		tracy.ZoneN("Physics update")
		subdt := rl.GetFrameTime() / SUBSTEPS
		
		for substep in 0 ..< SUBSTEPS {
			tracy.ZoneN("Physics substep")
			
			// Apply gravity
			for &cluster in ps.clusters {
				cluster.accel.y += G
			}
			
			// Update spatial grid
			tracy.ZoneN("Update spatial grid")
			update_spatial_grid(&ps.spatial_grid, ps.clusters)
			
			// Collision detection using spatial partitioning
			tracy.ZoneN("Collision detection")
			resp_coef: f32 = 1 - 0.3
			
			for i in 0..<len(ps.clusters) {
				cluster1 := &ps.clusters[i]
				
				// Self-collision within cluster
				check_self_collision(cluster1, resp_coef)
				
				// Get average position for spatial lookup
				avg_pos := [2]f32{
					simd.reduce_add_ordered(cluster1.pos.x) / 8,
					simd.reduce_add_ordered(cluster1.pos.y) / 8,
				}
				
				// Get grid cell for this cluster
				grid_idx := get_grid_index(&ps.spatial_grid, avg_pos)
				
				// Check adjacent cells for potential collisions
				cell_x := int(avg_pos.x / ps.spatial_grid.cell_size)
				cell_y := int(avg_pos.y / ps.spatial_grid.cell_size)
				
				for dy in -1..=1 {
					for dx in -1..=1 {
						nx := cell_x + dx
						ny := cell_y + dy
						
						if nx >= 0 && nx < ps.spatial_grid.grid_width && ny >= 0 && ny < ps.spatial_grid.grid_height {
							cell_idx := ny * ps.spatial_grid.grid_width + nx
							
							for j in ps.spatial_grid.cells[cell_idx].cluster_indices {
								if i >= j do continue // Avoid duplicate checks and self-collision
								
								cluster2 := &ps.clusters[j]
								check_cluster_collision(cluster1, cluster2, resp_coef)
							}
						}
					}
				}
			}
			
			// Boundary constraints
			tracy.ZoneN("Boundary constraints")
			for &cluster in ps.clusters {
				right := simd.f32x8(W_DIMS.x)
				bottom := simd.f32x8(W_DIMS.y)
				radiuses := cluster.radius
				vel := cluster.pos - cluster.pos_old
				damping := simd.f32x8(1 - 0.3)
				
				// Right edge
				cr := simd.lanes_gt(cluster.pos.x + radiuses, right) & ONEU32
				if simd.reduce_or(cr) == 1 {
					crf := simd.f32x8(cr)
					cluster.pos.x = simd.clamp(cluster.pos.x, simd.f32x8(-math.INF_F32), right - radiuses)
					cluster.pos_old.x += ((cluster.pos.x + vel.x * damping) - cluster.pos_old.x) * crf
				}
				
				// Left edge
				cl := simd.lanes_lt(cluster.pos.x - radiuses, ZEROF32) & ONEU32
				if simd.reduce_or(cl) == 1 {
					clf := simd.f32x8(cl)
					cluster.pos.x *= simd.f32x8(cl ~ ONEU32)
					cluster.pos.x += radiuses * clf
					cluster.pos_old.x += ((cluster.pos.x + vel.x * damping) - cluster.pos_old.x) * clf
				}
				
				// Bottom edge
				cb := simd.lanes_gt(cluster.pos.y + radiuses, bottom) & ONEU32
				if simd.reduce_or(cb) == 1 {
					cbf := simd.f32x8(cb)
					cluster.pos.y = simd.clamp(cluster.pos.y, simd.f32x8(-math.INF_F32), bottom - radiuses)
					cluster.pos_old.y += ((cluster.pos.y + vel.y * damping) - cluster.pos_old.y) * cbf
				}
				
				// Top edge
				ct := simd.lanes_lt(cluster.pos.y - radiuses, ZEROF32) & ONEU32
				if simd.reduce_or(ct) == 1 {
					ctf := simd.f32x8(ct)
					cluster.pos.y *= simd.f32x8(ct ~ ONEU32)
					cluster.pos.y += radiuses * ctf
					cluster.pos_old.y += ((cluster.pos.y + vel.y * damping) - cluster.pos_old.y) * ctf
				}
			}
			
			// Verlet integration
			tracy.ZoneN("Integration")
			for &cluster in ps.clusters {
				dt := simd.f32x8(subdt)
				disp := cluster.pos - cluster.pos_old
				cluster.pos_old = cluster.pos
				cluster.pos = cluster.pos + disp + (cluster.accel / cluster.radius) * (dt * dt)
				cluster.accel = 0
			}
		}
		
		// Rendering
		tracy.ZoneN("Render")
		rl.BeginDrawing()
		rl.BeginTextureMode(buffer)
		rl.ClearBackground(rl.BLACK)
		
		for cluster_index in 0..<len(ps.clusters) {
			cluster := ps.clusters[cluster_index]
			comb := simd_interleave(cluster.pos.x, cluster.pos.y)
			radiuses := simd.to_array(cluster.radius)
			index := 0
			for i in 0 ..< len(radiuses) {
				pos := [2]f32{comb[index], comb[index + 1]}
				// Fixed: Use cluster index and particle index for consistent coloring
				particle_id := cluster_index * 8 + i
				rl.DrawCircleV(pos, radiuses[i], COLORS[particle_id % len(COLORS)])
				index += 2
			}
		}
		
		rl.EndTextureMode()
		rl.DrawTexturePro(
			buffer.texture,
			{0, W_DIMS.y, W_DIMS.x, -W_DIMS.y},
			{0, 0, W_DIMS.x, W_DIMS.y},
			{0, 0}, 0, rl.WHITE,
		)
		rl.DrawFPS(0, 0)
		rl.EndDrawing()
	}
}

simd_interleave :: proc(a, b: simd.f32x8) -> [16]f32 {
	arr_a := simd.to_array(a)
	arr_b := simd.to_array(b)
	result: [16]f32
	for i in 0..<8 {
		result[i*2] = arr_a[i]
		result[i*2+1] = arr_b[i]
	}
	return result
}

COLORS := [?]rl.Color {
	rl.LIGHTGRAY,
	rl.GRAY,
	rl.DARKGRAY,
	rl.YELLOW,
	rl.GOLD,
	rl.ORANGE,
	rl.PINK,
	rl.RED,
	rl.MAROON,
	rl.GREEN,
	rl.LIME,
	rl.DARKGREEN,
	rl.SKYBLUE,
	rl.BLUE,
	rl.DARKBLUE,
	rl.PURPLE,
	rl.VIOLET,
	rl.DARKPURPLE,
	rl.BEIGE,
	rl.WHITE,
	rl.MAGENTA,
	rl.RAYWHITE,
}