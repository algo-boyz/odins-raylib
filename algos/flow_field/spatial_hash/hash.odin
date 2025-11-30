package spatial_hash

import "core:slice"
import "core:math"

Point :: struct { x, y: f32 }

SpatialHash :: struct { cells: map[i64][dynamic]int, cell_size: f32 }

get_hash_key :: proc(pos: Point, cell_size: f32) -> i64 {
    return i64(pos.x / cell_size) + i64(pos.y / cell_size) * 10000
}

init :: proc(hash: ^SpatialHash) {
    hash.cell_size = 8.0
    hash.cells = make(map[i64][dynamic]int)
}

clear :: proc(hash: ^SpatialHash) {
    for key in hash.cells { 
        hash.cells[key] = make([dynamic]int)
    }
}

insert :: proc(hash: ^SpatialHash, pos: Point, index: int) {
    key := get_hash_key(pos, hash.cell_size)
    if key not_in hash.cells { 
        hash.cells[key] = make([dynamic]int) 
    }
    append(&hash.cells[key], index)
}

query :: proc(hash: ^SpatialHash, pos: Point, radius: f32, result: ^[dynamic]int) {
    cells_to_check := i32(math.ceil(radius / hash.cell_size)) + 1
    center_x := i64(pos.x / hash.cell_size)
    center_y := i64(pos.y / hash.cell_size)
    for dy in -cells_to_check..=cells_to_check {
        for dx in -cells_to_check..=cells_to_check {
            key := (center_x + i64(dx)) + (center_y + i64(dy)) * 10000
            if key in hash.cells {
                for idx in hash.cells[key] { 
                    append(result, idx) 
                }
            }
        }
    }
}

destroy :: proc(hash: ^SpatialHash) {
    for key in hash.cells { 
        delete(hash.cells[key]) 
    }
    delete(hash.cells)
}