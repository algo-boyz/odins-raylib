package main

import "core:fmt"
import "core:time"
import "core:math/rand"
import rl "vendor:raylib"

SCREEN_WIDTH  :: 1280
SCREEN_HEIGHT :: 720

Animation :: struct {
    texture:                 rl.Texture2D,
    scale:                   f32,
    update_time:             f32,
    total_frames:            int,
    source:                  rl.Rectangle,
    width:                   f32,
    height:                  f32,
    running_time:            f32,
    frame:                   int,
    started:                 bool,
}

init_animation :: proc(texture: rl.Texture2D, scale: f32, update_time: f32, total_frames: int) -> Animation {
    frame_width := f32(texture.width) / f32(total_frames)
    frame_height := f32(texture.height)
    anim: Animation
    anim.texture = texture
    anim.scale = scale
    anim.update_time = update_time
    anim.total_frames = total_frames
    anim.source = {0, 0, frame_width, frame_height}
    anim.width = scale * frame_width
    anim.height = scale * frame_height
    anim.running_time = 0.0
    anim.frame = 0
    anim.started = true
    return anim
}

re_scale :: proc(anim: ^Animation, new_scale: f32) {
    anim.scale = new_scale
    frame_width := f32(anim.texture.width) / f32(anim.total_frames)
    frame_height := f32(anim.texture.height)
    anim.width = anim.scale * frame_width
    anim.height = anim.scale * frame_height
}

draw_animation :: proc(anim: ^Animation, pos: rl.Vector2, flip: bool, color: rl.Color) {
    src := anim.source
    if flip {
        src.width *= -1
    }
    dst := rl.Rectangle{pos.x, pos.y, anim.width, anim.height}
    rl.DrawTexturePro(anim.texture, src, dst, {0, 0}, 0, color)
}

update_frame :: proc(anim: ^Animation) {
    anim.running_time += rl.GetFrameTime()
    if anim.running_time >= anim.update_time {
        anim.started = true
        anim.running_time = 0
        if anim.frame == anim.total_frames {
            anim.frame = 0
        }
        anim.source.x = f32(anim.frame) * anim.source.width
        anim.frame += 1
    } else {
        anim.started = false
    }
}

finished_animation :: proc(anim: ^Animation) -> bool {
    return anim.frame == anim.total_frames && anim.running_time >= anim.update_time
}

unload_texture :: proc(anim: ^Animation) {
    rl.UnloadTexture(anim.texture)
}

Background :: struct {
    texture:    rl.Texture2D,
    pos:        rl.Vector2,
    pos_offset: rl.Vector2,
    distance:   f32,
    scale:      f32,
}

bg_init :: proc(texture: rl.Texture2D, pos, pos_offset: rl.Vector2, distance, scale: f32) -> ^Background {
    bg := new(Background)
    bg.texture = texture
    bg.pos = pos + pos_offset
    bg.pos_offset = pos_offset
    bg.distance = distance == 0 ? 1 : distance
    bg.scale = scale
    return bg
}

bg_destroy :: proc(bg: ^Background) {
    rl.UnloadTexture(bg.texture)
    free(bg)
}

get_scaled_size :: proc(b: ^Background) -> rl.Vector2 {
    return {f32(b.texture.width) * b.scale, f32(b.texture.height) * b.scale}
}

set_pos_above_line :: proc(b: ^Background, y: f32) {
    b.pos.y = (y - get_scaled_size(b).y) + b.pos_offset.y
}

set_pos_below_line :: proc(b: ^Background, y: f32) {
    b.pos.y = y + b.pos_offset.y
}

draw_background :: proc(b: ^Background, camera_pos: rl.Vector2, remove_vertical_shift: bool, background_padding: int, tint_color: rl.Color) {
    pos := rl.Vector2{camera_pos.x / b.distance, camera_pos.y / b.distance}
    if remove_vertical_shift {
        pos.y *= b.distance
    }
    scaled_width := f32(b.texture.width) * b.scale

    if pos.x >= scaled_width + b.pos.x {
        b.pos.x = pos.x
    }
    if pos.x <= -scaled_width + b.pos.x {
        b.pos.x = pos.x
    }
    temp_pos := rl.Vector2{b.pos.x - f32(background_padding) * scaled_width, b.pos.y}
    for i in 0 ..< background_padding * 2 + 1 {
        draw_pos := rl.Vector2{temp_pos.x - pos.x, temp_pos.y - pos.y}
        rl.DrawTextureEx(b.texture, draw_pos, 0, b.scale, tint_color)
        temp_pos.x += scaled_width
    }
}

