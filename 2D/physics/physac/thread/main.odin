package physac

import "core:thread"

import rl "vendor:raylib"

import physac "../physac"

_physics_loop :: proc(^thread.Thread) {
    PhysicsLoop(nil)
}

main :: proc() {
    screenWidth :f32 = 800.0
    screenHeight :f32 = 450.0
    rl.InitWindow(i32(screenHeight), i32(screenHeight), "raylib-odin :: physac example")
    rl.SetTargetFPS(60)

    InitPhysics()
    if t := thread.create(_physics_loop); t!= nil{
        t.init_context = context
        thread.start(t)
    }

    defer ClosePhysics()

    floor := CreatePhysicsBodyRectangle({ screenWidth / 2.0, screenHeight}, 500, 100, 10)
    floor.enabled = false

    circle := CreatePhysicsBodyCircle({ screenWidth / 2.0, screenHeight / 2.0}, 45, 10)
    circle.enabled = false

    for !rl.WindowShouldClose() {
        // Physics body creation inputs
        if rl.IsMouseButtonPressed(rl.MouseButton.LEFT) do CreatePhysicsBodyPolygon(rl.GetMousePosition(), f32(rl.GetRandomValue(20, 80)), int(rl.GetRandomValue(3, 8)), 10)
        else if rl.IsMouseButtonPressed(rl.MouseButton.RIGHT) do CreatePhysicsBodyCircle(rl.GetMousePosition(), f32(rl.GetRandomValue(10, 45)), 10)

        // Destroy falling physics bodies
        {
            bodies_count := GetPhysicsBodiesCount()
            for i in 0..<bodies_count - 1 {
                body := GetPhysicsBody(i)
                if body != nil && body.position.y > screenHeight*2 do DestroyPhysicsBody(body)
            }
        }

        rl.BeginDrawing()
        defer rl.EndDrawing()

        rl.ClearBackground(rl.RAYWHITE)

        bodies_count := GetPhysicsBodiesCount()
        for i in 0..<bodies_count - 1 {
            body := GetPhysicsBody(i)
            if body == nil do continue

            vertex_count := GetPhysicsShapeVerticesCount(i)
            for j in 0..<vertex_count - 1 {
                vertex_a := GetPhysicsShapeVertex(body, j)

                jj := ((j + 1) < vertex_count) ? (j + 1) : 0

                vertex_b := GetPhysicsShapeVertex(body, jj)

                rl.DrawLineV(vertex_a, vertex_b, rl.GREEN)
            }

        }
    }

    rl.CloseWindow()
}