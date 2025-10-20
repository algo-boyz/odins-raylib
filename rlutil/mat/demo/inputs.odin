package main

import rl "vendor:raylib"

HandleInputs :: proc(translation, rotation: ^Vector3, scale: ^f32, renderMode: ^i8, renderModesCount: i8, deltaTime: f32) {
    linearStep: f32 = (rl.IsKeyDown(rl.KeyboardKey.LEFT_SHIFT) ? 0.25 : 1) * deltaTime
    angularStep: f32 = (rl.IsKeyDown(rl.KeyboardKey.LEFT_SHIFT) ? 12 : 48) * deltaTime

    if rl.IsKeyDown(rl.KeyboardKey.W) do translation.z += linearStep
    if rl.IsKeyDown(rl.KeyboardKey.S) do translation.z -= linearStep
    if rl.IsKeyDown(rl.KeyboardKey.A) do translation.x += linearStep
    if rl.IsKeyDown(rl.KeyboardKey.D) do translation.x -= linearStep
    if rl.IsKeyDown(rl.KeyboardKey.E) do translation.y += linearStep
    if rl.IsKeyDown(rl.KeyboardKey.Q) do translation.y -= linearStep

    if rl.IsKeyDown(rl.KeyboardKey.J) do rotation.x += angularStep
    if rl.IsKeyDown(rl.KeyboardKey.L) do rotation.x -= angularStep
    if rl.IsKeyDown(rl.KeyboardKey.O) do rotation.y += angularStep
    if rl.IsKeyDown(rl.KeyboardKey.U) do rotation.y -= angularStep
    if rl.IsKeyDown(rl.KeyboardKey.I) do rotation.z -= angularStep
    if rl.IsKeyDown(rl.KeyboardKey.K) do rotation.z += angularStep

    if rl.IsKeyDown(rl.KeyboardKey.KP_ADD) do scale^ += linearStep
    if rl.IsKeyDown(rl.KeyboardKey.KP_SUBTRACT) do scale^ -= linearStep

    if rl.IsKeyPressed(rl.KeyboardKey.LEFT) {
        renderMode^ = (renderMode^ + renderModesCount - 1) % renderModesCount
    } else if rl.IsKeyPressed(rl.KeyboardKey.RIGHT) {
        renderMode^ = (renderMode^ + 1) % renderModesCount
    }
}