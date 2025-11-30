package nerd

import "core:fmt"
import "core:log"
import "core:strings"
import "core:strconv"

import rl "vendor:raylib"

UI_Context :: struct {
    font: rl.Font,
    font_size: i32,
    loaded: bool,
    has_nerd_font: bool,
}

Icon_Info :: struct {
    icon: string,         // Unicode character from CSV
    fallback: string,     // Fallback text when nerd font isn't available
    name: string,         // Icon name from CSV
    description: string,  // Generated description
}

Font_Symbol :: struct {
    name:    string `csv:"name"`,    // Nerd Font icon name
    unicode: string `csv:"unicode"`, // Unicode representation of the icon
}

// Convert hex unicode string to actual character
unicode_to_char :: proc(unicode_str: string) -> string {
    // Remove "U+" prefix if present
    hex_str := unicode_str
    if strings.has_prefix(hex_str, "U+") {
        hex_str = hex_str[2:]
    } else if strings.has_prefix(hex_str, "u+") {
        hex_str = hex_str[2:]
    }
    // Parse hex string to integer
    code_point, ok := strconv.parse_int(hex_str, 16)
    if !ok {
        log.warnf("Failed to parse unicode: %s", unicode_str)
        return "?"
    }
    // Convert to UTF-8 string
    rune_val := rune(code_point)
    return fmt.aprintf("%c", rune_val)
}

// Generate fallback text from icon name
generate_fallback :: proc(name: string) -> string {
    // Convert name to a short fallback representation
    cleaned := strings.to_upper(name)
    cleaned, _ = strings.replace_all(cleaned, "NF-", "")
    cleaned, _ = strings.replace_all(cleaned, "-", "")
    
    // Take first 3 characters or use specific mappings
    if len(cleaned) >= 3 {
        return cleaned[:3]
    }
    return cleaned
}

// Generate description from icon name
generate_description :: proc(name: string) -> string {
    // Simple description generation based on name patterns
    lower_name := strings.to_lower(name)
    
    if strings.contains(lower_name, "file") {
        return "File operations"
    } else if strings.contains(lower_name, "folder") || strings.contains(lower_name, "dir") {
        return "Directory operations"
    } else if strings.contains(lower_name, "git") {
        return "Git version control"
    } else if strings.contains(lower_name, "code") || strings.contains(lower_name, "dev") {
        return "Development tool"
    } else if strings.contains(lower_name, "media") || strings.contains(lower_name, "play") {
        return "Media control"
    } else if strings.contains(lower_name, "network") || strings.contains(lower_name, "wifi") {
        return "Network connectivity"
    } else if strings.contains(lower_name, "setting") || strings.contains(lower_name, "config") {
        return "Configuration"
    } else {
        return fmt.aprintf("Icon: %s", name)
    }
}

// Load icons from CSV data
load_icons_from_csv :: proc(symbols: []Font_Symbol) -> (icons: [dynamic]Icon_Info) {
    // Limit to first 50 icons for demo purposes (to avoid overwhelming the UI)
    max_icons := min(len(symbols), 50)
    
    for i in 0..<max_icons {
        symbol := symbols[i]
        
        icon_char := unicode_to_char(symbol.unicode)
        fallback := generate_fallback(symbol.name)
        description := generate_description(symbol.name)
        
        icon_info := Icon_Info{
            icon = strings.clone(icon_char),
            fallback = strings.clone(fallback),
            name = strings.clone(symbol.name),
            description = strings.clone(description),
        }
        append(&icons, icon_info)
    }
    
    log.infof("Loaded %d icons from CSV", len(icons))
    return icons
}

// Build character set for font loadings
build_charset :: proc(symbols: []Font_Symbol) -> string {
    BASIC_CHARS :: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789… ~!@#$%^&*()-|\"':;_+={}[]\\/`,.<>?★✓👁🚫↕•"
    
    builder := strings.builder_make()
    defer strings.builder_destroy(&builder)
    
    strings.write_string(&builder, BASIC_CHARS)
    
    // Add all unicode characters from CSV
    for i in 0..<len(symbols) {
        icon_char := unicode_to_char(symbols[i].unicode)
        strings.write_string(&builder, icon_char)
    }
    return strings.clone(strings.to_string(builder))
}

ui_load_font :: proc(ui_ctx: ^UI_Context, path: cstring, size: i32, symbols: []Font_Symbol) {
    charset := build_charset(symbols)
    defer delete(charset)
    
    code_point_count: i32
    code_points := rl.LoadCodepoints(fmt.caprintf("%s", charset), &code_point_count)
    defer rl.UnloadCodepoints(code_points)

    ui_ctx.has_nerd_font = false
    if rl.FileExists(path) {
        ui_ctx.font = rl.LoadFontEx(path, size, code_points, code_point_count)
        ui_ctx.has_nerd_font = true
        fmt.printf("Loaded nerd font: %s\n", path)
    }
    if !ui_ctx.has_nerd_font {
        fmt.println("Warning: No nerd font found. Using fallback text representations.")
        ui_ctx.font = rl.LoadFontEx("", size, code_points, code_point_count) // Load default with extended chars
        if ui_ctx.font.texture.id == 0 {
            ui_ctx.font = rl.GetFontDefault()
        }
    }
    ui_ctx.font_size = size
    ui_ctx.loaded = true
    rl.SetTextureFilter(ui_ctx.font.texture, .BILINEAR)
}

ui_unload_font :: proc(ui_ctx: ^UI_Context, ) {
    if ui_ctx.loaded && ui_ctx.font.texture.id != rl.GetFontDefault().texture.id {
        rl.UnloadFont(ui_ctx.font)
    }
    ui_ctx.loaded = false
}