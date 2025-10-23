package main

import rl "vendor:raylib"
import "core:fmt"
import "core:mem"

// Constants
WINDOW_WIDTH :: 1920
WINDOW_HEIGHT :: 1080
FPS :: 60
TITLE :: "Steering Behaviour"
PLAYER_MODEL_PATH :: "assets/player.glb"

// State Type Enum
StateType :: enum {
    Pause,
    Idle,
    Run,
}

// Player Animation Type Enum
PlayerAnimationType :: enum {
    Idle,
    Run,
    Pause,
}

// Camera Singleton
Camera :: struct {
    is_init: bool,
    camera: rl.Camera3D,
}

camera_instance: ^Camera

init_camera :: proc() -> ^Camera {
    if camera_instance == nil {
        camera_instance = new(Camera)
        camera_instance.is_init = false
    }
    return camera_instance
}

camera_init :: proc(cam: ^Camera, position: rl.Vector3) {
    cam.camera = rl.Camera3D{
        position = position,
        target = {0, 0, 0},
        up = {0, 1, 0},
        fovy = 45.0,
        projection = .PERSPECTIVE,
    }
    cam.is_init = true
}

camera_look_at :: proc(cam: ^Camera, target: rl.Vector3) {
    cam.camera.target = target
}

// State Machine for Game
GameStateMachine :: struct {
    current_state: ^GameState,
}

// State Machine for Player
PlayerStateMachine :: struct {
    current_state: ^PlayerState,
}

game_state_machine_change_state :: proc(sm: ^GameStateMachine, new_state: ^GameState) {
    if sm.current_state != nil && sm.current_state.type != new_state.type {
        sm.current_state.procs.on_exit(sm.current_state)
    }
    sm.current_state = new_state
    sm.current_state.procs.on_enter(sm.current_state)
}

player_state_machine_change_state :: proc(sm: ^PlayerStateMachine, new_state: ^PlayerState) {
    if sm.current_state != nil && sm.current_state.type != new_state.type {
        sm.current_state.procs.on_exit(sm.current_state)
    }
    sm.current_state = new_state
    sm.current_state.procs.on_enter(sm.current_state)
}

// Player
Player :: struct {
    is_init: bool,
    position: rl.Vector3,
    model: rl.Model,
    model_animations: []rl.ModelAnimation,
    current_animation: rl.ModelAnimation,
    current_anim_frame: u32,
    total_animations: i32,
    state_machine: ^PlayerStateMachine,
}

player_init :: proc(p: ^Player, position: rl.Vector3) {
    p.position = position
    p.model = rl.LoadModel(PLAYER_MODEL_PATH)
    p.model.transform = rl.MatrixRotateXYZ({rl.DEG2RAD * 90, 0, 0})
    p.is_init = true

    anim_count: i32
    anim_ptr := rl.LoadModelAnimations(PLAYER_MODEL_PATH, &anim_count)
    p.model_animations = mem.slice_ptr(anim_ptr, int(anim_count))
    p.total_animations = anim_count
    p.current_anim_frame = 0

    p.state_machine = new(PlayerStateMachine)
    p.state_machine.current_state = player_state_pause_new(p)
}

player_render :: proc(p: ^Player) {
    if p.state_machine.current_state != nil {
        p.state_machine.current_state.procs.render(p.state_machine.current_state)
    }
}

player_update :: proc(p: ^Player, delta_time: f32) {
    if p.state_machine.current_state != nil {
        p.state_machine.current_state.procs.on_execute(p.state_machine.current_state, delta_time)
    }
}

player_set_animation :: proc(p: ^Player, anim_type: PlayerAnimationType) {
    p.current_animation = p.model_animations[cast(i32)anim_type]
    p.current_anim_frame = 0
}

player_update_animation :: proc(p: ^Player) {
    p.current_anim_frame = (p.current_anim_frame + 1) % cast(u32)p.current_animation.frameCount
    rl.UpdateModelAnimation(p.model, p.current_animation, cast(i32)p.current_anim_frame)
}

player_draw_model :: proc(p: ^Player) {
    rl.DrawModel(p.model, p.position, 0.01, rl.WHITE)
}

// Game State Interface
GameStateProcs :: struct {
    on_enter: proc(state: ^GameState),
    on_execute: proc(state: ^GameState, delta_time: f32),
    on_exit: proc(state: ^GameState),
    render: proc(state: ^GameState),
}

GameState :: struct {
    type: StateType,
    procs: GameStateProcs,
    scene: ^Scene,
    player: ^Player,
    camera: ^Camera,
    render_text: cstring,
}

// Player State Interface
PlayerStateProcs :: struct {
    on_enter: proc(state: ^PlayerState),
    on_execute: proc(state: ^PlayerState, delta_time: f32),
    on_exit: proc(state: ^PlayerState),
    render: proc(state: ^PlayerState),
}

PlayerState :: struct {
    type: StateType,
    procs: PlayerStateProcs,
    player: ^Player,
}

// Scene
Scene :: struct {
    is_init: bool,
    player: ^Player,
    state_machine: ^GameStateMachine,
}

scene_init :: proc(s: ^Scene) {
    rl.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, TITLE)
    rl.SetTargetFPS(FPS)

    cam := init_camera()
    camera_init(cam, {0, 3, 0})

    s.player = new(Player)
    player_init(s.player, {0, 0, -6})
    camera_look_at(cam, s.player.position)

    s.state_machine = new(GameStateMachine)
    s.state_machine.current_state = game_state_pause_new(s)
    s.is_init = true
}

