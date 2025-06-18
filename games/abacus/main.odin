package main

import "core:fmt"
import "core:math"
import "core:math/rand"
import "core:slice"
import "core:time"
import rl "vendor:raylib"
import "slider"

// Constants
TITLE         :: "🧮 Abacus Adventure 🧮"
SCREEN_WIDTH  :: 1200
SCREEN_HEIGHT :: 900

// Responsive constants
MIN_SCREEN_MARGIN :: 20
HEADER_HEIGHT     :: 80
FOOTER_HEIGHT     :: 100
SIDE_MARGIN       :: 40

// Abacus geometry
ROD_WIDTH         :: 7       // Rod thickness
BEAD_ASPECT_RATIO :: 2       // Width/Height ratio for beads
BEAD_VMARGIN      :: 6       // Vertical margin between beads
BEAD_ANIM_LERP    :: 0.15    // Interpolation for smooth animation
BAR_HEIGHT        :: 12      // Height of the horizontal bar

// Animation constants
BEAD_MOVE_SPEED  :: 7.0      // Speed of bead movement animation
BOUNCE_AMPLITUDE :: 5.0      // Bounce effect amplitude
NUM_PARTICLES    :: 30

// Rod count
ALLOWED_ROD_COUNTS      :: []int{5, 7, 9, 11, 13, 15, 17, 19, 21}
DEFAULT_ROD_COUNT_INDEX :: 3 // Index for ALLOWED_ROD_COUNTS, default 11 rods

// Color palette
BACKGROUND_GRADIENT_TOP    :: rl.Color{135, 206, 250, 255}  // Sky Blue
BACKGROUND_GRADIENT_BOTTOM :: rl.Color{255, 228, 181, 255}  // Moccasin
FRAME_COLOR                :: rl.Color{101, 67, 33, 255}    // Dark Brown
FRAME_SHADOW               :: rl.Color{0, 0, 0, 60}         // Semi-transparent black
ROD_COLOR                  :: rl.Color{139, 69, 19, 255}    // Saddle Brown
BAR_COLOR                  :: rl.Color{160, 82, 45, 255}    // Saddle Brown
TEXT_COLOR                 :: rl.Color{255, 255, 255, 255}  // White
VALUE_TEXT_COLOR           :: rl.Color{255, 69, 0, 255}     // Red-Orange
CHALLENGE_TEXT_COLOR       :: rl.Color{255, 255, 150, 255}  // Yellow for challenges
CHALLENGE_COMPLETE_COLOR   :: rl.Color{60, 255, 60, 255}    // Bright Green for completion
RESET_BTN_COLOR            :: rl.Color{100, 149, 237, 200}  // Cornflower Blue
RESET_BTN_HOVER_COLOR      :: rl.Color{65, 105, 225, 255}   // Royal Blue

rng := rand.default_random_generator()

// Bead color set
ColorSet :: struct {
    inactive:  rl.Color,
    active:    rl.Color,
    highlight: rl.Color, // For hover/click effect
}

COLOR_WHEEL :: []ColorSet{
    // Gray
    {rl.Color{220, 220, 220, 255}, rl.Color{128, 128, 128, 255}, rl.Color{105, 105, 105, 255}},
    // Olive
    {rl.Color{238, 232, 170, 255}, rl.Color{107, 142, 35, 255}, rl.Color{85, 107, 47, 255}},
    // Tan/Brown
    {rl.Color{245, 222, 179, 255}, rl.Color{210, 180, 140, 255}, rl.Color{160, 82, 45, 255}},
    // Rose Pink
    {rl.Color{255, 228, 225, 255}, rl.Color{219, 112, 147, 255}, rl.Color{199, 21, 133, 255}},
    // Hot Pink
    {rl.Color{255, 182, 193, 255}, rl.Color{255, 20, 147, 255}, rl.Color{255, 105, 180, 255}},
    // Magenta
    {rl.Color{255, 240, 245, 255}, rl.Color{199, 21, 133, 255}, rl.Color{139, 0, 139, 255}},
    // Purple
    {rl.Color{216, 191, 216, 255}, rl.Color{138, 43, 226, 255}, rl.Color{148, 0, 211, 255}},
    // Indigo
    {rl.Color{147, 112, 219, 255}, rl.Color{75, 0, 130, 255}, rl.Color{72, 61, 139, 255}},
    // True Blue
    {rl.Color{173, 216, 230, 255}, rl.Color{0, 0, 255, 255}, rl.Color{65, 105, 225, 255}},
    // Sky Blue
    {rl.Color{135, 206, 250, 255}, rl.Color{30, 144, 255, 255}, rl.Color{70, 130, 180, 255}},
    // Cyan
    {rl.Color{224, 255, 255, 255}, rl.Color{0, 255, 255, 255}, rl.Color{0, 139, 139, 255}},
    // Teal
    {rl.Color{175, 238, 238, 255}, rl.Color{0, 206, 209, 255}, rl.Color{64, 224, 208, 255}},
    // Forest Green
    {rl.Color{144, 238, 144, 255}, rl.Color{34, 139, 34, 255}, rl.Color{60, 179, 113, 255}},
    // Leaf Green
    {rl.Color{144, 238, 144, 255}, rl.Color{50, 205, 50, 255}, rl.Color{0, 128, 0, 255}},
    // Chartreuse
    {rl.Color{152, 251, 152, 255}, rl.Color{127, 255, 0, 255}, rl.Color{124, 252, 0, 255}},
    // Lime-Yellow
    {rl.Color{255, 250, 205, 255}, rl.Color{255, 255, 0, 255}, rl.Color{173, 255, 47, 255}},
    // Yellow
    {rl.Color{255, 255, 224, 255}, rl.Color{255, 215, 0, 255}, rl.Color{255, 223, 0, 255}},
    // Yellow-Orange
    {rl.Color{255, 239, 213, 255}, rl.Color{255, 165, 79, 255}, rl.Color{210, 105, 30, 255}},
    // Orange
    {rl.Color{255, 218, 185, 255}, rl.Color{255, 140, 0, 255}, rl.Color{255, 165, 0, 255}},
    // Red-Orange (Coral)
    {rl.Color{255, 160, 122, 255}, rl.Color{255, 99, 71, 255}, rl.Color{255, 127, 80, 255}},
    // Red
    {rl.Color{240, 128, 128, 255}, rl.Color{220, 20, 60, 255}, rl.Color{178, 34, 34, 255}},
}

