package geom

import rl "vendor:raylib"

LineDimensions_Orient :: enum { NONE, HOR, VER }

LineDimensions :: struct {
    using _ : struct #raw_union {
        using _: struct { x0, x1: i32 },
        x: i32
    },
    using _ : struct #raw_union {
        using _: struct { y0, y1: i32 },
        y: i32
    },
    orient: LineDimensions_Orient
}

draw_line :: proc(line: LineDimensions, color: rl.Color) {
    using line
    switch orient {
        case .HOR:  rl.DrawLine(line.x0, line.y, line.x1, line.y, color)
        case .VER:  rl.DrawLine(line.x, line.y0, line.x, line.y1, color)
        case .NONE: rl.DrawLine(line.x0, line.y0, line.x1, line.y1, color)
    }
}

draw_vertical_line :: proc "contextless" (x: i32, color: rl.Color) {
    rl.DrawLine(x, 0, x, rl.GetScreenHeight(), color)
}

draw_horizontal_line :: proc "contextless" (y: i32, color: rl.Color) {
    rl.DrawLine(0, y, rl.GetScreenWidth(), y, color)
}