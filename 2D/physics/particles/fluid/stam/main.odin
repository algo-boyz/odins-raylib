package main

import "core:fmt"
import "core:mem"
import "core:math"
import rl "vendor:raylib"

N :: 256
ARRAY_SIZE :: (N + 2) * (N + 2)
SCREEN_WIDTH :: 900
SCREEN_HEIGHT :: 900

Fluid :: struct {
    size:        int,
    dt:          f64,
    diff:        f64,
    visc:        f64,
    // Changed from fixed arrays to slices (allocated on heap)
    sources:     []f64,
    density:     []f64,
    new_density: []f64,
    u:           []f64,
    v:           []f64,
    new_u:       []f64,
    new_v:       []f64,
    u_source:    []f64,
    v_source:    []f64,
    div:         []f64,
    p:           []f64,
}

ix :: proc(i, j: int) -> int {
    return i * (N + 2) + j
}

new_fluid :: proc(size: int, diff, visc: f64) -> ^Fluid {
    fluid := new(Fluid)
    
    fluid.size = size
    fluid.dt = 1.0 / 30.0
    fluid.diff = diff
    fluid.visc = visc
    
    // Allocate arrays on heap to avoid stack overflow
    fluid.sources = make([]f64, ARRAY_SIZE)
    fluid.density = make([]f64, ARRAY_SIZE)
    fluid.new_density = make([]f64, ARRAY_SIZE)
    fluid.u = make([]f64, ARRAY_SIZE)
    fluid.v = make([]f64, ARRAY_SIZE)
    fluid.new_u = make([]f64, ARRAY_SIZE)
    fluid.new_v = make([]f64, ARRAY_SIZE)
    fluid.u_source = make([]f64, ARRAY_SIZE)
    fluid.v_source = make([]f64, ARRAY_SIZE)
    fluid.div = make([]f64, ARRAY_SIZE)
    fluid.p = make([]f64, ARRAY_SIZE)
    
    return fluid
}

destroy_fluid :: proc(fluid: ^Fluid) {
    delete(fluid.sources)
    delete(fluid.density)
    delete(fluid.new_density)
    delete(fluid.u)
    delete(fluid.v)
    delete(fluid.new_u)
    delete(fluid.new_v)
    delete(fluid.u_source)
    delete(fluid.v_source)
    delete(fluid.div)
    delete(fluid.p)
    free(fluid)
}

add_source :: proc(fluid: ^Fluid) {
    for i in 0..<ARRAY_SIZE {
        fluid.density[i] += fluid.sources[i] * fluid.dt
        fluid.u[i] += fluid.u_source[i] * fluid.dt
        fluid.v[i] += fluid.v_source[i] * fluid.dt
    }
}

diffuse :: proc(fluid: ^Fluid) {
    if fluid.diff == 0 {
        return
    }
    
    a := fluid.dt * fluid.diff * f64(N * N)
    
    for k in 0..<20 {
        for i in 1..=N {
            for j in 1..=N {
                fluid.new_density[ix(i, j)] = (fluid.density[ix(i, j)] + 
                    a * (fluid.new_density[ix(i+1, j)] + fluid.new_density[ix(i-1, j)] + 
                         fluid.new_density[ix(i, j+1)] + fluid.new_density[ix(i, j-1)])) / 
                    (1.0 + 4.0 * a)
            }
        }
    }
    
    set_bnd(N, 0, fluid.new_density)
    
    // Swap arrays
    temp := fluid.density
    fluid.density = fluid.new_density
    fluid.new_density = temp
}

advect :: proc(fluid: ^Fluid) {
    dt0 := fluid.dt * f64(fluid.size)
    
    for i in 1..=N {
        for j in 1..=N {
            x := f64(i) - dt0 * fluid.v[ix(i, j)]
            y := f64(j) - dt0 * fluid.u[ix(i, j)]
            
            if x < 0.5 do x = 0.5
            else if x > f64(N) + 0.5 do x = f64(N) + 0.5
            
            if y < 0.5 do y = 0.5
            else if y > f64(N) + 0.5 do y = f64(N) + 0.5
            
            i0 := int(x)
            i1 := i0 + 1
            j0 := int(y)
            j1 := j0 + 1
            
            s1 := x - f64(i0)
            s0 := 1.0 - s1
            t1 := y - f64(j0)
            t0 := 1.0 - t1
            
            fluid.new_density[ix(i, j)] = s0 * (t0 * fluid.density[ix(i0, j0)] + t1 * fluid.density[ix(i0, j1)]) + 
                                          s1 * (t0 * fluid.density[ix(i1, j0)] + t1 * fluid.density[ix(i1, j1)])
        }
    }
    
    // Swap arrays
    temp := fluid.density
    fluid.density = fluid.new_density
    fluid.new_density = temp
}

