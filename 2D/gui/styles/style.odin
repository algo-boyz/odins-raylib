package main

import rl "vendor:raylib"

main :: proc() {
    rl.InitWindow(400, 200, "raygui - controls test suite")
    rl.SetTargetFPS(60)
    showMessageBox := false

    for !rl.WindowShouldClose() {
        rl.BeginDrawing()
        rl.ClearBackground(rl.GetColor(u32(rl.GuiGetStyle(rl.GuiControl.DEFAULT, i32(rl.GuiDefaultProperty.BACKGROUND_COLOR)))))
        
        if rl.GuiButton({24, 24, 120, 30}, "#191#Show Message") {
            showMessageBox = true
            rl.GuiLoadStyle("assets/dark/style_dark.rgs")
        }
        
        if showMessageBox {
            result := rl.GuiMessageBox({85, 70, 250, 100}, 
                "#191#Message Box", "Hi! This is a message!", "Nice;Cool")
            if result >= 0 {
                rl.GuiLoadStyle("assets/terminal/style_terminal.rgs")
                showMessageBox = false
            }
        }
        
        rl.EndDrawing()
    }
    
    rl.CloseWindow()
}