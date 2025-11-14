package main

import rl "vendor:raylib"
import raydial "../../"

screen_width :: 800
screen_height :: 450

main :: proc() {
    rl.InitWindow(screen_width, screen_height, "Basic Example")
    rl.SetTargetFPS(60)

    // Create a root dialogue node
    root_node := raydial.create_dialogue_node("root", "ROOT!")

    // Create a dialogue manager
    manager := raydial.create_dialogue_manager(root_node)

    // Create UI components for the root node
    panel := raydial.create_panel({100, 100, 600, 250}, rl.RAYWHITE)

    title_label := raydial.create_label(
        {120, 120, 560, 40},
        "Welcome!",
        true, // Enable text wrapping
    )

    message_label := raydial.create_label(
        {120, 170, 560, 150},
        "This is a basic example creating a dialogue.\n\nText will properly wrap within the bounds of this component, preventing overflow and making the UI look pretty.",
        true,
    )

    // Add components to the panel
    raydial.add_component(panel, title_label)
    raydial.add_component(panel, message_label)

    // Set the panel as the root node's component
    root_node.components = panel

    for !rl.WindowShouldClose() {
        raydial.update_dialogue_manager(manager)

        rl.BeginDrawing()
        rl.ClearBackground(rl.RAYWHITE)
        raydial.draw_dialogue_manager(manager)
        rl.DrawText("Press ESC to exit", 10, screen_height - 30, 20, rl.DARKGRAY)
        rl.EndDrawing()
    }
    raydial.free_dialogue_manager(manager)
    rl.CloseWindow()
}