Light_Mode :: enum {
    NONE,
    FADE_OUT,
    RANGE_SHIFT,
    INTENSITY_SHIFT,
    RANGE_AND_INTENSITY_SHIFT,
    FLICKER,
}

Light :: struct {
    pos:                  rl.Vector2,
    original_range:       f32,
    original_intensity:   f32,
    range:                f32,
    intensity:            f32,
    color:                rl.Color,
    mode:                 Light_Mode,
    mode_value:           f32,
    range_shift_bound:    rl.Vector2,
    intensity_shift_bound: rl.Vector2,
}

init_light :: proc(pos: rl.Vector2, original_range, original_intensity: f32, color: rl.Color, mode: Light_Mode, mode_value: f32, range_shift_bound, intensity_shift_bound: rl.Vector2) -> ^Light {
    ls := new(Light)
    ls.pos = pos
    ls.color = color
    ls.mode = mode
    ls.mode_value = mode_value
    ls.range_shift_bound = range_shift_bound
    ls.intensity_shift_bound = intensity_shift_bound

    if ls.range_shift_bound.x < 0 { ls.range_shift_bound.x = 0 }
    if ls.intensity_shift_bound.x < 0 { ls.intensity_shift_bound.x = 0 }

    ls.original_range = original_range < 0 ? 0 : original_range
    ls.range = ls.original_range
    ls.original_intensity = original_intensity < 0 ? 0 : original_intensity
    ls.intensity = ls.original_intensity
    return ls
}

draw_light :: proc(ls: ^Light, camera_pos: rl.Vector2, radius: f32, color: rl.Color) {
    rl.DrawCircle(i32(ls.pos.x - camera_pos.x), i32(ls.pos.y - camera_pos.y), radius, color)
}

check_bound :: proc(value: ^f32, bound: rl.Vector2) {
    if value^ < bound.x { value^ = bound.x }
    if value^ > bound.y { value^ = bound.y }
}

influence_by_mode :: proc(ls: ^Light) {
    dt := rl.GetFrameTime()
    abs_mode_value := abs(ls.mode_value)

    #partial switch ls.mode {
    case .FADE_OUT:
        ls.range -= abs_mode_value * dt
        ls.intensity -= abs_mode_value * dt
        if ls.range < 0 { ls.range = 0 }
        if ls.intensity < 0 { ls.intensity = 0 }

    case .RANGE_SHIFT:
        if ls.range >= ls.range_shift_bound.y { ls.mode_value = -abs_mode_value }
        else if ls.range <= ls.range_shift_bound.x { ls.mode_value = abs_mode_value }
        ls.range += ls.mode_value * dt
        check_bound(&ls.range, ls.range_shift_bound)

    case .INTENSITY_SHIFT:
        if ls.intensity >= ls.intensity_shift_bound.y { ls.mode_value = -abs_mode_value }
        else if ls.intensity <= ls.intensity_shift_bound.x { ls.mode_value = abs_mode_value }
        ls.intensity += ls.mode_value * dt
        check_bound(&ls.intensity, ls.intensity_shift_bound)

    case .RANGE_AND_INTENSITY_SHIFT:
        if ls.range >= ls.range_shift_bound.y && ls.intensity >= ls.intensity_shift_bound.y {
            ls.mode_value = -abs_mode_value
        } else if ls.range <= ls.range_shift_bound.x && ls.intensity <= ls.intensity_shift_bound.x {
            ls.mode_value = abs_mode_value
        }
        ls.range += ls.mode_value * dt
        ls.intensity += ls.mode_value * dt
        check_bound(&ls.range, ls.range_shift_bound)
        check_bound(&ls.intensity, ls.intensity_shift_bound)

    case .FLICKER:
        if ls.mode_value != 0 {
            rand_val := f32(rand.int_max(int(abs_mode_value))) - (abs_mode_value / 2)
            ls.range = ls.original_range + rand_val
        }
    }
}

Shadow :: struct {
    pos:    rl.Vector2,
    width:  f32,
    height: f32,
    color:  rl.Color,
}

init_shadow :: proc(pos: rl.Vector2, width, height: f32, color: rl.Color) -> ^Shadow {
    s := new(Shadow)
    s.pos = pos
    s.width = width
    s.height = height
    s.color = color
    return s
}

get_center_pos :: proc(s: ^Shadow) -> rl.Vector2 {
    return {s.pos.x + s.width / 2, s.pos.y + s.height / 2}
}

draw_shadow :: proc(s: ^Shadow, camera_pos: rl.Vector2) {
    rl.DrawRectangle(i32(s.pos.x - camera_pos.x), i32(s.pos.y - camera_pos.y), i32(s.width), i32(s.height), s.color)
}

