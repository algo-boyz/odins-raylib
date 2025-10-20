package tests

import "core:fmt"
import "core:math"
import "core:testing"
import ql "../"

@(test)
test_default_reward_configuration :: proc(t: ^testing.T) {
    world := ql.new_grid(5, 5)
    defer ql.destroy_grid(world)
    testing.expect(t, world != nil, "Failed to create world")
    testing.expect(t, abs(world.goal_reward - 100) <= 0.01, 
                  fmt.tprintf("Goal reward should be 100, got %.1f", world.goal_reward))
    testing.expect(t, abs(world.wall_penalty - (-10)) <= 0.01,
                  fmt.tprintf("Wall penalty should be -10, got %.1f", world.wall_penalty))
    testing.expect(t, abs(world.step_penalty - (-1)) <= 0.01,
                  fmt.tprintf("Step penalty should be -1, got %.1f", world.step_penalty))
}

@(test)
test_goal_reward_calculation :: proc(t: ^testing.T) {
    world := ql.new_grid(5, 5)
    testing.expect(t, world != nil, "Failed to create world")
    defer ql.destroy_grid(world)
    
    ql.reset_environment(world)
    // Move agent to position adjacent to goal
    world.agent_pos.x = 3
    world.agent_pos.y = 4
    old_pos := world.agent_pos
    goal_pos := ql.Position{4, 4}
    reward := ql.calculate_reward(world, old_pos, goal_pos, true)
    
    testing.expect(t, abs(reward - 100) <= 0.01,
                   fmt.tprintf("Goal reward calculation failed: got %.1f, expected 100", reward))
}

@(test)
test_wall_penalty_calculation :: proc(t: ^testing.T) {
    world := ql.new_grid(5, 5)
    testing.expect(t, world != nil, "Failed to create world")
    defer ql.destroy_grid(world)
    
    ql.reset_environment(world)
    boundary_pos := ql.Position{0, 0}
    reward := ql.calculate_reward(world, boundary_pos, boundary_pos, false)
    
    testing.expect(t, abs(reward - (-10)) <= 0.01,
                  fmt.tprintf("Wall penalty calculation failed: got %.1f, expected -10", reward))
}

@(test)
test_step_penalty_calculation :: proc(t: ^testing.T) {
    world := ql.new_grid(5, 5)
    testing.expect(t, world != nil, "Failed to create world")
    defer ql.destroy_grid(world)
    
    empty_pos1 := ql.Position{1, 1}
    empty_pos2 := ql.Position{2, 1}
    reward := ql.calculate_reward(world, empty_pos1, empty_pos2, true)
    
    testing.expect(t, abs(reward - (-1)) <= 0.01,
                  fmt.tprintf("Step penalty calculation failed: got %.1f, expected -1", reward))
}

@(test)
test_config_based_creation :: proc(t: ^testing.T) {
    cfg := ql.Environment_Config{
        width = 8,
        height = 6,
        step_penalty = -0.5,
        goal_reward = 150,
        wall_penalty = -15,
        max_steps = 100,
    }
    world := ql.new_grid_from_config(cfg)
    testing.expect(t, world != nil, "Failed to create world from config")
    defer ql.destroy_grid(world)
    
    testing.expect(t, world.width == 8, fmt.tprintf("Width should be 8, got %d", world.width))
    testing.expect(t, world.height == 6, fmt.tprintf("Height should be 6, got %d", world.height))
    testing.expect(t, abs(world.goal_reward - 150) <= 0.01,
                  fmt.tprintf("Goal reward should be 150, got %.1f", world.goal_reward))
    testing.expect(t, abs(world.wall_penalty - (-15)) <= 0.01,
                  fmt.tprintf("Wall penalty should be -15, got %.1f", world.wall_penalty))
    testing.expect(t, abs(world.step_penalty - (-0.5)) <= 0.01,
                  fmt.tprintf("Step penalty should be -0.5, got %.1f", world.step_penalty))
    testing.expect(t, world.max_steps == 100,
                  fmt.tprintf("Max steps should be 100, got %d", world.max_steps))
}

@(test)
test_reward_validation :: proc(t: ^testing.T) {
    world := ql.new_grid(5, 5)
    testing.expect(t, world != nil, "Failed to create world")
    defer ql.destroy_grid(world)
    
    // Test valid configuration
    testing.expect(t, ql.validate_reward_values(world), "Valid reward configuration incorrectly rejected")
    
    // Test invalid configurations
    invalid := ql.new_grid(3, 3)
    testing.expect(t, invalid != nil, "Failed to create invalid test world")
    defer ql.destroy_grid(invalid)
    
    // Invalid: goal should be positive
    invalid.goal_reward = -50.0
    testing.expect(t, !ql.validate_reward_values(invalid), "Invalid goal reward not caught")
    
    // Invalid: wall penalty should be negative
    invalid.goal_reward = 100
    invalid.wall_penalty = 5.0
    testing.expect(t, !ql.validate_reward_values(invalid), "Invalid wall penalty not caught")
    
    // Invalid: step penalty should be negative
    invalid.wall_penalty = -10
    invalid.step_penalty = 2.0
    testing.expect(t, !ql.validate_reward_values(invalid), "Invalid step penalty not caught")
}

