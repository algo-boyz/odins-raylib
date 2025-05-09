package main

import "core:math"
import rl "vendor:raylib"

SCREEN_WIDTH :: 1280
SCREEN_HEIGHT :: 720
// Raylib, projecting 3D onto 2D handy for debugging - https://bedroomcoders.co.uk/posts/173

Obj :: struct {
    index:    int,
    pos:      rl.Vector3,    // required render position
    proj:     rl.Vector4,    // projected 2d position and depth
    m:        ^rl.Model,     // which model to use
}

// Port of https://www.khronos.org/opengl/wiki/GluProject_and_gluUnProject_code
project :: proc(pos: rl.Vector3, mat_view: rl.Matrix, mat_perps: rl.Matrix) -> rl.Vector4 {
    temp: rl.Vector4
    temp.x = mat_view[0,0] * pos.x + mat_view[1,0] * pos.y + mat_view[2,0] * pos.z + mat_view[3,0]
    temp.y = mat_view[0,1] * pos.x + mat_view[1,1] * pos.y + mat_view[2,1] * pos.z + mat_view[3,1]
    temp.z = mat_view[0,2] * pos.x + mat_view[1,2] * pos.y + mat_view[2,2] * pos.z + mat_view[3,2]
    temp.w = mat_view[0,3] * pos.x + mat_view[1,3] * pos.y + mat_view[2,3] * pos.z + mat_view[3,3]

    result: rl.Vector4
    result.x = mat_perps[0,0] * temp.x + mat_perps[1,0] * temp.y + mat_perps[2,0] * temp.z + mat_perps[3,0] * temp.w
    result.y = mat_perps[0,1] * temp.x + mat_perps[1,1] * temp.y + mat_perps[2,1] * temp.z + mat_perps[3,1] * temp.w
    result.z = mat_perps[0,2] * temp.x + mat_perps[1,2] * temp.y + mat_perps[2,2] * temp.z + mat_perps[3,2] * temp.w
    result.w = -temp.z

    if result.w != 0.0 {
        result.w = (1.0 / result.w) / 0.75    // TODO fudge of .75 WHY???
        // Perspective division
        result.x *= result.w
        result.y *= result.w
        result.z *= result.w
        return result
    } else {
        // result.x = result.y = result.z = result.w
        return result
    }
}