// Color combination and light influence logic
combine_colors :: proc(colors: []rl.Color, weights: []f32) -> rl.Color {
    if len(colors) == 0 {
        return {0, 0, 0, 0}
    }

    r, g, b: f32
    total_weight: f32
    for weight in weights {
        total_weight += weight
    }

    if total_weight == 0 {
        return {0,0,0,0}
    }

    for i in 0 ..< len(colors) {
        r += f32(colors[i].r) * weights[i]
        g += f32(colors[i].g) * weights[i]
        b += f32(colors[i].b) * weights[i]
    }

    r /= total_weight
    g /= total_weight
    b /= total_weight

    return {u8(r), u8(g), u8(b), 0}
}

handle_light_influence_color :: proc(s: ^Shadow, camera_pos: rl.Vector2, lights: []^Light) {
    center_pos := get_center_pos(s)
    
    colors_to_combine := make([dynamic]rl.Color, 0, len(lights))
    defer delete(colors_to_combine)

    weights := make([dynamic]f32, 0, len(lights))
    defer delete(weights)
    
    max_alpha : u8 = 0
    
    for ls in lights {
        distance := rl.Vector2Length(ls.pos - camera_pos - center_pos)
        if ls.range > 0 && distance <= ls.range {
            append(&colors_to_combine, ls.color)

            new_alpha := (1 - distance / ls.range) * ls.intensity
            append(&weights, new_alpha)
            
            if new_alpha > 255 { new_alpha = 255 }
            if s.color.a < u8(new_alpha) { s.color.a = u8(new_alpha) }
        }
    }

    if len(colors_to_combine) > 0 {
        old_alpha := s.color.a
        s.color = combine_colors(colors_to_combine[:], weights[:])
        s.color.a = old_alpha
    }
}

handle_light_influence_alpha :: proc(s: ^Shadow, camera_pos: rl.Vector2, lights: []^Light) {
    center_pos := get_center_pos(s)
    for ls in lights {
        distance := rl.Vector2Length(ls.pos - camera_pos - center_pos)
        if ls.range > 0 && distance <= ls.range {
            s.color.a = u8(f32(s.color.a) * (distance / ls.range))
        }
    }
}

check_alpha_bound :: proc(s: ^Shadow, min_alpha, max_alpha: u8) {
    if s.color.a < min_alpha { s.color.a = min_alpha }
    if s.color.a > max_alpha { s.color.a = max_alpha }
}

Fog :: struct {
    original_color: rl.Color,
    min_alpha:      u8,
    max_alpha:      u8,
    
    color_shadows:  [dynamic][dynamic]^Shadow,
    alpha_shadows:  [dynamic][dynamic]^Shadow,
}

init_fog :: proc(original_color: rl.Color, min_alpha, max_alpha: u8, num_rows, num_cols: int) -> ^Fog {
    fow := new(Fog)
    fow.original_color = original_color
    fow.min_alpha = min_alpha
    fow.max_alpha = max_alpha

    fow.color_shadows = create_shadows(num_rows, num_cols, original_color)
    fow.alpha_shadows = create_shadows(num_rows, num_cols, original_color)
    reset_shadow(fow)
    return fow
}

destroy_fog :: proc(fow: ^Fog) {
    clear_shadows(&fow.color_shadows)
    clear_shadows(&fow.alpha_shadows)
    free(fow)
}

create_shadows :: proc(num_rows, num_cols: int, color: rl.Color) -> [dynamic][dynamic]^Shadow {
    shadows := make([dynamic][dynamic]^Shadow, num_rows)
    width := f32(SCREEN_WIDTH) / f32(num_cols)
    height := f32(SCREEN_HEIGHT) / f32(num_rows)
    pos := rl.Vector2{}

    for row in 0 ..< num_rows {
        pos.x = 0
        shadows[row] = make([dynamic]^Shadow, num_cols)
        for col in 0 ..< num_cols {
            shadows[row][col] = init_shadow(pos, width, height, color)
            pos.x += width
        }
        pos.y += height
    }
    return shadows
}

clear_shadows :: proc(shadows: ^[dynamic][dynamic]^Shadow) {
    for row in shadows^ {
        for shadow in row {
            free(shadow)
        }
        delete(row)
    }
    delete(shadows^)
}

draw_fog :: proc(fow: ^Fog) {
    // Draw the main fog/color grid
    for row in fow.color_shadows {
        for shadow in row {
            draw_shadow(shadow, {0,0}) // Shadow draw_animation is already in screen space
        }
    }
    for row in fow.alpha_shadows {
        for shadow in row {
            draw_shadow(shadow, {0,0})
        }
    }
}

