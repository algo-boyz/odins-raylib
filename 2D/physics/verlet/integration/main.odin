package main

import rl "vendor:raylib"
import "core:math"
import "core:fmt"
import "core:strings"

// Constants
WIDTH :: 1280
HEIGHT :: 900
SUBSTEPS :: 8
MAX_LATENCY :: 0.05
MAX_OBJECTS :: 4096
MAX_LINKS :: 8192
MAX_BTNS :: 32
UNIT_SIZE :: 20

// Enums
Anchoring :: enum {
    FIRST,
    LAST,
    BOTH,
    NONE,
}

StructType :: enum {
    DEFAULT = 0,
    ROPE,
    CLOTH,
    NUM_STRUCTURES,
}

// Types
Verlet :: struct {
    current_pos: rl.Vector2,
    old_pos: rl.Vector2,
    acceleration: rl.Vector2,
    radius: f32,
    color: rl.Color,
    is_static: bool,
    is_colliding: bool,
}

Link :: struct {
    object1: ^Verlet,
    object2: ^Verlet,
    target_distance: f32,
}

Btn :: struct {
    rect: rl.Rectangle,
    label: string,
}

Slider :: struct {
    bounds: rl.Rectangle,
    rect: rl.Rectangle,
    label: string,
    variable: ^f32,
    range: rl.Vector2,
}

// Global variables
objects: [MAX_OBJECTS]Verlet
num_objects: int = 0
links: [MAX_LINKS]Link
num_links: int = 0
btns: [MAX_BTNS]Btn
num_btns: int = 0
sliders: [MAX_BTNS]Slider
num_sliders: int = 0

button_mouse_hover: int = -1
slider_focused: int = -1
frames_counter: int = 0
response_coef: f32 = 1.0
gravity: rl.Vector2 = {0, 1000}

// UI globals
g_mouse_pos: rl.Vector2
g_button_pressed0: bool = false
g_spawn_radius: f32 = 10
g_spawn_rate: f32 = 10
g_gravity: f32 = 1000
g_red: f32 = 127
g_green: f32 = 127
g_blue: f32 = 127
g_struct_type: StructType = .DEFAULT
g_apply_constraint: bool = true

// Utility functions
clamp :: proc(value, min_val, max_val: f32) -> f32 {
    if value < min_val do return min_val
    if value > max_val do return max_val
    return value
}

random_value :: proc(min_val, max_val: i32) -> i32 {
    return rl.GetRandomValue(min_val, max_val)
}

// Verlet functions
spawn_verlet :: proc(position: rl.Vector2, radius: f32, color: rl.Color) {
    if num_objects >= MAX_OBJECTS do return
    
    ball := &objects[num_objects]
    ball.current_pos = position
    ball.old_pos = position
    ball.radius = radius
    ball.color = color
    ball.is_static = false
    ball.is_colliding = true
    num_objects += 1
}

spawn_verlet_static :: proc(position: rl.Vector2, radius: f32, color: rl.Color) {
    if num_objects >= MAX_OBJECTS do return
    
    ball := &objects[num_objects]
    ball.current_pos = position
    ball.old_pos = position
    ball.radius = radius
    ball.color = color
    ball.is_static = true
    ball.is_colliding = true
    num_objects += 1
}

spawn_verlet_non_colliding :: proc(position: rl.Vector2, radius: f32, color: rl.Color) {
    if num_objects >= MAX_OBJECTS do return
    
    ball := &objects[num_objects]
    ball.current_pos = position
    ball.old_pos = position
    ball.radius = radius
    ball.color = color
    ball.is_static = false
    ball.is_colliding = false
    num_objects += 1
}

spawn_link :: proc(pos1, pos2: int, distance: f32) {
    if num_links >= MAX_LINKS do return
    
    links[num_links] = Link{
        object1 = &objects[num_objects + pos1],
        object2 = &objects[num_objects + pos2],
        target_distance = distance,
    }
    num_links += 1
}

