package qling_demo

import "core:fmt"
import "core:math/rand"
import "core:time"
import "core:strings"
import "core:c"
import rl "vendor:raylib"
import ql "../../"

Demo_Config :: struct {
    demo_epochs, visualization_epochs: i32,
    show_q_values, educational_mode: bool,
    training_speed: f32,
}

NUM_ACTIONS :: 4
seed := rand.create(u64(time.now()._nsec))
rng := rand.default_random_generator(&seed)

educational_demo :: proc(world: ^ql.Grid, agent: ^ql.Q_Agent) {
    fmt.println("\nStep-by-step Q-Learning Demo")
    ql.reset_environment(world)
    
    fmt.printf("1. Initial State: Agent at (%d, %d), Goal at (%d, %d)\n",
               world.agent_pos.x, world.agent_pos.y,
               world.goal_pos.x, world.goal_pos.y)
    
    state := ql.get_state_index(world)
    fmt.println("   Initial Q-values for state:")
    
    action_names := [NUM_ACTIONS]string{"UP", "DOWN", "LEFT", "RIGHT"}
    for action in 0..<NUM_ACTIONS {
        q_val := ql.get_q_value(agent, state, ql.Action(action))
        fmt.printf("     %s: %.3f\n", action_names[action], q_val)
    }
    fmt.printf("\n2. Epsilon-greedy action selection (epsilon = %.3f):\n", agent.epsilon)
    action := ql.select_action(agent, state)
    fmt.printf("   Selected action: %s\n", action_names[action])
    
    fmt.println("\n3. Take action and observe result:")
    old_pos := world.agent_pos
    result := ql.step_environment(world, action)
    
    fmt.printf("   Old position: (%d, %d)\n", old_pos.x, old_pos.y)
    fmt.printf("   New position: (%d, %d)\n", world.agent_pos.x, world.agent_pos.y)
    fmt.printf("   Reward received: %.2f\n", result.reward)
    fmt.printf("   Epoch done: %s\n", result.done ? "Yes" : "No")
    
    fmt.println("\n4. Q-value update using Bellman equation:")
    fmt.println("   Q(s,a) = Q(s,a) + α[r + γ*max(Q(s',a')) - Q(s,a)]")
    fmt.printf("   Where: α=%.2f (learning rate), γ=%.2f (discount factor)\n",
               agent.learning_rate, agent.discount_factor)
    
    updated_q := ql.get_q_value(agent, state, action)
    fmt.printf("   Updated Q-value %s: %.3f\n", action_names[action], updated_q)
    
    fmt.println("\n5. Epsilon decay for next epoch:")
    old_epsilon := agent.epsilon
    ql.decay_epsilon(agent)
    fmt.printf("   Epsilon: %.3f -> %.3f\n", old_epsilon, agent.epsilon)
    
    fmt.println("\nProcess repeats for thousands of epochs until agent learns optimal policy\n")
}

performance_demo :: proc() {
    DEMO_EPOCHS :: 100
    GRID_SIZE :: 8
    fmt.println("\nPerformance Comparison of different learners:\n")
    Config_Test :: struct {
        learning_rate, discount_factor, epsilon_decay: f32,
        description: string,
    }
    configs := [4]Config_Test{
        {0.1, 0.9, 0.995, "Standard Q-learner"},
        {0.3, 0.9, 0.995, "Higher learning rate"},
        {0.1, 0.7, 0.995, "Lower discount factor"},
        {0.1, 0.9, 0.990, "Faster epsilon decay"},
    }
    for config, config_idx in configs {
        fmt.printf("%d. %s:\n", config_idx + 1, config.description)
        
        // Create environment and agent
        world := ql.new_grid(GRID_SIZE, GRID_SIZE)
        defer ql.destroy_grid(world)
        
        world.start_pos = {}
        world.goal_pos = {GRID_SIZE - 1, GRID_SIZE - 1}
        world.step_penalty = -0.1
        world.goal_reward = 100
        world.wall_penalty = -10
        world.max_steps = 100
        
        agent := ql.new_agent(GRID_SIZE * GRID_SIZE, NUM_ACTIONS,
                             config.learning_rate, config.discount_factor, 1)
        defer ql.destroy_agent(agent)
        
        agent.epsilon_decay = config.epsilon_decay
        agent.epsilon_min = 0.01
        
        // Train and measure performance
        successful_epochs := 0
        total_reward: f32
        
        for epoch in 0..<DEMO_EPOCHS {
            ql.reset_environment(world)
            epoch_reward: f32
            
            for !world.epoch_done && world.epoch_steps < world.max_steps {
                state := ql.get_state_index(world)
                action := ql.select_action(agent, state)
                result := ql.step_environment(world, action)
                
                next_state := ql.position_to_state(world, result.next_state.position)
                ql.update_q_value(agent, nil, state, action, result.reward, next_state, result.done)
                epoch_reward += result.reward
            }
            
            if ql.positions_equal(world.agent_pos, world.goal_pos) {
                successful_epochs += 1
            }
            total_reward += epoch_reward
            ql.decay_epsilon(agent)
        }
        rate := f32(successful_epochs) / f32(DEMO_EPOCHS) * 100
        avg_reward := total_reward / f32(DEMO_EPOCHS)
        fmt.printf("   Success rate: %d/%d (%.1f%%)\n", successful_epochs, DEMO_EPOCHS, rate)
        fmt.printf("   Average reward: %.2f\n", avg_reward)
        fmt.printf("   Final epsilon: %.3f\n\n", agent.epsilon)
    }
}

