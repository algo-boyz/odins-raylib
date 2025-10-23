package mat

import "core:fmt"
import "core:math/rand"
import "core:time"
import "core:testing"

init_test_matrices :: proc(a, b, c: [][]f32, pattern: string = "sequential") {
	switch pattern {
	case "sequential":
		// Fill with sequential numbers for predictable results
		val := f32(1.0)
		for i in 0 ..< len(a) {
			for j in 0 ..< len(a[0]) {
				a[i][j] = val
				val += 1.0
			}
		}
		val = 1.0
		for i in 0 ..< len(b) {
			for j in 0 ..< len(b[0]) {
				b[i][j] = val
				val += 1.0
			}
		}
	case "identity":
		// A as identity-like, B as sequential
		for i in 0 ..< len(a) {
			for j in 0 ..< len(a[0]) {
				a[i][j] = f32(i == j ? 1.0 : 0.0)
			}
		}
		val := f32(1.0)
		for i in 0 ..< len(b) {
			for j in 0 ..< len(b[0]) {
				b[i][j] = val
				val += 1.0
			}
		}
	case "random":
		for i in 0 ..< len(a) {
			for j in 0 ..< len(a[0]) {
				a[i][j] = rand.float32_range(0.0, 10.0)
			}
		}
		for i in 0 ..< len(b) {
			for j in 0 ..< len(b[0]) {
				b[i][j] = rand.float32_range(0.0, 10.0)
			}
		}
	}
	// Always zero out C
	for i in 0 ..< len(c) {
		for j in 0 ..< len(c[0]) {
			c[i][j] = 0.0
		}
	}
}

// Reference implementation
matmul_reference :: proc(a, b, c: [][]f32) {
	for i in 0 ..< len(c) {
		for j in 0 ..< len(c[0]) {
			c[i][j] = 0.0
			for k in 0 ..< len(b) {
				c[i][j] += a[i][k] * b[k][j]
			}
		}
	}
}

// Cmp two matrices with tolerance for floating point err
matrices_equal :: proc(a, b: [][]f32, tolerance: f32 = 1e-5) -> bool {
	if len(a) != len(b) || len(a[0]) != len(b[0]) {
		return false
	}
	for i in 0 ..< len(a) {
		for j in 0 ..< len(a[0]) {
			diff := abs(a[i][j] - b[i][j])
			if diff > tolerance {
				fmt.printf("Mismatch at [%d][%d]: %f vs %f (diff: %f)\n", 
						  i, j, a[i][j], b[i][j], diff)
				return false
			}
		}
	}
	return true
}

@(test)
test_matmul_dot4x16 :: proc(t: ^testing.T) {
	// Test case 1: 4x16 * 16x16 = 4x16
	a := new_slice_2D(4, 16, f32)
	b := new_slice_2D(16, 16, f32)
	c_opt := new_slice_2D(4, 16, f32)
	c_ref := new_slice_2D(4, 16, f32)
	defer delete_slice_2D(a)
	defer delete_slice_2D(b)
	defer delete_slice_2D(c_opt)
	defer delete_slice_2D(c_ref)
	
	init_test_matrices(a, b, c_opt, "sequential")
	init_test_matrices(a, b, c_ref, "sequential")

	matmul_dot4x16(a, b, c_opt)
	matmul_reference(a, b, c_ref)
	
	testing.expect(t, matrices_equal(c_opt, c_ref), "matmul_dot4x16 results should match reference implementation")
}

@(test)
test_matmul_sizes :: proc(t: ^testing.T) {
	test_sizes := []struct{m, k, n: int}{
		{4, 16, 16},     // Exact tile size
		{8, 32, 32},     // Multiple of tile size
		{5, 17, 13},     // Odd sizes (should use fallback)
		{100, 50, 75},   // Larger mixed sizes
		{256, 128, 256}, // Even larger
	}
	for size, idx in test_sizes {
		a := new_slice_2D(size.m, size.k, f32)
		b := new_slice_2D(size.k, size.n, f32)
		c_opt := new_slice_2D(size.m, size.n, f32)
		c_ref := new_slice_2D(size.m, size.n, f32)
		defer delete_slice_2D(a)
		defer delete_slice_2D(b)
		defer delete_slice_2D(c_opt)
		defer delete_slice_2D(c_ref)
		
		init_test_matrices(a, b, c_opt, "random")
		init_test_matrices(a, b, c_ref, "random")
		
		matmul(a, b, c_opt)
		matmul_reference(a, b, c_ref)
		
		testing.expect(t, matrices_equal(c_opt, c_ref, 1e-3), fmt.aprintf("matmul failed for size %dx%d * %dx%d", 
					   size.m, size.k, size.k, size.n))
	}
}

