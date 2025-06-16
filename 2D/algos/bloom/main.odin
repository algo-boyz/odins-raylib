package main

import "core:fmt"
import rl "vendor:raylib"
import "vendor:raylib/rlgl"

MarginRec :: proc(r: rl.Rectangle, v: f32) -> rl.Rectangle {
    return rl.Rectangle{r.x + v, r.y + v, r.width - v * 2, r.height - v * 2}
}

DrawTextCentered :: proc(text: cstring, x, y, size: i32, color: rl.Color) {
    width := rl.MeasureText(text, size)
    rl.DrawText(text, x - width / 2, y, size, color)
}

DrawTextRight :: proc(text: cstring, x, y, size: i32, color: rl.Color) {
    width := rl.MeasureText(text, size)
    rl.DrawText(text, x - width, y, size, color)
}

BLOOM_MIPS :: 8

Intern_State :: struct {
    mix_shader: struct {
        s:        rl.Shader,
        exposure: f32,
        locs:     struct {
            exposure: i32,
        },
    },
    downsample_shader: struct {
        s:             rl.Shader,
        srcResolution: rl.Vector2,
        locs:          struct {
            srcResolution: i32,
        },
    },
    upsample_shader: struct {
        s:            rl.Shader,
        filterRadius: f32,
        locs:         struct {
            filterRadius: i32,
        },
    },
    fb: [BLOOM_MIPS]rl.RenderTexture2D,
}

intern: Intern_State

LoadHdrRenderTexture :: proc(width, height: i32) -> rl.RenderTexture2D {
    target: rl.RenderTexture2D
    target.id = rlgl.LoadFramebuffer(width, height) // Load empty framebuffer

    if target.id > 0 {
        rlgl.EnableFramebuffer(target.id)

        // Create color texture (default to RGBA)
        target.texture.id = rlgl.LoadTexture(
            nil,
            width,
            height,
            i32(rl.PixelFormat.UNCOMPRESSED_R32G32B32A32),
            1,
        )
        target.texture.width = width
        target.texture.height = height
        target.texture.format = rl.PixelFormat.UNCOMPRESSED_R32G32B32A32
        target.texture.mipmaps = 1

        // Create depth renderbuffer/texture
        target.depth.id = rlgl.LoadTextureDepth(width, height, true)
        target.depth.width = width
        target.depth.height = height
        target.depth.format = rl.PixelFormat(0) 
        target.depth.mipmaps = 1

        // Attach color texture and depth renderbuffer/texture to FBO
        rlgl.FramebufferAttach(
            target.id,
            target.texture.id,
            i32(rlgl.FramebufferAttachType.COLOR_CHANNEL0),
            i32(rlgl.FramebufferAttachTextureType.TEXTURE2D),
            0,
        )
        rlgl.FramebufferAttach(
            target.id,
            target.depth.id,
            i32(rlgl.FramebufferAttachType.DEPTH),
            i32(rlgl.FramebufferAttachTextureType.RENDERBUFFER),
            0,
        )
        if rlgl.FramebufferComplete(target.id) {
            rl.TraceLog(
                .INFO,
                fmt.ctprintf("FBO: [ID %i] Framebuffer object created successfully", target.id),
            )
        }
        rlgl.DisableFramebuffer()
    } else {
        rl.TraceLog(.WARNING, "FBO: Framebuffer object can not be created")
    }
    rl.SetTextureFilter(target.texture, .BILINEAR)
    rl.SetTextureWrap(target.texture, .CLAMP)

    return target
}

update_downsample_shader :: proc() {
    rl.SetShaderValue(
        intern.downsample_shader.s,
        intern.downsample_shader.locs.srcResolution,
        &intern.downsample_shader.srcResolution,
        .VEC2,
    )
}

update_upsample_shader :: proc() {
    rl.SetShaderValue(
        intern.upsample_shader.s,
        intern.upsample_shader.locs.filterRadius,
        &intern.upsample_shader.filterRadius,
        .FLOAT,
    )
}

