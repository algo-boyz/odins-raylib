package obb

import "core:math"
import "core:math/linalg"
import rl "vendor:raylib"

NUM_VERT :: 8
Vec3 :: rl.Vector3
Mat4 :: rl.Matrix

Collider :: struct {
	vert_loc, vert_glob:  [NUM_VERT]Vec3,
	rotation, translation: Mat4,
}

// All colliders are axis-aligned bounding boxes in local space
new_collider :: proc(min, max: Vec3) -> Collider {
	c: Collider
	c.vert_loc[0] = {min.x, min.y, min.z}
	c.vert_loc[1] = {min.x, min.y, max.z}
	c.vert_loc[2] = {min.x, max.y, min.z}
	c.vert_loc[3] = {min.x, max.y, max.z}
	c.vert_loc[4] = {max.x, min.y, min.z}
	c.vert_loc[5] = {max.x, min.y, max.z}
	c.vert_loc[6] = {max.x, max.y, min.z}
	c.vert_loc[7] = {max.x, max.y, max.z}
	c.rotation    = Mat4(1)
	c.translation = Mat4(1)
	update(&c)
	return c
}

// Overwrites collider rotation matrix
// Updates global vertex positions
set_rotation :: proc(c: ^Collider, axis: Vec3, angle: f32) {
	c.rotation =  rl.MatrixRotate(axis, angle)
	update(c)
}

// Multiplies current collider rotation matrix by new one
// Updates global vertex positions
rotate :: proc(c: ^Collider, axis: Vec3, angle: f32) {
	c.rotation = c.rotation * rl.MatrixRotate(axis, angle)
	update(c)
}

// Overwrites collider translation matrix
// Updates global vertex positions
set_translation :: proc(c: ^Collider, pos: Vec3) {
	c.translation = rl.MatrixTranslate(pos.x, pos.y, pos.z)
	update(c)
}

// Adds new translation matrix to current translation matrix
// Updates global vertex positions
translate :: proc(c: ^Collider, pos: Vec3) {
	c.translation = c.translation * rl.MatrixTranslate(pos.x, pos.y, pos.z)
	update(c)
}

// Returns overall transform, rotation then translation
transform :: proc(col: ^Collider) -> Mat4 {
	return col.rotation * col.translation
}

// First check along each face normal
// Then check along the cross products of the pairs of the face normals
collision_vectors :: proc(a, b: ^Collider, vec: []Vec3) {
	x := Vec3{1.0, 0.0, 0.0}
	y := Vec3{0.0, 1.0, 0.0}
	z := Vec3{0.0, 0.0, 1.0}

	vec[0] = rl.Vector3Transform(x, a.rotation)
	vec[1] = rl.Vector3Transform(y, a.rotation)
	vec[2] = rl.Vector3Transform(z, a.rotation)

	vec[3] = rl.Vector3Transform(x, b.rotation)
	vec[4] = rl.Vector3Transform(y, b.rotation)
	vec[5] = rl.Vector3Transform(z, b.rotation)
	
	i := 6
	for j in 0..<3 {
		for k in 3..<6 {
			if rl.Vector3Equals(vec[j], vec[k]) {
				vec[i] = x
			} else {
				vec[i] = linalg.normalize(linalg.cross(vec[j], vec[k]))
			}
			i += 1
		}
	}
}

// Iterate through all verts, project on test vector, find min and max values
// Returns min and max in x and y members, respectively
proj_bounds :: proc(col: ^Collider, vec: Vec3) -> [2]f32 {
	bounds := [2]f32{}
	proj := linalg.dot(col.vert_glob[0], vec)
	bounds.x = proj
	bounds.y = proj
	
	for i in 1..<NUM_VERT {
		proj = linalg.dot(col.vert_glob[i], vec)
		bounds.x = min(bounds.x, proj)
		bounds.y = max(bounds.y, proj)
	}
	return bounds
}

bounds_overlap :: proc(a, b: [2]f32) -> bool {
	// If the min of one projection is greater than the max of the other
	// then projections do not overlap
	if a.x > b.y do return false
	if b.x > a.y do return false
	return true
}

// Calc amount of overlap along axis being checked
get_overlap :: proc(a, b: [2]f32) -> f32 {
	if a.x > b.y do return 0.0
	if b.x > a.y do return 0.0
	if a.x > b.x do return b.y - a.x
	else do return b.x - a.y
}

collides :: proc(a, b: ^Collider) -> bool {
	test_vec := make([]Vec3, 15, context.temp_allocator)
	
	// First 6 are the surface normals of each collider
	// Last 9 are the cross products of each pair of surface normals
	collision_vectors(a, b, test_vec)
	
	for i in 0..<15 {
		// Get min and max points of the projection
		a_proj := proj_bounds(a, test_vec[i])
		b_proj := proj_bounds(b, test_vec[i])

		if !bounds_overlap(a_proj, b_proj) do return false
	}
	return true
}

collision_correction :: proc(a, b: ^Collider) -> Vec3 {
	overlap_min := f32(100.0)
	overlap_dir := Vec3{0, 0, 0}
	
	vec := make([]Vec3, 15, context.temp_allocator)
	collision_vectors(a, b, vec)
	
	for i in 0..<15 {
		a_proj := proj_bounds(a, vec[i])
		b_proj := proj_bounds(b, vec[i])

		overlap := get_overlap(a_proj, b_proj)
		if overlap == 0.0 do return {0, 0, 0}
		
		if abs(overlap) < abs(overlap_min) {
			overlap_min = overlap
			overlap_dir = vec[i]
		}
	}
	return overlap_dir * overlap_min
}

// Converts matrices to local verts to calculate vertex positions in global space
update :: proc(c: ^Collider) {
	for i in 0..<NUM_VERT {
		c.vert_glob[i] = rl.Vector3Transform(c.vert_loc[i], c.rotation * c.translation)
	}
}