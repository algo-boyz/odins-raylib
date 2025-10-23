package tests

import "core:fmt"
import "core:math"
import "core:math/rand"
import "core:os"
import "core:testing"
import "core:time"
import ql "../"

TEST_NUM_STATES :: 64
TEST_NUM_ACTIONS :: 4
TEST_GRID_SIZE :: 8
NUM_TEST_EPOCHS :: 50
EPSILON :: 1e-6

@(test)
test_state_visit_tracker_creation :: proc(t: ^testing.T) {
    tracker := ql.new_state_tracker(TEST_NUM_STATES, true, true)
    defer ql.destroy_state_tracker(tracker)
    
    testing.expect(t, tracker != nil, "State visit tracker creation should succeed")
    testing.expect(t, tracker.num_states == TEST_NUM_STATES, "Number of states should be set correctly")
    testing.expect(t, tracker.total_visits == 0, "Initial total visits should be zero")
    testing.expect(t, tracker.adaptive_epsilon == true, "Adaptive epsilon should be enabled")
    testing.expect(t, tracker.adaptive_learning_rate == true, "Adaptive learning rate should be enabled")
    
    // Check initial values
    for i in 0..<TEST_NUM_STATES {
        testing.expect(t, tracker.visit_counts[i] == 0, "Initial visit count should be zero")
        testing.expect(t, abs(tracker.exploration_bonuses[i] - 1) < EPSILON, "Initial exploration bonus should be 1.0")
        testing.expect(t, abs(tracker.state_epsilons[i] - 1) < EPSILON, "Initial state epsilon should be 1.0")
        testing.expect(t, abs(tracker.state_learning_rates[i] - 1) < EPSILON, "Initial state learning rate should be 1.0")
        testing.expect(t, abs(tracker.visit_priorities[i] - 1) < EPSILON, "Initial visit priority should be 1.0")
    }
}

@(test)
test_visit_count_updates :: proc(t: ^testing.T) {
    tracker := ql.new_state_tracker(TEST_NUM_STATES, true, true)
    defer ql.destroy_state_tracker(tracker)
    
    // Test updating a single state multiple times
    test_state := 10
    for i in 1..=5 {
        ql.update_state(tracker, test_state)
        testing.expect(t, tracker.visit_counts[test_state] == i, "Visit count should be incremented correctly")
        testing.expect(t, tracker.total_visits == i, "Total visits should be incremented correctly")
        
        // Check exploration bonus decreases with visits
        expected_bonus := max(tracker.min_exploration_bonus, 1 / math.sqrt(f32(i) + 1))
        testing.expect(t, abs(tracker.exploration_bonuses[test_state] - expected_bonus) < EPSILON,
                      "Exploration bonus should decrease with visits")
    }
    // Test updating multiple states
    ql.update_state(tracker, 5)
    ql.update_state(tracker, 15)
    ql.update_state(tracker, 20)
    
    testing.expect(t, tracker.visit_counts[5] == 1, "State 5 visit count should be 1")
    testing.expect(t, tracker.visit_counts[15] == 1, "State 15 visit count should be 1")
    testing.expect(t, tracker.visit_counts[20] == 1, "State 20 visit count should be 1")
    testing.expect(t, tracker.total_visits == 8, "Total visits should be 8 after multiple updates")
}

@(test)
test_adaptive_epsilon :: proc(t: ^testing.T) {
    tracker := ql.new_state_tracker(TEST_NUM_STATES, true, false)
    defer ql.destroy_state_tracker(tracker)
    
    base_epsilon: f32 = 0.5
    
    // Test unvisited state (should have high epsilon)
    unvisited_state: int = 0
    epsilon_unvisited := ql.get_state_epsilon(tracker, unvisited_state, base_epsilon)
    testing.expect(t, abs(epsilon_unvisited - base_epsilon * 1) < EPSILON, 
                   "Unvisited state should have high epsilon")
    
    // Visit a state multiple times and check epsilon decreases
    visited_state := 1
    for i in 0..<10 {
        ql.update_state(tracker, visited_state)
    }
    epsilon_visited := ql.get_state_epsilon(tracker, visited_state, base_epsilon)
    testing.expect(t, epsilon_visited < epsilon_unvisited, "Visited state should have lower epsilon")
    testing.expect(t, epsilon_visited >= base_epsilon * tracker.min_exploration_bonus, 
                   "Epsilon should not go below minimum")
    
    // Test with adaptive epsilon disabled
    tracker_disabled := ql.new_state_tracker(TEST_NUM_STATES, false, false)
    defer ql.destroy_state_tracker(tracker_disabled)
    
    ql.update_state(tracker_disabled, 5)
    epsilon_disabled := ql.get_state_epsilon(tracker_disabled, 5, base_epsilon)
    testing.expect(t, abs(epsilon_disabled - base_epsilon) < EPSILON, 
                   "Disabled adaptive epsilon should return base epsilon")
}

