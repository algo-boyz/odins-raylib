package astar

import "core:container/priority_queue"
import "core:math"
import "core:time"
import "core:thread"

import rl "vendor:raylib"

PQueue :: priority_queue.Priority_Queue(Cell)

grid: [][]CellState
app_status: Status
app_state: State
item_selected: Item
tool_selected: Tool
speed_selected: Speed

source_cell: rl.Vector2
destination_cell: rl.Vector2

// Allocate each row and initialize cells to FREE
init_grid :: proc() {
    grid = make([][]CellState, GRID_COLUMN_COUNT)
    for i in 0..<GRID_COLUMN_COUNT {
        grid[i] = make([]CellState, GRID_ROW_COUNT)
        for j in 0..<GRID_ROW_COUNT {
            grid[i][j] = CellState.Free
        }
    }
}

// Init state to idle
init_state :: proc() {
    set_state(State.Idle)
}

init_status :: proc() {
    set_status(OBSTACLES_STATUS_TEXT, MsgType.Normal)
}

init_items :: proc() {
    select_item(Item.Obstacles)
}

init_tools :: proc() {
    select_tool(Tool.Add)
}

init_speed :: proc() {
    select_speed(Speed.Instant)
}

init_cells :: proc() {
    source_cell = rl.Vector2{ -1, -1}
    destination_cell = rl.Vector2{ -1, -1}
}

set_state :: proc(state: State) {
    app_state = state
}

set_status :: proc(message: cstring, type: MsgType) {
    app_status.message_type = type
    app_status.message = message
}

select_item :: proc(item: Item) {
    if app_state != State.Idle {
        return
    }

    item_selected = item

    if item == Item.Obstacles {
        set_status(OBSTACLES_STATUS_TEXT, MsgType.Normal)
    }
    else if item == Item.Source {
        set_status(SOURCE_STATUS_TEXT, MsgType.Normal)
    }
    else if item == Item.Destination {
        set_status(DESTINATION_STATUS_TEXT, MsgType.Success)
    }
}

select_tool :: proc(tool: Tool) {
    if app_state != State.Idle {
        return
    }

    tool_selected = tool
}

select_speed :: proc (speed: Speed) {
    speed_selected = speed
}

select_cell :: proc(column_index, row_index: i32) {
    if app_state != State.Idle {
        return
    }
    switch item_selected {
        case Item.Obstacles:
            if tool_selected == Tool.Add {
                grid[column_index][row_index] = CellState.Obstacle
            }
            else if tool_selected == Tool.Remove && 
                grid[column_index][row_index] == CellState.Obstacle {
                grid[column_index][row_index] = CellState.Free
            }
        case Item.Source:
            if tool_selected == Tool.Add && source_cell.x == -1 {
                grid[column_index][row_index] = CellState.Source
                source_cell = rl.Vector2{ f32(column_index), f32(row_index)}
            }
            else if tool_selected == Tool.Remove && 
                grid[column_index][row_index] == CellState.Source {
                grid[column_index][row_index] = CellState.Free
                source_cell = rl.Vector2{ -1, -1}
            }
        case Item.Destination:
            if tool_selected == Tool.Add && destination_cell.x == -1 {
                grid[column_index][row_index] = CellState.Destination
                destination_cell = rl.Vector2{ f32(column_index), f32(row_index)}
            }
            else if tool_selected == Tool.Remove && grid[column_index][row_index] == CellState.Destination {
                grid[column_index][row_index] = CellState.Free
                destination_cell = rl.Vector2{ -1, -1}
            }
        break
    }
}

cycle_speed :: proc() {
    speed := int(speed_selected) - 1
    if speed < 0 {
        speed = int(Speed.Slow)
    }
    select_speed(Speed(speed))
}

free_grid :: proc() {
  for i in 0..<GRID_COLUMN_COUNT {
    delete(grid[i])
  }
  delete(grid)
}

end_cycle :: proc() {
    switch (speed_selected) {
        case Speed.Instant:
        case Speed.Fast:
            sleep(FAST_SLEEP_MS)
        case Speed.Medium:
            sleep(MEDIUM_SLEEP_MS)
        case Speed.Slow:
            sleep(SLOW_SLEEP_MS)
    }
}

distance :: proc(a, b: rl.Vector2) -> f32 {
    return abs((a.x - b.x)) + abs(a.y - b.y)
}
  
compress :: proc(a: rl.Vector2) -> i32 {
    x := a.x
    y := a.y
    return i32(((x + y) * (x + y + 1) / 2) + y)
}

expand :: proc(a: f32) -> rl.Vector2 {
    w := (math.sqrt_f32(8 * a + 1) - 1) / 2
    t := (w * (w + 1)) / 2
    y := a - t;
    x := w - y;
    return rl.Vector2{ x, y}
}

cost :: proc(a: rl.Vector2) -> i32 {
    return i32(distance(a, destination_cell))
}
  
sleep :: proc(ms: i32) {
    time.sleep(time.Duration(ms) * time.Millisecond)
}

Cell :: struct {
    pos: rl.Vector2,
    f_score: i32,
}

cell_less :: proc(a, b: Cell) -> bool {
    return a.f_score < b.f_score
}

swap :: proc(q: []Cell, i, j: int) {
    q[i], q[j] = q[j], q[i]
}