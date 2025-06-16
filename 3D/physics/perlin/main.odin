package main

import "core:math"
import rl "vendor:raylib"
import "../../../rlutil/noise"

SCREEN_WIDTH :: 1024
SCREEN_HEIGHT :: 780
GRID_WIDTH :: 2048
GRID_HEIGHT :: 1560
CELL_SIZE :: 20
COLS :: GRID_WIDTH / CELL_SIZE
ROWS :: GRID_HEIGHT / CELL_SIZE
MIN_HEIGHT :: -10
MAX_HEIGHT :: 5
MOVE_SPEED :: 60

CAM_INIT_POS :: rl.Vector3{35.0, SCREEN_WIDTH, 210.0}
CAM_INIT_TARGET :: rl.Vector3{120.0, SCREEN_WIDTH, 150.0}
CAM_UP :: rl.Vector3{0.0, 0.0, 1.0}
CAM_FOVY :: 45.0
FLYING_SPEED :: 0.01

State :: struct {
    camera: rl.Camera3D,
    terrain: [COLS][ROWS]f32,
    flying: f64,
}

main :: proc() {
    state := State{
        camera = rl.Camera3D{},
        terrain = [COLS][ROWS]f32{},
        flying = 0,
    }
    
    init(&state)
    defer rl.CloseWindow()
    
    for !rl.WindowShouldClose() {
        rl.UpdateCamera(&state.camera, .FREE)
        process_input(&state)
        draw(&state)
    }
}

init :: proc(state: ^State) {
    rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "Raylib - 3D Terrain Generation")
    
    state.camera.position = CAM_INIT_POS
    state.camera.target = CAM_INIT_TARGET
    state.camera.up = CAM_UP
    state.camera.fovy = CAM_FOVY
    state.camera.projection = .PERSPECTIVE
    
    rl.SetTargetFPS(60)
    rl.DisableCursor()
}

set_terrain :: proc(state: ^State) {
    state.flying += FLYING_SPEED
    perl := noise.perlin_noise_init()
    yoff := state.flying
    for x := 0; x < COLS; x += 1 {
        xoff := 0.0
        for y := 0; y < ROWS; y += 1 {
            // Generate noise value using Perlin noise
            noise_value := noise.perlin_noise_2d(&perl, xoff, yoff)
            
            // Map the noise value to the desired range
            state.terrain[x][y] = f32(noise.map_range(noise_value, 0, 1, MIN_HEIGHT, MAX_HEIGHT))
            
            xoff += 0.2
        }
        yoff += 0.2
    }
}

process_input :: proc(state: ^State) {
    move_amount := MOVE_SPEED * rl.GetFrameTime()
    
    // Calculate forward and right vectors
    forward := rl.Vector3Normalize(state.camera.target - state.camera.position)
    right := rl.Vector3Normalize(rl.Vector3CrossProduct(forward, state.camera.up))
    
    // Forward and Backward Movement
    if rl.IsKeyDown(.W) {
        state.camera.position = state.camera.position + (forward * move_amount)
        state.camera.target = state.camera.target + (forward * move_amount)
    }
    if rl.IsKeyDown(.S) {
        state.camera.position = state.camera.position - (forward * move_amount)
        state.camera.target = state.camera.target - (forward * move_amount)
    }
    
    // Left and Right Movement
    if rl.IsKeyDown(.A) {
        state.camera.position = state.camera.position - (forward * move_amount)
        state.camera.target = state.camera.target - (forward * move_amount)
    }
    if rl.IsKeyDown(.D) {
        state.camera.position = state.camera.position + (forward * move_amount)
        state.camera.target = state.camera.target + (forward * move_amount)
    }
    
    // Up and Down Movement
    if rl.IsKeyDown(.E) {
        state.camera.position.z += move_amount
        state.camera.target.z += move_amount
    }
    if rl.IsKeyDown(.Q) {
        state.camera.position.z -= move_amount
        state.camera.target.z -= move_amount
    }
    
    // Ensure camera.up remains consistent
    state.camera.up = CAM_UP
}

draw :: proc(state: ^State) {
    set_terrain(state)
    
    rl.BeginDrawing()
    defer rl.EndDrawing()
    
    rl.ClearBackground(rl.BLACK)
    
    rl.BeginMode3D(state.camera)
    defer rl.EndMode3D()
    
    // Draw the terrain grid
    for x := 0; x < COLS - 1; x += 1 {
        for y := 0; y < ROWS - 1; y += 1 {
            // Get heights from the terrain array
            z_top_left := state.terrain[x][y]
            z_top_right := state.terrain[x + 1][y]
            z_bottom_left := state.terrain[x][y + 1]
            z_bottom_right := state.terrain[x + 1][y + 1]
            
            // Define corners of the current cell
            top_left := rl.Vector3{f32(x * CELL_SIZE), f32(y * CELL_SIZE), z_top_left}
            top_right := rl.Vector3{f32((x + 1) * CELL_SIZE), f32(y * CELL_SIZE), z_top_right}
            bottom_left := rl.Vector3{f32(x * CELL_SIZE), f32((y + 1) * CELL_SIZE), z_bottom_left}
            bottom_right := rl.Vector3{f32((x + 1) * CELL_SIZE), f32((y + 1) * CELL_SIZE), z_bottom_right}
            
            // Draw horizontal and vertical lines
            rl.DrawLine3D(top_left, top_right, rl.RAYWHITE)    // Top edge
            rl.DrawLine3D(top_left, bottom_left, rl.RAYWHITE)  // Left edge
            
            // Draw diagonal lines
            rl.DrawLine3D(top_right, bottom_left, rl.RAYWHITE)  // Diagonal (top-right to bottom-left)
            rl.DrawLine3D(top_left, bottom_right, rl.RAYWHITE)  // Diagonal (top-left to bottom-right)
        }
    }
    
    rl.DrawFPS(10, 10)
}