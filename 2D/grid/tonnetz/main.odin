package tonnetz

import "base:runtime"
import "core:fmt"
import "core:math"
import "core:time"
import "core:sync"
import "core:slice"
import rl "vendor:raylib"

// Musical notes
Note :: enum { C, DB, D, EB, E, F, FS_GB, G, AB, A, BB, B }
MAX_NOTE :: Note.B

note_to_string :: proc(key: Note) -> (n: cstring) {
    switch key {
    case .C:  n = "C"
    case .DB: n = "Db"
    case .D:  n = "D"
    case .EB: n = "Eb"
    case .E:  n = "E"
    case .F:  n = "F"
    case .FS_GB: n = "F#"
    case .G:  n = "G"
    case .AB: n = "Ab"
    case .A:  n = "A"
    case .BB: n = "Bb"
    case .B:  n = "B"
    case: n = "?"
    }
    return
}

note_to_u8 :: proc(key: Note) -> u8 {
    return u8(key)
}

u8_to_note :: proc(val: u8) -> Note {
    return Note(val)
}

Step :: struct {
    val: u8,
}

step :: proc(val: u8) -> Step {
    return Step{val = val}
}

PRIME := step(0)
MINOR_SECOND := step(1)
MAJOR_SECOND := step(2)
MINOR_THIRD := step(3)
MAJOR_THIRD := step(4)
PERFECT_FOURTH := step(5)
AUGMENTED_FOURTH := step(6)
DIMINISHED_FIFTH := step(6)
PERFECT_FIFTH := step(7)
MINOR_SIXTH := step(8)
MAJOR_SIXTH := step(9)
MINOR_SEVENTH := step(10)
MAJOR_SEVENTH := step(11)
OCTAVE := step(12)

note_forward :: proc(key: Note, step: Step) -> Note {
    int_val := note_to_u8(key)
    return u8_to_note(u8(uint(int_val + step.val) % (uint(MAX_NOTE) + 1)))
}

note_backward :: proc(key: Note, step: Step) -> Note {
    int_val := int(note_to_u8(key))
    istep := int(step.val)
    result := (int_val - istep) % (int(MAX_NOTE) + 1)
    if result < 0 {
        result += int(MAX_NOTE) + 1
    }
    return u8_to_note(u8(result))
}

note_to_frequency :: proc(key: Note, octave: i32) -> f32 {
    a4: f32 = 440
    return a4 * math.pow(2, (f32(key) + 12 * f32(octave) - 9) / 12)
}

// Audio context
Wave :: enum {
    SINE,
    SQUARE,
    TRIANGLE,
    SAWTOOTH,
}

Sound :: struct {
    frequency: f32,
    volume: f32,
    fade_phase: f32,
    phase: f32,
    waveform: Wave,
    fade: enum {
        MAX,
        FADE_IN,
        FADE_OUT,
    },
}

AudioCtx :: struct {
    mutex: sync.Mutex,
    sounds: map[Note]Sound,
    fade_duration: f32,
}

SAMPLE_RATE :: 48000
BUFFER_SIZE :: SAMPLE_RATE / 60
CHANNELS :: 1
SAMPLE_SIZE :: 32
MAX_VOLUME :: 1.0

global_audio_ctx: ^AudioCtx

audio_callback :: proc "c" (buf_ptr: rawptr, frames: u32) {
    context = runtime.default_context()
    buf := cast([^]f32)buf_ptr
    buffer := buf[:frames]
    
    sync.mutex_lock(&global_audio_ctx.mutex)
    defer sync.mutex_unlock(&global_audio_ctx.mutex)
    
    n_sounds := f32(len(global_audio_ctx.sounds))
    if n_sounds == 0 do return
    
    // Clear buffer
    for i in 0..<frames {
        buffer[i] = 0
    }
    
    // Process each sound
    for key, &sound in global_audio_ctx.sounds {
        incr := (sound.frequency / SAMPLE_RATE) * math.TAU
        
        for &sample in buffer {
            wave_val: f32
            switch sound.waveform {
            case .SINE:
                wave_val = math.sin(sound.phase)
            case .SQUARE:
                wave_val = sound.phase < math.PI ? 1.0 : -1.0
            case .TRIANGLE:
                wave_val = sound.phase / math.TAU
            case .SAWTOOTH:
                wave_val = 2.0 * (sound.phase / math.TAU) - 1.0
            }
            
            val := sound.fade_phase * (sound.volume / n_sounds) * MAX_VOLUME * wave_val
            sample += val
            
            sound.phase += incr
            if sound.phase >= math.TAU {
                sound.phase -= math.TAU
            }
            
            switch sound.fade {
            case .FADE_IN:
                sound.fade_phase += 1000.0 / (SAMPLE_RATE * global_audio_ctx.fade_duration)
                if sound.fade_phase >= 1.0 {
                    sound.fade = .MAX
                    sound.fade_phase = 1.0
                }
            case .FADE_OUT:
                sound.fade_phase -= 1000.0 / (SAMPLE_RATE * global_audio_ctx.fade_duration)
                if sound.fade_phase <= 0.0 {
                    delete_key(&global_audio_ctx.sounds, key)
                }
            case .MAX:
                // Do nothing
            }
        }
    }
}

