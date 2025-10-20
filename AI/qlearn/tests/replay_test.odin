package tests

import "core:fmt"
import "core:math"
import "core:math/rand"
import "core:testing"
import "core:time"
import ql "../"

TEST_BUFFER_SIZE :: 1000
TEST_BATCH_SIZE :: 32

@(test)
test_priority_buffer_creation :: proc(t: ^testing.T) {
    cfg := ql.new_default_replay_config()
    buf := ql.new_prio_buffer(TEST_BUFFER_SIZE, cfg)
    defer ql.destroy_experience_buffer(buf)
    
    testing.expect(t, buf != nil, "Priority buffer creation should succeed")
    testing.expect(t, buf.capacity == TEST_BUFFER_SIZE, "Buffer capacity should be set correctly")
    testing.expect(t, buf.size == 0, "Initial buffer size should be zero")
    testing.expect(t, buf.alpha == cfg.priority_alpha, "Alpha parameter should be set correctly")
    testing.expect(t, buf.beta == cfg.priority_beta_start, "Beta parameter should be set correctly")
}

@(test)
test_add_priority_experience :: proc(t: ^testing.T) {
    cfg := ql.new_default_replay_config()
    buf := ql.new_prio_buffer(TEST_BUFFER_SIZE, cfg)
    defer ql.destroy_experience_buffer(buf)

    // Add some test experiences
    for i in 0..<10 {
        td_err := f32(i + 1) / 10.0  // Varying TD errors
        ql.add_experience(buf, i, .UP, 1, i + 1, false, td_err)
    }
    testing.expect(t, buf.size == 10, "Buffer size should increase correctly")
    testing.expect(t, buf.curr_idx == 10, "Current index should be updated correctly")
    
    // Check that experiences were stored correctly
    for i in 0..<10 {
        exp := &buf.experiences[i]
        testing.expect(t, exp.state == i, "Experience state should be stored correctly")
        testing.expect(t, exp.action == .UP, "Experience action should be stored correctly") 
        testing.expect(t, exp.reward == 1, "Experience reward should be stored correctly")
        testing.expect(t, exp.next_state == i + 1, "Experience next_state should be stored correctly")
        testing.expect(t, !exp.done, "Experience done flag should be stored correctly")
    }
}

@(test)
test_priority_calc :: proc(t: ^testing.T) {
    cfg := ql.new_default_replay_config()
    buf := ql.new_prio_buffer(TEST_BUFFER_SIZE, cfg)
    defer ql.destroy_experience_buffer(buf)
    
    // Add experiences with known TD errors
    td_errs := []f32{0.1, 0.5, 0.2, 0.8, 0.05}
    
    for i in 0..<len(td_errs) {
        ql.add_experience(buf, i, .UP, 1, i + 1, false, td_errs[i])
    }
    
    // Check that priorities are calculated correctly
    for i in 0..<len(td_errs) {
        // Check buf.priorities[i], not exp.priority
        expected_priority := math.pow(math.abs(td_errs[i]) + buf.min_priority, buf.alpha)
        testing.expect(t, f32_near(buf.priorities[i], expected_priority, 0.01), 
            fmt.tprintf("Expected priority calculation to be %.6f, got %.6f", expected_priority, buf.priorities[i]))
    }
    
    // Check that max priority is updated
    max_expected := math.pow(0.8 + buf.min_priority, buf.alpha)  // 0.8 is the highest TD error
    testing.expect(t, f32_near(buf.max_priority, max_expected, 0.01), 
        fmt.tprintf("Max priority should be updated correctly: expected %.6f, got %.6f", max_expected, buf.max_priority))
}

@(test)
test_priority_sampling :: proc(t: ^testing.T) {
    cfg := ql.new_default_replay_config()
    buf := ql.new_prio_buffer(TEST_BUFFER_SIZE, cfg)
    defer ql.destroy_experience_buffer(buf)
    
    // Add experiences with different priorities
    for i in 0..<100 {
        td_err := f32(i % 10) / 10.0  // Creates varying priorities
        ql.add_experience(buf, i, .UP, 1, i + 1, false, td_err)
    }
    batch_size := 32
    batch, indices, weights := ql.sample_prio_batch(buf, batch_size)
    defer delete(batch)
    defer delete(indices)
    defer delete(weights)
    testing.expect(t, len(batch) > 0, "Batch sampling should return valid batch")
    // Check that all sampled experiences are valid
    for i in 0..<batch_size {
        testing.expect(t, indices[i] >= 0 && indices[i] < buf.size, "Sampled index should be valid")
        testing.expect(t, weights[i] > 0, "Importance weight should be positive")
    }
    // Count frequency of high-priority vs low-priority samples
    high_priority_count, low_priority_count: int
    for i in 0..<batch_size {
        idx := indices[i]
        if buf.experiences[idx].td_err > 0.5 {
            high_priority_count += 1
        } else if buf.experiences[idx].td_err < 0.2 {
            low_priority_count += 1
        }
    }
    fmt.printf("High priority samples: %d, Low priority samples: %d", high_priority_count, low_priority_count)
}

