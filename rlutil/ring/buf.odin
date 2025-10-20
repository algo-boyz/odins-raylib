package ring

import "core:fmt"
import "core:testing"

Ring_Buffer :: struct($N: u64, $T: typeid) {
	write_idx: u64,  // Where to write next
	read_idx: u64,   // Where to read next
	len: u64,        // Current number of elements
	data: [N]T,
}

append :: push_back
push   :: push_back
// Core operations - using consistent naming and behavior
push_back :: proc(b: ^Ring_Buffer($N, $T), item: T) {
	b.data[b.write_idx] = item
	b.write_idx = (b.write_idx + 1) % N
	
	if b.len < N {
		b.len += 1
	} else {
		// Buffer is full, advance read pointer to maintain FIFO behavior
		b.read_idx = (b.read_idx + 1) % N
	}
	when ODIN_DEBUG {
		fmt.printf("Added %v, buffer: ", item)
		for i in 0..<N {
			if i < b.len {
				fmt.printf("%v ", b.data[(b.read_idx + i) % N])
			} else {
				fmt.printf("_ ")
			}
		}
		fmt.println()
	}
}

push_front :: proc(b: ^Ring_Buffer($N, $T), item: T) {
	// Move read pointer backward
	b.read_idx = (b.read_idx - 1 + N) % N
	b.data[b.read_idx] = item
	
	if b.len < N {
		b.len += 1
	} else {
		// Buffer is full, move write pointer backward
		b.write_idx = (b.write_idx - 1 + N) % N
	}
}

pop_front :: proc(b: ^Ring_Buffer($N, $T)) -> (value: T, ok: bool) {
	if b.len == 0 {
		return {}, false
	}
	value = b.data[b.read_idx]
	b.read_idx = (b.read_idx + 1) % N
	b.len -= 1
	
	return value, true
}

pop    :: pop_back

pop_back :: proc(b: ^Ring_Buffer($N, $T)) -> (value: T, ok: bool) {
	if b.len == 0 {
		return {}, false
	}
	// Move write pointer backward to get last written item
	b.write_idx = (b.write_idx - 1 + N) % N
	value = b.data[b.write_idx]
	b.len -= 1
	
	return value, true
}

// Peek operations
peek_front :: proc(b: Ring_Buffer($N, $T)) -> (value: T, ok: bool) {
	if b.len == 0 {
		return {}, false
	}
	return b.data[b.read_idx], true
}

peek_back :: proc(b: Ring_Buffer($N, $T)) -> (value: T, ok: bool) {
	if b.len == 0 {
		return {}, false
	}
	last_idx := (b.write_idx - 1 + N) % N
	return b.data[last_idx], true
}

peek_front_ptr :: proc(b: ^Ring_Buffer($N, $T)) -> (value: ^T, ok: bool) {
	if b.len == 0 {
		return nil, false
	}
	return &b.data[b.read_idx], true
}

peek_back_ptr :: proc(b: ^Ring_Buffer($N, $T)) -> (value: ^T, ok: bool) {
	if b.len == 0 {
		return nil, false
	}
	last_idx := (b.write_idx - 1 + N) % N
	return &b.data[last_idx], true
}

// Indexing operations
get :: proc(b: Ring_Buffer($N, $T), index: int) -> T {
	assert(index >= 0 && u64(index) < b.len, "Index out of bounds")
	actual_idx := (b.read_idx + u64(index)) % N
	return b.data[actual_idx]
}

get_safe :: proc(b: Ring_Buffer($N, $T), index: int) -> (value: T, ok: bool) {
	if index < 0 || u64(index) >= b.len {
		return {}, false
	}
	actual_idx := (b.read_idx + u64(index)) % N
	return b.data[actual_idx], true
}

get_ptr :: proc(b: ^Ring_Buffer($N, $T), index: int) -> ^T {
	assert(index >= 0 && u64(index) < b.len, "Index out of bounds")
	actual_idx := (b.read_idx + u64(index)) % N
	return &b.data[actual_idx]
}

get_ptr_safe :: proc(b: ^Ring_Buffer($N, $T), index: int) -> (value: ^T, ok: bool) {
	if index < 0 || u64(index) >= b.len {
		return nil, false
	}
	actual_idx := (b.read_idx + u64(index)) % N
	return &b.data[actual_idx], true
}

set :: proc(b: ^Ring_Buffer($N, $T), index: int, value: T) {
	assert(index >= 0 && u64(index) < b.len, "Index out of bounds")
	actual_idx := (b.read_idx + u64(index)) % N
	b.data[actual_idx] = value
}

set_safe :: proc(b: ^Ring_Buffer($N, $T), index: int, value: T) -> bool {
	if index < 0 || u64(index) >= b.len {
		return false
	}
	actual_idx := (b.read_idx + u64(index)) % N
	b.data[actual_idx] = value
	return true
}