reset_shadow :: proc(fow: ^Fog) {
    for row in fow.color_shadows {
        for shadow in row {
            shadow.color = {fow.original_color.r, fow.original_color.g, fow.original_color.b, fow.min_alpha}
        }
    }
    for row in fow.alpha_shadows {
        for shadow in row {
            shadow.color = {fow.original_color.r, fow.original_color.g, fow.original_color.b, fow.max_alpha}
        }
    }
}

handle_light_source_influence :: proc(fow: ^Fog, camera_pos: rl.Vector2, lights: []^Light) {
    for row in fow.color_shadows {
        for shadow in row {
            handle_light_influence_color(shadow, camera_pos, lights)
        }
    }
    for row in fow.alpha_shadows {
        for shadow in row {
            handle_light_influence_alpha(shadow, camera_pos, lights)
        }
    }
}

check_alpha_bound_fog :: proc(fow: ^Fog) {
    for row in fow.color_shadows {
        for shadow in row {
            check_alpha_bound(shadow, fow.min_alpha, fow.max_alpha)
        }
    }
    for row in fow.alpha_shadows {
        for shadow in row {
            check_alpha_bound(shadow, fow.min_alpha, fow.max_alpha)
        }
    }
}

Effect_Type :: enum {
    BLUE_BALL,
    PURPLE_SQUARES,
    BLUE_CROSS,
}

ball_effect:                 Animation
squares_effect: Animation
cross_effect:                Animation

Effect :: struct {
    pos:         rl.Vector2,
    facing_left: bool,
    scale:       f32,
    animation:   Animation,
    light_source: ^Light,
}

load_effects :: proc() {
    ball_effect    = init_animation(rl.LoadTexture("assets/effect/ball.png"), 1, 1.0 / 48.0, 17)
    squares_effect = init_animation(rl.LoadTexture("assets/effect/squares.png"), 1, 1.0 / 48.0, 15)
    cross_effect   = init_animation(rl.LoadTexture("assets/effect/cross.png"), 1, 1.0 / 48.0, 18)
}

unload_effects :: proc() {
    unload_texture(&ball_effect)
    unload_texture(&squares_effect)
    unload_texture(&cross_effect)
}

init_effect :: proc(effect_type: Effect_Type, center_pos: rl.Vector2, facing_left: bool, scale: f32) -> ^Effect {
    e := new(Effect)
    e.facing_left = facing_left
    e.scale = scale

    #partial switch effect_type {
    case .BLUE_BALL:
        e.animation = ball_effect
        e.light_source = init_light(center_pos, scale * 100, 200, rl.BLUE, .FADE_OUT, scale * 100, {}, {})
    case .PURPLE_SQUARES:
        e.animation = squares_effect
        e.light_source = init_light(center_pos, scale * 100, 200, rl.PURPLE, .FADE_OUT, scale * 100, {}, {})
    case .BLUE_CROSS:
        e.animation = cross_effect
        e.light_source = init_light(center_pos, scale * 100, 200, rl.BLUE, .FADE_OUT, scale * 100, {}, {})
    }
    re_scale(&e.animation, scale)
    set_hit_box(e, center_pos)
    if e.light_source != nil {
        e.light_source.pos = center_pos
    }
    return e
}

destroy_effect :: proc(e: ^Effect) {
    if e.light_source != nil {
        free(e.light_source)
    }
    free(e)
}

get_hit_box :: proc(e: ^Effect, camera_pos: rl.Vector2) -> rl.Rectangle {
    return {e.pos.x - camera_pos.x, e.pos.y - camera_pos.y, e.animation.width, e.animation.height}
}

get_hit_box_center_pos :: proc(e: ^Effect) -> rl.Vector2 {
    hit_box := get_hit_box(e, {0, 0})
    return {hit_box.x + hit_box.width / 2, hit_box.y + hit_box.height / 2}
}

set_hit_box :: proc(e: ^Effect, pos: rl.Vector2) {
    change_vector := pos - get_hit_box_center_pos(e)
    e.pos = e.pos + change_vector
}

draw_effect :: proc(e: ^Effect, camera_pos: rl.Vector2, tint: rl.Color = rl.WHITE) {
    draw_animation(&e.animation, {e.pos.x - camera_pos.x, e.pos.y - camera_pos.y}, e.facing_left, tint)
    update_frame(&e.animation)
}

finished_effect :: proc(e: ^Effect) -> bool {
    return finished_animation(&e.animation)
}

Scene :: struct {
    top_of_ground:     f32,
    bottom_of_ground:  f32,
    bg_layers:         [dynamic]^Background,
    ground_layers:     [dynamic]^Background,
    fg_layers:         [dynamic]^Background,
}