@(test)
test_matmul_dimensions :: proc(t: ^testing.T) {
	a := new_slice_2D(3, 4, f32)
	b := new_slice_2D(4, 5, f32)
	c := new_slice_2D(3, 5, f32)
	defer delete_slice_2D(a)
	defer delete_slice_2D(b)
	defer delete_slice_2D(c)
	
	init_test_matrices(a, b, c, "sequential")
	
	testing.expect(t, len(a) == 3, "matrix A should have 3 rows")
	testing.expect(t, len(a[0]) == 4, "matrix A should have 4 columns")
	testing.expect(t, len(b) == 4, "matrix B should have 4 rows")
	testing.expect(t, len(b[0]) == 5, "matrix B should have 5 columns")
	testing.expect(t, len(c) == 3, "result matrix C should have 3 rows")
	testing.expect(t, len(c[0]) == 5, "result matrix C should have 5 columns")
	
	testing.expect(t, len(a[0]) == len(b), "matrix A columns should match matrix B rows for valid multiplication")
}

@(test)
test_identity_multiplication :: proc(t: ^testing.T) {
	size := 8
	a := new_slice_2D(size, size, f32)
	identity := new_slice_2D(size, size, f32)
	result := new_slice_2D(size, size, f32)
	defer delete_slice_2D(a)
	defer delete_slice_2D(identity)
	defer delete_slice_2D(result)
	
	// Fill A with sequential values
	val := f32(1.0)
	for i in 0 ..< size {
		for j in 0 ..< size {
			a[i][j] = val
			val += 1.0
		}
	}
	// Create identity matrix
	for i in 0 ..< size {
		for j in 0 ..< size {
			identity[i][j] = f32(i == j ? 1.0 : 0.0)
		}
	}
	// Zero result matrix
	for i in 0 ..< size {
		for j in 0 ..< size {
			result[i][j] = 0.0
		}
	}
	// Multiply A * I should equal A
	matmul(a, identity, result)
	testing.expect(t, matrices_equal(a, result), "multiplying by identity matrix should preserve original matrix")
}

@(test)
test_zero_multiplication :: proc(t: ^testing.T) {
	size := 4
	a := new_slice_2D(size, size, f32)
	zero := new_slice_2D(size, size, f32)
	result := new_slice_2D(size, size, f32)
	expected_zero := new_slice_2D(size, size, f32)
	defer delete_slice_2D(a)
	defer delete_slice_2D(zero)
	defer delete_slice_2D(result)
	defer delete_slice_2D(expected_zero)
	
	// Fill A with random values
	init_test_matrices(a, zero, result, "random")
	
	// Zero matrix is already initialized to zeros by init_test_matrices
	// Expected result should also be zeros
	for i in 0 ..< size {
		for j in 0 ..< size {
			zero[i][j] = 0.0
			expected_zero[i][j] = 0.0
		}
	}
	// Multiply A * 0 should equal 0
	matmul(a, zero, result)
	testing.expect(t, matrices_equal(result, expected_zero), "multiplying by zero matrix should result in zero matrix")
}

@(test)
test_small_matrix_manual :: proc(t: ^testing.T) {
	// 2x2 matrices for easy manual verification
	a := new_slice_2D(2, 2, f32)
	b := new_slice_2D(2, 2, f32)
	result := new_slice_2D(2, 2, f32)
	expected := new_slice_2D(2, 2, f32)
	defer delete_slice_2D(a)
	defer delete_slice_2D(b)
	defer delete_slice_2D(result)
	defer delete_slice_2D(expected)
	
	// A = [[1, 2], [3, 4]]
	a[0][0], a[0][1] = 1.0, 2.0
	a[1][0], a[1][1] = 3.0, 4.0
	
	// B = [[5, 6], [7, 8]]
	b[0][0], b[0][1] = 5.0, 6.0
	b[1][0], b[1][1] = 7.0, 8.0
	
	// Expected result: [[19, 22], [43, 50]]
	expected[0][0], expected[0][1] = 19.0, 22.0
	expected[1][0], expected[1][1] = 43.0, 50.0
	
	// Zero result matrix
	for i in 0 ..< 2 {
		for j in 0 ..< 2 {
			result[i][j] = 0.0
		}
	}
	matmul(a, b, result)

	testing.expect(t, matrices_equal(result, expected), "2x2 matrix multiplication should produce expected manual result")
	testing.expect(t, abs(result[0][0] - 19.0) < 1e-5, "result[0][0] should be 19")
	testing.expect(t, abs(result[0][1] - 22.0) < 1e-5, "result[0][1] should be 22")
	testing.expect(t, abs(result[1][0] - 43.0) < 1e-5, "result[1][0] should be 43")
	testing.expect(t, abs(result[1][1] - 50.0) < 1e-5, "result[1][1] should be 50")
}

