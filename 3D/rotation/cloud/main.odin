package main

import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:slice"
import rl "vendor:raylib"

POINT_RADIUS :: 0.05

PanOrbitCamera :: struct {
	target:          rl.Vector3,
	distance,
	angle_yaw,
	angle_pitch,
	distance_min,
	distance_max,
	angle_pitch_min,
	angle_pitch_max,
	mouse_speed,
	pan_speed,
	zoom_speed:      f32,
}

init_pan_orbit_camera :: proc(target: rl.Vector3, distance: f32) -> PanOrbitCamera {
	pi_2 :: math.PI / 2
	return PanOrbitCamera {
		target = target,
		distance = distance,
		angle_yaw = pi_2 / 2,
		angle_pitch = pi_2 / 2,
		distance_min = 1.0,
		distance_max = 100.0,
		angle_pitch_min = -pi_2 + 0.01,
		angle_pitch_max = pi_2 - 0.01,
		mouse_speed = 0.005,
		zoom_speed = 2.0,
		pan_speed = 0.001,
	}
}

update_pan_orbit_camera :: proc(camera: ^PanOrbitCamera) -> rl.Camera {
	dt := rl.GetFrameTime()
	mouse_delta := rl.GetMouseDelta()
	// Mouse orbit controls
	if rl.IsMouseButtonDown(.RIGHT) {
		camera.angle_yaw -= mouse_delta.x * camera.mouse_speed
		camera.angle_pitch += mouse_delta.y * camera.mouse_speed
		camera.angle_pitch = math.clamp(
			camera.angle_pitch,
			camera.angle_pitch_min,
			camera.angle_pitch_max,
		)
	}
	// Mouse zoom controls
	mouse_scroll := rl.GetMouseWheelMove()
	if mouse_scroll != 0 {
		camera.distance -= mouse_scroll * camera.zoom_speed
		camera.distance = math.clamp(camera.distance, camera.distance_min, camera.distance_max)
	}
	cos_y := math.cos(camera.angle_pitch)
	sin_y := math.sin(camera.angle_pitch)
	cos_x := math.cos(camera.angle_yaw)
	sin_x := math.sin(camera.angle_yaw)
	// Mouse pan controls
	if rl.IsMouseButtonDown(.MIDDLE) {
		right := rl.Vector3{-sin_x, cos_x, 0}
		forward := rl.Vector3{cos_y * cos_x, cos_y * sin_x, sin_y}
		up := rl.Vector3 {
			forward.y * right.z - forward.z * right.y,
			forward.z * right.x - forward.x * right.z,
			forward.x * right.y - forward.y * right.x,
		}
		pan_distance := camera.distance * camera.pan_speed
		camera.target.x -= (right.x * mouse_delta.x - up.x * mouse_delta.y) * pan_distance
		camera.target.y -= (right.y * mouse_delta.x - up.y * mouse_delta.y) * pan_distance
		camera.target.z -= (right.z * mouse_delta.x - up.z * mouse_delta.y) * pan_distance
	}
	position := rl.Vector3 {
		camera.target.x + camera.distance * cos_y * cos_x,
		camera.target.y + camera.distance * cos_y * sin_x,
		camera.target.z + camera.distance * sin_y,
	}
	return rl.Camera {
		position = position,
		target = camera.target,
		up = {0.0, 0.0, 1.0},
		projection = .PERSPECTIVE,
		fovy = 45.0,
	}
}

draw_axis :: proc(mat: rl.Matrix) {
	origin := rl.Vector3{mat[0, 3], mat[1, 3], mat[2, 3]}
	x_axis := rl.Vector3{mat[0, 0], mat[1, 0], mat[2, 0]}
	y_axis := rl.Vector3{mat[0, 1], mat[1, 1], mat[2, 1]}
	z_axis := rl.Vector3{mat[0, 2], mat[1, 2], mat[2, 2]}
	rl.DrawSphere(origin, 0.1, rl.PINK)
	rl.DrawCylinderEx(origin, origin + x_axis, 0.02, 0.02, 10, rl.RED)
	rl.DrawCylinderEx(origin, origin + y_axis, 0.02, 0.02, 10, rl.GREEN)
	rl.DrawCylinderEx(origin, origin + z_axis, 0.02, 0.02, 10, rl.BLUE)
}

draw_points :: proc(pts: ^[]rl.Vector3, sel: ^PointSelection) {
	for pt, i in pts {
		is_selected := false
		for index: uint = 0; index < sel.size; index += 1 {
			if uint(i) == sel.indexes[index] {
				is_selected = true
				break
			}
		}
		if is_selected {
			rl.DrawSphere(pt, POINT_RADIUS, rl.YELLOW)
		} else {
			rl.DrawSphere(pt, POINT_RADIUS, rl.WHITE)
		}
	}
}

PointSelection :: struct {
	points:  [3]rl.Vector3,
	indexes: [3]uint,
	size:    uint,
}

point_selection_append :: proc(sel: ^PointSelection, pt: rl.Vector3, index: uint) {
	sel.size = 0 if sel.size >= 3 else sel.size
	sel.indexes[sel.size] = uint(index)
	sel.points[sel.size] = pt
	sel.size += 1
}