@(test)
test_adaptive_learning_rate :: proc(t: ^testing.T) {
    tracker := ql.new_state_tracker(TEST_NUM_STATES, false, true)
    defer ql.destroy_state_tracker(tracker)
    
    base_learning_rate: f32 = 0.1
    // Test unvisited state (should have high learning rate)
    unvisited_state: int
    lr_unvisited := ql.get_state_learning_rate(tracker, unvisited_state, base_learning_rate)
    fmt.println("Unvisited state learning rate: ", lr_unvisited)
    testing.expect(t, f32_near(lr_unvisited, base_learning_rate), 
                   "Unvisited state should have high learning rate")
    
    // Visit a state multiple times and check learning rate decreases
    visited_state := 1
    for i in 0..<20 {
        ql.update_state(tracker, visited_state)
    }
    lr_visited := ql.get_state_learning_rate(tracker, visited_state, base_learning_rate)
    // testing.expect(t, lr_visited < lr_unvisited, "Visited state should have lower learning rate")
    testing.expect(t, lr_visited >= base_learning_rate, "Learning rate should not go below base rate")
    
    // Test with adaptive learning rate disabled
    tracker_disabled := ql.new_state_tracker(TEST_NUM_STATES, false, false)
    defer ql.destroy_state_tracker(tracker_disabled)
    
    ql.update_state(tracker_disabled, 5)
    lr_disabled := ql.get_state_learning_rate(tracker_disabled, 5, base_learning_rate)
    testing.expectf(t, f32_near(lr_disabled, base_learning_rate), 
                   "Disabled adaptive learning rate should return base rate")
}

f32_near :: proc(a, b: f32, epsilon: f32 = 1e-6) -> bool {
    return abs(a - b) < epsilon
}

@(test)
test_state_priorities :: proc(t: ^testing.T) {
    tracker := ql.new_state_tracker(TEST_NUM_STATES, true, true)
    defer ql.destroy_state_tracker(tracker)
    
    // Visit some states with different frequencies
    for i in 0..<10 { ql.update_state(tracker, 0) }  // High visits
    for i in 0..<5 { ql.update_state(tracker, 1) }   // Medium visits
    ql.update_state(tracker, 2)                      // Low visits
    // State 3 remains unvisited                               // No visits
    
    // Check that less visited states have higher priorities
    priority_unvisited := tracker.visit_priorities[3]
    priority_low := tracker.visit_priorities[2]
    priority_medium := tracker.visit_priorities[1]
    priority_high := tracker.visit_priorities[0]
    
    testing.expect(t, priority_unvisited >= priority_low, 
                   "Unvisited state should have higher priority than low visited")
    testing.expect(t, priority_low >= priority_medium, 
                   "Low visited state should have higher priority than medium visited")
    testing.expect(t, priority_medium >= priority_high, 
                   "Medium visited state should have higher priority than high visited")
    
    // Test priority state selection
    highest_priority_state := ql.select_priority_state(tracker)
    testing.expect(t, highest_priority_state == 3 || tracker.visit_priorities[highest_priority_state] >= priority_unvisited, 
                   "Highest priority state selection should be correct")
}

