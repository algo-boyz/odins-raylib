package qlearn

import "core:fmt"
import "core:math"
import "core:math/rand"
import "core:mem"
import "core:slice"
import "core:os"
import rl "vendor:raylib" // Assuming this is needed for Action enum or similar
import "core:testing" // Added for the test

TEST_NUM_STATES :: 10
TEST_NUM_ACTIONS :: 4

Q_Agent :: struct {
    num_states,
    num_actions,
    current_state:   int,
    learning_rate,
    discount_factor,
    epsilon,
    epsilon_decay,
    epsilon_min:     f32,
    last_action:     Action,
    q_table:         [][]f32,
}

Experience :: struct {
    action:     Action,
    state,
    next_state: int,
    reward,
    td_err,
    priority:   f32,
    done:       bool,
    timestamp:  u64,
}

// Experience Buffer for basic replay
Experience_Buffer :: struct {
    experiences: []Experience,
    capacity,
    size,
    curr_idx,
    replay_batch_size: int,
    // For prioritized replay
    priorities:        []f32,
    heap:              []int,
    alpha,
    beta,
    beta_increment,
    max_priority,
    min_priority:      f32,
    global_step:       u64,
}

Replay_Config :: struct {
    enabled:           bool,
    buf_size,
    batch_size,
    replay_frequency,
    beta_anneal_steps: int,
    priority_alpha,
    priority_beta_start,
    priority_beta_end,
    min_priority:      f32,
}

// Create new Q-learning agent
new_agent :: proc(num_states, num_actions: int, learning_rate, discount_factor, epsilon: f32, allocator := context.allocator) -> ^Q_Agent {
    if num_states <= 0 || num_actions <= 0 {
        fmt.eprintln("Error: Number of states and actions must be greater than 0")
        return nil
    }
    if learning_rate <= 0 || discount_factor < 0 || epsilon < 0 || epsilon > 1 {
        fmt.eprintln("Error: Invalid parameters for agent creation")
        return nil
    }
    agent := new(Q_Agent, allocator)
    
    agent.num_states = num_states
    agent.num_actions = num_actions
    agent.learning_rate = learning_rate
    agent.discount_factor = discount_factor
    agent.epsilon = epsilon
    agent.epsilon_decay = 0.995
    agent.epsilon_min = 0.01
    agent.current_state = 0
    agent.last_action = .UP
    
    // Alloc Q-table
    agent.q_table = make([][]f32, num_states, allocator)
    for i in 0..<num_states {
        agent.q_table[i] = make([]f32, num_actions, allocator)
    }
    return agent
}

destroy_agent :: proc(agent: ^Q_Agent, allocator := context.allocator) {
    if agent == nil do return
    
    for row in agent.q_table {
        delete(row, allocator)
    }
    delete(agent.q_table, allocator)
    free(agent, allocator)
}

// Select action using epsilon-greedy strategy
select_action :: proc(agent: ^Q_Agent, state: int) -> Action {
    if agent == nil || state < 0 || state >= agent.num_states {
        return .UP
    }
    agent.current_state = state
    random_val := rand.float32()
    
    if random_val < agent.epsilon {
        // Explore: choose random action
        return Action(rand.int_max(int(agent.num_actions)))
    } else {
        // Exploit: choose greedy action
        return select_greedy_action(agent, state)
    }
}

// Select greedy action (highest Q-value)
select_greedy_action :: proc(agent: ^Q_Agent, state: int) -> Action {
    if agent == nil || state < 0 || state >= agent.num_states {
        return .UP
    }
    best_action := Action.UP
    best_q_val := agent.q_table[state][0]
    
    for action in 1..<agent.num_actions {
        if agent.q_table[state][action] > best_q_val {
            best_q_val = agent.q_table[state][action]
            best_action = Action(action)
        }
    }
    return best_action
}

// Update Q-value using Q-learning formula
update_q_value :: proc(agent: ^Q_Agent, tracker: ^State_Tracker, state: int, action: Action, reward: f32, next_state: int, done: bool) {
    if agent == nil || state < 0 || state >= agent.num_states || 
       next_state < 0 || next_state>= agent.num_states ||
       int(action) < 0 || int(action) >= agent.num_actions {
        return
    }
    current_q := agent.q_table[state][action]
    max_next_q: f32
    
    // Get adaptive learning rate for this state
    learning_rate := agent.learning_rate
    if tracker != nil {
        learning_rate = get_state_learning_rate(tracker, state, agent.learning_rate)
    }

    // Add exploration bonus to reward for less-visited states
    enhanced_reward := reward
    if tracker != nil {
        enhanced_reward += get_exploration_bonus(tracker, state)
    }

    // If not terminal state, find max Q-value for next state
    if !done {
        max_next_q = agent.q_table[next_state][0]
        for a in 1..<agent.num_actions {
            if agent.q_table[next_state][a] > max_next_q {
                max_next_q = agent.q_table[next_state][a]
            }
        }
    }
    // Q-learning formula: Q(s,a) = Q(s,a) + α[r + γ*max(Q(s',a')) - Q(s,a)]
    td_target := enhanced_reward + agent.discount_factor * max_next_q
    td_error := td_target - current_q
    agent.q_table[state][action] = current_q + learning_rate * td_error
    agent.last_action = action
}

