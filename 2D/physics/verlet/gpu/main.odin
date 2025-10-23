package main

import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:mem"
import "core:slice"
import "core:strings"
import "core:time"
import rl "vendor:raylib"
import "vendor:raylib/rlgl"
import "fibr"

ANIMATION_TIME :: 90.0
ADDITION_SPEED :: 10
TARGET_FPS :: 60
NUM_SUBSTEPS :: 8
SCR_WIDTH :: 1280
SCR_HEIGHT :: 720
GRAVITY :: -15.0
CONTAINER_RADIUS :: 6.0
VERLET_RADIUS :: 0.15
MAX_INSTANCES :: 10000
DIMENSION :: 58
MAX_PER_CELL :: 4
THREAD_COUNT :: 8

// Types
Vec3 :: [3]f32
Mat4 :: matrix[4, 4]f32

VerletObject :: struct {
    current:      Vec3,
    previous:     Vec3,
    acceleration: Vec3,
    radius:       f32,
}

Camera3D :: struct {
    position: Vec3,
    target:   Vec3,
    up:       Vec3,
    fovy:     f32,
    yaw:      f32,
    pitch:    f32,
}

Mouse :: struct {
    x, y:       f32,
    last_x:     f32,
    last_y:     f32,
    first_move: bool,
}

InstanceData :: struct {
    position: Vec3,
    velocity: f32,
}

// Global variables
camera: Camera3D
camera_radius: f32 = 24.0
total_frames: int = 0
cursor_entered: bool = false
verlets: []VerletObject
num_active: int = 0
container_position: Vec3 = {0, 0, 0}

// Spatial grid for collision detection
grid: [DIMENSION][DIMENSION][DIMENSION][MAX_PER_CELL]^VerletObject

// Shaders
phong_shader: rl.Shader
instance_shader: rl.Shader
base_shader: rl.Shader

// Shader uniform locations
phong_uniforms: struct {
    model_loc: i32,
    view_loc: i32,
    projection_loc: i32,
    light_pos_loc: i32,
    light_color_loc: i32,
    view_pos_loc: i32,
    object_color_loc: i32,
    ambient_strength_loc: i32,
    specular_strength_loc: i32,
    shininess_loc: i32,
}

instance_uniforms: struct {
    scale_loc: i32,
    view_loc: i32,
    projection_loc: i32,
    light_pos_loc: i32,
    light_color_loc: i32,
    view_pos_loc: i32,
    ambient_strength_loc: i32,
}

base_uniforms: struct {
    model_loc: i32,
    view_loc: i32,
    projection_loc: i32,
    light_pos_loc: i32,
    light_color_loc: i32,
    view_pos_loc: i32,
    object_color_loc: i32,
    ambient_strength_loc: i32,
    alpha_loc: i32,
}

// Models
sphere_model: rl.Model
cube_model: rl.Model

// Instance rendering data
instance_buffer: u32
position_buffer: u32
velocity_buffer: u32

// Threading data
ThreadData :: struct {
    thread_id: int,
    start:     int,
    end:       int,
}

init_opengl :: proc() {
    // Init OpenGL settings
    rlgl.EnableDepthTest()
    rlgl.EnableBackfaceCulling()
    rlgl.SetCullFace(rlgl.CullMode.BACK)
    rlgl.EnableColorBlend()
    rlgl.SetBlendMode(cast(i32)rlgl.BlendMode.ALPHA)
    rlgl.SetLineWidth(3.0)
}

