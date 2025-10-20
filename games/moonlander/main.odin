package main

import rl "vendor:raylib"

g: ^Game

main_loop_content :: proc() {
	dt := rl.GetFrameTime()
	game_update(g, dt)
	game_draw(g)
}

main :: proc() {
	rl.InitWindow(WIDTH, HEIGHT, "Moonlander")
	rl.InitAudioDevice()
	rl.SetTargetFPS(60)

	g = init_game(WIDTH, HEIGHT)

	for !exit_window && !rl.WindowShouldClose() {
		main_loop_content()
	}
	destroy_game(g)
	free(g)

	rl.CloseAudioDevice()
	rl.CloseWindow()
}