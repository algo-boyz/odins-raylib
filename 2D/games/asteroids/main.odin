package asteroids

import "core:math"

import rl "vendor:raylib"

SCREEN_WIDTH :: 800
SCREEN_HEIGHT :: 450

PLAYER_BASE_SIZE :: 20.0
PLAYER_SPEED :: 6.0
PLAYER_MAX_SHOOTS :: 10

METEORS_SPEED :: 2
MAX_MEDIUM_METEORS :: 8
MAX_SMALL_METEORS :: 16

Player :: struct {
    position: rl.Vector2,
    speed: rl.Vector2,
    acceleration: f32,
    rotation: f32,
    collider: rl.Vector3,
    color: rl.Color,
}

Meteor :: struct {
    position: rl.Vector2,
    speed: rl.Vector2,
    radius: f32,
    active: bool,
    color: rl.Color,
}

Game_State :: struct {
    frames_counter: int,
    game_over: bool,
    pause: bool,
    ship_height: f32,
    player: Player,
    medium_meteors: [MAX_MEDIUM_METEORS]Meteor,
    small_meteors: [MAX_SMALL_METEORS]Meteor,
}

state: Game_State

init_game :: proc() {
    state.pause = false
    state.frames_counter = 0
    state.game_over = false
    // Calculate ship height based on isosceles triangle with 70-degree angles
    state.ship_height = (PLAYER_BASE_SIZE/2)/math.tan_f32(20 * math.PI/180)
    // Initialize player
    state.player = Player{
        position = {SCREEN_WIDTH/2, SCREEN_HEIGHT/2 - state.ship_height/2},
        speed = {0, 0},
        acceleration = 0,
        rotation = 0,
        color = rl.LIGHTGRAY,
    }
    state.player.collider = {
        state.player.position.x + math.sin(state.player.rotation * math.PI/180) * (state.ship_height/2.5),
        state.player.position.y - math.cos(state.player.rotation * math.PI/180) * (state.ship_height/2.5),
        12,
    }
    // Initialize meteors
    for i := 0; i < MAX_MEDIUM_METEORS; i += 1 {
        pos_x, pos_y: i32
        vel_x, vel_y: i32
        correct_range := false
        for !correct_range {
            pos_x = rl.GetRandomValue(0, SCREEN_WIDTH)
            if !(pos_x > SCREEN_WIDTH/2 - 150 && pos_x < SCREEN_WIDTH/2 + 150) {
                correct_range = true
            }
        }
        correct_range = false
        for !correct_range {
            pos_y = rl.GetRandomValue(0, SCREEN_HEIGHT)
            if !(pos_y > SCREEN_HEIGHT/2 - 150 && pos_y < SCREEN_HEIGHT/2 + 150) {
                correct_range = true
            }
        }
        correct_range = false
        for !correct_range {
            vel_x = rl.GetRandomValue(-METEORS_SPEED, METEORS_SPEED)
            vel_y = rl.GetRandomValue(-METEORS_SPEED, METEORS_SPEED)
            if !(vel_x == 0 && vel_y == 0) {
                correct_range = true
            }
        }
        state.medium_meteors[i] = Meteor{
            position = {f32(pos_x), f32(pos_y)},
            speed = {f32(vel_x), f32(vel_y)},
            radius = 20,
            active = true,
            color = rl.GREEN,
        }
    }
    // Initialize small meteors with similar logic
    for i := 0; i < MAX_SMALL_METEORS; i += 1 {
        pos_x, pos_y: i32
        vel_x, vel_y: i32
        correct_range := false
        for !correct_range {
            pos_x = rl.GetRandomValue(0, SCREEN_WIDTH)
            if !(pos_x > SCREEN_WIDTH/2 - 150 && pos_x < SCREEN_WIDTH/2 + 150) {
                correct_range = true
            }
        }
        correct_range = false
        for !correct_range {
            pos_y = rl.GetRandomValue(0, SCREEN_HEIGHT)
            if !(pos_y > SCREEN_HEIGHT/2 - 150 && pos_y < SCREEN_HEIGHT/2 + 150) {
                correct_range = true
            }
        }
        correct_range = false
        for !correct_range {
            vel_x = rl.GetRandomValue(-METEORS_SPEED, METEORS_SPEED)
            vel_y = rl.GetRandomValue(-METEORS_SPEED, METEORS_SPEED)
            if !(vel_x == 0 && vel_y == 0) {
                correct_range = true
            }
        }
        state.small_meteors[i] = Meteor{
            position = {f32(pos_x), f32(pos_y)},
            speed = {f32(vel_x), f32(vel_y)},
            radius = 10,
            active = true,
            color = rl.YELLOW,
        }
    }
}