// Grid structures
POS_NUM :: 4
MAX_POS :: (1 << POS_NUM) - 1
NUM_POS :: MAX_POS + 1

Item :: struct {
    key: Note,
    octave: i8,
    pressed: bool,
    pos: struct { x, y: u8},
}

Style :: struct {
    gaps: struct { h, v: u32 },
    radius: f32,
    line_width: u32,
    color_map: map[Note]rl.Color,
}

Tonnetz :: struct {
    keys: [NUM_POS * NUM_POS]Item,
    style: Style,
}

item_coords :: proc(item: Item, style: ^Style) -> (u32, u32) {
    h_gap := style.gaps.h
    v_gap := style.gaps.v
    rad := u32(style.radius)
    
    x := u32(item.pos.x) * (h_gap + rad)
    y := u32(item.pos.y) * (v_gap + rad)

    if item.pos.x % 2 == 1 {
        y += (rad + v_gap) / 2
    }
    return x, y
}

init_grid :: proc(style: Style) -> Tonnetz {
    grid := Tonnetz{
        style = style,
    }
    key := Note.C
    for i in 0..<NUM_POS * NUM_POS {
        grid.keys[i] = Item{
            key = key,
            octave = 0,
            pressed = false,
            pos = {
                x = u8(i / NUM_POS),
                y = u8(i % NUM_POS),
            },
        }
        if i % NUM_POS != MAX_POS {
            key = note_backward(key, PERFECT_FIFTH)
        } else if grid.keys[i].pos.x % 2 == 0 {
            key = note_backward(key, DIMINISHED_FIFTH)
        } else {
            key = note_forward(key, MINOR_SECOND)
        }
    }
    return grid
}

idx_from_pos :: proc(x: u8, y: u8) -> int {
    return int(x) * NUM_POS + int(y)
}

clicked_item :: proc(grid: ^Tonnetz, mouse_pos: rl.Vector2) -> ^Item {
    for &item in grid.keys {
        x, y := item_coords(item, &grid.style)
        if rl.CheckCollisionPointCircle(mouse_pos, {f32(x), f32(y)}, grid.style.radius) {
            return &item
        }
    }
    return nil
}

draw_grid :: proc(grid: ^Tonnetz) {
    for item in grid.keys {
        draw_area(grid, item)
    }
    for item in grid.keys {
        draw_connections(grid, item)
    }
    for item in grid.keys {
        draw_circle(grid, item)
    }
}

draw_connections :: proc(grid: ^Tonnetz, circle: Item) {
    style := &grid.style
    offsets := [3]struct{x: u8, y: i8}{
        {0, 1},
        {1, 0},
        {1, circle.pos.x % 2 == 0 ? -1 : 1},
    }
    sx, sy := item_coords(circle, style)
    
    for offset in offsets {
        ox, oy := offset.x, offset.y
        pos := circle.pos
        
        if pos.x == MAX_POS && ox == 1 do continue
        if pos.y == MAX_POS && oy == 1 do continue
        if pos.y == 0 && oy == -1 do continue
        
        new_y := int(pos.y) + int(oy)
        if new_y < 0 || new_y > MAX_POS do continue
        
        neighbour := grid.keys[idx_from_pos(pos.x + ox, u8(new_y))]
        ex, ey := item_coords(neighbour, style)
        
        rl.DrawLine(i32(sx), i32(sy), i32(ex), i32(ey), rl.BLACK)
    }
}

