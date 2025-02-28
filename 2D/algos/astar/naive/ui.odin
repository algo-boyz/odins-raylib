package astar

import "core:fmt"
import "core:strings"

import rl "vendor:raylib"

// UI Font
UI_FONT_PATH:cstring = "assets/romulus.png"
font: rl.Font

// UI Colors
UI_WINDOW_BG_COLOR := rl.Color{ 9, 9, 11, 255 }
UI_CONTAINER_BG_COLOR := rl.Color{ 39, 39, 42, 255 }

UI_TEXT_COLOR := rl.Color{ 212, 212, 216, 255 }
UI_TEXT_WARNING_COLOR := rl.Color{ 251, 191, 36, 255 }
UI_TEXT_ERROR_COLOR := rl.Color{ 248, 113, 113, 255 }
UI_TEXT_SUCCESS_COLOR := rl.Color{ 74, 222, 128, 255 }

UI_CELL_FREE_COLOR := rl.Color{ 115, 115, 115, 255 }
UI_CELL_VISITED_COLOR := rl.Color{ 251, 113, 133, 255 }
UI_CELL_RESULT_COLOR := rl.Color{ 74, 222, 128, 255 }
UI_CELL_OBSTACLE_COLOR := rl.Color{ 0, 0, 0, 255 }
UI_CELL_SOURCE_COLOR := rl.Color{ 167, 139, 250, 255 }
UI_CELL_DESTINATION_COLOR := rl.Color{ 251, 191, 36, 255 }

UI_SELECTED_ITEM_COLOR := rl.Color{ 251, 146, 60, 255 }
UI_SELECTED_TOOL_COLOR := rl.Color{ 34, 211, 238, 255 }

UI_DISABLED_COLOR := rl.Color{ 163, 163, 163, 255 }

// UI Values
UI_ROUNDNESS_LG:f32: 0.05
UI_ROUNDNESS_SM:f32: 0.01

UI_TEXT_SIZE_XL:f32: 5.0
UI_TEXT_SPACING_XL:f32: 8.0
UI_TEXT_SIZE_MD:f32: 3.0
UI_TEXT_SPACING_MD:f32: 4.0
UI_TEXT_SIZE_SM:f32: 2.5
UI_TEXT_SPACING_SM:f32: 1.0

UI_TEXT_ITEM_SIZE:f32: UI_TEXT_SIZE_SM
UI_TEXT_ITEM_SPACING:f32: UI_TEXT_SPACING_SM

UI_TEXT_TOOL_SIZE:f32: UI_TEXT_SIZE_SM
UI_TEXT_TOOL_SPACING:f32: UI_TEXT_SPACING_SM

UI_TEXT_ACTION_SIZE:f32: UI_TEXT_SIZE_SM
UI_TEXT_ACTION_SPACING:f32: UI_TEXT_SPACING_SM

UI_WINDOW_PADDING := rl.Vector2{ 20.0, 20.0 }

UI_CONTAINER_PADDING := rl.Vector2{ 20.0, 10.0 }
UI_CONTAINER_SPACING := rl.Vector2{ 20.0, 20.0 }

UI_GRID_PADDING := rl.Vector2{ 12.0, 7.0 }
UI_GRID_SPACING := rl.Vector2{ 7.0, 7.0 }

UI_ITEMS_SPACING := rl.Vector2{ 30.0, 0.0 }
UI_TOOLS_SPACING := rl.Vector2{ 30.0, 0.0 }
UI_ACTIONS_SPACING := rl.Vector2{ 30.0, 0.0 }

// UI Elements
ui_menu_bar: rl.Rectangle
ui_status_bar: rl.Rectangle
ui_grid: rl.Rectangle
ui_obstacles_button: rl.Rectangle
ui_source_button: rl.Rectangle
ui_destination_button: rl.Rectangle
ui_add_button: rl.Rectangle
ui_remove_button: rl.Rectangle
ui_speed_button: rl.Rectangle
ui_play_button: rl.Rectangle
ui_reset_button: rl.Rectangle
ui_clear_button: rl.Rectangle

ui_title_text: rl.Vector2
ui_cell: rl.Vector2
ui_status_position: rl.Vector2

// UI Functions
// Centers a point vertically within a rectangle
V_CENTER :: proc(a: rl.Rectangle, b: rl.Vector2) -> f32 {
    return a.y + ((a.height - b.y) / 2)
}

