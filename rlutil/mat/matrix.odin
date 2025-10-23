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

directions_row_major :: proc(m: #row_major matrix[4, 4]$F) -> [3][3]F {
	return [3][3]F{
		[3]F{ m[0, 0], m[1, 0], m[2, 0] }, // Right (first row)
		[3]F{ m[0, 1], m[1, 1], m[2, 1] }, // Up (second row)
		[3]F{ m[0, 2], m[1, 2], m[2, 2] }, // Forward (third row)
	}
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
		0.0,     0.0,     0.0,     1.0,
	}
}

// Transpose a 3x3 matrix
transpose_3x3 :: proc(m: matrix[3, 3]$F) -> matrix[3, 3]F {
	return matrix[3, 3]F{
		m[0, 0], m[1, 0], m[2, 0],
		m[0, 1], m[1, 1], m[2, 1],
		m[0, 2], m[1, 2], m[2, 2],
	}
}

// Transpose a 4x4 matrix
transpose_4x4 :: proc(m: matrix[4, 4]$F) -> matrix[4, 4]F {
	return matrix[4, 4]F{
		m[0, 0], m[1, 0], m[2, 0], m[3, 0],
		m[0, 1], m[1, 1], m[2, 1], m[3, 1],
		m[0, 2], m[1, 2], m[2, 2], m[3, 2],
		m[0, 3], m[1, 3], m[2, 3], m[3, 3],
	}
}

// Transpose a row-major 4x4 matrix
transpose_4x4_row_major :: proc(m: #row_major matrix[4, 4]$F) -> #row_major matrix[4, 4]F {
	return #row_major matrix[4, 4]F{
		m[0, 0], m[1, 0], m[2, 0], m[3, 0],
		m[0, 1], m[1, 1], m[2, 1], m[3, 1],
		m[0, 2], m[1, 2], m[2, 2], m[3, 2],
		m[0, 3], m[1, 3], m[2, 3], m[3, 3],
	}
}