draw_area :: proc(grid: ^Tonnetz, circle: Item) {
    if !circle.pressed do return
    
    style := &grid.style
    pos := circle.pos
    
    if pos.x == MAX_POS do return
    
    shared_offset_x:u8 = 1
    shared_offset_y:u8 = pos.x % 2 == 0 ? 0 : 1
    
    if pos.y == MAX_POS && shared_offset_y == 1 do return
    
    shared_circle := grid.keys[idx_from_pos(pos.x + shared_offset_x, pos.y + shared_offset_y)]
    if !shared_circle.pressed do return
    
    sx, sy := item_coords(circle, style)
    scx, scy := item_coords(shared_circle, style)
    
    offsets := [2]struct{x: u8, y: i8}{
        {0, 1},
        {1, pos.x % 2 == 0 ? -1 : 0},
    }
    
    for offset in offsets {
        ox, oy := offset.x, offset.y
        
        if pos.y == MAX_POS && oy == 1 do continue
        if pos.y == 0 && oy == -1 do continue
        
        new_y := int(pos.y) + int(oy)
        if new_y < 0 || new_y > MAX_POS do continue
        
        corner := grid.keys[idx_from_pos(pos.x + ox, u8(new_y))]
        if !corner.pressed do continue
        
        ex, ey := item_coords(corner, style)
        
        start_col := style.color_map[circle.key]
        shared_col := style.color_map[shared_circle.key]
        end_col := style.color_map[corner.key]
        avg_col := rl.Color{
            u8((u32(start_col.r) + u32(shared_col.r) + u32(end_col.r)) / 3),
            u8((u32(start_col.g) + u32(shared_col.g) + u32(end_col.g)) / 3),
            u8((u32(start_col.b) + u32(shared_col.b) + u32(end_col.b)) / 3),
            u8((u32(start_col.a) + u32(shared_col.a) + u32(end_col.a)) / 3)}
        v2, v3: rl.Vector2
        if offset.x == 0 {
            v2 = {f32(ex), f32(ey)}
            v3 = {f32(scx), f32(scy)}
        } else {
            v2 = {f32(scx), f32(scy)}
            v3 = {f32(ex), f32(ey)}
        }
        rl.DrawTriangle({f32(sx), f32(sy)}, v2, v3, avg_col)
    }
}

draw_circle :: proc(grid: ^Tonnetz, circle: Item) {
    style := &grid.style
    x, y := item_coords(circle, style)
    font_size := i32(style.radius / 2)
    color := circle.pressed ? style.color_map[circle.key] : rl.LIGHTGRAY
    
    rl.DrawCircle(i32(x), i32(y), style.radius, color)
    // Draw text
    str := fmt.ctprintf("%s %d", note_to_string(circle.key), circle.octave)
    rl.DrawText(str,
        i32(x) - rl.MeasureText(str, font_size) / 2,
        i32(y) - font_size / 2,
        font_size,
        rl.BLACK,
    )
}

KeyState :: enum {
    OFF,
    KB,
    TOGGLE,
}

KeyPair :: struct {
    kb: rl.KeyboardKey,
    note: Note,
    state: KeyState,
}

