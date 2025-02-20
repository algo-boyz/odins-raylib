package main

import "core:fmt"
import rl "vendor:raylib"

Timer :: struct {
    lifetime: f32,
}

start_timer :: proc(timer: ^Timer, duration: f32) {
    timer.lifetime = duration
}

update_timer :: proc(timer: ^Timer) {
    if timer.lifetime > 0 {
        timer.lifetime -= rl.GetFrameTime()
    }
}

timer_done :: proc(timer: ^Timer) -> bool {
    if timer != nil {
        return timer.lifetime <= 0
    }
    return false
}

main :: proc() {
    rl.InitWindow(1280, 800, "Fixed Time Steps Example - Beats Per Minute")
    rl.SetTargetFPS(40)
    defer rl.CloseWindow()
    
    rl.InitAudioDevice()
    defer rl.CloseAudioDevice()
    
    sound := rl.LoadSound("../stringpluck.wav")
    defer rl.UnloadSound(sound)
    
    second := f32(1.0)
    beat_per_min := f32(100)
    beat_per_sec := 60.0 / beat_per_min
    
    timer := Timer{0}
    ticker := 0
    pause := true
    
    for !rl.WindowShouldClose() {
        if rl.IsKeyPressed(.SPACE) {
            start_timer(&timer, beat_per_sec)
            pause = false
            rl.PlaySound(sound)
        }
        
        update_timer(&timer)
        
        rl.BeginDrawing()
        defer rl.EndDrawing()
        
        rl.ClearBackground(rl.BLACK)
        
        circle_pos := rl.Vector2{400, 400}
        
        if !timer_done(&timer) || pause {
            rl.DrawCircleV(circle_pos, 50, rl.RED)
        } else {
            rl.DrawCircleV(circle_pos, 50, rl.BLUE)
            start_timer(&timer, beat_per_sec)
            ticker += 1
            rl.PlaySound(sound)
        }
        
        // Debug stats
        rl.DrawText(fmt.ctprintf("timer.lifetime = %f", timer.lifetime), 20, 20, 15, rl.WHITE)
        rl.DrawText(fmt.ctprintf("timer_done() = %v", timer_done(&timer)), 20, 35, 15, rl.WHITE)
        rl.DrawText(fmt.ctprintf("GetFrameTime() = %f", rl.GetFrameTime()), 20, 65, 15, rl.WHITE)
        rl.DrawText(fmt.ctprintf("ticker = %d", ticker), 20, 80, 15, rl.WHITE)
        rl.DrawText(fmt.ctprintf("GetTime() = %f\n(unused variable)", rl.GetTime()), 20, 200, 15, rl.WHITE)
        rl.DrawText(fmt.ctprintf("BeatPerMin = %f,\nBeatPerSec = %f", beat_per_min, beat_per_sec), 20, 240, 15, rl.WHITE)
    }
}