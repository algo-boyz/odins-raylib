package dyn

// import "core:testing"

// main :: proc() {
//     testing.run({
//         test_array_filter,
//         test_array_filter_slice,
//         test_array_push,
//         test_array_pop_back,
//         test_array_remove,
//         test_array_ordered_remove,
//         test_array_sort_default,
//         test_array_binary_search_default,
//         test_array_contains,
//         test_array_distinct,
//         test_array_clone,
//         test_array_take,
//         test_array_skip,
//     })
// }

// test_array_filter :: proc() {
//     // Define a predicate function
//     is_even :: proc(x: int) -> bool {
//         return x % 2 == 0
//     }

//     // Create an array with some test data
//     arr: Array(10, int) = {
//         data = [10]int{1, 2, 3, 4, 5, 6, 7, 8, 9, 10},
//         len = 10,
//         invalid_value = -1,
//     }

//     // Call array_filter with the predicate
//     result := array_filter(&arr, is_even)

//     // Expected result
//     expected := Array(10, int){
//         data = [10]int{2, 4, 6, 8, 10},
//         len = 5,
//         invalid_value = -1,
//     }

//     // Check if the result matches the expected output
//     testing.expect(array_slice(&result) == array_slice(&expected), "array_filter did not return the expected result")
// }

// test_array_filter_slice :: proc() {
//     // Define a predicate function
//     is_even :: proc(x: int) -> bool {
//         return x % 2 == 0
//     }

//     // Create an array with some test data
//     arr: Array(10, int) = {
//         data = [10]int{1, 2, 3, 4, 5, 6, 7, 8, 9, 10},
//         len = 10,
//         invalid_value = -1,
//     }

//     // Call array_filter_slice with the predicate
//     result := array_filter_slice(&arr, is_even, context.allocator)

//     // Expected result
//     expected := []int{2, 4, 6, 8, 10}

//     // Check if the result matches the expected output
//     testing.expect(result == expected, "array_filter_slice did not return the expected result")
// }

// test_array_push :: proc() {
//     arr: Array(5, int) = {
//         data = [5]int{},
//         len = 0,
//         invalid_value = -1,
//     }

//     array_push(&arr, 1)
//     array_push(&arr, 2)
//     array_push(&arr, 3)

//     expected := Array(5, int){
//         data = [5]int{1, 2, 3},
//         len = 3,
//         invalid_value = -1,
//     }

//     testing.expect(array_slice(&arr) == array_slice(&expected), "array_push did not return the expected result")
// }

// test_array_pop_back :: proc() {
//     arr: Array(5, int) = {
//         data = [5]int{1, 2, 3},
//         len = 3,
//         invalid_value = -1,
//     }

//     item := array_pop_back(&arr)

//     expected := Array(5, int){
//         data = [5]int{1, 2},
//         len = 2,
//         invalid_value = -1,
//     }

//     testing.expect(item == 3, "array_pop_back did not return the expected item")
//     testing.expect(array_slice(&arr) == array_slice(&expected), "array_pop_back did not return the expected result")
// }

// test_array_remove :: proc() {
//     arr: Array(5, int) = {
//         data = [5]int{1, 2, 3},
//         len = 3,
//         invalid_value = -1,
//     }

//     array_remove(&arr, 1)

//     expected := Array(5, int){
//         data = [5]int{1, 3},
//         len = 2,
//         invalid_value = -1,
//     }

//     testing.expect(array_slice(&arr) == array_slice(&expected), "array_remove did not return the expected result")
// }

// test_array_ordered_remove :: proc() {
//     arr: Array(5, int) = {
//         data = [5]int{1, 2, 3},
//         len = 3,
//         invalid_value = -1,
//     }

//     array_ordered_remove(&arr, 1)

//     expected := Array(5, int){
//         data = [5]int{1, 3},
//         len = 2,
//         invalid_value = -1,
//     }

//     testing.expect(array_slice(&arr) == array_slice(&expected), "array_ordered_remove did not return the expected result")
// }

// test_array_sort_default :: proc() {
//     arr: Array(5, int) = {
//         data = [5]int{3, 1, 2},
//         len = 3,
//         invalid_value = -1,
//     }

//     array_sort_default(&arr)

//     expected := Array(5, int){
//         data = [5]int{1, 2, 3},
//         len = 3,
//         invalid_value = -1,
//     }

//     testing.expect(array_slice(&arr) == array_slice(&expected), "array_sort_default did not return the expected result")
// }

// test_array_binary_search_default :: proc() {
//     arr: Array(5, int) = {
//         data = [5]int{1, 2, 3},
//         len = 3,
//         invalid_value = -1,
//     }

//     index, found := array_binary_search_default(&arr, 2)

//     testing.expect(found, "array_binary_search_default did not find the expected value")
//     testing.expect(index == 1, "array_binary_search_default did not return the expected index")
// }

// test_array_contains :: proc() {
//     arr: Array(5, int) = {
//         data = [5]int{1, 2, 3},
//         len = 3,
//         invalid_value = -1,
//     }

//     contains := array_contains(&arr, 2)

//     testing.expect(contains, "array_contains did not find the expected value")
// }

// test_array_distinct :: proc() {
//     arr: Array(10, int) = {
//         data = [10]int{1, 2, 2, 3, 3, 3, 4, 4, 4, 4},
//         len = 10,
//         invalid_value = -1,
//     }

//     result := array_distinct(&arr)

//     expected := Array(10, int){
//         data = [10]int{1, 2, 3, 4},
//         len = 4,
//         invalid_value = -1,
//     }

//     testing.expect(array_slice(&result) == array_slice(&expected), "array_distinct did not return the expected result")
// }

// test_array_clone :: proc() {
//     arr: Array(5, int) = {
//         data = [5]int{1, 2, 3},
//         len = 3,
//         invalid_value = -1,
//     }

//     result := array_clone(&arr)

//     testing.expect(array_slice(&result) == array_slice(&arr), "array_clone did not return the expected result")
// }

// test_array_take :: proc() {
//     arr: Array(5, int) = {
//         data = [5]int{1, 2, 3},
//         len = 3,
//         invalid_value = -1,
//     }

//     result := array_take(&arr, 2)

//     expected := Array(5, int){
//         data = [5]int{1, 2},
//         len = 2,
//         invalid_value = -1,
//     }

//     testing.expect(array_slice(&result) == array_slice(&expected), "array_take did not return the expected result")
// }

// test_array_skip :: proc() {
//     arr: Array(5, int) = {
//         data = [5]int{1, 2, 3},
//         len = 3,
//         invalid_value = -1,
//     }

//     result := array_skip(&arr, 1)

//     expected := Array(5, int){
//         data = [5]int{2, 3},
//         len = 2,
//         invalid_value = -1,
//     }

//     testing.expect(array_slice(&result) == array_slice(&expected), "array_skip did not return the expected result")
// }
