package css

import rl "vendor:raylib"
import "core:math/rand"
import "core:strings"
import "core:strconv"

COLOR :: enum {
    // CSS1 Colors
    WHITE, SILVER, GRAY, BLACK, RED, MAROON, LIME, GREEN, BLUE, NAVY, 
    YELLOW, ORANGE, OLIVE, PURPLE, FUCHSIA, TEAL, AQUA,
    // Reds
    INDIAN_RED, LIGHT_CORAL, SALMON, DARK_SALMON, LIGHT_SALMON, 
    CRIMSON, FIRE_BRICK, DARK_RED,
    // Pinks
    PINK, LIGHT_PINK, HOT_PINK, DEEP_PINK, MEDIUM_VIOLET_RED, PALE_VIOLET_RED,
    // Oranges
    CORAL, TOMATO, ORANGE_RED, DARK_ORANGE,
    // Yellows
    GOLD, LIGHT_YELLOW, LEMON_CHIFFON, LIGHT_GOLDENROD_YELLOW, PAPAYA_WHIP,
    MOCCASIN, PEACH_PUFF, PALE_GOLDENROD, KHAKI, DARK_KHAKI,
    // Purples
    LAVENDER, THISTLE, PLUM, VIOLET, ORCHID, MAGENTA, MEDIUM_ORCHID,
    MEDIUM_PURPLE, BLUE_VIOLET, DARK_VIOLET, DARK_ORCHID, DARK_MAGENTA,
    REBECCA_PURPLE, INDIGO, MEDIUM_SLATE_BLUE, SLATE_BLUE, DARK_SLATE_BLUE,
    // Greens
    GREEN_YELLOW, CHARTREUSE, LAWN_GREEN, LIME_GREEN, PALE_GREEN, LIGHT_GREEN,
    MEDIUM_SPRING_GREEN, SPRING_GREEN, MEDIUM_SEA_GREEN, SEA_GREEN, FOREST_GREEN,
    DARK_GREEN, YELLOW_GREEN, OLIVE_DRAB, DARK_OLIVE_GREEN, MEDIUM_AQUAMARINE,
    DARK_SEA_GREEN, LIGHT_SEA_GREEN, DARK_CYAN,
    // Blues
    CYAN, LIGHT_CYAN, PALE_TURQUOISE, AQUAMARINE, TURQUOISE, MEDIUM_TURQUOISE,
    DARK_TURQUOISE, CADET_BLUE, STEEL_BLUE, LIGHT_STEEL_BLUE, POWDER_BLUE,
    LIGHT_BLUE, SKY_BLUE, LIGHT_SKY_BLUE, DEEP_SKY_BLUE, DODGER_BLUE,
    CORNFLOWER_BLUE, ROYAL_BLUE, MEDIUM_BLUE, DARK_BLUE, MIDNIGHT_BLUE,
    // Browns
    CORNSILK, BLANCHED_ALMOND, BISQUE, NAVAJO_WHITE, WHEAT, BURLY_WOOD,
    TAN, ROSY_BROWN, SANDY_BROWN, GOLDENROD, DARK_GOLDENROD, PERU,
    CHOCOLATE, SADDLE_BROWN, SIENNA, BROWN,
    // Whites
    SNOW, HONEYDEW, MINT_CREAM, AZURE, ALICE_BLUE, GHOST_WHITE, WHITE_SMOKE,
    SEASHELL, BEIGE, OLD_LACE, FLORAL_WHITE, IVORY, ANTIQUE_WHITE, LINEN,
    LAVENDER_BLUSH, MISTY_ROSE,
    // Grays
    GAINSBORO, LIGHT_GRAY, LIGHT_GREY, DARK_GRAY, GREY, DIM_GRAY,
    LIGHT_SLATE_GRAY, SLATE_GRAY, DARK_SLATE_GRAY,
}

// Convert enum to string using the enum's name
enum_string :: proc(color: COLOR) -> string {
    return strings.to_lower(enum_name(color))
}

// Get the enum name as a string
enum_name :: proc(color: COLOR) -> string {
    return strings.to_string(color)
}

to_rgba :: proc(color_code: COLOR) -> rl.Color {
    return COLORS[color_code]
}

// Gets the base name of a color group, e.g., RED from DARK_RED
color_base_name :: proc(color: COLOR) -> string {
    name := enum_string(color)
    
    // Handle compound color names by finding the last part
    if strings.contains(name, "_") {
        parts := strings.split(name, "_")
        defer delete(parts)
        return parts[len(parts)-1]
    }
    return name
}

