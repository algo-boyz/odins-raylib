package main

import "core:math"
import "core:math/linalg"
import rl "vendor:raylib"

@(private)
saturate :: proc(x: f32) -> f32 {
    return clamp(x, 0.0, 1.0)
}

@(private)
square :: proc(x: f32) -> f32 {
    return x * x
}

quat_between :: proc(p, q: rl.Vector3) -> rl.Quaternion {
	c := rl.Vector3CrossProduct(p, q)
	o := transmute(quaternion128)[4]f32{
		c.x,
		c.y,
		c.z,
		math.sqrt(rl.Vector3DotProduct(p, p) * rl.Vector3DotProduct(q, q)) + rl.Vector3DotProduct(p, q),
	}
	return abs(o) < 1e-8 ? rl.QuaternionFromAxisAngle({1, 0, 0}, rl.PI) : rl.QuaternionNormalize(o)
}

quat_abs :: proc(q: rl.Quaternion) -> rl.Quaternion {
	q := q
	if q.w < 0.0 {
		q.x = -q.x; q.y = -q.y; q.z = -q.z; q.w = -q.w
	}
	return q
}

quat_exp :: proc(v: rl.Vector3) -> rl.Quaternion {
	halfangle := math.sqrt(v.x*v.x + v.y*v.y + v.z*v.z)
	if halfangle < 1e-4 {
		return rl.QuaternionNormalize(transmute(quaternion128)[4]f32{v.x, v.y, v.z, 1.0})
	} else {
		c := math.cos(halfangle)
		s := math.sin(halfangle) / halfangle
		return transmute(quaternion128)[4]f32{s * v.x, s * v.y, s * v.z, c}
	}
}

quat_log :: proc(q: rl.Quaternion) -> rl.Vector3 {
	length := math.sqrt(q.x*q.x + q.y*q.y + q.z*q.z)
	if length < 1e-4 {
		return {q.x, q.y, q.z}
	} else {
		halfangle := math.atan2(length, q.w)
		return {q.x, q.y, q.z} * halfangle / length
	}
}

quat_to_scaled_angle_axis :: proc(q: rl.Quaternion) -> rl.Vector3 {
	return quat_log(q) * 2.0
}

quat_from_scaled_angle_axis :: proc(v: rl.Vector3) -> rl.Quaternion {
	return quat_exp(v * 0.5)
}

// Cubic Interpolation
vec3_hermite :: proc(p0, p1, v0, v1: rl.Vector3, alpha: f32) -> rl.Vector3 {
	x := alpha
	w0 := 2*x*x*x - 3*x*x + 1
	w1 := 3*x*x - 2*x*x*x
	w2 := x*x*x - 2*x*x + x
	w3 := x*x*x - x*x
	return ((p0 * w0) + (p1 * w1)) + ((v0 * w2) + (v1 * w3))
}

vec3_interpolate_cubic :: proc(p0, p1, p2, p3: rl.Vector3, alpha: f32) -> rl.Vector3 {
	v1 := ((p1-p0) + (p2-p1)) * 0.5
    v2 := ((p2-p1) + (p3-p2)) * 0.5
	return vec3_hermite(p1, p2, v1, v2, alpha)
}

quat_hermite :: proc(r0, r1: rl.Quaternion, v0, v1: rl.Vector3, alpha: f32) -> rl.Quaternion {
	x := alpha
	w1 := 3*x*x - 2*x*x*x
	w2 := x*x*x - 2*x*x + x
	w3 := x*x*x - x*x
	r1r0 := quat_to_scaled_angle_axis(quat_abs((r1 * (1/r0))))

	return quat_from_scaled_angle_axis((((r1r0 * w1) + (v0 * w2)) + (v1 * w3))) * r0
}

