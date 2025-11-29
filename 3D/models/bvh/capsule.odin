package main

import "core:math"
import "core:slice"
import rl "vendor:raylib"

CapsuleSort :: struct {
    index: int,
    value: f32,
}

CapsuleData :: struct {
    // Data for all the capsules which are in the scene
    capsule_count:       int,
    capsule_positions:   [dynamic]rl.Vector3,
    capsule_rotations:   [dynamic]rl.Quaternion,
    capsule_radii:       [dynamic]f32,
    capsule_half_lengths: [dynamic]f32,
    capsule_colors:      [dynamic]rl.Vector3,
    capsule_opacities:   [dynamic]f32,
    capsule_sort:        [dynamic]CapsuleSort,
    
    // Buffers for all the capsules casting ambient occlusion
    ao_capsule_count:    int,
    ao_capsule_starts:   [dynamic]rl.Vector3,
    ao_capsule_vectors:  [dynamic]rl.Vector3,
    ao_capsule_radii:    [dynamic]f32,
    ao_capsule_sort:     [dynamic]CapsuleSort,
    
    // Buffers for all the capsules casting shadows
    shadow_capsule_count:   int,
    shadow_capsule_starts:  [dynamic]rl.Vector3,
    shadow_capsule_vectors: [dynamic]rl.Vector3,
    shadow_capsule_radii:   [dynamic]f32,
    shadow_capsule_sort:    [dynamic]CapsuleSort,
    
    // Lookup table for the capsule ambient occlusion function
    ao_lookup_image:      rl.Image,
    ao_lookup_table:      rl.Texture2D,
    ao_lookup_resolution: rl.Vector2,
    
    // Lookup table for the capsule shadow function
    shadow_lookup_image:      rl.Image,
    shadow_lookup_table:      rl.Texture2D,
    shadow_lookup_resolution: rl.Vector2,
}

// Get the start point of the capsule line segment
capsule_start :: proc(position: rl.Vector3, rotation: rl.Quaternion, half_length: f32) -> rl.Vector3 {
    return position + rl.Vector3RotateByQuaternion({half_length, 0, 0}, rotation)
}

// Get the end point of the capsule line segment
capsule_end :: proc(position: rl.Vector3, rotation: rl.Quaternion, half_length: f32) -> rl.Vector3 {
    return position + rl.Vector3RotateByQuaternion({-half_length, 0, 0}, rotation)
}

// Get the vector from the start to the end of the capsule line segment
capsule_vector :: proc(position: rl.Vector3, rotation: rl.Quaternion, half_length: f32) -> rl.Vector3 {
    start := capsule_start(position, rotation, half_length)
    end := position + rl.Vector3RotateByQuaternion({-half_length, 0, 0}, rotation)
    return end - start
}

capsule_directional_occlusion :: proc(
    pos: rl.Vector3, 
    cap_start: rl.Vector3, 
    cap_vec: rl.Vector3,
    cap_radius: f32, 
    cone_dir: rl.Vector3, 
    cone_angle: f32,
) -> f32 {
    ba := cap_vec
    pa := cap_start - pos
    cba := -cone_dir * rl.Vector3DotProduct(-cone_dir, ba) - ba
    t := saturate(rl.Vector3DotProduct(pa, cba) / max(rl.Vector3DotProduct(cba, cba), 1e-8))
    
    return sphere_directional_occlusion(pos, cap_start + ba * t, cap_radius, cone_dir, cone_angle)
}

capsule_sort_compare_greater :: proc(i, j: CapsuleSort) -> bool {
    return i.value > j.value
}

capsule_sort_compare_less :: proc(i, j: CapsuleSort) -> bool {
    return i.value < j.value
}