Particle :: struct {
    pos:      rl.Vector2,
    velocity: rl.Vector2,
    life:     f32,
    max_life: f32,
    color:    rl.Color,
    size:     f32,
}

Bead :: struct {
    rect:                  rl.Rectangle,
    target_pos:            rl.Vector2,
    current_pos:           rl.Vector2,
    is_active:             bool,
    value:                 int,
    bounce_offset:         f32,
    hover_scale:           f32,
    is_solution_highlight: bool,
}

Rod :: struct {
    heaven_bead:        Bead,
    earth_beads:        [4]Bead,
    value:              int,
    color_index:        int,
    celebration_timer:  int,
}

Layout :: struct {
    available_width:  i32,
    available_height: i32,
    rod_spacing:      i32,
    bead_width:       i32,
    bead_height:      i32,
    frame_padding:    i32,
}

Challenge_Type :: enum {
    NUMBER,
    ADDITION,
}

Challenge :: struct {
    type:             Challenge_Type,
    number:           i64,
    operand1:         i64,
    operand2:         i64,
    text:             cstring,
    is_complete:      bool,
    completion_timer: int,
    anim_scale:       f32,
}

Game_State :: enum {
    PLAYING,
    GIVE_UP_ANIMATION,
    CHALLENGE_COMPLETE,
}

Addition_Animation_Phase :: enum {
    NONE,
    SET_OPERAND1,
    ADD_OPERAND2,
}

Move :: struct {
    rod_idx:    int,
    val:        int,
}

FontSizes :: struct {
    title:           f32,
    subtitle:        f32,
    rod_value:       f32,
    total_label:     f32,
    challenge_label: f32,
    challenge_text:  f32,
    button:          f32,
    info:            f32,
}

Abacus :: struct {
    rods:              [dynamic]Rod,
    particles:         [dynamic]Particle,
    wood_texture:      rl.Texture2D,
    rod_count:         int,
    cfg_idx:           int,
    layout:            Layout,
    frame_width:       i32,
    frame_height:      i32,
    frame_x:           i32,
    frame_y:           i32,
    bar_y_pos:         i32,
    background_wave:   f32,
    font :             rl.Font,
    font_size:         i32,
    font_sizes:        FontSizes,
    current_challenge: Challenge,
    game_state:        Game_State,
    solution_moves:    [dynamic]Move,
    anim_timer:        f32,
    addition_phase:    Addition_Animation_Phase,
    text_animator:     slider.Animator,
    intro_finished:    bool,
}

generate_rod_color_indexes :: proc(rod_count: int) -> []int {
    total_colors :: 21
    step := 1
    for s in 2..<total_colors {
        if (s * rod_count >= total_colors) && (math.gcd(s, total_colors) == 1) {
            step = s
            break
        }
    }
    palette_selection := make([]int, rod_count)
    for i in 0..<rod_count {
        palette_selection[i] = (i * step) % total_colors
    }
    slice.sort(palette_selection)
    return palette_selection
}

calc_font_sizes :: proc(screen_width: i32, screen_height: i32) -> FontSizes {
    sizes: FontSizes
    width_scale          := f32(screen_width) / f32(SCREEN_WIDTH)
    height_scale         := f32(screen_height) / f32(SCREEN_HEIGHT)
    scale_factor         := min(width_scale, height_scale)
    sizes.title           = max(74 * scale_factor, 32)
    sizes.subtitle        = max(32 * scale_factor, 16)
    sizes.rod_value       = max(32 * scale_factor, 14)
    sizes.total_label     = max(36 * scale_factor, 18)
    sizes.challenge_label = max(24 * scale_factor, 12)
    sizes.challenge_text  = max(28 * scale_factor, 14)
    sizes.button          = max(20 * scale_factor, 12)
    sizes.info            = max(28 * scale_factor, 14)
    return sizes
}

calc_layout :: proc(rod_count: int, screen_width: i32, screen_height: i32) -> Layout {
    layout: Layout
    layout.available_width  = screen_width - 2 * SIDE_MARGIN
    layout.available_height = screen_height - HEADER_HEIGHT - FOOTER_HEIGHT - 2 * MIN_SCREEN_MARGIN
    layout.rod_spacing      = layout.available_width / (i32(rod_count) + 1)
    layout.rod_spacing      = max(layout.rod_spacing, 45)
    layout.rod_spacing      = min(layout.rod_spacing, 80)
    layout.bead_width       = max(i32(f32(layout.rod_spacing) * 0.7), 35)
    layout.bead_height      = i32(f32(layout.bead_width) / BEAD_ASPECT_RATIO)
    layout.frame_padding    = max(layout.rod_spacing / 2, 30)
    return layout
}

