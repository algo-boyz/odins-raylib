package main

import "core:fmt"
import "core:math"
import "core:math/rand"
import rl "vendor:raylib"
import "../"

// Constants
EMPTY_POS :: [2]f32{-999, -999}
PERLIN_IMAGE_SCALE :: 1
P_RADIUS_MAX :: 20

// Global settings with defaults
P_GRAV_SPEED: f32 = 100
P_WIND_SPEED: f32 = 0.5
P_RADIUS_SCALE: f32 = 0.25
P_TEXTURES_SCALE: f32 = 0.025
P_COLOR_ALPHA_SCALE: f32 = 0.85
P_SPAWN_FREQUENCY: f32 = 1.0

// Structures
Window :: struct {
    name: cstring,
    posX, posY: i32,
    width, height: i32,
    fps: i32,
    configFlags: rl.ConfigFlags,
    mousePassthroughCtrl: bool,
    mousePassthroughTimer: f32,
}

SnowParticle :: struct {
    color: rl.Color,
    pos: rl.Vector2,
    rot: f32,
    radius: f32,
    isDot: bool,
    texIndex: u8,
}

Context :: struct {
    window: Window,
    textures: [dynamic]rl.Texture2D,
    snowParticles: [2048]SnowParticle,
    newSnowParticleTimer: f32,
    perlinTex: rl.Texture2D,
    perlinImg: rl.Image,
}

// Global context
ctx: ^Context

main :: proc() {
    init()
    for update() {
        continue
    }
    destroy()
}

init :: proc() {
    ctx = new(Context)
    ctx.window = Window{
        name = "Christmas Snow",
        posX = 0,
        posY = 0,
        width = 1200,
        height = 720,
        fps = 60,
        configFlags = {
            .MSAA_4X_HINT,
            .WINDOW_UNDECORATED,
            .WINDOW_TOPMOST,
            .WINDOW_TRANSPARENT,
        }
    }
    
    rl.SetConfigFlags(ctx.window.configFlags)
    rl.InitWindow(ctx.window.width, ctx.window.height, ctx.window.name)
    rl.SetWindowState(ctx.window.configFlags)
    rl.SetTargetFPS(ctx.window.fps)

    // Initialize empty particle positions
    for &p in ctx.snowParticles {
        p.pos = EMPTY_POS
    }
    
    // Initialize perlin noise for wind effects
    ctx.perlinImg = rl.GenImagePerlinNoise(
        ctx.window.width / PERLIN_IMAGE_SCALE, 
        ctx.window.height / PERLIN_IMAGE_SCALE, 
        0, 0, 10.0
    )
    ctx.perlinTex = rl.LoadTextureFromImage(ctx.perlinImg)
    
    // Create a simple snowflake texture
    // img := rl.GenImageColor(16, 16, rl.WHITE)
    // for i in 0..<3 { // Add several snowflake variations
    //     append(&ctx.textures, rl.LoadTextureFromImage(img))
    // }
    // rl.UnloadImage(img)
    img := rl.Image {
        data = rawptr(&snow.FLAKE_A),
        width = snow.FLAKE_A_WIDTH,
        height = snow.FLAKE_A_HEIGHT,
        mipmaps = 1,
        format = rl.PixelFormat(snow.FLAKE_A_FORMAT),
    }
    append(&ctx.textures, rl.LoadTextureFromImage(img))
    img.data = rawptr(&snow.FLAKE_B)
    img.width = snow.FLAKE_B_WIDTH
    img.height = snow.FLAKE_B_HEIGHT
    append(&ctx.textures, rl.LoadTextureFromImage(img))
    img.data = rawptr(&snow.FLAKE_C)
    img.width = snow.FLAKE_C_WIDTH
    img.height = snow.FLAKE_C_HEIGHT
    append(&ctx.textures, rl.LoadTextureFromImage(img))
}

