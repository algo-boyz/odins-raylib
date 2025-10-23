package tests

import "core:fmt"
import "core:math/rand"
import "core:time"
import "core:math"
import "core:testing"
import ql "../"

@(test)
test_agent_creation :: proc(t: ^testing.T) {
    agent := ql.new_agent(25, 4, 0.1, 0.9, 0.1)
    testing.expect(t, agent != nil, "Agent should be created successfully")
    
    if agent != nil {
        testing.expect(t, agent.num_states == 25, "Agent should have 25 states")
        testing.expect(t, agent.num_actions == 4, "Agent should have 4 actions")
        testing.expect(t, agent.learning_rate == 0.1, "Learning rate should be 0.1")
        testing.expect(t, agent.discount_factor == 0.9, "Discount factor should be 0.9")
        testing.expect(t, agent.epsilon == 0.1, "Epsilon should be 0.1")
        ql.destroy_agent(agent)
    }
}

@(test)
test_q_value_operations :: proc(t: ^testing.T) {
    agent := ql.new_agent(5, 4, 0.1, 0.9, 0.1)
    testing.expect(t, agent != nil, "Agent should be created successfully")
    
    if agent != nil {
        ql.set_q_value(agent, 0, .UP, 10.5)
        ql.set_q_value(agent, 0, .RIGHT, 8.2)
        
        q_up := ql.get_q_value(agent, 0, .UP)
        q_right := ql.get_q_value(agent, 0, .RIGHT)
        
        testing.expect(t, abs(q_up - 10.5) < 0.001, "Q-value for UP action should be set correctly")
        testing.expect(t, abs(q_right - 8.2) < 0.001, "Q-value for RIGHT action should be set correctly")
        ql.destroy_agent(agent)
    }
}

@(test)
test_agent_action_selection :: proc(t: ^testing.T) {
    agent := ql.new_agent(5, 4, 0.1, 0.9, 0.0) // deterministic epsilon = 0 for testing
    testing.expect(t, agent != nil, "Agent should be created successfully")
    
    if agent != nil {
        // Set Q-values to make ACTION_DOWN best choice
        ql.set_q_value(agent, 0, .UP, 1.0)
        ql.set_q_value(agent, 0, .DOWN, 10.0) // Best action
        ql.set_q_value(agent, 0, .LEFT, 2.0)
        ql.set_q_value(agent, 0, .RIGHT, 3.0)
        
        move := ql.select_greedy_action(agent, 0)
        testing.expect(t, move == ql.Action.DOWN, "Greedy action selection should select DOWN (highest Q-value)")
        ql.destroy_agent(agent)
    }
}

@(test)
test_q_learning_update :: proc(t: ^testing.T) {
    agent := ql.new_agent(5, 4, 0.5, 0.9, 0.1)
    testing.expect(t, agent != nil, "Agent should be created successfully")

    if agent != nil {
        initial_q := ql.get_q_value(agent, 0, .UP)
        
        // Simulate a step with positive reward
        reward: f32 = 10.0
        next_state :: 1
        ql.set_q_value(agent, next_state, .UP, 5.0) // Set some value in next state
        ql.update_q_value(agent, nil, 0, .UP, reward, next_state, false)

        updated_q := ql.get_q_value(agent, 0, .UP)
        
        // Q-learning formula: Q(s,a) = Q(s,a) + α[r + γ*max(Q(s',a')) - Q(s,a)]
        // Expected: 0 + 0.5 * [10.0 + 0.9 * 5.0 - 0] = 0.5 * [10.0 + 4.5] = 7.25
        expected_q := initial_q + 0.5 * (reward + 0.9 * 5.0 - initial_q)
        
        testing.expect(t, abs(updated_q - expected_q) < 0.001, 
                      fmt.tprintf("Q-learning update should be correct (Expected: %.3f, Got: %.3f)", 
                                 expected_q, updated_q))
        ql.destroy_agent(agent)
    }
}

