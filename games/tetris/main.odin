package tetris

import rl "vendor:raylib"
import "core:fmt"
import "core:time"

last_update_time: f64 = 0

event_triggered :: proc(interval: f64) -> bool {
    current_time := f64(rl.GetTime())
    if current_time - last_update_time >= interval {
        last_update_time = current_time
        return true
    }
    return false
}

main :: proc() {
    rl.InitWindow(500, 620, "Tetris")
    defer rl.CloseWindow()
    
    rl.SetTargetFPS(60)
    
    // Load font
    font := rl.LoadFontEx("assets/monogram.ttf", 64, nil, 0)
    
    // Initialize game
    g := init_game()
    defer destroy_game(&g)
    
    for !rl.WindowShouldClose() {
        // Update music stream
        rl.UpdateMusicStream(g.music)
        
        // Handle input and game updates
        game_handle_input(&g)
        if event_triggered(0.2) {
            move_block_down(&g)
        }
        
        // Drawing
        rl.BeginDrawing()        
        rl.ClearBackground(DARK_BLUE)
        
        // Draw text
        rl.DrawTextEx(font, "Score", rl.Vector2{365, 15}, 38, 2, rl.WHITE)
        rl.DrawTextEx(font, "Next", rl.Vector2{370, 175}, 38, 2, rl.WHITE)
        
        if g.game_over {
            rl.DrawTextEx(font, "GAME OVER", rl.Vector2{320, 450}, 38, 2, rl.WHITE)
        }
        
        // Draw score box
        score_box := rl.Rectangle{320, 55, 170, 60}
        rl.DrawRectangleRounded(score_box, 0.3, 6, LIGHT_BLUE)
        
        // Draw score
        score_text := fmt.ctprintf("%d", g.score)
        text_size := rl.MeasureTextEx(font, score_text, 38, 2)
        score_pos := rl.Vector2{
            320 + (170 - text_size.x) / 2,
            65,
        }
        rl.DrawTextEx(font, score_text, score_pos, 38, 2, rl.WHITE)
        
        // Draw next piece box
        next_box := rl.Rectangle{320, 215, 170, 180}
        rl.DrawRectangleRounded(next_box, 0.3, 6, LIGHT_BLUE)
        
        // Draw game
        game_draw(&g)
        rl.EndDrawing()
    }
}