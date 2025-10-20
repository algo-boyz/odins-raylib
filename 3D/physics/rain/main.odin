package main

import "core:math"
import "core:math/rand"
import "core:slice"
import rl "vendor:raylib"
import "vendor:raylib/rlgl"

WIDTH :: 1280
HEIGHT :: 720
NUM_DROPS :: 3000
RAIN_AREA_SIZE :: 50.0
BASE_RAIN_SPEED :: 0.8
DROP_LENGTH :: 0.4
GROUND_LEVEL :: 0.0
WIND_VELOCITY :: rl.Vector3{0.1, 0.0, 0.04}
NUM_SPLASH_PARTICLES :: 8
SPLASH_LIFETIME :: 0.3
SPLASH_VELOCITY :: 2.0
SPLASH_GRAVITY :: -5.0
WATER_WIDTH :: RAIN_AREA_SIZE * 1.5
WATER_DEPTH :: RAIN_AREA_SIZE * 1.5
WATER_DIVISIONS_X :: 60
WATER_DIVISIONS_Z :: 60
MAX_RIPPLES :: 30

WaterRipple :: struct {
    center: rl.Vector2,
    start_time: f32,
    strength: f32,
    max_radius: f32,
    duration: f32,
    wavelength: f32,
    active: bool,
}

RainDrop :: struct {
    pos: rl.Vector3,
    velocity: rl.Vector3,
    color: rl.Color,
    speed_variation: f32,
}

SplashParticle :: struct {
    pos: rl.Vector3,
    velocity: rl.Vector3,
    color: rl.Color,
    life_left: f32,
}

GameState :: struct {
    water_mesh: rl.Mesh,
    water_model: rl.Model,
    water_ripples: [MAX_RIPPLES]WaterRipple,
    icube_model: rl.Model,
    icube_pos: rl.Vector3,
    icube_size: f32,
    icube_color: rl.Color,
    icube_bobble_time: f32,
    raindrops: [NUM_DROPS]RainDrop,
    splashes: [dynamic]SplashParticle,
    skybox_model: rl.Model,
    skybox_texture: rl.TextureCubemap,
}

get_random_float :: proc(min, max: f32) -> f32 {
    return rand.float32_range(min, max)
}

create_splash :: proc(splashes: ^[dynamic]SplashParticle, impact_pos: rl.Vector3, base_color: rl.Color) {
    for i in 0..<NUM_SPLASH_PARTICLES {
        p := SplashParticle{
            pos = impact_pos,
            velocity = {
                get_random_float(-SPLASH_VELOCITY, SPLASH_VELOCITY) * 0.5,
                get_random_float(0.5, 1.0) * SPLASH_VELOCITY,
                get_random_float(-SPLASH_VELOCITY, SPLASH_VELOCITY) * 0.5,
            },
            color = rl.Fade(base_color, 0.7),
            life_left = SPLASH_LIFETIME,
        }
        append(splashes, p)
    }
}

init_game_state :: proc(state: ^GameState) {
    // Init skybox
    sky_img := rl.GenImageGradientLinear(
        WIDTH, HEIGHT, 0,
        rl.Color{15, 20, 25, 255},
        rl.Color{40, 50, 60, 255}
    )
    state.skybox_texture = rl.LoadTextureCubemap(sky_img, rl.CubemapLayout.AUTO_DETECT)
    rl.UnloadImage(sky_img)
    
    unit_cube_mesh := rl.GenMeshCube(1.0, 1.0, 1.0)
    state.skybox_model = rl.LoadModelFromMesh(unit_cube_mesh)
    state.skybox_model.materials[0].maps[rl.MaterialMapIndex.CUBEMAP].texture = state.skybox_texture
    
    // Init interactive cube
    state.icube_model = rl.LoadModelFromMesh(unit_cube_mesh)
    state.icube_size = 5.0
    state.icube_color = rl.RED
    state.icube_model.materials[0].maps[rl.MaterialMapIndex.ALBEDO].color = state.icube_color
    state.icube_pos = {0.0, GROUND_LEVEL + state.icube_size / 2.0 + 1.0, 0.0}
    
    // Init water
    state.water_mesh = rl.GenMeshPlane(WATER_WIDTH, WATER_DEPTH, WATER_DIVISIONS_X, WATER_DIVISIONS_Z)
    state.water_model = rl.LoadModelFromMesh(state.water_mesh)
    state.water_model.materials[0].maps[rl.MaterialMapIndex.ALBEDO].color = {60, 100, 150, 200}
    
    // Init water ripples
    for &ripple in state.water_ripples {
        ripple.active = false
    }
    
    // Init raindrops
    for &drop in state.raindrops {
        drop.pos = {
            get_random_float(-RAIN_AREA_SIZE / 2.0, RAIN_AREA_SIZE / 2.0),
            get_random_float(GROUND_LEVEL + 5.0, RAIN_AREA_SIZE * 1.5),
            get_random_float(-RAIN_AREA_SIZE / 2.0, RAIN_AREA_SIZE / 2.0),
        }
        drop.speed_variation = get_random_float(0.8, 1.2)
        drop.velocity = {
            WIND_VELOCITY.x,
            (-BASE_RAIN_SPEED * drop.speed_variation) + WIND_VELOCITY.y,
            WIND_VELOCITY.z,
        }
        base_val := u8(get_random_float(100.0, 180.0))
        drop.color = {base_val, base_val, base_val + 10, 200}
    }
    
    // Init splash particles array
    state.splashes = make([dynamic]SplashParticle, 0, NUM_DROPS * NUM_SPLASH_PARTICLES / 10)
}

