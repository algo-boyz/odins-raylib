package main

import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:math/rand"
import "core:mem"
import "core:os"
import "core:time"
import rl "vendor:raylib"
import "../../../../../rlutil"

// based on: https://lisyarus.github.io/blog/posts/simulating-water-over-terrain.html

N :: 256
DT :: 0.001
G :: 10.0
FRICTION_FACTOR :: 1.0
VISCOSITY :: 0.0
SEDIMENT_CAPACITY_FACTOR :: 0.1
EROSION_RATE :: 1.0
DEPOSITION_RATE :: 10.0
CORIOLIS_FACTOR :: 0.01
MAX_PARTICLES :: 16 * 1024
PARTICLES_PER_FRAME :: 16
MAX_PARTICLE_LIFETIME :: MAX_PARTICLES / PARTICLES_PER_FRAME
sim_shader        : rl.Shader
sim_texture       : rl.Texture2D
sim_data_buffer   : []f32 // Buffer to hold float data for texture upload

// Uniform locations
simDataTexLoc     : i32
textureSizeLoc    : i32
lightDirectionLoc : i32
maxBedHeightLoc   : i32
maxWaterHeightLoc : i32
maxSedimentLoc    : i32

// Move these constants here to be accessible for uniforms
MAX_BED_HEIGHT_FOR_COLOR    :: 5.0
MAX_WATER_HEIGHT_FOR_COLOR  :: 2.0
MAX_SEDIMENT_FOR_COLOR      :: 1.0
LIGHT_DIRECTION_UNIFORM : [3]f32 // Use vec3 for uniform

Simulation_Area :: rl.Rectangle { -1.0, -1.0, 2.0, 2.0 }
Inner_Area : rl.Rectangle
Aspect_Ratio : f32

sim_time : f32

// Grid dimensions derived from N
Grid_Dim_X :: N
Grid_Dim_Y :: N
FlowX_Dim_X :: N + 1
FlowX_Dim_Y :: N
FlowY_Dim_X :: N
FlowY_Dim_Y :: N + 1

bed          : [dynamic][dynamic]f32 // Using dynamic for easier initialization, treat as fixed size
water        : [dynamic][dynamic]f32
flowx        : [dynamic][dynamic]f32 // Size [FlowX_Dim_Y][FlowX_Dim_X] -> [N][N+1]
flowy        : [dynamic][dynamic]f32 // Size [FlowY_Dim_Y][FlowY_Dim_X] -> [N+1][N]
velocity     : [dynamic][dynamic]rl.Vector2
sediment     : [dynamic][dynamic]f32
new_sediment : [dynamic][dynamic]f32 // Buffer for transport calculation

// Control Flags
paused         := true
show_water     := true
show_velocity  := false
show_particles := false
erosion_on     := false
rain_on        := false

Particle :: struct {
	position : rl.Vector2,
	lifetime : int,
}
particles : [dynamic]Particle

screen_width  : i32 = 1280
screen_height : i32 = 720


noise2d :: proc(x, y: f32) -> f32 {
	return rlutil.perlin_2d(x, y)  * 0.5 + 0.55
}

unlerp :: proc(min, max, value: f32) -> f32 {
	if max - min == 0 { return 0.5 } // Avoid division by zero, return midpoint
	return (value - min) / (max - min)
}

