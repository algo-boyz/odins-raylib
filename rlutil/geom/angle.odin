package geom

import "core:math"

PI : f32 = math.PI;

// Return the angle from - to in float
get_angle :: proc(x1, y1, x2, y2: f32) -> f32 {
    return math.atan2_f32(y2 - y1, x2 - x1);
}

// takes radian iput! <0 is left is shorter else right turn is shorter.
// When it outputs >3 you can asume it aligns with the target(2) angle.
angle_diff :: proc(angle1, angle2: f32) -> f32 {
    // Normalize angles to the range [-PI, PI]
    angle1 := math.mod_f32(angle1 + PI, PI * 2) - PI;
    angle2 := math.mod_f32(angle2 + PI, PI * 2) - PI;

    // Calculate the difference
    diff := angle1 - angle2;

    // Normalize the difference to the range [-PI, PI]
    if diff < -PI {
        diff += PI * 2;
    } else if diff > PI {
        diff -= PI * 2;
    }

    return diff;
}
