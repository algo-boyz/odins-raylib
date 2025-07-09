package main

import "core:fmt"
import "core:os"
import "core:time"
import rl "vendor:raylib"
import rlgl "vendor:raylib/rlgl"
import "../../../rlutil"

SCREEN_WIDTH :: 1280
SCREEN_HEIGHT :: 720

PLANE_MESH: rl.Mesh
PLANE_MESH_MATERIAL: rl.Material

CAMERA_DEFAULT := rl.Camera3D{
	position   = {0.0, 0.5, 1.8},
	target     = {0.0, 0.5, 0.0},
	up         = {0.0, 1.0, 0.0},
	fovy       = 40.0,
	projection = .PERSPECTIVE,
}
ASPECT: f32 = 1.0
CAMERA: rl.Camera3D = CAMERA_DEFAULT
BACKGROUND_COLOR := rl.Color{20, 20, 20, 255}

Message :: struct {
	text:         string,
	color:        rl.Color,
	time_created: f32,
}

MESSAGE := Message{"", rl.WHITE, 0.0}
TIME: f32 = 0.0

SHADER_WATCHER: rlutil.ShaderWatcher
BASE_VERT_SHADER :: "assets/shader/base.vs"
ERROR_FRAG_SHADER :: "assets/shader/error.fs"

// List of fragment shaders
SHADER_FILES := []string{
	"anisotropic.fs",
	"beer_lambert.fs",
	"black_hole.fs",
	"cube.fs",
	"dome.fs",
	"fabric.fs",
	"fbm.fs",
	"gargantua.fs",
	"golf_ball.fs",
	"hexagon.fs",
	"ice_fire.fs",
	"kaleidoscope.fs",
	"matrix.fs",
	"ocean.fs",
	"perlin.fs",
	"plot.fs",
	"pseudo_perlin.fs",
	"sauron.fs",
	"sd_outline.fs",
	"sd_spectrum.fs",
	"signal2noise.fs",
	"simplex.fs",
	"sky_perf.fs",
	"sky.fs",
	"sphere.fs",
	"spider_web.fs",
	"spiral.fs",
	"tiled_city.fs",
	"tree_ditter.fs",
	"voro_hell.fs",
	"voro_noise.fs",
	"voronoi.fs",
	"water_fire.fs",
	"water.fs",
	"white_hole.fs",
	"wind.fs",
	"worms.fs",
}

get_shader_path :: proc(file_name: string) -> string {
    return fmt.tprintf("assets/shader/%s", file_name)
}

isect_ray_plane :: proc(ray: rl.Ray, plane_p: rl.Vector3, plane_normal: rl.Vector3) -> rl.RayCollision {
	result := rl.RayCollision{}
	result.hit = false
	normal := rl.Vector3Normalize(plane_normal)
	denom := rl.Vector3DotProduct(normal, ray.direction)

	if abs(denom) > 0.0001 {
		diff := plane_p - ray.position
		t := rl.Vector3DotProduct(diff, normal) / denom
		if t >= 0.0 {
			result.hit = true
			result.distance = t
			result.point = ray.position + (ray.direction * t)
			result.normal = denom < 0.0 ? normal : normal * -1.0
		}
	}
	return result
}

reset_camera :: proc() {
	CAMERA = CAMERA_DEFAULT
	MESSAGE = {"Camera reset", rl.GREEN, f32(rl.GetTime())}
	if ASPECT != 1.0 do CAMERA.position.z += 1.0
}

handle_input :: proc() {
    if rl.IsKeyPressed(.RIGHT) {
        rlutil.watcher_next(&SHADER_WATCHER)
        name := rlutil.watcher_get_current_name(&SHADER_WATCHER)
        MESSAGE = {fmt.tprintf("Shader: %s", name), rl.GREEN, f32(rl.GetTime())}
    }
    if rl.IsKeyPressed(.LEFT) {
        rlutil.watcher_previous(&SHADER_WATCHER)
        name := rlutil.watcher_get_current_name(&SHADER_WATCHER)
        MESSAGE = {fmt.tprintf("Shader: %s", name), rl.GREEN, f32(rl.GetTime())}
    }

	if rl.IsKeyPressed(.R) do reset_camera()
	if rl.IsKeyPressed(.ONE) {
		ASPECT = 1.0
		reset_camera()
	}
	if rl.IsKeyPressed(.TWO) {
		ASPECT = 16.0 / 9.0
		reset_camera()
	}

	TIME += rl.GetFrameTime()
}

