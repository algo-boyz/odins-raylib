package others

import "vendor:raylib"

FONT_SIZE :: 20

D_STEP:      f32 : 20
D_STEP_FINE: f32 : 2
D_MIN:       f32 : 1
D_MAX:       f32 : 10000

EasingTypes :: enum {
    LINEAR_NONE,
    LINEAR_IN,
    LINEAR_OUT,
    LINEAR_IN_OUT,
    SINE_IN,
    SINE_OUT,
    SINE_IN_OUT,
    CIRC_IN,
    CIRC_OUT,
    CIRC_IN_OUT,
    CUBIC_IN,
    CUBIC_OUT,
    CUBIC_IN_OUT,
    QUAD_IN,
    QUAD_OUT,
    QUAD_IN_OUT,
    EXPO_IN,
    EXPO_OUT,
    EXPO_IN_OUT,
    BACK_IN,
    BACK_OUT,
    BACK_IN_OUT,
    BOUNCE_OUT,
    BOUNCE_IN,
    BOUNCE_IN_OUT,
    ELASTIC_IN,
    ELASTIC_OUT,
    ELASTIC_IN_OUT,
    NONE,
}

Easings: [EasingTypes]struct {
    name: cstring,
    func: proc(f32, f32, f32, f32) -> f32,
}

EasingsInit :: proc() {
    using raylib

    Easings[.LINEAR_NONE]    = {"EaseLinearNone",   EaseLinearNone}
    Easings[.LINEAR_IN]      = {"EaseLinearIn",     EaseLinearIn}
    Easings[.LINEAR_OUT]     = {"EaseLinearOut",    EaseLinearOut}
    Easings[.LINEAR_IN_OUT]  = {"EaseLinearInOut",  EaseLinearInOut}
    Easings[.SINE_IN]        = {"EaseSineIn",       EaseSineIn}
    Easings[.SINE_OUT]       = {"EaseSineOut",      EaseSineOut}
    Easings[.SINE_IN_OUT]    = {"EaseSineInOut",    EaseSineInOut}
    Easings[.CIRC_IN]        = {"EaseCircIn",       EaseCircIn}
    Easings[.CIRC_OUT]       = {"EaseCircOut",      EaseCircOut}
    Easings[.CIRC_IN_OUT]    = {"EaseCircInOut",    EaseCircInOut}
    Easings[.CUBIC_IN]       = {"EaseCubicIn",      EaseCubicIn}
    Easings[.CUBIC_OUT]      = {"EaseCubicOut",     EaseCubicOut}
    Easings[.CUBIC_IN_OUT]   = {"EaseCubicInOut",   EaseCubicInOut}
    Easings[.QUAD_IN]        = {"EaseQuadIn",       EaseQuadIn}
    Easings[.QUAD_OUT]       = {"EaseQuadOut",      EaseQuadOut}
    Easings[.QUAD_IN_OUT]    = {"EaseQuadInOut",    EaseQuadInOut}
    Easings[.EXPO_IN]        = {"EaseExpoIn",       EaseExpoIn}
    Easings[.EXPO_OUT]       = {"EaseExpoOut",      EaseExpoOut}
    Easings[.EXPO_IN_OUT]    = {"EaseExpoInOut",    EaseExpoInOut}
    Easings[.BACK_IN]        = {"EaseBackIn",       EaseBackIn}
    Easings[.BACK_OUT]       = {"EaseBackOut",      EaseBackOut}
    Easings[.BACK_IN_OUT]    = {"EaseBackInOut",    EaseBackInOut}
    Easings[.BOUNCE_OUT]     = {"EaseBounceOut",    EaseBounceOut}
    Easings[.BOUNCE_IN]      = {"EaseBounceIn",     EaseBounceIn}
    Easings[.BOUNCE_IN_OUT]  = {"EaseBounceInOut",  EaseBounceInOut}
    Easings[.ELASTIC_IN]     = {"EaseElasticIn",    EaseElasticIn}
    Easings[.ELASTIC_OUT]    = {"EaseElasticOut",   EaseElasticOut}
    Easings[.ELASTIC_IN_OUT] = {"EaseElasticInOut", EaseElasticInOut}
    Easings[.NONE]           = {"None",             proc(t, b, c, d: f32) -> f32 {return b}}
}

