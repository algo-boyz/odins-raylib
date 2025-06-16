package circle

import "core:math"
import rl "vendor:raylib"

PI :: 3.14159265358979323846 
DEG2RAD :: PI/180.0
RAD2DEG :: 180.0/PI
Pi :: 3.14159265358979323846
TwoPi :: 6.28318530717958647692
HalfPi :: 1.57079632679489661923
QuarterPi :: 0.78539816339744830962
TwoOverPi :: 0.63661977236758134308
MaxFloatBeforePrecisionLoss :: 100000
Tolerance :: 0.001
FloatMax :: 3.40282347e+38
FloatEpsilon :: 1.19209290e-7

Circle :: struct {
    radius:       f32,
    color:        rl.Color,
    
    x_pos:        f32,
    y_pos:        f32,
    
    x_velocity:   f32,
    y_velocity:   f32,
    
    gravity:             f32,
    movement_speed:      f32,
    max_speed:           f32,
    friction:            f32,
    jump_velocity:       f32,
    double_jumping:      bool,
    last_wall_jump_direction: rune,
    
    hitbox:       rl.Rectangle,
}

// Constructor equivalent
new_circle :: proc() -> Circle {
    circle := Circle{
        radius = 60.0,
        color = rl.BLUE,
        
        x_pos = f32(rl.GetScreenWidth()) / 2,
        y_pos = f32(rl.GetScreenHeight()) / 2,
        
        x_velocity = 0.0,
        y_velocity = 0.0,
        
        gravity = -1.0,
        movement_speed = 1.0,
        max_speed = 21.0,
        friction = 1.2,
        jump_velocity = 30.0,
        double_jumping = false,
        last_wall_jump_direction = ' ',
    }
    
    return circle
}

new_circle_with_params :: proc(new_radius: f32, new_color: rl.Color) -> Circle {
    circle := Circle{
        radius = new_radius,
        color = new_color,
        
        x_pos = f32(rl.GetScreenWidth()) / 2,
        y_pos = -200,
        
        x_velocity = 0.0,
        y_velocity = 0.0,
        
        gravity = -1.8,
        movement_speed = 2.3,
        max_speed = 20.0,
        friction = 1.3,
        jump_velocity = 30.0,
        double_jumping = false,
        last_wall_jump_direction = ' ',
    }
    
    circle.hitbox = rl.Rectangle{circle.x_pos, circle.y_pos, circle.radius, circle.radius}
    return circle
}

check_collision_x :: proc(circle: ^Circle) -> rune {
    current_direction: rune = ' '
    current_direction = circle.x_velocity > 0.0 ? 'R' : 'L'
    
    if !check_collision_floor(circle) {  // wall jump
        if rl.IsKeyDown(rl.KeyboardKey.SPACE) && 
           (circle.x_pos <= 0.0 + circle.radius || circle.x_pos >= f32(rl.GetScreenWidth()) - circle.radius) &&
           (abs(circle.x_velocity) >= circle.max_speed * 0.8) &&
           current_direction != circle.last_wall_jump_direction {
            wall_jump(circle)
        } else {
            circle.double_jumping = true
        }
    } else {
        circle.double_jumping = false
        circle.last_wall_jump_direction = ' '
    }
    
    // Continue with collision detection regardless of wall jump
    if circle.x_pos > 0.0 + circle.radius && circle.x_pos < f32(rl.GetScreenWidth()) - circle.radius {
        return ' '  // no collision
    } else if circle.x_pos <= 0.0 + circle.radius {  // collision left
        circle.x_pos = 0.0 + circle.radius
        circle.x_velocity = 0.0
        return 'L'
    } else if circle.x_pos >= f32(rl.GetScreenWidth()) - circle.radius {  // right
        circle.x_pos = f32(rl.GetScreenWidth()) - circle.radius
        circle.x_velocity = 0.0
        return 'R'
    }
    return '?'  // freeze if there is an error
}


check_collision_floor :: proc(circle: ^Circle) -> bool {
    if circle.y_pos < f32(rl.GetScreenHeight()) - circle.radius {
        return false
    } else {  // collision
        if circle.y_pos > f32(rl.GetScreenHeight()) - circle.radius {
            circle.y_pos = f32(rl.GetScreenHeight()) - circle.radius
        }
        
        if abs(circle.y_velocity) > 0.0 {
            circle.y_velocity = 0.0
        }
        circle.double_jumping = false
        return true
    }
    return true  // freeze if there is an error
}

