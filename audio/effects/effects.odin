package audio

import "core:mem"
import rl "vendor:raylib"
import c "core:c/libc"

delayBuffer: [^]f32 = nil
delayBufferSize: u32 = 0
delayReadIndex: u32 = 2
delayWriteIndex: u32 = 0
lowPassState: [2]f32 = {0, 0}
lowPassCutoff: f32 = 100

main :: proc() {

    rl.InitWindow(800, 450, "raylib [audio] example - stream effects")
    defer rl.CloseWindow()

    rl.InitAudioDevice()
    defer rl.CloseAudioDevice()

    music := rl.LoadMusicStream("../a-faded-folk-song.mp3")
    defer rl.UnloadMusicStream(music)

    delayBufferSize = 48000*2
    delay_slice := make([]f32, delayBufferSize)
    delayBuffer = &delay_slice[0]
    defer delete(delay_slice)

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
            rl.ClearBackground(rl.RAYWHITE)

            rl.DrawText("MUSIC PLAYING!", 245, 150, 20, rl.LIGHTGRAY)

            rl.DrawRectangle(200, 180, 400, 12, rl.LIGHTGRAY)
            rl.DrawRectangle(200, 180, i32(timePlayed*400), 12, rl.MAROON)
            rl.DrawRectangleLines(200, 180, 400, 12, rl.GRAY)

            rl.DrawText("PRESS SPACE TO RESTART MUSIC", 215, 230, 20, rl.LIGHTGRAY)
            rl.DrawText("PRESS P TO PAUSE/RESUME MUSIC", 208, 260, 20, rl.LIGHTGRAY)

            rl.DrawText(rl.TextFormat("PRESS F TO TOGGLE LPF EFFECT: %s", enableEffectLPF? "ON" : "OFF"), 200, 320, 20, rl.GRAY)
            rl.DrawText(rl.TextFormat("PRESS D TO TOGGLE DELAY EFFECT: %s", enableEffectDelay? "ON" : "OFF"), 180, 350, 20, rl.GRAY)
            rl.EndDrawing()
        }
    }
}

AudioProcessEffectLPF :: proc "c" (buffer: rawptr, frames: c.uint) {
    cutoff: f32 = lowPassCutoff/44100
    k: f32 = cutoff / (cutoff + 0.1591549431)
    bufptr := ([^]f32)(buffer)

    for i := 0; i < int(frames)*2; i += 2 {
        l := bufptr[i]
        r := bufptr[i+1]
        lowPassState[0] += k * (l - lowPassState[0])
        lowPassState[1] += k * (r - lowPassState[1])
        bufptr[i] = lowPassState[0]
        bufptr[i+1] = lowPassState[1]
    }
}

AudioProcessEffectDelay :: proc "c" (buffer: rawptr, frames: c.uint) {
    bufptr := ([^]f32)(buffer)
    
    for i := 0; i < int(frames)*2; i += 2 {
        leftDelay := delayBuffer[delayReadIndex]; delayReadIndex += 1
        rightDelay := delayBuffer[delayReadIndex]; delayReadIndex += 1
        
        if delayReadIndex == delayBufferSize {
            delayReadIndex = 0
        }
        
        bufptr[i] = 0.5 * bufptr[i] + 0.5 * leftDelay
        bufptr[i+1] = 0.5 * bufptr[i+1] + 0.5 * rightDelay
        
        delayBuffer[delayWriteIndex] = bufptr[i]; delayWriteIndex += 1
        delayBuffer[delayWriteIndex] = bufptr[i+1]; delayWriteIndex += 1
        
        if delayWriteIndex == delayBufferSize {
            delayWriteIndex = 0
        }
    }
}