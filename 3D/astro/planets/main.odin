package planet_simulator

import "core:fmt"
import "core:math"
import "core:strings"
import rl "vendor:raylib"

Planet :: struct {
    topography: rl.Image,
    texture_image: rl.Image,
    texture: rl.Texture2D,
    mesh: rl.Model,
    shader: rl.Shader,
    
    clouds: ^Clouds,
    seasons: ^Seasons,
    
    frame: int,
    last_update_time: f64,
    hide: bool,
    
    height_scale: f32,
    initial_height: f32,
    radius: f32,
    resolution: f32,
    position: rl.Vector3,
    rotation: f32,
    rotation_speed: f32,
    
    transform_matrix: rl.Matrix,  // Store the current transformation matrix

    change_resolution: f32,
    change_height_scale: f32,
    change_radius: f32,
    change_initial_height: f32,
    
    height_map_loaded: bool,
    map_loaded: bool,
    is_topo_color: bool,
    
    height_map: []f32,
}

create_planet :: proc(
    topography_map, texture_map: string,
    clouds_map_loc, seasons_map_loc: string,
) -> ^Planet {
    planet := new(Planet)
    
    // Load topography
    planet.topography = rl.LoadImage(strings.clone_to_cstring(topography_map))
    rl.ImageRotateCCW(&planet.topography)
    // Remove the ImageFlipVertical call for topography
    
    // Load texture
    planet.texture_image = rl.LoadImage(strings.clone_to_cstring(texture_map))
    rl.ImageRotateCCW(&planet.texture_image)
    // Remove the ImageFlipVertical call for texture
    planet.texture = rl.LoadTextureFromImage(planet.texture_image)
    
    // Initialize rotation
    planet.rotation = 0
    planet.rotation_speed = 0

    // Initialize parameters
    planet.height_scale = 1
    planet.initial_height = 0
    planet.radius = 5
    planet.resolution = 25
    planet.position = rl.Vector3{0, 0, 0}
    planet.change_resolution = planet.resolution
    planet.change_height_scale = planet.height_scale
    // Initialize clouds and seasons
    planet.clouds = create_clouds(clouds_map_loc, 1, 79, true)
    planet.seasons = create_seasons(seasons_map_loc, 1, 12, true)
    // Load shader
    planet.shader = rl.LoadShader(
        "assets/base.vs",
        "assets/base.fs",
    )
    
    return planet
}
// Only showing the modified parts for clarity - the rest remains the same
update_planet :: proc(planet: ^Planet) {
    if planet.topography.data != nil && !planet.height_map_loaded {
        planet.height_map = load_height_map(planet)
        planet.height_map_loaded = true
    }
    
    if !planet.map_loaded && len(planet.height_map) > 0 {
        planet.map_loaded = true
    }
    
    // Update rotation continuously instead of at fixed intervals
    planet.rotation += planet.rotation_speed * rl.GetFrameTime()
    
    needs_update := false
    needs_update |= abs(planet.change_resolution - planet.resolution) >= 0.01
    needs_update |= abs(planet.change_height_scale - planet.height_scale) >= 0.01
    needs_update |= abs(planet.change_radius - planet.radius) >= 0.01
    needs_update |= abs(planet.change_initial_height - planet.initial_height) >= 0.01
    needs_update |= planet.mesh.meshCount == 0
    
    if needs_update && planet.map_loaded {
        mesh := generate_displaced_sphere(
            planet.radius,
            i32(planet.resolution),
            i32(planet.resolution),
            planet.height_map,
            int(planet.topography.width),
            int(planet.topography.height),
            f32(planet.height_scale),
            planet.initial_height,
        )
        
        planet.mesh = rl.LoadModelFromMesh(mesh)
        
        if planet.texture.id != 0 && (planet.seasons == nil || planet.seasons.hide) {
            planet.mesh.materials[0].maps[rl.MaterialMapIndex.ALBEDO].texture = planet.texture
        }
        
        if planet.shader.id != 0 {
            planet.mesh.materials[0].shader = planet.shader
        }
        
        planet.change_resolution = planet.resolution
        planet.change_height_scale = planet.height_scale
        planet.change_radius = planet.radius
        planet.change_initial_height = planet.initial_height
    }
    
    // Update transformation matrix
    initial_orientation := rl.MatrixRotateX(-90 * DEG2RAD)
    rotation_matrix := rl.MatrixRotateY(planet.rotation)
    planet.transform_matrix = rotation_matrix * initial_orientation
    planet.mesh.transform = planet.transform_matrix
}

