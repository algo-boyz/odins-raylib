package main 

import rl "vendor:raylib"

WINDOW_WIDTH :: 800
WINDOW_HEIGHT :: 800

main :: proc() {
    rl.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "Taste the rainbow")

    rl.SetTargetFPS(30)

    SCREEN_CENTER := rl.Vector2{
        WINDOW_WIDTH / 2,
        WINDOW_HEIGHT / 2
    }

    factor :f32 = 1.0
    rotation:f32
    offset := rl.Vector2{0.0, 0.0}

    for !rl.WindowShouldClose() {
        rl.BeginDrawing()

        rl.ClearBackground(rl.BLACK)

        rl.DrawCircleSector(SCREEN_CENTER + offset, 105 * factor, -180 + rotation, 0 + rotation, 30, rl.VIOLET)
        rl.DrawCircleSector(SCREEN_CENTER + offset, 90 * factor, -180 + rotation, 0 + rotation, 30, rl.PURPLE)
        rl.DrawCircleSector(SCREEN_CENTER + offset, 75 * factor, -180 + rotation, 0 + rotation, 30, rl.BLUE)
        rl.DrawCircleSector(SCREEN_CENTER + offset, 60 * factor, -180 + rotation, 0 + rotation, 30, rl.GREEN)
        rl.DrawCircleSector(SCREEN_CENTER + offset, 45 * factor, -180 + rotation, 0 + rotation, 30, rl.YELLOW)
        rl.DrawCircleSector(SCREEN_CENTER + offset, 30 * factor, -180 + rotation, 0 + rotation, 30, rl.ORANGE)
        rl.DrawCircleSector(SCREEN_CENTER + offset, 15 * factor, -180 + rotation, 0 + rotation, 30, rl.RED)

        rl.GuiLabel(rl.Rectangle{96, 36, 216, 16}, "Scale Rainbow")
        rl.GuiSlider(rl.Rectangle{ 96, 48, 216, 16 }, rl.TextFormat("%0.1f", factor), nil, &factor, 0.0, 2.5)

        rl.GuiLabel(rl.Rectangle{96, 64, 216, 16}, "Rotation")
        rl.GuiSlider(rl.Rectangle{ 96, 80, 216, 16 }, rl.TextFormat("%0.1f", rotation), nil, &rotation, 0.0, 360.0)

        rl.GuiLabel(rl.Rectangle{96, 96, 216, 16}, "Rainbow X:")
        rl.GuiSlider(rl.Rectangle{ 96, 112, 216, 16 }, rl.TextFormat("%0.1f", offset.x), nil, &offset.x, -100.0, 100.0)

        rl.GuiLabel(rl.Rectangle{96, 128, 216, 16}, "Rainbow Y:")
        rl.GuiSlider(rl.Rectangle{ 96, 144, 216, 16 }, rl.TextFormat("%0.1f", offset.y), nil, &offset.y, -100.0, 350.0)

        if(rl.GuiButton(rl.Rectangle{96, 176, 216, 16}, "Reset")) {
            factor = 1.0
            rotation = 0.0
            offset = rl.Vector2{0.0, 0.0}
        }
        rl.EndDrawing()
    }

    rl.CloseWindow()
}