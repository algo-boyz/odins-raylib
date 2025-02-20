package phys

import "core:math"
import rl "vendor:raylib"
// todo https://github.com/Porem5002/graphi/blob/master/demo/img1.png
// odin visualizer

// Springs
// Daniel Holden
// https://theorangeduck.com/page/spring-roll-call
// https://github.com/orangeduck/Spring-It-On

// Freya's smooth lerp function with exponential decay for smooth transitions 
// between two points/values over time
// a - from
// b - to
// decay - approx. from 1 (slow) to 25 (fast)
// dt - deltaTime
exp_decay :: proc "contextless" (a, b, decay, dt: f32) -> f32 {
    return b+(a-b)*math.exp(-decay*dt)
}

// https://gamedev.net/articles/programming/general-and-gameplay-programming/inverse-lerp-a-super-useful-yet-often-overlooked-function-r5230/

// remap takes a value between iMin and iMax and remaps it to a value between oMin and oMax
remap :: proc "contextless" (iMin, iMax, oMin, oMax, val: $T) -> T {
    t := inv_lerp(iMin, iMax, val)
    // lerp returns a blend between a and b, based on a fraction t
    return math.lerp(oMin, oMax, t)
}

eerp :: proc "contextless" (x, y, a: f32) -> f32 {
    return math.pow(x, (1.0 - a)) * math.pow(y, a)
}

eerp_alt :: proc "contextless" (x, y, a: f32) -> f32 {
    return x * math.pow(y / x, a)
}

lerp_alt :: proc "contextless" (x, y, a: f32) -> f32 {
    return x + (y - x) * a
}

// inverse lerp returns a fraction t, based on a value between a and b
inv_lerp :: proc "contextless" (a, b, val: $T) -> T {
    return (val - a) / (b - a)
}

// damper so each frame can smoothly move toward the goal without popping
damper_exponential :: proc "contextless" (
    x, g, damping, dt: f32,
    ft: f32 = 1.0/60.0,
) -> f32 {
    return math.lerp(x, g, 1.0 - math.pow(1.0/(1.0 - ft*damping), -dt/ft))
}

fast_negexp :: proc "contextless" (x: f32) -> f32 {
    return 1.0 / (1.0 + x + 0.48*x*x + 0.235*x*x*x)
}

damper_exact :: proc "contextless" (
    x, g, halflife, dt: f32,
    eps: f32 = 1e-5,
) -> f32 {
    return math.lerp(x, g, 1.0 - fast_negexp((0.69314718056 * dt)/(halflife + eps)))
}

fast_atan :: proc "contextless" (x: f32) -> f32 {
    z := abs(x)
    w := z > 1.0 ? 1.0 / z : z
    y := (math.PI / 4.0) * w - w * (w - 1.0) * (0.2447 + 0.0663 * w)
    return math.copy_sign(z > 1.0 ? math.PI / 2.0 - y : y, x)
}

square :: proc "contextless" (x: f32) -> f32 {
    return x * x
}

frequency_to_stiffness :: proc "contextless" (frequency: f32) -> f32 {
    return square(2.0 * math.PI * frequency)
}

stiffness_to_frequency :: proc "contextless" (stiffness: f32) -> f32 {
    return math.sqrt(stiffness) / (2.0 * math.PI)
}

halflife_to_damping :: proc "contextless" (halflife: f32, eps: f32 = 1e-5) -> f32 {
    return (4.0 * 0.69314718056) / (halflife + eps)
}

damping_to_halflife :: proc "contextless" (damping: f32, eps: f32 = 1e-5) -> f32 {
    return (4.0 * 0.69314718056) / (damping + eps)
}

critical_halflife :: proc "contextless" (frequency: f32) -> f32 {
    return damping_to_halflife(math.sqrt(frequency_to_stiffness(frequency) * 4.0))
}

critical_frequency :: proc "contextless" (halflife: f32) -> f32 {
    return stiffness_to_frequency(square(halflife_to_damping(halflife)) / 4.0)
}