draw_planet :: proc(planet: ^Planet) {
    if planet.mesh.meshCount != 0 {
        rl.DrawModel(planet.mesh, planet.position, 1.0, rl.WHITE)
    }
    // Draw coordinate axes
    rl.DrawLine3D(rl.Vector3{-10, 0, 0}, rl.Vector3{10, 0, 0}, rl.RED)    // X-axis
    rl.DrawLine3D(rl.Vector3{0, -10, 0}, rl.Vector3{0, 10, 0}, rl.GREEN)  // Y-axis 
    rl.DrawLine3D(rl.Vector3{0, 0, -10}, rl.Vector3{0, 0, 10}, rl.BLUE)   // Z-axis
}

draw_planet_gui :: proc(planet: ^Planet) {
    rl.GuiLabel(rl.Rectangle{100, 30, 150, 20}, "Planet Controls:")
    rl.GuiSliderBar(rl.Rectangle{100, 70, 100, 20}, "Resolution", nil, &planet.resolution, 20, 250)
    rl.GuiSliderBar(rl.Rectangle{100, 90, 100, 20}, "Height Scale", nil, &planet.height_scale, 0, 10)
    rl.GuiSliderBar(rl.Rectangle{100, 110, 100, 20}, "InitialHeight Scale", nil, &planet.initial_height, 0, 4)
    rl.GuiSliderBar(rl.Rectangle{100, 130, 100, 20}, "Radius", nil, &planet.radius, 5, 10)
    rl.GuiSliderBar(rl.Rectangle{100, 150, 100, 20}, "Rotation Speed", nil, &planet.rotation_speed, 0, 0.5)
    
    if rl.GuiCheckBox(rl.Rectangle{100, 180, 20, 20}, "isTopoColor", &planet.is_topo_color) {
        planet.height_map_loaded = false
        planet.map_loaded = false
    }
    
    rl.GuiCheckBox(rl.Rectangle{100, 210, 20, 20}, "Hide", &planet.hide)
    
    if rl.GuiButton(rl.Rectangle{60, 820, 70, 20}, "Load") {
        load_planet(planet)
    }
    
    if rl.GuiButton(rl.Rectangle{60, 850, 70, 20}, "Save") {
        save_planet(planet)
    }
}

load_height_map :: proc(planet: ^Planet) -> []f32 {
    pixels := rl.LoadImageColors(planet.topography)
    height_map := make([]f32, planet.topography.width * planet.topography.height)
    
    if planet.is_topo_color {
        for i :i32 = 0; i < planet.topography.width * planet.topography.height; i += 1 {
            hsv := rl.ColorToHSV(pixels[i])
            height_map[i] = hsv.x / 240.0
        }
    } else {
        for i :i32 = 0; i < planet.topography.width * planet.topography.height; i += 1 {
            height_map[i] = f32(pixels[i].r) / 255.0
        }
    }
    
    rl.UnloadImageColors(pixels)
    return height_map
}

save_planet :: proc(planet: ^Planet) {
    rl.ExportMesh(planet.mesh.meshes[0], "assets/planet.obj")
}

load_planet :: proc(planet: ^Planet) {
    // TODO: Implement mesh loading
}

// Cloud system
Clouds :: struct {
    model: rl.Model,
    image: rl.Image,
    filename: string,
    
    radius: f32,
    rings: f32,
    slices: f32,
    rotation: f32,
    rotation_speed: f32,
    
    iteration_pos: int,
    direction: int,
    start: int,
    end: int,
    reverse: bool,
    
    last_time_update: f64,
    change_radius: f32,
    change_rings: f32,
    change_slices: f32,
    
    hide: bool,
}