scene_start :: proc(s: ^Scene) {
    if !s.is_init {
        fmt.eprintln("[X] Scene is not initialized")
        return
    }

    for !rl.WindowShouldClose() {
        s.state_machine.current_state.procs.on_execute(s.state_machine.current_state, rl.GetFrameTime())
        rl.BeginDrawing()
        rl.ClearBackground(rl.BLACK)
        s.state_machine.current_state.procs.render(s.state_machine.current_state)
        rl.EndDrawing()
    }
    rl.CloseWindow()
}

// Game State Implementations
game_state_render :: proc(state: ^GameState) {
    rl.BeginMode3D(state.camera.camera)
    player_render(state.player) // Fixed: Call player_render procedure
    rl.DrawGrid(30, 2.0)
    rl.EndMode3D()
    rl.DrawText(state.render_text, 10, 20, 20, rl.RED)
}

game_state_pause_new :: proc(scene: ^Scene) -> ^GameState {
    state := new(GameState)
    state.type = .Pause
    state.scene = scene
    state.player = scene.player
    state.camera = init_camera()
    state.render_text = "Pause State"
    state.procs = GameStateProcs{
        on_enter = proc(s: ^GameState) {
            player_state_machine_change_state(s.player.state_machine, player_state_pause_new(s.player))
        },
        on_execute = proc(s: ^GameState, delta_time: f32) {
            player_update(s.player, delta_time) // Fixed: Call player_update procedure
            if rl.IsKeyPressed(.ENTER) {
                game_state_machine_change_state(s.scene.state_machine, game_state_idle_new(s.scene))
            }
        },
        on_exit = proc(s: ^GameState) {},
        render = game_state_render,
    }
    return state
}

game_state_idle_new :: proc(scene: ^Scene) -> ^GameState {
    state := new(GameState)
    state.type = .Idle
    state.scene = scene
    state.player = scene.player
    state.camera = init_camera()
    state.render_text = "Idle State"
    state.procs = GameStateProcs{
        on_enter = proc(s: ^GameState) {
            player_state_machine_change_state(s.player.state_machine, player_state_idle_new(s.player))
        },
        on_execute = proc(s: ^GameState, delta_time: f32) {
            player_update(s.player, delta_time) // Fixed: Call player_update procedure
            if rl.IsKeyPressed(.ENTER) {
                game_state_machine_change_state(s.scene.state_machine, game_state_run_new(s.scene))
            }
        },
        on_exit = proc(s: ^GameState) {},
        render = game_state_render,
    }
    return state
}

game_state_run_new :: proc(scene: ^Scene) -> ^GameState {
    state := new(GameState)
    state.type = .Run
    state.scene = scene
    state.player = scene.player
    state.camera = init_camera()
    state.render_text = "Run State"
    state.procs = GameStateProcs{
        on_enter = proc(s: ^GameState) {
            player_state_machine_change_state(s.player.state_machine, player_state_run_new(s.player))
        },
        on_execute = proc(s: ^GameState, delta_time: f32) {
            player_update(s.player, delta_time) // Fixed: Call player_update procedure
            if rl.IsKeyPressed(.ENTER) {
                game_state_machine_change_state(s.scene.state_machine, game_state_pause_new(s.scene))
            }
        },
        on_exit = proc(s: ^GameState) {},
        render = game_state_render,
    }
    return state
}

// Player State Implementations
player_state_pause_new :: proc(player: ^Player) -> ^PlayerState {
    state := new(PlayerState)
    state.type = .Pause
    state.player = player
    state.procs = PlayerStateProcs{
        on_enter = proc(s: ^PlayerState) {
            player_set_animation(s.player, .Pause)
        },
        on_execute = proc(s: ^PlayerState, delta_time: f32) {
            player_update_animation(s.player)
        },
        on_exit = proc(s: ^PlayerState) {},
        render = proc(s: ^PlayerState) {
            player_draw_model(s.player)
        },
    }
    return state
}

player_state_idle_new :: proc(player: ^Player) -> ^PlayerState {
    state := new(PlayerState)
    state.type = .Idle
    state.player = player
    state.procs = PlayerStateProcs{
        on_enter = proc(s: ^PlayerState) {
            player_set_animation(s.player, .Idle)
        },
        on_execute = proc(s: ^PlayerState, delta_time: f32) {
            player_update_animation(s.player)
        },
        on_exit = proc(s: ^PlayerState) {},
        render = proc(s: ^PlayerState) {
            player_draw_model(s.player)
        },
    }
    return state
}

player_state_run_new :: proc(player: ^Player) -> ^PlayerState {
    state := new(PlayerState)
    state.type = .Run
    state.player = player
    state.procs = PlayerStateProcs{
        on_enter = proc(s: ^PlayerState) {
            player_set_animation(s.player, .Run)
        },
        on_execute = proc(s: ^PlayerState, delta_time: f32) {
            player_update_animation(s.player)
        },
        on_exit = proc(s: ^PlayerState) {},
        render = proc(s: ^PlayerState) {
            player_draw_model(s.player)
        },
    }
    return state
}

main :: proc() {
    scene: Scene
    scene_init(&scene)
    scene_start(&scene)
    // Cleanup
    if scene.player != nil {
        rl.UnloadModel(scene.player.model)
        for anim in scene.player.model_animations {
            rl.UnloadModelAnimation(anim)
        }
        if scene.player.state_machine != nil {
            if scene.player.state_machine.current_state != nil {
                free(scene.player.state_machine.current_state)
            }
            free(scene.player.state_machine)
        }
        free(scene.player)
    }
    if scene.state_machine != nil {
        if scene.state_machine.current_state != nil {
            free(scene.state_machine.current_state)
        }
        free(scene.state_machine)
    }
    if camera_instance != nil {
        free(camera_instance)
    }
}