capsule_data_init :: proc(data: ^CapsuleData) {
    data.capsule_count = 0
    data.ao_capsule_count = 0
    data.shadow_capsule_count = 0
    
    // Capsule AO Lookup Table
    ao_size :: 32
    ao_data := make([]u8, ao_size * ao_size)
    data.ao_lookup_image = rl.Image{
        data = raw_data(ao_data),
        width = ao_size,
        height = ao_size,
        format = .UNCOMPRESSED_GRAYSCALE,
        mipmaps = 1,
    }
    data.ao_lookup_table = rl.LoadTextureFromImage(data.ao_lookup_image)
    data.ao_lookup_resolution = {ao_size, ao_size}
    rl.SetTextureWrap(data.ao_lookup_table, .CLAMP)
    rl.SetTextureFilter(data.ao_lookup_table, .BILINEAR)
    capsule_data_update_ao_lookup_table(data)
    
    // Capsule Shadow Lookup Table
    shadow_width :: 256
    shadow_height :: 128
    shadow_data := make([]u8, shadow_width * shadow_height)
    data.shadow_lookup_image = rl.Image{
        data = raw_data(shadow_data),
        width = shadow_width,
        height = shadow_height,
        format = .UNCOMPRESSED_GRAYSCALE,
        mipmaps = 1,
    }
    data.shadow_lookup_table = rl.LoadTextureFromImage(data.shadow_lookup_image)
    data.shadow_lookup_resolution = {shadow_width, shadow_height}
    rl.SetTextureWrap(data.shadow_lookup_table, .CLAMP)
    rl.SetTextureFilter(data.shadow_lookup_table, .BILINEAR)
    capsule_data_update_shadow_lookup_table(data, 0.2)
}

capsule_data_update_ao_lookup_table :: proc(data: ^CapsuleData) {
    width := int(data.ao_lookup_resolution.x)
    height := int(data.ao_lookup_resolution.y)
    pixels := slice.from_ptr(cast([^]u8)data.ao_lookup_image.data, width * height)
    
    for y in 0..<height {
        for x in 0..<width {
            nl_angle := (f32(x) / f32(width - 1)) * math.PI
            h := 1.0 + (AO_RATIO_MAX - 1.0) * (f32(y) / f32(height - 1))
            pixels[y * width + x] = u8(clamp(255.0 * sphere_occlusion_lookup(nl_angle, h), 0, 255))
        }
    }
    rl.UpdateTexture(data.ao_lookup_table, data.ao_lookup_image.data)
}

capsule_data_update_shadow_lookup_table :: proc(data: ^CapsuleData, cone_angle: f32) {
    width := int(data.shadow_lookup_resolution.x)
    height := int(data.shadow_lookup_resolution.y)
    pixels := slice.from_ptr(cast([^]u8)data.shadow_lookup_image.data, width * height)
    
    for y in 0..<height {
        for x in 0..<width {
            phi := (f32(x) / f32(width - 1)) * math.PI
            theta := (f32(y) / f32(height - 1)) * (math.PI / 2.0)
            pixels[y * width + x] = u8(clamp(255.0 * sphere_directional_occlusion_lookup(phi, theta, cone_angle), 0, 255))
        }
    }
    rl.UpdateTexture(data.shadow_lookup_table, data.shadow_lookup_image.data)
}

capsule_data_resize :: proc(data: ^CapsuleData, max_count: i32) {
    count := int(max_count)
    resize(&data.capsule_positions, count)
    resize(&data.capsule_rotations, count)
    resize(&data.capsule_radii, count)
    resize(&data.capsule_half_lengths, count)
    resize(&data.capsule_colors, count)
    resize(&data.capsule_opacities, count)
    resize(&data.capsule_sort, count)
    resize(&data.ao_capsule_starts, count)
    resize(&data.ao_capsule_vectors, count)
    resize(&data.ao_capsule_radii, count)
    resize(&data.ao_capsule_sort, count)
    resize(&data.shadow_capsule_starts, count)
    resize(&data.shadow_capsule_vectors, count)
    resize(&data.shadow_capsule_radii, count)
    resize(&data.shadow_capsule_sort, count)
}

capsule_data_free :: proc(data: ^CapsuleData) {
    delete(data.capsule_positions)
    delete(data.capsule_rotations)
    delete(data.capsule_radii)
    delete(data.capsule_half_lengths)
    delete(data.capsule_colors)
    delete(data.capsule_opacities)
    delete(data.capsule_sort)
    delete(data.ao_capsule_starts)
    delete(data.ao_capsule_vectors)
    delete(data.ao_capsule_radii)
    delete(data.ao_capsule_sort)
    delete(data.shadow_capsule_starts)
    delete(data.shadow_capsule_vectors)
    delete(data.shadow_capsule_radii)
    delete(data.shadow_capsule_sort)
    rl.UnloadImage(data.ao_lookup_image)
    rl.UnloadTexture(data.ao_lookup_table)
    rl.UnloadImage(data.shadow_lookup_image)
    rl.UnloadTexture(data.shadow_lookup_table)
}