// Decay epsilon for exploration reduction over time
decay_epsilon :: proc(agent: ^Q_Agent) {
    if agent == nil do return
    agent.epsilon *= agent.epsilon_decay
    if agent.epsilon < agent.epsilon_min {
        agent.epsilon = agent.epsilon_min
    }
}

// Get Q-value for state-action pair
get_q_value :: proc(agent: ^Q_Agent, state: int, action: Action) -> f32 {
    if agent == nil || state < 0 || state >= agent.num_states || 
       int(action) < 0 || int(action) >= agent.num_actions {
        return 0
    }
    return agent.q_table[state][action]
}

// Set Q-value for state-action pair
set_q_value :: proc(agent: ^Q_Agent, state: int, action: Action, value: f32) {
    if agent == nil || state < 0 || state >= agent.num_states || 
       int(action) < 0 || int(action) >= agent.num_actions {
        return
    }
    agent.q_table[state][action] = value
}

// Create new experience buffer
new_experience_buffer :: proc(capacity: int, allocator := context.allocator) -> ^Experience_Buffer {
    if capacity <= 0 {
        fmt.eprintln("Error: Experience buffer capacity must be greater than 0")
        return nil
    }
    buf := new(Experience_Buffer, allocator)
    buf.experiences = make([]Experience, capacity, allocator)
    buf.capacity = capacity
    buf.size = 0
    buf.curr_idx = 0
    return buf
}

// Destroy experience buffer
destroy_experience_buffer :: proc(buf: ^Experience_Buffer, allocator := context.allocator) {
    if buf == nil do return
    delete(buf.experiences, allocator)
    if buf.priorities != nil do delete(buf.priorities, allocator)
    if buf.heap != nil do delete(buf.heap, allocator)
    free(buf, allocator)
}

// Add experience to buffer
add_experience :: proc(buf: ^Experience_Buffer, state: int, action: Action, reward: f32, next_state: int, done: bool, td_err: f32) {
    if buf == nil do return
    
    buf.experiences[buf.curr_idx] = Experience{
        state = state,
        action = action,
        reward = reward,
        next_state = next_state,
        done = done,
        td_err = td_err,
        timestamp = buf.global_step,
    }
    
    // Calculate priority with higher precision
    priority := math.max(math.abs(td_err), buf.min_priority)
    priority = math.pow(priority, buf.alpha)
    buf.priorities[buf.curr_idx] = priority
    
    buf.curr_idx = (buf.curr_idx + 1) % buf.capacity
    if buf.size < buf.capacity {
        buf.size += 1
    }
    // Always recalculate max priority for precision (less efficient but more accurate)
    recalculate_max_priority(buf)
    
    buf.global_step += 1
}

recalculate_max_priority :: proc(buf: ^Experience_Buffer) {
    buf.max_priority = buf.min_priority
    for i in 0..<buf.size {
        if buf.priorities[i] > buf.max_priority {
            buf.max_priority = buf.priorities[i]
        }
    }
}

// Sample random experience from buffer
sample_experience :: proc(buf: ^Experience_Buffer) -> ^Experience {
    if buf == nil || buf.size == 0 do return nil
    idx := rand.int_max(buf.size)
    return &buf.experiences[idx]
}

// Calculate moving average of values
calc_moving_avg :: proc(values: []f32, start, count: int) -> f32 {
    if len(values) == 0 || count <= 0 do return 0
    
    sum: f32
    for i in start..<start + count {
        if i < len(values) {
            sum += values[i]
        }
    }
    return sum / f32(count)
}

// Calculate variance of Q-values
calc_q_val_variance :: proc(agent: ^Q_Agent) -> f32 {
    if agent == nil do return 0
    // Calculate mean Q-value
    sum: f32
    total_entries := agent.num_states * agent.num_actions
    
    for s in 0..<agent.num_states {
        for a in 0..<agent.num_actions {
            sum += agent.q_table[s][a]
        }
    }
    mean := sum / f32(total_entries)
    
    // Calculate variance
    variance_sum: f32
    for s in 0..<agent.num_states {
        for a in 0..<agent.num_actions {
            diff := agent.q_table[s][a] - mean
            variance_sum += diff * diff
        }
    }
    return variance_sum / f32(total_entries)
}

