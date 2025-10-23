package main

import rl "vendor:raylib"
import "core:math"

WINDOW_WIDTH  :: 1280
WINDOW_HEIGHT :: 720

CELL_SIZE :: 5

numX :: WINDOW_WIDTH  / CELL_SIZE
numY :: WINDOW_HEIGHT / CELL_SIZE
numCells :: numX * numY

resolution :: f32(1.0)        // similation resolution

u    := make([]f32, numCells) // horizontal velocity
v    := make([]f32, numCells) // vertical   velocity
newU := make([]f32, numCells)
newV := make([]f32, numCells)

p    := make([]f32, numCells) // pressure (for drawing)
s    := make([]f32, numCells) // walls (0 = fluid, 1 = solid)

m    := make([]f32, numCells) // smoke/density
newM := make([]f32, numCells)

solve_incompressibility :: proc() {
    n := numY

    for i in 1..<numX-1 {
        for j in 1..<numY-1 {
            if s[i*n + j] == 0.0 {
                continue
            }

            sx0 := s[(i-1)*n + j]
            sx1 := s[(i+1)*n + j]
            sy0 := s[i*n + j-1]
            sy1 := s[i*n + j+1]

            num_walls := sx0 + sx1 + sy0 + sy1

            if num_walls == 0.0 {
                continue
            }

            divergence := u[(i+1)*n + j] - u[i*n + j] +
                            v[i*n + j+1] - v[i*n + j]

            OVER_RELAXATION :: 1.9
            pressure := (-divergence / num_walls) * OVER_RELAXATION
            p[i*n + j] += pressure

            u[i*n + j]     -= sx0 * pressure
            u[(i+1)*n + j] += sx1 * pressure
            v[i*n + j]     -= sy0 * pressure
            v[i*n + j+1]   += sy1 * pressure
        }
    }
}

extrapolate :: proc() {
    n := numY

    for i in 0..<numX {
        u[i*numY + 0] = u[i*numY + 1]
        u[i*numY + numY-1] = u[i*numY + numY-2]
    }

    for j in 0..<numY {
        v[0*n + j] = v[1*n + j]
        v[(numX-1)*n + j] = v[(numX-2)*n + j]
    }
}

U_FIELD :: 0
V_FIELD :: 1
S_FIELD :: 2

sample_field :: proc(x, y: f32, field: int) -> f32 {
    n := numY
    h1 := 1.0 / resolution
    h2 := 0.5 * resolution

    // Clamp coordinates to valid range
    clamped_x := clamp(x, resolution, f32(numX) * resolution)
    clamped_y := clamp(y, resolution, f32(numY) * resolution)

    dx, dy: f32
    field_array: []f32

    switch field {
    case U_FIELD:
        field_array = u
        dy = h2
    case V_FIELD:
        field_array = v
        dx = h2
    case S_FIELD:
        field_array = m
        dx = h2
        dy = h2
    }

    x0 := int(min(math.floor((clamped_x - dx) * h1), f32(numX - 1)))
    tx := ((clamped_x - dx) - f32(x0) * resolution) * h1
    x1 := int(min(f32(x0) + 1, f32(numX - 1)))

    y0 := int(min(math.floor((clamped_y - dy) * h1), f32(numY - 1)))
    ty := ((clamped_y - dy) - f32(y0) * resolution) * h1
    y1 := int(min(f32(y0) + 1, f32(numY - 1)))

    sx := 1.0 - tx
    sy := 1.0 - ty

    val := sx * sy * field_array[x0 * n + y0] +
           tx * sy * field_array[x1 * n + y0] +
           tx * ty * field_array[x1 * n + y1] +
           sx * ty * field_array[x0 * n + y1]

    return val
}

avg_u :: proc(i, j: int) -> f32 {
    n := numY
    result := (u[i * n + j - 1] + u[i * n + j] +
               u[(i + 1) * n + j - 1] + u[(i + 1) * n + j]) * 0.25
    return result
}

avg_v :: proc(i, j: int) -> f32 {
    n := numY
    result := (v[(i - 1) * n + j] + v[i * n + j] +
               v[(i - 1) * n + j + 1] + v[i * n + j + 1]) * 0.25
    return result
}

