package qlearn

import "base:intrinsics"
import "core:fmt"
import "core:mem"
import "core:math"
import "core:slice"
import "core:simd"
import "core:thread"
import rl "vendor:raylib"

// SIMD vector width - configurable for performance tuning
SIMD_WIDTH :: #config(SIMD_WIDTH, 8)

// Alloc strategies
Alloc :: enum {
    STANDARD,
    ALIGNED,
}

// Access pattern hints for optimization
Access_Pattern :: struct { freq_max_queries, sequential_access, batch_updates, cachable: bool }

Perf_Counters :: struct { total_access, cache_hits, cache_miss, batch_ops, simd_ops: u64 }

// Thread-local performance counters
@(thread_local)
g_perf_counters: Perf_Counters

QTable :: struct {
    num_states,
    num_actions,
    state_stride: int,
    // Row cache for small state space
    state_rows:       [256][]f32,
    use_row_cache,
    // Performance optimization
    simd_enabled:     bool,
    simd_alignment,
    // Last accessed state
    last_state_id:    int,
    last_state_ptr,
    // Cache
    data, max_cache:  []f32,
    best_action:      []int,
    cache_valid:      []bool,
    allocator:        mem.Allocator,
}

// Wrapper for agent compat
QTable_Wrapper :: struct {
    qtable:   ^QTable,
    counters: ^Perf_Counters,
}

// Create Arch optimized Q-table
new_qtable :: proc(num_states: int, num_actions: int, strategy: Alloc = .ALIGNED, hints: Access_Pattern = {}, allocator := context.allocator) -> ^QTable {
    if num_states <= 0 || num_actions <= 0 {
        fmt.eprintln("Error: Invalid Q-table dims")
        return nil
    }
    qtable := new(QTable, allocator)
    qtable.allocator = allocator
    qtable.num_states = num_states
    qtable.num_actions = num_actions
    qtable.state_stride = num_actions
    qtable.last_state_id = -1
    // Determine SIMD capability
    qtable.simd_enabled = ODIN_ARCH == .amd64 || ODIN_ARCH == .i386
    qtable.simd_alignment = 32 // AVX2 alignment
    data_size := num_states * num_actions
    switch strategy {
    case .ALIGNED:
        qtable.data = align([]f32, data_size, qtable.simd_alignment, allocator)
    case .STANDARD:
        qtable.data = make([]f32, data_size, allocator)
    }
    if qtable.data == nil {
        fmt.eprintln("Error: Failed to allocate Q-table data array")
        free(qtable, allocator)
        return nil
    }
    slice.fill(qtable.data, 0) // Init zero
    // Setup caching if requested
    if hints.freq_max_queries {
        qtable.max_cache = make([]f32, num_states, allocator)
        qtable.best_action = make([]int, num_states, allocator)
        qtable.cache_valid = make([]bool, num_states, allocator)
        
        if qtable.max_cache == nil || qtable.best_action == nil || qtable.cache_valid == nil {
            fmt.eprintln("Error: Failed to allocate cache structures")
            destroy_qtable(qtable)
            return nil
        }
    }
    // Setup row cache for small state spaces
    qtable.use_row_cache = num_states <= 256
    if qtable.use_row_cache {
        for i in 0..<min(num_states, 256) {
            start_idx := i * qtable.state_stride
            end_idx := start_idx + qtable.state_stride
            qtable.state_rows[i] = qtable.data[start_idx:end_idx]
        }
    }
    fmt.printf("Q-table: %dx%d, SIMD: %s (width: %d), Cache: %s, RowCache: %s\n",
               num_states, num_actions,
               qtable.simd_enabled ? "enabled" : "disabled", SIMD_WIDTH,
               qtable.max_cache != nil ? "enabled" : "disabled",
               qtable.use_row_cache ? "enabled" : "disabled")
    return qtable
}

align :: proc($T: typeid, count: int, alignment: int, allocator := context.allocator) -> T {
    // Odin has no built-in aligned alloc, so we'll allocate extra space and align manually
    size := size_of(T)
    total := count * size
    extra := alignment - 1
    
    raw_ptr, err := mem.alloc(total + extra, alignment, allocator)
    if err != nil {
        fmt.eprintln("Error allocating aligned memory:", err)
        return nil
    }
    if raw_ptr == nil do return nil
    
    aligned_ptr := uintptr(raw_ptr)
    aligned_ptr = (aligned_ptr + uintptr(alignment - 1)) & ~uintptr(alignment - 1)
    
    return mem.slice_ptr(cast(^f32)aligned_ptr, count)
}

