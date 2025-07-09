package noise

import "core:math"
import "core:math/linalg"
import "core:math/noise"

/*
    Simple FBM using value_noise_3d as basis
*/
fbm_simple :: proc(pos: [3]f32, octaves: int, lacunarity: f32, init_gain: f32, gain: f32) -> f32 {
    p := pos
    H := init_gain
    t: f32 = 0
    
    for i in 0..<octaves {
        t += value_noise_3d(p) * H
        p *= lacunarity
        H *= gain
    }
    
    return t
}

/*
    Tiled FBM using value noise with value_noise_3d as basis
*/
fbm_simple_tiled :: proc(pos: [3]f32, octaves: int, lacunarity: f32, init_gain: f32, gain: f32) -> f32 {
    p := pos
    H := init_gain
    L := lacunarity
    t: f32 = 0
    
    for i in 0..<octaves {
        t += value_noise_3d(p) * H
        L *= lacunarity
        H *= gain
        // Note: In the tiled version, we could modify p differently for tiling
        // but the original macro doesn't show specific tiling implementation
        p *= L
    }
    
    return t
}

/*
    Hash function for 3D vectors
    Ported from iq's noise function: https://www.shadertoy.com/view/ldl3Dl
*/
hash_3d :: proc(x: [3]f32) -> [3]f32 {
    xx := [3]f32{
        x.x * 127.1 + x.y * 311.7 + x.z * 74.7,
        x.x * 269.5 + x.y * 183.3 + x.z * 246.1,
        x.x * 113.5 + x.y * 271.9 + x.z * 124.6,
    }
    
    return {
        fract(math.sin(xx.x) * 43758.5453123),
        fract(math.sin(xx.y) * 43758.5453123),
        fract(math.sin(xx.z) * 43758.5453123),
    }
}

/*
    Worley/Cellular noise function
    Returns closest distance, second closest distance, and cell id
    Ported from iq's noise function: https://www.shadertoy.com/view/ldl3Dl
*/
worley_noise :: proc(pos: [3]f32, domain_repeat: f32) -> [3]f32 {
    x := pos * domain_repeat
    
                    p := [3]f32{math.floor(x.x), math.floor(x.y), math.floor(x.z)}
    f := [3]f32{fract(x.x), fract(x.y), fract(x.z)}
    
    id: f32 = 0.0
    res := [2]f32{100.0, 100.0}
    
    for k in -1..=1 {
        for j in -1..=1 {
            for i in -1..=1 {
                b := [3]f32{f32(i), f32(j), f32(k)}
                mod_p := [3]f32{
                    math.mod(p.x + b.x, domain_repeat),
                    math.mod(p.y + b.y, domain_repeat),
                    math.mod(p.z + b.z, domain_repeat),
                }
                r := b - f + hash_3d(mod_p)
                d := r.x*r.x + r.y*r.y + r.z*r.z
                
                if d < res.x {
                    id = (p.x + b.x) + (p.y + b.y) * 57.0 + (p.z + b.z) * 113.0
                    res = {d, res.x}
                } else if d < res.y {
                    res.y = d
                }
            }
        }
    }
    
    return {math.sqrt(res.x), math.sqrt(res.y), math.abs(id)}
}

/*
    Simple hash function for float values
    Ported from iq's noise function: https://www.shadertoy.com/view/4sfGzS
*/
hash_1d :: proc(n: f32) -> f32 {
    return fract(math.sin(n) * 753.5453123)
}

/*
    3D value noise function
    Ported from iq's noise function: https://www.shadertoy.com/view/4sfGzS
*/
value_noise_3d :: proc(x: [3]f32) -> f32 {
    p := [3]f32{math.floor(x.x), math.floor(x.y), math.floor(x.z)}
    f := [3]f32{fract(x.x), fract(x.y), fract(x.z)}
    
    // Smooth interpolation
    f = f * f * (3.0 - 2.0 * f)
    
    n := p.x + p.y * 157.0 + 113.0 * p.z
    
    // Trilinear interpolation
    return linalg.lerp(
        linalg.lerp(
            linalg.lerp(hash_1d(n + 0.0),   hash_1d(n + 1.0),   f.x),
            linalg.lerp(hash_1d(n + 157.0), hash_1d(n + 158.0), f.x),
            f.y
        ),
        linalg.lerp(
            linalg.lerp(hash_1d(n + 113.0), hash_1d(n + 114.0), f.x),
            linalg.lerp(hash_1d(n + 270.0), hash_1d(n + 271.0), f.x),
            f.y
        ),
        f.z
    )
}

/*
    Fractional Brownian Motion using value noise
    Combines multiple octaves of value noise for more complex patterns
*/
fbm_value_noise :: proc(pos: [3]f32, octaves: int, persistence: f32, lacunarity: f32) -> f32 {
    freq: f32 = 1.0
    amp: f32 = 1.0
    max: f32 = 1.0
    total: f32 = value_noise_3d(pos)
    
    for i in 1..<octaves {
        freq *= lacunarity
        amp *= persistence
        max += amp
        total += value_noise_3d(pos * freq) * amp
    }
    
    return total / max
}

/*
    Fractional Brownian Motion using worley noise
    Uses the closest distance from worley noise for fractal generation
*/
fbm_worley_noise :: proc(pos: [3]f32, octaves: int, persistence: f32, lacunarity: f32, domain_repeat: f32) -> f32 {
    freq: f32 = 1.0
    amp: f32 = 1.0
    max: f32 = 1.0
    worley_result := worley_noise(pos, domain_repeat)
    total: f32 = worley_result.x // Use closest distance
    
    for i in 1..<octaves {
        freq *= lacunarity
        amp *= persistence
        max += amp
        worley_result = worley_noise(pos * freq, domain_repeat * freq)
        total += worley_result.x * amp
    }
    
    return total / max
}

// compute the fractional part of a float
fract :: proc(x: f32) -> f32 {
    return x - math.floor(x)
}