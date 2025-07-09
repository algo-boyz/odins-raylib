package others

import "vendor:raylib"

main :: proc() {
	using raylib

	screenWidth  :: 800
	screenHeight :: 450

	InitWindow(screenWidth, screenHeight, "Angles")
	defer CloseWindow()

	v0: Vector2 = {screenWidth/2, screenHeight/2}
	v1: Vector2 = v0 + {100, 80}
	v2: Vector2 = {}

	angle: f32
	angleMode: bool

	SetTargetFPS(60)

	for !WindowShouldClose() {
		startAngle: f32

		if !angleMode { startAngle = -Vector2LineAngle(v0, v1) * RAD2DEG }
		if  angleMode { startAngle = 0 }

		v2 = GetMousePosition()

		if IsKeyPressed(.SPACE) {
			angleMode = !angleMode
		}

		if !angleMode && IsMouseButtonDown(.RIGHT) {
			v1 = GetMousePosition()
		}

		if !angleMode {
			v1Normal := Vector2Normalize(v1 - v0)
			v2Normal := Vector2Normalize(v2 - v0)
			
			// Calculate the basic angle between vectors (0 to 180 degrees)
			basicAngle := Vector2Angle(v1Normal, v2Normal) * RAD2DEG
			
			// Use cross product to determine direction
			// Cross product in 2D: a.x * b.y - a.y * b.x
			crossProduct := v1Normal.x * v2Normal.y - v1Normal.y * v2Normal.x
			
			// If cross product is negative, we're going clockwise (need to make angle negative)
			// If cross product is positive, we're going counterclockwise (angle stays positive)
			if crossProduct < 0 {
				angle = -basicAngle
			} else {
				angle = basicAngle
			}
		} else {
			angle = Vector2LineAngle(v0, v2) * RAD2DEG
		}

		{
			BeginDrawing()
                ClearBackground(RAYWHITE)

                if !angleMode {
                    DrawText("MODE 0: Angle between V1 and V2", 10, 10, 20, BLACK)
                    DrawText("Right Click to Move V1", 10, 30, 20, DARKGRAY)

                    DrawLineEx(v0, v1, 2, BLACK)
                    DrawLineEx(v0, v2, 2, RED)

                    DrawCircleSector(v0, 40, startAngle, startAngle + angle, 32, Fade(GREEN, 0.6))
                } else {
                    DrawText("MODE 1: Angle formed by line V1 to V2", 10, 10, 20, BLACK)

                    DrawLine(0, screenHeight/2, screenWidth, screenHeight/2, LIGHTGRAY)
                    DrawLineEx(v0, v2, 2, RED)

                    DrawCircleSector(v0, 40, startAngle, startAngle - angle, 32, Fade(GREEN, 0.6))
                }

                DrawText("v0", i32(v0.x), i32(v0.y), 10, DARKGRAY)

                if !angleMode && (v0 - v1).y > 0 { DrawText("v1", i32(v1.x), i32(v1.y) - 10, 10, DARKGRAY) }
                if !angleMode && (v0 - v1).y < 0 { DrawText("v1", i32(v1.x), i32(v1.y), 10, DARKGRAY) }

                if angleMode { DrawText("v1", i32(v0.x) + 40, i32(v0.y), 10, DARKGRAY) }

                DrawText("v2", i32(v2.x) - 10, i32(v2.y) - 10, 10, DARKGRAY)

                DrawText("Press SPACE to change MODE", 460, 10, 20, DARKGRAY)
                DrawText(TextFormat("Angle: %2.2f", angle), 10, 70, 20, LIME)
            EndDrawing()
		}
	}
}