advect_vel :: proc(dt : f32) {
    copy(newU[:], u[:])
    copy(newV[:], v[:])

    n := numY
    h2 := 0.5 * resolution

    for i in 1..<numX {
        for j in 1..<numY {
            // Advect u component
            if s[i * n + j] != 0.0 && s[(i - 1) * n + j] != 0.0 && j < numY - 1 {
                x := f32(i) * resolution
                y := f32(j) * resolution + h2
                vel_u := u[i * n + j]
                vel_v := avg_v(i, j)

                // Trace backwards in time
                x = x - dt * vel_u
                y = y - dt * vel_v

                // Sample velocity at traced position
                sampled_u := sample_field(x, y, U_FIELD)
                newU[i * n + j] = sampled_u
            }

            // Advect v component
            if s[i * n + j] != 0.0 && s[i * n + j - 1] != 0.0 && i < numX - 1 {
                x := f32(i) * resolution + h2
                y := f32(j) * resolution
                vel_u := avg_u(i, j)
                vel_v := v[i * n + j]

                // Trace backwards in time
                x = x - dt * vel_u
                y = y - dt * vel_v

                // Sample velocity at traced position
                sampled_v := sample_field(x, y, V_FIELD)
                newV[i * n + j] = sampled_v
            }
        }
    }

    copy(u[:], newU[:])
    copy(v[:], newV[:])
}

advect_smoke :: proc(dt : f32) {
    copy(newM[:], m[:])

    n := numY
    h2 := 0.5 * resolution

    for i in 1..<numX-1 {
        for j in 1..<numY-1 {
            if s[i * n + j] != 0.0 {
                // Get velocity at cell center
                vel_u := (u[i * n + j] + u[(i + 1) * n + j]) * 0.5
                vel_v := (v[i * n + j] + v[i * n + j + 1]) * 0.5

                // Trace backwards in time
                x := f32(i) * resolution + h2 - dt * vel_u
                y := f32(j) * resolution + h2 - dt * vel_v

                // Sample smoke at traced position
                newM[i * n + j] = sample_field(x, y, S_FIELD)
            }
        }
    }

    copy(m[:], newM[:])
}

simulate :: proc(dt : f32) {
    for &pressure in p {
        pressure = 0
    }

    for i in 0..<20 {
        solve_incompressibility()
    }

    extrapolate()
    advect_vel(dt)
    advect_smoke(dt)
}

main :: proc() {
    rl.SetWindowState({.VSYNC_HINT})
    rl.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "Fluid Simulation")

    for x in 1..<numX-1 {
        for y in 1..<numY-1 {
            s[x * numY + y] = 1.0 // everything is a fluid except borders
        }
    }

    for x in numX/3..<2*numX/3 {
        for y in numY/3..<2*numY/3 {
            m[x * numY + y] = 1.0 // add some smoke to the middle
        }
    }

    dt :: f32(1.0 / 165.0)

    for !rl.WindowShouldClose() {
        if rl.IsMouseButtonDown(.LEFT) {
            mousePos := rl.GetMousePosition()
            i := i32(mousePos.x) / CELL_SIZE
            j := i32(mousePos.y) / CELL_SIZE

            if i >= 1 && i < numX-1 && j >= 1 && j < numY-1 {
                u[i * numY + j] += 200.0
                u[(i+1) * numY + j] += 200.0
                m[i * numY + j] = 1.5 // add smoke

                u[i * numY + j + 1] += 200.0
                u[(i+1) * numY + j + 1] += 200.0
                m[i * numY + j + 1] = 1.5
            }
        }

        if rl.IsMouseButtonDown(.RIGHT) {
            mousePos := rl.GetMousePosition()
            i := i32(mousePos.x) / CELL_SIZE
            j := i32(mousePos.y) / CELL_SIZE

            if i >= 1 && i < numX-1 && j >= 1 && j < numY-1 {
                s[i * numY + j] = 0.0 // draw walls
            }
        }

        simulate(dt)

        rl.BeginDrawing()
        rl.ClearBackground({33, 40, 48, 255})

        for x in 0..<numX {
            for y in 0..<numY {
                if s[x * numY + y] == 0.0 {
                    rl.DrawRectangle(i32(x * CELL_SIZE), i32(y * CELL_SIZE), CELL_SIZE, CELL_SIZE, rl.DARKBROWN)
                } else {
                    value := clamp(m[x * numY + y] * 255.0, 0.0, 255.0)
                    c := u8(value)
                    rl.DrawRectangle(i32(x * CELL_SIZE), i32(y * CELL_SIZE), CELL_SIZE, CELL_SIZE, rl.Color{c, c, c, 255})
                }

            }
        }

        if rl.IsKeyDown(.SPACE){
            for x in 0..<numX {
                for y in 0..<numY {
                    if s[x * numY + y] != 0 {
                        vel_u := u[x * numY + y] * 2.0
                        vel_v := v[x * numY + y] * 2.0

                        start_x := f32(x * CELL_SIZE + CELL_SIZE/2)
                        start_y := f32(y * CELL_SIZE + CELL_SIZE/2)
                        end_x := start_x + vel_u
                        end_y := start_y + vel_v

                        rl.DrawLine(i32(start_x), i32(start_y), i32(end_x), i32(end_y), rl.RED)
                    }
                }
            }
        }

        rl.EndDrawing()
    }

    rl.CloseWindow()
}