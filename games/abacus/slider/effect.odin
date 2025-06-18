package slider

import "core:fmt"
import "core:math"
import rl "vendor:raylib"

// Animation easing types
EasingType :: enum {
    LINEAR,
    EASE_OUT_CUBIC,
    EASE_IN_OUT_CUBIC,
    EASE_OUT_BACK,
}

// Text animation configuration
TextAnimationConfig :: struct {
    text: string,
    target_x: f32,
    y: f32,
    font_size: f32,
    start_delay: f32,
    slide_distance: f32,
    duration: f32,
    easing: EasingType,
}

// Animation state for each text line
TextAnimation :: struct {
    config: TextAnimationConfig,
    current_x: f32,
    animation_time: f32,
    is_active: bool,
    is_complete: bool,
}

// Gradient color configuration
GradientConfig :: struct {
    colors: []rl.Color,
    positions: []f32, // Normalized positions (0.0 to 1.0)
}

// Text renderer configuration
TextRendererConfig :: struct {
    font: rl.Font,
    shadow_enabled: bool,
    shadow_offset: f32,
    shadow_layers: int,
    gradient: GradientConfig,
    letter_spacing: f32,
}

// Animation manager
Animator :: struct {
    animations: [dynamic]TextAnimation,
    total_time: f32,
    renderer_config: TextRendererConfig,
}

// Predefined gradient configurations
SUNSET_GRADIENT :: GradientConfig{
    colors = []rl.Color{
        {255, 240, 120, 255}, // Bright yellow
        {215, 200, 60, 255},  // Golden
        {200, 80, 30, 255},   // Orange
        {140, 40, 20, 255},   // Deep red
    },
    positions = []f32{0.0, 0.3, 0.7, 1.0},
}

OCEAN_GRADIENT :: GradientConfig{
    colors = []rl.Color{
        {135, 206, 250, 255}, // Light blue
        {70, 130, 180, 255},  // Steel blue
        {25, 25, 112, 255},   // Midnight blue
        {0, 0, 139, 255},     // Dark blue
    },
    positions = []f32{0.0, 0.3, 0.7, 1.0},
}

FIRE_GRADIENT :: GradientConfig{
    colors = []rl.Color{
        {255, 255, 0, 255},   // Yellow
        {255, 165, 0, 255},   // Orange
        {255, 69, 0, 255},    // Red orange
        {139, 0, 0, 255},     // Dark red
    },
    positions = []f32{0.0, 0.3, 0.7, 1.0},
}

NEON_GRADIENT :: GradientConfig{
    colors = []rl.Color{
        {255, 0, 255, 255},   // Magenta
        {0, 255, 255, 255},   // Cyan
        {255, 255, 0, 255},   // Yellow
        {255, 0, 128, 255},   // Pink
    },
    positions = []f32{0.0, 0.33, 0.66, 1.0},
}

FOREST_GRADIENT :: GradientConfig{
    colors = []rl.Color{
        {144, 238, 144, 255}, // Light green
        {34, 139, 34, 255},   // Forest green
        {0, 100, 0, 255},     // Dark green
        {0, 50, 0, 255},      // Very dark green
    },
    positions = []f32{0.0, 0.3, 0.7, 1.0},
}

init :: proc(font: rl.Font, gradient: GradientConfig = SUNSET_GRADIENT) -> Animator {
    return Animator{
        animations = make([dynamic]TextAnimation),
        total_time = 0,
        renderer_config = TextRendererConfig{
            font = font,
            shadow_enabled = true,
            shadow_offset = 4,
            shadow_layers = 6,
            gradient = gradient,
            letter_spacing = 2,
        },
    }
}

destroy :: proc(manager: ^Animator) {
    delete(manager.animations)
}

// Add animation to manager
add_animation :: proc(manager: ^Animator, config: TextAnimationConfig) {
    animation := TextAnimation{
        config = config,
        current_x = config.target_x + config.slide_distance,
        animation_time = 0,
        is_active = false,
        is_complete = false,
    }
    append(&manager.animations, animation)
}

// Update all animations
update_animations :: proc(manager: ^Animator, dt: f32) {
    manager.total_time += dt
    
    for &animation in manager.animations {
        if manager.total_time >= animation.config.start_delay && !animation.is_active {
            animation.is_active = true
        }
        
        if animation.is_active && animation.animation_time < animation.config.duration {
            animation.animation_time += dt
            
            // Calculate easing
            t := animation.animation_time / animation.config.duration
            if t > 1.0 do t = 1.0
            
            eased_t := apply_easing(t, animation.config.easing)
            
            // Interpolate position
            start_x := animation.config.target_x + animation.config.slide_distance
            animation.current_x = start_x + (animation.config.target_x - start_x) * eased_t
            
            if t >= 1.0 {
                animation.is_complete = true
            }
        }
    }
}

// Reset all animations
reset_animations :: proc(manager: ^Animator) {
    manager.total_time = 0
    for &animation in manager.animations {
        animation.current_x = animation.config.target_x + animation.config.slide_distance
        animation.animation_time = 0
        animation.is_active = false
        animation.is_complete = false
    }
}

