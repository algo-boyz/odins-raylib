package raydial

import "base:runtime"
import "core:os"
import "core:strings"
import rl "vendor:raylib"

// Main localization manager struct
I18N :: struct {
    languages: ^Language,
    current_language: ^Language,
    use_styled_text_parsing: bool,
}

// Language struct
Language :: struct {
    language_code: string,
    language_name: string,
    translations: ^Translation_Entry,
    next: ^Language,
}

// Translation entry struct
Translation_Entry :: struct {
    key: string,
    value: string,
    next: ^Translation_Entry,
}

// Create a new localization manager
create_i18n_manager :: proc() -> ^I18N {
    manager := new(I18N)
    if manager == nil {
        return nil
    }
    manager.languages = nil
    manager.current_language = nil
    manager.use_styled_text_parsing = true
    return manager
}

// Free all resources associated with the localization manager
free_i18n_manager :: proc(manager: ^I18N) {
    if manager == nil {
        return
    }

    // Temporarily set context to default for safe deallocation
    old_ctx := context
    context = runtime.default_context()
    defer context = old_ctx

    // Free all languages and their translation entries
    for lang := manager.languages; lang != nil; {
        next_lang := lang.next

        // Free all translations in this language
        for entry := lang.translations; entry != nil; {
            next_entry := entry.next
            delete(entry.key, context.allocator)
            delete(entry.value, context.allocator)
            free(entry, context.allocator)
            entry = next_entry
        }

        // Free the language itself
        delete(lang.language_code, context.allocator)
        delete(lang.language_name, context.allocator)
        free(lang, context.allocator)

        lang = next_lang
    }

    // Free the manager itself
    free(manager, context.allocator)
}

// Add a new language to the manager
add_language :: proc(manager: ^I18N, language_code: string, language_name: string) -> bool {
    if manager == nil || len(language_code) == 0 || len(language_name) == 0 {
        return false
    }

    // Check if the language already exists
    for lang := manager.languages; lang != nil; lang = lang.next {
        if lang.language_code == language_code {
            return false // Language already exists
        }
    }

    // Create a new language
    new_lang := new(Language, context.allocator)
    if new_lang == nil {
        return false
    }

    new_lang.language_code = strings.clone(language_code, context.allocator)
    new_lang.language_name = strings.clone(language_name, context.allocator)
    new_lang.translations = nil
    new_lang.next = nil

    // Add the language to the list
    if manager.languages == nil {
        manager.languages = new_lang
    } else {
        lang := manager.languages
        for ; lang.next != nil; lang = lang.next {}
        lang.next = new_lang
    }

    // If this is the first language, set it as the current language
    if manager.current_language == nil {
        manager.current_language = new_lang
    }

    return true
}

// Set the current language by language code
set_current_language :: proc(manager: ^I18N, language_code: string) -> bool {
    if manager == nil || len(language_code) == 0 {
        return false
    }

    for lang := manager.languages; lang != nil; lang = lang.next {
        if lang.language_code == language_code {
            manager.current_language = lang
            return true
        }
    }

    return false // Language not found
}

// Get the current language
get_current_language :: proc(manager: ^I18N) -> ^Language {
    if manager == nil {
        return nil
    }
    return manager.current_language
}

// Get the current language code
get_current_language_code :: proc(manager: ^I18N) -> string {
    if manager == nil || manager.current_language == nil {
        return ""
    }
    return manager.current_language.language_code
}

// Get the current language name
get_current_language_name :: proc(manager: ^I18N) -> string {
    if manager == nil || manager.current_language == nil {
        return ""
    }
    return manager.current_language.language_name
}

