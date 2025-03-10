package conf

import "core:encoding/json"
import "core:fmt"
import "core:os"
import "core:path/filepath"

import rl "vendor:raylib"

SETTINGS_FILE :: "settings.json"

JsonErr :: union {
    bool,
    json.Error,
    json.Unmarshal_Error,
}

Settings :: struct {
    viscosity:      f32,
    gravity:        f32,
    wall_repel:     f32,
    bound_width:    i32,
    bound_height:   i32,
    bounded:        bool,
    motion_blur:    bool,
    synced:         bool        `json:"-"`,
    green, red, white, yellow:  ColorGroup,
}

ColorGroup :: struct {
    positions: [dynamic]rl.Vector2,
    velocities: [dynamic]rl.Vector2,
    color: rl.Color,
    count: int,
}

default_settings := Settings {
    viscosity = 0.5,
    gravity = 0,
    wall_repel = 1,
    bound_width = 900,
    bound_height = 600,
    bounded = true,
    motion_blur = false,
    synced = false,
}

load_settings :: proc(
    path: string,
    allocator := context.temp_allocator,
) -> (
    result: Settings,
    err: JsonErr,
) {
    defer if err != nil {
        result = default_settings
    }
    data := os.read_entire_file(path, context.temp_allocator) or_return
    json.unmarshal(data, &result, json.DEFAULT_SPECIFICATION, allocator) or_return
    return result, nil
}

save_settings :: proc(path: string, settings: ^Settings) {
    data, err := json.marshal(settings^, {pretty = true}, context.temp_allocator)
    if err != nil {
        fmt.println("Error marshal settings: ", err)
        return
    }
    if ok := os.write_entire_file(SETTINGS_FILE, data); ok {
        fmt.println("Settings saved")
        settings.synced = true
        return
    }
    fmt.println("Error saving settings")
}