load_shaders :: proc() {
    // Load shaders
    phong_shader = rl.LoadShader("assets/shaders/phong.vs", "assets/shaders/phong.fs")
    instance_shader = rl.LoadShader("assets/shaders/instance.vs", "assets/shaders/instance.fs")
    base_shader = rl.LoadShader("assets/shaders/base.vs", "assets/shaders/base.fs")
    
    // Get uniform locations for phong shader
    phong_uniforms.model_loc = rl.GetShaderLocation(phong_shader, "model")
    phong_uniforms.view_loc = rl.GetShaderLocation(phong_shader, "view")
    phong_uniforms.projection_loc = rl.GetShaderLocation(phong_shader, "projection")
    phong_uniforms.light_pos_loc = rl.GetShaderLocation(phong_shader, "lightPos")
    phong_uniforms.light_color_loc = rl.GetShaderLocation(phong_shader, "lightColor")
    phong_uniforms.view_pos_loc = rl.GetShaderLocation(phong_shader, "viewPos")
    phong_uniforms.object_color_loc = rl.GetShaderLocation(phong_shader, "objectColor")
    phong_uniforms.ambient_strength_loc = rl.GetShaderLocation(phong_shader, "ambientStrength")
    phong_uniforms.specular_strength_loc = rl.GetShaderLocation(phong_shader, "specularStrength")
    phong_uniforms.shininess_loc = rl.GetShaderLocation(phong_shader, "shininess")
    
    // Get uniform locations for instance shader
    instance_uniforms.scale_loc = rl.GetShaderLocation(instance_shader, "scale")
    instance_uniforms.view_loc = rl.GetShaderLocation(instance_shader, "view")
    instance_uniforms.projection_loc = rl.GetShaderLocation(instance_shader, "projection")
    instance_uniforms.light_pos_loc = rl.GetShaderLocation(instance_shader, "lightPos")
    instance_uniforms.light_color_loc = rl.GetShaderLocation(instance_shader, "lightColor")
    instance_uniforms.view_pos_loc = rl.GetShaderLocation(instance_shader, "viewPos")
    instance_uniforms.ambient_strength_loc = rl.GetShaderLocation(instance_shader, "ambientStrength")
    
    // Get uniform locations for base shader
    base_uniforms.model_loc = rl.GetShaderLocation(base_shader, "model")
    base_uniforms.view_loc = rl.GetShaderLocation(base_shader, "view")
    base_uniforms.projection_loc = rl.GetShaderLocation(base_shader, "projection")
    base_uniforms.light_pos_loc = rl.GetShaderLocation(base_shader, "lightPos")
    base_uniforms.light_color_loc = rl.GetShaderLocation(base_shader, "lightColor")
    base_uniforms.view_pos_loc = rl.GetShaderLocation(base_shader, "viewPos")
    base_uniforms.object_color_loc = rl.GetShaderLocation(base_shader, "objectColor")
    base_uniforms.ambient_strength_loc = rl.GetShaderLocation(base_shader, "ambientStrength")
    base_uniforms.alpha_loc = rl.GetShaderLocation(base_shader, "alpha")
}

load_models :: proc() {
    // Load 3D models
    sphere_model = rl.LoadModel("assets/models/sphere.obj")
    cube_model = rl.LoadModel("assets/models/cube.obj")
    
    // If models don't exist, create primitive models
    if sphere_model.meshCount == 0 {
        sphere_model = rl.LoadModelFromMesh(rl.GenMeshSphere(1.0, 16, 16))
    }
    if cube_model.meshCount == 0 {
        cube_model = rl.LoadModelFromMesh(rl.GenMeshCube(1.0, 1.0, 1.0))
    }
}

// Simplified instance rendering initialization
init_instance_rendering :: proc() {
    // Create instance buffers - simplified approach
    instance_data := make([]InstanceData, MAX_INSTANCES)
    defer delete(instance_data)
    
    // Init with empty data
    for i in 0..<MAX_INSTANCES {
        instance_data[i] = InstanceData{
            position = {0, 0, 0},
            velocity = 0.0,
        }
    }
    
    // Create buffers using LoadVertexBuffer with proper data
    instance_buffer = rlgl.LoadVertexBuffer(
        raw_data(instance_data), 
        i32(MAX_INSTANCES * size_of(InstanceData)), 
        true
    )
    
    // Create separate buffers for position and velocity
    positions := make([]Vec3, MAX_INSTANCES)
    velocities := make([]f32, MAX_INSTANCES)
    defer delete(positions)
    defer delete(velocities)
    
    position_buffer = rlgl.LoadVertexBuffer(
        raw_data(positions), 
        i32(MAX_INSTANCES * size_of(Vec3)), 
        true
    )
    
    velocity_buffer = rlgl.LoadVertexBuffer(
        raw_data(velocities), 
        i32(MAX_INSTANCES * size_of(f32)), 
        true
    )
}