advect_velocity :: proc(fluid: ^Fluid) {
    dt0 := fluid.dt * f64(fluid.size)
    
    for i in 1..=N {
        for j in 1..=N {
            x := f64(i) - dt0 * fluid.v[ix(i, j)]
            y := f64(j) - dt0 * fluid.u[ix(i, j)]
            
            if x < 0.5 do x = 0.5
            else if x > f64(N) + 0.5 do x = f64(N) + 0.5
            
            if y < 0.5 do y = 0.5
            else if y > f64(N) + 0.5 do y = f64(N) + 0.5
            
            i0 := int(x)
            i1 := i0 + 1
            j0 := int(y)
            j1 := j0 + 1
            
            s1 := x - f64(i0)
            s0 := 1.0 - s1
            t1 := y - f64(j0)
            t0 := 1.0 - t1
            
            fluid.new_u[ix(i, j)] = s0 * (t0 * fluid.u[ix(i0, j0)] + t1 * fluid.u[ix(i0, j1)]) + 
                                   s1 * (t0 * fluid.u[ix(i1, j0)] + t1 * fluid.u[ix(i1, j1)])
            
            fluid.new_v[ix(i, j)] = s0 * (t0 * fluid.v[ix(i0, j0)] + t1 * fluid.v[ix(i0, j1)]) + 
                                   s1 * (t0 * fluid.v[ix(i1, j0)] + t1 * fluid.v[ix(i1, j1)])
        }
    }
    
    // Swap arrays
    temp_u := fluid.u
    fluid.u = fluid.new_u
    fluid.new_u = temp_u
    
    temp_v := fluid.v
    fluid.v = fluid.new_v
    fluid.new_v = temp_v
}

project :: proc(fluid: ^Fluid) {
    h := 1.0 / f64(N)
    
    for i in 1..=N {
        for j in 1..=N {
            fluid.div[ix(i, j)] = -0.5 * h * (fluid.v[ix(i+1, j)] - fluid.v[ix(i-1, j)] + 
                                             fluid.u[ix(i, j+1)] - fluid.u[ix(i, j-1)])
            fluid.p[ix(i, j)] = 0
        }
    }
    
    set_bnd(N, 0, fluid.div)
    set_bnd(N, 0, fluid.p)
    
    for k in 0..<20 {
        for i in 1..=N {
            for j in 1..=N {
                fluid.p[ix(i, j)] = (fluid.div[ix(i, j)] + fluid.p[ix(i-1, j)] + fluid.p[ix(i+1, j)] + 
                                    fluid.p[ix(i, j-1)] + fluid.p[ix(i, j+1)]) / 4.0
            }
        }
        set_bnd(N, 0, fluid.p)
    }
    
    for i in 1..=N {
        for j in 1..=N {
            fluid.v[ix(i, j)] -= 0.5 * (fluid.p[ix(i+1, j)] - fluid.p[ix(i-1, j)]) / h
            fluid.u[ix(i, j)] -= 0.5 * (fluid.p[ix(i, j+1)] - fluid.p[ix(i, j-1)]) / h
        }
    }
    
    set_bnd(N, 1, fluid.u)
    set_bnd(N, 2, fluid.v)
}

