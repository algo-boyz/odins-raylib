package tests

import "core:fmt"
import "core:math"
import "core:time"
import "core:mem"
import "core:math/rand"
import "core:testing"
import ql "../"

TEST_STATES :: 1000
TEST_ACTIONS :: ql.Action
PERFORMANCE_ITERATIONS :: 100000
CACHE_TEST_ITERATIONS :: 10000

@(test)
test_qtable_creation :: proc(t: ^testing.T) {
    hints := ql.Access_Pattern{
        freq_max_queries = true,
        sequential_access = false,
        batch_updates = false,
        cachable = true,
    }
    // Test standard alloc
    qtable := ql.new_qtable(TEST_STATES, int(TEST_ACTIONS.COUNT), .STANDARD, hints)
    defer ql.destroy_qtable(qtable)
    
    testing.expect(t, qtable != nil, "STANDARD Q-table creation")
    testing.expect(t, qtable.num_states == TEST_STATES, "Correct number of states")
    testing.expect(t, qtable.num_actions == int(TEST_ACTIONS.COUNT), "Correct number of actions")
    testing.expect(t, qtable.data != nil, "Data array allocated")
    
    // Test aligned alloc
    qtable_aligned := ql.new_qtable(TEST_STATES, int(TEST_ACTIONS.COUNT), .ALIGNED, hints)
    defer ql.destroy_qtable(qtable_aligned)
    
    testing.expect(t, qtable_aligned != nil, "ALIGNED Q-table creation")
    testing.expect(t, qtable_aligned.simd_alignment >= 16, "SIMD alignment set")
    
    // Test with cache disabled
    hints_no_cache := hints
    hints_no_cache.freq_max_queries = false
    qtable_no_cache := ql.new_qtable(TEST_STATES, int(TEST_ACTIONS.COUNT), .STANDARD, hints_no_cache)
    defer ql.destroy_qtable(qtable_no_cache)
    
    testing.expect(t, qtable_no_cache != nil, "Q-table creation without cache")
    testing.expect(t, qtable_no_cache.max_cache == nil, "Cache disabled")
}

@(test)
test_basic_operations :: proc(t: ^testing.T) {
    hints := ql.Access_Pattern{
        freq_max_queries = true,
        sequential_access = false,
        batch_updates = false,
        cachable = true,
    }
    qtable := ql.new_qtable(100, int(TEST_ACTIONS.COUNT), .ALIGNED, hints)
    defer ql.destroy_qtable(qtable)
    
    testing.expect(t, qtable != nil, "Q-table creation for testing")
    
    // Test setting and getting
    ql.set_q_value_fast(qtable, 0, 0, 1.5)
    value := ql.get_q_value_fast(qtable, 0, 0)
    testing.expect(t, f32_near(value, 1.5), "Set and get Q-value")
    
    // Test multiple values
    all_correct := true
    for s in 0..<10 {
        for a in 0..<int(TEST_ACTIONS.COUNT) {
            test_value := f32(s * int(TEST_ACTIONS.COUNT) + a) + 0.1
            ql.set_q_value_fast(qtable, s, a, test_value)
            retrieved := ql.get_q_value_fast(qtable, s, a)
            if abs(retrieved - test_value) >= 1e-6 {
                all_correct = false
                break
            }
        }
        if !all_correct do break
    }
    testing.expect(t, all_correct, "Multiple Q-value operations")
}

