package main

import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:math/rand"
import "core:time"

import "vendor:raylib"

Vec2 :: [2]f32
Vec3 :: [3]f32

dot :: linalg.dot

Color :: raylib.Color

WIDTH :: 800
HEIGHT :: 600

TARGET_FPS :: 240

UPDATE_RATE :: 480 // Hz
UPDATE_TIME :: time.Second / time.Duration(UPDATE_RATE) // ns

GRAVITY :: 1
DAMPING :: 0.90

particles: #soa[dynamic]Particle
dynamics: #soa[dynamic]Dynamics2D
springs: #soa[dynamic]Spring

Spring :: struct {
	body1_index:     i32,
	body2_index:     i32,
	spring_constant: f32,
	rest_length:     f32,
}

Dynamics2D :: struct {
	inv_mass:     f32, // 1 / mass
	damping:      f32,
	force:        Vec2,
	position:     Vec2,
	velocity:     Vec2,
	acceleration: Vec2,
}

get_inv_mass :: proc(mass: f32) -> f32 {
	return 1 / mass
}

set_mass :: proc(dyn: ^Dynamics2D, mass: f32) {
	dyn.inv_mass = 1 / mass
}

Particle :: struct {
	size:     Vec2,
	color:    Color,
	dynamics: i32, // index into dynamics
}

make_particle :: proc(
	size: Vec2,
	color: Color = raylib.GRAY,
	inv_mass: f32 = 0,
	damping: f32 = DAMPING,
	force: Vec2 = {},
	position: Vec2 = {},
	velocity: Vec2 = {},
	acceleration: Vec2 = {},
) -> Particle {
	dyn := Dynamics2D{inv_mass, damping, force, position, velocity, acceleration}
	index := i32(len(dynamics))
	append(&dynamics, dyn)

	return Particle{size, color, index}
}

draw_particles :: proc() {
	for particle in particles {
		dyn := dynamics[particle.dynamics]
		raylib.DrawRectangleV(dyn.position, particle.size, particle.color)
	}
}

integrate :: proc(time_step: f32) {
	for &dyn in dynamics {
		dyn.position += dyn.velocity * time_step

		dyn.acceleration = dyn.force * dyn.inv_mass

		dyn.velocity += dyn.acceleration * time_step
		dyn.velocity *= math.pow(dyn.damping, time_step)

		dyn.force = {}
	}
}

apply_gravity :: proc() {
	for &dyn, i in dynamics {
		dyn.force += {0, GRAVITY}
	}
}

apply_springs :: proc() {
	for spring in springs {
		body1 := &dynamics[spring.body1_index]
		body2 := &dynamics[spring.body2_index]

		spring_vector := body1.position - body2.position

		spring_length := linalg.vector_length(spring_vector)
		assert(spring_length != 0)

		displacement := spring_length - spring.rest_length

		force_length := spring.spring_constant * displacement
		force_direction := spring_vector / spring_length

		spring_force := force_direction * force_length

		body1.force -= spring_force
		body2.force += spring_force
	}
}

update :: proc(time_step: f32) {
	apply_gravity()
	apply_springs()
	//apply_drag()

	integrate(time_step)
}

draw :: proc() {
	raylib.BeginDrawing()

	raylib.ClearBackground(raylib.RAYWHITE)

	draw_particles()

	raylib.EndDrawing()
}

main :: proc() {
	raylib.SetTraceLogLevel(raylib.TraceLogLevel.WARNING)
	raylib.InitWindow(WIDTH, HEIGHT, "Physics solver")
	defer raylib.CloseWindow()

	raylib.SetTargetFPS(TARGET_FPS)

	p1 := make_particle(
		size = {10, 10},
		position = {WIDTH / 2.0, 100},
		inv_mass = get_inv_mass(1),
		color = raylib.MAROON,
	)
	append(&particles, p1)

	p2 := make_particle(
		size = {10, 10},
		position = {WIDTH / 2.0, 200},
		inv_mass = 0, // immovable
		color = raylib.DARKBLUE,
	)
	append(&particles, p2)

	spring := Spring {
		body1_index     = p1.dynamics,
		body2_index     = p2.dynamics,
		spring_constant = 4,
		rest_length     = 2,
	}
	append(&springs, spring)

	accumulator: time.Duration = 0
	for !raylib.WindowShouldClose() {
		accumulator += time.Duration(f64(raylib.GetFrameTime()) * f64(time.Second))

		for accumulator >= UPDATE_TIME {
			update_time_seconds := cast(f32)time.duration_seconds(UPDATE_TIME)
			update(update_time_seconds)
			accumulator -= UPDATE_TIME
		}

		draw()
	}
}