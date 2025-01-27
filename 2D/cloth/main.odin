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

SetupCloth :: proc(width, height, spacing, startX, startY: int) -> Cloth {
    cloth: Cloth

    for y := 0; y <= height; y += 1 {
        for x := 0; x <= width; x += 1 {
            point := new(Point)
            point.initPos = { f32(startX + x * spacing), f32(startY + y * spacing) }
            point.pos = point.initPos
            point.prevPos = point.initPos
            point.isPinned = y == 0
            append(&cloth.points, point)

            if x != 0 {
                stick := new(Stick)
                stick.p0 = cloth.points[len(cloth.points) - 2]
                stick.p1 = cloth.points[len(cloth.points) - 1]
                stick.isActive = true
                append(&cloth.sticks, stick)
            }

            if y != 0 {
                stick := new(Stick)
                stick.p0 = cloth.points[(y - 1) * (width + 1) + x]
                stick.p1 = cloth.points[y * (width + 1) + x]
                stick.isActive = true
                append(&cloth.sticks, stick)
            }
        }
    }

    return cloth
}

UpdateCloth :: proc(cloth: ^Cloth, deltaTime: f32, spacing: int, drag: f32, acceleration: rl.Vector2, 
    elasticity: f32, iterations: int, correctionFactor: f32) {
    for point in cloth.points {
        if point.isPinned {
            point.pos = point.initPos
            continue
        }

        velocity: rl.Vector2 = point.pos - point.prevPos
        point.prevPos = point.pos
        point.pos += velocity * (1.0 - drag) + acceleration * deltaTime * deltaTime
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

DrawCloth :: proc(cloth: ^Cloth, spacing: int, elasticity: f32) {
    for stick in cloth.sticks {
        if (stick.isActive) {
            distance := rl.Vector2Distance(stick.p0.pos, stick.p1.pos)
            color := stick.p0.isSelected || stick.p1.isSelected ? rl.BLUE : GetColor(distance, elasticity, spacing)
            rl.DrawLineV(stick.p0.pos, stick.p1.pos, color)
        }
    }

    GetColor :: proc(distance: f32, elasticity: f32, spacing: int) -> rl.Color {
        if distance <= f32(spacing) {
            return {44, 222, 130, 255}  // Green
        } else if distance <= f32(spacing) * 1.33 {
            t := (distance - f32(spacing)) / (f32(spacing) * 0.33)
            return {Lerp(44, 255, t), Lerp(222, 255, t), Lerp(130, 0, t), 255}  // Gradual transition to yellow
        } else {
            t := (distance - f32(spacing) * 1.33) / (elasticity - f32(spacing) * 1.33)
            return {Lerp(255, 222, t), Lerp(255, 44, t), Lerp(0, 44, t), 255}  // Gradual transition to red
        }

        Lerp :: proc(a: f32, b: f32, t: f32) -> u8 {
            return u8(a + ((b - a) * t))
        }
    }
}

HandleMouseInteraction :: proc(cloth: ^Cloth, cursorSize: ^f32) {
    if rl.GetMouseWheelMove() > 0 {
        cursorSize^ += 5 
    } else if rl.GetMouseWheelMove() < 0 && !(cursorSize^ <= 5) {
        cursorSize^ -= 5
    }
    
    @(static) prevMousePos : rl.Vector2
    
    mousePos: rl.Vector2 = rl.GetMousePosition()
    mouseDelta: rl.Vector2 = mousePos - prevMousePos

    mouseDelta = rl.Vector2Clamp(mouseDelta, {0,0}, {100,100})

    for &point in cloth.points {
        dist: f32 = rl.Vector2Distance(mousePos, point.pos)
        if dist < cursorSize^ {

            if rl.IsMouseButtonDown(.LEFT) { 
                point.prevPos = point.prevPos + mouseDelta
                point.pos = point.pos + mouseDelta
            }

            point.isSelected = true
        }
        else {
            point.isSelected = false
        }
    }

    prevMousePos = mousePos
}

main :: proc() {
    rl.InitWindow(0, 0, "Cloth Simulation 2D")
    rl.ToggleBorderlessWindowed()
    screen_width := rl.GetScreenWidth()
    screen_height := rl.GetScreenHeight()
    rl.SetTargetFPS(300)

    spacing := 10
    width := 150
    height := 75
    cloth := SetupCloth(width, height, spacing, (int(screen_width) - (width * spacing)) / 2, 50)
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
    cursorSize: f32 = 30.0
    iterations := 2
    correctionFactor: f32 = 0.5

    fixedDeltaTime: f32 = 1.0 / 300.0
    accumulator: f32 = 0.0

    for !rl.WindowShouldClose() { 
        rl.BeginDrawing()
        rl.ClearBackground({33, 40, 48, 255})
        HandleMouseInteraction(&cloth, &cursorSize)

        accumulator += rl.GetFrameTime()
        for accumulator >= fixedDeltaTime {
            UpdateCloth(&cloth, fixedDeltaTime, spacing, drag, acceleration, elasticity, iterations, correctionFactor)
            accumulator -= fixedDeltaTime
        }

        DrawCloth(&cloth, spacing, elasticity)
        rl.EndDrawing()
    }

    rl.CloseWindow()
}