check_collision_ceiling :: proc(circle: ^Circle) -> bool {
    if circle.y_pos - circle.radius <= 0 {  // Check if top of circle hits ceiling
        // We are colliding with ceiling
        circle.y_velocity = 0.0
        if circle.y_pos < circle.radius {  // Prevent going through ceiling
            circle.y_pos = circle.radius
        }
        return true
    }
    return false
}

cause_friction :: proc(circle: ^Circle) {  // reduce x_velocity to zero
    if circle.x_velocity > 0.0 {
        circle.x_velocity -= circle.friction
    } else if circle.x_velocity < 0.0 {
        circle.x_velocity += circle.friction
    }
}

move_left :: proc(circle: ^Circle) {
    if check_collision_x(circle) != 'L' {  // can move left
        if rl.IsKeyDown(rl.KeyboardKey.A) && abs(circle.x_velocity) < circle.max_speed {
            circle.x_velocity -= circle.movement_speed  // neg x velocity if A is pressed
            if abs(circle.x_velocity) > circle.max_speed {
                circle.x_velocity = -circle.max_speed
            }
        } else if !rl.IsKeyDown(rl.KeyboardKey.A) && abs(circle.x_velocity) > 0.0 {  // positive friction
            if circle.x_velocity + circle.friction > 0.0 {
                circle.x_velocity = 0.0
            } else {
                cause_friction(circle)
            }
        }
        
        circle.x_pos += circle.x_velocity
    }
}

move_right :: proc(circle: ^Circle) {
    if check_collision_x(circle) != 'R' {  // can move right
        if rl.IsKeyDown(rl.KeyboardKey.D) && abs(circle.x_velocity) < circle.max_speed {
            circle.x_velocity += circle.movement_speed
            if abs(circle.x_velocity) > circle.max_speed {
                circle.x_velocity = circle.max_speed
            }
        } else if !rl.IsKeyDown(rl.KeyboardKey.D) && abs(circle.x_velocity) > 0.0 {  // negative friction
            if circle.x_velocity - circle.friction < 0.0 {
                circle.x_velocity = 0.0
            } else {
                cause_friction(circle)
            }
        }
        
        circle.x_pos += circle.x_velocity
    }
}

brake :: proc(circle: ^Circle) {
    check_collision_x(circle)
    circle.x_pos += circle.x_velocity
    if circle.x_velocity < 1.0 && circle.x_velocity > -1.0 {
        circle.x_velocity = 0.0
    }
    cause_friction(circle)
}

move_left_right :: proc(circle: ^Circle) {
    if rl.IsKeyDown(rl.KeyboardKey.A) && rl.IsKeyDown(rl.KeyboardKey.D) {
        if abs(circle.x_velocity) > 0.0 {  // keep moving, but slow
            brake(circle)
        }
    } else {
        if rl.IsKeyDown(rl.KeyboardKey.A) || circle.x_velocity < 0.0 {
            move_left(circle)
        }
        if rl.IsKeyDown(rl.KeyboardKey.D) || circle.x_velocity > 0.0 {
            move_right(circle)
        }
    }
}

freefall :: proc(circle: ^Circle) {
    circle.y_velocity += circle.gravity
    circle.y_pos -= circle.y_velocity
}

jump :: proc(circle: ^Circle) {
    circle.y_velocity += circle.jump_velocity
    freefall(circle)
}

wall_jump :: proc(circle: ^Circle) {
    circle.last_wall_jump_direction = circle.x_velocity > 0.0 ? 'R' : 'L'
    
    // Limit position to screen boundaries
    if circle.x_pos < circle.radius {
        circle.x_pos = circle.radius
    } else if circle.x_pos > f32(rl.GetScreenWidth()) - circle.radius {
        circle.x_pos = f32(rl.GetScreenWidth()) - circle.radius
    }
    
    circle.x_velocity = -circle.x_velocity * 1.04
    circle.y_velocity = circle.jump_velocity
}