// Converts a Rectangle's position to a Vector2
REC2VEC :: proc(a: rl.Rectangle) -> rl.Vector2 {
    return rl.Vector2{a.x, a.y}
}

ui_init_fonts :: proc() {
  font = rl.LoadFont(UI_FONT_PATH)
}

ui_calculate ::proc() {
    ui_status_bar = rl.Rectangle{
        UI_WINDOW_PADDING.x,
        UI_WINDOW_PADDING.y,
        f32(rl.GetScreenWidth()) - (2 * UI_WINDOW_PADDING.x),
        80.0
    }

    ui_menu_bar = rl.Rectangle{
        UI_WINDOW_PADDING.x,
        f32(rl.GetScreenHeight()) - UI_WINDOW_PADDING.y - 80.0,
        f32(rl.GetScreenWidth()) - (2 * UI_WINDOW_PADDING.x),
        80.0
    }

    ui_grid = rl.Rectangle{
        UI_WINDOW_PADDING.x,
        ui_menu_bar.height + UI_WINDOW_PADDING.y + UI_CONTAINER_SPACING.y,
        f32(rl.GetScreenWidth()) - (2 * UI_WINDOW_PADDING.x),
        f32(rl.GetScreenHeight()) - (2 * UI_CONTAINER_SPACING.y) - (2 * UI_WINDOW_PADDING.y) - ui_menu_bar.height - ui_status_bar.height
    }

    ui_title_text = rl.Vector2{
        UI_WINDOW_PADDING.x + UI_CONTAINER_PADDING.x,
        UI_WINDOW_PADDING.y + UI_CONTAINER_PADDING.y,
    }

    ui_cell = rl.Vector2{
        (ui_grid.width - UI_CONTAINER_PADDING.x - (UI_GRID_SPACING.x * f32(GRID_COLUMN_COUNT))) / f32(GRID_COLUMN_COUNT),
        (ui_grid.height - UI_CONTAINER_PADDING.y - (UI_GRID_SPACING.y * f32(GRID_ROW_COUNT))) / f32(GRID_ROW_COUNT),
    }
    fontBaseSize := f32(font.baseSize)
    status_measure := rl.MeasureTextEx(font, app_status.message, fontBaseSize * UI_TEXT_SIZE_MD, UI_TEXT_SPACING_MD)
    ui_status_position = rl.Vector2{
        (ui_status_bar.x + ui_status_bar.width) - status_measure.x - UI_CONTAINER_PADDING.x,
        V_CENTER(ui_status_bar, status_measure)
    }

    obstacle_measure := rl.MeasureTextEx(font, OBSTACLES_TEXT, fontBaseSize * UI_TEXT_ITEM_SIZE, UI_TEXT_ITEM_SPACING)
    ui_obstacles_button = rl.Rectangle{
        ui_menu_bar.x + UI_CONTAINER_PADDING.x,
        V_CENTER(ui_menu_bar, obstacle_measure),
        obstacle_measure.x,
        obstacle_measure.y
    }

    source_measure := rl.MeasureTextEx(font, SOURCE_TEXT, fontBaseSize * UI_TEXT_ITEM_SIZE, UI_TEXT_ITEM_SPACING)
    ui_source_button = rl.Rectangle{
        ui_obstacles_button.x + ui_obstacles_button.width + UI_ITEMS_SPACING.x,
        V_CENTER(ui_menu_bar, source_measure),
        source_measure.x,
        source_measure.y
    }

    destination_measure := rl.MeasureTextEx(font, DESTINATION_TEXT, fontBaseSize * UI_TEXT_ITEM_SIZE, UI_TEXT_ITEM_SPACING)
    ui_destination_button = rl.Rectangle{
        ui_source_button.x + ui_source_button.width + UI_ITEMS_SPACING.x,
        V_CENTER(ui_menu_bar, destination_measure),
        destination_measure.x,
        destination_measure.y
    }

    add_measure := rl.MeasureTextEx(font, ADD_TEXT, fontBaseSize * UI_TEXT_TOOL_SIZE, UI_TEXT_TOOL_SPACING)
    remove_measure := rl.MeasureTextEx(font, REMOVE_TEXT, fontBaseSize * UI_TEXT_TOOL_SIZE, UI_TEXT_TOOL_SPACING)
    toolbar_measure := rl.Vector2{
        (ui_menu_bar.width/2) - ((add_measure.x + remove_measure.x + UI_TOOLS_SPACING.x)/2),
        (add_measure.y +remove_measure.y) / 2
    }
    ui_add_button = rl.Rectangle{
        toolbar_measure.x,
        V_CENTER(ui_menu_bar, toolbar_measure),
        add_measure.x,
        add_measure.y
    }
    ui_remove_button = rl.Rectangle{
        ui_add_button.x + ui_add_button.width + UI_TOOLS_SPACING.x,
        V_CENTER(ui_menu_bar, toolbar_measure),
        remove_measure.x,
        remove_measure.y
    }

    clear_measure := rl.MeasureTextEx(font, CLEAR_TEXT, fontBaseSize * UI_TEXT_ACTION_SIZE, UI_TEXT_ACTION_SPACING)
    ui_clear_button = rl.Rectangle{
        (ui_menu_bar.x + ui_menu_bar.width) - UI_CONTAINER_PADDING.x - clear_measure.x,
        V_CENTER(ui_menu_bar,clear_measure),
        clear_measure.x,
        clear_measure.y
    }

    reset_measure := rl.MeasureTextEx(font, RESET_TEXT, fontBaseSize * UI_TEXT_ACTION_SIZE, UI_TEXT_ACTION_SPACING)
    ui_reset_button = rl.Rectangle{
        ui_clear_button.x - UI_ACTIONS_SPACING.x - reset_measure.x,
        V_CENTER(ui_menu_bar,reset_measure),
        reset_measure.x,
        reset_measure.y
    }

    play_measure := rl.MeasureTextEx(font, app_state == State.Playing ? PAUSE_TEXT : PLAY_TEXT, fontBaseSize * UI_TEXT_ACTION_SIZE, UI_TEXT_ACTION_SPACING)
    ui_play_button = rl.Rectangle{
        ui_reset_button.x - UI_ACTIONS_SPACING.x - play_measure.x,
        V_CENTER(ui_menu_bar,play_measure),
        play_measure.x,
        play_measure.y
    }

    speed_text := ui_get_speed_text(speed_selected)
    speed_measure := rl.MeasureTextEx(font, speed_text, fontBaseSize * UI_TEXT_ACTION_SIZE, UI_TEXT_ACTION_SPACING)
    ui_speed_button = rl.Rectangle{
        ui_play_button.x - UI_ACTIONS_SPACING.x - speed_measure.x,
        V_CENTER(ui_menu_bar,speed_measure),
        speed_measure.x,
        speed_measure.y
    }
}