spring_damper_exact :: proc "contextless" (
    x: ^f32,
    v: ^f32,
    x_goal: f32,
    v_goal: f32,
    frequency: f32,
    halflife: f32,
    dt: f32,
    eps: f32 = 1e-5,
) {
    g := x_goal
    q := v_goal
    s := frequency_to_stiffness(frequency)
    d := halflife_to_damping(halflife)
    c := g + (d*q)/(s + eps)
    y := d/2.0
    w := math.sqrt(abs(s - y*y))
    
    j := math.sqrt(square(x^ - c) + square((v^ + y*(x^ - c))/w))
    p := math.atan2(-(v^ + y*(x^ - c))/w, x^ - c)
    
    eydt := fast_negexp(y*dt)
    
    x^ = j*eydt*math.cos(w*dt + p) + c
    v^ = -y*j*eydt*math.cos(w*dt + p) - w*j*eydt*math.sin(w*dt + p)
}

damping_ratio_to_stiffness :: proc "contextless" (ratio, damping: f32) -> f32 {
    return square(damping / (ratio * 2.0))
}

damping_ratio_to_damping :: proc "contextless" (ratio, stiffness: f32) -> f32 {
    return ratio * 2.0 * math.sqrt(stiffness)
}

spring_damper_exact_ratio :: proc "contextless" (
    x, v: ^f32,
    x_goal, v_goal: f32,
    damping_ratio, halflife, dt: f32,
    eps: f32 = 1e-5,
) {
    g := x_goal
    q := v_goal
    d := halflife_to_damping(halflife)
    s := damping_ratio_to_stiffness(damping_ratio, d)
    c := g + (d*q) / (s + eps)
    y := d / 2.0
    
    if abs(s - (d*d) / 4.0) < eps { // Critically Damped
        j0 := x^ - c
        j1 := v^ + j0*y
        
        eydt := fast_negexp(y*dt)
        
        x^ = j0*eydt + dt*j1*eydt + c
        v^ = -y*j0*eydt - y*dt*j1*eydt + j1*eydt
    } else if s - (d*d) / 4.0 > 0.0 { // Under Damped
        w := math.sqrt(s - (d*d)/4.0)
        j := math.sqrt(square(v^ + y*(x^ - c)) / (w*w + eps) + square(x^ - c))
        p := fast_atan((v^ + (x^ - c) * y) / (-(x^ - c)*w + eps))
        
        j = x^ - c > 0.0 ? j : -j
        
        eydt := fast_negexp(y*dt)
        
        x^ = j*eydt*math.cos(w*dt + p) + c
        v^ = -y*j*eydt*math.cos(w*dt + p) - w*j*eydt*math.sin(w*dt + p)
    } else if s - (d*d) / 4.0 < 0.0 { // Over Damped
        y0 := (d + math.sqrt(d*d - 4*s)) / 2.0
        y1 := (d - math.sqrt(d*d - 4*s)) / 2.0
        j1 := (c*y0 - x^*y0 - v^) / (y1 - y0)
        j0 := x^ - j1 - c
        
        ey0dt := fast_negexp(y0*dt)
        ey1dt := fast_negexp(y1*dt)

        x^ = j0*ey0dt + j1*ey1dt + c
        v^ = -y0*j0*ey0dt - y1*j1*ey1dt
    }
}

critical_spring_damper_exact :: proc "contextless" (
    x, v: ^f32,
    x_goal, v_goal: f32,
    halflife, dt: f32,
) {
    g := x_goal
    q := v_goal
    d := halflife_to_damping(halflife)
    c := g + (d*q) / ((d*d) / 4.0)
    y := d / 2.0
    j0 := x^ - c
    j1 := v^ + j0*y
    eydt := fast_negexp(y*dt)

    x^ = eydt*(j0 + j1*dt) + c
    v^ = eydt*(v^ - j1*y*dt)
}