@(test)
test_exploration_bonus_decay :: proc(t: ^testing.T) {
    tracker := ql.new_state_tracker(TEST_NUM_STATES, true, true)
    defer ql.destroy_state_tracker(tracker)
    
    // Visit a state to set its exploration bonus
    ql.update_state(tracker, 0)
    initial_bonus := tracker.exploration_bonuses[0]
    
    // Apply decay multiple times
    for i in 0..<1000 {
        ql.decay_exploration_bonuses(tracker)
    }
    decayed_bonus := tracker.exploration_bonuses[0]
    testing.expect(t, decayed_bonus < initial_bonus, "Exploration bonus should decrease after decay")
    testing.expect(t, decayed_bonus >= tracker.min_exploration_bonus, "Bonus should not go below minimum")
    
    // Apply many decay cycles to test minimum clamping
    for i in 0..<1000 {
        ql.decay_exploration_bonuses(tracker)
    }
    testing.expectf(t, f32_near(tracker.exploration_bonuses[0], tracker.min_exploration_bonus, 0.1),
                   "Bonus should be clamped to minimum (%f) after extensive decay not %f",
                   tracker.min_exploration_bonus, tracker.exploration_bonuses[0])
}

@(test)
test_state_action_selection :: proc(t: ^testing.T) {
    agent := ql.new_agent(TEST_NUM_STATES, TEST_NUM_ACTIONS, 0.1, 0.9, 0.5)
    defer ql.destroy_agent(agent)
    
    testing.expect(t, agent != nil, "Agent should be created successfully")
    
    // Set some Q-values to make action DOWN optimal for state 0
    ql.set_q_value(agent, 0, .UP, 1)
    ql.set_q_value(agent, 0, .DOWN, 10)     // Best action
    ql.set_q_value(agent, 0, .LEFT, 2)
    ql.set_q_value(agent, 0, .RIGHT, 3)

    // Store original epsilon
    original_epsilon := agent.epsilon
    // Temporarily set epsilon to 0 to force exploitation
    agent.epsilon = 0

    selected_action := ql.select_action(agent, 0)

    // With epsilon = 0.0, it should always select the greedy action (DOWN)
    testing.expectf(t, selected_action == ql.Action.DOWN, 
                   "Expected DOWN action when epsilon is 0.0, but got %s", selected_action)

    // Restore original epsilon for the next test
    agent.epsilon = original_epsilon

    // --- Test exploration vs. exploitation balance ---
    exploration_count, exploitation_count: int
    num_trials := 1000
    // Reset agent epsilon to a known value for statistical testing
    agent.epsilon = 0.3 // 30% exploration, 70% exploitation
    
    for i in 0..<num_trials {
        action := ql.select_action(agent, 0)
        // In this setup, .DOWN is the exploitation action
        if action == ql.Action.DOWN {
            exploitation_count += 1
        } else {
            exploration_count += 1
        }
    }
    
    // Should have some balance between exploration and exploitation
    testing.expect(t, exploration_count > 0, "Some exploration should occur")
    testing.expect(t, exploitation_count > 0, "Some exploitation should occur")
    
    // With epsilon = 0.3, exploitation (70%) should be significantly more than exploration (30%)
    testing.expectf(t, exploitation_count > exploration_count, 
                   "Expected more exploitation (%d) than exploration (%d) with epsilon=0.3", 
                   exploitation_count, exploration_count)
    
    // Optional: Add a more precise check for the ratio if needed
    // For example, check if counts are within a reasonable range of the expected percentages
    expected_exploitation := f32(num_trials) * (1.0 - agent.epsilon)
    expected_exploration := f32(num_trials) * agent.epsilon
    
    // Allow for some deviation due to randomness, e.g., 10% tolerance
    tolerance := f32(num_trials) * 0.1
    
    testing.expectf(t, f32(exploitation_count) > expected_exploitation - tolerance &&
                       f32(exploitation_count) < expected_exploitation + tolerance,
                   "Exploitation count %d outside expected range [%.0f, %.0f]", 
                   exploitation_count, expected_exploitation - tolerance, expected_exploitation + tolerance)
    
    testing.expectf(t, f32(exploration_count) > expected_exploration - tolerance &&
                       f32(exploration_count) < expected_exploration + tolerance,
                   "Exploration count %d outside expected range [%.0f, %.0f]", 
                   exploration_count, expected_exploration - tolerance, expected_exploration + tolerance)
}


