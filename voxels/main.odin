package main

import "core:fmt"
import "core:math"
import "core:strings"

import rl "vendor:raylib"

SCREEN_WIDTH :: 640
SCREEN_HEIGHT :: 400
FPS :: 60
MAP_N :: 1024
SCALE_FACTOR :: 100.0
NUM_MAPS :: 29

Camera :: struct {
    x: f32,
    y: f32,
    height: f32,
    angle: f32,
    horizon: f32,
    speed: f32,
    rotspeed: f32,
    heightspeed: f32,
    horizonspeed: f32,
    tiltspeed: f32,
    tilt: f32,
    zfar: f32,
}

Map :: struct {
    color_map: cstring,
    height_map: cstring,
}

global_state := struct {
    camera: Camera,
    color_map: [^]rl.Color,
    height_map: [^]rl.Color,
    fog_type: i32,
    fog_density: f32,
    fog_start: f32,
    fog_end: f32,
    selected_map: i32,
    current_selected_map: i32,
    map_selector_mode: bool,
    maps: [NUM_MAPS]Map,
}{
    camera = Camera{
        x = 512,
        y = 512,
        height = 150,
        angle = 1.5 * math.PI,
        horizon = 100,
        speed = 60,
        rotspeed = 0.5,
        heightspeed = 100,
        horizonspeed = 100,
        tiltspeed = 1.5,
        tilt = 0,
        zfar = 600,
    },
    fog_density = 0.0025,
    fog_start = 300.0,
    fog_end = 600.0,
}

process_input :: proc(time_delta: f32) {
    if rl.IsKeyDown(.UP) {
        global_state.camera.x += global_state.camera.speed * math.cos(global_state.camera.angle) * time_delta
        global_state.camera.y += global_state.camera.speed * math.sin(global_state.camera.angle) * time_delta
    }
    if rl.IsKeyDown(.DOWN) {
        global_state.camera.x -= global_state.camera.speed * math.cos(global_state.camera.angle) * time_delta
        global_state.camera.y -= global_state.camera.speed * math.sin(global_state.camera.angle) * time_delta
    }
    if rl.IsKeyDown(.LEFT) {
        global_state.camera.angle -= global_state.camera.rotspeed * time_delta
    }
    if rl.IsKeyDown(.RIGHT) {
        global_state.camera.angle += global_state.camera.rotspeed * time_delta
    }
    if rl.IsKeyDown(.Q) {
        global_state.camera.height += global_state.camera.heightspeed * time_delta
    }
    if rl.IsKeyDown(.E) {
        global_state.camera.height -= global_state.camera.heightspeed * time_delta
    }
    if rl.IsKeyDown(.W) {
        global_state.camera.horizon += global_state.camera.horizonspeed * time_delta
    }
    if rl.IsKeyDown(.S) {
        global_state.camera.horizon -= global_state.camera.horizonspeed * time_delta
    }
    if rl.IsKeyDown(.A) {
        global_state.camera.tilt -= global_state.camera.tiltspeed * time_delta
        global_state.camera.tilt = global_state.camera.tilt < -1 ? -1 : global_state.camera.tilt
    }
    if rl.IsKeyDown(.D) {
        global_state.camera.tilt += global_state.camera.tiltspeed * time_delta
        global_state.camera.tilt = global_state.camera.tilt > 1 ? 1 : global_state.camera.tilt
    }
    if rl.IsKeyDown(.R) {
        global_state.camera.angle = 1.5 * math.PI
        global_state.camera.tilt = 0
        global_state.camera.height = 150
        global_state.camera.horizon = 100
    }
}

get_linear_fog_factor :: proc(fog_end, fog_start, z: int) -> int {
    return int((f32(fog_end) - f32(z)) / (f32(fog_end) - f32(fog_start)))
}

get_exponential_fog_factor :: proc(fog_density: f32, z: int) -> f32 {
    return 1 / math.exp(f32(z) * fog_density)
}

get_scaled_pixel :: proc(pixel, fog: rl.Color, fog_factor: f32) -> rl.Color {
    scaled_pixel := rl.Color{
        u8(f32(pixel.r) * fog_factor), // r
        u8(f32(pixel.g) * fog_factor), // g
        u8(f32(pixel.b) * fog_factor), // b
        u8(f32(pixel.a) * fog_factor), // a
    }
    
    scaled_fog := rl.Color{
        u8(f32(fog.r) * (1 - fog_factor)), // r
        u8(f32(fog.g) * (1 - fog_factor)), // g
        u8(f32(fog.b) * (1 - fog_factor)), // b
        u8(f32(fog.a) * (1 - fog_factor)), // a
    }
    
    return rl.Color{
        scaled_pixel.r + scaled_fog.r,
        scaled_pixel.g + scaled_fog.g,
        scaled_pixel.b + scaled_fog.b,
        scaled_pixel.a + scaled_fog.a,
    }
}

load_maps :: proc() {
    for i := 0; i < NUM_MAPS; i += 1 {
        global_state.maps[i] = Map{
            color_map = fmt.ctprintf("assets/map%d.color.gif", i),
            height_map = fmt.ctprintf("assets/map%d.height.gif", i),
        }
    }
}

dropdown_options :: proc() -> cstring {
    builder: strings.Builder
    strings.builder_init(&builder)
    defer strings.builder_destroy(&builder)
    
    for i := 0; i < NUM_MAPS; i += 1 {
        fmt.sbprintf(&builder, "map%d;", i)
    }
    
    str := strings.to_string(builder)
    defer delete(str)
    return strings.clone_to_cstring(str[:len(str)-1])
}

