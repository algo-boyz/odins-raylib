package main

import "core:math"
import "core:math/rand"
import rl "vendor:raylib"

// Constants
MAX_SPHERES :: 100
MAX_VELOCITY :: 25
MAX_SPACE :: 50

MIN_RADIUS :: 0.3
MAX_RADIUS :: 10
DENSITY :: 1

WIDTH :: 1920
HEIGHT :: 1080

Sphere :: struct {
    position, velocity: rl.Vector3,
    radius, mass:       f32,
    color:              rl.Color,
}

spheres: [MAX_SPHERES]Sphere
num_spheres: i32 = 10
rest_coeff: f32 = 0.9
hit_sphere: rl.Sound
hit_wall: rl.Sound

// Init sphere with random properties
new_sphere :: proc(s: ^Sphere) {
    s.radius = MIN_RADIUS + rand.float32() * (MAX_RADIUS - MIN_RADIUS)
    s.mass = DENSITY * (4 / 3) * math.PI * math.pow(s.radius, 3)
    
    // Spawn within bounds with buffer zones
    buffer := s.radius * 2
    range_size := MAX_SPACE - buffer * 2
    
    s.position.x = rand.float32() * range_size - MAX_SPACE/2 + buffer
    s.position.y = rand.float32() * range_size - MAX_SPACE/2 + buffer
    s.position.z = rand.float32() * range_size - MAX_SPACE/2 + buffer

    s.velocity.x = rand.float32() * MAX_VELOCITY * 2 - MAX_VELOCITY
    s.velocity.y = rand.float32() * MAX_VELOCITY * 2 - MAX_VELOCITY
    s.velocity.z = rand.float32() * MAX_VELOCITY * 2 - MAX_VELOCITY

    s.color = rl.Color{
        u8(rand.int31() % 256),
        u8(rand.int31() % 256),
        u8(rand.int31() % 256),
        255,
    }
}

// Resolves collision between two spheres
collide :: proc(sphere_a: ^Sphere, sphere_b: ^Sphere) {
    // Normal vector from center of sphere A to B
    norm := sphere_b.position - sphere_a.position
    dist_sq := rl.Vector3LengthSqr(norm)
    sum_radii := sphere_a.radius + sphere_b.radius
    min_dist_sq := sum_radii * sum_radii

    // Separate spheres if overlapping
    if dist_sq < min_dist_sq {
        dist := math.sqrt(dist_sq)

        if dist == 0 { // Rare case where they're in the same spot
            // Create random normal to separate them
            norm = rl.Vector3{
                rand.float32() - 0.5,
                rand.float32() - 0.5,
                rand.float32() - 0.5,
            }
            norm = rl.Vector3Normalize(norm)
            dist = sum_radii
        } else {
            norm *= 1 / dist
        }

        overlap := sum_radii - dist
        separation := norm * (overlap / 2)

        sphere_a.position -= separation
        sphere_b.position += separation
    } else {
        norm = rl.Vector3Normalize(norm)
    }

    // Calculate relative velocities along normal before collision
    vel_a_norm := rl.Vector3DotProduct(sphere_a.velocity, norm)
    vel_b_norm := rl.Vector3DotProduct(sphere_b.velocity, norm)

    // If spheres are moving away from each other, no collision needed
    if vel_a_norm - vel_b_norm > 0 do return

    // Calculate new normal velocities using 1D collision formulas
    total_mass := sphere_a.mass + sphere_b.mass

    va_norm_fin := (sphere_a.mass * vel_a_norm + sphere_b.mass * vel_b_norm - 
                       sphere_b.mass * rest_coeff * (vel_a_norm - vel_b_norm)) / total_mass
    vb_norm_fin := (sphere_a.mass * vel_a_norm + sphere_b.mass * vel_b_norm - 
                       sphere_a.mass * rest_coeff * (vel_b_norm - vel_a_norm)) / total_mass

    // Calculate tangential velocities (perpendicular to normal)
    vel_a_tangential := sphere_a.velocity - (norm * vel_a_norm)
    vel_b_tangential := sphere_b.velocity - (norm * vel_b_norm)

    // Recompose final velocities
    sphere_a.velocity = norm * va_norm_fin + vel_a_tangential
    sphere_b.velocity = norm * vb_norm_fin + vel_b_tangential

    rl.PlaySound(hit_sphere)
}

// Detects and resolves sphere collisions
detect_collisions :: proc() {
    for i in 0..<num_spheres {
        for j in i+1..<num_spheres {
            if rl.Vector3Distance(spheres[i].position, spheres[j].position) <= spheres[i].radius + spheres[j].radius {
                collide(&spheres[i], &spheres[j])
            }
        }
    }
}

init :: proc() {
    for i in 0..<num_spheres {
        new_sphere(&spheres[i])
    }
}

// Draw spheres
draw :: proc() {
    for i in 0..<num_spheres {
        rl.DrawSphere(spheres[i].position, spheres[i].radius, spheres[i].color)
    }
}

// Destroy/reset a sphere
destroy :: proc(index: i32) {
    if index >= 0 && index < MAX_SPHERES {
        spheres[index].position = {}
        spheres[index].velocity = {}
        spheres[index].radius = 0
        spheres[index].mass = 0
        spheres[index].color = rl.BLANK
    }
}

