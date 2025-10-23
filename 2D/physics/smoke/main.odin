package main

import "core:fmt"
import rl "vendor:raylib"

MAX_PARTICLES :: 300
HEIGHT :: 450

Particle :: struct {
    position: rl.Vector2,
    color:    rl.Color,
    alpha:    f32,
    size:     f32,
    rotation: f32,
    active:   bool,
}

main :: proc() {
    rl.InitWindow(800, HEIGHT, "Smoke Trail")
    mouse_tail := [MAX_PARTICLES]Particle{}
    for i in 0..<MAX_PARTICLES {
        mouse_tail[i].position = rl.Vector2{0, 0}
        mouse_tail[i].color = rl.GRAY
        mouse_tail[i].alpha = 1.0
        mouse_tail[i].size = f32(rl.GetRandomValue(1, 30)) / 20.0
        mouse_tail[i].rotation = f32(rl.GetRandomValue(0, 360))
        mouse_tail[i].active = false
    }
    gravity: f32 = 3.0
    // Create a Image in memory
    smoke := rl.LoadRenderTexture(32, 32)
    
    rl.BeginTextureMode(smoke)
    rl.ClearBackground(rl.BLANK)
    
    // Draw a base image(dark edges and white inside) for the additive blend mode smoke trail.
    for i in 0..<16 {
        rl.BeginTextureMode(smoke)
        c := u8(255 / 16 * i)
        rl.DrawCircle(16, 16, 16 - f32(i) / 2, rl.Color{c, c, c, 255})
        rl.EndTextureMode()  // This needs to be called after every different draw command used.
    }
    rl.EndTextureMode()
    // Start at blend additive mode for the white smoke trial.
    blending := rl.BlendMode.ADDITIVE
    rl.SetTargetFPS(60) 
    for !rl.WindowShouldClose() {  // Detect window close button or ESC key
        // Activate one particle every frame and Update active particles
        // NOTE: Particles initial position should be mouse position when activated
        // NOTE: Particles fall down with gravity and rotation... and disappear after 2 seconds (alpha = 0)
        // NOTE: When a particle disappears, active = false and it can be reused.
        for i in 0..<MAX_PARTICLES {
            if !mouse_tail[i].active {
                mouse_tail[i].active = true
                mouse_tail[i].alpha = 1.0
                mouse_tail[i].position = rl.GetMousePosition()
                break
            }
        }
        for i in 0..<MAX_PARTICLES {
            if mouse_tail[i].active {
                mouse_tail[i].position.y += gravity / 2
                mouse_tail[i].alpha -= 0.005

                if mouse_tail[i].alpha <= 0.0 {
                    mouse_tail[i].active = false
                }
                mouse_tail[i].rotation += 2.0
            }
        }
        if rl.IsKeyPressed(rl.KeyboardKey.SPACE) {
            blending = blending == rl.BlendMode.ALPHA ? rl.BlendMode.ADDITIVE : rl.BlendMode.ALPHA
        }
        rl.BeginDrawing()
        rl.ClearBackground(rl.DARKGRAY)
        rl.BeginBlendMode(blending)
        
        for i in 0..<MAX_PARTICLES {
            if mouse_tail[i].active {
                sourceRec := rl.Rectangle{
                    0.0, 
                    0.0, 
                    f32(smoke.texture.width), 
                    f32(smoke.texture.height),
                }
                destRec := rl.Rectangle{
                    mouse_tail[i].position.x,
                    mouse_tail[i].position.y,
                    f32(smoke.texture.width) * mouse_tail[i].size,
                    f32(smoke.texture.height) * mouse_tail[i].size,
                }
                origin := rl.Vector2{
                    f32(smoke.texture.width) * mouse_tail[i].size / 2.0,
                    f32(smoke.texture.height) * mouse_tail[i].size / 2.0,
                }
                color := rl.ColorAlpha(mouse_tail[i].color, mouse_tail[i].alpha)
                rl.DrawTexturePro(
                    smoke.texture,
                    sourceRec,
                    destRec,
                    origin,
                    mouse_tail[i].rotation,
                    color,
                )
            }
        }
        rl.EndBlendMode()
        rl.DrawText("PRESS SPACE to CHANGE BLENDING MODE", 180, 20, 20, rl.BLACK)

        if blending == rl.BlendMode.ALPHA {
            rl.DrawText("ALPHA BLENDING", 290, HEIGHT - 40, 20, rl.BLACK)
        } else {
            rl.DrawText("ADDITIVE BLENDING", 280, HEIGHT - 40, 20, rl.WHITE)
        }
        rl.EndDrawing()
    }
    rl.UnloadRenderTexture(smoke)
    rl.CloseWindow()
}