capsule_data_reset :: proc(data: ^CapsuleData) {
    data.capsule_count = 0
    data.ao_capsule_count = 0
    data.shadow_capsule_count = 0
}

// Append capsules to the capsule data based off the joint transforms
capsule_data_append_from_transform_data :: proc(
    data: ^CapsuleData, 
    xforms: ^TransformData, 
    max_capsule_radius: f32, 
    color: rl.Color, 
    opacity: f32, 
    ignore_end_site: bool,
) {
    // Safety resize
    required_size := i32(data.capsule_count + xforms.joint_count)
    if len(data.capsule_positions) < int(required_size) {
        capsule_data_resize(data, required_size)
    }
    for i in 0..<xforms.joint_count {
        p := xforms.parents[i]
        if p == -1 do continue
        if ignore_end_site && xforms.end_site[i] do continue
        
        capsule_half_length := rl.Vector3Length(xforms.local_positions[i]) / 2.0
        capsule_radius := min(max_capsule_radius, capsule_half_length) + f32(i % 2) * 0.001
        if capsule_radius < 0.001 do continue
        
        capsule_position := (xforms.global_positions[i] + xforms.global_positions[p]) * 0.5
        capsule_rotation := xforms.global_rotations[p] * quat_between({1, 0, 0}, rl.Vector3Normalize(xforms.local_positions[i]))
        
        data.capsule_positions[data.capsule_count] = capsule_position
        data.capsule_rotations[data.capsule_count] = capsule_rotation
        data.capsule_half_lengths[data.capsule_count] = capsule_half_length
        data.capsule_radii[data.capsule_count] = capsule_radius
        data.capsule_colors[data.capsule_count] = {f32(color.r) / 255.0, f32(color.g) / 255.0, f32(color.b) / 255.0}
        data.capsule_opacities[data.capsule_count] = opacity
        data.capsule_count += 1
    }
}

// Gather all of the capsules which are potentially casting ambient occlusion on a ground segment
capsule_data_update_ao_capsules_for_ground_segment :: proc(data: ^CapsuleData, ground_segment_position: rl.Vector3) {
    // Safety resize
    if len(data.ao_capsule_sort) < data.capsule_count {
        count := int(data.capsule_count)
        resize(&data.ao_capsule_sort, count)
        resize(&data.ao_capsule_starts, count)
        resize(&data.ao_capsule_vectors, count)
        resize(&data.ao_capsule_radii, count)
    }
    data.ao_capsule_count = 0
    
    for i in 0..<data.capsule_count {
        capsule_position := data.capsule_positions[i]
        capsule_half_length := data.capsule_half_lengths[i]
        capsule_radius := data.capsule_radii[i]
        
        // Check if bounding spheres are more than AO_RATIO_MAX away from each other
        if rl.Vector3Distance(ground_segment_position, capsule_position) - sqrt_two > capsule_half_length + AO_RATIO_MAX * capsule_radius {
            continue
        }
        capsule_rotation := data.capsule_rotations[i]
        capsule_start := capsule_start(capsule_position, capsule_rotation, capsule_half_length)
        capsule_end_val := capsule_end(capsule_position, capsule_rotation, capsule_half_length)
        capsule_vec := capsule_vector(capsule_position, capsule_rotation, capsule_half_length)
        
        capsule_time, ground_point := nearest_point_between_line_segment_and_ground_segment(
            capsule_start,
            capsule_end_val,
            rl.Vector3{ground_segment_position.x - 1, 0, ground_segment_position.z - 1},
            rl.Vector3{ground_segment_position.x + 1, 0, ground_segment_position.z + 1},
        )
        capsule_point := capsule_start + capsule_vec * capsule_time
        
        // Check if the nearest point on the ground is more than AO_RATIO_MAX away
        if rl.Vector3Distance(ground_point, capsule_point) > AO_RATIO_MAX * capsule_radius {
            continue
        }
        // Compute the actual occlusion for the closest point on the ground
        capsule_occlusion := rl.Vector3Distance(ground_point, capsule_point) < capsule_radius ? 0.0 :
            sphere_occlusion(ground_point, {0, 1, 0}, capsule_point, capsule_radius)
        
        if capsule_occlusion < 0.99 {
            data.ao_capsule_sort[data.ao_capsule_count] = {i, capsule_occlusion}
            data.ao_capsule_count += 1
        }
    }
    slice.sort_by(data.ao_capsule_sort[:data.ao_capsule_count], capsule_sort_compare_greater)
    
    for i in 0..<data.ao_capsule_count {
        j := data.ao_capsule_sort[i].index
        data.ao_capsule_starts[i] = capsule_start(data.capsule_positions[j], data.capsule_rotations[j], data.capsule_half_lengths[j])
        data.ao_capsule_vectors[i] = capsule_vector(data.capsule_positions[j], data.capsule_rotations[j], data.capsule_half_lengths[j])
        data.ao_capsule_radii[i] = data.capsule_radii[j]
    }
}