// Utility operations
len :: proc(b: Ring_Buffer($N, $T)) -> int {
	return int(b.len)
}

cap :: proc(b: Ring_Buffer($N, $T)) -> int {
	return int(N)
}

space :: proc(b: Ring_Buffer($N, $T)) -> int {
	return int(N) - int(b.len)
}

is_empty :: proc(b: Ring_Buffer($N, $T)) -> bool {
	return b.len == 0
}

is_full :: proc(b: Ring_Buffer($N, $T)) -> bool {
	return b.len == N
}

clear :: proc(b: ^Ring_Buffer($N, $T)) {
	b.len = 0
	b.read_idx = 0
	b.write_idx = 0
}

// Iterator operations
iterate :: proc(b: Ring_Buffer($N, $T), cursor: ^int) -> (value: T, ok: bool) {
	if cursor^ < 0 || u64(cursor^) >= b.len {
		return {}, false
	}
	actual_idx := (b.read_idx + u64(cursor^)) % N
	value = b.data[actual_idx]
	cursor^ += 1
	return value, true
}

iterate_reverse :: proc(b: Ring_Buffer($N, $T), cursor: ^int) -> (value: T, ok: bool) {
	if cursor^ < 0 || u64(cursor^) >= b.len {
		return {}, false
	}
	// Get element from back
	reverse_idx := b.len - 1 - u64(cursor^)
	actual_idx := (b.read_idx + reverse_idx) % N
	value = b.data[actual_idx]
	cursor^ += 1
	return value, true
}

iterate_ptr :: proc(b: ^Ring_Buffer($N, $T), cursor: ^int) -> (value: ^T, ok: bool) {
	if cursor^ < 0 || u64(cursor^) >= b.len {
		return nil, false
	}
	actual_idx := (b.read_idx + u64(cursor^)) % N
	value = &b.data[actual_idx]
	cursor^ += 1
	return value, true
}

iterate_reverse_ptr :: proc(b: ^Ring_Buffer($N, $T), cursor: ^int) -> (value: ^T, ok: bool) {
	if cursor^ < 0 || u64(cursor^) >= b.len {
		return nil, false
	}
	// Get element from back
	reverse_idx := b.len - 1 - u64(cursor^)
	actual_idx := (b.read_idx + reverse_idx) % N
	value = &b.data[actual_idx]
	cursor^ += 1
	return value, true
}

@(test)
test_basic_operations :: proc(t: ^testing.T) {
	using testing
	
	buffer := Ring_Buffer(3, int){}
	
	// Test empty buffer
	expect(t, is_empty(buffer), "Buffer should start empty")
	expect(t, len(buffer) == 0, "Length should be 0")
	expect(t, cap(buffer) == 3, "Capacity should be 3")
	expect(t, space(buffer) == 3, "Space should be 3")
	
	// Test basic push_back
	push_back(&buffer, 10)
	expectf(t, len(buffer) == 1, "Length should be 1, got %v", len(buffer))
	expectf(t, !is_empty(buffer), "Buffer should not be empty")
	
	val, ok := peek_front(buffer)
	expect(t, ok, "Should be able to peek front")
	expectf(t, val == 10, "Front should be 10, got %v", val)
	
	val, ok = peek_back(buffer)
	expect(t, ok, "Should be able to peek back")
	expectf(t, val == 10, "Back should be 10, got %v", val)
}

@(test)
test_push_pop_operations :: proc(t: ^testing.T) {
	using testing
	
	buffer := Ring_Buffer(4, int){}
	
	// Test push_back and pop_front (FIFO)
	push_back(&buffer, 1)
	push_back(&buffer, 2)
	push_back(&buffer, 3)
	
	val, ok := pop_front(&buffer)
	expect(t, ok, "Should pop successfully")
	expectf(t, val == 1, "Should pop 1, got %v", val)
	
	val, ok = pop_front(&buffer)
	expect(t, ok, "Should pop successfully")
	expectf(t, val == 2, "Should pop 2, got %v", val)
	
	// Test push_front and pop_front (LIFO)
	clear(&buffer)
	push_front(&buffer, 1)
	push_front(&buffer, 2)
	push_front(&buffer, 3)
	
	val, ok = pop_front(&buffer)
	expect(t, ok, "Should pop successfully")
	expectf(t, val == 3, "Should pop 3, got %v", val)
	
	val, ok = pop_front(&buffer)
	expect(t, ok, "Should pop successfully")
	expectf(t, val == 2, "Should pop 2, got %v", val)
	
	// Test push_back and pop_back (LIFO)
	clear(&buffer)
	push_back(&buffer, 1)
	push_back(&buffer, 2)
	push_back(&buffer, 3)
	
	val, ok = pop_back(&buffer)
	expect(t, ok, "Should pop successfully")
	expectf(t, val == 3, "Should pop 3, got %v", val)
	
	val, ok = pop_back(&buffer)
	expect(t, ok, "Should pop successfully")
	expectf(t, val == 2, "Should pop 2, got %v", val)
}

