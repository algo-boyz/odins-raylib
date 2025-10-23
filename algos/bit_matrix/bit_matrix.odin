package bit_matrix

import "base:intrinsics"
import "core:fmt"
import "core:math/bits"
import "core:math/rand"
import "core:time"
import rl "vendor:raylib"

// Core bit_mat package utilities (your existing code)
BYTES :: Size(1)
KIBI_BYTES :: Size(1024 * BYTES)
MEBI_BYTES :: Size(1024 * KIBI_BYTES)
GIBI_BYTES :: Size(1024 * MEBI_BYTES)

Size :: distinct int

BIT_WIDTH :: 8

Matrix :: struct {
    data: [BIT_WIDTH]u8,
    origins: [BIT_WIDTH][BIT_WIDTH]int, // Track source row of each bit
}

// Core matrix operations
matrix_init :: proc(m: ^Matrix) {
    // Initialize all bits to 1 for visualization
    for i in 0..<BIT_WIDTH {
        m.data[i] = 0xFF
    }
    
    // Initialize origin tracking
    for row in 0..<BIT_WIDTH {
        for col in 0..<BIT_WIDTH {
            m.origins[row][col] = row
        }
    }
}

matrix_copy :: proc(dst: ^Matrix, src: ^Matrix) {
    dst.data = src.data
    dst.origins = src.origins
}

matrix_transpose_step :: proc(m: ^Matrix, swap_width: int) {
    mask := u8(max(u8)) ~ (u8(max(u8)) >> uint(swap_width))
    
    for outer in 0..<BIT_WIDTH/(swap_width*2) {
        for inner in 0..<swap_width {
            row1 := inner + outer*swap_width*2
            row2 := inner + swap_width + outer*swap_width*2
            
            // Store original origins before swap
            orig_origins_row1: [BIT_WIDTH]int
            orig_origins_row2: [BIT_WIDTH]int
            copy(orig_origins_row1[:], m.origins[row1][:])
            copy(orig_origins_row2[:], m.origins[row2][:])
            
            x := &m.data[row1]
            y := &m.data[row2]
            
            // Perform bit swap using XOR
            x^ = ((y^ << uint(swap_width)) & mask) ~ x^
            y^ = ((x^ & mask) >> uint(swap_width)) ~ y^
            x^ = ((y^ << uint(swap_width)) & mask) ~ x^
            
            // Update origin tracking
            for col in 0..<BIT_WIDTH {
                col_group := col / swap_width
                if col_group % 2 == 1 {
                    m.origins[row1][col] = orig_origins_row2[col]
                    m.origins[row2][col] = orig_origins_row1[col]
                } else {
                    m.origins[row1][col] = orig_origins_row1[col]
                    m.origins[row2][col] = orig_origins_row2[col]
                }
            }
        }
    }
}

matrix_print :: proc(m: ^Matrix) {
    for row in 0..<BIT_WIDTH {
        pattern := m.data[row]
        for col in 0..<BIT_WIDTH {
            bit := get_bit(pattern, u8(7 - col))
            fmt.printf("%d ", bit)
        }
        fmt.println()
    }
    fmt.println()
}


// Matrix analysis functions
matrix_hamming_weight :: proc(m: ^Matrix) -> u8 {
    total:u8
    for row in 0..<BIT_WIDTH {
        total += count_ones(m.data[row])
    }
    return total
}

matrix_density :: proc(m: ^Matrix) -> f32 {
    ones := matrix_hamming_weight(m)
    total_bits := BIT_WIDTH * BIT_WIDTH
    return f32(ones) / f32(total_bits)
}

matrix_equals :: proc(a: ^Matrix, b: ^Matrix) -> bool {
    for i in 0..<BIT_WIDTH {
        if a.data[i] != b.data[i] {
            return false
        }
    }
    return true
}

// Matrix manipulation functions
matrix_clear :: proc(m: ^Matrix) {
    for i in 0..<BIT_WIDTH {
        m.data[i] = 0
    }
}

matrix_fill :: proc(m: ^Matrix) {
    for i in 0..<BIT_WIDTH {
        m.data[i] = 0xFF
    }
}

matrix_invert :: proc(m: ^Matrix) {
    for i in 0..<BIT_WIDTH {
        m.data[i] = ~m.data[i]
    }
}

matrix_set_bit :: proc(m: ^Matrix, row, col: int, value: bool) {
    if row >= 0 && row < BIT_WIDTH && col >= 0 && col < BIT_WIDTH {
        bit_pos := u8(7 - col) // MSB is leftmost
        if value {
            m.data[row] = set_bit_one(m.data[row], bit_pos)
        } else {
            m.data[row] = set_bit_zero(m.data[row], bit_pos)
        }
    }
}

