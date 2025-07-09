package shapes

import "vendor:raylib"
import "core:math"

main :: proc() {
    using raylib

    screenWidth  :: 800
    screenHeight :: 450

    InitWindow(screenWidth, screenHeight, "Circle sector")
    defer CloseWindow()

    center: Vector2 = {f32(GetScreenWidth() - 300)/2, f32(GetScreenHeight())/2}

    outerRadius: f32 = 180
    startAngle:  f32 = 0
    endAngle:    f32 = 180
    segments:    f32 = 10
    minSegments: f32 = 4

    SetTargetFPS(60)

    for !WindowShouldClose() {
        BeginDrawing()
        defer EndDrawing()

        ClearBackground(RAYWHITE)

        DrawLine(500, 0, 500, GetScreenWidth(), Fade(LIGHTGRAY, 0.6))
        DrawRectangle(500, 0, GetScreenWidth() - 500, GetScreenHeight(), Fade(LIGHTGRAY, 0.3))

        DrawCircleSector(center, outerRadius, startAngle, endAngle, i32(segments), Fade(MAROON, 0.3))
        DrawCircleSectorLines(center, outerRadius, startAngle, endAngle, i32(segments), Fade(MAROON, 0.6))

        GuiSliderBar({600, 40, 120, 20}, "StartAngle", nil, &startAngle, 0, 720)
        GuiSliderBar({600, 70, 120, 20}, "EndAngle", nil, &endAngle, 0, 720)
        GuiSliderBar({600, 140, 120, 20}, "Radius", nil, &outerRadius, 0, 200)
        GuiSliderBar({600, 170, 120, 20}, "Segments", nil, &segments, 0, 100)

        minSegments = math.trunc(math.ceil((endAngle - startAngle) / 90))
        DrawText(TextFormat("MODE: %s", segments >= minSegments ? "MANUAL" : "AUTO"),
            600, 200, 10, segments >= minSegments ? MAROON : DARKGRAY)

        DrawFPS(10, 10)
    }
}