package sort

import "core:fmt"
import "core:math/rand"
import rl "vendor:raylib"

WIDTH  :: 800
HEIGHT :: 600
FPS    :: 60
TITLE  :: "Bubble Sort"
SIZE : i32 : 120
GREY : rl.Color = {50, 50, 50, 255}

State :: enum{ INIT, SORTING, SORTED }

// populate array linearly, values will be 1 to length of array. No repeating numbers
populate_array :: proc(bars : ^[SIZE]i32){
    for i in 0..<len(bars){
        bars[i] = i32(i + 1)
    }
}

// populate array randomly with values starting at 1 to length of array. Numbers can repeat
populate_rand :: proc(bars : ^[SIZE]i32){
    for i in 0..<len(bars){
        a : i32 = i32(rand.float32() * f32(len(bars)))
        bars[i] = a
    }
}

// for 2x the length of the array, choose 2 random indexes and swap them
shuffle :: proc(bars : ^[SIZE]i32) {
    for i in 0..=len(bars) * 2 {
        a : int = int(rand.float32() * f32(len(bars)))
        b : int = int(rand.float32() * f32(len(bars)))
        swap := bars[a]
        bars[a] = bars[b]
        bars[b] = swap
    }
}

// single step of the bubble sort algorithm, 
// compares 2 adjacent values and swaps them if they appear out of order
// i is the current index, final_idx is the last index or the index to compare to
// i is reset to 0 and final_idx decremented by 1
// this continues until final_idx is 0 and the array is sorted
bubble_sort_step :: proc(bars : ^[SIZE]i32, i : ^int, final_idx : ^int) {
    if bars[i^] > bars[i^ + 1]{
        swap := bars[i^]
        bars[i^] = bars[i^ + 1]
        bars[i^ + 1] = swap
    }
    i^ += 1
    if i^ == final_idx^ {
        i^ = 0
        final_idx^ -= 1
    }
}

main :: proc() {    
    rl.InitWindow(WIDTH, HEIGHT, TITLE)
    defer rl.CloseWindow()
    rl.SetTargetFPS(FPS)

    state : State = .INIT
    bars : [SIZE]i32
    
    populate_array(&bars)
    shuffle(&bars)

    speed := 3
    current_idx: int
    final_idx := len(bars) - 1
    text : cstring = "Press X to start sorting."
    text_color := GREY

    for !rl.WindowShouldClose() {
        x:i32 = 100
        if rl.IsKeyPressed(rl.KeyboardKey(.X)) {
            state = .SORTING
            text = "Sorting..."
            text_color = rl.ORANGE
        }
        if rl.IsKeyPressed(rl.KeyboardKey(.UP)) && state == .SORTING {
            speed += 1
            if speed > 10{
                speed = 10
            }
        }
        if rl.IsKeyPressed(rl.KeyboardKey(.DOWN)) && state == .SORTING {
            speed -= 1
            if speed < 1{
                speed = 1
            }
        }
        if rl.IsKeyPressed(rl.KeyboardKey(.R)) && state == .INIT {
            populate_rand(&bars)
        }
        if rl.IsKeyPressed(rl.KeyboardKey(.S)) && state == .INIT {
            shuffle(&bars)
        }
        if rl.IsKeyPressed(rl.KeyboardKey(.Q)) && state == .SORTED{
            current_idx = 0
            final_idx = len(bars) - 1
            text = "Press X to start sorting."
            text_color = GREY
            populate_array(&bars)
            shuffle(&bars)
            state = .INIT
        }
        if final_idx == 0 {
            state = .SORTED
            text = "Done sorting"
            text_color = rl.DARKGREEN
        }
        if state == .SORTING{
            for i in 0..<speed {
                bubble_sort_step(&bars, &current_idx, &final_idx)
            }
        }
        rl.BeginDrawing()
        rl.ClearBackground(rl.BLACK)
            for i in 0..<len(bars){
                rl.DrawRectangle(x, 400 - bars[i] * 2, 3, bars[i] * 2, rl.PURPLE)
                x += 5
            }
            rl.DrawText(text, 100, 450, 30, text_color)

            if state == .INIT {
                rl.DrawText("R to randomize values", 100, 500, 20, GREY)
                rl.DrawText("S to shuffle values", 100, 530, 20, GREY)
            }
            if state == .SORTING{
                rl.DrawText("UP to sort faster", 100, 500, 20, GREY)
                rl.DrawText("DOWN to sort slower", 100, 530, 20, GREY)
            }
            if state == .SORTED {
                rl.DrawText("Q to reset", 100, 500, 20, GREY)
            }
        rl.EndDrawing()
    }
}