simple_spring_damper_exact :: proc "contextless" (
    x, v: ^f32,
    x_goal: f32,
    halflife, dt: f32,
) {
    y := halflife_to_damping(halflife) / 2.0
    j0 := x^ - x_goal
    j1 := v^ + j0*y
    eydt := fast_negexp(y*dt)

    x^ = eydt*(j0 + j1*dt) + x_goal
    v^ = eydt*(v^ - j1*y*dt)
}

decay_spring_damper_exact :: proc "contextless" (
    x, v: ^f32,
    halflife, dt: f32,
) {
    y := halflife_to_damping(halflife) / 2.0
    j1 := v^ + x^*y
    eydt := fast_negexp(y*dt)

    x^ = eydt*(x^ + j1*dt)
    v^ = eydt*(v^ - j1*y*dt)
}

spring_character_update :: proc "contextless" (
    x, v, a: ^f32,
    v_goal: f32,
    halflife, dt: f32,
) {
    y := halflife_to_damping(halflife) / 2.0
    j0 := v^ - v_goal
    j1 := a^ + j0*y
    eydt := fast_negexp(y*dt)

    x^ = eydt*(((-j1)/(y*y)) + ((-j0 - j1*dt)/y)) + 
         (j1/(y*y)) + j0/y + v_goal * dt + x^
    v^ = eydt*(j0 + j1*dt) + v_goal
    a^ = eydt*(a^ - j1*y*dt)
}

spring_character_predict :: proc "contextless" (
    px, pv, pa: []f32,
    x, v, a: f32,
    v_goal: f32,
    halflife, dt: f32,
) {
    count := len(px)
    
    for i := 0; i < count; i += 1 {
        px[i] = x
        pv[i] = v
        pa[i] = a
    }

    for i := 0; i < count; i += 1 {
        spring_character_update(&px[i], &pv[i], &pa[i], v_goal, halflife, f32(i) * dt)
    }
}

inertialize_transition :: proc "contextless" (
    off_x, off_v: ^f32,
    src_x, src_v: f32,
    dst_x, dst_v: f32,
) {
    off_x^ = (src_x + off_x^) - dst_x
    off_v^ = (src_v + off_v^) - dst_v
}

inertialize_update :: proc "contextless" (
    out_x, out_v: ^f32,
    off_x, off_v: ^f32,
    in_x, in_v: f32,
    halflife, dt: f32,
) {
    decay_spring_damper_exact(off_x, off_v, halflife, dt)
    out_x^ = in_x + off_x^
    out_v^ = in_v + off_v^
}

piecewise_interpolation :: proc "contextless" (
    x, v: ^f32,
    t: f32,
    pnts: []f32,
) {
    npnts := len(pnts)
    t := t * f32(npnts - 1)
    i0 := int(math.floor(t))
    i1 := i0 + 1
    i0 = i0 > npnts - 1 ? npnts - 1 : i0
    i1 = i1 > npnts - 1 ? npnts - 1 : i1
    alpha := math.mod(t, 1.0)
    
    x^ = math.lerp(pnts[i0], pnts[i1], alpha)
    v^ = (pnts[i0] - pnts[i1]) / f32(npnts)
}

spring_energy :: proc "contextless" (
    x, v: f32,
    frequency: f32,
    x_rest: f32 = 0.0,
    v_rest: f32 = 0.0,
    scale: f32 = 1.0,
) -> f32 {
    s := frequency_to_stiffness(frequency)
    return (square(scale * (v - v_rest)) + s * square(scale * (x - x_rest))) / 2.0
}

resonant_frequency :: proc "contextless" (
    goal_frequency, halflife: f32,
) -> f32 {
    d := halflife_to_damping(halflife)
    goal_stiffness := frequency_to_stiffness(goal_frequency)
    resonant_stiffness := goal_stiffness - (d*d)/4.0
    return stiffness_to_frequency(resonant_stiffness)
}