diffuse_velocity :: proc(fluid: ^Fluid) {
    if fluid.visc == 0 {
        return
    }
    
    a := fluid.dt * fluid.visc * f64(N * N)
    
    for k in 0..<20 {
        for i in 1..=N {
            for j in 1..=N {
                fluid.new_u[ix(i, j)] = (fluid.u[ix(i, j)] + 
                    a * (fluid.new_u[ix(i+1, j)] + fluid.new_u[ix(i-1, j)] + 
                         fluid.new_u[ix(i, j+1)] + fluid.new_u[ix(i, j-1)])) / 
                    (1.0 + 4.0 * a)
                
                fluid.new_v[ix(i, j)] = (fluid.v[ix(i, j)] + 
                    a * (fluid.new_v[ix(i+1, j)] + fluid.new_v[ix(i-1, j)] + 
                         fluid.new_v[ix(i, j+1)] + fluid.new_v[ix(i, j-1)])) / 
                    (1.0 + 4.0 * a)
            }
        }
    }
    
    set_bnd(N, 0, fluid.new_u)
    set_bnd(N, 0, fluid.new_v)
    
    // Swap arrays
    temp_u := fluid.u
    fluid.u = fluid.new_u
    fluid.new_u = temp_u
    
    temp_v := fluid.v
    fluid.v = fluid.new_v
    fluid.new_v = temp_v
}

set_bnd :: proc(n: int, b: int, x: []f64) {
    for i in 1..=n {
        if b == 1 {
            x[ix(i, 0)] = -x[ix(i, 1)]
            x[ix(i, n+1)] = -x[ix(i, n)]
            x[ix(0, i)] = x[ix(1, i)]
            x[ix(n+1, i)] = x[ix(n, i)]
        } else if b == 2 {
            x[ix(i, 0)] = x[ix(i, 1)]
            x[ix(i, n+1)] = x[ix(i, n)]
            x[ix(0, i)] = -x[ix(1, i)]
            x[ix(n+1, i)] = -x[ix(n, i)]
        }
    }
    
    x[ix(0, 0)] = 0.5 * (x[ix(1, 0)] + x[ix(0, 1)])
    x[ix(0, n+1)] = 0.5 * (x[ix(1, n+1)] + x[ix(0, n)])
    x[ix(n+1, 0)] = 0.5 * (x[ix(n, 0)] + x[ix(n+1, 1)])
    x[ix(n+1, n+1)] = 0.5 * (x[ix(n, n+1)] + x[ix(n+1, n)])
}

update_fluid :: proc(fluid: ^Fluid) {
    add_source(fluid)
    diffuse(fluid)
    advect(fluid)
    diffuse_velocity(fluid)
    advect_velocity(fluid)
    project(fluid)
}

main :: proc() {
    // Initialize fluid - now returns pointer to heap-allocated fluid
    fluid := new_fluid(N, 0, 0)
    defer destroy_fluid(fluid)
    
    // Set up initial conditions - velocity sources
    for i in N/2 - 10..=N/2 + 10 {
        for j in 1..=3 {
            fluid.u_source[ix(i, j)] = 1
        }
    }
    
    for i in N/2 - 10..=N/2 + 10 {
        for j in N - 2..=N {
            fluid.u_source[ix(i, j)] = -1
        }
    }
    
    // Set up density sources
    for i in N/2 - 3..=N/2 + 3 {
        fluid.sources[ix(i, 1)] = 100
        fluid.sources[ix(i, N)] = 100
    }
    
    // Initialize Raylib
    rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "Fluid Simulator")
    rl.SetTargetFPS(60)
    
    // Create image and texture for rendering
    image := rl.GenImageColor(N, N, rl.WHITE)
    texture := rl.LoadTextureFromImage(image)
    rl.UnloadImage(image)
    
    defer {
        rl.UnloadTexture(texture)
        rl.CloseWindow()
    }
    
    // Main game loop
    for !rl.WindowShouldClose() {
        // Update fluid simulation
        update_fluid(fluid)
        
        // Create pixel data
        pixels := make([]rl.Color, N * N)
        defer delete(pixels)
        
        for i in 1..=N {
            for j in 1..=N {
                density_value := math.min(fluid.density[ix(i, j)], 1.0)
                color_value := u8(density_value * 255)
                pixel_index := (i - 1) * N + (j - 1)
                pixels[pixel_index] = rl.Color{color_value, color_value, color_value, 255}
            }
        }
        
        // Update texture
        rl.UpdateTexture(texture, raw_data(pixels))
        
        // Draw
        rl.BeginDrawing()
        rl.ClearBackground(rl.BLACK)
        
        // Scale texture to fill window
        rl.DrawTextureEx(texture, {0, 0}, 0, f32(SCREEN_WIDTH) / f32(N), rl.WHITE)
        
        rl.EndDrawing()
    }
}