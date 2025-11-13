package main

import "base:runtime"
import "core:fmt"
import rl "vendor:raylib"
import raydial "../../"

// Character states (used for switching portraits)
CHARACTER_HAPPY :: 0
CHARACTER_NEUTRAL :: 1
CHARACTER_SAD :: 2
CHARACTER_ANGRY :: 3

// Example dialogue data with rich text formatting
DialogueEntry :: struct {
    speaker_name: string,
    dialogue_text: string,
    portrait_state: i32,
    show_on_right: bool,
}

// Structure to track conversation state
ConversationState :: struct {
    entries: [^]DialogueEntry,
    entry_count: i32,
    current_index: i32,
    portrait_dialogue: ^raydial.Component,
}

// Create a basic emotional face based on state (same as in example 5)
draw_emotional_face :: proc(bounds: rl.Rectangle, emotion_state: i32) {
    face_color: rl.Color
    switch emotion_state {
    case CHARACTER_HAPPY:
        face_color = rl.YELLOW
    case CHARACTER_NEUTRAL:
        face_color = rl.LIGHTGRAY
    case CHARACTER_SAD:
        face_color = rl.BLUE
    case CHARACTER_ANGRY:
        face_color = rl.RED
    case:
        face_color = rl.WHITE
    }
    
    // Draw face
    center_x := bounds.x + bounds.width / 2
    center_y := bounds.y + bounds.height / 2
    radius := min(bounds.width, bounds.height) / 2.2
    rl.DrawCircleV({center_x, center_y}, radius, face_color)
               
    // Draw features based on emotion
    switch emotion_state {
    case CHARACTER_HAPPY:
        // Happy face
        rl.DrawCircleV({bounds.x + bounds.width / 3, bounds.y + bounds.height * 0.4}, 5, rl.BLACK)
        rl.DrawCircleV({bounds.x + bounds.width * 2 / 3, bounds.y + bounds.height * 0.4}, 5, rl.BLACK)
        rl.DrawText(")", i32(bounds.x + bounds.width * 0.45), i32(bounds.y + bounds.height * 0.6), 30, rl.BLACK)
    case CHARACTER_NEUTRAL:
        // Neutral face
        rl.DrawCircleV({bounds.x + bounds.width / 3, bounds.y + bounds.height * 0.4}, 5, rl.BLACK)
        rl.DrawCircleV({bounds.x + bounds.width * 2 / 3, bounds.y + bounds.height * 0.4}, 5, rl.BLACK)
        rl.DrawRectangle(i32(bounds.x + bounds.width / 3), i32(bounds.y + bounds.height * 0.7), i32(bounds.width / 3), 5, rl.BLACK)
    case CHARACTER_SAD:
        // Sad face
        rl.DrawCircleV({bounds.x + bounds.width / 3, bounds.y + bounds.height * 0.4}, 5, rl.BLACK)
        rl.DrawCircleV({bounds.x + bounds.width * 2 / 3, bounds.y + bounds.height * 0.4}, 5, rl.BLACK)
        rl.DrawText("(", i32(bounds.x + bounds.width * 0.45), i32(bounds.y + bounds.height * 0.6), 30, rl.BLACK)
    case CHARACTER_ANGRY:
        // Angry face
        rl.DrawCircleV({bounds.x + bounds.width / 3, bounds.y + bounds.height * 0.4}, 5, rl.BLACK)
        rl.DrawCircleV({bounds.x + bounds.width * 2 / 3, bounds.y + bounds.height * 0.4}, 5, rl.BLACK)
        rl.DrawLineV({bounds.x + bounds.width / 3, bounds.y + bounds.height * 0.7}, {bounds.x + bounds.width * 2 / 3, bounds.y + bounds.height * 0.75}, rl.BLACK)
        // Angry eyebrows
        rl.DrawLineV({bounds.x + bounds.width / 4, bounds.y + bounds.height * 0.3}, {bounds.x + bounds.width * 0.4, bounds.y + bounds.height * 0.35}, rl.BLACK)
        rl.DrawLineV({bounds.x + bounds.width * 3 / 4, bounds.y + bounds.height * 0.3}, {bounds.x + bounds.width * 0.6, bounds.y + bounds.height * 0.35}, rl.BLACK)
    }
}