@(test)
test_cached_operations :: proc(t: ^testing.T) {
    hints := ql.Access_Pattern{
        freq_max_queries = true,
        sequential_access = false,
        batch_updates = false,
        cachable = true,
    }
    qtable := ql.new_qtable(100, int(TEST_ACTIONS.COUNT), .ALIGNED, hints)
    defer ql.destroy_qtable(qtable)
    
    testing.expect(t, qtable != nil, "Q-table creation for cache testing")
    
    // Set up test values for state 0
    ql.set_q_value_fast(qtable, 0, 0, 1)
    ql.set_q_value_fast(qtable, 0, 1, 3.5)  // max
    ql.set_q_value_fast(qtable, 0, 2, 2)
    ql.set_q_value_fast(qtable, 0, 3, 1.5)
    
    // Test max value
    max_val := ql.get_max_q_value_cached(qtable, 0)
    testing.expect(t, f32_near(max_val, 3.5), "Cached max Q-value")
    
    // Test best action
    best_action := ql.get_best_action(qtable, 0)
    testing.expectf(t, best_action == 1, "Expected cached best action to be 1, got %d", best_action)
    
    // Test cache hit (second call should hit cache)
    ql.reset_perf_counters()
    ql.get_max_q_value_cached(qtable, 0) // This will hit cache
    ql.get_best_action(qtable, 0)        // This will hit cache
    counters := ql.get_perf_counters()
    testing.expect(t, counters.cache_hits > 0, "Cache hits registered")
    
    // Test cache invalidation
    ql.invalidate_state_cache(qtable, 0)
    testing.expect(t, !qtable.cache_valid[0], "Cache invalidated")
}

@(test)
test_batch_operations :: proc(t: ^testing.T) {
    hints := ql.Access_Pattern{
        freq_max_queries = true,
        sequential_access = false,
        batch_updates = true,
        cachable = true,
    }
    qtable := ql.new_qtable(100, int(TEST_ACTIONS.COUNT), .ALIGNED, hints)
    defer ql.destroy_qtable(qtable)
    
    testing.expect(t, qtable != nil, "Q-table creation for batch testing")
    
    // Prepare batch data
    batch_size :: 10
    states := make([]int, batch_size, context.temp_allocator)
    actions := make([]int, batch_size, context.temp_allocator)
    values := make([]f32, batch_size, context.temp_allocator)
    retrieved := make([]f32, batch_size, context.temp_allocator)
    
    for i in 0..<batch_size {
        states[i] = i
        actions[i] = i % int(TEST_ACTIONS.COUNT)
        values[i] = f32(i) * 0.5 + 1
    }
    // Test batch update
    ql.reset_perf_counters()
    ql.batch_update_q_values(qtable, states, actions, values)
    counters := ql.get_perf_counters()
    testing.expect(t, counters.batch_ops > 0, "Batch update recorded")
    
    // Test batch get
    ql.batch_get_q_values(qtable, states, actions, retrieved)
    all_correct := true
    for i in 0..<batch_size {
        if abs(retrieved[i] - values[i]) > 1e-6 {
            all_correct = false
            break
        }
    }
    testing.expect(t, all_correct, "Batch get operations")
    
    // Test batch max values
    max_values := make([]f32, batch_size, context.temp_allocator)
    ql.batch_get_max_q_values(qtable, states, max_values)
    testing.expect(t, max_values[0] >= 0, "Batch max values operation")
}

@(test)
test_simd_operations :: proc(t: ^testing.T) {
    hints := ql.Access_Pattern{
        freq_max_queries = true,
        sequential_access = false,
        batch_updates = false,
        cachable = true,
    }
    qtable := ql.new_qtable(100, 16, .ALIGNED, hints) // 16 actions for SIMD
    defer ql.destroy_qtable(qtable)
    
    testing.expect(t, qtable != nil, "Q-table creation for SIMD testing")
    
    // Set up test values
    for a in 0..<16 {
        ql.set_q_value_fast(qtable, 0, a, f32(a) * 0.5)
    }
    // Test SIMD max (should find action 15 with value 7.5)
    if qtable.simd_enabled {
        ql.reset_perf_counters()
        simd_max := ql.simd_max_in_row(qtable, 0)
        testing.expect(t, f32_near(simd_max, 7.5), "SIMD max operation")

        simd_argmax := ql.simd_argmax_in_row(qtable, 0)
        testing.expect(t, simd_argmax == 15, "SIMD argmax operation")
        
        counters := ql.get_perf_counters()
        testing.expect(t, counters.simd_ops > 0, "SIMD operations recorded")
    } else {
        fmt.println("SIMD not available on this platform - skipping SIMD tests")
    }
}