main :: proc() {
    // Initialization
    rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "raylib - test (Odin)")

    // Define the camera to look into our 3d world
    camera := rl.Camera{}
    camera.position = rl.Vector3{0.0, 1.0, 0.0}
    camera.target = rl.Vector3{0.0, 0.0, 4.0}
    camera.up = rl.Vector3{0.0, 1.0, 0.0}
    camera.fovy = 45.0
    camera.projection = .PERSPECTIVE

    models: [4]rl.Model
    objs: [8]Obj
    
    // each model orbits a centre position of its own
    base_pos: [8]rl.Vector3

    for i in 0..<8 {
        objs[i].pos = rl.Vector3{
            math.cos(0.7853982 * f32(i)) * 4.0, 
            0, 
            math.sin(0.7853982 * f32(i)) * 4.0,
        }
        // bias the cylinder positions
        if i == 2 || i == 6 {
            objs[i].pos.y -= 0.5
        }
        base_pos[i] = objs[i].pos
        objs[i].index = i
    }

    // text to print for each object
    labels := [8]cstring{
        "torus 1", "cube 1", "cylinder 1", "sphere 1",
        "torus 2", "cube 2", "cylinder 2", "sphere 2",
    }

    mesh := rl.GenMeshTorus(0.3, 1, 16, 32)
    models[0] = rl.LoadModelFromMesh(mesh)
    mesh = rl.GenMeshCube(1, 1, 1)
    models[1] = rl.LoadModelFromMesh(mesh)
    mesh = rl.GenMeshCylinder(0.5, 1, 32)
    models[2] = rl.LoadModelFromMesh(mesh)
    mesh = rl.GenMeshSphere(0.5, 16, 32)
    models[3] = rl.LoadModelFromMesh(mesh)

    // each object shares its shape with another object
    objs[0].m = &models[0]; objs[4].m = &models[0]
    objs[1].m = &models[1]; objs[5].m = &models[1]
    objs[2].m = &models[2]; objs[6].m = &models[2]
    objs[3].m = &models[3]; objs[7].m = &models[3]

    // lighting shader
    shader := rl.LoadShader("assets/light.vs", "assets/light.fs")
    shader_loc_matrix_model := rl.GetShaderLocation(shader, "matModel")
    shader_loc_vector_view := rl.GetShaderLocation(shader, "viewPos")

    // ambient light level
    amb := rl.GetShaderLocation(shader, "ambient")
    ambient_values := [4]f32{0.2, 0.2, 0.2, 1.0}
    rl.SetShaderValue(shader, amb, &ambient_values, .VEC4)

    // set the models shader, texture and position
    tex := rl.LoadTexture("assets/test.png")
    for i in 0..<4 {
        models[i].materials[0].maps[rl.MaterialMapIndex.ALBEDO].texture = tex
        models[i].materials[0].shader = shader
    }

    // Make a light (max 4 but we're only using 1)
    // Note: In Odin, we need to implement the CreateLight function manually
    // as it's from rlights.h which is an external library
    light := create_light(.POINT, rl.Vector3{2, 4, 1}, rl.Vector3{}, rl.WHITE, shader)

    // frame counter
    frame := 0
    // model rotation
    ang := rl.Vector3{}

    toggle_pos := true
    toggle_radar := false

    rl.SetTargetFPS(60)

    // Main game loop
    for !rl.WindowShouldClose() {
        // Update
        frame += 1
        ang.x += 0.01
        ang.y += 0.005
        ang.z -= 0.0025

        // rotate one of the models
        models[0].transform = rl.MatrixRotateXYZ(ang)

        rl.UpdateCamera(&camera, .FIRST_PERSON)

        // these matrices are used to project 3d to 2d
        view := rl.MatrixLookAt(camera.position, camera.target, camera.up)
        aspect := f32(SCREEN_WIDTH) / f32(SCREEN_HEIGHT)
        perps := rl.MatrixPerspective(camera.fovy * rl.DEG2RAD, aspect, 0.01, 1000.0)

        if rl.IsKeyPressed(.SPACE) {
            toggle_pos = !toggle_pos
        }
        if rl.IsKeyPressed(.R) {
            toggle_radar = !toggle_radar
        }

        // move the objects around and project the 3d coordinates
        // to 2d for the labels
        for i in 0..<8 {
            objs[i].pos = base_pos[objs[i].index]
            xi := f32(frame) / 100.0
            // different orbits for alternate objects
            if objs[i].index % 2 == 1 {
                xi = -xi
            }
            mi := f32(0.25)
            // one object describing a larger orbit
            if objs[i].index == 0 {
                mi = 8
            }
            objs[i].pos.x += math.cos(xi) * mi
            objs[i].pos.z += math.sin(xi) * mi
            p := objs[i].pos
            p.y = toggle_pos ? 1.0 : 0.0
            objs[i].proj = project(p, view, perps)
        }

        // as we have no depth buffer in 2d we must depth sort the labels
        // as the array items change place this is why they each need an "index"
        sorted := false
        for !sorted {
            sorted = true
            for i in 0..<7 {
                if objs[i].proj.w > objs[i+1].proj.w {
                    sorted = false
                    tmp := objs[i]
                    objs[i] = objs[i+1]
                    objs[i+1] = tmp
                }
            }
        }

        // position the light slightly above the camera
        light.position = camera.position
        light.position.y += 0.1

        // update the light shader with the camera view position
        rl.SetShaderValue(shader, shader_loc_vector_view, &camera.position, .VEC3)
        update_light_values(shader, light)

        // Draw
        rl.BeginDrawing()
        
        rl.ClearBackground(rl.BLACK)

        rl.BeginMode3D(camera)

        // render the 3d shapes in any order
        for i in 0..<8 {
            rl.DrawModel(objs[i].m^, objs[i].pos, 1, rl.WHITE)
        }

        rl.DrawGrid(10, 1.0)  // Draw a grid

        rl.EndMode3D()

        rl.DrawFPS(10, 10)

        rl.DrawText("Space : toggle label position,  R : toggle 3d radar", 140, 10, 20, rl.DARKGREEN)

        hsw := f32(SCREEN_WIDTH) / 2.0
        hsh := f32(SCREEN_HEIGHT) / 2.0

        for i in 0..<8 {
            p := objs[i].proj
            // don't bother drawing if its behind us
            if p.w > 0 {
                // draw the label text centred
                l := rl.MeasureText(labels[objs[i].index], 24)
                rl.DrawRectangle(
                    i32(hsw + p.x * (hsw)) - 4 - i32(l) / 2, 
                    i32(hsh - p.y * (hsh)) - 4, 
                    i32(l) + 8, 
                    27, 
                    rl.BLUE,
                )
                rl.DrawText(
                    labels[objs[i].index], 
                    i32(hsw + p.x * (hsw)) - i32(l) / 2, 
                    i32(hsh - p.y * (hsh)), 
                    24, 
                    rl.WHITE,
                )

                // draw the ground plane coordinates
                tx := rl.TextFormat("%2.3f %2.3f", objs[i].pos.x, objs[i].pos.z)
                l = rl.MeasureText(tx, 24)
                rl.DrawRectangle(
                    i32(hsw + p.x * (hsw)) - 4 - i32(l) / 2, 
                    i32(hsh - p.y * (hsh)) - 4 + 27, 
                    i32(l) + 8, 
                    27, 
                    rl.BLUE,
                )
                rl.DrawText(
                    tx, 
                    i32(hsw + p.x * (hsw)) - i32(l) / 2, 
                    i32(hsh - p.y * (hsh)) + 27, 
                    24, 
                    rl.WHITE,
                )
            }
            if toggle_radar {
                // effect the coordinates to give a "3d" radar effect
                p.x /= p.w
                p.y /= p.w
                rl.DrawCircle(
                    i32(hsw + p.x * (hsw / 32)), 
                    i32((f32(SCREEN_HEIGHT) - (hsh / 3)) - p.y * (hsh / 32)), 
                    3, 
                    rl.RED,
                )
            }
        }

        // Format text for frame counter
        ft := rl.TextFormat("Frame %i", frame)
        l := rl.MeasureText(ft, 20)
        rl.DrawRectangle(16, 698, i32(l) + 8, 42, rl.BLUE)
        rl.DrawText(ft, 20, 700, 20, rl.WHITE)

        rl.EndDrawing()
    }

    // De-Initialization
    for i in 0..<4 {
        rl.UnloadModel(models[i])
    }

    rl.UnloadTexture(tex)
    rl.UnloadShader(shader)

    rl.CloseWindow()
}

