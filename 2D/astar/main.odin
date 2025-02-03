package astar

import "core:container/priority_queue"
import "core:fmt"
import "core:thread"

import rl "vendor:raylib"

main :: proc() {
    rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "A* Visualizer")
    rl.SetTargetFPS(60)
  
    init_grid()
    init_state()
    init_status()
    init_items()
    init_tools()
    init_speed()
    init_cells()
    ui_init_fonts()
  
    t: ^thread.Thread

    // Game loop
    for !rl.WindowShouldClose() {
        rl.BeginDrawing()
        rl.ClearBackground(UI_WINDOW_BG_COLOR)
        ui_calculate()
        ui_draw_containers()
        ui_draw_text()
        ui_draw_grid()
        rl.EndDrawing()
    
        mouse := rl.GetMousePosition()
        if rl.IsMouseButtonDown(rl.MouseButton.LEFT) {
            if rl.CheckCollisionPointRec(mouse, ui_grid) {
                mx := mouse.x - ui_grid.x - UI_GRID_PADDING.x
                my := mouse.y - ui_grid.y - UI_GRID_PADDING.y
                mx = mx < 0 ? 0 : mx
                my = my < 0 ? 0 : my
                column_index := mx / (ui_cell.x + UI_GRID_SPACING.x)
                row_index := my / (ui_cell.y + UI_GRID_SPACING.y)
                select_cell(i32(column_index), i32(row_index))
            }
        }
        if rl.IsMouseButtonPressed(rl.MouseButton.LEFT) {
            if rl.CheckCollisionPointRec(mouse, ui_obstacles_button) {
                select_item(Item.Obstacles)
            }
            else if rl.CheckCollisionPointRec(mouse, ui_source_button) {
                select_item(Item.Source)
            }
            else if rl.CheckCollisionPointRec(mouse, ui_destination_button) {
                select_item(Item.Destination)
            }
            else if rl.CheckCollisionPointRec(mouse, ui_add_button) {
                select_tool(Tool.Add)
            }
            else if rl.CheckCollisionPointRec(mouse, ui_remove_button) {
                select_tool(Tool.Remove)
            }
            else if rl.CheckCollisionPointRec(mouse, ui_speed_button) {
                cycle_speed()
            }
            else if rl.CheckCollisionPointRec(mouse, ui_play_button) {
                t = play()
            }
            else if rl.CheckCollisionPointRec(mouse, ui_clear_button) {
                clear(t)
            }
            else if rl.CheckCollisionPointRec(mouse, ui_reset_button) {
                reset(t)
            }
        }
    }
    // Clean
    rl.CloseWindow()
    rl.UnloadFont(font)
    if t != nil {
        thread.join(t) // waits for thread to finish and will block until done
        thread.destroy(t)
    }
    free_grid()
}

play :: proc() -> ^thread.Thread {
    if app_state == State.Playing {
        set_state(State.Paused)
        return nil
    }
    else if app_state == State.Paused {
        set_state(State.Playing)
        return nil
    }

    if source_cell.x == -1 || source_cell.y == -1 {
        set_status(SELECT_SOURCE_TEXT, MsgType.Error)
        return nil
    }

    if destination_cell.x == -1 || destination_cell.y == -1 {
        set_status(SELECT_DESTINATION_TEXT, MsgType.Error)
        return nil
    }

    set_state(State.Playing)
    t := thread.create(asv)
    assert(t != nil)
    thread.start(t)
    return t
}

clear :: proc(t: ^thread.Thread) {
    for i in 0..<GRID_COLUMN_COUNT {
        for j in 0..<GRID_ROW_COUNT {
            grid[i][j] = CellState.Free
        }
    }
    if app_state != State.Idle {
        thread.terminate(t, 0)
    }
    source_cell = rl.Vector2{ -1, -1}
    destination_cell = rl.Vector2{ -1, -1}
    set_state(State.Idle)
    select_tool(Tool.Add)
    select_item(Item.Obstacles)
}

