package geom

import "core:math"
import rl "vendor:raylib"

LN2f:f32 = 0.6931471805599453

scale_differentiate_velocity_naive :: proc(next, curr, dt: f32) -> f32 {
    return (next - curr) / dt
}

scale_inv :: proc(s: f32) -> f32 {
    return 1.0 / s
}

scale_mul :: proc(s, t: f32) -> f32 {
    return s * t
}

quat_differentiate_angular_velocity :: proc(next, curr: rl.Vector4, dt: f32) -> rl.Vector3 {
    return quat_to_scaled_angle_axis(quat_abs(quat_mul(next, quat_inv(curr)))) / dt
}

scale_differentiate_velocity_natural :: proc(next, curr, dt: f32) -> f32 {
    return math.log_f32(scale_mul(next, scale_inv(curr)), 10) / dt
}

quat_integrate_angular_velocity :: proc(vel: rl.Vector3, curr: rl.Vector4, dt: f32) -> rl.Vector4 {
    return quat_mul(quat_from_scaled_angle_axis(vel * dt), curr)
}

scale_integrate_velocity_natural :: proc(vel, curr, dt: f32) -> f32 {
    return scale_mul(math.exp_f32(scale_mul(vel, dt)), curr)
}

scale_differentiate_velocity :: proc(curr, prev, dt: f32) -> f32 {
    return math.log2_f32(curr / prev) / dt
}

scale_integrate_velocity :: proc(vel, curr, dt: f32) -> f32 {
    return math.exp(vel * dt) * curr
}

scale_differentiate_velocity_alt :: proc(curr, prev, dt: f32) -> f32 {
    return (math.log_f32(curr / prev, 10) / LN2f) / dt
}

scale_integrate_velocity_alt :: proc(vel, curr, dt: f32) -> f32 {
    return math.exp_f32(LN2f * vel * dt) * curr
}

quat_abs :: proc(q: rl.Vector4) -> rl.Vector4 {
    return rl.Vector4{abs(q.x), abs(q.y), abs(q.z), abs(q.w)}
}

quat_inv :: proc(q: rl.Vector4) -> rl.Vector4 {
    len_sq := q.x*q.x + q.y*q.y + q.z*q.z + q.w*q.w
    if len_sq == 0 {
        return rl.Vector4{0, 0, 0, 1}
    }
    inv_len_sq := 1.0 / len_sq
    return rl.Vector4{-q.x * inv_len_sq, -q.y * inv_len_sq, -q.z * inv_len_sq, q.w * inv_len_sq}
}

quat_mul :: proc(a, b: rl.Vector4) -> rl.Vector4 {
    return rl.Vector4{
        a.w*b.x + a.x*b.w + a.y*b.z - a.z*b.y,
        a.w*b.y - a.x*b.z + a.y*b.w + a.z*b.x,
        a.w*b.z + a.x*b.y - a.y*b.x + a.z*b.w,
        a.w*b.w - a.x*b.x - a.y*b.y - a.z*b.z,
    }
}

quat_to_scaled_angle_axis :: proc(q: rl.Vector4) -> rl.Vector3 {
    sin_squared := q.x*q.x + q.y*q.y + q.z*q.z
    
    if sin_squared <= 0.0 {
        return rl.Vector3{0, 0, 0}
    }
    
    sin_theta := math.sqrt_f32(sin_squared)
    theta := 2.0 * math.atan2_f32(sin_theta, q.w)
    
    scale := theta / sin_theta
    return rl.Vector3{q.x * scale, q.y * scale, q.z * scale}
}

quat_from_scaled_angle_axis :: proc(v: rl.Vector3) -> rl.Vector4 {
    theta := math.sqrt_f32(v.x*v.x + v.y*v.y + v.z*v.z)
    
    if theta <= 0.0 {
        return rl.Vector4{0, 0, 0, 1}
    }
    
    half_theta := theta * 0.5
    sin_half_theta := math.sin_f32(half_theta)
    cos_half_theta := math.cos_f32(half_theta)
    
    scale := sin_half_theta / theta
    return rl.Vector4{
        v.x * scale,
        v.y * scale,
        v.z * scale,
        cos_half_theta,
    }
}