package main

import "core:fmt"
import "core:strings"
import "core:math"
import "core:os"
import "core:strconv"
import rl "vendor:raylib"

Boundaries :: struct {
    left: f32,
    right: f32,
    top: f32,
    bottom: f32,
}

AnimType :: enum {
    REPEAT,
    ONESHOT,
}

AnimState :: enum {
    IDLE,
    WALK,
    JUMP,
    CROUCH,
    ATTACK,
}

Frame :: enum {
    IDLE,
    IDLING,
    WALKING,
    WALKINGF,
    PUNCHING1,
    PUNCHING2,
    PUNCHING3,
    JUMPING,
    JUMPINGF,
    CROUCHING,
    ANIMSTATESFINAL, // Used as count
}

PlayerType :: enum {
    PLAYER1,
    PLAYER2,
}

Animation :: struct {
    first:         int,
    last:          int,
    cur:           int,
    duration_left: f32,
    speed:         f32,
    step:          int,
    type:          AnimType,
    frame_width:   int,
    frame_height:  int,
    px:            int,
    py:            int,
}

Player :: struct {
    type:               int,
    pos:                rl.Vector2,
    dir:                rl.Vector2,
    velocity:           rl.Vector2,
    grounded:           bool,
    texture:            rl.Texture2D,
    textures:           []rl.Texture2D,
    animation:          AnimState,
    animations:         []Animation,
    frame:              Frame,
    rects:              []rl.Rectangle,
}

set :: proc(p: ^Player, state: AnimState, frame: Frame) {
    p.animation = state
    p.frame = frame
}

move :: proc(p: ^Player, direction: int, state: AnimState, frame: Frame) {
    p.dir.x = f32(direction)
    set(p, state, frame)
}

jump :: proc(p: ^Player, direction: int, state: AnimState, frame: Frame) {
    switch direction {
    case 0:  // Jump up
        p.dir.x = 0
        p.velocity.x = 0
    case 1:  // Jump right
        p.dir.x = 1
        p.velocity.x = 200
    case -1:  // Jump left
        p.dir.x = -1
        p.velocity.x = -200
    }
    if p.grounded {
        set(p, state, frame)
        p.velocity.y = -300  // Upward velocity
        p.grounded = false
    }
}

attack :: proc(p: ^Player, state: AnimState, frame: Frame) {
    set(p, state, frame)
}

input_idle :: proc(p: []Player, typ: PlayerType) {
    player := &p[PlayerType.PLAYER1]
    if typ == .PLAYER2 {
        player = &p[PlayerType.PLAYER2]
    }
    switch {
        case rl.IsKeyDown(.A) || rl.IsKeyDown(.RIGHT):
            move(player, 1, .WALK, .WALKING)
        case rl.IsKeyDown(.D) || rl.IsKeyDown(.LEFT):
            move(player, -1, .WALK, .WALKINGF)
        // case rl.IsKeyDown(.S) || rl.IsKeyDown(.DOWN):
        //     crouch(player, .CROUCH, .CROUCHING)
        case rl.IsKeyDown(.W) || rl.IsKeyDown(.UP):
            jump(player, 0, .JUMP, .JUMPING)
        case rl.IsKeyDown(.E) || rl.IsKeyDown(.KP_1):
            attack(player, .ATTACK, .PUNCHING1)
        case rl.IsKeyDown(.R) || rl.IsKeyDown(.KP_2):
            attack(player, .ATTACK, .PUNCHING2)
        case rl.IsKeyDown(.T) || rl.IsKeyDown(.KP_3):
            attack(player, .ATTACK, .PUNCHING3)
        case:
            set(player, .IDLE, .IDLE)
    }
}

