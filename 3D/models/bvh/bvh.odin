package main

import "core:c/libc"
import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:slice"
import "core:strings"
import rl "vendor:raylib"
import "vendor:raylib/rlgl"

import "tinyobj"

RAYGUI_WINDOWBOX_STATUSBAR_HEIGHT :: 24
CHARACTERS_MAX :: 6
AO_CAPSULES_MAX :: 32
SHADOW_CAPSULES_MAX :: 32

Frustum :: struct {
	back,
	front,
	left,
	right,
	top,
	bottom: rl.Vector4,
}

frustum_from_camera :: proc(proj, m: rl.Matrix) -> Frustum {
	planes: rl.Matrix
	// Row 0
	planes[0,0] = m[0,0] * proj[0,0] + m[0,1] * proj[1,0] + m[0,2] * proj[2,0] + m[0,3] * proj[3,0]
	planes[0,1] = m[0,0] * proj[0,1] + m[0,1] * proj[1,1] + m[0,2] * proj[2,1] + m[0,3] * proj[3,1]
	planes[0,2] = m[0,0] * proj[0,2] + m[0,1] * proj[1,2] + m[0,2] * proj[2,2] + m[0,3] * proj[3,2]
	planes[0,3] = m[0,0] * proj[0,3] + m[0,1] * proj[1,3] + m[0,2] * proj[2,3] + m[0,3] * proj[3,3]
	// Row 1
	planes[1,0] = m[1,0] * proj[0,0] + m[1,1] * proj[1,0] + m[1,2] * proj[2,0] + m[1,3] * proj[3,0]
	planes[1,1] = m[1,0] * proj[0,1] + m[1,1] * proj[1,1] + m[1,2] * proj[2,1] + m[1,3] * proj[3,1]
	planes[1,2] = m[1,0] * proj[0,2] + m[1,1] * proj[1,2] + m[1,2] * proj[2,2] + m[1,3] * proj[3,2]
	planes[1,3] = m[1,0] * proj[0,3] + m[1,1] * proj[1,3] + m[1,2] * proj[2,3] + m[1,3] * proj[3,3]
	// Row 2
	planes[2,0] = m[2,0] * proj[0,0] + m[2,1] * proj[1,0] + m[2,2] * proj[2,0] + m[2,3] * proj[3,0]
	planes[2,1] = m[2,0] * proj[0,1] + m[2,1] * proj[1,1] + m[2,2] * proj[2,1] + m[2,3] * proj[3,1]
	planes[2,2] = m[2,0] * proj[0,2] + m[2,1] * proj[1,2] + m[2,2] * proj[2,2] + m[2,3] * proj[3,2]
	planes[2,3] = m[2,0] * proj[0,3] + m[2,1] * proj[1,3] + m[2,2] * proj[2,3] + m[2,3] * proj[3,3]
	// Row 3
	planes[3,0] = m[3,0] * proj[0,0] + m[3,1] * proj[1,0] + m[3,2] * proj[2,0] + m[3,3] * proj[3,0]
	planes[3,1] = m[3,0] * proj[0,1] + m[3,1] * proj[1,1] + m[3,2] * proj[2,1] + m[3,3] * proj[3,1]
	planes[3,2] = m[3,0] * proj[0,2] + m[3,1] * proj[1,2] + m[3,2] * proj[2,2] + m[3,3] * proj[3,2]
	planes[3,3] = m[3,0] * proj[0,3] + m[3,1] * proj[1,3] + m[3,2] * proj[2,3] + m[3,3] * proj[3,3]
	return Frustum{
		back   = rl.Vector4{ planes[0,3] - planes[0,2], planes[1,3] - planes[1,2], planes[2,3] - planes[2,2], planes[3,3] - planes[3,2] },
		front  = rl.Vector4{ planes[0,3] + planes[0,2], planes[1,3] + planes[1,2], planes[2,3] + planes[2,2], planes[3,3] + planes[3,2] },
		bottom = rl.Vector4{ planes[0,3] + planes[0,1], planes[1,3] + planes[1,1], planes[2,3] + planes[2,1], planes[3,3] + planes[3,1] },
		top    = rl.Vector4{ planes[0,3] - planes[0,1], planes[1,3] - planes[1,1], planes[2,3] - planes[2,1], planes[3,3] - planes[3,1] },
		left   = rl.Vector4{ planes[0,3] + planes[0,0], planes[1,3] + planes[1,0], planes[2,3] + planes[2,0], planes[3,3] + planes[3,0] },
		right  = rl.Vector4{ planes[0,3] - planes[0,0], planes[1,3] - planes[1,0], planes[2,3] - planes[2,0], planes[3,3] - planes[3,0] }
	}
}

frustum_plane_normalize :: proc(plane: rl.Vector4) -> rl.Vector4 {
	magnitude := math.sqrt(square(plane.x) + square(plane.y) + square(plane.z))
	return rl.Vector4{
		plane.x / magnitude,
		plane.y / magnitude,
		plane.z / magnitude,
		plane.w / magnitude,
	}
}

frustum_plane_distance_to_point :: proc(frustum: ^Frustum, plane: rl.Vector4, point: rl.Vector3) -> f32 {
	return (plane.x * point.x + plane.y * point.y + plane.z * point.z + plane.w)
}

frustum_contains_sphere :: proc(frustum: ^Frustum, position: rl.Vector3, radius: f32) -> bool {
	if frustum_plane_distance_to_point(frustum, frustum.back, position) < -radius do return false
	if frustum_plane_distance_to_point(frustum, frustum.front, position) < -radius do return false
	if frustum_plane_distance_to_point(frustum, frustum.bottom, position) < -radius do return false
	if frustum_plane_distance_to_point(frustum, frustum.top, position) < -radius do return false
	if frustum_plane_distance_to_point(frustum, frustum.left, position) < -radius do return false
	if frustum_plane_distance_to_point(frustum, frustum.right, position) < -radius do return false
	return true
}

OrbitCamera :: struct {
	cam:        rl.Camera3D,
	offset:     rl.Vector3,
	azimuth,
	altitude,
	distance:   f32,
	track_bone: i32,
	track:      bool,
}

orbit_camera_init :: proc(oc: ^OrbitCamera) {
	oc.cam = rl.Camera3D{
		position = {2, 3, 5},
		target = {-0.5, 1, 0},
		up = {0, 1, 0},
		fovy = 45,
		projection = .PERSPECTIVE,
	}
	oc.distance = 4.0
	oc.altitude = 0.4
	oc.azimuth = 0
	oc.offset = {}
	oc.track = true
	oc.track_bone = 0
}

orbit_camera_update :: proc(oc: ^OrbitCamera, target_pos: rl.Vector3) {
	dt := rl.GetFrameTime()
	// Mouse Input
	if rl.IsMouseButtonDown(.LEFT) && rl.IsKeyDown(.LEFT_CONTROL) {
		delta := rl.GetMouseDelta()
		oc.azimuth -= delta.x * 01
		oc.altitude += delta.y * 01
		oc.altitude = rl.Clamp(oc.altitude, 01, rl.PI*0.49)
	}
	wheel := rl.GetMouseWheelMove()
	oc.distance = rl.Clamp(oc.distance - wheel, 0.1, 100)
	
	rot_az := rl.QuaternionFromAxisAngle({0, 1, 0}, oc.azimuth)
	pos := rl.Vector3RotateByQuaternion({0, 0, oc.distance}, rot_az)
	axis := rl.Vector3Normalize(rl.Vector3CrossProduct(pos, {0, 1, 0}))
	rot_alt := rl.QuaternionFromAxisAngle(axis, oc.altitude)
	// Final Calc
	eye_offset := rl.Vector3RotateByQuaternion(pos, rot_alt)
	
	oc.cam.target = oc.offset + target_pos
	oc.cam.position = oc.cam.target + eye_offset
}

TransformData :: struct {
	joint_count:      int,
	parents:          [dynamic]int,
	end_site:         [dynamic]bool,
    global_positions,
	local_positions:  [dynamic]rl.Vector3,
	global_rotations,
	local_rotations:  [dynamic]rl.Quaternion,
}

transforms_init :: proc(data: ^TransformData, bvh: ^BVHData) {
	data.joint_count = len(bvh.joints)
	// Resize arrays
	resize(&data.parents, data.joint_count)
	resize(&data.end_site, data.joint_count)
	resize(&data.local_positions, data.joint_count)
	resize(&data.local_rotations, data.joint_count)
	resize(&data.global_positions, data.joint_count)
	resize(&data.global_rotations, data.joint_count)
	
	for i in 0..<data.joint_count {
		data.parents[i] = bvh.joints[i].parent
		data.end_site[i] = bvh.joints[i].end_site
	}
}

transforms_free :: proc(data: ^TransformData) {
	delete(data.parents)
	delete(data.end_site)
	delete(data.local_positions)
	delete(data.local_rotations)
	delete(data.global_positions)
	delete(data.global_rotations)
}

transform_data_sample_frame :: proc(data: ^TransformData, bvh: ^BVHData, frame_idx: i32, scale: f32) {
	frame := rl.Clamp(f32(frame_idx), 0, f32(bvh.frame_count - 1))
	idx := i32(frame)
	offset: i32
	motion_offset := idx * bvh.channel_count
	for i in 0..<len(bvh.joints) {
		position := bvh.joints[i].offset * scale
		rotation := rl.Quaternion(1)
		for channel in bvh.joints[i].channels {
			val := bvh.motion_data[motion_offset + offset]
			offset += 1
			switch channel {
			case .X_POSITION: position.x = scale * val
			case .Y_POSITION: position.y = scale * val
			case .Z_POSITION: position.z = scale * val
			case .X_ROTATION: rotation *= rl.QuaternionFromAxisAngle({1,0,0}, rl.DEG2RAD*val)
			case .Y_ROTATION: rotation *= rl.QuaternionFromAxisAngle({0,1,0}, rl.DEG2RAD*val)
			case .Z_ROTATION: rotation *= rl.QuaternionFromAxisAngle({0,0,1}, rl.DEG2RAD*val)
			}
		}
		data.local_positions[i] = position
		data.local_rotations[i] = rotation
	}
}