update_game :: proc() {
    if !state.game_over {
        if rl.IsKeyPressed(rl.KeyboardKey.S) ||
            rl.IsKeyPressed(rl.KeyboardKey.P) {
            state.pause = !state.pause
        }
        if !state.pause {
            state.frames_counter += 1
            
            // Player logic
            if rl.IsKeyDown(rl.KeyboardKey.LEFT) {
                state.player.rotation -= 5
            }
            if rl.IsKeyDown(rl.KeyboardKey.RIGHT) {
                state.player.rotation += 5
            }
            // Speed
            state.player.speed = {
                math.sin(state.player.rotation * math.PI/180) * PLAYER_SPEED,
                math.cos(state.player.rotation * math.PI/180) * PLAYER_SPEED,
            }
            // Controller
            if rl.IsKeyDown(rl.KeyboardKey.UP) {
                if state.player.acceleration < 1 {
                    state.player.acceleration += 0.04
                }
            } else {
                if state.player.acceleration > 0 {
                    state.player.acceleration -= 0.02
                } else if state.player.acceleration < 0 {
                    state.player.acceleration = 0
                }
            }
            if rl.IsKeyDown(rl.KeyboardKey.DOWN) {
                if state.player.acceleration > 0 {
                    state.player.acceleration -= 0.04
                } else if state.player.acceleration < 0 {
                    state.player.acceleration = 0
                }
            }
            // Movement
            state.player.position.x += state.player.speed.x * state.player.acceleration
            state.player.position.y -= state.player.speed.y * state.player.acceleration
            // Wall behaviour
            if state.player.position.x > f32(SCREEN_WIDTH) + state.ship_height {
                state.player.position.x = -state.ship_height
            } else if state.player.position.x < -state.ship_height {
                state.player.position.x = f32(SCREEN_WIDTH) + state.ship_height
            }
            if state.player.position.y > f32(SCREEN_HEIGHT) + state.ship_height {
                state.player.position.y = -state.ship_height
            } else if state.player.position.y < -state.ship_height {
                state.player.position.y = f32(SCREEN_HEIGHT) + state.ship_height
            }
            // Update player collider
            state.player.collider = {
                state.player.position.x + math.sin(state.player.rotation * math.PI/180) * (state.ship_height/2.5),
                state.player.position.y - math.cos(state.player.rotation * math.PI/180) * (state.ship_height/2.5),
                12,
            }
            // Check collisions with meteors
            for meteor in &state.medium_meteors {
                if meteor.active && rl.CheckCollisionCircles(
                    {state.player.collider.x, state.player.collider.y},
                    state.player.collider.z,
                    meteor.position,
                    meteor.radius,
                ) {
                    state.game_over = true
                }
            }
            for meteor in &state.small_meteors {
                if meteor.active && rl.CheckCollisionCircles(
                    {state.player.collider.x, state.player.collider.y},
                    state.player.collider.z,
                    meteor.position,
                    meteor.radius,
                ) {
                    state.game_over = true
                }
            }
            // Update meteors
            for &meteor in &state.medium_meteors {
                if meteor.active {
                    meteor.position.x += meteor.speed.x
                    meteor.position.y += meteor.speed.y
                    
                    // Wall behaviour
                    if meteor.position.x > f32(SCREEN_WIDTH) + meteor.radius {
                        meteor.position.x = -meteor.radius
                    } else if meteor.position.x < -meteor.radius {
                        meteor.position.x = f32(SCREEN_WIDTH) + meteor.radius
                    }
                    if meteor.position.y > f32(SCREEN_HEIGHT) + meteor.radius {
                        meteor.position.y = -meteor.radius
                    } else if meteor.position.y < -meteor.radius {
                        meteor.position.y = f32(SCREEN_HEIGHT) + meteor.radius
                    }
                }
            }
            for &meteor in &state.small_meteors {
                if meteor.active {
                    meteor.position.x += meteor.speed.x
                    meteor.position.y += meteor.speed.y
                    
                    // Wall behaviour
                    if meteor.position.x > f32(SCREEN_WIDTH) + meteor.radius {
                        meteor.position.x = -meteor.radius
                    } else if meteor.position.x < -meteor.radius {
                        meteor.position.x = f32(SCREEN_WIDTH) + meteor.radius
                    }
                    if meteor.position.y > f32(SCREEN_HEIGHT) + meteor.radius {
                        meteor.position.y = -meteor.radius
                    } else if meteor.position.y < -meteor.radius {
                        meteor.position.y = f32(SCREEN_HEIGHT) + meteor.radius
                    }
                }
            }
        }
    } else if rl.IsKeyPressed(rl.KeyboardKey.SPACE) {
        init_game()
        state.game_over = false
    }
}

