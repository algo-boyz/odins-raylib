package Gnipahellir

import rl "vendor:raylib"

MAX_BUILDINGS :: 100

main :: proc() {

	screenWidth :: 800
	screenHeight :: 450

	rl.InitWindow(screenWidth, screenHeight, "raylib [core] example - 2d camera")

	player: rl.Rectangle = {400, 280, 40, 40}
	buildings := [MAX_BUILDINGS]rl.Rectangle{}
	buildColors := [MAX_BUILDINGS]rl.Color{}

	spacing := 0

	for i := 0; i < MAX_BUILDINGS; i += 1 {
		buildings[i].width = f32(rl.GetRandomValue(50, 200))
		buildings[i].height = f32(rl.GetRandomValue(100, 800))
		buildings[i].y = screenHeight - 130.0 - buildings[i].height
		buildings[i].x = -6000.0 + f32(spacing)

		spacing += int(buildings[i].width)

		buildColors[i] = {
			u8(rl.GetRandomValue(200, 240)),
			u8(rl.GetRandomValue(200, 240)),
			u8(rl.GetRandomValue(200, 250)),
			255,
		}
	}

	camera: rl.Camera2D = {0, 0, 0, 0}
	camera.target = {player.x + 20.0, player.y + 20.0}
	camera.offset = {screenWidth / 2.0, screenHeight / 2.0}
	camera.rotation = 0.0
	camera.zoom = 1.0

	rl.SetTargetFPS(60)

	// Main game loop
	for (!rl.WindowShouldClose()) {

		// Player movement
		if rl.IsKeyDown(.RIGHT) {
			player.x += 2
		} else if rl.IsKeyDown(.LEFT) {player.x -= 2}

		// Camera target follows player
		camera.target = {player.x + 20, player.y + 20}

		// Camera rotation controls
		if rl.IsKeyDown(
			.A,
		) {camera.rotation += -1} else if rl.IsKeyDown(.S) {camera.rotation += +1}

		// Limit camera rotation to 80 degrees (-40 to 40)
		if camera.rotation > 40 {
			camera.rotation = 40
		} else if camera.rotation < -40 {
			camera.rotation = -40
		}

		// Camera zoom controls
		camera.zoom += rl.GetMouseWheelMove() * 0.05

		if (camera.zoom > 3.0) {camera.zoom = 3.0} else if (camera.zoom < 0.1) {camera.zoom = 0.1}

		// Camera reset (zoom and rotation)
		if (rl.IsKeyPressed(.R)) {
			camera.zoom = 1.0
			camera.rotation = 0.0
		}

		rl.BeginDrawing()

		rl.ClearBackground(rl.RAYWHITE)

		rl.BeginMode2D(camera)

		rl.DrawRectangle(-6000, 320, 13000, 8000, rl.DARKGRAY)

		for i in 0 ..< MAX_BUILDINGS {
			rl.DrawRectangleRec(buildings[i], buildColors[i])
		}

		rl.DrawRectangleRec(player, rl.RED)

		rl.DrawLine(
			i32(camera.target.x),
			-screenHeight * 10,
			i32(camera.target.x),
			screenHeight * 10,
			rl.GREEN,
		)
		rl.DrawLine(
			-screenWidth * 10,
			i32(camera.target.y),
			screenWidth * 10,
			i32(camera.target.y),
			rl.GREEN,
		)

		rl.EndMode2D()

		rl.DrawText("SCREEN AREA", 640, 10, 20, rl.RED)

		rl.DrawRectangle(0, 0, screenWidth, 5, rl.RED)
		rl.DrawRectangle(0, 5, 5, screenHeight - 10, rl.RED)
		rl.DrawRectangle(screenWidth - 5, 5, 5, screenHeight - 10, rl.RED)
		rl.DrawRectangle(0, screenHeight - 5, screenWidth, 5, rl.RED)

		rl.DrawRectangle(10, 10, 250, 113, rl.Fade(rl.SKYBLUE, 0.5))
		rl.DrawRectangleLines(10, 10, 250, 113, rl.BLUE)

		rl.DrawText("Free 2d camera controls:", 20, 20, 10, rl.BLACK)
		rl.DrawText("- Right/Left to move Offset", 40, 40, 10, rl.DARKGRAY)
		rl.DrawText("- Mouse Wheel to Zoom in-out", 40, 60, 10, rl.DARKGRAY)
		rl.DrawText("- A / S to Rotate", 40, 80, 10, rl.DARKGRAY)
		rl.DrawText("- R to reset Zoom and Rotation", 40, 100, 10, rl.DARKGRAY)

		rl.EndDrawing()
	}

	rl.CloseWindow() // Close window and OpenGL context
}