update_abacus_geometry :: proc(a: ^Abacus) {
    screen_width       := rl.GetScreenWidth()
    screen_height      := rl.GetScreenHeight()
    a.layout        = calc_layout(a.rod_count, screen_width, screen_height)
    a.frame_width   = i32(a.layout.rod_spacing * (i32(a.rod_count) - 1) + 2 * a.layout.frame_padding)
    a.frame_height  = i32(5 * (a.layout.bead_height + BEAD_VMARGIN) + BAR_HEIGHT + 2 * a.layout.frame_padding + 60)
    a.frame_x       = (screen_width - a.frame_width) / 2
    a.frame_y       = HEADER_HEIGHT + (screen_height - HEADER_HEIGHT - FOOTER_HEIGHT - a.frame_height) / 2
    a.bar_y_pos     = a.frame_y + a.layout.frame_padding + a.layout.bead_height + BEAD_VMARGIN + 30

    for i in 0..<a.rod_count {
        rod     := &a.rods[i]
        rod_x   := f32(a.frame_x + a.layout.frame_padding + i32(i) * a.layout.rod_spacing - a.layout.bead_width / 2)
        bead_w  := f32(a.layout.bead_width)
        bead_h  := f32(a.layout.bead_height)
        rod.heaven_bead.target_pos.x = rod_x
        rod.heaven_bead.rect.width   = bead_w
        rod.heaven_bead.rect.height  = bead_h
        if rod.heaven_bead.is_active {
            rod.heaven_bead.target_pos.y = f32(a.bar_y_pos - a.layout.bead_height)
        } else {
            rod.heaven_bead.target_pos.y = f32(a.bar_y_pos - a.layout.bead_height - BEAD_VMARGIN * 2 - 20)
        }
        earth_value := rod.value % 5
        bead_step   := f32(a.layout.bead_height + BEAD_VMARGIN)
        for k in 0..<earth_value {
            rod.earth_beads[k].target_pos.x = rod_x
            rod.earth_beads[k].rect.width   = bead_w
            rod.earth_beads[k].rect.height  = bead_h
            rod.earth_beads[k].target_pos.y = f32(a.bar_y_pos + BAR_HEIGHT) + f32(k) * bead_step
        }
        bottom_y        := f32(a.frame_y + a.frame_height - a.layout.frame_padding)
        inactive_count  := 4 - earth_value
        for k in 0..<inactive_count {
            bead_index := earth_value + k
            rod.earth_beads[bead_index].target_pos.x = rod_x
            rod.earth_beads[bead_index].rect.width   = bead_w
            rod.earth_beads[bead_index].rect.height  = bead_h
            rod.earth_beads[bead_index].target_pos.y = bottom_y - f32(inactive_count - k) * bead_step
        }
        rod.heaven_bead.current_pos = rod.heaven_bead.target_pos
        for j in 0..<4 {
            rod.earth_beads[j].current_pos = rod.earth_beads[j].target_pos
        }
    }
}

init_abacus :: proc(cfg_idx: int) -> (a: Abacus) {
    a.cfg_idx        = cfg_idx
    allowed_rod_counts  := ALLOWED_ROD_COUNTS
    a.rod_count      = allowed_rod_counts[cfg_idx]
    a.rods           = make([dynamic]Rod, a.rod_count)
    a.particles      = make([dynamic]Particle, 0, 200) // Increased capacity
    a.solution_moves = make([dynamic]Move, 0, a.rod_count)
    color_indexes       := generate_rod_color_indexes(a.rod_count)

    for i in 0..<a.rod_count {
        a.rods[i].value = 0
        a.rods[i].color_index = color_indexes[i] 
        a.rods[i].heaven_bead = Bead{ value = 5, hover_scale = 1.0 }
        for j in 0..<4 {
            a.rods[i].earth_beads[j] = Bead{ value = 1, hover_scale = 1.0 }
        }
    }
    sw := rl.GetScreenWidth()
    sh := rl.GetScreenHeight()
    a.font_sizes = calc_font_sizes(sw, sh)
    update_abacus_geometry(&a)
    a.current_challenge = generate_challenge(a.rod_count)
    a.current_challenge.anim_scale = 1.0 
    a.game_state     = .PLAYING
    a.addition_phase = .NONE
    return
}

update_animator_layout :: proc(animator: ^slider.Animator) {
    sw := f32(rl.GetScreenWidth())
    title_anim := slider.get_animation(animator, 0)
    if title_anim != nil { title_anim.config.target_x = sw / 2 }
    subtitle_anim := slider.get_animation(animator, 1)
    if subtitle_anim != nil { subtitle_anim.config.target_x = sw / 2 }
}

reset_abacus_state :: proc(a: ^Abacus) {
    for i in 0..<a.rod_count {
        rod := &a.rods[i]
        if rod.value != 0 {
            rod.value = 0
            rod.celebration_timer = 20
        }
    }
}

reset_and_snap_abacus :: proc(a: ^Abacus) {
    for i in 0..<a.rod_count { a.rods[i].value = 0 }
    update_abacus_geometry(a)
}

generate_challenge :: proc(rod_count: int) -> Challenge {
    c: Challenge
    max_value := i64(math.pow(10, f64(rod_count))) - 1
    c.type = Challenge_Type(rand.int_max(2, rng))
    switch c.type {
    case .NUMBER:
        c.number = i64(rand.int63_max(min(max_value, 1000), rng)) 
        c.text = fmt.ctprintf("Set the abacus to: %v", c.number)
    case .ADDITION:
        c.operand1 = i64(rand.int63_max(min(max_value / 2, 500), rng))
        c.operand2 = i64(rand.int63_max(min(max_value / 2, 500), rng))
        c.number = c.operand1 + c.operand2
        c.text = fmt.ctprintf("Calculate: %v + %v", c.operand1, c.operand2)
    }
    c.is_complete = false
    c.completion_timer = 0
    c.anim_scale = 0.0
    return c
}

calc_number_moves :: proc(a: ^Abacus, number: i64) {
    clear(&a.solution_moves)
    temp_target := number
    for i := a.rod_count - 1; i >= 0; i -= 1 {
        power_of_ten := i64(math.pow(10, f64(i)))
        target_digit := int(temp_target / power_of_ten)
        temp_target  %= power_of_ten
        rod_idx := a.rod_count - 1 - i
        if a.rods[rod_idx].value != target_digit {
            append(&a.solution_moves, Move{rod_idx = rod_idx, val = target_digit})
        }
    }
}

calc_addition_moves :: proc(a: ^Abacus) {
    clear(&a.solution_moves)
    operand_to_add := a.current_challenge.operand2
    temp_operand   := operand_to_add
    carry: i64

    for i := 0; i < a.rod_count; i += 1 {
        rod_idx := a.rod_count - 1 - i
        digit_to_add := temp_operand % 10
        temp_operand /= 10
        current_rod_value := i64(a.rods[rod_idx].value)
        total_new_value := current_rod_value + digit_to_add + carry
        final_rod_digit := int(total_new_value % 10)
        carry = total_new_value / 10
        if a.rods[rod_idx].value != final_rod_digit {
            append(&a.solution_moves, Move{rod_idx = rod_idx, val = final_rod_digit})
        }
        if temp_operand == 0 && carry == 0 { break }
    }
    slice.reverse(a.solution_moves[:])
}