init_scene :: proc() -> ^Scene {
    s := new(Scene)
    return s
}

destroy_scene :: proc(s: ^Scene) {
    destroy_layers(&s.bg_layers)
    destroy_layers(&s.ground_layers)
    destroy_layers(&s.fg_layers)
    free(s)
}

destroy_layers :: proc(layers: ^[dynamic]^Background) {
    for layer in layers^ {
        bg_destroy(layer)
    }
    delete(layers^)
}

set_layers_above_line :: proc(layers: []^Background, y: f32) {
    for layer in layers {
        set_pos_above_line(layer, y)
    }
}

set_layers_below_line :: proc(layers: []^Background, y: f32) {
    for layer in layers {
        set_pos_below_line(layer, y)
    }
}

draw_scene :: proc(s: ^Scene, camera_pos: rl.Vector2, remove_vertical_shift: bool, background_padding: int, tint_color: rl.Color = rl.WHITE, foreground_color: rl.Color = rl.WHITE) {
    for layer in s.bg_layers {
        draw_background(layer, camera_pos, remove_vertical_shift, background_padding, tint_color)
    }
    for layer in s.ground_layers {
        draw_background(layer, camera_pos, remove_vertical_shift, background_padding, tint_color)
    }
    for layer in s.fg_layers {
        draw_background(layer, camera_pos, remove_vertical_shift, background_padding, foreground_color)
    }
}

draw_ground_borders :: proc(s: ^Scene, camera_pos: rl.Vector2, thick: f32, top_color, bottom_color: rl.Color) {
    start_pos_top := rl.Vector2{0, s.top_of_ground - camera_pos.y}
    end_pos_top := rl.Vector2{f32(SCREEN_WIDTH), s.top_of_ground - camera_pos.y}
    rl.DrawLineEx(start_pos_top, end_pos_top, thick, top_color)

    start_pos_bottom := rl.Vector2{0, s.bottom_of_ground - camera_pos.y}
    end_pos_bottom := rl.Vector2{f32(SCREEN_WIDTH), s.bottom_of_ground - camera_pos.y}
    rl.DrawLineEx(start_pos_bottom, end_pos_bottom, thick, bottom_color)
}

Cam :: struct {
    pos:    rl.Vector2,
    speed:  f32,
    locked: bool,
}

input_cam :: proc(c: ^ Cam) {
    direction := rl.Vector2{}
    if rl.IsKeyDown(.LEFT) { direction.x -= 1 }
    if rl.IsKeyDown(.RIGHT) { direction.x += 1 }
    if rl.IsKeyDown(.UP) { direction.y -= 1 }
    if rl.IsKeyDown(.DOWN) { direction.y += 1 }
    direction = rl.Vector2Normalize(direction)

    change_vector := direction * c.speed * rl.GetFrameTime()
    c.pos = c.pos + change_vector

    if rl.IsKeyDown(.UP) || rl.IsKeyDown(.DOWN) || rl.IsKeyDown(.LEFT) || rl.IsKeyDown(.RIGHT) {
        c.locked = false
    }
    if rl.IsKeyPressed(.L) || rl.IsMouseButtonPressed(.MIDDLE) {
        c.locked = !c.locked
    }
}

check_top_down_bound :: proc(c: ^ Cam, vertical_bound: rl.Vector2) {
    if c.pos.y < vertical_bound.x { c.pos.y = vertical_bound.x }
    if c.pos.y > vertical_bound.y - f32(SCREEN_HEIGHT) { c.pos.y = vertical_bound.y - f32(SCREEN_HEIGHT) }
}

check_left_right_bound :: proc(c: ^ Cam, horizontal_bound: rl.Vector2) {
    if c.pos.x < horizontal_bound.x { c.pos.x = horizontal_bound.x }
    if c.pos.x > horizontal_bound.y - f32(SCREEN_WIDTH) { c.pos.x = horizontal_bound.y - f32(SCREEN_WIDTH) }
}

check_bounds :: proc(c: ^ Cam, vertical_bound, horizontal_bound: rl.Vector2) {
    check_top_down_bound(c, vertical_bound)
    check_left_right_bound(c, horizontal_bound)
}

camera:           Cam
vertical_bound:  rl.Vector2 = {-500, f32(SCREEN_HEIGHT) + 500}
scene_index:     int
scenes:          [dynamic]^Scene
effects:         [dynamic]^Effect
lights:          [dynamic]^Light
fog:             ^Fog
show_fog:        bool

