package fluid

import "base:runtime"
import "core:fmt"
import "core:thread"
import "core:math"
import "core:math/rand"
import "core:os"
import "core:sync"

import rl "vendor:raylib"

// --- Simulation Constants ---
WIDTH :: 800
HEIGHT :: 600
PARTICLE_COUNT :: 6000
PARTICLE_RADIUS :: 3 // For drawing
PARTICLE_COLOR :: rl.SKYBLUE

// SPH Parameters
H :: 16               // Smoothing Length (Radius of influence)
H2 :: H * H           // H squared, optimization
H6 :: H2 * H2 * H2    // H^6, optimization
H9 :: H6 * H2 * H     // H^9, optimization
PARTICLE_MASS :: 1.0  // Assume uniform mass for now
REST_DENSITY :: 1000.0 // Rest density (rho0) - tune based on initial spacing
STIFFNESS :: 8000.0   // Stiffness (k) for Tait equation - controls compressibility
VISCOSITY_COEFF :: 0.7 // Viscosity coefficient (mu)
GAMMA :: 7.0           // Tait equation exponent

// Derived SPH Kernel Constants (Precomputed factors)
POLY6_FACTOR :: 315.0 / (64.0 * math.PI * H9)
SPIKY_GRAD_FACTOR :: -45.0 / (math.PI * H6)
VISC_LAP_FACTOR :: 45.0 / (math.PI * H6)

// Physics & Boundary
GRAVITY :: rl.Vector2{0, 300.0 * 5} // Increased gravity a bit
BOUNDARY_DAMPING :: 0.5 // Energy loss on hard collision
BOUNDARY_REPULSION :: 50000.0 // Force strength for boundary penalty

// Grid Parameters
GRID_CELL_SIZE :: H // Cell size based on smoothing length
GRID_WIDTH :: int(WIDTH / GRID_CELL_SIZE) + 1
GRID_HEIGHT :: int(HEIGHT / GRID_CELL_SIZE) + 1

// --- Structures ---

Grid :: struct {
	cells:      [][]Cell,
	cell_size:  f32,
	width, height: int,
}

Cell :: struct {
	particles: [dynamic]^Particle,
	mutex:     sync.Mutex, // Still needed for grid updates
}

Particle :: struct {
	pos:          rl.Vector2,
	velocity:     rl.Vector2,
	acceleration: rl.Vector2,
	rho:          f32, // Density
	p:            f32, // Pressure
	mass:         f32, // Mass
	// Store old acceleration for Verlet integration
	acceleration_old: rl.Vector2,
}

// --- Grid Management ---

new_grid :: proc() -> Grid {
	cells := make([][]Cell, GRID_HEIGHT)
	for i in 0..<GRID_HEIGHT {
		cells[i] = make([]Cell, GRID_WIDTH)
		for j in 0..<GRID_WIDTH {
			// Initialize dynamic array and mutex
			cells[i][j].particles = make([dynamic]^Particle)
		}
	}
	return Grid{cells, GRID_CELL_SIZE, GRID_WIDTH, GRID_HEIGHT}
}

// Updates the grid with particle positions. Should be called after position updates.
update_grid :: proc(grid: ^Grid, particles: []Particle) {
	// Clear grid - Consider parallelizing if this becomes a bottleneck
	for y in 0..<grid.height {
		for x in 0..<grid.width {
			// Mutex potentially not needed for clear if done serially before parallel insertion
			// sync.mutex_lock(&grid.cells[y][x].mutex) 
			clear(&grid.cells[y][x].particles)
			// sync.mutex_unlock(&grid.cells[y][x].mutex)
		}
	}

	// Insert particles - This part needs synchronization if done in parallel
	// Keeping it serial for now for simplicity after position updates.
	for i in 0..<len(particles) {
		p := &particles[i]
		x := int(p.pos.x / grid.cell_size)
		y := int(p.pos.y / grid.cell_size)
		if x >= 0 && x < grid.width && y >= 0 && y < grid.height {
			cell := &grid.cells[y][x]
			// Lock only when modifying the cell's list
			sync.mutex_lock(&cell.mutex)
			append(&cell.particles, p)
			sync.mutex_unlock(&cell.mutex)
		}
	}
}

// --- SPH Kernels ---

// Poly6 Kernel for density calculation
kernel_poly6 :: proc(r2: f32) -> f32 {
	if r2 < H2 {
		diff := H2 - r2
		return POLY6_FACTOR * diff * diff * diff
	}
	return 0.0
}

