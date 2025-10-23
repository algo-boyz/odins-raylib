package qlearn

import "core:fmt"
import "core:os"
import "core:strings"
import "core:strconv"
import "core:time"
import "core:math"
import "core:math/rand"
import rl "vendor:raylib"

seed := rand.create(u64(time.now()._nsec))
rng := rand.default_random_generator(&seed)

Training_Config :: struct {
    visualize, save_policy, show_progress: bool,
    progress_interval, num_epochs, max_steps_in_epoch: i32,
    policy_path: string,
}

Training_Control :: struct {
    paused, reset, exit, show_q, save_req, load_req: bool,
    speed: f32,
    path: string,
}

save_policy :: proc(agent: ^Q_Agent, world: ^Grid, filename: string) {
    file, err := os.open(filename, os.O_CREATE | os.O_WRONLY | os.O_TRUNC)
    if err != os.ERROR_NONE {
        fmt.printf("Error: Could not open file %s for writing\n", filename)
        return
    }
    defer os.close(file)
    
    os.write_string(file, "# Q-Learning Policy\n")
    os.write_string(file, fmt.tprintf("# Grid dims: %dx%d\n", world.width, world.height))
    os.write_string(file, fmt.tprintf("# States: %d, Actions: %d\n", agent.num_states, agent.num_actions))
    os.write_string(file, "# Format: state_x,state_y,action_up,action_down,action_left,action_right,best_action\n")
    
    for state in 0..<agent.num_states {
        pos := state_to_position(world, state)
        // Skip wall states
        if !is_walkable(world, pos.x, pos.y) {
            continue
        }
        line := fmt.tprintf("%d,%d", pos.x, pos.y)
        // Write Q-values for all actions
        for action in 0..<agent.num_actions {
            q_val := get_q_value(agent, state, Action(action))
            line = fmt.tprintf("%s,%.3f", line, q_val)
        }
        // Find and write best action
        best_action := select_greedy_action(agent, state)
        line = fmt.tprintf("%s,%d\n", line, int(best_action))
        os.write_string(file, line)
    }
    fmt.printf("Policy saved: %s\n", filename)
}

// Print epoch progress
print_epoch_progress :: proc(epoch: i32, stats: ^Epoch_Stats, agent: ^Q_Agent) {
    fmt.printf("Epoch %d: Reward=%.2f, Steps=%d, Epsilon=%.3f, Avg Q=%.3f\n",
        stats.epoch, stats.total_reward, stats.steps_taken, stats.epsilon_used, stats.avg_q_val)
}

// Calculate average Q-value for current state
calculate_avg_q_value :: proc(agent: ^Q_Agent, state: int) -> f32 {
    sum: f32 
    for action in 0..<agent.num_actions {
        sum += get_q_value(agent, state, Action(action))
    }
    return sum / f32(agent.num_actions)
}

// Create new training control
new_training_control :: proc() -> Training_Control {
    return Training_Control{
        paused = false,
        reset = false,
        exit = false,
        show_q = false,
        speed = 1.0,
        save_req = false,
        load_req = false,
        path = "qtable.dat",
    }
}

// Handle user input during training
handle_input :: proc(control: ^Training_Control, vis_state: ^Visualization_State) {
    if rl.IsKeyPressed(.SPACE) {
        control.paused = !control.paused
        fmt.printf("Training %s\n", control.paused ? "PAUSED" : "RESUMED")
    }
    if rl.IsKeyPressed(.R) {
        control.reset = true
        fmt.printf("Q RESET\n")
    }
    if rl.IsKeyPressed(.V) {
        control.show_q = !control.show_q
        if vis_state != nil {
            vis_state.config.show_q = control.show_q
        }
        fmt.printf("Q-values: %s\n", control.show_q ? "ON" : "OFF")
    } 
    // Increase speed
    if rl.IsKeyPressed(.EQUAL) || rl.IsKeyPressed(.KP_ADD) {
        control.speed = math.min(control.speed * 1.5, 10.0)
        fmt.printf("Training Speed: %.1fx\n", control.speed)
    }
    // Decrease speed
    if rl.IsKeyPressed(.MINUS) || rl.IsKeyPressed(.KP_SUBTRACT) {
        control.speed = math.max(control.speed / 1.5, 0.1)
        fmt.printf("Training Speed: %.1fx\n", control.speed)
    }
    if rl.IsKeyPressed(.S) {
        control.save_req = true
        fmt.printf("Save Q-table\n")
    }
    if rl.IsKeyPressed(.L) {
        control.load_req = true
        fmt.printf("Load Q-table\n")
    }
    if rl.IsKeyPressed(.ESCAPE) || rl.WindowShouldClose() {
        control.exit = true
        fmt.printf("Exit\n")
    }
    if rl.IsKeyPressed(.Q) && vis_state != nil {
        vis_state.config.show_q = !vis_state.config.show_q
        control.show_q = vis_state.config.show_q
    }
    if rl.IsKeyPressed(.G) && vis_state != nil {
        vis_state.config.show_grid = !vis_state.config.show_grid
    }
    if rl.IsKeyPressed(.F) && vis_state != nil {
        vis_state.config.show_fps = !vis_state.config.show_fps
        fmt.printf("FPS: %s\n", vis_state.config.show_fps ? "ON" : "OFF")
    }
}