cave :: proc() {
    scene := init_scene()
    pos: rl.Vector2 = {0, 0}
    scale: f32 = 5

    scene.top_of_ground = f32(SCREEN_HEIGHT)
    scene.bottom_of_ground = f32(SCREEN_HEIGHT)
    
    append(&scene.bg_layers, bg_init(rl.LoadTexture("assets/cave/7.png"), pos, {0, 0}, 5, scale))
    append(&scene.bg_layers, bg_init(rl.LoadTexture("assets/cave/6.png"), pos, {0, 0}, 4, scale))
    append(&scene.bg_layers, bg_init(rl.LoadTexture("assets/cave/5.png"), pos, {0, 0}, 3, scale))
    append(&scene.bg_layers, bg_init(rl.LoadTexture("assets/cave/4.png"), pos, {0, 0}, 2, scale))
    append(&scene.bg_layers, bg_init(rl.LoadTexture("assets/cave/3.png"), pos, {0, 0}, 1, scale))
    append(&scene.fg_layers, bg_init(rl.LoadTexture("assets/cave/2.png"), pos, {0, 0}, 0.8, scale))
    append(&scene.fg_layers, bg_init(rl.LoadTexture("assets/cave/1.png"), pos, {0, 0}, 0.6, scale))

    set_layers_above_line(scene.bg_layers[:], scene.bottom_of_ground)
    set_layers_above_line(scene.ground_layers[:], scene.bottom_of_ground)
    set_layers_above_line(scene.fg_layers[:], scene.bottom_of_ground)

    append(&scenes, scene)
}

dark_forest :: proc() {
    scene := init_scene()
    pos: rl.Vector2 = {0, 0}
    scale: f32 = 1.8

    scene.top_of_ground = f32(SCREEN_HEIGHT - 115)
    scene.bottom_of_ground = f32(SCREEN_HEIGHT)

    append(&scene.bg_layers, bg_init(rl.LoadTexture("assets/dark_forest/0.png"), pos, {0, 0}, 2.4, scale))
    append(&scene.bg_layers, bg_init(rl.LoadTexture("assets/dark_forest/1.png"), pos, {0, 0}, 2.2, scale))
    append(&scene.bg_layers, bg_init(rl.LoadTexture("assets/dark_forest/2.png"), pos, {0, 0}, 2.0, scale))
    append(&scene.bg_layers, bg_init(rl.LoadTexture("assets/dark_forest/3.png"), pos, {0, 0}, 1.8, scale))
    append(&scene.bg_layers, bg_init(rl.LoadTexture("assets/dark_forest/4.png"), pos, {0, 0}, 1.6, scale))
    append(&scene.bg_layers, bg_init(rl.LoadTexture("assets/dark_forest/4_Lights.png"), pos, {0, 0}, 1.6, scale))
    append(&scene.bg_layers, bg_init(rl.LoadTexture("assets/dark_forest/5.png"), pos, {0, 0}, 1.4, scale))
    append(&scene.bg_layers, bg_init(rl.LoadTexture("assets/dark_forest/6.png"), pos, {0, 0}, 1.2, scale))
    append(&scene.bg_layers, bg_init(rl.LoadTexture("assets/dark_forest/7.png"), pos, {0, 0}, 1, scale))
    append(&scene.bg_layers, bg_init(rl.LoadTexture("assets/dark_forest/7_Lights.png"), pos, {0, 0}, 1, scale))
    append(&scene.ground_layers, bg_init(rl.LoadTexture("assets/dark_forest/8.png"), pos, {0, 0}, 1, scale))
    append(&scene.ground_layers, bg_init(rl.LoadTexture("assets/dark_forest/9.png"), pos, {0, 0}, 1, scale))

    set_layers_above_line(scene.bg_layers[:], scene.bottom_of_ground)
    set_layers_above_line(scene.ground_layers[:], scene.bottom_of_ground)

    append(&scenes, scene)
}

dead_forest :: proc() {
    scene := init_scene()
    pos: rl.Vector2 = {0, 0}
    scale: f32 = 5

    scene.top_of_ground = f32(SCREEN_HEIGHT - 340)
    scene.bottom_of_ground = f32(SCREEN_HEIGHT)

    append(&scene.bg_layers, bg_init(rl.LoadTexture("assets/dead_forest/6.png"), pos, {0, 0}, 5, scale))
    append(&scene.bg_layers, bg_init(rl.LoadTexture("assets/dead_forest/5.png"), pos, {0, 0}, 4, scale))
    append(&scene.bg_layers, bg_init(rl.LoadTexture("assets/dead_forest/4.png"), pos, {0, 0}, 3, scale))
    append(&scene.bg_layers, bg_init(rl.LoadTexture("assets/dead_forest/3.png"), pos, {0, 0}, 2, scale))
    append(&scene.ground_layers, bg_init(rl.LoadTexture("assets/dead_forest/2.png"), pos, {0, 0}, 1, scale))
    append(&scene.fg_layers, bg_init(rl.LoadTexture("assets/dead_forest/1.png"), pos, {0, 0}, 0.7, scale))

    set_layers_above_line(scene.bg_layers[:], scene.bottom_of_ground)
    set_layers_above_line(scene.ground_layers[:], scene.bottom_of_ground)
    set_layers_above_line(scene.fg_layers[:], scene.bottom_of_ground)

    append(&scenes, scene)
}