spawn_struct_rope :: proc(pos: rl.Vector2, num_joints: int, distance, radius: f32, anchoring: Anchoring, color: rl.Color) {
    if num_objects + num_joints >= MAX_OBJECTS do return
    if num_links + num_joints - 1 >= MAX_LINKS do return
    if radius > distance/2 do return
    
    // Create links
    for i in 0..<num_joints-1 {
        spawn_link(i, i + 1, distance)
    }
    
    // Spawn objects for rope
    if anchoring == .FIRST || anchoring == .BOTH {
        spawn_verlet_static(pos, radius, color)
    } else {
        spawn_verlet(pos, radius, color)
    }
    
    for i in 1..<num_joints-1 {
        spawn_verlet({pos.x + f32(i)*distance, pos.y}, radius, color)
    }
    
    if anchoring == .LAST || anchoring == .BOTH {
        spawn_verlet_static({pos.x + f32(num_joints-1)*distance, pos.y}, radius, color)
    } else {
        spawn_verlet({pos.x + f32(num_joints-1)*distance, pos.y}, radius, color)
    }
}

xy_to_num :: proc(x, y, width: int) -> int {
    return y*width + x
}

spawn_struct_cloth :: proc(pos: rl.Vector2, num_side_joints: int, distance, radius: f32, color: rl.Color) {
    if num_objects + num_side_joints*num_side_joints >= MAX_OBJECTS do return
    if num_links + num_side_joints*num_side_joints*2 >= MAX_LINKS do return
    
    // Create links
    for i in 0..<num_side_joints {
        for j in 0..<num_side_joints {
            if i < num_side_joints - 1 {
                spawn_link(xy_to_num(i, j, num_side_joints), xy_to_num(i + 1, j, num_side_joints), distance)
            }
            if j < num_side_joints - 1 {
                spawn_link(xy_to_num(i, j, num_side_joints), xy_to_num(i, j + 1, num_side_joints), distance)
            }
        }
    }
    
    // Spawn objects
    for i in 0..<num_side_joints {
        for j in 0..<num_side_joints {
            // Anchor the two top corners
            if (i == 0 && j == 0) || (i == 0 && j == num_side_joints - 1) {
                spawn_verlet_static({pos.x + f32(j)*distance - 5, pos.y + f32(i)*distance}, radius, color)
            } else {
                spawn_verlet_non_colliding({pos.x + f32(j)*distance, pos.y + f32(i)*distance}, radius, color)
            }
        }
    }
}

apply_links :: proc() {
    for i in 0..<num_links {
        obj1 := links[i].object1
        obj2 := links[i].object2
        
        axis := obj1.current_pos - obj2.current_pos
        dist := rl.Vector2Length(axis)
        n := rl.Vector2{axis.x/dist, axis.y/dist}
        delta := links[i].target_distance - dist
        
        // Only apply forces if in tension
        if delta < 0 {
            if !obj1.is_static {
                obj1.current_pos.x += 0.5 * delta * n.x
                obj1.current_pos.y += 0.5 * delta * n.y
            }
            if !obj2.is_static {
                obj2.current_pos.x -= 0.5 * delta * n.x
                obj2.current_pos.y -= 0.5 * delta * n.y
            }
        }
    }
}

apply_acceleration :: proc(vector: rl.Vector2) {
    for i in 0..<num_objects {
        objects[i].acceleration.y += vector.y
    }
}

accelerate_to_point :: proc(vector: rl.Vector2, strength: f32) {
    for i in 0..<num_objects {
        object := &objects[i]
        to_point := vector - object.current_pos
        distance := rl.Vector2Length(to_point)
        if distance < 0.0001 do continue
        
        object.acceleration.x += to_point.x * strength / distance
        object.acceleration.y += to_point.y * strength / distance
    }
}

apply_constraint_circle :: proc(constraint_pos: rl.Vector2, radius: f32) {
    for i in 0..<num_objects {
        object := &objects[i]
        to_obj := object.current_pos - constraint_pos
        constraint_distance := rl.Vector2Length(to_obj)
        
        if constraint_distance > radius - object.radius {
            n := rl.Vector2{to_obj.x/constraint_distance, to_obj.y/constraint_distance}
            object.current_pos.x = constraint_pos.x + n.x * (radius - object.radius)
            object.current_pos.y = constraint_pos.y + n.y * (radius - object.radius)
        }
    }
}

