package main

import "core:math/rand"
import "core:c"
import rl "vendor:raylib"

// https://arxiv.org/abs/1111.1567
main :: proc() {
    factor: f32 = 100
    width:  f32 = 16 * factor
    height: f32 = 9 * factor
    scalar: f32 = 0.2
    texture_width:  f32 = width * scalar
    texture_height: f32 = height * scalar
    
    rl.InitWindow(i32(width), i32(height), "Smooth Life")
    rl.SetTargetFPS(60)
    
    // Create image with random noise in 3/4 of the area
    img := rl.GenImageColor(i32(texture_width), i32(texture_height), rl.BLACK)
    
    for y in 0..<i32(texture_height * 3/4) {
        for x in 0..<i32(texture_width * 3/4) {
            v := u8(rand.float32() * 255)
            color := rl.Color{v, v, v, 255}
            rl.ImageDrawPixel(&img, x, y, color)
        }
    }
    // Create render textures for double buffering
    state: [2]rl.RenderTexture2D
    
    state[0] = rl.LoadRenderTexture(i32(texture_width), i32(texture_height))
    rl.SetTextureWrap(state[0].texture, rl.TextureWrap.REPEAT)
    rl.SetTextureFilter(state[0].texture, rl.TextureFilter.BILINEAR)
    rl.UpdateTexture(state[0].texture, img.data)
    
    state[1] = rl.LoadRenderTexture(i32(texture_width), i32(texture_height))
    rl.SetTextureWrap(state[1].texture, rl.TextureWrap.REPEAT)
    rl.SetTextureFilter(state[1].texture, rl.TextureFilter.BILINEAR)
    
    shader := rl.LoadShader(nil, "../assets/life.fs")
    resolution := rl.Vector2{texture_width, texture_height}
    resolution_loc := rl.GetShaderLocation(shader, "resolution")
    rl.SetShaderValue(shader, resolution_loc, &resolution, .VEC2)
    i: int
    for !rl.WindowShouldClose() {
        rl.BeginTextureMode(state[1 - i])
            rl.ClearBackground(rl.BLACK)
            rl.BeginShaderMode(shader)
                rl.DrawTexture(state[i].texture, 0, 0, rl.WHITE)
            rl.EndShaderMode()
        rl.EndTextureMode()
        i = 1 - i
        rl.BeginDrawing()
            rl.ClearBackground(rl.BLACK)
            rl.DrawTextureEx(state[i].texture, rl.Vector2{0, 0}, 0, 1/scalar, rl.WHITE)
            rl.DrawFPS(10, 10)
        rl.EndDrawing()
    }
    rl.UnloadRenderTexture(state[0])
    rl.UnloadRenderTexture(state[1])
    rl.UnloadShader(shader)
    rl.UnloadImage(img)
    rl.CloseWindow()
}