instantiate_verlets :: proc(objects: []VerletObject, size: int) {
    distance := f32(7.0)
    for i in 0..<size {
        obj := &objects[i]
        x := math.sin(f32(i)) * distance
        z := math.cos(f32(i)) * distance
        xp := math.sin(f32(i)) * distance * 0.999
        zp := math.cos(f32(i)) * distance * 0.999
        y := f32(1 + (i % 2)) // Simple random y between 1-2
        
        obj.current = {x, y, z}
        obj.previous = {xp, y, zp}
        obj.acceleration = {0, 0, 0}
        obj.radius = VERLET_RADIUS
    }
}

apply_forces :: proc(objects: []VerletObject, size: int) {
    for i in 0..<size {
        objects[i].acceleration.y += GRAVITY
    }
}

handle_collision :: proc(a: ^VerletObject, b: ^VerletObject) {
    axis := a.current - b.current
    dist := linalg.length(axis)
    
    if dist < a.radius + b.radius && dist > 0 {
        norm := axis / dist
        delta := a.radius + b.radius - dist
        correction := norm * (0.5 * delta)
        
        a.current += correction
        b.current -= correction
    }
}

clamp_int :: proc(value, min_val, max_val: int) -> int {
    if value < min_val do return min_val
    if value > max_val do return max_val
    return value
}

push_node :: proc(grid_x, grid_y, grid_z: int, obj: ^VerletObject) {
    current_cell := &grid[grid_x][grid_y][grid_z]
    for i in 0..<MAX_PER_CELL {
        if current_cell[i] == nil {
            current_cell[i] = obj
            break
        }
    }
}

fill_grid :: proc(objects: []VerletObject, size: int) {
    for i in 0..<size {
        obj := &objects[i]
        grid_x := int(obj.current.x / (VERLET_RADIUS * 2)) + DIMENSION / 2
        grid_y := int(obj.current.y / (VERLET_RADIUS * 2)) + DIMENSION / 2
        grid_z := int(obj.current.z / (VERLET_RADIUS * 2)) + DIMENSION / 2
        
        grid_x = clamp_int(grid_x, 0, DIMENSION - 1)
        grid_y = clamp_int(grid_y, 0, DIMENSION - 1)
        grid_z = clamp_int(grid_z, 0, DIMENSION - 1)
        
        push_node(grid_x, grid_y, grid_z, obj)
    }
}

clear_grid :: proc() {
    for x in 0..<DIMENSION {
        for y in 0..<DIMENSION {
            for z in 0..<DIMENSION {
                for i in 0..<MAX_PER_CELL {
                    grid[x][y][z][i] = nil
                }
            }
        }
    }
}

handle_grid_collision :: proc(current_cell: ^[MAX_PER_CELL]^VerletObject, other_cell: ^[MAX_PER_CELL]^VerletObject) {
    for a in 0..<MAX_PER_CELL {
        if current_cell[a] == nil do break
        for b in 0..<MAX_PER_CELL {
            if other_cell[b] == nil do break
            if current_cell[a] != other_cell[b] {
                handle_collision(current_cell[a], other_cell[b])
            }
        }
    }
}

collision_thread_worker :: proc(arg: rawptr) {
    data := cast(^ThreadData)arg
    
    for x in data.start..<data.end {
        for y in 1..<DIMENSION-1 {
            for z in 1..<DIMENSION-1 {
                current_cell := &grid[x][y][z]
                if current_cell[0] == nil do continue
                
                for dx in -1..=1 {
                    for dy in -1..=1 {
                        for dz in -1..=1 {
                            other_cell := &grid[x + dx][y + dy][z + dz]
                            if other_cell[0] == nil do continue
                            handle_grid_collision(current_cell, other_cell)
                        }
                    }
                }
            }
        }
    }
}

apply_grid_collisions :: proc(objects: []VerletObject, size: int) {
    clear_grid()
    fill_grid(objects, size)
    
    // Create threads for collision detection
    threads: [THREAD_COUNT]fibr.Thread
    thread_data: [THREAD_COUNT]ThreadData
    
    for t in 0..<THREAD_COUNT {
        thread_data[t].thread_id = t
        thread_data[t].start = 1 + t * (DIMENSION / THREAD_COUNT)
        thread_data[t].end = 1 + (t + 1) * (DIMENSION / THREAD_COUNT)
        
        if t == THREAD_COUNT - 1 {
            thread_data[t].end += DIMENSION % THREAD_COUNT - 2
        }
        
        fibr.spawn(&threads[t], collision_thread_worker, &thread_data[t])
    }
    
    // Wait for all threads to complete
    for t in 0..<THREAD_COUNT {
        fibr.join(&threads[t])
    }
}