// Create default replay configuration
new_default_replay_config :: proc() -> Replay_Config {
    return Replay_Config{
        enabled = true,
        buf_size = 10000,
        batch_size = 32,
        replay_frequency = 4,
        priority_alpha = 0.6,
        priority_beta_start = 0.4,
        priority_beta_end = 1.0,
        beta_anneal_steps = 100000,
        min_priority = 1e-6,
    }
}

// Create custom replay configuration
new_replay_config :: proc(enabled: bool, buf_size, batch_size, replay_frequency: int, 
                         prio_alpha, prio_beta_start, prio_beta_end: f32, 
                         beta_anneal_steps: int, min_priority: f32) -> Replay_Config {
    return Replay_Config{
        enabled = enabled,
        buf_size = buf_size,
        batch_size = batch_size,
        replay_frequency = replay_frequency,
        priority_alpha = prio_alpha,
        priority_beta_start = prio_beta_start,
        priority_beta_end = prio_beta_end,
        beta_anneal_steps = beta_anneal_steps,
        min_priority = min_priority,
    }
}

// Heap operations for prioritized replay
heap_up :: proc(buf: ^Experience_Buffer, idx: int) {
    if idx == 0 do return
    
    parent := (idx - 1) / 2
    heap_idx := buf.heap[idx]
    parent_idx := buf.heap[parent]
    
    if buf.priorities[heap_idx] > buf.priorities[parent_idx] {
        buf.heap[idx] = parent_idx
        buf.heap[parent] = heap_idx
        heap_up(buf, parent)
    }
}

heap_down :: proc(buf: ^Experience_Buffer, idx: int) {
    left := 2 * idx + 1
    right := 2 * idx + 2
    largest := idx
    
    if left < buf.size {
        left_heap_idx := buf.heap[left]
        largest_heap_idx := buf.heap[largest]
        if buf.priorities[left_heap_idx] > buf.priorities[largest_heap_idx] {
            largest = left
        }
    }
    if right < buf.size {
        right_heap_idx := buf.heap[right]
        largest_heap_idx := buf.heap[largest]
        if buf.priorities[right_heap_idx] > buf.priorities[largest_heap_idx] {
            largest = right
        }
    }
    if largest != idx {
        buf.heap[idx], buf.heap[largest] = buf.heap[largest], buf.heap[idx]
        heap_down(buf, largest)
    }
}

// Create new prioritized experience buffer
new_prio_buffer :: proc(capacity: int, config: Replay_Config, allocator := context.allocator) -> ^Experience_Buffer {
    buf := new(Experience_Buffer, allocator)
    buf.experiences = make([]Experience, capacity, allocator)
    buf.priorities = make([]f32, capacity, allocator)
    buf.heap = make([]int, capacity, allocator)
    
    buf.capacity = capacity
    buf.size = 0
    buf.curr_idx = 0
    buf.alpha = config.priority_alpha
    buf.beta = config.priority_beta_start
    buf.beta_increment = (config.priority_beta_end - config.priority_beta_start) / f32(config.beta_anneal_steps)
    buf.max_priority = config.min_priority  // Initialize to min_priority instead of 1.0
    buf.min_priority = config.min_priority
    buf.replay_batch_size = config.batch_size
    buf.global_step = 0
    
    // Init priorities to min val
    for i in 0..<capacity {
        buf.priorities[i] = buf.min_priority
    }
    return buf
}

// Add experience with priority
add_priority_experience :: proc(buf: ^Experience_Buffer, state: int, action: Action, reward: f32, next_state: int, done: bool, td_err: f32) {
    if buf == nil do return
    
    buf.experiences[buf.curr_idx] = Experience{
        state = state,
        action = action,
        reward = reward,
        next_state = next_state,
        done = done,
        td_err = td_err,
        timestamp = buf.global_step,
    }
    // Calculate priority from TD error
    priority := math.pow(math.abs(td_err) + buf.min_priority, buf.alpha)
    buf.experiences[buf.curr_idx].priority = priority
    buf.priorities[buf.curr_idx] = priority
    // Update priority in the priority array
    buf.priorities[buf.curr_idx] = priority
    buf.global_step += 1
    // Update max priority (recalculate if this is the first experience or if overwrite)
    if (buf.size == 0 || priority > buf.max_priority) {
        buf.max_priority = priority
    } else if (buf.size >= buf.capacity && buf.curr_idx < buf.size) {
        // Overwriting max priority experience -> recalculate max
        buf.max_priority = buf.priorities[0]
        for i := 1; i < buf.size; i += 1 {
            if (buf.priorities[i] > buf.max_priority) {
                buf.max_priority = buf.priorities[i]
            }
        }
    }
    buf.curr_idx = (buf.curr_idx + 1) % buf.capacity
    if buf.size < buf.capacity {
        buf.size += 1
    }
}