extrapolate :: proc "contextless" (
    x, v: ^f32,
    dt, halflife: f32,
    eps: f32 = 1e-5,
) {
    y := 0.69314718056 / (halflife + eps)
    x^ = x^ + (v^ / (y + eps)) * (1.0 - fast_negexp(y * dt))
    v^ = v^ * fast_negexp(y * dt)
}

double_spring_damper_exact :: proc "contextless" (
    x, v, xi, vi: ^f32,
    x_goal: f32,
    halflife, dt: f32,
) {
    simple_spring_damper_exact(xi, vi, x_goal, 0.5 * halflife, dt)
    simple_spring_damper_exact(x, v, xi^, 0.5 * halflife, dt)
}

timed_spring_damper_exact :: proc "contextless" (
    x, v, xi: ^f32,
    x_goal: f32,
    t_goal: f32,
    halflife, dt: f32,
    apprehension: f32 = 2.0,
) {
    min_time := t_goal > dt ? t_goal : dt
    v_goal := (x_goal - xi^) / min_time
    
    t_goal_future := dt + apprehension * halflife
    x_goal_future := t_goal_future < t_goal ? xi^ + v_goal * t_goal_future : x_goal
        
    simple_spring_damper_exact(x, v, x_goal_future, halflife, dt)
    
    xi^ += v_goal * dt
}

// https://theorangeduck.com/media/uploads/springs/tracking_exact.m4v
velocity_spring_damper_exact :: proc "contextless" (
    x, v, xi: ^f32,
    x_goal, v_goal: f32,
    halflife, dt: f32,
    apprehension: f32 = 2.0,
    eps: f32 = 1e-5,
) {
    x_diff := ((x_goal - xi^) > 0.0 ? 1.0 : -1.0) * v_goal
    
    t_goal_future := dt + apprehension * halflife
    x_goal_future := abs(x_goal - xi^) > t_goal_future * v_goal ? xi^ + x_diff * t_goal_future : x_goal
    
    simple_spring_damper_exact(x, v, x_goal_future, halflife, dt)
    
    xi^ = abs(x_goal - xi^) > dt * v_goal ? xi^ + x_diff * dt : x_goal
}

simple_spring_damper_exact_quat :: proc(
    x: ^rl.Vector4,
    v: ^rl.Vector3,
    x_goal: rl.Vector4,
    halflife, dt: f32,
) {
    y := halflife_to_damping(halflife) / 2.0
    
    q := quat_mul(x^, quat_inv(x_goal))
    j0 := quat_to_scaled_angle_axis(q)
    j1 := v^ + j0 * y

    eydt := fast_negexp(y*dt)

    x^ = quat_mul(quat_from_scaled_angle_axis(eydt*(j0 + j1*dt)), x_goal)
    v^ = eydt*(v^ - j1*y*dt)
}

/*
vector3_length calculates the magnitude (length) of a 3D vector using the Pythagorean theorem 
generalized to 3 dimensions: √(x² + y² + z²)
- takes a 3D vector v as input
- squares each component: v.x*v.x, v.y*v.y, v.z*v.z
- adds these squared values together
- returns the square root of the sum
*/
vector3_length :: proc "contextless" (v: rl.Vector3) -> f32 {
    return math.sqrt_f32(v.x*v.x + v.y*v.y + v.z*v.z)
}

velocity_spring_damper_exact_quat :: proc(
    x: ^rl.Vector4,
    v: ^rl.Vector3,
    xi: ^rl.Vector4,
    x_goal: rl.Vector4,
    v_goal: rl.Vector3,
    halflife, dt: f32,
    apprehension: f32 = 2.0,
    eps: f32 = 1e-5,
) {
    q_diff := quat_mul(x_goal, quat_inv(xi^))
    axis_diff := quat_to_scaled_angle_axis(q_diff)
    angle_diff := math.sqrt_f32(axis_diff.x*axis_diff.x + axis_diff.y*axis_diff.y + axis_diff.z*axis_diff.z)
    
    if angle_diff <= eps {
        axis_diff = v_goal
    } else {
        axis_diff = (axis_diff / angle_diff) * vector3_length(v_goal)
    }
    
    t_goal_future := dt + apprehension * halflife
    x_goal_future := quat_mul(quat_from_scaled_angle_axis(axis_diff * t_goal_future), xi^)
    
    simple_spring_damper_exact_quat(x, v, x_goal_future, halflife, dt)
    
    xi^ = quat_mul(quat_from_scaled_angle_axis(axis_diff * dt), xi^)
}

