package ripple

import "core:fmt"
import "core:math"
import "core:math/linalg"

import rl "vendor:raylib"

Matter :: struct {
    gradient: rl.Vector3,
    normal: rl.Vector3,
    height: f32,
    vel: f32,
    boundary: bool,
}

Sphere :: struct {
    location: rl.Vector3,
    velocity: rl.Vector3,
    color: rl.Color,
}

colorizer :: proc(
    mat_array: []Matter, 
    xsize, zsize: i32, 
    posx, posz: i32, 
    eye: rl.Vector3
) -> rl.Color {
    blue := rl.BLUE
    light := rl.RAYWHITE

    blue_parts := rl.Vector3{f32(blue.r), f32(blue.g), f32(blue.b)}
    light_parts := rl.Vector3{f32(light.r), f32(light.g), f32(light.b)}

    pos := rl.Vector3{
        f32(posx), 
        mat_array[posx + posz * xsize].height, 
        f32(posz)
    }

    light_source := rl.Vector3{0, 100, 0}
    l_to_p := light_source - pos

    if mat_array[posx + posz * xsize].boundary {
        return rl.WHITE
    }

    if posx == 0 || posz == 0 || posx >= xsize - 1 || posz >= zsize - 1 {
        return rl.Color{0, 121, 241, 128}
    }

    normal := mat_array[posx + posz * xsize].normal
    reflected := linalg.reflect(rl.Vector3Normalize((pos - eye)), normal)
    fade := rl.Vector3DotProduct(reflected, rl.Vector3Normalize(l_to_p))

    fade = clamp(fade, 0, 1)
    fade_results := linalg.lerp(blue_parts, light_parts, fade)

    return rl.Color{
        u8(fade_results.x), 
        u8(fade_results.y), 
        u8(fade_results.z), 
        128
    }
}

update_height :: proc(mat_array: []Matter, xsize, zsize: i32) {
    for i in 0..<xsize {
        for j in 0..<zsize {
            if !mat_array[i + xsize * j].boundary {
                mat_array[i + xsize * j].height += mat_array[i + xsize * j].vel
            }
        }
    }
}

update_vel :: proc(mat_array: []Matter, xsize, zsize: i32) {
    for i in 0..<xsize {
        for j in 0..<zsize {
            temp, tempdiv: f32 = 0, 0

            a_range: []i32
            if i > 0 && i < xsize - 1 {
                a_range = []i32{-1, 0, 1}
            } else {
                a_range = []i32{0}
            }
            
            b_range: []i32
            if j > 0 && j < zsize - 1 {
                b_range = []i32{-1, 0, 1}
            } else {
                b_range = []i32{0}
            }

            for a in a_range {
                for b in b_range {
                    if !mat_array[(i+a) + xsize * (j+b)].boundary {
                        temp += mat_array[(i+a) + xsize * (j+b)].height - mat_array[i + xsize * j].height
                        tempdiv += 1
                    } else {
                        tempdiv += 1
                    }
                }
            }

            mat_array[i + xsize * j].vel += 0.5 * temp / tempdiv
            mat_array[i + xsize * j].vel *= 0.995
        }
    }
}

calc_gradient_and_normal :: proc(mat_array: []Matter, xsize, zsize: i32) {
    for i in 1..<xsize-1 {
        for j in 1..<zsize-1 {
            dx := (mat_array[(i+1) + j * xsize].height - mat_array[(i-1) + j * xsize].height) / 2
            dz := (mat_array[i + (j+1) * xsize].height - mat_array[i + (j-1) * xsize].height) / 2

            mat_array[i + j * xsize].gradient = {dx, 0, dz}
            mat_array[i + j * xsize].normal = rl.Vector3Normalize(
                rl.Vector3CrossProduct({0, dz, 1}, {1, dx, 0})
            )
        }
    }
}

