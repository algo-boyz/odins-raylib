package main

import "base:runtime"
import "core:fmt"
import "core:strings"
import rl "vendor:raylib"
import raydial "../../"

Gallery_State :: struct {
    colors: [dynamic]rl.Color,      // Colored rectangles instead of images
    image_count: i32,
    image_titles: [dynamic]string,
    image_descriptions: [dynamic]string,
    current_image_index: i32,
    scroll_position: f32,
}

// Button callbacks
on_next_img :: proc "c" (user_data: rawptr) {
    context = runtime.default_context()
    state := cast(^Gallery_State)user_data
    if state.current_image_index < state.image_count - 1 {
        state.current_image_index += 1
        state.scroll_position = 0 // Reset scroll position for new image
        fmt.printf("Showing image %d of %d\n", state.current_image_index + 1, state.image_count)
    }
}

on_prev_img :: proc "c" (user_data: rawptr) {
    context = runtime.default_context()
    state := cast(^Gallery_State)user_data
    if state.current_image_index > 0 {
        state.current_image_index -= 1
        state.scroll_position = 0
        fmt.printf("Showing image %d of %d\n", state.current_image_index + 1, state.image_count)
    }
}

load_gallery :: proc(allocator := context.allocator) -> Gallery_State {
    state: Gallery_State
    
    // Create colors for our "portraits"
    state.image_count = 4
    reserve(&state.colors, i32(state.image_count))
    reserve(&state.image_titles, i32(state.image_count))
    reserve(&state.image_descriptions, i32(state.image_count))
    
    // Set colors for each portrait
    append(&state.colors, rl.YELLOW)      // Happy
    append(&state.colors, rl.LIGHTGRAY)   // Neutral
    append(&state.colors, rl.BLUE)        // Sad
    append(&state.colors, rl.RED)         // Angry
    
    // Set titles and description
    titles := []string {
        "Happy Portrait (Yellow)",
        "Neutral Portrait (Gray)",
        "Sad Portrait (Blue)",
        "Angry Portrait (Red)",
    }
    
    descriptions := []string{
        "This is the happy portrait, represented by yellow.\n\n",
        "Yellow is often associated with happiness, optimism, and positive energy. ",
        "This color can be used to represent cheerful character expressions.",
        "This is the neutral portrait, represented by gray.\n\n",
        "Gray represents neutrality and balance. It's perfect for situations ",
        "where the character isn't expressing any particular emotion.",
        "This is the sad portrait, represented by blue.\n\n",
        "Blue is often associated with sadness, melancholy, and calm. ",
        "It works well for representing a character who is feeling down.",
        "This is the angry portrait, represented by red.\n\n",
        "Red represents anger, passion, and intensity. It's an effective color ",
        "for showing that a character is upset or agitated.",
    }
    
    for title, i in titles {
        append(&state.image_titles, strings.clone(title, allocator))
    }
    
    for desc, i in descriptions {
        append(&state.image_descriptions, strings.clone(desc, allocator))
    }
    
    state.current_image_index = 0
    state.scroll_position = 0
    
    return state
}

unload_gallery :: proc(state: ^Gallery_State, allocator := context.allocator) {
    for title in &state.image_titles {
        delete(title)
    }
    for desc in &state.image_descriptions {
        delete(desc)
    }
    
    delete(state.colors)
    delete(state.image_titles)
    delete(state.image_descriptions)
}

