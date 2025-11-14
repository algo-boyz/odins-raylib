package main

import "base:runtime"
import "core:fmt"
import "core:strings"

import rl "vendor:raylib"
import raydial "../../"

Text_Speed :: enum i32 {
    Slow = 1,
    Normal = 3,
    Fast = 6,
}

Animated_Text :: struct {
    full_text: string,          // Complete text to display
    display_text: string,       // Current displayed text (partial)
    text_length: i32,           // Length of full text
    current_length: i32,        // Currently displayed length
    speed: Text_Speed,          // Animation speed
    animation_complete: bool,   // Flag for animation completion
    frames_counter: i32,        // Frame counter for animation timing
}

init_animated_text :: proc(text: string, speed: Text_Speed, allocator := context.allocator) -> Animated_Text {
    anim: Animated_Text
    anim.full_text = text
    anim.text_length = i32(len(text))
    anim.display_text = ""
    anim.current_length = 0
    anim.speed = speed
    anim.animation_complete = false
    anim.frames_counter = 0
    return anim
}

update_animated_text :: proc(anim: ^Animated_Text) {
    if anim.animation_complete { return }

    anim.frames_counter += 1

    // Update text based on speed
    if anim.frames_counter >= (60 / (i32(anim.speed) * 5)) {
        anim.frames_counter = 0

        if anim.current_length < anim.text_length {
            // Append next character
            new_text, err := strings.concatenate([]string{anim.display_text, string(anim.full_text[anim.current_length : anim.current_length+1])}, context.allocator)
            if err != nil {
                fmt.eprintln("Error concatenating strings: %s", err)
                return
            }
            anim.display_text = new_text
            anim.current_length += 1

            // Play a typing sound (simulated with console output)
            if anim.current_length % 5 == 0 {
                fmt.println("*click*")
            }
        } else {
            anim.animation_complete = true
        }
    }
}

get_animated_text :: proc(anim: ^Animated_Text) -> string {
    return anim.display_text
}

on_set_speed_slow :: proc "c" (user_data: rawptr) {
    context = runtime.default_context()
    anim := cast(^Animated_Text)user_data
    anim.speed = .Slow
    fmt.println("Text speed set to SLOW")
}

on_set_speed_normal :: proc "c" (user_data: rawptr) {
    context = runtime.default_context()
    anim := cast(^Animated_Text)user_data
    anim.speed = .Normal
    fmt.println("Text speed set to NORMAL")
}

on_set_speed_fast :: proc "c" (user_data: rawptr) {
    context = runtime.default_context()
    anim := cast(^Animated_Text)user_data
    anim.speed = .Fast
    fmt.println("Text speed set to FAST")
}

on_reset_animation :: proc "c" (user_data: rawptr) {
    context = runtime.default_context()
    anim := cast(^Animated_Text)user_data
    anim.current_length = 0
    anim.display_text = ""
    anim.animation_complete = false
    fmt.println("Animation reset")
}

on_complete_animation :: proc "c" (user_data: rawptr) {
    context = runtime.default_context()
    anim := cast(^Animated_Text)user_data
    anim.display_text = anim.full_text
    anim.current_length = anim.text_length
    anim.animation_complete = true
    fmt.println("Animation completed")
}

