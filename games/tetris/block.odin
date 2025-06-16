package tetris

import "base:runtime"
import "core:fmt"
import "core:math/rand"
import rl "vendor:raylib"

Position :: struct {
    row: i32,
    col: i32,
}

Block :: struct {
    cell_size: i32,
    rotation_state: int,
    colors: []rl.Color,
    row_offset: i32,
    col_offset: i32,
    cells: [][]Position,
    id: i32,
}

BlockType :: enum {
    L,
    J,
    I,
    O,
    S,
    T,
    Z,
}

all_blocks :: proc() -> [dynamic]Block {
    b := make([dynamic]Block)
    append(&b, init_block(.L))
    append(&b, init_block(.J))
    append(&b, init_block(.I))
    append(&b, init_block(.O))
    append(&b, init_block(.S))
    append(&b, init_block(.T))
    append(&b, init_block(.Z))
    return b
}

init_block :: proc(block_type: BlockType) -> (b: Block) {
    b.cell_size = 30
    b.rotation_state = 0
    b.row_offset = 0
    b.col_offset = 0
    b.colors = get_cell_colors()

    #partial switch block_type {
    case .L:
        b.id = 1
        b.cells = make([][]Position, 4)
        
        // First rotation state
        b.cells[0] = make([]Position, 4)
        b.cells[0][0] = {0, 2}
        b.cells[0][1] = {1, 0}
        b.cells[0][2] = {1, 1}
        b.cells[0][3] = {1, 2}
        
        // Second rotation state
        b.cells[1] = make([]Position, 4)
        b.cells[1][0] = {0, 1}
        b.cells[1][1] = {1, 1}
        b.cells[1][2] = {2, 1}
        b.cells[1][3] = {2, 2}
        
        // Third rotation state
        b.cells[2] = make([]Position, 4)
        b.cells[2][0] = {1, 0}
        b.cells[2][1] = {1, 1}
        b.cells[2][2] = {1, 2}
        b.cells[2][3] = {2, 0}
        
        // Fourth rotation state
        b.cells[3] = make([]Position, 4)
        b.cells[3][0] = {0, 0}
        b.cells[3][1] = {0, 1}
        b.cells[3][2] = {1, 1}
        b.cells[3][3] = {2, 1}
        
        block_move(&b, 0, 3)
        
    case .J:
        b.id = 2
        b.cells = make([][]Position, 4)
        
        // First rotation state
        b.cells[0] = make([]Position, 4)
        b.cells[0][0] = {0, 0}
        b.cells[0][1] = {1, 0}
        b.cells[0][2] = {1, 1}
        b.cells[0][3] = {1, 2}
        
        // Second rotation state
        b.cells[1] = make([]Position, 4)
        b.cells[1][0] = {0, 1}
        b.cells[1][1] = {0, 2}
        b.cells[1][2] = {1, 1}
        b.cells[1][3] = {2, 1}
        
        // Third rotation state
        b.cells[2] = make([]Position, 4)
        b.cells[2][0] = {1, 0}
        b.cells[2][1] = {1, 1}
        b.cells[2][2] = {1, 2}
        b.cells[2][3] = {2, 2}
        
        // Fourth rotation state
        b.cells[3] = make([]Position, 4)
        b.cells[3][0] = {0, 1}
        b.cells[3][1] = {1, 1}
        b.cells[3][2] = {2, 0}
        b.cells[3][3] = {2, 1}
        
        block_move(&b, 0, 3)
        
    case .I:
        b.id = 3
        b.cells = make([][]Position, 4)
        
        // First rotation state
        b.cells[0] = make([]Position, 4)
        b.cells[0][0] = {1, 0}
        b.cells[0][1] = {1, 1}
        b.cells[0][2] = {1, 2}
        b.cells[0][3] = {1, 3}
        
        // Second rotation state
        b.cells[1] = make([]Position, 4)
        b.cells[1][0] = {0, 2}
        b.cells[1][1] = {1, 2}
        b.cells[1][2] = {2, 2}
        b.cells[1][3] = {3, 2}
        
        // Third rotation state
        b.cells[2] = make([]Position, 4)
        b.cells[2][0] = {2, 0}
        b.cells[2][1] = {2, 1}
        b.cells[2][2] = {2, 2}
        b.cells[2][3] = {2, 3}
        
        // Fourth rotation state
        b.cells[3] = make([]Position, 4)
        b.cells[3][0] = {0, 1}
        b.cells[3][1] = {1, 1}
        b.cells[3][2] = {2, 1}
        b.cells[3][3] = {3, 1}
        
        block_move(&b, -1, 3)
        
    case .O:
        b.id = 4
        b.cells = make([][]Position, 1)
        
        // O block has only one rotation state (it's a square)
        b.cells[0] = make([]Position, 4)
        b.cells[0][0] = {0, 0}
        b.cells[0][1] = {0, 1}
        b.cells[0][2] = {1, 0}
        b.cells[0][3] = {1, 1}
        
        block_move(&b, 0, 4)
        
    case .S:
        b.id = 5
        b.cells = make([][]Position, 4)
        
        // First rotation state
        b.cells[0] = make([]Position, 4)
        b.cells[0][0] = {0, 1}
        b.cells[0][1] = {0, 2}
        b.cells[0][2] = {1, 0}
        b.cells[0][3] = {1, 1}
        
        // Second rotation state
        b.cells[1] = make([]Position, 4)
        b.cells[1][0] = {0, 1}
        b.cells[1][1] = {1, 1}
        b.cells[1][2] = {1, 2}
        b.cells[1][3] = {2, 2}
        
        // Third rotation state
        b.cells[2] = make([]Position, 4)
        b.cells[2][0] = {1, 1}
        b.cells[2][1] = {1, 2}
        b.cells[2][2] = {2, 0}
        b.cells[2][3] = {2, 1}
        
        // Fourth rotation state
        b.cells[3] = make([]Position, 4)
        b.cells[3][0] = {0, 0}
        b.cells[3][1] = {1, 0}
        b.cells[3][2] = {1, 1}
        b.cells[3][3] = {2, 1}
        
        block_move(&b, 0, 3)
        
    case .T:
        b.id = 6
        b.cells = make([][]Position, 4)
        
        // First rotation state
        b.cells[0] = make([]Position, 4)
        b.cells[0][0] = {0, 1}
        b.cells[0][1] = {1, 0}
        b.cells[0][2] = {1, 1}
        b.cells[0][3] = {1, 2}
        
        // Second rotation state
        b.cells[1] = make([]Position, 4)
        b.cells[1][0] = {0, 1}
        b.cells[1][1] = {1, 1}
        b.cells[1][2] = {1, 2}
        b.cells[1][3] = {2, 1}
        
        // Third rotation state
        b.cells[2] = make([]Position, 4)
        b.cells[2][0] = {1, 0}
        b.cells[2][1] = {1, 1}
        b.cells[2][2] = {1, 2}
        b.cells[2][3] = {2, 1}
        
        // Fourth rotation state
        b.cells[3] = make([]Position, 4)
        b.cells[3][0] = {0, 1}
        b.cells[3][1] = {1, 0}
        b.cells[3][2] = {1, 1}
        b.cells[3][3] = {2, 1}
        
        block_move(&b, 0, 3)
        
    case .Z:
        b.id = 7
        b.cells = make([][]Position, 4)
        
        // First rotation state
        b.cells[0] = make([]Position, 4)
        b.cells[0][0] = {0, 0}
        b.cells[0][1] = {0, 1}
        b.cells[0][2] = {1, 1}
        b.cells[0][3] = {1, 2}
        
        // Second rotation state
        b.cells[1] = make([]Position, 4)
        b.cells[1][0] = {0, 2}
        b.cells[1][1] = {1, 1}
        b.cells[1][2] = {1, 2}
        b.cells[1][3] = {2, 1}
        
        // Third rotation state
        b.cells[2] = make([]Position, 4)
        b.cells[2][0] = {1, 0}
        b.cells[2][1] = {1, 1}
        b.cells[2][2] = {2, 1}
        b.cells[2][3] = {2, 2}
        
        // Fourth rotation state
        b.cells[3] = make([]Position, 4)
        b.cells[3][0] = {0, 1}
        b.cells[3][1] = {1, 0}
        b.cells[3][2] = {1, 1}
        b.cells[3][3] = {2, 0}
        
        block_move(&b, 0, 3)
    }
    return b
}