// From rlights.h implementation - we need to add these light-related functions

Light_Type :: enum {
    DIRECTIONAL,
    POINT,
}

Light :: struct {
    type:      Light_Type,
    position:  rl.Vector3,
    target:    rl.Vector3,
    color:     rl.Color,
    enabled:   bool,
    
    // Shader locations
    enabledLoc:  i32,
    typeLoc:     i32,
    posLoc:      i32,
    targetLoc:   i32,
    colorLoc:    i32,
}

create_light :: proc(type: Light_Type, position, target: rl.Vector3, color: rl.Color, shader: rl.Shader) -> Light {
    light: Light
    light.type = type
    light.position = position
    light.target = target
    light.color = color
    light.enabled = true
    
    // Get shader locations
    light_count_loc := rl.GetShaderLocation(shader, "lightsCount")
    
    // TODO: Odin doesn't have a direct C sprintf equivalent
    // Instead, we'll use array indexing for uniform locations
    light.enabledLoc = rl.GetShaderLocation(shader, "lights[0].enabled")
    light.typeLoc = rl.GetShaderLocation(shader, "lights[0].type")
    light.posLoc = rl.GetShaderLocation(shader, "lights[0].position")
    light.targetLoc = rl.GetShaderLocation(shader, "lights[0].target")
    light.colorLoc = rl.GetShaderLocation(shader, "lights[0].color")
    
    // Set light count to 1
    light_count_val := 1
    rl.SetShaderValue(shader, light_count_loc, &light_count_val, .INT)
    
    // Set light type
    type_val := i32(light.type)
    rl.SetShaderValue(shader, light.typeLoc, &type_val, .INT)
    
    // Apply other light settings
    enabled_val := i32(light.enabled)
    rl.SetShaderValue(shader, light.enabledLoc, &enabled_val, .INT)
    rl.SetShaderValue(shader, light.posLoc, &light.position, .VEC3)
    rl.SetShaderValue(shader, light.targetLoc, &light.target, .VEC3)
    
    // Convert color to normalized float array
    color_normalized := [4]f32{
        f32(color.r) / 255.0,
        f32(color.g) / 255.0,
        f32(color.b) / 255.0,
        f32(color.a) / 255.0,
    }
    rl.SetShaderValue(shader, light.colorLoc, &color_normalized, .VEC4)
    
    return light
}

update_light_values :: proc(shader: rl.Shader, light: Light) {
    // Update light enabled state and type
    enabled_val := i32(light.enabled)
    rl.SetShaderValue(shader, light.enabledLoc, &enabled_val, .INT)
    
    type_val := i32(light.type)
    rl.SetShaderValue(shader, light.typeLoc, &type_val, .INT)
    
    // Update light position and target
    // rl.SetShaderValue(shader, light.posLoc,  &light.position, .VEC3)
    // rl.SetShaderValue(shader, light.targetLoc, &light.target, .VEC3)
    
    // Convert color to normalized values
    color_normalized := [4]f32{
        f32(light.color.r) / 255.0,
        f32(light.color.g) / 255.0,
        f32(light.color.b) / 255.0,
        f32(light.color.a) / 255.0,
    }
    rl.SetShaderValue(shader, light.colorLoc, &color_normalized, .VEC4)
}