package noise

import "core:math"
import "core:math/rand"
import "core:math/noise"
import "core:slice"

// Perlin Noise structure
Perlin :: struct {
    p: [512]int, // Permutation vector (doubled)
}

// Initialize with the reference values for the permutation vector
// This is a direct translation from the reference Java implementation
// Original Java implementation is copyright 2002 Ken Perlin
perlin_noise_init :: proc() -> Perlin {
    noise := Perlin{}
    
    // Initialize the permutation vector with the reference values
    reference_p := [256]int{
        151,160,137,91,90,15,131,13,201,95,96,53,194,233,7,225,140,36,103,30,69,142,
        8,99,37,240,21,10,23,190,6,148,247,120,234,75,0,26,197,62,94,252,219,203,117,
        35,11,32,57,177,33,88,237,149,56,87,174,20,125,136,171,168,68,175,74,165,71,
        134,139,48,27,166,77,146,158,231,83,111,229,122,60,211,133,230,220,105,92,41,
        55,46,245,40,244,102,143,54,65,25,63,161,1,216,80,73,209,76,132,187,208,89,
        18,169,200,196,135,130,116,188,159,86,164,100,109,198,173,186,3,64,52,217,226,
        250,124,123,5,202,38,147,118,126,255,82,85,212,207,206,59,227,47,16,58,17,182,
        189,28,42,223,183,170,213,119,248,152,2,44,154,163,70,221,153,101,155,167,43,
        172,9,129,22,39,253,19,98,108,110,79,113,224,232,178,185,112,104,218,246,97,
        228,251,34,242,193,238,210,144,12,191,179,162,241,81,51,145,235,249,14,239,
        107,49,192,214,31,181,199,106,157,184,84,204,176,115,121,50,45,127,4,150,254,
        138,236,205,93,222,114,67,29,24,72,243,141,128,195,78,66,215,61,156,180
    }
    
    // Copy reference values to first half
    for i in 0..<256 {
        noise.p[i] = reference_p[i]
    }
    
    // Duplicate the permutation vector
    for i in 0..<256 {
        noise.p[i + 256] = reference_p[i]
    }
    
    return noise
}

// Generate a new permutation vector based on the seed
perlin_noise_init_with_seed :: proc(seed: u64) -> Perlin {
    noise := Perlin{}
    
    // Create a slice to work with
    temp_p := make([]int, 256, context.temp_allocator)
    defer delete(temp_p, context.temp_allocator)
    
    // Fill with values from 0 to 255
    for i in 0..<256 {
        temp_p[i] = i
    }
    
    // Initialize random state with seed
    seeder := rand.create(seed)
    // Shuffle using Fisher-Yates algorithm
    for i := len(temp_p) - 1; i > 0; i -= 1 {
        j := rand.int_max(i + 1, rand.default_random_generator(&seeder))
        temp_p[i], temp_p[j] = temp_p[j], temp_p[i]
    }
    
    // Copy shuffled values to first half
    for i in 0..<256 {
        noise.p[i] = temp_p[i]
    }
    
    // Duplicate the permutation vector
    for i in 0..<256 {
        noise.p[i + 256] = temp_p[i]
    }
    
    return noise
}

// Core 1D Perlin noise function
perlin_noise_1d :: proc(noise: ^Perlin, x: f64) -> f64 {
    // Find the unit interval that contains the point
    X := int(math.floor(x)) & 255
    
    // Find relative x of point in interval
    rel_x := x - math.floor(x)
    
    // Compute fade curve for x
    u := fade(rel_x)
    
    // Hash coordinates of the 2 interval corners
    A := noise.p[X]
    B := noise.p[X + 1]
    
    // Blend results from 2 corners of interval
    res := lerp(u, grad_1d(A, rel_x), grad_1d(B, rel_x - 1.0))
    
    return (res + 1.0) / 2.0
}

// Get 1D noise with multiple octaves
get_noise_1d_with_octaves :: proc(noise: ^Perlin, x: f64, octaves: int) -> f64 {
    result := 0.0
    amp := 1.0
    freq := 0.5
    max_value := 0.0
    
    for i in 0..<octaves {
        result += perlin_noise_1d(noise, x * freq) * amp
        max_value += amp
        amp /= 2.0
        freq *= 2.0
    }
    
    return result / max_value
}

