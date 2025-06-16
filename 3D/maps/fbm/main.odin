package main

import "core:math"
import "core:math/rand"
import rl "vendor:raylib"

WINDOW_WIDTH :: 600
WINDOW_HEIGHT :: 450
TERRAIN_SIZE :: 128
CUBE_SIZE :: 0.5
INITIAL_WATER_LEVEL :f32 = 10.0

fade :: proc(t: f32) -> f32 {
    return t * t * t * (t * (t * 6 - 15) + 10)
}

lerp :: proc(t, a, b: f32) -> f32 {
    return a + t * (b - a)
}

grad :: proc(hash: i32, x, y, z: f32) -> f32 {
    h := hash & 15
    u := x if h < 8 else y
    v := y if h < 4 else x if h == 12 || h == 14 else z
    return (u if (h & 1) == 0 else -u) + (v if (h & 2) == 0 else -v)
}

noise :: proc(x, y, z: f32, p: []i32) -> f32 {
    X := u8(int(x)) & 255
    Y := u8(int(y)) & 255
    Z := u8(int(z)) & 255
    x_floor := x - math.floor(x)
    y_floor := y - math.floor(y)
    z_floor := z - math.floor(z)
    u := fade(x_floor)
    v := fade(y_floor)
    w := fade(z_floor)

    A := u8(p[X]) + Y
    AA := u8(p[A]) + Z
    AB := u8(p[A + 1]) + Z
    B := u8(p[X + 1]) + Y
    BA := u8(p[B]) + Z
    BB := u8(p[B + 1]) + Z

    return lerp(w,
        lerp(v,
            lerp(u,
                grad(p[AA], x_floor, y_floor, z_floor),
                grad(p[BA], x_floor - 1, y_floor, z_floor)),
            lerp(u,
                grad(p[AB], x_floor, y_floor - 1, z_floor),
                grad(p[BB], x_floor - 1, y_floor - 1, z_floor))),
        lerp(v,
            lerp(u,
                grad(p[AA + 1], x_floor, y_floor, z_floor - 1),
                grad(p[BA + 1], x_floor - 1, y_floor, z_floor - 1)),
            lerp(u,
                grad(p[AB + 1], x_floor, y_floor - 1, z_floor - 1),
                grad(p[BB + 1], x_floor - 1, y_floor - 1, z_floor - 1))))
}

generate_permutation :: proc(seed: i32) -> []i32 {
    perm := make([]i32, 512)
    source := make([]i32, 256)
    defer delete(source)

    for i := 0; i < 256; i += 1 {
        source[i] = i32(i)
    }

    r := rand.create(u64(seed))
    for i := 255; i > 0; i -= 1 {
        j := rand.int_max(i + 1)
        temp := source[i]
        source[i] = source[j]
        source[j] = temp
    }

    for i := 0; i < 512; i += 1 {
        perm[i] = source[i % 256]
    }

    return perm
}

fbm :: proc(x, y: f32, octaves: u32, persistence, lacunarity, scale: f32, p: []i32) -> f32 {
    value, amplitude, frequency := f32(0), f32(1), f32(1)

    for i := u32(0); i < octaves; i += 1 {
        value += amplitude * noise(x * frequency / scale, y * frequency / scale, 0, p)
        amplitude *= persistence
        frequency *= lacunarity
    }

    return value
}

generate_terrain :: proc(seed: i32) -> []f32 {
    terrain := make([]f32, TERRAIN_SIZE * TERRAIN_SIZE)
    perm := generate_permutation(seed)
    defer delete(perm)

    for y := 0; y < TERRAIN_SIZE; y += 1 {
        for x := 0; x < TERRAIN_SIZE; x += 1 {
            terrain[y * TERRAIN_SIZE + x] = fbm(f32(x), f32(y), 6, 0.5, 2.0, 50.0, perm)
        }
    }

    // Normalize the terrain
    min, max := terrain[0], terrain[0]
    for value in terrain {
        min = math.min(min, value)
        max = math.max(max, value)
    }

    for i := 0; i < len(terrain); i += 1 {
        terrain[i] = (terrain[i] - min) / (max - min)
    }

    return terrain
}