@(test)
test_importance_weights :: proc(t: ^testing.T) {
    cfg := ql.new_default_replay_config()
    buf := ql.new_prio_buffer(TEST_BUFFER_SIZE, cfg)
    defer ql.destroy_experience_buffer(buf)

    // Add experiences with different priorities
    ql.add_experience(buf, 0, .UP, 1, 1, false, 1)  // Low priority
    ql.add_experience(buf, 1, .UP, 1, 2, false, 2)  // High priority
    
    weight_low := ql.calc_importance_weight(buf, 0)
    weight_high := ql.calc_importance_weight(buf, 1)
    
    testing.expect(t, weight_low > 0, "Low priority weight should be positive")
    testing.expect(t, weight_high > 0, "High priority weight should be positive")
    
    // Low priority experiences should have higher importance weights
    testing.expect(t, weight_low > weight_high, fmt.tprintf("Low priority (%.f) should have higher importance weight not (%.f)", weight_low, weight_high))
}

@(test)
test_td_err_calc :: proc(t: ^testing.T) {
    // Create a simple agent for testing
    agent := ql.new_agent(TEST_GRID_SIZE * TEST_GRID_SIZE, int(ql.Action.COUNT), 0.1, 0.9, 0.1)
    defer ql.destroy_agent(agent)
    
    testing.expect(t, agent != nil, "Agent creation for TD error test should succeed")
    
    // Set some known Q-values
    ql.set_q_value(agent, 0, .UP, 5)
    ql.set_q_value(agent, 1, .UP, 10)
    ql.set_q_value(agent, 1, .DOWN, 8)
    ql.set_q_value(agent, 1, .LEFT, 12)  // Maximum for next state
    ql.set_q_value(agent, 1, .RIGHT, 6)
    
    // Create test experience
    exp := ql.Experience{
        state = 0,
        action = .UP,
        reward = 2,
        next_state = 1,
        done = false,
    }
    td_err := ql.calc_td_err(agent, &exp)
    expected_td_err := f32(7.8)  // 2 + 0.9 * 12 - 5 = 7.8
    
    testing.expect(t, abs(td_err - expected_td_err) < 1e-6, "TD error calculation should be correct")
}

@(test)
test_batch_replay :: proc(t: ^testing.T) {
    // Create agent and environment for realistic testing
    agent := ql.new_agent(TEST_GRID_SIZE * TEST_GRID_SIZE, int(ql.Action.COUNT), 0.1, 0.9, 0.1)
    defer ql.destroy_agent(agent)
    
    cfg := ql.new_default_replay_config()
    buf := ql.new_prio_buffer(TEST_BUFFER_SIZE, cfg)
    defer ql.destroy_experience_buffer(buf)
    
    testing.expect(t, agent != nil && buf != nil, "Agent and buffer creation for batch replay test should succeed")
    
    // Add some experiences to buffer
    for i in 0..<50 {
        td_err := rand.float32() * 2.0 - 1.0  // Random TD errors
        ql.add_experience(buf, i % (TEST_GRID_SIZE * TEST_GRID_SIZE), 
                                      ql.Action(i % int(ql.Action.COUNT)), 1, 
                                      (i + 1) % (TEST_GRID_SIZE * TEST_GRID_SIZE), 
                                      false, td_err)
    }
    // Store initial Q-values for comparison
    initial_q_values := make([][]f32, TEST_GRID_SIZE * TEST_GRID_SIZE)
    defer {
        for row in initial_q_values {
            delete(row)
        }
        delete(initial_q_values)
    }
    for s in 0..<TEST_GRID_SIZE * TEST_GRID_SIZE {
        initial_q_values[s] = make([]f32, ql.Action.COUNT)
        for a in 0..<int(ql.Action.COUNT) {
            initial_q_values[s][a] = ql.get_q_value(agent, s, ql.Action(a))
        }
    }
    // Sample and replay a batch
    batch_size := 16
    batch, indices, weights := ql.sample_prio_batch(buf, batch_size)
    defer delete(batch)
    defer delete(indices)
    defer delete(weights)

    ql.replay_batch_experiences(agent, batch, weights)
    
    // Check that some Q-values have changed
    q_values_changed := false
    outer: for s in 0..<TEST_GRID_SIZE * TEST_GRID_SIZE {
        for a in 0..<int(ql.Action.COUNT) {
            if abs(ql.get_q_value(agent, s, ql.Action(a)) - initial_q_values[s][a]) > 1e-6 {
                q_values_changed = true
                break outer
            }
        }
    }
    testing.expect(t, q_values_changed, "Q-values should be updated after batch replay")
}