// 1D Gradient function
grad_1d :: proc(hash: int, x: f64) -> f64 {
    return x if (hash & 1) == 0 else -x
}

// Core 2D Perlin noise function
perlin_noise_2d :: proc(noise: ^Perlin, x, y: f64) -> f64 {
    // Find the unit square that contains the point
    X := int(math.floor(x)) & 255
    Y := int(math.floor(y)) & 255
    
    // Find relative x, y of point in square
    rel_x := x - math.floor(x)
    rel_y := y - math.floor(y)
    
    // Compute fade curves for each of x, y
    u := fade(rel_x)
    v := fade(rel_y)
    
    // Hash coordinates of the 4 square corners
    A := noise.p[X] + Y
    B := noise.p[X + 1] + Y
    
    // Blend results from 4 corners of square
    res := lerp(v,
        lerp(u, grad_2d(noise.p[A], rel_x, rel_y), grad_2d(noise.p[B], rel_x - 1, rel_y)),
        lerp(u, grad_2d(noise.p[A + 1], rel_x, rel_y - 1), grad_2d(noise.p[B + 1], rel_x - 1, rel_y - 1)))
    
    return (res + 1.0) / 2.0
}

// Get 2D noise with multiple octaves
get_noise_2d_with_octaves :: proc(noise: ^Perlin, x, y: f64, octaves: int) -> f64 {
    result := 0.0
    amp := 1.0
    freq := 0.5
    max_value := 0.0
    
    for i in 0..<octaves {
        result += perlin_noise_2d(noise, x * freq, y * freq) * amp
        max_value += amp
        amp /= 2.0
        freq *= 2.0
    }
    
    return result / max_value
}

// 2D Gradient function
grad_2d :: proc(hash: int, x, y: f64) -> f64 {
    h := hash & 7
    u := x if h < 4 else y
    v := y if h < 4 else x
    
    u_sign := u if (h & 1) == 0 else -u
    v_sign := v if (h & 2) == 0 else -v
    
    return u_sign + v_sign
}

// Core 3D Perlin noise function
perlin_noise_3d :: proc(noise: ^Perlin, x, y, z: f64) -> f64 {
    // Find the unit cube that contains the point
    X := int(math.floor(x)) & 255
    Y := int(math.floor(y)) & 255
    Z := int(math.floor(z)) & 255
    
    // Find relative x, y, z of point in cube
    rel_x := x - math.floor(x)
    rel_y := y - math.floor(y)
    rel_z := z - math.floor(z)
    
    // Compute fade curves for each of x, y, z
    u := fade(rel_x)
    v := fade(rel_y)
    w := fade(rel_z)
    
    // Hash coordinates of the 8 cube corners
    A := noise.p[X] + Y
    AA := noise.p[A] + Z
    AB := noise.p[A + 1] + Z
    B := noise.p[X + 1] + Y
    BA := noise.p[B] + Z
    BB := noise.p[B + 1] + Z
    
    // Add blended results from 8 corners of cube
    res := lerp(w, 
        lerp(v, 
            lerp(u, 
                grad_3d(noise.p[AA], rel_x, rel_y, rel_z), 
                grad_3d(noise.p[BA], rel_x - 1, rel_y, rel_z)), 
            lerp(u, 
                grad_3d(noise.p[AB], rel_x, rel_y - 1, rel_z), 
                grad_3d(noise.p[BB], rel_x - 1, rel_y - 1, rel_z))),
        lerp(v, 
            lerp(u, 
                grad_3d(noise.p[AA + 1], rel_x, rel_y, rel_z - 1), 
                grad_3d(noise.p[BA + 1], rel_x - 1, rel_y, rel_z - 1)), 
            lerp(u, 
                grad_3d(noise.p[AB + 1], rel_x, rel_y - 1, rel_z - 1),
                grad_3d(noise.p[BB + 1], rel_x - 1, rel_y - 1, rel_z - 1))))
    
    return (res + 1.0) / 2.0
}

