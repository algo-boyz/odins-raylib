package main

import rl "vendor:raylib"

main :: proc() {
    // Initialization
    SCREEN_WIDTH :: 800
    SCREEN_HEIGHT :: 450

    rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "raylib [textures] example - background scrolling")

    // NOTE: Be careful, background width must be equal or bigger than screen width
    // if not, texture should be drawn more than two times for scrolling effect
    background := rl.LoadTexture("assets/cyberpunk_street_background.png")
    midground := rl.LoadTexture("assets/cyberpunk_street_midground.png")
    foreground := rl.LoadTexture("assets/cyberpunk_street_foreground.png")

    scrolling_back := 0.0
    scrolling_mid := 0.0
    scrolling_fore := 0.0

    rl.SetTargetFPS(60)  // Set our game to run at 60 frames-per-second

    // Main game loop
    for !rl.WindowShouldClose() {  // Detect window close button or ESC key
        // Update
        scrolling_back -= 0.1
        scrolling_mid -= 0.5
        scrolling_fore -= 1.0

        // NOTE: Texture is scaled twice its size, so it should be considered on scrolling
        if scrolling_back <= -f64(background.width * 2) do scrolling_back = 0
        if scrolling_mid <= -f64(midground.width * 2) do scrolling_mid = 0
        if scrolling_fore <= -f64(foreground.width * 2) do scrolling_fore = 0

        // Draw
        rl.BeginDrawing()
        
        rl.ClearBackground(rl.GetColor(0x052c46ff))

        // Draw background image twice
        // NOTE: Texture is scaled twice its size
        rl.DrawTextureEx(background, 
                        rl.Vector2{f32(scrolling_back), 20}, 
                        0.0, 
                        2.0, 
                        rl.WHITE)
        rl.DrawTextureEx(background, 
                        rl.Vector2{f32(background.width * 2) + f32(scrolling_back), 20}, 
                        0.0, 
                        2.0, 
                        rl.WHITE)

        // Draw midground image twice
        rl.DrawTextureEx(midground, 
                        rl.Vector2{f32(scrolling_mid), 20}, 
                        0.0, 
                        2.0, 
                        rl.WHITE)
        rl.DrawTextureEx(midground, 
                        rl.Vector2{f32(midground.width * 2) + f32(scrolling_mid), 20}, 
                        0.0, 
                        2.0, 
                        rl.WHITE)

        // Draw foreground image twice
        rl.DrawTextureEx(foreground, 
                        rl.Vector2{f32(scrolling_fore), 70}, 
                        0.0, 
                        2.0, 
                        rl.WHITE)
        rl.DrawTextureEx(foreground, 
                        rl.Vector2{f32(foreground.width * 2) + f32(scrolling_fore), 70}, 
                        0.0, 
                        2.0, 
                        rl.WHITE)

        rl.DrawText("BACKGROUND SCROLLING & PARALLAX", 10, 10, 20, rl.RED)
        rl.DrawText("(c) Cyberpunk Street Environment by Luis Zuno (@ansimuz)", 
                    SCREEN_WIDTH - 330, 
                    SCREEN_HEIGHT - 20, 
                    10, 
                    rl.RAYWHITE)

        rl.EndDrawing()
    }

    // De-Initialization
    rl.UnloadTexture(background)  // Unload background texture
    rl.UnloadTexture(midground)   // Unload midground texture
    rl.UnloadTexture(foreground)  // Unload foreground texture

    rl.CloseWindow()              // Close window and OpenGL context
}