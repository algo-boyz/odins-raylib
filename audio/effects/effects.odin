package audio

import rl "vendor:raylib"
import c "core:c/libc"

delayBuffer: [^]f32 = nil
delayBufferSize: u32 = 0
delayReadIndex: u32 = 2
delayWriteIndex: u32 = 0

main :: proc() {

    rl.InitWindow(800, 450, "raylib [audio] example - stream effects")
    defer rl.CloseWindow()

    rl.InitAudioDevice()
    defer rl.CloseAudioDevice()

    music := rl.LoadMusicStream("../a-faded-folk-song.mp3")
    defer rl.UnloadMusicStream(music)

    // TODO: This might be the incorrect way to do malloc/free
    delayBufferSize = 48000*2
    delayBuffer = make([^]f32, delayBufferSize)
    defer free(delayBuffer)

    rl.PlayMusicStream(music)

    timePlayed: f32
    pause: bool

    enableEffectLPF: bool
    enableEffectDelay: bool

    rl.SetTargetFPS(60)

    for !rl.WindowShouldClose() {
        rl.UpdateMusicStream(music)

        if rl.IsKeyPressed(.SPACE) {
            rl.StopMusicStream(music)
            rl.PlayMusicStream(music)
        }

        if rl.IsKeyPressed(rl.KeyboardKey.P) {
            pause = !pause

            if pause {
                rl.PauseMusicStream(music)
            } else {
                rl.ResumeMusicStream(music)
            }
        }

        if rl.IsKeyPressed(rl.KeyboardKey.F) {
            enableEffectLPF = !enableEffectLPF

            if enableEffectLPF {
                rl.AttachAudioStreamProcessor(music.stream, AudioProcessEffectLPF)
            } else {
                rl.DetachAudioStreamProcessor(music.stream, AudioProcessEffectLPF)
            }
        }

        if rl.IsKeyPressed(rl.KeyboardKey.D) {
            enableEffectDelay = !enableEffectDelay

            if enableEffectDelay {
                rl.AttachAudioStreamProcessor(music.stream, AudioProcessEffectDelay)
            } else {
                rl.DetachAudioStreamProcessor(music.stream, AudioProcessEffectDelay)
            }
        }

        timePlayed = rl.GetMusicTimePlayed(music)/rl.GetMusicTimeLength(music)

        if timePlayed > 1 {
            timePlayed = 1
        }

        {
            rl.BeginDrawing()
            defer rl.EndDrawing()

            rl.ClearBackground(rl.RAYWHITE)

            rl.DrawText("MUSIC PLAYING!", 245, 150, 20, rl.LIGHTGRAY)

            rl.DrawRectangle(200, 180, 400, 12, rl.LIGHTGRAY)
            rl.DrawRectangle(200, 180, i32(timePlayed*400), 12, rl.MAROON)
            rl.DrawRectangleLines(200, 180, 400, 12, rl.GRAY)

            rl.DrawText("PRESS SPACE TO RESTART MUSIC", 215, 230, 20, rl.LIGHTGRAY)
            rl.DrawText("PRESS P TO PAUSE/RESUME MUSIC", 208, 260, 20, rl.LIGHTGRAY)

            rl.DrawText(rl.TextFormat("PRESS F TO TOGGLE LPF EFFECT: %s", enableEffectLPF? "ON" : "OFF"), 200, 320, 20, rl.GRAY)
            rl.DrawText(rl.TextFormat("PRESS D TO TOGGLE DELAY EFFECT: %s", enableEffectDelay? "ON" : "OFF"), 180, 350, 20, rl.GRAY)
        }
    }
}

// FIXME: both effect are not working, idk how to translate the c code that
//        casts the pointer to float

AudioProcessEffectLPF :: proc "c" (buffer: rawptr, frames: c.uint) {
    low: [2]f32
    cutoff: f32 : 70/44100
    k:      f32 : cutoff / (cutoff + 0.1591549431)

    for i := 0; i < int(frames)*2; i += 2 {
        bufptr := cast([^]f32)buffer

        l := bufptr[i + 0]
        r := bufptr[i + 1]

        low[0] += k * (l - low[0])
        low[1] += k * (r - low[1])

        bufptr[i + 0] = low[0]
        bufptr[i + 1] = low[1]
    }
}

AudioProcessEffectDelay :: proc "c" (buffer: rawptr, frames: c.uint) {
    for i := 0; i < int(frames)*2; i += 2 {
        bufptr := cast([^]f32)buffer

        leftDelay  := delayBuffer[delayReadIndex]; delayReadIndex += 1
        rightDelay := delayBuffer[delayReadIndex]; delayReadIndex += 1

        if delayReadIndex == delayBufferSize {
            delayReadIndex = 0
        }

        bufptr[i + 0] = 0.5 * bufptr[i + 0] + 0.5 * leftDelay
        bufptr[i + 1] = 0.5 * bufptr[i + 1] + 0.5 * rightDelay

        delayBuffer[delayWriteIndex] = bufptr[i + 0]; delayReadIndex += 1
        delayBuffer[delayWriteIndex] = bufptr[i + 1]; delayReadIndex += 1

        if delayWriteIndex == delayBufferSize {
            delayWriteIndex = 0
        }
    }
}