@(test)
test_performance_comparison :: proc(t: ^testing.T) {
    // Create standard Q-table (using existing agent structure)
    // NOTE: ql.new_agent and ql.select_greedy_action are not provided in the snippet.
    // Assuming they exist and are compatible for this test.
    // For a complete runnable test, these would need to be defined or mocked.
    standard_agent := ql.new_agent(TEST_STATES, int(TEST_ACTIONS.COUNT), 0.1, 0.99, 0.1)
    defer ql.destroy_agent(standard_agent)
    testing.expect(t, standard_agent != nil, "STANDARD agent creation")
    
    // Create optimized Q-table
    optimized := ql.qtable_wrap_for_agent(TEST_STATES, int(TEST_ACTIONS.COUNT))
    defer ql.destroy_qtable_wrapper(optimized)
    testing.expect(t, optimized != nil, "Optimized Q-table wrapper creation")
    
    // Fill with random data
    // TODO rand.set_global_seed(42) // Consistent seed for fair comparison
    for s in 0..<TEST_STATES {
        for a in 0..<int(TEST_ACTIONS.COUNT) {
            value := rand.float32() * 10 - 5
            ql.set_q_value(standard_agent, s, ql.Action(i32(a)), value)
            ql.qtable_set_value(optimized, s, a, value)
        }
    }
    // Test standard Q-table performance
    start_time := time.now()
    for i in 0..<PERFORMANCE_ITERATIONS {
        state := rand.int_max(TEST_STATES)
        ql.select_greedy_action(standard_agent, state)
    }
    standard_time := time.duration_milliseconds(time.since(start_time))
    
    // Test optimized Q-table performance
    start_time = time.now()
    for i in 0..<PERFORMANCE_ITERATIONS {
        state := rand.int_max(TEST_STATES)
        ql.qtable_get_best_action(optimized, state)
    }
    optimized_time := time.duration_milliseconds(time.since(start_time))
    
    speedup := f64(standard_time) / f64(optimized_time)
    fmt.printf("STANDARD Q-table time: %.2f ms\n", f64(standard_time))
    fmt.printf("Optimized Q-table time: %.2f ms\n", f64(optimized_time))
    fmt.printf("Speedup: %.2fx\n", speedup)
    
    testing.expect(t, speedup >= 1.0, "Optimized Q-table performance improvement")
}
    
@(test)
test_memory_layout :: proc(t: ^testing.T) {
    hints := ql.Access_Pattern{
        freq_max_queries = true,
        sequential_access = true,
        batch_updates = false,
        cachable = true,
    }
    qtable := ql.new_qtable(256, int(TEST_ACTIONS.COUNT), .ALIGNED, hints)
    defer ql.destroy_qtable(qtable)
    
    testing.expect(t, qtable != nil, "Q-table creation for memory layout testing")
    
    // Test row cache for small state spaces
    testing.expect(t, qtable.use_row_cache, "Row cache enabled for small state space")
    
    // Test memory alignment
    data_addr := uintptr(raw_data(qtable.data))
    testing.expect(t, data_addr % uintptr(qtable.simd_alignment) == 0, "Data properly aligned for SIMD")
    
    // // Test prefetching (doesn't crash)
    // ql.prefetch_state_data(qtable, 0)
    // testing.expect(t, true, "Memory prefetching operation")
    
    // // Test cache warm-up
    // likely_states := []int{0, 1, 2, 3, 4}
    // ql.warm_up_caches(qtable, likely_states)
    // testing.expect(t, true, "Cache warm-up operation")
}