main :: proc() {
    screen_width :: 800
    screen_height :: 600
    rl.InitWindow(screen_width, screen_height, "Animated Text Example")
    rl.SetTargetFPS(60)

    // Init animated text with a much longer text to demonstrate scrolling
    dialogue_text := "Once upon a time in a land far, far away...\n\n" +
        "There lived a brave hero who embarked on a journey to save the kingdom " +
        "from an ancient evil that had awakened after centuries of slumber.\n\n" +
        "The hero faced many challenges along the way, but with determination " +
        "and courage, continued forward despite all obstacles.\n\n" +
        "As our hero ventured deeper into the mysterious forest, they encountered strange creatures " +
        "and magical phenomena that defied explanation. Trees whispered secrets of old, and streams " +
        "flowed with water that glowed under the moonlight.\n\n" +
        "In a small clearing, the hero found an old hermit living in a hut made of twisted branches " +
        "and moss. The hermit spoke of prophecies and destinies, of stars aligning and ancient powers " +
        "stirring once more.\n\n" +
        "'You have been chosen,' said the hermit, handing the hero a peculiar amulet. 'This will " +
        "guide you through the darkness ahead. But beware, for where there is great power, there is " +
        "also great danger.'\n\n" +
        "They stood before a fortress of obsidian that seemed to devour light itself. The amulet " +
        "glowed brighter than ever, pushing back the darkness just enough for them to find their way forward.\n\n" +
        "'Remember why we're here,' the hero said to their companions. 'For the future of all.'\n\n" +
        "And with that, they stepped into the unknown, ready to face whatever awaited them within the heart " +
        "of darkness...\n\n" +
        "TO BE CONTINUED..."

    anim_text := init_animated_text(dialogue_text, .Normal)

    // Create dialogue node
    root_node := raydial.create_dialogue_node("root", "Animated Text Example")

    // Create dialogue manager
    manager := raydial.create_dialogue_manager(root_node)

    // Create UI panel
    panel := raydial.create_panel({100, 100, 600, 400}, rl.RAYWHITE)

    // Create title
    title := raydial.create_label({120, 120, 560, 40}, "Animated Text Example - Now With Scrolling!", true)

    // Create animated text label - this will now be scrollable
    text_label := raydial.create_label({120, 170, 560, 220}, "", true)

    // Create speed control buttons
    slow_button := raydial.create_button({120, 400, 150, 40}, "Slow Speed", on_set_speed_slow, &anim_text)

    normal_button := raydial.create_button({280, 400, 150, 40}, "Normal Speed", on_set_speed_normal, &anim_text)

    fast_button := raydial.create_button({440, 400, 150, 40}, "Fast Speed", on_set_speed_fast, &anim_text)

    // Create control buttons
    reset_button := raydial.create_button({120, 450, 230, 40}, "Reset Animation", on_reset_animation, &anim_text)

    complete_button := raydial.create_button({360, 450, 230, 40}, "Complete Animation", on_complete_animation, &anim_text)

    // Assemble UI
    raydial.add_component(panel, title)
    raydial.add_component(panel, text_label)
    raydial.add_component(panel, slow_button)
    raydial.add_component(panel, normal_button)
    raydial.add_component(panel, fast_button)
    raydial.add_component(panel, reset_button)
    raydial.add_component(panel, complete_button)

    // Set root node component
    root_node.components = panel

    for !rl.WindowShouldClose() {
        update_animated_text(&anim_text)

        // Update the text label with current animation state
        text_data := cast(^raydial.Label_Data)text_label.data
        text_data.text = get_animated_text(&anim_text)

        // Update
        raydial.update_dialogue_manager(manager)

        rl.BeginDrawing()
        rl.ClearBackground(rl.SKYBLUE)
        raydial.draw_dialogue_manager(manager)

        // Draw additional info
        rl.DrawText("Press ESC to exit", 10, screen_height - 30, 20, rl.DARKGRAY)
        rl.DrawText("Use mouse wheel or arrow keys to scroll text", 10, screen_height - 60, 20, rl.DARKGRAY)

        // Draw animation status
        status := anim_text.animation_complete ? "Animation complete" : "Animating..."
        rl.DrawText(fmt.ctprint(status), 10, 10, 20, rl.DARKGRAY)

        // Draw current speed
        speed_text: cstring
        switch anim_text.speed {
        case .Slow: speed_text = "Speed: Slow"
        case .Normal: speed_text = "Speed: Normal"
        case .Fast: speed_text = "Speed: Fast"
        }
        rl.DrawText(speed_text, 10, 40, 20, rl.DARKGRAY)
        rl.EndDrawing()
    }
    // Cleanup
    raydial.free_dialogue_manager(manager)
    rl.CloseWindow()
}