// Sample the nearest frame to the given time
transform_data_sample_frame_nearest :: proc(data: ^TransformData, bvh: ^BVHData, time: f32, scale: f32) {
	frame := clamp(i32(time / bvh.frame_time + 0.5), 0, bvh.frame_count - 1)
	transform_data_sample_frame(data, bvh, frame, scale)
}

// Perform a basic linear interpolation of the frame data in the BVH file
transform_data_sample_frame_linear :: proc(data, tmp0, tmp1: ^TransformData, bvh: ^BVHData, time: f32, scale: f32) {
	alpha := math.mod(time / bvh.frame_time, 1.0)
	frame0 := clamp(i32(time / bvh.frame_time) + 0, 0, bvh.frame_count - 1)
	frame1 := clamp(i32(time / bvh.frame_time) + 1, 0, bvh.frame_count - 1)
	transform_data_sample_frame(tmp0, bvh, frame0, scale)
	transform_data_sample_frame(tmp1, bvh, frame1, scale)
	for i in 0..<data.joint_count {
		data.local_positions[i] = linalg.lerp(tmp0.local_positions[i], tmp1.local_positions[i], alpha)
		data.local_rotations[i] = rl.QuaternionSlerp(tmp0.local_rotations[i], tmp1.local_rotations[i], alpha)
	}
}

// Perform a cubic interpolation of the frame data in the BVH file
transform_data_sample_frame_cubic :: proc(data, tmp0, tmp1, tmp2, tmp3: ^TransformData, bvh: ^BVHData, time: f32, scale: f32) {
	alpha := math.mod(time / bvh.frame_time, 1.0)
	frame0 := clamp(i32(time / bvh.frame_time) - 1, 0, bvh.frame_count - 1)
	frame1 := clamp(i32(time / bvh.frame_time) + 0, 0, bvh.frame_count - 1)
	frame2 := clamp(i32(time / bvh.frame_time) + 1, 0, bvh.frame_count - 1)
	frame3 := clamp(i32(time / bvh.frame_time) + 2, 0, bvh.frame_count - 1)
	transform_data_sample_frame(tmp0, bvh, frame0, scale)
	transform_data_sample_frame(tmp1, bvh, frame1, scale)
	transform_data_sample_frame(tmp2, bvh, frame2, scale)
	transform_data_sample_frame(tmp3, bvh, frame3, scale)
	for i in 0..<data.joint_count {
		data.local_positions[i] = vec3_interpolate_cubic(
			tmp0.local_positions[i], tmp1.local_positions[i],
			tmp2.local_positions[i], tmp3.local_positions[i], alpha)
		data.local_rotations[i] = quat_interpolate_cubic(
			tmp0.local_rotations[i], tmp1.local_rotations[i],
			tmp2.local_rotations[i], tmp3.local_rotations[i], alpha)
	}
}

transform_data_forward_kinematics :: proc(data: ^TransformData) {
	for i in 0..<data.joint_count {
		p := data.parents[i]
		if p == -1 {
			data.global_positions[i] = data.local_positions[i]
			data.global_rotations[i] = data.local_rotations[i]
		} else {
			rot_pos := rl.Vector3RotateByQuaternion(data.local_positions[i], data.global_rotations[p])
			data.global_positions[i] = rot_pos + data.global_positions[p]
			data.global_rotations[i] *= data.global_rotations[p]
		}
	}
}

// Shader Uniforms Structure
ShaderUniforms :: struct {
    is_capsule,
    capsule_position,
    capsule_rotation,
    capsule_half_length,
    capsule_radius,
    capsule_start,
    capsule_vector,
    shadow_capsule_count,
    shadow_capsule_starts,
    shadow_capsule_vectors,
    shadow_capsule_radii,
    shadow_lookup_table,
    shadow_lookup_resolution,
    ao_capsule_count,
    ao_capsule_starts,
    ao_capsule_vectors,
    ao_capsule_radii,
    ao_lookup_table,
    ao_lookup_resolution,
    camera_position,
    object_color,
    object_specularity,
    object_glossiness,
    object_opacity,
    sun_strength,
    sun_dir,
    sun_color,
    sky_strength,
    sky_color,
    ambient_strength,
    ground_strength,
    exposure: i32,
}

shader_uniforms_init :: proc(shader: rl.Shader) -> ShaderUniforms {
    u: ShaderUniforms
    
    u.is_capsule = rl.GetShaderLocation(shader, "isCapsule")
    u.capsule_position = rl.GetShaderLocation(shader, "capsulePosition")
    u.capsule_rotation = rl.GetShaderLocation(shader, "capsuleRotation")
    u.capsule_half_length = rl.GetShaderLocation(shader, "capsuleHalfLength")
    u.capsule_radius = rl.GetShaderLocation(shader, "capsuleRadius")
    u.capsule_start = rl.GetShaderLocation(shader, "capsuleStart")
    u.capsule_vector = rl.GetShaderLocation(shader, "capsuleVector")
    
    u.shadow_capsule_count = rl.GetShaderLocation(shader, "shadowCapsuleCount")
    u.shadow_capsule_starts = rl.GetShaderLocation(shader, "shadowCapsuleStarts")
    u.shadow_capsule_vectors = rl.GetShaderLocation(shader, "shadowCapsuleVectors")
    u.shadow_capsule_radii = rl.GetShaderLocation(shader, "shadowCapsuleRadii")
    u.shadow_lookup_table = rl.GetShaderLocation(shader, "shadowLookupTable")
    u.shadow_lookup_resolution = rl.GetShaderLocation(shader, "shadowLookupResolution")
    
    u.ao_capsule_count = rl.GetShaderLocation(shader, "aoCapsuleCount")
    u.ao_capsule_starts = rl.GetShaderLocation(shader, "aoCapsuleStarts")
    u.ao_capsule_vectors = rl.GetShaderLocation(shader, "aoCapsuleVectors")
    u.ao_capsule_radii = rl.GetShaderLocation(shader, "aoCapsuleRadii")
    u.ao_lookup_table = rl.GetShaderLocation(shader, "aoLookupTable")
    u.ao_lookup_resolution = rl.GetShaderLocation(shader, "aoLookupResolution")
    
    u.camera_position = rl.GetShaderLocation(shader, "cameraPosition")
    
    u.object_color = rl.GetShaderLocation(shader, "objectColor")
    u.object_specularity = rl.GetShaderLocation(shader, "objectSpecularity")
    u.object_glossiness = rl.GetShaderLocation(shader, "objectGlossiness")
    u.object_opacity = rl.GetShaderLocation(shader, "objectOpacity")
    
    u.sun_strength = rl.GetShaderLocation(shader, "sunStrength")
    u.sun_dir = rl.GetShaderLocation(shader, "sunDir")
    u.sun_color = rl.GetShaderLocation(shader, "sunColor")
    u.sky_strength = rl.GetShaderLocation(shader, "skyStrength")
    u.sky_color = rl.GetShaderLocation(shader, "skyColor")
    u.ambient_strength = rl.GetShaderLocation(shader, "ambientStrength")
    u.ground_strength = rl.GetShaderLocation(shader, "groundStrength")

    u.exposure = rl.GetShaderLocation(shader, "exposure")

    return u
}

// Render Settings
Render_Settings :: struct {
    background_color,
    sky_color,
    sun_color: rl.Color,
    sun_light_cone_angle,
    sun_light_strength,
    sun_azimuth,
    sun_altitude,
    sky_light_strength,
    ground_light_strength,
    ambient_light_strength,
    exposure: f32,
    draw_origin,
    draw_grid,
    draw_checker,
    draw_capsules,
    draw_wireframes,
    draw_skeleton,
    draw_transforms,
    draw_ao,
    draw_shadows,
    draw_end_sites,
    draw_fps,
    draw_ui: bool,
}

render_settings_init :: proc() -> Render_Settings {
    settings := Render_Settings{
        background_color = rl.WHITE,
        sun_light_cone_angle = 0.2,
        sun_light_strength = 0.25,
        sun_azimuth = math.PI / 4.0,
        sun_altitude = 0.8,
        sun_color = {253, 255, 232, 255},
        sky_light_strength = 0.15,
        sky_color = {174, 183, 190, 255},
        ground_light_strength = 0.1,
        ambient_light_strength = 1.0,
        exposure = 0.9,
        draw_origin = true,
        draw_grid = false,
        draw_checker = true,
        draw_capsules = true,
        draw_wireframes = false,
        draw_skeleton = true,
        draw_transforms = false,
        draw_ao = true,
        draw_shadows = true,
        draw_end_sites = true,
        draw_fps = false,
        draw_ui = true,
    }
    return settings
}

Scrubber_Settings :: struct {
    playing: bool,
    looping: bool,
    inplace: bool,
    play_time: f32,
    play_speed: f32,
    frame_snap: bool,
    sample_mode: i32,
    time_limit: f32,
    frame_limit: i32,
    frame_min: i32,
    frame_max: i32,
    frame_min_select: i32,
    frame_max_select: i32,
    frame_min_edit: bool,
    frame_max_edit: bool,
    time_min: f32,
    time_max: f32,
}

scrubber_settings_init :: proc() -> Scrubber_Settings {
    sample_modes := []string{"nearest", "linear", "cubic"}
    
    settings := Scrubber_Settings{
        playing = true,
        looping = false,
        inplace = false,
        play_time = 0,
        play_speed = 1.0,
        frame_snap = true,
        sample_mode = 1, // Default linear
        time_limit = 0,
        frame_limit = 0,
        frame_min = 0,
        frame_max = 0,
        frame_min_select = 0,
        frame_max_select = 0,
        frame_min_edit = false,
        frame_max_edit = false,
        time_min = 0,
        time_max = 0,
    }
    return settings
}