// Get 3D noise with multiple octaves
get_noise_3d_with_octaves :: proc(noise: ^Perlin, x, y, z: f64, octaves: int) -> f64 {
    result := 0.0
    amp := 1.0
    freq := 0.5
    max_value := 0.0
    
    for i in 0..<octaves {
        result += perlin_noise_3d(noise, x * freq, y * freq, z * freq) * amp
        max_value += amp
        amp /= 2.0
        freq *= 2.0
    }
    
    return result / max_value
}

// 3D Gradient function
grad_3d :: proc(hash: int, x, y, z: f64) -> f64 {
    h := hash & 15
    // Convert lower 4 bits of hash into 12 gradient directions
    u := x if h < 8 else y
    v: f64
    if h < 4 {
        v = y
    } else if h == 12 || h == 14 {
        v = x
    } else {
        v = z
    }
    
    u_sign := u if (h & 1) == 0 else -u
    v_sign := v if (h & 2) == 0 else -v
    
    return u_sign + v_sign
}

// Generate a 2D graph by calculating height with Perlin noise
// for every x, y coordinate on a plane
generate_2d_graph :: proc(noise: ^Perlin, size: int, octaves: int = 6) -> [][]f64 {
    graph := make([][]f64, size)
    for i in 0..<size {
        graph[i] = make([]f64, size)
    }
    
    for x in 0..<size {
        for y in 0..<size {
            graph[x][y] = get_noise_2d_with_octaves(noise, 
                f64(x) / f64(size), 
                f64(y) / f64(size), 
                octaves)
        }
    }
    
    return graph
}

// Generate a 3D graph by calculating height with Perlin noise
// for every x, y coordinate on a plane
generate_3d_graph :: proc(noise: ^Perlin, size: int, octaves: int = 6) -> [][]f64 {
    graph := make([][]f64, size)
    for i in 0..<size {
        graph[i] = make([]f64, size)
    }
    
    for x in 0..<size {
        for y in 0..<size {
            graph[x][y] = get_noise_3d_with_octaves(noise, 
                f64(x) / f64(size), 
                f64(y) / f64(size), 
                0.0, 
                octaves)
        }
    }
    
    return graph
}

// Smooth the graph using a box filter
smooth_graph :: proc(graph: [][]f64, factor: int) -> [][]f64 {
    size := len(graph)
    smoothed_graph := make([][]f64, size)
    for i in 0..<size {
        smoothed_graph[i] = make([]f64, size)
    }
    
    for x in factor..<(size - factor) {
        for y in factor..<(size - factor) {
            sum := 0.0
            count := 0
            
            // Average the surrounding cells
            for dx in -factor..=factor {
                for dy in -factor..=factor {
                    sum += graph[x + dx][y + dy]
                    count += 1
                }
            }
            smoothed_graph[x][y] = sum / f64(count)
        }
    }
    
    return smoothed_graph
}

// Fade function for smooth interpolation
fade :: proc(t: f64) -> f64 {
    return t * t * t * (t * (t * 6 - 15) + 10)
}

// Linear interpolation
lerp :: proc(t, a, b: f64) -> f64 {
    return a + t * (b - a)
}

// Helper procedure to free a 2D graph
free_graph :: proc(graph: [][]f64) {
    for row in graph {
        delete(row)
    }
    delete(graph)
}

// map range function to map a value from one range to another
map_range :: proc(value, in_min, in_max, out_min, out_max: f64) -> f64 {
    t := (value - in_min) / (in_max - in_min)
    return out_min + t * (out_max - out_min)
}

// Convenience procedure overloads for different dimensions
perlin_noise :: proc{perlin_noise_1d, perlin_noise_2d, perlin_noise_3d}
get_noise_with_octaves :: proc{get_noise_1d_with_octaves, get_noise_2d_with_octaves, get_noise_3d_with_octaves}

/*
    simplex noise, might be preferable over perlin noise
    due to the lower computational overhead
*/
simplex_noise :: proc (x, y: f32, octaves: int, persistence: f32, lacunarity: f32, seed: i64) -> f32
{
    freq: f32 = 1
    amp: f32 = 1
    max: f32 = 1
    total: f32 = noise.noise_2d(seed, {f64(x), f64(y)})
    for i := 1; i < octaves; i += 1
    {
        freq *= lacunarity
        amp *= persistence
        max += amp
        total += noise.noise_2d(seed, {f64(x * freq), f64(y * freq)}) * amp
    }
    return (1 + total / max) / 2
}