package ease

// Adapted from functions here: https://github.com/warrenm/AHEasing/blob/master/AHEasing/easing.c
// For previews go here: https://easings.net/

import "core:math"

Mode :: enum {
    linear = 0,
    quad_in,
    quad_out,
    quad_in_out,
    cube_in,
    cube_out,
    cube_in_out,
    quart_in,
    quart_out,
    quart_in_out,
    quint_in,
    quint_out,
    quint_in_out,
    sine_in,
    sine_out,
    sine_in_out,
    circ_in,
    circ_out,
    circ_in_out,
    exp_in,
    exp_out,
    exp_in_out,
    elastic_in,
    elastic_out,
    elastic_in_out,
    back_in,
    back_out,
    back_in_out,
    bounce_in,
    bounce_out,
    bounce_in_out,
}

linear :: proc(t: f32) -> f32 {
    return t
}

quad_in :: proc(t: f32) -> f32 {
    return t * t
}

quad_out :: proc(t: f32) -> f32 {
    return -(t * (t - 2))
}

quad_in_out :: proc(t: f32) -> f32 {
    if t < 0.5 {
        return 2 * t * t
    }
    return (-2 * t * t) + (4 * t) - 1
}

cube_in :: proc(t: f32) -> f32 {
    return t * t * t
}

cube_out :: proc(t: f32) -> f32 {
    f: f32 = (t - 1)
    return f * f * f + 1
}

cube_in_out :: proc(t: f32) -> f32 {
    if t < 0.5 {
        return 4 * t * t * t
    }
    f: f32 = (2 * t) - 2
    return 0.5 * f * f * f + 1
}

quart_in :: proc(t: f32) -> f32 {
    return t * t * t * t
}

quart_out :: proc(t: f32) -> f32 {
    f: f32 = (t - 1)
    return f * f * f * (1 - t) + 1
}

quart_in_out :: proc(t: f32) -> f32 {
    if t < 0.5 {
        return 8 * t * t * t * t
    }
    f: f32 = (t - 1)
    return -8 * f * f * f * f + 1
}

quint_in :: proc(t: f32) -> f32 {
    return t * t * t * t * t
}

quint_out :: proc(t: f32) -> f32 {
    f: f32 = (t - 1)
    return f * f * f * f * f + 1
}

quint_in_out :: proc(t: f32) -> f32 {
    if t < 0.5 {
        return 16 * t * t * t * t * t
    }
    f: f32 = ((2 * t) - 2)
    return 0.5 * f * f * f * f * f + 1
}

sine_in :: proc(t: f32) -> f32 {
    return math.sin((t - 1.0) * math.PI * 0.5) + 1.0
}

sine_out :: proc(t: f32) -> f32 {
    return math.sin(t * (math.PI * 0.5))
}

sine_in_out :: proc(t: f32) -> f32 {
    return 0.5 * (1 - math.cos(t * math.PI))
}

circ_in :: proc(t: f32) -> f32 {
    return 1 - math.sqrt(1 - (t * t))
}

circ_out :: proc(t: f32) -> f32 {
    return math.sqrt((2 - t) * t)
}

circ_in_out :: proc(t: f32) -> f32 {
    if t < 0.5 {
        return 0.5 * (1 - math.sqrt(1 - 4 * (t * t)))
    }
    return 0.5 * (math.sqrt(-((2 * t) - 3) * ((2 * t) - 1)) + 1)
}

exp_in :: proc(t: f32) -> f32 {
    return (t == 0) ? 0 : math.pow(2, 10 * (t - 1))
}

exp_out :: proc(t: f32) -> f32 {
    return (t == 1) ? 1 : 1 - math.pow(2, -10 * t)
}

exp_in_out :: proc(t: f32) -> f32 {
    if t == 0 || t == 1 {
        return t
    }
    if t < 0.5 {
        return 0.5 * math.pow(2, (20 * t) - 10)
    }
    return -0.5 * math.pow(2, (-20 * t) + 10) + 1
}

