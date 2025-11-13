package main

import "core:fmt"
import "core:strings"
import rl "vendor:raylib"
import raydial "../../"

Counter_State :: struct {
    counter: i32,
}

on_increment :: proc "c" (user_data: rawptr) {
    state := cast(^Counter_State)user_data
    state.counter += 1
}

on_decrement :: proc "c" (user_data: rawptr) {
    state := cast(^Counter_State)user_data
    if state.counter > 0 {
        state.counter -= 1
    }
}

on_reset :: proc "c" (user_data: rawptr) {
    state := cast(^Counter_State)user_data
    state.counter = 0
}

main :: proc() {
    // Init window
    screen_width :: 800
    screen_height :: 600
    rl.InitWindow(screen_width, screen_height, "Counter Example")
    rl.SetTargetFPS(60)

    // Init state
    state: Counter_State = {counter = 0}

    // Create dialogue node
    root_node := raydial.create_dialogue_node("root", "Counter Example")

    // Create dialogue manager
    manager := raydial.create_dialogue_manager(root_node)

    // Create UI panel
    panel := raydial.create_panel(
        {150, 100, 500, 400},
        rl.RAYWHITE,
    )

    // Create title
    title := raydial.create_label(
        {170, 120, 460, 50},
        "Interactive Counter",
        true,
    )

    // Create description
    description := raydial.create_label(
        {170, 180, 460, 80},
        "This example demonstrates button functionality with proper text wrapping.\n\nUse the buttons below to change the counter value.",
        true,
    )

    // Create counter display
    counter_display := raydial.create_label(
        {170, 270, 460, 60},
        "Counter: 0",
        true,
    )

    // Create buttons
    increment_button := raydial.create_button(
        {170, 340, 150, 50},
        "Increment",
        on_increment,
        &state,
    )

    decrement_button := raydial.create_button(
        {340, 340, 150, 50},
        "Decrement",
        on_decrement,
        &state,
    )

    reset_button := raydial.create_button(
        {170, 410, 320, 50},
        "Reset Counter",
        on_reset,
        &state,
    )

    // Assemble UI
    raydial.add_component(panel, title)
    raydial.add_component(panel, description)
    raydial.add_component(panel, counter_display)
    raydial.add_component(panel, increment_button)
    raydial.add_component(panel, decrement_button)
    raydial.add_component(panel, reset_button)

    // Set root node component
    root_node.components = panel

    // Main game loop
    for !rl.WindowShouldClose() {
        // Update
        raydial.update_dialogue_manager(manager)

        // Update counter display
        data := cast(^raydial.Label_Data)counter_display.data
        data.text = fmt.tprintf("Current value: %d", state.counter)

        // Draw
        rl.BeginDrawing()
        defer rl.EndDrawing()
        rl.ClearBackground(rl.SKYBLUE)
        raydial.draw_dialogue_manager(manager)
        rl.DrawText("Press ESC to exit", 10, screen_height - 30, 20, rl.DARKGRAY)
    }

    // Cleanup
    raydial.free_dialogue_manager(manager)
    rl.CloseWindow()
}