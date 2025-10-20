package timer

// Timer struct
Timer :: struct {
    remaining: f32, // seconds remaining
    max:       f32, // Keeps track of the original time the timer was set for
}

// Creates a new timer with zero time
new :: proc() -> Timer {
    return Timer{
        remaining = 0.0,
        max       = 0.0,
    }
}

// Sets the timer to the specified number of seconds
set :: proc(timer: ^Timer, seconds: f32) {
    timer.remaining = seconds
    timer.max = seconds
}

// Gets the maximum time the timer was set for
get_max :: proc(timer: ^Timer) -> f32 {
    return timer.max
}

// Updates the timer - should be called every frame
tick :: proc(timer: ^Timer, delta_time: f32) {
    if timer.remaining > 0.0 {
        timer.remaining -= delta_time
    }
}

// Returns true if timer has reached zero or below
is_done :: proc(timer: ^Timer) -> bool {
    return timer.remaining <= 0.0
}

// Returns how many seconds are remaining (never negative)
seconds_remaining :: proc(timer: ^Timer) -> f32 {
    return max(timer.remaining, 0.0)
}

// Returns the progress as a value between 0.0 and 1.0
progress :: proc(timer: ^Timer) -> f32 {
    if timer.max <= 0.0 {
        return 1.0
    }
    return 1.0 - (timer.remaining / timer.max)
}

// Resets the timer to its maximum value
reset :: proc(timer: ^Timer) {
    timer.remaining = timer.max
}

// Stops the timer by setting remaining time to 0
stop :: proc(timer: ^Timer) {
    timer.remaining = 0.0
}