create_clouds :: proc(filename: string, start, end: int, reverse: bool) -> ^Clouds {
    clouds := new(Clouds)
    clouds.radius = 6.0
    clouds.rings = 25
    clouds.slices = 25
    clouds.change_radius = clouds.radius
    clouds.change_rings = clouds.rings
    clouds.change_slices = clouds.slices
    
    clouds.iteration_pos = start
    clouds.start = start
    clouds.end = end
    clouds.reverse = reverse
    clouds.direction = 1
    clouds.filename = filename
    
    clouds.model = rl.LoadModelFromMesh(rl.GenMeshSphere(clouds.radius, i32(clouds.rings), i32(clouds.slices)))
    return clouds
}

update_clouds :: proc(planet: ^Planet) {
    clouds := planet.clouds
    needs_update := false
    needs_update |= abs(clouds.change_radius - clouds.radius) >= 0.1
    needs_update |= abs(clouds.change_rings - clouds.rings) >= 0.1
    needs_update |= abs(clouds.change_slices - clouds.slices) >= 0.1
    
    if needs_update {
        clouds.model = rl.LoadModelFromMesh(rl.GenMeshSphere(
            clouds.radius,
            i32(clouds.rings),
            i32(clouds.slices),
        ))
        clouds.change_radius = clouds.radius
        clouds.change_rings = clouds.rings
        clouds.change_slices = clouds.slices
    }
    
    // Update cloud texture animation at fixed intervals
    if rl.GetTime() - clouds.last_time_update >= 0.1 {
        if clouds.iteration_pos < clouds.start || clouds.iteration_pos > clouds.end {
            if clouds.reverse {
                clouds.direction = -clouds.direction
            }
            clouds.iteration_pos += clouds.direction
        }
        
        filename := fmt.tprintf("%s%d.png", clouds.filename, clouds.iteration_pos)
        clouds.image = rl.LoadImage(strings.clone_to_cstring(filename))
        rl.ImageRotateCCW(&clouds.image)
        rl.ImageFlipVertical(&clouds.image)
        clouds.model.materials[0].maps[rl.MaterialMapIndex.ALBEDO].texture = rl.LoadTextureFromImage(clouds.image)
        
        clouds.iteration_pos += clouds.direction
        clouds.last_time_update = rl.GetTime()
    }
    
    // Update cloud rotation to match planet's direction
    clouds.rotation = planet.rotation
    initial_orientation := rl.MatrixRotateX(-90 * DEG2RAD)
    rotation_matrix := rl.MatrixRotateY(clouds.rotation)
    clouds.model.transform = rotation_matrix * initial_orientation
}

draw_clouds :: proc(clouds: ^Clouds) {
    rl.DrawModel(clouds.model, {0, 0, 0}, 1.0, rl.WHITE)
}

draw_clouds_gui :: proc(clouds: ^Clouds) {
    rl.GuiLabel(rl.Rectangle{275, 30, 150, 20}, "Cloud Controls:")
    rl.GuiSliderBar(rl.Rectangle{275, 70, 100, 20}, "Radius", nil, &clouds.radius, 5, 10)
    rl.GuiSliderBar(rl.Rectangle{275, 90, 100, 20}, "Slices", nil, &clouds.slices, 10, 100)
    rl.GuiSliderBar(rl.Rectangle{275, 110, 100, 20}, "Rings", nil, &clouds.rings, 10, 100)
    rl.GuiSliderBar(rl.Rectangle{275, 130, 100, 20}, "Rotation", nil, &clouds.rotation_speed, 0, 0.5)
    rl.GuiCheckBox(rl.Rectangle{275, 150, 20, 20}, "Hide", &clouds.hide)
}

// Seasons system
Seasons :: struct {
    image: rl.Image,
    filename: string,
    iteration_pos: int,
    start: int,
    end: int,
    reverse: bool,
    last_time_update: f64,
    direction: int,
    hide: bool,
}

create_seasons :: proc(filename: string, start, end: int, reverse: bool) -> ^Seasons {
    seasons := new(Seasons)
    seasons.filename = filename
    seasons.start = start
    seasons.end = end
    seasons.reverse = reverse
    seasons.direction = 1
    seasons.iteration_pos = start
    return seasons
}

