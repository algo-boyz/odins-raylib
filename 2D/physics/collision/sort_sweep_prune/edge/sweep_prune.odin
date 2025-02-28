package main

import rl "vendor:raylib"
import "core:fmt"

Edge :: struct {
    value: f32,
    is_start: bool,
    index: i32,
}

edges: [dynamic]Edge

//Populate the Edge Array
populate_edge_array :: proc(key: i32) {
    value := enemies[key]
    start := value.position.x
    end := value.position.x + value.width

    append(&edges, Edge{value = start, is_start = true, index = key})
    append(&edges, Edge{value = end, is_start = false, index = key})
}

//Sort by X value
sort_edges :: proc(a, b: Edge) -> int {
    return int(a.value - b.value)
}

//Sort using optimised insertion sort
insertion_sort_edges :: proc() {
    for i := 1; i < len(edges); i += 1 {
        insert_index := i
        key := edges[i]

        for j := i-1; j >= 0; j -= 1 {
            //Sort by smallest value first
            if edges[j].value > key.value {
                edges[j+1] = edges[j]
                insert_index = j
            } else {
                break
            }
        }
        edges[insert_index] = key
    }
}

sweep_prune :: proc() {
    COLLISIONS = 0
    TOTAL_CHECKS = 0

    active_entities := make([dynamic]i32)
    defer delete(active_entities)

    for &edge, i in edges {
        TOTAL_CHECKS += 1

        _, ok := enemies[edge.index]
        if !ok {
            ordered_remove(&edges, i)
            continue 
        }

        //Check if the edge is the left side of the object on X axis
        if edge.is_start {
            edge.value = enemies[edge.index].position.x
            //Check other active edges and see if they intersect
            for other in active_entities {
                TOTAL_CHECKS += 1

                r1 := rl.Rectangle{
                    x = enemies[other].position.x,
                    y = enemies[other].position.y,
                    width = enemies[other].width,
                    height = enemies[other].height
                }

                r2 := rl.Rectangle{
                    x = enemies[edge.index].position.x,
                    y = enemies[edge.index].position.y,
                    width = enemies[edge.index].width,
                    height = enemies[edge.index].height
                }
                if rl.CheckCollisionRecs(r1, r2) {
                    COLLISIONS += 1
                    e_1 := enemies[edge.index]
                    e_2 := enemies[other]
                    e_1.collided = true
                    e_2.collided = true
                    enemies[edge.index] = e_1
                    enemies[other] = e_2
                } else {
                    e_1 := enemies[edge.index]
                    e_2 := enemies[other]
                    e_1.collided = false
                    e_2.collided = false
                    enemies[edge.index] = e_1
                    enemies[other] = e_2
                }
            }
            append(&active_entities, edge.index)
        } else {
            //If not start remove it from the active entities list
            edge.value = enemies[edge.index].position.x + enemies[edge.index].width
            index_to_remove := -1
            for active_entity, i in active_entities {
                if active_entity == edge.index {
                    index_to_remove = i
                    break
                }
            }
            if index_to_remove != -1 {
                ordered_remove(&active_entities, index_to_remove)
            }
        }
    }
}


// //A simple sweep that breaks the loop if X position is greater.
// simple_sweep :: proc() {
//     TOTAL_CHECKS = 0
//     COLLISIONS = 0

//     for index in enemies {
//         enemy := &enemies[index]
//         enemy.position.x += enemy.velocity.x
//         enemy.position.y += enemy.velocity.y

//         if enemy.position.x >= (SCREEN_WIDTH - enemy.width/2) || enemy.position.x <= enemy.width/2 {
//             enemy.velocity.x *= -1
//         }
//         if enemy.position.y >= (SCREEN_HEIGHT - enemy.height/2) || enemy.position.y <= enemy.height/2 { 
//             enemy.velocity.y *= -1
//         }
//         rect := rl.Rectangle{
//             x = enemy.position.x,
//             y = enemy.position.y,
//             width = enemy.width,
//             height = enemy.height
//         }

//         for index_2, enemy_2 in enemies {
//             rect_2 := rl.Rectangle{
//                 x = enemy_2.position.x,
//                 y = enemy_2.position.y,
//                 width = enemy_2.width,
//                 height = enemy_2.height
//             }

//             //If X is greater than current object x then it is not possible they will collide
//             if rect_2.x >= rect.x + rect.width || index == index_2 {
//                 break;
//             }

//             TOTAL_CHECKS += 1

//             if (rl.CheckCollisionRecs(rect, rect_2)) {
//                 COLLISIONS += 1
//             }
//         }
        
//     }
// }

// overlap_x :: proc(a, b: rl.Rectangle) -> bool {
//     if a.y < b.y + b.height && a.y + a.height > b.y {
//         COLLISIONS += 1
//         return true
//     }
//     return false
// }

// intersects :: proc(rec1, rec2: rl.Rectangle) -> bool {
//     return (rec1.x <= rec2.x + rec2.width && 
//             rec1.x + rec1.width >= rec2.x && 
//             rec1.y <= rec2.y + rec2.height &&
//             rec1.y + rec1.height >= rec2.y)
// }