scrubber_settings_recompute_limits :: proc(settings: ^Scrubber_Settings, character_data: ^Character) {
    settings.frame_limit = 0
    settings.time_limit = 0
    
    for i in 0..<character_data.count {
        settings.frame_limit = max(settings.frame_limit, character_data.bvh[i].frame_count - 1)
        settings.time_limit = max(settings.time_limit, 
            f32(character_data.bvh[i].frame_count - 1) * character_data.bvh[i].frame_time)
    }
}

scrubber_settings_init_maxs :: proc(settings: ^Scrubber_Settings, character_data: ^Character) {
    if character_data.count == 0 do return
    
    settings.frame_max = i32(character_data.bvh[character_data.active].frame_count) - 1
    settings.frame_max_select = settings.frame_max
    settings.time_max = f32(settings.frame_max) * character_data.bvh[character_data.active].frame_time
    settings.frame_min = 0
    settings.frame_min_select = settings.frame_min
    settings.time_min = 0
}

scrubber_settings_clamp :: proc(settings: ^Scrubber_Settings, character_data: ^Character) {
    if character_data.count == 0 do return
    
    settings.frame_max = clamp(settings.frame_max, 0, settings.frame_limit)
    settings.frame_max_select = settings.frame_max
    settings.time_max = f32(settings.frame_max) * character_data.bvh[character_data.active].frame_time
    
    settings.frame_min = clamp(settings.frame_min, 0, settings.frame_max)
    settings.frame_min_select = settings.frame_min
    settings.time_min = f32(settings.frame_min) * character_data.bvh[character_data.active].frame_time
    
    settings.play_time = clamp(settings.play_time, settings.time_min, settings.time_max)
}

draw_transform :: proc(position: rl.Vector3, rotation: rl.Quaternion, size: f32) {
    rl.DrawLine3D(
        position,
        position + rl.Vector3RotateByQuaternion({size, 0, 0}, rotation),
        rl.RED,
    )
    rl.DrawLine3D(
        position,
        position + rl.Vector3RotateByQuaternion({0, size, 0}, rotation),
        rl.GREEN,
    )
    rl.DrawLine3D(
        position,
        position + rl.Vector3RotateByQuaternion({0, 0, size}, rotation),
        rl.BLUE,
    )
}

draw_skeleton :: proc(
    xform_data: ^TransformData,
    draw_end_sites: bool,
    color: rl.Color,
    end_site_color: rl.Color,
) {
    for i in 0 ..< xform_data.joint_count {
        if !xform_data.end_site[i] {
            rl.DrawSphereWires(xform_data.global_positions[i], 01, 4, 6, color)
        } else if draw_end_sites {
            rl.DrawCubeWiresV(
                xform_data.global_positions[i],
                {02, 02, 02},
                end_site_color,
            )
        }
        if xform_data.parents[i] != -1 {
            if !xform_data.end_site[i] {
                rl.DrawLine3D(
                    xform_data.global_positions[i],
                    xform_data.global_positions[xform_data.parents[i]],
                    color,
                )
            } else if draw_end_sites {
                rl.DrawLine3D(
                    xform_data.global_positions[i],
                    xform_data.global_positions[xform_data.parents[i]],
                    end_site_color,
                )
            }
        }
    }
}

draw_transforms :: proc(xform_data: ^TransformData) {
    for i in 0 ..< xform_data.joint_count {
        if !xform_data.end_site[i] {
            draw_transform(
                xform_data.global_positions[i],
                xform_data.global_rotations[i],
                0.1,
            )
        }
    }
}

draw_wireframes :: proc(capsule_data: ^CapsuleData, color: rl.Color) {
    for i in 0 ..< capsule_data.capsule_count {
        capsule_start := capsule_start(
            capsule_data.capsule_positions[i],
            capsule_data.capsule_rotations[i],
            capsule_data.capsule_half_lengths[i],
        )
        capsule_end := capsule_end(
            capsule_data.capsule_positions[i],
            capsule_data.capsule_rotations[i],
            capsule_data.capsule_half_lengths[i],
        )
        capsule_radius := capsule_data.capsule_radii[i]

        rl.DrawSphereWires(capsule_start, capsule_radius, 4, 6, color)
        rl.DrawSphereWires(capsule_end, capsule_radius, 4, 6, color)
        rl.DrawCylinderWiresEx(
            capsule_start,
            capsule_end,
            capsule_radius,
            capsule_radius,
            6,
            color,
        )
    }
}

gui_orbit_camera :: proc(
    camera: ^OrbitCamera,
    character_data: ^Character,
) {
    rl.GuiGroupBox({20, 10, 190, 260}, "Camera")
    rl.GuiLabel({30, 20, 150, 20}, "Ctrl + Left Click - Rotate")
    rl.GuiLabel({30, 40, 150, 20}, "Ctrl + Right Click - Pan")
    rl.GuiLabel({30, 60, 150, 20}, "Mouse Scroll - Zoom")
    rl.GuiLabel(
        {30, 80, 150, 20},
        fmt.ctprintf(
            "Target: [% 5.3f % 5.3f % 5.3f]",
            camera.cam.target.x,
            camera.cam.target.y,
            camera.cam.target.z,
        ),
    )
    rl.GuiLabel(
        {30, 100, 150, 20},
        fmt.ctprintf(
            "Offset: [% 5.3f % 5.3f % 5.3f]",
            camera.offset.x,
            camera.offset.y,
            camera.offset.z,
        ),
    )
    rl.GuiLabel({30, 120, 150, 20}, fmt.ctprintf("Azimuth: %5.3f", camera.azimuth))
    rl.GuiLabel({30, 140, 150, 20}, fmt.ctprintf("Altitude: %5.3f", camera.altitude))
    rl.GuiLabel({30, 160, 150, 20}, fmt.ctprintf("Distance: %5.3f", camera.distance))

    if rl.GuiButton({30, 180, 100, 20}, "Reset") {
        camera.azimuth = 0
        camera.altitude = 0.4
        camera.distance = 4.0
        camera.offset = {}
        camera.track = true
        camera.track_bone = 0
    }
    if character_data.count > 0 {
        rl.GuiToggle({30, 210, 100, 20}, "Track", &camera.track)
        rl.GuiComboBox(
            {30, 240, 150, 20},
            fmt.ctprint(character_data.joint_names_combo[character_data.active]),
            &camera.track_bone,
        )
    }
}

gui_render_settings :: proc(
    settings: ^Render_Settings,
    capsule_data: ^CapsuleData,
    screen_width: i32,
    screen_height: i32,
) {
    rl.GuiGroupBox(
        {f32(screen_width) - 260, 10, 240, 430},
        "Rendering",
    )
    rl.GuiSliderBar(
        {f32(screen_width) - 160, 20, 100, 20},
        "Exposure",
        fmt.ctprintf("%5.2f", settings.exposure),
        &settings.exposure,
        0,
        3.0,
    )
    rl.GuiSliderBar(
        {f32(screen_width) - 160, 50, 100, 20},
        "Sun Light",
        fmt.ctprintf("%5.2f", settings.sun_light_strength),
        &settings.sun_light_strength,
        0,
        1.0,
    )
    softness := rl.GuiSliderBar(
        {f32(screen_width) - 160, 80, 100, 20},
        "Sun Softness",
        fmt.ctprintf("%5.2f", settings.sun_light_cone_angle),
        &settings.sun_light_cone_angle,
        02,
        math.PI / 4.0,
    ) 
	if softness > 0 { // TODO: should check if changed
        capsule_data_update_shadow_lookup_table(capsule_data, settings.sun_light_cone_angle)
    }
    rl.GuiSliderBar(
        {f32(screen_width) - 160, 110, 100, 20},
        "Sky Light",
        fmt.ctprintf("%5.2f", settings.sky_light_strength),
        &settings.sky_light_strength,
        0,
        1.0,
    )
    rl.GuiSliderBar(
        {f32(screen_width) - 160, 140, 100, 20},
        "Ambient Light",
        fmt.ctprintf("%5.2f", settings.ambient_light_strength),
        &settings.ambient_light_strength,
        0,
        2.0,
    )
    rl.GuiSliderBar(
        {f32(screen_width) - 160, 170, 100, 20},
        "Ground Light",
        fmt.ctprintf("%5.2f", settings.ground_light_strength),
        &settings.ground_light_strength,
        0,
        0.5,
    )
    rl.GuiSliderBar(
        {f32(screen_width) - 160, 200, 100, 20},
        "Sun Azimuth",
        fmt.ctprintf("%5.2f", settings.sun_azimuth),
        &settings.sun_azimuth,
        -math.PI,
        math.PI,
    )
    rl.GuiSliderBar(
        {f32(screen_width) - 160, 230, 100, 20},
        "Sun Altitude",
        fmt.ctprintf("%5.2f", settings.sun_altitude),
        &settings.sun_altitude,
        0,
        0.49 * math.PI,
    )
    rl.GuiCheckBox(
        {f32(screen_width) - 250, 260, 20, 20},
        "Draw Origin",
        &settings.draw_origin,
    )
    rl.GuiCheckBox(
        {f32(screen_width) - 130, 260, 20, 20},
        "Draw Grid",
        &settings.draw_grid,
    )
    rl.GuiCheckBox(
        {f32(screen_width) - 250, 290, 20, 20},
        "Draw Checker",
        &settings.draw_checker,
    )
    rl.GuiCheckBox(
        {f32(screen_width) - 130, 290, 20, 20},
        "Draw Capsules",
        &settings.draw_capsules,
    )
    rl.GuiCheckBox(
        {f32(screen_width) - 250, 320, 20, 20},
        "Draw Wireframes",
        &settings.draw_wireframes,
    )
    rl.GuiCheckBox(
        {f32(screen_width) - 130, 320, 20, 20},
        "Draw Skeleton",
        &settings.draw_skeleton,
    )
    rl.GuiCheckBox(
        {f32(screen_width) - 250, 350, 20, 20},
        "Draw Transforms",
        &settings.draw_transforms,
    )
    rl.GuiCheckBox(
        {f32(screen_width) - 130, 350, 20, 20},
        "Draw AO",
        &settings.draw_ao,
    )
    rl.GuiCheckBox(
        {f32(screen_width) - 250, 380, 20, 20},
        "Draw Shadows",
        &settings.draw_shadows,
    )
    rl.GuiCheckBox(
        {f32(screen_width) - 130, 380, 20, 20},
        "Draw End Sites",
        &settings.draw_end_sites,
    )
    rl.GuiCheckBox(
        {f32(screen_width) - 250, 410, 20, 20},
        "Draw FPS",
        &settings.draw_fps,
    )
    rl.GuiLabel({f32(screen_width) - 130, 410, 100, 20}, "H Key - Hide UI")
}

