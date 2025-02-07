package main

import rl "vendor:raylib"

// todo compile raylib with rlights.h https://github.com/Bigfoot71/rlights

MAX_LIGHTS :: 4  // Max dynamic lights supported by shader

Light_Type :: enum {
    Directional = 0,
    Point,
    Spot,
}

Light :: struct {
    type: Light_Type,
    enabled: bool,
    position: rl.Vector3,
    target: rl.Vector3,
    color: [4]f32,
    intensity: f32,
    // Shader light parameters locations
    type_loc: i32,
    enabled_loc: i32,
    position_loc: i32,
    target_loc: i32,
    color_loc: i32,
    intensity_loc: i32,
}

light_count := 0  // Current number of dynamic lights created

create_light :: proc(type: Light_Type, position, target: rl.Vector3, color: rl.Color, intensity: f32, shader: rl.Shader) -> Light {
    light: Light
    if light_count < MAX_LIGHTS {
        light.enabled = true
        light.type = type
        light.position = position
        light.target = target
        light.color[0] = f32(color.r) / 255.0
        light.color[1] = f32(color.g) / 255.0
        light.color[2] = f32(color.b) / 255.0
        light.color[3] = f32(color.a) / 255.0
        light.intensity = intensity
        
        // Get shader locations for light parameters
        light.enabled_loc = rl.GetShaderLocation(shader, rl.TextFormat("lights[%d].enabled", light_count))
        light.type_loc = rl.GetShaderLocation(shader, rl.TextFormat("lights[%d].type", light_count))
        light.position_loc = rl.GetShaderLocation(shader, rl.TextFormat("lights[%d].position", light_count))
        light.target_loc = rl.GetShaderLocation(shader, rl.TextFormat("lights[%d].target", light_count))
        light.color_loc = rl.GetShaderLocation(shader, rl.TextFormat("lights[%d].color", light_count))
        light.intensity_loc = rl.GetShaderLocation(shader, rl.TextFormat("lights[%d].intensity", light_count))
        
        update_light(shader, light)
        light_count += 1
    }
    return light
}

update_light :: proc(shader: rl.Shader, light: Light) {
    enabled := i32(light.enabled)
    type := i32(light.type)
    
    rl.SetShaderValue(shader, light.enabled_loc, &enabled, .INT)
    rl.SetShaderValue(shader, light.type_loc, &type, .INT)
    
    position := [3]f32{light.position.x, light.position.y, light.position.z}
    rl.SetShaderValue(shader, light.position_loc, &position, .VEC3)
    
    target := [3]f32{light.target.x, light.target.y, light.target.z}
    rl.SetShaderValue(shader, light.target_loc, &target, .VEC3)
    color := light.color
    rl.SetShaderValue(shader, light.color_loc, &color, .VEC4)
    intensity := light.intensity
    rl.SetShaderValue(shader, light.intensity_loc, &intensity, .FLOAT)
}

