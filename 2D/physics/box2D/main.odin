package box

import b2 "vendor:box2d"
import rl "vendor:raylib"

Entity :: struct {
	body_id: b2.BodyId,
	pos:     rl.Vector2,
	dim:     rl.Vector2,
	col:     rl.Color,
	ang:     b2.Rot,
	move:    bool,
	type:    string,
}

C_Struct :: struct {
	c_enum: Colors,
	color:  rl.Color,
}

Selector :: enum {
	Ball,
	Box,
}

Colors :: enum {
	Green,
	Blue,
	Yellow,
	Purple,
	Orange,
}

WIDTH :: 1280
HEIGHT :: 720
time_step: f32
sub_steps: i32
world_id: b2.WorldId
entities: [dynamic]Entity
pause: bool
box_size: f32
ball_size: f32
selector: Selector
clr: [5]C_Struct
c_mode: [2]u8


main :: proc() {
	rl.SetConfigFlags({.MSAA_4X_HINT})
	rl.InitWindow(WIDTH, HEIGHT, "Box2D")
	rl.SetTargetFPS(1000)
	defer {
		rl.CloseWindow()
		destroy()
	}
	init_game()

	for !rl.WindowShouldClose() do update_game()
}

// procedures to help with printing text for simulation
dbg_game1 :: proc(val: $T, col: rl.Color = rl.RED, size: i32 = 20, x: i32 = 5, y: i32 = 0) {
	rl.DrawText(rl.TextFormat("%v", val), x, y, size, col)
}

dbg_game2 :: proc(
	val: $T,
	descrip: string,
	col: rl.Color = rl.RED,
	size: i32 = 20,
	x: i32 = 5,
	y: i32 = 0,
) {
	rl.DrawText(rl.TextFormat("%v: %v", descrip, val), x, y, size, col)
}

dbg_game :: proc {
	dbg_game1,
	dbg_game2,
}

// invert y position for box2d
invert_y :: proc(y, height: f32) -> f32 {
	return y + height
}

// translate box2d position to raylib coordinates
ray_pos :: proc(pos, dim: rl.Vector2, t: string, move: bool) -> rl.Vector2 {
	pos := pos
	if t == "box" {
		if !move do pos.y -= dim.y
		else {
			pos.x -= dim.x
			pos.y -= dim.y
		}
	}
	return pos
}

// init game with starting state
init_game :: proc() {
	c_mode = {0, 1}
	box_size = 20
	ball_size = 20
	selector = .Box
	pause = false
	time_step = 1.0 / 60
	sub_steps = 4
	clr = {
		{.Blue, rl.BLUE},
		{.Green, rl.GREEN},
		{.Yellow, rl.YELLOW},
		{.Purple, rl.PURPLE},
		{.Orange, rl.ORANGE},
	}
	clear(&entities)

	// initialize simulation world
	world_def := b2.DefaultWorldDef()
	world_def.gravity = b2.Vec2{0, 7}
	world_id = b2.CreateWorld(world_def)

	// walls
	box_entity_init({0, 600}, {1280, 120}, rl.GRAY, {}, false, "box", .1, .2)
	box_entity_init({0, 0}, {1, 720}, rl.GRAY, {}, false, "box", .1, .2)
	box_entity_init({1279, 0}, {1, 720}, rl.GRAY, {}, false, "box", .1, .2)
	// boxEntityInit({0, 1},    {1280, 1},    rl.GRAY,  false, "box", .1, .2)

}

// procedure to create boxes and balls
box_entity_init :: proc(
	pos, dim: rl.Vector2,
	col: rl.Color,
	ang: b2.Rot,
	move: bool,
	type: string,
	fric, dens: f32,
	a_dam: f32 = 0,
) {

	// body def
	body_def := b2.DefaultBodyDef()
	if move do body_def.type = .dynamicBody
	else do body_def.type = .staticBody
	body_def.position = b2.Vec2{pos.x, invert_y(pos.y, dim.y)}
	body_def.angularDamping = a_dam
	body_id := b2.CreateBody(world_id, body_def)

	// shape_def
	shape_def := b2.DefaultShapeDef()
	shape_def.material.friction = fric
	shape_def.density = dens

	// creates boxes and balls
	if type == "box" {
		box := b2.MakeBox(dim.x, dim.y)
		_ = b2.CreatePolygonShape(body_id, shape_def, box)
	} else if type == "ball" {
		circle := b2.Circle{{0, 0}, dim.x}
		_ = b2.CreateCircleShape(body_id, shape_def, circle)
	}

	// add entity to entities array
	ent := Entity{body_id, pos, dim, col, ang, move, type}
	append(&entities, ent)
}