main :: proc() {
    rl.SetConfigFlags(rl.ConfigFlags{.WINDOW_RESIZABLE})
    rl.InitWindow(900, 900, "Tonnetz")
    defer rl.CloseWindow()
    rl.SetTargetFPS(60)
    
    rl.InitAudioDevice()
    defer rl.CloseAudioDevice()
    
    audio_ctx := AudioCtx{
        sounds = make(map[Note]Sound),
        fade_duration = 200.0,
    }
    defer delete(audio_ctx.sounds)
    
    current_wave := Wave.SINE
    global_audio_ctx = &audio_ctx
    
    audio_stream := rl.LoadAudioStream(SAMPLE_RATE, SAMPLE_SIZE, CHANNELS)
    defer rl.UnloadAudioStream(audio_stream)
    
    rl.SetAudioStreamCallback(audio_stream, audio_callback)
    rl.PlayAudioStream(audio_stream)
        
    last_click: time.Time
    last_clicked: Maybe(Note)
    double_click_delay := 500 * time.Millisecond
    
    colors := make(map[Note]rl.Color)
    defer delete(colors)
    
    colors[.C] = rl.RED
    colors[.DB] = rl.ORANGE
    colors[.D] = rl.YELLOW
    colors[.EB] = rl.GREEN
    colors[.E] = rl.BLUE
    colors[.F] = rl.PURPLE
    colors[.FS_GB] = rl.PINK
    colors[.G] = rl.BROWN
    colors[.AB] = rl.GRAY
    colors[.A] = rl.BLACK
    colors[.BB] = rl.WHITE
    colors[.B] = {255, 165, 0, 255}
    
    grid := init_grid(Style{
        gaps = {50, 50},
        radius = 20,
        line_width = 2,
        color_map = colors,
    })
    notes := [12]KeyPair{
        {.Z, .C, .OFF},
        {.S, .DB, .OFF},
        {.X, .D, .OFF},
        {.D, .EB, .OFF},
        {.C, .E, .OFF},
        {.V, .F, .OFF},
        {.G, .FS_GB, .OFF},
        {.B, .G, .OFF},
        {.H, .AB, .OFF},
        {.N, .A, .OFF},
        {.J, .BB, .OFF},
        {.M, .B, .OFF},
    }
    for !rl.WindowShouldClose() {
        // Handle wave switching
        if rl.IsKeyPressed(.W) {
            switch current_wave {
            case .SINE: current_wave = .SQUARE
            case .SQUARE: current_wave = .TRIANGLE
            case .TRIANGLE: current_wave = .SAWTOOTH
            case .SAWTOOTH: current_wave = .SINE
            }
        }
        // Handle keyboard input
        for &note_pair in notes {
            if note_pair.state == .TOGGLE do continue
            
            is_down := rl.IsKeyDown(note_pair.kb)
            has_changed := (note_pair.state == .KB) != is_down
            note_pair.state = is_down ? .KB : .OFF
            
            if has_changed {
                sync.mutex_lock(&audio_ctx.mutex)
                defer sync.mutex_unlock(&audio_ctx.mutex)
                
                if note_pair.note in audio_ctx.sounds {
                    sound := &audio_ctx.sounds[note_pair.note]
                    if is_down {
                        sound.fade = .FADE_IN
                    } else {
                        sound.fade = .FADE_OUT
                    }
                } else if is_down {
                    audio_ctx.sounds[note_pair.note] = Sound{
                        volume = 0.1,
                        waveform = current_wave,
                        frequency = note_to_frequency(note_pair.note, 0),
                        fade_phase = 0.0,
                        phase = 0.0,
                        fade = .FADE_IN,
                    }
                }
            }
        }
        // Handle mouse clicks
        if rl.IsMouseButtonPressed(.LEFT) {
            now := time.now()
            click_delay := time.diff(last_click, now)
            last_click = now
            
            mouse_pos := rl.GetMousePosition()
            if item := clicked_item(&grid, mouse_pos); item != nil {
                if click_delay < double_click_delay {
                    if last_clicked_key, ok := last_clicked.?; ok && last_clicked_key == item.key {
                        sync.mutex_lock(&audio_ctx.mutex)
                        defer sync.mutex_unlock(&audio_ctx.mutex)
                        
                        pressed := item.pressed
                        item.pressed = !pressed
                        
                        if item.key in audio_ctx.sounds {
                            sound := &audio_ctx.sounds[item.key]
                            if pressed {
                                sound.fade = .FADE_OUT
                            } else {
                                sound.fade = .FADE_IN
                                sound.frequency = note_to_frequency(item.key, i32(item.octave))
                                sound.waveform = current_wave
                            }
                        } else if !pressed {
                            audio_ctx.sounds[item.key] = Sound{
                                frequency = note_to_frequency(item.key, i32(item.octave)),
                                volume = 0.1,
                                waveform = current_wave,
                                fade_phase = 0.0,
                                phase = 0.0,
                                fade = .FADE_IN,
                            }
                        }
                        if pressed {
                            notes[int(item.key)].state = .OFF
                        } else {
                            notes[int(item.key)].state = .TOGGLE
                        }
                        last_clicked = nil
                    }
                } else {
                    last_clicked = item.key
                }
            } else {
                last_clicked = nil
            }
        }
        // Handle right click for octave change
        if rl.IsMouseButtonPressed(.RIGHT) {
            mouse_pos := rl.GetMousePosition()
            if item := clicked_item(&grid, mouse_pos); item != nil {
                sync.mutex_lock(&audio_ctx.mutex)
                defer sync.mutex_unlock(&audio_ctx.mutex)
                
                if item.octave < 3 {
                    item.octave += 1
                } else {
                    item.octave = -2
                }
                if item.key in audio_ctx.sounds {
                    sound := &audio_ctx.sounds[item.key]
                    sound.frequency = note_to_frequency(item.key, i32(item.octave))
                    sound.waveform = current_wave
                } else {
                    audio_ctx.sounds[item.key] = Sound{
                        frequency = note_to_frequency(item.key, i32(item.octave)),
                        volume = 0.1,
                        waveform = current_wave,
                        fade_phase = 0.0,
                        phase = 0.0,
                        fade = .FADE_IN,
                    }
                }
            }
        }
        // Update grid key states
        for &item in grid.keys {
            item.pressed = notes[int(item.key)].state != .OFF
        }
        rl.BeginDrawing()
        rl.ClearBackground(rl.WHITE)
        
        draw_grid(&grid)
        
        w: cstring
        switch current_wave {
        case .SINE: w = "sine"
        case .SQUARE: w = "square"
        case .TRIANGLE: w = "triangle"
        case .SAWTOOTH: w = "sawtooth"
        }
        rl.DrawText(fmt.ctprintf("Current wave: %s", w), 4, 4, 16, rl.BLACK)
        rl.DrawText("Double-click to toggle notes, Right-click to change octave", 4, 24, 16, rl.BLACK)
        rl.DrawText("Press W to change waveform", 4, 44, 16, rl.BLACK)
        rl.DrawText("Use keyboard keys Z,S,X,D,C,V,G,B,H,N,J,M for piano", 4, 64, 16, rl.BLACK)
        
        // Debug info
        rl.DrawText(fmt.ctprintf("Active sounds: %d", len(audio_ctx.sounds)), 4, 84, 16, rl.BLACK)
        
        rl.EndDrawing()
    }
}