main :: proc() {
    rl.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "TerrainOdin")
    defer rl.CloseWindow()

    camera_distance := f32(200.0)
    camera_angle := rl.Vector2{0.7, 0.7}
    camera := rl.Camera3D{
        position = {
            math.cos(camera_angle.y) * math.cos(camera_angle.x) * camera_distance,
            math.sin(camera_angle.x) * camera_distance,
            math.sin(camera_angle.y) * math.cos(camera_angle.x) * camera_distance,
        },
        target = {0, -20, 0},
        up = {0, 1, 0},
        fovy = 45.0,
        projection = .PERSPECTIVE,
    }

    terrain := generate_terrain(i32(rl.GetTime() * 1000000))
    defer delete(terrain)

    water_level := INITIAL_WATER_LEVEL

    rl.SetTargetFPS(60)

    for !rl.WindowShouldClose() {
        // Camera rotation
        if rl.IsMouseButtonDown(.LEFT) {
            delta := rl.GetMouseDelta()
            camera_angle.x += delta.y * 0.003
            camera_angle.y -= delta.x * 0.003
            camera_angle.x = math.clamp(camera_angle.x, -math.PI / 3.0, math.PI / 3.0)
        }

        // Camera zoom
        wheel := rl.GetMouseWheelMove()
        if wheel != 0 {
            camera_distance *= (1.0 - wheel * 0.02)
            camera_distance = math.clamp(camera_distance, 10.0, 300.0)
        }

        // Update camera position
        camera.position = {
            math.cos(camera_angle.y) * math.cos(camera_angle.x) * camera_distance,
            math.sin(camera_angle.x) * camera_distance,
            math.sin(camera_angle.y) * math.cos(camera_angle.x) * camera_distance,
        }

        // Reset camera
        if rl.IsKeyPressed(.Z) {
            camera_angle = {0.7, 0.7}
            camera_distance = 200.0
        }

        // Regenerate terrain
        if rl.IsKeyPressed(.R) || rl.IsMouseButtonPressed(.RIGHT) {
            delete(terrain)
            terrain = generate_terrain(i32(rl.GetTime() * 1000000))
        }

        // Adjust water level
        if rl.IsKeyDown(.COMMA) do water_level = math.max(0.0, water_level - 0.1)
        if rl.IsKeyDown(.PERIOD) do water_level += 0.1

        // Drawing
        rl.BeginDrawing()
        rl.ClearBackground(rl.SKYBLUE)
        rl.BeginMode3D(camera)

        // Draw terrain
        for z := 0; z < TERRAIN_SIZE; z += 1 {
            for x := 0; x < TERRAIN_SIZE; x += 1 {
                height := terrain[z * TERRAIN_SIZE + x]
                cube_height := height * 20.0
                pos := rl.Vector3{
                    f32(x) * CUBE_SIZE - f32(TERRAIN_SIZE) * CUBE_SIZE / 2,
                    cube_height / 2,
                    f32(z) * CUBE_SIZE - f32(TERRAIN_SIZE) * CUBE_SIZE / 2,
                }
                color := rl.ColorFromHSV(120 * height, 0.8, 0.8)
                if cube_height < water_level * 2 {
                    color.r = u8(f32(color.r) * 0.7)
                    color.g = u8(f32(color.g) * 0.7)
                    color.b = u8(f32(color.b) * 0.7)
                }
                rl.DrawCube(pos, CUBE_SIZE, cube_height, CUBE_SIZE, color)
            }
        }

        // Draw water
        water_size := f32(TERRAIN_SIZE) * CUBE_SIZE
        water_pos := rl.Vector3{0, water_level, 0}
        rl.DrawCube(water_pos, water_size, 0.1, water_size, rl.Fade(rl.SKYBLUE, 0.5))

        rl.DrawGrid(10, 10.0)
        rl.EndMode3D()

        // Draw UI
        rl.DrawRectangle(10, 10, 245, 162, rl.Fade(rl.RAYWHITE, 0.5))
        rl.DrawRectangleLines(10, 10, 245, 162, rl.BLUE)
        rl.DrawText("Controls:", 20, 20, 10, rl.BLACK)
        rl.DrawText("- R or Right Mouse: Regenerate terrain", 40, 40, 10, rl.BLACK)
        rl.DrawText("- , or .: Decrease/Increase water level", 40, 55, 10, rl.BLACK)
        rl.DrawText("- Left Mouse: Rotate camera", 40, 70, 10, rl.BLACK)
        rl.DrawText("- Mouse Wheel: Zoom in/out", 40, 85, 10, rl.BLACK)
        rl.DrawText("- Z: Reset camera", 40, 100, 10, rl.BLACK)
        rl.DrawText(rl.TextFormat("Camera Angle X: %.2f", camera_angle.x), 20, 120, 10, rl.BLACK)
        rl.DrawText(rl.TextFormat("Camera Angle Y: %.2f", camera_angle.y), 20, 135, 10, rl.BLACK)
        rl.DrawText(rl.TextFormat("Camera Distance: %.2f", camera_distance), 20, 150, 10, rl.BLACK)
        rl.DrawFPS(10, 180)
        rl.EndDrawing()
    }
}