plains :: proc() {
    scene := init_scene()
    pos: rl.Vector2 = {0, 0}
    scale: f32 = 5

    scene.top_of_ground = f32(SCREEN_HEIGHT - 65)
    scene.bottom_of_ground = f32(SCREEN_HEIGHT)

    append(&scene.bg_layers, bg_init(rl.LoadTexture("assets/plains/8.png"), pos, {0, 0}, 11, scale))
    append(&scene.bg_layers, bg_init(rl.LoadTexture("assets/plains/7.png"), pos, {0, 0}, 9, scale))
    append(&scene.bg_layers, bg_init(rl.LoadTexture("assets/plains/6.png"), pos, {0, 0}, 7, scale))
    append(&scene.bg_layers, bg_init(rl.LoadTexture("assets/plains/5.png"), pos, {0, 0}, 5, scale))
    append(&scene.bg_layers, bg_init(rl.LoadTexture("assets/plains/4.png"), pos, {0, 0}, 3, scale))
    append(&scene.bg_layers, bg_init(rl.LoadTexture("assets/plains/3.png"), pos, {0, 0}, 2, scale))
    append(&scene.ground_layers, bg_init(rl.LoadTexture("assets/plains/2.png"), pos, {0, 0}, 1, scale))
    append(&scene.fg_layers, bg_init(rl.LoadTexture("assets/plains/1.png"), pos, {0, 0}, 0.6, scale))

    set_layers_above_line(scene.bg_layers[:], scene.bottom_of_ground)
    set_layers_above_line(scene.ground_layers[:], scene.bottom_of_ground)
    set_layers_above_line(scene.fg_layers[:], scene.bottom_of_ground)

    append(&scenes, scene)
}

snowy_mountains :: proc() {
    scene := init_scene()
    pos: rl.Vector2 = {0, 0}
    scale: f32 = 5

    scene.top_of_ground = f32(SCREEN_HEIGHT)
    scene.bottom_of_ground = f32(SCREEN_HEIGHT)
    
    append(&scene.bg_layers, bg_init(rl.LoadTexture("assets/snowy_mountains/5.png"), pos, {0, 0}, 5, scale))
    append(&scene.bg_layers, bg_init(rl.LoadTexture("assets/snowy_mountains/4.png"), pos, {0, 0}, 4, scale))
    append(&scene.bg_layers, bg_init(rl.LoadTexture("assets/snowy_mountains/3.png"), pos, {0, 0}, 3, scale))
    append(&scene.bg_layers, bg_init(rl.LoadTexture("assets/snowy_mountains/2.png"), pos, {0, 0}, 2, scale))
    append(&scene.ground_layers, bg_init(rl.LoadTexture("assets/snowy_mountains/1.png"), pos, {0, 0}, 1, scale))

    set_layers_above_line(scene.bg_layers[:], scene.bottom_of_ground)
    set_layers_above_line(scene.ground_layers[:], scene.bottom_of_ground)

    append(&scenes, scene)
}

sunny_hill :: proc() {
    scene := init_scene()
    pos: rl.Vector2 = {0, 0}
    scale: f32 = 4

    scene.top_of_ground = f32(SCREEN_HEIGHT - 65)
    scene.bottom_of_ground = f32(SCREEN_HEIGHT)
    
    append(&scene.bg_layers, bg_init(rl.LoadTexture("assets/sunny_hill/1.png"), pos, {0, 0}, 1.8, scale))
    append(&scene.bg_layers, bg_init(rl.LoadTexture("assets/sunny_hill/2.png"), pos, {0, 0}, 1.6, scale))
    append(&scene.bg_layers, bg_init(rl.LoadTexture("assets/sunny_hill/3.png"), pos, {0, 0}, 1.4, scale))
    append(&scene.bg_layers, bg_init(rl.LoadTexture("assets/sunny_hill/4.png"), pos, {0, 0}, 1.2, scale))
    append(&scene.ground_layers, bg_init(rl.LoadTexture("assets/sunny_hill/5.png"), pos, {0, 0}, 1, scale))
    append(&scene.fg_layers, bg_init(rl.LoadTexture("assets/sunny_hill/6.png"), pos, {0, 0}, 0.8, scale))

    set_layers_above_line(scene.bg_layers[:], scene.bottom_of_ground)
    set_layers_above_line(scene.ground_layers[:], scene.bottom_of_ground)
    set_layers_above_line(scene.fg_layers[:], scene.bottom_of_ground)

    append(&scenes, scene)
}