// Calculate total kinetic energy of system
calc_total_energy :: proc() -> f32 {
    total_energy: f32 = 0
    for i in 0..<num_spheres {
        speed := rl.Vector3Length(spheres[i].velocity)
        total_energy += 0.5 * spheres[i].mass * (speed * speed)
    }
    return total_energy
}

// Update physics simulation
update_sim :: proc(dt: f32) {
    min_bound: f32 = -MAX_SPACE / 2
    max_bound: f32 = MAX_SPACE / 2

    for i in 0..<num_spheres {
        // Update position
        spheres[i].position += spheres[i].velocity * dt

        // Wall collisions - X axis
        if spheres[i].position.x + spheres[i].radius > max_bound {
            spheres[i].velocity.x *= -1
            spheres[i].position.x = max_bound - spheres[i].radius
            rl.PlaySound(hit_wall)
        } else if spheres[i].position.x - spheres[i].radius < min_bound {
            spheres[i].velocity.x *= -1
            spheres[i].position.x = min_bound + spheres[i].radius
            rl.PlaySound(hit_wall)
        }
        // Wall collisions - Y axis
        if spheres[i].position.y + spheres[i].radius > max_bound {
            spheres[i].velocity.y *= -1
            spheres[i].position.y = max_bound - spheres[i].radius
            rl.PlaySound(hit_wall)
        } else if spheres[i].position.y - spheres[i].radius < min_bound {
            spheres[i].velocity.y *= -1
            spheres[i].position.y = min_bound + spheres[i].radius
            rl.PlaySound(hit_wall)
        }
        // Wall collisions - Z axis
        if spheres[i].position.z + spheres[i].radius > max_bound {
            spheres[i].velocity.z *= -1
            spheres[i].position.z = max_bound - spheres[i].radius
            rl.PlaySound(hit_wall)
        } else if spheres[i].position.z - spheres[i].radius < min_bound {
            spheres[i].velocity.z *= -1
            spheres[i].position.z = min_bound + spheres[i].radius
            rl.PlaySound(hit_wall)
        }
    }
    detect_collisions()
}

main :: proc() {
    rl.InitWindow(WIDTH, HEIGHT, "3D Sphere Physics")
    rl.InitAudioDevice()
    rl.DisableCursor()
    cam := rl.Camera3D{
        position   = {40, 40, 40},
        target     = {},
        up         = {0, 1, 0},
        fovy       = 45,
        projection = rl.CameraProjection.PERSPECTIVE,
    }
    // Load sounds (you'll need these audio files)
    hit_sphere = rl.LoadSound("hitball.wav")
    hit_wall = rl.LoadSound("hitwall.wav")

    init()

    for !rl.WindowShouldClose() {
        rl.UpdateCamera(&cam, rl.CameraMode.FREE)
        // Reset camera with R
        if rl.IsKeyPressed(rl.KeyboardKey.R) {
            cam.position = {40, 40, 40}
            cam.target = {}
            cam.up = {0, 1, 0}
        }
        // Update restitution coefficient
        if rl.IsKeyPressed(rl.KeyboardKey.EQUAL) {
            rest_coeff += 0.05
        }
        if rl.IsKeyPressed(rl.KeyboardKey.MINUS) && rest_coeff > 0 {
            rest_coeff -= 0.05
        }
        // Add/remove spheres
        if rl.IsKeyPressed(rl.KeyboardKey.M) && num_spheres < MAX_SPHERES {
            new_sphere(&spheres[num_spheres])
            num_spheres += 1
        }
        if rl.IsKeyPressed(rl.KeyboardKey.N) && num_spheres > 1 {
            num_spheres -= 1
            destroy(num_spheres)
        }
        // Calculate total energy
        energy := calc_total_energy()

        // Update physics simulation
        delta_time := rl.GetFrameTime()
        update_sim(delta_time)

        rl.BeginDrawing()
        rl.ClearBackground(rl.BLACK)
        rl.BeginMode3D(cam)
        
        // Draw spheres
        draw()

        // Draw bounding box
        rl.DrawCubeWires({0, 0, 0}, MAX_SPACE, MAX_SPACE, MAX_SPACE, rl.WHITE)
        rl.EndMode3D()

        // Draw UI
        rl.DrawFPS(10, 10)
        rl.DrawText(" Move WASD, Q/Up, E/Down", 10, 60, 20, rl.WHITE)
        rl.DrawText(" Rotate with Mouse", 10, 80, 20, rl.WHITE)
        rl.DrawText(" Wheel for Zoom", 10, 100, 20, rl.WHITE)
        rl.DrawText(" R to reset camera", 10, 120, 20, rl.WHITE)
        rl.DrawText(rl.TextFormat("Spheres: %i (Press N/M)", num_spheres), 10, 140, 20, rl.WHITE)
        rl.DrawText(rl.TextFormat("Restitution Coeff: %.2f (Press +/-)", rest_coeff), 10, 160, 20, rl.WHITE)
        rl.DrawText(rl.TextFormat("Total Energy: %.2f J", energy), 10, 180, 20, rl.WHITE)

        rl.EndDrawing()
    }
    rl.UnloadSound(hit_sphere)
    rl.UnloadSound(hit_wall)
    rl.CloseAudioDevice()
    rl.CloseWindow()
}