apply_constraints :: proc(objects: []VerletObject, size: int, container_pos: Vec3) {
    b_width:f32 = CONTAINER_RADIUS
    
    for i in 0..<size {
        obj := &objects[i]
        
        // X constraints
        if obj.current.x < -b_width + container_pos.x {
            disp := obj.current.x - obj.previous.x
            obj.current.x = -b_width + container_pos.x
            obj.previous.x = obj.current.x + disp
        }
        if obj.current.x > b_width + container_pos.x {
            disp := obj.current.x - obj.previous.x
            obj.current.x = b_width + container_pos.x
            obj.previous.x = obj.current.x + disp
        }
        
        // Y constraints
        if obj.current.y < -b_width + container_pos.y {
            disp := obj.current.y - obj.previous.y
            obj.current.y = -b_width + container_pos.y
            obj.previous.y = obj.current.y + disp
        }
        if obj.current.y > b_width + container_pos.y {
            disp := obj.current.y - obj.previous.y
            obj.current.y = b_width + container_pos.y
            obj.previous.y = obj.current.y + disp
        }
        
        // Z constraints
        if obj.current.z < -b_width + container_pos.z {
            disp := obj.current.z - obj.previous.z
            obj.current.z = -b_width + container_pos.z
            obj.previous.z = obj.current.z + disp
        }
        if obj.current.z > b_width + container_pos.z {
            disp := obj.current.z - obj.previous.z
            obj.current.z = b_width + container_pos.z
            obj.previous.z = obj.current.z + disp
        }
    }
}

update_positions :: proc(objects: []VerletObject, size: int, dt: f32) {
    for i in 0..<size {
        obj := &objects[i]
        
        disp := obj.current - obj.previous
        obj.previous = obj.current
        obj.acceleration *= dt * dt
        obj.current += disp + obj.acceleration
        obj.acceleration = {0, 0, 0}
    }
}

add_force :: proc(objects: []VerletObject, size: int, center: Vec3, strength: f32) {
    for i in 0..<size {
        obj := &objects[i]
        disp := obj.current - center
        dist := linalg.length(disp)
        
        if dist > 0 {
            norm := disp / dist
            force := norm * strength
            obj.acceleration += force
        }
    }
}

update_camera :: proc(camera: ^Camera3D, dt: f32) {
    speed := f32(0.08)
    
    // Orbital camera movement
    universal_angle := f32(total_frames) / 4.0
    angle_rad := math.to_radians(universal_angle)
    
    camera.position.x = math.cos(angle_rad) * camera_radius
    camera.position.z = math.sin(angle_rad) * camera_radius
    camera.yaw = universal_angle + 180.0
    
    // Manual camera controls
    if rl.IsKeyDown(.W) {
        camera.position += camera.up * speed
        camera.pitch -= 0.22
        camera_radius -= 0.01
    }
    if rl.IsKeyDown(.S) {
        camera.position -= camera.up * speed
        camera.pitch += 0.22
        camera_radius += 0.01
    }
    
    // Update camera target to look at origin
    camera.target = {0, 0, 0}
}

// Fixed uniform setting using cached locations
set_instance_uniforms :: proc(projection: rl.Matrix, view: rl.Matrix) {
    light_pos := Vec3{10.0, 10.0, 10.0}
    light_color := Vec3{1.0, 1.0, 1.0}
    ambient_strength := f32(0.3)
    scale := VERLET_RADIUS
    
    rl.SetShaderValue(instance_shader, instance_uniforms.light_pos_loc, &light_pos, rl.ShaderUniformDataType.VEC3)
    rl.SetShaderValue(instance_shader, instance_uniforms.light_color_loc, &light_color, rl.ShaderUniformDataType.VEC3)
    rl.SetShaderValue(instance_shader, instance_uniforms.view_pos_loc, &camera.position, rl.ShaderUniformDataType.VEC3)
    rl.SetShaderValue(instance_shader, instance_uniforms.ambient_strength_loc, &ambient_strength, rl.ShaderUniformDataType.FLOAT)
    rl.SetShaderValue(instance_shader, instance_uniforms.scale_loc, &scale, rl.ShaderUniformDataType.FLOAT)
    rl.SetShaderValueMatrix(instance_shader, instance_uniforms.projection_loc, projection)
    rl.SetShaderValueMatrix(instance_shader, instance_uniforms.view_loc, view)
}