draw_game :: proc() {
    rl.BeginDrawing()
    defer rl.EndDrawing()
    rl.ClearBackground(rl.RAYWHITE)
    
    if !state.game_over {
        // Draw spaceship
        v1 := rl.Vector2{
            state.player.position.x + math.sin(state.player.rotation * math.PI/180) * state.ship_height,
            state.player.position.y - math.cos(state.player.rotation * math.PI/180) * state.ship_height,
        }
        v2 := rl.Vector2{
            state.player.position.x - math.cos(state.player.rotation * math.PI/180) * (PLAYER_BASE_SIZE/2),
            state.player.position.y - math.sin(state.player.rotation * math.PI/180) * (PLAYER_BASE_SIZE/2),
        }
        v3 := rl.Vector2{
            state.player.position.x + math.cos(state.player.rotation * math.PI/180) * (PLAYER_BASE_SIZE/2),
            state.player.position.y + math.sin(state.player.rotation * math.PI/180) * (PLAYER_BASE_SIZE/2),
        }
        rl.DrawTriangle(v1, v2, v3, rl.MAROON)
        // Draw meteors
        for meteor in state.medium_meteors {
            if meteor.active {
                rl.DrawCircleV(meteor.position, meteor.radius, rl.GRAY)
            } else {
                rl.DrawCircleV(meteor.position, meteor.radius, {192, 192, 192, 77})
            }
        }
        for meteor in state.small_meteors {
            if meteor.active {
                rl.DrawCircleV(meteor.position, meteor.radius, rl.DARKGRAY)
            } else {
                rl.DrawCircleV(meteor.position, meteor.radius, {192, 192, 192, 77})
            }
        }
        rl.DrawText(rl.TextFormat("TIME: %.02f", f32(state.frames_counter)/60), 10, 10, 20, rl.BLACK)
        if state.pause {
            text:cstring = "GAME PAUSED"
            width := rl.MeasureText(text, 40)
            rl.DrawText(text, SCREEN_WIDTH/2 - width/2, SCREEN_HEIGHT/2 - 40, 40, rl.GRAY)
        }
    } else {
        text:cstring = "PRESS [SPACE] TO PLAY AGAIN"
        width := rl.MeasureText(text, 20)
        rl.DrawText(text, SCREEN_WIDTH/2 - width/2, SCREEN_HEIGHT/2 - 50, 20, rl.GRAY)
    }
}

main :: proc() {
    rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "asteroid survival")
    defer rl.CloseWindow()
    rl.SetTargetFPS(60)
    init_game()
    for !rl.WindowShouldClose() {
        update_game()
        draw_game()
    }
}