input_walk :: proc(p: []Player, typ: PlayerType) {
    player := &p[PlayerType.PLAYER1]
    if typ == .PLAYER2 {
        player = &p[PlayerType.PLAYER2]
    }
    switch {
        case rl.IsKeyDown(.W) || rl.IsKeyDown(.UP):
            switch {
            case rl.IsKeyDown(.D) || rl.IsKeyDown(.RIGHT):
                jump(player, 1, .JUMP, .JUMPINGF)  // Jump right
            case rl.IsKeyDown(.A) || rl.IsKeyDown(.LEFT):
                jump(player, -1, .JUMP, .JUMPINGF)  // Jump left
            }
            return
        case rl.IsKeyDown(.A) || rl.IsKeyDown(.LEFT):
            move(player, -1, .WALK, .WALKING)
        case rl.IsKeyDown(.D) || rl.IsKeyDown(.RIGHT):
            move(player, 1, .WALK, .WALKINGF)
        // case rl.IsKeyDown(.S) || rl.IsKeyDown(.DOWN):
        //     crouch(player, .CROUCH, .CROUCHING)
        case rl.IsKeyDown(.E):
            attack(player, .ATTACK, .PUNCHING1)
        case rl.IsKeyDown(.R):
            attack(player, .ATTACK, .PUNCHING2)
        case rl.IsKeyDown(.T):
            attack(player, .ATTACK, .PUNCHING3)
        case:
            set(player, .IDLE, .IDLE)
    }
}

input_crouch :: proc(p: []Player, typ: PlayerType) {}

input_jump :: proc(p: []Player, typ: PlayerType) {
    player := &p[PlayerType.PLAYER1]
    if typ == .PLAYER2 {
        player = &p[PlayerType.PLAYER2]
    }
    if rl.IsKeyDown(.E) && player.frame != .PUNCHING1 ||
        rl.IsKeyDown(.KP_1) && player.frame != .PUNCHING1{
        attack(player, .ATTACK, .PUNCHING1)
    } else if rl.IsKeyDown(.R) && player.frame != .PUNCHING2 ||
        rl.IsKeyDown(.KP_2) && player.frame != .PUNCHING2 {
        attack(player, .ATTACK, .PUNCHING2)
    } else if rl.IsKeyDown(.T) && player.frame != .PUNCHING3 ||
        rl.IsKeyDown(.KP_3) && player.frame != .PUNCHING3 {
        attack(player, .ATTACK, .PUNCHING3)
    }
}

input_attack :: proc(p: []Player, typ: PlayerType) {
    player := &p[PlayerType.PLAYER1]
    if typ == .PLAYER2 {
        player = &p[PlayerType.PLAYER2]
    }
    if rl.IsKeyDown(.E) && player.frame != .PUNCHING1 ||
        rl.IsKeyDown(.KP_1) && player.frame != .PUNCHING1{
        attack(player, .ATTACK, .PUNCHING1)
    } else if rl.IsKeyDown(.R) && player.frame != .PUNCHING2 ||
        rl.IsKeyDown(.KP_2) && player.frame != .PUNCHING2 {
        attack(player, .ATTACK, .PUNCHING2)
    } else if rl.IsKeyDown(.T) && player.frame != .PUNCHING3 ||
        rl.IsKeyDown(.KP_3) && player.frame != .PUNCHING3 {
        attack(player, .ATTACK, .PUNCHING3)
    }
}

handle_input :: proc(dir: ^[]rl.Vector2, can_update_animation: ^[]bool, animState: ^[]AnimState, p: []Player) {
    for i in 0..=int(PlayerType.PLAYER2) {
        switch p[i].animation {
        case .IDLE:
            input_idle(p, PlayerType(i))
        case .WALK:
            input_walk(p, PlayerType(i))
        case .JUMP:
            input_jump(p, PlayerType(i))
        case .CROUCH:
            input_crouch(p, PlayerType(i))
        case .ATTACK:
            input_attack(p, PlayerType(i))
        }
    }
}

draw :: proc(p: ^Player, animState: ^[]AnimState, pos: ^[]rl.Vector2, type: PlayerType) {
    anim := &p.animations[int(p.frame)]
    frame := anim_frame(anim, int(type))
    source := rl.Rectangle{
        x = frame.x,
        y = frame.y,
        width = f32(anim.frame_width),
        height = f32(anim.frame_height),
    }
    dest := rl.Rectangle{
        x = p.pos.x,
        y = p.pos.y,
        width = f32(anim.frame_width),
        height = f32(anim.frame_height),
    }
    origin := rl.Vector2{
        f32(anim.frame_width) / 2,
        f32(anim.frame_height),
    }
    // TODO Handle flipping differently for Player 2
    if type == .PLAYER2 {
        source.width = -source.width
        source.x += f32(anim.frame_width)  // Use fixed width instead of source.width
    }
    rl.DrawTexturePro(p.textures[int(p.frame)], source, dest, origin, 0.0, rl.WHITE)
    pushbox := rl.Rectangle{
        x = p.pos.x - 10,
        y = p.pos.y - 80,
        width = f32(anim.frame_width) * 0.7,
        height = f32(anim.frame_height),
    }
    box_color := type == .PLAYER1 ? rl.RED : rl.BLUE
    rl.DrawRectangleLinesEx(pushbox, 2.0, box_color)
}