@(test)
test_epsilon_decay :: proc(t: ^testing.T) {
    agent := ql.new_agent(5, 4, 0.1, 0.9, 1.0)
    testing.expect(t, agent != nil, "Agent should be created successfully")
    
    if agent != nil {
        agent.epsilon_decay = 0.9
        agent.epsilon_min = 0.1
        
        initial_epsilon := agent.epsilon
        testing.expect(t, initial_epsilon == 1.0, "Initial epsilon should be 1.0")
        
        for i in 0..<5 {
            ql.decay_epsilon(agent)
        }
        testing.expect(t, agent.epsilon < initial_epsilon, "Epsilon should decrease after decay")
        testing.expect(t, agent.epsilon >= agent.epsilon_min, "Epsilon should not go below minimum")
        ql.destroy_agent(agent)
    }
}

@(test)
test_experience_buffer :: proc(t: ^testing.T) {
    buffer := ql.new_experience_buffer(3)
    testing.expect(t, buffer != nil, "Experience buffer should be created successfully")
    
    if buffer != nil {
        testing.expect(t, buffer.capacity == 3, "Buffer capacity should be 3")
        testing.expect(t, buffer.size == 0, "Initial buffer size should be 0")
        
        ql.add_experience(buffer, 0, .UP, 1.0, 1, false, 0)
        testing.expect(t, buffer.size == 1, "Buffer size should be 1 after adding first experience")
        
        ql.add_experience(buffer, 1, .RIGHT, 2.0, 2, false, 0)
        ql.add_experience(buffer, 2, .DOWN, 5.0, 3, true, 0)
        testing.expect(t, buffer.size == 3, "Buffer size should be 3 after adding 3 experiences")
        
        exp := ql.sample_experience(buffer)
        testing.expect(t, exp != nil, "Should be able to sample experience from buffer")
        
        // Test overflow (circular buffer)
        ql.add_experience(buffer, 3, .LEFT, 3.0, 4, false, 0)
        testing.expect(t, buffer.size == 3, "Buffer size should remain at capacity after overflow")
        ql.destroy_experience_buffer(buffer)
    }
}