quat_interpolate_cubic :: proc(r0, r1, r2, r3: rl.Quaternion, alpha: f32) -> rl.Quaternion {
	r1r0 := quat_to_scaled_angle_axis(quat_abs((r1 * (1/r0))))
	r2r1 := quat_to_scaled_angle_axis(quat_abs((r2 * (1/r1))))
	r3r2 := quat_to_scaled_angle_axis(quat_abs((r3 * (1/r2))))
	v1 := (r1r0 + r2r1) * 0.5
	v2 := (r2r1 + r3r2) * 0.5
	return quat_hermite(r1, r2, v1, v2, alpha)
}

// Returns the time parameter along a line segment closest to another point
nearest_point_on_line_segment :: proc(
    line_start,
    line_vector,
    point: rl.Vector3,
) -> f32 {
    ap := point - line_start
    lengthsq := linalg.length2(line_vector)
    return lengthsq < 1e-8 ? 0.5 : saturate(linalg.dot(line_vector, ap) / lengthsq)
}

// Returns the time parameters along two line segments at the closest point between the two
nearest_point_between_line_segments :: proc(
    line0_start,
    line0_end,
    line1_start,
    line1_end: rl.Vector3,
) -> (nearest_time0: f32, nearest_time1: f32) {
    line0_vec := line0_end - line0_start
    line1_vec := line1_end - line1_start
    d0 := linalg.length2(line1_start - line0_start)
    d1 := linalg.length2(line1_end - line0_start)
    d2 := linalg.length2(line1_start - line0_end)
    d3 := linalg.length2(line1_end - line0_end)
    nearest_time0 = (d2 < d0 || d2 < d1 || d3 < d0 || d3 < d1) ? 1.0 : 0.0
    nearest_time1 = nearest_point_on_line_segment(line1_start, line1_vec, line0_start + line0_vec * nearest_time0)
    nearest_time0 = nearest_point_on_line_segment(line0_start, line0_vec, line1_start + line1_vec * nearest_time1)
    return
}

// Returns the time parameter for a line segment closest to the plane
nearest_point_between_line_segment_and_plane :: proc(
    line_start,
    line_vector,
    plane_position,
    plane_normal: rl.Vector3,
) -> f32 {
    denom := linalg.dot(plane_normal, line_vector)
    if abs(denom) < 1e-8 {
        return 0.5
    }
    return saturate(linalg.dot(plane_position - line_start, plane_normal) / denom)
}

// Returns the time parameter for a line segment closest to the ground plane
nearest_point_between_line_segment_and_ground_plane :: proc(
    line_start,
    line_vector: rl.Vector3,
) -> f32 {
    return abs(line_vector.y) < 1e-8 ? 0.5 : saturate((-line_start.y) / line_vector.y)
}

