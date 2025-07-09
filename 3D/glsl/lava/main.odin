package main

import "core:fmt"
import "core:math"
import rl "vendor:raylib"

VERTEX_SHADER :: #load(`assets/lava.vs`)
FRAGMENT_SHADER :: #load(`assets/lava.fs`)

State :: struct {
    screenWidth:  i32,
    screenHeight: i32,
    camera:       rl.Camera3D,
    uiManager:    UI,
    lavaObject:   Lava,
}

UI :: struct {
    speed:      f32,
    zoom:       f32,
    distortion: f32,
    crustiness: f32,
    pulseSpeed: f32,
    hotColor:   rl.Color,
    midColor:   rl.Color,
    crustColor: rl.Color,
}

Lava :: struct {
    shader:         rl.Shader,
    model:          rl.Model,
    runningTime:    f32,
    isLoaded:       bool,
    // Shader locations
    timeLoc:        i32,
    speedLoc:       i32,
    zoomLoc:        i32,
    distortionLoc:  i32,
    crustinessLoc:  i32,
    pulseSpeedLoc:  i32,
    hotColorLoc:    i32,
    midColorLoc:    i32,
    crustColorLoc:  i32,
}

ui_init :: proc(ui: ^UI) {
    ui.speed = 1.0
    ui.zoom = 3.0
    ui.distortion = 1.0
    ui.crustiness = 0.6
    ui.pulseSpeed = 2.0
    ui.hotColor = {255, 255, 150, 255}
    ui.midColor = {255, 80, 0, 255}
    ui.crustColor = {30, 0, 0, 255}
}

ui_draw_controls :: proc(ui: ^UI) {    
    // Draw control panel background
    rl.DrawRectangle(10, 50, 300, 400, rl.Color{40, 40, 40, 200})
    rl.DrawText("Lava Controls", 20, 60, 20, rl.WHITE)
    
    // Draw current values as text
    y_offset := i32(90)
    
    rl.DrawText(fmt.ctprintf("Speed: %.2f", ui.speed), 20, y_offset, 16, rl.WHITE)
    y_offset += 25
    
    rl.DrawText(fmt.ctprintf("Zoom: %.2f", ui.zoom), 20, y_offset, 16, rl.WHITE)
    y_offset += 25
    
    rl.DrawText(fmt.ctprintf("Distortion: %.2f", ui.distortion), 20, y_offset, 16, rl.WHITE)
    y_offset += 25
    
    rl.DrawText(fmt.ctprintf("Crustiness: %.2f", ui.crustiness), 20, y_offset, 16, rl.WHITE)
    y_offset += 25
    
    rl.DrawText(fmt.ctprintf("Pulse Speed: %.2f", ui.pulseSpeed), 20, y_offset, 16, rl.WHITE)
    y_offset += 40
    
    // Simple keyboard controls
    rl.DrawText("Controls:", 20, y_offset, 16, rl.YELLOW)
    y_offset += 25
    rl.DrawText("Q/A - Speed", 20, y_offset, 14, rl.WHITE)
    y_offset += 20
    rl.DrawText("W/S - Zoom", 20, y_offset, 14, rl.WHITE)
    y_offset += 20
    rl.DrawText("E/D - Distortion", 20, y_offset, 14, rl.WHITE)
    y_offset += 20
    rl.DrawText("R/F - Crustiness", 20, y_offset, 14, rl.WHITE)
    y_offset += 20
    rl.DrawText("T/G - Pulse Speed", 20, y_offset, 14, rl.WHITE)
}

ui_handle_input :: proc(ui: ^UI) {
    dt := rl.GetFrameTime()
    
    // Speed controls
    if rl.IsKeyDown(.Q) do ui.speed = max(0.0, ui.speed - 2.0 * dt)
    if rl.IsKeyDown(.A) do ui.speed = min(10.0, ui.speed + 2.0 * dt)
    
    // Zoom controls
    if rl.IsKeyDown(.W) do ui.zoom = max(0.1, ui.zoom - 2.0 * dt)
    if rl.IsKeyDown(.S) do ui.zoom = min(10.0, ui.zoom + 2.0 * dt)
    
    // Distortion controls
    if rl.IsKeyDown(.E) do ui.distortion = max(0.0, ui.distortion - 2.0 * dt)
    if rl.IsKeyDown(.D) do ui.distortion = min(5.0, ui.distortion + 2.0 * dt)
    
    // Crustiness controls
    if rl.IsKeyDown(.R) do ui.crustiness = max(0.1, ui.crustiness - 1.0 * dt)
    if rl.IsKeyDown(.F) do ui.crustiness = min(1.0, ui.crustiness + 1.0 * dt)
    
    // Pulse speed controls
    if rl.IsKeyDown(.T) do ui.pulseSpeed = max(0.0, ui.pulseSpeed - 2.0 * dt)
    if rl.IsKeyDown(.G) do ui.pulseSpeed = min(10.0, ui.pulseSpeed + 2.0 * dt)
}

// Lava procedures
lava_init :: proc(lava: ^Lava) {
    lava.runningTime = 0.0
    lava.isLoaded = false
}