gui_character_data :: proc(
    character_data: ^Character,
    scrubber_settings: ^Scrubber_Settings,
    err_msg: ^string,
) {
    offset_height: f32 = 280
    rl.GuiGroupBox(
        {20, offset_height, 190, (CHARACTERS_MAX - 1) * 30 + 150},
        "Characters",
    )
    if rl.GuiButton({150, offset_height + 10, 50, 20}, "Clear") {
        character_data.count = 0
        err_msg^ = ""
        scrubber_settings^ = scrubber_settings_init()
        rl.SetWindowTitle("BVHView")
    }
    for i in 0 ..< character_data.count {
        bvh_name_short: [20]u8
        name_len := len(character_data.names[i])

        if name_len + 1 <= 20 {
            copy(bvh_name_short[:], character_data.names[i])
        } else {
            copy(bvh_name_short[:16], character_data.names[i][:16])
            copy(bvh_name_short[16:], "...")
        }
        bvh_selected := i == character_data.active

        rl.GuiToggle(
            {30, offset_height + 40 + f32(i) * 30, 140, 20},
            cstring(raw_data(bvh_name_short[:])),
            &bvh_selected,
        )
        if bvh_selected && character_data.active != i {
            character_data.active = i
            scrubber_settings_clamp(scrubber_settings, character_data)

            window_title := fmt.ctprintf(
                "%s - BVHView",
                character_data.file_paths[character_data.active],
            )
            rl.SetWindowTitle(window_title)
        }
        rl.DrawRectangleRec(
            {180, offset_height + 40 + f32(i) * 30, 20, 20},
            character_data.colors[i],
        )
        rl.DrawRectangleLinesEx(
            {180, offset_height + 40 + f32(i) * 30, 20, 20},
            1,
            rl.GRAY,
        )
        if rl.IsMouseButtonPressed(.LEFT) {
            mouse_pos := rl.GetMousePosition()
            if mouse_pos.x > 180 &&
               mouse_pos.x < 200 &&
               mouse_pos.y > offset_height + 40 + f32(i) * 30 &&
               mouse_pos.y < offset_height + 40 + f32(i) * 30 + 20 {
                character_data.color_picker_active = !character_data.color_picker_active
            }
        }
    }
    if character_data.count > 0 {
        scale_m := character_data.scales[character_data.active] == 1.0
        rl.GuiToggle({30, offset_height + 60 + (CHARACTERS_MAX - 1) * 30, 30, 20}, "m", &scale_m)
        if scale_m {character_data.scales[character_data.active] = 1.0}

        scale_cm := character_data.scales[character_data.active] == 01
        rl.GuiToggle({65, offset_height + 60 + (CHARACTERS_MAX - 1) * 30, 30, 20}, "cm", &scale_cm)
        if scale_cm {character_data.scales[character_data.active] = 01}

        scale_inches := character_data.scales[character_data.active] == 0254
        rl.GuiToggle(
            {100, offset_height + 60 + (CHARACTERS_MAX - 1) * 30, 30, 20},
            "inch",
            &scale_inches,
        )
        if scale_inches {character_data.scales[character_data.active] = 0254}

        scale_feet := character_data.scales[character_data.active] == 0.3048
        rl.GuiToggle(
            {135, offset_height + 60 + (CHARACTERS_MAX - 1) * 30, 30, 20},
            "feet",
            &scale_feet,
        )
        if scale_feet {character_data.scales[character_data.active] = 0.3048}

        scale_auto :=
            character_data.scales[character_data.active] ==
            character_data.auto_scales[character_data.active]
        rl.GuiToggle(
            {170, offset_height + 60 + (CHARACTERS_MAX - 1) * 30, 30, 20},
            "auto",
            &scale_auto,
        )
        if scale_auto {
            character_data.scales[character_data.active] =
                character_data.auto_scales[character_data.active]
        }
        rl.GuiSliderBar(
            {70, offset_height + 90 + (CHARACTERS_MAX - 1) * 30, 100, 20},
            "Radius",
            fmt.ctprintf("%5.2f", character_data.radii[character_data.active]),
            &character_data.radii[character_data.active],
            01,
            0.1,
        )
        rl.GuiSliderBar(
            {70, offset_height + 120 + (CHARACTERS_MAX - 1) * 30, 100, 20},
            "Opacity",
            fmt.ctprintf("%5.2f", character_data.opacities[character_data.active]),
            &character_data.opacities[character_data.active],
            0,
            1.0,
        )
    }
}

gui_scrubber_settings :: proc(
    settings: ^Scrubber_Settings,
    character_data: ^Character,
    screen_width: i32,
    screen_height: i32,
) {
    if character_data.count == 0 {return}

    frame_time := character_data.bvh[character_data.active].frame_time

    rl.GuiGroupBox(
        {f32(screen_width) / 2 - 600, f32(screen_height) - 100, 1200, 90},
        "Scrubber",
    )
    rl.GuiLabel(
        {f32(screen_width) / 2 - 480, f32(screen_height) - 80, 150, 20},
        fmt.ctprintf("Frame Time: %f", frame_time),
    )
    rl.GuiCheckBox(
        {f32(screen_width) / 2 - 350, f32(screen_height) - 80, 20, 20},
        "Snap to Frame",
        &settings.frame_snap,
    )
    rl.GuiComboBox(
        {f32(screen_width) / 2 - 240, f32(screen_height) - 80, 100, 20},
        "Nearest;Linear;Cubic",
        &settings.sample_mode,
    )
    rl.GuiToggle(
        {f32(screen_width) / 2 - 130, f32(screen_height) - 80, 50, 20},
        "Inplace",
        &settings.inplace,
    )
    rl.GuiToggle(
        {f32(screen_width) / 2 - 70, f32(screen_height) - 80, 50, 20},
        "Loop",
        &settings.looping,
    )
    rl.GuiToggle(
        {f32(screen_width) / 2 - 10, f32(screen_height) - 80, 50, 20},
        "Play",
        &settings.playing,
    )
    // Speed toggles
    speed_01x := settings.play_speed == 0.1
    rl.GuiToggle(
        {f32(screen_width) / 2 + 50, f32(screen_height) - 80, 30, 20},
        "0.1x",
        &speed_01x,
    )
    if speed_01x {settings.play_speed = 0.1}

    speed_05x := settings.play_speed == 0.5
    rl.GuiToggle(
        {f32(screen_width) / 2 + 90, f32(screen_height) - 80, 30, 20},
        "0.5x",
        &speed_05x,
    )
    if speed_05x {settings.play_speed = 0.5}

    speed_1x := settings.play_speed == 1.0
    rl.GuiToggle(
        {f32(screen_width) / 2 + 130, f32(screen_height) - 80, 30, 20},
        "1x",
        &speed_1x,
    )
    if speed_1x {settings.play_speed = 1.0}

    speed_2x := settings.play_speed == 2.0
    rl.GuiToggle(
        {f32(screen_width) / 2 + 170, f32(screen_height) - 80, 30, 20},
        "2x",
        &speed_2x,
    )
    if speed_2x {settings.play_speed = 2.0}

    speed_4x := settings.play_speed == 4.0
    rl.GuiToggle(
        {f32(screen_width) / 2 + 210, f32(screen_height) - 80, 30, 20},
        "4x",
        &speed_4x,
    )
    if speed_4x {settings.play_speed = 4.0}

    rl.GuiSliderBar(
        {f32(screen_width) / 2 + 250, f32(screen_height) - 80, 70, 20},
        "",
        fmt.ctprintf("%5.2fx", settings.play_speed),
        &settings.play_speed,
        0,
        4.0,
    )
    frame := clamp(
        i32(settings.play_time / frame_time + 0.5),
        settings.frame_min,
        settings.frame_max,
    )
    min_val := rl.GuiValueBox(
        {f32(screen_width) / 2 - 540, f32(screen_height) - 80, 50, 20},
        "Min   ",
        &settings.frame_min_select,
        0,
        i32(settings.frame_limit),
        settings.frame_min_edit,
    ) 
    if min_val > 0 { // TODO: should check if changed
        settings.frame_min_edit = !settings.frame_min_edit
        if !settings.frame_min_edit {
            settings.frame_min = settings.frame_min_select
            scrubber_settings_clamp(settings, character_data)
        }
    }
    max_val := rl.GuiValueBox(
        {f32(screen_width) / 2 + 470, f32(screen_height) - 80, 50, 20},
        "Max   ",
        &settings.frame_max_select,
        0,
        i32(settings.frame_limit),
        settings.frame_max_edit,
    ) 
    if max_val > 0 { // TODO: should check if changed
        settings.frame_max_edit = !settings.frame_max_edit
        if !settings.frame_max_edit {
            settings.frame_max = settings.frame_max_select
            scrubber_settings_clamp(settings, character_data)
        }
    }
    rl.GuiLabel(
        {f32(screen_width) / 2 + 530, f32(screen_height) - 80, 100, 20},
        fmt.ctprintf("of %i", settings.frame_limit),
    )
    frame_float_prev := settings.frame_snap ? f32(frame) : settings.play_time / frame_time
    frame_float := frame_float_prev

    rl.GuiSliderBar(
        {f32(screen_width) / 2 - 540, f32(screen_height) - 50, 1080, 20},
        fmt.ctprintf("%5.2f", settings.play_time),
        fmt.ctprintf("%i", frame),
        &frame_float,
        f32(settings.frame_min),
        f32(settings.frame_max),
    )
    if frame_float != frame_float_prev {
        if settings.frame_snap {
            frame = clamp(i32(frame_float + 0.5), settings.frame_min, settings.frame_max)
            settings.play_time = clamp(
                f32(frame) * frame_time,
                settings.time_min,
                settings.time_max,
            )
        } else {
            settings.play_time = clamp(
                frame_float * frame_time,
                settings.time_min,
                settings.time_max,
            )
        }
    }
}

