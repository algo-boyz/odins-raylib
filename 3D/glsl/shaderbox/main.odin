package main

import "core:fmt"
import "core:os"
import "core:strings"
import "core:time"
import "core:thread"
import "core:sys/unix"
import rl "vendor:raylib"
import "vendor:raylib/rlgl"

SCREEN_WIDTH :: 1280
SCREEN_HEIGHT :: 720

BACKGROUND_COLOR := rl.Color{20, 20, 20, 255}

PLANE_MESH: rl.Mesh
PLANE_MESH_MATERIAL: rl.Material

CAMERA_DEFAULT := rl.Camera3D{
    position = {0.0, 0.5, 1.8},
    target = {0.0, 0.5, 0.0},
    up = {0.0, 1.0, 0.0},
    fovy = 40.0,
    projection = rl.CameraProjection.PERSPECTIVE,
}

ASPECT: f32 = 1.0
CAMERA: rl.Camera3D = CAMERA_DEFAULT

Message :: struct {
    text: string,
    color: rl.Color,
    time_created: f32,
}

MESSAGE := Message{"", rl.WHITE, 0.0}
TIME: f32 = 0.0

ShaderInfo :: struct {
    shader: rl.Shader,
    is_success: bool,
    vs_last_modified: time.Time,
    fs_last_modified: time.Time,
}

PLANE_MESH_SHADER_INFO: ShaderInfo
ERROR_SHADER_INFO: ShaderInfo

isect_ray_plane :: proc(ray: rl.Ray, plane_p: rl.Vector3, plane_normal: rl.Vector3) -> rl.RayCollision {
    result := rl.RayCollision{}
    result.hit = false

    // Normalize plane normal
    normal := rl.Vector3Normalize(plane_normal)

    // Check if ray and plane are parallel
    denom := rl.Vector3DotProduct(normal, ray.direction)

    if abs(denom) > 0.0001 {  // Not parallel
        // Calculate distance to intersection point
        diff := plane_p - ray.position
        t := rl.Vector3DotProduct(diff, normal) / denom

        // Check if intersection is in front of ray origin
        if t >= 0.0 {
            result.hit = true
            result.distance = t
            result.point = ray.position + (ray.direction * t)
            result.normal = denom < 0.0 ? normal : normal * -1.0
        }
    }
    return result
}

get_shader_file_path :: proc(file_name: string) -> string {
    return fmt.tprintf("assets/shader/%s", file_name)
}

load_shader_src :: proc(file_name: string) -> string {
    version_src := "#version 330"
    
    common_path := get_shader_file_path("common.fs")
    shader_path := get_shader_file_path(file_name)
    
    common_data, common_ok := os.read_entire_file(common_path)
    shader_data, shader_ok := os.read_entire_file(shader_path)
    
    if !common_ok || !shader_ok {
        return ""
    }
    
    common_src := string(common_data)
    shader_src := string(shader_data)
    
    // full_src := fmt.tprintf("%s\n%s\n%s", version_src, common_src, shader_src)
    full_src := fmt.tprintf("%s\n%s", common_src, shader_src)
    
    return full_src
}

get_last_modified_time :: proc(file_path: string) -> time.Time {
    stat, err := os.stat(file_path)
    if err != nil {
        fmt.println("Error getting file stat for modified time:", err)
        return time.now()
    }
    return stat.modification_time
}

load_shader :: proc(vs_file_name: string, fs_file_name: string) -> ShaderInfo {
    vs := load_shader_src(vs_file_name)
    fs := load_shader_src(fs_file_name)
    
    shader := rl.LoadShaderFromMemory(fmt.ctprint(vs), fmt.ctprint(fs))
    is_success := true
    
    if !rl.IsShaderReady(shader) {
        // || shader.id == rl.GetShaderIdDefault() {
        MESSAGE = {"ERROR: Failed to load shader", rl.RED, f32(rl.GetTime())}
        is_success = false
    }
    
    return ShaderInfo{
        shader = shader,
        is_success = is_success,
        vs_last_modified = get_last_modified_time(get_shader_file_path(vs_file_name)),
        fs_last_modified = get_last_modified_time(get_shader_file_path(fs_file_name)),
    }
}

update_shader :: proc() {
    counter := 0
    counter += 1
    if counter % 10 != 0 do return
    
    vs_current_time := get_last_modified_time(get_shader_file_path("base.vs"))
    fs_current_time := get_last_modified_time(get_shader_file_path("plane.fs"))
    
    if time.diff(vs_current_time, PLANE_MESH_SHADER_INFO.vs_last_modified) > 0 ||
       time.diff(fs_current_time, PLANE_MESH_SHADER_INFO.fs_last_modified) > 0 {
        
        TIME = 0.0
        // Add small delay to ensure file write is complete
        time.accurate_sleep(100 * time.Millisecond)
        
        shader_info := load_shader("base.vs", "plane.fs")
        rl.UnloadShader(PLANE_MESH_SHADER_INFO.shader)
        PLANE_MESH_SHADER_INFO = shader_info
        PLANE_MESH_MATERIAL.shader = PLANE_MESH_SHADER_INFO.shader
        
        if shader_info.is_success {
            MESSAGE = {"Shader loaded", rl.GREEN, f32(rl.GetTime())}
        } else {
            MESSAGE = {"Failed to load shader", rl.RED, f32(rl.GetTime())}
            PLANE_MESH_MATERIAL.shader = ERROR_SHADER_INFO.shader
        }
    }
}

reset_camera :: proc() {
    CAMERA = CAMERA_DEFAULT
    MESSAGE = {"Camera reset", rl.GREEN, f32(rl.GetTime())}
    
    if ASPECT != 1.0 do CAMERA.position.z += 1.0
}

