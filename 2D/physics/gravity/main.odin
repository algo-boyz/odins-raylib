package gravity_zone

import "core:fmt"
import "core:math"
import rl "vendor:raylib"
import "../../../rlutil/gif"

CELL_SIZE :: 30
CELL_COUNT :: 25
SCALE :: 30.0
G :: 6.67428e-11
HEIGHT :: 720
LENGTH :: 1280
MAX_OLD_POS :: 100

Position :: struct {
    x, y: f32,
}

Velocity2 :: struct {
    x, y: f32,
}

Body :: struct {
    pos: Position,
    mass: f64,
    radius: f32,
    speed: Velocity2,
    acceleration: f32,
    old_positions: [dynamic]Position,
    has_touched_low_ledge: bool,
    has_touched_top_ledge: bool,
    has_touched_left_ledge: bool,
    has_touched_right_ledge: bool,
}

View :: struct {}

body_init :: proc(pos: Position, mass: f64, radius: f32, speed: Velocity2) -> Body {
    return Body{
        pos = pos,
        mass = mass,
        radius = radius,
        speed = speed,
        old_positions = make([dynamic]Position, 0, MAX_OLD_POS),
        acceleration = 1.0,
    }
}

body_draw :: proc(b: Body, color: rl.Color) {
    screen_x := i32(b.pos.x * SCALE)
    screen_y := i32(b.pos.y * SCALE)
    screen_radius := b.radius * SCALE
    rl.DrawCircle(screen_x, screen_y, screen_radius, color)

    for e in b.old_positions {
        rl.DrawCircle(i32(e.x * SCALE), i32(e.y * SCALE), 2, color)
    }
}

body_check_touched_ledge :: proc(b: ^Body) {
    pos_y := b.pos.y + b.radius + 0.10
    pos_x := b.pos.x + b.radius
    pos_x_back := b.pos.x - b.radius - 0.17
    pos_y_top := b.pos.y - b.radius

    b.has_touched_low_ledge = pos_y >= f32(HEIGHT) / SCALE
    b.has_touched_top_ledge = pos_y_top <= 0
    b.has_touched_left_ledge = pos_x_back <= 0.5
    b.has_touched_right_ledge = pos_x >= f32(LENGTH) / SCALE
}

apply_gravity :: proc(b1, b2: ^Body) {
    b1.speed.y += 0.02 // Gravity constant, to be modified by G
    b1.pos.y += b1.speed.y
    b1.pos.x += b1.speed.x

    if len(b1.old_positions) >= MAX_OLD_POS {
        clear(&b1.old_positions)
    }
    append(&b1.old_positions, b1.pos)

    body_check_touched_ledge(b1)

    if b1.has_touched_low_ledge {
        b1.pos.y = (f32(HEIGHT) / SCALE) - b1.radius
        b1.speed.y *= -0.9
        b1.speed.x *= 0.9
    }
    if b1.has_touched_top_ledge {
        b1.pos.y = b1.radius
        b1.speed.y *= -0.9
        b1.speed.x *= 0.9
    }
    if b1.has_touched_right_ledge {
        b1.pos.x = (f32(LENGTH) / SCALE) - b1.radius
        b1.speed.y *= 0.9
        b1.speed.x *= -0.9
    }
    if b1.has_touched_left_ledge || collision_check(b1^, b2^) {
        b1.speed.x *= -0.9
        b1.speed.y *= -0.9
    }
}

calculate_distance :: proc(b1, b2: Body) -> f64 {
    dx := f64(b2.pos.x - b1.pos.x)
    dy := f64(b2.pos.y - b1.pos.y)
    return math.sqrt(dx * dx + dy * dy)
}

collision_check :: proc(b1, b2: Body) -> bool {
    distance := calculate_distance(b1, b2)
    radius_sum := f64(b1.radius + b2.radius)
    return distance <= radius_sum
}