reset :: proc(t: ^thread.Thread) {
    for i in 0..<GRID_COLUMN_COUNT {
        for j in 0..<GRID_ROW_COUNT {
            if grid[i][j] == CellState.Visited || grid[i][j] == CellState.Result {
                grid[i][j] = CellState.Free
            }
        }
    }
    if (app_state != State.Idle) {
        thread.terminate(t, 0)
    }
    set_state(State.Idle)
    select_tool(Tool.Add)
    select_item(Item.Obstacles)
}


asv :: proc(t: ^thread.Thread) {
    found := false

    // Initialize open set (priority queue)
    open_set: PQueue
    priority_queue.init(&open_set, cell_less, swap)
    cost_src := cost(source_cell)
    priority_queue.push(&open_set, Cell{source_cell, cost_src})

    // Initialize maps
    came_from := make(map[i32]i32)
    g_score := make(map[i32]i32)
    f_score := make(map[i32]i32)
    visited := make(map[i32]i32)

    g_score[compress(source_cell)] = 0
    f_score[compress(source_cell)] = cost_src

    result: PQueue
    priority_queue.init(&result, cell_less, swap)
    defer {
        priority_queue.destroy(&result)
        priority_queue.destroy(&open_set)
        delete(g_score)
        delete(f_score)
        delete(visited)
        delete(came_from)
    }
    for priority_queue.len(open_set) > 0 {
        for app_state == State.Paused {
            sleep(500)
        }

        current := priority_queue.pop(&open_set).pos
        visited[compress(current)] = 1

        if current.x == destination_cell.x && current.y == destination_cell.y {
            priority := GRID_ROW_COUNT * GRID_COLUMN_COUNT

            for {
                check, ok := came_from[compress(current)]
                if !ok do break

                current = expand(f32(check))
                priority_queue.push(&result, Cell{current, priority})
                priority -= 1
            }

            found = true
            break
        }

        current_g, ok := g_score[compress(current)]
        if !ok {
            current_g = -1
        }
        new_g := current_g + 1
        new_f:i32 = -1

        if current.x != source_cell.x || current.y != source_cell.y {
                grid[int(current.x)][int(current.y)] = CellState.Visited
        }

        neighbors_delta := [4]rl.Vector2{{-1, 0}, {1, 0}, {0, -1}, {0, 1}}

        for delta in neighbors_delta {
            neighbor_cell := rl.Vector2{
                    current.x + delta.x,
                    current.y + delta.y,
            }

            if neighbor_cell.x < 0 || 
                    i32(neighbor_cell.x) >= GRID_COLUMN_COUNT ||
                    neighbor_cell.y < 0 || 
                    i32(neighbor_cell.y) >= GRID_ROW_COUNT ||
                    grid[int(neighbor_cell.x)][int(neighbor_cell.y)] == CellState.Obstacle {

                continue
            }

            test_f, test_g:i32
            new_f = new_g + cost(neighbor_cell)

            test_g, ok = g_score[compress(neighbor_cell)]
            if !ok {
                test_g = -1
            }
            if test_g == -1 || test_g > new_g {
                g_score[compress(neighbor_cell)] = new_g
                came_from[compress(neighbor_cell)] = compress(current)
            }

            test_f, ok = f_score[compress(neighbor_cell)]
            if !ok {
                test_f = -1
            }
            if test_f == -1 || test_f > new_f {
                f_score[compress(neighbor_cell)] = new_f
            }

            _, ok = visited[compress(neighbor_cell)]
            if !ok {
                priority_queue.push(&open_set, Cell{neighbor_cell, new_f})
            }
        }
        end_cycle()
    }

    if found {
        set_status(FOUND_PATH_TEXT, MsgType.Success)
        for priority_queue.len(result) > 0 {
            for app_state == State.Paused {
                sleep(500)
            }

            t := priority_queue.pop(&result).pos

            if t.x != source_cell.x || t.y != source_cell.y {
                grid[int(t.x)][int(t.y)] = CellState.Result
            }
            end_cycle()
        }
    } else {
        set_status(NOT_FOUND_PATH_TEXT, MsgType.Error)
    }
}