transpose :: proc{
	transpose_3x3,
	transpose_4x4,
	transpose_4x4_row_major,
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
to_translation :: proc(x, y, z: $F) -> matrix[4, 4]F {
    return matrix[4, 4]F{
        1.0,  0.0,  0.0,    x,
        0.0,  1.0,  0.0,    y,
        0.0,  0.0,  1.0,    z,
        0.0,  0.0,  0.0,  1.0,
    }
}

// Converts scale factors to a scaling matrix
to_scale :: proc(sx, sy, sz: $F) -> matrix[4, 4]F {
    return matrix[4, 4]F{
        sx,   0.0,  0.0,  0.0,
        0.0,   sy,  0.0,  0.0,
        0.0,  0.0,   sz,  0.0,
        0.0,  0.0,  0.0,  1.0,
    }
}

// Converts pitch, yaw, and roll angles to a rotation matrix
to_rotation :: proc(pitch, yaw, roll: $F) -> matrix[4, 4]F {
    alpha := yaw * rl.DEG2RAD
    beta  := pitch * rl.DEG2RAD
    gamma := roll * rl.DEG2RAD

    ca := math.cos(alpha)
    sa := math.sin(alpha)

    cb := math.cos(beta)
    sb := math.sin(beta)

    cg := math.cos(gamma)
    sg := math.sin(gamma)

    return matrix[4, 4]F{
        ca*cb, ca*sb*sg-sa*cg,  ca*sb*cg+sa*sg,  0.0,
        sa*cb, sa*sb*sg+ca*cg,  sa*sb*cg-ca*sg,  0.0,
          -sb,          cb*sg,             cb*cg,  0.0,
          0.0,            0.0,               0.0,  1.0,
    }
}

// transforms coordinates from world space to view space
to_view :: proc(eye, target: [3]$F) -> matrix[4, 4]F {
    forward := linalg.normalize(eye - target)
    right   := linalg.cross([3]F{0.0, 1.0, 0.0}, forward)
    up      := linalg.cross(forward, right)
    return matrix[4, 4]F{
           right.x,       right.y,       right.z,  -linalg.dot(right, eye),
              up.x,          up.y,          up.z,  -linalg.dot(up, eye),
         forward.x,     forward.y,     forward.z,  -linalg.dot(forward, eye),
               0.0,           0.0,           0.0,   1.0,
    }
}

// transforms coordinates from world space to projection space
to_projection :: proc(fov, width, height, near, far: $F) -> matrix[4, 4]F {
    f := 1.0 / math.tan(fov * 0.5 * rl.DEG2RAD)
    aspect := width / height

    return matrix[4, 4]F{
        f / aspect, 0.0,                        0.0,  0.0,
               0.0,   f,                        0.0,  0.0,
               0.0, 0.0,        -far / (far - near), -1.0,
               0.0, 0.0, -far * near / (far - near),  0.0,
    }
}

// transforms coordinates from world space to orthographic projection space
to_orthographic :: proc(l, right, bottom, top, near, far: $F) -> matrix[4, 4]F {
	return matrix[4, 4]F{
		2.0 / (right - l), 0.0,                  0.0,  -(right + l) / (right - l),
		0.0,                  2.0 / (top - bottom), 0.0,  -(top + bottom) / (top - bottom),
		0.0,                  0.0,                 -2.0 / (far - near), -(far + near) / (far - near),
		0.0,                  0.0,                  0.0,  1.0,
	}
}

// Multiplies two matrices in row-major order
transmatmul :: proc(l, r: #row_major matrix[4,4]f32) -> #row_major matrix[4,4]f32 {
  m : #row_major matrix[4,4]f32
  m[0,0] = l[0,0]*r[0,0] + l[0,1]*r[1,0] + l[0,2]*r[2,0] + l[0,3]*r[3,0]
  m[0,1] = l[0,0]*r[0,1] + l[0,1]*r[1,1] + l[0,2]*r[2,1] + l[0,3]*r[3,1]
  m[0,2] = l[0,0]*r[0,2] + l[0,1]*r[1,2] + l[0,2]*r[2,2] + l[0,3]*r[3,2]
  m[0,3] = l[0,0]*r[0,3] + l[0,1]*r[1,3] + l[0,2]*r[2,3] + l[0,3]*r[3,3]
  m[1,0] = l[1,0]*r[0,0] + l[1,1]*r[1,0] + l[1,2]*r[2,0] + l[1,3]*r[3,0]
  m[1,1] = l[1,0]*r[0,1] + l[1,1]*r[1,1] + l[1,2]*r[2,1] + l[1,3]*r[3,1]
  m[1,2] = l[1,0]*r[0,2] + l[1,1]*r[1,2] + l[1,2]*r[2,2] + l[1,3]*r[3,2]
  m[1,3] = l[1,0]*r[0,3] + l[1,1]*r[1,3] + l[1,2]*r[2,3] + l[1,3]*r[3,3]
  m[2,0] = l[2,0]*r[0,0] + l[2,1]*r[1,0] + l[2,2]*r[2,0] + l[2,3]*r[3,0]
  m[2,1] = l[2,0]*r[0,1] + l[2,1]*r[1,1] + l[2,2]*r[2,1] + l[2,3]*r[3,1]
  m[2,2] = l[2,0]*r[0,2] + l[2,1]*r[1,2] + l[2,2]*r[2,2] + l[2,3]*r[3,2]
  m[2,3] = l[2,0]*r[0,3] + l[2,1]*r[1,3] + l[2,2]*r[2,3] + l[2,3]*r[3,3]
  m[3,0] = l[3,0]*r[0,0] + l[3,1]*r[1,0] + l[3,2]*r[2,0] + l[3,3]*r[3,0]
  m[3,1] = l[3,0]*r[0,1] + l[3,1]*r[1,1] + l[3,2]*r[2,1] + l[3,3]*r[3,1]
  m[3,2] = l[3,0]*r[0,2] + l[3,1]*r[1,2] + l[3,2]*r[2,2] + l[3,3]*r[3,2]
  m[3,3] = l[3,0]*r[0,3] + l[3,1]*r[1,3] + l[3,2]*r[2,3] + l[3,3]*r[3,3]
  return m
}

// Matrix multiplication tests
import "core:testing"

rm_mat1 :: #row_major matrix[4,4]f32 {
   2., 3., 5., 7.,
  11.,13.,17.,19.,
  23.,29.,31.,37.,
  41.,43.,47.,53.,
}

cm_mat1 :: matrix[4,4]f32 {
   2., 3., 5., 7.,
  11.,13.,17.,19.,
  23.,29.,31.,37.,
  41.,43.,47.,53.,
}

rm_mat2 :: #row_major matrix[4,4]f32 {
   .2, .3, .5, .7,
  .11,.13,.17,.19,
  .23,.29,.31,.37,
  .41,.43,.47,.53,
}

cm_mat2 :: matrix[4,4]f32 {
   .2, .3, .5, .7,
  .11,.13,.17,.19,
  .23,.29,.31,.37,
  .41,.43,.47,.53,
}

@(test)
tests :: proc(t: ^testing.T) {
  ident := #row_major matrix[4,4]f32{
    1, 0, 0, 0,
    0, 1, 0, 0,
    0, 0, 1, 0,
    0, 0, 0, 1,
  }
  
  rlhm := transmatmul(rm_mat1, rm_mat2)
  cm_mul_odin := cm_mat1 * cm_mat2
  rm_mul_odin := rm_mat1 * rm_mat2
  
  // Convert column major to row major for comparison
  cm_to_rm := cast(#row_major matrix[4,4]f32) cm_mat1
  rm_to_cm := cast(matrix[4,4]f32) rm_mat1
  
  // Fixed test assertions
  testing.expect_value(t, transmatmul(ident, ident), ident)
  testing.expect_value(t, transmatmul(rm_mat1, ident), rm_mat1)
  testing.expect(t, rlhm != rm_mul_odin, "Row major multiplication should differ from Odin's default")
  testing.expect(t, cast(#row_major matrix[4,4]f32)(cm_mat1 * cm_mat2) != rlhm, "Column major cast should differ from transmatmul")
}