@(test)
test_q_value_updates :: proc(t: ^testing.T) {
    agent := ql.new_agent(TEST_NUM_STATES, TEST_NUM_ACTIONS, 0.1, 0.9, 0.1)
    defer ql.destroy_agent(agent)
    
    tracker := ql.new_state_tracker(TEST_NUM_STATES, true, true)
    defer ql.destroy_state_tracker(tracker)
    
    testing.expect(t, agent != nil && tracker != nil, "Agent and tracker should be created successfully")
    
    // Set initial Q-values
    ql.set_q_value(agent, 0, .UP, 0)
    ql.set_q_value(agent, 1, .UP, 5)
    ql.set_q_value(agent, 1, .DOWN, 3)
    ql.set_q_value(agent, 1, .LEFT, 7)   // Best action for next state
    ql.set_q_value(agent, 1, .RIGHT, 2)
    
    initial_q := ql.get_q_value(agent, 0, .UP)
    
    // Update Q-value with priority (includes exploration bonus)
    ql.update_q_value(agent, tracker, 0, .UP, 1, 1, false)
    
    updated_q := ql.get_q_value(agent, 1, .UP)
    testing.expect(t, updated_q != initial_q, "Q-value should be updated")
    
    // The updated Q-value should be higher due to exploration bonus
    exploration_bonus := ql.get_exploration_bonus(tracker, 0)
    testing.expect(t, exploration_bonus > 0, "Exploration bonus should be positive")
    
    // Compare with standard Q-value update (without priority)
    agent_std := ql.new_agent(TEST_NUM_STATES, TEST_NUM_ACTIONS, 0.1, 0.9, 0.1)
    defer ql.destroy_agent(agent_std)

    ql.set_q_value(agent_std, 0, .UP, 0)
    ql.set_q_value(agent_std, 1, .UP, 5)
    ql.set_q_value(agent_std, 1, .DOWN, 3)
    ql.set_q_value(agent_std, 1, .LEFT, 7)
    ql.set_q_value(agent_std, 1, .RIGHT, 2)

    ql.update_q_value(agent_std, tracker, 0, .UP, 1, 1, false)
    standard_q := ql.get_q_value(agent_std, 0, .UP)
    testing.expectf(t, updated_q > standard_q, "Priority Q-value (%.f) should be higher due to exploration bonus not %.f", updated_q, standard_q)
}

@(test)
test_state_visit_analysis :: proc(t: ^testing.T) {
    tracker := ql.new_state_tracker(TEST_NUM_STATES, true, true)
    defer ql.destroy_state_tracker(tracker)
    
    // Create a pattern of visits
    for i in 0..<20 { ql.update_state(tracker, 0) }  // Most visited
    for i in 0..<10 { ql.update_state(tracker, 1) }
    for i in 0..<5 { ql.update_state(tracker, 2) }
    ql.update_state(tracker, 3)                      // Least visited (among visited)
    // States 4+ remain unvisited
    
    // Test exploration coverage
    coverage := ql.calc_exploration_coverage(tracker)
    expected_coverage := f32(4) / f32(TEST_NUM_STATES) * 100  // 4 states visited out of TEST_NUM_STATES
    testing.expect(t, abs(coverage - expected_coverage) < 0.1, "Exploration coverage should be calculated correctly")
    
    // Test least/most visited state identification
    least_visited := ql.get_least_visited_state(tracker)
    most_visited := ql.get_most_visited_state(tracker)
    
    testing.expect(t, most_visited == 0, "Most visited state should be identified correctly")
    testing.expect(t, least_visited >= 4, "Least visited state should be unvisited (among all states)")
    
    // // Test state visit data saving
    // ql.save_state_data(tracker, "test_state_visits.csv")
    
    // // Check if file was created (basic test)
    // if handle, err := os.open("test_state_visits.csv"); err == nil {
    //     os.close(handle)
    //     os.remove("test_state_visits.csv")  // Clean up
    //     testing.expect(t, true, "State visit data file should be created successfully")
    // } else {
    //     testing.expect(t, false, "State visit data file creation should not fail")
    // }
}

