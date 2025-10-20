package main

import "core:math"
import "core:fmt"
import rl "vendor:raylib"

WIDTH :: 1000
HEIGHT :: 800
GRID_COUNT :: 15
GRID_PAD :: 30
GRID_SIZE :: (GRID_COUNT - 1) * GRID_PAD
RADIUS :: 10

background_color := rl.Color{22, 22, 22, 255}
circle_color := rl.Color{200, 30, 30, 255}
inner_radius: f32 = RADIUS + 1
outer_radius: f32 = RADIUS + 3
tri_wide: f32 = 10.0
tri_height: f32 = 15.0

Point :: struct {
    x, y, z: f32,
    radius: f32,
    color: rl.Color,
}

Cube :: struct {
    points: [GRID_COUNT * GRID_COUNT * GRID_COUNT]Point,
}

Shape :: enum {
    SHAPE_NONE,
    CIRCLE,
    RING,
    TRIANGLE,
}

Rotation :: enum {
    ROTATION_NONE,
    X_AXIS,
    Y_AXIS,
    Z_AXIS,
}

AngleDir :: enum {
    ANGLE_NONE,
    CLOCKWISE,
    ANTI_CLOCKWISE,
}

Text :: struct {
    str: cstring,
    pos_x, pos_y: i32,
    font_size: i32,
    text_color: rl.Color,
}

CheckBox :: struct {
    rect: rl.Rectangle,
    text: Text,
    color: rl.Color,
    selected: bool,
    shape: Shape,
    rotation: Rotation,
    angle_dir: AngleDir,
}

font: rl.Font
font_size: i32 = 25
font_spacing: f32 = 2.0

draw_checkbox :: proc(cbs: []CheckBox) {
    roundness: f32 = 0.5
    segments: f32 = 10.0
    
    for &cb in cbs {
        rl.DrawRectangleRounded(cb.rect, roundness, i32(segments), cb.color)
        rl.DrawTextEx(font, cb.text.str, {f32(cb.text.pos_x), f32(cb.text.pos_y)}, 
                     f32(cb.text.font_size), font_spacing, cb.text.text_color)
    }
}

user_input_checkbox :: proc(cbs: []CheckBox) {
    mouse_pos := rl.GetMousePosition()
    
    for i in 0..<len(cbs) {
        cb := &cbs[i]
        if (mouse_pos.x >= cb.rect.x && mouse_pos.x <= cb.rect.x + cb.rect.width) &&
           (mouse_pos.y >= cb.rect.y && mouse_pos.y <= cb.rect.y + cb.rect.height) {
            if rl.IsMouseButtonDown(.LEFT) {
                cb.color = rl.RED
                cb.selected = true
                
                // Deselect other checkboxes in the same group
                for j in 0..<len(cbs) {
                    if cbs[j].selected && i != j {
                        cbs[j].color = rl.WHITE
                        cbs[j].selected = false
                    }
                }
            }
        }
    }
}

