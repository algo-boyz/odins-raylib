package main

import "core:math"
import "core:math/rand"
import "core:fmt"
import "core:slice"
import rl "vendor:raylib"

PI :: math.PI

// Helper functions
randf :: proc(a: f32 = 0, b: f32 = 1) -> f32 {
    return a + rand.float32() * (b - a)
}

color_from_hsv_f :: proc(h: f32, s: f32, v: f32, a: u8 = 255) -> rl.Color {
    hh := math.mod(h, 360)
    if hh < 0 do hh += 360
    c := rl.ColorFromHSV(hh, s, v)
    c.a = a
    return c
}

smoothstep :: proc(a: f32, b: f32, t: f32) -> f32 {
    if t <= a do return 0
    if t >= b do return 1
    tt := (t - a) / (b - a)
    return tt * tt * (3 - 2 * tt)
}

// Particle structure with trail
Particle :: struct {
    pos:   rl.Vector2,
    vel:   rl.Vector2,
    life:  f32,
    size:  f32,
    col:   rl.Color,
    trail: [dynamic]rl.Vector2,
}

// Star for parallax starfield
Star :: struct {
    x, y, z:    f32,
    brightness: f32,
}

// Spirograph parameters
Spiro :: struct {
    a, b:   f32,
    da, db: f32,
    scale:  f32,
    rot:    f32,
    col:    rl.Color,
}

