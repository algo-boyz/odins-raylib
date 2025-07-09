package rlutil

import "core:fmt"
import "core:time"
import rl "vendor:raylib"

Timer :: struct {
    lifetime: f32,
}

timer_start :: proc(timer: ^Timer, duration: f32) {
    timer.lifetime = duration
}

timer_update :: proc(timer: ^Timer) {
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

// Returns true if the timer has reached the specified interval in seconds.
// Resets the timer's lifetime to 0 after reaching the interval.
// This is useful for creating periodic events or actions in your game loop.
// Example usage:
// ```odin
// if timer_interval(&my_timer, 1.0) {
//     // Do something every second
// }
timer_interval :: proc(t: ^Timer, seconds: f32) -> bool {
    t.lifetime += rl.GetFrameTime();
    
    if (t.lifetime >= seconds) {
        t.lifetime = 0;
        return true;
    }

    return false;
}

timer_reset :: proc(t: ^Timer) {
    t.lifetime = 0;
}