update_spheres :: proc(
    spheres: []Sphere, 
    mat_array: []Matter, 
    xsize, zsize: i32
) {
    for s in 0..<len(spheres) {
        xpos := i32(spheres[s].location.x)
        zpos := i32(spheres[s].location.z)
        depth := mat_array[xpos + zpos * xsize].height - spheres[s].location.y

        if depth < 0 {
            spheres[s].velocity.y -= 0.9
        } else {
            depth = min(depth, 2)
            subvol := math.PI * (-depth * depth * depth / 3 + depth * depth)

            spheres[s].velocity.x -= 5 * mat_array[xpos + zpos * xsize].gradient.x
            spheres[s].velocity.z -= 5 * mat_array[xpos + zpos * xsize].gradient.z
            spheres[s].velocity.y += subvol - 0.9
            spheres[s].velocity.y += mat_array[xpos + zpos * xsize].vel

            // Viscosity drag
            spheres[s].velocity -= spheres[s].velocity * (0.01 * rl.Vector3Length(spheres[s].velocity))
        }

        // Temporarily assign position before checking boundary
        temp_loc := spheres[s].location + spheres[s].velocity * 0.03

        if mat_array[i32(temp_loc.x) + i32(temp_loc.z) * xsize].boundary {
            temp_vel := spheres[s].velocity
            temp := temp_vel.x
            temp_vel.x = -temp_vel.z
            temp_vel.z = temp

            spheres[s].velocity = temp_vel
            spheres[s].location += spheres[s].velocity * 0.03
        } else {
            spheres[s].location = temp_loc
        }
    }
}

GetCollisionRayGround :: proc(ray: rl.Ray, ground_height: f32) -> rl.RayCollision {
    hit_info: rl.RayCollision
    
    // Check if ray intersects ground plane
    if ray.direction.y == 0 {
        return hit_info  // No intersection possible
    }

    // Calculate intersection distance
    distance := (ground_height - ray.position.y) / ray.direction.y

    if distance >= 0 {
        hit_info.hit = true
        hit_info.distance = distance
        hit_info.point = ray.position + ray.direction * distance
        hit_info.normal = {0, 1, 0}  // Ground plane normal
    }

    return hit_info
}

