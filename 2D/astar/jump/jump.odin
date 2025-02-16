
// MIT (c) 2025 by Chris
// https://github.com/ChrisPHP/odin-jps

package jps

import "core:fmt"
import "core:math"
import "core:time"
import pq "core:container/priority_queue"

Heuristics_Type :: enum {
    euclidean,
    manhatten,
    manhatten_octile,
    chebyshev
}

Point :: [2]int
Matrix :: []int

Node :: struct {
    position: [2]int,
    g: int,
    h: int,
    f: f32,
}

GRID_WIDTH := 0
GRID_HEIGHT := 0
HEURISTICS := Heuristics_Type.euclidean

new_node :: proc(position: [2]int = {}, fscore: f32 = 0.0) -> ^Node {
    jps_node := new(Node)
    jps_node.position = position
    jps_node.g = 0
    jps_node.h = 0
    jps_node.f = fscore
    return jps_node
}

cost :: proc(a, b: ^Node) -> bool {
    return a.f < b.f
}

dblock :: proc(cX, cY, dX, dY: int, maze: Matrix) -> bool {
    size_x := cY * GRID_WIDTH + (cX - dX)
    size_y := (cY - dY) * GRID_WIDTH + cX
    return maze[size_x] == 1 && maze[size_y] == 1
}

direction :: proc(cX, cY, pX, pY: int) -> (dX: int, dY: int) {
    dX = int(math.sign(f64(cX - pX)))
    dY = int(math.sign(f64(cY - pY)))
    
    if cX - pX == 0 {
        dX = 0
    }
    if cY - pY == 0 {
        dY = 0
    }
    
    return dX, dY
}

blocked :: proc(cX, cY, dX, dY: int, maze: Matrix) -> bool {
    size_x := cY * GRID_WIDTH + (cX + dX)
    size_y := (cY + dY) * GRID_WIDTH + cX
    size_xy := (cY + dY) * GRID_WIDTH + (cX + dX)
    
    // Check if the new position is out of bounds
    if cX + dX < 0 || cX + dX >= GRID_WIDTH {
        return true
    }
    if cY + dY < 0 || cY + dY >= GRID_HEIGHT {
        return true
    }

    // Check diagonal movement
    if dX != 0 && dY != 0 {
        if maze[size_x] == 1 && maze[size_y] == 1 {
            return true
        }
        if maze[size_xy] == 1 {
            return true
        }
    } else {
        // Check horizontal or vertical movement
        if dX != 0 {
            if maze[size_x] == 1 {
                return true
            }
        } else {
            if maze[size_y] == 1 {
                return true
            }
        }
    }

    return false
}


jump :: proc(cX, cY, dX, dY: int, maze: Matrix, goal: Point) -> (Point, bool) {
    nX := cX + dX
    nY := cY + dY
    point_temp := Point{nX, nY}

    if blocked(nX, nY, 0, 0, maze) {
        return  Point{0, 0}, false
    }
    if point_temp == goal {
        return Point{nX, nY}, true
    }
    
    oX := nX
    oY := nY

    if dX != 0 && dY != 0 {
        for {
            if (!blocked(oX, oY, -dX, dY, maze) && blocked(oX, oY, -dX, 0, maze)) ||
               (!blocked(oX, oY, dX, -dY, maze) && blocked(oX, oY, 0, -dY, maze)) {
                return Point{oX, oY}, true
            }

            _, okY := jump(oX, oY, dX, 0, maze, goal)
            _, okX := jump(oX, oY, 0, dY, maze, goal)
            
            if okY != false || okX != false {
                return Point{oX, oY}, true
            }
            
            oX += dX
            oY += dY
            
            if blocked(oX, oY, 0, 0, maze) {
                return Point{0, 0}, false
            }
            if dblock(oX, oY, dX, dY, maze) {
                return Point{0, 0}, false
            }
            point_temp = Point{oX, oY}
            if point_temp == goal {
                return Point{oX, oY}, true
            }
        }
    } else {
        if dX != 0 {
            for {
                if (!blocked(oX, nY, dX, 1, maze) && blocked(oX, nY, 0, 1, maze)) ||
                   (!blocked(oX, nY, dX, -1, maze) && blocked(oX, nY, 0, -1, maze)) {
                    return Point{oX, nY}, true
                }
                oX += dX
                if blocked(oX, nY, 0, 0, maze) {
                    return Point{0, 0}, false
                }
                point_temp = Point{oX, nY}
                if point_temp == goal {
                    return Point{oX, nY}, true
                }
            }
        } else {
            for {
                if (!blocked(nX, oY, 1, dY, maze) && blocked(nX, oY, 1, 0, maze)) ||
                   (!blocked(nX, oY, -1, dY, maze) && blocked(nX, oY, -1, 0, maze)) {
                    return Point{nX, oY}, true
                }
                oY += dY
                if blocked(nX, oY, 0, 0, maze) {
                    return Point{0, 0}, false
                }
                point_temp = Point{nX, oY}
                if point_temp == goal {
                    return Point{nX, oY}, true
                }
            }
        }
    }
}

