package tests

import "core:fmt"
import "core:math"
import "core:testing"
import ql "../"

@(test)
test_valid_step_move :: proc(t: ^testing.T) {
    world := ql.new_grid(5, 5)
    testing.expect(t, world != nil, "Failed to create grid world")
    defer ql.destroy_grid(world)
    
    ql.reset_environment(world)
    
    result := ql.step_environment(world, .RIGHT)
    testing.expect(t, result.valid_action == true, "Valid action should be true")
    testing.expect(t, result.done == false, "Epoch should not be done")
    testing.expect(t, abs(result.reward - (-1)) < 0.01, "Expected reward -1.0")
    testing.expect(t, result.next_state.state_index == 1, "Expected state index 1")
    testing.expect(t, result.next_state.position.x == 1, "Expected position x to be 1")
    testing.expect(t, result.next_state.position.y == 0, "Expected position y to be 0")
    testing.expect(t, result.next_state.is_valid == true, "State should be valid")
    testing.expect(t, result.next_state.is_terminal == false, "State should not be terminal")
}

@(test)
test_wall_collision :: proc(t: ^testing.T) {
    world := ql.new_grid(5, 5)
    testing.expect(t, world != nil, "Failed to create grid world")
    defer ql.destroy_grid(world)
    
    ql.reset_environment(world)
    
    result := ql.step_environment(world, .UP)  // Try to move up from (0,0)
    testing.expect(t, result.valid_action == false, "Invalid action should be false")
    testing.expect(t, result.done == false, "Epoch should not be done for wall collision")
    testing.expect(t, abs(result.reward - (-10)) < 0.01, "Expected penalty reward -10.0")
    testing.expect(t, result.next_state.state_index == 0, "Should remain at same position")
    testing.expect(t, result.next_state.position.x == 0, "Position x should remain 0")
    testing.expect(t, result.next_state.position.y == 0, "Position y should remain 0")
}

@(test)
test_goal_achievement :: proc(t: ^testing.T) {
    world := ql.new_grid(5, 5)
    testing.expect(t, world != nil, "Failed to create grid world")
    defer ql.destroy_grid(world)
    
    // Position agent one step away from goal
    world.agent_pos.x = 3
    world.agent_pos.y = 4
    
    result := ql.step_environment(world, .RIGHT)  // Move to goal at (4,4)
    testing.expect(t, result.valid_action == true, "Valid action should be true")
    testing.expect(t, result.done == true, "Epoch should be done when reaching goal")
    testing.expect(t, abs(result.reward - 100) < 0.01, "Expected goal reward 100.0")
    testing.expect(t, result.next_state.state_index == 24, "Expected state index 24 (4*5 + 4)")
    testing.expect(t, result.next_state.position.x == 4, "Expected goal position x to be 4")
    testing.expect(t, result.next_state.position.y == 4, "Expected goal position y to be 4")
    testing.expect(t, result.next_state.is_terminal == true, "Goal state should be terminal")
}

@(test)
test_step_error_handling :: proc(t: ^testing.T) {
    // Test NULL world
    result := ql.step_environment(nil, .UP)
    testing.expect(t, result.valid_action == false, "NULL world should result in invalid action")
    testing.expect(t, result.done == true, "NULL world should result in done state")
    testing.expect(t, result.next_state.state_index == -1, "NULL world should result in invalid state index")
    testing.expect(t, result.next_state.is_valid == false, "NULL world should result in invalid state")
    
    // Test step on completed epoch
    world := ql.new_grid(5, 5)
    testing.expect(t, world != nil, "Failed to create grid world")
    defer ql.destroy_grid(world)
    
    ql.reset_environment(world)
    world.epoch_done = true
    
    result = ql.step_environment(world, .RIGHT)
    testing.expect(t, result.valid_action == false, "Step on completed epoch should be invalid")
    testing.expect(t, result.done == true, "Step on completed epoch should remain done")
    testing.expect(t, abs(result.reward) < 0.01, "Step on completed epoch should have zero reward")
}

@(test)
test_step_consistency :: proc(t: ^testing.T) {
    world := ql.new_grid(5, 5)
    testing.expect(t, world != nil, "Failed to create grid world")
    defer ql.destroy_grid(world)
    
    ql.reset_environment(world)
    
    next_step, reward, ok := ql.step(world, .RIGHT)
    testing.expect(t, ok == true, "Step should succeed")
    testing.expect(t, world.agent_pos.x == 1, "Agent x position after RIGHT move")
    testing.expect(t, world.agent_pos.y == 0, "Agent y position after RIGHT move")
    testing.expect(t, abs(reward - (-1)) < 0.01, "Incorrect step penalty")
    testing.expect(t, next_step == 1, "Incorrect new state after RIGHT move")
    testing.expect(t, world.epoch_steps == 1, "epoch steps not incremented")
    
    ql.reset_environment(world)
    step_env_result := ql.step_environment(world, .RIGHT)
    
    // Results should be equivalent
    //     testing.expect(t, step_state == step_env_result.next_state.state_index, 
    //                    "State consistency: step and step_environment should return same state")
    //     testing.expect(t, abs(step_reward - step_env_result.reward) < 0.01, 
    //                    "Reward consistency: step and step_environment should return same reward")
}

