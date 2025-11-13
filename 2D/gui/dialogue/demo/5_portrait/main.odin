package main

import "base:runtime"
import "core:fmt"
import rl "vendor:raylib"
import raydial "../../"

CHARACTER_HAPPY :: 0
CHARACTER_NEUTRAL :: 1
CHARACTER_SAD :: 2
CHARACTER_ANGRY :: 3

DialogueEntry :: struct {
    speaker_name,
    dialogue_text: string,
    portrait_state: i32,
    show_on_right: bool,
}

ConversationState :: struct {
    entries: [^]DialogueEntry,
    entry_count, current_index: i32,
    portrait_dialogue: ^raydial.Component,
}

// Create a basic emotional face based on state
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
    
    // Update the portrait dialogue component
    raydial.set_portrait_dialogue_speaker(conversation.portrait_dialogue, current_entry.speaker_name)
    raydial.set_portrait_dialogue_text(conversation.portrait_dialogue, current_entry.dialogue_text)
    color : rl.Color
    if current_entry.portrait_state == CHARACTER_HAPPY {
        color = rl.YELLOW
    } else if current_entry.portrait_state == CHARACTER_NEUTRAL {
        color = rl.LIGHTGRAY
    } else if current_entry.portrait_state == CHARACTER_SAD {
        color = rl.BLUE
    } else {
        color = rl.RED
    }
    raydial.set_portrait_dialogue_color(conversation.portrait_dialogue, color)
    raydial.set_portrait_dialogue_position(conversation.portrait_dialogue, current_entry.show_on_right)
    
    fmt.printf("Showing dialogue %d of %d: %s\n", conversation.current_index + 1, conversation.entry_count, current_entry.speaker_name)
}

main :: proc() {
    screen_width:: 800
    screen_height:: 600
    rl.InitWindow(screen_width, screen_height, "Portrait Dialogue Example")
    rl.SetTargetFPS(60)
    
    // Init dialogue entries
    dialogues: [9]DialogueEntry = {
        {"Hero", "Hello there! I'm excited to start this adventure with you.", CHARACTER_HAPPY, false},
        {"Companion", "Nice to meet you. I'll be your guide throughout this journey.", CHARACTER_NEUTRAL, true},
        {"Hero", "What should we expect to find along the way?", CHARACTER_NEUTRAL, false},
        {"Companion", "Dangers and treasures both await us. We need to be careful.", CHARACTER_SAD, true},
        {"Hero", "I'm ready for anything! Let's get started.", CHARACTER_HAPPY, false},
        {"Companion", "Wait! We should prepare better before rushing in!", CHARACTER_ANGRY, true},
        {"Hero", "Oh, sorry. You're right. What do you suggest we do first?", CHARACTER_SAD, false},
        {"Companion", "Let's gather some supplies and information at the nearby village.", CHARACTER_NEUTRAL, true},
        {"Hero", "That sounds like a good plan. Lead the way!", CHARACTER_HAPPY, false},
    }
    // Init conversation state
    conversation: ConversationState
    conversation.entries = &dialogues[0]
    conversation.entry_count = i32(len(dialogues))
    conversation.current_index = 0
    
    // Create dialogue node
    root_node := raydial.create_dialogue_node("root", "Portrait Dialogue Example")
    
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
        "Portrait Dialogue Example",
        true,
    )
    
    // Create portrait dialogue component
    first_entry := &conversation.entries[0]
    color:rl.Color
    if first_entry.portrait_state == CHARACTER_HAPPY {
        color = rl.YELLOW
    } else if first_entry.portrait_state == CHARACTER_NEUTRAL {
        color = rl.LIGHTGRAY
    } else if first_entry.portrait_state == CHARACTER_SAD {
        color = rl.BLUE
    } else {
        color = rl.RED
    }
    portrait_dialogue := raydial.create_portrait_dialogue(
        {70, 120, 660, 300},
        first_entry.speaker_name,
        first_entry.dialogue_text,
        color,
    )
    
    // Store the portrait dialogue component in the conversation state
    conversation.portrait_dialogue = portrait_dialogue
    
    // Set initial portrait position
    raydial.set_portrait_dialogue_position(portrait_dialogue, first_entry.show_on_right)
    
    // Create next dialogue button
    next_button := raydial.create_button(
        {325, 430, 150, 40},
        "Next Dialogue",
        OnNextDialogue,
        &conversation,
    )
    
    // Create info label
    info_label := raydial.create_label(
        {70, 480, 660, 30},
        "Press the button to advance through the conversation",
        true,
    )
    
    // Add components to the panel
    raydial.add_component(panel, title)
    raydial.add_component(panel, portrait_dialogue)
    raydial.add_component(panel, next_button)
    raydial.add_component(panel, info_label)
    
    // Set the panel as the root node's component
    root_node.components = panel
    
    for !rl.WindowShouldClose() {
        raydial.update_dialogue_manager(manager)
        // Draw
        rl.BeginDrawing()
        rl.ClearBackground(rl.SKYBLUE)
        
        // Draw manager (UI components)
        raydial.draw_dialogue_manager(manager)
        
        // Custom drawing for the portrait (override the default solid color)
        current_entry := &conversation.entries[conversation.current_index]
        portrait_bounds: rl.Rectangle
        if current_entry.show_on_right {
            portrait_bounds = { 
                portrait_dialogue.bounds.x + portrait_dialogue.bounds.width - 110, 
                portrait_dialogue.bounds.y + 10, 
                100, 
                100 
            }
        } else {
            portrait_bounds = { 
                portrait_dialogue.bounds.x + 10, 
                portrait_dialogue.bounds.y + 10, 
                100, 
                100 
            }
        }
        draw_emotional_face(portrait_bounds, current_entry.portrait_state)

        rl.DrawText("Press ESC to exit", 10, screen_height - 30, 20, rl.DARKGRAY)
        rl.EndDrawing()
    }

    raydial.free_dialogue_manager(manager)
    rl.CloseWindow()
}