// Returns the time parameter and nearest point on the ground between a line segment and ground segment
nearest_point_between_line_segment_and_ground_segment :: proc(
    line_start,
    line_end,
    ground_mins,
    ground_maxs: rl.Vector3,
) -> (nearest_time_on_line: f32, nearest_point_on_ground: rl.Vector3) {
    line_vec := line_end - line_start
    
    // Check Against Plane
    nearest_time_on_line = nearest_point_between_line_segment_and_ground_plane(line_start, line_vec)
    nearest_point_on_ground = rl.Vector3{
        line_start.x + nearest_time_on_line * line_vec.x,
        0.0,
        line_start.z + nearest_time_on_line * line_vec.z,
    }
    // If point is inside plane bounds it must be the nearest
    if nearest_point_on_ground.x >= ground_mins.x &&
       nearest_point_on_ground.x <= ground_maxs.x &&
       nearest_point_on_ground.z >= ground_mins.z &&
       nearest_point_on_ground.z <= ground_maxs.z {
        return
    }
    // Check against four edges
    edge_start0 := rl.Vector3{ground_mins.x, 0.0, ground_mins.z}
    edge_end0 := rl.Vector3{ground_mins.x, 0.0, ground_maxs.z}
    
    edge_start1 := rl.Vector3{ground_mins.x, 0.0, ground_maxs.z}
    edge_end1 := rl.Vector3{ground_maxs.x, 0.0, ground_maxs.z}
    
    edge_start2 := rl.Vector3{ground_maxs.x, 0.0, ground_maxs.z}
    edge_end2 := rl.Vector3{ground_maxs.x, 0.0, ground_mins.z}
    
    edge_start3 := rl.Vector3{ground_maxs.x, 0.0, ground_mins.z}
    edge_end3 := rl.Vector3{ground_mins.x, 0.0, ground_mins.z}
    
    nearest_time_on_line0, nearest_time_on_edge0 := nearest_point_between_line_segments(
        line_start, line_end, edge_start0, edge_end0)
    nearest_time_on_line1, nearest_time_on_edge1 := nearest_point_between_line_segments(
        line_start, line_end, edge_start1, edge_end1)
    nearest_time_on_line2, nearest_time_on_edge2 := nearest_point_between_line_segments(
        line_start, line_end, edge_start2, edge_end2)
    nearest_time_on_line3, nearest_time_on_edge3 := nearest_point_between_line_segments(
        line_start, line_end, edge_start3, edge_end3)
    
    nearest_point_on_line0 := line_start + line_vec * nearest_time_on_line0
    nearest_point_on_line1 := line_start + line_vec * nearest_time_on_line1
    nearest_point_on_line2 := line_start + line_vec * nearest_time_on_line2
    nearest_point_on_line3 := line_start + line_vec * nearest_time_on_line3
    
    nearest_point_on_edge0 := edge_start0 + (edge_end0 - edge_start0) * nearest_time_on_edge0
    nearest_point_on_edge1 := edge_start1 + (edge_end1 - edge_start1) * nearest_time_on_edge1
    nearest_point_on_edge2 := edge_start2 + (edge_end2 - edge_start2) * nearest_time_on_edge2
    nearest_point_on_edge3 := edge_start3 + (edge_end3 - edge_start3) * nearest_time_on_edge3
    
    distance0 := linalg.distance(nearest_point_on_line0, nearest_point_on_edge0)
    distance1 := linalg.distance(nearest_point_on_line1, nearest_point_on_edge1)
    distance2 := linalg.distance(nearest_point_on_line2, nearest_point_on_edge2)
    distance3 := linalg.distance(nearest_point_on_line3, nearest_point_on_edge3)
    
    if distance0 <= distance1 && distance0 <= distance2 && distance0 <= distance3 {
        nearest_time_on_line = nearest_time_on_line0
        nearest_point_on_ground = nearest_point_on_edge0
        return
    }
    if distance1 <= distance0 && distance1 <= distance2 && distance1 <= distance3 {
        nearest_time_on_line = nearest_time_on_line1
        nearest_point_on_ground = nearest_point_on_edge1
        return
    }
    if distance2 <= distance0 && distance2 <= distance1 && distance2 <= distance3 {
        nearest_time_on_line = nearest_time_on_line2
        nearest_point_on_ground = nearest_point_on_edge2
        return
    }
    if distance3 <= distance0 && distance3 <= distance1 && distance3 <= distance2 {
        nearest_time_on_line = nearest_time_on_line3
        nearest_point_on_ground = nearest_point_on_edge3
        return
    }
    unreachable()
}

project_point_onto_swept_line :: proc(
    swept_line_start,
    swept_line_vec,
    swept_line_sweep_vec,
        position: rl.Vector3,
    ) -> rl.Vector3 {
    w := position - swept_line_start
    u := linalg.normalize(swept_line_vec)
    v := linalg.normalize(swept_line_sweep_vec)
    
    // Solved using Cramer's Rule in 2D
    a1 := linalg.dot(u, u)
    b1 := linalg.dot(u, v)
    c1 := linalg.dot(w, u)
    a2 := linalg.dot(v, u)
    b2 := linalg.dot(v, v)
    c2 := linalg.dot(w, v)
    
    x := ((c1 * b2) - (b1 * c2)) / (a1 * b2 - b1 * a2)
    y := (c1 - x * a1) / b1
    
    x = clamp(x, 0.0, linalg.length(swept_line_vec))
    y = clamp(y, 0.0, linalg.length(swept_line_sweep_vec))
    
    return swept_line_start + u * x + v * y
}

