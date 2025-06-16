package main

import "core:fmt"
import "core:math"

import rl "vendor:raylib"

BG_COLOR :: rl.Color{186, 149, 127, 255}
CAR_COLOR :: rl.BLACK
CAMERA_FOLLOW_OFFSET :: 400
MAX_SKIDMARKS :: 500
SKIDMARK_TIME :: 3

Skidmark :: struct {
    left_tire_x: f32,
    left_tire_y: f32,
    right_tire_x: f32,
    right_tire_y: f32,
    time: f64,
}

main :: proc() {
    width:i32 = 1300
    height:i32 = 1000
    rl.InitWindow(width, height, "Racer")
    rl.SetTargetFPS(60)

    world_width:i32 = 5000
    world_height:i32 = 5000

    soil_img := rl.LoadImage("assets/soil.png")
    rl.ImageRotateCW(&soil_img)
    soil_texture := rl.LoadTextureFromImage(soil_img)

    car_img := rl.LoadImage("assets/car.png")
    car_texture := rl.LoadTextureFromImage(car_img)
    car_texture_rec := rl.Rectangle{
        x = 0,
        y = 0,
        width = f32(car_texture.width),
        height = f32(car_texture.height),
    }

    car_width:f32 = 80.0
    car_length:f32 = 150.0
    car_x := f32(width)/2 - car_width/2
    car_y := f32(height/2) - car_length/2
    car_speed:f32
    car_max_speed:f32 = 7
    car_direction := -1
    car_angle:f32
    car_speedup:f32 = 10
    car_slowdown:f32 = 0.97

    drift_angle := car_angle
    drift_bias:f32 = 15

    steering:f32
    steering_speed:f32 = 2
    max_steering:f32 = 4
    steer_back_speed: f32 = 0.04

    skidmarks: [MAX_SKIDMARKS]Skidmark
    skidmark_count := 0

    cam := rl.Camera2D{
        offset = rl.Vector2{0, 0},
        target = rl.Vector2{0, 0},
        rotation = 0,
        zoom = 1.0,
    }
    for !rl.WindowShouldClose() {
        dt := rl.GetFrameTime()
        rl.BeginDrawing()
        rl.ClearBackground(BG_COLOR)
        rl.BeginMode2D(cam)

        tile_count_col := int(math.ceil(f32(world_width) / f32(soil_texture.width)))
        tile_count_row := int(math.ceil(f32(world_height) / f32(soil_texture.height)))

        for x in 0..<tile_count_col {
            for y in 0..<tile_count_row {
                rl.DrawTexture(soil_texture, i32(x) * soil_texture.width, i32(y) * soil_texture.height, rl.WHITE)
            }
        }
        if rl.IsKeyDown(.UP) {
            car_direction = -1
            car_speed += car_speedup * dt
            if car_speed > car_max_speed {
                car_speed = car_max_speed
            }
        } else if rl.IsKeyDown(.DOWN) {
            car_direction = 1
            car_speed -= car_speedup * dt
            if car_speed > car_max_speed {
                car_speed = car_max_speed
            }
        } else {
            car_speed *= car_slowdown
        }
        if rl.IsKeyDown(.LEFT) {
            steering -= steering_speed * dt * abs(car_speed)
            if steering < -max_steering {
                steering = -max_steering
            }
        } else if rl.IsKeyDown(.RIGHT) {
            steering += steering_speed * dt * abs(car_speed)
            if steering > max_steering {
                steering = max_steering
            }
        }
        steering *= (1 - steer_back_speed)
        car_angle += steering
        drift_angle = (car_angle + drift_angle * drift_bias) / (1 + drift_bias)
        drift_diff := drift_angle - car_angle
        drifting := abs(drift_diff) > 30
        // Move car forward
        radians := math.PI * (car_angle - 90) / 180
        car_x += car_speed * math.cos(radians)
        car_y += car_speed * math.sin(radians)
        // Move car to direction of drift
        radians = math.PI * (drift_angle - 90) / 180
        car_x += car_speed * math.cos(radians)
        car_y += car_speed * math.sin(radians)
        // Camera boundary checks
        if car_x + cam.offset.x < CAMERA_FOLLOW_OFFSET {
            cam.offset.x = -car_x + CAMERA_FOLLOW_OFFSET
        }
        if car_x + cam.offset.x > f32(width - CAMERA_FOLLOW_OFFSET) {
            cam.offset.x = -car_x + f32(width - CAMERA_FOLLOW_OFFSET)
        }
        if car_y + cam.offset.y < CAMERA_FOLLOW_OFFSET {
            cam.offset.y = -car_y + CAMERA_FOLLOW_OFFSET
        }
        if car_y + cam.offset.y > f32(height - CAMERA_FOLLOW_OFFSET) {
            cam.offset.y = -car_y + f32(height - CAMERA_FOLLOW_OFFSET)
        }
        cam.offset.x = max(min(cam.offset.x, 0), f32(-world_width + width + CAMERA_FOLLOW_OFFSET))
        cam.offset.y = max(min(cam.offset.y, 0), f32(-world_height + height + CAMERA_FOLLOW_OFFSET))

        car_rec := rl.Rectangle{
            x = car_x,
            y = car_y,
            width = car_width,
            height = car_length,
        }
        car_origin := rl.Vector2{car_width/2, car_length/2}
        if drifting {
            radians := math.PI * (car_angle - 240) / 180
            left_tire_x := car_x + car_length / 2.6 * math.cos(radians)
            left_tire_y := car_y + car_length / 2.6 * math.sin(radians)

            radians = math.PI * (car_angle - 300) / 180
            right_tire_x := car_x + car_length / 2.6 * math.cos(radians)
            right_tire_y := car_y + car_length / 2.6 * math.sin(radians)

            skidmarks[skidmark_count % MAX_SKIDMARKS] = Skidmark{
                left_tire_x = left_tire_x,
                left_tire_y = left_tire_y,
                right_tire_x = right_tire_x,
                right_tire_y = right_tire_y,
                time = rl.GetTime(),
            }
            skidmark_count += 1
        }
        for i in 0..<min(skidmark_count, MAX_SKIDMARKS) {
            mark := skidmarks[i]
            current_time := rl.GetTime()
            if current_time - mark.time > SKIDMARK_TIME {
                continue
            }
            rl.DrawCircle(i32(mark.left_tire_x), i32(mark.left_tire_y), 6, rl.BLACK)
            rl.DrawCircle(i32(mark.right_tire_x), i32(mark.right_tire_y), 6, rl.BLACK)
        }
        rl.DrawTexturePro(
            car_texture, 
            car_texture_rec, 
            car_rec, 
            car_origin, 
            car_angle, 
            rl.WHITE
        )
        rl.EndMode2D()
        rl.EndDrawing()
    }
    rl.UnloadImage(car_img)
    rl.UnloadTexture(car_texture)
    rl.UnloadImage(soil_img)
    rl.UnloadTexture(soil_texture)
    rl.CloseWindow()
}