// Create dispersion effect.
create_particles :: proc(a: ^Abacus, source_rect: rl.Rectangle, base_color: rl.Color) {
    for _ in 0..<NUM_PARTICLES {
        // Random position within the bead's bounds
        position := rl.Vector2 {
            source_rect.x + f32(rand.int_max(int(source_rect.width), rng)),
            source_rect.y + f32(rand.int_max(int(source_rect.height), rng)),
        }
        // Random velocity with upward bias and some spread
        tmp := 2 * math.PI
        angle       := f32(rand.int_max(int(tmp), rng))
        speed       := rand.float32_range(50, 150, rng)
        upward_bias := rand.float32_range(20, 80, rng) // Give it a little "pop" upwards
        velocity := rl.Vector2 {
            math.cos(angle) * speed,
            math.sin(angle) * speed - upward_bias,
        }
        // Random life between 0.8 and 1.5 seconds
        max_life := rand.float32_range(0.8, 1.5, rng)
        // Color variation based on the bead's highlight color
        color_variation := u8(rand.int_max(40, rng))
        r := base_color.r > color_variation ? base_color.r - color_variation : 0
        g := base_color.g > color_variation ? base_color.g - color_variation : 0
        b := base_color.b > color_variation ? base_color.b - color_variation : 0
        p := Particle {
            pos      = position,
            velocity = velocity,
            life     = max_life,
            max_life = max_life,
            color    = rl.Color{r, g, b, 255}, // Start fully opaque
            size     = rand.float32_range(1, 4, rng),
        }
        append(&a.particles, p)
    }
}

// Particles mimic air resistance for natural movement.
update_particles :: proc(a: ^Abacus, dt: f32) {
    AIR_RESISTANCE :: 0.6 
    GRAVITY        :: 350.0

    for i := len(a.particles) - 1; i >= 0; i -= 1 {
        particle            := &a.particles[i]
        particle.pos        += particle.velocity * dt
        particle.velocity.y += GRAVITY * dt
        particle.velocity.x *= (1.0 - AIR_RESISTANCE * dt) // Apply drag
        particle.velocity.y *= (1.0 - AIR_RESISTANCE * dt)
        particle.life       -= dt
        if particle.life <= 0 {
            ordered_remove(&a.particles, i)
        }
    }
}

// Nerd font
load_font :: proc(a: ^Abacus, size: i32) {
    CHARS :: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789… ~!@#$%^&*()-|\"':;_+={}[]\\/`,.<>?★✓← →"
    code_point_count: i32
    code_points := rl.LoadCodepoints(CHARS, &code_point_count)
    defer rl.UnloadCodepoints(code_points)
    path :: "assets/nerd.ttf"
    if rl.FileExists(path) {
        a.font = rl.LoadFontEx(path, size, code_points, code_point_count)
        fmt.printf("Loaded nerd font: %s\n", path)
    }
    a.font_size = size
    rl.SetTextureFilter(a.font.texture, .BILINEAR)
}

unload_font :: proc(a: ^Abacus) {
    rl.UnloadFont(a.font)
}

calc_total :: proc(a: ^Abacus) -> i64 {
    total: i64 = 0
    power_of_ten: i64 = 1
    for i := a.rod_count - 1; i >= 0; i -= 1 {
        total += i64(a.rods[i].value) * power_of_ten
        power_of_ten *= 10
    }
    return total
}

update_beads :: proc(a: ^Abacus) {
    for i in 0..<a.rod_count {
        rod := &a.rods[i]
        rod.heaven_bead.is_active = (rod.value >= 5)
        if rod.heaven_bead.is_active {
            rod.heaven_bead.target_pos.y = f32(a.bar_y_pos - a.layout.bead_height)
        } else {
            rod.heaven_bead.target_pos.y = f32(a.bar_y_pos - a.layout.bead_height - BEAD_VMARGIN * 2 - 20)
        }
        earth_value := rod.value % 5
        for k in 0..<4 { rod.earth_beads[k].is_active = (k < earth_value) }
        bead_step := f32(a.layout.bead_height + BEAD_VMARGIN)
        for k in 0..<earth_value {
            rod.earth_beads[k].target_pos.y = f32(a.bar_y_pos + BAR_HEIGHT) + f32(k) * bead_step
        }
        bottom_y := f32(a.frame_y + a.frame_height - a.layout.frame_padding)
        inactive_count := 4 - earth_value
        for k in 0..<inactive_count {
            bead_index := earth_value + k
            rod.earth_beads[bead_index].target_pos.y = bottom_y - f32(inactive_count - k) * bead_step
        }
    }
}