heuristics :: proc(p1, p2: Point) ->f32 {
    switch HEURISTICS {
    case .euclidean:
        return math.sqrt_f32(
            math.pow_f32(f32(p1[0] - p2[0]), 2) + math.pow_f32(f32(p1[1] - p2[1]), 2)
        )
    case .manhatten:
        dx := abs(p2[0] - p1[0])
        dy := abs(p2[1] - p1[1])
        return f32(dx + dy)
    case .manhatten_octile:
        dx := abs(p2[0] - p1[0])
        dy := abs(p2[1] - p1[1])
        if dx > dy {
            return f32(dy) + math.SQRT_TWO * f32(dx - dy)   
        } else {
            return f32(dx) + math.SQRT_TWO * f32(dy - dx)
        }
    case .chebyshev:
        dx := abs(p2[0] - p1[0])
        dy := abs(p2[1] - p1[1])
        return f32(max(dx, dy))  
    case: // default
        return math.sqrt_f32(
            math.pow_f32(f32(p1[0] - p2[0]), 2) + math.pow_f32(f32(p1[1] - p2[1]), 2)
        )
    }
}

node_neighbours :: proc(cX, cY: int, parent: [2]int, maze: Matrix) -> []Point {
    neighbours := make([dynamic]Point)

    if parent == {-999, -999} {
        directions := [][2]int{
            {-1, 0}, {0, -1}, {1, 0}, {0, 1},
            {-1, -1}, {-1, 1}, {1, -1}, {1, 1},
        }
        for dir in directions {
            if !blocked(cX, cY, dir[0], dir[1], maze) {
                append(&neighbours, Point{cX + dir[0], cY + dir[1]})
            }
        }
    } else {
        dX, dY := direction(cX, cY, parent[0], parent[1])

        if dX != 0 && dY != 0 {
            if !blocked(cX, cY, 0, dY, maze) {
                append(&neighbours, Point{cX, cY + dY})
            }
            if !blocked(cX, cY, dX, 0, maze) {
                append(&neighbours, Point{cX + dX, cY})
            }
            if (!blocked(cX, cY, 0, dY, maze) || !blocked(cX, cY, dX, 0, maze)) && 
               !blocked(cX, cY, dX, dY, maze) {
                append(&neighbours, Point{cX + dX, cY + dY})
            }
            if blocked(cX, cY, -dX, 0, maze) && !blocked(cX, cY, 0, dY, maze) {
                append(&neighbours, Point{cX - dX, cY + dY})
            }
            if blocked(cX, cY, 0, -dY, maze) && !blocked(cX, cY, dX, 0, maze) {
                append(&neighbours, Point{cX + dX, cY - dY})
            }
        } else {
            if dX == 0 {
                if !blocked(cX, cY, dX, 0, maze) {
                    if !blocked(cX, cY, 0, dY, maze) {
                        append(&neighbours, Point{cX, cY + dY})
                    }
                    if blocked(cX, cY, 1, 0, maze) {
                        append(&neighbours, Point{cX + 1, cY + dY})
                    }
                    if blocked(cX, cY, -1, 0, maze) {
                        append(&neighbours, Point{cX - 1, cY + dY})
                    }
                }
            } else {
                if !blocked(cX, cY, dX, 0, maze) {
                    if !blocked(cX, cY, dX, 0, maze) {
                        append(&neighbours, Point{cX + dX, cY})
                    }
                    if blocked(cX, cY, 0, 1, maze) {
                        append(&neighbours, Point{cX + dX, cY + 1})
                    }
                    if blocked(cX, cY, 0, -1, maze) {
                        append(&neighbours, Point{cX + dX, cY - 1})
                    }
                }
            }
        }
    }

    return neighbours[:]
}

