package audio

import "vendor:raylib"
import "core:math"
import c "core:c/libc"

WIDTH  :: 800
HEIGHT :: 450

MAX_SAMPLES :: 512
MAX_SAMPLES_PER_UPDATE :: 4096

frequency:      f32 = 440
audioFrequency: f32 = 440
oldFrequency:   f32 = 1
sineIdx:        f32 = 0

AudioInputCallback :: proc "c" (buffer: rawptr, frames: c.uint) {
    audioFrequency = frequency + (audioFrequency - frequency) * 0.95
    incr := audioFrequency/44100
    d := cast([^]i16)buffer

    for i in 0..<frames {
        d[i] = i16(32000 * math.tan(2 * math.π * sineIdx))
        sineIdx += incr
        if sineIdx > 1 {
            sineIdx -= 1
        }
    }
}

main :: proc() {
    using raylib

    InitWindow(WIDTH, HEIGHT, "raw audio stream")
    defer CloseWindow()

    InitAudioDevice()
    defer CloseAudioDevice()

    SetAudioStreamBufferSizeDefault(MAX_SAMPLES_PER_UPDATE)

    stream := LoadAudioStream(44100, 16, 1)
    defer UnloadAudioStream(stream)

    SetAudioStreamCallback(stream, AudioInputCallback)

    data := new([MAX_SAMPLES]i16)
    defer free(data)

    writeBuf := new([MAX_SAMPLES_PER_UPDATE]i16)
    defer free(writeBuf)

    PlayAudioStream(stream)

    mousePosition: Vector2 = {-100, -100}

    waveLength: i32 = 1

    position: Vector2

    SetTargetFPS(30)

    for !WindowShouldClose() {
        mousePosition = GetMousePosition()

        if IsMouseButtonDown(.LEFT) {
            fp := mousePosition.y
            frequency = 40 + fp

            pan := mousePosition.x / f32(WIDTH)
            SetAudioStreamPan(stream, pan)
        }

        if frequency != oldFrequency {
            waveLength = i32(22050/frequency)
            waveLength = clamp(waveLength, 1, MAX_SAMPLES/2)

            for i in 0..<waveLength*2 {
                data[i] = i16(math.tan(2 * math.π * f32(i)/f32(waveLength)) * 32000)
            }

            for j in waveLength*2..<MAX_SAMPLES {
                data[j] = 0
            }

            oldFrequency = frequency
        }
        {
            BeginDrawing()
            ClearBackground(RAYWHITE)
            DrawText(TextFormat("sine frequency: %i", i32(frequency)), GetScreenWidth() - 220, 10, 20, RED)
            DrawText("click mouse button to change frequency or pan", 10, 10, 20, DARKGRAY)
            for i in 0..<WIDTH {
                position.x = f32(i)
                position.y = 250 + 50 * f32(data[i*MAX_SAMPLES/WIDTH])/32000

                DrawPixelV(position, RED)
            }
            EndDrawing()
        }
    }
}