update_camera :: proc() {
	rot_speed: f32 = 0.003
	move_speed: f32 = 0.01
	zoom_speed: f32 = 0.1
	is_mmb_down := rl.IsMouseButtonDown(.MIDDLE)
	is_shift_down := rl.IsKeyDown(.LEFT_SHIFT)
	mouse_delta := rl.GetMouseDelta()
	is_moving := is_mmb_down && is_shift_down
	is_rotating := is_mmb_down && !is_shift_down
	if is_moving {
		rl.CameraMoveRight(&CAMERA, -move_speed * mouse_delta.x, true)
		z := rl.GetCameraForward(&CAMERA)
		x := rl.Vector3Normalize(rl.Vector3CrossProduct(z, {0.0, 1.0, 0.0}))
		y := rl.Vector3Normalize(rl.Vector3CrossProduct(x, z))
		up := y * move_speed * mouse_delta.y
		CAMERA.position = CAMERA.position + up
		CAMERA.target = CAMERA.target + up
	}
	if is_rotating {
		rl.CameraYaw(&CAMERA, -rot_speed * mouse_delta.x, true)
		rl.CameraPitch(&CAMERA, rot_speed * mouse_delta.y, true, true, false)
	}
	rl.CameraMoveToTarget(&CAMERA, -rl.GetMouseWheelMove() * zoom_speed)
}

draw_message :: proc() {
	current_time := rl.GetTime()
	message_age := current_time - f64(MESSAGE.time_created)
	if message_age < 10.0 {
		alpha := 1.0 - (message_age / 10.0)
		message_color := rl.Color{MESSAGE.color.r, MESSAGE.color.g, MESSAGE.color.b, u8(255 * alpha)}
		text_height: i32 = 30
		text_width := rl.MeasureText(fmt.ctprint(MESSAGE.text), text_height)
		text_x := f32(rl.GetScreenWidth()) / 2 - f32(text_width) / 2
		text_y := 10
		rl.DrawText(fmt.ctprint(MESSAGE.text), i32(text_x), i32(text_y), i32(text_height), message_color)
	}
}

load :: proc() {
    rl.SetConfigFlags({.MSAA_4X_HINT, .WINDOW_RESIZABLE})
    rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "shaderbox")
    rl.SetTargetFPS(60)
    rlgl.EnableDepthTest()
    PLANE_MESH = rl.GenMeshPlane(1.0, 1.0, 2, 2)
    // Initialize the watcher
    ok: bool
    SHADER_WATCHER, ok = rlutil.watcher_create(BASE_VERT_SHADER, ERROR_FRAG_SHADER, SHADER_FILES)
    if !ok {
        os.exit(1) // Exit if the error shader fails to load.
    }
    PLANE_MESH_MATERIAL = rl.LoadMaterialDefault()
    // The material's shader will be updated each frame in draw_plane.
}

unload :: proc() {
    rlutil.watcher_destroy(&SHADER_WATCHER)
    rl.UnloadMesh(PLANE_MESH)
    rl.CloseWindow()
}

draw_plane :: proc() {
	mat := PLANE_MESH_MATERIAL
    mat.shader = rlutil.watcher_get_current(&SHADER_WATCHER)
    mouse_ray := rl.GetScreenToWorldRay(rl.GetMousePosition(), CAMERA)
	collision := isect_ray_plane(mouse_ray, {0.0, 0.0, 0.0}, {0.0, 0.0, -1.0})
	mouse_pos := rl.Vector2{
		rl.Clamp((collision.point.x / ASPECT) + 0.5, 0.0, 1.0),
		rl.Clamp(collision.point.y + 0.5, 0.0, 1.0),
	}
    resolution := rl.Vector2{f32(rl.GetScreenWidth()), f32(rl.GetScreenHeight())}

	rl.SetShaderValue(mat.shader, rl.GetShaderLocation(mat.shader, "u_time"), &TIME, .FLOAT)
	rl.SetShaderValue(mat.shader, rl.GetShaderLocation(mat.shader, "u_aspect"), &ASPECT, .FLOAT)
	rl.SetShaderValue(mat.shader, rl.GetShaderLocation(mat.shader, "u_mouse_pos"), &mouse_pos, .VEC2)
    rl.SetShaderValue(mat.shader, rl.GetShaderLocation(mat.shader, "u_resolution"), &resolution, .VEC2)

	r := rl.MatrixRotateX(0.5 * rl.PI)
	s := rl.MatrixScale(ASPECT, 1.0, 1.0)
	t := rl.MatrixTranslate(0.0, 0.5, 0.0)
	transform := t * (s * r)
	rl.DrawMesh(PLANE_MESH, mat, transform)
}

watch_shaders :: proc() {
	update_result := rlutil.watcher_update(&SHADER_WATCHER)
	if update_result != .NoChange {
		name := rlutil.watcher_get_current_name(&SHADER_WATCHER)
		if update_result == .ReloadSuccess {
			MESSAGE = {fmt.tprintf("Reloaded %s", name), rl.GREEN, f32(rl.GetTime())}
		} else {
			MESSAGE = {fmt.tprintf("Reload failed for %s", name), rl.RED, f32(rl.GetTime())}
		}
	}
}

main :: proc() {
    load()
    defer unload()
    for !rl.WindowShouldClose() {
		watch_shaders()
        handle_input()
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
}