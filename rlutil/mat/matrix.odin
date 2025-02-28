
package mat

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
	return {
		{ m[0, 0], m[1, 0], m[2, 0] }, // Right (first row)
		{ m[0, 1], m[1, 1], m[2, 1] }, // Up (second row)
		{ m[0, 2], m[1, 2], m[2, 2] }, // Forward (third row)
	}
}

directions_col_major :: proc(m: matrix[4, 4]$F) -> [3][3]F {
	return directions_row_major(cast(#row_major matrix[4, 4]F) m)
}

directions :: proc{
	directions_col_major,
	directions_row_major,
}