elastic_in :: proc(t: f32) -> f32 {
    return math.sin(13 * (math.PI * 0.5) * t) * math.pow(2, 10 * (t - 1))
}

elastic_out :: proc(t: f32) -> f32 {
    return math.sin(-13 * (math.PI * 0.5) * (t + 1)) * math.pow(2, -10 * t) + 1
}

elastic_in_out :: proc(t: f32) -> f32 {
    if t < 0.5 {
        return 0.5 * math.sin(13 * (math.PI * 0.5) * (2 * t)) * math.pow(2, 10 * ((2 * t) - 1))
    }
    return 0.5 * (math.sin(-13 * (math.PI * 0.5) * ((2 * t - 1) + 1)) * math.pow(2, -10 * (2 * t - 1)) + 2)
}

back_in :: proc(t: f32) -> f32 {
    return t * t * t - t * math.sin(t * math.PI)
}

back_out :: proc(t: f32) -> f32 {
    f: f32 = (1 - t)
    return 1 - (f * f * f - f * math.sin(f * math.PI))
}

back_in_out :: proc(t: f32) -> f32 {
    if (t < 0.5) {
        f: f32 = 2 * t
        return 0.5 * (f * f * f - f * math.sin(f * math.PI))
    } else {
        f: f32 = (1 - (2 * t - 1))
        return 0.5 * (1 - (f * f * f - f * math.sin(f * math.PI))) + 0.5
    }
}

bounce_out :: proc(t: f32) -> f32 {
    if t < 4 / 11.0 {
        return (121 * t * t) / 16.0
    }
    if t < 8 / 11.0 {
        return (363 / 40.0 * t * t) - (99 / 10.0 * t) + 17 / 5.0
    }
    if t < 9 / 10.0 {
        return (4356 / 361.0 * t * t) - (35442 / 1805.0 * t) + 16061 / 1805.0
    }
    return (54 / 5.0 * t * t) - (513 / 25.0 * t) + 268 / 25.0
}

bounce_in :: proc(t: f32) -> f32 {
    return 1 - bounce_out(1 - t)
}

bounce_in_out :: proc(t: f32) -> f32 {
    if t < 0.5 {
        return 0.5 * bounce_in(t * 2)
    }
    return 0.5 * bounce_out(t * 2 - 1) + 0.5
}

mode_ease :: proc(e: Mode, t: f32) -> f32 {
    switch (e) {
    case .linear:
        return linear(t)
    case .cube_in:
        return cube_in(t)
    case .cube_out:
        return cube_out(t)
    case .cube_in_out:
        return cube_in_out(t)
    case .quad_in:
        return quad_in(t)
    case .quad_out:
        return quad_out(t)
    case .quad_in_out:
        return quad_in_out(t)
    case .quart_in:
        return quart_in(t)
    case .quart_out:
        return quart_out(t)
    case .quart_in_out:
        return quart_in_out(t)
    case .quint_in:
        return quint_in(t)
    case .quint_out:
        return quint_out(t)
    case .quint_in_out:
        return quint_in_out(t)
    case .sine_in:
        return sine_in(t)
    case .sine_out:
        return sine_out(t)
    case .sine_in_out:
        return sine_in_out(t)
    case .circ_in:
        return circ_in(t)
    case .circ_out:
        return circ_out(t)
    case .circ_in_out:
        return circ_in_out(t)
    case .exp_in:
        return exp_in(t)
    case .exp_out:
        return exp_out(t)
    case .exp_in_out:
        return exp_in_out(t)
    case .elastic_in:
        return elastic_in(t)
    case .elastic_out:
        return elastic_out(t)
    case .elastic_in_out:
        return elastic_in_out(t)
    case .back_in:
        return back_in(t)
    case .back_out:
        return back_out(t)
    case .back_in_out:
        return back_in_out(t)
    case .bounce_in:
        return bounce_in(t)
    case .bounce_out:
        return bounce_out(t)
    case .bounce_in_out:
        return bounce_in_out(t)
    }
    return t
}