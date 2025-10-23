package main

import "core:fmt"
import "core:math/rand"
import "core:math"
import "core:strings"
import "core:strconv"
import rl "vendor:raylib"

WIDTH :: 1024
HALF_WIDTH :: WIDTH / 2
HEIGHT :: 768
HALF_HEIGHT :: HEIGHT / 2
RAD :: 100
TWO_RAD :: RAD * 2
RAD_SQR :: RAD * RAD
X :: HALF_WIDTH - RAD 
Y :: HALF_HEIGHT - RAD 
PI: f64

Rect :: struct { x, y, width, height: i32 }

Pixel :: struct { x, y: i32 }

length :: proc( x, y: i32 ) -> i32 {
    return i32(math.sqrt(f32(x * x + y * y)))
}

inside :: proc( x, y: i32, rect: Rect ) -> bool {
    return x >= rect.x && x <= rect.x + rect.width \
	&& y >= rect.y && y <= rect.y + rect.height
}

draw_btn :: proc(rect: Rect, text: cstring, invert: bool) {
    if(invert) {
        rl.DrawRectangle(rect.x, rect.y, rect.width, rect.height, rl.BLACK)
        rl.DrawText(text, rect.x+20, rect.y+5, 26, rl.WHITE)
        return
    }
    rl.DrawRectangleLines(rect.x, rect.y, rect.width, rect.height, rl.BLACK)
    rl.DrawText(text, rect.x+20, rect.y+5, 26, rl.BLACK)
}

sample :: proc(pxs: ^[dynamic]Pixel, count: i32 = 1) -> (inside, out: i32) {
    for i: i32; i < count; i += 1 {
        // Generate random x and y coordinates within the square [0, TWO_RAD]
        x := rand.int31_max(TWO_RAD)
        y := rand.int31_max(TWO_RAD)

        append(pxs, Pixel{x, y})

        // Check if point is inside circle (distance from center < radius)
        if(length(x - RAD, y - RAD) < RAD) {
            inside += 1
        } else {
            out += 1
        }
    }
    return inside, out
}

main :: proc() {
    rl.InitWindow(WIDTH, HEIGHT, "Monte Carlo Circle Estimator")
    rl.SetTargetFPS(165)

    pxs: [dynamic]Pixel
    num_in, num_out: i32

    cam: rl.Camera2D
    cam.zoom = 2
    cam.target.x = 320 
    cam.target.y = 200

    for !rl.WindowShouldClose() {
        rl.BeginDrawing()
        rl.ClearBackground(rl.WHITE)
        
        if(num_in + num_out > 0) {
            PI = 4 * f64(num_in) / f64(num_in + num_out)
        }
        buf: strings.Builder
        strings.write_f64(&buf, PI, 'f')
        rl.DrawText(strings.to_cstring(&buf), 200, 60, 32, rl.RED)

        rl.BeginMode2D(cam)
            rl.DrawRectangleLines(X, Y, TWO_RAD, TWO_RAD, rl.BLACK)
            
            // Draw filled yellow circle if we have samples
            if len(pxs) > 10000 {
                rl.DrawCircle(WIDTH / 2, HEIGHT / 2, f32(RAD), rl.YELLOW)
            }
            rl.DrawCircleLines(WIDTH / 2, HEIGHT / 2, f32(RAD), rl.BLACK)
            // Still draw the dots but make them more visible on yellow background
            for px in pxs {
                color := rl.RED
                if length(px.x - RAD, px.y - RAD) < RAD {
                    color = rl.DARKGREEN  // Inside circle points
                } else {
                    color = rl.MAGENTA    // Outside circle points
                }
                rl.DrawPixel(X + px.x, Y + px.y, color)
            }
        rl.EndMode2D()
        
        mouse_x := i32(rl.GetMouseX())
        mouse_y := i32(rl.GetMouseY())

        add_btn: Rect = { X + TWO_RAD + 50, Y, 180, 40 } 
        add_1k_btn: Rect = { X + TWO_RAD + 50, Y + 50, 180, 40 } 
        clear_btn: Rect = { X + TWO_RAD + 50, Y + 100, 180, 40 } 
        mode_btn: Rect = { X + TWO_RAD + 50, Y + 150, 180, 40 } 

        add_btn_hover: bool = inside(mouse_x, mouse_y, add_btn)
        add_1k_btn_hover: bool = inside(mouse_x, mouse_y, add_1k_btn)
        clear_btn_hover: bool = inside(mouse_x, mouse_y, clear_btn)
        mode_btn_hover: bool = inside(mouse_x, mouse_y, mode_btn)
        
        draw_btn(add_btn, "Add dot", add_btn_hover)
        draw_btn(add_1k_btn, "1K dots", add_1k_btn_hover)
        draw_btn(clear_btn, "Clear", clear_btn_hover)
        
        switch true {
        case add_btn_hover && rl.IsMouseButtonPressed(rl.MouseButton.LEFT):
            inside, out := sample(&pxs, 1)
            num_in += inside
            num_out += out
        case add_1k_btn_hover && rl.IsMouseButtonPressed(rl.MouseButton.LEFT):
            inside, out := sample(&pxs, 1000)
            num_in += inside
            num_out += out
        case clear_btn_hover && rl.IsMouseButtonPressed(rl.MouseButton.LEFT):
            clear(&pxs)
            num_in = 0
            num_out = 0
        }
        rl.EndDrawing()
    }
    rl.CloseWindow()
}