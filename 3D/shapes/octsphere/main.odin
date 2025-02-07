// Octahedral mapping visualization in Odin and Raylib
// by Jakub Tomšů (@jakubtomsu_)
//
// Build and run with 'odin run octsphere.odin -file'.
// No additional dependencies required.
//
// Sources:
// https://gpuopen.com/learn/fetching-from-cubes-and-octahedrons/
// https://knarkowicz.wordpress.com/2014/04/16/octahedron-normal-vector-encoding/

package octsphere

import "core:fmt"
import "core:math/linalg"
import rl "vendor:raylib"

abs :: linalg.abs

Mode :: enum {
    Sphere,
    Hemisphere,
}

mode_to_dir :: proc(mode: Mode, uv: rl.Vector2) -> rl.Vector3 {
    switch mode {
    case .Sphere: return sphoct_to_dir(uv)
    case .Hemisphere: return hemioct_to_dir(uv * 2 - 1).xzy;
    }
    return {}
}

sphoct_wrap :: proc(v: rl.Vector2) -> rl.Vector2 {
    f: rl.Vector2
    f.x = v.x >= 0 ? 1 : -1
    f.y = v.y >= 0 ? 1 : -1
    return (1.0 - abs(v.yx)) * f
}

dir_to_sphoct :: proc(n: rl.Vector3) -> rl.Vector2 {
    n := n
    n /= (abs(n.x) + abs(n.y) + abs(n.z))
    n.xz = n.z >= 0.0 ? n.xz : cast([2]f32)sphoct_wrap(n.xz)
    n.xz = n.xz * 0.5 + 0.5
    return n.xz
}

sphoct_to_dir :: proc(f: rl.Vector2) -> rl.Vector3 {
    f := f
    f = f * 2.0 - 1.0
    // https://twitter.com/Stubbesaurus/status/937994790553227264
    n := rl.Vector3{f.x, 1.0 - abs(f.x) - abs(f.y), f.y}
    t: f32 = clamp(-n.y, 0, 1)
    // n.xy += (n.x >= 0.0 || n.y >= 0.0) ? -t : t
    n.x += n.x >= 0 ? -t : t
    n.z += n.z >= 0 ? -t : t
    return linalg.normalize(n)
}

// Assume input on [-1, 1]. Output is normalized on +Z hemisphere.
hemioct_to_dir :: proc(e: rl.Vector2) -> rl.Vector3 {
    temp := rl.Vector2{e.x + e.y, e.x - e.y} * 0.5
    v := rl.Vector3{temp.x, temp.y, 1.0 - abs(temp.x) - abs(temp.y)}
    return linalg.normalize(v)
}

// Assume normalized input on +Z hemisphere. Output is on [-1, 1].
dir_to_hemioct :: proc(v: rl.Vector3) -> rl.Vector2 {
    // Project the hemisphere onto the hemi-octahedron, and then into the xy plane
    p := v.xy * (1.0 / (abs(v.x) + abs(v.y) + v.z))
    // Rotate and scale the center diamond to the unit square
    return {p.x + p.y, p.x - p.y};
}