destroy_qtable :: proc(qtable: ^QTable) {
    if qtable == nil do return
    
    delete(qtable.data, qtable.allocator)
    delete(qtable.max_cache, qtable.allocator)
    delete(qtable.best_action, qtable.allocator)
    delete(qtable.cache_valid, qtable.allocator)
    free(qtable, qtable.allocator)
}

// Fast state row access
get_state_row_fast :: proc(qtable: ^QTable, state: int) -> []f32 {
    if state < 0 || state >= qtable.num_states do return nil
    
    // Use cached row if exist
    if qtable.use_row_cache && state < 256 {
        return qtable.state_rows[state]
    }
    // Check last accessed state
    if qtable.last_state_id == state && qtable.last_state_ptr != nil {
        return qtable.last_state_ptr
    }
    start_idx := state * qtable.state_stride
    end_idx := start_idx + qtable.state_stride
    row := qtable.data[start_idx:end_idx]
    
    // Cache for next access
    qtable.last_state_id = state
    qtable.last_state_ptr = row
    
    return row
}

// Fast Q-value access
get_q_value_fast :: proc(qtable: ^QTable, state: int, action: int) -> f32 {
    if state < 0 || state >= qtable.num_states || action < 0 || action >= qtable.num_actions {
        return 0
    }
    state_data := get_state_row_fast(qtable, state)
    return state_data[action]
}

// Fast Q-value update
set_q_value_fast :: proc(qtable: ^QTable, state: int, action: int, value: f32) {
    if state < 0 || state >= qtable.num_states || action < 0 || action >= qtable.num_actions {
        return
    }
    state_data := get_state_row_fast(qtable, state)
    state_data[action] = value
    
    // Invalidate cache for this state
    invalidate_state_cache(qtable, state)
}

// Helper to create an index vector for SIMD operations
iota :: proc ($V: typeid/#simd[$N]$E) -> (result: V) {
    for i in 0..<N {
        result = simd.replace(result, i, E(i))
    }
    return
}