update :: proc() -> bool {
    ctx.window.width = rl.GetScreenWidth()
    ctx.window.height = rl.GetScreenHeight()

    dt := rl.GetFrameTime()
    windowRect := rl.Rectangle{0, 0, f32(ctx.window.width), f32(ctx.window.height)}

    // Create new snow particles
    ctx.newSnowParticleTimer -= dt * P_SPAWN_FREQUENCY
    if ctx.newSnowParticleTimer <= 0 {
        new_snow()
        ctx.newSnowParticleTimer = rand.float32_range(0.05, 0.2)
    }
    
    rl.BeginDrawing()
    rl.ClearBackground(rl.BLANK)
    
    // Update and render particles
    for &p, idx in ctx.snowParticles {
        if p.pos == EMPTY_POS {
            continue
        }
        
        // Get perlin noise value for wind effect
        perlinColor := f32(i8(rl.GetImageColor(
            ctx.perlinImg, 
            i32(p.pos.x) / PERLIN_IMAGE_SCALE, 
            i32(p.pos.y) / PERLIN_IMAGE_SCALE
        ).r) - 127)
        
        // Apply wind and gravity
        windForce := perlinColor * P_WIND_SPEED * dt
        p.pos.x += windForce
        
        gForce := (perlinColor * 0.001) + p.radius / P_RADIUS_MAX
        p.pos.y += gForce * P_GRAV_SPEED * dt

        // Remove particles outside of window
        if !rl.CheckCollisionPointRec(p.pos, windowRect) {
            p.pos = EMPTY_POS
            continue
        }
        
        // Fade near bottom
        smoothstepOfPosY := 1 - math.smoothstep(f32(0.75), f32(1.05), p.pos.y / f32(ctx.window.height))
        renderColor := p.color
        renderColor.a = u8(f32(renderColor.a) * smoothstepOfPosY * P_COLOR_ALPHA_SCALE)

        // Draw particles
        if p.isDot {
            rl.DrawCircle(i32(p.pos.x), i32(p.pos.y), p.radius * P_RADIUS_SCALE, renderColor)
        } else {
            p.rot += p.radius / P_RADIUS_MAX * 70 * dt
            rot := math.sin(p.rot * 0.01) * (math.PI * 0.9) * math.DEG_PER_RAD

            tex_idx := int(p.texIndex) % len(ctx.textures)
            tex := &ctx.textures[tex_idx]
            srcRec := rl.Rectangle{0, 0, f32(tex.width), f32(tex.height)}
            
            texW := f32(tex.width) * (p.radius * P_TEXTURES_SCALE)
            texH := f32(tex.height) * (p.radius * P_TEXTURES_SCALE)
            dstRec := rl.Rectangle{p.pos.x, p.pos.y, texW / 2, texH / 2}
            origin := rl.Vector2{texW / 4, texH / 4}
            
            rl.DrawTexturePro(tex^, srcRec, dstRec, origin, rot, renderColor)
        }
    }
    
    // Draw UI
    draw_ui()
    
    rl.DrawFPS(10, 10)
    rl.EndDrawing()

    // Exit on window close request
    return !rl.WindowShouldClose()
}

new_snow :: proc() {
    for &p in ctx.snowParticles {
        if p.pos != EMPTY_POS {
            continue
        }
        // Initialize a new particle
        p.pos.x = rand.float32_range(0, f32(ctx.window.width))
        p.pos.y = 0
        p.radius = rand.float32_range(8, P_RADIUS_MAX)
        
        // Set color (bluish white)
        rg := u8(rand.float32_range(170, 230))
        p.color.r = rg
        p.color.g = rg
        p.color.b = 255
        p.color.a = u8(rand.float32_range(100, 255))
        
        // Randomly choose between dot or textured flake
        p.isDot = 0.3 < rand.float32_range(0, 1)
        if !p.isDot {
            p.texIndex = u8(rand.float32_range(0, f32(len(ctx.textures) - 1)))
        }
        break
    }
}

draw_ui :: proc() {
    // Simple UI for controls
    if !rl.IsKeyDown(.LEFT_ALT) {
        return
    }
    
    bgColor := rl.ColorAlpha(rl.LIGHTGRAY, 0.8)
    rl.DrawRectangle(10, 10, 300, 220, bgColor)
    
    rl.DrawText("Controls (hold Alt to show)", 20, 20, 20, rl.DARKGRAY)
    rl.DrawText("Press Escape to close", 20, 45, 16, rl.DARKGRAY)
    
    // Display current settings
    y:i32 = 70
    rl.DrawText("Snow Settings:", 20, y, 18, rl.DARKBLUE)
    
    y += 25
    rl.DrawText(rl.TextFormat("Gravity: %.1f", P_GRAV_SPEED), 20, y, 16, rl.BLACK)
    
    y += 20
    rl.DrawText(rl.TextFormat("Wind: %.2f", P_WIND_SPEED), 20, y, 16, rl.BLACK)
    
    y += 20
    rl.DrawText(rl.TextFormat("Size: %.2f", P_RADIUS_SCALE), 20, y, 16, rl.BLACK)
    
    y += 20
    rl.DrawText(rl.TextFormat("Opacity: %.2f", P_COLOR_ALPHA_SCALE), 20, y, 16, rl.BLACK)
    
    y += 20
    rl.DrawText(rl.TextFormat("Frequency: %.2f", P_SPAWN_FREQUENCY), 20, y, 16, rl.BLACK)
}

destroy :: proc() {
    // Unload textures
    for t in ctx.textures {
        rl.UnloadTexture(t)
    }
    delete(ctx.textures)
    
    rl.UnloadTexture(ctx.perlinTex)
    rl.UnloadImage(ctx.perlinImg)
    
    free(ctx)
    rl.CloseWindow()
}