ui_get_status_color ::proc() -> rl.Color {
    switch app_status.message_type {
        case MsgType.Normal:
            return UI_TEXT_COLOR

        case MsgType.Warning:
            return UI_TEXT_WARNING_COLOR

        case MsgType.Error:
            return UI_TEXT_ERROR_COLOR

        case MsgType.Success:
            return UI_TEXT_SUCCESS_COLOR
    }
    return UI_TEXT_COLOR
}

ui_get_cell_color ::proc(column_index, row_index: i32) -> rl.Color {
    switch grid[column_index][row_index] {
        case CellState.Free:
            return UI_CELL_FREE_COLOR

        case CellState.Obstacle:
            return UI_CELL_OBSTACLE_COLOR

        case CellState.Source:
            return UI_CELL_SOURCE_COLOR

        case CellState.Destination:
            return UI_CELL_DESTINATION_COLOR

        case CellState.Visited:
            return UI_CELL_VISITED_COLOR

        case CellState.Result:
            return UI_CELL_RESULT_COLOR
    }
    return UI_CELL_FREE_COLOR
}

ui_get_item_color :: proc(item: Item) -> rl.Color{
  if app_state != State.Idle {
    return UI_DISABLED_COLOR
  }
  if item_selected == item {
    return UI_SELECTED_ITEM_COLOR
  }
  return UI_TEXT_COLOR
}

ui_get_tool_color :: proc(tool: Tool) -> rl.Color{
  if (app_state != State.Idle) {
    return UI_DISABLED_COLOR
  }
  if (tool_selected == tool) {
    return UI_SELECTED_TOOL_COLOR
  }
  return UI_TEXT_COLOR
}

