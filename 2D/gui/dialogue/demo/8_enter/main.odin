package main

import rl "vendor:raylib"
import "core:fmt"
import "core:strings"
import raydial "../../"

Dialogue_State :: struct {
    dialogues: []string,
    dialogue_count: int,
    current_index: int,
    dialogue_label: ^raydial.Component,
}

example_dialogues := []string{
    "Welcome to the Enter Dialogue Example!",
    "This example shows how to progress through dialogue using the Enter key.",
    "Press Enter to continue to the next line of dialogue.",
    "You can also use the Space key if you prefer.",
    "The dialogue will loop back to the beginning when it reaches the end.",
    "Thank you for trying out this example!",
}

update_dialogue :: proc(state: ^Dialogue_State) {
    // Check for Enter or Space key press
    if rl.IsKeyPressed(.ENTER) || rl.IsKeyPressed(.SPACE) {
        // Move to next dialogue
        state.current_index = (state.current_index + 1) % state.dialogue_count

        // Update the label text
        data := cast(^raydial.Label_Data)state.dialogue_label.data
        data.text = state.dialogues[state.current_index]
    }
}

main :: proc() {
    // Init window
    screen_width :: 800
    screen_height :: 450
    rl.InitWindow(screen_width, screen_height, "Enter Dialogue Example")
    rl.SetTargetFPS(60)

    // Init dialogue state
    state: Dialogue_State = {
        dialogues = example_dialogues,
        dialogue_count = len(example_dialogues),
        current_index = 0,
    }

    // Create dialogue manager and root node
    root_node := raydial.create_dialogue_node("root", "Enter Dialogue Example")
    manager := raydial.create_dialogue_manager(root_node)

    // Create UI components
    panel := raydial.create_panel({100, 100, 600, 250}, rl.LIGHTGRAY)

    // Create dialogue label
    state.dialogue_label = raydial.create_label({120, 120, 560, 180}, state.dialogues[0], true)

    // Create instruction label
    instruction_label := raydial.create_label({120, 320, 560, 20}, "Press Enter or Space to continue", false)

    // Assemble UI
    raydial.add_component(panel, state.dialogue_label)
    raydial.add_component(panel, instruction_label)
    root_node.components = panel

    // Main game loop
    for !rl.WindowShouldClose() {
        // Update dialogue based on keyboard input
        update_dialogue(&state)

        // Update dialogue manager
        raydial.update_dialogue_manager(manager)

        // Draw
        rl.BeginDrawing()
        defer rl.EndDrawing()
        rl.ClearBackground(rl.RAYWHITE)
        raydial.draw_dialogue_manager(manager)

        // Draw current dialogue index
        index_text := fmt.tprintf("Dialogue %d/%d", state.current_index + 1, state.dialogue_count)
        rl.DrawText(strings.clone_to_cstring(index_text, context.temp_allocator), 10, 10, 20, rl.DARKGRAY)
    }

    // Cleanup
    raydial.free_dialogue_manager(manager)
    rl.CloseWindow()
}