// Progress to the next dialogue entry
OnNextDialogue :: proc "c" (user_data: rawptr) {
    context = runtime.default_context() 
    conversation := cast(^ConversationState)user_data
    
    conversation.current_index += 1
    if conversation.current_index >= conversation.entry_count {
        // Loop back to the beginning when we reach the end
        conversation.current_index = 0
    }
    
    // Get the current dialogue entry
    current_entry := &conversation.entries[conversation.current_index]
    
    // Update the portrait dialogue component with stylized text
    raydial.set_portrait_dialogue_speaker(conversation.portrait_dialogue, current_entry.speaker_name)
    raydial.set_portrait_dialogue_styled_text(conversation.portrait_dialogue, current_entry.dialogue_text)
    color := rl.RED
    if current_entry.portrait_state == CHARACTER_HAPPY {
        color = rl.YELLOW
    } else if current_entry.portrait_state == CHARACTER_NEUTRAL {
        color = rl.LIGHTGRAY
    } else if current_entry.portrait_state == CHARACTER_SAD {
        color = rl.BLUE
    }
    raydial.set_portrait_dialogue_color(conversation.portrait_dialogue, color)
    raydial.set_portrait_dialogue_position(conversation.portrait_dialogue, current_entry.show_on_right)
    
    fmt.printf("Showing styled dialogue %d of %d: %s\n", conversation.current_index + 1, conversation.entry_count, current_entry.speaker_name)
}

