
package mat

import "core:math"
import "core:math/linalg"
import rl "vendor:raylib"

/*
   Index   Mapping (m[row, col])

	m0		m[0,0]
	m1		m[0,1]
	m2		m[0,2]
	m3		m[0,3]
	m4		m[1,0]
	m5		m[1,1]
	m6		m[1,2]
	m7		m[1,3]
	m8		m[2,0]
	m9		m[2,1]
	m10		m[2,2]
	m11		m[2,3]
	m12		m[3,0]
	m13		m[3,1]
	m14		m[3,2]
	m15		m[3,3]
*/

// Extend if necessary for other sizes
directions_row_major :: proc(m: #row_major matrix[4, 4]$F) -> [3][3]F {
	return [3][3]F{
		[3]F{ m[0, 0], m[1, 0], m[2, 0] }, // Right (first row)
		[3]F{ m[0, 1], m[1, 1], m[2, 1] }, // Up (second row)
		[3]F{ m[0, 2], m[1, 2], m[2, 2] }, // Forward (third row)
	};
}

directions_col_major :: proc(m: matrix[4, 4]$F) -> [3][3]F {
	return directions_row_major(cast(#row_major matrix[4, 4]F) m)
}

directions :: proc{
	directions_col_major,
	directions_row_major,
}

// Converts a 3x3 matrix to a 4x4 matrix by adding a row and column for homogeneous coordinates
to_homogeneous :: proc(m: matrix[3, 3]$F) -> matrix[4, 4]F {
	return matrix[4, 4]F{
		m[0, 0], m[1, 0], m[2, 0], 0.0,
		m[0, 1], m[1, 1], m[2, 1], 0.0,
		m[0, 2], m[1, 2], m[2, 2], 0.0,
		0.0,     0.0,     0.0, 1.0
	}
}

// Converts a 4x4 matrix to a 3x3 matrix by removing the last row and column
transpose :: proc(m: matrix[3, 3]$F) -> matrix[3, 3]F {
	return matrix[3, 3]F{
		m[0, 0], m[1, 0], m[2, 0],
		m[0, 1], m[1, 1], m[2, 1],
		m[0, 2], m[1, 2], m[2, 2]
	}
}

// 2D rotation matrix
rotate_2d :: proc(angle_degrees: $F) -> matrix[2, 2]F {
	angle := math.to_radians(angle_degrees)
	sin_a := math.sin(angle)
	cos_a := math.cos(angle)
	return matrix[2, 2]F{
		cos_a, -sin_a,
		sin_a,  cos_a,
	}
}

// 3D rotation around Z axis
rotate_around_z :: proc(angle_degrees: $F) -> matrix[3, 3]F {
	angle := math.to_radians(angle_degrees)
	sin_a := math.sin(angle)
	cos_a := math.cos(angle)
	return matrix[3, 3]F{
		cos_a, -sin_a, 0,
		sin_a,  cos_a, 0,
		0,      0,     1,
	}
}

// 3D rotation around Y axis
rotate_around_y :: proc(angle_degrees: $F) -> matrix[3, 3]F {
	angle := math.to_radians(angle_degrees)
	sin_a := math.sin(angle)
	cos_a := math.cos(angle)
	return matrix[3, 3]F{
		 cos_a, 0, sin_a,
		 0,     1, 0,
		-sin_a, 0, cos_a,
	}
}

// 3D rotation around X axis
rotate_around_x :: proc(angle_degrees: $F) -> matrix[3, 3]F {
	angle := math.to_radians(angle_degrees)
	sin_a := math.sin(angle)
	cos_a := math.cos(angle)
	return matrix[3, 3]F{
		1, 0,      0,
		0, cos_a, -sin_a,
		0, sin_a,  cos_a,
	}
}

// Converts translation values to a translation matrix
// The translation values are expected to be in world units
// Note: The resulting matrix in row-major order can be used to translate 3D objects
to_translation :: proc(x, y, z: $F) -> matrix[4, 4]F {
    return matrix[4, 4]F{
        {1.0,  0.0,  0.0,    x},
        {0.0,  1.0,  0.0,    y},
        {0.0,  0.0,  1.0,    z},
        {0.0,  0.0,  0.0,  1.0}    
    }
}

// Converts scale factors to a scaling matrix
// The scale factors are expected to be in world units
// Note: The resulting matrix in row-major order can be used to scale 3D objects in a scene
//       Scale factors are expected to be positive values
to_scale :: proc(sx, sy, sz: $F) -> matrix[4, 4]F {
    return matrix[4, 4]F{
        {sx,   0.0,  0.0,  0.0},
        {0.0,   sy,  0.0,  0.0},
        {0.0,  0.0,   sz,  0.0},
        {0.0,  0.0,  0.0,  1.0}
    }
}

// Converts pitch, yaw, and roll angles to a rotation matrix
// The angles are expected to be in degrees
// Note: The resulting matrix in row-major order can be used to transform 3D coordinates from
//       world space to view space or to apply rotations on 3D objects in a scene
to_rotation :: proc(pitch, yaw, roll: $F) -> matrix[4, 4]F {
    alpha := yaw * DEG_TO_RAD
    beta  := pitch * DEG_TO_RAD
    gamma := roll * DEG_TO_RAD

    ca := math.cos(alpha)
    sa := math.sin(alpha)

    cb := math.cos(beta)
    sb := math.sin(beta)

    cg := math.cos(gamma)
    sg := math.sin(gamma)

    return matrix[4, 4]F{
        {ca*cb, ca*sb*sg-sa*cg,  ca*sb*cg+sa*sg,  0.0},
        {sa*cb, sa*sb*sg+ca*cg,  sa*sb*cg-ca*sg,  0.0},
        {  -sb,          cb*sg,  cb*cg,           0.0},
        {  0.0,              0.0,  0.0,           1.0}
    }
}

// transforms coordinates from world space to view space
// The resulting matrix is suitable for rendering 3D scenes with a camera
// The eye parameter defines the position of the camera in world space
// The target parameter defines the point in world space that the camera is looking at
// The resulting matrix is in row-major order
// Note: The eye and target parameters are expected to be in world units
//       The resulting matrix is suitable for use with raylib's rl.LoadShader() function or
//       can be used to transform 3D coordinates from world space to view
to_view :: proc(eye, target: [3]$F) -> matrix[4, 4]F {
    forward := rl.Vector3Normalize(eye - target)
    right   := rl.Vector3CrossProduct({0.0, 1.0, 0.0}, forward)
    up      := rl.Vector3CrossProduct(forward, right)

    return matrix[4, 4]F{
        {   right.x,   right.y,   right.z,  -Vector3DotProduct(right, eye)},
        {      up.x,      up.y,      up.z,  -Vector3DotProduct(up, eye)},
        { forward.x, forward.y, forward.z,  -Vector3DotProduct(forward, eye)},
        {       0.0,       0.0,       0.0,   1.0}
    }
}

// transforms coordinates from world space to projection space
// The resulting matrix is suitable for rendering 3D scenes with perspective distortion
// The fov parameter defines the field of view in degrees
// The width and height parameters define the viewport size
// The near and far parameters define the depth range of the projection
// The resulting matrix is in row-major order
// Note: The fov is expected to be in degrees
//       The width and height are expected to be in pixels
//       The near and far parameters are expected to be in world units
//       The resulting matrix is suitable for use with raylib's rl.LoadShader() function
to_projection :: proc(fov, width, height, near, far: $F) -> matrix[4, 4]F {
    f := 1.0 / math.tan_f32(fov * 0.5 * rl.DEG2RAD)
    aspect := width / height

    return matrix[4, 4]F{
        { f / aspect, 0.0,                        0.0,  0.0},
        {        0.0,   f,                        0.0,  0.0},
        {        0.0, 0.0,        -far / (far - near), -1.0},
        {        0.0, 0.0, -far * near / (far - near),  0.0},
    }
}

// transforms coordinates from world space to orthographic projection space
// The resulting matrix is suitable for rendering 2D or 3D scenes without perspective distortion
// The near and far parameters define the depth range of the projection
// The left, right, bottom, and top parameters define the bounds (clip planes) of the orthographic projection
to_orthographic :: proc(left, right, bottom, top, near, far: $F) -> matrix[4, 4]F {
	return matrix[4, 4]F{
	{2.0 / (right - left), 0.0,                  0.0,  -(right + left) / (right - left)},
	{0.0,                  2.0 / (top - bottom), 0.0,  -(top + bottom) / (top - bottom)},
		{0.0,                  0.0,                 -2.0 / (far - near), -(far + near) / (far - near)},
			{0.0,                  0.0,                  0.0,  1.0},
	}
}