smooth_step :: proc(edge0, edge1, x: f32) -> f32 {
    t := clamp((x - edge0) / (edge1 - edge0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)
}

color_f32_to_u8 :: proc(r, g, b, a: f32) -> rl.Color {
    return rl.Color{
        cast(u8)clamp(r * 255.0, 0, 255),
        cast(u8)clamp(g * 255.0, 0, 255),
        cast(u8)clamp(b * 255.0, 0, 255),
        cast(u8)clamp(a * 255.0, 0, 255),
    }
}

vec2_length :: proc(v: rl.Vector2) -> f32 {
    return math.sqrt(v.x*v.x + v.y*v.y)
}

// Orthogonal vector (-y, x)
vec2_ort :: proc(v: rl.Vector2) -> rl.Vector2 {
    return rl.Vector2{-v.y, v.x}
}

// Allocate and initialize a 2D dynamic array with a value
make_2d_array_f32 :: proc(rows, cols: int, value: f32) -> [dynamic][dynamic]f32 {
	arr := make([dynamic][dynamic]f32, rows)
	for r in 0..<rows {
		arr[r] = make([dynamic]f32, cols)
		for c in 0..<cols {
			arr[r][c] = value
		}
	}
	return arr
}

make_2d_array_vec2 :: proc(rows, cols: int, value: rl.Vector2) -> [dynamic][dynamic]rl.Vector2 {
	arr := make([dynamic][dynamic]rl.Vector2, rows)
	for r in 0..<rows {
		arr[r] = make([dynamic]rl.Vector2, cols)
		for c in 0..<cols {
			arr[r][c] = value
		}
	}
	return arr
}

init_simulation :: proc() {
	// Calculate inner area (shrink by half a cell width)
    dx := Simulation_Area.width / N
    dy := Simulation_Area.height / N
    Inner_Area = rl.Rectangle{
        Simulation_Area.x + dx / 2.0,
        Simulation_Area.y + dy / 2.0,
        Simulation_Area.width - dx,
        Simulation_Area.height - dy,
    }

	// Allocate and initialize arrays
	bed          = make_2d_array_f32(Grid_Dim_Y, Grid_Dim_X, 0.0)
	water        = make_2d_array_f32(Grid_Dim_Y, Grid_Dim_X, 0.0)
	flowx        = make_2d_array_f32(FlowX_Dim_Y, FlowX_Dim_X, 0.0) // [N][N+1]
	flowy        = make_2d_array_f32(FlowY_Dim_Y, FlowY_Dim_X, 0.0) // [N+1][N]
	velocity     = make_2d_array_vec2(Grid_Dim_Y, Grid_Dim_X, rl.Vector2{0,0})
	sediment     = make_2d_array_f32(Grid_Dim_Y, Grid_Dim_X, 0.0)
	new_sediment = make_2d_array_f32(Grid_Dim_Y, Grid_Dim_X, 0.0)

	// Initialize terrain (bed) and water
	for y in 0..<N {
		for x in 0..<N {
			tx := (cast(f32)x + 0.5) / N
			ty := (cast(f32)y + 0.5) / N

			n := noise2d(tx, ty) // Base noise
			n = 0.5 * noise2d(tx, ty) + 0.5 * noise2d((2.0 * tx), (2.0 * ty)) // Octave
			dist_center := math.sqrt( (tx-0.5) * (tx-0.5) + (ty-0.5) * (ty-0.5) )
			n -= 0.5 * dist_center // Make center lower
			n = 5.0 * smooth_step(0.45, 0.55, n) // Sharpen features

			// // Island (Placeholder noise)
			// dist_center := math.sqrt( (tx-0.5)^2 + (ty-0.5)^2 )
			// n := 4.0 * math.max(0.0, 1.0 - 3.0 * dist_center + (2.0 * noise2d(tx, ty) - 1.0) * 0.25)

			// // Delta (Placeholder noise)
			// n := 4.0 * abs(2.0 * noise2d(tx, ty) - 1.0) * (1.0 - tx)

            // --- Assign bed height ---
            bed[y][x] = n

			// --- Initial water (Example: fill depressions up to level 1.0) ---
            water[y][x] = math.max(0.0, 1.0 - bed[y][x]) * (0.5 + 0.5 * noise2d(tx, ty)) // Add some noise to water

			// --- Initial flow (Example from C++) ---
            flowx[y][x] = (2.0 * ty - 1.0) * water[y][x] * 10.0 / N
		}
	}
	particles = make([dynamic]Particle, 0, MAX_PARTICLES)
}

update_simulation :: proc() {
	if paused { return }

    dx :: Simulation_Area.width / N
    dy :: Simulation_Area.height / N
    g_dt :: G * DT
    friction :: FRICTION_FACTOR // Already per-dt

    for x in 0..<N {
        flowy[0][x] = 0.0 // Top boundary
        flowy[N][x] = 0.0 // Bottom boundary (Index N is valid for flowy[N][x])
    }
    for y in 0..<N {
        flowx[y][0] = 0.0 // Left boundary
        flowx[y][N] = 0.0 // Right boundary (Index N is valid for flowx[y][N])
    }
    // Rain
    if rain_on {
        for y in 0..<N {
            for x in 0..<N {
                water[y][x] += rand.float32() * DT
            }
        }
    }
	for y in 0..<N {
		// Calculate boundary flow
		h_diff_wrap := (water[y][N-1] + bed[y][N-1]) - (water[y][0] + bed[y][0])
		flowx[y][0] = friction * flowx[y][0] + g_dt * h_diff_wrap // Update flow from x=N-1 to x=0
		// Update internal flows
		for x in 1..<N {
			h_diff := (water[y][x-1] + bed[y][x-1]) - (water[y][x] + bed[y][x])
			flowx[y][x] = friction * flowx[y][x] + g_dt * h_diff
		}
	}
	for x in 0..<N {
		// Update internal flows
		for y in 1..<N {
			h_diff := (water[y-1][x] + bed[y-1][x]) - (water[y][x] + bed[y][x])
			flowy[y][x] = friction * flowy[y][x] + g_dt * h_diff
		}
	}
	inv_dx_dy_dt := 1.0 / (dx * dy / DT)
	for y in 0..<N {
		for x in 0..<N {
			x_plus_1 := (x + 1) % N // Wrap index for right neighbor flow

			outflow := math.max(0.0, -flowx[y][x])         // Outflow left
			outflow += math.max(0.0,  flowx[y][x_plus_1])  // Outflow right
			outflow += math.max(0.0, -flowy[y][x])         // Outflow up
			outflow += math.max(0.0,  flowy[y+1][x])      // Outflow down (y+1 is safe due to N+1 dim)

            max_outflow := water[y][x] * dx * dy / DT // Max water that can leave cell in dt

			if outflow > 1e-9 { // Avoid scaling if no outflow
				scale := math.min(1.0, max_outflow / outflow)
				if scale < 0.999 { // Apply scaling only if significant
					if flowx[y][x] < 0.0      { flowx[y][x] *= scale }      // Scale outflow left
					if flowx[y][x_plus_1] > 0.0 { flowx[y][x_plus_1] *= scale } // Scale outflow right
					if flowy[y][x] < 0.0      { flowy[y][x] *= scale }      // Scale outflow up
					if flowy[y+1][x] > 0.0    { flowy[y+1][x] *= scale }    // Scale outflow down
                }
			}
		}
	}
    dt_over_area := DT / (dx * dy)
	for y in 0..<N {
		for x in 0..<N {
            w_old := water[y][x]
            x_plus_1 := (x + 1) % N

            // Net flow into cell (x, y)
            inflow_x  := flowx[y][x]        // From left (x-1) or wrap
            outflow_x := flowx[y][x_plus_1] // To right (x+1) or wrap
            inflow_y  := flowy[y][x]        // From top (y-1)
            outflow_y := flowy[y+1][x]      // To bottom (y+1)

            water[y][x] += (inflow_x - outflow_x + inflow_y - outflow_y) * dt_over_area
            water[y][x] = math.max(0.0, water[y][x]) // Ensure non-negative water

            // Compute average velocity in cell (x, y)
            w_avg := (w_old + water[y][x]) * 0.5
            vel := rl.Vector2{}
            if w_avg > 1e-6 {
                // Avg horizontal flow through the cell center
                avg_flow_x := (flowx[y][x] + flowx[y][x_plus_1]) * 0.5
                // Avg vertical flow through the cell center
                avg_flow_y := (flowy[y][x] + flowy[y+1][x]) * 0.5
				vel.x = avg_flow_x / (dy * w_avg) // Flow through YZ plane
				vel.y = avg_flow_y / (dx * w_avg) // Flow through XZ plane
				// If dx == dy:
				vel.x = avg_flow_x / (dx * w_avg)
				vel.y = avg_flow_y / (dy * w_avg)
            }
            velocity[y][x] = vel
		}
	}
    coriolis_factor_dt_half:f32 = CORIOLIS_FACTOR * DT * 0.5
    pi_half :f32 = math.PI / 2.0
    for y in 0..<N {
        latitude_factor := math.sin(pi_half * (f32(y) + 0.5) * 2.0 / (N - 1.0 )) // Sin(latitude) approx
        if abs(latitude_factor) < 1e-6 { continue } // Skip equator

        for x in 0..<N {
            vel := velocity[y][x]
            if vec2_length(vel) < 1e-6 { continue }

            // Coriolis force vector is orthogonal to velocity
            coriolis_v := vec2_ort(vel) * coriolis_factor_dt_half * latitude_factor

            // Apply force as impulse to surrounding flows (distribute impact)
			x_plus_1 := (x + 1) % N
            flowx[y][x]        += coriolis_v.x * 0.5 // Left face
            flowx[y][x_plus_1] += coriolis_v.x * 0.5 // Right face
            flowy[y][x]        += coriolis_v.y * 0.5 // Top face
            flowy[y+1][x]      += coriolis_v.y * 0.5 // Bottom face
        }
    }
    if erosion_on {
        // Erosion/Deposition based on capacity
        for y in 0..<N {
            for x in 0..<N {
                vel_len := vec2_length(velocity[y][x])
                // Capacity is proportional to water depth and velocity magnitude
                capacity := SEDIMENT_CAPACITY_FACTOR * water[y][x] * vel_len
                current_sed := sediment[y][x]
                delta : f32
                if capacity >= current_sed { // Potential for erosion
                    // Erode bed material, amount limited by availability and rate
                    potential_erosion := (capacity - current_sed) * EROSION_RATE * DT
                    delta = math.min(bed[y][x], potential_erosion)
                    bed[y][x]      -= delta
                    sediment[y][x] += delta
                } else { // Potential for deposition
                    // Deposit sediment, amount limited by availability and rate
                    potential_deposition := (current_sed - capacity) * DEPOSITION_RATE * DT
                    delta = math.min(current_sed, potential_deposition)
                    bed[y][x]      += delta
                    sediment[y][x] -= delta
                }
            }
        }
        inv_n := 1.0 / N
        for y in 0..<N {
            for x in 0..<N {
				current_pos := rl.Vector2{f32(x) + 0.5, f32(y) + 0.5}
				vel_grid := rl.Vector2{
					velocity[y][x].x * N / Simulation_Area.width,
					velocity[y][x].y * N / Simulation_Area.height,
				}
                prev_pos := current_pos - (vel_grid * DT)
                prev_pos.x = clamp(prev_pos.x, 0.5, N - 0.5)
                prev_pos.y = clamp(prev_pos.y, 0.5, N - 0.5)

                // Find 4 neighboring cells and interpolation weights
				// Subtract 0.5 to get bottom-left integer index
                ix := int(math.floor(prev_pos.x - 0.5))
                iy := int(math.floor(prev_pos.y - 0.5))
                tx := prev_pos.x - 0.5 - f32(ix) // Fractional part for x interpolation
                ty := prev_pos.y - 0.5 - f32(iy) // Fractional part for y interpolation
				// Clamp indices to valid range [0, N-2] to access ix+1, iy+1 safely
				ix = clamp(ix, 0, N - 2)
				iy = clamp(iy, 0, N - 2)
                // Bilinear interpolation
                s00 := sediment[iy][ix]
                s10 := sediment[iy][ix+1]
                s01 := sediment[iy+1][ix]
                s11 := sediment[iy+1][ix+1]

                new_sediment[y][x] = math.lerp(math.lerp(s00, s10, tx), math.lerp(s01, s11, tx), ty)
            }
        }
        // Swap buffers
        sediment, new_sediment = new_sediment, sediment // Swap pointers/slices
    }
	// Spawn new particles
    for i in 0..<PARTICLES_PER_FRAME {
        if len(particles) < MAX_PARTICLES {
			// Spawn randomly, but only where there is some water
            spawn_x := rand.float32() * N
            spawn_y := rand.float32() * N
            ix := clamp(cast(int)math.floor(spawn_x), 0, N-1)
            iy := clamp(cast(int)math.floor(spawn_y), 0, N-1)
            if water[iy][ix] > 1e-3 {
                append(&particles, Particle{
                    position = rl.Vector2{spawn_x, spawn_y},
                    lifetime = 0,
                })
            }
        }
    }
	// Update particle positions and lifetime
    for i in 0..<len(particles) {
		p := &particles[i]
		// Get velocity at particle position (use integer floor for grid cell)
		ix := clamp(cast(int)math.floor(p.position.x), 0, N-1)
		iy := clamp(cast(int)math.floor(p.position.y), 0, N-1)

		vel_sim := velocity[iy][ix]
		vel_grid_dt := rl.Vector2 {
			vel_sim.x * (N / Simulation_Area.width) * DT,
			vel_sim.y * (N / Simulation_Area.height) * DT,
		}
		p.position = p.position + vel_grid_dt
		// Wrap particle X position (toroidal world)
		p.position.x = fmod(p.position.x + N, N) // Ensure positive result for fmod
		// Clamp particle Y position (non-wrapping boundaries)
		p.position.y = clamp(p.position.y, 0.0, cast(f32)N) // Allow up to N for interpolation
		p.lifetime += 1
    }

	// Destroy old particles (swap-and-pop)
    i := 0
    for i < len(particles) {
        if particles[i].lifetime >= MAX_PARTICLE_LIFETIME {
            // Swap with last element and remove last
            particles[i] = particles[len(particles)-1]
            pop(&particles)
            // Don't increment i, process the swapped element next
        } else {
            i += 1 // Move to next particle
        }
    }
	// Increment time
	sim_time += DT
}

draw_simulation :: proc(camera: rl.Camera2D) {
	rl.BeginMode2D(camera)

	invN:f32 = 1.0 / N
	cell_width := Simulation_Area.width * invN
	cell_height := Simulation_Area.height * invN

	// Draw grid cells (bed, water, sediment)
	for y in 0..<N {
		for x in 0..<N {
			// Cell boundaries in simulation coordinates
            cell_x := Simulation_Area.x + cast(f32)x * cell_width
            cell_y := Simulation_Area.y + cast(f32)y * cell_height
            cell_rect := rl.Rectangle{cell_x, cell_y, cell_width, cell_height}

            // Calculate colors based on height/amount (using exponential falloff)
            b := 1.0 - math.exp(-1.0 * bed[y][x])
            w := 1.0 - math.exp(-1.0 * water[y][x])
            s := 1.0 - math.exp(-1.0 * sediment[y][x])

            // bed_color := color_f32_to_u8(0.96, 0.72, 0.53, b) // sandy color
			bed_color := color_f32_to_u8(0.3, 0.5, 0.1, b)       // green bed

            rl.DrawRectangleRec(cell_rect, bed_color)

            if show_water {
                water_color := color_f32_to_u8(0.0, 0.25, 1.0, w)
				// Make water slightly opaque if deep enough
				if water[y][x] > 1e-3 { water_color.a = clamp(water_color.a, 128, 255) } // Simple boost

                sediment_color := color_f32_to_u8(1.0, 0.25, 0.0, s * w) // Sediment only visible in water

                rl.DrawRectangleRec(cell_rect, water_color)
                rl.DrawRectangleRec(cell_rect, sediment_color)
            }
		}
	}

	// Draw velocity vectors
    if show_velocity {
        max_vel_display_length:f32 = 0.05 // Max length in simulation units
        vel_scale_factor:f32 = 1.0 / 40.0
        for y in 0..<N {
            for x in 0..<N {
                // Cell center in simulation coordinates
                center_x := Simulation_Area.x + (cast(f32)x + 0.5) * cell_width
                center_y := Simulation_Area.y + (cast(f32)y + 0.5) * cell_height
                center := rl.Vector2{center_x, center_y}

				// Scale velocity for display
                v := velocity[y][x] * water[y][x] * vel_scale_factor
                v_len := vec2_length(v)

                if v_len > 1e-6 {
					display_len := math.min(v_len, max_vel_display_length)
					v_norm := rl.Vector2Normalize(v)
					d := v_norm * display_len * 0.5 // Half length for centered line

                    start_pos := center - d
                    end_pos := center + d

					line_thickness := clamp(display_len * 20.0, 1.0, 3.0)
                    rl.DrawLineEx(start_pos, end_pos, 0.002, rl.WHITE) // Use pixel for thickness
                }
            }
        }
    }
	// Draw particles
    if show_particles {
        particle_radius_sim:f32 = 0.005 // Radius in simulation units
        for p in particles {
            sim_x := math.lerp(Simulation_Area.x, Simulation_Area.x + Simulation_Area.width, p.position.x * invN)
            sim_y := math.lerp(Simulation_Area.y, Simulation_Area.y + Simulation_Area.height, p.position.y * invN)
            sim_pos := rl.Vector2{sim_x, sim_y}
            rl.DrawCircleV(sim_pos, particle_radius_sim, rl.Fade(rl.WHITE, 0.5)) // Semi-transparent white
        }
    }
	rl.EndMode2D()

    mouse_pos_screen := rl.GetMousePosition()
    mouse_pos_world := rl.GetScreenToWorld2D(mouse_pos_screen, camera)

    // Convert world pos to grid index
    mx_f := unlerp(Simulation_Area.x, Simulation_Area.x + Simulation_Area.width, mouse_pos_world.x) * N
    my_f := unlerp(Simulation_Area.y, Simulation_Area.y + Simulation_Area.height, mouse_pos_world.y) * N
    mx := int(math.floor(mx_f))
    my := int(math.floor(my_f))

    // Display info if mouse is over the grid
    if mx >= 0 && mx < N && my >= 0 && my < N {
        b := bed[my][mx]
        w := water[my][mx]
        h := b + w
        s := sediment[my][mx]
        debug_text1 := fmt.ctprintf("Pos: (%d,%d) Bed: %.3f + Water: %.3f = Height: %.3f", mx, my, b, w, h)
        debug_text2 := fmt.ctprintf("Sediment: %.3f", s)

        // Draw text relative to top-left in screen space for simplicity
        rl.DrawText(debug_text1, 10, 30, 15, rl.PURPLE)
        rl.DrawText(debug_text2, 10, 45, 15, rl.PURPLE)

        if rl.IsMouseButtonDown(.LEFT) {
            brush_radius :: 2
            for dy in -brush_radius..=brush_radius {
                for dx in -brush_radius..=brush_radius {
                    cx := mx + dx
                    cy := my + dy
                    if cx >= 0 && cx < N && cy >= 0 && cy < N {
						// Add a fixed amount per frame/click
						water[cy][cx] += 10.0 * DT
                    }
                }
            }
        }
    }
    particle_text := fmt.ctprintf("%d particles", len(particles))
    rl.DrawText(particle_text, 10, 10, 20, rl.BLACK)
	controls_text :: "[SPACE] Pause [W] Water [V] Velocity [P] Particles [E] Erosion [R] Rain"
	rl.DrawText(controls_text, 10, screen_height - 20, 10, rl.DARKGRAY)

}

handle_input :: proc() {
    if rl.IsKeyPressed(.SPACE) { paused = !paused }
    if rl.IsKeyPressed(.W) { show_water = !show_water }
    if rl.IsKeyPressed(.V) { show_velocity = !show_velocity }
    if rl.IsKeyPressed(.P) { show_particles = !show_particles }
    if rl.IsKeyPressed(.E) { erosion_on = !erosion_on }
    if rl.IsKeyPressed(.R) { rain_on = !rain_on }
}

main :: proc() {
	rl.SetConfigFlags({.MSAA_4X_HINT, .VSYNC_HINT})
	rl.InitWindow(screen_width, screen_height, "Odin Water 2D Simulation")
	rl.SetTargetFPS(60)

	init_simulation()
	
    camera := rl.Camera2D{
		offset = rl.Vector2{f32(screen_width) / 2, f32(screen_height) / 2},
		target = rl.Vector2{ // Center of simulation area
			Simulation_Area.x + Simulation_Area.width / 2,
			Simulation_Area.y + Simulation_Area.height / 2,
		},
		rotation = 0.0,
		zoom = 1.0, // Initial zoom
	}
    // Calculate zoom to fit the simulation area width or height, whichever is larger relative to screen aspect
    Aspect_Ratio = f32(screen_width) / f32(screen_height)
	if Simulation_Area.width / f32(screen_width) > Simulation_Area.height / f32(screen_height) {
		camera.zoom = f32(screen_width) / Simulation_Area.width
	} else {
		camera.zoom = f32(screen_height) / Simulation_Area.height
	}
	// Add small padding
	camera.zoom *= 0.9

    for !rl.WindowShouldClose() {
		handle_input()

		// For DT=0.001, running 10-16 steps per frame at 60 FPS seems reasonable.
        steps_per_frame :: 10
        if !paused {
            for i in 0..<steps_per_frame {
		        update_simulation()
            }
        }
		rl.BeginDrawing()
		rl.ClearBackground(rl.RAYWHITE)
		draw_simulation(camera)
		rl.DrawFPS(screen_width - 90, 10)
		rl.EndDrawing()
	}
	for row in bed { delete(row) }
	delete(bed)
	for row in water { delete(row) }
	delete(water)
	for row in flowx { delete(row) }
	delete(flowx)
	for row in flowy { delete(row) }
	delete(flowy)
	for row in velocity { delete(row) }
	delete(velocity)
	for row in sediment { delete(row) }
	delete(sediment)
	for row in new_sediment { delete(row) }
	delete(new_sediment)
	delete(particles)
	rl.CloseWindow()
}

fmod :: proc(x, y: f32) -> f32 {
	if y == 0 { return 0 }
    return x - math.trunc(x / y) * y
}