destroy_block :: proc(b: ^Block) {
    for cells in b.cells {
        delete(cells)
    }
    delete(b.cells)
}

block_draw :: proc(b: ^Block, offset_x, offset_y: i32) {
    tiles := block_cell_position(b)
    for tile in tiles {
        rl.DrawRectangle(
            i32(tile.col * b.cell_size + offset_x),
            i32(tile.row * b.cell_size + offset_y),
            i32(b.cell_size - 1),
            i32(b.cell_size - 1),
            b.colors[b.id],
        )
    }
}

random_block :: proc(g: ^Game) -> Block {
    return g.blocks[rand.int_max(len(g.blocks))]
}

block_move :: proc(b: ^Block, rows, columns: i32) {
    b.row_offset += rows
    b.col_offset += columns
}

block_cell_position :: proc(b: ^Block) -> []Position {
    tiles := b.cells[b.rotation_state]
    moved_tiles := make([dynamic]Position, 0, len(tiles))
    
    for tile in tiles {
        new_pos := Position{
            row = tile.row + b.row_offset,
            col = tile.col + b.col_offset,
        }
        append(&moved_tiles, new_pos)
    }
    
    return moved_tiles[:]
}

block_rotate :: proc(b: ^Block) {
    b.rotation_state += 1
    if b.rotation_state == len(b.cells) {
        b.rotation_state = 0
    }
}