interactive_demo :: proc(world: ^ql.Grid, agent: ^ql.Q_Agent, config: ^Demo_Config) {
    fmt.println("Controls during training:")
    fmt.println("  Q - Toggle Q-value visuals")
    fmt.println("  G - Toggle grid")
    fmt.println("  P - Play/Pause training")
    fmt.println("  ESC - Exit")
    fmt.println("  1-5 - Change speed")
    
    // Initialize the visualization system BEFORE getting the state
    // Choose appropriate screen dimensions and cell size for your grid
    // Pass grid dimensions (world.width, world.height) for proper layout calculation
    vis_state := ql.init_visualization(1200, 800, 70, world.width, world.height)
    
    // Defer cleanup of graphics (CloseWindow, etc.) until the very end of function.
    defer ql.destroy_visualization(vis_state)

    // Set initial show_q_values from config
    vis_state.config.show_q = config.show_q_values
    
    rl.SetTargetFPS(60)

    demo_paused: bool
    training_speed := config.training_speed
    
    stats := ql.new_training_stats(config.visualization_epochs)
    defer ql.destroy_training_stats(stats)
    
    for epoch in 0..<config.visualization_epochs {
        if rl.WindowShouldClose() {
            fmt.println("Demo interrupted by user during training.")
            return
        }
        ql.reset_environment(world)
        epoch_reward, total_q_value: f32
        steps_taken, q_value_count: i32
        
        for !world.epoch_done && steps_taken < world.max_steps {
            // Handle input
            if rl.WindowShouldClose() {
                fmt.println("Demo interrupted by user during epoch.")
                return
            }
            if rl.IsKeyPressed(rl.KeyboardKey.P) {
                demo_paused = !demo_paused
                fmt.printf("Demo %s\n", demo_paused ? "PAUSED" : "RESUMED")
            }
            if rl.IsKeyPressed(rl.KeyboardKey.Q) {
                vis_state.config.show_q = !vis_state.config.show_q // Toggle through vis_state
                fmt.printf("Q-value visualization: %s\n", vis_state.config.show_q ? "ON" : "OFF")
            }
            if rl.IsKeyPressed(rl.KeyboardKey.G) {
                vis_state.config.show_grid = !vis_state.config.show_grid
                fmt.printf("Grid visualization: %s\n", vis_state.config.show_grid ? "ON" : "OFF")
            }
            // Speed controls
            if rl.IsKeyPressed(rl.KeyboardKey.ONE)   do training_speed = 0.01
            if rl.IsKeyPressed(rl.KeyboardKey.TWO)   do training_speed = 0.05
            if rl.IsKeyPressed(rl.KeyboardKey.THREE) do training_speed = 0.1
            if rl.IsKeyPressed(rl.KeyboardKey.FOUR)  do training_speed = 0.2
            if rl.IsKeyPressed(rl.KeyboardKey.FIVE)  do training_speed = 0.5
            
            if !demo_paused {
                // Training step
                current_state := ql.get_state_index(world)
                action := ql.select_action(agent, current_state)
                result := ql.step_environment(world, action)
                
                next_state := ql.position_to_state(world, result.next_state.position)
                ql.update_q_value(agent, nil, current_state, action, result.reward, next_state, result.done)
                epoch_reward += result.reward
                steps_taken += 1
                // Calc avg Q-value for state
                sum: f32
                for a in 0..<ql.TEST_NUM_ACTIONS { // Use ql.NUM_ACTIONS from the qling_demo package
                    sum += ql.get_q_value(agent, current_state, ql.Action(a))
                }
                total_q_value += sum / f32(ql.TEST_NUM_ACTIONS)
                q_value_count += 1
            }
            rl.BeginDrawing()
            rl.ClearBackground(vis_state.colors.background)
            
            // Draw environment
            if vis_state.config.show_q {
                ql.draw_q_values(vis_state, world, agent)
            } else {
                ql.draw_grid_world(vis_state, world)
            }
            ql.draw_walls(vis_state, world)
            ql.draw_goal(vis_state, world.goal_pos)
            ql.draw_agent(vis_state, world.agent_pos)

            // Draw info text on a dedicated panel
            panel_y := vis_state.layout.grid_area.y + vis_state.layout.grid_area.height + f32(vis_state.layout.margin)
            
            info_text := fmt.tprintf("Interactive Q-Learning Demo | Epoch: %d/%d | Step: %d | Reward: %.1f",
                                    epoch + 1, config.visualization_epochs, steps_taken, epoch_reward)
            rl.DrawTextEx(vis_state.text.font, strings.clone_to_cstring(info_text), rl.Vector2{f32(vis_state.layout.margin), panel_y}, f32(vis_state.text.font_size), f32(vis_state.text.line_spacing), vis_state.colors.text_color)
            
            agent_info := fmt.tprintf("Agent: (%d,%d) | Epsilon: %.3f | Speed: %.2fx | Q-values: %s",
                                     world.agent_pos.x, world.agent_pos.y, agent.epsilon,
                                     training_speed * 20, vis_state.config.show_q ? "ON" : "OFF")
            rl.DrawTextEx(vis_state.text.font, strings.clone_to_cstring(agent_info), rl.Vector2{f32(vis_state.layout.margin), panel_y + f32(vis_state.text.font_size) + 5}, f32(vis_state.text.font_size - 4), f32(vis_state.text.line_spacing), rl.DARKGRAY)
            
            if demo_paused {
                rl.DrawTextEx(vis_state.text.font, "DEMO PAUSED - Press P to resume", rl.Vector2{f32(vis_state.layout.margin), panel_y + 2*f32(vis_state.text.font_size) + 10}, f32(vis_state.text.font_size - 2), f32(vis_state.text.line_spacing), rl.RED)
            }
            
            rl.DrawTextEx(vis_state.text.font, "Controls: P=Pause | Q=Q-values | G=Grid | 1-5=Speed | ESC=Exit", rl.Vector2{f32(vis_state.layout.margin), f32(rl.GetScreenHeight() - vis_state.layout.margin - vis_state.text.font_size)}, f32(vis_state.text.font_size - 6), f32(vis_state.text.line_spacing), rl.DARKBLUE)
            
            ql.draw_fps_counter(vis_state)
            
            rl.EndDrawing()
            if !demo_paused {
                time.sleep(time.Duration(training_speed * f32(time.Second)))
            }
        }
        // Record epoch statistics
        ql.decay_epsilon(agent)
        avg_q_epoch := q_value_count > 0 ? total_q_value / f32(q_value_count) : 0
        ql.record_epoch(stats, epoch, epoch_reward, steps_taken, agent.epsilon, avg_q_epoch)
        
        // Check if goal was reached
        if ql.positions_equal(world.agent_pos, world.goal_pos) {
            stats.total_successful_epochs += 1
        }
        // Print progress every 10 epochs
        if (epoch + 1) % 10 == 0 {
            fmt.printf("Epoch %d completed: Reward=%.2f, Steps=%d, Epsilon=%.3f\n",
                       epoch + 1, epoch_reward, steps_taken, agent.epsilon)
        }
    }
    fmt.println("\nInteractive demo completed!")
    ql.print_summary(stats)
    // Visualize the best learned solution after training
    fmt.println("Displaying best learned policy. Press ESC to exit the demo.")
    
    // Reset agent to start position to demonstrate the learned path
    ql.reset_environment(world)
    current_agent_pos := world.agent_pos
    
    for !rl.WindowShouldClose() {
        rl.BeginDrawing()
        rl.ClearBackground(vis_state.colors.background)
        
        // Always show Q-values and policy arrows for the learned solution
        vis_state.config.show_q = true
        ql.draw_q_values(vis_state, world, agent)
        
        ql.draw_walls(vis_state, world)
        ql.draw_goal(vis_state, world.goal_pos)
        ql.draw_agent(vis_state, current_agent_pos) // Draw agent at its current position
    
        // Update the info panel for post-training state
        panel_y := vis_state.layout.grid_area.y + vis_state.layout.grid_area.height + f32(vis_state.layout.margin)
        info_text := fmt.tprintf("TRAINING COMPLETE! | Final Epsilon: %.3f", agent.epsilon)
        rl.DrawTextEx(vis_state.text.font, strings.clone_to_cstring(info_text), rl.Vector2{f32(vis_state.layout.margin), panel_y}, f32(vis_state.text.font_size), f32(vis_state.text.line_spacing), vis_state.colors.text_color)
        
        // Simulate agent following the learned policy
        if !ql.positions_equal(current_agent_pos, world.goal_pos) {
            state := ql.position_to_state(world, current_agent_pos)
            // This is a placeholder for a function that gets the best action.
            best_action := ql.select_action(agent, state)
            
            next_pos := current_agent_pos
            #partial switch best_action {
            case ql.Action.UP:
                next_pos.y -= 1
            case ql.Action.DOWN:
                next_pos.y += 1
            case ql.Action.LEFT:
                next_pos.x -= 1
            case ql.Action.RIGHT:
                next_pos.x += 1
            }
        
            // Clamp next_pos to grid boundaries and handle walls
            if !(next_pos.x < 0 || next_pos.x >= world.width ||
                next_pos.y < 0 || next_pos.y >= world.height ||
                world.grid[next_pos.y][next_pos.x] == ql.Cell_Type.WALL) {
                current_agent_pos = next_pos
            }
        }
        // Check if goal reached in visualization
        if ql.positions_equal(current_agent_pos, world.goal_pos) {
            rl.DrawTextEx(vis_state.text.font, "GOAL REACHED!", rl.Vector2{f32(vis_state.layout.margin), panel_y + 2*f32(vis_state.text.font_size) + 10}, f32(vis_state.text.font_size - 2), f32(vis_state.text.line_spacing), rl.GREEN)
        } else {
            rl.DrawTextEx(vis_state.text.font, fmt.ctprintf("Following optimal policy from (%d,%d)", current_agent_pos.x, current_agent_pos.y), rl.Vector2{f32(vis_state.layout.margin), panel_y + 2*f32(vis_state.text.font_size) + 10}, f32(vis_state.text.font_size - 2), f32(vis_state.text.line_spacing), rl.DARKBLUE)
        }
        rl.DrawTextEx(vis_state.text.font, "Press ESC to exit", rl.Vector2{f32(vis_state.layout.margin), f32(rl.GetScreenHeight() - vis_state.layout.margin - vis_state.text.font_size)}, f32(vis_state.text.font_size - 6), f32(vis_state.text.line_spacing), rl.RED)
    
        ql.draw_fps_counter(vis_state)
        rl.EndDrawing()
        
        // Small delay to make the "playback" visible
        time.sleep(time.Duration(0.3 * f32(time.Second)))
    }
}

