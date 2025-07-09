package textures

import "vendor:raylib"

WIDTH  :: 800
HEIGTH :: 450

main :: proc() {
    using raylib
    InitWindow(WIDTH, HEIGTH, "Blend Modes")
    defer CloseWindow()

    bgImage := LoadImage("../paralax/assets/cyberpunk_street_background.png")
    bgTexture := LoadTextureFromImage(bgImage)
    defer UnloadTexture(bgTexture)
    UnloadImage(bgImage)

    fgImage := LoadImage("../paralax/assets/cyberpunk_street_foreground.png")
    fgTexture := LoadTextureFromImage(fgImage)
    defer UnloadTexture(fgTexture)
    UnloadImage(fgImage)

    blendCountMax :: 4
    blendMode: BlendMode

    for !WindowShouldClose() {
        if IsKeyPressed(.SPACE) {
            if int(blendMode) >= blendCountMax - 1 {
                blendMode = BlendMode(0)
            } else {
                blendMode += BlendMode(1)
            }
        }
        BeginDrawing()
            ClearBackground(RAYWHITE)
            DrawTexture(bgTexture, WIDTH/2 - bgTexture.width/2, HEIGTH/2 - bgTexture.height/2, WHITE)

            BeginBlendMode(blendMode)
                DrawTexture(fgTexture, WIDTH/2 - fgTexture.width/2, HEIGTH/2 - fgTexture.height/2, WHITE)
            EndBlendMode()

            DrawText("Press SPACE to change blend modes.", 310, 350, 10, GRAY)

            #partial switch blendMode {
            case .ALPHA:      DrawText("Current: BLEND_ALPHA", (WIDTH/2) - 60, 370, 10, GRAY)
            case .ADDITIVE:   DrawText("Current: BLEND_ADDITIVE", (WIDTH/2) - 60, 370, 10, GRAY)
            case .MULTIPLIED: DrawText("Current: BLEND_MULTIPLIED", (WIDTH/2) - 60, 370, 10, GRAY)
            case .ADD_COLORS: DrawText("Current: BLEND_ADD_COLORS", (WIDTH/2) - 60, 370, 10, GRAY)
            }
            DrawText("(c) Cyberpunk Street Environment by Luis Zuno (@ansimuz)", WIDTH - 330, HEIGTH - 20, 10, GRAY)
        EndDrawing()
    }
}