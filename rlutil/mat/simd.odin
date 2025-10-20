package mat

import "core:fmt"
import "core:simd"

// Ref:
// https://github.com/flame/how-to-optimize-gemm
// https://github.com/pytorch/glow/blob/405e632ef138f1d49db9c3181182f7efd837bccc/lib/Backends/CPU/libjit/libjit_matmul.cpp
// https://github.com/pytorch/glow/blob/405e632ef138f1d49db9c3181182f7efd837bccc/lib/Backends/CPU/libjit/libjit_defs.h

new_slice_2D :: proc(y, x: int, $T: typeid, allocator := context.allocator) -> (res: [][]T) {
	assert(x > 0 && y > 0)
	context.allocator = allocator

	backing := make([]T, x * y)
	res = make([][]T, y)

	for i in 0 ..< y {
		res[i] = backing[x * i:][:x]
	}
	return
}

delete_slice_2D :: proc(slice: [][]$T, allocator := context.allocator) {
	delete(slice[0], allocator)
	delete(slice, allocator)
}

// Naive gemm to handle oddly-sized matrices.
matmul_odd :: proc(a, b, c: [][]f32) {
	for i in 0 ..< len(a) {
		for j in 0 ..< len(b[0]) {
			for k in 0 ..< len(b) {
				c[i][j] += a[i][k] * b[k][j]
			}
		}
	}
}

// Improved version using direct memory operations instead of from_slice/to_array
add_u_f32x8 :: #force_inline proc(p: []f32, v: simd.f32x8) {
	// Direct memory load, add, and store - much faster than from_slice/to_array
	existing := (^simd.f32x8)(raw_data(p))^
	result := existing + v
	(^simd.f32x8)(raw_data(p))^ = result
}

// Compute a 4x16 block of C using a vectorized dot product. from slices a: 4x16, b: 16x16
matmul_dot4x16 :: proc(a, b, c: [][]f32, a_col: int = 0) {
	ctmp07 := [cth]simd.f32x8{}
	ctmp815 := [cth]simd.f32x8{}
	
	for p in 0 ..< bth {
		// Load a values once and broadcast efficiently
		a_vals := [4]f32{a[0][a_col + p], a[1][a_col + p], a[2][a_col + p], a[3][a_col + p]}
		a0p := simd.f32x8{a_vals[0], a_vals[0], a_vals[0], a_vals[0], a_vals[0], a_vals[0], a_vals[0], a_vals[0]}
		a1p := simd.f32x8{a_vals[1], a_vals[1], a_vals[1], a_vals[1], a_vals[1], a_vals[1], a_vals[1], a_vals[1]}
		a2p := simd.f32x8{a_vals[2], a_vals[2], a_vals[2], a_vals[2], a_vals[2], a_vals[2], a_vals[2], a_vals[2]}
		a3p := simd.f32x8{a_vals[3], a_vals[3], a_vals[3], a_vals[3], a_vals[3], a_vals[3], a_vals[3], a_vals[3]}
		
		// Direct memory loads for b vectors
		bp0p7 := (^simd.f32x8)(raw_data(b[p][:8]))^
		bp8p15 := (^simd.f32x8)(raw_data(b[p][8:]))^
		
		ctmp07[0] = simd.fma(a0p, bp0p7, ctmp07[0])
		ctmp07[1] = simd.fma(a1p, bp0p7, ctmp07[1])
		ctmp07[2] = simd.fma(a2p, bp0p7, ctmp07[2])
		ctmp07[3] = simd.fma(a3p, bp0p7, ctmp07[3])
		ctmp815[0] = simd.fma(a0p, bp8p15, ctmp815[0])
		ctmp815[1] = simd.fma(a1p, bp8p15, ctmp815[1])
		ctmp815[2] = simd.fma(a2p, bp8p15, ctmp815[2])
		ctmp815[3] = simd.fma(a3p, bp8p15, ctmp815[3])
	}
	
	// Store results directly
	add_u_f32x8(c[0][:8], ctmp07[0])
	add_u_f32x8(c[1][:8], ctmp07[1])
	add_u_f32x8(c[2][:8], ctmp07[2])
	add_u_f32x8(c[3][:8], ctmp07[3])
	add_u_f32x8(c[0][8:], ctmp815[0])
	add_u_f32x8(c[1][8:], ctmp815[1])
	add_u_f32x8(c[2][8:], ctmp815[2])
	add_u_f32x8(c[3][8:], ctmp815[3])
}