@(test)
test_dynamic_reward_setting :: proc(t: ^testing.T) {
    // world := ql.new_grid(5, 5)
    // testing.expect(t, world != nil, "Failed to create world")
    // defer ql.destroy_grid(world)
    
    // // Test valid setting
    // success := ql.set_reward_values(world, 200, -20, -2)
    // testing.expect(t, success, "Failed to set valid reward values")
    
    // testing.expect(t, abs(world.goal_reward - 200) <= 0.01,
    //               fmt.tprintf("Goal reward not set correctly: got %.1f, expected 200.0", world.goal_reward))
    // testing.expect(t, abs(world.wall_penalty - (-20)) <= 0.01,
    //               fmt.tprintf("Wall penalty not set correctly: got %.1f, expected -20.0", world.wall_penalty))
    // testing.expect(t, abs(world.step_penalty - (-2)) <= 0.01,
    //               fmt.tprintf("Step penalty not set correctly: got %.1f, expected -2.0", world.step_penalty))
    
    // // Test invalid setting (should fail and rollback)
    // success = ql.set_reward_values(world, -50.0, 10, 5) // All invalid
    // testing.expect(t, !success, "Invalid reward setting not rejected")
    
    // // Values should remain unchanged
    // testing.expect(t, abs(world.goal_reward - 200) <= 0.01,
    //               "Goal reward changed after failed setting")
    // testing.expect(t, abs(world.wall_penalty - (-20)) <= 0.01,
    //               "Wall penalty changed after failed setting")
    // testing.expect(t, abs(world.step_penalty - (-2)) <= 0.01,
    //               "Step penalty changed after failed setting")
}

@(test)
test_reward_value_retrieval :: proc(t: ^testing.T) {
    // world := ql.new_grid(5, 5)
    // testing.expect(t, world != nil, "Failed to create world")
    // defer ql.destroy_grid(world)
    
    // // Set known values
    // success := ql.set_reward_values(world, 200, -20, -2)
    // testing.expect(t, success, "Failed to set reward values")
    
    // goal, wall, step_val: f32
    // ql.get_reward_values(world, &goal, &wall, &step_val)
    
    // testing.expect(t, abs(goal - 200) <= 0.01,
    //               fmt.tprintf("Goal value retrieval failed: got %.1f, expected 200.0", goal))
    // testing.expect(t, abs(wall - (-20)) <= 0.01,
    //               fmt.tprintf("Wall value retrieval failed: got %.1f, expected -20.0", wall))
    // testing.expect(t, abs(step_val - (-2)) <= 0.01,
    //               fmt.tprintf("Step value retrieval failed: got %.1f, expected -2.0", step_val))
}

// @(test)
// test_end_to_end_scenarios :: proc(t: ^testing.T) {
//     world := ql.new_grid(5, 5)
//     testing.expect(t, world != nil, "Failed to create world")
//     defer ql.destroy_grid(world)
    
//     success := ql.calculate_reward(world, 200.0, -20.0, -2)
//     testing.expect(t, success, "Failed to set reward values")
    
//     ql.reset_environment(world)
    
//     total_reward, reward_step: f32 = 0.0, 0.0
    
//     // Step 1: Move right (empty space)
//     ql.step(world, .RIGHT, &reward_step)
//     total_reward += reward_step
//     testing.expect(t, abs(reward_step - (-2)) <= 0.01,
//                   fmt.tprintf("Step 1 reward incorrect: got %.1f, expected -2", reward_step))
    
//     // Step 2: Move right again (empty space)
//     ql.step(world, .RIGHT, &reward_step)
//     total_reward += reward_step
//     testing.expect(t, abs(reward_step - (-2)) <= 0.01,
//                   fmt.tprintf("Step 2 reward incorrect: got %.1f, expected -2", reward_step))
    
//     // Step 3: Try to move up (hit boundary)
//     ql.step(world, .UP, &reward_step)
//     total_reward += reward_step
//     testing.expect(t, abs(reward_step - (-20)) <= 0.01,
//                   fmt.tprintf("Step 3 reward incorrect: got %.1f, expected -20", reward_step))
    
//     // Move agent to near goal for final test
//     world.agent_pos.x = 3
//     world.agent_pos.y = 4
    
//     // Step 4: Move to goal
//     ql.step(world, .RIGHT, &reward_step)
//     total_reward += reward_step
//     testing.expect(t, abs(reward_step - 200) <= 0.01,
//                   fmt.tprintf("Step 4 reward incorrect: got %.1f, expected 200", reward_step))
    
//     expected_total := -2.0 + -2.0 + -20.0 + 200.0 // 176
//     testing.expect(t, abs(total_reward - expected_total) <= 0.01,
//                   fmt.tprintf("Total reward incorrect: got %.1f, expected %.1f", total_reward, expected_total))
// }

@(test)
test_reward_error_handling :: proc(t: ^testing.T) {
    // // Test nil params
    // testing.expect(t, !ql.validate_reward_values(nil),
    //               "validate_reward_values should reject nil")
    // testing.expect(t, !ql.set_reward_values(nil, 100, -10, -1),
    //               "set_reward_values should reject nil")
    
    // // Test graceful handling of nil params (should not crash)
    // dummy: f32
    // ql.get_reward_values(nil, &dummy, &dummy, &dummy)
    
    // world := ql.new_grid(3, 3)
    // if world != nil {
    //     defer ql.destroy_grid(world)
    //     ql.get_reward_values(world, nil, &dummy, &dummy) 
    // }
    // // Test invalid config
    // invalid_config := ql.Environment_Config{
    //     width = -1,  // Invalid
    //     height = 5,
    //     step_penalty = -1,
    //     goal_reward = 100,
    //     wall_penalty = -10,
    //     max_steps = 50,
    // }
    // null_world := ql.new_grid_from_config(invalid_config)
    // testing.expect(t, null_world == nil, "Should not create world with invalid config")
    // if null_world != nil {
    //     ql.destroy_grid(null_world)
    // }
}