// Main training procedure
train :: proc(world: ^Grid, agent: ^Q_Agent, config: ^Training_Config) {
    fmt.printf("Starting Q-Learning\nEpochs: %d, Max steps per epoch: %d\n", 
        config.num_epochs, config.max_steps_in_epoch)
    fmt.printf("Visualization: %s\n", config.visualize ? "ON" : "OFF")
    
    control := new_training_control()
    stats := new_training_stats(config.num_epochs)
    if stats == nil {
        fmt.printf("Error: Could not create training stats\n")
        return
    }
    defer destroy_training_stats(stats)
    
    vis_state: ^Visualization_State = nil
    if config.visualize {
        CELL_SIZE :: 40
        // init_graphics(800, 600)
        vis_state = get_visualization_state()
        defer cleanup_graphics()
    }
    start_time := time.now()
    epoch: i32
    training_loop: for epoch < config.num_epochs && !control.exit {
        // Handle reset
        if control.reset {
            fmt.printf("Resetting training...\n")
            epoch = 0
            // Reset Q-table
            for s in 0..<agent.num_states {
                for a in 0..<agent.num_actions {
                    agent.q_table[s][a]  = 0
                }
            }
            agent.epsilon = 1.0
            destroy_training_stats(stats)
            stats = new_training_stats(config.num_epochs)
            control.reset = false
            start_time = time.now()
        }
        reset_environment(world)
        epoch_reward, total_q_value: f32
        steps_taken, q_value_count: i32
        epoch_loop: for world.grid != nil && steps_taken < config.max_steps_in_epoch && !control.exit {
            if config.visualize {
                handle_input(&control, vis_state)
                if control.save_req {
                    if save_q_table_to(agent, control.path) {
                        fmt.printf("Q-table saved\n")
                    }
                    control.save_req = false
                }
                if control.load_req {
                    if load_q_table(agent, control.path) {
                        fmt.printf("Q-table loaded\n")
                    }
                    control.load_req = false
                }
                if control.exit {
                    fmt.printf("Training interrupted\n")
                    break training_loop
                }
                if control.paused {
                    rl.BeginDrawing()
                    rl.ClearBackground(rl.RAYWHITE)
                    
                    if control.show_q {
                        draw_q_values(vis_state, world, agent)
                    } else {
                        draw_grid_world(vis_state, world)
                    }
                    draw_walls(vis_state, world)
                    draw_goal(vis_state, world.goal_pos)
                    draw_agent(vis_state, world.agent_pos)
                    
                    status_text := fmt.tprintf("TRAINING PAUSED - Epoch: %d/%d | Speed: %.1fx", 
                        epoch + 1, config.num_epochs, control.speed)
                    rl.DrawText(strings.clone_to_cstring(status_text), 10, 10, 20, rl.RED)
                    
                    controls_text := "SPACE: Resume | R: Reset | V: Q-vals | S: Save | L: Load | ESC: Exit"
                    rl.DrawText(strings.clone_to_cstring(controls_text), 10, rl.GetScreenHeight() - 50, 12, rl.DARKBLUE)
                    
                    draw_fps_counter(vis_state)
                    rl.EndDrawing()
                    rl.WaitTime(0.016) // ~60 FPS
                    continue epoch_loop
                }
            }
            // Get current state
            current_state := get_state_index(world)
            // Select action using epsilon-greedy policy
            action := select_action(agent, current_state)
            // Take action
            result := step_environment(world, action)
            // Update Q-value
            next_state := position_to_state(world, result.next_state.position)
            update_q_value(agent, nil, current_state, action, result.reward, next_state, result.done)
            // Accumulate stats
            epoch_reward += result.reward
            steps_taken += 1
            avg_q := calculate_avg_q_value(agent, current_state)
            total_q_value += avg_q
            q_value_count += 1
            // Render visualization
            if config.visualize {
                rl.BeginDrawing()
                rl.ClearBackground(rl.RAYWHITE)
                if control.show_q {
                    draw_q_values(vis_state, world, agent)
                } else {
                    draw_grid_world(vis_state, world)
                }
                draw_walls(vis_state, world)
                draw_goal(vis_state, world.goal_pos)
                draw_agent(vis_state, world.agent_pos)
                // Draw info
                info_text := fmt.tprintf("Epoch: %d/%d | Step: %d | Reward: %.1f | Epsilon: %.3f | Speed: %.1fx",
                    epoch + 1, config.num_epochs, steps_taken, epoch_reward, 
                    agent.epsilon, control.speed)
                rl.DrawText(strings.clone_to_cstring(info_text), 10, 10, 16, rl.BLACK)
                
                action_name := ""
                #partial switch action {
                case .UP: action_name = "UP"
                case .DOWN: action_name = "DOWN"
                case .LEFT: action_name = "LEFT"
                case .RIGHT: action_name = "RIGHT"
                }
                agent_info := fmt.tprintf("Agent: (%d,%d) | Action: %s | Q-values: %s",
                    world.agent_pos.x, world.agent_pos.y, action_name,
                    control.show_q ? "ON" : "OFF")
                rl.DrawText(strings.clone_to_cstring(agent_info), 10, 30, 14, rl.DARKGRAY)
                
                controls_text := "SPACE: Pause | R: Reset | V: Q-values | +/-: Speed | S: Save | L: Load | ESC: Exit"
                rl.DrawText(strings.clone_to_cstring(controls_text), 10, rl.GetScreenHeight() - 30, 12, rl.DARKBLUE)
                draw_fps_counter(vis_state)
                rl.EndDrawing()
                delay := 0.05 / f64(control.speed)
                rl.WaitTime(delay)
            }
        } // End of epoch
        decay_epsilon(agent)

        q_variance := calc_q_val_variance(agent)
        goal_reached := (world.agent_pos.x == world.goal_pos.x && world.agent_pos.y == world.goal_pos.y)
        avg_q_epoch := q_value_count > 0 ? total_q_value / f32(q_value_count) : 0.0
        
        record_epoch(stats, epoch, epoch_reward, steps_taken, agent.epsilon, avg_q_epoch)
        update_performance_metrics(stats.metrics, stats, epoch, b32(goal_reached), q_variance)
        
        converged := check_convergence(stats.metrics, epoch)
        if converged && !config.visualize {
            fmt.printf("Training converged at epoch %d!\n", epoch + 1)
        }
        // Print progress
        if config.show_progress && (epoch + 1) % config.progress_interval == 0 {
            epoch_stats := &stats.epochs[epoch]
            print_epoch_progress(epoch + 1, epoch_stats, agent)
            // Print learning curves every 200 epochs
            if (epoch + 1) % (config.progress_interval * 2) == 0 {
                print_learning_curves(stats, 20)
            }
            // Print convergence analysis every 100 epochs
            if (epoch + 1) % config.progress_interval == 0 {
                print_convergence(stats.metrics, epoch)
            }
        }
        epoch += 1
    }
    end_time := time.now()
    training_duration := time.duration_seconds(time.diff(start_time, end_time))
    fmt.printf("\nTraining completed!\n")
    fmt.printf("Training time: %.2f seconds\n", training_duration)
    fmt.printf("Training speed: %.1fx\n", control.speed)
    print_summary(stats)
    print_learning_curves(stats, 50)  // Show last 50 epochs
    print_convergence(stats.metrics, epoch - 1)
    save_performance_data(stats, "performance_data.csv")
    if config.save_policy && len(config.policy_path) > 0 {
        save_policy(agent, world, config.policy_path)
    }
    if config.visualize {
        if save_q_table_to(agent, control.path) {
            fmt.printf("Q-table auto-saved to %s\n", control.path)
        }
    }
    // Print stats
    if stats.metrics != nil && stats.current_epoch > 0 {
        fmt.printf("Epochs completed: %d\n", stats.current_epoch)
        fmt.printf("Best epoch: %d (reward: %.2f)\n", stats.best_epoch + 1, stats.best_reward)
        fmt.printf("Training converged: %s\n", stats.metrics.has_converged ? "Yes" : "No")
        
        if stats.metrics.has_converged {
            fmt.printf("Convergence epoch: %d\n", stats.metrics.convergence_epoch + 1)
        }
        successful_epochs := 0
        for i in 0..<stats.current_epoch {
            if stats.metrics.success_epochs[i] {
                successful_epochs += 1
            }
        }
        rate := f32(successful_epochs) / f32(stats.current_epoch) * 100.0
        fmt.printf("Overall success rate: %.1f%% (%d/%d epochs)\n", 
            rate, successful_epochs, stats.current_epoch)
    }
}