Character :: struct {
	count: int,
	active: int,
	bvh:   [dynamic]BVHData,
	scales: []f32,
    names: []string,
    auto_scales: []f32,
    colors: []rl.Color,
    opacities: []f32,
    radii: []f32,
    file_paths: []string,
    xform: [dynamic]TransformData,
    xform_tmp0: [dynamic]TransformData,
    xform_tmp1: [dynamic]TransformData,
    xform_tmp2: [dynamic]TransformData,
    xform_tmp3: [dynamic]TransformData,
    joint_names_combo: []string,
    color_picker_active: bool,
}

character_init :: proc() -> Character {
    character := Character{
        count = 0,
        active = 0,
        bvh = [dynamic]BVHData{},
        scales = []f32{},
        names = []string{},
        auto_scales = []f32{},
        colors = []rl.Color{},
        opacities = []f32{},
        radii = []f32{},
        file_paths = []string{},
        xform = [dynamic]TransformData{},
        xform_tmp0 = [dynamic]TransformData{},
        xform_tmp1 = [dynamic]TransformData{},
        xform_tmp2 = [dynamic]TransformData{},
        xform_tmp3 = [dynamic]TransformData{},
        joint_names_combo = []string{},
        color_picker_active = false,
    }
    return character
}

character_free :: proc(character: ^Character) {
    for i in 0 ..< character.count {
        transforms_free(&character.xform[i])
        transforms_free(&character.xform_tmp0[i])
        transforms_free(&character.xform_tmp1[i])
        transforms_free(&character.xform_tmp2[i])
        transforms_free(&character.xform_tmp3[i])
        bvh_free(&character.bvh[i])
        delete(character.joint_names_combo[i])
    }
}

// Attempt to load a new character from given file path
character_load_from_file :: proc(character: ^Character, path: string) -> (success: bool, err_msg: string) {
    fmt.println("INFO: Loading", path)
    
    if character.count == CHARACTERS_MAX {
        return false, fmt.tprintf("Error: Maximum number of BVH files loaded (%i)", CHARACTERS_MAX)
    }
    bvh_data, bvh_err := bvh_load(path)
    if bvh_err != .None {
        fmt.println("INFO: Failed to Load", path)
        return false, fmt.tprintf("Error: Failed to load BVH file")
    }
    // Add the BVH data
    append(&character.bvh, bvh_data)
    
    // Init transform data structs
    xform: TransformData
    transforms_init(&xform, &bvh_data)
    append(&character.xform, xform)
    
    xform_tmp0: TransformData
    transforms_init(&xform_tmp0, &bvh_data)
    append(&character.xform_tmp0, xform_tmp0)
    
    xform_tmp1: TransformData
    transforms_init(&xform_tmp1, & bvh_data)
    append(&character.xform_tmp1, xform_tmp1)
    
    xform_tmp2: TransformData
    transforms_init(&xform_tmp2, &bvh_data)
    append(&character.xform_tmp2, xform_tmp2)
    
    xform_tmp3: TransformData
    transforms_init(&xform_tmp3, &bvh_data)
    append(&character.xform_tmp3, xform_tmp3)
    
    // Store file path
    file_paths := make([]string, character.count + 1)
    copy(file_paths, character.file_paths)
    delete(character.file_paths)
    file_paths[character.count] = strings.clone(path)
    character.file_paths = file_paths
    
    // Extract filename from path
    filename := path
    if idx := strings.last_index(filename, "/"); idx != -1 {
        filename = filename[idx+1:]
    }
    if idx := strings.last_index(filename, "\\"); idx != -1 {
        filename = filename[idx+1:]
    }
    // Store name
    names := make([]string, character.count + 1)
    copy(names, character.names)
    delete(character.names)
    names[character.count] = strings.clone(filename)
    character.names = names
    // Init scale
    scales := make([]f32, character.count + 1)
    copy(scales, character.scales)
    delete(character.scales)
    scales[character.count] = 1.0
    character.scales = scales
    
    // Auto-Scaling and unit detection
    auto_scales := make([]f32, character.count + 1)
    copy(auto_scales, character.auto_scales)
    delete(character.auto_scales)
    
    if bvh_data.frame_count > 0 {
        transform_data_sample_frame(&character.xform[character.count], &bvh_data, 0, 1.0)
        transform_data_forward_kinematics(&character.xform[character.count])
        
        height := f32(1e-8)
        for j in 0 ..< character.xform[character.count].joint_count {
            height = max(height, character.xform[character.count].global_positions[j].y)
        }
        scales[character.count] = height > 10 ? 01 : 1.0
        auto_scales[character.count] = 1.8 / height
    } else {
        auto_scales[character.count] = 1.0
    }
    character.auto_scales = auto_scales
    
    // Build joint names combo string
    joint_names_combo := make([]string, character.count + 1)
    copy(joint_names_combo, character.joint_names_combo)
    delete(character.joint_names_combo)
    
    combo_builder := strings.builder_make()
    defer strings.builder_destroy(&combo_builder)
    
    for i in 0 ..< bvh_data.joint_count {
        if i > 0 {
            strings.write_string(&combo_builder, ";")
        }
        strings.write_string(&combo_builder, bvh_data.joints[i].name)
    }
    joint_names_combo[character.count] = strings.clone(strings.to_string(combo_builder))
    character.joint_names_combo = joint_names_combo
    
    // Init other arrays if needed
    if len(character.colors) <= character.count {
        colors := make([]rl.Color, character.count + 1)
        copy(colors, character.colors)
        delete(character.colors)
        colors[character.count] = rl.WHITE
        character.colors = colors
    }
    if len(character.opacities) <= character.count {
        opacities := make([]f32, character.count + 1)
        copy(opacities, character.opacities)
        delete(character.opacities)
        opacities[character.count] = 1.0
        character.opacities = opacities
    }
    if len(character.radii) <= character.count {
        radii := make([]f32, character.count + 1)
        copy(radii, character.radii)
        delete(character.radii)
        radii[character.count] = 1.0
        character.radii = radii
    }
    character.count += 1
    
    fmt.println("INFO: Successfully loaded character", character.count)
    return true, ""
}

// Structure containing app state which we pass to the Update function
App :: struct {
    screen_width:  i32,
    screen_height: i32,
	camera:       OrbitCamera,
	shader:       rl.Shader,
    uniforms:     ShaderUniforms,
	// Resources
	ground_model: rl.Model,
    capsule_model: rl.Model,
	character:    Character,
    capsule_data: CapsuleData,
    scrubber_settings: Scrubber_Settings,
    render_settings: Render_Settings,
    err_msg: string,
}

