package core

import "vendor:raylib"

WIDTH  :: 800
HEIGHT :: 450

main :: proc() {
    using raylib
    InitWindow(WIDTH, HEIGHT, "VR Simulator")
    defer CloseWindow()

    device: VrDeviceInfo = {
        hResolution = 2160,
        vResolution = 1200,
        hScreenSize = 0.133793,
        vScreenSize = 0.069,
        eyeToScreenDistance = 0.041,
        lensSeparationDistance = 0.07,
        interpupillaryDistance = 0.07,

        lensDistortionValues = { 1.0, 0.22, 0.24, 0.0 },
        chromaAbCorrection = { 0.996, -0.004, 1.014, 0.0 },
    }
    config := LoadVrStereoConfig(device)
    defer UnloadVrStereoConfig(config)

    distortion := LoadShader("", TextFormat("distortion.fs"))
    defer UnloadShader(distortion)

    SetShaderValue(distortion, ShaderLocationIndex(GetShaderLocation(distortion, "leftLensCenter")),     &config.leftLensCenter,       .VEC2)
    SetShaderValue(distortion, ShaderLocationIndex(GetShaderLocation(distortion, "rightLensCenter")),    &config.rightLensCenter,      .VEC2)
    SetShaderValue(distortion, ShaderLocationIndex(GetShaderLocation(distortion, "leftScreenCenter")),   &config.leftScreenCenter,     .VEC2)
    SetShaderValue(distortion, ShaderLocationIndex(GetShaderLocation(distortion, "rightScreenCenter")) , &config.rightScreenCenter,    .VEC2)
    SetShaderValue(distortion, ShaderLocationIndex(GetShaderLocation(distortion, "scale")),              &config.scale,                .VEC2)
    SetShaderValue(distortion, ShaderLocationIndex(GetShaderLocation(distortion, "scaleIn")),            &config.scaleIn,              .VEC2)
    SetShaderValue(distortion, ShaderLocationIndex(GetShaderLocation(distortion, "deviceWarpParam")),    &device.lensDistortionValues, .VEC2)
    SetShaderValue(distortion, ShaderLocationIndex(GetShaderLocation(distortion, "chromaAbParam")),      &device.chromaAbCorrection,   .VEC2)

    target := LoadRenderTexture(device.hResolution, device.vResolution)
    defer UnloadRenderTexture(target)

    sourceRec: Rectangle = { 0, 0, f32(target.texture.width), -f32(target.texture.height) }
    destRec:   Rectangle = { 0, 0, f32(GetScreenWidth()), f32(GetScreenHeight()) }

    cam: Camera
    cam.position   = { 5, 2, 5 }
    cam.target     = { 0, 2, 0 }
    cam.up         = { 0, 1, 0}
    cam.fovy       = 60
    cam.projection = .PERSPECTIVE

    cube_pos: Vector3 = { 0, 0, 0 }

    DisableCursor()
    SetTargetFPS(90)

    for !WindowShouldClose() {
        UpdateCamera(&cam, .FIRST_PERSON)
        {
            BeginTextureMode(target)
            defer EndTextureMode()
            ClearBackground(RAYWHITE)

            BeginVrStereoMode(config)
            defer EndVrStereoMode()

            BeginMode3D(cam)
            defer EndMode3D()

            DrawCube(cube_pos, 2, 2, 2, RED)
            DrawCubeWires(cube_pos, 2, 2, 2, MAROON)
            DrawGrid(40, 1)
        }
        {
            BeginDrawing()
            defer EndDrawing()
            ClearBackground(RAYWHITE)

            BeginShaderMode(distortion)
                DrawTexturePro(target.texture, sourceRec, destRec, {0, 0}, 0, WHITE)
            EndShaderMode()
            DrawFPS(10, 10)
        }
    }
}