// Factor for Spiky Kernel Gradient (Pressure) - Excludes the direction vector (r_vec / r)
kernel_spiky_gradient_factor :: proc(dist: f32) -> f32 {
	if dist < H && dist > 1e-6 { // Avoid division by zero if dist is exactly 0
		diff := H - dist
		return SPIKY_GRAD_FACTOR * diff * diff / dist // Division by dist incorporates the 1/r factor from (r_vec / r) magnitude
	}
	return 0.0
}

// Viscosity Kernel Laplacian
kernel_viscosity_laplacian :: proc(dist: f32) -> f32 {
	if dist < H {
		return VISC_LAP_FACTOR * (H - dist)
	}
	return 0.0
}


// --- SPH Calculations ---

// Calculates density and pressure for a single particle
calculate_density_pressure :: proc(p: ^Particle, grid: ^Grid) {
	x := int(p.pos.x / grid.cell_size)
	y := int(p.pos.y / grid.cell_size)

	p.rho = 0.0 // Reset density accumulator

	// Iterate over neighboring cells (3x3 grid)
	for dy in -1..=1 {
		ny := y + dy
		if ny < 0 || ny >= grid.height { continue }

		for dx in -1..=1 {
			nx := x + dx
			if nx < 0 || nx >= grid.width { continue }

			cell := &grid.cells[ny][nx]
			// Read-only access during density calc might not strictly need mutex if grid update is finished
			// sync.mutex_lock(&cell.mutex) 
			for other in cell.particles {
				diff_vec := p.pos - other.pos
				r2 := rl.Vector2LengthSqr(diff_vec) // Use squared distance

				if r2 < H2 {
					p.rho += other.mass * kernel_poly6(r2)
				}
			}
			// sync.mutex_unlock(&cell.mutex)
		}
	}

	// Ensure density doesn't go below rest density (or a small fraction) to avoid issues
	p.rho = math.max(p.rho, REST_DENSITY * 0.1) 

	// Calculate pressure using Tait Equation of State
	// P = k * ( (rho/rho0)^gamma - 1 )
	density_ratio := p.rho / REST_DENSITY
	// Clamp ratio power input to avoid NaN if density_ratio is negative (shouldn't happen with max check)
	ratio_pow_gamma := math.pow(math.max(0, density_ratio), GAMMA) 
	p.p = STIFFNESS * (ratio_pow_gamma - 1.0)
	// Ensure pressure is non-negative (optional, depends on EOS interpretation)
	p.p = math.max(0.0, p.p) 
}

// Calculates SPH forces (pressure, viscosity) for a single particle
calculate_sph_forces :: proc(p: ^Particle, grid: ^Grid) {
	x := int(p.pos.x / grid.cell_size)
	y := int(p.pos.y / grid.cell_size)

	force_pressure := rl.Vector2{}
	force_viscosity := rl.Vector2{}

	// Iterate over neighboring cells
	for dy in -1..=1 {
		ny := y + dy
		if ny < 0 || ny >= grid.height { continue }

		for dx in -1..=1 {
			nx := x + dx
			if nx < 0 || nx >= grid.width { continue }

			cell := &grid.cells[ny][nx]
			// Read-only access, mutex likely not needed if density/pressure pass is complete
			// sync.mutex_lock(&cell.mutex)
			for other in cell.particles {
				if p == other { continue } // Don't interact with self

				diff_vec := p.pos - other.pos
				dist := rl.Vector2Length(diff_vec)

				if dist < H && dist > 1e-6 { // Check within smoothing length H and avoid dist=0
					
					// Pressure Force
					// F_p = - sum( m_j * (P_i/rho_i^2 + P_j/rho_j^2) * grad_W_spiky ) * r_vec
					// We use the symmetrical form for stability
					pressure_term := other.mass * (p.p / (p.rho * p.rho) + other.p / (other.rho * other.rho))
					grad_factor := kernel_spiky_gradient_factor(dist) // Factor already includes 1/dist
					
					// Direction vector is normalized diff_vec (diff_vec / dist)
                    // grad_factor * (diff_vec / dist) gives the gradient vector times the factor
                    // We multiply by pressure_term and sum up
					// Need to handle dist=0 case carefully if particles overlap exactly
					if dist > 1e-6 { // Avoid division by zero
						force_pressure += diff_vec * (pressure_term * grad_factor) // grad_factor has negative sign baked in
					}

					// Viscosity Force
					// F_v = mu * sum( m_j * (v_j - v_i) / rho_j * lapl_W_visc )
					visc_lap := kernel_viscosity_laplacian(dist)
					vel_diff := other.velocity - p.velocity
					force_viscosity += vel_diff * (other.mass / other.rho * visc_lap * VISCOSITY_COEFF)
				}
			}
			// sync.mutex_unlock(&cell.mutex)
		}
	}

	// Apply calculated forces (acceleration = force / mass, but mass=1 here)
	p.acceleration += force_pressure
	p.acceleration += force_viscosity
}