// Update ticks the application
app_update :: proc(app: ^App) {
    // Update the App state with the current window dimensions
    app.screen_width = rl.GetScreenWidth()
    app.screen_height = rl.GetScreenHeight()
    // Process Key Presses
    if rl.IsKeyPressed(.H) {
        app.render_settings.draw_ui = !app.render_settings.draw_ui
    }
    // Tick time forward
    if app.scrubber_settings.playing {
        app.scrubber_settings.play_time += app.scrubber_settings.play_speed * rl.GetFrameTime()
        if app.scrubber_settings.play_time >= app.scrubber_settings.time_max {
            if app.scrubber_settings.looping && app.scrubber_settings.time_max >= 1e-8 {
                app.scrubber_settings.play_time = math.mod_f32(app.scrubber_settings.play_time, app.scrubber_settings.time_max) + app.scrubber_settings.time_min
            } else {
                app.scrubber_settings.play_time = app.scrubber_settings.time_max
            }
        }
    }
    // Sample Anim Data
    for i := 0; i < app.character.count; i+=1 {
        switch app.scrubber_settings.sample_mode {
        case 0:
            transform_data_sample_frame_nearest(
                &app.character.xform[i],
                &app.character.bvh[i],
                app.scrubber_settings.play_time,
                app.character.scales[i])
        case 1:
            transform_data_sample_frame_linear(
                &app.character.xform[i],
                &app.character.xform_tmp0[i],
                &app.character.xform_tmp1[i],
                &app.character.bvh[i],
                app.scrubber_settings.play_time,
                app.character.scales[i])
        case:
            transform_data_sample_frame_cubic(
                &app.character.xform[i],
                &app.character.xform_tmp0[i],
                &app.character.xform_tmp1[i],
                &app.character.xform_tmp2[i],
                &app.character.xform_tmp3[i],
                &app.character.bvh[i],
                app.scrubber_settings.play_time,
                app.character.scales[i])
        }
        if app.scrubber_settings.inplace {
            // Remove Translation on ground Plane
            app.character.xform[i].local_positions[0].x = 0
            app.character.xform[i].local_positions[0].z = 0
            
            // Attempt to extract rotation around vertical axis (this does not work 
            // for all animations but is pretty effective for almost all of them)
            vertical_rotation := linalg.quaternion_inverse(rl.QuaternionNormalize(transmute(quaternion128)[4]f32{
                0,
                app.character.xform[i].local_rotations[0].y,
                0,
                app.character.xform[i].local_rotations[0].w,
            }))
            // Remove rotation around vertical axis
            app.character.xform[i].local_rotations[0] = linalg.quaternion_mul_quaternion(
                vertical_rotation,
                app.character.xform[i].local_rotations[0])
        }
        transform_data_forward_kinematics(&app.character.xform[i])
    }
    // Update Camera
    camera_target := rl.Vector3{0, 1.0, 0}
    if app.camera.track && int(app.camera.track_bone) < app.character.xform[app.character.active].joint_count {
        camera_target = app.character.xform[app.character.active].global_positions[app.camera.track_bone]
    }
    orbit_camera_update(&app.camera, camera_target)
    
    // Create Capsules
    capsule_data_reset(&app.capsule_data)
    for i := 0; i < app.character.count; i+=1 {
        if app.render_settings.draw_capsules {
            capsule_data_append_from_transform_data(
                &app.capsule_data,
                &app.character.xform[i],
                app.character.radii[i],
                app.character.colors[i],
                app.character.opacities[i],
                !app.render_settings.draw_end_sites)
        }
    }
    // Ensure all data arrays match the reported capsule_count
    count := int(app.capsule_data.capsule_count)
    
    if len(app.capsule_data.capsule_sort) < count {
        resize(&app.capsule_data.capsule_sort, count)
    }
    // Check geometry arrays just in case the append function missed one
    if len(app.capsule_data.capsule_positions) < count {
        resize(&app.capsule_data.capsule_positions, count)
    }
    if len(app.capsule_data.capsule_rotations) < count {
        resize(&app.capsule_data.capsule_rotations, count)
    }
    if len(app.capsule_data.capsule_half_lengths) < count {
        resize(&app.capsule_data.capsule_half_lengths, count)
    }
    if len(app.capsule_data.capsule_radii) < count {
        resize(&app.capsule_data.capsule_radii, count)
    }
    if len(app.capsule_data.capsule_colors) < count {
        resize(&app.capsule_data.capsule_colors, count)
    }
    if len(app.capsule_data.capsule_opacities) < count {
        resize(&app.capsule_data.capsule_opacities, count)
    }
    // Ensure Shadow/AO lookup buffers are sized to their MAX constants
    // Used in draw_ground pass which happens first
    if len(app.capsule_data.ao_capsule_starts) < AO_CAPSULES_MAX {
        resize(&app.capsule_data.ao_capsule_starts, AO_CAPSULES_MAX)
        resize(&app.capsule_data.ao_capsule_vectors, AO_CAPSULES_MAX)
        resize(&app.capsule_data.ao_capsule_radii, AO_CAPSULES_MAX)
    }
    if len(app.capsule_data.shadow_capsule_starts) < SHADOW_CAPSULES_MAX {
        resize(&app.capsule_data.shadow_capsule_starts, SHADOW_CAPSULES_MAX)
        resize(&app.capsule_data.shadow_capsule_vectors, SHADOW_CAPSULES_MAX)
        resize(&app.capsule_data.shadow_capsule_radii, SHADOW_CAPSULES_MAX)
    }
    // Rendering
    frustum := frustum_from_camera(
        rl.GetCameraProjectionMatrix(&app.camera.cam, f32(app.screen_height) / f32(app.screen_width)),
        rl.GetCameraMatrix(app.camera.cam))
    
    rl.BeginDrawing()
    rl.ClearBackground(app.render_settings.background_color)
    rl.BeginMode3D(app.camera.cam)
    
    // Set shader uniforms that don't change based on the object being drawn
    sun_color_value := rl.Vector3{
        f32(app.render_settings.sun_color.r) / 255.0,
        f32(app.render_settings.sun_color.g) / 255.0,
        f32(app.render_settings.sun_color.b) / 255.0,
    }
    sky_color_value := rl.Vector3{
        f32(app.render_settings.sky_color.r) / 255.0,
        f32(app.render_settings.sky_color.g) / 255.0,
        f32(app.render_settings.sky_color.b) / 255.0,
    }
    object_specularity: f32 = 0.5
    object_glossiness: f32 = 10
    object_opacity: f32 = 1.0
    
    sun_light_position := rl.Vector3RotateByQuaternion(
        rl.Vector3{0, 0, 1.0},
        rl.QuaternionFromAxisAngle(rl.Vector3{0,1,0}, app.render_settings.sun_azimuth))
    
    sun_light_axis := linalg.vector_normalize(linalg.vector_cross(sun_light_position, rl.Vector3{0, 1.0, 0}))

    sun_light_dir := -rl.Vector3RotateByQuaternion(
        sun_light_position,
        rl.QuaternionFromAxisAngle(sun_light_axis, app.render_settings.sun_altitude))
    
    rl.SetShaderValue(app.shader, app.uniforms.camera_position, &app.camera.cam.position, .VEC3)
    rl.SetShaderValue(app.shader, app.uniforms.exposure, &app.render_settings.exposure, .FLOAT)
    rl.SetShaderValue(app.shader, app.uniforms.sun_dir, &sun_light_dir, .VEC3)
    rl.SetShaderValue(app.shader, app.uniforms.sun_strength, &app.render_settings.sun_light_strength, .FLOAT)
    rl.SetShaderValue(app.shader, app.uniforms.sun_color, &sun_color_value, .VEC3)
    rl.SetShaderValue(app.shader, app.uniforms.sky_strength, &app.render_settings.sky_light_strength, .FLOAT)
    rl.SetShaderValue(app.shader, app.uniforms.sky_color, &sky_color_value, .VEC3)
    rl.SetShaderValue(app.shader, app.uniforms.ambient_strength, &app.render_settings.ambient_light_strength, .FLOAT)
    rl.SetShaderValue(app.shader, app.uniforms.ground_strength, &app.render_settings.ground_light_strength, .FLOAT)
    rl.SetShaderValue(app.shader, app.uniforms.object_specularity, &object_specularity, .FLOAT)
    rl.SetShaderValue(app.shader, app.uniforms.object_glossiness, &object_glossiness, .FLOAT)
    rl.SetShaderValue(app.shader, app.uniforms.object_opacity, &object_opacity, .FLOAT)
    rl.SetShaderValue(app.shader, app.uniforms.ao_lookup_resolution, &app.capsule_data.ao_lookup_resolution, .VEC2)
    rl.SetShaderValue(app.shader, app.uniforms.shadow_lookup_resolution, &app.capsule_data.shadow_lookup_resolution, .VEC2)
    rl.SetShaderValueTexture(app.shader, app.uniforms.ao_lookup_table, app.capsule_data.ao_lookup_table)
    rl.SetShaderValueTexture(app.shader, app.uniforms.shadow_lookup_table, app.capsule_data.shadow_lookup_table)
    
    // Draw Ground
    if app.render_settings.draw_checker {
        ground_is_capsule: i32 = 0
        ground_color := rl.Vector3{0.75, 0.75, 0.75}
        rl.SetShaderValue(app.shader, app.uniforms.is_capsule, &ground_is_capsule, .INT)
        rl.SetShaderValue(app.shader, app.uniforms.object_color, &ground_color, .VEC3)
        
        // Draw ground in a grid of 10x10, 2 meter wide segments.
        for i in 0..<11 {
            for j in 0..<11 {
                // Check if we can cull ground segment
                ground_segment_position := rl.Vector3{
                    (f32(i) / 10 - 0.5) * 20,
                    0,
                    (f32(j) / 10 - 0.5) * 20,
                }
                if !frustum_contains_sphere(&frustum, ground_segment_position, math.sqrt_f32(2.0)) {
                    continue
                }
                // Gather all capsules casting AO on this ground segment
                app.capsule_data.ao_capsule_count = 0
                if app.render_settings.draw_capsules && app.render_settings.draw_ao {
                    capsule_data_update_ao_capsules_for_ground_segment(&app.capsule_data, ground_segment_position)
                }
                ao_capsule_count := min(i32(app.capsule_data.ao_capsule_count), AO_CAPSULES_MAX)
                
                rl.SetShaderValue(app.shader, app.uniforms.ao_capsule_count, &ao_capsule_count, .INT)
                rl.SetShaderValueV(app.shader, app.uniforms.ao_capsule_starts, raw_data(app.capsule_data.ao_capsule_starts[:]), .VEC3, ao_capsule_count)
                rl.SetShaderValueV(app.shader, app.uniforms.ao_capsule_vectors, raw_data(app.capsule_data.ao_capsule_vectors[:]), .VEC3, ao_capsule_count)
                rl.SetShaderValueV(app.shader, app.uniforms.ao_capsule_radii, raw_data(app.capsule_data.ao_capsule_radii[:]), .FLOAT, ao_capsule_count)
                
                // Gather all capsules casting shadows on this ground segment
                app.capsule_data.shadow_capsule_count = 0
                if app.render_settings.draw_capsules && app.render_settings.draw_shadows {
                    capsule_data_update_shadow_capsules_for_ground_segment(&app.capsule_data, ground_segment_position, sun_light_dir, app.render_settings.sun_light_cone_angle)
                }
                shadow_capsule_count := min(i32(app.capsule_data.shadow_capsule_count), SHADOW_CAPSULES_MAX)
                
                rl.SetShaderValue(app.shader, app.uniforms.shadow_capsule_count, &shadow_capsule_count, .INT)
                rl.SetShaderValueV(app.shader, app.uniforms.shadow_capsule_starts, raw_data(app.capsule_data.shadow_capsule_starts[:]), .VEC3, shadow_capsule_count)
                rl.SetShaderValueV(app.shader, app.uniforms.shadow_capsule_vectors, raw_data(app.capsule_data.shadow_capsule_vectors[:]), .VEC3, shadow_capsule_count)
                rl.SetShaderValueV(app.shader, app.uniforms.shadow_capsule_radii, raw_data(app.capsule_data.shadow_capsule_radii[:]), .FLOAT, shadow_capsule_count)
                
                rl.DrawModel(app.ground_model, ground_segment_position, 1.0, rl.WHITE)
            }
        }
    }
    // Draw Capsules
    if app.render_settings.draw_capsules {
        // Ensure the sort array is large enough to hold the current frame's capsules
        if len(app.capsule_data.capsule_sort) < int(app.capsule_data.capsule_count) {
            resize(&app.capsule_data.capsule_sort, int(app.capsule_data.capsule_count))
        }
        // Depth sort back to front for transparency
        for i in 0..<app.capsule_data.capsule_count {
            app.capsule_data.capsule_sort[i].index = i
            app.capsule_data.capsule_sort[i].value = linalg.vector_length(app.camera.cam.position - app.capsule_data.capsule_positions[i])
        }
        slice.sort_by(app.capsule_data.capsule_sort[:app.capsule_data.capsule_count], proc(i, j: CapsuleSort) -> bool {
            return i.value > j.value
        })
        // Render
        capsule_is_capsule: i32 = 1
        rl.SetShaderValue(app.shader, app.uniforms.is_capsule, &capsule_is_capsule, .INT)
        
        for i in 0..<app.capsule_data.capsule_count {
            j := app.capsule_data.capsule_sort[i].index
            
            // Check if we can cull capsule
            capsule_position := app.capsule_data.capsule_positions[j]
            capsule_half_length := app.capsule_data.capsule_half_lengths[j]
            capsule_radius := app.capsule_data.capsule_radii[j]
            
            if !frustum_contains_sphere(&frustum, capsule_position, capsule_half_length + capsule_radius) {
                continue
            }
            // If capsule is semi-transparent disable depth mask
            if app.capsule_data.capsule_opacities[j] < 1.0 {
                rlgl.DrawRenderBatchActive()
                rlgl.DisableDepthMask()
            }
            // Set shader properties
            capsule_rotation := app.capsule_data.capsule_rotations[j]
            capsule_start := capsule_start(capsule_position, capsule_rotation, capsule_half_length)
            capsule_vector := capsule_vector(capsule_position, capsule_rotation, capsule_half_length)
            
            rl.SetShaderValue(app.shader, app.uniforms.object_color, &app.capsule_data.capsule_colors[j], .VEC3)
            rl.SetShaderValue(app.shader, app.uniforms.object_opacity, &app.capsule_data.capsule_opacities[j], .FLOAT)
            rl.SetShaderValue(app.shader, app.uniforms.capsule_position, &app.capsule_data.capsule_positions[j], .VEC3)
            rl.SetShaderValue(app.shader, app.uniforms.capsule_rotation, &app.capsule_data.capsule_rotations[j], .VEC4)
            rl.SetShaderValue(app.shader, app.uniforms.capsule_half_length, &app.capsule_data.capsule_half_lengths[j], .FLOAT)
            rl.SetShaderValue(app.shader, app.uniforms.capsule_radius, &app.capsule_data.capsule_radii[j], .FLOAT)
            rl.SetShaderValue(app.shader, app.uniforms.capsule_start, &capsule_start, .VEC3)
            rl.SetShaderValue(app.shader, app.uniforms.capsule_vector, &capsule_vector, .VEC3)
            
            // Find all capsules casting AO on this capsule
            app.capsule_data.ao_capsule_count = 0
            if app.render_settings.draw_ao {
                capsule_data_update_ao_capsules_for_capsule(&app.capsule_data, j)
            }
            ao_capsule_count := min(i32(app.capsule_data.ao_capsule_count), AO_CAPSULES_MAX)
            
            rl.SetShaderValue(app.shader, app.uniforms.ao_capsule_count, &ao_capsule_count, .INT)
            rl.SetShaderValueV(app.shader, app.uniforms.ao_capsule_starts, raw_data(app.capsule_data.ao_capsule_starts[:]), .VEC3, ao_capsule_count)
            rl.SetShaderValueV(app.shader, app.uniforms.ao_capsule_vectors, raw_data(app.capsule_data.ao_capsule_vectors[:]), .VEC3, ao_capsule_count)
            rl.SetShaderValueV(app.shader, app.uniforms.ao_capsule_radii, raw_data(app.capsule_data.ao_capsule_radii[:]), .FLOAT, ao_capsule_count)
            
            // Find all capsules casting shadows on this capsule
            app.capsule_data.shadow_capsule_count = 0
            if app.render_settings.draw_shadows {
                capsule_data_update_shadow_capsules_for_capsule(&app.capsule_data, j, sun_light_dir, app.render_settings.sun_light_cone_angle)
            }
            shadow_capsule_count := min(i32(app.capsule_data.shadow_capsule_count), SHADOW_CAPSULES_MAX)
            
            rl.SetShaderValue(app.shader, app.uniforms.shadow_capsule_count, &shadow_capsule_count, .INT)
            rl.SetShaderValueV(app.shader, app.uniforms.shadow_capsule_starts, raw_data(app.capsule_data.shadow_capsule_starts[:]), .VEC3, shadow_capsule_count)
            rl.SetShaderValueV(app.shader, app.uniforms.shadow_capsule_vectors, raw_data(app.capsule_data.shadow_capsule_vectors[:]), .VEC3, shadow_capsule_count)
            rl.SetShaderValueV(app.shader, app.uniforms.shadow_capsule_radii, raw_data(app.capsule_data.shadow_capsule_radii[:]), .FLOAT, shadow_capsule_count)
            
            rl.DrawModel(app.capsule_model, rl.Vector3{}, 1.0, rl.WHITE)
            
            // Reset depth mask if rendered semi-transparent
            if app.capsule_data.capsule_opacities[j] < 1.0 {
                rlgl.DrawRenderBatchActive()
                rlgl.EnableDepthMask()
            }
        }
    }
    // Grid
    if app.render_settings.draw_grid {
        rl.DrawGrid(20, 1.0)
    }
    // Origin
    if app.render_settings.draw_origin {
        draw_transform(
            rl.Vector3{0, 01, 0},
            linalg.QUATERNIONF32_IDENTITY,
            1.0)
    }
    // Disable Depth Test
    rlgl.DrawRenderBatchActive()
    rlgl.DisableDepthTest()
    
    // Draw Capsule Wireframes
    if app.render_settings.draw_wireframes {
        draw_wireframes(&app.capsule_data, rl.DARKGRAY)
    }
    // Draw Bones
    if app.render_settings.draw_skeleton {
        for i := 0; i < app.character.count; i+=1 {
            draw_skeleton(
                &app.character.xform[i],
                app.render_settings.draw_end_sites,
                rl.DARKGRAY,
                rl.GRAY)
        }
    }
    // Draw Joint Transforms
    if app.render_settings.draw_transforms {
        for i := 0; i < app.character.count; i+=1 {
            draw_transforms(&app.character.xform[i])
        }
    }
    // Re-Enable Depth Test
    rlgl.DrawRenderBatchActive()
    rlgl.EnableDepthTest()
    // Rendering Done
    rl.EndMode3D()
    
    if app.render_settings.draw_ui {
        gui_render_settings(&app.render_settings, &app.capsule_data, app.screen_width, app.screen_height)
        rl.DrawFPS(230, 10)
        gui_orbit_camera(&app.camera, &app.character)
        gui_character_data(&app.character, &app.scrubber_settings, &app.err_msg)
        // Color Picker
        if app.character.color_picker_active {
            // GuiGroupBox and ColorPicker need to be implemented
        }
        // Scrubber
        gui_scrubber_settings(&app.scrubber_settings, &app.character, app.screen_width, app.screen_height)
    }
    rl.EndDrawing()
}

