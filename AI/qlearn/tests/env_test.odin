package tests

import "core:testing"
import ql "../"

@(test)
test_grid_creation :: proc(t: ^testing.T) {
    world := ql.new_grid(5, 5)
    defer ql.destroy_grid(world)
    
    testing.expect(t, world != nil, "Failed to create grid")
    testing.expect(t, world.width == 5, "Incorrect grid width")
    testing.expect(t, world.height == 5, "Incorrect grid height")
    testing.expect(t, world.agent_pos.x == 0, "Incorrect initial agent x position")
    testing.expect(t, world.agent_pos.y == 0, "Incorrect initial agent y position")
    testing.expect(t, world.goal_pos.x == 4, "Incorrect goal x position")
    testing.expect(t, world.goal_pos.y == 4, "Incorrect goal y position")
}

@(test)
test_state_indexing :: proc(t: ^testing.T) {
    world := ql.new_grid(5, 5)
    defer ql.destroy_grid(world)
    
    // Test initial position (0,0)
    state := ql.get_state_index(world)
    testing.expect(t, state == 0, "Incorrect state index for (0,0)")
    
    // Test arbitrary position (2,3)
    world.agent_pos.x = 2
    world.agent_pos.y = 3
    state = ql.get_state_index(world)
    expected := 3 * 5 + 2  // row * width + col = 17
    testing.expect(t, state == expected, "Incorrect state index for (2,3)")
    
    // Test goal position (4,4)
    world.agent_pos.x = 4
    world.agent_pos.y = 4
    state = ql.get_state_index(world)
    expected = 4 * 5 + 4  // 24
    testing.expect(t, state == expected, "Incorrect state index for (4,4)")
}

@(test)
test_terminal_state :: proc(t: ^testing.T) {
    world := ql.new_grid(5, 5)
    defer ql.destroy_grid(world)
    
    // Test non-terminal position
    test_pos := ql.Position{2, 3}
    terminal := ql.is_terminal_state(world, test_pos)
    testing.expect(t, !terminal, "Position (2,3) incorrectly identified as terminal")
    
    // Test goal position (terminal)
    goal_pos := ql.Position{4, 4}
    terminal = ql.is_terminal_state(world, goal_pos)
    testing.expect(t, terminal, "Goal position (4,4) not identified as terminal")
}

@(test)
test_environment_reset :: proc(t: ^testing.T) {
    world := ql.new_grid(5, 5)
    defer ql.destroy_grid(world)
    
    // Modify world state
    world.agent_pos.x = 3
    world.agent_pos.y = 2
    world.epoch_steps = 10
    world.epoch_done = true
    world.total_reward = 50
    
    // Reset environment
    ql.reset_environment(world)
    
    // Verify reset
    testing.expect(t, world.agent_pos.x == 0, "Agent x position not reset")
    testing.expect(t, world.agent_pos.y == 0, "Agent y position not reset")
    testing.expect(t, world.epoch_steps == 0, "epoch steps not reset")
    testing.expect(t, world.epoch_done == false, "epoch done flag not reset")
    testing.expect(t, world.total_reward == 0, "Total reward not reset")
}

@(test)
test_movement_mechanics :: proc(t: ^testing.T) {
    world := ql.new_grid(5, 5)
    defer ql.destroy_grid(world)
    
    // Test valid move: RIGHT from (0,0) to (1,0)
    next_step, reward, ok := ql.step(world, .RIGHT)
    
    testing.expect(t, ok == true, "Step to RIGHT should succeed")
    testing.expect(t, world.agent_pos.x == 1, "Agent x position after RIGHT move")
    testing.expect(t, world.agent_pos.y == 0, "Agent y position after RIGHT move")
    testing.expect(t, reward == -1, "Incorrect step penalty")
    testing.expect(t, next_step == 1, "Incorrect new state after RIGHT move")
    testing.expect(t, world.epoch_steps == 1, "epoch steps not incremented")
}

@(test)
test_boundary_collision :: proc(t: ^testing.T) {
    world := ql.new_grid(5, 5)
    defer ql.destroy_grid(world)
        
    // Test boundary collision: UP from (0,0) - should stay at (0,0)
    next_step, reward, ok := ql.step(world, .UP)
    
    testing.expect(t, world.agent_pos.x == 0, "Agent x position after boundary collision")
    testing.expect(t, world.agent_pos.y == 0, "Agent y position after boundary collision")
    testing.expect(t, reward == -10, "Incorrect wall penalty")
    testing.expect(t, next_step == 0, "State changed after boundary collision")
}

@(test)
test_goal_reaching :: proc(t: ^testing.T) {
    world := ql.new_grid(5, 5)
    defer ql.destroy_grid(world)

    // Position agent one step away from goal
    world.agent_pos.x = 3
    world.agent_pos.y = 4
    
    // Move right to reach goal
    next_step, reward, ok := ql.step(world, .RIGHT)
    testing.expect(t, ok == true, "Step to goal should succeed")
    testing.expect(t, world.agent_pos.x == 4, "Agent x position after reaching goal")
    testing.expect(t, world.agent_pos.y == 4, "Agent y position after reaching goal")
    testing.expect(t, reward == 100, "Incorrect goal reward")
    testing.expect(t, world.epoch_done == true, "epoch not marked as done after reaching goal")
    
    expected := 4 * 5 + 4  // 24
    testing.expect(t, next_step == expected, "Incorrect goal state")
}

@(test)
test_error_handling :: proc(t: ^testing.T) {
    // Test with nil world
    pos1 := ql.Position{2, 3}
    error_state := ql.get_state_index(nil)
    testing.expect(t, error_state == -1, "get_state_index with nil world should return -1")
    
    error_terminal := ql.is_terminal_state(nil, pos1)
    testing.expect(t, error_terminal == true, "is_terminal_state with nil world should return true")
    
    _, reward, ok := ql.step(nil, .UP)
    testing.expect(t, ok == false, "step with nil world should return false")
}