package main

import "core:fmt"
import "core:math"
import "core:math/rand"
import "core:strings"
import "core:path/filepath"
import "core:os"
import rl "vendor:raylib"

// based on: The ultimate introduction to Raylib - https://www.youtube.com/watch?v=UoAsDlUwjy0

// Constants
WINDOW_WIDTH :: 1200
WINDOW_HEIGHT :: 900
BG_COLOR :: rl.BLACK
PLAYER_SPEED :: 7.0
LASER_SPEED :: 9.0
METEOR_SPEED_MIN :: 3.0
METEOR_SPEED_MAX :: 4.0
METEOR_TIMER_DURATION :: 0.4
FONT_SIZE :: 60

Timer :: struct {
    duration: f64,
    start_time: f64,
    active: bool,
    repeat: bool,
}

timer_init :: proc(duration: f64, repeat: bool = false, autostart: bool = false) -> Timer {
    timer := Timer{
        duration = duration,
        start_time = 0,
        active = false,
        repeat = repeat,
    }
    
    if autostart {
        timer_activate(&timer)
    }
    
    return timer
}

timer_activate :: proc(timer: ^Timer) {
    timer.active = true
    timer.start_time = rl.GetTime()
}

timer_deactivate :: proc(timer: ^Timer) {
    timer.active = false
    timer.start_time = 0
    if timer.repeat {
        timer_activate(timer)
    }
}

timer_update :: proc(meteor: ^Meteor) {
    if meteor.death_timer.active {
        if rl.GetTime() - meteor.death_timer.start_time >= meteor.death_timer.duration {
            meteor.discard = true
            timer_deactivate(&meteor.death_timer)
        }
    }
}

Model_Base :: struct {
    model: rl.Model,
    pos: rl.Vector3,
    speed: f32,
    direction: rl.Vector3,
    discard: bool,
}

model_init :: proc(model: rl.Model, pos: rl.Vector3, speed: f32, direction: rl.Vector3 = {0, 0, 0}) -> Model_Base {
    return Model_Base{
        model = model,
        pos = pos,
        speed = speed,
        direction = direction,
        discard = false,
    }
}

model_move :: proc(model: ^Model_Base, dt: f32) {
    model.pos.x += model.direction.x * model.speed * dt
    model.pos.y += model.direction.y * model.speed * dt
    model.pos.z += model.direction.z * model.speed * dt
}

model_update :: proc(model: ^Model_Base, dt: f32) {
    model_move(model, dt)
}

model_draw :: proc(model: ^Model_Base) {
    rl.DrawModel(model.model, model.pos, 1.0, rl.WHITE)
}

Floor :: struct {
    using base: Model_Base,
}

floor_init :: proc(texture: rl.Texture2D) -> Floor {
    mesh := rl.GenMeshCube(32, 1, 32)
    model := rl.LoadModelFromMesh(mesh)
    rl.SetMaterialTexture(&model.materials[0], rl.MaterialMapIndex.ALBEDO, texture)
    
    return Floor{
        base = model_init(model, {6.5, -2, -8}, 0),
    }
}

Player :: struct {
    using base: Model_Base,
    angle: f32,
}

player_init :: proc(model: rl.Model) -> Player {
    return Player{
        base = model_init(model, {0, 0, 0}, PLAYER_SPEED),
        angle = 0,
    }
}

player_input :: proc(game: ^Game) {
    game.player.direction.x = rl.IsKeyDown(.RIGHT) ? 1 : (rl.IsKeyDown(.LEFT) ? -1 : 0)
    if rl.IsKeyPressed(.SPACE) {
        pos := game.player.pos
        pos.z -= 1
        shoot_laser(game, pos)
    }
}

player_update :: proc(game: ^Game, dt: f32) {
    player_input(game)
    model_update(&game.player.base, dt)
    game.player.angle -= game.player.direction.x * 10 * dt
    game.player.pos.y += math.sin_f32(f32(rl.GetTime()) * 5) * dt * 0.1
    
    // constraints
    game.player.pos.x = math.max(-6, math.min(game.player.pos.x, 7))
    game.player.angle = math.max(-15, math.min(game.player.angle, 15))
}

player_draw :: proc(player: ^Player) {
    rl.DrawModelEx(player.model, player.pos, {0, 0, 1}, player.angle, {1, 1, 1}, rl.WHITE)
}

Laser :: struct {
    using base: Model_Base,
}

laser_init :: proc(model: rl.Model, pos: rl.Vector3, texture: rl.Texture2D) -> Laser {
    laser := Laser{
        base = model_init(model, pos, LASER_SPEED, {0, 0, -1}),
    }
    rl.SetMaterialTexture(&laser.model.materials[0], rl.MaterialMapIndex.ALBEDO, texture)
    return laser
}