CAPSULE_OBJ :: `v 0.82165808 -0.82165808 -1.0579772e-18
v 0.82165808 -0.58100000 0.58100000
v 0.82165808 8.7595780e-17 0.82165808
v 0.82165808 0.58100000 0.58100000
v 0.82165808 0.82165808 9.9566116e-17
v 0.82165808 0.58100000 -0.58100000
v 0.82165808 2.8884397e-16 -0.82165808
v 0.82165808 -0.58100000 -0.58100000
v -0.82165808 -0.82165808 -1.0579772e-18
v -0.82165808 -0.58100000 0.58100000
v -0.82165808 -1.3028313e-17 0.82165808
v -0.82165808 0.58100000 0.58100000
v -0.82165808 0.82165808 9.9566116e-17
v -0.82165808 0.58100000 -0.58100000
v -0.82165808 1.8821987e-16 -0.82165808
v -0.82165808 -0.58100000 -0.58100000
v 1.16200000 1.5874776e-16 -1.0579772e-18
v -1.16200000 1.6443801e-17 -1.0579772e-18
v -9.1030792e-3 -1.15822938 -1.0579772e-18
v 9.1030792e-3 -1.15822938 -1.0579772e-18
v 9.1030792e-3 -0.81899185 0.81899185
v -9.1030792e-3 -0.81899185 0.81899185
v 9.1030792e-3 1.7232088e-17 1.15822938
v -9.1030792e-3 1.6117282e-17 1.15822938
v 9.1030792e-3 0.81899185 0.81899185
v -9.1030792e-3 0.81899185 0.81899185
v 9.1030792e-3 1.15822938 1.4078421e-16
v -9.1030792e-3 1.15822938 1.4078421e-16
v 9.1030792e-3 0.81899185 -0.81899185
v -9.1030792e-3 0.81899185 -0.81899185
v 9.1030792e-3 3.0091647e-16 -1.15822938
v -9.1030792e-3 2.9980166e-16 -1.15822938
v 9.1030792e-3 -0.81899185 -0.81899185
v -9.1030792e-3 -0.81899185 -0.81899185
vn 0.71524683 -0.69887193 -2.5012597e-16
vn 0.61185516 -0.55930013 0.55930013
vn 0.71524683 0000000e+0 0.69887193
vn 0.61185516 0.55930013 0.55930013
vn 0.71524683 0.69887193 1.5632873e-17
vn 0.61185516 0.55930013 -0.55930013
vn 0.71524683 6.2531494e-17 -0.69887193
vn 0.61185516 -0.55930013 -0.55930013
vn -0.71524683 -0.69887193 -2.5012597e-16
vn -0.61185516 -0.55930013 0.55930013
vn -0.71524683 0000000e+0 0.69887193
vn -0.61185516 0.55930013 0.55930013
vn -0.71524683 0.69887193 4.6898620e-17
vn -0.61185516 0.55930013 -0.55930013
vn -0.71524683 4.6898620e-17 -0.69887193
vn -0.61185516 -0.55930013 -0.55930013
vn 1.00000000 1.5208752e-17 -2.6615316e-17
vn -1.00000000 -1.5208752e-17 2.2813128e-17
vn -0.19614758 -0.98057439 -2.2848712e-16
vn 0.26047011 -0.96548191 -2.4273177e-16
vn 0.13072302 -0.70103905 0.70103905
vn -0.19614758 -0.69337080 0.69337080
vn 0.22349711 5.9825845e-2 0.97286685
vn -0.22349711 -5.9825845e-2 0.97286685
vn 0.15641931 0.75510180 0.63667438
vn -0.15641931 0.63667438 0.75510180
vn 0.22349711 0.97286685 -5.9825845e-2
vn -0.22349711 0.97286685 5.9825845e-2
vn 0.15641931 0.63667438 -0.75510180
vn -0.15641931 0.75510180 -0.63667438
vn 0.22349711 -5.9825845e-2 -0.97286685
vn -0.22349711 5.9825845e-2 -0.97286685
vn 0.15641931 -0.75510180 -0.63667438
vn -0.15641931 -0.63667438 -0.75510180
f 1//1 17//17 2//2
f 1//1 20//20 8//8
f 2//2 17//17 3//3
f 2//2 20//20 1//1
f 2//2 23//23 21//21
f 3//3 17//17 4//4
f 3//3 23//23 2//2
f 4//4 17//17 5//5
f 4//4 23//23 3//3
f 4//4 27//27 25//25
f 5//5 17//17 6//6
f 5//5 27//27 4//4
f 6//6 17//17 7//7
f 6//6 27//27 5//5
f 6//6 31//31 29//29
f 7//7 17//17 8//8
f 7//7 31//31 6//6
f 8//8 17//17 1//1
f 8//8 20//20 33//33
f 8//8 31//31 7//7
f 9//9 18//18 16//16
f 9//9 19//19 10//10
f 10//10 18//18 9//9
f 10//10 19//19 22//22
f 10//10 24//24 11//11
f 11//11 18//18 10//10
f 11//11 24//24 12//12
f 12//12 18//18 11//11
f 12//12 24//24 26//26
f 12//12 28//28 13//13
f 13//13 18//18 12//12
f 13//13 28//28 14//14
f 14//14 18//18 13//13
f 14//14 28//28 30//30
f 14//14 32//32 15//15
f 15//15 18//18 14//14
f 15//15 32//32 16//16
f 16//16 18//18 15//15
f 16//16 19//19 9//9
f 16//16 32//32 34//34
f 19//19 33//33 20//20
f 20//20 21//21 19//19
f 21//21 20//20 2//2
f 21//21 24//24 22//22
f 22//22 19//19 21//21
f 22//22 24//24 10//10
f 23//23 26//26 24//24
f 24//24 21//21 23//23
f 25//25 23//23 4//4
f 25//25 28//28 26//26
f 26//26 23//23 25//25
f 26//26 28//28 12//12
f 27//27 30//30 28//28
f 28//28 25//25 27//27
f 29//29 27//27 6//6
f 29//29 32//32 30//30
f 30//30 27//27 29//29
f 30//30 32//32 14//14
f 31//31 34//34 32//32
f 32//32 29//29 31//31
f 33//33 19//19 34//34
f 33//33 31//31 8//8
f 34//34 19//19 16//16
f 34//34 31//31 33//33`