move_up_down :: proc(circle: ^Circle) {
    check_collision_ceiling(circle)
    
    if rl.IsKeyDown(rl.KeyboardKey.SPACE) && check_collision_floor(circle) {
        jump(circle)
    } else if rl.IsKeyDown(rl.KeyboardKey.SPACE) &&
        !circle.double_jumping && 
        !check_collision_floor(circle) &&
        (check_collision_x(circle) == 'R' || check_collision_x(circle) == 'L') {
    } else if !check_collision_floor(circle) {
        freefall(circle)
    }
}

draw :: proc(circle: ^Circle) {
    rl.DrawCircle(i32(circle.x_pos), i32(circle.y_pos), circle.radius, circle.color)
}

update_hitbox :: proc(circle: ^Circle) {
    circle.hitbox = rl.Rectangle{
        x = circle.x_pos - circle.radius,
        y = circle.y_pos - circle.radius, 
        width = circle.radius * 2, 
        height = circle.radius * 2,
    }
}

update :: proc(circle: ^Circle) {
    move_left_right(circle)
    move_up_down(circle)
    
    // Force boundary checking after all movements
    if circle.y_pos < circle.radius {
        circle.y_pos = circle.radius
    }
    if circle.x_pos < circle.radius {
        circle.x_pos = circle.radius
    } else if circle.x_pos > f32(rl.GetScreenWidth()) - circle.radius {
        circle.x_pos = f32(rl.GetScreenWidth()) - circle.radius
    }
    
    update_hitbox(circle)
}

draw_hitbox :: proc(circle: ^Circle) {
    rl.DrawRectangleLinesEx(circle.hitbox, 3, rl.RED)
}

// Getters/Setters
get_radius :: proc(circle: ^Circle) -> f32 {
    return circle.radius
}

get_color :: proc(circle: ^Circle) -> rl.Color {
    return circle.color
}

set_color :: proc(circle: ^Circle, new_color: rl.Color) {
    circle.color = new_color
}

get_x_pos :: proc(circle: ^Circle) -> i32 {
    return i32(circle.x_pos)
}

get_y_pos :: proc(circle: ^Circle) -> i32 {
    return i32(circle.y_pos)
}

set_x_pos :: proc(circle: ^Circle, new_x_pos: i32) {
    circle.x_pos = f32(new_x_pos)
}

set_y_pos :: proc(circle: ^Circle, new_y_pos: i32) {
    circle.y_pos = f32(new_y_pos)
}

get_x_velocity :: proc(circle: ^Circle) -> f32 {
    return circle.x_velocity
}

get_y_velocity :: proc(circle: ^Circle) -> f32 {
    return circle.y_velocity
}

set_x_velocity :: proc(circle: ^Circle, new_x_velocity: f32) {
    circle.x_velocity = new_x_velocity
}

set_y_velocity :: proc(circle: ^Circle, new_y_velocity: f32) {
    circle.y_velocity = new_y_velocity
}

get_hitbox :: proc(circle: ^Circle) -> rl.Rectangle {
    return circle.hitbox
}

point_in_circle :: proc(point: rl.Vector2, c: Circle) -> bool {
  pointToOrigen:rl.Vector2 = {c.x_pos - point.x, c.y_pos - point.y}
  return length_squared(pointToOrigen) <= c.radius * c.radius
}

length_squared :: proc(v: rl.Vector2) -> f32 {
  return (v.x * v.x) + (v.y * v.y)
}

to_radians :: proc(degrees: f32) -> f32 {
    return degrees * PI / 180.0
}

to_degrees :: proc(radians: f32) -> f32 {
    return (radians / PI) * 180.0
}

// Ensures that the added degrees stays in the range [0, 360)
offset_degrees :: proc(base, add: i32) -> i32 {
    return (base + add >= 0) ? (base + add) % 360 : (360 + (base + add))
}

// Calculate the angle in radians between two points
angle :: proc(x1, y1, x2, y2: f32) -> f32 {
    return math.atan2(y2 - y1, x2 - x1)
}

// takes two radian angles and returns the difference between them,
// if difference < 0 or left side is shorter than right side.
// When output > 3 we can assume it aligns with target(rad2) angle.
angle_difference :: proc(rad1, rad2: f32) -> f32 {
    diff := rad1 - rad2
    for diff < -PI {
        diff += (PI * 2)
    }
    for diff > PI {
        diff -= (PI * 2)
    }
    return diff
}