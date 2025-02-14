
package mat

// Extend if necessary for other sizes
directions_row_major :: proc(m: #row_major matrix[4, 4]$F) -> [3][3]F {
	return {
		{ m[0, 0], m[1, 0], m[2, 0] },
		{ m[0, 1], m[1, 1], m[2, 1] },
		{ m[0, 2], m[1, 2], m[2, 2] },
	}
}

directions_col_major :: proc(m: matrix[4, 4]$F) -> [3][3]F {
	return directions_row_major(cast(#row_major matrix[4, 4]F) m)
}

directions :: proc{
	directions_col_major,
	directions_row_major,
}