solve_collisions :: proc() {
    for i in 0..<num_objects {
        object1 := &objects[i]
        if !object1.is_colliding do continue
        
        for j in i+1..<num_objects {
            object2 := &objects[j]
            if !object2.is_colliding do continue
            
            v := object1.current_pos - object2.current_pos
            dist2 := v.x * v.x + v.y * v.y
            min_dist := object1.radius + object2.radius
            
            // Check overlapping
            if dist2 < min_dist * min_dist {
                dist := math.sqrt(dist2)
                n := rl.Vector2{v.x/dist, v.y/dist}
                mass_ratio1 := object1.radius / (object1.radius + object2.radius)
                mass_ratio2 := object2.radius / (object1.radius + object2.radius)
                delta := 0.5 * response_coef * (dist - min_dist)
                
                // Update positions
                if !object1.is_static {
                    object1.current_pos.x -= n.x * (mass_ratio2 * delta)
                    object1.current_pos.y -= n.y * (mass_ratio2 * delta)
                }
                if !object2.is_static {
                    object2.current_pos.x += n.x * (mass_ratio1 * delta)
                    object2.current_pos.y += n.y * (mass_ratio1 * delta)
                }
            }
        }
    }
}

update_positions :: proc(dt: f32) {
    for i in 0..<num_objects {
        object := &objects[i]
        
        displacement := rl.Vector2{
            object.current_pos.x - object.old_pos.x,
            object.current_pos.y - object.old_pos.y,
        }
        
        if !object.is_static {
            object.old_pos = object.current_pos
            object.current_pos.x = object.current_pos.x + displacement.x + object.acceleration.x*dt*dt
            object.current_pos.y = object.current_pos.y + displacement.y + object.acceleration.y*dt*dt
            object.acceleration = rl.Vector2{0, 0}
        }
    }
}

update_verlet :: proc(dt: f32) {
    // React to UI signals
    if g_button_pressed0 {
        num_objects = 0
        num_links = 0
        g_button_pressed0 = false
    }
    
    gravity.y = f32(int(g_gravity/100)*100)
    center := rl.Vector2{f32(WIDTH)/2, f32(HEIGHT)/2}
    
    for k in 0..<SUBSTEPS {
        apply_acceleration(gravity)
        if rl.IsMouseButtonDown(.RIGHT) && !is_mouse_on_ui() {
            accelerate_to_point(g_mouse_pos, 2000)
        }
        if g_apply_constraint {
            apply_constraint_circle(center, 400)
        }
        solve_collisions()
        apply_links()
        update_positions(dt)
    }
}

draw_verlet :: proc() {
    for i in 0..<num_links {
        rl.DrawLineEx(links[i].object1.current_pos, links[i].object2.current_pos, 2.0, 
                     rl.Color{u8(g_red), u8(g_green), u8(g_blue), 255})
    }
    for i in 0..<num_objects {
        rl.DrawCircleV(objects[i].current_pos, objects[i].radius, objects[i].color)
    }
}

// UI functions
new_btn :: proc(rect: rl.Rectangle, label: string) {
    if num_btns >= MAX_BTNS do return
    
    btns[num_btns] = Btn{rect = rect, label = label}
    num_btns += 1
}

new_slider :: proc(bounds: rl.Rectangle, label: string, variable: ^f32, range: rl.Vector2) {
    if num_sliders >= MAX_BTNS do return
    
    // Figure out where in between the two ends the slider should go
    fraction := (variable^ - range.x) / (range.y - range.x)
    slider_rect := rl.Rectangle{
        x = bounds.x + (bounds.width - 2*f32(UNIT_SIZE)/3) * fraction,
        y = bounds.y + bounds.height - f32(UNIT_SIZE)*2,
        width = 2*f32(UNIT_SIZE)/3,
        height = f32(UNIT_SIZE)*2,
    }
    
    sliders[num_sliders] = Slider{
        bounds = bounds,
        rect = slider_rect,
        label = label,
        variable = variable,
        range = range,
    }
    num_sliders += 1
}