main :: proc() {
    rl.SetConfigFlags({.VSYNC_HINT, .MSAA_4X_HINT})
    rl.InitWindow(1000, 800, "Octahedral mapping - use arrow keys to change resolution")

    cam := rl.Camera3D {
        position = {0, 3.5, -5},
        fovy = 30,
        up = {0, 1, 0},
    }

    res: [2]int = 4
    mode: Mode = .Sphere

    for !rl.WindowShouldClose() {
        rl.UpdateCamera(&cam, .ORBITAL)

        if rl.IsKeyPressed(.UP) {
            res.y += 1
        }

        if rl.IsKeyPressed(.DOWN) {
            res.y -= 1
        }

        if rl.IsKeyPressed(.LEFT) {
            res.x -= 1
        }

        if rl.IsKeyPressed(.RIGHT) {
            res.x += 1
        }
        
        if rl.IsKeyPressed(.SPACE) {
            mode = Mode((int(mode) + 1) %% len(Mode))
        }

        rl.BeginDrawing()
        rl.ClearBackground({10, 20, 25, 255})

        rl.BeginMode3D(cam)
        rl.DrawSphereEx(0, 1, 256, 256, rl.GRAY)
        rl.DrawCircle3D(0, 1.01, {1, 0, 0}, 90, rl.WHITE)
        rl.DrawCircle3D(0, 1.01, {0, 1, 0}, 90, rl.WHITE)
        rl.DrawCircle3D(0, 1.01, {0, 0, 1}, 90, rl.WHITE)

        for x in 0 ..< res.x {
            for y in 0 ..< res.y {
                uv := rl.Vector2{(0.5 + f32(x)) / f32(res.x), (0.5 + f32(y)) / f32(res.y)}
                n := mode_to_dir(mode, uv);
                end := n * 1.3
                // rl.DrawLine3D(n, end, rl.WHITE)
                rl.DrawSphere(n, 0.05, rl.ColorFromNormalized({uv.x, uv.y, 0.0, 1.0}))
            }
        }

        rl.EndMode3D()

        S :: 200
        OFFS: rl.Vector2 : {2, 66}
        scale := S / rl.Vector2{f32(res.x), f32(res.y)}
        for x in 0 ..< res.x {
            for y in 0 ..< res.y {
                p := rl.Vector2{f32(x), f32(y)}
                uv := rl.Vector2{(0.5 + f32(x)) / f32(res.x), (0.5 + f32(y)) / f32(res.y)}
                rl.DrawRectangleV(p * scale + OFFS, scale, rl.ColorFromNormalized({uv.x, uv.y, 0.0, 1.0}))
                rl.DrawRectangleV((p + 0.5) * scale + OFFS - 1, 2, {0, 0, 0, 200})
            }
        }

        // Draw
        UV_LINE_COL: rl.Color: {255, 255, 255, 150}
        rl.DrawLineV(OFFS + S * {0, 0}, OFFS + S * {1, 0}, UV_LINE_COL)
        rl.DrawLineV(OFFS + S * {0, 0}, OFFS + S * {0, 1}, UV_LINE_COL)
        rl.DrawLineV(OFFS + S * {1, 0}, OFFS + S * {1, 1}, UV_LINE_COL)
        rl.DrawLineV(OFFS + S * {0, 1}, OFFS + S * {1, 1}, UV_LINE_COL)

        switch mode {
        case .Sphere:
            rl.DrawLineV(OFFS + S * {0.5, 0.5}, OFFS + S * {0.5, 0}, UV_LINE_COL)
            rl.DrawLineV(OFFS + S * {0.5, 0.5}, OFFS + S * {0.5, 1}, UV_LINE_COL)
            rl.DrawLineV(OFFS + S * {0.5, 0.5}, OFFS + S * {0, 0.5}, UV_LINE_COL)
            rl.DrawLineV(OFFS + S * {0.5, 0.5}, OFFS + S * {1, 0.5}, UV_LINE_COL)
    
            rl.DrawLineV(OFFS + S * {0.5, 0.0}, OFFS + S * {1, 0.5}, UV_LINE_COL)
            rl.DrawLineV(OFFS + S * {0.5, 0.0}, OFFS + S * {0, 0.5}, UV_LINE_COL)
            rl.DrawLineV(OFFS + S * {1.0, 0.5}, OFFS + S * {0.5, 1}, UV_LINE_COL)
            rl.DrawLineV(OFFS + S * {0.0, 0.5}, OFFS + S * {0.5, 1}, UV_LINE_COL)
        
        case .Hemisphere:
            rl.DrawLineV(OFFS + S * {0, 0}, OFFS + S * {0.5, 0.5}, UV_LINE_COL)
            rl.DrawLineV(OFFS + S * {1, 0}, OFFS + S * {0.5, 0.5}, UV_LINE_COL)
            rl.DrawLineV(OFFS + S * {0, 1}, OFFS + S * {0.5, 0.5}, UV_LINE_COL)
            rl.DrawLineV(OFFS + S * {1, 1}, OFFS + S * {0.5, 0.5}, UV_LINE_COL)
        }
        
        rl.DrawText(fmt.ctprintf("Mode:         %v", mode), 2, 2, 20, rl.WHITE)
        rl.DrawText(fmt.ctprintf("Resolution:   %v", res), 2, 22, 20, rl.WHITE)
        rl.DrawText(fmt.ctprintf("Total pixels: %v", res.x * res.y), 2, 44, 20, rl.WHITE)

        rl.EndDrawing()
    }

    rl.CloseWindow()
}