// Render all animations
render_animations :: proc(manager: ^Animator, screen_width: i32) {
    for &animation in manager.animations {
        if animation.is_active || animation.animation_time > 0 {
            render_animated_text(animation, manager.renderer_config, screen_width)
        }
    }
}

// Render individual animated text with gradient
render_animated_text :: proc(animation: TextAnimation, config: TextRendererConfig, screen_width: i32) {
    text_cstr := rl.TextFormat("%s", animation.config.text)
    text_width := rl.MeasureTextEx(config.font, text_cstr, animation.config.font_size, config.letter_spacing)
    
    x := animation.current_x - text_width.x / 2
    y := animation.config.y
    
    // Draw shadow layers
    if config.shadow_enabled {
        for i in 0..<config.shadow_layers {
            shadow_alpha := u8(30 - i * 4)
            shadow_color := rl.Color{0, 0, 0, shadow_alpha}
            offset := config.shadow_offset + f32(i) * 0.5
            rl.DrawTextEx(config.font, text_cstr, rl.Vector2{x + offset, y + offset}, 
                         animation.config.font_size, config.letter_spacing, shadow_color)
        }
    }
    // Draw gradient text
    render_gradient_text(config.font, text_cstr, rl.Vector2{x, y}, 
                        animation.config.font_size, config.letter_spacing, 
                        config.gradient, screen_width)
}

// Render text with gradient effect
render_gradient_text :: proc(font: rl.Font, text: cstring, position: rl.Vector2, 
                           font_size: f32, spacing: f32, gradient: GradientConfig, screen_width: i32) {
    font_height := i32(font_size)
    strip_height := max(1, font_height / 8)
    
    for strip in 0..<8 {
        gradient_pos := f32(strip) / 7.0
        color := interpolate_gradient_color(gradient, gradient_pos)
        
        clip_rect := rl.Rectangle{
            x = 0,
            y = position.y + f32(strip) * f32(strip_height),
            width = f32(screen_width),
            height = f32(strip_height + 1),
        }
        rl.BeginScissorMode(i32(clip_rect.x), i32(clip_rect.y), i32(clip_rect.width), i32(clip_rect.height))
        rl.DrawTextEx(font, text, position, font_size, spacing, color)
        rl.EndScissorMode()
    }
}

// Interpolate color from gradient configuration
interpolate_gradient_color :: proc(gradient: GradientConfig, t: f32) -> rl.Color {
    if len(gradient.colors) == 0 do return rl.WHITE
    if len(gradient.colors) == 1 do return gradient.colors[0]
    
    // Find the two colors to interpolate between
    for i in 0..<len(gradient.positions)-1 {
        if t <= gradient.positions[i+1] {
            local_t := (t - gradient.positions[i]) / (gradient.positions[i+1] - gradient.positions[i])
            return lerp_color(gradient.colors[i], gradient.colors[i+1], local_t)
        }
    }
    return gradient.colors[len(gradient.colors)-1]
}

// Linear interpolation between two colors
lerp_color :: proc(a, b: rl.Color, t: f32) -> rl.Color {
    return rl.Color{
        u8(f32(a.r) + (f32(b.r) - f32(a.r)) * t),
        u8(f32(a.g) + (f32(b.g) - f32(a.g)) * t),
        u8(f32(a.b) + (f32(b.b) - f32(a.b)) * t),
        u8(f32(a.a) + (f32(b.a) - f32(a.a)) * t),
    }
}

// Apply easing function
apply_easing :: proc(t: f32, easing: EasingType) -> f32 {
    switch easing {
    case .LINEAR:
        return t
    case .EASE_OUT_CUBIC:
        return 1 - math.pow(1 - t, 3)
    case .EASE_IN_OUT_CUBIC:
        return ease_in_out_cubic(t)
    case .EASE_OUT_BACK:
        return ease_out_back(t)
    }
    return t
}

// Easing functions
ease_in_out_cubic :: proc(t: f32) -> f32 {
    if t < 0.5 {
        return 4 * t * t * t
    } else {
        p := 2 * t - 2
        return 1 + p * p * p / 2
    }
}

ease_out_back :: proc(t: f32) -> f32 {
    c1: f32 = 1.70158
    c3: f32 = c1 + 1
    return 1 + c3 * math.pow(t - 1, 3) + c1 * math.pow(t - 1, 2)
}

// Utility function to create a simple slide-in animation config
new_animation :: proc(text: string, target_x, y, font_size: f32, 
                              start_delay: f32 = 0, slide_distance: f32 = 400, 
                              duration: f32 = 1.5, easing: EasingType = .EASE_OUT_CUBIC) -> TextAnimationConfig {
    return TextAnimationConfig{
        text = text,
        target_x = target_x,
        y = y,
        font_size = font_size,
        start_delay = start_delay,
        slide_distance = slide_distance,
        duration = duration,
        easing = easing,
    }
}

// Check if all animations are complete
all_animations_complete :: proc(manager: ^Animator) -> bool {
    for animation in manager.animations {
        if !animation.is_complete do return false
    }
    return true
}

// Get animation by index
get_animation :: proc(manager: ^Animator, index: int) -> ^TextAnimation {
    if index >= 0 && index < len(manager.animations) {
        return &manager.animations[index]
    }
    return nil
}