// Calculate importance sampling weight
calc_importance_weight :: proc(buf: ^Experience_Buffer, idx: int) -> f32 {
    if buf == nil || idx < 0 || idx >= buf.size do return 1.0
    return math.pow(buf.priorities[idx] / buf.max_priority * f32(buf.size), -buf.beta)
}

// Update beta for importance sampling annealing
update_beta :: proc(buf: ^Experience_Buffer) {
    if buf == nil do return
    buf.beta = min(buf.beta + buf.beta_increment, 1.0)
}

// Sample prioritized batch with importance weights
sample_prio_batch :: proc(buf: ^Experience_Buffer, batch_size: int, allocator := context.allocator) -> (batch: []Experience, indices: []int, weights: []f32) {
    if buf == nil || buf.size == 0 || batch_size <= 0 do return nil, nil, nil
    
    batch = make([]Experience, batch_size, allocator)
    indices = make([]int, batch_size, allocator)
    weights = make([]f32, batch_size, allocator)
    
    // Calculate total priority sum
    total_priority: f32
    for i in 0..<buf.size {
        total_priority += buf.priorities[i]
    }
    // Sample experiences based on priority
    for i in 0..<batch_size {
        random_val := rand.float32() * total_priority
        cumulative_priority: f32
        selected_index := 0
        
        for j in 0..<buf.size {
            cumulative_priority += buf.priorities[j]
            if cumulative_priority >= random_val {
                selected_index = j
                break
            }
        }
        indices[i] = selected_index
        batch[i] = buf.experiences[selected_index]
        weights[i] = calc_importance_weight(buf, selected_index)
    }
    return
}

// Update experience priorities based on TD errors
update_experience_prios :: proc(buf: ^Experience_Buffer, indices: []int, td_errs: []f32) {
    if buf == nil || len(indices) != len(td_errs) do return
    
    for i in 0..<len(indices) {
        idx := indices[i]
        if idx >= 0 && idx < buf.size {
            new_prio := math.pow(math.abs(td_errs[i]) + buf.min_priority, buf.alpha)
            buf.priorities[idx] = new_prio
            buf.experiences[idx].td_err = td_errs[i]
            buf.experiences[idx].priority = new_prio
            
            if new_prio > buf.max_priority {
                buf.max_priority = new_prio
            }
        }
    }
}

// Calculate TD error for experience
calc_td_err :: proc(agent: ^Q_Agent, exp: ^Experience) -> f32 {
    if agent == nil || exp == nil do return 0
    
    current_q := get_q_value(agent, exp.state, exp.action)
    max_next_q: f32
    
    if !exp.done {
        for a in 0..<agent.num_actions {
            q_val := get_q_value(agent, exp.next_state, Action(a))
            if a == 0 || q_val > max_next_q {
                max_next_q = q_val
            }
        }
    }
    return (exp.reward + agent.discount_factor * max_next_q) - current_q
}

// Replay batch of experiences with importance sampling
replay_batch_experiences :: proc(agent: ^Q_Agent, batch: []Experience, importance_weights: []f32) {
    if agent == nil || len(batch) != len(importance_weights) do return
    
    for i in 0..<len(batch) {
        exp := &batch[i]
        current_q := get_q_value(agent, exp.state, exp.action)
        max_next_q: f32
        
        if !exp.done {
            for a in 0..<agent.num_actions {
                q_val := get_q_value(agent, exp.next_state, Action(a))
                if a == 0 || q_val > max_next_q {
                    max_next_q = q_val
                }
            }
        }
        td_error := (exp.reward + agent.discount_factor * max_next_q) - current_q
        
        // Apply importance sampling weight to learning rate
        weighted_lr := agent.learning_rate * importance_weights[i]
        set_q_value(agent, exp.state, exp.action, current_q + weighted_lr * td_error)
    }
}

// Save Q-table to file (placeholder implementation)
save_q_table_to :: proc(agent: ^Q_Agent, filename: string) -> bool {
    fmt.printf("Q-table saved to %s\n", filename)
    // TODO: Implement binary file saving
    return true
}

// Load Q-table from file (placeholder implementation)
load_q_table :: proc(agent: ^Q_Agent, filename: string) -> bool {
    fmt.printf("Q-table loaded from %s\n", filename)
    // TODO: Implement binary file loading
    return true
}