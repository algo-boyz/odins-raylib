package main

import "core:math"
import rl "vendor:raylib"

MAX_POINTS :: 1000
MAX_CONSTRAINTS :: 1000
POINT_SIZE :: 25
EDGE_SIZE :: 10
GRAVITY_ACC :: 0.3
DAMPING :: 1.0
RESTITUTION :: 1.0

Point :: struct {
    x, x_prv, x_nxt, acc: rl.Vector2,
}

Constraint :: struct {
    a, b: int,
    distance: f32,
}

World :: struct {
    points: [MAX_POINTS]Point,
    constraints: [MAX_CONSTRAINTS]Constraint,
    num_points: int,
    num_constraints: int,
}

clamp_range :: proc(value, min, max: f32) -> f32 {
    if value < min {
        return min
    } else if value > max {
        return max
    }
    return value
}

world_add_point :: proc(world: ^World, px, py, vx, vy: f32) -> int {
    if world.num_points >= MAX_POINTS {
        return -1
    }

    point := Point{}
    point.x = rl.Vector2{px, py}
    point.x_prv = rl.Vector2{px - vx, py - vy}
    point.x_nxt = rl.Vector2{px, py}
    point.acc = rl.Vector2{0, GRAVITY_ACC}

    world.points[world.num_points] = point
    world.num_points += 1
    return world.num_points - 1
}

world_add_constraint :: proc(world: ^World, a, b: int, distance: f32) -> int {
    if world.num_constraints >= MAX_CONSTRAINTS {
        return -1
    }

    constraint := Constraint{}
    constraint.a = a
    constraint.b = b
    constraint.distance = distance

    world.constraints[world.num_constraints] = constraint
    world.num_constraints += 1
    return world.num_constraints - 1
}

world_add_random_point :: proc(world: ^World) -> int {
    px := f32(rl.GetRandomValue(POINT_SIZE, rl.GetScreenWidth() - POINT_SIZE))
    py := f32(rl.GetRandomValue(POINT_SIZE, rl.GetScreenHeight() - POINT_SIZE))
    vx := f32(rl.GetRandomValue(-5, 5))
    vy := f32(rl.GetRandomValue(-5, 5))
    return world_add_point(world, px, py, vx, vy)
}

world_add_random_pair :: proc(world: ^World) {
    // Pick a random midpoint, angle, and length
    angle := f32(rl.GetRandomValue(0, 360)) * math.RAD_PER_DEG
    length := f32(rl.GetRandomValue(50, 200))
    offset := POINT_SIZE + i32(length * 0.5)
    midx := f32(rl.GetRandomValue(offset, rl.GetScreenWidth() - offset))
    midy := f32(rl.GetRandomValue(offset, rl.GetScreenHeight() - offset))

    // Calculate the end points
    px1 := midx + math.cos(angle) * length * 0.5
    py1 := midy + math.sin(angle) * length * 0.5
    px2 := midx - math.cos(angle) * length * 0.5
    py2 := midy - math.sin(angle) * length * 0.5
    vx1 := f32(rl.GetRandomValue(-5, 5))
    vy1 := f32(rl.GetRandomValue(-5, 5))
    vx2 := f32(rl.GetRandomValue(-5, 5))
    vy2 := f32(rl.GetRandomValue(-5, 5))

    // Add the points and constraints
    a := world_add_point(world, px1, py1, vx1, vy1)
    b := world_add_point(world, px2, py2, vx2, vy2)
    world_add_constraint(world, a, b, length)
}

world_update :: proc(world: ^World) {
    for i := 0; i < world.num_points; i += 1 {
        p := &world.points[i]

        // Verlet integration to update position
        // x_t+1 = x_t + (x_t - x_t-1) * damping + a_t
        p.x_nxt.x = p.x.x + (p.x.x - p.x_prv.x) * DAMPING + p.acc.x
        p.x_nxt.y = p.x.y + (p.x.y - p.x_prv.y) * DAMPING + p.acc.y
    }

    for i := 0; i < world.num_constraints; i += 1 {
        a := &world.points[world.constraints[i].a]
        b := &world.points[world.constraints[i].b]

        // Distance constraints on points
        // Ensure a.x_t+1 and b.x_t+1 are 'distance' apart
        dx := b.x_nxt.x - a.x_nxt.x
        dy := b.x_nxt.y - a.x_nxt.y
        d := math.sqrt(dx * dx + dy * dy)
        diff := (world.constraints[i].distance - d) / d
        a.x_nxt.x -= dx * 0.5 * diff
        a.x_nxt.y -= dy * 0.5 * diff
        b.x_nxt.x += dx * 0.5 * diff
        b.x_nxt.y += dy * 0.5 * diff
    }

    for i := 0; i < world.num_points; i += 1 {
        p := &world.points[i]

        // Clamp positions to screen and update previous position
        // Clamp x_t+1 to screen and override x_t and x_t-1 to (x_t+1 + v_t * restitution)
        if p.x_nxt.x < POINT_SIZE || p.x_nxt.x > f32(rl.GetScreenWidth() - POINT_SIZE) {
            v_x := p.x.x - p.x_prv.x
            p.x_nxt.x = clamp_range(p.x_nxt.x, POINT_SIZE, f32(rl.GetScreenWidth() - POINT_SIZE))
            p.x.x = p.x_nxt.x + v_x * RESTITUTION
        }
        if p.x_nxt.y < POINT_SIZE || p.x_nxt.y > f32(rl.GetScreenHeight() - POINT_SIZE) {
            v_y := p.x.y - p.x_prv.y
            p.x_nxt.y = clamp_range(p.x_nxt.y, POINT_SIZE, f32(rl.GetScreenHeight() - POINT_SIZE))
            p.x.y = p.x_nxt.y + v_y * RESTITUTION
        }

        // Update positions
        // p_t-1 = p_t and p_t = p_t+1
        p.x_prv.x = p.x.x
        p.x_prv.y = p.x.y
        p.x.x = p.x_nxt.x
        p.x.y = p.x_nxt.y
    }
}

world_draw :: proc(world: ^World) {
    for i := 0; i < world.num_constraints; i += 1 {
        a := world.points[world.constraints[i].a]
        b := world.points[world.constraints[i].b]
        rl.DrawLineEx(a.x, b.x, EDGE_SIZE, rl.WHITE)
    }

    for i := 0; i < world.num_points; i += 1 {
        p := &world.points[i]
        rl.DrawCircleV(p.x, POINT_SIZE, rl.WHITE)
        rl.DrawCircleV(p.x, POINT_SIZE - EDGE_SIZE, rl.Color{44, 41, 53, 255})
    }
}

main :: proc() {
    rl.InitWindow(1200, 700, "Verlet Physics")
    rl.SetTargetFPS(60)

    world := World{}

    world_add_point(&world, 450, 500, 5, 0)
    world_add_point(&world, 600, 600, 0, 5)
    world_add_constraint(&world, 0, 1, 150)

    for !rl.WindowShouldClose() {
        world_update(&world)

        if rl.IsKeyPressed(.SPACE) {
            world_add_random_pair(&world)
        }

        rl.BeginDrawing()
        rl.ClearBackground(rl.Color{44, 41, 53, 255})
        world_draw(&world)
        rl.EndDrawing()
    }

    rl.CloseWindow()
}