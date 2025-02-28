package astar

SCREEN_WIDTH:i32 = 1400
SCREEN_HEIGHT:i32 = 900

MAX_FONTS :: 8
MAX_MESSAGE_LENGTH :: 100

GRID_ROW_COUNT:i32 = 20
GRID_COLUMN_COUNT:i32 = 40

CELL_OBSTACLE :: 1
CELL_VISITED :: 2
CELL_RESULT :: 3

STATE_PAUSED :: 1

APP_TITLE:cstring = "A* Visualizer"
OBSTACLES_TEXT:cstring = "Obstacles"
SOURCE_TEXT:cstring = "Source"
DESTINATION_TEXT:cstring = "Destination"
OBSTACLES_STATUS_TEXT:cstring = "Select obstacles"
SOURCE_STATUS_TEXT:cstring = "Select souce"
DESTINATION_STATUS_TEXT:cstring = "Select destination"
ADD_TEXT:cstring = "Add"
REMOVE_TEXT:cstring = "Del"
SPEED_INSTANT_TEXT:string = "Instant"
SPEED_FAST_TEXT:string = "Fast"
SPEED_MEDIUM_TEXT:string = "Medium"
SPEED_SLOW_TEXT:string = "Slow"
PLAY_TEXT:cstring = "Play"
PAUSE_TEXT:cstring = "Pause"
RESET_TEXT:cstring = "Reset"
CLEAR_TEXT:cstring = "Clear"
SELECT_SOURCE_TEXT:cstring = "Please select a source cell"
SELECT_DESTINATION_TEXT:cstring = "Please select a destination cell"
FOUND_PATH_TEXT:cstring = "Path found"
NOT_FOUND_PATH_TEXT:cstring = "Path not found"

FAST_SLEEP_MS :: 10
MEDIUM_SLEEP_MS :: 100
SLOW_SLEEP_MS :: 200

State :: enum {
    Idle,
    Playing,
    Paused,
}

CellState :: enum {
    Free,
    Visited,
    Result,
    Source,
    Destination,
    Obstacle,
}

Item :: enum {
    Obstacles,
    Source,
    Destination,
}

Tool :: enum {
    Add,
    Remove,
}

Speed :: enum {
    Instant,
    Fast,
    Medium,
    Slow,
}

Status :: struct {
    message_type: MsgType,
    message: cstring
}

MsgType :: enum {
    Normal,
    Warning,
    Error,
    Success,
}