matrix_get_bit :: proc(m: ^Matrix, row, col: int) -> bool {
    if row >= 0 && row < BIT_WIDTH && col >= 0 && col < BIT_WIDTH {
        bit_pos := u8(7 - col) // MSB is leftmost
        return get_bit(m.data[row], bit_pos) == 1
    }
    return false
}

matrix_toggle_bit :: proc(m: ^Matrix, row, col: int) {
    current := matrix_get_bit(m, row, col)
    matrix_set_bit(m, row, col, !current)
}

// Pattern generation functions
matrix_set_diagonal :: proc(m: ^Matrix, value: bool) {
    for i in 0..<BIT_WIDTH {
        matrix_set_bit(m, i, i, value)
    }
}

matrix_set_anti_diagonal :: proc(m: ^Matrix, value: bool) {
    for i in 0..<BIT_WIDTH {
        matrix_set_bit(m, i, BIT_WIDTH - 1 - i, value)
    }
}

matrix_set_border :: proc(m: ^Matrix, value: bool) {
    // Top and bottom rows
    for col in 0..<BIT_WIDTH {
        matrix_set_bit(m, 0, col, value)
        matrix_set_bit(m, BIT_WIDTH - 1, col, value)
    }
    // Left and right columns
    for row in 1..<BIT_WIDTH-1 {
        matrix_set_bit(m, row, 0, value)
        matrix_set_bit(m, row, BIT_WIDTH - 1, value)
    }
}

matrix_set_checkerboard :: proc(m: ^Matrix) {
    for row in 0..<BIT_WIDTH {
        for col in 0..<BIT_WIDTH {
            value := (row + col) % 2 == 0
            matrix_set_bit(m, row, col, value)
        }
    }
}

matrix_randomize :: proc(m: ^Matrix, density: f32 = 0.5) {
    matrix_clear(m)
    for row in 0..<BIT_WIDTH {
        for col in 0..<BIT_WIDTH {
            if rand.float32() < density {
                matrix_set_bit(m, row, col, true)
            }
        }
    }
}

// Matrix operations
matrix_and :: proc(result: ^Matrix, a: ^Matrix, b: ^Matrix) {
    for i in 0..<BIT_WIDTH {
        result.data[i] = a.data[i] & b.data[i]
    }
}

matrix_or :: proc(result: ^Matrix, a: ^Matrix, b: ^Matrix) {
    for i in 0..<BIT_WIDTH {
        result.data[i] = a.data[i] | b.data[i]
    }
}

matrix_xor :: proc(result: ^Matrix, a: ^Matrix, b: ^Matrix) {
    for i in 0..<BIT_WIDTH {
        result.data[i] = a.data[i] ~ b.data[i]
    }
}

matrix_rotate_left :: proc(m: ^Matrix, positions: int) {
    positions := positions % BIT_WIDTH
    if positions == 0 do return
    
    temp_data: [BIT_WIDTH]u8
    for i in 0..<BIT_WIDTH {
        new_pos := (i + positions) % BIT_WIDTH
        temp_data[new_pos] = m.data[i]
    }
    m.data = temp_data
}

matrix_rotate_right :: proc(m: ^Matrix, positions: int) {
    positions := positions % BIT_WIDTH
    if positions == 0 do return
    
    temp_data: [BIT_WIDTH]u8
    for i in 0..<BIT_WIDTH {
        new_pos := (i - positions + BIT_WIDTH) % BIT_WIDTH
        temp_data[new_pos] = m.data[i]
    }
    m.data = temp_data
}

matrix_flip_horizontal :: proc(m: ^Matrix) {
    for row in 0..<BIT_WIDTH {
        // Reverse bits in each row
        reversed := u8(0)
        for bit in 0..<8 {
            if get_bit(m.data[row], u8(bit)) == 1 {
                reversed = set_bit_one(reversed, u8(7 - bit))
            }
        }
        m.data[row] = reversed
    }
}

matrix_flip_vertical :: proc(m: ^Matrix) {
    for i in 0..<BIT_WIDTH/2 {
        m.data[i], m.data[BIT_WIDTH - 1 - i] = m.data[BIT_WIDTH - 1 - i], m.data[i]
    }
}

// Validation and debugging
matrix_validate_transpose :: proc(original: ^Matrix, transposed: ^Matrix) -> bool {
    for row in 0..<BIT_WIDTH {
        for col in 0..<BIT_WIDTH {
            orig_bit := matrix_get_bit(original, row, col)
            trans_bit := matrix_get_bit(transposed, col, row)
            if orig_bit != trans_bit {
                return false
            }
        }
    }
    return true
}