set_base_uniforms :: proc(projection: rl.Matrix, view: rl.Matrix) {
    light_pos := Vec3{10.0, 10.0, 10.0}
    light_color := Vec3{1.0, 1.0, 1.0}
    ambient_strength := f32(0.3)
    
    rl.SetShaderValue(base_shader, base_uniforms.light_pos_loc, &light_pos, rl.ShaderUniformDataType.VEC3)
    rl.SetShaderValue(base_shader, base_uniforms.light_color_loc, &light_color, rl.ShaderUniformDataType.VEC3)
    rl.SetShaderValue(base_shader, base_uniforms.view_pos_loc, &camera.position, rl.ShaderUniformDataType.VEC3)
    rl.SetShaderValue(base_shader, base_uniforms.ambient_strength_loc, &ambient_strength, rl.ShaderUniformDataType.FLOAT)
    rl.SetShaderValueMatrix(base_shader, base_uniforms.projection_loc, projection)
    rl.SetShaderValueMatrix(base_shader, base_uniforms.view_loc, view)
}

// Simplified instanced rendering without advanced OpenGL features
draw_instanced_spheres :: proc(objects: []VerletObject, size: int, projection: rl.Matrix, view: rl.Matrix) {
    if size == 0 do return
    
    // For now, we'll use individual sphere rendering instead of true instancing
    // This is because the advanced OpenGL instancing features may not be fully available
    for i in 0..<size {
        obj := &objects[i]
        
        // Calculate model matrix for this sphere
        model := rl.MatrixScale(obj.radius * 2, obj.radius * 2, obj.radius * 2)
        model *= rl.MatrixTranslate(obj.current.x, obj.current.y, obj.current.z)
        
        // Calculate velocity for color
        velocity := linalg.length(obj.current - obj.previous)
        color_intensity := u8(clamp(velocity * 100, 0, 255))
        color := rl.Color{255, 255 - color_intensity, 255 - color_intensity, 255}
        
        // Draw sphere
        rl.DrawModel(sphere_model, obj.current, obj.radius * 2, color)
    }
}

draw_container :: proc(position: Vec3, size: f32, projection: rl.Matrix, view: rl.Matrix) {
    rl.BeginShaderMode(base_shader)
    
    // Set uniforms using cached locations
    set_base_uniforms(projection, view)
    
    // Set container-specific uniforms
    object_color := Vec3{1.0, 1.0, 1.0}
    alpha := f32(0.2)
    model := rl.MatrixScale(size, size, size)
    model *= rl.MatrixTranslate(position.x, position.y, position.z)
    
    rl.SetShaderValue(base_shader, base_uniforms.object_color_loc, &object_color, rl.ShaderUniformDataType.VEC3)
    rl.SetShaderValue(base_shader, base_uniforms.alpha_loc, &alpha, rl.ShaderUniformDataType.FLOAT)
    rl.SetShaderValueMatrix(base_shader, base_uniforms.model_loc, model)
    
    rl.DrawModel(cube_model, {0, 0, 0}, 1.0, rl.Color{255, 255, 255, 50})
    
    rl.EndShaderMode()
}

