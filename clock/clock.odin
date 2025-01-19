package main

import rl "vendor:raylib"
import "core:time"

AnalogClock :: struct {
    size: f32,
    position: rl.Vector2,
    hour: int,
    minute: int,
    second: int,
}

DARK_GREY :: rl.Color{45, 45, 45, 255}
LIGHT_GREY :: rl.Color{229, 229, 229, 255}

draw_clock :: proc(clock: ^AnalogClock) {
    draw_face(clock)
    draw_hour_marks(clock)
    draw_minute_hand(clock, clock.minute)
    draw_hour_hand(clock, clock.hour, clock.minute)
    draw_second_hand(clock, clock.second)
    rl.DrawCircleV(clock.position, 15, DARK_GREY)
}

update_clock :: proc(clock: ^AnalogClock) {
    clock.hour, clock.minute, clock.second = time.clock_from_time(time.now())
}

draw_face :: proc(clock: ^AnalogClock) {
    rl.DrawCircleV(clock.position, clock.size, DARK_GREY)
    rl.DrawCircleV(clock.position, clock.size - 30, LIGHT_GREY)
    rl.DrawCircleV(clock.position, clock.size - 40, rl.WHITE)
}

draw_hour_marks :: proc(clock: ^AnalogClock) {
    rect_width := f32(10)
    rect_height := clock.size
    rect := rl.Rectangle{
        x = clock.position.x,
        y = clock.position.y,
        width = rect_width,
        height = rect_height,
    }
    
    for i := 0; i < 12; i += 1 {
        origin := rl.Vector2{rect_width/2, rect_height}
        rl.DrawRectanglePro(rect, origin, f32(i * 30), DARK_GREY)
    }
    rl.DrawCircleV(clock.position, clock.size - 50, rl.WHITE)
}

draw_hand :: proc(clock: ^AnalogClock, hand_width: f32, hand_length: f32, angle: f32, color: rl.Color, offset: f32) {
    hand_rect := rl.Rectangle{
        x = clock.position.x,
        y = clock.position.y,
        width = hand_width,
        height = hand_length,
    }
    origin := rl.Vector2{hand_width/2, hand_length - offset}
    rl.DrawRectanglePro(hand_rect, origin, angle, color)
}

draw_minute_hand :: proc(clock: ^AnalogClock, minute: int) {
    hand_width := f32(10)
    hand_length := clock.size * 0.7
    angle := f32(minute * 6)
    draw_hand(clock, hand_width, hand_length, angle, DARK_GREY, 0)
}

draw_hour_hand :: proc(clock: ^AnalogClock, hour: int, minute: int) {
    hand_width := f32(15)
    hand_length := clock.size * 0.6
    angle := f32(30 * hour + (minute / 60.0) * 30)
    draw_hand(clock, hand_width, hand_length, angle, DARK_GREY, 0)
}

draw_second_hand :: proc(clock: ^AnalogClock, second: int) {
    hand_width := f32(5)
    hand_length := clock.size * 1.05
    angle := f32(second * 6)
    draw_hand(clock, hand_width, hand_length, angle, rl.RED, 55)
}

main :: proc() {
    WINDOW_WIDTH :: 600
    WINDOW_HEIGHT :: 600
    LIGHT_BLUE :: rl.Color{225, 239, 240, 255}
    
    rl.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "Analog Clock")
    defer rl.CloseWindow()
    
    rl.SetTargetFPS(15)
    
    clock := AnalogClock{
        size = 250,
        position = rl.Vector2{300, 300},
    }
    
    for !rl.WindowShouldClose() {
        // Update
        update_clock(&clock)
        
        // Draw
        rl.BeginDrawing()
        rl.ClearBackground(LIGHT_BLUE)
        draw_clock(&clock)
        rl.EndDrawing()
    }
}