@(test)
test_overflow_behavior :: proc(t: ^testing.T) {
	using testing
	
	buffer := Ring_Buffer(3, int){}
	
	// Fill buffer completely
	push_back(&buffer, 1)
	push_back(&buffer, 2)
	push_back(&buffer, 3)
	
	expect(t, is_full(buffer), "Buffer should be full")
	expectf(t, len(buffer) == 3, "Length should be 3, got %v", len(buffer))
	
	// Add one more - should overwrite oldest
	push_back(&buffer, 4)
	
	expect(t, is_full(buffer), "Buffer should still be full")
	expectf(t, len(buffer) == 3, "Length should be 3, got %v", len(buffer))
	
	// Should contain 2, 3, 4 (1 was overwritten)
	val, ok := pop_front(&buffer)
	expect(t, ok, "Should pop successfully")
	expectf(t, val == 2, "Should pop 2, got %v", val)
	
	val, ok = pop_front(&buffer)
	expect(t, ok, "Should pop successfully")
	expectf(t, val == 3, "Should pop 3, got %v", val)
	
	val, ok = pop_front(&buffer)
	expect(t, ok, "Should pop successfully")
	expectf(t, val == 4, "Should pop 4, got %v", val)
}

@(test)
test_indexing :: proc(t: ^testing.T) {
	using testing
	
	buffer := Ring_Buffer(4, int){}
	
	push_back(&buffer, 10)
	push_back(&buffer, 20)
	push_back(&buffer, 30)
	
	// Test get
	expectf(t, get(buffer, 0) == 10, "Index 0 should be 10, got %v", get(buffer, 0))
	expectf(t, get(buffer, 1) == 20, "Index 1 should be 20, got %v", get(buffer, 1))
	expectf(t, get(buffer, 2) == 30, "Index 2 should be 30, got %v", get(buffer, 2))
	
	// Test get_safe
	val, ok := get_safe(buffer, 0)
	expect(t, ok, "Should get successfully")
	expectf(t, val == 10, "Should get 10, got %v", val)
	
	val, ok = get_safe(buffer, 5)
	expect(t, !ok, "Should fail for out of bounds")
	
	// Test set
	set(&buffer, 1, 99)
	expectf(t, get(buffer, 1) == 99, "Index 1 should be 99 after set, got %v", get(buffer, 1))
	
	// Test set_safe
	ok = set_safe(&buffer, 2, 88)
	expect(t, ok, "Should set successfully")
	expectf(t, get(buffer, 2) == 88, "Index 2 should be 88 after set, got %v", get(buffer, 2))
	
	ok = set_safe(&buffer, 5, 77)
	expect(t, !ok, "Should fail for out of bounds")
}

@(test)
test_iteration :: proc(t: ^testing.T) {
	using testing
	
	buffer := Ring_Buffer(4, int){}
	
	push_back(&buffer, 1)
	push_back(&buffer, 2)
	push_back(&buffer, 3)
	
	// Test forward iteration
	cursor := 0
	expected := []int{1, 2, 3}
	i := 0
	for {
		val, ok := iterate(buffer, &cursor)
		if !ok do break
		expectf(t, val == expected[i], "Expected %v at position %v, got %v", expected[i], i, val)
		i += 1
	}
	expectf(t, i == 3, "Should iterate 3 times, got %v", i)
	
	// Test reverse iteration
	cursor = 0
	expected_reverse := []int{3, 2, 1}
	i = 0
	for {
		val, ok := iterate_reverse(buffer, &cursor)
		if !ok do break
		expectf(t, val == expected_reverse[i], "Expected %v at position %v, got %v", expected_reverse[i], i, val)
		i += 1
	}
	expectf(t, i == 3, "Should iterate 3 times in reverse, got %v", i)
}

@(test)
test_mixed_operations :: proc(t: ^testing.T) {
	using testing
	
	buffer := Ring_Buffer(3, int){}
	
	// Mix of front and back operations
	push_back(&buffer, 1)
	push_front(&buffer, 2)
	push_back(&buffer, 3)
	
	// Buffer should contain: 2, 1, 3
	expectf(t, get(buffer, 0) == 2, "Index 0 should be 2, got %v", get(buffer, 0))
	expectf(t, get(buffer, 1) == 1, "Index 1 should be 1, got %v", get(buffer, 1))
	expectf(t, get(buffer, 2) == 3, "Index 2 should be 3, got %v", get(buffer, 2))
	
	val, ok := pop_back(&buffer)
	expect(t, ok, "Should pop back successfully")
	expectf(t, val == 3, "Should pop 3, got %v", val)
	
	val, ok = pop_front(&buffer)
	expect(t, ok, "Should pop front successfully")
	expectf(t, val == 2, "Should pop 2, got %v", val)
}