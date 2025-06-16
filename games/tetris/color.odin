package tetris

import rl "vendor:raylib"

DARK_GREY := rl.Color{26, 31, 40, 255}
GREEN := rl.Color{47, 230, 23, 255}
RED := rl.Color{232, 18, 18, 255}
ORANGE := rl.Color{226, 116, 17, 255}
YELLOW := rl.Color{237, 234, 4, 255}
PURPLE := rl.Color{166, 0, 247, 255}
CYAN := rl.Color{21, 204, 209, 255}
BLUE := rl.Color{13, 64, 216, 255}
LIGHT_BLUE := rl.Color{59, 85, 162, 255}
DARK_BLUE := rl.Color{44, 44, 127, 255}

get_cell_colors :: proc() -> []rl.Color {
    colors := make([]rl.Color, 8)
    colors[0] = DARK_GREY
    colors[1] = GREEN
    colors[2] = RED
    colors[3] = ORANGE
    colors[4] = YELLOW
    colors[5] = PURPLE
    colors[6] = CYAN
    colors[7] = BLUE
    return colors
}

destroy_colors :: proc(colors: []rl.Color) {
    delete(colors)
}