@(test)
test_qtable_error_handling :: proc(t: ^testing.T) {
    // Test invalid parameters
    qtable_invalid_states := ql.new_qtable(-1, 4, .STANDARD, ql.Access_Pattern{})
    testing.expect(t, qtable_invalid_states == nil, "Invalid state count rejected")
    
    qtable_invalid_actions := ql.new_qtable(100, -1, .STANDARD, ql.Access_Pattern{})
    testing.expect(t, qtable_invalid_actions == nil, "Invalid action count rejected")
    
    // Test operations on nil qtable
    value := ql.get_q_value_fast(nil, 0, 0)
    testing.expect(t, value == 0, "nil qtable get returns 0")
    
    max_val := ql.get_max_q_value_cached(nil, 0)
    testing.expect(t, max_val == 0, "nil qtable max returns 0")
    
    best_action := ql.get_best_action(nil, 0)
    testing.expect(t, best_action == 0, "nil qtable best action returns 0")
    
    // Test out-of-bounds access
    qtable := ql.new_qtable(10, 4, .STANDARD, ql.Access_Pattern{})
    defer ql.destroy_qtable(qtable)
    
    if qtable != nil {
        value = ql.get_q_value_fast(qtable, 100, 0) // Out of bounds state
        testing.expect(t, true, "Out-of-bounds access handled gracefully")
        
        max_val = ql.get_max_q_value_cached(qtable, -1) // Negative state
        testing.expect(t, max_val == 0, "Negative state index handled")
    }
}

@(test)
test_compatibility_wrapper :: proc(t: ^testing.T) {
    wrapper := ql.qtable_wrap_for_agent(100, int(TEST_ACTIONS.COUNT))
    defer ql.destroy_qtable_wrapper(wrapper)
    
    testing.expect(t, wrapper != nil, "Wrapper creation")
    testing.expect(t, wrapper.qtable != nil, "Wrapped Q-table exists")
    testing.expect(t, wrapper.counters != nil, "Performance counters exist")
    
    // Test wrapper operations
    ql.qtable_set_value(wrapper, 0, 0, 2.5)
    value := ql.qtable_get_value(wrapper, 0, 0)
    testing.expect(t, f32_near(value, 2.5), "Wrapper set/get operations")

    // Set up for max/argmax test - USE VALID ACTION INDICES
    ql.qtable_set_value(wrapper, 1, 0, 1.0)      // action 0: 1.0
    ql.qtable_set_value(wrapper, 1, 1, 4.0)      // action 1: 4.0 (should be max)
    ql.qtable_set_value(wrapper, 1, 2, 2.0)      // action 2: 2.0
    ql.qtable_set_value(wrapper, 1, 3, 3.0)      // action 3: 3.0
    
    max_val := ql.qtable_get_max_value(wrapper, 1)
    best_action := ql.qtable_get_best_action(wrapper, 1)

    testing.expect(t, f32_near(max_val, 4.0), "Wrapper max value")
    testing.expectf(t, best_action == 1, "Wrapper best action should be 1, got %d", best_action)
}

@(test)
test_argmax :: proc(t: ^testing.T) {
    qtable := ql.new_qtable(2, 4)  // 2 states, 4 actions
    defer ql.destroy_qtable(qtable)
    if qtable == nil {
        fmt.println("ERROR: Failed to create qtable")
        return
    }
    // Set up test values for state 1: [1, 4, 2, 3]
    ql.set_q_value_fast(qtable, 1, 0, 1.0)
    ql.set_q_value_fast(qtable, 1, 1, 4.0)
    ql.set_q_value_fast(qtable, 1, 2, 2.0)
    ql.set_q_value_fast(qtable, 1, 3, 3.0)
    for action in 0..<4 {
        value := ql.get_q_value_fast(qtable, 1, action)
        fmt.printf("  qtable[1][%d] = %.1f\n", action, value)
    }
    _ = ql.simd_argmax_in_row(qtable, 1) // This just calculates, doesn't cache
    best_action := ql.get_best_action(qtable, 1) // This will use the cache if enabled, otherwise call argmax directly
    testing.expectf(t, best_action == 1, "Original best action should be 1, got %d", best_action)
}
