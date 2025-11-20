package main 

import rl "vendor:raylib"

Point :: struct {
     pos: rl.Vector2,
     prevPos: rl.Vector2,
     initPos: rl.Vector2,
     isPinned: bool,
     isSelected: bool
}

Stick :: struct {
    p0: ^Point,
    p1: ^Point,
    isActive: bool
}

Cloth :: struct {
    points: [dynamic]^Point,
    sticks: [dynamic]^Stick
}

new_cloth :: proc(width, height, spacing, start_x, start_y: int) -> (c: Cloth) {
    for y := 0; y <= height; y += 1 {
        for x := 0; x <= width; x += 1 {
            point := new(Point)
            point.initPos = { f32(start_x + x * spacing), f32(start_y + y * spacing) }
            point.pos = point.initPos
            point.prevPos = point.initPos
            point.isPinned = y == 0
            append(&c.points, point)

            if x != 0 {
                stick := new(Stick)
                stick.p0 = c.points[len(c.points) - 2]
                stick.p1 = c.points[len(c.points) - 1]
                stick.isActive = true
                append(&c.sticks, stick)
            }

            if y != 0 {
                stick := new(Stick)
                stick.p0 = c.points[(y - 1) * (width + 1) + x]
                stick.p1 = c.points[y * (width + 1) + x]
                stick.isActive = true
                append(&c.sticks, stick)
            }
        }
    }

    return c
}

update :: proc(cloth: ^Cloth, delta_time: f32, spacing: int, drag: f32, acceleration: rl.Vector2, 
    elasticity: f32, iterations: int, correctionFactor: f32) {
    for point in cloth.points {
        if point.isPinned {
            point.pos = point.initPos
            continue
        }

        velocity: rl.Vector2 = point.pos - point.prevPos
        point.prevPos = point.pos
        point.pos += velocity * (1.0 - drag) + acceleration * delta_time * delta_time
    }

    for i := 0; i < iterations; i += 1 {
        for stick in cloth.sticks {
            delta: rl.Vector2 = stick.p1.pos - stick.p0.pos
            dist: f32 = rl.Vector2Length(delta)
    
            if (dist > elasticity) {
                stick.isActive = false
            }
    
            correction: rl.Vector2 = delta * ((dist - f32(spacing)) / dist * 0.5)
            correction *= correctionFactor
    
            if !stick.p0.isPinned && stick.isActive {
                stick.p0.pos += correction
            }
    
            if !stick.p1.isPinned && stick.isActive  {
                stick.p1.pos -= correction
            }
        }
    } 
}

draw :: proc(cloth: ^Cloth, spacing: int, elasticity: f32) {
    for stick in cloth.sticks {
        if (stick.isActive) {
            distance := rl.Vector2Distance(stick.p0.pos, stick.p1.pos)
            color := stick.p0.isSelected || stick.p1.isSelected ? rl.BLUE : get_color(distance, elasticity, spacing)
            rl.DrawLineV(stick.p0.pos, stick.p1.pos, color)
        }
    }

    get_color :: proc(distance: f32, elasticity: f32, spacing: int) -> rl.Color {
        if distance <= f32(spacing) {
            return {44, 222, 130, 255}  // Green
        } else if distance <= f32(spacing) * 1.33 {
            t := (distance - f32(spacing)) / (f32(spacing) * 0.33)
            return {lerp(44, 255, t), lerp(222, 255, t), lerp(130, 0, t), 255}  // Gradual transition to yellow
        } else {
            t := (distance - f32(spacing) * 1.33) / (elasticity - f32(spacing) * 1.33)
            return {lerp(255, 222, t), lerp(255, 44, t), lerp(0, 44, t), 255}  // Gradual transition to red
        }

        lerp :: proc(a: f32, b: f32, t: f32) -> u8 {
            return u8(a + ((b - a) * t))
        }
    }
}

handle_mouse :: proc(cloth: ^Cloth, cursor_size: ^f32) {
    if rl.GetMouseWheelMove() > 0 {
        cursor_size^ += 5 
    } else if rl.GetMouseWheelMove() < 0 && !(cursor_size^ <= 5) {
        cursor_size^ -= 5
    }
    
    @(static) prevMousePos : rl.Vector2
    
    pos: rl.Vector2 = rl.GetMousePosition()
    delta: rl.Vector2 = pos - prevMousePos
    delta = rl.Vector2Clamp(delta, {0,0}, {100,100})

    for &point in cloth.points {
        dist: f32 = rl.Vector2Distance(pos, point.pos)
        if dist < cursor_size^ {
            if rl.IsMouseButtonDown(.LEFT) { 
                point.prevPos = point.prevPos + delta
                point.pos = point.pos + delta
            }
            point.isSelected = true
        } else {
            point.isSelected = false
        }
    }

    prevMousePos = pos
}

main :: proc() {
    rl.InitWindow(0, 0, "Cloth Simulation 2D")
    rl.ToggleBorderlessWindowed()
    WIDTH := rl.GetScreenWidth()
    HEIGHT := rl.GetScreenHeight()
    rl.SetTargetFPS(300)

    spacing := 10
    width := 150
    height := 75
    cloth := new_cloth(width, height, spacing, (int(WIDTH) - (width * spacing)) / 2, 50)
    defer {
        for &point in cloth.points {
            free(point)
        }
        
        for &stick in cloth.sticks {
            free(stick)
        }
    }

    drag: f32 = 0.005
    acceleration: rl.Vector2 = {0, 980}
    elasticity: f32 = 80.0
    cursor_size: f32 = 30.0
    iterations := 2
    corr_factor: f32 = 0.5

    delta: f32 = 1.0 / 300.0
    accumulator: f32 = 0.0

    for !rl.WindowShouldClose() { 
        rl.BeginDrawing()
        rl.ClearBackground({33, 40, 48, 255})
        handle_mouse(&cloth, &cursor_size)

        accumulator += rl.GetFrameTime()
        for accumulator >= delta {
            update(&cloth, delta, spacing, drag, acceleration, elasticity, iterations, corr_factor)
            accumulator -= delta
        }

        draw(&cloth, spacing, elasticity)
        rl.EndDrawing()
    }

    rl.CloseWindow()
}