// Init player positions at center bottom of background
init_players :: proc(bg, sprite: rl.Texture2D) -> (me, enemy: Player, positions: []rl.Vector2) {
    initial_x := f32(bg.width) / 2
    initial_y := f32(bg.height) - 20  // Offset from bottom to account for character height
    me = Player{}
    init_player(sprite, &me, true)
    enemy = Player{}
    init_player(sprite, &enemy, false)
    pos := rl.Vector2{initial_x - 50, initial_y}  // Player 1 slightly to the left
    epos := rl.Vector2{initial_x + 50, initial_y}  // Player 2 slightly to the right
    positions = []rl.Vector2{pos, epos}
    return
}

init_player :: proc(sprite: rl.Texture2D, p: ^Player, is_me: bool) {
    p.animations = make([]Animation, int(Frame.ANIMSTATESFINAL))
    p.textures = make([]rl.Texture2D, int(Frame.ANIMSTATESFINAL))
    p.rects = make([]rl.Rectangle, int(Frame.ANIMSTATESFINAL) * 10)
    p.animation = .IDLE
    p.texture = sprite
    p.frame = .IDLING
    p.velocity = rl.Vector2{100, 0}
    p.type = is_me ? 0 : 1
    init_anims(p)
}

// Load animation data from the data file
init_anims :: proc(p: ^Player) {
    anims_text, ok := os.read_entire_file("assets/settings.txt")
    if !ok {
        fmt.println("Failed to open settings.txt")
        return
    }    
    // Convert text to string for easier parsing
    anims_str, err := strings.clone_from_bytes(anims_text)
    if err != nil {
        fmt.println("Failed to convert text to string")
        return
    }
    lines := strings.split(anims_str, "\n")
    defer delete(lines)

    anim_count := min(len(lines), int(Frame.ANIMSTATESFINAL))
    
    for i in 0..<anim_count {
        line := strings.trim_space(lines[i])
        if line == "" do continue
        
        parts := strings.split(line, " ")
        defer delete(parts)
        
        if len(parts) < 11 {
            fmt.printf("Invalid animation data format in line %d: %s\n", i, line)
            continue
        }
        anim_name := strings.to_upper(parts[0])
        first, _ := strconv.parse_int(parts[1], 10)
        last, _ := strconv.parse_int(parts[2], 10)
        cur, _ := strconv.parse_int(parts[3], 10)
        speed, _ := strconv.parse_f32(parts[4])
        duration, _ := strconv.parse_f32(parts[5])
        step, _ := strconv.parse_int(parts[6], 10)
        anim_type_str := strings.to_upper(parts[7])
        frame_width, _ := strconv.parse_int(parts[8], 10)
        frame_height, _ := strconv.parse_int(parts[9], 10)
        px, _ := strconv.parse_int(parts[10], 10)
        py, _ := strconv.parse_int(parts[11], 10)
        
        anim_type: AnimType
        if anim_type_str == "REPEATING" {
            anim_type = .REPEAT
        } else {
            anim_type = .ONESHOT
        }
        frame: Frame
        switch anim_name {
        case "IDLE":
            frame = .IDLE
        case "IDLING":
            frame = .IDLING
        case "CROUCHING":
            frame = .CROUCHING
        case "WALKING":
            frame = .WALKING
        case "WALKINGF":
            frame = .WALKINGF
        case "PUNCHING1":
            frame = .PUNCHING1
        case "PUNCHING2":
            frame = .PUNCHING2
        case "PUNCHING3":
            frame = .PUNCHING3
        case "JUMPING":
            frame = .JUMPING
        case "JUMPINGF":
            frame = .JUMPINGF
        case:
            fmt.printf("Unknown animation name: %s\n", anim_name)
            continue
        }
        p.animations[frame] = Animation{
            first = first,
            last = last,
            cur = cur,
            duration_left = duration,
            speed = speed,
            step = step,
            type = anim_type,
            frame_width = frame_width,
            frame_height = frame_height,
            px = px,
            py = py,
        }
        p.textures[frame] = p.texture
        p.rects[frame] = rl.Rectangle{
            x = f32(px),
            y = f32(py),
            width = f32(frame_width),
            height = f32(frame_height),
        }
        fmt.printf("Loaded animation: %s (%d-%d), size: %dx%d, pos: %d,%d\n", 
                  anim_name, first, last, frame_width, frame_height, px, py)
    }
}

