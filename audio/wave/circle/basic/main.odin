package audio

import "vendor:raylib"

MAX_CIRCLES :: 64

CircleWave :: struct {
    position: raylib.Vector2,
    radius: f32,
    alpha: f32,
    speed: f32,
    color: raylib.Color,
}

main :: proc() {
    using raylib

    screenWidth  :: 800
    screenHeight :: 450

    SetConfigFlags({.MSAA_4X_HINT})

    InitWindow(screenWidth, screenHeight, "Circle Wave Audio Visualizer")
    defer CloseWindow()

    InitAudioDevice()
    defer CloseAudioDevice()

    colors: [14]Color = {
        ORANGE, RED, GOLD, LIME, BLUE, VIOLET, BROWN, LIGHTGRAY, PINK,
        YELLOW, GREEN, SKYBLUE, PURPLE, BEIGE,
    }

    circles: [MAX_CIRCLES]CircleWave

    for i := MAX_CIRCLES-1; i >= 0; i -= 1 {
        circles[i].alpha = 0
        circles[i].radius = f32(GetRandomValue(10, 40))
        circles[i].position.x = f32(GetRandomValue(i32(circles[i].radius), screenWidth - i32(circles[i].radius)))
        circles[i].position.y = f32(GetRandomValue(i32(circles[i].radius), screenHeight - i32(circles[i].radius)))
        circles[i].speed = f32(GetRandomValue(1, 100)) / 2000
        circles[i].color = colors[GetRandomValue(0, 13)]
    }

    music := LoadMusicStream("../mini.xm")
    defer UnloadMusicStream(music)
    music.looping = false
    pitch: f32 = 1

    PlayMusicStream(music)

    timePlayed: f32 = 0
    pause := false

    SetTargetFPS(60)

    for !WindowShouldClose() {
        UpdateMusicStream(music)

        if IsKeyPressed(.SPACE) {
            StopMusicStream(music)
            PlayMusicStream(music)
            pause = false
        }

        if IsKeyPressed(.P) {
            pause = !pause

            if pause {
                PauseMusicStream(music)
            } else {
                ResumeMusicStream(music)
            }
        }

        if IsKeyDown(.DOWN) {
            pitch -= 0.01
        } else if IsKeyDown(.UP) {
            pitch += 0.01
        }

        SetMusicPitch(music, pitch)

        timePlayed = GetMusicTimePlayed(music) / GetMusicTimeLength(music) * f32(screenWidth - 40)

        for i := MAX_CIRCLES-1; (i >= 0) && !pause; i -= 1 {
            circles[i].alpha += circles[i].speed
            circles[i].radius += circles[i].speed * 10

            if circles[i].alpha > 1 {
                circles[i].speed *= -1
            }

            if circles[i].alpha <= 0 {
                circles[i].alpha = 0
                circles[i].radius = f32(GetRandomValue(10, 40))
                circles[i].position.x = f32(GetRandomValue(i32(circles[i].radius), screenWidth - i32(circles[i].radius)))
                circles[i].position.y = f32(GetRandomValue(i32(circles[i].radius), screenHeight - i32(circles[i].radius)))
                circles[i].speed = f32(GetRandomValue(1, 100)) / 2000
                circles[i].color = colors[GetRandomValue(0, 13)]
            }
        }

        {
            BeginDrawing()
            defer EndDrawing()

            ClearBackground(RAYWHITE)

            for i := MAX_CIRCLES-1; i >= 0; i -= 1 {
                DrawCircleV(circles[i].position, circles[i].radius, Fade(circles[i].color, circles[i].alpha))
            }

            DrawRectangle(20, screenHeight - 20 - 12, screenWidth - 40, 12, LIGHTGRAY)
            DrawRectangle(20, screenHeight - 20 - 12, i32(timePlayed), 12, MAROON)
            DrawRectangleLines(20, screenHeight - 20 - 12, screenWidth - 40, 12, GRAY)

            DrawRectangle(20, 20, 425, 145, WHITE)
            DrawRectangleLines(20, 20, 425, 145, GRAY)
            DrawText("PRESS SPACE TO RESTART MUSIC", 40, 40, 20, BLACK)
            DrawText("PRESS P TO PAUSE/RESUME", 40, 70, 20, BLACK)
            DrawText("PRESS UP/DOWN TO CHANGE SPEED", 40, 100, 20, BLACK)
            DrawText(TextFormat("SPEED: %f", pitch), 40, 130, 20, MAROON)
        }
    }
}