// Boundary penalty force - pushes particles away before hard collision
calculate_boundary_penalty :: proc(p: ^Particle, boundary: rl.Rectangle) -> rl.Vector2 {
    force := rl.Vector2{}
    penalty_dist:f32 = H * 0.5 // Activate penalty within half the smoothing radius from boundary

    // Calculate distance to each boundary edge
    dist_x_min := p.pos.x - boundary.x
    dist_x_max := (boundary.x + boundary.width) - p.pos.x
    dist_y_min := p.pos.y - boundary.y
    dist_y_max := (boundary.y + boundary.height) - p.pos.y

	// Apply penalty force proportional to penetration depth (how far inside the penalty_dist)
    if dist_x_min < penalty_dist {
        // Use a simple linear or quadratic ramp-up for the force
		// Example: linear force = k * (penetration_depth / penalty_dist)
		penetration := penalty_dist - dist_x_min
		force.x += BOUNDARY_REPULSION * (penetration / penalty_dist)
    } 
	if dist_x_max < penalty_dist {
		penetration := penalty_dist - dist_x_max
        force.x -= BOUNDARY_REPULSION * (penetration / penalty_dist)
    }
    
    if dist_y_min < penalty_dist {
		penetration := penalty_dist - dist_y_min
        force.y += BOUNDARY_REPULSION * (penetration / penalty_dist)
    } 
	if dist_y_max < penalty_dist {
		penetration := penalty_dist - dist_y_max
        force.y -= BOUNDARY_REPULSION * (penetration / penalty_dist)
    }

    return force
}


// Hard boundary collision - stops particle and dampens velocity
collide_boundary :: proc(p: ^Particle, boundary: rl.Rectangle) {
	collided := false
	if p.pos.x < boundary.x + PARTICLE_RADIUS { // Check against particle radius
		p.pos.x = boundary.x + PARTICLE_RADIUS
		p.velocity.x *= -BOUNDARY_DAMPING // Reverse and dampen
		collided = true
	} else if p.pos.x > boundary.x + boundary.width - PARTICLE_RADIUS {
		p.pos.x = boundary.x + boundary.width - PARTICLE_RADIUS
		p.velocity.x *= -BOUNDARY_DAMPING
		collided = true
	}
	if p.pos.y < boundary.y + PARTICLE_RADIUS {
		p.pos.y = boundary.y + PARTICLE_RADIUS
		p.velocity.y *= -BOUNDARY_DAMPING
		collided = true
	} else if p.pos.y > boundary.y + boundary.height - PARTICLE_RADIUS {
		p.pos.y = boundary.y + boundary.height - PARTICLE_RADIUS
		p.velocity.y *= -BOUNDARY_DAMPING
		collided = true
	}
	// Optional: If collided, you might want to zero out acceleration perpendicular to collision?
	// Or let the next step's forces handle it.
}