// Gets the color family/category based on the enum position and name
color_family :: proc(color: COLOR) -> string {
    name := enum_string(color)
    
    // CSS1 basic colors
    if int(color) <= int(COLOR.AQUA) {
        return "BASIC"
    }
    // Check by name patterns
    if strings.contains(name, "RED") || name == "CRIMSON" || name == "FIRE_BRICK" ||
       name == "SALMON" || name == "CORAL" || name == "INDIAN_RED" {
        return "RED"
    }
    if strings.contains(name, "PINK") {
        return "PINK"
    }
    if strings.contains(name, "ORANGE") || name == "CORAL" || name == "TOMATO" {
        return "ORANGE"
    }
    if strings.contains(name, "YELLOW") || strings.contains(name, "GOLD") ||
       name == "KHAKI" || name == "MOCCASIN" || name == "PEACH_PUFF" {
        return "YELLOW"
    }
    if strings.contains(name, "PURPLE") || strings.contains(name, "VIOLET") ||
       strings.contains(name, "MAGENTA") || name == "ORCHID" || name == "PLUM" ||
       name == "THISTLE" || name == "LAVENDER" || name == "INDIGO" ||
       strings.contains(name, "SLATE_BLUE") {
        return "PURPLE"
    }
    if strings.contains(name, "GREEN") || name == "CHARTREUSE" || name == "OLIVE_DRAB" ||
       name == "SEA_GREEN" || name == "FOREST_GREEN" || name == "AQUAMARINE" {
        return "GREEN"
    }
    if strings.contains(name, "BLUE") || strings.contains(name, "CYAN") ||
       strings.contains(name, "TURQUOISE") || name == "STEEL_BLUE" ||
       name == "SKY_BLUE" || name == "CADET_BLUE" || name == "AQUA" {
        return "BLUE"
    }
    if strings.contains(name, "BROWN") || name == "TAN" || name == "WHEAT" ||
       name == "CHOCOLATE" || name == "PERU" || name == "SIENNA" ||
       name == "SANDY_BROWN" || name == "BURLY_WOOD" {
        return "BROWN"
    }
    if strings.contains(name, "WHITE") || name == "SNOW" || name == "IVORY" ||
       name == "BEIGE" || name == "LINEN" || strings.contains(name, "CREAM") {
        return "WHITE"
    }
    if strings.contains(name, "GRAY") || strings.contains(name, "GREY") ||
       name == "GAINSBORO" || name == "DIM_GRAY" || strings.contains(name, "SLATE_GRAY") {
        return "GRAY"
    }
    return "OTHER"
}

// Picks a random color from a specific family (e.g., only reds)
random_family :: proc(family: string) -> rl.Color {
    matching_colors := [dynamic]COLOR{}
    defer delete(matching_colors)
    
    for color in COLOR {
        if color_family(color) == family {
            append(&matching_colors, color)
        }
    }
    if len(matching_colors) == 0 {
        return COLORS[COLOR.GRAY] // fallback color
    }
    random_index := rand.int_max(len(matching_colors))
    return COLORS[matching_colors[random_index]]
}

// Picks a random color across all COLORS
random_color :: proc() -> rl.Color {
    random_color_enum := COLOR(rand.int_max(len(COLOR)))
    return COLORS[random_color_enum]
}

// Convert a hex string to a color
from_hex :: proc(hex: string) -> (color: rl.Color, ok: bool) {
    if len(hex) != 7 && len(hex) != 9 {
        return rl.Color{}, false
    }
    r_val, r_ok := strconv.parse_int(hex[1:3], 16)
    g_val, g_ok := strconv.parse_int(hex[3:5], 16)
    b_val, b_ok := strconv.parse_int(hex[5:7], 16)
    if !r_ok || !g_ok || !b_ok {
        return rl.Color{}, false
    }
    a: u8
    if len(hex) == 9 {
        a_val, a_ok := strconv.parse_int(hex[7:9], 16)
        if !a_ok {
            return rl.Color{}, false
        }
        a = u8(a_val)
    } else {
        a = 255
    }
    return rl.Color{u8(r_val), u8(g_val), u8(b_val), a}, true
}

must_from_hex :: proc(hex: string) -> rl.Color {
    color, ok := from_hex(hex)
    if !ok {
        panic("must_from_hex: Invalid hex color format")
    }
    return color
}