anim_update :: proc(p: []Player, canupdt: ^[]bool, anst: ^[]AnimState) {
    dt := rl.GetFrameTime()
    for i in 0..=int(PlayerType.PLAYER2) {
        anim := p[i].animations[int(p[i].frame)]
        anim.duration_left -= dt
        if anim.type == .ONESHOT {
            canupdt[i] = false
        }
        if anim.duration_left <= 0.0 {
            anim.duration_left = anim.speed
            anim.cur += anim.step
            if anim.cur > anim.last {
                switch anim.type {
                case .REPEAT:
                    anim.cur = anim.first
                case .ONESHOT:
                    // Explicitly handle jump animation return to idle
                    if p[i].frame == .JUMPING {
                        anim.cur = anim.first
                        canupdt[i] = true
                        p[i].frame = .IDLE
                        p[i].animation = .IDLE
                    } else {
                        anim.cur = anim.first
                        canupdt[i] = true
                        p[i].frame = .IDLE
                        p[i].animation = .IDLE
                    }
                }
            } else if anim.cur < anim.first {
                switch anim.type {
                case .REPEAT:
                    anim.cur = anim.last
                case .ONESHOT:
                    // Similar handling for jump animation
                    if p[i].frame == .JUMPING {
                        anim.cur = anim.last
                        canupdt[i] = true
                        p[i].frame = .IDLE
                        p[i].animation = .IDLE
                    } else {
                        anim.cur = anim.last
                        canupdt[i] = true
                        p[i].frame = .IDLE
                        p[i].animation = .IDLE
                    }
                }
            }
        }
        p[i].animations[int(p[i].frame)] = anim
    }
}

anim_frame :: proc(a: ^Animation, direction: int) -> rl.Rectangle {
    wid := a.frame_width
    wid *= direction
    // Calc position of curr frame
    frames_per_row := 5
    // row and column of the current frame
    col := a.cur % frames_per_row
    row := a.cur / frames_per_row
    return rl.Rectangle{
        x = f32(a.px + (col * a.frame_width)),
        y = f32(a.py + (row * a.frame_height)),
        width = f32(wid),  // Use positive width always
        height = f32(a.frame_height),
    }
}

init :: proc(screenWidth, screenHeight: i32) -> (bg, sprite: rl.Texture2D, music: rl.Music, cam: rl.Camera2D) {
    rl.InitAudioDevice()
    rl.InitWindow(screenWidth, screenHeight, "Street Fighter")
    rl.SetTargetFPS(60)
    bg = rl.LoadTexture("assets/bg.jpg")
    sprite = rl.LoadTexture("assets/sprite.png")
    music = rl.LoadMusicStream("assets/music.mp3")
    rl.PlayMusicStream(music)
    cam = rl.Camera2D{
        target = {0, 0},
        offset = {f32(screenWidth) / 2.0, f32(screenHeight) / 2.0},
        rotation = 0.0,
        zoom = 1.8,
    }
    return
}

boundaries :: proc(bg: rl.Texture2D) -> Boundaries {
    return Boundaries{
        left = 0,
        right = f32(bg.width),
        top = 0,
        bottom = f32(bg.height),
    }
}