matrix_print_binary :: proc(m: ^Matrix) {
    fmt.println("Binary:")
    for row in 0..<BIT_WIDTH {
        fmt.printf("Row %c: %08b\n", 'A' + row, m.data[row])
    }
    fmt.println()
}

matrix_print_hex :: proc(m: ^Matrix) {
    fmt.println("Hex:")
    for row in 0..<BIT_WIDTH {
        fmt.printf("Row %c: 0x%02X\n", 'A' + row, m.data[row])
    }
    fmt.println()
}

matrix_get_row_pattern :: proc(m: ^Matrix, row: int) -> u8 {
    if row >= 0 && row < BIT_WIDTH {
        return m.data[row]
    }
    return 0
}

matrix_set_row_pattern :: proc(m: ^Matrix, row: int, pattern: u8) {
    if row >= 0 && row < BIT_WIDTH {
        m.data[row] = pattern
    }
}

matrix_get_column_pattern :: proc(m: ^Matrix, col: int) -> u8 {
    if col < 0 || col >= BIT_WIDTH do return 0
    result := u8(0)
    bit_pos := u8(7 - col)
    
    for row in 0..<BIT_WIDTH {
        if get_bit(m.data[row], bit_pos) == 1 {
            result = set_bit_one(result, u8(7 - row))
        }
    }
    return result
}

matrix_set_column_pattern :: proc(m: ^Matrix, col: int, pattern: u8) {
    if col < 0 || col >= BIT_WIDTH do return
    
    bit_pos := u8(7 - col)
    for row in 0..<BIT_WIDTH {
        bit_value := get_bit(pattern, u8(7 - row)) == 1
        matrix_set_bit(m, row, col, bit_value)
    }
}

ptr_add :: #force_inline proc "contextless" (ptr: rawptr, offset: int) -> [^]byte {
	return ([^]byte)(uintptr(ptr) + transmute(uintptr)(offset))
}

align_forward :: #force_inline proc(ptr: rawptr, align_power_of_two: int) -> int {
	assert(is_power_of_two(align_power_of_two))
	remainder := (uintptr(ptr)) & transmute(uintptr)(align_power_of_two - 1)
	result := remainder == 0 ? 0 : transmute(uintptr)align_power_of_two - remainder
	return transmute(int)result
}

align_backward :: #force_inline proc(ptr: rawptr, alignment_power_of_two: int) -> int {
	result := uintptr(ptr) & (transmute(uintptr)alignment_power_of_two - 1)
	return transmute(int)result
}

count_leading_zeros :: bits.count_leading_zeros
count_trailing_zeros :: bits.count_trailing_zeros
count_ones :: bits.count_ones
count_zeros :: bits.count_zeros

is_power_of_two :: #force_inline proc "contextless" (x: $T) -> bool where intrinsics.type_is_integer(T) {
	return count_ones(x) == 1
}

low_mask :: #force_inline proc "contextless" (power_of_two: $T) -> T where intrinsics.type_is_unsigned(T) {
	return power_of_two - 1
}

high_mask :: #force_inline proc "contextless" (power_of_two: $T) -> T where intrinsics.type_is_unsigned(T) {
	return ~(power_of_two - 1)
}

get_bit :: #force_inline proc "contextless" (x, bit_index: $T) -> T where intrinsics.type_is_unsigned(T) {
	return (x >> bit_index) & 1
}

set_bit_one :: #force_inline proc "contextless" (x, bit_index: $T) -> T where intrinsics.type_is_unsigned(T) {
	return x | (1 << bit_index)
}

set_bit_zero :: #force_inline proc "contextless" (x, bit_index: $T) -> T where intrinsics.type_is_unsigned(T) {
	return x & ~(1 << bit_index)
}

set_bit :: #force_inline proc "contextless" (x, bit_index, bit_value: $T) -> T where intrinsics.type_is_unsigned(T) {
	x_without_bit := x & ~(1 << bit_index)
	bit := ((bit_value & 1) << bit_index)
	return x | bit
}

bit_swap :: proc(a: ^$T, b: ^T) {
    a^ ^= b^
    b^ ^= a^
    a^ ^= b^
}

log2_floor :: #force_inline proc "contextless" (x: $T) -> T where intrinsics.type_is_unsigned(T) {
	return x > 0 ? size_of(T) * 8 - 1 - count_leading_zeros(x) : 0
}

log2_ceil :: #force_inline proc "contextless" (x: $T) -> T where intrinsics.type_is_unsigned(T) {
	return x > 1 ? size_of(T) * 8 - 1 - count_leading_zeros((x - 1) << 1) : 0
}