// a is a slice a[row:row+4] e.g. 4 rows all columns
// a_packed is a slice of contiguous memory the same size as passed the slice of a
pack_mat_a :: proc(a, a_packed: [][]f32) {
	// Use bulk memory copy for better performance
	for i in 0 ..< len(a) {
		copy(a_packed[i], a[i])
	}
}

// col is the starting column to pack from b
// b_packed is len(b) x btw 
// Pre-packed b matrix for better cache performance
pack_mat_b :: proc(col: int, b, b_packed: [][]f32) {
	for r, i in b {
		end_col := min(col + btw, len(r))
		copy(b_packed[i][:end_col-col], r[col:end_col])
		// Zero out remaining elements if needed
		if end_col - col < btw {
			for j in end_col-col ..< btw {
				b_packed[i][j] = 0
			}
		}
	}
}

pack_mat_c :: proc(col_c: int, c, c_packed: [][]f32) {
	for r, i in c {
		end_col := min(col_c + ctw, len(r))
		copy(c_packed[i][:end_col-col_c], r[col_c:end_col])
		// Zero out remaining elements if needed
		if end_col - col_c < ctw {
			for j in end_col-col_c ..< ctw {
				c_packed[i][j] = 0
			}
		}
	}
}

unpack_mat_c :: proc(col_c: int, c, c_packed: [][]f32) {
	for r, i in c {
		end_col := min(col_c + ctw, len(r))
		copy(r[col_c:end_col], c_packed[i][:end_col-col_c])
	}
}

// loops over tiles of the packed a and b to make a complete tile of c
matmul_inner :: proc(a_packed, b_packed, c_packed: [][]f32) {
	for i in 0 ..< len(b_packed) / bth {
		j := i * bth
		matmul_dot4x16(a_packed, b_packed[j:j + bth], c_packed, j)
	}
}

mc :: 256
kc :: 128
nb :: 1000

ath :: 4 // a tile height
bth :: 16 // b tile height
btw :: 16 // b tile width
atw :: bth
// c tiles are ofc 4x16
cth :: ath
ctw :: btw

matmul :: proc(a, b, c: [][]f32) {
	assert(len(c) == len(a) && len(b[0]) == len(c[0]))
	
	// Handle edge cases with naive multiplication
	if len(a) < ath || len(b[0]) < ctw || len(b) < bth {
		matmul_odd(a, b, c)
		return
	}
	
	a_packed := new_slice_2D(ath, len(b), f32)
	defer delete_slice_2D(a_packed)
	
	b_packed := new_slice_2D(len(b), btw, f32)
	defer delete_slice_2D(b_packed)
	
	c_packed := new_slice_2D(cth, ctw, f32)
	defer delete_slice_2D(c_packed)
	
	// Iterate over column blocks of C
	for j := 0; j < len(c[0]); j += ctw {
		// Pack the current column block of B
		pack_mat_b(j, b, b_packed)
		
		// Iterate over row blocks of C  
		for i := 0; i < len(c); i += cth {
			// Handle partial blocks at edges
			actual_rows := min(cth, len(c) - i)
			actual_cols := min(ctw, len(c[0]) - j)
			
			if actual_rows == cth && actual_cols == ctw {
				// Full block - use optimized path
				pack_mat_a(a[i:i + ath], a_packed)
				pack_mat_c(j, c[i:i + cth], c_packed)
				matmul_inner(a_packed, b_packed, c_packed)
				unpack_mat_c(j, c[i:i + cth], c_packed)
			} else {
				// Partial block - use naive multiplication
				for ii in i ..< min(i + actual_rows, len(c)) {
					for jj in j ..< min(j + actual_cols, len(c[0])) {
						for k in 0 ..< len(b) {
							c[ii][jj] += a[ii][k] * b[k][jj]
						}
					}
				}
			}
		}
	}
}