main :: proc() {
    using raylib

    EasingsInit()

    screenWidth  :: 800
    screenHeight :: 450

    InitWindow(screenWidth, screenHeight, "easings testbed")
    defer CloseWindow()

    ballPosition: Vector2 = {100, 100}

    t: f32 = 0
    d: f32 = 300
    paused := true
    boundedT := true

    easingX: EasingTypes = .NONE
    easingY: EasingTypes = .NONE

    SetTargetFPS(60)

    for !WindowShouldClose() {
        if IsKeyPressed(.T) {
            boundedT = !boundedT
        }

        if IsKeyPressed(.RIGHT) {
            easingX = wrap(easingX + EasingTypes(1), min(EasingTypes), max(EasingTypes))
        }

        if IsKeyPressed(.LEFT) {
            easingX = wrap(easingX - EasingTypes(1), min(EasingTypes), max(EasingTypes))
        }

        if IsKeyPressed(.DOWN) {
            easingY = wrap(easingY + EasingTypes(1), min(EasingTypes), max(EasingTypes))
        }

        if IsKeyPressed(.UP) {
            easingY = wrap(easingY - EasingTypes(1), min(EasingTypes), max(EasingTypes))
        }

        if IsKeyPressed(.W) && d < D_MAX - D_STEP { d += D_STEP }
        if IsKeyPressed(.Q) && d > D_MIN - D_STEP { d -= D_STEP }

        if IsKeyDown(.S) && d < D_MAX - D_STEP_FINE { d += D_STEP_FINE }
        if IsKeyDown(.A) && d > D_MIN + D_STEP_FINE { d -= D_STEP_FINE }

        if IsKeyPressed(.SPACE) || IsKeyPressed(.T) ||
                IsKeyPressed(.RIGHT) || IsKeyPressed(.LEFT) ||
                IsKeyPressed(.DOWN) || IsKeyPressed(.UP) ||
                IsKeyPressed(.W) || IsKeyPressed(.Q) ||
                IsKeyPressed(.S) || IsKeyPressed(.A) ||
                (IsKeyPressed(.ENTER) && boundedT && t >= d) {
            t = 0
            ballPosition = {100, 100}
            paused = true
        }

        if IsKeyPressed(.ENTER) {
            paused = !paused
        }

        if !paused && ((boundedT && t < d) || !boundedT) {
            ballPosition = {
                Easings[easingX].func(t, 100, 700 - 170, d),
                Easings[easingY].func(t, 100, 400 - 170, d),
            }
            t += 1
        }

        {
            BeginDrawing()
            defer EndDrawing()

            ClearBackground(RAYWHITE)

            DrawText(TextFormat("Easing x: %s", Easings[easingX].name), 20, FONT_SIZE, FONT_SIZE, LIGHTGRAY)
            DrawText(TextFormat("Easing y: %s", Easings[easingY].name), 20, FONT_SIZE*2, FONT_SIZE, LIGHTGRAY)
            DrawText(TextFormat("t (%c) = %.2f d = %.2f", boundedT == true ? 'b' : 'u', t, d), 20, FONT_SIZE*3, FONT_SIZE, LIGHTGRAY)

            DrawText("Use ENTER to play or pause movement, use SPACE to restart", 20, GetScreenHeight() - FONT_SIZE*2, FONT_SIZE, LIGHTGRAY)
            DrawText("Use Q and W or A and S keys to change duration", 20, GetScreenHeight() - FONT_SIZE*3, FONT_SIZE, LIGHTGRAY)
            DrawText("Use LEFT or RIGHT keys to choose easing for the x axis", 20, GetScreenHeight() - FONT_SIZE*4, FONT_SIZE, LIGHTGRAY)
            DrawText("Use UP or DOWN keys to choose easing for the y axis", 20, GetScreenHeight() - FONT_SIZE*5, FONT_SIZE, LIGHTGRAY)

            DrawCircleV(ballPosition, 16, MAROON)
        }
    }
}

wrap :: proc(value, minimum, maximum: $T) -> T {
    if value < minimum { return maximum }
    if value > maximum { return minimum }
    return value
}