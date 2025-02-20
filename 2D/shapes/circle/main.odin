package main

import "core:fmt"
import rl "vendor:raylib"
import "../../../rlutil/geom/circle"

obstacle: rl.Rectangle

show_position :: proc(c: ^circle.Circle) {
    rl.DrawText(
        fmt.ctprintf("x pos: %d", circle.get_x_pos(c)),
        20, 10, 20, rl.BLACK)
    rl.DrawText(
        fmt.ctprintf("y pos: %d", circle.get_y_pos(c)), 
        20, 30, 20, rl.BLACK)
}

show_velocity :: proc(c: ^circle.Circle) {
    rl.DrawText(
        fmt.ctprintf("x vel: %.2f", circle.get_x_velocity(c)), 
        20, 60, 20, rl.BLACK)
    rl.DrawText(
        fmt.ctprintf("y vel: %.2f", circle.get_y_velocity(c)),
        20, 80, 20, rl.BLACK)
}

show_collision :: proc(c: ^circle.Circle) {
    x_collision_str := circle.check_collision_x(c)
    if x_collision_str == rune(' ') && circle.check_collision_floor(c) {
        x_collision_str = rune('F')
    }
    // todo add collision with platform rectangle
    rl.DrawText(
        fmt.ctprintf("x collision: %c", x_collision_str),
        20, 110, 20, rl.BLACK)
}

show_time :: proc() {
    rl.DrawText(
        fmt.ctprintf("time: %.2f", rl.GetTime()),
        20, 140, 20, rl.BLACK)
}

main :: proc() {
    screen_width :: 1280
    screen_height :: 720
    
    rl.InitWindow(screen_width, screen_height, "Jumping Circle")
    rl.EnableCursor()
    
    rl.SetTargetFPS(60)
    
    c := circle.new_circle_with_params(50, rl.BLUE)
    
    platform := rl.Rectangle{
        x = f32(screen_width) * 0.2,
        y = f32(screen_height) / 2,
        width = f32(screen_width) * 0.6,
        height = 50,
    }
    
    for !rl.WindowShouldClose() {
        if rl.CheckCollisionRecs(platform, circle.get_hitbox(&c)) {
            circle.set_color(&c, rl.PURPLE)
        } else {
            circle.set_color(&c, rl.BLUE)
        }
        
        circle.update(&c)
        rl.PollInputEvents()
        rl.BeginDrawing()
        
        rl.ClearBackground(rl.RAYWHITE)
        
        show_position(&c)
        show_velocity(&c)
        show_collision(&c)
        show_time()
        // circle.draw_hitbox(&c)
        rl.DrawRectangleRec(platform, rl.BLACK)
        circle.draw(&c)
        
        rl.EndDrawing()
    }
    
    rl.CloseWindow()
}