update_seasons :: proc(seasons: ^Seasons, model: ^rl.Model) {
    if !seasons.hide {
        if rl.GetTime() - seasons.last_time_update >= 0.3 {
            if seasons.iteration_pos < seasons.start || seasons.iteration_pos > seasons.end {
                if seasons.reverse {
                    seasons.direction = -seasons.direction
                } else {
                    seasons.iteration_pos %= (seasons.end - seasons.start)
                    seasons.iteration_pos += seasons.start
                }
                seasons.iteration_pos += seasons.direction
            }
            
            filename := fmt.tprintf("%s%d.png", seasons.filename, seasons.iteration_pos)
            seasons.image = rl.LoadImage(strings.clone_to_cstring(filename))
            rl.ImageRotateCCW(&seasons.image)
            rl.ImageFlipVertical(&seasons.image)
            
            if model.meshCount != 0 {
                model.materials[0].maps[rl.MaterialMapIndex.ALBEDO].texture = rl.LoadTextureFromImage(seasons.image)
            }
            
            seasons.iteration_pos += seasons.direction
            seasons.last_time_update = rl.GetTime()
        }
    }
}

draw_seasons_gui :: proc(seasons: ^Seasons) {
    rl.GuiLabel(rl.Rectangle{420, 30, 150, 20}, "Seasons Controls:")
    rl.GuiCheckBox(rl.Rectangle{420, 60, 20, 20}, "Hide", &seasons.hide)
}

// Mesh generation
generate_displaced_sphere :: proc(
    radius: f32,
    rings: i32,
    slices: i32,
    height_map: []f32,
    map_width: int,
    map_height: int,
    height_scale: f32,
    initial_height: f32,
) -> rl.Mesh {
    sphere := rl.GenMeshSphere(radius, rings, slices)
    
    if len(height_map) > 0 {
        vertices := ([^]rl.Vector3)(sphere.vertices)
        texcoords := ([^]f32)(sphere.texcoords)
        
        for i :i32 = 0; i < sphere.vertexCount; i += 1 {
            vertex := vertices[i]
            u := texcoords[i * 2]
            v := texcoords[i * 2 + 1]
            
            // Adjust texture coordinates to fix mapping
            u = 1.0 - u  // Flip U coordinate to fix texture orientation
            
            tex_x := int(u * f32(map_width - 1))
            tex_y := int(v * f32(map_height - 1))
            height_value := height_map[tex_y * map_width + tex_x]
            
            // Displace vertex along its normal
            normal := rl.Vector3Normalize(vertex)
            displacement := height_value * height_scale
            if height_value != 0 {
                displacement += initial_height
            }
            
            vertices[i] = vertex + normal * displacement
        }
        
        rl.UpdateMeshBuffer(
            sphere,
            0,
            raw_data(vertices),
            sphere.vertexCount * size_of(rl.Vector3),
            0,
        )
    }
    
    return sphere
}

DEG2RAD :: math.PI / 180.0

main :: proc() {
    window_width:i32 = 1200
    window_height:i32 = 900
    
    rl.InitWindow(window_width, window_height, "Planet Simulator")
    defer rl.CloseWindow()
    
    camera := rl.Camera{
        position = {20, 20, 20},
        target = {0, 0, 0},
        up = {0, 1, 0},
        fovy = 45,
        projection = .PERSPECTIVE,
    }
    
    planet := create_planet(
        "assets/earth/topography(1).png",
        "assets/earth/texture.png",
        "assets/GFSR/",
        "assets/earth/resized-images/",
    )
    defer free(planet)
    
    rl.SetTargetFPS(60)
    
    for !rl.WindowShouldClose() {
        rl.UpdateCamera(&camera, .THIRD_PERSON)
        update_planet(planet)
        if planet.seasons != nil do update_seasons(planet.seasons, &planet.mesh)
        if planet.clouds != nil do update_clouds(planet)  // Pass planet reference
        
        rl.BeginDrawing()        
        rl.ClearBackground(rl.BLACK)
        
        rl.BeginMode3D(camera)
        if !planet.hide do draw_planet(planet)
        if planet.clouds != nil && !planet.clouds.hide do draw_clouds(planet.clouds)
        rl.EndMode3D()
        
        draw_planet_gui(planet)
        if planet.clouds != nil do draw_clouds_gui(planet.clouds)
        if planet.seasons != nil do draw_seasons_gui(planet.seasons)
        rl.EndDrawing()
    }
}