benchmark_matmul :: proc(size: int, iterations: int = 5) -> time.Duration {
	fmt.printf("Benchmarking %dx%d matrix multiplication (%d iterations)...\n", size, size, iterations)
	
	a := new_slice_2D(size, size, f32)
	b := new_slice_2D(size, size, f32)
	c := new_slice_2D(size, size, f32)
	defer delete_slice_2D(a)
	defer delete_slice_2D(b)
	defer delete_slice_2D(c)
	
	// Fill with random data once
	init_test_matrices(a, b, c, "random")
	
	total_time := time.Duration(0)
	
	for i in 0 ..< iterations {
		// Reset C matrix
		for row in c {
			for j in 0 ..< len(row) {
				row[j] = 0.0
			}
		}
		start := time.now()
		matmul(a, b, c)
		elapsed := time.since(start)
		total_time += elapsed
		fmt.printf("  Iteration %d: %v\n", i+1, elapsed)
	}
	avg_time := total_time / time.Duration(iterations)
	fmt.printf("Average time: %v\n", avg_time)
	// Calculate GFLOPS
	ops := f64(size) * f64(size) * f64(size) * 2.0 // 2 ops per multiply-add
	gflops := ops / f64(time.duration_nanoseconds(avg_time)) 
	fmt.printf("Performance: %.2f GFLOPS\n\n", gflops)
	
	return avg_time
}

// Compare optimized vs reference performance (not a test)
benchmark_comparison :: proc() {
	fmt.println("=== Performance Comparison ===")
	
	size := 512
	iterations := 3
	
	a := new_slice_2D(size, size, f32)
	b := new_slice_2D(size, size, f32)
	c_opt := new_slice_2D(size, size, f32)
	c_ref := new_slice_2D(size, size, f32)
	defer delete_slice_2D(a)
	defer delete_slice_2D(b)
	defer delete_slice_2D(c_opt)
	defer delete_slice_2D(c_ref)
	
	init_test_matrices(a, b, c_opt, "random")
	
	fmt.printf("Optimized matmul (%dx%d, %d iterations):\n", size, size, iterations)
	opt_total := time.Duration(0)
	for i in 0 ..< iterations {
		for row in c_opt {
			for j in 0 ..< len(row) {
				row[j] = 0.0
			}
		}
		start := time.now()
		matmul(a, b, c_opt)
		elapsed := time.since(start)
		opt_total += elapsed
		fmt.printf("  Run %d: %v\n", i+1, elapsed)
	}
	opt_avg := opt_total / time.Duration(iterations)
	
	fmt.printf("\nReference matmul (%dx%d, %d iterations):\n", size, size, iterations)
	ref_total := time.Duration(0)
	for i in 0 ..< iterations {
		for row in c_ref {
			for j in 0 ..< len(row) {
				row[j] = 0.0
			}
		}
		start := time.now()
		matmul_reference(a, b, c_ref)
		elapsed := time.since(start)
		ref_total += elapsed
		fmt.printf("  Run %d: %v\n", i+1, elapsed)
	}
	ref_avg := ref_total / time.Duration(iterations)
	
	speedup := f64(time.duration_nanoseconds(ref_avg)) / f64(time.duration_nanoseconds(opt_avg))
	fmt.printf("\nResults:\n")
	fmt.printf("Optimized average: %v\n", opt_avg)
	fmt.printf("Reference average: %v\n", ref_avg)
	fmt.printf("Speedup: %.2fx\n", speedup)
	if matrices_equal(c_opt, c_ref, 1e-3) {
		fmt.println("✓ Results are numerically equivalent")
	} else {
		fmt.println("❌ Results differ - there may be a bug!")
	}
}

@(test)
main :: proc() {
	fmt.println("Benchmarks MatMul")
	benchmark_matmul(64)
	benchmark_matmul(128) 
	benchmark_matmul(256)
	benchmark_matmul(512)
	benchmark_matmul(1024)
	// Performance comparison
	benchmark_comparison()
}