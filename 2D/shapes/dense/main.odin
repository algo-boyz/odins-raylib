package main

import "core:math"
import "core:fmt"
import rl "vendor:raylib"

// A dense injection is a function from integers 0->infinity to
// the real line [0, 1] such that every point on the real line,
// gets approached infinity close by the function.
// The function does not map the same point twice (hence injective).
//
// The Straight Dense Injection does this by iterating a subdivided
// grid while skipping earlier points.
// The grid becomes finer and finer as n increase.
straight_di :: proc(n: int) -> f32 {
    r := math.pow(2, math.floor(math.log2(f32(n+1))))
    v := (1.5 + f32(n)) / r - 1
    return v
}

// The Inward Dense Injection satisfies the same DI conditions but
// iterates the grid points in an alternating fashion rather than increasing.
// This means each layer converges to 0.5. 
// This one looks nicer and is better suited when symmetry is preferred.
inward_di :: proc(n: int) -> f32 {
    r := math.pow(2, math.floor(math.log2(f32(n+1))))
    A := 1 - f32(n % 2)
    s := math.floor(f32(n+1-int(r))/2)
    v := (0.5 + s + A*(r-1-2*s))/r
    return v
}

// Rather than convering inwards, this one converges outwards.
outward_di :: proc(n: int) -> f32 {
    r := int(math.pow(2, math.floor(math.log2(f32(n+1)))))
    A := 1 - f32((3*r-3-n) % 2)
    s := math.floor(f32(2*r-2-n)/2)
    v := (0.5 + s + A*(f32(r)-1-2*s))/f32(r)
    return v
}

wrap :: proc(value, min, max: f32) -> f32 {
    result := value
    if result < min do result = max
    if result > max do result = min
    return result
}

clamp :: proc(value, min, max: int) -> int {
    if value < min do return min
    if value > max do return max
    return value
}

main :: proc() {
    rl.SetConfigFlags({.MSAA_4X_HINT})
    rl.InitWindow(1000, 800, "Dense Injection")
    defer rl.CloseWindow()

    ladders:uint = 8
    max_points := 1 << ladders
    height := f32(500)
    width := f32(900)
    grid_color := rl.ColorFromHSV(0, 0, 0.2)

    speed := f32(100)
    base_speed := f32(100)
    speed_factor := 0

    circle_radius := f32(4)
    num_points := 0
    num_points_f := f32(0)
    di_type := 0

    x0 := f32(500) - width/2
    y0 := f32(500) - height/2

    points := make([]rl.Vector2, max_points)
    defer delete(points)

    // Load Latex formulas
    di_textures := [3]rl.Texture2D{
        rl.LoadTexture("sdi.png"),
        rl.LoadTexture("idi.png"),
        rl.LoadTexture("odi.png"),
    }
    defer {
        for tex in di_textures {
            rl.UnloadTexture(tex)
        }
    }
    
    for i := 0; i < 3; i += 1 {
        rl.GenTextureMipmaps(&di_textures[i])
    }

    for !rl.WindowShouldClose() {
        num_points_f = wrap(num_points_f + rl.GetFrameTime() * speed, 0, f32(max_points - 1))
        num_points = int(num_points_f)
        speed = base_speed * math.pow(2, f32(speed_factor))
        last_value := f32(0)
        
        if rl.IsKeyPressed(.SPACE) do num_points_f = 0
        if rl.IsKeyPressed(.RIGHT) do di_type = clamp(di_type + 1, 0, 2)
        if rl.IsKeyPressed(.LEFT) do di_type = clamp(di_type - 1, 0, 2)
        if rl.IsKeyPressed(.UP) do speed_factor = clamp(speed_factor + 1, -6, 2)
        if rl.IsKeyPressed(.DOWN) do speed_factor = clamp(speed_factor - 1, -6, 2)

        rl.BeginDrawing()
        rl.ClearBackground(rl.BLACK)

        // Iterate all ladders and draw points.
        // Keep track of points in vector list.
        n := 0
        for i:uint; i < ladders; i += 1 {
            y := y0 + height * 1.0 / f32(ladders) * (f32(i) + 0.5)
            rl.DrawLine(i32(x0), i32(y), i32(x0 + width), i32(y), grid_color)
            rl.DrawCircle(i32(x0), i32(y), circle_radius, grid_color)
            rl.DrawCircle(i32(x0 + width), i32(y), circle_radius, grid_color)

            // Draw 2^i points on each ladder, up until the total number of points.
            for j := 0; j < int(math.pow(2, f32(i))) && n < num_points; j += 1 {
                f: f32
                switch di_type {
                case 0: f = straight_di(n)
                case 1: f = inward_di(n)
                case 2: f = outward_di(n)
                }
                
                if n == num_points - 1 do last_value = f

                x := x0 + width * f
                points[n] = rl.Vector2{x0 + width / f32(max_points) * f32(n), y0 + 10 - 150 * f}
                rl.DrawCircleV(points[n], 2, rl.DARKBLUE)

                rl.DrawLine(i32(x), i32(y), i32(x), i32(y0 + height), grid_color)
                rl.DrawCircle(i32(x), i32(y), circle_radius, rl.ColorFromHSV(360 * f, 1, 1))
                n += 1
            }
        }

        rl.DrawLineStrip(raw_data(points), i32(num_points), rl.DARKBLUE)
        
        texture := di_textures[di_type]
        rl.DrawTextureEx(
            texture, 
            rl.Vector2{500 - f32(texture.width) / 2.0 * 0.75, 50}, 
            0, 
            0.75, 
            rl.WHITE
        )
        di_names := [3]cstring{
            "1. Straight Dense Injection (SDI)", 
            "2. Inward Dense Injection (IDI)", 
            "3. Outward Dense Injection (ODI)",
        }
        rl.DrawText(di_names[di_type], 10, 10, 20, rl.DARKGRAY)
        rl.DrawText(
            fmt.ctprintf("(Left/Right) Change Function, (Up/Down) Speed = %3.1f", speed),
            700,
            10,
            10,
            rl.DARKGRAY)
        rl.EndDrawing()
    }
}