main :: proc() {
    title :: "3D Cube Projection On 2D Plane"
    rl.SetConfigFlags({.WINDOW_UNDECORATED})
    rl.InitWindow(WIDTH, HEIGHT, title)
    rl.SetTargetFPS(60)

    font = rl.LoadFontEx("assets/poppins.otf", font_size, nil, 0)
    
    cube := Cube{}
    angle: f32 = 0
    x, y, z: f32
    z_eye: f32 = 320.0
    
    // Point of rotation
    xp: f32 = 0
    yp: f32 = 0
    zp: f32 = (GRID_SIZE * 0.5 + z_eye) / GRID_COUNT

    // Init cube points
    idx := 0
    for iy in 0..<GRID_COUNT {
        for ix in 0..<GRID_COUNT {
            for iz in 0..<GRID_COUNT {
                r := u8(((iz < 8) && (iy < 8) && (ix < 8)) ? (((ix + 2) * 255) / GRID_COUNT) : ((ix * 255) / GRID_COUNT))
                g := u8(((iz < 8) && (iy < 8) && (ix < 8)) ? (((iy + 2) * 255) / GRID_COUNT) : ((iy * 255) / GRID_COUNT))
                b := u8(((iz < 8) && (iy < 8) && (ix < 8)) ? (((iz + 2) * 255) / GRID_COUNT) : ((iz * 255) / GRID_COUNT))
                
                circle_color_gradient := rl.Color{r, g, b, 255}
   
                // Calculate object position
                x = (f32(ix) * GRID_PAD - (GRID_SIZE * 0.5)) / GRID_COUNT
                y = (f32(iy) * GRID_PAD - (GRID_SIZE * 0.5)) / GRID_COUNT
                z = ((f32(iz) * GRID_PAD) + z_eye) / GRID_COUNT
                
                cube.points[idx].x = x
                cube.points[idx].y = y
                cube.points[idx].z = z
                cube.points[idx].radius = RADIUS
                cube.points[idx].color = circle_color_gradient
                idx += 1
            }
        }
    }
    // Setup checkboxes
    cb_init_x: f32 = 20.0
    cb_init_y: f32 = 50.0
    cb_width: f32 = 20.0
    cb_height: f32 = 20.0
    cb_y_offset: f32 = 30.0
    cb_text_init_x := i32(cb_init_x + 30.0)
    cb_text_init_y := i32(cb_init_y - 1.0)
    cb_text_y_offset := i32(cb_y_offset)
    
    // Shape filling checkboxes
    circle_cb := CheckBox{
        rect = {cb_init_x, cb_init_y, cb_width, cb_height},
        text = {"Circle", cb_text_init_x, cb_text_init_y, font_size, rl.RAYWHITE},
        color = rl.RED,
        selected = true,
        shape = .CIRCLE,
        rotation = .ROTATION_NONE,
        angle_dir = .ANGLE_NONE,
    }
    ring_cb := CheckBox{
        rect = {cb_init_x, cb_init_y + cb_y_offset, cb_width, cb_height},
        text = {"Ring", cb_text_init_x, cb_text_init_y + cb_text_y_offset, font_size, rl.RAYWHITE},
        color = rl.WHITE,
        selected = false,
        shape = .RING,
        rotation = .ROTATION_NONE,
        angle_dir = .ANGLE_NONE,
    }
    triangle_cb := CheckBox{
        rect = {cb_init_x, cb_init_y + 2.0 * cb_y_offset, cb_width, cb_height},
        text = {"Triangle", cb_text_init_x, cb_text_init_y + 2 * cb_text_y_offset, font_size, rl.RAYWHITE},
        color = rl.WHITE,
        selected = false,
        shape = .TRIANGLE,
        rotation = .ROTATION_NONE,
        angle_dir = .ANGLE_NONE,
    }
    // Rotation axis checkboxes
    x_axis_cb_text :: "X-Axis"
    x_axis_cb_text_dim := rl.MeasureTextEx(font, x_axis_cb_text, f32(font_size), font_spacing)
    x_axis_x_offset: f32 = 10.0
    
    x_axis_cb := CheckBox{
        rect = {WIDTH - x_axis_cb_text_dim.x - 2 * cb_init_x - cb_width * 0.5, cb_init_y, cb_width, cb_height},
        text = {x_axis_cb_text, i32(WIDTH - x_axis_cb_text_dim.x - 2 * x_axis_x_offset), cb_text_init_y, font_size, rl.RAYWHITE},
        color = rl.WHITE,
        selected = false,
        shape = .SHAPE_NONE,
        rotation = .X_AXIS,
        angle_dir = .ANGLE_NONE,
    }
    y_axis_cb_text :: "Y-Axis"
    y_axis_cb_text_dim := rl.MeasureTextEx(font, y_axis_cb_text, f32(font_size), font_spacing)
    
    y_axis_cb := CheckBox{
        rect = {WIDTH - x_axis_cb_text_dim.x - 2 * cb_init_x - cb_width * 0.5, cb_init_y + cb_y_offset, cb_width, cb_height},
        text = {y_axis_cb_text, i32(WIDTH - y_axis_cb_text_dim.x - 2 * x_axis_x_offset), cb_text_init_y + cb_text_y_offset, font_size, rl.RAYWHITE},
        color = rl.RED,
        selected = true,
        shape = .SHAPE_NONE,
        rotation = .Y_AXIS,
        angle_dir = .ANGLE_NONE,
    }
    z_axis_cb_text :: "Z-Axis"
    z_axis_cb_text_dim := rl.MeasureTextEx(font, z_axis_cb_text, f32(font_size), font_spacing)
    
    z_axis_cb := CheckBox{
        rect = {WIDTH - x_axis_cb_text_dim.x - 2 * cb_init_x - cb_width * 0.5, cb_init_y + 2.0 * cb_y_offset, cb_width, cb_height},
        text = {z_axis_cb_text, i32(WIDTH - z_axis_cb_text_dim.x - 2 * x_axis_x_offset), cb_text_init_y + 2 * cb_text_y_offset, font_size, rl.RAYWHITE},
        color = rl.WHITE,
        selected = false,
        shape = .SHAPE_NONE,
        rotation = .Z_AXIS,
        angle_dir = .ANGLE_NONE,
    }
    // Angle direction checkboxes
    clockwise_cb_text :: "+ve"
    clockwise_cb_text_dim := rl.MeasureTextEx(font, clockwise_cb_text, f32(font_size), font_spacing)
    
    clockwise_cb := CheckBox{
        rect = {WIDTH - x_axis_cb_text_dim.x - 2 * cb_init_x - cb_width * 0.5, z_axis_cb.rect.y + 3.0 * cb_y_offset, cb_width, cb_height},
        text = {clockwise_cb_text, i32(WIDTH - clockwise_cb_text_dim.x - 2 * x_axis_x_offset), cb_text_init_y + 5 * cb_text_y_offset, font_size, rl.RAYWHITE},
        color = rl.RED,
        selected = true,
        shape = .SHAPE_NONE,
        rotation = .ROTATION_NONE,
        angle_dir = .CLOCKWISE,
    }
    anti_clockwise_cb_text :: "-ve"
    anti_clockwise_cb_text_dim := rl.MeasureTextEx(font, anti_clockwise_cb_text, f32(font_size), font_spacing)
    
    anti_clockwise_cb := CheckBox{
        rect = {WIDTH - x_axis_cb_text_dim.x - 2 * cb_init_x - cb_width * 0.5, z_axis_cb.rect.y + 4.0 * cb_y_offset, cb_width, cb_height},
        text = {anti_clockwise_cb_text, i32(WIDTH - anti_clockwise_cb_text_dim.x - 2 * x_axis_x_offset), cb_text_init_y + 6 * cb_text_y_offset, font_size, rl.RAYWHITE},
        color = rl.WHITE,
        selected = false,
        shape = .SHAPE_NONE,
        rotation = .ROTATION_NONE,
        angle_dir = .ANTI_CLOCKWISE,
    }
    angle_dir_none_cb_text :: "Stop"
    angle_dir_none_cb_text_dim := rl.MeasureTextEx(font, angle_dir_none_cb_text, f32(font_size), font_spacing)
    
    angle_dir_none_cb := CheckBox{
        rect = {WIDTH - x_axis_cb_text_dim.x - 2 * cb_init_x - cb_width * 0.5, z_axis_cb.rect.y + 5.0 * cb_y_offset, cb_width, cb_height},
        text = {angle_dir_none_cb_text, i32(WIDTH - angle_dir_none_cb_text_dim.x - 2 * x_axis_x_offset), cb_text_init_y + 7 * cb_text_y_offset, font_size, rl.RAYWHITE},
        color = rl.WHITE,
        selected = false,
        shape = .SHAPE_NONE,
        rotation = .ROTATION_NONE,
        angle_dir = .ANGLE_NONE,
    }
    shape_cbs := []CheckBox{circle_cb, ring_cb, triangle_cb}
    rotation_cbs := []CheckBox{x_axis_cb, y_axis_cb, z_axis_cb}
    angle_dir_cbs := []CheckBox{clockwise_cb, anti_clockwise_cb, angle_dir_none_cb}
    
    for !rl.WindowShouldClose() {
        rl.BeginDrawing()
        rl.ClearBackground(background_color)
        
        user_input_checkbox(shape_cbs[:])
        user_input_checkbox(rotation_cbs[:])
        user_input_checkbox(angle_dir_cbs[:])
        
        selected_shape := Shape.SHAPE_NONE
        selected_rotation := Rotation.ROTATION_NONE
        selected_angle_dir := AngleDir.ANGLE_NONE
        
        // Get selected options
        for cb in shape_cbs {
            if cb.selected {
                selected_shape = cb.shape
            }
        }
        for cb in rotation_cbs {
            if cb.selected {
                selected_rotation = cb.rotation
            }
        }
        for cb in angle_dir_cbs {
            if cb.selected {
                selected_angle_dir = cb.angle_dir
            }
        }
        // Draw UI text
        rl.DrawTextEx(font, "Select Filling Shape Of Cube : ", {cb_init_x, cb_init_y * 0.40}, f32(font_size), font_spacing, rl.WHITE)
        draw_checkbox(shape_cbs[:])
        
        rot_heading :: "Select Rotational Axis : "
        rot_heading_width := rl.MeasureTextEx(font, rot_heading, f32(font_size), font_spacing)
        rl.DrawTextEx(font, rot_heading, {WIDTH - rot_heading_width.x - 10.0, cb_init_y * 0.40}, f32(font_size), font_spacing, rl.WHITE)
        draw_checkbox(rotation_cbs[:])
        
        ang_dir_heading :: "Angle Direction : "
        ang_dir_heading_width := rl.MeasureTextEx(font, ang_dir_heading, f32(font_size), font_spacing)
        rl.DrawTextEx(font, ang_dir_heading, {WIDTH - ang_dir_heading_width.x - 10.0, z_axis_cb.rect.y + 2.0 * cb_y_offset}, f32(font_size), font_spacing, rl.WHITE)
        draw_checkbox(angle_dir_cbs[:])
        
        // Update angle based on selected direction
        switch selected_angle_dir {
        case .CLOCKWISE:
            angle += 3 * math.PI * rl.GetFrameTime()
        case .ANTI_CLOCKWISE:
            angle -= 3 * math.PI * rl.GetFrameTime()
        case .ANGLE_NONE:
            paused :: "Rotation Is Paused !!"
            paused_dim := rl.MeasureTextEx(font, paused, f32(font_size), font_spacing)
            rl.DrawTextEx(font, paused, {WIDTH * 0.5 - paused_dim.x * 0.5, HEIGHT - paused_dim.y - 5.0}, f32(font_size), font_spacing, rl.RED)
        }
        // Render cube points
        for i in 0..<GRID_COUNT * GRID_COUNT * GRID_COUNT {
            // Translate to origin for rotation
            x_prime := cube.points[i].x - xp
            y_prime := cube.points[i].y - yp
            z_prime := cube.points[i].z - zp
            
            new_x, new_y, new_z: f32
            
            // Apply rotation based on selected axis
            switch selected_rotation {
            case .X_AXIS:
                new_x = x_prime
                new_y = y_prime * math.cos(math.to_radians(angle)) - z_prime * math.sin(math.to_radians(angle))
                new_z = y_prime * math.sin(math.to_radians(angle)) + z_prime * math.cos(math.to_radians(angle))
            case .Y_AXIS:
                new_x = x_prime * math.cos(math.to_radians(angle)) + z_prime * math.sin(math.to_radians(angle))
                new_y = y_prime
                new_z = -x_prime * math.sin(math.to_radians(angle)) + z_prime * math.cos(math.to_radians(angle))
            case .Z_AXIS:
                new_x = x_prime * math.cos(math.to_radians(angle)) - y_prime * math.sin(math.to_radians(angle))
                new_y = x_prime * math.sin(math.to_radians(angle)) + y_prime * math.cos(math.to_radians(angle))
                new_z = z_prime
            case .ROTATION_NONE:
                new_x = x_prime
                new_y = y_prime
                new_z = z_prime
            }
            // Translate back to position
            x = new_x + xp
            y = new_y + yp
            z = new_z + zp
            
            // Perspective divide
            x = x / z
            y = y / z
            x = (x + 1) / 2
            y = (y + 1) / 2
            
            // Scale coordinates back
            x *= WIDTH
            y *= HEIGHT
            
            // Draw based on selected shape
            switch selected_shape {
            case .CIRCLE:
                circle_color := cube.points[i].color
                rad := cube.points[i].radius / z
                rad *= cube.points[i].radius
                rl.DrawCircle(i32(x), i32(y), rad, circle_color)
            case .RING:
                ring_color := cube.points[i].color
                in_rad := inner_radius / z
                out_rad := outer_radius / z
                in_rad *= inner_radius
                out_rad *= outer_radius
                rl.DrawRing({x, y}, in_rad, out_rad, 0, 360, 10, ring_color)
            case .TRIANGLE:
                triangle_color := cube.points[i].color
                tri_w := tri_wide / z
                tri_h := tri_height / z
                tri_w *= tri_wide
                tri_h *= tri_height
                v1 := rl.Vector2{x, y}
                v2 := rl.Vector2{x - tri_w, y + tri_h}
                v3 := rl.Vector2{x + tri_w, y + tri_h}
                rl.DrawTriangleLines(v1, v2, v3, triangle_color)
            case .SHAPE_NONE:
                default_text :: "SWITCH DEFAULT EXECUTED !!\n\t\t\tNO SHAPE DETECTED .."
                default_font_size: i32 = 20
                default_text_width := rl.MeasureText(default_text, default_font_size)
                rl.DrawTextEx(font, default_text, {WIDTH * 0.5 - f32(default_text_width) * 0.5, HEIGHT * 0.5}, f32(default_font_size), font_spacing, rl.WHITE)
            }
        }
        rl.DrawFPS(WIDTH - 75, HEIGHT - 20)
        rl.EndDrawing()
    }
    rl.CloseWindow()
}