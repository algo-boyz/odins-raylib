package main

import "base:runtime"
import "core:fmt"
import "core:os"
import "core:strings"
import rl "vendor:raylib"
import raydial "../../"
import i18n "../../i18n/"

AppState :: struct {
    i18n: ^i18n.I18N,
    dialogue_component: ^raydial.Component,
    language_label: ^raydial.Component,
    greeting_label: ^raydial.Component,
    title: ^raydial.Component,
    switch_button: ^raydial.Component,
    current_language_index: i32,
    available_languages: [3]string,
    original_default_font: rl.Font,
    greek_font: rl.Font,
    greek_font_loaded: bool,
}

main :: proc() {
    // Init window
    screen_width: i32 = 800
    screen_height: i32 = 600
    rl.InitWindow(screen_width, screen_height, "RayDial Localization Example")
    rl.SetTargetFPS(60)
    
    // Store the original default font
    original_default_font := rl.GetFontDefault()
    
    // Print current working directory for debugging
    cwd := os.get_current_directory()
    if cwd != "" {
        fmt.printf("Current working directory: %s\n", cwd)
    }
    
    // Init application state
    state: AppState
    state.original_default_font = original_default_font
    state.greek_font_loaded = false
    
    // Define the characters needed for Greek text + common Latin/symbols
    greek_chars:cstring = "Παράδειγμα τοπικοποίησης Καλώς ήρθατε στη RayDial Αλλαγή γλώσσας Δείγμα διαλόγου Οδηγός Αυτό είναι ένα παράδειγμα [color=green]κειμένου[/color] με [size=large]μορφοποίηση[/size]. Τρέχουσα: Ελληνικά ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789 .,:;!?()[]{}<>\"'"
    codepoint_count: i32
    codepoints := rl.LoadCodepoints(greek_chars, &codepoint_count)
    defer rl.UnloadCodepoints(codepoints)
    fmt.printf("Attempting to load %d glyphs for Greek font.\n", codepoint_count)
    
    // Try to load Greek font from system paths with specific codepoints
    paths := []string {
        "/System/Library/Fonts/Supplemental/Arial Unicode.ttf", // Common on macOS
        "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",      // Common on Linux
        "C:/Windows/Fonts/Arial.ttf",                           // Common on Windows (might lack Greek)
        "C:/Windows/Fonts/Tahoma.ttf",                          // Common on Windows
    }
    
    for path in paths {
        if os.exists(path) {
            cpath := strings.clone_to_cstring(path, context.temp_allocator)
            font := rl.LoadFontEx(cpath, 20, &codepoints[0], codepoint_count)
            if font.texture.id != 0 {
                state.greek_font = font
                state.greek_font_loaded = true
                fmt.printf("Successfully loaded Greek font (%d glyphs) from: %s\n", font.glyphCount, path)
                break // Stop searching once a font is loaded
            } else {
                fmt.printf("Failed to load Greek font from: %s\n", path)
            }
        }
    }
    
    if !state.greek_font_loaded {
        fmt.printf("Warning: Could not load any suitable Greek font. Greek text may not display correctly.\n")
        // Assign the original font to greekFont to avoid null issues later if needed, though it won't display correctly.
        state.greek_font = state.original_default_font
    }
    
    // Init localization system
    i18n_mgr := i18n.create_i18n_manager()
    state.i18n = i18n_mgr
    
    // Add supported languages
    i18n.add_language(i18n_mgr, "en", "English")
    i18n.add_language(i18n_mgr, "es", "Español")
    i18n.add_language(i18n_mgr, "el", "Ελληνικά") // Greek
    
    // Set English as the default language
    i18n.set_current_language(i18n_mgr, "en")
    
    // Define translation keys and values for English
    i18n.add_translation(i18n_mgr, "en", "title", "Localization Example")
    i18n.add_translation(i18n_mgr, "en", "greetingLabel", "Welcome to RayDial localization")
    i18n.add_translation(i18n_mgr, "en", "switchLanguage", "Switch Language")
    i18n.add_translation(i18n_mgr, "en", "dialogueTitle", "Sample Dialogue")
    i18n.add_translation(i18n_mgr, "en", "speakerName", "Guide")
    i18n.add_translation(i18n_mgr, "en", "dialogueText", "This is an example of [color=green]localized text[/color] with [size=large]styled[/size] formatting.")
    i18n.add_translation(i18n_mgr, "en", "currentLanguage", "Current Language: English")
    
    // Spanish translations
    i18n.add_translation(i18n_mgr, "es", "title", "Ejemplo de Localización")
    i18n.add_translation(i18n_mgr, "es", "greetingLabel", "Bienvenido a la localización de RayDial")
    i18n.add_translation(i18n_mgr, "es", "switchLanguage", "Cambiar Idioma")
    i18n.add_translation(i18n_mgr, "es", "dialogueTitle", "Diálogo de Ejemplo")
    i18n.add_translation(i18n_mgr, "es", "speakerName", "Guía")
    i18n.add_translation(i18n_mgr, "es", "dialogueText", "Este es un ejemplo de [color=green]texto localizado[/color] con formato [size=large]estilizado[/size].")
    i18n.add_translation(i18n_mgr, "es", "currentLanguage", "Idioma Actual: Español")
    
    // Greek translations
    i18n.add_translation(i18n_mgr, "el", "title", "Παράδειγμα τοπικοποίησης")
    i18n.add_translation(i18n_mgr, "el", "greetingLabel", "Καλώς ήρθατε στη τοπικοποίηση RayDial")
    i18n.add_translation(i18n_mgr, "el", "switchLanguage", "Αλλαγή γλώσσας")
    i18n.add_translation(i18n_mgr, "el", "dialogueTitle", "Δείγμα διαλόγου")
    i18n.add_translation(i18n_mgr, "el", "speakerName", "Οδηγός")
    i18n.add_translation(i18n_mgr, "el", "dialogueText", "Αυτό είναι ένα παράδειγμα [color=green]τοπικοποιημένου κειμένου[/color] με [size=large]μορφοποίηση[/size].")
    i18n.add_translation(i18n_mgr, "el", "currentLanguage", "Τρέχουσα γλώσσα: Ελληνικά")
    
    // Init application state
    state.current_language_index = 0
    state.available_languages = {"en", "es", "el"}
    
    // Create dialogue node
    root_node := raydial.create_dialogue_node("root", "Localized Dialogue Node")
    
    // Create dialogue manager
    manager := raydial.create_dialogue_manager(root_node)
    
    // Create main UI panel
    panel := raydial.create_panel(
        {50, 50, 700, 500},
        rl.RAYWHITE,
    )
    
    // Create title with localized text
    state.title = raydial.create_localized_label(
        {70, 70, 660, 40},
        "title",
        true,
        i18n_mgr,
    )
    
    // Create greeting label with localized text
    state.greeting_label = raydial.create_localized_label(
        {70, 120, 660, 30},
        "greetingLabel",
        true,
        i18n_mgr,
    )
    
    // Create language display label
    state.language_label = raydial.create_localized_label(
        {70, 160, 660, 30},
        "currentLanguage",
        true,
        i18n_mgr,
    )
    
    // Create portrait dialogue with localized text
    state.dialogue_component = raydial.create_localized_portrait_dialogue(
        {70, 200, 660, 220},
        "speakerName",
        "dialogueText",
        rl.BLUE,
        i18n_mgr,
    )
    
    // Enable styled text for the dialogue
    raydial.set_localized_portrait_dialogue_styled_text(state.dialogue_component, "dialogueText", i18n_mgr)
    
    // Create language switch button
    state.switch_button = raydial.create_localized_button(
        {300, 430, 200, 40},
        "switchLanguage",
        OnSwitchLanguage,
        &state,
        i18n_mgr,
    )
    
    // Add components to the panel
    raydial.add_component(panel, state.title)
    raydial.add_component(panel, state.greeting_label)
    raydial.add_component(panel, state.language_label)
    raydial.add_component(panel, state.dialogue_component)
    raydial.add_component(panel, state.switch_button)
    
    // Set the panel as the root node's component
    root_node.components = panel
    
    // Main game loop
    for !rl.WindowShouldClose() {
        // Update
        raydial.update_dialogue_manager(manager)
        
        // Determine current font based on language
        current_font:rl.Font
        if state.current_language_index == 2 && state.greek_font_loaded { current_font = state.greek_font } else { current_font = state.original_default_font }
        
        // Draw
        rl.BeginDrawing()
        rl.ClearBackground(rl.SKYBLUE)
        
        // Manual Drawing of Components 
        // We bypass DrawDialogueManager to control font usage
        
        // 1. Draw Panel Background (using data from the panel component)
        panel_data := cast(^raydial.Panel_Data)panel.data
        rl.DrawRectangleRec(panel.bounds, panel_data.background_color)
        rl.DrawRectangleLinesEx(panel.bounds, panel_data.border_width, panel_data.border_color)
        
        // Get localized text for components manually
        title_text := i18n.get_localized_text(state.i18n, "title")
        greeting_text := i18n.get_localized_text(state.i18n, "greetingLabel")
        lang_label_text := i18n.get_localized_text(state.i18n, "currentLanguage")
        button_text := i18n.get_localized_text(state.i18n, "switchLanguage")
        speaker_name_text := i18n.get_localized_text(state.i18n, "speakerName")
        // Note: Dialogue text needs special handling for styled text
        
        // 2. Draw Title Label (using raylib directly)
        title_data := cast(^raydial.Label_Data)state.title.data
        title_cstr := strings.clone_to_cstring(title_text, context.temp_allocator)
        rl.DrawTextEx(current_font, title_cstr, {state.title.bounds.x, state.title.bounds.y}, f32(title_data.font_size), 1, title_data.text_color)
        
        // 3. Draw Greeting Label
        greeting_data := cast(^raydial.Label_Data)state.greeting_label.data
        greeting_cstr := strings.clone_to_cstring(greeting_text, context.temp_allocator)
        rl.DrawTextEx(current_font, greeting_cstr, {state.greeting_label.bounds.x, state.greeting_label.bounds.y}, f32(greeting_data.font_size), 1, greeting_data.text_color)
        
        // 4. Draw Current Language Label
        lang_label_data := cast(^raydial.Label_Data)state.language_label.data
        lang_label_cstr := strings.clone_to_cstring(lang_label_text, context.temp_allocator)
        rl.DrawTextEx(current_font, lang_label_cstr, {state.language_label.bounds.x, state.language_label.bounds.y}, f32(lang_label_data.font_size), 1, lang_label_data.text_color)
        
        // 5. Draw Portrait Dialogue (More complex - replicating parts of DrawComponent)
        dialogue_data := cast(^raydial.Portrait_Dialogue_Data)state.dialogue_component.data
        dialogue_bounds := state.dialogue_component.bounds
        portrait_size := dialogue_data.portrait_size
        padding: i32 = 10
        name_height: int
        if len(speaker_name_text) > 0 { name_height = 40 } else { name_height = 0 }
        portrait_x : f32
        if dialogue_data.show_on_right {
            portrait_x = dialogue_bounds.x + dialogue_bounds.width - f32(portrait_size) - f32(padding)
        } else {
            portrait_x = dialogue_bounds.x + f32(padding)
        }
        portrait_y := dialogue_bounds.y + f32(padding)
        
        // Draw dialogue box background
        rl.DrawRectangleRec(dialogue_bounds, dialogue_data.dialogue_box_color)
        rl.DrawRectangleLinesEx(dialogue_bounds, 2, rl.DARKGRAY)
        
        // Draw portrait (color only for simplicity here)
        portrait_rect := rl.Rectangle{portrait_x, portrait_y, f32(portrait_size), f32(portrait_size)}
        if dialogue_data.use_texture {
            // Added texture support back
            src_rect := rl.Rectangle{0, 0, f32(dialogue_data.portrait_texture.width), f32(dialogue_data.portrait_texture.height)}
            rl.DrawTexturePro(dialogue_data.portrait_texture, src_rect, portrait_rect, {0, 0}, 0, rl.WHITE)
        } else {
            rl.DrawRectangleRec(portrait_rect, dialogue_data.portrait_color)
            rl.DrawRectangleLinesEx(portrait_rect, 2, rl.DARKGRAY)
        }
        
        // Draw name tag
        if len(speaker_name_text) > 0 {
            name_tag_rect: rl.Rectangle
            if dialogue_data.show_on_right {
                name_tag_rect = {portrait_x - 120, portrait_y, 120, f32(name_height)}
            } else {
                name_tag_rect = {portrait_x + f32(portrait_size), portrait_y, 120, f32(name_height)}
            }
            rl.DrawRectangleRec(name_tag_rect, dialogue_data.name_tag_color)
            rl.DrawRectangleLinesEx(name_tag_rect, 2, rl.DARKGRAY)
            speaker_name_cstr := strings.clone_to_cstring(speaker_name_text, context.temp_allocator)
            name_size := rl.MeasureTextEx(current_font, speaker_name_cstr, f32(dialogue_data.name_font_size), 1)
            name_x := name_tag_rect.x + (name_tag_rect.width - name_size.x) / 2
            name_y := name_tag_rect.y + (name_tag_rect.height - f32(dialogue_data.name_font_size)) / 2
            rl.DrawTextEx(current_font, speaker_name_cstr, {name_x, name_y}, f32(dialogue_data.name_font_size), 1, dialogue_data.name_color)
        }
        
        // Draw dialogue text (handling styled vs plain)
        text_area_x : f32
        if dialogue_data.show_on_right { text_area_x = dialogue_bounds.x + f32(padding) } else { text_area_x = portrait_x + f32(portrait_size) + f32(padding) }
        text_area_width :f32
        if dialogue_data.show_on_right {
            text_area_width = portrait_x - dialogue_bounds.x - f32(padding * 2)
        } else {
            text_area_width = dialogue_bounds.x + dialogue_bounds.width - text_area_x - f32(padding)
        }
        text_area_y := portrait_y + f32(name_height) + f32(padding)
        text_area_height := dialogue_bounds.height - f32(name_height) - f32(padding * 3)
        text_area := rl.Rectangle{text_area_x, text_area_y, text_area_width, text_area_height}
        
        rl.BeginScissorMode(i32(text_area.x), i32(text_area.y), i32(text_area.width), i32(text_area.height))
        if dialogue_data.use_styled_text && dialogue_data.styled_text != nil {
            // Draw Styled Text Segments 
            current_x: f32 = text_area.x
            current_y: f32 = text_area.y
            base_font_size := f32(dialogue_data.font_size) // Use dialogue's base font size
            line_height := base_font_size * 1.5 // Base line height
            
            for segment := dialogue_data.styled_text; segment != nil; segment = segment.next {
                // Determine style for this segment
                seg_color := dialogue_data.text_color // Default
                seg_font_size := base_font_size        // Default
                // TODO: Add bold/italic handling if needed (requires font variants)
                
                for style := cast(^raydial.Text_Style)segment.styles; style != nil; style = style.next {
                    #partial switch style.type {
                    case .Colored:
                        seg_color = style.value.color
                    case .Sized:
                        seg_font_size = style.value.font_size
                    }
                    // TODO: Add cases for bold/italic
                }
                
                // Basic Word Wrapping for Segment 
                i := 0
                for i < len(segment.text) {
                    start := i
                    for i < len(segment.text) && segment.text[i] != ' ' && segment.text[i] != '\n' {
                        i += 1
                    }
                    word := segment.text[start:i]
                    include_space := i < len(segment.text) && segment.text[i] == ' '
                    if include_space {
                        i += 1
                    }
                    full_word : string
                    if include_space { full_word = strings.concatenate({word, " "})} else { full_word = word }
                    full_word_cstr := strings.clone_to_cstring(full_word, context.temp_allocator)
                    
                    // Measure the word with its style
                    word_size := rl.MeasureTextEx(current_font, full_word_cstr, seg_font_size, 1)
                    
                    // Check if word fits on the current line
                    if current_x > text_area.x && current_x + word_size.x > text_area.x + text_area.width {
                        // Doesn't fit, move to the next line
                        current_x = text_area.x
                        current_y += line_height // Advance line
                        // Check if we've gone past the vertical bounds
                        if current_y >= text_area.y + text_area.height {
                            break // Stop drawing text
                        }
                    }
                    
                    // Draw the word if within vertical bounds
                    if current_y < text_area.y + text_area.height {
                        // Draw word from buffer
                        rl.DrawTextEx(current_font, full_word_cstr, {current_x, current_y}, seg_font_size, 1, seg_color)
                    }
                    
                    current_x += word_size.x // Advance position
                }
                if current_y >= text_area.y + text_area.height {
                    break // Stop drawing segments
                }
            }
        } else {
            dialogue_text_plain := i18n.get_localized_text(state.i18n, "dialogueText")
            dialogue_text_cstr := strings.clone_to_cstring(dialogue_text_plain, context.temp_allocator)
            rl.DrawTextEx(current_font, dialogue_text_cstr, {text_area.x, text_area.y}, f32(dialogue_data.font_size), 1, dialogue_data.text_color)
        }
        rl.EndScissorMode()
        
        // 6. Draw Button
        button_data := cast(^raydial.Button_Data)state.switch_button.data
        mouse_pos := rl.GetMousePosition()
        is_hovered := rl.CheckCollisionPointRec(mouse_pos, state.switch_button.bounds)
        button_text_cstr := strings.clone_to_cstring(button_text, context.temp_allocator)
        hover_color: rl.Color
        if is_hovered { hover_color = button_data.hover_color } else { hover_color = button_data.background_color }
        rl.DrawRectangleRec(state.switch_button.bounds, hover_color)
        button_text_size := rl.MeasureTextEx(current_font, button_text_cstr, f32(button_data.font_size), 1)
        button_text_x := state.switch_button.bounds.x + (state.switch_button.bounds.width - button_text_size.x) / 2
        button_text_y := state.switch_button.bounds.y + (state.switch_button.bounds.height - f32(button_data.font_size)) / 2
        rl.DrawTextEx(current_font, button_text_cstr, {button_text_x, button_text_y}, f32(button_data.font_size), 1, button_data.text_color)
        
        // End Manual Drawing 
        
        // Display current language in the status bar (using currentFont)
        if state.current_language_index == 2 { // Greek selected
            rl.DrawRectangle(50, 10, 700, 30, rl.DARKGRAY)
            status_text := "Currently using Greek (Ελληνικά)"
            status_cstr := strings.clone_to_cstring(status_text, context.temp_allocator)
            rl.DrawTextEx(current_font, status_cstr, {60, 15}, 20, 1, rl.WHITE) // <-- Use currentFont
        } else {
            // Optionally display for other languages if needed
            // rl.DrawRectangle(50, 10, 700, 30, rl.DARKGRAY)
            // DrawText(TextFormat("Currently using %s", GetCurrentLanguageName(state.i18n)), 60, 15, 20, WHITE)
        }
        
        rl.EndDrawing()
    }
    
    // Cleanup
    if state.greek_font_loaded && state.greek_font.texture.id != state.original_default_font.texture.id {
        rl.UnloadFont(state.greek_font) // Unload only if it's different from original
        fmt.printf("Unloaded Greek font.\n")
    }
    
    raydial.free_dialogue_manager(manager)
    i18n.free_i18n_manager(i18n_mgr)
    
    rl.CloseWindow()
}