simd_max_in_row :: proc(qtable: ^QTable, state: int) -> f32 {
    if state < 0 || state >= qtable.num_states {
        return 0
    }
    g_perf_counters.simd_ops += 1
    
    state_data := get_state_row_fast(qtable, state)
    num_actions := qtable.num_actions
    
    if !qtable.simd_enabled || num_actions < SIMD_WIDTH {
        // Fixed scalar fallback - find MAX VALUE, not index!
        max_q := state_data[0]
        for i in 1..<num_actions {
            if state_data[i] > max_q {
                max_q = state_data[i]
            }
        }
        return max_q  // Return the VALUE, not the index
    }
    
    // Init with first value repeated across vector
    max_vec: #simd[SIMD_WIDTH]f32 = state_data[0]
    data := state_data
    
    // Process full SIMD_WIDTH chunks
    for len(data) >= SIMD_WIDTH {
        chunk_ptr := cast(^#simd[SIMD_WIDTH]f32)raw_data(data)
        data = data[SIMD_WIDTH:]
        
        // Use unaligned load to be safe
        chunk := intrinsics.unaligned_load(chunk_ptr)
        max_vec = simd.max(max_vec, chunk)
    }
    
    // Reduce vector to single max value
    result := simd.reduce_max(max_vec)
    
    // Handle remaining elements in scalar fashion
    for x in data {
        if x > result {
            result = x
        }
    }
    
    return result
}

simd_argmax_in_row :: proc(qtable: ^QTable, state: int) -> int {
    if state < 0 || state >= qtable.num_states {
        return 0
    }
    
    state_data := get_state_row_fast(qtable, state)
    if len(state_data) == 0 {
        return 0
    }
    
    // Debug print to inspect state_data
    // fmt.printf("simd_argmax_in_row for state %d: values = %v\n", state, state_data)

    // Just use simple scalar implementation - argmax doesn't benefit much from SIMD
    max_q := state_data[0]
    best_action := 0
    
    for i in 1..<qtable.num_actions {
        if state_data[i] > max_q {
            max_q = state_data[i]
            best_action = i
        }
    }
    
    return best_action
}

// Fixed: When max_q is calculated, best_action should also be cached.
get_max_q_value_cached :: proc(qtable: ^QTable, state: int) -> f32 {
    if state < 0 || state >= qtable.num_states {
        return 0
    }
    g_perf_counters.total_access += 1
    
    // Check cache if exist
    if qtable.cache_valid != nil && qtable.cache_valid[state] {
        g_perf_counters.cache_hits += 1
        return qtable.max_cache[state]
    }
    g_perf_counters.cache_miss += 1
    
    // Calculate max Q-value and best action
    max_q := simd_max_in_row(qtable, state)
    best_action_idx := simd_argmax_in_row(qtable, state) // Calculate best action index here
    
    // Cache result
    if qtable.max_cache != nil && qtable.best_action != nil { // Ensure both cache arrays are allocated
        qtable.max_cache[state] = max_q
        qtable.best_action[state] = best_action_idx // Store the best action index
        qtable.cache_valid[state] = true
    }
    return max_q
}

// Fixed: When best_action is calculated, max_q_value should also be cached.
get_best_action :: proc(qtable: ^QTable, state: int) -> (best_action: int) {
    if state < 0 || state >= qtable.num_states { return 0 }
    g_perf_counters.total_access += 1

    // Check cache if available
    if qtable.cache_valid != nil && qtable.cache_valid[state] {
        g_perf_counters.cache_hits += 1
        return qtable.best_action[state]
    }
    g_perf_counters.cache_miss += 1

    // Calculate best action and max Q-value
    best_action = simd_argmax_in_row(qtable, state)
    max_q := simd_max_in_row(qtable, state) // Calculate max Q value here
    
    // Cache result
    if qtable.best_action != nil && qtable.max_cache != nil { // Ensure both cache arrays are allocated
        qtable.best_action[state] = best_action
        qtable.max_cache[state] = max_q // Store the max Q value
        qtable.cache_valid[state] = true
    }
    return
}

// Cache invalidation
invalidate_state_cache :: proc(qtable: ^QTable, state: int) {
    if qtable.cache_valid == nil || state < 0 || state >= qtable.num_states {
        return
    }
    qtable.cache_valid[state] = false
}

invalidate_all_cache :: proc(qtable: ^QTable) {
    if qtable.cache_valid == nil do return
    slice.fill(qtable.cache_valid, false)
}

// Batch operations for performance
batch_update_q_values :: proc(qtable: ^QTable, states: []int, actions: []int, values: []f32) {
    if len(states) != len(actions) || len(states) != len(values) do return
    
    g_perf_counters.batch_ops += 1
    
    for i in 0..<len(states) {
        state := states[i]
        action := actions[i]
        
        if state >= 0 && state < qtable.num_states && action >= 0 && action < qtable.num_actions {
            set_q_value_fast(qtable, state, action, values[i])
        }
    }
}

batch_get_q_values :: proc(qtable: ^QTable, states: []int, actions: []int, values: []f32) {
    if len(states) != len(actions) || len(states) != len(values) do return
    
    g_perf_counters.batch_ops += 1
    
    for i in 0..<len(states) {
        state := states[i]
        action := actions[i]
        
        if state >= 0 && state < qtable.num_states && action >= 0 && action < qtable.num_actions {
            values[i] = get_q_value_fast(qtable, state, action)
        } else {
            values[i] = 0
        }
    }
}

batch_get_max_q_values :: proc(qtable: ^QTable, states: []int, max_values: []f32) {
    if len(states) != len(max_values) do return
    
    g_perf_counters.batch_ops += 1
    
    for i in 0..<len(states) {
        max_values[i] = get_max_q_value_cached(qtable, states[i])
    }
}

// SIMD row update - improved version following proper patterns
simd_update_state_row :: proc(qtable: ^QTable, state: int, new_values: []f32) {
    if state < 0 || state >= qtable.num_states || len(new_values) != qtable.num_actions {
        return
    }
    
    state_data := get_state_row_fast(qtable, state)
    
    if !qtable.simd_enabled || qtable.num_actions < SIMD_WIDTH {
        // Scalar fallback
        copy(state_data, new_values)
        invalidate_state_cache(qtable, state)
        return
    }
    
    g_perf_counters.simd_ops += 1
    
    src := new_values
    dst := state_data
    
    // Process full SIMD_WIDTH chunks
    for len(src) >= SIMD_WIDTH && len(dst) >= SIMD_WIDTH {
        src_ptr := cast(^#simd[SIMD_WIDTH]f32)raw_data(src)
        dst_ptr := cast(^#simd[SIMD_WIDTH]f32)raw_data(dst)
        
        // Load source data
        chunk := intrinsics.unaligned_load(src_ptr)
        
        // Store to destination
        intrinsics.unaligned_store(dst_ptr, chunk)
        
        src = src[SIMD_WIDTH:]
        dst = dst[SIMD_WIDTH:]
    }
    
    // Handle remaining elements
    copy(dst, src)
    
    // Invalidate cache for this state
    invalidate_state_cache(qtable, state)
}

reset_perf_counters :: proc() {
    g_perf_counters = {}
}

get_perf_counters :: proc() -> Perf_Counters {
    return g_perf_counters
}

calculate_cache_hit_ratio :: proc() -> f32 {
    total_cache_accesses := g_perf_counters.cache_hits + g_perf_counters.cache_miss
    if total_cache_accesses == 0 do return 0
    
    return f32(g_perf_counters.cache_hits) / f32(total_cache_accesses) * 100
}

print_perf_stats :: proc() {
    fmt.println("\nQ-Table Performance Stats:")
    fmt.printf("Total: %d\n", g_perf_counters.total_access)
    fmt.printf("Cache hits: %d\n", g_perf_counters.cache_hits)
    fmt.printf("Cache misses: %d\n", g_perf_counters.cache_miss)
    fmt.printf("Cache hit ratio: %.2f%%\n", calculate_cache_hit_ratio()) 
    fmt.printf("Batch ops: %d\n", g_perf_counters.batch_ops)
    fmt.printf("SIMD ops: %d\n\n", g_perf_counters.simd_ops)
}

qtable_wrap_for_agent :: proc(num_states: int, num_actions: int, allocator := context.allocator) -> ^QTable_Wrapper {
    wrapper := new(QTable_Wrapper, allocator)
    
    hints := Access_Pattern{
        freq_max_queries = true,
        sequential_access = false,
        batch_updates = false,
        cachable = true,
    }
    wrapper.qtable = new_qtable(num_states, num_actions, .ALIGNED, hints, allocator)
    if wrapper.qtable == nil {
        free(wrapper, allocator)
        return nil
    }
    wrapper.counters = new(Perf_Counters, allocator)
    wrapper.counters^ = {}
    
    return wrapper
}

destroy_qtable_wrapper :: proc(w: ^QTable_Wrapper) {
    if w == nil do return
    
    destroy_qtable(w.qtable)
    free(w.counters, w.qtable.allocator)
    free(w, w.qtable.allocator)
}

qtable_get_value :: proc(w: ^QTable_Wrapper, state: int, action: int) -> f32 {
    if w == nil || w.qtable == nil do return 0
    return get_q_value_fast(w.qtable, state, action)
}

qtable_set_value :: proc(w: ^QTable_Wrapper, state: int, action: int, value: f32) {
    if w == nil || w.qtable == nil do return
    set_q_value_fast(w.qtable, state, action, value)
}

qtable_get_best_action :: proc(q: ^QTable_Wrapper, state: int) -> int {
    if q == nil || q.qtable == nil do return 0
    return get_best_action(q.qtable, state)
}

qtable_get_max_value :: proc(w: ^QTable_Wrapper, state: int) -> f32 {
    if w == nil || w.qtable == nil do return 0
    return get_max_q_value_cached(w.qtable, state)
}

// Raylib integration helpers
qtable_draw :: proc(qtable: ^QTable, x, y, width, height: i32) {
    if qtable == nil || qtable.data == nil do return
    
    cell_width := width / i32(qtable.num_actions)
    cell_height := height / i32(qtable.num_states)
    
    // Find min/max values for normalization
    min_v, max_v := qtable.data[0], qtable.data[0]
    for val in qtable.data {
        if val < min_v do min_v = val
        if val > max_v do max_v = val
    }
    range_val := max_v - min_v
    if range_val == 0 do range_val = 1
    
    for state in 0..<qtable.num_states {
        for action in 0..<qtable.num_actions {
            val := get_q_value_fast(qtable, state, action)
            norm := (val - min_v) / range_val
            
            // Color based on value (blue to red gradient)
            color := rl.Color{ u8(norm * 255), 0, u8((1 - norm) * 255), 255 }
            
            rect_x := x + i32(action) * cell_width
            rect_y := y + i32(state) * cell_height
            
            rl.DrawRectangle(rect_x, rect_y, cell_width, cell_height, color)
            rl.DrawRectangleLines(rect_x, rect_y, cell_width, cell_height, rl.WHITE)
        }
    }
}
