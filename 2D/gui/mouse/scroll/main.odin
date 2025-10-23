package main

import "core:fmt"
import "core:math" // NEW: For abs
import rl "vendor:raylib"

Product :: struct {
    name:     string,
    category: string,
    animated: bool,
}

Thumbnail :: struct {
    name:      string,
    category:  string,
    primary:   rl.Color,
    secondary: rl.Color,
}

main :: proc() {
    WIDTH:  i32 = 1024
    HEIGHT: i32 = 768

    rl.InitWindow(WIDTH, HEIGHT, "Scroll Gallery Demo")
    defer rl.CloseWindow()

    rl.SetTargetFPS(60)

    // Grid Properties
    grid_cols:   i32 = 4
    cell_width:  i32 = 180
    cell_height: i32 = 200
    cell_pad:    i32 = 20

    // Scroll Variables
    scroll_y:              f32  = 0.0
    speed:                 f32  = 200.0
    is_dragging_scrollbar: bool = false
    
    // NEW: Scroll animation variables
    target_scroll_y:      f32  = 0.0
    is_animating_scroll:  bool = false
    animation_speed:      f32  = 1.0 // Adjust for faster/slower animation

    // Product Data (Omitted for brevity, no changes)
    items := []Product{
        {"Simple Character", "Characters", true}, {"Robot", "Characters", true},
        {"Animal", "Characters", true}, {"Ghost", "Characters", true},
        {"Soldier", "Characters", true}, {"Zombie", "Characters", true},
        {"Wizard", "Characters", true}, {"Dragon", "Characters", true},
        {"Skeleton", "Characters", true}, {"Mummy", "Characters", true},
        {"Frankenstein", "Characters", true}, {"Dracula", "Characters", true},
        {"Werewolf", "Characters", true},
        {"Tree", "Environment", false}, {"Cloud", "Environment", false},
        {"House", "Environment", false}, {"Castle", "Environment", false},
        {"Bush", "Environment", false}, {"Rock", "Environment", false},
        {"Flower", "Environment", false}, {"Fish", "Environment", false},
        {"Snowman", "Environment", true},
        {"Car", "Vehicles", false}, {"Tank", "Vehicles", false},
        {"Motorcycle", "Vehicles", false}, {"Skateboard", "Vehicles", false},
        {"Sailboat", "Vehicles", false}, {"Airplane", "Vehicles", true},
        {"UFO", "Vehicles", true},
        {"Sword", "Items", false}, {"Arrow", "Items", false},
        {"Key", "Items", false}, {"Shield", "Items", false},
        {"Crown", "Items", false}, {"Coin", "Items", false},
        {"Gem", "Items", false}, {"Potion", "Items", true},
        {"Treasure Chest", "Items", true}, {"Cannon", "Items", true},
        {"Apple", "Items", false}, {"Banana", "Items", false},
        {"Orange", "Items", false}, {"Watermelon", "Items", false},
        {"Grape", "Items", false}, {"Grapes", "Items", false},
        {"Star", "Magic", true}, {"Lightning", "Magic", false},
        {"Explosion", "Magic", true}, {"Portal", "Magic", true},
        {"Waterfall", "Magic", true},
        {"Water Drop", "Special Shapes", true},
        {"Button", "UI", false},
        {"Health Bar", "UI", false},
    }

    models := []Thumbnail{
        {"Pine Tree (3D)", "3D Models", rl.BROWN, rl.DARKGREEN},
        {"Oak Tree (3D)", "3D Models", rl.DARKBROWN, rl.LIME},
        {"Autumn Tree (3D)", "3D Models", rl.BROWN, rl.DARKBROWN},
        {"Green Robot (3D)", "3D Models", rl.DARKGRAY, rl.GREEN},
        {"Blue Robot (3D)", "3D Models", rl.BLUE, rl.RED},
        {"Silver Spaceship (3D)", "3D Models", rl.LIGHTGRAY, rl.SKYBLUE},
        {"Red Spaceship (3D)", "3D Models", rl.RED, rl.YELLOW},
    }

    items_count := len(items)
    models_count := len(models)
    total_items := i32(items_count + models_count)
    
    grid_rows := (total_items + grid_cols - 1) / grid_cols
    totalHeight := f32(grid_rows * (cell_height + cell_pad / 2))
    max_y := totalHeight - f32(HEIGHT) + 40
    
    // Main Game Loop
    for !rl.WindowShouldClose() {
        // Update
        deltaTime := rl.GetFrameTime()
        mouse_pos := rl.GetMousePosition()
        
        // Handle mouse wheel scrolling
        wheel_move := rl.GetMouseWheelMove()
        if wheel_move != 0 {
            is_animating_scroll = false // NEW: Interrupt animation
            scroll_y -= wheel_move * speed * deltaTime
        }

        // START: SCROLLBAR LOGIC
        if max_y > 0 {
            // -- Scrollbar Properties --
            scrollbar_width:  i32 = 10
            scrollbar_margin: i32 = 4
            track_height:     f32 = f32(HEIGHT - 40 - 2 * scrollbar_margin)
            track_x:          i32 = WIDTH - scrollbar_width - scrollbar_margin
            track_y:          i32 = 40 + scrollbar_margin
            track_rect       := rl.Rectangle{f32(track_x), f32(track_y), f32(scrollbar_width), track_height}

            // -- Handle (Thumb) Calculations --
            viewable_ratio := f32(HEIGHT - 40) / totalHeight
            handle_height  := max(track_height * viewable_ratio, 20)
            
            scroll_percentage := scroll_y / max_y
            handle_y          := f32(track_y) + (track_height - handle_height) * scroll_percentage
            handle_rect       := rl.Rectangle{f32(track_x), handle_y, f32(scrollbar_width), handle_height}

            // -- Handle Input --
            if rl.IsMouseButtonPressed(.LEFT) {
                if rl.CheckCollisionPointRec(mouse_pos, handle_rect) {
                    is_dragging_scrollbar = true
                    is_animating_scroll = false // NEW: Interrupt animation
                } else if rl.CheckCollisionPointRec(mouse_pos, track_rect) {
                    // NEW: Clicked on the track, not the handle -> start animation
                    is_animating_scroll = true
                    is_dragging_scrollbar = false
                    
                    // Calculate where the center of the handle should be
                    relative_mouse_y := mouse_pos.y - f32(track_y)
                    target_handle_center := relative_mouse_y
                    
                    // Convert that position to a scroll percentage
                    scroll_percent := (target_handle_center - handle_height / 2) / (track_height - handle_height)
                    
                    // Set the target scroll position
                    target_scroll_y = scroll_percent * max_y
                }
            }

            if rl.IsMouseButtonReleased(.LEFT) {
                is_dragging_scrollbar = false
            }

            if is_dragging_scrollbar {
                scroll_ratio := max_y / (track_height - handle_height)
                scroll_y += rl.GetMouseDelta().y * scroll_ratio
            }
        }
        
        // NEW: Smooth Scroll Animation Logic
        if is_animating_scroll && !is_dragging_scrollbar {
            // Lerp scroll_y towards the target_scroll_y
            scroll_y += (target_scroll_y - scroll_y) * animation_speed * deltaTime

            // Stop animating when we are very close to the target
            if abs(target_scroll_y - scroll_y) < 0.1 {
                scroll_y = target_scroll_y // Snap to final position
                is_animating_scroll = false
            }
        }

        // Clamp scrolling to bounds
        if max_y > 0 {
            if scroll_y < 0 { scroll_y = 0 }
            if scroll_y > max_y { scroll_y = max_y }

            // NEW: Clamp the animation target as well
            if target_scroll_y < 0 { target_scroll_y = 0 }
            if target_scroll_y > max_y { target_scroll_y = max_y }
        } else {
            scroll_y = 0
        }

        rl.BeginDrawing()
        defer rl.EndDrawing()

        rl.ClearBackground(rl.RAYWHITE)
        
        // --- DRAWING LOGIC (Omitted for brevity, no changes) ---
        // Draw Grid
        for i in 0..<items_count {
            col := i32(i) % grid_cols
            row := i32(i) / grid_cols

            x := f32(col * cell_width + cell_width / 2 + cell_pad)
            y := f32(row * cell_height + cell_height / 2 + cell_pad) - scroll_y

            if y >= f32(-cell_height) && y <= f32(HEIGHT + cell_height) {
                box := rl.Rectangle{
                    f32(col * cell_width + cell_pad / 2),
                    f32(row * cell_height + cell_pad / 2) - scroll_y,
                    f32(cell_width - cell_pad),
                    f32(cell_height - cell_pad),
                }
                col: rl.Color
                switch items[i].category {
                case "Characters":
                    col = {230, 240, 255, 255}
                case "Environment":
                    col = {230, 255, 230, 255}
                case "Magic":
                    col = {230, 230, 255, 255}
                case:
                    col = {255, 240, 230, 255}
                }
                
                rl.DrawRectangleRec(box, col)
                rl.DrawRectangleLinesEx(box, 1, rl.LIGHTGRAY)
                rl.DrawCircleV({x, y - 10}, 30, rl.LIGHTGRAY)
                rl.DrawText(fmt.ctprint(items[i].name), i32(box.x + 10), i32(box.y + box.height - 40), 16, rl.DARKGRAY)
                rl.DrawText(fmt.ctprint(items[i].category), i32(box.x + 10), i32(box.y + box.height - 20), 13, rl.GRAY)
            }
        }
        
        // Draw 3D Models Grid
        for i in 0..<models_count {
            idx := items_count + i
            col := i32(idx) % grid_cols
            row := i32(idx) / grid_cols

            x := f32(col * cell_width + cell_width / 2 + cell_pad)
            y := f32(row * cell_height + cell_height / 2 + cell_pad) - scroll_y

            if y >= f32(-cell_height) && y <= f32(HEIGHT + cell_height) {
                box := rl.Rectangle{
                    f32(col * cell_width + cell_pad / 2),
                    f32(row * cell_height + cell_pad / 2) - scroll_y,
                    f32(cell_width - cell_pad),
                    f32(cell_height - cell_pad),
                }
                
                rl.DrawRectangleRec(box, rl.Color{240, 230, 255, 255})
                rl.DrawRectangleLinesEx(box, 1, rl.LIGHTGRAY)
                rl.DrawCubeV({x, y - 10, 0}, {40, 40, 40}, models[i].primary)
                rl.DrawRectangle(i32(x - 15), i32(y - 50), 30, 20, rl.RED)
                rl.DrawText("3D", i32(x - 10), i32(y - 47), 16, rl.WHITE)
                rl.DrawText(fmt.ctprint(models[i].name), i32(box.x + 10), i32(box.y + box.height - 40), 16, rl.DARKGRAY)
                rl.DrawText(fmt.ctprint(models[i].category), i32(box.x + 10), i32(box.y + box.height - 20), 13, rl.GRAY)
            }
        }

        // Draw the scrollbar if there is content to scroll through
        if max_y > 0 {
            scrollbar_width:  i32 = 10
            scrollbar_margin: i32 = 4
            track_height:     f32 = f32(HEIGHT - 40 - 2 * scrollbar_margin)
            track_x:          i32 = WIDTH - scrollbar_width - scrollbar_margin
            track_y:          i32 = 40 + scrollbar_margin

            viewable_ratio := f32(HEIGHT - 40) / totalHeight
            handle_height  := max(track_height * viewable_ratio, 20)

            scroll_percentage := scroll_y / max_y
            handle_y          := f32(track_y) + (track_height - handle_height) * scroll_percentage
            
            // Draw the background track
            rl.DrawRectangle(track_x, track_y, scrollbar_width, i32(track_height), rl.Fade(rl.LIGHTGRAY, 0.5))
            // Draw the handle
            rl.DrawRectangle(track_x, i32(handle_y), scrollbar_width, i32(handle_height), rl.Fade(rl.GRAY, 0.7))
        }
        
        rl.DrawRectangle(0, 0, WIDTH, 40, rl.Fade(rl.RAYWHITE, 0.9))
        // UPDATED: Changed text to reflect new functionality
        rl.DrawText("Scroll (wheel, drag, or click track)", 20, 10, 20, rl.DARKGRAY)
        rl.DrawFPS(WIDTH - 100, 10)
    }
}