main :: proc() {
    screen_width  :: 800
    screen_height :: 600
    rl.InitWindow(screen_width, screen_height, "Image Gallery Example")
    rl.SetTargetFPS(60)
    
    // Init image gallery
    gallery := load_gallery()
    defer unload_gallery(&gallery)
    
    // Create dialogue node
    root_node := raydial.create_dialogue_node("root", "Image Gallery Example")
    
    // Create dialogue manager
    manager := raydial.create_dialogue_manager(root_node)
    
    // Create main UI panel
    panel := raydial.create_panel(
        {50, 50, 700, 500},
        rl.RAYWHITE,
    )
    
    // Create title
    title := raydial.create_label(
        {70, 70, 660, 40},
        "Color Portrait Gallery",
        true,
    )
    
    // Create image display area
    image_panel := raydial.create_panel(
        {70, 120, 300, 300},
        rl.LIGHTGRAY,
    )
    
    // Create description panel instead of scroll area
    description_panel := raydial.create_panel(
        {390, 120, 340, 300},
        rl.LIGHTGRAY,
    )
    
    // Create image title label
    image_title := raydial.create_label(
        {400, 130, 320, 40},
        gallery.image_titles[0],
        true,
    )
    
    // Create image description label
    image_description := raydial.create_label(
        {400, 180, 320, 220},
        gallery.image_descriptions[0],
        true,
    )
    
    // Create navigation buttons
    prev_button := raydial.create_button(
        {70, 430, 150, 40},
        "Prev Color",
        on_prev_img,
        &gallery,
    )
    
    next_button := raydial.create_button(
        {230, 430, 150, 40},
        "Next Color",
        on_next_img,
        &gallery,
    )
    
    // Create info label
    info_label := raydial.create_label(
        {390, 430, 340, 40},
        "Use the buttons to navigate between colors",
        true,
    )
    
    // Add components to the description panel
    raydial.add_component(description_panel, image_title)
    raydial.add_component(description_panel, image_description)
    
    // Add components to the main panel
    raydial.add_component(panel, title)
    raydial.add_component(panel, image_panel)
    raydial.add_component(panel, description_panel)
    raydial.add_component(panel, prev_button)
    raydial.add_component(panel, next_button)
    raydial.add_component(panel, info_label)
    
    // Set the panel as the root node's component
    root_node.components = panel
    
    for !rl.WindowShouldClose() {
        raydial.update_dialogue_manager(manager)
        
        // Update image and description based on current selection
        title_buffer := fmt.tprintf("%s (%d of %d)", 
            gallery.image_titles[gallery.current_image_index],
            gallery.current_image_index + 1, 
            gallery.image_count)

        // text := cast(^raydial.Label_Data)image_title.data
        // title_buffer.text = text
        // gallery.image_descriptions[gallery.current_image_index] = cast(^raydial.Label_Data)image_description.data.text
        
        // Draw
        rl.BeginDrawing()
        rl.ClearBackground(rl.SKYBLUE)
        
        // Draw manager (UI components)
        raydial.draw_dialogue_manager(manager)
        
        // Draw current portrait as colored rectangle
        rl.DrawRectangle(
            i32(image_panel.bounds.x + 50),
            i32(image_panel.bounds.y + 50),
            200,
            200,
            gallery.colors[gallery.current_image_index],
        )
        
        // Add facial expression to colored rectangle
        if gallery.current_image_index == 0 {  // Happy
            rl.DrawCircle(i32(image_panel.bounds.x + 150), i32(image_panel.bounds.y + 150), 100, gallery.colors[0])
            rl.DrawCircle(i32(image_panel.bounds.x + 120), i32(image_panel.bounds.y + 120), 15, rl.BLACK)
            rl.DrawCircle(i32(image_panel.bounds.x + 180), i32(image_panel.bounds.y + 120), 15, rl.BLACK)
            rl.DrawText(")", i32(image_panel.bounds.x + 140), i32(image_panel.bounds.y + 170), 40, rl.BLACK)
        } else if gallery.current_image_index == 1 {  // Neutral
            rl.DrawCircle(i32(image_panel.bounds.x + 150), i32(image_panel.bounds.y + 150), 100, gallery.colors[1])
            rl.DrawCircle(i32(image_panel.bounds.x + 120), i32(image_panel.bounds.y + 120), 15, rl.BLACK)
            rl.DrawCircle(i32(image_panel.bounds.x + 180), i32(image_panel.bounds.y + 120), 15, rl.BLACK)
            rl.DrawRectangle(i32(image_panel.bounds.x + 130), i32(image_panel.bounds.y + 180), 40, 5, rl.BLACK)
        } else if gallery.current_image_index == 2 {  // Sad
            rl.DrawCircle(i32(image_panel.bounds.x + 150), i32(image_panel.bounds.y + 150), 100, gallery.colors[2])
            rl.DrawCircle(i32(image_panel.bounds.x + 120), i32(image_panel.bounds.y + 120), 15, rl.BLACK)
            rl.DrawCircle(i32(image_panel.bounds.x + 180), i32(image_panel.bounds.y + 120), 15, rl.BLACK)
            rl.DrawText("(", i32(image_panel.bounds.x + 140), i32(image_panel.bounds.y + 170), 40, rl.BLACK)
        } else if gallery.current_image_index == 3 {  // Angry
            rl.DrawCircle(i32(image_panel.bounds.x + 150), i32(image_panel.bounds.y + 150), 100, gallery.colors[3])
            rl.DrawCircle(i32(image_panel.bounds.x + 120), i32(image_panel.bounds.y + 120), 15, rl.BLACK)
            rl.DrawCircle(i32(image_panel.bounds.x + 180), i32(image_panel.bounds.y + 120), 15, rl.BLACK)
            rl.DrawLine(i32(image_panel.bounds.x + 130), i32(image_panel.bounds.y + 180), 
                        i32(image_panel.bounds.x + 170), i32(image_panel.bounds.y + 190), rl.BLACK)
        }
        
        rl.DrawText("Press ESC to exit", 10, screen_height - 30, 20, rl.DARKGRAY)
        rl.EndDrawing()
    }
    raydial.free_dialogue_manager(manager)
    rl.CloseWindow()
}