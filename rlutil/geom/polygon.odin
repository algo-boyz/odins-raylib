package geom

import rl "vendor:raylib"

// TODO: https://github.com/marichardson137/Prism/blob/main/src/geometry.cpp

DrawPolygonLines :: proc(vertices: []rl.Vector2, color: rl.Color) {
    for v1, i in vertices {
        v2 := vertices[(i+1) % len(vertices)]

        rl.DrawLineV(v1, v2, color)
    }
}

draw_polygon :: proc(vs: []rl.Vector2, color: rl.Color) {
    switch len(vs) {
        case 0: return
        case 1: rl.DrawPixelV(vs[0], color); return
        case 2: rl.DrawLineV(vs[0], vs[1], color); return
    }

    for x := 1; x <= len(vs); x *= 2 {
        for i := 0; i + x < len(vs); i += 2*x {
            final := i + 2*x if i + 2*x < len(vs) else 0
            rl.DrawTriangle(vs[i], vs[i+x], vs[final], color)
        }
    }
}