default_config :: proc() -> Training_Config {
    return Training_Config{
        num_epochs = 1000,
        max_steps_in_epoch = 200,
        visualize = false,
        save_policy = true,
        show_progress = true,
        progress_interval = 100,
        policy_path = "qpolicy.txt",
    }
}

// Parse command line arguments
parse_arguments :: proc(args: []string) -> Training_Config {
    config := default_config()
    for i in 1..<len(args) {
        arg := args[i]
        switch arg {
        case "--epochs":
            if i + 1 < len(args) {
                if epochs, ok := strconv.parse_int(args[i + 1]); ok {
                    config.num_epochs = i32(epochs)
                } else {
                    fmt.printf("Error: Invalid value for --epochs: %s\n", args[i + 1])
                }
            }
        case "--max-steps":
            if i + 1 < len(args) {
                if steps, ok := strconv.parse_int(args[i + 1]); ok {
                    config.max_steps_in_epoch = i32(steps)
                } else {
                    fmt.printf("Error: Invalid value for --max-steps: %s\n", args[i + 1])
                }
            }
        case "--visualize":
            config.visualize = true
        case "--no-save":
            config.save_policy = false
        case "--quiet":
            config.show_progress = false
        case "--policy":
            if i + 1 < len(args) {
                config.policy_path = args[i + 1]
            } else {
                fmt.printf("Error: --policy requires a file path argument\n")
            }
        case:
            fmt.printf("Warning: Unknown argument '%s'. Ignoring.\n", arg)
        }
    }
    return config
}

