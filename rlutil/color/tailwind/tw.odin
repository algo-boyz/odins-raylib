package tailwind

import rl "vendor:raylib"
import "core:math/rand"
import "core:strings"
import "core:strconv"

COLOR :: enum {
    SLATE0, SLATE1, SLATE2, SLATE3, SLATE4, SLATE5, SLATE6, SLATE7, SLATE8, SLATE9,
    GRAY0, GRAY1, GRAY2, GRAY3, GRAY4, GRAY5, GRAY6, GRAY7, GRAY8, GRAY9,
    ZINC0, ZINC1, ZINC2, ZINC3, ZINC4, ZINC5, ZINC6, ZINC7, ZINC8, ZINC9,
    NEUTRAL0, NEUTRAL1, NEUTRAL2, NEUTRAL3, NEUTRAL4, NEUTRAL5, NEUTRAL6, NEUTRAL7, NEUTRAL8, NEUTRAL9,
    STONE0, STONE1, STONE2, STONE3, STONE4, STONE5, STONE6, STONE7, STONE8, STONE9,
    RED0, RED1, RED2, RED3, RED4, RED5, RED6, RED7, RED8, RED9,
    ORANGE0, ORANGE1, ORANGE2, ORANGE3, ORANGE4, ORANGE5, ORANGE6, ORANGE7, ORANGE8, ORANGE9,
    AMBER0, AMBER1, AMBER2, AMBER3, AMBER4, AMBER5, AMBER6, AMBER7, AMBER8, AMBER9,
    YELLOW0, YELLOW1, YELLOW2, YELLOW3, YELLOW4, YELLOW5, YELLOW6, YELLOW7, YELLOW8, YELLOW9,
    LIME0, LIME1, LIME2, LIME3, LIME4, LIME5, LIME6, LIME7, LIME8, LIME9,
    GREEN0, GREEN1, GREEN2, GREEN3, GREEN4, GREEN5, GREEN6, GREEN7, GREEN8, GREEN9,
    EMERALD0, EMERALD1, EMERALD2, EMERALD3, EMERALD4, EMERALD5, EMERALD6, EMERALD7, EMERALD8, EMERALD9,
    TEAL0, TEAL1, TEAL2, TEAL3, TEAL4, TEAL5, TEAL6, TEAL7, TEAL8, TEAL9,
    CYAN0, CYAN1, CYAN2, CYAN3, CYAN4, CYAN5, CYAN6, CYAN7, CYAN8, CYAN9,
    SKY0, SKY1, SKY2, SKY3, SKY4, SKY5, SKY6, SKY7, SKY8, SKY9,
    BLUE0, BLUE1, BLUE2, BLUE3, BLUE4, BLUE5, BLUE6, BLUE7, BLUE8, BLUE9,
    INDIGO0, INDIGO1, INDIGO2, INDIGO3, INDIGO4, INDIGO5, INDIGO6, INDIGO7, INDIGO8, INDIGO9,
    VIOLET0, VIOLET1, VIOLET2, VIOLET3, VIOLET4, VIOLET5, VIOLET6, VIOLET7, VIOLET8, VIOLET9,
    PURPLE0, PURPLE1, PURPLE2, PURPLE3, PURPLE4, PURPLE5, PURPLE6, PURPLE7, PURPLE8, PURPLE9,
    FUCHSIA0, FUCHSIA1, FUCHSIA2, FUCHSIA3, FUCHSIA4, FUCHSIA5, FUCHSIA6, FUCHSIA7, FUCHSIA8, FUCHSIA9,
    PINK0, PINK1, PINK2, PINK3, PINK4, PINK5, PINK6, PINK7, PINK8, PINK9,
    ROSE0, ROSE1, ROSE2, ROSE3, ROSE4, ROSE5, ROSE6, ROSE7, ROSE8, ROSE9,
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

// Gets the base name of a color group, e.g., SLATE from SLATE3
color_base_name :: proc(color: COLOR) -> string {
    name := enum_string(color)
    for i in 0..<len(name) {
        if name[i] >= '0' && name[i] <= '9' {
            return name[:i]
        }
    }
    return name // fallback to full name if no digit found
}

// Gets the numeric index of a color shade, e.g., 3 from SLATE3
color_shade_index :: proc(color: COLOR) -> int {
    name := enum_string(color)
    for i in 0..<len(name) {
        if name[i] >= '0' && name[i] <= '9' {
            if result, ok := strconv.parse_int(name[i:]); ok {
                return result
            }
            break
        }
    }
    return 0 // default to 0 if no digit found
}

// Picks a random color from a specific group (e.g., only BLUE*)
random_group_color :: proc(base: string) -> rl.Color {
    matching_colors := [dynamic]COLOR{}
    defer delete(matching_colors)
    
    for color in COLOR {
        if strings.has_prefix(enum_string(color), base) {
            append(&matching_colors, color)
        }
    }
    if len(matching_colors) == 0 {
        return COLORS[COLOR.GRAY5] // fallback color
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
	r_val, r_ok:= strconv.parse_int(hex[1:3], 16)
	g_val, g_ok:= strconv.parse_int(hex[3:5], 16)
	b_val, b_ok:= strconv.parse_int(hex[5:7], 16)
	if !r_ok|| !g_ok|| !b_ok{
		return rl.Color{}, false
	}
	a:u8
	if len(hex) == 9 {
		a_val, a_ok:= strconv.parse_int(hex[7:9], 16)
		if !a_ok{
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

COLORS : [COLOR]rl.Color : {
    .SLATE0   = must_from_hex("#F1F5F9"),
    .SLATE1   = must_from_hex("#E2E8F0"),
    .SLATE2   = must_from_hex("#CBD5E1"),
    .SLATE3   = must_from_hex("#94A3B8"),
    .SLATE4   = must_from_hex("#64748B"),
    .SLATE5   = must_from_hex("#475569"),
    .SLATE6   = must_from_hex("#334155"),
    .SLATE7   = must_from_hex("#1E293B"),
    .SLATE8   = must_from_hex("#0F172A"),
    .SLATE9   = must_from_hex("#020617"),

    .GRAY0    = must_from_hex("#F3F4F6"),
    .GRAY1    = must_from_hex("#E5E7EB"),
    .GRAY2    = must_from_hex("#D1D5DB"),
    .GRAY3    = must_from_hex("#9CA3AF"),
    .GRAY4    = must_from_hex("#6B7280"),
    .GRAY5    = must_from_hex("#4B5563"),
    .GRAY6    = must_from_hex("#374151"),
    .GRAY7    = must_from_hex("#1F2937"),
    .GRAY8    = must_from_hex("#111827"),
    .GRAY9    = must_from_hex("#030712"),

    .ZINC0    = must_from_hex("#F4F4F5"),
    .ZINC1    = must_from_hex("#E4E4E7"),
    .ZINC2    = must_from_hex("#D4D4D8"),
    .ZINC3    = must_from_hex("#A1A1AA"),
    .ZINC4    = must_from_hex("#71717A"),
    .ZINC5    = must_from_hex("#52525B"),
    .ZINC6    = must_from_hex("#3F3F46"),
    .ZINC7    = must_from_hex("#27272A"),
    .ZINC8    = must_from_hex("#18181B"),
    .ZINC9    = must_from_hex("#09090B"),

    .NEUTRAL0 = must_from_hex("#F5F5F5"),
    .NEUTRAL1 = must_from_hex("#E5E5E5"),
    .NEUTRAL2 = must_from_hex("#D4D4D4"),
    .NEUTRAL3 = must_from_hex("#A3A3A3"),
    .NEUTRAL4 = must_from_hex("#737373"),
    .NEUTRAL5 = must_from_hex("#525252"),
    .NEUTRAL6 = must_from_hex("#404040"),
    .NEUTRAL7 = must_from_hex("#262626"),
    .NEUTRAL8 = must_from_hex("#171717"),
    .NEUTRAL9 = must_from_hex("#0A0A0A"),

    .STONE0   = must_from_hex("#F5F5F4"),
    .STONE1   = must_from_hex("#E7E5E4"),
    .STONE2   = must_from_hex("#D6D3D1"),
    .STONE3   = must_from_hex("#A8A29E"),
    .STONE4   = must_from_hex("#78716C"),
    .STONE5   = must_from_hex("#57534E"),
    .STONE6   = must_from_hex("#44403C"),
    .STONE7   = must_from_hex("#292524"),
    .STONE8   = must_from_hex("#1C1917"),
    .STONE9   = must_from_hex("#0C0A09"),

    .RED0     = must_from_hex("#FEE2E2"),
    .RED1     = must_from_hex("#FECACA"),
    .RED2     = must_from_hex("#FCA5A5"),
    .RED3     = must_from_hex("#F87171"),
    .RED4     = must_from_hex("#EF4444"),
    .RED5     = must_from_hex("#DC2626"),
    .RED6     = must_from_hex("#B91C1C"),
    .RED7     = must_from_hex("#991B1B"),
    .RED8     = must_from_hex("#7F1D1D"),
    .RED9     = must_from_hex("#450A0A"),

    .ORANGE0  = must_from_hex("#FFEDD5"),
    .ORANGE1  = must_from_hex("#FED7AA"),
    .ORANGE2  = must_from_hex("#FDBA74"),
    .ORANGE3  = must_from_hex("#FB923C"),
    .ORANGE4  = must_from_hex("#F97316"),
    .ORANGE5  = must_from_hex("#EA580C"),
    .ORANGE6  = must_from_hex("#C2410C"),
    .ORANGE7  = must_from_hex("#9A3412"),
    .ORANGE8  = must_from_hex("#7C2D12"),
    .ORANGE9  = must_from_hex("#431407"),

    .AMBER0   = must_from_hex("#FEF3C7"),
    .AMBER1   = must_from_hex("#FDE68A"),
    .AMBER2   = must_from_hex("#FCD34D"),
    .AMBER3   = must_from_hex("#FBBF24"),
    .AMBER4   = must_from_hex("#F59E0B"),
    .AMBER5   = must_from_hex("#D97706"),
    .AMBER6   = must_from_hex("#B45309"),
    .AMBER7   = must_from_hex("#92400E"),
    .AMBER8   = must_from_hex("#78350F"),
    .AMBER9   = must_from_hex("#451A03"),

    .YELLOW0  = must_from_hex("#FEF9C3"),
    .YELLOW1  = must_from_hex("#FEF08A"),
    .YELLOW2  = must_from_hex("#FDE047"),
    .YELLOW3  = must_from_hex("#FACC15"),
    .YELLOW4  = must_from_hex("#EAB308"),
    .YELLOW5  = must_from_hex("#CA8A04"),
    .YELLOW6  = must_from_hex("#A16207"),
    .YELLOW7  = must_from_hex("#854D0E"),
    .YELLOW8  = must_from_hex("#713F12"),
    .YELLOW9  = must_from_hex("#422006"),

    .LIME0    = must_from_hex("#ECFCCB"),
    .LIME1    = must_from_hex("#D9F99D"),
    .LIME2    = must_from_hex("#BEF264"),
    .LIME3    = must_from_hex("#A3E635"),
    .LIME4    = must_from_hex("#84CC16"),
    .LIME5    = must_from_hex("#65A30D"),
    .LIME6    = must_from_hex("#4D7C0F"),
    .LIME7    = must_from_hex("#3F6212"),
    .LIME8    = must_from_hex("#365314"),
    .LIME9    = must_from_hex("#1A2E05"),

    .GREEN0   = must_from_hex("#DCFCE7"),
    .GREEN1   = must_from_hex("#BBF7D0"),
    .GREEN2   = must_from_hex("#86EFAC"),
    .GREEN3   = must_from_hex("#4ADE80"),
    .GREEN4   = must_from_hex("#22C55E"),
    .GREEN5   = must_from_hex("#16A34A"),
    .GREEN6   = must_from_hex("#15803D"),
    .GREEN7   = must_from_hex("#166534"),
    .GREEN8   = must_from_hex("#14532D"),
    .GREEN9   = must_from_hex("#052E16"),

    .EMERALD0 = must_from_hex("#D1FAE5"),
    .EMERALD1 = must_from_hex("#A7F3D0"),
    .EMERALD2 = must_from_hex("#6EE7B7"),
    .EMERALD3 = must_from_hex("#34D399"),
    .EMERALD4 = must_from_hex("#10B981"),
    .EMERALD5 = must_from_hex("#059669"),
    .EMERALD6 = must_from_hex("#047857"),
    .EMERALD7 = must_from_hex("#065F46"),
    .EMERALD8 = must_from_hex("#064E3B"),
    .EMERALD9 = must_from_hex("#022C22"),

    .TEAL0    = must_from_hex("#CCFBF1"),
    .TEAL1    = must_from_hex("#99F6E4"),
    .TEAL2    = must_from_hex("#5EEAD4"),
    .TEAL3    = must_from_hex("#2DD4BF"),
    .TEAL4    = must_from_hex("#14B8A6"),
    .TEAL5    = must_from_hex("#0D9488"),
    .TEAL6    = must_from_hex("#0F766E"),
    .TEAL7    = must_from_hex("#115E59"),
    .TEAL8    = must_from_hex("#134E4A"),
    .TEAL9    = must_from_hex("#042F2E"),

    .CYAN0    = must_from_hex("#CFFAFE"),
    .CYAN1    = must_from_hex("#A5F3FC"),
    .CYAN2    = must_from_hex("#67E8F9"),
    .CYAN3    = must_from_hex("#22D3EE"),
    .CYAN4    = must_from_hex("#06B6D4"),
    .CYAN5    = must_from_hex("#0891B2"),
    .CYAN6    = must_from_hex("#0E7490"),
    .CYAN7    = must_from_hex("#155E75"),
    .CYAN8    = must_from_hex("#164E63"),
    .CYAN9    = must_from_hex("#083344"),

    .SKY0     = must_from_hex("#E0F2FE"),
    .SKY1     = must_from_hex("#BAE6FD"),
    .SKY2     = must_from_hex("#7DD3FC"),
    .SKY3     = must_from_hex("#38BDF8"),
    .SKY4     = must_from_hex("#0EA5E9"),
    .SKY5     = must_from_hex("#0284C7"),
    .SKY6     = must_from_hex("#0369A1"),
    .SKY7     = must_from_hex("#075985"),
    .SKY8     = must_from_hex("#0C4A6E"),
    .SKY9     = must_from_hex("#082F49"),

    .BLUE0    = must_from_hex("#DBEAFE"),
    .BLUE1    = must_from_hex("#BFDBFE"),
    .BLUE2    = must_from_hex("#93C5FD"),
    .BLUE3    = must_from_hex("#60A5FA"),
    .BLUE4    = must_from_hex("#3B82F6"),
    .BLUE5    = must_from_hex("#2563EB"),
    .BLUE6    = must_from_hex("#1D4ED8"),
    .BLUE7    = must_from_hex("#1E40AF"),
    .BLUE8    = must_from_hex("#1E3A8A"),
    .BLUE9    = must_from_hex("#172554"),

    .INDIGO0  = must_from_hex("#E0E7FF"),
    .INDIGO1  = must_from_hex("#C7D2FE"),
    .INDIGO2  = must_from_hex("#A5B4FC"),
    .INDIGO3  = must_from_hex("#818CF8"),
    .INDIGO4  = must_from_hex("#6366F1"),
    .INDIGO5  = must_from_hex("#4F46E5"),
    .INDIGO6  = must_from_hex("#4338CA"),
    .INDIGO7  = must_from_hex("#3730A3"),
    .INDIGO8  = must_from_hex("#312E81"),
    .INDIGO9  = must_from_hex("#1E1B4B"),

    .VIOLET0  = must_from_hex("#EDE9FE"),
    .VIOLET1  = must_from_hex("#DDD6FE"),
    .VIOLET2  = must_from_hex("#C4B5FD"),
    .VIOLET3  = must_from_hex("#A78BFA"),
    .VIOLET4  = must_from_hex("#8B5CF6"),
    .VIOLET5  = must_from_hex("#7C3AED"),
    .VIOLET6  = must_from_hex("#6D28D9"),
    .VIOLET7  = must_from_hex("#5B21B6"),
    .VIOLET8  = must_from_hex("#4C1D95"),
    .VIOLET9  = must_from_hex("#2E1065"),

    .PURPLE0  = must_from_hex("#F3E8FF"),
    .PURPLE1  = must_from_hex("#E9D5FF"),
    .PURPLE2  = must_from_hex("#D8B4FE"),
    .PURPLE3  = must_from_hex("#C084FC"),
    .PURPLE4  = must_from_hex("#A855F7"),
    .PURPLE5  = must_from_hex("#9333EA"),
    .PURPLE6  = must_from_hex("#7E22CE"),
    .PURPLE7  = must_from_hex("#6B21A8"),
    .PURPLE8  = must_from_hex("#581C87"),
    .PURPLE9  = must_from_hex("#3B0764"),

    .FUCHSIA0 = must_from_hex("#FAE8FF"),
    .FUCHSIA1 = must_from_hex("#F5D0FE"),
    .FUCHSIA2 = must_from_hex("#F0ABFC"),
    .FUCHSIA3 = must_from_hex("#E879F9"),
    .FUCHSIA4 = must_from_hex("#D946EF"),
    .FUCHSIA5 = must_from_hex("#C026D3"),
    .FUCHSIA6 = must_from_hex("#A21CAF"),
    .FUCHSIA7 = must_from_hex("#86198F"),
    .FUCHSIA8 = must_from_hex("#701A75"),
    .FUCHSIA9 = must_from_hex("#4A044E"),

    .PINK0    = must_from_hex("#FCE7F3"),
    .PINK1    = must_from_hex("#FBCFE8"),
    .PINK2    = must_from_hex("#F9A8D4"),
    .PINK3    = must_from_hex("#F472B6"),
    .PINK4    = must_from_hex("#EC4899"),
    .PINK5    = must_from_hex("#DB2777"),
    .PINK6    = must_from_hex("#BE185D"),
    .PINK7    = must_from_hex("#9D174D"),
    .PINK8    = must_from_hex("#831843"),
    .PINK9    = must_from_hex("#500724"),

    .ROSE0    = must_from_hex("#FFE4E6"),
    .ROSE1    = must_from_hex("#FECDD3"),
    .ROSE2    = must_from_hex("#FDA4AF"),
    .ROSE3    = must_from_hex("#FB7185"),
    .ROSE4    = must_from_hex("#F43F5E"),
    .ROSE5    = must_from_hex("#E11D48"),
    .ROSE6    = must_from_hex("#BE123C"),
    .ROSE7    = must_from_hex("#9F1239"),
    .ROSE8    = must_from_hex("#881337"),
    .ROSE9    = must_from_hex("#4C0519"),
}