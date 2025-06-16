package dyn

import "base:builtin"
import "base:runtime"
import "core:sort"

/*
Static array with dynamic length

Based on core:container/small_array.
Usage is similar to `[dynamic]T`
*/
Array :: struct($Num: i32, $Val: typeid) where Num >= 0 {
    data:          [Num]Val,
    len:           i32,
    invalid_value: Val,
}

@(require_results)
array_has_index :: #force_inline proc "contextless" (a: $A/Array, #any_int index: int) -> bool {
    return index >= 0 && index < int(a.len)
}

@(require_results)
array_slice :: #force_inline proc "contextless" (a: ^$A/Array($N, $T)) -> []T {
    return a.data[:a.len]
}

@(require_results)
array_get :: #force_inline proc "contextless" (a: $A/Array($N, $T), #any_int index: int, loc := #caller_location) -> T {
    runtime.bounds_check_error_loc(loc, index, int(a.len))
    return a.data[index]
}

@(require_results)
array_get_safe :: proc "contextless" (a: $A/Array($N, $T), #any_int index: int) -> (T, bool) #optional_ok {
    if index < 0 || index >= int(a.len) {
        return {}, false
    }
    return a.data[index], true
}

@(require_results)
array_get_ptr :: #force_inline proc "contextless" (a: ^$A/Array($N, $T), #any_int index: int, loc := #caller_location) -> ^T {
    runtime.bounds_check_error_loc(loc, index, int(a.len))
    return &a.data[index]
}

@(require_results)
array_get_ptr_safe :: proc "contextless" (a: ^$A/Array($N, $T), #any_int index: int) -> (^T, bool) #optional_ok {
    if index < 0 || index >= int(a.len) {
        return &a.invalid_value, false
    }
    return &a.data[index], true
}

array_set :: #force_inline proc "contextless" (a: ^$A/Array($N, $T), #any_int index: int, value: T, loc := #caller_location) {
    runtime.bounds_check_error_loc(loc, index, int(a.len))
    a.data[index] = value
}

array_set_safe :: proc "contextless" (a: ^$A/Array($N, $T), #any_int index: int, value: T) -> bool {
    if index < 0 || index >= int(a.len) {
        return false
    }
    a.data[index] = value
    return true
}

array_set_ptr :: #force_inline proc "contextless" (a: ^$A/Array($N, $T), #any_int index: int, value: ^T, loc := #caller_location) {
    runtime.bounds_check_error_loc(loc, index, int(a.len))
    a.data[index] = value
}

array_set_ptr_safe :: proc "contextless" (a: ^$A/Array($N, $T), #any_int index: int, value: ^T) -> bool {
    if index < 0 || index >= int(a.len) {
        return false
    }
    a.data[index] = value
    return true
}

// Returns index of the pushed value
array_push :: proc "contextless" (a: ^$A/Array($N, $T), item: T, loc := #caller_location) -> int {
    assert_contextless(a.len < i32(N), "Reached the array size limit", loc)
    index := a.len
    a.data[index] = item
    a.len += 1
    return int(index)
}

array_push_safe :: proc "contextless" (a: ^$A/Array($N, $T), item: T) -> (index: int, ok: bool) #optional_ok {
    index = array_push_empty(a) or_return
    a.data[index] = item
    return index, true
}

// Warning: doesn't clear previous value!
@(require_results)
array_push_empty :: proc "contextless" (a: ^$A/Array($N, $T)) -> (index: int, ok: bool) #optional_ok {
    if a.len >= N {
        return 0, false
    }
    index = int(a.len)
    a.len += 1
    return index, true
}

array_push_elems :: proc "contextless" (a: ^$A/Array($N, $T), elems: ..T, loc := #caller_location) {
    n := copy(a.data[a.len:], elems[:])
    a.len += i32(n)
    assert_contextless(n == len(elems), "Not enough space in the array", loc)
}

array_push_elems_safe :: proc "contextless" (a: ^$A/Array($N, $T), elems: ..T) -> bool {
    n := copy(a.data[a.len:], elems[:])
    a.len += n
    return n == len(elems)
}