init_ui :: proc() {
    new_btn(rl.Rectangle{30, 40, 200, 100}, "Delete Objects")
    new_slider(rl.Rectangle{30, 180, 200, 60}, "Radius", &g_spawn_radius, rl.Vector2{3, 60})
    new_slider(rl.Rectangle{30, 280, 200, 60}, "Spawn Rate", &g_spawn_rate, rl.Vector2{5, 60})
    new_slider(rl.Rectangle{30, 380, 200, 60}, "Gravity", &g_gravity, rl.Vector2{-1000, 1000})
    
    new_btn(rl.Rectangle{30, 480, 50, 60}, "<")
    new_btn(rl.Rectangle{180, 480, 50, 60}, ">")
    
    new_btn(rl.Rectangle{30, 580, 200, 60}, "Toggle Constraint")
    
    new_slider(rl.Rectangle{WIDTH - 230, 180, 200, 60}, "Red", &g_red, rl.Vector2{0, 255})
    new_slider(rl.Rectangle{WIDTH - 230, 280, 200, 60}, "Green", &g_green, rl.Vector2{0, 255})
    new_slider(rl.Rectangle{WIDTH - 230, 380, 200, 60}, "Blue", &g_blue, rl.Vector2{0, 255})
}

update_slider :: proc(slider_num: int) {
    slider := &sliders[slider_num]
    slider.rect.x = g_mouse_pos.x - slider.rect.width/2
    
    // Clamp positions
    if slider.rect.x < slider.bounds.x {
        slider.rect.x = slider.bounds.x
    }
    if slider.rect.x > slider.bounds.x + slider.bounds.width - slider.rect.width {
        slider.rect.x = slider.bounds.x + slider.bounds.width - slider.rect.width
    }
    
    // Update variable based on slider position
    fraction := (slider.rect.x - slider.bounds.x) / (slider.bounds.width - slider.rect.width)
    slider.variable^ = slider.range.x + (slider.range.y - slider.range.x) * fraction
}

update_ui :: proc() {
    g_mouse_pos = rl.GetMousePosition()
    
    // Check collision with buttons
    button_mouse_hover = -1
    for i in 0..<num_btns {
        if rl.CheckCollisionPointRec(g_mouse_pos, btns[i].rect) {
            button_mouse_hover = i
        }
    }
    
    for i in 0..<num_sliders {
        if rl.CheckCollisionPointRec(g_mouse_pos, sliders[i].bounds) {
            button_mouse_hover = MAX_BTNS + i
        }
    }
    
    // Mouse click response
    if rl.IsMouseButtonPressed(.LEFT) && button_mouse_hover >= 0 {
        if button_mouse_hover == 0 {
            g_button_pressed0 = true
        } else if button_mouse_hover == 1 {
            g_struct_type = StructType((int(g_struct_type) - 1 + int(StructType.NUM_STRUCTURES)) % int(StructType.NUM_STRUCTURES))
        } else if button_mouse_hover == 2 {
            g_struct_type = StructType((int(g_struct_type) + 1) % int(StructType.NUM_STRUCTURES))
        } else if button_mouse_hover == 3 {
            g_apply_constraint = !g_apply_constraint
        } else if button_mouse_hover >= MAX_BTNS {
            slider_focused = button_mouse_hover - MAX_BTNS
        }
    }
    
    if rl.IsMouseButtonReleased(.LEFT) {
        slider_focused = -1
    }
    
    // Update sliders
    if slider_focused >= 0 {
        update_slider(slider_focused)
    }
}

draw_btns :: proc() {
    for i in 0..<num_btns {
        color := rl.LIGHTGRAY
        if button_mouse_hover == i {
            color = rl.GRAY
        }
        rl.DrawRectangleRec(btns[i].rect, color)
        
        label_cstr := strings.clone_to_cstring(btns[i].label)
        defer delete(label_cstr)
        text_width := rl.MeasureText(label_cstr, UNIT_SIZE)
        rl.DrawText(label_cstr,
                   i32(btns[i].rect.x + btns[i].rect.width/2 - f32(text_width)/2),
                   i32(btns[i].rect.y + btns[i].rect.height/2 - f32(UNIT_SIZE)/2),
                   UNIT_SIZE, rl.BLACK)
    }
}