Meteor :: struct {
    using base: Model_Base,
    radius: f32,
    rotation: rl.Vector3,
    rotation_speed: rl.Vector3,
    hit: bool,
    death_timer: Timer,
    shader: rl.Shader,
    flash_loc: i32,
    flash_amount: [2]f32,
}

meteor_activate_discard :: proc(meteor: ^Meteor) {
    meteor.discard = true
}

meteor_init :: proc(texture: rl.Texture2D) -> Meteor {
    // setup
    pos := rl.Vector3{rand.float32_range(-6, 7), 0, -20}
    radius := rand.float32_range(0.6, 1.5)
    mesh := rl.GenMeshSphere(radius, 8, 8)
    model := rl.LoadModelFromMesh(mesh)
    rl.SetMaterialTexture(&model.materials[0], rl.MaterialMapIndex.ALBEDO, texture)
    
    meteor := Meteor{
        base = model_init(model, pos, rand.float32_range(METEOR_SPEED_MIN, METEOR_SPEED_MAX), {0, 0, rand.float32_range(0.75, 1.25)}),
        radius = radius,
        hit = false,
    }
    
    // rotation 
    meteor.rotation = {rand.float32_range(-5, 5), rand.float32_range(-5, 5), rand.float32_range(-5, 5)}
    meteor.rotation_speed = {rand.float32_range(-1, 1), rand.float32_range(-1, 1), rand.float32_range(-1, 1)}
    meteor.death_timer = timer_init(0.25, false, false)
    
    // shader
    meteor.shader = rl.LoadShader(nil, "assets/shaders/flash.fs")
    model.materials[0].shader = meteor.shader
    meteor.flash_loc = rl.GetShaderLocation(meteor.shader, "flash")
    meteor.flash_amount = {1, 0}
    
    return meteor
}

meteor_flash :: proc(meteor: ^Meteor) {
    rl.SetShaderValue(meteor.shader, meteor.flash_loc, &meteor.flash_amount, .VEC2)
}

meteor_update :: proc(meteor: ^Meteor, dt: f32) {
    timer_update(meteor)
    if !meteor.hit {
        model_update(&meteor.base, dt)
        meteor.rotation.x += meteor.rotation_speed.x * dt
        meteor.rotation.y += meteor.rotation_speed.y * dt
        meteor.rotation.z += meteor.rotation_speed.z * dt
        meteor.model.transform = rl.MatrixRotateXYZ(meteor.rotation)
    }
}

Game :: struct {
    camera: rl.Camera3D,
    floor: Floor,
    player: Player,
    lasers: [dynamic]Laser,
    meteors: [dynamic]Meteor,
    timer: Timer,
    models: map[string]rl.Model,
    audio: map[string]rl.Sound,
    music: rl.Music,
    textures: [dynamic]rl.Texture2D,
    dark_texture: rl.Texture2D,
    light_texture: rl.Texture2D,
    font: rl.Font,
}

game_create_meteor :: proc(game: ^Game) {
    texture_idx := int(rand.float32_range(0, f32(len(game.textures))))
    meteor := meteor_init(game.textures[texture_idx])
    append(&game.meteors, meteor)
}

shoot_laser :: proc(game: ^Game, pos: rl.Vector3) {
    laser := laser_init(game.models["laser"], pos, game.light_texture)
    append(&game.lasers, laser)
    rl.PlaySound(game.audio["laser"])
}

game_import_assets :: proc(game: ^Game) {
    // Initialize maps
    game.models = make(map[string]rl.Model)
    game.audio = make(map[string]rl.Sound)
    
    // Load models
    game.models["player"] = rl.LoadModel("assets/models/ship.glb")
    game.models["laser"] = rl.LoadModel("assets/models/laser.glb")
    
    // Load audio
    game.audio["laser"] = rl.LoadSound("assets/audio/laser.wav")
    game.audio["explosion"] = rl.LoadSound("assets/audio/explosion.wav")
    game.music = rl.LoadMusicStream("assets/audio/music.wav")

    // Load textures
    texture_colors := [?]string{"red", "green", "orange", "purple"}
    for color in texture_colors {
        texture := rl.LoadTexture(fmt.ctprint(filepath.join({"assets/textures", strings.concatenate({color, ".png"})})))
        append(&game.textures, texture)
    }
    
    game.dark_texture = rl.LoadTexture("assets/textures/dark.png")
    game.light_texture = rl.LoadTexture("assets/textures/light.png")
    
    // Load font
    game.font = rl.LoadFontEx("assets/font/Stormfaze.otf", FONT_SIZE, nil, 0)
}