handle_input :: proc(a: ^Abacus, earth_snd, heaven_snd: rl.Sound) {
    mouse_pos := rl.GetMousePosition()
    rod_count_changed := false
    new_config_index := a.cfg_idx
    if rl.IsKeyPressed(.RIGHT) {
        new_config_index = (a.cfg_idx + 1) % len(ALLOWED_ROD_COUNTS)
        rod_count_changed = true
    }
    if rl.IsKeyPressed(.LEFT) {
        new_config_index = (a.cfg_idx - 1 + len(ALLOWED_ROD_COUNTS)) % len(ALLOWED_ROD_COUNTS)
        rod_count_changed = true
    }
    if rod_count_changed {
        tmp_font := a.font
        tmp_texture := a.wood_texture
        tmp_animator := a.text_animator 
        tmp_animator_finished := a.intro_finished
        delete(a.rods)
        delete(a.particles)
        delete(a.solution_moves)
        a^ = init_abacus(new_config_index)
        a.font = tmp_font
        a.wood_texture = tmp_texture
        a.text_animator = tmp_animator
        a.intro_finished = tmp_animator_finished
        return
    }
    if a.game_state != .PLAYING { return }
    if rl.IsMouseButtonPressed(.LEFT) {
        for i in 0..<a.rod_count {
            rod := &a.rods[i]
            if rl.CheckCollisionPointRec(mouse_pos, rod.heaven_bead.rect) {
                if rl.IsSoundReady(heaven_snd) { rl.PlaySound(heaven_snd) }
                if rod.value >= 5 { rod.value -= 5 } else { rod.value += 5 }
                rod.heaven_bead.bounce_offset = BOUNCE_AMPLITUDE
                rod.celebration_timer = 30
                // Call the new particle procedure
                color_wheel := COLOR_WHEEL
                color_set := color_wheel[rod.color_index]
                create_particles(a, rod.heaven_bead.rect, color_set.highlight)
                return 
            }
            for j in 0..<4 {
                if rl.CheckCollisionPointRec(mouse_pos, rod.earth_beads[j].rect) {
                    if rl.IsSoundReady(earth_snd) { rl.PlaySound(earth_snd) }
                    current_heaven_value := (rod.value / 5) * 5
                    if (rod.value % 5) == (j + 1) { rod.value = current_heaven_value } else { rod.value = current_heaven_value + (j + 1) }
                    rod.earth_beads[j].bounce_offset = BOUNCE_AMPLITUDE
                    rod.celebration_timer = 30
                    color_wheel := COLOR_WHEEL
                    color_set := color_wheel[rod.color_index]
                    create_particles(a, rod.earth_beads[j].rect, color_set.highlight)
                    create_particles(a, rod.earth_beads[j].rect, color_set.highlight)
                    return 
                }
            }
        }
    }
    footer_y := rl.GetScreenHeight() - FOOTER_HEIGHT - 40
    give_up_text :: "I give up!"
    button_font_size: f32 = a.font_sizes.button 
    give_up_text_size := rl.MeasureTextEx(a.font, give_up_text, button_font_size, 1.0)
    button_padding: f32 = 10
    give_up_button_rect := rl.Rectangle{ f32(rl.GetScreenWidth()) - give_up_text_size.x - button_padding * 2 - 40, f32(footer_y), give_up_text_size.x + button_padding * 2, give_up_text_size.y + button_padding * 2, }
    reset_text :: "Reset"
    reset_text_size := rl.MeasureTextEx(a.font, reset_text, button_font_size, 1.0)
    reset_button_rect := rl.Rectangle{ give_up_button_rect.x - reset_text_size.x - button_padding * 2 - 15, f32(footer_y), reset_text_size.x + button_padding * 2, reset_text_size.y + button_padding * 2, }
    if rl.CheckCollisionPointRec(mouse_pos, reset_button_rect) && rl.IsMouseButtonPressed(.LEFT) {
        reset_abacus_state(a)
        if rl.IsSoundReady(earth_snd) { rl.PlaySound(earth_snd) }
    }
    if rl.CheckCollisionPointRec(mouse_pos, give_up_button_rect) && rl.IsMouseButtonPressed(.LEFT) {
        reset_and_snap_abacus(a)
        a.game_state = .GIVE_UP_ANIMATION
        a.anim_timer = 0
        switch a.current_challenge.type {
        case .NUMBER:
            a.addition_phase = .NONE
            calc_number_moves(a, a.current_challenge.number)
        case .ADDITION:
            a.addition_phase = .SET_OPERAND1
            calc_number_moves(a, a.current_challenge.operand1)
        }
    }
}

update_state :: proc(a: ^Abacus, dt: f32, earth_snd, complete_snd: rl.Sound) {
    a.background_wave += dt * 2.0
    update_particles(a, dt)

    if a.current_challenge.anim_scale < 1.0 {
        a.current_challenge.anim_scale += dt * 5.0
        if a.current_challenge.anim_scale > 1.0 {
            a.current_challenge.anim_scale = 1.0
        }
    }
    switch a.game_state {
    case .PLAYING:
        total := calc_total(a)
        if !a.current_challenge.is_complete && total == a.current_challenge.number {
            a.game_state = .CHALLENGE_COMPLETE
            a.current_challenge.is_complete = true
            a.current_challenge.completion_timer = 120
            if rl.IsSoundReady(complete_snd) { rl.PlaySound(complete_snd) }
        }
    case .GIVE_UP_ANIMATION:
        for &rod in &a.rods {
            rod.heaven_bead.is_solution_highlight = false
            for i in 0..<4 { rod.earth_beads[i].is_solution_highlight = false }
        }
        if len(a.solution_moves) > 0 {
            move := a.solution_moves[0]
            rod := &a.rods[move.rod_idx]
            target_heaven_active := move.val >= 5
            if rod.heaven_bead.is_active != target_heaven_active { rod.heaven_bead.is_solution_highlight = true }
            target_earth_value := move.val % 5
            current_earth_value := rod.value % 5
            for k in 0..<4 {
                if (k < current_earth_value) != (k < target_earth_value) { rod.earth_beads[k].is_solution_highlight = true }
            }
        }
        a.anim_timer += dt * 0.8
        if a.anim_timer > 1.0 {
            if len(a.solution_moves) > 0 {
                move := a.solution_moves[0]
                a.rods[move.rod_idx].value = move.val
                a.rods[move.rod_idx].celebration_timer = 30
                if rl.IsSoundReady(earth_snd) { rl.PlaySound(earth_snd) }
                ordered_remove(&a.solution_moves, 0)
                a.anim_timer = 0
            } else { 
                if a.current_challenge.type == .ADDITION && a.addition_phase == .SET_OPERAND1 {
                    a.addition_phase = .ADD_OPERAND2
                    a.anim_timer = -0.5
                    calc_addition_moves(a)
                } else {
                    for &rod in &a.rods {
                        rod.heaven_bead.is_solution_highlight = false
                        for i in 0..<4 { rod.earth_beads[i].is_solution_highlight = false }
                    }
                    a.game_state = .CHALLENGE_COMPLETE
                    a.addition_phase = .NONE
                    a.current_challenge.is_complete = true
                    a.current_challenge.completion_timer = 180
                }
            }
        }
    case .CHALLENGE_COMPLETE:
        a.current_challenge.completion_timer -= 1
        if a.current_challenge.completion_timer <= 0 {
            a.current_challenge = generate_challenge(a.rod_count)
            a.game_state = .PLAYING
        }
    }
    for i in 0..<a.rod_count {
        rod := &a.rods[i]
        if rod.celebration_timer > 0 { rod.celebration_timer -= 1 }
        rod.heaven_bead.current_pos.x += (rod.heaven_bead.target_pos.x - rod.heaven_bead.current_pos.x) * BEAD_ANIM_LERP
        rod.heaven_bead.current_pos.y += (rod.heaven_bead.target_pos.y - rod.heaven_bead.current_pos.y) * BEAD_ANIM_LERP
        for j in 0..<4 {
            rod.earth_beads[j].current_pos.x += (rod.earth_beads[j].target_pos.x - rod.earth_beads[j].current_pos.x) * BEAD_ANIM_LERP
            rod.earth_beads[j].current_pos.y += (rod.earth_beads[j].target_pos.y - rod.earth_beads[j].current_pos.y) * BEAD_ANIM_LERP
        }
    }
    update_beads(a)
}