main :: proc() {
    // Init window
    screen_width: i32 = 1024 // Increased width
    screen_height: i32 = 768 // Increased height
    rl.InitWindow(screen_width, screen_height, "Styled Dialogue Example")
    rl.SetTargetFPS(60)
    
    // Init dialogue entries with rich text styling
    dialogues: [9]DialogueEntry = {
        {"Knight", "Hello adventurer! I'm [color=yellow]Sir Galahad[/color], knight of the realm.", CHARACTER_HAPPY, false},
        {"Wizard", "I am [color=blue]Merlin[/color], a [size=large]wizard[/size] of great power.", CHARACTER_NEUTRAL, true},
        {"Knight", "We need your help to defeat the [color=red][b]dragon[/b][/color] that threatens our kingdom!", CHARACTER_NEUTRAL, false},
        {"Wizard", "This quest will be [size=small]dangerous[/size] but [size=large]rewarding[/size]! Are you prepared?", CHARACTER_SAD, true},
        {"Knight", "Take this [color=yellow]golden[/color] sword. It will aid you on your journey.", CHARACTER_HAPPY, false},
        {"Wizard", "[color=red][size=large]WARNING![/size][/color] The dragon breathes fire that can melt even the strongest armor.", CHARACTER_ANGRY, true},
        {"Knight", "But with [color=blue]courage[/color] and [color=green]wisdom[/color], you shall prevail!", CHARACTER_NEUTRAL, false},
        {"Wizard", "Remember: The dragon's weakness is its [color=purple][b]crystal heart[/b][/color]. Aim for it!", CHARACTER_NEUTRAL, true},
        {"Knight", "May the gods bless your journey, [size=large]brave hero[/size]!", CHARACTER_HAPPY, false},
    }
    
    // Init conversation state
    conversation: ConversationState
    conversation.entries = &dialogues[0]
    conversation.entry_count = i32(len(dialogues))
    conversation.current_index = 0
    
    // Create dialogue node
    root_node := raydial.create_dialogue_node("root", "Styled Dialogue Example")
    
    // Create dialogue manager
    manager := raydial.create_dialogue_manager(root_node)
    
    // Create main UI panel (larger and centered)
    panel := raydial.create_panel(
        {f32((screen_width - 800) / 2), f32((screen_height - 600) / 2), 800, 600}, // Centered 800x600 panel
        rl.RAYWHITE,
    )
    
    // Create title (adjust position)
    title := raydial.create_label(
        {panel.bounds.x + 20, panel.bounds.y + 20, panel.bounds.width - 40, 40},
        "Styled Dialogue Text Example",
        true,
    )
    
    // Create portrait dialogue component (make shorter again)
    first_entry := &conversation.entries[0]
    color := rl.RED
    if first_entry.portrait_state == CHARACTER_HAPPY {
        color = rl.YELLOW
    } else if first_entry.portrait_state == CHARACTER_NEUTRAL {
        color = rl.LIGHTGRAY
    } else if first_entry.portrait_state == CHARACTER_SAD {
        color = rl.BLUE
    }
    portrait_dialogue := raydial.create_portrait_dialogue(
        {panel.bounds.x + 20, panel.bounds.y + 70, panel.bounds.width - 40, 330}, // Reduced height from 350 to 330
        first_entry.speaker_name,
        "Plain text version",  // Will be replaced with styled text
        color,
    )
    
    // Set styled text for the dialogue
    raydial.set_portrait_dialogue_styled_text(portrait_dialogue, first_entry.dialogue_text)
    
    // Store the portrait dialogue component in the conversation state
    conversation.portrait_dialogue = portrait_dialogue
    
    // Set initial portrait position
    raydial.set_portrait_dialogue_position(portrait_dialogue, first_entry.show_on_right)
    
    // Create next dialogue button (adjust Y position)
    button_y := panel.bounds.y + 70 + 330 + 10 // Position below shorter dialogue box + padding
    next_button := raydial.create_button(
        {panel.bounds.x + (panel.bounds.width - 180) / 2, button_y, 180, 40}, // Use calculated buttonY
        "Next Dialogue",
        OnNextDialogue,
        &conversation,
    )
    
    // Create info label (adjust Y position and give more height)
    legend_height_estimate: f32 = 50 // Approximate height needed for legend text
    legend_y := button_y + 40 + 10 // Position below button + padding
    info_label_y := legend_y + legend_height_estimate 
    info_label_height := panel.bounds.y + panel.bounds.height - info_label_y - 20 // Fill remaining space minus bottom padding
    
    info_label := raydial.create_label(
        {panel.bounds.x + 20, info_label_y, panel.bounds.width - 40, info_label_height}, // Use calculated Y and Height
        "This example demonstrates styled text with colors, sizes, and formatting",
        true,
    )
    
    // Add components to the panel
    raydial.add_component(panel, title)
    raydial.add_component(panel, portrait_dialogue)
    raydial.add_component(panel, next_button)
    raydial.add_component(panel, info_label)
    
    // Set the panel as the root node's component
    root_node.components = panel
    
    // Main game loop
    for !rl.WindowShouldClose() {
        // Update
        raydial.update_dialogue_manager(manager)
        
        // Draw
        rl.BeginDrawing()
        rl.ClearBackground(rl.DARKGRAY) // Slightly different background
        
        // Draw manager (UI components)
        raydial.draw_dialogue_manager(manager)
        
        // Custom drawing for the portrait (override the default solid color)
        current_entry := &conversation.entries[conversation.current_index]
        portrait_bounds: rl.Rectangle
        portrait_area_y := portrait_dialogue.bounds.y + 10
        portrait_area_size: f32 = 100 // Keep portrait size fixed for now
        
        if current_entry.show_on_right {
            portrait_bounds = { 
                portrait_dialogue.bounds.x + portrait_dialogue.bounds.width - portrait_area_size - 10, 
                portrait_area_y, 
                portrait_area_size, 
                portrait_area_size 
            }
        } else {
            portrait_bounds = { 
                portrait_dialogue.bounds.x + 10, 
                portrait_area_y, 
                portrait_area_size, 
                portrait_area_size 
            }
        }
        
        // Draw the emotional face
        draw_emotional_face(portrait_bounds, current_entry.portrait_state)
        
        // Draw formatting legend (Adjust Y relative to button)
        rl.DrawText("Formatting Tags:", i32(panel.bounds.x + 20), i32(legend_y), 20, rl.BLACK)
        rl.DrawText("[color=red]text[/color]", i32(panel.bounds.x + 20), i32(legend_y + 30), 16, rl.RED)
        rl.DrawText("[size=large]text[/size]", i32(panel.bounds.x + 220), i32(legend_y + 30), 16, rl.BLACK)
        rl.DrawText("[b]text[/b] (bold)", i32(panel.bounds.x + 420), i32(legend_y + 30), 16, rl.BLACK)
        
        // Draw help text (Relative to screen bottom)
        rl.DrawText("Press ESC to exit", 10, screen_height - 30, 20, rl.DARKGRAY)
        rl.EndDrawing()
    }
    
    // Cleanup
    raydial.free_dialogue_manager(manager)
    rl.CloseWindow()
}