view_debug_info :: proc(v: View, b1, b2: Body) {
    s_x := fmt.tprintf("%f", b1.speed.x)
    s_y := fmt.tprintf("%f", b1.speed.y)
    p_x := fmt.tprintf("%f", b1.pos.x)
    p_y := fmt.tprintf("%f", b1.pos.y)
    check := fmt.tprintf("%v", collision_check(b1, b2))
    acc := fmt.tprintf("%f", b1.acceleration)

    s_x2 := fmt.tprintf("%f", b2.speed.x)
    s_y2 := fmt.tprintf("%f", b2.speed.y)
    p_x2 := fmt.tprintf("%f", b2.pos.x)
    p_y2 := fmt.tprintf("%f", b2.pos.y)
    check2 := fmt.tprintf("%v", collision_check(b2, b1))
    acc2 := fmt.tprintf("%f", b2.acceleration)

    rl.DrawText(fmt.ctprintf("X speed: %s", s_x), 10, 10, 13, rl.WHITE)
    rl.DrawText(fmt.ctprintf("Y speed: %s", s_y), 10, 40, 13, rl.WHITE)
    rl.DrawText(fmt.ctprintf("X pos: %s", p_x), 10, 70, 13, rl.WHITE)
    rl.DrawText(fmt.ctprintf("Y pos: %s", p_y), 10, 100, 13, rl.WHITE)
    rl.DrawText(fmt.ctprintf("Collision: %s", check), 10, 130, 13, rl.WHITE)
    rl.DrawText(fmt.ctprintf("Accel: %s", acc), 10, 145, 13, rl.WHITE)

    rl.DrawText(fmt.ctprintf("X speed: %s", s_x2), 10, 160, 13, rl.BLUE)
    rl.DrawText(fmt.ctprintf("Y speed: %s", s_y2), 10, 190, 13, rl.BLUE)
    rl.DrawText(fmt.ctprintf("X pos: %s", p_x2), 10, 210, 13, rl.BLUE)
    rl.DrawText(fmt.ctprintf("Y pos: %s", p_y2), 10, 240, 13, rl.BLUE)
    rl.DrawText(fmt.ctprintf("Collision: %s", check2), 10, 270, 13, rl.BLUE)
    rl.DrawText(fmt.ctprintf("Accel: %s", acc2), 10, 285, 13, rl.BLUE)
}

main :: proc() {
    rl.InitWindow(LENGTH, HEIGHT, "Gravity Zone")
    rl.SetTargetFPS(60)
	rec := gif.new_recorder("preview.gif", 12, 600)
    defer gif.recorder_cleanup(&rec)
    bodies: [dynamic]Body
    defer delete(bodies)

    pos1 := Position{20, 20}
    pos2 := Position{30, 20}
    pos3 := Position{40, 20}

    planet := body_init(pos1, 50, 1, Velocity2{1, 1})
    planet2 := body_init(pos2, 50, 1, Velocity2{1, 1})
    planet3 := body_init(pos3, 50, 1, Velocity2{1, 0.5})

    append(&bodies, planet, planet2, planet3)

    v: View

    for !rl.WindowShouldClose() {
        gif.recorder_update(&rec)

        rl.BeginDrawing()
        rl.ClearBackground(rl.BLACK)
            body_draw(bodies[0], rl.WHITE)
            body_draw(bodies[1], rl.BLUE)
            body_draw(bodies[2], rl.GREEN)

            view_debug_info(v, bodies[0], bodies[1])

            apply_gravity(&bodies[0], &bodies[1])
            apply_gravity(&bodies[1], &bodies[0])
            apply_gravity(&bodies[2], &bodies[0])
            apply_gravity(&bodies[2], &bodies[1])
            apply_gravity(&bodies[0], &bodies[2])
            apply_gravity(&bodies[1], &bodies[2])
        rl.EndDrawing()
    }
    rl.CloseWindow()
}