update_mix_shader :: proc() {
    rl.SetShaderValue(
        intern.mix_shader.s,
        intern.mix_shader.locs.exposure,
        &intern.mix_shader.exposure,
        .FLOAT,
    )
}

init_bloom :: proc(width, height: i32) {
    intern.downsample_shader.s = rl.LoadShader(nil, "assets/downsample.fs")
    intern.upsample_shader.s = rl.LoadShader(nil, "assets/upsample.fs")
    intern.mix_shader.s = rl.LoadShader(nil, "assets/mix.fs")

    intern.downsample_shader.locs.srcResolution =
        rl.GetShaderLocation(intern.downsample_shader.s, "srcResolution")
    intern.upsample_shader.locs.filterRadius =
        rl.GetShaderLocation(intern.upsample_shader.s, "filterRadius")
    intern.mix_shader.locs.exposure =
        rl.GetShaderLocation(intern.mix_shader.s, "exposure")

    current_width := width
    current_height := height
    for i in 0 ..< BLOOM_MIPS {
        intern.fb[i] = LoadHdrRenderTexture(current_width, current_height)
        current_width /= 2
        current_height /= 2
    }
}

downsample :: proc(i: int) {
    rl.BeginTextureMode(intern.fb[i + 1])
    rl.ClearBackground(rl.BLACK)

    rl.BeginShaderMode(intern.downsample_shader.s)
    intern.downsample_shader.srcResolution = rl.Vector2{
        f32(intern.fb[i].texture.width),
        f32(intern.fb[i].texture.height),
    }
    update_downsample_shader()

    rl.DrawTexturePro(
        intern.fb[i].texture,
        rl.Rectangle{
            0,
            0,
            f32(intern.fb[i].texture.width),
            -f32(intern.fb[i].texture.height), // Negative height to flip
        },
        rl.Rectangle{
            0,
            0,
            f32(intern.fb[i + 1].texture.width),
            f32(intern.fb[i + 1].texture.height),
        },
        rl.Vector2{0, 0},
        0,
        rl.WHITE,
    )
    rl.EndShaderMode()
    rl.EndTextureMode()
}

upsample :: proc(i: int) {
    rl.BeginTextureMode(intern.fb[BLOOM_MIPS - 2 - i])
    rl.BeginShaderMode(intern.upsample_shader.s)
    intern.upsample_shader.filterRadius = 0.003
    update_upsample_shader()

    rl.DrawTexturePro(
        intern.fb[BLOOM_MIPS - 1 - i].texture,
        rl.Rectangle{
            0,
            0,
            f32(intern.fb[BLOOM_MIPS - 1 - i].texture.width),
            -f32(intern.fb[BLOOM_MIPS - 1 - i].texture.height), // Negative height
        },
        rl.Rectangle{
            0,
            0,
            f32(intern.fb[BLOOM_MIPS - 2 - i].texture.width),
            f32(intern.fb[BLOOM_MIPS - 2 - i].texture.height),
        },
        rl.Vector2{0, 0},
        0,
        rl.WHITE,
    )
    rl.EndShaderMode()
    rl.EndTextureMode()
}