game_controls :: proc() {
	// press 'r' to restart simulation
	if rl.IsKeyPressed(.R) do init_game()

	// pres 'space' to pause all motion
	if rl.IsKeyPressed(.SPACE) do pause = !pause

	// 'left click' add balls at mouse location and 'right click' add balls at mouse location
	if rl.IsMouseButtonPressed(.LEFT) do box_entity_init(rl.GetMousePosition(), {ball_size, ball_size}, clr[c_mode[0]].color, {1, 1}, true, "ball", .3, 1, .1)
	if rl.IsMouseButtonPressed(.RIGHT) do box_entity_init(rl.GetMousePosition(), {box_size, box_size}, clr[c_mode[1]].color, {1, 1}, true, "box", .3, 1, .1)

	// press 's' changes between boxes and balls for color and size changes
	if rl.IsKeyPressed(.S) {
		if selector == .Ball do selector = .Box
		else do selector = .Ball
	}

	// press 'up' or 'down' to change boxes and ball size depending on selector
	if rl.IsKeyPressed(.UP) {
		if selector == .Ball do ball_size += 1
		else do box_size += 1
	}
	if rl.IsKeyPressed(.DOWN) {
		if selector == .Ball do ball_size -= 1
		else do box_size -= 1
	}

	// pressing 'c' changes color of boxes and balls depending on selector
	if rl.IsKeyPressed(.C) {
		if selector == .Ball {
			if c_mode[0] != 4 do c_mode[0] += 1
			else do c_mode[0] = 0
		} else {
			if c_mode[1] != 4 do c_mode[1] += 1
			else do c_mode[1] = 0
		}
	}

	// press 'a' to slow simulation and 'd' to speed it up
	if rl.IsKeyPressed(.D) do time_step += .001
	if rl.IsKeyPressed(.A) do time_step -= .001
}

// updates simulation based on time step and sub steps
update_B2D :: proc() {
	if !pause {
		b2.World_Step(world_id, time_step, sub_steps)

		for &i in entities {
			i.pos = b2.Body_GetPosition(i.body_id)
			i.ang = b2.Body_GetRotation(i.body_id)
		}
	}
}

// draw all entities and text
draw :: proc() {
	rl.BeginDrawing()
	defer rl.EndDrawing()
	rl.ClearBackground(rl.BLACK)

	for &i in entities {
		using i
		if i.type == "box" {
			if move {
				rot := b2.Rot_GetAngle(b2.Body_GetRotation(body_id))
				posi := ray_pos(pos, dim, type, move)
				rl.DrawRectanglePro(
					{pos.x, pos.y, dim.x * 2, dim.y * 2},
					{dim.x, dim.y},
					rot * (180 / 3.14),
					col,
				)
			} else do rl.DrawRectangleV(ray_pos(pos, dim, type, move), dim, col)
		}
		if i.type == "ball" do rl.DrawCircleV(ray_pos(pos, dim, type, move), dim.x, col)
	}

	dbg_game(selector, rl.RED)
	dbg_game(box_size, "Box Size", clr[c_mode[1]].color, 20, 5, 30)
	dbg_game(ball_size, "Ball Size", clr[c_mode[0]].color, 20, 5, 60)

	if pause do rl.DrawText("PRESS SPACE TO CONTINUE", WIDTH / 2 - rl.MeasureText("PRESS SPACE TO CONTINUE", 40) / 2, HEIGHT / 2 - 50, 40, rl.RED)
}

update_game :: proc() {
	game_controls()
	update_B2D()
	draw()
}

destroy :: proc() {
	b2.DestroyWorld(world_id)
	delete(entities)
}