update_physics :: proc(entities: []Player, positions: []rl.Vector2, initial_y: f32, dt: f32) -> []rl.Vector2 {
    new_pos := make([]rl.Vector2, len(positions))
    copy(new_pos, positions)
    gravity: f32 = 980.0
    for i in 0..=int(PlayerType.PLAYER2) {
        // Apply gravity
        entities[i].velocity.y += gravity * dt
        
        // Apply both vertical and horizontal velocity
        if i == int(PlayerType.PLAYER1) {
            new_pos[i].x += entities[i].velocity.x * dt
            new_pos[i].y += entities[i].velocity.y * dt
        } else {
            new_pos[i].x += entities[i].velocity.x * dt
            new_pos[i].y += entities[i].velocity.y * dt
        }
        // Check if landed on ground
        if (i == int(PlayerType.PLAYER1) && new_pos[i].y >= initial_y) || 
           (i == int(PlayerType.PLAYER2) && new_pos[i].y >= initial_y) {
            // Reset horizontal velocity when landing
            entities[i].velocity.x = 0
            entities[i].velocity.y = 0
            entities[i].grounded = true
            
            new_pos[i].y = initial_y
            
            // Return to idle if jumping
            if entities[i].animation == .JUMP {
                set(&entities[i], .IDLE, .IDLE)
            }
        }
    }
    return new_pos
}

// Update camera target, clamped to ensure background stays in view 
update_cam :: proc(pos: rl.Vector2, cam: ^rl.Camera2D, boundaries: Boundaries, screenWidth, screenHeight: f32) {
    cam.target = {
        clamp(
            pos.x + 20, 
            boundaries.left + screenWidth / (2 * cam.zoom),
            boundaries.right - screenWidth / (2 * cam.zoom)
        ), 
        clamp(
            pos.y - 80,
            boundaries.top + screenHeight / (2 * cam.zoom),
            boundaries.bottom - screenHeight / (2 * cam.zoom)
        ),
    }
}

main :: proc() {
    screenWidth :: 960
    screenHeight :: 561
    bg, sprite, music, cam := init(screenWidth, screenHeight)
    boundaries := boundaries(bg)
    defer rl.CloseWindow()
    defer rl.CloseAudioDevice()
    defer rl.UnloadTexture(bg)
    defer rl.UnloadTexture(sprite)
    defer rl.UnloadMusicStream(music)

    me, enemy, positions := init_players(bg, sprite)
    defer {
        delete(me.animations)
        delete(me.textures)
        delete(me.rects)
        rl.UnloadTexture(me.texture)
        
        delete(enemy.animations)
        delete(enemy.textures)
        delete(enemy.rects)
        rl.UnloadTexture(enemy.texture)
    }
    
    players := [2]Player{me, enemy}
    
    speed: f32 = 100.0
    initial_y := positions[0].y
    
    me_state := AnimState.IDLE
    can_update_animation := true
    
    enemy_state := AnimState.IDLE
    can_enemy_update_animation := true
    
    can_update := []bool{can_update_animation, can_enemy_update_animation}
    anims := []AnimState{me_state, enemy_state}
    
    for !rl.WindowShouldClose() {
        dt := rl.GetFrameTime()
        rl.UpdateMusicStream(music)

        handle_input(&positions, &can_update, &anims, players[:])
        positions = update_physics(players[:], positions, initial_y, dt)
        anim_update(players[:], &can_update, &anims)
        
        // Apply boundary clamping
        speed: f32 = 100.0
        for i in 0..=int(PlayerType.PLAYER2) {
            directions := []rl.Vector2{{0, 0}, {0, 0}}
            new_pos_x := positions[i].x + players[i].dir.x * speed * dt
            new_pos_y := positions[i].y + directions[i].y * speed * dt
            
            positions[i].x = clamp(new_pos_x, boundaries.left + 50, boundaries.right - 50)  // 50px margin
            positions[i].y = clamp(new_pos_y, boundaries.top + 50, boundaries.bottom)
            
            players[i].pos = positions[i]
        }
        update_cam(positions[PlayerType.PLAYER1], &cam, boundaries, f32(screenWidth), f32(screenHeight))
        
        // Reset directions
        players[PlayerType.PLAYER1].dir = {0, 0}
        players[PlayerType.PLAYER2].dir = players[PlayerType.PLAYER1].dir
        
        rl.BeginDrawing()
        rl.ClearBackground(rl.SKYBLUE)
        
        rl.BeginMode2D(cam)
        
        rl.DrawTexture(bg, 0, 0, rl.WHITE)
        
        draw(&players[PlayerType.PLAYER2], &anims, &positions, .PLAYER2)
        draw(&players[PlayerType.PLAYER1], &anims, &positions, .PLAYER1)
        rl.EndMode2D()
        rl.EndDrawing()
    }
}