update_game_state :: proc(state: ^GameState, dt: f32, current_time: f32) {
    // Update interactive cube bobbing motion
    state.icube_bobble_time += dt
    state.icube_pos.x = math.cos(state.icube_bobble_time * 0.4) * (RAIN_AREA_SIZE / 3.5)
    state.icube_pos.z = math.sin(state.icube_bobble_time * 0.4) * (RAIN_AREA_SIZE / 3.5)
    state.icube_pos.y = GROUND_LEVEL + state.icube_size / 2.0 + 0.5 + 
                        math.sin(state.icube_bobble_time * 0.6) * 2.0
    
    // Update raindrops
    for &drop in state.raindrops {
        drop.pos += drop.velocity * dt * 60.0
        
        if drop.pos.y < GROUND_LEVEL {
            impact_pos := rl.Vector3{drop.pos.x, GROUND_LEVEL, drop.pos.z}
            create_splash(&state.splashes, impact_pos, drop.color)
            
            // Create water ripple
            for &ripple in state.water_ripples {
                if !ripple.active {
                    ripple.active = true
                    ripple.center = {impact_pos.x, impact_pos.z}
                    ripple.start_time = current_time
                    ripple.strength = get_random_float(0.15, 0.3)
                    ripple.max_radius = get_random_float(3.0, 5.0)
                    ripple.duration = get_random_float(2.0, 3.5)
                    ripple.wavelength = get_random_float(0.5, 1.0)
                    break
                }
            }
            
            // Reset raindrop position
            drop.pos = {
                get_random_float(-RAIN_AREA_SIZE / 2.0, RAIN_AREA_SIZE / 2.0),
                RAIN_AREA_SIZE + get_random_float(0.0, RAIN_AREA_SIZE * 0.5),
                get_random_float(-RAIN_AREA_SIZE / 2.0, RAIN_AREA_SIZE / 2.0),
            }
        }
    }
    
    // Update splash particles
    for i := len(state.splashes) - 1; i >= 0; i -= 1 {
        state.splashes[i].life_left -= dt
        if state.splashes[i].life_left <= 0 {
            ordered_remove(&state.splashes, i)
        } else {
            state.splashes[i].velocity.y += SPLASH_GRAVITY * dt
            state.splashes[i].pos += state.splashes[i].velocity * dt
            life_ratio := state.splashes[i].life_left / SPLASH_LIFETIME
            state.splashes[i].color.a = u8(255.0 * life_ratio)
        }
    }
    
    // Update water mesh vertices
    vertices := cast([^]f32)state.water_mesh.vertices
    for i in 0..<state.water_mesh.vertexCount {
        vx := vertices[i * 3 + 0]
        vz := vertices[i * 3 + 2]
        
        // Base water animation
        dynamic_water_height:f32 = GROUND_LEVEL
        dynamic_water_height += 0.3 * math.sin(vx * 0.3 + current_time * 1.5)
        dynamic_water_height += 0.25 * math.cos(vz * 0.25 + current_time * 1.1)
        
        // Add ripple effects
        for &ripple in state.water_ripples {
            if ripple.active {
                age := current_time - ripple.start_time
                if age > ripple.duration {
                    ripple.active = false
                    continue
                }
                
                dist_to_center := rl.Vector2Distance({vx, vz}, ripple.center)
                strength_factor := ripple.strength * (1.0 - age / ripple.duration)
                propagation_speed := ripple.max_radius / ripple.duration
                current_wave_front_radius := propagation_speed * age
                wave_packet_offset := dist_to_center - current_wave_front_radius
                envelope_width_factor := f32(1.5)
                
                if abs(wave_packet_offset) < ripple.wavelength * envelope_width_factor {
                    phase := wave_packet_offset / ripple.wavelength * 2.0 * math.PI
                    ripple_val := math.sin(phase)
                    envelope := math.exp(-math.pow(wave_packet_offset / (ripple.wavelength * 0.8), 2.0))
                    dynamic_water_height += strength_factor * ripple_val * envelope
                }
            }
        }
        
        // Add cube wake effect
        dist_to_icube_xz := rl.Vector2Distance({vx, vz}, {state.icube_pos.x, state.icube_pos.z})
        c_wake_rad := state.icube_size * 1.5
        c_wake_str := f32(0.1)
        c_wake_wave_len := f32(2.5)
        c_wake_spd := f32(2.0)
        
        if dist_to_icube_xz < c_wake_rad && dist_to_icube_xz > state.icube_size * 0.3 {
            normalized_dist := dist_to_icube_xz / c_wake_rad
            falloff := (1.0 - normalized_dist) * (1.0 - normalized_dist)
            phase := (dist_to_icube_xz / c_wake_wave_len) - (current_time * c_wake_spd / c_wake_wave_len)
            dynamic_water_height += math.sin(phase * 2.0 * math.PI) * c_wake_str * falloff
        }
        
        // Handle cube displacement
        icube_bottom_y := state.icube_pos.y - state.icube_size / 2.0
        is_under_icube_xz := (vx >= state.icube_pos.x - state.icube_size / 2.0 &&
                              vx <= state.icube_pos.x + state.icube_size / 2.0 &&
                              vz >= state.icube_pos.z - state.icube_size / 2.0 &&
                              vz <= state.icube_pos.z + state.icube_size / 2.0)
        
        if is_under_icube_xz && icube_bottom_y < dynamic_water_height {
            dynamic_water_height = icube_bottom_y
        }
        
        vertices[i * 3 + 1] = dynamic_water_height
    }
    
    rl.UpdateMeshBuffer(state.water_mesh, 0, state.water_mesh.vertices, 
                        state.water_mesh.vertexCount * 3 * size_of(f32), 0)
}

