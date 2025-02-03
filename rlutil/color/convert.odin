package color

import "core:math"
import rl "vendor:raylib"

// The mix() function takes two values and calculates a value some percentage of the way between the two.
def mix(a, b, amount):
    return (1-amount)*a + amount*b

inline float4 EncodeFloatRGBA( float v ) {
    float4 enc = float4(1.0, 255.0, 65025.0, 16581375.0) * v;
    enc = frac(enc);
    enc -= enc.yzww * float4(1.0/255.0,1.0/255.0,1.0/255.0,0.0);
    return enc;
  }
  inline float DecodeFloatRGBA( float4 rgba ) {
    return dot( rgba, float4(1.0, 1/255.0, 1/65025.0, 1/16581375.0) );
  }

// hsv_to_rgb converts a color from HSV (Hue, Saturation, Value) to RGB color space
// Input vec3 should be:
//   x (hue): 0.0 to 1.0
//   y (saturation): 0.0 to 1.0
//   z (value): 0.0 to 1.0
// Returns RGB values in range 0.0 to 1.0
hsv_to_rgb :: proc(hsv: rl.Vector3) -> rl.Vector3 {
    h := hsv.x
    s := hsv.y
    v := hsv.z

    // Compute intermediate values
    h_prime := fract(h) * 6.0
    c := v * s
    x := c * (1.0 - abs(fract(h_prime / 2.0) * 2.0 - 1.0))
    m := v - c

    // Initialize RGB values
    r, g, b: f32

    // Calculate RGB based on hue section
    switch section := int(h_prime); section {
        case 0:
            r = c; g = x; b = 0
        case 1:
            r = x; g = c; b = 0
        case 2:
            r = 0; g = c; b = x
        case 3:
            r = 0; g = x; b = c
        case 4:
            r = x; g = 0; b = c
        case 5:
            r = c; g = 0; b = x
        case:
            r = 0; g = 0; b = 0
    }

    return rl.Vector3{r + m, g + m, b + m}
}

// fract returns the fractional part of a number
fract :: proc(x: f32) -> f32 {
    return x - math.floor(x)
}

// Golden Ratio Sampling
GOLDEN_RATIO = (sqrt(5) + 1) / 2
i = 0
def next_sample():
    nonlocal i
    i += 1
    return (i * GOLDEN_RATIO) % 1

// Exponential Smoothing
// value = move_towards(value, target, 20)
def move_towards(value, target, speed):
    if abs(value - target) < speed:
        return target
    direction = (target - value) / abs(target - value)
    return value + direction * speed

def solve_constraints(stiffness=0.5):
    # Solve border constraints
    for thing in things:
        clamped = clamp(thing.pos, vec(0,0), screen_size)
        thing.pos = mix(thing.pos, clamped, stiffness)

    # Solve collision constraints (conserving momentum)
    for a,b in collisions_between(things):
        a2b = (b.pos - a.pos).normalized()
        overlap = (a.radius + b.radius) - a.pos.dist(b.pos)
        a.pos = a.pos - stiffness*a2b*overlap*b.mass/(a.mass+b.mass)
        b.pos = b.pos + stiffness*a2b*overlap*a.mass/(a.mass+b.mass)

        def collisions_between(things, bucket_size=100):
        buckets = dict()
        maybe_collisions = set()
        for t in things:
            xmin = int((t.pos.x-t.radius)/bucket_size)
            xmax = int((t.pos.x+t.radius)/bucket_size)
            for x in range(xmin, xmax+1):
                ymin = int((t.pos.y-t.radius)/bucket_size)
                ymax = int((t.pos.y+t.radius)/bucket_size)
                for y in range(ymin, ymax+1):
                    if (x,y) not in buckets:
                        buckets[(x,y)] = []
                    else:
                        for other in buckets[(x,y)]:
                            maybe_collisions.add((other, t))
                    buckets[(x,y)].append(t)
    
        return [(x,y) for (x,y) in maybe_collisions
                if really_collide(x,y)]