simple_spring_damper_exact_scale :: proc "contextless" (
    x, v: ^f32,
    x_goal: f32,
    halflife, dt: f32,
) {
    y := halflife_to_damping(halflife) / 2.0
    
    j0 := math.log2(x^ / x_goal)
    j1 := v^ + j0*y
    
    eydt := fast_negexp(y*dt)

    x^ = math.exp(eydt*(j0 + j1*dt)) * x_goal
    v^ = eydt*(v^ - j1*y*dt)
}

tracking_spring_update_exact :: proc "contextless" (
    x, v: ^f32,
    x_goal, v_goal, a_goal: f32,
    x_gain, v_gain, a_gain: f32,
    dt, gain_dt: f32,
) {
    t0 := (1.0 - v_gain) * (1.0 - x_gain)
    t1 := a_gain * (1.0 - v_gain) * (1.0 - x_gain)
    t2 := (v_gain * (1.0 - x_gain)) / gain_dt
    t3 := x_gain / (gain_dt*gain_dt)
    
    stiffness := t3
    damping := (1.0 - t0) / gain_dt
    spring_x_goal := x_goal
    spring_v_goal := (t2*v_goal + t1*a_goal) / ((1.0 - t0) / gain_dt)
    
    spring_damper_exact(
        x,
        v,
        spring_x_goal,
        spring_v_goal,
        stiffness,
        damping,
        dt,
    )
}

spring_damper_exact_stiffness_damping :: proc(
    x, v: ^f32,
    x_goal, v_goal: f32,
    stiffness, damping, dt: f32,
    eps: f32 = 1e-5,
) {
    g := x_goal
    q := v_goal
    s := stiffness
    d := damping
    c := g + (d * q) / (s + eps)
    y := d / 2.0
    
    if math.abs(s - (d * d) / 4.0) < eps { // Critically Damped
        j0 := x^ - c
        j1 := v^ + j0 * y
        
        eydt := fast_negexp(y * dt)
        
        x^ = j0 * eydt + dt * j1 * eydt + c
        v^ = -y * j0 * eydt - y * dt * j1 * eydt + j1 * eydt
    } else if s - (d * d) / 4.0 > 0.0 { // Under Damped
        w := math.sqrt(s - (d * d) / 4.0)
        j := math.sqrt(square(v^ + y * (x^ - c)) / (w * w + eps) + square(x^ - c))
        p := math.atan((v^ + (x^ - c) * y) / (-(x^ - c) * w + eps))
        
        j = j if x^ - c > 0.0 else -j
        
        eydt := fast_negexp(y * dt)
        
        x^ = j * eydt * math.cos(w * dt + p) + c
        v^ = -y * j * eydt * math.cos(w * dt + p) - w * j * eydt * math.sin(w * dt + p)
    } else if s - (d * d) / 4.0 < 0.0 { // Over Damped
        y0 := (d + math.sqrt(d * d - 4 * s)) / 2.0
        y1 := (d - math.sqrt(d * d - 4 * s)) / 2.0
        j1 := (c * y0 - x^ * y0 - v^) / (y1 - y0)
        j0 := x^ - j1 - c
        
        ey0dt := fast_negexp(y0 * dt)
        ey1dt := fast_negexp(y1 * dt)
        x^ = j0 * ey0dt + j1 * ey1dt + c
        v^ = -y0 * j0 * ey0dt - y1 * j1 * ey1dt
    }
}