draw_background :: proc(wave_offset: f32) {
    screen_height := rl.GetScreenHeight()
    screen_width := rl.GetScreenWidth()
    for i in 0..<screen_height {
        wave := math.sin(f32(i) * 0.01 + wave_offset) * 10.0
        color := rl.Color{ u8(135 + wave), u8(206 + wave * 0.3), u8(250 - f32(i) * 0.3), 255 }
        rl.DrawRectangle(0, i32(i), screen_width, 1, color)
    }
}

draw_frame :: proc(a: ^Abacus) {
    frame_rect := rl.Rectangle{f32(a.frame_x), f32(a.frame_y), f32(a.frame_width), f32(a.frame_height)}
    shadow_rect := rl.Rectangle{f32(a.frame_x + 5), f32(a.frame_y + 5), f32(a.frame_width), f32(a.frame_height)}
    rl.DrawRectangleRounded(shadow_rect, 0.02, 10, FRAME_SHADOW)
    if a.wood_texture.id > 0 {
        tex := a.wood_texture
        dest := frame_rect
        BASE_ROD_COUNT :: 5.0
        horizontal_scale_factor := f32(a.rod_count) / BASE_ROD_COUNT
        source_rect := rl.Rectangle{0, 0, f32(tex.width) * horizontal_scale_factor, (f32(tex.width) * horizontal_scale_factor) / (dest.width / dest.height)}
        rl.DrawTexturePro(tex, source_rect, dest, {0, 0}, 0, rl.WHITE)
    } else {
        rl.DrawRectangleRounded(frame_rect, 0.02, 10, FRAME_COLOR)
    }
    rl.DrawRectangleRoundedLines(frame_rect, 0.02, 10, rl.Color{80, 40, 20, 255})
    corner_size := f32(20)
    corners := []rl.Vector2{ {f32(a.frame_x), f32(a.frame_y)}, {f32(a.frame_x + a.frame_width), f32(a.frame_y)}, {f32(a.frame_x), f32(a.frame_y + a.frame_height)}, {f32(a.frame_x + a.frame_width), f32(a.frame_y + a.frame_height)}, }
    for corner in corners {
        rl.DrawCircleV(corner, corner_size, rl.Color{160, 82, 45, 255})
        rl.DrawCircleV(corner, corner_size - 3, FRAME_COLOR)
    }
}

draw_bead :: proc(bead: ^Bead, color_set: ColorSet, is_hovered: bool) {
    target_scale := is_hovered ? 1.1 : 1.0
    bead.hover_scale += (f32(target_scale) - bead.hover_scale) * 0.2
    if bead.bounce_offset > 0 { bead.bounce_offset -= 0.3 }
    bead_color := bead.is_active ? color_set.active : color_set.inactive
    if is_hovered { bead_color = color_set.highlight }
    final_pos := bead.current_pos
    final_pos.y += bead.bounce_offset
    scaled_width := bead.rect.width * bead.hover_scale
    scaled_height := bead.rect.height * bead.hover_scale
    offset_x := (scaled_width - bead.rect.width) * 0.5
    offset_y := (scaled_height - bead.rect.height) * 0.5
    scaled_rect := rl.Rectangle{ final_pos.x - offset_x, final_pos.y - offset_y, scaled_width, scaled_height }
    shadow_rect := scaled_rect
    shadow_rect.x += 2; shadow_rect.y += 2
    rl.DrawEllipse(i32(shadow_rect.x + shadow_rect.width/2), i32(shadow_rect.y + shadow_rect.height/2), shadow_rect.width/2, shadow_rect.height/2, rl.Color{0, 0, 0, 60})
    rl.DrawEllipse(i32(scaled_rect.x + scaled_rect.width/2), i32(scaled_rect.y + scaled_rect.height/2), scaled_rect.width/2, scaled_rect.height/2, bead_color)
    highlight_color := rl.Color{255, 255, 255, 100}
    rl.DrawEllipse(i32(scaled_rect.x + scaled_rect.width/2 - 5), i32(scaled_rect.y + scaled_rect.height/2 - 5), scaled_rect.width/4, scaled_rect.height/4, highlight_color)
    
    // The old line-based sparkle effect is removed.
    
    if bead.is_solution_highlight {
        pulse_alpha := 150 + u8(math.sin(rl.GetTime() * 6.0) * 105)
        highlight_color := rl.Color{255, 255, 0, pulse_alpha}
        rl.DrawEllipseLines(i32(scaled_rect.x + scaled_rect.width/2), i32(scaled_rect.y + scaled_rect.height/2), scaled_rect.width/2 + 3, scaled_rect.height/2 + 3, highlight_color)
    }
}

draw_header :: proc(a: ^Abacus) {
    screen_width := rl.GetScreenWidth()
    slider.render_animations(&a.text_animator, screen_width)
}