update_input :: proc() {
    if rl.IsKeyPressed(rl.KeyboardKey.R) {
        reset_camera()
    }
    
    if rl.IsKeyPressed(rl.KeyboardKey.ONE) {
        ASPECT = 1.0
        reset_camera()
    }
    
    if rl.IsKeyPressed(rl.KeyboardKey.TWO) {
        ASPECT = 16.0 / 9.0
        reset_camera()
    }
    
    TIME += rl.GetFrameTime()
}

update_camera :: proc() {
    rot_speed: f32 = 0.003
    move_speed: f32 = 0.01
    zoom_speed: f32 = 0.1
    
    is_mmb_down := rl.IsMouseButtonDown(rl.MouseButton.MIDDLE)
    is_shift_down := rl.IsKeyDown(rl.KeyboardKey.LEFT_SHIFT)
    mouse_delta := rl.GetMouseDelta()
    
    is_moving := is_mmb_down && is_shift_down
    is_rotating := is_mmb_down && !is_shift_down
    
    // move
    if is_moving {
        rl.CameraMoveRight(&CAMERA, -move_speed * mouse_delta.x, true)
        
        // camera basis
        z := rl.GetCameraForward(&CAMERA)
        x := rl.Vector3Normalize(rl.Vector3CrossProduct(z, {0.0, 1.0, 0.0}))
        y := rl.Vector3Normalize(rl.Vector3CrossProduct(x, z))
        
        up := y * move_speed * mouse_delta.y
        
        CAMERA.position = CAMERA.position + up
        CAMERA.target = CAMERA.target + up
    }
    
    // rotate
    if is_rotating {
        rl.CameraYaw(&CAMERA, -rot_speed * mouse_delta.x, true)
        rl.CameraPitch(&CAMERA, rot_speed * mouse_delta.y, true, true, false)
    }
    
    // zoom
    rl.CameraMoveToTarget(&CAMERA, -rl.GetMouseWheelMove() * zoom_speed)
}

draw_message :: proc() {
    current_time := rl.GetTime()
    message_age := current_time - f64(MESSAGE.time_created)
    
    if message_age < 10.0 {
        alpha := 1.0 - (message_age / 10.0)
        message_color := rl.Color{
            MESSAGE.color.r,
            MESSAGE.color.g,
            MESSAGE.color.b,
            u8(255 * alpha),
        }
        
        text_height:i32 = 30
        text_width := rl.MeasureText(fmt.ctprint(MESSAGE.text), text_height)
        text_x := f32(rl.GetScreenWidth()) / 2 - f32(text_width) / 2
        text_y := 10
        
        rl.DrawText(fmt.ctprint(MESSAGE.text), i32(text_x), i32(text_y), i32(text_height), message_color)
    }
}

load :: proc() {
    // window
    rl.SetConfigFlags({.MSAA_4X_HINT, .WINDOW_RESIZABLE})
    rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "shaderbox")
    rl.SetTargetFPS(60)
    
    rlgl.EnableDepthTest()
    
    // meshes
    PLANE_MESH = rl.GenMeshPlane(1.0, 1.0, 2, 2)
    
    // materials
    PLANE_MESH_SHADER_INFO = load_shader("base.vs", "clouds.fs")
    ERROR_SHADER_INFO = load_shader("base.vs", "error.fs")
    
    PLANE_MESH_MATERIAL = rl.LoadMaterialDefault()
    PLANE_MESH_MATERIAL.shader = PLANE_MESH_SHADER_INFO.shader
}

unload :: proc() {
    rl.UnloadMesh(PLANE_MESH)
    rl.CloseWindow()
}

draw_plane :: proc() {
    material := PLANE_MESH_MATERIAL
    shader := material.shader
    
    mouse_ray := rl.GetScreenToWorldRay(rl.GetMousePosition(), CAMERA)
    collision := isect_ray_plane(mouse_ray, {0.0, 0.0, 0.0}, {0.0, 0.0, -1.0})
    mouse_pos := rl.Vector2{
        rl.Clamp((collision.point.x / ASPECT) + 0.5, 0.0, 1.0),
        rl.Clamp(collision.point.y + 0.5, 0.0, 1.0),
    }
    
    time_loc := rl.GetShaderLocation(shader, "u_time")
    aspect_loc := rl.GetShaderLocation(shader, "u_aspect")
    mouse_pos_loc := rl.GetShaderLocation(shader, "u_mouse_pos")
    
    rl.SetShaderValue(shader, time_loc, &TIME, .FLOAT)
    rl.SetShaderValue(shader, aspect_loc, &ASPECT, .FLOAT)
    rl.SetShaderValue(shader, mouse_pos_loc, &mouse_pos, .VEC2)
    
    // First rotate
    r := rl.MatrixRotateX(0.5 * rl.PI)

    // Then scale
    s := rl.MatrixScale(ASPECT, 1.0, 1.0)

    // Finally translate
    t := rl.MatrixTranslate(0.0, 0.5, 0.0)

    // T(S(R(P)))
    transform := t * (s * r)
    
    rl.DrawMesh(PLANE_MESH, material, transform)
}

main :: proc() {
    load()
    
    for !rl.WindowShouldClose() {
        update_shader()
        update_input()
        update_camera()
        
        rl.BeginDrawing()
        rl.ClearBackground(BACKGROUND_COLOR)
        
        rl.BeginMode3D(CAMERA)
        
        draw_plane()
        
        rl.EndMode3D()
        
        draw_message()
        rl.DrawFPS(10, 10)
        rl.EndDrawing()
    }
    
    unload()
}