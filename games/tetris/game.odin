package tetris

import rl "vendor:raylib"

Game :: struct {
    grid: Grid,
    blocks: [dynamic]Block,
    current_block: Block,
    next_block: Block,
    game_over: bool,
    score: i32,
    music: rl.Music,
    rotate_sound: rl.Sound,
    clear_sound: rl.Sound,
}

init_game :: proc() -> (g: Game) {
    // Init grid
    g.grid = init_grid()
    // Init audio
    rl.InitAudioDevice()
    g.music = rl.LoadMusicStream("assets/music.mp3")
    rl.PlayMusicStream(g.music)
    g.rotate_sound = rl.LoadSound("assets/rotate.mp3")
    g.clear_sound = rl.LoadSound("assets/clear.mp3")
    // Init blocks
    g.blocks = make([dynamic]Block)
    g.blocks = all_blocks()
    g.current_block = random_block(&g)
    g.next_block = random_block(&g)
    
    g.game_over = false
    g.score = 0
    return g
}

destroy_game :: proc(game: ^Game) {
    rl.UnloadSound(game.rotate_sound)
    rl.UnloadSound(game.clear_sound)
    rl.UnloadMusicStream(game.music)
    rl.CloseAudioDevice()
    delete(game.blocks)
    rl.CloseWindow()
}

game_draw :: proc(g: ^Game) {
    grid_draw(&g.grid)
    block_draw(&g.current_block, 11, 11)
    // Draw next block
    switch g.next_block.id {
    case 3:
        block_draw(&g.next_block, 255, 290)
    case 4:
        block_draw(&g.next_block, 255, 280)
    case:
        block_draw(&g.next_block, 270, 270)
    }
}

game_handle_input :: proc(g: ^Game) {
    pressed := rl.GetKeyPressed()
    if g.game_over && pressed != rl.KeyboardKey.KEY_NULL {
        g.game_over = false
        game_reset(g)
        return
    }
    #partial switch pressed {
    case rl.KeyboardKey.LEFT:
        move_block_left(g)
    case rl.KeyboardKey.RIGHT:
        move_block_right(g)
    case rl.KeyboardKey.DOWN:
        move_block_down(g)
        game_update_score(g, 0, 1)
    case rl.KeyboardKey.UP:
        rotate_block(g)
    }
}

game_reset :: proc(g: ^Game) {
    delete(g.blocks)
    g.blocks = all_blocks()
    g.grid = init_grid()
    g.current_block = random_block(g)
    g.next_block = random_block(g)
    g.score = 0
}

game_update_score :: proc(g: ^Game, lines_cleared, move_down_points: i32) {
    switch lines_cleared {
    case 1:
        g.score += 100
    case 2:
        g.score += 300
    case 3:
        g.score += 500
    }
    g.score += move_down_points
}