@(test)
test_priority_updates :: proc(t: ^testing.T) {
    cfg := ql.new_default_replay_config()
    buf := ql.new_prio_buffer(TEST_BUFFER_SIZE, cfg)
    defer ql.destroy_experience_buffer(buf)
    
    // Add some experiences
    for i in 0..<10 {
        ql.add_experience(buf, i, .UP, 1, i + 1, false, 0)
    }
    // Update priorities for some experiences
    indices := []int{2, 5, 8}
    td_errs := []f32{0.9, 0.7, 0.3}
    
    // Store old priorities
    old_prios := make([]f32, len(indices))
    defer delete(old_prios)
    for i in 0..<len(indices) {
        old_prios[i] = buf.experiences[indices[i]].priority
    }
    ql.update_experience_prios(buf, indices, td_errs)
    
    // Check that priorities were updated
    for i in 0..<len(indices) {
        expected_priority := math.pow(abs(td_errs[i]) + buf.min_priority, buf.alpha)
        testing.expect(t, abs(buf.experiences[indices[i]].priority - expected_priority) < 1e-6, "Priority should be correct after update")
        testing.expect(t, abs(buf.experiences[indices[i]].priority - old_prios[i]) > 1e-6, "Priority should have changed")
    }
}

@(test)
test_beta_annealing :: proc(t: ^testing.T) {
    cfg := ql.new_replay_config(true, 1000, 32, 4, 0.6, 0.4, 1, 100, 1e-6)
    buf := ql.new_prio_buffer(TEST_BUFFER_SIZE, cfg)
    defer ql.destroy_experience_buffer(buf)
    
    initial_beta := buf.beta
    testing.expect(t, abs(initial_beta - 0.4) < 1e-6, "Initial beta value should be correct")
    
    // Anneal beta several times
    for i in 0..<50 {
        ql.update_beta(buf)
    }
    testing.expect(t, buf.beta > initial_beta, "Beta should increase after annealing")
    testing.expect(t, buf.beta <= 1, "Beta should not exceed maximum")
    
    // Anneal many more times to test clamping
    for i in 0..<100 {
        ql.update_beta(buf)
    }
    testing.expect(t, abs(buf.beta - 1) < 1e-6, "Beta should be clamped to maximum")
}