// Returns the time parameter and nearest point on between a line segment and swept line segment
nearest_point_between_line_segment_and_swept_line :: proc(
    line_start,
    line_end,
    swept_line_start,
    swept_line_end,
    swept_line_sweep_vector: rl.Vector3,
) -> (nearest_time_on_line: f32, nearest_point_on_swept_line: rl.Vector3) {
    line_vec := line_end - line_start
    swept_line_vec := swept_line_end - swept_line_start
    
    plane_normal: rl.Vector3
    if linalg.length(swept_line_vec) < 1e-8 {
        plane_normal = linalg.normalize(linalg.cross(rl.Vector3{0.0, 1.0, 0.0}, swept_line_sweep_vector))
    } else {
        plane_normal = linalg.normalize(linalg.cross(swept_line_vec, swept_line_sweep_vector))
    }
    // Check Against Plane
    nearest_time_on_line0 := nearest_point_between_line_segment_and_plane(
        line_start, line_vec, swept_line_start, plane_normal)
    nearest_point_on_line0 := line_start + line_vec * nearest_time_on_line0
    
    nearest_point_on_swept_line0: rl.Vector3
    if linalg.length(swept_line_vec) > 1e-8 {
        nearest_point_on_swept_line0 = project_point_onto_swept_line(
            swept_line_start, 
            swept_line_vec, 
            swept_line_sweep_vector, 
            nearest_point_on_line0)
    } else {
        nearest_time_on_swept_line := nearest_point_on_line_segment(
            swept_line_start,
            swept_line_sweep_vector,
            nearest_point_on_line0)
        
        nearest_point_on_swept_line0 = swept_line_start + swept_line_sweep_vector * nearest_time_on_swept_line
    }
    distance0 := linalg.distance(nearest_point_on_line0, nearest_point_on_swept_line0)
    
    // Check against three edges
    edge_start1 := swept_line_start
    edge_end1 := swept_line_start + swept_line_sweep_vector
    edge_start2 := swept_line_end
    edge_end2 := swept_line_end + swept_line_sweep_vector
    edge_start3 := swept_line_start
    edge_end3 := swept_line_end
    
    nearest_time_on_line1, nearest_time_on_edge1 := nearest_point_between_line_segments(
        line_start, line_end, edge_start1, edge_end1)
    nearest_time_on_line2, nearest_time_on_edge2 := nearest_point_between_line_segments(
        line_start, line_end, edge_start2, edge_end2)
    nearest_time_on_line3, nearest_time_on_edge3 := nearest_point_between_line_segments(
        line_start, line_end, edge_start3, edge_end3)
    
    nearest_point_on_line1 := line_start + line_vec * nearest_time_on_line1
    nearest_point_on_line2 := line_start + line_vec * nearest_time_on_line2
    nearest_point_on_line3 := line_start + line_vec * nearest_time_on_line3
    
    nearest_point_on_swept_line1 := edge_start1 + (edge_end1 - edge_start1) * nearest_time_on_edge1
    nearest_point_on_swept_line2 := edge_start2 + (edge_end2 - edge_start2) * nearest_time_on_edge2
    nearest_point_on_swept_line3 := edge_start3 + (edge_end3 - edge_start3) * nearest_time_on_edge3
    
    distance1 := linalg.distance(nearest_point_on_line1, nearest_point_on_swept_line1)
    distance2 := linalg.distance(nearest_point_on_line2, nearest_point_on_swept_line2)
    distance3 := linalg.distance(nearest_point_on_line3, nearest_point_on_swept_line3)
    
    if distance0 <= distance1 && distance0 <= distance2 && distance0 <= distance3 {
        nearest_time_on_line = nearest_time_on_line0
        nearest_point_on_swept_line = nearest_point_on_swept_line0
        return
    }
    if distance1 <= distance0 && distance1 <= distance2 && distance1 <= distance3 {
        nearest_time_on_line = nearest_time_on_line1
        nearest_point_on_swept_line = nearest_point_on_swept_line1
        return
    }
    if distance2 <= distance0 && distance2 <= distance1 && distance2 <= distance3 {
        nearest_time_on_line = nearest_time_on_line2
        nearest_point_on_swept_line = nearest_point_on_swept_line2
        return
    }
    if distance3 <= distance0 && distance3 <= distance1 && distance3 <= distance2 {
        nearest_time_on_line = nearest_time_on_line3
        nearest_point_on_swept_line = nearest_point_on_swept_line3
        return
    }
    unreachable()
}