/*
# Basic training with defaults
./qlearn

# With visualization
./qlearn --visualize

# Custom epochs and steps
./qlearn --epochs 2000 --max-steps 300

# Quiet mode
./qlearn --quiet

# Custom policy
./qlearn --policy my_policy.txt
*/

main :: proc() {
    config := parse_arguments(os.args)
    world := new_grid(10, 10)
    if world == nil {
        fmt.printf("Error: Failed to create grid\n")
        return
    }
    defer destroy_grid(world)
    
    world.start_pos = {1, 1}
    world.goal_pos = {8, 8}
    world.step_penalty = -0.1
    world.goal_reward = 100.0
    world.wall_penalty = -10.0
    world.max_steps = config.max_steps_in_epoch
    // Add walls
    set_cell(world, 3, 3, .WALL)
    set_cell(world, 3, 4, .WALL)
    set_cell(world, 3, 5, .WALL)
    set_cell(world, 5, 2, .WALL)
    set_cell(world, 5, 3, .WALL)
    set_cell(world, 5, 4, .WALL)
    set_cell(world, 7, 6, .WALL)
    set_cell(world, 7, 7, .WALL)
    // Mark goal and start positions
    set_cell(world, world.goal_pos.x, world.goal_pos.y, .GOAL)
    set_cell(world, world.start_pos.x, world.start_pos.y, .START)
    // Create agent
    num_states := int(world.width * world.height)
    agent := new_agent(num_states, len(Action), 0.1, 0.9, 1.0)
    if agent == nil {
        fmt.printf("Error: Failed to create agent\n")
        return
    }
    defer destroy_agent(agent)

    agent.epsilon_decay = 0.995
    agent.epsilon_min = 0.01
    fmt.printf("Agent:\n")
    fmt.printf(" Learning rate: %.3f\n", agent.learning_rate)
    fmt.printf(" Discount factor: %.3f\n", agent.discount_factor)
    fmt.printf(" Epsilon: %.3f\n", agent.epsilon)
    fmt.printf(" Epsilon decay: %.3f\n", agent.epsilon_decay)
    fmt.printf(" Min epsilon: %.3f\n", agent.epsilon_min)

    if !validate_env(world) {
        fmt.printf("Error: Invalid env config\n")
        return
    }
    print_env_info(world)
    train(world, agent, &config)
    fmt.printf("Training complete\n")
}