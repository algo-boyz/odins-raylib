package main

import "core:math/linalg"

import rl "vendor:raylib"

// based on: https://gist.github.com/jakubtomsu/5372712e98d12445670b3acd19f786f0
main :: proc() {
    rl.SetConfigFlags({.MSAA_4X_HINT, .VSYNC_HINT})
    rl.InitWindow(900, 600, "Curves")
    defer rl.CloseWindow()

    points := [4]rl.Vector2{{100, 100}, {100, 600}, {500, 0}, {800, 500}}

    for !rl.WindowShouldClose() {
        rl.BeginDrawing()
        defer rl.EndDrawing()

        rl.ClearBackground(rl.BLACK)

        rl.DrawFPS(3, 3)


        for p1, i in points[1:] {
            p0 := points[i]
            rl.DrawLineEx(p0, p1, 1.5, {30, 30, 30, 255})
        }

        rl.DrawSplineSegmentBezierCubic(points[0], points[1], points[2], points[3], 3, rl.ORANGE)

        for p in points {
            rl.DrawCircleV(p, 5, rl.ORANGE)
        }

        NUM_POINTS :: 10
        SPEED :: 0.2
        FADE_IN_OUT :: 0.03
        for i in 0 ..< NUM_POINTS {
            t := linalg.fract(f32(rl.GetTime() * SPEED) + f32(i) / NUM_POINTS)
            p := rl.GetSplinePointBezierCubic(points[0], points[1], points[2], points[3], t)
            rad: f32 = 10
            rad *= linalg.smoothstep(f32(0), FADE_IN_OUT, t) // fade in rad
            rad *= linalg.smoothstep(f32(1), 1 - FADE_IN_OUT, t) // fade out rad
            rl.DrawCircleV(p, rad, rl.YELLOW)
        }
    }
}