init :: proc() {
    camera = {pos = {0, 0}, speed = 800, locked = false}
    cave()
    dark_forest()
    dead_forest()
    plains()
    snowy_mountains()
    sunny_hill()
    scene_index = 0
    load_effects()
    fog = init_fog({0, 0, 0, 255}, 100, 255, 20, 20)
    show_fog = true
}

print_mouse_pos :: proc() {
    pos: rl.Vector2 = {10, 10}
    font_size: i32 = 30
    
    mouse_world_pos := rl.GetMousePosition() + camera.pos
    world_msg := fmt.caprintf("World Pos: %d, %d", i32(mouse_world_pos.x), i32(mouse_world_pos.y))
    rl.DrawText(world_msg, i32(pos.x), i32(pos.y), font_size, rl.YELLOW)
    pos.y += f32(font_size)

    mouse_screen_pos := rl.GetMousePosition()
    screen_msg := fmt.caprintf("Screen Pos: %d, %d", i32(mouse_screen_pos.x), i32(mouse_screen_pos.y))
    rl.DrawText(screen_msg, i32(pos.x), i32(pos.y), font_size, rl.YELLOW)
}

draw :: proc() {
    rl.BeginDrawing()
    defer rl.EndDrawing()
    rl.ClearBackground(rl.BLACK)

    if scene_index >= 0 && scene_index < len(scenes) {
        draw_scene(scenes[scene_index], camera.pos, true, 2)
        //draw_ground_borders(scenes[scene_index], camera.pos, 2, rl.RED, rl.BLUE)
    }
    for effect in effects {
        draw_effect(effect, camera.pos)
    }
    if show_fog {
        draw_fog(fog)
    }
    print_mouse_pos()
}

swap_scenes :: proc() {
    if rl.IsMouseButtonPressed(.RIGHT) {
        scene_index += 1
        if scene_index >= len(scenes) {
            if len(scenes) > 0 {
                scene_index = 0
            } else {
                scene_index = -1
            }
        }
    }
}

spawn_effect :: proc() {
    pos := rl.GetMousePosition() + camera.pos
    facing_left := false
    scale: f32 = 3
    if rl.IsKeyPressed(.ONE) { append(&effects, init_effect(.BLUE_BALL, pos, facing_left, scale)) }
    if rl.IsKeyPressed(.TWO) { append(&effects, init_effect(.PURPLE_SQUARES, pos, facing_left, scale)) }
    if rl.IsKeyPressed(.THREE) { append(&effects, init_effect(.BLUE_CROSS, pos, facing_left, scale)) }
}

input :: proc() {
    swap_scenes()
    spawn_effect()
    if rl.IsMouseButtonPressed(.LEFT) {
        show_fog = !show_fog
    }
    input_cam(&camera)
}

logic :: proc() {
    // Effect Logic
    i := 0
    for i < len(effects) {
        if finished_effect(effects[i]) {
            destroy_effect(effects[i])
            ordered_remove(&effects, i)
        } else {
            i += 1
        }
    }
    clear(&lights)
    for effect in effects {
        if effect.light_source != nil {
            append(&lights, effect.light_source)
        }
    }
    // Light Source Logic
    for ls in lights {
        influence_by_mode(ls)
    }
    // Fog Logic
    reset_shadow(fog)
    handle_light_source_influence(fog, camera.pos, lights[:])
    check_alpha_bound_fog(fog)

    //check_top_down_bound(&camera, vertical_bound)
}

destroy :: proc() {
    for scene in scenes {
        destroy_scene(scene)
    }
    delete(scenes)
    for effect in effects {
        destroy_effect(effect)
    }
    delete(effects)
    unload_effects()
    delete(lights)
    destroy_fog(fog)
}

main :: proc() {
    rl.SetConfigFlags({.MSAA_4X_HINT, .VSYNC_HINT})
    rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "Sceneries and Effects")
    rl.SetTargetFPS(120)
    init()
    defer destroy()

    for !rl.WindowShouldClose() {
        draw()
        input()
        logic()
    }
    rl.CloseWindow()
}