// --- Main Simulation Step ---
mov_particles :: proc(particles: []Particle, grid: ^Grid, dt: f32) {

    boundary := rl.Rectangle{0, 0, f32(WIDTH), f32(HEIGHT)}

    // --- 1. Verlet Integration: Predict positions & Store old acceleration ---
    for i := 0; i < len(particles); i += 1 {
        p := &particles[i]
        p.acceleration_old = p.acceleration
        p.pos += p.velocity * dt + 0.5 * p.acceleration_old * dt * dt
    }

    // --- 2. Update Grid ---
    update_grid(grid, particles)

    // --- Threading Setup ---
    thread_count := max(1, os.processor_core_count() - 1) // Leave one core free for other tasks
    batch_size := (len(particles) + thread_count - 1) / thread_count

    Thread_Data :: struct {
        particles: []Particle,
        grid:      ^Grid,
        dt:        f32,
        start, end: int,
        boundary:  rl.Rectangle,
    }

    threads := make([]^thread.Thread, thread_count)
    thread_data := make([]Thread_Data, thread_count)
    // Defer cleanup if using temporary allocator or if manual free is needed
    // defer { free(threads); free(thread_data); }

    // --- 3. Calculate Density and Pressure (Parallel) ---
    density_pressure_worker :: proc(t: ^thread.Thread) {
        data := (^Thread_Data)(t.data) // Cast data pointer
        for i := data.start; i < data.end; i += 1 {
            if i < len(data.particles) {
                calculate_density_pressure(&data.particles[i], data.grid)
            }
        }
    }

    for i := 0; i < thread_count; i += 1 {
        start := i * batch_size
        end := min((i + 1) * batch_size, len(particles))
        if start >= end { continue }

        thread_data[i] = Thread_Data{
            particles = particles,
            grid      = grid,
            dt        = dt,
            start     = start,
            end       = end,
            boundary  = boundary,
        }

        // Use create, assign data, then start
        threads[i] = thread.create(density_pressure_worker)
        assert(threads[i] != nil, "Failed to create density thread") // Use assert from "core:testing" or handle error
        threads[i].data = &thread_data[i] // Assign data pointer
        thread.start(threads[i]) // Start the thread
    }

    // Wait for density/pressure calculation
    for t in threads {
        if t != nil {
            thread.join(t)
            thread.destroy(t)
        }
    }
    // Clear thread handles if reusing the slice (good practice)
    // Not strictly necessary if creating new ones in the next loop, but safer
    // slice.clear(&threads) // Alternative: loop and set to nil

    // --- 4. Calculate Forces (Parallel) ---
    force_worker :: proc(t: ^thread.Thread) {
        data := (^Thread_Data)(t.data) // Cast data pointer
        for i := data.start; i < data.end; i += 1 {
            if i < len(data.particles) {
                p := &data.particles[i]
                p.acceleration = GRAVITY
                penalty_force := calculate_boundary_penalty(p, data.boundary)
                if p.mass != 0 {
                    p.acceleration += penalty_force / p.mass
                }
                calculate_sph_forces(p, data.grid)
            }
        }
    }

    for i := 0; i < thread_count; i += 1 {
        start := i * batch_size
        end := min((i + 1) * batch_size, len(particles))
        if start >= end { continue }

        // Reuse thread_data element, just update start/end
        thread_data[i].start = start
        thread_data[i].end = end

        // Use create, assign data, then start (assigning to the same threads[i] index)
        threads[i] = thread.create(force_worker)
        assert(threads[i] != nil, "Failed to create force thread")
        threads[i].data = &thread_data[i] // Assign data pointer (to the updated struct)
        thread.start(threads[i]) // Start the thread
    }

    // Wait for force calculation
    for t in threads {
        if t != nil {
            thread.join(t)
            thread.destroy(t)
        }
    }

    // --- 5. Verlet Integration: Update Velocity & Apply Collision ---
    for i := 0; i < len(particles); i += 1 {
        p := &particles[i]
        p.velocity += 0.5 * (p.acceleration_old + p.acceleration) * dt
        collide_boundary(p, boundary)
    }

    // Slices `threads` and `thread_data` managed by context/scope or deferred free
}

// --- Main Application ---

