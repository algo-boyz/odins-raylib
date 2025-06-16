package moog

import "core:math"
import "core:fmt"

// Thermal voltage (26 miliwatts at room temp)
VT :: 0.312
PI :: 3.14159265358979323846264338327950288

LadderFilter :: struct {
    sample_rate : int,
    cutoff      : f64,
    resonance   : f64,
    drive       : f64,
    x           : f64,
    g           : f64,
    V           : [4]f64,
    dV          : [4]f64,
    tV          : [4]f64,
}

// TODO: What should default sample rate be? 44100? 48000?
// TODO: What should default cutoff be?
ladder_filter_create :: proc (sample_rate : int = 26040, cutoff : f64 = 1500,
                                  resonance : f64 = 0.1, drive : f64 = 1.0) -> ^LadderFilter {
    f := new(LadderFilter)
    f.sample_rate = sample_rate
    // f.cutoff   = cutoff
    f.resonance   = resonance
    f.drive       = drive
    f.x           = 0
    f.g           = 0
    f.V           = { 0, 0, 0, 0 }
    f.dV          = { 0, 0, 0, 0 }
    f.tV          = { 0, 0, 0, 0 }

    set_cutoff(f, cutoff)
    return f
}

ladder_filter_destroy :: proc (moog : ^LadderFilter) {
    free(moog)
}

// Should likely put limits on this (ie 4 > res > 0)
set_resonance :: proc (moog : ^LadderFilter, res : f64) {
    moog.resonance = res
}

get_resonance :: proc (moog : ^LadderFilter) -> f64 {
    return moog.resonance
}

set_cutoff :: proc (moog : ^LadderFilter, cutoff : f64) {
    moog.cutoff = cutoff
    moog.x = (PI * cutoff) / f64(moog.sample_rate)
    moog.g = 4.0 * PI * VT * cutoff * (1.0 - moog.x) / (1.0 + moog.x)
}

get_cutoff :: proc (moog : ^LadderFilter) -> f64 {
    return moog.cutoff
}

process :: proc (moog : ^LadderFilter, samples :  []f64) -> []f64 {
    samples := samples
    if moog == nil {
        fmt.printf("process: moog is nil\n")
        return samples
    }
    sample_rate_f64 := f64(moog.sample_rate)
    dV0, dV1, dV2, dV3: f64

    for s, i in samples {
        dV0 = -moog.g * (math.tanh((moog.drive * samples[i] + moog.resonance * moog.V[3]) / (2.0 * VT)) + moog.tV[0])
        moog.V[0] += (dV0 + moog.dV[0]) / (2.0 * sample_rate_f64)
        moog.dV[0] = dV0
        moog.tV[0] = math.tanh(moog.V[0] / (2.0 * VT))
        
        dV1 = moog.g * (moog.tV[0] - moog.tV[1])
        moog.V[1] += (dV1 + moog.dV[1]) / (2.0 * sample_rate_f64)
        moog.dV[1] = dV1
        moog.tV[1] = math.tanh(moog.V[1] / (2.0 * VT))
        
        dV2 = moog.g * (moog.tV[1] - moog.tV[2])
        moog.V[2] += (dV2 + moog.dV[2]) / (2.0 * sample_rate_f64)
        moog.dV[2] = dV2
        moog.tV[2] = math.tanh(moog.V[2] / (2.0 * VT))
        
        dV3 = moog.g * (moog.tV[2] - moog.tV[3])
        moog.V[3] += (dV3 + moog.dV[3]) / (2.0 * sample_rate_f64)
        moog.dV[3] = dV3
        moog.tV[3] = math.tanh(moog.V[3] / (2.0 * VT))
        
        samples[i] = moog.V[3]
    }
    return samples
}