// load_to_gpu: set to false when running unit tests to avoid OpenGL context errors
load_obj_from_memory :: proc(file_text: string, load_to_gpu := true) -> rl.Model {
	model := rl.Model{}
	model.transform = rl.Matrix(1)

	// Guard against empty input
	if len(file_text) == 0 {
		return model
	}
	// Parse
	res := tinyobj.parse_obj(file_text, "", tinyobj.FLAG_TRIANGULATE)
	if !res.success {
		return model
	}
	defer tinyobj.destroy(&res)

	// Guard against files with no valid geometry
	if len(res.attrib.faces) == 0 {
		return model
	}
	// Setup Model Structure
	model.meshCount = 1
	model.materialCount = 1

	// Allocates and Zero-Inits memory
	model.meshes = cast([^]rl.Mesh)libc.calloc(uint(model.meshCount), size_of(rl.Mesh))
	model.materials = cast([^]rl.Material)libc.calloc(uint(model.materialCount), size_of(rl.Material))
	model.meshMaterial = cast([^]i32)libc.calloc(uint(model.meshCount), size_of(i32))

	// Default Material
	model.materials[0] = rl.LoadMaterialDefault()
	model.meshMaterial[0] = 0 // Assign Mesh 0 to Material 0

	// Setup Mesh allocation
	// len(faces) is the total vertex count
	total_vertices := len(res.attrib.faces)
	
	mesh := &model.meshes[0]
	mesh.vertexCount = i32(total_vertices)
	mesh.triangleCount = i32(total_vertices / 3)

	// Allocate buffers (Vertices, TexCoords, Normals)
	mesh.vertices  = cast([^]f32)libc.calloc(uint(mesh.vertexCount * 3), size_of(f32))
	mesh.texcoords = cast([^]f32)libc.calloc(uint(mesh.vertexCount * 2), size_of(f32))
	mesh.normals   = cast([^]f32)libc.calloc(uint(mesh.vertexCount * 3), size_of(f32))

	// Create slices for easier filling
	verts_slice := ([^]f32)(mesh.vertices)[:mesh.vertexCount * 3]
	uvs_slice   := ([^]f32)(mesh.texcoords)[:mesh.vertexCount * 2]
	norms_slice := ([^]f32)(mesh.normals)[:mesh.vertexCount * 3]

	// Cache lengths for bounds checking
	n_verts := len(res.attrib.vertices)
	n_uvs   := len(res.attrib.texcoords)
	n_norms := len(res.attrib.normals)

	// Fill Buffers
	// `faces` array is already flattened, so we iterate 0..total_vertices.
	for i := 0; i < total_vertices; i += 1 {
		idx := res.attrib.faces[i]
		// Position
		v_idx := idx.v_idx
		if v_idx >= 0 && (v_idx * 3 + 2) < n_verts {
			verts_slice[i*3 + 0] = res.attrib.vertices[v_idx*3 + 0]
			verts_slice[i*3 + 1] = res.attrib.vertices[v_idx*3 + 1]
			verts_slice[i*3 + 2] = res.attrib.vertices[v_idx*3 + 2]
		}
		// TexCoords
		// Note: Raylib requires flipping the Y coordinate (1.0 - y)
		vt_idx := idx.vt_idx
		if n_uvs > 0 && vt_idx >= 0 && (vt_idx * 2 + 1) < n_uvs {
			uvs_slice[i*2 + 0] = res.attrib.texcoords[vt_idx*2 + 0]
			uvs_slice[i*2 + 1] = 1.0 - res.attrib.texcoords[vt_idx*2 + 1]
		}
		// Normals
		vn_idx := idx.vn_idx
		if n_norms > 0 && vn_idx >= 0 && (vn_idx * 3 + 2) < n_norms {
			norms_slice[i*3 + 0] = res.attrib.normals[vn_idx*3 + 0]
			norms_slice[i*3 + 1] = res.attrib.normals[vn_idx*3 + 1]
			norms_slice[i*3 + 2] = res.attrib.normals[vn_idx*3 + 2]
		} else {
			// Default normal (Up) if missing
			norms_slice[i*3 + 0] = 0
			norms_slice[i*3 + 1] = 1
			norms_slice[i*3 + 2] = 0
		}
	}
	if load_to_gpu {
		rl.UploadMesh(mesh, false)
	}
	return model
}

main :: proc() {
	rl.SetConfigFlags({.VSYNC_HINT, .MSAA_4X_HINT})
	rl.InitWindow(1280, 720, "BVH Viewer")
	defer rl.CloseWindow()
	rl.SetTargetFPS(60)
	
	app: App
	app.camera.cam = rl.Camera3D{
		position = {0, 5, 10},
		target = {0, 1, 0},
		up = {0, 1, 0},
		fovy = 45,
		projection = .PERSPECTIVE,
	}
	app.camera.distance = 5.0
	app.camera.altitude = 0.4
	
	// Load Resources
	app.ground_model = rl.LoadModelFromMesh(rl.GenMeshPlane(20, 20, 1, 1))
    defer rl.UnloadModel(app.ground_model)
    fmt.println("INFO: Loading shaders")
	app.shader = rl.LoadShader("./assets/bvh.vs", "./assets/bvh.fs")
    defer rl.UnloadShader(app.shader)
    app.capsule_model = load_obj_from_memory(CAPSULE_OBJ)
    defer rl.UnloadModel(app.capsule_model)
    fmt.println("INFO: Setting up shader uniforms")
    app.uniforms = shader_uniforms_init(app.shader)
	app.character = character_init()
    defer character_free(&app.character)
    capsule_data_init(&app.capsule_data)
    defer capsule_data_free(&app.capsule_data)
    app.scrubber_settings = scrubber_settings_init()
    app.render_settings = render_settings_init()
    capsule_data_update_shadow_lookup_table(&app.capsule_data, app.render_settings.sun_light_cone_angle)

    fmt.println("INFO: Loading default character stance.bvh")
    ok, err := character_load_from_file(&app.character, "assets/stance.bvh")
    if !ok {
        app.err_msg = fmt.tprintf("%s", err)
    }
    // If any characters loaded, update capsules and scrubber
    if app.character.count > 0 {
        app.character.active = app.character.count - 1;

        capsule_data_update_for_characters(&app.capsule_data, &app.character);
        scrubber_settings_recompute_limits(&app.scrubber_settings, &app.character);
        scrubber_settings_init_maxs(&app.scrubber_settings, &app.character);
    }
    for !rl.WindowShouldClose() {
        app_update(&app);
    }    
}