@(require_results)
array_pop_back :: proc "contextless" (a: ^$A/Array($N, $T), loc := #caller_location) -> T {
    assert_contextless(a.len > 0, "Array is empty", loc)
    item := a.data[a.len - 1]
    a.len -= 1
    return item
}

@(require_results)
array_pop_back_safe :: proc "contextless" (a: ^$A/Array($N, $T)) -> (item: T, ok: bool) #optional_ok {
    if a.len <= 0 {
        return {}, false
    }
    item = a.data[a.len - 1]
    a.len -= 1
    return item, true
}

array_remove :: proc "contextless" (a: ^$A/Array($N, $T), #any_int index: int, loc := #caller_location) {
    runtime.bounds_check_error_loc(loc, index, int(a.len))
    n := a.len - 1
    if index != int(n) {
        a.data[index] = a.data[n]
    }
    a.len -= 1
}

// Remove an element while preserving the order of remaining elements
array_ordered_remove :: proc "contextless" (a: ^$A/Array($N, $T), #any_int index: int, loc := #caller_location) {
    runtime.bounds_check_error_loc(loc, index, int(a.len))
    
    // Shift all elements after the removed one
    for i := index; i < int(a.len - 1); i += 1 {
        a.data[i] = a.data[i + 1]
    }
    
    a.len -= 1
}

// Safe version with return value indicating success
array_ordered_remove_safe :: proc "contextless" (a: ^$A/Array($N, $T), #any_int index: int) -> bool {
    if index < 0 || index >= int(a.len) {
        return false
    }
    
    // Shift all elements after the removed one
    for i := index; i < int(a.len - 1); i += 1 {
        a.data[i] = a.data[i + 1]
    }
    
    a.len -= 1
    return true
}

array_clear :: proc "contextless" (a: ^$A/Array($N, $T)) {
    a.data = nil
    a.len = 0
}

array_from_slice :: proc "contextless" (a: ^$A/Array($N, $T), data: []T) -> bool {
    a.len = cast(i32)copy(a.data[:], data)
    return int(a.len) == len(data)
}

array_as_slice :: #force_inline proc "contextless" (a: ^$A/Array($N, $T)) -> []T {
    return a.data[:a.len]
}

// Concat two arrays
array_concat :: proc "contextless" (a: ^$A/Array($N, $T), b: $B/Array($M, $U), loc := #caller_location) {
    assert_contextless(a.len + b.len <= N, "Combined array would exceed maximum size", loc)
    array_push_elems(a, array_slice(b)[:], loc)
}

// Reverse the array in place
array_reverse :: proc "contextless" (a: ^$A/Array($N, $T)) {
    i, j := 0, int(a.len) - 1
    for i < j {
        a.data[i], a.data[j] = a.data[j], a.data[i]
        i += 1
        j -= 1
    }
}

// Find first occurrence of value
array_find :: proc "contextless" (a: $A/Array($N, $T), value: T) -> (index: int, ok: bool) where intrinsics.type_has_equal(T) {
    for i in 0..<int(a.len) {
        if a.data[i] == value {
            return i, true
        }
    }
    return -1, false
}

// Map function - applies a function to all elements and returns a new array
array_map :: proc "contextless" (a: $A/Array($N, $T), f: proc(T) -> $R) -> Array(N, R) {
    result: Array(N, R)
    result.len = a.len
    
    for i in 0..<int(a.len) {
        result.data[i] = f(a.data[i])
    }
    
    return result
}

// Filter function - keeps elements that satisfy predicate
array_filter :: proc "contextless" (a: $A/Array($N, $T), pred: proc(T) -> bool) -> Array(N, T) {
    result: Array(N, T) = {invalid_value = a.invalid_value}
    
    for i in 0..<int(a.len) {
        if pred(a.data[i]) {
            array_push(&result, a.data[i])
        }
    }
    
    return result
}

// Insert at specific position (shifting elements)
array_insert :: proc "contextless" (a: ^$A/Array($N, $T), #any_int index: int, value: T, loc := #caller_location) {
    runtime.bounds_check_error_loc(loc, index, int(a.len) + 1)
    assert_contextless(a.len < i32(N), "Reached the array size limit", loc)
    
    // Shift elements to make room
    for i := a.len; i > i32(index); i -= 1 {
        a.data[i] = a.data[i-1]
    }
    
    a.data[index] = value
    a.len += 1
}

