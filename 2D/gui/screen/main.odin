package scene_manager

/*******************************************************************************************
*
*   raylib [core] examples - basic screen manager
*
*   NOTE: This example illustrates a very simple screen manager based on a states machines
*
*   Example originally created with raylib 4.0, last time updated with raylib 4.0
*
*   Example licensed under an unmodified zlib/libpng license, which is an OSI-certified,
*   BSD-like license that allows static linking with closed source software
*
*   Copyright (c) 2021-2024 Ramon Santamaria (@raysan5)
*   Translation to Odin by Evan Martinez (@Nave55)
*
*   https://github.com/Nave55/Odin-Raylib-Examples/blob/main/Core/screen_manager.odin
*
********************************************************************************************/

import rl "vendor:raylib"

SCREEN_WIDTH :: 800
SCREEN_HEIGHT :: 450

Gamescene :: enum {
    LOGO, 
    TITLE, 
    GAMEPLAY, 
    ENDING,
}

scene: Gamescene
frames_counter: int

main :: proc() {
    rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "Template")
    defer rl.CloseWindow()
    rl.SetTargetFPS(60)
    initGame()

    for !rl.WindowShouldClose() do updateGame()
}

initGame :: proc() {
    scene = .LOGO
}

changeScene :: proc() {
    switch scene {
        case .LOGO: 
            frames_counter += 1
            if frames_counter > 120 do scene = .TITLE
        case .TITLE: 
            if rl.IsKeyPressed(.ENTER) || rl.IsGestureDetected(.TAP) do scene = .GAMEPLAY
        case .GAMEPLAY: 
            if rl.IsKeyPressed(.ENTER) || rl.IsGestureDetected(.TAP) do scene = .ENDING
        case .ENDING: 
            if rl.IsKeyPressed(.ENTER) || rl.IsGestureDetected(.TAP) do scene = .TITLE
    }  
}
 
drawGame :: proc() {
    rl.BeginDrawing()
    defer rl.EndDrawing()
    rl.ClearBackground(rl.WHITE)

    switch(scene) {
        case .LOGO:// TODO: Draw LOGO screen here!
            rl.DrawText("LOGO SCREEN", 20, 20, 40, rl.LIGHTGRAY)
            rl.DrawText("WAIT for 2 SECONDS...", 290, 220, 20, rl.GRAY)

        case .TITLE:
            // TODO: Draw TITLE screen here!
            rl.DrawRectangle(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT, rl.GREEN)
            rl.DrawText("TITLE SCREEN", 20, 20, 40, rl.DARKGREEN)
            rl.DrawText("PRESS ENTER or TAP to JUMP to GAMEPLAY SCREEN", 120, 220, 20, rl.DARKGREEN)
        
        case .GAMEPLAY:
            // TODO: Draw GAMEPLAY screen here!
            rl.DrawRectangle(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT, rl.PURPLE)
            rl.DrawText("GAMEPLAY SCREEN", 20, 20, 40, rl.MAROON)
            rl.DrawText("PRESS ENTER or TAP to JUMP to ENDING SCREEN", 130, 220, 20, rl.MAROON)
    
        case .ENDING:
            // TODO: Draw ENDING screen here!
            rl.DrawRectangle(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT, rl.BLUE)
            rl.DrawText("ENDING SCREEN", 20, 20, 40, rl.DARKBLUE)
            rl.DrawText("PRESS ENTER or TAP to RETURN to TITLE SCREEN", 120, 220, 20, rl.DARKBLUE)   
    }
}

updateGame :: proc() {
    changeScene()
    drawGame()
}