main :: proc() {
    // Init Raylib
    rl.InitWindow(SCR_WIDTH, SCR_HEIGHT, "Verlet Integration - Odin")
    defer rl.CloseWindow()
    
    rl.SetTargetFPS(TARGET_FPS)
    
    // Init OpenGL settings
    init_opengl()
    
    // Load shaders and models
    load_shaders()
    defer {
        rl.UnloadShader(phong_shader)
        rl.UnloadShader(instance_shader)
        rl.UnloadShader(base_shader)
    }
    
    load_models()
    defer {
        rl.UnloadModel(sphere_model)
        rl.UnloadModel(cube_model)
    }
    
    // Init instance rendering
    init_instance_rendering()
    
    // Init camera
    camera = Camera3D{
        position = {0, 0, camera_radius},
        target = {0, 0, 0},
        up = {0, 1, 0},
        fovy = 45.0,
        yaw = 0,
        pitch = 0,
    }
    
    // Init Verlet objects
    verlets = make([]VerletObject, MAX_INSTANCES)
    defer delete(verlets)
    instantiate_verlets(verlets, MAX_INSTANCES)
    
    // Main loop
    dt: f32 = 0.000001
    last_frame_time := rl.GetTime()
    
    for !rl.WindowShouldClose() {
        current_time := rl.GetTime()
        dt = f32(current_time - last_frame_time)
        
        // Input handling
        if rl.IsKeyPressed(.ESCAPE) do break
        
        // Add gravity force
        if rl.IsKeyDown(.G) {
            add_force(verlets, num_active, {0, 3, 0}, -30.0 * NUM_SUBSTEPS)
        }
        
        // Add more particles
        if 1.0/dt >= TARGET_FPS - 5 && rl.IsKeyDown(.V) && num_active < MAX_INSTANCES {
            num_active += ADDITION_SPEED
            if num_active > MAX_INSTANCES do num_active = MAX_INSTANCES
        }
        
        // Container movement
        if rl.IsKeyDown(.LEFT) do container_position.x -= 0.05
        if rl.IsKeyDown(.RIGHT) do container_position.x += 0.05
        if rl.IsKeyDown(.DOWN) do container_position.y -= 0.05
        if rl.IsKeyDown(.UP) do container_position.y += 0.05
        
        // Update camera
        update_camera(&camera, dt)
        
        // Physics simulation with substeps
        sub_dt := dt / NUM_SUBSTEPS
        for _ in 0..<NUM_SUBSTEPS {
            apply_forces(verlets, num_active)
            apply_grid_collisions(verlets, num_active)
            apply_constraints(verlets, num_active, container_position)
            update_positions(verlets, num_active, sub_dt)
        }
        
        // Update window title with FPS and particle count
        if total_frames % 60 == 0 {
            fps := 1.0 / dt
            title := fmt.tprintf("FPS: %.0f | Balls: %d", fps, num_active)
            rl.SetWindowTitle(strings.clone_to_cstring(title))
        }
        
        // Rendering
        rl.BeginDrawing()
        rl.ClearBackground(rl.Color{25, 25, 25, 255})
        
        // 3D rendering
        raylib_camera := rl.Camera3D{
            position = camera.position,
            target = camera.target,
            up = camera.up,
            fovy = camera.fovy,
            projection = .PERSPECTIVE,
        }
        
        // Get proper 3D matrices
        aspect := f32(SCR_WIDTH) / f32(SCR_HEIGHT)
        projection := rl.MatrixPerspective(math.to_radians(camera.fovy), aspect, 0.1, 1000.0)
        view := rl.MatrixLookAt(camera.position, camera.target, camera.up)
        
        rl.BeginMode3D(raylib_camera)
        
        // Draw particles with instanced rendering
        draw_instanced_spheres(verlets, num_active, projection, view)
        
        // Draw container
        container_size :: CONTAINER_RADIUS * 2 + VERLET_RADIUS * 3
        draw_container(container_position, container_size, projection, view)
        
        rl.EndMode3D()
        
        // Draw UI
        rl.DrawText("Controls:", 10, 10, 20, rl.WHITE)
        rl.DrawText("V - Add particles", 10, 35, 16, rl.WHITE)
        rl.DrawText("G - Apply upward force", 10, 55, 16, rl.WHITE)
        rl.DrawText("Arrow keys - Move container", 10, 75, 16, rl.WHITE)
        rl.DrawText("W/S - Camera zoom", 10, 95, 16, rl.WHITE)
        
        rl.EndDrawing()
        
        // Frame limiting
        for dt < 1.0/TARGET_FPS {
            current_time = rl.GetTime()
            dt = f32(current_time - last_frame_time)
        }
        
        last_frame_time = current_time
        total_frames += 1
    }
}