draw_abacus :: proc(a: ^Abacus) {
    mouse_pos := rl.GetMousePosition()
    draw_frame(a)
    bar_rect := rl.Rectangle{f32(a.frame_x), f32(a.bar_y_pos), f32(a.frame_width), f32(BAR_HEIGHT)}
    rl.DrawRectangleRec(bar_rect, BAR_COLOR)
    rl.DrawRectangleLinesEx(bar_rect, 2, rl.Color{80, 40, 20, 255})
    for i in 0..<a.rod_count {
        rod := &a.rods[i]
        rod.heaven_bead.rect = {rod.heaven_bead.current_pos.x, rod.heaven_bead.current_pos.y, f32(a.layout.bead_width), f32(a.layout.bead_height)}
        for j in 0..<4 {
            rod.earth_beads[j].rect = {rod.earth_beads[j].current_pos.x, rod.earth_beads[j].current_pos.y, f32(a.layout.bead_width), f32(a.layout.bead_height)}
        }
        rod_x := f32(a.frame_x + a.layout.frame_padding + i32(i) * a.layout.rod_spacing)
        rl.DrawLineEx({rod_x, f32(a.frame_y + 10)}, {rod_x, f32(a.frame_y + a.frame_height - 10)}, f32(ROD_WIDTH), ROD_COLOR)
        color_wheel := COLOR_WHEEL
        color_set := color_wheel[rod.color_index]
        heaven_hovered := rl.CheckCollisionPointRec(mouse_pos, rod.heaven_bead.rect) && a.game_state == .PLAYING
        draw_bead(&rod.heaven_bead, color_set, heaven_hovered)
        for j in 0..<4 {
            earth_hovered := rl.CheckCollisionPointRec(mouse_pos, rod.earth_beads[j].rect) && a.game_state == .PLAYING
            draw_bead(&rod.earth_beads[j], color_set, earth_hovered)
        }
        rod_value_text := fmt.ctprintf("%v", rod.value)
        font_size : f32 = a.font_sizes.rod_value
        text_size := rl.MeasureTextEx(a.font, rod_value_text, font_size, 1.0)
        text_x := rod_x - text_size.x/2
        text_y := f32(a.frame_y - i32(font_size) - 15)
        rl.DrawTextEx(a.font, rod_value_text, {text_x + 2, text_y + 2}, font_size, 1.0, {0, 0, 0, 100})
        rl.DrawTextEx(a.font, rod_value_text, {text_x, text_y}, font_size, 1.0, VALUE_TEXT_COLOR)
        if rod.celebration_timer > 0 {
            alpha := u8(f32(rod.celebration_timer) / 30.0 * 255)
            rl.DrawCircleLines(i32(rod_x), i32(text_y) + i32(font_size)/2, 25, {255, 215, 0, alpha})
        }
    }
}

draw_footer :: proc(a: ^Abacus) {
    screen_width := i32(rl.GetScreenWidth())
    screen_height := i32(rl.GetScreenHeight())
    mouse_pos := rl.GetMousePosition()
    footer_y := screen_height - FOOTER_HEIGHT - 40
    rod_info_text := fmt.ctprintf("Rods: %d", a.rod_count)
    rl.DrawTextEx(a.font, rod_info_text, {40, f32(footer_y)}, a.font_sizes.info, 1.0, TEXT_COLOR)
    total := calc_total(a)
    total_text := fmt.ctprintf("Total: %v", total)
    total_font_size : f32 = a.font_sizes.total_label
    total_text_size := rl.MeasureTextEx(a.font, total_text, total_font_size, 1.0)
    text_x := f32(screen_width - i32(total_text_size.x)) / 2
    rl.DrawTextEx(a.font, total_text, {text_x + 2, f32(footer_y + 30 + 2)}, total_font_size, 1.0, {0, 0, 0, 100})
    rl.DrawTextEx(a.font, total_text, {text_x, f32(footer_y + 30)}, total_font_size, 1.0, TEXT_COLOR)
    challenge_label :: "Goal:"
    challenge_font_size: f32 = a.font_sizes.challenge_text
    label_font_size: f32 = a.font_sizes.challenge_label
    challenge_text: cstring
    if a.current_challenge.is_complete {
        challenge_text = fmt.ctprintf("Correct! The answer is %v!", a.current_challenge.number)
    } else if a.game_state == .GIVE_UP_ANIMATION {
        if a.current_challenge.type == .ADDITION {
            #partial switch a.addition_phase {
            case .SET_OPERAND1: challenge_text = fmt.ctprintf("First, let's set the board to %v...", a.current_challenge.operand1)
            case .ADD_OPERAND2: challenge_text = fmt.ctprintf("Now, let's add %v...", a.current_challenge.operand2)
            case: challenge_text = "Showing the solution..."
            }
        } else { challenge_text = "Showing the solution..." }
    } else { challenge_text = a.current_challenge.text }
    label_size := rl.MeasureTextEx(a.font, challenge_label, label_font_size, 1.0)
    text_size := rl.MeasureTextEx(a.font, challenge_text, challenge_font_size, 1.0)
    padding: f32 = 15
    panel_width := label_size.x + text_size.x + padding * 3
    panel_height := max(label_size.y, text_size.y) + padding * 2
    panel_x := f32(screen_width - i32(panel_width)) / 2
    panel_y := f32(footer_y + 65)
    scale := a.current_challenge.anim_scale
    scaled_panel_rect := rl.Rectangle{ panel_x + panel_width * (1 - scale) / 2, panel_y + panel_height * (1 - scale) / 2, panel_width * scale, panel_height * scale }
    rl.DrawRectangleRounded(scaled_panel_rect, 0.2, 8, FRAME_SHADOW)
    pulse_alpha := 150 + u8(math.sin(rl.GetTime() * 2.0) * 55)
    rl.DrawRectangleRoundedLines(scaled_panel_rect, 0.2, 8, {255, 215, 0, pulse_alpha})
    label_pos := rl.Vector2{scaled_panel_rect.x + padding, scaled_panel_rect.y + (scaled_panel_rect.height - label_size.y) / 2}
    text_pos := rl.Vector2{label_pos.x + label_size.x + padding, scaled_panel_rect.y + (scaled_panel_rect.height - text_size.y) / 2}
    challenge_color := a.current_challenge.is_complete ? CHALLENGE_COMPLETE_COLOR : CHALLENGE_TEXT_COLOR
    rl.DrawTextEx(a.font, challenge_label, label_pos, label_font_size, 1.0, CHALLENGE_TEXT_COLOR)
    rl.DrawTextEx(a.font, challenge_text, text_pos, challenge_font_size, 1.0, challenge_color)
    if a.game_state == .PLAYING {
        button_font_size: f32 = a.font_sizes.button
        button_padding: f32 = 10
        give_up_text :: "I give up!"
        give_up_text_size := rl.MeasureTextEx(a.font, give_up_text, button_font_size, 1.0)
        give_up_button_rect := rl.Rectangle{ f32(screen_width) - give_up_text_size.x - button_padding * 2 - 40, f32(footer_y), give_up_text_size.x + button_padding * 2, give_up_text_size.y + button_padding * 2 }
        reset_text :: "Reset"
        reset_text_size := rl.MeasureTextEx(a.font, reset_text, button_font_size, 1.0)
        reset_button_rect := rl.Rectangle{ give_up_button_rect.x - reset_text_size.x - button_padding * 2 - 15, f32(footer_y), reset_text_size.x + button_padding * 2, reset_text_size.y + button_padding * 2 }
        is_reset_hovered := rl.CheckCollisionPointRec(mouse_pos, reset_button_rect)
        reset_color := is_reset_hovered ? RESET_BTN_HOVER_COLOR : RESET_BTN_COLOR
        rl.DrawRectangleRounded(reset_button_rect, 0.3, 4, reset_color)
        rl.DrawTextEx(a.font, reset_text, {reset_button_rect.x + button_padding, reset_button_rect.y + button_padding}, button_font_size, 1.0, TEXT_COLOR)
        is_give_up_hovered := rl.CheckCollisionPointRec(mouse_pos, give_up_button_rect)
        give_up_color := is_give_up_hovered ? rl.Color{255, 60, 60, 255} : rl.Color{255, 100, 100, 200}
        rl.DrawRectangleRounded(give_up_button_rect, 0.3, 4, give_up_color)
        rl.DrawTextEx(a.font, give_up_text, {give_up_button_rect.x + button_padding, give_up_button_rect.y + button_padding}, button_font_size, 1.0, TEXT_COLOR)
    }
}

