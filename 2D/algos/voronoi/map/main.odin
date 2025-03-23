package main

import "core:fmt"
import "core:math"
import "core:c"
import rl "vendor:raylib"

SCREEN_WIDTH :: 1200
SCREEN_HEIGHT :: 700

screen_ratio := [2]f32 {
    SCREEN_WIDTH < SCREEN_HEIGHT ? 1.0 : (f32(SCREEN_WIDTH) / f32(SCREEN_HEIGHT)),
    SCREEN_WIDTH > SCREEN_HEIGHT ? 1.0 : (f32(SCREEN_HEIGHT) / f32(SCREEN_WIDTH)),
}

pixel_size := [2]f32 {
    1.0 / f32(SCREEN_WIDTH),
    1.0 / f32(SCREEN_HEIGHT),
}

sunset_colour := rl.Vector3{255.0 / 255.0, 161.0 / 255.0, 79.0 / 255.0}
midday_colour := rl.Vector3{1.0, 1.0, 0.9}
direct_light_colour := rl.Vector3{0.9, 0.9, 0.85}
global_light_strength_min :: 0.3
global_light_strength_max :: 0.5
direct_light_strength_min :: 0.4
direct_light_strength_max :: 0.7
min_sun_centre_dist :: 0.4
min_sun_height :: 0.45
water_level := 0.15

heightmap_sh: rl.Shader
heightmap_rt: rl.RenderTexture2D
shadow_sh: rl.Shader
voronoi_tex: rl.Texture2D
time_ms: f32 = 0.0
sun_dir: rl.Vector3
global_light_strength: f32
direct_light_strength: f32
global_light_colour: rl.Vector3

draw_heightmap_texture :: proc() {
    rl.BeginTextureMode(heightmap_rt)
    rl.BeginShaderMode(heightmap_sh)
    rl.SetShaderValue(heightmap_sh, rl.GetShaderLocation(heightmap_sh, "screenRatio"), &screen_ratio, rl.ShaderUniformDataType.VEC2)
    rl.DrawRectangle(0, 0, i32(heightmap_rt.texture.width), i32(heightmap_rt.texture.height), rl.WHITE)
    rl.EndShaderMode()
    rl.EndTextureMode()
}

draw_plain_heightmap :: proc() {
    source_rect := rl.Rectangle{0, 0, f32(heightmap_rt.texture.width), -f32(heightmap_rt.texture.height)}
    rl.DrawTextureRec(heightmap_rt.texture, source_rect, rl.Vector2{0, 0}, rl.WHITE)
}

draw_shadowed_heightmap :: proc() {
    rl.BeginShaderMode(shadow_sh)
    rl.SetShaderValueTexture(shadow_sh, rl.GetShaderLocation(shadow_sh, "heightmapTex"), heightmap_rt.texture)
    rl.SetShaderValueTexture(shadow_sh, rl.GetShaderLocation(shadow_sh, "voronoiTex"), voronoi_tex)
    rl.SetShaderValue(shadow_sh, rl.GetShaderLocation(shadow_sh, "pixelSize"), &pixel_size, rl.ShaderUniformDataType.VEC2)
    rl.SetShaderValue(shadow_sh, rl.GetShaderLocation(shadow_sh, "sunDir"), &sun_dir, rl.ShaderUniformDataType.VEC3)
    rl.SetShaderValue(shadow_sh, rl.GetShaderLocation(shadow_sh, "globalLightStrength"), &global_light_strength, rl.ShaderUniformDataType.FLOAT)
    rl.SetShaderValue(shadow_sh, rl.GetShaderLocation(shadow_sh, "globalLightColour"), &global_light_colour, rl.ShaderUniformDataType.VEC3)
    rl.SetShaderValue(shadow_sh, rl.GetShaderLocation(shadow_sh, "directLightStrength"), &direct_light_strength, rl.ShaderUniformDataType.FLOAT)
    rl.SetShaderValue(shadow_sh, rl.GetShaderLocation(shadow_sh, "directLightColour"), &direct_light_colour, rl.ShaderUniformDataType.VEC3)
    rl.SetShaderValue(shadow_sh, rl.GetShaderLocation(shadow_sh, "timeMs"), &time_ms, rl.ShaderUniformDataType.FLOAT)
    rl.SetShaderValue(shadow_sh, rl.GetShaderLocation(shadow_sh, "waterLevel"), &water_level, rl.ShaderUniformDataType.FLOAT)
    
    source_rect := rl.Rectangle{0, 0, f32(SCREEN_WIDTH), -f32(SCREEN_HEIGHT)}
    rl.DrawTextureRec(heightmap_rt.texture, source_rect, rl.Vector2{0, 0}, rl.WHITE)
    rl.EndShaderMode()
}