// The number of times radius being away from the sphere where
// the ambient occlusion drops off to zero
AO_RATIO_MAX :: 4.0

sphere_occlusion_lookup :: proc(nl_angle: f32, h: f32) -> f32 {
    nl := math.cos(nl_angle)
    h2 := h * h
    
    res := max(nl, 0.0) / h2
    k2 := 1.0 - h2 * nl * nl
    if k2 > 1e-4 {
        res = nl * math.acos(clamp(-nl * math.sqrt((h2 - 1.0) / max(1.0 - nl * nl, 1e-8)), -1.0, 1.0)) - 
              math.sqrt(k2 * (h2 - 1.0))
        res = (res / h2 + math.atan(math.sqrt(k2 / (h2 - 1.0)))) / math.PI
    }
    decay := max(1.0 - (h - 1.0) / (AO_RATIO_MAX - 1.0), 0.0)
    return 1.0 - res * decay
}

sphere_occlusion :: proc(pos, nor, sph: rl.Vector3, rad: f32) -> f32 {
    di := sph - pos
    l := linalg.length(di)
    nl_angle := math.acos(clamp(linalg.dot(nor, di * (1.0 / max(l, 1e-8))), -1.0, 1.0))
    h := l < rad ? 1.0 : l / rad
    return sphere_occlusion_lookup(nl_angle, h)
}

sphere_intersection_area :: proc(r1: f32, r2: f32, d: f32) -> f32 {
    if min(r1, r2) <= max(r1, r2) - d {
        return 1.0 - max(math.cos(r1), math.cos(r2))
    } else if r1 + r2 <= d {
        return 0.0
    }
    delta := abs(r1 - r2)
    x := 1.0 - saturate((d - delta) / max(r1 + r2 - delta, 1e-8))
    area := square(x) * (-2.0 * x + 3.0)
    return area * (1.0 - max(math.cos(r1), math.cos(r2)))
}

sphere_directional_occlusion_lookup :: proc(phi: f32, theta: f32, cone_angle: f32) -> f32 {
    return 1.0 - sphere_intersection_area(theta, cone_angle / 2.0, phi) / (1.0 - math.cos(cone_angle / 2.0))
}

sphere_directional_occlusion :: proc(
    pos,
    sphere: rl.Vector3,
    radius: f32,
    cone_dir: rl.Vector3,
    cone_angle: f32,
) -> f32 {
    occluder := sphere - pos
    occluder_len2 := linalg.dot(occluder, occluder)
    occluder_dir := occluder * (1.0 / max(math.sqrt(occluder_len2), 1e-8))
    phi := math.acos(clamp(linalg.dot(occluder_dir, -cone_dir), -1.0, 1.0))
    theta := math.acos(clamp(math.sqrt(occluder_len2 / (square(radius) + occluder_len2)), -1.0, 1.0))
    return sphere_directional_occlusion_lookup(phi, theta, cone_angle)
}