// Gather all of the capsules which are potentially casting ambient occlusion on another capsule
capsule_data_update_ao_capsules_for_capsule :: proc(data: ^CapsuleData, capsule_index: int) {
    // Safety resize
    if len(data.ao_capsule_sort) < data.capsule_count {
        count := int(data.capsule_count)
        resize(&data.ao_capsule_sort, count)
        resize(&data.ao_capsule_starts, count)
        resize(&data.ao_capsule_vectors, count)
        resize(&data.ao_capsule_radii, count)
    }
    query_capsule_position := data.capsule_positions[capsule_index]
    query_capsule_half_length := data.capsule_half_lengths[capsule_index]
    query_capsule_radius := data.capsule_radii[capsule_index]
    query_capsule_rotation := data.capsule_rotations[capsule_index]
    query_capsule_start := capsule_start(query_capsule_position, query_capsule_rotation, query_capsule_half_length)
    query_capsule_end := capsule_end(query_capsule_position, query_capsule_rotation, query_capsule_half_length)
    query_capsule_vector := capsule_vector(query_capsule_position, query_capsule_rotation, query_capsule_half_length)
    
    data.ao_capsule_count = 0
    
    for i in 0..<data.capsule_count {
        if i == capsule_index do continue
        
        capsule_position := data.capsule_positions[i]
        capsule_radius := data.capsule_radii[i]
        capsule_half_length := data.capsule_half_lengths[i]
        
        // Check if the bounding spheres are more than AO_RATIO_MAX away from each other
        if rl.Vector3Distance(query_capsule_position, capsule_position) - query_capsule_half_length - query_capsule_radius >
           capsule_half_length + AO_RATIO_MAX * capsule_radius {
            continue
        }
        capsule_rotation := data.capsule_rotations[i]
        capsule_start_val := capsule_start(capsule_position, capsule_rotation, capsule_half_length)
        capsule_end_val := capsule_end(capsule_position, capsule_rotation, capsule_half_length)
        capsule_vec := capsule_vector(capsule_position, capsule_rotation, capsule_half_length)
        
        capsule_time, query_time := nearest_point_between_line_segments(
            capsule_start_val,
            capsule_end_val,
            query_capsule_start,
            query_capsule_end,
        )
        
        capsule_point := capsule_start_val + capsule_vec * capsule_time
        query_point := query_capsule_start + query_capsule_vector * query_time
        
        // Check if the nearest points on the two capsules are more than AO_RATIO_MAX away
        if rl.Vector3Distance(query_point, capsule_point) - query_capsule_radius > AO_RATIO_MAX * capsule_radius {
            continue
        }
        // Compute the actual occlusion at the nearest point
        surface_normal := rl.Vector3Normalize(capsule_point - query_point)
        surface_point := query_point + surface_normal * query_capsule_radius
        capsule_occlusion := rl.Vector3Distance(query_point, capsule_point) <= query_capsule_radius + capsule_radius ? 0.0 :
            sphere_occlusion(surface_point, surface_normal, capsule_point, capsule_radius)
        
        if capsule_occlusion < 0.99 {
            data.ao_capsule_sort[data.ao_capsule_count] = {i, capsule_occlusion}
            data.ao_capsule_count += 1
        }
    }
    slice.sort_by(data.ao_capsule_sort[:data.ao_capsule_count], capsule_sort_compare_greater)
    
    for i in 0..<data.ao_capsule_count {
        j := data.ao_capsule_sort[i].index
        data.ao_capsule_starts[i] = capsule_start(data.capsule_positions[j], data.capsule_rotations[j], data.capsule_half_lengths[j])
        data.ao_capsule_vectors[i] = capsule_vector(data.capsule_positions[j], data.capsule_rotations[j], data.capsule_half_lengths[j])
        data.ao_capsule_radii[i] = data.capsule_radii[j]
    }
}

sqrt_two := math.sqrt_f32(2.0)

