package audio

import rl "vendor:raylib"
import "core:math"
import c "core:c/libc"

exponent: f32 = 1
averageVolume: [400]f32

ProcessAudio :: proc "c" (buffer: rawptr, frames: c.uint) {
    samples := cast([^]f32)buffer
    average: f32

    for frame in 0..<frames {
        left  := &samples[frame * 2 + 0]
        right := &samples[frame * 2 + 1]

        left^  = math.pow(math.abs(left^),  exponent) * (left^  < 0 ? -1 : 1)
        right^ = math.pow(math.abs(right^), exponent) * (right^ < 0 ? -1 : 1)

        average += math.abs(left^)  / f32(frames)
        average += math.abs(right^) / f32(frames)
    }

    for i in 0..<399 {
        averageVolume[i] = averageVolume[i + 1]
    }

    averageVolume[399] = average
}

main :: proc() {

    rl.InitWindow(800, 450, "raylib [audio] example - processing mixed output")
    defer rl.CloseWindow()

    rl.InitAudioDevice()
    defer rl.CloseAudioDevice()

    rl.AttachAudioMixedProcessor(ProcessAudio)
    defer rl.DetachAudioMixedProcessor(ProcessAudio)

    music := rl.LoadMusicStream("../a-faded-folk-song.mp3")
    defer rl.UnloadMusicStream(music)
    sound := rl.LoadSound("../stringpluck.wav")
    defer rl.UnloadSound(sound)

    rl.PlayMusicStream(music)

    rl.SetTargetFPS(60)

    for !rl.WindowShouldClose() {
        rl.UpdateMusicStream(music)

        if rl.IsKeyPressed(rl.KeyboardKey.LEFT)  { exponent -= 0.05 }
        if rl.IsKeyPressed(rl.KeyboardKey.RIGHT) { exponent += 0.05 }

        exponent = clamp(exponent, 0.5, 3)

        if rl.IsKeyPressed(.SPACE) {
            rl.PlaySound(sound)
        }

        {
            rl.BeginDrawing()
            rl.ClearBackground(rl.RAYWHITE)

            rl.DrawText("MUSIC SHOULD BE PLAYING!", 255, 150, 20, rl.LIGHTGRAY)

            rl.DrawText(rl.TextFormat("EXPONENT = %.2f", exponent), 215, 180, 20, rl.LIGHTGRAY)

            rl.DrawRectangle(199, 199, 402, 34, rl.LIGHTGRAY)
            for i in i32(0)..<400 {
                rl.DrawLine(201 + i, 232 - i32(averageVolume[i] * 32), 201 + i, 232, rl.MAROON)
            }

            rl.DrawRectangleLines(199, 199, 402, 34, rl.GRAY)

            rl.DrawText("PRESS SPACE TO PLAY OTHER SOUND", 200, 250, 20, rl.LIGHTGRAY)
            rl.DrawText("USE LEFT AND RIGHT ARROWS TO ALTER DISTORTION", 140, 280, 20, rl.LIGHTGRAY)
            rl.EndDrawing()
        }
    }
}