main :: proc() {
	// Initialize particles
	particles: [PARTICLE_COUNT]Particle
	// Simple grid initialization
    // In your particle initialization code:
    for i in 0..<PARTICLE_COUNT {
        // Place particles in a grid pattern
        particles_per_row := int(math.sqrt(f32(PARTICLE_COUNT)))
        row := i / particles_per_row
        col := i % particles_per_row
        spacing := PARTICLE_RADIUS * 2.5
        
        particles[i].pos = {
            f32(col) * f32(spacing) + WIDTH/4.0, 
            f32(row) * f32(spacing) + HEIGHT/10.0,
        }
        
        // Add small random initial velocities
        random_vx := (rand.float32() * 20.0) - 10.0  // -10 to +10
        random_vy := (rand.float32() * 5.0) - 2.5    // -2.5 to +2.5
        particles[i].velocity = {random_vx, random_vy}
        
        particles[i].acceleration = {0, 0}
        particles[i].mass = PARTICLE_MASS
        particles[i].rho = REST_DENSITY
        particles[i].p = 0.0
    }
    // At the end of your initialization, before the main loop:
    // Apply initial perturbation to break symmetry
    center := rl.Vector2{f32(WIDTH)/2, f32(HEIGHT)/3}
    perturbation_strength:f32 = 100.0

    for i := 0; i < len(particles); i += 1 {
        p := &particles[i]
        dir := p.pos - center
        dist := rl.Vector2Length(dir)
        if dist > 0.001 {  // Avoid division by zero
            force := rl.Vector2Scale(rl.Vector2Normalize(dir), perturbation_strength / (1.0 + dist * 0.1))
            p.velocity += force * (1.0 / 60.0)  // Apply as impulse
        }
    }
	grid := new_grid()

	rl.InitWindow(WIDTH, HEIGHT, "2D Fluid Simulation (SPH + Verlet)")
	rl.SetTargetFPS(60)

	for !rl.WindowShouldClose() {
		// Use a fixed delta time for stability, or carefully manage variable dt
		// dt := rl.GetFrameTime() 
        dt:f32 = 1.0 / 60.0 // Fixed timestep is often better for physics stability
        // You might need substeps if dt is too large for stability:
        // substeps := 2
        // substep_dt := dt / f32(substeps)
        // for s in 0..<substeps { mov_particles(particles[:], &grid, substep_dt) }

		// --- User Interaction ---
		mouse := rl.GetMousePosition()
		mouse_radius :: 50.0
		mouse_force_strength :: 10000.0
		if rl.IsMouseButtonDown(.LEFT) || rl.IsMouseButtonDown(.RIGHT) {
			for i := 0; i < len(particles); i += 1 {
				p := &particles[i]
				dist_sq := rl.Vector2DistanceSqrt(mouse, p.pos)
				if dist_sq < mouse_radius * mouse_radius {
					force_dir: rl.Vector2
					if rl.IsMouseButtonDown(.LEFT) { // Attract
						force_dir = rl.Vector2Normalize(mouse - p.pos)
					} else { // Repel
						force_dir = rl.Vector2Normalize(p.pos - mouse)
					}
                    // Apply force decaying with distance
                    strength_factor := (mouse_radius - math.sqrt(dist_sq)) / mouse_radius
					// Add force directly to acceleration ( F = ma => a = F/m )
					p.acceleration += force_dir * (mouse_force_strength * strength_factor / p.mass)
				}
			}
		}

		// --- Simulation Step ---
		mov_particles(particles[:], &grid, dt)

		// --- Drawing ---
		rl.BeginDrawing()
		rl.ClearBackground(rl.Color{0x18, 0x18, 0x18, 0xFF}) // Dark grey background

		// Optional: Draw grid for debugging
		// for y := 0; y < grid.height; y += 1 {
		// 	rl.DrawLine(0, i32(f32(y) * grid.cell_size), WIDTH, i32(f32(y) * grid.cell_size), rl.DARKGRAY)
		// }
		// for x := 0; x < grid.width; x += 1 {
		// 	rl.DrawLine(i32(f32(x) * grid.cell_size), 0, i32(f32(x) * grid.cell_size), HEIGHT, rl.DARKGRAY)
		// }

		for i := 0; i < len(particles); i += 1 {
			particle := particles[i]
			// Optional: Color based on pressure or density
			pressure_color_factor := clamp(particle.p / (STIFFNESS * 0.5), 0.0, 1.0) // Example scaling
			particle_color := rl.ColorLerp(rl.BLUE, rl.RED, pressure_color_factor)
			rl.DrawCircleV(particle.pos, PARTICLE_RADIUS, particle_color)

			rl.DrawCircleV(particle.pos, PARTICLE_RADIUS, PARTICLE_COLOR)

			// Optional: Draw velocity vectors
			// rl.DrawLineV(particle.pos, particle.pos + particle.velocity * 0.05, rl.GREEN)
            // Optional: Draw smoothing radius for a few particles
            // if i % 50 == 0 {
            //     rl.DrawCircleLines(int(particle.pos.x), int(particle.pos.y), H, rl.ColorAlpha(rl.WHITE, 0.1))
            // }
		}
		rl.DrawFPS(10, 10)
        // Optional: Display particle count
        rl.DrawText(fmt.ctprintf("Particles: %d", len(particles)), 10, 30, 10, rl.WHITE)
		rl.EndDrawing()
	}
    rl.CloseWindow()
    // Delete dynamically allocated cell lists (Odin's GC might handle this, but explicit is clearer)
    for i in 0..<grid.height {
        for j in 0..<grid.width {
            delete(grid.cells[i][j].particles)
        }
        delete(grid.cells[i])
    }
    delete(grid.cells)
}