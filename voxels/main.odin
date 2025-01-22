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

scene := struct {
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
        scene.camera.x += scene.camera.speed * math.cos(scene.camera.angle) * time_delta
        scene.camera.y += scene.camera.speed * math.sin(scene.camera.angle) * time_delta
    }
    if rl.IsKeyDown(.DOWN) {
        scene.camera.x -= scene.camera.speed * math.cos(scene.camera.angle) * time_delta
        scene.camera.y -= scene.camera.speed * math.sin(scene.camera.angle) * time_delta
    }
    if rl.IsKeyDown(.LEFT) {
        scene.camera.angle -= scene.camera.rotspeed * time_delta
    }
    if rl.IsKeyDown(.RIGHT) {
        scene.camera.angle += scene.camera.rotspeed * time_delta
    }
    if rl.IsKeyDown(.Q) {
        scene.camera.height += scene.camera.heightspeed * time_delta
    }
    if rl.IsKeyDown(.E) {
        scene.camera.height -= scene.camera.heightspeed * time_delta
    }
    if rl.IsKeyDown(.W) {
        scene.camera.horizon += scene.camera.horizonspeed * time_delta
    }
    if rl.IsKeyDown(.S) {
        scene.camera.horizon -= scene.camera.horizonspeed * time_delta
    }
    if rl.IsKeyDown(.A) {
        scene.camera.tilt -= scene.camera.tiltspeed * time_delta
        scene.camera.tilt = scene.camera.tilt < -1 ? -1 : scene.camera.tilt
    }
    if rl.IsKeyDown(.D) {
        scene.camera.tilt += scene.camera.tiltspeed * time_delta
        scene.camera.tilt = scene.camera.tilt > 1 ? 1 : scene.camera.tilt
    }
    if rl.IsKeyDown(.R) {
        scene.camera.angle = 1.5 * math.PI
        scene.camera.tilt = 0
        scene.camera.height = 150
        scene.camera.horizon = 100
    }
}

get_linear_fog_factor :: proc(fog_end, fog_start: f32, z: i32) -> f32 {
    return (fog_end - f32(z)) / (fog_end - fog_start)
}

get_exponential_fog_factor :: proc(fog_density: f32, z: i32) -> f32 {
    return 1 / math.exp(f32(z) * fog_density)
}

