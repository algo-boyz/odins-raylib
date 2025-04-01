package fft

import "core:math"

// Complex type
Complex :: struct {
    re: f32,
    im: f32,
}

// Constants
FFT_FORWARD :: 1
FFT_INVERSE :: 0

// Complex absolute value
cmp_abs :: proc(x: Complex) -> f32 {
    return math.sqrt(x.re * x.re + x.im * x.im)
}

// Make window functions
hanning :: proc(window: []f32) {
    length := len(window)
    pi := 4.0 * math.atan(1.0)
    phase := 0.0
    delta := 2.0 * pi / f64(length)

    for i := 0; i < length; i += 1 {
        window[i] = f32(0.5 * (1.0 - math.cos(phase)))
        phase += delta
    }
}

hamming :: proc(window: []f32) {
    length := len(window)
    pi := 4.0 * math.atan(1.0)
    phase := 0.0
    delta := 2.0 * pi / f64(length)

    for i := 0; i < length; i += 1 {
        window[i] = f32(0.54 - 0.46 * math.cos(phase))
        phase += delta
    }
}

blackman :: proc(window: []f32) {
    length := len(window)
    pi := 4.0 * math.atan(1.0)
    phase := 0.0
    delta := 2.0 * pi / f64(length)

    for i := 0; i < length; i += 1 {
        window[i] = f32(0.42 - 0.5 * math.cos(phase) + 0.08 * math.cos(2 * phase))
        phase += delta
    }
}

// Apply a window to data
apply_window :: proc(data, window: []f32) {
    length := min(len(data), len(window))
    for i := 0; i < length; i += 1 {
        data[i] *= window[i]
    }
}

// Global variables (package variables in Odin)
PI: f32
TWOPI: f32
is_first := true

// Bit reverse places float array x containing N/2 complex values into bit-reversed order
bit_reverse :: proc(x: []f32) {
    N := len(x)
    j := 0
    for i := 0; i < N; i += 2 {
        if j > i {
            // Complex exchange
            rtemp, itemp := x[j], x[j+1]
            x[j], x[j+1] = x[i], x[i+1]
            x[i], x[i+1] = rtemp, itemp
        }
        m := N >> 1
        for m >= 2 && j >= m {
            j -= m
            m >>= 1
        }
        j += m
    }
}

// Complex value FFT
cfft :: proc(x: []f32, forward: bool) {
    NC := len(x) / 2  // Number of complex values
    ND := NC * 2

    if is_first {
        PI = f32(4.0 * math.atan(1.0))
        TWOPI = f32(8.0 * math.atan(1.0))
        is_first = false
    }
    bit_reverse(x[:ND])

    mmax := 2
    for mmax < ND {
        delta := mmax * 2
        theta := TWOPI / (forward ? f32(mmax) : -f32(mmax))
        wpr := -2.0 * math.pow(math.sin(0.5 * theta), 2.0)
        wpi := math.sin(theta)
        wr := f32(1.0)
        wi := f32(0.0)

        for m := 0; m < mmax; m += 2 {
            for i := m; i < ND; i += delta {
                j := i + mmax
                rtemp := wr * x[j] - wi * x[j+1]
                itemp := wr * x[j+1] + wi * x[j]
                
                // Safety check (adapted from original code)
                if j >= len(x) - 1 || i >= len(x) - 1 {
                    continue
                }
                x[j] = x[i] - rtemp
                x[j+1] = x[i+1] - itemp
                x[i] += rtemp
                x[i+1] += itemp
            }
            rtemp := wr
            wr = rtemp * wpr - wi * wpi + wr
            wi = wi * wpr + rtemp * wpi + wi
        }
        mmax = delta
    }
    // Scale output
    scale := forward ? f32(1.0 / f32(ND)) : f32(2.0)
    for i := 0; i < ND; i += 1 {
        x[i] *= scale
    }
}

// Real value FFT
rfft :: proc(x: []f32, forward: bool) {
    N := len(x) / 2  // Assuming x contains 2*N real values

    if is_first {
        PI = f32(4.0 * math.atan(1.0))
        TWOPI = f32(8.0 * math.atan(1.0))
        is_first = false
    }
    theta := PI / f32(N)
    wr := f32(1.0)
    wi := f32(0.0)
    c1 := f32(0.5)
    c2: f32
    xr, xi: f32

    if forward {
        c2 = -0.5
        cfft(x, forward)
        xr = x[0]
        xi = x[1]
    } else {
        c2 = 0.5
        theta = -theta
        xr = x[1]
        xi = 0.0
        x[1] = 0.0
    }
    wpr := -2.0 * math.pow(math.sin(0.5 * theta), 2.0)
    wpi := math.sin(theta)
    N2p1 := (N << 1) + 1

    for i := 0; i <= N >> 1; i += 1 {
        i1 := i << 1
        i2 := i1 + 1
        i3 := N2p1 - i2
        i4 := i3 + 1
        if i == 0 {
            h1r := c1 * (x[i1] + xr)
            h1i := c1 * (x[i2] - xi)
            h2r := -c2 * (x[i2] + xi)
            h2i := c2 * (x[i1] - xr)
            
            x[i1] = h1r + wr * h2r - wi * h2i
            x[i2] = h1i + wr * h2i + wi * h2r
            xr = h1r - wr * h2r + wi * h2i
            xi = -h1i + wr * h2i + wi * h2r
        } else {
            h1r := c1 * (x[i1] + x[i3])
            h1i := c1 * (x[i2] - x[i4])
            h2r := -c2 * (x[i2] + x[i4])
            h2i := c2 * (x[i1] - x[i3])
            
            x[i1] = h1r + wr * h2r - wi * h2i
            x[i2] = h1i + wr * h2i + wi * h2r
            x[i3] = h1r - wr * h2r + wi * h2i
            x[i4] = -h1i + wr * h2i + wi * h2r
        }
        temp := wr
        wr = temp * wpr - wi * wpi + wr
        wi = wi * wpr + temp * wpi + wi
    }
    if forward {
        x[1] = xr
    } else {
        cfft(x, forward)
    }
}