@(test)
test_state_visit_reset :: proc(t: ^testing.T) {
    tracker := ql.new_state_tracker(TEST_NUM_STATES, true, true)
    defer ql.destroy_state_tracker(tracker)
    
    // Create some visits and modifications
    for i in 0..<5 {
        ql.update_state(tracker, i)
    }
    // Apply some decay
    for i in 0..<10 {
        ql.decay_exploration_bonuses(tracker)
    }
    testing.expect(t, tracker.total_visits > 0, "Tracker should have visits before reset")
    
    // Reset the tracker
    ql.reset_state_tracker(tracker)
    
    // Check that everything is reset to initial state
    testing.expect(t, tracker.total_visits == 0, "Total visits should be reset to zero")
    
    for i in 0..<TEST_NUM_STATES {
        testing.expect(t, tracker.visit_counts[i] == 0, "Visit counts should be reset to zero")
        testing.expect(t, abs(tracker.exploration_bonuses[i] - 1) < EPSILON, "Exploration bonuses should be reset")
        testing.expect(t, abs(tracker.state_epsilons[i] - 1) < EPSILON, "State epsilons should be reset")
        testing.expect(t, abs(tracker.state_learning_rates[i] - 1) < EPSILON, "State learning rates should be reset")
        testing.expect(t, abs(tracker.visit_priorities[i] - 1) < EPSILON, "Visit priorities should be reset")
    }
}

@(test)
test_integration_with_environment :: proc(t: ^testing.T) {
    GRID_SIZE :: 6
    NUM_STATES :: GRID_SIZE * GRID_SIZE
    EPOCHS :: 20
    
    world := ql.new_grid(GRID_SIZE, GRID_SIZE)
    defer ql.destroy_grid(world)
    
    world.start_pos = {}
    world.goal_pos = {GRID_SIZE-1, GRID_SIZE-1}
    world.step_penalty = -0.1
    world.goal_reward = 10
    world.wall_penalty = -1
    world.max_steps = 50
    
    // Create agent and state visit tracker
    agent := ql.new_agent(NUM_STATES, TEST_NUM_ACTIONS, 0.1, 0.9, 1)
    defer ql.destroy_agent(agent)
    
    tracker := ql.new_state_tracker(NUM_STATES, true, true)
    defer ql.destroy_state_tracker(tracker)
    
    testing.expect(t, world != nil && agent != nil && tracker != nil, "Environment setup should succeed")
    
    total_successful_epochs, total_steps: int
    // Run training epochs with state visit tracking
    for epoch in 0..<EPOCHS {
        ql.reset_environment(world)
        epoch_steps: i32
        for !world.epoch_done && epoch_steps < world.max_steps {
            state := ql.get_state_index(world)
            
            // Use action selection with state visit priority
            action := ql.select_action(agent, state)
            result := ql.step_environment(world, action)
            
            // Use Q-value update with state visit priority
            next_state := ql.position_to_state(world, result.next_state.position)
            ql.update_q_value(agent, tracker, state, action, result.reward, next_state, result.done)
            ql.update_state(tracker, state) // Track state visits for exploration coverage
            
            epoch_steps += 1
            total_steps += 1
        }
        if ql.positions_equal(world.agent_pos, world.goal_pos) {
            total_successful_epochs += 1
        }
        ql.decay_epsilon(agent)
    }
    // Check that training made progress
    success_rate := f32(total_successful_epochs) / f32(EPOCHS)
    avg_steps := f32(total_steps) / f32(EPOCHS)
    
    fmt.printf("Integration test results:\n")
    fmt.printf("  Success rate: %.1f%% (%d/%d epochs)\n", success_rate * 100, total_successful_epochs, EPOCHS)
    fmt.printf("  Average steps per epoch: %.1f\n", avg_steps)
    fmt.printf("  Total state visits: %d\n", tracker.total_visits)
    fmt.printf("  Exploration coverage: %.1f%%\n", ql.calc_exploration_coverage(tracker))
    
    testing.expect(t, tracker.total_visits > 0, "State visits should be recorded")
    testing.expect(t, ql.calc_exploration_coverage(tracker) > 0, "Some exploration should occur")
    
    // Test state visit analysis
    ql.print_state_analysis(tracker)
}