main :: proc() {
    load_maps()
    dropdown_text := dropdown_options()
    
    rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "Voxel Space")
    defer rl.CloseWindow()
    
    // Load initial maps
    color_map_img := rl.LoadImage(global_state.maps[global_state.selected_map].color_map)
    height_map_img := rl.LoadImage(global_state.maps[global_state.selected_map].height_map)
    
    global_state.color_map = rl.LoadImageColors(color_map_img)
    global_state.height_map = rl.LoadImageColors(height_map_img)
    
    rl.SetTargetFPS(FPS)
    
    for !rl.WindowShouldClose() {
        if global_state.current_selected_map != global_state.selected_map {
            global_state.selected_map = global_state.current_selected_map
            color_map_img = rl.LoadImage(global_state.maps[global_state.selected_map].color_map)
            height_map_img = rl.LoadImage(global_state.maps[global_state.selected_map].height_map)
            global_state.color_map = rl.LoadImageColors(color_map_img)
            global_state.height_map = rl.LoadImageColors(height_map_img)
        }
        
        time_delta := rl.GetFrameTime()
        process_input(time_delta)
        
        sin_angle := math.sin(global_state.camera.angle)
        cos_angle := math.cos(global_state.camera.angle)
        
        plx := cos_angle * global_state.camera.zfar + sin_angle * global_state.camera.zfar
        ply := sin_angle * global_state.camera.zfar - cos_angle * global_state.camera.zfar
        
        prx := cos_angle * global_state.camera.zfar - sin_angle * global_state.camera.zfar
        pry := sin_angle * global_state.camera.zfar + cos_angle * global_state.camera.zfar
        
        rl.BeginDrawing()
        defer rl.EndDrawing()
        
        rl.ClearBackground(rl.RAYWHITE)
        
        for i := 0; i < SCREEN_WIDTH; i += 1 {
            delta_x := (plx + (prx - plx) / f32(SCREEN_WIDTH) * f32(i)) / global_state.camera.zfar
            delta_y := (ply + (pry - ply) / f32(SCREEN_WIDTH) * f32(i)) / global_state.camera.zfar
            
            rx := global_state.camera.x
            ry := global_state.camera.y
            
            max_height := SCREEN_HEIGHT
            
            for z := 1; z < int(global_state.camera.zfar); z += 1 {
                rx += delta_x
                ry += delta_y
                
                map_offset := (MAP_N * (int(ry) & (MAP_N - 1))) + (int(rx) & (MAP_N - 1))
                proj_height := int((global_state.camera.height - f32(global_state.height_map[map_offset].r)) / f32(z) * SCALE_FACTOR + global_state.camera.horizon)
                proj_height = proj_height < 0 ? 0 : proj_height
                proj_height = proj_height > SCREEN_HEIGHT ? SCREEN_HEIGHT - 1 : proj_height
                
                if proj_height < max_height {
                    lean := (global_state.camera.tilt * (f32(i) / f32(SCREEN_WIDTH) - 0.5) + 0.5) * f32(SCREEN_HEIGHT) / 6
                    
                    for y := int(f32(proj_height) + lean); y < int(f32(max_height) + lean); y += 1 {
                        pixel := global_state.color_map[map_offset]
                        scaled_pixel := pixel
                        
                        if global_state.fog_type == 0 {
                            scaled_pixel = get_scaled_pixel(pixel, rl.Color{180, 180, 180, 255}, 
                                get_exponential_fog_factor(global_state.fog_density, z))
                        } else {
                            if global_state.fog_end <= global_state.fog_start {
                                global_state.fog_end = global_state.fog_start + 1
                            }
                            scaled_pixel = get_scaled_pixel(pixel, rl.Color{180, 180, 180, 100},
                                f32(get_linear_fog_factor(int(global_state.fog_end), 
                                    int(global_state.fog_start), z)))
                        }
                        
                        if y >= 0 && y < SCREEN_HEIGHT {
                            rl.DrawPixel(i32(i), i32(y), scaled_pixel)
                        }
                    }
                    max_height = proj_height
                }
            }
        }
        
        // GUI Controls using raygui
        rl.GuiToggleSlider(rl.Rectangle{5, 5, 150, 10}, "Density;Linear", &global_state.fog_type)
        
        if global_state.fog_type == 0 {
            rl.GuiSliderBar(
                rl.Rectangle{70, 20, 150, 10}, 
                "Fog Density", 
                fmt.ctprintf("%1.4f", global_state.fog_density), 
                &global_state.fog_density, 
                0.0, 
                0.02,
            )
        } else {
            rl.GuiSliderBar(
                rl.Rectangle{70, 20, 150, 10}, 
                "Fog Start", 
                fmt.ctprintf("%3.2f", global_state.fog_start), 
                &global_state.fog_start, 
                0.0, 
                global_state.camera.zfar,
            )
            rl.GuiSliderBar(
                rl.Rectangle{70, 35, 150, 10}, 
                "Fog End", 
                fmt.ctprintf("%3.2f", global_state.fog_end), 
                &global_state.fog_end, 
                global_state.fog_start + 1, 
                global_state.camera.zfar,
            )
        }
        
        if rl.GuiDropdownBox(
            rl.Rectangle{480, 5, 150, 10}, 
            dropdown_text,
            &global_state.current_selected_map, 
            global_state.map_selector_mode,
        ) {
            global_state.map_selector_mode = !global_state.map_selector_mode
        }
    }
}