update_sun :: proc() {
    // Set sun position to the mouse
    mouse_pos := rl.GetMousePosition()
    sun_pos := rl.Vector3{mouse_pos.x / f32(SCREEN_WIDTH), mouse_pos.y / f32(SCREEN_HEIGHT), 1.0}

    // Calculate suns offset from the centre
    centre_dir := rl.Vector2{sun_pos.x - 0.5, sun_pos.y - 0.5}
    centre_dist := math.sqrt_f32(centre_dir.x * centre_dir.x + centre_dir.y * centre_dir.y) * 2.0
    if centre_dist > 1.0 {
        centre_dist = 1.0
    }

    // Keep the sun a minimum distance from the centre
    if centre_dist < min_sun_centre_dist {
        sun_pos.x = 0.5 + min_sun_centre_dist * centre_dir.x / centre_dist
        sun_pos.y = 0.5 + min_sun_centre_dist * centre_dir.y / centre_dist
    }

    // Make sun lower when further away
    sun_pos.z = math.sqrt_f32(1.0 - centre_dist * centre_dist)
    if sun_pos.z < min_sun_height {
        sun_pos.z = min_sun_height
    }

    // Point sun dir towards the sun
    sun_dir.x = sun_pos.x - 0.5
    sun_dir.y = 0.5 - sun_pos.y
    sun_dir.z = sun_pos.z

    // Update the colours based on sun height
    midday_pct := (sun_pos.z - min_sun_height) / (1.0 - min_sun_height)
    global_light_strength = global_light_strength_min + (global_light_strength_max - global_light_strength_min) * midday_pct
    direct_light_strength = direct_light_strength_min + (direct_light_strength_max - direct_light_strength_min) * midday_pct
    global_light_colour.x = sunset_colour.x + (midday_colour.x - sunset_colour.x) * midday_pct
    global_light_colour.y = sunset_colour.y + (midday_colour.y - sunset_colour.y) * midday_pct
    global_light_colour.z = sunset_colour.z + (midday_colour.z - sunset_colour.z) * midday_pct
}

main :: proc() {
    rl.SetTraceLogLevel(rl.TraceLogLevel.WARNING)
    rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "Heightmap")
    rl.SetTargetFPS(60)

    // Initialize the shaders and textures
    heightmap_sh = rl.LoadShader("assets/shader.vs", "assets/heightmap.fs")
    heightmap_rt = rl.LoadRenderTexture(SCREEN_WIDTH, SCREEN_HEIGHT)
    shadow_sh = rl.LoadShader("assets/shader.vs", "assets/shadow.fs")
    voronoi_img := rl.LoadImage("assets/voronoi.png")
    voronoi_tex = rl.LoadTextureFromImage(voronoi_img)
    rl.UnloadImage(voronoi_img)

    draw_heightmap_texture()

    for !rl.WindowShouldClose() {
        time_ms = f32(rl.GetTime()) * 1000.0

        update_sun()

        rl.BeginDrawing()
        rl.ClearBackground(rl.MAGENTA)
        draw_shadowed_heightmap()
        rl.EndDrawing()
    }

    // Cleanup
    rl.UnloadShader(heightmap_sh)
    rl.UnloadRenderTexture(heightmap_rt)
    rl.UnloadShader(shadow_sh)
    rl.UnloadTexture(voronoi_tex)

    rl.CloseWindow()
}