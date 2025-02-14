package main

import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:math/rand"
import mui "vendor:microui"
import rl "vendor:raylib"

WINDOW_WIDTH :: 1000
WINDOW_HEIGHT :: 800

BOID_AMOUNT :: 100
BOID_SIZE :: 10
BOID_SPEED :: 100
BOID_VIEWING_ANGLE :: 140
BOID_VIEWING_RADIUS :: 70
BOID_TURNING_STR :: 80000
BOID_COHESION :: 300
BOID_ALIGNMENT_RADIUS :: 100
BOID_ALIGNMENT :: 300

Boid :: struct {
	id:    int,
	pos:   rl.Vector2,
	vel:   rl.Vector2,
	rot:   f32,
	color: rl.Color,
}

main :: proc() {
	rl.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "2D Boids")
	defer rl.CloseWindow()
	rl.SetTargetFPS(60)


	boids := make([]Boid, BOID_AMOUNT)
	for i in 0 ..< BOID_AMOUNT {
		boids[i] = random_boid(i)
	}

	for !rl.WindowShouldClose() {
		delta := rl.GetFrameTime()

		for &boid in boids {
			update_boid_position(&boid, boids, delta)
			update_boid_rotation(&boid)
		}

		rl.BeginDrawing()
		defer rl.EndDrawing()
		rl.ClearBackground(rl.DARKBLUE)

		for boid in boids {
			draw_boid(boid)
		}
	}
}

random_boid :: proc(id: int) -> Boid {
	return Boid {
		id = id,
		pos = {rand.float32_range(0, WINDOW_WIDTH), rand.float32_range(0, WINDOW_HEIGHT)},
		vel = {rand.float32_range(-200, 200), rand.float32_range(-200, 200)},
		rot = 0,
		color = rl.RAYWHITE,
	}
}

draw_boid :: proc(boid: Boid) {
	rl.DrawPoly(boid.pos, 3, BOID_SIZE, boid.rot, boid.color)
}

update_boid_position :: proc(boid: ^Boid, boids: []Boid, delta: f32) {

	update_separation(boid, boids, delta)
	update_cohesion(boid, boids, delta)
	update_alignment(boid, boids, delta)

	// Max Velocity 
	boid.vel = linalg.normalize(boid.vel) * 200

	boid.pos += boid.vel * delta
	if boid.pos.x > WINDOW_WIDTH {boid.pos.x = 0}
	if boid.pos.x < 0 {boid.pos.x = WINDOW_WIDTH}
	if boid.pos.y > WINDOW_HEIGHT {boid.pos.y = 0}
	if boid.pos.y < 0 {boid.pos.y = WINDOW_HEIGHT}
}

// This could use a little tweaking but is working okay. 
// Consider using a vision angle so they can't see behind themselves.
update_separation :: proc(boid: ^Boid, boids: []Boid, delta: f32) {
	for other_boid in boids {
		if boid.id != other_boid.id {
			dist := linalg.distance(boid.pos, other_boid.pos)
			if dist < BOID_VIEWING_RADIUS {
				// dist = max(dist, 0.1)
				dir := linalg.normalize(other_boid.pos - boid.pos)
				avoidance_dir := rl.Vector2{-dir.y, dir.x}
				if rand.int_max(2) > 1 {avoidance_dir = rl.Vector2{dir.y, -dir.x}}
				avoidance_str := BOID_TURNING_STR / (dist * dist)
				avoidance_force := avoidance_dir * avoidance_str
				boid.vel += avoidance_force * delta
			}
		}
	}
}

update_cohesion :: proc(boid: ^Boid, boids: []Boid, delta: f32) {
	sum := rl.Vector2{0, 0}
	for boid in boids {sum += boid.pos}
	avg := sum / f32(len(boids))
	dir := linalg.normalize(avg - boid.pos)
	cohesion_force := dir * BOID_COHESION
	boid.vel += cohesion_force * delta
}

update_alignment :: proc(boid: ^Boid, boids: []Boid, delta: f32) {

	count: f32 = 0
	sum := rl.Vector2{0, 0}
	for other_boid in boids {
		if boid.id != other_boid.id {
			dist := linalg.distance(boid.pos, other_boid.pos)
			if dist < BOID_ALIGNMENT_RADIUS {
				sum += other_boid.vel
				count += 1
			}
		}
	}

	if count > 0 {
		avg_vel := sum / count
		alignment := linalg.normalize(avg_vel - boid.vel) * BOID_ALIGNMENT
		boid.vel += alignment * delta
	}
}

update_boid_rotation :: proc(boid: ^Boid) {
	radians := math.atan2(boid.vel.y, boid.vel.x)
	boid.rot = radians * (180 / math.PI)
}