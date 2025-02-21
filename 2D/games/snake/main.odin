package main

import "core:fmt"
import rl "vendor:raylib"
import "core:math/rand"

vec2 :: rl.Vector2
rect :: rl.Rectangle

CELL_SIZE :: 30
CELL_COUNT :: 25
OFFSET :: 75

GREEN := rl.Color{173, 204, 96, 255}
DARK_GREEN := rl.Color{43, 51, 24, 255}

last_update_time: f64

Game :: struct {
    snake: Snake,
    food: Food,
    running: bool,
    score: int,
    eat_sound: rl.Sound,
    wall_sound: rl.Sound,
}

Snake :: struct {
    body: [dynamic]vec2,
    direction: vec2,
    add_segment: bool,
}

Food :: struct {
    position: vec2,
    texture: rl.Texture2D,
}

element_in_slice :: proc(element: vec2, slice: []vec2) -> bool {
    for v in slice {
        if v.x == element.x && v.y == element.y {
            return true
        }
    }
    return false
}

event_triggered :: proc(interval: f64) -> bool {
    current_time := rl.GetTime()
    if current_time - last_update_time >= interval {
        last_update_time = current_time
        return true
    }
    return false
}

snake_init :: proc() -> Snake {
    snake := Snake{
        body = make([dynamic]vec2, 0, 100),
        direction = vec2{1, 0},
        add_segment = false,
    }
    append(&snake.body, vec2{6, 9})
    append(&snake.body, vec2{5, 9})
    append(&snake.body, vec2{4, 9})
    return snake
}

snake_draw :: proc(snake: ^Snake) {
    for segment in snake.body {
        segment_rect := rect{
            OFFSET + segment.x * CELL_SIZE,
            OFFSET + segment.y * CELL_SIZE,
            CELL_SIZE,
            CELL_SIZE,
        }
        rl.DrawRectangleRounded(segment_rect, 0.5, 6, DARK_GREEN)
    }
}

snake_update :: proc(snake: ^Snake) {
    new_head := vec2{
        snake.body[0].x + snake.direction.x,
        snake.body[0].y + snake.direction.y,
    }
    inject_at(&snake.body, 0, new_head)
    
    if !snake.add_segment {
        pop(&snake.body)
    }
    snake.add_segment = false
}

snake_reset :: proc(snake: ^Snake) {
    clear(&snake.body)
    append(&snake.body, vec2{6, 9})
    append(&snake.body, vec2{5, 9})
    append(&snake.body, vec2{4, 9})
    snake.direction = vec2{1, 0}
}

generate_random_cell :: proc() -> vec2 {
    x := rand.int_max(CELL_COUNT)
    y := rand.int_max(CELL_COUNT)
    return vec2{f32(x), f32(y)}
}

generate_random_pos :: proc(snake_body: []vec2) -> vec2 {
    position := generate_random_cell()
    for element_in_slice(position, snake_body) {
        position = generate_random_cell()
    }
    return position
}

food_init :: proc(snake_body: []vec2) -> Food {
    image := rl.LoadImage("assets/food.png")
    texture := rl.LoadTextureFromImage(image)
    rl.UnloadImage(image)
    
    return Food{
        position = generate_random_pos(snake_body),
        texture = texture,
    }
}

food_draw :: proc(food: ^Food) {
    rl.DrawTexture(
        food.texture,
        i32(OFFSET + food.position.x * CELL_SIZE),
        i32(OFFSET + food.position.y * CELL_SIZE),
        rl.WHITE,
    )
}

game_init :: proc() -> Game {
    rl.InitAudioDevice()
    snake := snake_init()
    
    game := Game{
        snake = snake,
        food = food_init(snake.body[:]),
        running = true,
        score = 0,
        eat_sound = rl.LoadSound("assets/eat.mp3"),
        wall_sound = rl.LoadSound("assets/wall.mp3"),
    }
    
    return game
}

game_draw :: proc(game: ^Game) {
    food_draw(&game.food)
    snake_draw(&game.snake)
}

check_collision_with_food :: proc(game: ^Game) {
    if game.snake.body[0].x == game.food.position.x && 
       game.snake.body[0].y == game.food.position.y {
        game.food.position = generate_random_pos(game.snake.body[:])
        game.snake.add_segment = true
        game.score += 1
        rl.PlaySound(game.eat_sound)
    }
}

check_collision_with_edges :: proc(game: ^Game) {
    if game.snake.body[0].x == CELL_COUNT || game.snake.body[0].x == -1 ||
       game.snake.body[0].y == CELL_COUNT || game.snake.body[0].y == -1 {
        game_over(game)
    }
}

check_collision_with_tail :: proc(game: ^Game) {
    if len(game.snake.body) > 1 {
        if element_in_slice(game.snake.body[0], game.snake.body[1:]) {
            game_over(game)
        }
    }
}

game_over :: proc(game: ^Game) {
    snake_reset(&game.snake)
    game.food.position = generate_random_pos(game.snake.body[:])
    game.running = false
    game.score = 0
    rl.PlaySound(game.wall_sound)
}

game_update :: proc(game: ^Game) {
    if game.running {
        snake_update(&game.snake)
        check_collision_with_food(game)
        check_collision_with_edges(game)
        check_collision_with_tail(game)
    }
}

main :: proc() {
    rl.InitWindow(
        2 * OFFSET + CELL_SIZE * CELL_COUNT,
        2 * OFFSET + CELL_SIZE * CELL_COUNT,
        "Retro Snake",
    )
    rl.SetTargetFPS(60)
    
    g := game_init()
    allow_move := false
    
    for !rl.WindowShouldClose() {
        if event_triggered(0.2) {
            allow_move = true
            game_update(&g)
        }
        
        if rl.IsKeyPressed(.UP) && g.snake.direction.y != 1 && allow_move {
            g.snake.direction = vec2{0, -1}
            g.running = true
            allow_move = false
        }
        if rl.IsKeyPressed(.DOWN) && g.snake.direction.y != -1 && allow_move {
            g.snake.direction = vec2{0, 1}
            g.running = true
            allow_move = false
        }
        if rl.IsKeyPressed(.LEFT) && g.snake.direction.x != 1 && allow_move {
            g.snake.direction = vec2{-1, 0}
            g.running = true
            allow_move = false
        }
        if rl.IsKeyPressed(.RIGHT) && g.snake.direction.x != -1 && allow_move {
            g.snake.direction = vec2{1, 0}
            g.running = true
            allow_move = false
        }
        
        rl.BeginDrawing()
        rl.ClearBackground(GREEN)
        
        border_rect := rect{
            f32(OFFSET - 5),
            f32(OFFSET - 5),
            f32(CELL_SIZE * CELL_COUNT + 10),
            f32(CELL_SIZE * CELL_COUNT + 10),
        }
        rl.DrawRectangleLinesEx(border_rect, 5, DARK_GREEN)
        
        rl.DrawText("Retro Snake", OFFSET - 5, 20, 40, DARK_GREEN)
        rl.DrawText(
            fmt.ctprintf("%d", g.score),
            OFFSET - 5,
            OFFSET + CELL_SIZE * CELL_COUNT + 10,
            40,
            DARK_GREEN,
        )
        
        game_draw(&g)
        rl.EndDrawing()
    }
    
    rl.CloseWindow()
}