block_undo_rotation :: proc(b: ^Block) {
    b.rotation_state -= 1
    if b.rotation_state == -1 {
        b.rotation_state = len(b.cells) - 1
    }
}

move_block_left :: proc(g: ^Game) {
    if !g.game_over {
        block_move(&g.current_block, 0, -1)
        if is_block_outside(g) || !block_fits(g) {
            block_move(&g.current_block, 0, 1)
        }
    }
}

move_block_right :: proc(g: ^Game) {
    if !g.game_over {
        block_move(&g.current_block, 0, 1)
        if is_block_outside(g) || !block_fits(g) {
            block_move(&g.current_block, 0, -1)
        }
    }
}

move_block_down :: proc(g: ^Game) {
    if !g.game_over {
        block_move(&g.current_block, 1, 0)
        if is_block_outside(g) || !block_fits(g) {
            block_move(&g.current_block, -1, 0)
            lock_block(g)
        }
    }
}

is_block_outside :: proc(g: ^Game) -> bool {
    tiles := block_cell_position(&g.current_block)
    defer delete(tiles)
    
    for tile in tiles {
        if grid_is_cell_outside(&g.grid, tile.row, tile.col) {
            return true
        }
    }
    return false
}

rotate_block :: proc(g: ^Game) {
    if !g.game_over {
        block_rotate(&g.current_block)
        if is_block_outside(g) || !block_fits(g) {
            block_undo_rotation(&g.current_block)
        } else {
            rl.PlaySound(g.rotate_sound)
        }
    }
}

lock_block :: proc(g: ^Game) {
    tiles := block_cell_position(&g.current_block)
    defer delete(tiles)
    
    for tile in tiles {
        g.grid.grid[tile.row][tile.col] = g.current_block.id
    }
    
    g.current_block = g.next_block
    if !block_fits(g) {
        g.game_over = true
    }
    g.next_block = random_block(g)
    
    rows_cleared := grid_clear_full_rows(&g.grid)
    if rows_cleared > 0 {
        rl.PlaySound(g.clear_sound)
        game_update_score(g, rows_cleared, 0)
    }
}

block_fits :: proc(g: ^Game) -> bool {
    tiles := block_cell_position(&g.current_block)
    defer delete(tiles)
    
    for tile in tiles {
        if !grid_is_cell_empty(&g.grid, tile.row, tile.col) {
            return false
        }
    }
    return true
}