main :: proc() {
    W :: 1200
    H :: 900
    rl.InitWindow(W, H, "Ultra Extended Raylib Demo - Mouse Controls (Enhanced) - Odin")
    rl.SetTargetFPS(60)
    
    // Render targets for accumulation and glow
    accum := rl.LoadRenderTexture(W, H)
    glow := rl.LoadRenderTexture(W/2, H/2)
    rl.SetTextureFilter(accum.texture, .BILINEAR)
    rl.SetTextureFilter(glow.texture, .BILINEAR)
    
    // Camera setup
    cam := rl.Camera2D{
        offset   = {W/2, H/2},
        target   = {W/2, H/2},
        rotation = 0,
        zoom     = 1,
    }
    cam_target_zoom := cam.zoom
    cam_shake: f32 = 0
    
    // State variables
    t: f32 = 0
    spawn_acc: f32 = 0
    mouse_rotate_accum: f32 = 0
    paused := false
    slow_mo := false
    show_fps := true
    
    // Particle arrays
    particles := make([dynamic]Particle, 0, 4000)
    smoke := make([dynamic]Particle, 0, 1500)
    
    // Feature toggles
    enable_wind := true
    gravity_well := true
    show_debug := false
    enable_spiro := true
    enable_smoke := true
    enable_trails := true
    enable_glow := true
    
    // Configuration
    trail_length := 18
    particle_color_mode := 0 // 0=hue cycle, 1=palette, 2=white fade
    max_particles := 5000
    max_smoke := 2000
    
    // Initialize spirographs
    spiros := make([dynamic]Spiro, 0, 8)
    for i in 0..<8 {
        spiro := Spiro{
            a     = randf(1, 5),
            b     = randf(1, 5),
            da    = randf(-0.02, 0.02),
            db    = randf(-0.02, 0.02),
            scale = 80 + f32(i) * 20,
            rot   = 0,
            col   = color_from_hsv_f(randf(0, 360), 0.8, 0.95),
        }
        append(&spiros, spiro)
    }
    // Starfield layers for parallax
    LAYERS :: 3
    layers: [LAYERS][dynamic]Star
    counts := [LAYERS]int{900, 600, 300}
    speeds := [LAYERS]f32{60, 110, 200}
    
    for l in 0..<LAYERS {
        layers[l] = make([dynamic]Star, 0, counts[l])
        for _ in 0..<counts[l] {
            star := Star{
                x          = randf(-W/2, W/2),
                y          = randf(-H/2, H/2),
                z          = randf(0.5 + f32(l) * 0.5, W),
                brightness = randf(0.6, 1),
            }
            append(&layers[l], star)
        }
    }
    // Color palettes
    palettes := [][3]rl.Color{
        {
            color_from_hsv_f(200, 0.6, 0.9),
            color_from_hsv_f(260, 0.6, 0.9),
            color_from_hsv_f(320, 0.7, 0.9),
        },
        {
            color_from_hsv_f(10, 0.8, 0.95),
            color_from_hsv_f(40, 0.8, 0.95),
            color_from_hsv_f(70, 0.8, 0.95),
        },
        {
            color_from_hsv_f(150, 0.6, 0.8),
            color_from_hsv_f(200, 0.6, 0.8),
            color_from_hsv_f(260, 0.6, 0.8),
        },
    }
    palette_index := 0
    // Timing
    last_screenshot_time: f64 = 0
    screenshot_counter := 0
    help_text:cstring = "Keys: D debug  P palette  S spiro  M smoke  T trails  G glow  C clear  Space pause  Z slow-mo  K screenshot  W wind  V gravity-well  [+/-] trails len  O color mode  F fps toggle"
    
    // Main loop
    for !rl.WindowShouldClose() {
        real_dt := rl.GetFrameTime()
        dt := paused ? 0 : (slow_mo ? real_dt * 0.22 : real_dt)
        t += dt
        // Input handling
        mouse_screen := rl.GetMousePosition()
        mouse_delta := rl.GetMouseDelta()
        wheel := rl.GetMouseWheelMove()
        lmb := rl.IsMouseButtonDown(.LEFT)
        rmb := rl.IsMouseButtonDown(.RIGHT)
        mmb_pressed := rl.IsMouseButtonPressed(.MIDDLE)
        
        mouse_world := rl.GetScreenToWorld2D(mouse_screen, cam)
        if mmb_pressed {
            clear(&particles)
            clear(&smoke)
        }
        // Key toggles
        if rl.IsKeyPressed(.D) do show_debug = !show_debug
        if rl.IsKeyPressed(.P) do palette_index = (palette_index + 1) % len(palettes)
        if rl.IsKeyPressed(.S) do enable_spiro = !enable_spiro
        if rl.IsKeyPressed(.M) do enable_smoke = !enable_smoke
        if rl.IsKeyPressed(.T) do enable_trails = !enable_trails
        if rl.IsKeyPressed(.G) do enable_glow = !enable_glow
        if rl.IsKeyPressed(.C) {
            clear(&particles)
            clear(&smoke)
        }
        if rl.IsKeyPressed(.SPACE) do paused = !paused
        if rl.IsKeyPressed(.Z) do slow_mo = !slow_mo
        if rl.IsKeyPressed(.K) {
            now := rl.GetTime()
            if now - last_screenshot_time > 0.3 {
                filename := fmt.ctprintf("screenshot_%03d.png", screenshot_counter)
                rl.TakeScreenshot(filename)
                screenshot_counter += 1
                last_screenshot_time = now
            }
        }
        if rl.IsKeyPressed(.W) do enable_wind = !enable_wind
        if rl.IsKeyPressed(.V) do gravity_well = !gravity_well
        if rl.IsKeyPressed(.O) do particle_color_mode = (particle_color_mode + 1) % 3
        if rl.IsKeyPressed(.F) do show_fps = !show_fps
        if rl.IsKeyPressed(.EQUAL) || rl.IsKeyPressed(.KP_ADD) {
            trail_length = min(200, trail_length + 2)
        }
        if rl.IsKeyPressed(.MINUS) || rl.IsKeyPressed(.KP_SUBTRACT) {
            trail_length = max(0, trail_length - 2)
        }
        // Mouse wheel zoom
        cam_target_zoom += wheel * 0.08
        cam_target_zoom = clamp(cam_target_zoom, 0.45, 3.5)
        
        // Procedural "audio" level for variation
        audio_level := 0.5 + 0.5 * math.sin(t * 1.9) * (0.4 + 0.6 * abs(math.sin(t * 0.27)))
        beat := math.sin(t * 2) > 0.85 ? 1 : 0
        
        // Camera interpolation
        cam.zoom += (cam_target_zoom - cam.zoom) * smoothstep(0, 1, dt * 6)
        cam.rotation = math.sin(t * 0.12) * audio_level * 2.5 + mouse_rotate_accum * 0.05
        cam_shake = 0.85 * audio_level
        
        // Right mouse drag for rotation
        if rmb {
            mouse_rotate_accum += mouse_delta.x * 0.6 * (paused ? 0 : 1)
        }
        // Spawn particles based on procedural audio
        spawn_acc += dt * (30 + 140 * audio_level)
        for spawn_acc >= 1 {
            spawn_acc -= 1
            if len(particles) < max_particles {
                particle := Particle{
                    pos = {W/2 + randf(-24, 24), H/2 + randf(-24, 24)},
                    vel = {
                        math.cos(randf(0, 2*PI)) * randf(40, 420),
                        math.sin(randf(0, 2*PI)) * randf(40, 420),
                    },
                    life = randf(1, 3.5),
                    size = randf(1.6, 5.2),
                }
                // Color based on mode
                switch particle_color_mode {
                case 0:
                    hue := math.mod(t * 48 + randf(0, 360), 360)
                    particle.col = color_from_hsv_f(hue, 0.85, 0.95)
                case 1:
                    pal := palettes[palette_index % len(palettes)]
                    particle.col = pal[int(randf(0, 3))]
                case:
                    particle.col = rl.WHITE
                }
                if enable_trails {
                    particle.trail = make([dynamic]rl.Vector2, 0, trail_length)
                    append(&particle.trail, particle.pos)
                }
                append(&particles, particle)
            } else {
                break
            }
        }
        // Spawn smoke particles
        if enable_smoke {
            for i in 0..<8 {
                if len(smoke) >= max_smoke do break
                
                s := Particle{
                    pos = {W/2 + randf(-300, 300), H/2 + randf(-200, 200)},
                    vel = {
                        math.cos(randf(0, 2*PI)) * randf(10, 40),
                        math.sin(randf(0, 2*PI)) * randf(10, 40),
                    },
                    life = randf(2, 6),
                    size = randf(3, 8),
                    col = color_from_hsv_f(math.mod(200 + randf(-30, 30), 360), 0.2, 0.7),
                }
                if enable_trails {
                    s.trail = make([dynamic]rl.Vector2, 0, trail_length + 12)
                    append(&s.trail, s.pos)
                }
                append(&smoke, s)
            }
        }
        // Update particles with mouse interaction
        for &p in particles {
            to_mouse := mouse_world - p.pos
            d2 := to_mouse.x*to_mouse.x + to_mouse.y*to_mouse.y + 1e-6
            dist := math.sqrt(d2)
            
            if lmb && dist < 420 {
                // Attract to mouse
                strength := 400 * (1 - dist/420)
                p.vel += (to_mouse / dist) * strength * dt * 0.6
            } else if !lmb && dist < 200 {
                // Subtle repulsion when hovering
                strength := 30 * (1 - dist/200)
                p.vel -= (to_mouse / dist) * strength * dt * 0.4
            }
            // Gravity well at center
            if gravity_well {
                to_center := rl.Vector2{W/2, H/2} - p.pos
                dc2 := to_center.x*to_center.x + to_center.y*to_center.y + 1e-6
                d_center := math.sqrt(dc2)
                g_strength := 50 * (1 - min(d_center / f32(max(W, H)), 1))
                p.vel += (to_center / d_center) * g_strength * dt * 0.12
            }
        }
        // Update particle physics
        for &p in particles {
            p.pos += p.vel * dt
            damp_factor := math.pow(0.975, dt * 60)
            p.vel *= damp_factor
            p.life -= dt
            
            if enable_trails {
                append(&p.trail, p.pos)
                for len(p.trail) > trail_length {
                    ordered_remove(&p.trail, 0)
                }
            }
        }
        // Remove dead particles
        for i := len(particles) - 1; i >= 0; i -= 1 {
            if particles[i].life <= 0 {
                delete(particles[i].trail)
                ordered_remove(&particles, i)
            }
        }
        // Update smoke with flow field
        for &s in smoke {
            nx := s.pos.x * 0.004 + t * 0.18
            ny := s.pos.y * 0.004 + t * 0.14
            flow := rl.Vector2{
                math.cos(ny*2.3) * 40 + math.sin(nx*1.7) * 40,
                math.sin(nx*2.1) * 40 + math.cos(ny*1.4) * 40,
            }
            if !enable_wind do flow = {0, 0}
            
            s.vel += flow * dt * 0.56
            s.pos += s.vel * dt
            s.vel *= math.pow(0.97, dt * 60)
            s.life -= dt * 0.6
            
            if enable_trails {
                append(&s.trail, s.pos)
                for len(s.trail) > trail_length + 12 {
                    ordered_remove(&s.trail, 0)
                }
            }
        }
        // Remove dead smoke
        for i := len(smoke) - 1; i >= 0; i -= 1 {
            if smoke[i].life <= 0 {
                delete(smoke[i].trail)
                ordered_remove(&smoke, i)
            }
        }
        // Update spirographs
        if enable_spiro {
            for &sp in spiros {
                sp.a += sp.da * dt * 60 * 0.02
                sp.b += sp.db * dt * 60 * 0.02
                sp.rot += (mouse_rotate_accum * 0.0015) * (paused ? 0 : 1)
            }
        }
        // Update star layers for parallax
        for l in 0..<LAYERS {
            for &star in layers[l] {
                star.z -= speeds[l] * dt * (0.5 + audio_level * (0.5 + f32(l)*0.1))
                if star.z <= 0.5 {
                    star.x = randf(-W/2, W/2)
                    star.y = randf(-H/2, H/2)
                    star.z = randf(0.5, W)
                }
            }
        }
        rl.BeginTextureMode(accum)
        rl.DrawRectangle(0, 0, W, H, rl.Fade(rl.BLACK, 0.14))
        rl.BeginMode2D(cam)
        
        // Background gradient with current palette
        pal := palettes[palette_index % len(palettes)]
        for i in 0..<6 {
            p := f32(i) / 5
            bg := pal[i % len(pal)]
            bg.a = u8(20 + int(p * 60))
            rl.DrawRectangle(0, i32(p*H), W, i32(H/6)+2, bg)
        }
        // Draw star layers (far to near)
        for l in 0..<LAYERS {
            for star in layers[l] {
                k := 256 / max(star.z, 0.0001)
                sx := star.x * k + W/2
                sy := star.y * k + H/2
                if sx < -50 || sx > W+50 || sy < -50 || sy > H+50 do continue
                
                shade := u8(clamp((1 - star.z / W) * 255 * star.brightness, 0, 255))
                rl.DrawPixel(i32(sx), i32(sy), {shade, shade, shade, 255})
            }
        }
        // Draw spirographs
        if enable_spiro {
            for sp, idx in spiros {
                col := sp.col
                phase := t * (0.3 + f32(idx) * 0.05) + sp.rot
                prev := rl.Vector2{W/2, H/2}
                first := true
                
                for i in 0..<600 {
                    u := f32(i) / 600
                    theta := u * PI * 8 + phase
                    x := math.cos(sp.a * theta) * sp.scale * (1 + 0.25 * math.sin(t*0.2 + f32(idx)))
                    y := math.sin(sp.b * theta) * sp.scale * (1 + 0.25 * math.cos(t*0.2 + f32(idx)))
                    p := rl.Vector2{W/2 + x, H/2 + y}
                    
                    if !first {
                        rl.DrawLineEx(prev, p, 1.2 + f32(idx)*0.02, rl.Fade(col, 0.9))
                    }
                    prev = p
                    first = false
                }
            }
        }
        // Draw smoke with trails
        if enable_smoke {
            for s in smoke {
                c := s.col
                c.a = u8(clamp(255 * (s.life/6), 0, 255))
                
                if enable_trails && len(s.trail) > 1 {
                    alpha_step := 1 / f32(len(s.trail))
                    alpha_acc:f32 = 1
                    for pt in s.trail {
                        tc := c
                        tc.a = u8(f32(tc.a) * alpha_acc)
                        rl.DrawCircleV(pt, s.size * 0.6, tc)
                        alpha_acc -= alpha_step
                    }
                } else {
                    rl.DrawCircleV(s.pos, s.size, c)
                }
            }
        }
        // Draw main particles and trails
        for p in particles {
            c := p.col
            c.a = u8(255 * clamp(p.life / 3, 0, 1))
            
            if enable_trails && len(p.trail) > 1 {
                step := 1 / f32(len(p.trail))
                alpha:f32 = 1
                for pt in p.trail {
                    tc := c
                    tc.a = u8(f32(tc.a) * alpha * 0.9)
                    rl.DrawCircleV(pt, p.size * (0.6 + 0.4*alpha), tc)
                    alpha -= step
                }
            }
            rl.DrawCircleV(p.pos, p.size + 0.6, c)
        }
        // Rotating layered polygons
        for i in 0..<7 {
            rr := 90 + f32(i) * 18 + 20 * math.sin(t * (0.4 + 0.1*f32(i)))
            rot := t * (20 + f32(i)*6) * (1 + 0.3*audio_level) + mouse_rotate_accum * 0.002
            c := color_from_hsv_f(math.mod(360 * (f32(i)/7 + t*0.02), 360), 0.7, 0.9)
            rl.DrawPoly({W/2, H/2}, 6, rr, rot, rl.Fade(c, 0.85))
        }
        rl.EndMode2D()
        rl.EndTextureMode()
        if enable_glow {
            rl.BeginTextureMode(glow)
            rl.DrawTexturePro(
                accum.texture,
                {0, 0, f32(accum.texture.width), -f32(accum.texture.height)},
                {0, 0, f32(glow.texture.width), f32(glow.texture.height)},
                {0, 0}, 0, rl.WHITE,
            )
            // Multi-pass blur-like additive
            for i in 0..<4 {
                off := 1 + f32(i) * 1.8
                rl.DrawTexturePro(
                    glow.texture,
                    {0, 0, f32(glow.texture.width), -f32(glow.texture.height)},
                    {off, 0, f32(glow.texture.width), f32(glow.texture.height)},
                    {0, 0}, 0, rl.Fade(rl.WHITE, 0.12),
                )
                rl.DrawTexturePro(
                    glow.texture,
                    {0, 0, f32(glow.texture.width), -f32(glow.texture.height)},
                    {-off, 0, f32(glow.texture.width), f32(glow.texture.height)},
                    {0, 0}, 0, rl.Fade(rl.WHITE, 0.12),
                )
            }
            rl.EndTextureMode()
        }
        rl.BeginDrawing()
        rl.ClearBackground(rl.BLACK)
        
        // Camera shake jitter
        jitter := rl.Vector2{randf(-cam_shake, cam_shake) * 0.6, randf(-cam_shake, cam_shake) * 0.6}
        rl.DrawTextureRec(
            accum.texture,
            {0, 0, f32(accum.texture.width), -f32(accum.texture.height)},
            jitter, rl.WHITE,
        )
        if enable_glow {
            rl.BeginBlendMode(.ADDITIVE)
            rl.DrawTexturePro(
                glow.texture,
                {0, 0, f32(glow.texture.width), -f32(glow.texture.height)},
                {0, 0, W, H},
                {0, 0}, 0, {255, 255, 255, 220},
            )
            rl.EndBlendMode()
        }
        // Subtle vignette
        rl.DrawRectangleGradientV(0, 0, W, H/2, rl.Fade(rl.BLACK, 0), rl.Fade(rl.BLACK, 0.06))
        rl.DrawRectangleGradientV(0, H/2, W, H/2, rl.Fade(rl.BLACK, 0.06), rl.Fade(rl.BLACK, 0))
        
        // HUD
        rl.DrawText(help_text, 12, 12, 14, rl.Fade(rl.RAYWHITE, 0.95))
        
        info := fmt.ctprintf(
            "Particles: %d  Smoke: %d  Spiro: %s  Glow: %s  TrailsLen: %d  Mode: %d  Wind: %s  GravityWell: %s  Palette: %d",
            len(particles), len(smoke),
            enable_spiro ? "ON" : "OFF",
            enable_glow ? "ON" : "OFF",
            trail_length, particle_color_mode,
            enable_wind ? "ON" : "OFF",
            gravity_well ? "ON" : "OFF",
            palette_index,
        )
        rl.DrawText(info, 12, 32, 14, rl.RAYWHITE)
        
        if show_debug {
            rl.DrawTextureEx(accum.texture, {10, 70}, 0, 0.12, rl.WHITE)
            if enable_glow {
                rl.DrawTextureEx(glow.texture, {10, 70 + 120}, 0, 0.38, rl.WHITE)
            }
        }
        if show_fps {
            rl.DrawFPS(W - 80, 12)
        }
        rl.EndDrawing()
        
        // Trim particle pools if needed
        if len(particles) > max_particles {
            excess := len(particles) - max_particles
            for i in 0..<excess {
                delete(particles[i].trail)
            }
            copy(particles[0:], particles[excess:])
            resize(&particles, len(particles) - excess)
        }
        if len(smoke) > max_smoke {
            excess := len(smoke) - max_smoke
            for i in 0..<excess {
                delete(smoke[i].trail)
            }
            copy(smoke[0:], smoke[excess:])
            resize(&smoke, len(smoke) - excess)
        }
    }
    for &p in particles do delete(p.trail)
    for &s in smoke do delete(s.trail)
    delete(particles)
    delete(smoke)
    for &spiro in spiros do spiro = {}
    delete(spiros)
    for l in 0..<LAYERS do delete(layers[l])
    rl.UnloadRenderTexture(accum)
    rl.UnloadRenderTexture(glow)
    rl.CloseWindow()
}