@(test)
test_action_selection :: proc(t: ^testing.T) {
    agent := ql.new_agent(TEST_NUM_STATES, TEST_NUM_ACTIONS, 0.1, 0.9, 0.5)
    defer ql.destroy_agent(agent)
    
    testing.expect(t, agent != nil, "Agent should be created successfully")
    
    // Set some Q-values to make action DOWN optimal for state 0
    ql.set_q_value(agent, 0, .UP, 1)
    ql.set_q_value(agent, 0, .DOWN, 10)     // Best action
    ql.set_q_value(agent, 0, .LEFT, 2)
    ql.set_q_value(agent, 0, .RIGHT, 3)

    // --- Test deterministic exploitation ---
    // Store original epsilon
    original_epsilon := agent.epsilon
    // Temporarily set epsilon to 0 to force exploitation
    agent.epsilon = 0.0
    
    selected_action := ql.select_action(agent, 0)
    
    // With epsilon = 0.0, it should always select the greedy action (DOWN)
    testing.expectf(t, selected_action == .DOWN, 
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
        if action == .DOWN {
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
test_simple_learning_scenario :: proc(t: ^testing.T) {
    // Create a simple 1D environment (5 states in a line)
    // State 0 -> State 1 -> State 2 -> State 3 -> State 4 (goal)
    agent := ql.new_agent(5, 2, 0.1, 0.9, 0.3) // 2 actions: LEFT(0), RIGHT(1)
    defer ql.destroy_agent(agent)
    
    testing.expect(t, agent != nil, "Agent should be created successfully")
    if agent != nil {
        initial_epsilon := agent.epsilon
        
        // Simulate training for more epochs to ensure learning stability
        num_epochs := 100 // Increased from 5
        max_steps_per_episode := 50 // Increased from 20
        
        for epoch in 0..<num_epochs {
            state := 0 // Start at state 0
            steps := 0
            total_reward: f32
            done := false
            
            for !done && steps < max_steps_per_episode { // Goal is state 4
                action := ql.select_action(agent, state)
                
                // Simple env dynamics
                next_state := state
                reward: f32 = -0.1 // Small step penalty

                if int(action) == 1 && state < 4 { // RIGHT action
                    next_state = state + 1
                } else if int(action) == 0 && state > 0 { // LEFT action
                    next_state = state - 1
                }
                // Goal reward
                if next_state == 4 {
                    reward = 10
                    done = true
                }
                ql.update_q_value(agent, nil, state, action, reward, next_state, done)
                state = next_state
                total_reward += reward
                steps += 1
            }
            ql.decay_epsilon(agent)
        }
        // Test that the agent learned something
        q_right_state0 := ql.get_q_value(agent, 0, ql.Action(1)) // RIGHT from state 0
        q_left_state0 := ql.get_q_value(agent, 0, ql.Action(0))  // LEFT from state 0

        testing.expectf(t, q_right_state0 > q_left_state0, 
                       "Agent should learn that RIGHT (%.4f) is better than LEFT (%.4f) from state 0", 
                       q_right_state0, q_left_state0)
        testing.expect(t, agent.epsilon < initial_epsilon, "Epsilon should have decayed during training")
    }
}

@(test)
test_training_stats :: proc(t: ^testing.T) {
    stats := ql.new_training_stats(5)
    testing.expect(t, stats != nil, "Training stats should be created successfully")
    
    if stats != nil {
        testing.expect(t, stats.current_epoch == 0, "Initial current epoch should be 0")
        
        // Record some epochs
        ql.record_epoch(stats, 0, 10.5, 25, 0.9, 2.1)
        testing.expect(t, stats.current_epoch == 1, "Current epoch should increment after recording")
        testing.expect(t, stats.best_reward == 10.5, "Best reward should be updated")
        testing.expect(t, stats.best_epoch == 0, "Best epoch should be 0")
        
        ql.record_epoch(stats, 1, 15.2, 20, 0.8, 3.2)
        testing.expect(t, stats.best_reward == 15.2, "Best reward should be updated to higher value")
        testing.expect(t, stats.best_epoch == 1, "Best epoch should be updated")
        
        ql.record_epoch(stats, 2, 12.8, 22, 0.7, 2.8)
        testing.expect(t, stats.current_epoch == 3, "Current epoch should be 3 after 3 recordings")
        testing.expect(t, stats.best_reward == 15.2, "Best reward should remain 15.2")
        ql.destroy_training_stats(stats)
    }
}

@(test)
test_agent_error_handling :: proc(t: ^testing.T) {
    // Test invalid agent creation
    invalid_agent := ql.new_agent(0, 4, 0.1, 0.9, 0.1) // 0 states should be invalid
    testing.expect(t, invalid_agent == nil, "Agent creation with 0 states should fail")
    
    invalid_agent2 := ql.new_agent(5, 0, 0.1, 0.9, 0.1) // 0 actions should be invalid
    testing.expect(t, invalid_agent2 == nil, "Agent creation with 0 actions should fail")
    
    // Test invalid buffer creation
    invalid_buffer := ql.new_experience_buffer(0) // 0 capacity should be invalid
    testing.expect(t, invalid_buffer == nil, "Buffer creation with 0 capacity should fail")
}

@(test)
test_agent_boundary_conditions :: proc(t: ^testing.T) {
    agent := ql.new_agent(3, 2, 0.5, 0.95, 0.2)
    testing.expect(t, agent != nil, "Agent should be created successfully")
    
    if agent != nil {
        // Test boundary state and action indices
        ql.set_q_value(agent, 0, ql.Action(0), 5.0) // First state, first action
        ql.set_q_value(agent, 2, ql.Action(1), 7.0) // Last state, last action
        
        q_first := ql.get_q_value(agent, 0, ql.Action(0))
        q_last := ql.get_q_value(agent, 2, ql.Action(1))
        
        testing.expect(t, abs(q_first - 5.0) < 0.001, "First boundary Q-value should be set correctly")
        testing.expect(t, abs(q_last - 7.0) < 0.001, "Last boundary Q-value should be set correctly")
        ql.destroy_agent(agent)
    }
}