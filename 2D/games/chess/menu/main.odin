package main

import "../"
import "core:fmt"
import rl "vendor:raylib"

WINDOW_WIDTH :: 640
WINDOW_HEIGHT :: 800

Button :: struct {
    texture: rl.Texture2D,
    position: rl.Vector2,
}

// Constructor equivalent
create_button :: proc(image_path: cstring, image_position: rl.Vector2, scale: f32) -> Button {
    img := rl.LoadImage(image_path)
    original_width := img.width
    original_height := img.height
    new_width := i32(f32(original_width) * scale)
    new_height := i32(f32(original_height) * scale)
    
    rl.ImageResize(&img, new_width, new_height)
    tex := rl.LoadTextureFromImage(img)
    rl.UnloadImage(img)
    
    return Button{
        texture = tex,
        position = image_position,
    }
}

// Destructor equivalent
destroy_button :: proc(button: ^Button) {
    rl.UnloadTexture(button.texture)
}

draw_button :: proc(button: ^Button) {
    rl.DrawTextureV(button.texture, button.position, rl.WHITE)
}

is_button_pressed :: proc(button: ^Button, mouse_pos: rl.Vector2, mouse_pressed: bool) -> bool {
    rect := rl.Rectangle{
        x = button.position.x,
        y = button.position.y,
        width = f32(button.texture.width),
        height = f32(button.texture.height),
    }
    
    return rl.CheckCollisionPointRec(mouse_pos, rect) && mouse_pressed
}

main :: proc() {
    rl.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "Chess")
    rl.SetTargetFPS(60)
    
    bg := rl.LoadImage("assets/bg.png")
    rl.ImageResize(&bg, WINDOW_WIDTH, WINDOW_HEIGHT)
    tex := rl.LoadTextureFromImage(bg)
    rl.UnloadImage(bg)

    // Create buttons
    start_button := create_button("assets/start_button.png", rl.Vector2{50, 670}, 0.65)
    exit_button := create_button("assets/exit_button.png", rl.Vector2{370, 670}, 0.65)
    
    exit := false
    
    for !rl.WindowShouldClose() && !exit {
        // Input
        mouse_position := rl.GetMousePosition()
        mouse_pressed := rl.IsMouseButtonPressed(.LEFT)
        
        // Update
        if is_button_pressed(&start_button, mouse_position, mouse_pressed) {
            fmt.println("Start Button Pressed")
            game := chess.init()
            chess.run(game)
            chess.destroy(game)
        }
        
        if is_button_pressed(&exit_button, mouse_position, mouse_pressed) {
            exit = true
        }
        
        // Draw
        rl.BeginDrawing()
        rl.ClearBackground(rl.BLACK)
        
        rl.DrawTexture(tex, 0, 0, rl.WHITE)
        draw_button(&start_button)
        draw_button(&exit_button)
        
        rl.EndDrawing()
    }
    
    // Cleanup
    destroy_button(&start_button)
    destroy_button(&exit_button)
    rl.UnloadTexture(tex)
}