render_game :: proc(state: ^GameState, camera: rl.Camera) {
    rl.BeginDrawing()
    rl.ClearBackground(rl.BLACK)
    
    rl.BeginMode3D(camera)
    
    // Draw skybox
    rlgl.DisableBackfaceCulling()
    rlgl.DisableDepthMask()
    rl.DrawModel(state.skybox_model, {0, 0, 0}, 1.0, rl.WHITE)
    rlgl.EnableDepthMask()
    rlgl.EnableBackfaceCulling()
    
    // Draw water
    rl.DrawModel(state.water_model, {0, 0, 0}, 1.0, rl.WHITE)
    
    // Draw interactive cube
    rl.DrawModelEx(state.icube_model, state.icube_pos, {0, 1, 0}, 0.0,
                   {state.icube_size, state.icube_size, state.icube_size}, rl.WHITE)
    
    // Draw raindrops
    for drop in state.raindrops {
        vel_dir := rl.Vector3Normalize(drop.velocity)
        drop_end_pos := drop.pos + vel_dir * (-DROP_LENGTH)
        
        dist := rl.Vector3Distance(drop.pos, camera.position)
        fade_start_dist := f32(RAIN_AREA_SIZE * 0.5)
        fade_end_dist := f32(RAIN_AREA_SIZE * 1.5)
        alpha := f32(1.0)
        
        if dist > fade_start_dist {
            alpha = 1.0 - (dist - fade_start_dist) / (fade_end_dist - fade_start_dist)
            alpha = rl.Clamp(alpha, 0.0, 1.0)
        }
        
        drop_color := drop.color
        drop_color.a = u8(f32(drop.color.a) * alpha)
        rl.DrawLine3D(drop.pos, drop_end_pos, drop_color)
    }
    
    // Draw splash particles
    for particle in state.splashes {
        rl.DrawPoint3D(particle.pos, particle.color)
    }
    
    rl.EndMode3D()
    
    // Draw UI
    rl.DrawFPS(10, 10)
    rl.DrawText("Drag mouse to orbit camera", 10, 40, 20, rl.LIME)
    rl.DrawText(rl.TextFormat("Splashes: %d", len(state.splashes)), 10, 70, 20, rl.LIME)
    
    active_ripples := 0
    for ripple in state.water_ripples {
        if ripple.active do active_ripples += 1
    }
    rl.DrawText(rl.TextFormat("Active Ripples: %d/%d", active_ripples, MAX_RIPPLES), 10, 100, 20, rl.LIME)
    
    rl.EndDrawing()
}

cleanup_game :: proc(state: ^GameState) {
    rl.UnloadTexture(state.skybox_texture)
    rl.UnloadModel(state.skybox_model)
    rl.UnloadModel(state.icube_model)
    rl.UnloadModel(state.water_model)
    delete(state.splashes)
}

main :: proc() {
    rl.InitWindow(WIDTH, HEIGHT, "Stormy Sim with Interactive Cube")
    rl.SetConfigFlags({.MSAA_4X_HINT})
    
    camera := rl.Camera{
        position = {25.0, 15.0, 25.0},
        target = {0.0, 3.0, 0.0},
        up = {0.0, 1.0, 0.0},
        fovy = 45.0,
        projection = .PERSPECTIVE,
    }
    
    state := GameState{}
    init_game_state(&state)
    
    rl.SetTargetFPS(60)
    
    for !rl.WindowShouldClose() {
        dt := rl.GetFrameTime()
        current_time := rl.GetTime()
        
        rl.UpdateCamera(&camera, .ORBITAL)
        update_game_state(&state, dt, f32(current_time))
        render_game(&state, camera)
    }
    
    cleanup_game(&state)
    rl.CloseWindow()
}