do_bloom :: proc(
    output: rl.RenderTexture2D,
    input_base: rl.RenderTexture2D,
    input_emission: rl.RenderTexture2D,
    bloom_amount: f32,
    exposure_amount: f32,
) {
    // render input emission first mip
    rl.BeginTextureMode(intern.fb[0])
    // ColorBrightness clamps values and does not achieve HDR bloom intensity
    // a shader would be more appropriate for true HDR effects
    tint_color := rl.ColorBrightness(rl.WHITE, bloom_amount) 
    
    rl.DrawTexturePro(
        input_emission.texture,
        rl.Rectangle{
            0,
            0,
            f32(input_emission.texture.width),
            -f32(input_emission.texture.height), // Negative height
        },
        rl.Rectangle{
            0,
            0,
            f32(intern.fb[0].texture.width),
            f32(intern.fb[0].texture.height),
        },
        rl.Vector2{0, 0},
        0,
        tint_color, 
    )
    rl.EndTextureMode()

    for i in 0 ..< BLOOM_MIPS - 1 {
        downsample(i)
    }

    rl.BeginBlendMode(.ADDITIVE)
    for i in 0 ..< BLOOM_MIPS - 1 {
        upsample(i)
    }
    rl.EndBlendMode()

    // combine first mip with base input
    rl.BeginBlendMode(.ADDITIVE)
    rl.BeginTextureMode(intern.fb[0])
    rl.DrawTextureRec(
        input_base.texture,
        rl.Rectangle{
            0,
            0,
            f32(intern.fb[0].texture.width),
            -f32(intern.fb[0].texture.height), // flip source
        },
        rl.Vector2{0, 0},
        rl.WHITE,
    )
    rl.EndTextureMode()
    rl.EndBlendMode()

    // render output with exposure
    rl.BeginTextureMode(output)
    rl.ClearBackground(rl.BLACK)
    rl.BeginShaderMode(intern.mix_shader.s)
    intern.mix_shader.exposure = exposure_amount
    update_mix_shader()
    rl.DrawTextureRec(
        intern.fb[0].texture,
        rl.Rectangle{
            0,
            0,
            f32(intern.fb[0].texture.width),
            -f32(intern.fb[0].texture.height), // flip source
        },
        rl.Vector2{0, 0},
        rl.WHITE,
    )
    rl.EndShaderMode()
    rl.EndTextureMode()
}

App_State :: struct {
    base_fb:     rl.RenderTexture2D,
    emission_fb: rl.RenderTexture2D,
    final_fb:    rl.RenderTexture2D,
}

state: App_State

draw_frame_emissions :: proc() {
    rl.BeginTextureMode(state.emission_fb)
    rl.ClearBackground(rl.BLACK)

    DrawTextCentered("BLOOM", 400, 400 - 20, 40, rl.WHITE)
    rl.DrawCircle(600, 600, 100, rl.BLUE)

    rl.EndTextureMode()
}

draw_frame :: proc() {
    rl.BeginTextureMode(state.base_fb)
    rl.ClearBackground(rl.BLACK)

    fps_text := fmt.ctprintf("%d FPS", rl.GetFPS())
    DrawTextRight(fps_text, 800, 0, 20, rl.RED)

    DrawTextCentered("BLOOM", 400, 400 - 20, 40, rl.WHITE)
    rl.DrawRectangle(100, 100, 100, 100, rl.GREEN)
    rl.DrawCircle(600, 600, 100, rl.BLUE)

    rl.EndTextureMode()
}

init :: proc() {
    state.base_fb = rl.LoadRenderTexture(800, 800)
    state.emission_fb = rl.LoadRenderTexture(800, 800)
    state.final_fb = rl.LoadRenderTexture(800, 800)

    init_bloom(800, 800)
}

loop :: proc() {
    draw_frame()
    draw_frame_emissions()

    do_bloom(state.final_fb, state.base_fb, state.base_fb, 0, 1)

    rl.BeginDrawing()
    rl.ClearBackground(rl.BLACK)
    rl.DrawTextureRec(
        state.final_fb.texture,
        rl.Rectangle{0, 0, 800, -800}, // Negative height to flip
        rl.Vector2{0, 0},
        rl.WHITE,
    )
    rl.EndDrawing()
}

main :: proc() {
    rl.InitWindow(800, 800, "BLOOM")
    init()
    rl.SetTargetFPS(60)
    for !rl.WindowShouldClose() {
        loop()
    }
    for i in 0..<BLOOM_MIPS {
        rl.UnloadRenderTexture(intern.fb[i])
    }
    rl.UnloadShader(intern.downsample_shader.s)
    rl.UnloadShader(intern.upsample_shader.s)
    rl.UnloadShader(intern.mix_shader.s)
    rl.UnloadRenderTexture(state.base_fb)
    rl.UnloadRenderTexture(state.emission_fb)
    rl.UnloadRenderTexture(state.final_fb)
    rl.CloseWindow()
}