game_init :: proc() -> Game {
    rl.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "Space shooter")
    rl.InitAudioDevice()
    game: Game
    game_import_assets(&game)
    
    // camera
    game.camera = rl.Camera3D{
        position = {-4.0, 8.0, 6.0},
        target = {0.0, 0.0, -1.0},
        up = {0.0, 1.0, 0.0},
        fovy = 45.0,
        projection = .PERSPECTIVE,
    }
    // setup
    game.floor = floor_init(game.dark_texture)
    game.player = player_init(game.models["player"])    
    game.timer = timer_init(METEOR_TIMER_DURATION, true, true)
    rl.PlayMusicStream(game.music)
    
    return game
}

game_check_discard :: proc(game: ^Game) {
    // Filter lasers
    i := 0
    for i < len(game.lasers) {
        if game.lasers[i].discard {
            ordered_remove(&game.lasers, i)
        } else {
            i += 1
        }
    }
    // Filter meteors
    i = 0
    for i < len(game.meteors) {
        if game.meteors[i].discard {
            ordered_remove(&game.meteors, i)
        } else {
            i += 1
        }
    }
}

game_check_collisions :: proc(game: ^Game) {
    // player -> meteor
    for meteor in &game.meteors {
        if rl.CheckCollisionSpheres(game.player.pos, 0.8, meteor.pos, meteor.radius) {
            rl.CloseWindow()
        }
    }
    // laser -> meteor
    for &laser, l_idx in &game.lasers {
        for &meteor, m_idx in &game.meteors {
            laser_bbox := rl.GetMeshBoundingBox(laser.model.meshes[0])
            col_bbox := rl.BoundingBox{
                min = laser_bbox.min + laser.pos,
                max = laser_bbox.max + laser.pos,
            }
            
            if rl.CheckCollisionBoxSphere(col_bbox, meteor.pos, meteor.radius) {
                meteor.hit = true
                laser.discard = true
                timer_activate(&meteor.death_timer)
                meteor_flash(&meteor)
                rl.PlaySound(game.audio["explosion"])
            }
        }
    }
}

game_update :: proc(game: ^Game) {
    dt := rl.GetFrameTime()
    if game.timer.active {
        if rl.GetTime() - game.timer.start_time >= game.timer.duration {
            game_create_meteor(game)
            timer_deactivate(&game.timer) // This will activate it again since repeat is true
        }
    }
    game_check_collisions(game)
    game_check_discard(game)
    player_update(game, dt)
    for i in 0..<len(game.lasers) {
        model_update(&game.lasers[i].base, dt)
    }
    
    for i in 0..<len(game.meteors) {
        timer_update(&game.meteors[i])
        meteor_update(&game.meteors[i], dt)
    }
    
    rl.UpdateMusicStream(game.music)
}

game_draw_shadows :: proc(game: ^Game) {
    player_radius := 0.5 + game.player.pos.y
    rl.DrawCylinder({game.player.pos.x, -1.5, game.player.pos.z}, player_radius, player_radius, 0.1, 20, {0, 0, 0, 50})
    
    for meteor in game.meteors {
        rl.DrawCylinder({meteor.pos.x, -1.5, meteor.pos.z}, meteor.radius * 0.8, meteor.radius * 0.8, 0.1, 20, {0, 0, 0, 50})
    }
}

game_draw_score :: proc(game: ^Game) {
    score := fmt.ctprintf("%.2f", rl.GetTime())
    rl.DrawTextEx(game.font, score, {WINDOW_WIDTH - 150, WINDOW_HEIGHT - 100}, FONT_SIZE, 2, rl.WHITE)
}

game_draw :: proc(game: ^Game) {
    rl.ClearBackground(BG_COLOR)
    rl.BeginDrawing()
    rl.BeginMode3D(game.camera)
    
    model_draw(&game.floor.base)
    game_draw_shadows(game)
    player_draw(&game.player)
    
    for &laser in game.lasers {
        model_draw(&laser.base)
    }
    
    for &meteor in game.meteors {
        model_draw(&meteor.base)
    }
    
    rl.EndMode3D()
    game_draw_score(game)
    rl.EndDrawing()
}

game_run :: proc(game: ^Game) {
    for !rl.WindowShouldClose() {
        game_update(game)
        game_draw(game)
    }
    
    rl.UnloadMusicStream(game.music)
    rl.CloseAudioDevice()
    rl.CloseWindow()
}

game_cleanup :: proc(game: ^Game) {
    // Clean up maps
    delete(game.models)
    delete(game.audio)
    
    // Clean up dynamic arrays
    delete(game.lasers)
    delete(game.meteors)
    delete(game.textures)
}

main :: proc() {
    game := game_init()
    context.user_ptr = &game
    defer game_cleanup(&game)
    
    game_run(&game)
}