draw_sliders :: proc() {
    for i in 0..<num_sliders {
        // Draw slider track
        rl.DrawRectangleRec(sliders[i].bounds, rl.RED)
        rl.DrawRectangle(i32(sliders[i].bounds.x),
                        i32(sliders[i].bounds.y + sliders[i].bounds.height - f32(UNIT_SIZE) - f32(UNIT_SIZE)/4),
                        i32(sliders[i].bounds.width),
                        UNIT_SIZE/2,
                        rl.LIGHTGRAY)
        
        // Draw slider handle
        color := rl.LIGHTGRAY
        if button_mouse_hover == MAX_BTNS + i || slider_focused == i {
            color = rl.GRAY
        }
        rl.DrawRectangleRec(sliders[i].rect, color)
        
        // Draw label
        label_cstr := strings.clone_to_cstring(sliders[i].label)
        defer delete(label_cstr)
        text_width := rl.MeasureText(label_cstr, UNIT_SIZE)
        rl.DrawText(label_cstr,
                   i32(sliders[i].bounds.x + sliders[i].bounds.width/2 - f32(text_width)/2),
                   i32(sliders[i].bounds.y),
                   UNIT_SIZE, rl.BLACK)
    }
}

is_mouse_on_ui :: proc() -> bool {
    return button_mouse_hover >= 0 || slider_focused >= 0
}

draw_ui :: proc() {
    draw_btns()
    draw_sliders()
    
    num_objects_text := fmt.ctprintf("Num Objects: %d", num_objects)
    rl.DrawText(num_objects_text, 40, 680, 20, rl.RAYWHITE)
    
    rl.DrawRectangleRec(rl.Rectangle{WIDTH - 230, 40, 200, 100}, 
                       rl.Color{u8(g_red), u8(g_green), u8(g_blue), 255})
    
    struct_text := "N/A"
    x_pos: i32 = 100
    #partial switch g_struct_type {
    case .DEFAULT:
        struct_text = "Ball"
        x_pos = 110
    case .ROPE:
        struct_text = "Rope"
    case .CLOTH:
        struct_text = "Cloth"
    }
    struct_text_cstr := strings.clone_to_cstring(struct_text)
    defer delete(struct_text_cstr)
    rl.DrawText(struct_text_cstr, x_pos, 500, 20, rl.RAYWHITE)
}

update_draw_frame :: proc() {
    object_color := rl.Color{u8(g_red), u8(g_green), u8(g_blue), 255}
    
    if rl.IsMouseButtonPressed(.LEFT) && !is_mouse_on_ui() {
        frames_counter = 100
    }
    
    if rl.IsMouseButtonDown(.LEFT) && !is_mouse_on_ui() {
        if frames_counter >= 60/int(g_spawn_rate) {
            frames_counter = 0
            if g_struct_type == .DEFAULT {
                spawn_verlet(
                    g_mouse_pos,
                    g_spawn_radius,
                    rl.Color{
                        u8(clamp(g_red + f32(random_value(-40, 40)), 0, 255)),
                        u8(clamp(g_green + f32(random_value(-40, 40)), 0, 255)),
                        u8(clamp(g_blue + f32(random_value(-40, 40)), 0, 255)),
                        255,
                    }
                )
            } else if g_struct_type == .ROPE {
                spawn_struct_rope(g_mouse_pos, 35, 25, 8, .BOTH, object_color)
            } else if g_struct_type == .CLOTH {
                spawn_struct_cloth(g_mouse_pos, 60, 12, 0, object_color)
            }
        }
    }
    // Cap dt at a reasonable value
    frame_time := rl.GetFrameTime()
    if frame_time > MAX_LATENCY do frame_time = MAX_LATENCY
    substep_time := frame_time / f32(SUBSTEPS)
    
    update_verlet(substep_time)
    update_ui()
    frames_counter += 1
    
    // Draw
    rl.BeginDrawing()
    rl.ClearBackground(rl.Color{50, 45, 55, 255})
    
    if g_apply_constraint {
        rl.DrawCircleSector(rl.Vector2{f32(WIDTH)/2, f32(HEIGHT)/2}, 400, 0, 360, 128, 
                           rl.Color{28, 27, 25, 255})
    }
    draw_verlet()
    draw_ui()
    rl.DrawFPS(10, 10)
    rl.EndDrawing()
}

main :: proc() {
    rl.SetConfigFlags({.MSAA_4X_HINT})
    rl.InitWindow(WIDTH, HEIGHT, "Verlet Integration")
    defer rl.CloseWindow()
    rl.SetTargetFPS(60)
    init_ui()
    for !rl.WindowShouldClose() {
        update_draw_frame()
    }
}