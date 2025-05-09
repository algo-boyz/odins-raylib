package main

import "core:fmt"
import rl "vendor:raylib"

// Character struct to hold character information
Character :: struct {
    name: cstring,
    image: rl.Texture2D,
    health: f32,
    max_health: f32,
}

// Create a character with a name, texture, and health
create_character :: proc(name: cstring, image_path: cstring, health: f32) -> Character {
    character_image := rl.LoadTexture(image_path)
    return Character {
        name = name,
        image = character_image,
        health = health,
        max_health = health,
    }
}

// Draw health bar for a character
draw_health_bar :: proc(character: ^Character, x, y, width, height: f32, is_left: bool) {
    // Background of health bar (dark color)
    rl.DrawRectangle(
        cast(i32)x, 
        cast(i32)y, 
        cast(i32)width, 
        cast(i32)height, 
        rl.DARKGRAY
    )
    
    // Calculate current health percentage
    health_percentage := character.health / character.max_health
    current_width := width * health_percentage
    
    // Health bar color (green to red based on health)
    health_color := rl.GREEN
    if health_percentage < 0.3 do health_color = rl.RED
    
    // Draw health bar (left-to-right or right-to-left based on character position)
    if is_left {
        rl.DrawRectangle(
            cast(i32)x, 
            cast(i32)y, 
            cast(i32)current_width, 
            cast(i32)height, 
            health_color
        )
    } else {
        rl.DrawRectangle(
            cast(i32)(x + width - current_width), 
            cast(i32)y, 
            cast(i32)current_width, 
            cast(i32)height, 
            health_color
        )
    }
}

// Draw character box with name and image
draw_character_box :: proc(character: ^Character, x, y, box_width, box_height: f32, is_left: bool) {
    // Draw character box background
    rl.DrawRectangle(
        cast(i32)x, 
        cast(i32)y, 
        cast(i32)box_width, 
        cast(i32)box_height, 
        rl.DARKBLUE
    )
    
    // Draw character name
    rl.DrawText(
        character.name, 
        cast(i32)(x + 10), 
        cast(i32)(y + 10), 
        20, 
        rl.WHITE
    )
    
    // Draw character image
    image_x := is_left ? x + 10 : x + box_width - f32(character.image.width - 10)
    rl.DrawTexture(
        character.image, 
        cast(i32)image_x, 
        cast(i32)(y + 40), 
        rl.WHITE
    )
}

main :: proc() {
    screen_width  :: 1024
    screen_height :: 768
    
    rl.InitWindow(screen_width, screen_height, "Street Fighter Menu")
    rl.SetTargetFPS(60)
    
    // Create background
    background := rl.LoadTexture("background.png")
    
    // Create characters
    ryu := create_character("Ryu", "ryu.png", 100)
    ken := create_character("Ken", "ken.png", 100)
    
    // Main game loop
    for !rl.WindowShouldClose() {
        rl.BeginDrawing()
        rl.ClearBackground(rl.RAYWHITE)
        
        // Draw background
        rl.DrawTexture(background, 0, 0, rl.WHITE)
        
        // Draw health bars
        draw_health_bar(&ryu, 50, 50, 300, 30, true)
        draw_health_bar(&ken, screen_width - 350, 50, 300, 30, false)
        
        // Draw character boxes
        draw_character_box(&ryu, 50, 100, 200, 250, true)
        draw_character_box(&ken, screen_width - 250, 100, 200, 250, false)
        
        // Simulate health decrease for demonstration
        if rl.IsKeyDown(.R) do ryu.health -= 0.5
        if rl.IsKeyDown(.K) do ken.health -= 0.5
        
        rl.EndDrawing()
    }
    
    // Cleanup
    rl.UnloadTexture(background)
    rl.UnloadTexture(ryu.image)
    rl.UnloadTexture(ken.image)
    
    rl.CloseWindow()
}