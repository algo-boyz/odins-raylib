package audio

import "vendor:raylib"
import "core:math"

MAX_CIRCLES :: 128
MAX_PARTICLES :: 256

CircleWave :: struct {
    position: raylib.Vector2,
    radius: f32,
    alpha: f32,
    speed: f32,
    color: raylib.Color,
    pulse_phase: f32,
    rotation: f32,
    trail_positions: [8]raylib.Vector2,
    trail_index: int,
}

Particle :: struct {
    position: raylib.Vector2,
    velocity: raylib.Vector2,
    life: f32,
    color: raylib.Color,
    size: f32,
}

main :: proc() {
    using raylib

    screenWidth  :: 1200
    screenHeight :: 800

    SetConfigFlags({.MSAA_4X_HINT, .VSYNC_HINT})

    InitWindow(screenWidth, screenHeight, "Audio Visualizer")
    defer CloseWindow()

    InitAudioDevice()
    defer CloseAudioDevice()

    // Enhanced color palette with gradients
    colors: [16]Color = {
        Color{255, 79, 79, 255},   // Coral Red
        Color{255, 149, 0, 255},   // Orange
        Color{255, 193, 7, 255},   // Amber
        Color{139, 195, 74, 255},  // Light Green
        Color{0, 188, 212, 255},   // Cyan
        Color{63, 81, 181, 255},   // Indigo
        Color{156, 39, 176, 255},  // Purple
        Color{233, 30, 99, 255},   // Pink
        Color{255, 235, 59, 255},  // Yellow
        Color{76, 175, 80, 255},   // Green
        Color{33, 150, 243, 255},  // Blue
        Color{103, 58, 183, 255},  // Deep Purple
        Color{255, 87, 34, 255},   // Deep Orange
        Color{0, 150, 136, 255},   // Teal
        Color{121, 85, 72, 255},   // Brown
        Color{96, 125, 139, 255},  // Blue Grey
    }

    circles: [MAX_CIRCLES]CircleWave
    particles: [MAX_PARTICLES]Particle

    // Initialize circles with enhanced properties
    for i := MAX_CIRCLES-1; i >= 0; i -= 1 {
        circles[i].alpha = 0
        circles[i].radius = f32(GetRandomValue(5, 25))
        circles[i].position.x = f32(GetRandomValue(i32(circles[i].radius), screenWidth - i32(circles[i].radius)))
        circles[i].position.y = f32(GetRandomValue(i32(circles[i].radius), screenHeight - i32(circles[i].radius)))
        circles[i].speed = f32(GetRandomValue(50, 200)) / 10000
        circles[i].color = colors[GetRandomValue(0, 15)]
        circles[i].pulse_phase = f32(GetRandomValue(0, 628)) / 100 // Random phase for pulsing
        circles[i].rotation = 0
        circles[i].trail_index = 0
    }

    // Initialize particles
    for i := 0; i < MAX_PARTICLES; i += 1 {
        particles[i].life = 0
    }

    music := LoadMusicStream("../mini.xm")
    defer UnloadMusicStream(music)
    music.looping = false
    pitch: f32 = 1

    PlayMusicStream(music)

    timePlayed: f32 = 0
    pause := false
    frame_count: f32 = 0
    bg_hue: f32 = 0

    SetTargetFPS(60)

    for !WindowShouldClose() {
        UpdateMusicStream(music)
        frame_count += 1
        bg_hue += 0.5

        if IsKeyPressed(.SPACE) {
            StopMusicStream(music)
            PlayMusicStream(music)
            pause = false
        }

        if IsKeyPressed(.P) {
            pause = !pause
            if pause {
                PauseMusicStream(music)
            } else {
                ResumeMusicStream(music)
            }
        }

        if IsKeyDown(.DOWN) {
            pitch -= 0.01
        } else if IsKeyDown(.UP) {
            pitch += 0.01
        }

        SetMusicPitch(music, pitch)
        timePlayed = GetMusicTimePlayed(music) / GetMusicTimeLength(music) * f32(screenWidth - 60)

        // Update circles with enhanced animations
        for i := MAX_CIRCLES-1; (i >= 0) && !pause; i -= 1 {
            circles[i].alpha += circles[i].speed
            circles[i].pulse_phase += 0.1
            circles[i].rotation += circles[i].speed * 50
            
            // Pulsing effect
            pulse_factor := 1.0 + 0.3 * math.sin(circles[i].pulse_phase)
            circles[i].radius += circles[i].speed * 15 * pulse_factor

            // Update trail
            if int(frame_count) % 3 == 0 {
                circles[i].trail_positions[circles[i].trail_index] = circles[i].position
                circles[i].trail_index = (circles[i].trail_index + 1) % len(circles[i].trail_positions)
            }

            if circles[i].alpha > 1 {
                circles[i].speed *= -1
                
                // Spawn particles when circle reaches peak
                for j := 0; j < 5; j += 1 {
                    for k := 0; k < MAX_PARTICLES; k += 1 {
                        if particles[k].life <= 0 {
                            particles[k].position = circles[i].position
                            angle := f32(GetRandomValue(0, 628)) / 100
                            speed := f32(GetRandomValue(50, 150))
                            particles[k].velocity = Vector2{math.cos(angle) * speed, math.sin(angle) * speed}
                            particles[k].life = f32(GetRandomValue(60, 120))
                            particles[k].color = circles[i].color
                            particles[k].size = f32(GetRandomValue(2, 6))
                            break
                        }
                    }
                }
            }

            if circles[i].alpha <= 0 {
                circles[i].alpha = 0
                circles[i].radius = f32(GetRandomValue(5, 25))
                circles[i].position.x = f32(GetRandomValue(i32(circles[i].radius), screenWidth - i32(circles[i].radius)))
                circles[i].position.y = f32(GetRandomValue(i32(circles[i].radius), screenHeight - i32(circles[i].radius)))
                circles[i].speed = f32(GetRandomValue(50, 200)) / 10000
                circles[i].color = colors[GetRandomValue(0, 15)]
                circles[i].pulse_phase = f32(GetRandomValue(0, 628)) / 100
            }
        }

        // Update particles
        for i := 0; i < MAX_PARTICLES; i += 1 {
            if particles[i].life > 0 {
                particles[i].position.x += particles[i].velocity.x * GetFrameTime()
                particles[i].position.y += particles[i].velocity.y * GetFrameTime()
                particles[i].velocity.x *= 0.98 // Friction
                particles[i].velocity.y *= 0.98
                particles[i].life -= 1
                particles[i].size *= 0.995
            }
        }

        {
            BeginDrawing()
            defer EndDrawing()

            // Animated background
            bg_color := ColorFromHSV(math.mod(bg_hue, 360), 0.1, 0.05)
            ClearBackground(bg_color)

            // Draw connection lines between nearby circles
            for i := 0; i < MAX_CIRCLES; i += 1 {
                if circles[i].alpha <= 0 do continue
                for j := i + 1; j < MAX_CIRCLES; j += 1 {
                    if circles[j].alpha <= 0 do continue
                    
                    dist := Vector2Distance(circles[i].position, circles[j].position)
                    if dist < 150 {
                        line_alpha := (150 - dist) / 150 * 0.3
                        line_color := Fade(WHITE, line_alpha)
                        DrawLineV(circles[i].position, circles[j].position, line_color)
                    }
                }
            }

            // Draw circle trails
            for i := MAX_CIRCLES-1; i >= 0; i -= 1 {
                if circles[i].alpha <= 0 do continue
                
                for j := 0; j < len(circles[i].trail_positions); j += 1 {
                    trail_alpha := f32(j) / f32(len(circles[i].trail_positions)) * circles[i].alpha * 0.3
                    trail_size := circles[i].radius * 0.3 * (f32(j) / f32(len(circles[i].trail_positions)))
                    if trail_size > 0 {
                        DrawCircleV(circles[i].trail_positions[j], trail_size, Fade(circles[i].color, trail_alpha))
                    }
                }
            }

            // Draw main circles with glow effect
            for i := MAX_CIRCLES-1; i >= 0; i -= 1 {
                if circles[i].alpha <= 0 do continue
                
                // Outer glow
                glow_radius := circles[i].radius * 1.5
                glow_color := Fade(circles[i].color, circles[i].alpha * 0.2)
                DrawCircleV(circles[i].position, glow_radius, glow_color)
                
                // Main circle
                DrawCircleV(circles[i].position, circles[i].radius, Fade(circles[i].color, circles[i].alpha))
                
                // Inner highlight
                highlight_radius := circles[i].radius * 0.3
                highlight_color := Fade(WHITE, circles[i].alpha * 0.8)
                DrawCircleV(circles[i].position, highlight_radius, highlight_color)
            }

            // Draw particles
            for i := 0; i < MAX_PARTICLES; i += 1 {
                if particles[i].life > 0 {
                    particle_alpha := particles[i].life / 120.0
                    DrawCircleV(particles[i].position, particles[i].size, Fade(particles[i].color, particle_alpha))
                }
            }

            // Enhanced progress bar with glow
            bar_y := screenHeight - 40
            bar_height := 20
            
            // Progress bar background with rounded corners
            DrawRectangleRounded(Rectangle{30, f32(bar_y), f32(screenWidth - 60), f32(bar_height)}, 0.5, 8, Color{40, 40, 40, 180})
            
            // Progress fill with gradient effect
            if timePlayed > 0 {
                progress_color := ColorFromHSV(math.mod(bg_hue * 2, 360), 0.8, 0.9)
                DrawRectangleRounded(Rectangle{30, f32(bar_y), timePlayed, f32(bar_height)}, 0.5, 8, progress_color)
                
                // Progress glow
                glow_color := Fade(progress_color, 0.3)
                DrawRectangleRounded(Rectangle{25, f32(bar_y - 5), timePlayed + 10, f32(bar_height + 10)}, 0.5, 8, glow_color)
            }

            // Modern UI panel
            panel_color := Color{20, 20, 30, 200}
            DrawRectangleRounded(Rectangle{30, 30, 450, 180}, 0.1, 8, panel_color)
            DrawRectangleRoundedLines(Rectangle{30, 30, 450, 180}, 0.1, 8, Color{100, 100, 120, 255})
            
            // UI Text with better styling
            DrawText("♪ SPACE - Restart Music", 50, 55, 18, Color{200, 200, 220, 255})
            DrawText("⏸ P - Pause/Resume", 50, 80, 18, Color{200, 200, 220, 255})
            DrawText("↕ UP/DOWN - Change Speed", 50, 105, 18, Color{200, 200, 220, 255})
            DrawText("✦ ESC - Exit", 50, 130, 18, Color{200, 200, 220, 255})
            
            speed_text := TextFormat("Speed: %.2f", pitch)
            speed_color := pitch > 1 ? Color{255, 100, 100, 255} : pitch < 1 ? Color{100, 255, 100, 255} : Color{255, 255, 100, 255}
            DrawText(speed_text, 50, 160, 20, speed_color)

            // Add FPS counter
            fps_text := TextFormat("FPS: %d", GetFPS())
            DrawText(fps_text, screenWidth - 100, 20, 16, Color{150, 150, 150, 255})
        }
    }
}