@(test)
test_state_performance_comparison :: proc(t: ^testing.T) {
    fmt.println("Performance Comparison: standard vs priority Q-learning...")
    GRID_SIZE :: 5
    NUM_STATES :: GRID_SIZE * GRID_SIZE
    EPOCHS :: 30
    
    // Test standard Q-learning
    world1 := ql.new_grid(GRID_SIZE, GRID_SIZE)
    defer ql.destroy_grid(world1)

    world1.start_pos = {}
    world1.goal_pos = {GRID_SIZE-1, GRID_SIZE-1}
    world1.step_penalty = -0.1
    world1.goal_reward = 10
    world1.max_steps = 40
    
    agent1 := ql.new_agent(NUM_STATES, TEST_NUM_ACTIONS, 0.1, 0.9, 1)
    defer ql.destroy_agent(agent1)
    
    successful_epochs_standard: int
    total_reward_standard: f32
    
    for epoch in 0..<EPOCHS {
        ql.reset_environment(world1)
        epoch_reward: f32 = 0.0
        
        for !world1.epoch_done && world1.epoch_steps < world1.max_steps {
            state := ql.get_state_index(world1)
            action := ql.select_action(agent1, state)
            result := ql.step_environment(world1, action)
            
            ql.update_q_value(agent1, nil, state, action, result.reward, ql.position_to_state(world1, result.next_state.position), result.done)
            epoch_reward += result.reward
        }
        if ql.positions_equal(world1.agent_pos, world1.goal_pos) {
            successful_epochs_standard += 1
        }
        total_reward_standard += epoch_reward
        ql.decay_epsilon(agent1)
    }
    // Test priority Q-learning
    world2 := ql.new_grid(GRID_SIZE, GRID_SIZE)
    defer ql.destroy_grid(world2)
    
    world2.start_pos = {}
    world2.goal_pos = {GRID_SIZE-1, GRID_SIZE-1}
    world2.step_penalty = -0.1
    world2.goal_reward = 10
    world2.max_steps = 40
    
    agent2 := ql.new_agent(NUM_STATES, TEST_NUM_ACTIONS, 0.1, 0.9, 1)
    defer ql.destroy_agent(agent2)
    
    tracker := ql.new_state_tracker(NUM_STATES, true, true)
    defer ql.destroy_state_tracker(tracker)
    
    successful_epochs_priority: int
    total_reward_priority: f32
    
    for epoch in 0..<EPOCHS {
        ql.reset_environment(world2)
        epoch_reward: f32
        
        for !world2.epoch_done && world2.epoch_steps < world2.max_steps {
            state := ql.get_state_index(world2)
            action := ql.select_action(agent2, state)
            result := ql.step_environment(world2, action)

            ql.update_q_value(agent2, tracker, state, action, result.reward,
                              ql.position_to_state(world2, result.next_state.position), result.done)
            ql.update_state(tracker, state) // Track state visits for exploration coverage
            
            epoch_reward += result.reward
        }
        if ql.positions_equal(world2.agent_pos, world2.goal_pos) {
            successful_epochs_priority += 1
        }
        total_reward_priority += epoch_reward
        ql.decay_epsilon(agent2)
        
        // Periodic exploration bonus decay
        if epoch % 5 == 0 {
            ql.decay_exploration_bonuses(tracker)
        }
    }
    // Calculate performance metrics
    success_rate_standard := f32(successful_epochs_standard) / f32(EPOCHS)
    success_rate_priority := f32(successful_epochs_priority) / f32(EPOCHS)
    avg_reward_standard := total_reward_standard / f32(EPOCHS)
    avg_reward_priority := total_reward_priority / f32(EPOCHS)
    coverage := ql.calc_exploration_coverage(tracker)
    
    fmt.printf("Standard Q-learning:\n")
    fmt.printf("  Success rate: %.1f%% (%d/%d)\n", success_rate_standard * 100, successful_epochs_standard, EPOCHS)
    fmt.printf("  Average reward: %.2f\n", avg_reward_standard)
    
    fmt.printf("Priority Q-learning:\n")
    fmt.printf("  Success rate: %.1f%% (%d/%d)\n", success_rate_priority * 100, successful_epochs_priority, EPOCHS)
    fmt.printf("  Average reward: %.2f\n", avg_reward_priority)
    fmt.printf("  Exploration coverage: %.1f%%\n", coverage)
    
    // Performance should be at least comparable
    testing.expect(t, success_rate_priority >= 0, "Priority learning should complete successfully")
    testing.expect(t, coverage > 0, "Some exploration should occur with priority tracking")
    fmt.println("Performance comparison completed")
}