// Add a translation to a language
add_translation :: proc(manager: ^I18N, language_code: string, key: string, value: string) -> bool {
    if manager == nil || len(language_code) == 0 || len(key) == 0 || len(value) == 0 {
        return false
    }

    // Find the language
    lang: ^Language = nil
    for l := manager.languages; l != nil; l = l.next {
        if l.language_code == language_code {
            lang = l
            break
        }
    }

    if lang == nil {
        return false // Language not found
    }

    // Check if the key already exists
    for entry := lang.translations; entry != nil; entry = entry.next {
        if entry.key == key {
            // Update the value: delete old and clone new
            delete(entry.value, context.allocator)
            entry.value = strings.clone(value, context.allocator)
            return true
        }
    }

    // Create a new translation entry
    new_entry := new(Translation_Entry, context.allocator)
    if new_entry == nil {
        return false
    }

    new_entry.key = strings.clone(key, context.allocator)
    new_entry.value = strings.clone(value, context.allocator)
    new_entry.next = nil

    // Add the entry to the language
    if lang.translations == nil {
        lang.translations = new_entry
    } else {
        entry := lang.translations
        for ; entry.next != nil; entry = entry.next {}
        entry.next = new_entry
    }

    return true
}

// Load translations from a file (properties format: key=value)
load_translations_from_file :: proc(manager: ^I18N, language_code: string, filename: string) -> bool {
    if manager == nil || len(language_code) == 0 || len(filename) == 0 {
        return false
    }

    // Read entire file
    data, ok := os.read_entire_file(filename)
    if !ok {
        return false
    }
    defer delete(data)

    // Find the language
    lang: ^Language = nil
    for l := manager.languages; l != nil; l = l.next {
        if l.language_code == language_code {
            lang = l
            break
        }
    }

    if lang == nil {
        return false // Language not found
    }

    // Split into lines
    lines := strings.split_multi(string(data), []string{"\n", "\r"})
    defer delete(lines)

    // Process each line
    for raw_line in lines {
        line := strings.trim_space(raw_line)
        if len(line) == 0 {
            continue
        }

        // Skip comments and empty lines
        if line[0] == '#' {
            continue
        }

        // Parse key=value format
        sep_idx := strings.index_rune(line, '=')
        if sep_idx == -1 {
            continue
        }

        // Extract key
        key := strings.trim_space(line[:sep_idx])
        if len(key) == 0 {
            continue
        }

        // Extract value
        value_start := sep_idx + 1
        value := strings.trim_space(line[value_start:])
        if len(value) == 0 {
            continue
        }

        // Clone for persistence (since original data is temporary)
        key_copy := strings.clone(key, context.allocator)
        value_copy := strings.clone(value, context.allocator)

        // Add the translation (ownership transferred to entry)
        add_translation(manager, language_code, key_copy, value_copy)
    }

    return true
}

// Save translations to a file (properties format: key=value)
save_translations_to_file :: proc(manager: ^I18N, language_code: string, filename: string) -> bool {
    if manager == nil || len(language_code) == 0 || len(filename) == 0 {
        return false
    }

    // Find the language
    lang: ^Language = nil
    for l := manager.languages; l != nil; l = l.next {
        if l.language_code == language_code {
            lang = l
            break
        }
    }

    if lang == nil {
        return false // Language not found
    }

    return true
}

// Get localized text for a key
get_localized_text :: proc(manager: ^I18N, key: string) -> string {
    if manager == nil || len(key) == 0 || manager.current_language == nil {
        return key
    }

    // Search for the key in the current language
    for entry := manager.current_language.translations; entry != nil; entry = entry.next {
        if entry.key == key {
            return entry.value
        }
    }

    return key // Return the key if no translation is found
}

// Get localized styled text for a key
get_localized_styled_text :: proc(manager: ^I18N, key: string, default_color: rl.Color, default_font_size: f32) -> ^Text_Segment {
    if manager == nil || len(key) == 0 || manager.current_language == nil {
        return nil
    }

    // First get the localized text
    localized_text := get_localized_text(manager, key)

    // If we don't want to parse styled text or the text is the same as the key (not found),
    // return a simple segment with the text
    if !manager.use_styled_text_parsing || localized_text == key {
        segment := new(Text_Segment, context.allocator)
        if segment == nil {
            return nil
        }

        segment.text = strings.clone(localized_text, context.allocator) // Clone for ownership
        segment.styles = nil
        segment.next = nil

        return segment
    }

    // Parse the text for styles (external function)
    return parse_styled_text(localized_text, default_color, default_font_size) // Assumed defined in raydial.h equivalent
}

// Set whether to use styled text parsing
set_use_styled_text_parsing :: proc(manager: ^I18N, use_styled_text: bool) {
    if manager != nil {
        manager.use_styled_text_parsing = use_styled_text
    }
}