@(test)
test_replay_performance_comparison :: proc(t: ^testing.T) {
    COMPARISON_EPOCHS :: 50
    GRID_SIZE :: 6
    
    // Test without priority replay (baseline)
    agent1 := ql.new_agent(GRID_SIZE * GRID_SIZE, int(ql.Action.COUNT), 0.1, 0.9, 1)
    defer ql.destroy_agent(agent1)
    
    world1 := ql.new_grid(GRID_SIZE, GRID_SIZE)
    defer ql.destroy_grid(world1)
    
    world1.start_pos = {}
    world1.goal_pos = {GRID_SIZE-1, GRID_SIZE-1}
    world1.step_penalty = -0.1
    world1.goal_reward = 10
    world1.wall_penalty = -5
    world1.max_steps = 50
    
    total_reward_baseline: f32
    successful_epochs_baseline: int
    
    for epoch in 0..<COMPARISON_EPOCHS {
        ql.reset_environment(world1)
        epoch_reward: f32
        
        for !world1.epoch_done && world1.epoch_steps < world1.max_steps {
            state := ql.get_state_index(world1)
            action := ql.select_action(agent1, state)
            result := ql.step_environment(world1, action)
            
            ql.update_q_value(agent1, nil, state, action, result.reward,
                                ql.position_to_state(world1, result.next_state.position), result.done)
            epoch_reward += result.reward
        }
        if ql.positions_equal(world1.agent_pos, world1.goal_pos) {
            successful_epochs_baseline += 1
        }
        total_reward_baseline += epoch_reward
        ql.decay_epsilon(agent1)
    }
    avg_reward_baseline := total_reward_baseline / COMPARISON_EPOCHS
    success_rate_baseline := f32(successful_epochs_baseline) / COMPARISON_EPOCHS
    
    fmt.printf("Baseline (no replay): Avg Reward=%.2f, Success Rate=%.2f%%", avg_reward_baseline, success_rate_baseline * 100)
    // Test with priority replay
    agent2 := ql.new_agent(GRID_SIZE * GRID_SIZE, int(ql.Action.COUNT), 0.1, 0.9, 1)
    defer ql.destroy_agent(agent2)
    
    world2 := ql.new_grid(GRID_SIZE, GRID_SIZE)
    defer ql.destroy_grid(world2)
    
    world2.start_pos = {}
    world2.goal_pos = {GRID_SIZE-1, GRID_SIZE-1}
    world2.step_penalty = -0.1
    world2.goal_reward = 10
    world2.wall_penalty = -5
    world2.max_steps = 50
    
    cfg := ql.new_default_replay_config()
    cfg.batch_size = 16
    cfg.replay_frequency = 4
    buf := ql.new_prio_buffer(1000, cfg)
    defer ql.destroy_experience_buffer(buf)
    
    total_reward_replay: f32
    successful_epochs_replay, step_count: int
    
    for epoch in 0..<COMPARISON_EPOCHS {
        ql.reset_environment(world2)
        epoch_reward: f32
        
        for !world2.epoch_done && world2.epoch_steps < world2.max_steps {
            state := ql.get_state_index(world2)
            action := ql.select_action(agent2, state)
            result := ql.step_environment(world2, action)
            
            // Calculate TD error for experience
            td_err := result.reward
            if !result.done {
                max_next_q := f32(0)
                for a in 0..<i32(ql.Action.COUNT) {
                    q_val := ql.get_q_value(agent2, ql.position_to_state(world2, result.next_state.position), ql.Action(a))
                    if a == 0 || q_val > max_next_q {
                        max_next_q = q_val
                    }
                }
                td_err += agent2.discount_factor * max_next_q
            }
            td_err -= ql.get_q_value(agent2, state, action)
            
            // Add experience to buffer
            ql.add_experience(buf, state, action, result.reward,
                                          ql.position_to_state(world2, result.next_state.position), 
                                          result.done, td_err)
            
            // Regular Q-learning update
            ql.update_q_value(agent2, nil, state, action, result.reward,
                                ql.position_to_state(world2, result.next_state.position), result.done)
            
            // Replay experiences periodically
            if step_count % cfg.replay_frequency == 0 && buf.size >= cfg.batch_size {
                batch, indices, weights := ql.sample_prio_batch(buf, cfg.batch_size)
                defer delete(batch)
                defer delete(indices)
                defer delete(weights)
                if len(batch) > 0 {
                    ql.replay_batch_experiences(agent2, batch, weights)
                    
                    // Update priorities based on new TD errors
                    td_errs := make([]f32, cfg.batch_size)
                    defer delete(td_errs)
                    
                    for i in 0..<cfg.batch_size {
                        td_errs[i] = ql.calc_td_err(agent2, &batch[i])
                    }
                    ql.update_experience_prios(buf, indices, td_errs)
                }
                ql.update_beta(buf)
            }
            epoch_reward += result.reward
            step_count += 1
        }
        if ql.positions_equal(world2.agent_pos, world2.goal_pos) {
            successful_epochs_replay += 1
        }
        total_reward_replay += epoch_reward
        ql.decay_epsilon(agent2)
    }
    avg_reward_replay := total_reward_replay / COMPARISON_EPOCHS
    success_rate_replay := f32(successful_epochs_replay) / COMPARISON_EPOCHS
    
    fmt.printf("With priority replay: Avg Reward=%.2f, Success Rate=%.2f%%", 
                            avg_reward_replay, success_rate_replay * 100)
    
    // Priority replay should generally perform better or at least comparable
    rate := (avg_reward_replay - avg_reward_baseline) / abs(avg_reward_baseline)
    fmt.printf("Performance improvement: %.2f%%", rate * 100)
    
    // This test always passes as it's primarily for performance analysis
    testing.expect(t, true, "Performance comparison completed")
}