ui_get_speed_text :: proc(speed: Speed) -> cstring {
    text := ""
    switch speed {
        case Speed.Instant:
            text = SPEED_INSTANT_TEXT
        case Speed.Fast:
            text = SPEED_FAST_TEXT
        case Speed.Medium:
            text = SPEED_MEDIUM_TEXT
        case Speed.Slow:
            text = SPEED_SLOW_TEXT
    }
    return fmt.ctprint(text)
}

ui_draw_containers :: proc() {
  rl.DrawRectangleRounded(ui_status_bar, UI_ROUNDNESS_LG, 0, UI_CONTAINER_BG_COLOR)
  rl.DrawRectangleRounded(ui_grid, UI_ROUNDNESS_SM, 0, UI_CONTAINER_BG_COLOR)
  rl.DrawRectangleRounded(ui_menu_bar, UI_ROUNDNESS_LG, 0, UI_CONTAINER_BG_COLOR)
}

ui_draw_text :: proc() {
  speed_text := ui_get_speed_text(speed_selected)
  fontBaseSize := f32(font.baseSize)
  rl.DrawTextEx(font, APP_TITLE, ui_title_text, fontBaseSize * UI_TEXT_SIZE_XL, UI_TEXT_SPACING_XL, UI_TEXT_COLOR)
  rl.DrawTextEx(font, app_status.message, ui_status_position, fontBaseSize * UI_TEXT_SIZE_MD, UI_TEXT_SPACING_MD, ui_get_status_color())
  rl.DrawTextEx(font, OBSTACLES_TEXT, REC2VEC(ui_obstacles_button), fontBaseSize * UI_TEXT_ITEM_SIZE, UI_TEXT_ITEM_SPACING, ui_get_item_color(Item.Obstacles))
  rl.DrawTextEx(font, SOURCE_TEXT, REC2VEC(ui_source_button), fontBaseSize * UI_TEXT_ITEM_SIZE, UI_TEXT_ITEM_SPACING, ui_get_item_color(Item.Source))
  rl.DrawTextEx(font, DESTINATION_TEXT, REC2VEC(ui_destination_button), fontBaseSize * UI_TEXT_ITEM_SIZE, UI_TEXT_ITEM_SPACING, ui_get_item_color(Item.Destination))
  rl.DrawTextEx(font, ADD_TEXT, REC2VEC(ui_add_button), fontBaseSize * UI_TEXT_TOOL_SIZE, UI_TEXT_TOOL_SPACING, ui_get_tool_color(Tool.Add))
  rl.DrawTextEx(font, REMOVE_TEXT, REC2VEC(ui_remove_button), fontBaseSize * UI_TEXT_TOOL_SIZE, UI_TEXT_TOOL_SPACING, ui_get_tool_color(Tool.Remove))
  rl.DrawTextEx(font, CLEAR_TEXT, REC2VEC(ui_clear_button), fontBaseSize * UI_TEXT_ACTION_SIZE, UI_TEXT_ACTION_SPACING, UI_TEXT_COLOR)
  rl.DrawTextEx(font, RESET_TEXT, REC2VEC(ui_reset_button), fontBaseSize * UI_TEXT_ACTION_SIZE, UI_TEXT_ACTION_SPACING, UI_TEXT_COLOR)
  rl.DrawTextEx(font, app_state == State.Playing ? PAUSE_TEXT : PLAY_TEXT, REC2VEC(ui_play_button), fontBaseSize * UI_TEXT_ACTION_SIZE, UI_TEXT_ACTION_SPACING, UI_TEXT_COLOR)
  rl.DrawTextEx(font, speed_text, REC2VEC(ui_speed_button), fontBaseSize * UI_TEXT_ACTION_SIZE, UI_TEXT_ACTION_SPACING, UI_TEXT_SUCCESS_COLOR)
}

ui_draw_grid :: proc() {
    for i in 0..<GRID_COLUMN_COUNT {
        for j in 0..<GRID_ROW_COUNT {
            cell := rl.Rectangle{
                ui_grid.x + UI_GRID_PADDING.x + (f32(i) * UI_GRID_SPACING.x) + (f32(i) * ui_cell.x),
                ui_grid.y + UI_GRID_PADDING.y + (f32(j) * UI_GRID_SPACING.y) + (f32(j) * ui_cell.y),
                ui_cell.x,
                ui_cell.y
            }
            rl.DrawRectangleRounded(cell, 0.15, 0, ui_get_cell_color(i, j))
        }
    }
}