// Main demo program
main :: proc() {
    GRID_WIDTH :: 10
    GRID_HEIGHT :: 10
    fmt.println("Q-Learning Training Demo")
    
    world := ql.new_grid(GRID_WIDTH, GRID_HEIGHT)
    defer ql.destroy_grid(world)

    world.start_pos = {1, 1}
    world.goal_pos = {8, 8}
    world.step_penalty = -0.1
    world.goal_reward = 100
    world.wall_penalty = -10
    world.max_steps = 100
    // Add some walls
    ql.set_cell(world, 3, 3, .WALL)
    ql.set_cell(world, 3, 4, .WALL)
    ql.set_cell(world, 3, 5, .WALL)
    ql.set_cell(world, 5, 2, .WALL)
    ql.set_cell(world, 5, 3, .WALL)
    ql.set_cell(world, 5, 4, .WALL)
    ql.set_cell(world, 7, 6, .WALL)
    ql.set_cell(world, 7, 7, .WALL)
    // Set special cells
    ql.set_cell(world, world.goal_pos.x, world.goal_pos.y, .GOAL)
    ql.set_cell(world, world.start_pos.x, world.start_pos.y, .START)
    
    // Create agent
    agent := ql.new_agent(GRID_WIDTH * GRID_HEIGHT, NUM_ACTIONS, 0.1, 0.9, 1)
    defer ql.destroy_agent(agent)
    agent.epsilon_decay = 0.995
    agent.epsilon_min = 0.01
    
    config := Demo_Config{
        demo_epochs = 50,
        visualization_epochs = 50,
        show_q_values = true,
        educational_mode = true,
        training_speed = 0.1,
    }
    fmt.println("1. Step-by-step Q-learning")
    educational_demo(world, agent)
    fmt.println("2. Performance comparison")
    performance_demo()
    fmt.println("3. Interactive visualization")
    interactive_demo(world, agent, &config)
    fmt.println("\nDemo complete!")
}