main :: proc() {
    screen_width :: 800
    screen_height :: 450
    
    rl.SetConfigFlags({.MSAA_4X_HINT})
    rl.InitWindow(screen_width, screen_height, "basic pbr")
    
    // Define camera to look into our 3d world
    camera := rl.Camera3D{
        position = {2.0, 2.0, 6.0},
        target = {0.0, 0.5, 0.0},
        up = {0.0, 1.0, 0.0},
        fovy = 45.0,
        projection = .PERSPECTIVE,
    }
    
    // Load PBR shader
    shader := rl.LoadShader("assets/pbr.vs", "assets/pbr.fs")
    
    // Get shader locations
    shader.locs[rl.ShaderLocationIndex.MAP_ALBEDO] = rl.GetShaderLocation(shader, "albedoMap")
    shader.locs[rl.ShaderLocationIndex.MAP_METALNESS] = rl.GetShaderLocation(shader, "mraMap")
    shader.locs[rl.ShaderLocationIndex.MAP_NORMAL] = rl.GetShaderLocation(shader, "normalMap")
    shader.locs[rl.ShaderLocationIndex.MAP_EMISSION] = rl.GetShaderLocation(shader, "emissiveMap")
    shader.locs[rl.ShaderLocationIndex.COLOR_DIFFUSE] = rl.GetShaderLocation(shader, "albedoColor")
    shader.locs[rl.ShaderLocationIndex.VECTOR_VIEW] = rl.GetShaderLocation(shader, "viewPos")
    
    light_count_loc := rl.GetShaderLocation(shader, "numOfLights")
    max_light_count := i32(MAX_LIGHTS)
    rl.SetShaderValue(shader, light_count_loc, &max_light_count, .INT)
    
    // Setup ambient parameters
    ambient_intensity := f32(0.02)
    ambient_color := rl.Color{26, 32, 135, 255}
    ambient_color_normalized := rl.Vector3{
        f32(ambient_color.r) / 255.0,
        f32(ambient_color.g) / 255.0,
        f32(ambient_color.b) / 255.0,
    }
    
    rl.SetShaderValue(shader, rl.GetShaderLocation(shader, "ambientColor"), &ambient_color_normalized, .VEC3)
    rl.SetShaderValue(shader, rl.GetShaderLocation(shader, "ambient"), &ambient_intensity, .FLOAT)
    
    // Get additional shader locations
    emissive_intensity_loc := rl.GetShaderLocation(shader, "emissivePower")
    emissive_color_loc := rl.GetShaderLocation(shader, "emissiveColor")
    texture_tiling_loc := rl.GetShaderLocation(shader, "tiling")
    
    // Load floor model and setup materials
    floor := rl.LoadModel("assets/plane.glb")
    floor.materials[0].shader = shader
    floor.materials[0].maps[rl.MaterialMapIndex.ALBEDO].color = rl.WHITE
    floor.materials[0].maps[rl.MaterialMapIndex.METALNESS].value = 0.0
    floor.materials[0].maps[rl.MaterialMapIndex.ROUGHNESS].value = 0.0
    floor.materials[0].maps[rl.MaterialMapIndex.OCCLUSION].value = 1.0
    floor.materials[0].maps[rl.MaterialMapIndex.EMISSION].color = rl.BLACK
    
    // Load textures
    floor.materials[0].maps[rl.MaterialMapIndex.ALBEDO].texture = rl.LoadTexture("assets/road_a.png")
    floor.materials[0].maps[rl.MaterialMapIndex.METALNESS].texture = rl.LoadTexture("assets/road_mra.png")
    floor.materials[0].maps[rl.MaterialMapIndex.NORMAL].texture = rl.LoadTexture("assets/road_n.png")
    
    // Texture tiling
    car_texture_tiling := [2]f32{0.5, 0.5}
    floor_texture_tiling := [2]f32{0.5, 0.5}
    
    // Create lights
    lights := [MAX_LIGHTS]Light{}
    lights[0] = create_light(.Point, {-1.0, 1.0, -2.0}, {0, 0, 0}, rl.YELLOW, 4.0, shader)
    lights[1] = create_light(.Point, {2.0, 1.0, 1.0}, {0, 0, 0}, rl.GREEN, 3.3, shader)
    lights[2] = create_light(.Point, {-2.0, 1.0, 1.0}, {0, 0, 0}, rl.RED, 8.3, shader)
    lights[3] = create_light(.Point, {1.0, 1.0, -2.0}, {0, 0, 0}, rl.BLUE, 2.0, shader)
    
    // Setup texture maps usage
    usage := i32(1)
    rl.SetShaderValue(shader, rl.GetShaderLocation(shader, "useTexAlbedo"), &usage, .INT)
    rl.SetShaderValue(shader, rl.GetShaderLocation(shader, "useTexNormal"), &usage, .INT)
    rl.SetShaderValue(shader, rl.GetShaderLocation(shader, "useTexMRA"), &usage, .INT)
    rl.SetShaderValue(shader, rl.GetShaderLocation(shader, "useTexEmissive"), &usage, .INT)
    
    rl.SetTargetFPS(60)
    
    for !rl.WindowShouldClose() {
        rl.UpdateCamera(&camera, .ORBITAL)
        
        // Update shader with camera view vector
        camera_pos := [3]f32{camera.position.x, camera.position.y, camera.position.z}
        rl.SetShaderValue(shader, shader.locs[rl.ShaderLocationIndex.VECTOR_VIEW], &camera_pos, .VEC3)
        
        // Handle light toggling
        if rl.IsKeyPressed(.ONE) { lights[2].enabled = !lights[2].enabled }
        if rl.IsKeyPressed(.TWO) { lights[1].enabled = !lights[1].enabled }
        if rl.IsKeyPressed(.THREE) { lights[3].enabled = !lights[3].enabled }
        if rl.IsKeyPressed(.FOUR) { lights[0].enabled = !lights[0].enabled }
        
        // Update lights
        for light in lights {
            update_light(shader, light)
        }
        
        rl.BeginDrawing()
        rl.ClearBackground(rl.BLACK)
        
        rl.BeginMode3D(camera)
        
        // Draw floor with texture tiling and emission parameters
        rl.SetShaderValue(shader, texture_tiling_loc, &floor_texture_tiling, .VEC2)
        floor_emissive_color := rl.ColorNormalize(floor.materials[0].maps[rl.MaterialMapIndex.EMISSION].color)
        rl.SetShaderValue(shader, emissive_color_loc, &floor_emissive_color, .VEC4)
        rl.DrawModel(floor, {0, 0, 0}, 5.0, rl.WHITE)
        
        // Draw light spheres
        for light, i in lights {
            light_color := rl.Color{
                u8(light.color[0] * 255),
                u8(light.color[1] * 255),
                u8(light.color[2] * 255),
                u8(light.color[3] * 255),
            }
            
            if light.enabled {
                rl.DrawSphereEx(light.position, 0.2, 8, 8, light_color)
            } else {
                rl.DrawSphereWires(light.position, 0.2, 8, 8, rl.ColorAlpha(light_color, 0.3))
            }
        }
        
        rl.EndMode3D()
        
        rl.DrawText("Toggle lights: [1][2][3][4]", 10, 40, 20, rl.LIGHTGRAY)
        rl.DrawFPS(10, 10)
        
        rl.EndDrawing()
    }
    
    // Cleanup
    floor.materials[0].shader = rl.Shader{}
    rl.UnloadMaterial(floor.materials[0])
    rl.UnloadModel(floor)
    rl.UnloadShader(shader)
    rl.CloseWindow()
}