// 1. Array capacity functions
@(require_results)
array_capacity :: #force_inline proc "contextless" (a: $A/Array($N, $T)) -> int {
    return N
}

@(require_results)
array_remaining_capacity :: #force_inline proc "contextless" (a: $A/Array($N, $T)) -> int {
    return N - int(a.len)
}

@(require_results)
array_fill_percentage :: #force_inline proc "contextless" (a: $A/Array($N, $T)) -> f32 {
    return f32(a.len) / f32(N) * 100
}

array_sort :: proc "contextless" (a: ^$A/Array($N, $T), less: proc(i, j: T) -> bool) {
    arr_slice := array_slice(a)
    sort.quick_sort_proc(arr_slice, less)
}

// Default sort for comparable types
array_sort_default :: proc "contextless" (a: ^$A/Array($N, $T)) where intrinsics.type_is_ordered(T) {
    arr_slice := array_slice(a)
    sort.quick_sort(arr_slice)
}

// Binary search (for sorted arrays)
@(require_results)
array_binary_search :: proc "contextless" (a: $A/Array($N, $T), value: T, less: proc(a, b: T) -> bool) -> (index: int, found: bool) #optional_ok {
    if a.len == 0 {
        return -1, false
    }
    
    left, right := 0, int(a.len) - 1
    
    for left <= right {
        mid := left + (right - left) / 2
        
        if a.data[mid] == value {
            return mid, true
        }
        
        if less(a.data[mid], value) {
            left = mid + 1
        } else {
            right = mid - 1
        }
    }
    
    return -1, false
}

// Binary search with default comparison for ordered types
@(require_results)
array_binary_search_default :: proc "contextless" (a: $A/Array($N, $T), value: T) -> (index: int, found: bool) where intrinsics.type_is_ordered(T) {
    if a.len == 0 {
        return -1, false
    }
    
    left, right := 0, int(a.len) - 1
    
    for left <= right {
        mid := left + (right - left) / 2
        
        if a.data[mid] == value {
            return mid, true
        }
        
        if a.data[mid] < value {
            left = mid + 1
        } else {
            right = mid - 1
        }
    }
    
    return -1, false
}

@(require_results)
array_contains :: #force_inline proc "contextless" (a: $A/Array($N, $T), value: T) -> bool where intrinsics.type_has_equal(T) {
    _, found := array_find(a, value)
    return found
}

@(require_results)
array_distinct :: proc "contextless" (a: $A/Array($N, $T)) -> Array(N, T) where intrinsics.type_has_equal(T) {
    result: Array(N, T) = {invalid_value = a.invalid_value}
    
    // For small arrays, this simple approach is probably fine
    // For very large arrays, a map/set would be more efficient
    for i in 0..<int(a.len) {
        item := a.data[i]
        found := false
        
        for j in 0..<int(result.len) {
            if result.data[j] == item {
                found = true
                break
            }
        }
        
        if !found {
            array_push(&result, item)
        }
    }
    
    return result
}

@(require_results)
array_clone :: proc "contextless" (a: $A/Array($N, $T)) -> Array(N, T) {
    result: Array(N, T) = {invalid_value = a.invalid_value}
    result.len = a.len
    
    for i in 0..<int(a.len) {
        result.data[i] = a.data[i]
    }
    
    return result
}

@(require_results)
array_take :: proc "contextless" (a: $A/Array($N, $T), count: int) -> Array(N, T) {
    result: Array(N, T) = {invalid_value = a.invalid_value}
    take_count := min(count, int(a.len))
    
    for i in 0..<take_count {
        array_push(&result, a.data[i])
    }
    
    return result
}

@(require_results)
array_skip :: proc "contextless" (a: $A/Array($N, $T), count: int) -> Array(N, T) {
    result: Array(N, T) = {invalid_value = a.invalid_value}
    skip_count := min(count, int(a.len))
    
    for i in skip_count..<int(a.len) {
        array_push(&result, a.data[i])
    }
    
    return result
}