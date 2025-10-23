package main

import "core:fmt"
import "core:math/rand"
import rl "vendor:raylib"
import "../../../rlutil/ring"

// port of https://github.com/epsilon-phase/raylib-experiments/blob/canon/src/particle/main.c
WIDTH :: 480
HEIGHT :: 640
MAX_SIZE :: 20
MAX_SPEED :: 4.0

Particle :: struct {
	pos: rl.Vector2,
	ttl: int,
	size: f32,
	color: rl.Color,
}

Particle_Emitter :: struct {
	pos: rl.Vector2,
	lifetime_max: int,
	particle_count: int,
	wheel_house: []Particle,
}

colors := [?]rl.Color {
	{255, 0, 0, 255},  // Red
	{0, 255, 0, 255},  // green
	{0, 0, 255, 255},  // Blue
	{55, 55, 55, 255}, // Gray
}

particle_emitter_init :: proc(x, y, particle_count, lifetime_max: int) -> ^Particle_Emitter {
	result := new(Particle_Emitter)
	result.particle_count = particle_count
	result.pos.x = f32(x)
	result.pos.y = f32(y)
	result.lifetime_max = lifetime_max
	result.wheel_house = make([]Particle, particle_count)
	return result
}

particle_emitter_step :: proc(e: ^Particle_Emitter) {
	for i in 0..< e.particle_count {
		particle_step(e, &e.wheel_house[i])
	}
}

particle_step :: proc(e: ^Particle_Emitter, p: ^Particle) {
	p.pos = e.pos

	if p.ttl <= 0 {
		p.color = colors[rand.int_max(len(colors))]
		p.ttl = rand.int_max(e.lifetime_max)
		p.size = rand.float32_range(1, MAX_SIZE)
		return
	}
	p.ttl -= 1
	p.size = f32(clamp(MAX_SIZE * p.ttl / e.lifetime_max, 1.0, MAX_SIZE))
}

draw_particle :: #force_inline proc(p: ^Particle) {
	rl.DrawCircle(i32(p.pos.x), i32(p.pos.y), p.size, p.color)
}

draw_emitter :: proc(e: ^Particle_Emitter) {
	rl.DrawCircle(i32(e.pos.x), i32(e.pos.y), 3.0, rl.BLACK)
	for i in 0..< e.particle_count {
		draw_particle(&e.wheel_house[i])
	}
}

main :: proc() {
	rl.InitWindow(WIDTH, HEIGHT, "Particle Emitter")
	defer rl.CloseWindow()
	rl.SetTargetFPS(60)

	emitters := ring.Ring_Buffer(150, ^Particle_Emitter){}

	for !rl.WindowShouldClose() {
		if rl.IsMouseButtonDown(.LEFT) {
			mouse_pos := rl.GetMousePosition()
			ring.append(&emitters, particle_emitter_init(int(mouse_pos.x), int(mouse_pos.y), 50, 100))
		}
		{
			rl.BeginDrawing()
			defer rl.EndDrawing()
			rl.ClearBackground(rl.RAYWHITE)

			for i in 0..<emitters.len {
				draw_emitter(emitters.data[i])
			}
			rl.DrawFPS(10, 10)
		}
		for i in 0..<emitters.len {
			particle_emitter_step(emitters.data[i])
		}
	}
}