get_scaled_pixel :: proc(pixel, fog: rl.Color, fog_factor: f32) -> rl.Color {
    scaled_pixel := rl.Color{
        u8(f32(pixel.r) * fog_factor),
        u8(f32(pixel.g) * fog_factor),
        u8(f32(pixel.b) * fog_factor),
        u8(f32(pixel.a) * fog_factor),
    }

    scale := 1 - fog_factor
    scaled_fog := rl.Color{
        u8(f32(fog.r) * scale),
        u8(f32(fog.g) * scale),
        u8(f32(fog.b) * scale),
        u8(f32(fog.a) * scale),
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
        scene.maps[i] = Map{
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
    return strings.clone_to_cstring(str[:len(str)-1]) // Remove the last semicolon
}

main :: proc() {
    load_maps()
    dropdown_text := dropdown_options()
    
    rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "Voxel Space")
    defer rl.CloseWindow()
    
    // Load initial maps
    color_map_img := rl.LoadImage(scene.maps[scene.selected_map].color_map)
    height_map_img := rl.LoadImage(scene.maps[scene.selected_map].height_map)
    
    scene.color_map = rl.LoadImageColors(color_map_img)
    scene.height_map = rl.LoadImageColors(height_map_img)
    
    rl.SetTargetFPS(FPS)
    
    for !rl.WindowShouldClose() {
        if scene.current_selected_map != scene.selected_map {
            scene.selected_map = scene.current_selected_map
            color_map_img = rl.LoadImage(scene.maps[scene.selected_map].color_map)
            height_map_img = rl.LoadImage(scene.maps[scene.selected_map].height_map)
            scene.color_map = rl.LoadImageColors(color_map_img)
            scene.height_map = rl.LoadImageColors(height_map_img)
        }
        
        time_delta := rl.GetFrameTime()
        process_input(time_delta)
        
        sin_angle := math.sin(scene.camera.angle)
        cos_angle := math.cos(scene.camera.angle)
        
        plx := cos_angle * scene.camera.zfar + sin_angle * scene.camera.zfar
        ply := sin_angle * scene.camera.zfar - cos_angle * scene.camera.zfar
        
        prx := cos_angle * scene.camera.zfar - sin_angle * scene.camera.zfar
        pry := sin_angle * scene.camera.zfar + cos_angle * scene.camera.zfar
        
        rl.BeginDrawing()
        defer rl.EndDrawing()
        
        rl.ClearBackground(rl.RAYWHITE)
        
        for i: i32 = 0; i < SCREEN_WIDTH; i += 1 {
            delta_x := (plx + (prx - plx) / f32(SCREEN_WIDTH) * f32(i)) / scene.camera.zfar
            delta_y := (ply + (pry - ply) / f32(SCREEN_WIDTH) * f32(i)) / scene.camera.zfar
            
            rx := scene.camera.x
            ry := scene.camera.y
            
            max_height := SCREEN_HEIGHT
            
            for z: i32 = 1; z < i32(scene.camera.zfar); z += 1 {
                rx += delta_x
                ry += delta_y
                
                map_offset := (MAP_N * (int(ry) & (MAP_N - 1))) + (int(rx) & (MAP_N - 1))
                proj_height := int((scene.camera.height - f32(scene.height_map[map_offset].r)) / f32(z) * SCALE_FACTOR + scene.camera.horizon)
                proj_height = proj_height < 0 ? 0 : proj_height
                proj_height = proj_height > SCREEN_HEIGHT ? SCREEN_HEIGHT - 1 : proj_height
                
                if proj_height < max_height {
                    lean := (scene.camera.tilt * (f32(i) / f32(SCREEN_WIDTH) - 0.5) + 0.5) * f32(SCREEN_HEIGHT) / 6
                    
                    for y := i32(f32(proj_height) + lean); y < i32(f32(max_height) + lean); y += 1 {
                        pixel := scene.color_map[map_offset]
                        scaled_pixel := pixel
                        
                        if scene.fog_type == 0 {
                            scaled_pixel = get_scaled_pixel(pixel, rl.Color{180, 180, 180, 255}, 
                                get_exponential_fog_factor(scene.fog_density, z))
                        } else {
                            if scene.fog_end <= scene.fog_start {
                                scene.fog_end = scene.fog_start + 1
                            }
                            scaled_pixel = get_scaled_pixel(pixel, rl.Color{180, 180, 180, 100},
                                get_linear_fog_factor(scene.fog_end, scene.fog_start, z))
                        }
                        
                        if y >= 0 && y < SCREEN_HEIGHT {
                            rl.DrawPixel(i, y, scaled_pixel) 
                        }
                    }
                    max_height = proj_height
                }
            }
        }
        
        // GUI Controls using raygui
        rl.GuiToggleSlider(rl.Rectangle{5, 5, 150, 10}, "Density;Linear", &scene.fog_type)
        
        if scene.fog_type == 0 {
            rl.GuiSliderBar(
                rl.Rectangle{70, 20, 150, 10}, 
                "Fog Density", 
                fmt.ctprintf("%1.4f", scene.fog_density), 
                &scene.fog_density, 
                0.0, 
                0.02,
            )
        } else {
            rl.GuiSliderBar(
                rl.Rectangle{70, 20, 150, 10}, 
                "Fog Start", 
                fmt.ctprintf("%3.2f", scene.fog_start), 
                &scene.fog_start, 
                0.0, 
                scene.camera.zfar,
            )
            rl.GuiSliderBar(
                rl.Rectangle{70, 35, 150, 10}, 
                "Fog End", 
                fmt.ctprintf("%3.2f", scene.fog_end), 
                &scene.fog_end, 
                scene.fog_start + 1, 
                scene.camera.zfar,
            )
        }
        
        if rl.GuiDropdownBox(
            rl.Rectangle{480, 5, 150, 10}, 
            dropdown_text,
            &scene.current_selected_map, 
            scene.map_selector_mode,
        ) {
            scene.map_selector_mode = !scene.map_selector_mode
        }
    }
}