package main

import "../"

import rl "vendor:raylib"
import rlgl "vendor:raylib/rlgl"


main :: proc() {
	rl.InitWindow(1200, 600, "raytracer")
	rl.SetTargetFPS(80)

	deltaTime:f32

	camera := rl.Camera{}
	camera.position = rl.Vector3{15, 8, 15}
	camera.target = rl.Vector3{0, 0.5, 0}
	camera.up = rl.Vector3{0, 1, 0}
	camera.fovy = 45
	camera.projection = rl.CameraProjection.PERSPECTIVE

	rl.DisableCursor()

	engine := tracer.init(rl.Vector2{1200, 600}, 7, 10, 0.001)

	skyMaterial := tracer.SkyMaterial{ rl.WHITE, rl.SKYBLUE, rl.BROWN, rl.WHITE, rl.Vector3{-0.5, -1, -0.5}, 1, 0.5 }
	red := tracer.Material{
		{ 1, 1, 1, 1 },
		{ 1, 0, 0, 10 },
		{ 0, 0, 0, 0 },
	}
	red2 := tracer.Material{
		{ 1, 0.6, 0.6, 0 },
		{ 0, 0, 0, 0 },
		{ 0, 0, 0, 0 },
	}
	green := tracer.Material{
		{ 1, 1, 1, 1 },
		{ 0, 0, 1, 10 },
		{ 0, 0, 0, 0 },
	}
	blue := tracer.Material{
		{ 1, 1, 1, 1 },
		{ 0, 1, 0, 10 },
		{ 0, 0, 0, 0 },
	}
	white := tracer.Material{
		{ 1, 1, 1, 1 },
		{ 0, 0, 0, 0 },
		{ 0, 0, 0, 0 },
	}
	grey := tracer.Material{
		{ 0.5, 0.5, 0.5, 1 },
		{ 0, 0, 0, 0 },
		{ 0, 0, 0, 0 },
	}
	light := tracer.Material{
		{ 1, 0.8, 0.7, 1 },
		{ 1, 1, 1, 1.2 },
		{ 0, 0, 0, 0 },
	}
	metal := tracer.Material{
		{ 1, 1, 1, 1 },
		{ 0, 0, 0, 0 },
		{ 0, 1, 0, 0 },
	}
	dragon := rl.LoadModel("../assets/monkey.obj")
	dragon.transform = rl.MatrixTranslate(0, 1, -1)
	tracer.upload_raylib_model(engine, dragon, red2, false, 7)

	floor := rl.LoadModelFromMesh(rl.GenMeshPlane(50, 50, 1, 1))
	tracer.upload_raylib_model(engine, floor, white, true, 0)

	wall := rl.LoadModelFromMesh(rl.GenMeshPlane(50, 50, 1, 1))
	wall.transform = rl.MatrixRotateX(rl.PI / 2) * rl.MatrixTranslate(0, 0, -2)
	tracer.upload_raylib_model(engine, wall, white, true, 0)

	ceiling := rl.LoadModelFromMesh(rl.GenMeshPlane(50, 50, 1, 1))
	ceiling.transform = rl.MatrixRotateX(rl.PI) * rl.MatrixTranslate(0, 3, 0)
	tracer.upload_raylib_model(engine, ceiling, white, true, 0)

	lighting := rl.LoadModelFromMesh(rl.GenMeshCube(2, 1, 2))
	lighting.transform = rl.MatrixTranslate(0, 3, 0)
	tracer.upload_raylib_model(engine, lighting, light, true, 0)

	left := rl.LoadModelFromMesh(rl.GenMeshPlane(50, 50, 1, 1))
	left.transform = rl.MatrixRotateZ(rl.PI / 2) * rl.MatrixTranslate(-2, 0, 0)
	tracer.upload_raylib_model(engine, left, white, true, 0)

	right := rl.LoadModelFromMesh(rl.GenMeshPlane(50, 50, 1, 1))
	right.transform = rl.MatrixRotateZ(rl.PI / 2) * rl.MatrixTranslate(2, 0, 0)
	tracer.upload_raylib_model(engine, right, white, true, 0)

	tracer.upload_static_data(engine)

	for !rl.WindowShouldClose()
	{
		rl.UpdateCamera(&camera, rl.CameraMode.FREE)


		tracer.upload_data(engine, &camera)

		if rl.IsKeyPressed(.ONE) { engine.debug = !engine.debug }
		if rl.IsKeyPressed(.R) { engine.denoise = !engine.denoise }
		if rl.IsKeyPressed(.P) { engine.pause = !engine.pause }

		tracer.render(engine, &camera)

		deltaTime += rl.GetFrameTime()
	}
	
	rl.UnloadModel(dragon)
	rl.UnloadModel(floor)
	rl.UnloadModel(wall)
	rl.UnloadModel(left)
	rl.UnloadModel(right)
	rl.UnloadModel(ceiling)
	rl.UnloadModel(lighting)

	tracer.unload(engine)

	rl.CloseWindow()
}