identify_successor :: proc(pos: [2]int, came_from: map[[2]int][2]int, maze: Matrix, goal: [2]int) -> []Point {
    cX := pos[0]
    cY := pos[1]

    val, ok := came_from[{cX, cY}]
    if !ok {
        val = [2]int{-999,-999}
    }
    successors := make([dynamic]Point)
    neighbours := node_neighbours(cX, cY, val, maze)
    defer delete(neighbours)

    for cell in neighbours {
        dX := cell[0] - cX
        dY := cell[1] - cY
        jumpPoint, ok := jump(cX, cY, dX, dY, maze, goal)
        if ok != false {
            append(&successors, jumpPoint)
        }
    }
    
    return successors[:]
}

search :: proc(maze: Matrix, start: [2]int, end: [2]int) -> []Point {
    came_from := make(map[[2]int][2]int)
    defer delete(came_from)
    close_set := make(map[[2]int][2]int)
    defer delete(close_set)
    gscore := make(map[[2]int]f32)
    defer delete(gscore)
    fscore := make(map[[2]int]f32)
    defer delete(fscore)
    gscore[start] = 0
    fscore[start] = heuristics(start, end)

    pqueue: pq.Priority_Queue(^Node)
    pq.init(&pqueue, cost, pq.default_swap_proc(^Node))
    j_node := new_node(start, fscore[start])
    pq.push(&pqueue, j_node)

    current_index := 0
    for pq.len(pqueue) > 0 {
        node :=  pq.pop(&pqueue)
        current := node.position

        if current == end {
            data := make([dynamic]Point)
            for {
                found := false
                for item, index in came_from {
                    if current == item {
                        append(&data, current)
                        current = index
                        found = true
                        break
                    }
                }
                if !found {
                    break
                }
            }
            append(&data, start)

            fixed_data := make([]Point, len(data))
            copy(fixed_data, data[:])
            delete(data)

            //Free remaining nodes from memory
            free(node)
            for pq.len(pqueue) > 0 {
                free_me := pq.pop(&pqueue)
                free(free_me)
            }
            pq.destroy(&pqueue)

            return fixed_data
        }

        close_set[current] = current

        successors := identify_successor(current, came_from, maze, end)
        defer delete(successors)

        for successor in successors {
            next_jump_point :=  successor

            if next_jump_point in close_set {
                continue
            }
        
            tentative_g_score := gscore[current] + heuristics(current, next_jump_point)

            gscore_val, ok := gscore[next_jump_point]
            if tentative_g_score < gscore_val || !ok {
                came_from[next_jump_point] = current
                gscore[next_jump_point] = tentative_g_score
                fscore[next_jump_point] = tentative_g_score + heuristics(next_jump_point, end)
                j_node = new_node(next_jump_point, fscore[next_jump_point])
                pq.push(&pqueue, j_node)
            }
        }
        current_index += 1
        free(node)
    }
    pq.destroy(&pqueue)
   
    return {}
}


init :: proc(width, height: int, heuristic: Heuristics_Type) {
    GRID_WIDTH = width
    GRID_HEIGHT = height
    HEURISTICS = heuristic
}