// Callback function for language switching
OnSwitchLanguage :: proc "c" (user_data: rawptr) {
    context = runtime.default_context()
    state := cast(^AppState)user_data
    
    // Cycle to the next language
    state.current_language_index = (state.current_language_index + 1) % 3
    new_language := state.available_languages[state.current_language_index]
    
    // Apply the new language to the I18N manager
    if i18n.set_current_language(state.i18n, new_language) {
        fmt.printf("Switched to language: %s\n", i18n.get_current_language_name(state.i18n))
        
        // Update component text keys - the drawing loop now handles font selection
        raydial.set_localized_label_text(state.title, "title", state.i18n)
        raydial.set_localized_label_text(state.greeting_label, "greetingLabel", state.i18n)
        raydial.set_localized_label_text(state.language_label, "currentLanguage", state.i18n)
        raydial.set_localized_button_text(state.switch_button, "switchLanguage", state.i18n)
        
        // Update the dialogue component's keys - IMPORTANT for styled text
        raydial.set_localized_portrait_dialogue_speaker(state.dialogue_component, "speakerName", state.i18n)
        // Re-parse styled text when language changes to ensure correct segments are generated
        raydial.set_localized_portrait_dialogue_styled_text(state.dialogue_component, "dialogueText", state.i18n)
        
        // No need to change default font anymore
    }
}