COLORS : [COLOR]rl.Color = {
    // CSS1 Colors
    .WHITE   = must_from_hex("#FFFFFF"),
    .SILVER  = must_from_hex("#C0C0C0"),
    .GRAY    = must_from_hex("#808080"),
    .BLACK   = must_from_hex("#000000"),
    .RED     = must_from_hex("#FF0000"),
    .MAROON  = must_from_hex("#800000"),
    .LIME    = must_from_hex("#00FF00"),
    .GREEN   = must_from_hex("#008000"),
    .BLUE    = must_from_hex("#0000FF"),
    .NAVY    = must_from_hex("#000080"),
    .YELLOW  = must_from_hex("#FFFF00"),
    .ORANGE  = must_from_hex("#FFA500"),
    .OLIVE   = must_from_hex("#808000"),
    .PURPLE  = must_from_hex("#800080"),
    .FUCHSIA = must_from_hex("#FF00FF"),
    .TEAL    = must_from_hex("#008080"),
    .AQUA    = must_from_hex("#00FFFF"),
    // Reds
    .INDIAN_RED    = must_from_hex("#CD5C5C"),
    .LIGHT_CORAL   = must_from_hex("#F08080"),
    .SALMON        = must_from_hex("#FA8072"),
    .DARK_SALMON   = must_from_hex("#E9967A"),
    .LIGHT_SALMON  = must_from_hex("#FFA07A"),
    .CRIMSON       = must_from_hex("#DC143C"),
    .FIRE_BRICK    = must_from_hex("#B22222"),
    .DARK_RED      = must_from_hex("#8B0000"),
    // Pinks
    .PINK               = must_from_hex("#FFC0CB"),
    .LIGHT_PINK         = must_from_hex("#FFB6C1"),
    .HOT_PINK           = must_from_hex("#FF69B4"),
    .DEEP_PINK          = must_from_hex("#FF1493"),
    .MEDIUM_VIOLET_RED  = must_from_hex("#C71585"),
    .PALE_VIOLET_RED    = must_from_hex("#DB7093"),
    // Oranges
    .CORAL       = must_from_hex("#FF7F50"),
    .TOMATO      = must_from_hex("#FF6347"),
    .ORANGE_RED  = must_from_hex("#FF4500"),
    .DARK_ORANGE = must_from_hex("#FF8C00"),
    // Yellows
    .GOLD                     = must_from_hex("#FFD700"),
    .LIGHT_YELLOW             = must_from_hex("#FFFFE0"),
    .LEMON_CHIFFON            = must_from_hex("#FFFACD"),
    .LIGHT_GOLDENROD_YELLOW   = must_from_hex("#FAFAD2"),
    .PAPAYA_WHIP              = must_from_hex("#FFEFD5"),
    .MOCCASIN                 = must_from_hex("#FFE4B5"),
    .PEACH_PUFF               = must_from_hex("#FFDAB9"),
    .PALE_GOLDENROD           = must_from_hex("#EEE8AA"),
    .KHAKI                    = must_from_hex("#F0E68C"),
    .DARK_KHAKI               = must_from_hex("#BDB76B"),
    // Purples
    .LAVENDER           = must_from_hex("#E6E6FA"),
    .THISTLE            = must_from_hex("#D8BFD8"),
    .PLUM               = must_from_hex("#DDA0DD"),
    .VIOLET             = must_from_hex("#EE82EE"),
    .ORCHID             = must_from_hex("#DA70D6"),
    .MAGENTA            = must_from_hex("#FF00FF"),
    .MEDIUM_ORCHID      = must_from_hex("#BA55D3"),
    .MEDIUM_PURPLE      = must_from_hex("#9370DB"),
    .BLUE_VIOLET        = must_from_hex("#8A2BE2"),
    .DARK_VIOLET        = must_from_hex("#9400D3"),
    .DARK_ORCHID        = must_from_hex("#9932CC"),
    .DARK_MAGENTA       = must_from_hex("#8B008B"),
    .REBECCA_PURPLE     = must_from_hex("#663399"),
    .INDIGO             = must_from_hex("#4B0082"),
    .MEDIUM_SLATE_BLUE  = must_from_hex("#7B68EE"),
    .SLATE_BLUE         = must_from_hex("#6A5ACD"),
    .DARK_SLATE_BLUE    = must_from_hex("#483D8B"),
    // Greens
    .GREEN_YELLOW         = must_from_hex("#ADFF2F"),
    .CHARTREUSE           = must_from_hex("#7FFF00"),
    .LAWN_GREEN           = must_from_hex("#7CFC00"),
    .LIME_GREEN           = must_from_hex("#32CD32"),
    .PALE_GREEN           = must_from_hex("#98FB98"),
    .LIGHT_GREEN          = must_from_hex("#90EE90"),
    .MEDIUM_SPRING_GREEN  = must_from_hex("#00FA9A"),
    .SPRING_GREEN         = must_from_hex("#00FF7F"),
    .MEDIUM_SEA_GREEN     = must_from_hex("#3CB371"),
    .SEA_GREEN            = must_from_hex("#2E8B57"),
    .FOREST_GREEN         = must_from_hex("#228B22"),
    .DARK_GREEN           = must_from_hex("#006400"),
    .YELLOW_GREEN         = must_from_hex("#9ACD32"),
    .OLIVE_DRAB           = must_from_hex("#6B8E23"),
    .DARK_OLIVE_GREEN     = must_from_hex("#556B2F"),
    .MEDIUM_AQUAMARINE    = must_from_hex("#66CDAA"),
    .DARK_SEA_GREEN       = must_from_hex("#8FBC8F"),
    .LIGHT_SEA_GREEN      = must_from_hex("#20B2AA"),
    .DARK_CYAN            = must_from_hex("#008B8B"),
    // Blues
    .CYAN               = must_from_hex("#00FFFF"),
    .LIGHT_CYAN         = must_from_hex("#E0FFFF"),
    .PALE_TURQUOISE     = must_from_hex("#AFEEEE"),
    .AQUAMARINE         = must_from_hex("#7FFFD4"),
    .TURQUOISE          = must_from_hex("#40E0D0"),
    .MEDIUM_TURQUOISE   = must_from_hex("#48D1CC"),
    .DARK_TURQUOISE     = must_from_hex("#00CED1"),
    .CADET_BLUE         = must_from_hex("#5F9EA0"),
    .STEEL_BLUE         = must_from_hex("#4682B4"),
    .LIGHT_STEEL_BLUE   = must_from_hex("#B0C4DE"),
    .POWDER_BLUE        = must_from_hex("#B0E0E6"),
    .LIGHT_BLUE         = must_from_hex("#ADD8E6"),
    .SKY_BLUE           = must_from_hex("#87CEEB"),
    .LIGHT_SKY_BLUE     = must_from_hex("#87CEFA"),
    .DEEP_SKY_BLUE      = must_from_hex("#00BFFF"),
    .DODGER_BLUE        = must_from_hex("#1E90FF"),
    .CORNFLOWER_BLUE    = must_from_hex("#6495ED"),
    .ROYAL_BLUE         = must_from_hex("#4169E1"),
    .MEDIUM_BLUE        = must_from_hex("#0000CD"),
    .DARK_BLUE          = must_from_hex("#00008B"),
    .MIDNIGHT_BLUE      = must_from_hex("#191970"),
    // Browns
    .CORNSILK         = must_from_hex("#FFF8DC"),
    .BLANCHED_ALMOND  = must_from_hex("#FFEBCD"),
    .BISQUE           = must_from_hex("#FFE4C4"),
    .NAVAJO_WHITE     = must_from_hex("#FFDEAD"),
    .WHEAT            = must_from_hex("#F5DEB3"),
    .BURLY_WOOD       = must_from_hex("#DEB887"),
    .TAN              = must_from_hex("#D2B48C"),
    .ROSY_BROWN       = must_from_hex("#BC8F8F"),
    .SANDY_BROWN      = must_from_hex("#F4A460"),
    .GOLDENROD        = must_from_hex("#DAA520"),
    .DARK_GOLDENROD   = must_from_hex("#B8860B"),
    .PERU             = must_from_hex("#CD853F"),
    .CHOCOLATE        = must_from_hex("#D2691E"),
    .SADDLE_BROWN     = must_from_hex("#8B4513"),
    .SIENNA           = must_from_hex("#A0522D"),
    .BROWN            = must_from_hex("#A52A2A"),
    // Whites
    .SNOW           = must_from_hex("#FFFAFA"),
    .HONEYDEW       = must_from_hex("#F0FFF0"),
    .MINT_CREAM     = must_from_hex("#F5FFFA"),
    .AZURE          = must_from_hex("#F0FFFF"),
    .ALICE_BLUE     = must_from_hex("#F0F8FF"),
    .GHOST_WHITE    = must_from_hex("#F8F8FF"),
    .WHITE_SMOKE    = must_from_hex("#F5F5F5"),
    .SEASHELL       = must_from_hex("#FFF5EE"),
    .BEIGE          = must_from_hex("#F5F5DC"),
    .OLD_LACE       = must_from_hex("#FDF5E6"),
    .FLORAL_WHITE   = must_from_hex("#FFFAF0"),
    .IVORY          = must_from_hex("#FFFFF0"),
    .ANTIQUE_WHITE  = must_from_hex("#FAEBD7"),
    .LINEN          = must_from_hex("#FAF0E6"),
    .LAVENDER_BLUSH = must_from_hex("#FFF0F5"),
    .MISTY_ROSE     = must_from_hex("#FFE4E1"),
    // Grays
    .GAINSBORO        = must_from_hex("#DCDCDC"),
    .LIGHT_GRAY       = must_from_hex("#D3D3D3"),
    .LIGHT_GREY       = must_from_hex("#D3D3D3"),
    .DARK_GRAY        = must_from_hex("#A9A9A9"),
    .GREY             = must_from_hex("#808080"),
    .DIM_GRAY         = must_from_hex("#696969"),
    .LIGHT_SLATE_GRAY = must_from_hex("#778899"),
    .SLATE_GRAY       = must_from_hex("#708090"),
    .DARK_SLATE_GRAY  = must_from_hex("#2F4F4F"),
}