lava_load :: proc(lava: ^Lava) {
    // Load .g from memory
    lava.shader = rl.LoadShaderFromMemory(cstring(VERTEX_SHADER), cstring(FRAGMENT_SHADER))
    // Get shader locations
    lava.timeLoc = rl.GetShaderLocation(lava.shader, "time")
    lava.speedLoc = rl.GetShaderLocation(lava.shader, "speed")
    lava.zoomLoc = rl.GetShaderLocation(lava.shader, "zoom")
    lava.distortionLoc = rl.GetShaderLocation(lava.shader, "distortion")
    lava.crustinessLoc = rl.GetShaderLocation(lava.shader, "crustiness")
    lava.pulseSpeedLoc = rl.GetShaderLocation(lava.shader, "pulseSpeed")
    lava.hotColorLoc = rl.GetShaderLocation(lava.shader, "hotColor")
    lava.midColorLoc = rl.GetShaderLocation(lava.shader, "midColor")
    lava.crustColorLoc = rl.GetShaderLocation(lava.shader, "crustColor")
    
    fmt.printf("Shader Uniform Locations\n")
    fmt.printf("time: %d\n", lava.timeLoc)
    fmt.printf("speed: %d\n", lava.speedLoc)
    fmt.printf("zoom: %d\n", lava.zoomLoc)
    
    // Create plane mesh and model
    plane := rl.GenMeshPlane(10.0, 10.0, 50, 50)
    lava.model = rl.LoadModelFromMesh(plane)
    lava.model.materials[0].shader = lava.shader
    lava.isLoaded = true
}

lava_unload :: proc(lava: ^Lava) {
    if lava.isLoaded {
        rl.UnloadShader(lava.shader)
        rl.UnloadModel(lava.model)
        lava.isLoaded = false
    }
}

lava_update :: proc(lava: ^Lava, ui: ^UI) {
    if !lava.isLoaded do return
    
    lava.runningTime += rl.GetFrameTime()
    
    // Convert colors to normalized vec3
    hotColor := rl.Vector3{f32(ui.hotColor.r) / 255.0, f32(ui.hotColor.g) / 255.0, f32(ui.hotColor.b) / 255.0}
    midColor := rl.Vector3{f32(ui.midColor.r) / 255.0, f32(ui.midColor.g) / 255.0, f32(ui.midColor.b) / 255.0}
    crustColor := rl.Vector3{f32(ui.crustColor.r) / 255.0, f32(ui.crustColor.g) / 255.0, f32(ui.crustColor.b) / 255.0}
    // Update shader uniforms
    rl.SetShaderValue(lava.shader, lava.timeLoc, &lava.runningTime, .FLOAT)
    rl.SetShaderValue(lava.shader, lava.speedLoc, &ui.speed, .FLOAT)
    rl.SetShaderValue(lava.shader, lava.zoomLoc, &ui.zoom, .FLOAT)
    rl.SetShaderValue(lava.shader, lava.distortionLoc, &ui.distortion, .FLOAT)
    rl.SetShaderValue(lava.shader, lava.crustinessLoc, &ui.crustiness, .FLOAT)
    rl.SetShaderValue(lava.shader, lava.pulseSpeedLoc, &ui.pulseSpeed, .FLOAT)
    rl.SetShaderValue(lava.shader, lava.hotColorLoc, &hotColor, .VEC3)
    rl.SetShaderValue(lava.shader, lava.midColorLoc, &midColor, .VEC3)
    rl.SetShaderValue(lava.shader, lava.crustColorLoc, &crustColor, .VEC3)
}

lava_draw :: proc(lava: ^Lava) {
    if lava.isLoaded {
        rl.DrawModel(lava.model, {0.0, 0.0, 0.0}, 1.0, rl.WHITE)
    }
}

// State procedures
init :: proc(s: ^State, width, height: i32, title: cstring) {
    s.screenWidth = width
    s.screenHeight = height
    
    rl.SetConfigFlags({.WINDOW_RESIZABLE})
    rl.InitWindow(width, height, title)
    rl.SetTargetFPS(60)
    
    ui_init(&s.uiManager)
    lava_init(&s.lavaObject)
    lava_load(&s.lavaObject)
    
    // Setup camera
    s.camera = rl.Camera3D{
        position = {5.0, 5.0, 5.0},
        target = {0.0, 0.5, 0.0},
        up = {0.0, 1.0, 0.0},
        fovy = 45.0,
        projection = .PERSPECTIVE,
    }
}

shutdown :: proc(s: ^State) {
    lava_unload(&s.lavaObject)
    rl.CloseWindow()
}

update :: proc(s: ^State) {
    rl.UpdateCamera(&s.camera, .ORBITAL)
    ui_handle_input(&s.uiManager)
    lava_update(&s.lavaObject, &s.uiManager)
}

draw :: proc(s: ^State) {
    rl.BeginDrawing()
    defer rl.EndDrawing()
    
    rl.ClearBackground(rl.BLACK)
    
    // 3D rendering
    rl.BeginMode3D(s.camera)
    {
        lava_draw(&s.lavaObject)
        rl.DrawGrid(20, 1.0)
    }
    rl.EndMode3D()
    
    // UI rendering
    rl.DrawFPS(10, 10)
    ui_draw_controls(&s.uiManager)
}

run :: proc(s: ^State) {
    for !rl.WindowShouldClose() {
        update(s)
        draw(s)
    }
}

main :: proc() {
    s: State
    init(&s, 1280, 720, "Animated Lava")
    defer shutdown(&s)
    
    run(&s)
}