@(test)
test_state_conversion :: proc(t: ^testing.T) {
    world := ql.new_grid(5, 5)
    testing.expect(t, world != nil, "Failed to create grid world")
    defer ql.destroy_grid(world)
    
    // Test valid conversions
    pos := ql.Position{2, 3}
    state_idx := ql.position_to_state(world, pos)
    expected_state := 17  // 3*5 + 2 = 17
    testing.expect(t, state_idx == expected_state, 
                   "Position to state conversion should work correctly")
    
    converted_pos := ql.state_to_position(world, state_idx)
    testing.expect(t, converted_pos.x == pos.x && converted_pos.y == pos.y, 
                   "State to position conversion should work correctly")
    
    // Test invalid conversions
    invalid_state := ql.position_to_state(world, {-1, 0})
    testing.expect(t, invalid_state == -1, 
                   "Invalid position should return -1")
    
    invalid_pos := ql.state_to_position(world, -1)
    testing.expect(t, invalid_pos.x == -1 && invalid_pos.y == -1, 
                   "Invalid state should return (-1,-1)")
}

@(test)
test_step_sequence :: proc(t: ^testing.T) {
    world := ql.new_grid(3, 3)
    testing.expect(t, world != nil, "Failed to create grid world")
    defer ql.destroy_grid(world)
    
    ql.reset_environment(world)
    
    // Test a sequence of moves
    moves := []ql.Action{.RIGHT, .DOWN, .RIGHT}
    total_reward: f32
    
    for action, i in moves {
        result := ql.step_environment(world, action)
        total_reward += result.reward
        
        // Basic validation for each step
        testing.expect(t, result.next_state.is_valid == true, 
                       "Each step should result in a valid state")
        if result.done {
            testing.expect(t, result.next_state.is_terminal == true, 
                           "Done state should be terminal")
            break
        }
    }
    // The total reward should be reasonable (negative from steps, positive if goal reached)
    testing.expect(t, total_reward != 0, "Total reward should not be zero")
}

@(test)
test_step_boundary_conditions :: proc(t: ^testing.T) {
    world := ql.new_grid(2, 2)  // Minimal grid
    testing.expect(t, world != nil, "Failed to create minimal grid world")
    defer ql.destroy_grid(world)
    
    ql.reset_environment(world)
    
    // Test all four directions from starting position (0,0)
    actions := []ql.Action{.UP, .LEFT, .DOWN, .RIGHT}
    expected_valid := []bool{false, false, true, true}  // UP and LEFT should be invalid
    
    for i, action in actions {
        ql.reset_environment(world)  // Reset for each test
        result := ql.step_environment(world, ql.Action(action))
        
        testing.expect(t, result.valid_action == expected_valid[i], 
                fmt.tprintf("Action %v should be %s from (0,0)", action, expected_valid[i] ? "valid" : "invalid"))
    }
}

@(test)
test_multiple_wall_collisions :: proc(t: ^testing.T) {
    world := ql.new_grid(3, 3)
    testing.expect(t, world != nil, "Failed to create grid world")
    defer ql.destroy_grid(world)
    
    ql.reset_environment(world)
    
    // Try multiple wall collisions in sequence
    for i in 0..<5 {
        result := ql.step_environment(world, .UP)  // Keep trying to go up from (0,0)
        testing.expect(t, result.valid_action == false, "Wall collision should be invalid")
        testing.expect(t, result.done == false, "Wall collision should not end epoch")
        testing.expect(t, abs(result.reward - (-10)) < 0.01, "Wall collision penalty should be consistent")
        testing.expect(t, result.next_state.position.x == 0 && result.next_state.position.y == 0, "Agent should remain at starting position after wall collision")
    }
}

@(test)
test_goal_state_finality :: proc(t: ^testing.T) {
    world := ql.new_grid(3, 3)
    testing.expect(t, world != nil, "Failed to create grid world")
    defer ql.destroy_grid(world)
    
    // Move agent to one step before goal
    world.agent_pos.x = 1
    world.agent_pos.y = 2
    
    // Reach the goal
    result := ql.step_environment(world, .RIGHT)
    testing.expect(t, result.done == true, "Reaching goal should end epoch")
    testing.expect(t, result.next_state.is_terminal == true, "Goal should be terminal state")
    testing.expect(t, abs(result.reward - 100) < 0.01, "Goal reward should be 100")
    
    // Try to take another step (should be invalid)
    next_result := ql.step_environment(world, .LEFT)
    testing.expect(t, next_result.valid_action == false, "Action after goal should be invalid")
    testing.expect(t, next_result.done == true, "Should remain in done state")
    testing.expect(t, abs(next_result.reward) < 0.01, "No additional reward after goal")
}