draw_game :: proc(a: ^Abacus) {
    rl.BeginDrawing()
    defer rl.EndDrawing()

    draw_background(a.background_wave)
    draw_header(a)
    draw_abacus(a)
    draw_footer(a)
    
    // Draw particles on top of everything else
    for particle in a.particles {
        alpha := u8(particle.life / particle.max_life * 255)
        rl.DrawCircleV(particle.pos, particle.size, {particle.color.r, particle.color.g, particle.color.b, alpha})
    }
}

main :: proc() {
    rl.SetConfigFlags({.MSAA_4X_HINT, .WINDOW_RESIZABLE, .VSYNC_HINT})
    rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, TITLE)
    defer rl.CloseWindow()

    rl.InitAudioDevice()
    defer rl.CloseAudioDevice()

    open_snd := rl.LoadSound("assets/open.mp3")
    earth_snd := rl.LoadSound("assets/earth.mp3")
    heaven_snd := rl.LoadSound("assets/heaven.mp3")
    challenge_complete_snd := rl.LoadSound("assets/complete.mp3")
    wood_texture := rl.LoadTexture("assets/wood.jpg")
    defer {
        rl.UnloadSound(open_snd)
        rl.UnloadSound(earth_snd)
        rl.UnloadSound(heaven_snd)
        rl.UnloadSound(challenge_complete_snd)
        rl.UnloadTexture(wood_texture)
    }
    if rl.IsSoundReady(open_snd) { rl.PlaySound(open_snd) }
    rl.SetTargetFPS(120)

    seed := rand.create(u64(time.now()._nsec))
    rng = rand.default_random_generator(&seed)
    abacus := init_abacus(DEFAULT_ROD_COUNT_INDEX)
    abacus.wood_texture = wood_texture
    load_font(&abacus, 42) 
    
    abacus.text_animator = slider.init(abacus.font, slider.SUNSET_GRADIENT)
    screen_width_f32 := f32(rl.GetScreenWidth())
    title_config := slider.new_animation( text = "Abacus Adventure", target_x = screen_width_f32 / 2, y = 20, font_size = abacus.font_sizes.title, start_delay = 0.2, slide_distance = -500, duration = 1.2, easing = .EASE_OUT_BACK, )
    slider.add_animation(&abacus.text_animator, title_config)
    subtitle_config := slider.new_animation( text = "Click beads to count! Use ← → to change size (:", target_x = screen_width_f32 / 2, y = 80, font_size = abacus.font_sizes.subtitle, start_delay = 0.5, slide_distance = 500, duration = 1.0, easing = .EASE_OUT_CUBIC, )
    slider.add_animation(&abacus.text_animator, subtitle_config)

    defer {
        delete(abacus.rods)
        delete(abacus.particles)
        delete(abacus.solution_moves)
        slider.destroy(&abacus.text_animator)
        unload_font(&abacus)
    }

    for !rl.WindowShouldClose() {
        dt := rl.GetFrameTime()
        if rl.IsWindowResized() {
            sw := rl.GetScreenWidth()
            sh := rl.GetScreenHeight()
            abacus.font_sizes = calc_font_sizes(sw, sh)
            update_abacus_geometry(&abacus)
            update_animator_layout(&abacus.text_animator)
        }
        if !abacus.intro_finished {
            slider.update_animations(&abacus.text_animator, dt)
            if slider.all_animations_complete(&abacus.text_animator) {
                abacus.intro_finished = true
            }
        }
        handle_input(&abacus, earth_snd, heaven_snd)
        update_state(&abacus, dt, earth_snd, challenge_complete_snd)
        draw_game(&abacus)
    }
}