point_selection_align :: proc(sel: ^PointSelection, mat: ^rl.Matrix) {
	// Do 1-2-3 alignment
	if sel.size == 3 && rl.IsKeyDown(.A) {
		// Point
		origin := &sel.points[0]
		mat[0, 3] = origin.x
		mat[1, 3] = origin.y
		mat[2, 3] = origin.z

		// Axis
		axis_pt := &sel.points[1]
		u := rl.Vector3{axis_pt.x - origin.x, axis_pt.y - origin.y, axis_pt.z - origin.z}
		u = linalg.normalize(u)
		mat[0, 0] = u.x
		mat[1, 0] = u.y
		mat[2, 0] = u.z

		// Plane
		plane_pt := &sel.points[2]
		v := rl.Vector3{plane_pt.x - origin.x, plane_pt.y - origin.y, plane_pt.z - origin.z}
		v = linalg.normalize(v)
		w := linalg.cross(u, v)
		mat[0, 2] = w.x
		mat[1, 2] = w.y
		mat[2, 2] = w.z

		// Other Axis
		v = linalg.cross(w, u)
		mat[0, 1] = v.x
		mat[1, 1] = v.y
		mat[2, 1] = v.z
	}
}

main :: proc() {
	rl.InitWindow(1280, 720, "Alignment")

	po_camera := init_pan_orbit_camera(rl.Vector3(0), 10.0)
	po_camera_orig := po_camera

	pts: []rl.Vector3 = {
		//
		{0.0, 0.0, -1.0},
		{1.0, 0.0, -1.0},
		{1.0, 1.0, -1.0},
		{0.0, 1.0, -1.0},
		{-1.0, 1.0, -1.0},
		{-1.0, 0.0, -1.0},
		{-1.0, -1.0, -1.0},
		{0.0, -1.0, -1.0},
		{1.0, -1.0, -1.0},
		//
		{0.0, 0.0, 0.0},
		{1.0, 0.0, 0.0},
		{1.0, 1.0, 0.0},
		{0.0, 1.0, 0.0},
		{-1.0, 1.0, 0.0},
		{-1.0, 0.0, 0.0},
		{-1.0, -1.0, 0.0},
		{0.0, -1.0, 0.0},
		{1.0, -1.0, 0.0},
		//
		{0.0, 0.0, 1.0},
		{1.0, 0.0, 1.0},
		{1.0, 1.0, 1.0},
		{0.0, 1.0, 1.0},
		{-1.0, 1.0, 1.0},
		{-1.0, 0.0, 1.0},
		{-1.0, -1.0, 1.0},
		{0.0, -1.0, 1.0},
		{1.0, -1.0, 1.0},
	}
	pt_selection: PointSelection = {
		points  = {rl.Vector3(0), rl.Vector3(0), rl.Vector3(0)},
		indexes = {0, 0, 0},
		size    = 0,
	}
	aligned_mat := rl.Matrix(1)

	rl.SetTargetFPS(60)
	for !rl.WindowShouldClose() {
		mouse_pos := rl.GetMousePosition()
		rl_camera := update_pan_orbit_camera(&po_camera)

		rl.BeginDrawing()
		rl.BeginMode3D(rl_camera)

		rl.ClearBackground(rl.Color{24, 24, 24, 255})
		rl.DrawLine3D(rl.Vector3(0), {1.0, 0.0, 0.0}, rl.RED)
		rl.DrawLine3D(rl.Vector3(0), {0.0, 1.0, 0.0}, rl.GREEN)
		rl.DrawLine3D(rl.Vector3(0), {0.0, 0.0, 1.0}, rl.BLUE)

		if rl.IsKeyDown(.ESCAPE) {
			pt_selection.size = 0
		}
		if rl.IsMouseButtonPressed(.LEFT) {
			mouse_ray := rl.GetScreenToWorldRay(mouse_pos, rl_camera)
			found_collision := false
			selected_distance := max(f32)
			selected_point := rl.Vector3(0)
			selected_index: uint = 0
			for pt, i in pts {
				ray_collision := rl.GetRayCollisionSphere(mouse_ray, pt, POINT_RADIUS)
				if ray_collision.hit && ray_collision.distance < selected_distance {
					selected_index = uint(i)
					selected_point = pt
					selected_distance = ray_collision.distance
					found_collision = true
				}
			}
			if found_collision {
				point_selection_append(&pt_selection, selected_point, selected_index)
			} else {
				pt_selection.size = 0
			}
		}

		// Do origin alignment
		if pt_selection.size == 1 && rl.IsKeyDown(.A) {
			pt := &pt_selection.points[pt_selection.size - 1]
			aligned_mat[0, 3] = pt.x
			aligned_mat[1, 3] = pt.y
			aligned_mat[2, 3] = pt.z
		}
		// Move everything into alignment with the world
		if rl.IsKeyDown(.C) {
			pt_selection.size = 0
			m_inv := linalg.inverse(aligned_mat)
			for &pt in pts {
				pt_local := m_inv * [4]f32{pt.x, pt.y, pt.z, 1.0}
				pt.x = pt_local[0]
				pt.y = pt_local[1]
				pt.z = pt_local[2]
			}
			aligned_mat = rl.Matrix(1)
		}
		// Reset view
		if rl.IsKeyDown(.R) {
			po_camera = po_camera_orig
		}
		// Do 1-2-3 alignment
		point_selection_align(&pt_selection, &aligned_mat)
		// Draw points
		draw_points(&pts, &pt_selection)
		// Draw aligned axis
		draw_axis(aligned_mat)
		rl.EndMode3D()
		rl.EndDrawing()
	}
}