// Gather all of the capsules which are potentially casting shadows on a ground segment
capsule_data_update_shadow_capsules_for_ground_segment :: proc(
    data: ^CapsuleData, 
    ground_segment_position: rl.Vector3, 
    light_dir: rl.Vector3, 
    light_cone_angle: f32,
) {
    // Safety resize
    if len(data.shadow_capsule_sort) < data.capsule_count {
        count := int(data.capsule_count)
        resize(&data.shadow_capsule_sort, count)
        resize(&data.shadow_capsule_starts, count)
        resize(&data.shadow_capsule_vectors, count)
        resize(&data.shadow_capsule_radii, count)
    }
    light_ray := light_dir * 10.0
    data.shadow_capsule_count = 0
    
    for i in 0..<data.capsule_count {
        capsule_position := data.capsule_positions[i]
        capsule_half_length := data.capsule_half_lengths[i]
        capsule_radius := data.capsule_radii[i]
        
        mid_ray_time := nearest_point_between_line_segment_and_ground_plane(capsule_position, light_ray)
        ground_capsule_mid := capsule_position + light_ray * mid_ray_time
        max_ratio: f32 = 4.0
        
        // Check if the ground segment is more than maxRatio away from the shadow point at the center of the capsule
        if rl.Vector3Distance(ground_segment_position, ground_capsule_mid) - sqrt_two > capsule_half_length + max_ratio * capsule_radius {
            continue
        }
        capsule_rotation := data.capsule_rotations[i]
        capsule_start_val := capsule_start(capsule_position, capsule_rotation, capsule_half_length)
        capsule_end_val := capsule_end(capsule_position, capsule_rotation, capsule_half_length)
        capsule_vec := capsule_vector(capsule_position, capsule_rotation, capsule_half_length)
        
        start_ray_time := nearest_point_between_line_segment_and_ground_plane(capsule_start_val, light_ray)
        end_ray_time := nearest_point_between_line_segment_and_ground_plane(capsule_end_val, light_ray)
        
        ground_capsule_start := capsule_start_val + light_ray * start_ray_time
        ground_capsule_end := capsule_end_val + light_ray * end_ray_time
        
        ground_capsule_start.x = clamp(ground_capsule_start.x, ground_segment_position.x - 1, ground_segment_position.x + 1)
        ground_capsule_start.z = clamp(ground_capsule_start.z, ground_segment_position.z - 1, ground_segment_position.z + 1)
        ground_capsule_end.x = clamp(ground_capsule_end.x, ground_segment_position.x - 1, ground_segment_position.x + 1)
        ground_capsule_end.z = clamp(ground_capsule_end.z, ground_segment_position.z - 1, ground_segment_position.z + 1)
        
        // Check if both points are more than maxRatio away from the ground segment
        if rl.Vector3Distance(ground_segment_position, ground_capsule_start) - sqrt_two > max_ratio * capsule_radius &&
           rl.Vector3Distance(ground_segment_position, ground_capsule_end) - sqrt_two > max_ratio * capsule_radius {
            continue
        }
        // Compute the actual occlusion at both points and take the min
        capsule_occlusion := min(
            capsule_directional_occlusion(ground_capsule_start, capsule_start_val, capsule_vec, capsule_radius, light_dir, light_cone_angle),
            capsule_directional_occlusion(ground_capsule_end, capsule_start_val, capsule_vec, capsule_radius, light_dir, light_cone_angle),
        )
        if capsule_occlusion < 0.99 {
            data.shadow_capsule_sort[data.shadow_capsule_count] = {i, capsule_occlusion}
            data.shadow_capsule_count += 1
        }
    }
    slice.sort_by(data.shadow_capsule_sort[:data.shadow_capsule_count], capsule_sort_compare_greater)
    
    for i in 0..<data.shadow_capsule_count {
        j := data.shadow_capsule_sort[i].index
        data.shadow_capsule_starts[i] = capsule_start(data.capsule_positions[j], data.capsule_rotations[j], data.capsule_half_lengths[j])
        data.shadow_capsule_vectors[i] = capsule_vector(data.capsule_positions[j], data.capsule_rotations[j], data.capsule_half_lengths[j])
        data.shadow_capsule_radii[i] = data.capsule_radii[j]
    }
}

