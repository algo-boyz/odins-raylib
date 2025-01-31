package rlutil

// inbetween checks if a value is between values a and b
inbetween :: proc "contextless" (val, a, b: f32) -> bool {
    return a <= val && val <= b
}

// closesTo returns the value that is closest to val (a or b)
closesTo :: proc "contextless" (val, a, b: f32) -> f32 {
    diffA := abs(val - a)
    diffB := abs(val - b)
    if diffA < diffB { return a }
    return b
}