main :: proc() {
    rl.InitWindow(800, 800, "Water")
    rl.SetWindowPosition(500, 50)

    camera := rl.Camera{
        position = {-10, 10, -10},
        target = {25, 0, 25},
        up = {0, 1, 0},
        fovy = 60,
        projection = rl.CameraProjection.PERSPECTIVE,
    }

    camera_speed:f32 = 0.5
    mouse_sensitivity:f32 = 0.2

    // rl.DisableCursor()

    rl.SetTargetFPS(60)
    rl.UpdateCamera(&camera, rl.CameraMode.FREE)

    xsize, zsize:i32 = 200, 200
    mat_array := make([]Matter, xsize * zsize)
    num_spheres := 20
    spheres := make([]Sphere, num_spheres)

    // Initialize mat_array and boundaries
    for i in 0..<xsize {
        for j in 0..<zsize {
            mat_array[i + j * xsize].height = 0
            mat_array[i + j * xsize].vel = 0
            mat_array[i + j * xsize].boundary = (i < 2 || i > xsize - 2 || j < 2 || j > zsize - 2)
        }
    }

    // Line boundary
    for i in 0..<xsize {
        mat_array[i + 40 * xsize].boundary = true
    }

    // Initialize spheres
    for i in 0..<num_spheres {
        posx := rl.GetRandomValue(0, xsize - 1)
        posz := rl.GetRandomValue(0, zsize - 1)
        spheres[i].location = {f32(posx), 1.5, f32(posz)}
        spheres[i].color = i % 2 == 0 ? rl.GREEN : rl.RED
    }

    for !rl.WindowShouldClose() {
        // Camera movement with WASD
        forward := rl.Vector3Normalize(camera.target - camera.position)
        right := rl.Vector3Normalize(rl.Vector3CrossProduct(forward, camera.up))
        
        // Move forward/backward
        if rl.IsKeyDown(rl.KeyboardKey.W) {
            camera.position = camera.position + forward * camera_speed
            camera.target = camera.target + forward * camera_speed
        }
        if rl.IsKeyDown(rl.KeyboardKey.S) {
            camera.position = camera.position - forward * camera_speed
            camera.target = camera.target - forward * camera_speed
        }
        
        // Strafe left/right
        if rl.IsKeyDown(rl.KeyboardKey.A) {
            camera.position = camera.position - forward * camera_speed
            camera.target = camera.target - forward * camera_speed
        }
        if rl.IsKeyDown(rl.KeyboardKey.D) {
            camera.position = camera.position + forward * camera_speed
            camera.target = camera.target + forward * camera_speed
        }

        // Mouse look control
        mouse_delta := rl.GetMouseDelta()
        
        // Rotate camera around local right axis (pitch)
        pitch_rotation := rl.QuaternionFromAxisAngle(right, -mouse_delta.y * mouse_sensitivity * rl.DEG2RAD)
        camera_forward := camera.target - camera.position
        rotated_forward := rl.Vector3RotateByQuaternion(camera_forward, pitch_rotation)
        camera.target = camera.position + rotated_forward
        
        // Rotate camera around world up axis (yaw)
        yaw_rotation := rl.QuaternionFromAxisAngle(camera.up, -mouse_delta.x * mouse_sensitivity * rl.DEG2RAD)
        camera_forward = camera.target - camera.position
        rotated_forward = rl.Vector3RotateByQuaternion(camera_forward, yaw_rotation)
        camera.target = camera.position + rotated_forward
        

        // Mouse drop interaction
        if rl.IsMouseButtonDown(rl.MouseButton.LEFT) {
            mouse_ray := rl.GetScreenToWorldRay(rl.GetMousePosition(), camera)
            hit_info := GetCollisionRayGround(mouse_ray, 1.0)
            
            // Check if click is within bounds
            if hit_info.hit && 
               hit_info.point.x > 0 && 
               hit_info.point.x < f32(xsize) && 
               hit_info.point.z > 0 && 
               hit_info.point.z < f32(zsize) {
                x := i32(hit_info.point.x)
                z := i32(hit_info.point.z)
                mat_array[x + xsize * z].height += 20.0
            }
        }

        // Ripple generation with 'T' key (dipole drops)
        if rl.IsKeyDown(rl.KeyboardKey.T) {
            mat_array[50 + xsize * 150].height += 5.0
            mat_array[150 + xsize * 150].height += 5.0
        }

        // Reset system with 'R' key
        if rl.IsKeyPressed(rl.KeyboardKey.R) {
            for i in 0..<(xsize * zsize) {
                mat_array[i].vel = 0
                mat_array[i].height = 0
            }
        }

        // Simulation update
        update_height(mat_array, xsize, zsize)
        update_vel(mat_array, xsize, zsize)
        calc_gradient_and_normal(mat_array, xsize, zsize)
        update_spheres(spheres, mat_array, xsize, zsize)

        // Drawing
        rl.BeginDrawing()
        rl.ClearBackground(rl.BLACK)
        rl.BeginMode3D(camera)

        for i in 0..<xsize {
            for j in 0..<zsize {
                loc := rl.Vector3{
                    f32(i), 
                    mat_array[i + xsize * j].height, 
                    f32(j)
                }
                rl.DrawCube(
                    loc, 
                    1, 1, 1, 
                    colorizer(mat_array, xsize, zsize, i, j, camera.position)
                )
            }
        }

        for s in 0..<num_spheres {
            rl.DrawSphere(spheres[s].location, 1, spheres[s].color)
        }

        rl.UpdateCamera(&camera, rl.CameraMode.FREE)
        rl.EndMode3D()
        rl.DrawFPS(10, 10)
        rl.EndDrawing()
    }

    rl.CloseWindow()
}