// Gather all of the capsules which are potentially casting shadows on another capsule
capsule_data_update_shadow_capsules_for_capsule :: proc(
    data: ^CapsuleData, 
    capsule_index: int, 
    light_dir: rl.Vector3, 
    light_cone_angle: f32,
) {
    // Safety resize
    if len(data.shadow_capsule_sort) < data.capsule_count {
        count := int(data.capsule_count)
        resize(&data.shadow_capsule_sort, count)
        resize(&data.shadow_capsule_starts, count)
        resize(&data.shadow_capsule_vectors, count)
        resize(&data.shadow_capsule_radii, count)
    }
    light_ray := light_dir * 10.0
    
    query_capsule_position := data.capsule_positions[capsule_index]
    query_capsule_half_length := data.capsule_half_lengths[capsule_index]
    query_capsule_radius := data.capsule_radii[capsule_index]
    query_capsule_rotation := data.capsule_rotations[capsule_index]
    query_capsule_start := capsule_start(query_capsule_position, query_capsule_rotation, query_capsule_half_length)
    query_capsule_end := capsule_end(query_capsule_position, query_capsule_rotation, query_capsule_half_length)
    query_capsule_vector := capsule_vector(query_capsule_position, query_capsule_rotation, query_capsule_half_length)
    
    data.shadow_capsule_count = 0
    
    for i in 0..<data.capsule_count {
        if i == capsule_index do continue
        
        capsule_position := data.capsule_positions[i]
        capsule_half_length := data.capsule_half_lengths[i]
        capsule_radius := data.capsule_radii[i]
        
        mid_ray_time := nearest_point_on_line_segment(capsule_position, light_ray, query_capsule_position)
        capsule_mid := capsule_position + light_ray * mid_ray_time
        max_ratio: f32 = 4.0
        
        // Check if this is greater than maxRatio away
        if rl.Vector3Distance(query_capsule_position, capsule_mid) - query_capsule_half_length - query_capsule_radius > 
           capsule_half_length + max_ratio * capsule_radius {
            continue
        }
        capsule_rotation := data.capsule_rotations[i]
        capsule_start_val := capsule_start(capsule_position, capsule_rotation, capsule_half_length)
        capsule_end_val := capsule_end(capsule_position, capsule_rotation, capsule_half_length)
        capsule_vec := capsule_vector(capsule_position, capsule_rotation, capsule_half_length)
        
        query_capsule_time, nearest_ray_point := nearest_point_between_line_segment_and_swept_line(
            query_capsule_start,
            query_capsule_end,
            capsule_start_val,
            capsule_end_val,
            light_ray,
        )
        query_capsule_point := query_capsule_start + query_capsule_vector * query_capsule_time
        
        // If this distance is greater than maxRatio away then skip
        if rl.Vector3Distance(query_capsule_point, nearest_ray_point) - query_capsule_radius > 
           capsule_half_length + max_ratio * capsule_radius {
            continue
        }
        surface_normal := rl.Vector3Normalize(nearest_ray_point - query_capsule_point)
        surface_point := query_capsule_point + surface_normal * query_capsule_radius
        
        // Find actual occlusion amount
        capsule_occlusion := rl.Vector3Distance(query_capsule_point, nearest_ray_point) <= query_capsule_radius + capsule_radius ? 0.0 :
            capsule_directional_occlusion(surface_point, capsule_start_val, capsule_vec, capsule_radius, light_dir, light_cone_angle)
        
        if capsule_occlusion < 0.99 {
            data.shadow_capsule_sort[data.shadow_capsule_count] = {i, capsule_occlusion}
            data.shadow_capsule_count += 1
        }
    }
    slice.sort_by(data.shadow_capsule_sort[:data.shadow_capsule_count], capsule_sort_compare_greater)
    
    for i in 0..<data.shadow_capsule_count {
        j := data.shadow_capsule_sort[i].index
        data.shadow_capsule_starts[i] = capsule_start(data.capsule_positions[j], data.capsule_rotations[j], data.capsule_half_lengths[j])
        data.shadow_capsule_vectors[i] = capsule_vector(data.capsule_positions[j], data.capsule_rotations[j], data.capsule_half_lengths[j])
        data.shadow_capsule_radii[i] = data.capsule_radii[j]
    }
}

// Resize so that we have enough capsules in the buffers for the given set of characters
capsule_data_update_for_characters :: proc(capsule_data: ^CapsuleData, character_data: ^Character) {
    total_joint_count: i32
    for i in 0..<character_data.count {
        total_joint_count += character_data.bvh[i].joint_count
    }
    capsule_data_resize(capsule_data, total_joint_count)
}