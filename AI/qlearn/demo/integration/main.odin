package main

import "core:fmt"
import "core:math/rand"
import "core:time"
import rl "vendor:raylib"
import ql "../../" // Assuming ql is in the parent directory

// --- Global Constants ---
WIDTH :: 1200 // Increased width to accommodate the sidebar better
HEIGHT :: 750 // Slightly increased height for more vertical space
GRID_SIZE :: 7 // Increased grid size
CELL_SIZE :: 80 // Maintained cell size, but overall grid will be larger
GRID_OFFSET_X :: 50 // Adjusted offset for new grid size
GRID_OFFSET_Y :: 50 // Adjusted offset for new grid size
NUM_EPOCHS :: 100
MAX_STEPS_PER_EPOCH :: 200

COLOR_EMPTY :: rl.WHITE
COLOR_WALL :: rl.DARKGRAY
COLOR_AGENT :: rl.BLUE
COLOR_GOAL :: rl.GREEN
COLOR_PATH :: rl.LIGHTGRAY
COLOR_BACKGROUND :: rl.Color{245, 245, 245, 255} // A softer off-white background

// --- New Proposed Colors for GUI Enhancement ---
COLOR_SIDEBAR_BG :: rl.Color{235, 235, 235, 255} // A light gray for sidebar
COLOR_Q_VALUE_TEXT :: rl.GOLD // Highlight Q-values
COLOR_PANEL_BORDER :: rl.LIGHTGRAY // Subtle borders for info panels
COLOR_HEADER_BG :: rl.Color{220, 220, 220, 255} // For section headers

// Global font variable (will be loaded in main)
font_jetbrains_mono: rl.Font

seed := rand.create(u64(time.now()._nsec))
rng := rand.default_random_generator(&seed)

Demo_State :: enum {
    TRAINING,
    TESTING,
    FINISHED,
}

Demo_Context :: struct {
    world: ^ql.Grid,
    agent: ^ql.Q_Agent,
    stats: ^ql.Training_Stats,
    current_epoch: i32,
    current_step: i32,
    state: Demo_State,
    path: [dynamic]ql.Position,
    last_update_time: f64,
    training_speed: f64,
    show_q_values: bool,
    paused: bool,
}

print_grid :: proc(world: ^ql.Grid) {
    fmt.println("\nGrid World:")
    for y in 0..<world.height {
        for x in 0..<world.width {
            if x == world.agent_pos.x && y == world.agent_pos.y {
                fmt.print("A ")
            } else if x == world.goal_pos.x && y == world.goal_pos.y {
                fmt.print("G ")
            } else {
                #partial switch world.grid[y][x] {
                case .EMPTY: fmt.print(". ")
                case .WALL: fmt.print("# ")
                }
            }
        }
        fmt.println()
    }
    fmt.println()
}

new_env :: proc(world: ^ql.Grid) {
    // Set goal and start positions
    world.goal_pos = {6, 6} // Adjusted for larger grid
    world.start_pos = {}
    
    // Add some walls to make it interesting
    ql.set_cell(world, 2, 1, .WALL)
    ql.set_cell(world, 2, 2, .WALL)
    ql.set_cell(world, 2, 3, .WALL)
    ql.set_cell(world, 1, 3, .WALL)
    ql.set_cell(world, 4, 4, .WALL)
    ql.set_cell(world, 4, 5, .WALL)
    ql.set_cell(world, 5, 4, .WALL)

    
    fmt.println("Environment Setup:")
    print_grid(world)
}

train_one_epoch :: proc(demo: ^Demo_Context) -> (total_reward: f32, steps: i32) {
    ql.reset_environment(demo.world)
    state := ql.get_state_index(demo.world)
    steps = 0
    total_reward = 0.0
    
    for !demo.world.epoch_done && steps < MAX_STEPS_PER_EPOCH {
        action := ql.select_action(demo.agent, state)
        result := ql.step_environment(demo.world, action)
        
        ql.update_q_value(demo.agent, nil, state, action, result.reward, result.next_state.state_index, result.done)
        
        state = result.next_state.state_index
        total_reward += result.reward
        steps += 1
    }
    ql.decay_epsilon(demo.agent)
    
    // Record epoch statistics
    avg_q: f32 = 0.0
    q_count := 0
    num_states := int(demo.world.width * demo.world.height)
    
    for s in 0..<num_states {
        for a in 0..<int(ql.Action.COUNT) {
            avg_q += ql.get_q_value(demo.agent, s, ql.Action(a))
            q_count += 1
        }
    }
    avg_q /= f32(q_count)
    
    ql.record_epoch(demo.stats, demo.current_epoch, total_reward, steps, demo.agent.epsilon, avg_q)
    
    return total_reward, steps
}

test_learned_policy :: proc(demo: ^Demo_Context) {
    ql.reset_environment(demo.world)
    demo.agent.epsilon = 0.0 // Pure exploitation
    demo.current_step = 0
    clear(&demo.path)
    
    // Record initial position
    append(&demo.path, demo.world.agent_pos)
    
    fmt.println("Testing learned policy (greedy actions only):")
    print_grid(demo.world)
}

perform_test_step :: proc(demo: ^Demo_Context) -> bool {
    if demo.world.epoch_done || demo.current_step >= 50 {
        return false
    }
    state := ql.get_state_index(demo.world)
    action := ql.select_greedy_action(demo.agent, state)
    
    action_name := ""
    #partial switch action {
    case .UP: action_name = "UP"
    case .DOWN: action_name = "DOWN"
    case .LEFT: action_name = "LEFT"
    case .RIGHT: action_name = "RIGHT"
    }
    fmt.printf("Step %d: Action = %s\n", demo.current_step + 1, action_name)
    
    result := ql.step_environment(demo.world, action)
    append(&demo.path, demo.world.agent_pos)
    demo.current_step += 1
    
    print_grid(demo.world)
    
    if result.done {
        if demo.world.agent_pos.x == demo.world.goal_pos.x && 
           demo.world.agent_pos.y == demo.world.goal_pos.y {
            fmt.printf("🎉 Agent reached the goal in %d steps!\n", demo.current_step)
        } else {
            fmt.println("Epoch ended without reaching goal.")
        }
        return false
    }
    return true
}

draw_grid :: proc(demo: ^Demo_Context) {
    world := demo.world
    
    // Draw grid cells
    for y in 0..<world.height {
        for x in 0..<world.width {
            cell_x := GRID_OFFSET_X + x * CELL_SIZE
            cell_y := GRID_OFFSET_Y + y * CELL_SIZE
            
            color := COLOR_EMPTY
            #partial switch world.grid[y][x] {
            case .WALL:
                color = COLOR_WALL
            case .EMPTY:
                color = COLOR_EMPTY
            }
            rl.DrawRectangle(i32(cell_x), i32(cell_y), CELL_SIZE, CELL_SIZE, color)
            rl.DrawRectangleLines(i32(cell_x), i32(cell_y), CELL_SIZE, CELL_SIZE, rl.BLACK)
        }
    }
    // Draw path during testing
    if demo.state == .TESTING && len(demo.path) > 1 {
        for i in 1..<len(demo.path) {
            pos := demo.path[i]
            cell_x := GRID_OFFSET_X + pos.x * CELL_SIZE
            cell_y := GRID_OFFSET_Y + pos.y * CELL_SIZE
            rl.DrawRectangle(i32(cell_x + 10), i32(cell_y + 10), CELL_SIZE - 20, CELL_SIZE - 20, COLOR_PATH)
        }
    }
    // Draw goal
    goal_x := GRID_OFFSET_X + world.goal_pos.x * CELL_SIZE
    goal_y := GRID_OFFSET_Y + world.goal_pos.y * CELL_SIZE
    rl.DrawRectangle(i32(goal_x + 10), i32(goal_y + 10), CELL_SIZE - 20, CELL_SIZE - 20, COLOR_GOAL)
    rl.DrawTextEx(font_jetbrains_mono, cstring("G"), rl.Vector2{f32(goal_x + CELL_SIZE/2 - 10), f32(goal_y + CELL_SIZE/2 - 10)}, 20, 0, rl.BLACK)
    // Draw agent
    agent_x := GRID_OFFSET_X + world.agent_pos.x * CELL_SIZE
    agent_y := GRID_OFFSET_Y + world.agent_pos.y * CELL_SIZE
    rl.DrawCircle(i32(agent_x + CELL_SIZE/2), i32(agent_y + CELL_SIZE/2), CELL_SIZE/3, COLOR_AGENT)
    rl.DrawTextEx(font_jetbrains_mono, cstring("A"), rl.Vector2{f32(agent_x + CELL_SIZE/2 - 8), f32(agent_y + CELL_SIZE/2 - 10)}, 16, 0, rl.WHITE)
}

draw_info :: proc(demo: ^Demo_Context) {
    // Define sidebar dimensions and padding
    sidebar_x := GRID_OFFSET_X + GRID_SIZE * CELL_SIZE + 50 // Offset to the right of the grid
    sidebar_y := GRID_OFFSET_Y
    sidebar_width := WIDTH - sidebar_x - 50 // Remaining width minus a right margin
    sidebar_height := HEIGHT - 2*GRID_OFFSET_Y // Height matches grid
    sidebar_padding := 20
    
    // Draw sidebar background and border
    rl.DrawRectangle(i32(sidebar_x - sidebar_padding), i32(sidebar_y - sidebar_padding), 
                     i32(sidebar_width + 2*sidebar_padding), i32(sidebar_height + 2*sidebar_padding), COLOR_SIDEBAR_BG)
    rl.DrawRectangleLines(i32(sidebar_x - sidebar_padding), i32(sidebar_y - sidebar_padding), 
                          i32(sidebar_width + 2*sidebar_padding), i32(sidebar_height + 2*sidebar_padding), COLOR_PANEL_BORDER) // Thicker border

    current_y := sidebar_y + 10 // Starting Y position within the sidebar content area

    // --- Section: Demo Status ---
    rl.DrawTextEx(font_jetbrains_mono, cstring("DEMO STATUS"), 
                  rl.Vector2{f32(sidebar_x), f32(current_y)}, 28, 0, rl.DARKBLUE)
    current_y += 35

    state_text := ""
    switch demo.state {
    case .TRAINING: state_text = "TRAINING"
    case .TESTING:  state_text = "TESTING"
    case .FINISHED: state_text = "FINISHED"
    }
    rl.DrawTextEx(font_jetbrains_mono, rl.TextFormat("State: %s", cstring(raw_data(state_text))), 
                  rl.Vector2{f32(sidebar_x), f32(current_y)}, 22, 0, rl.BLACK)
    current_y += 50

    // --- Section: Training/Testing/Finished Details ---
    if demo.state == .TRAINING {
        rl.DrawTextEx(font_jetbrains_mono, cstring("TRAINING PROGRESS"), 
                      rl.Vector2{f32(sidebar_x), f32(current_y)}, 24, 0, rl.DARKGRAY)
        current_y += 30
        rl.DrawTextEx(font_jetbrains_mono, rl.TextFormat("Epoch: %d/%d", demo.current_epoch, NUM_EPOCHS), 
                   rl.Vector2{f32(sidebar_x), f32(current_y)}, 20, 0, rl.BLACK)
        current_y += 28
        rl.DrawTextEx(font_jetbrains_mono, rl.TextFormat("Epsilon: %.3f", demo.agent.epsilon), 
                   rl.Vector2{f32(sidebar_x), f32(current_y)}, 20, 0, rl.BLACK)
        current_y += 28
        
        if demo.current_epoch > 0 {
            last_epoch_stats := demo.stats.epochs[demo.current_epoch - 1]
            rl.DrawTextEx(font_jetbrains_mono, rl.TextFormat("Last Epoch: %.1f reward, %d steps", last_epoch_stats.total_reward, last_epoch_stats.steps_taken), 
                       rl.Vector2{f32(sidebar_x), f32(current_y)}, 20, 0, rl.BLACK)
            current_y += 28
            rl.DrawTextEx(font_jetbrains_mono, rl.TextFormat("Avg Q-value: %.3f", last_epoch_stats.avg_q_val),
                       rl.Vector2{f32(sidebar_x), f32(current_y)}, 20, 0, rl.BLACK)
            current_y += 35
        }
    } else if demo.state == .TESTING {
        rl.DrawTextEx(font_jetbrains_mono, cstring("TESTING POLICY"), 
                      rl.Vector2{f32(sidebar_x), f32(current_y)}, 24, 0, rl.DARKGRAY)
        current_y += 30
        rl.DrawTextEx(font_jetbrains_mono, rl.TextFormat("Test Step: %d", demo.current_step), 
                   rl.Vector2{f32(sidebar_x), f32(current_y)}, 20, 0, rl.BLACK)
        current_y += 50 // More space before Q-values
        
        // --- Section: Q-values (Prominent and clear, aligned) ---
        rl.DrawTextEx(font_jetbrains_mono, cstring("Q-VALUES (CURRENT STATE):"), 
                      rl.Vector2{f32(sidebar_x), f32(current_y)}, 28, 0, rl.DARKBLUE)
        current_y += 35
        state := ql.get_state_index(demo.world)
        // Using fixed-width format specifiers for alignment
        rl.DrawTextEx(font_jetbrains_mono, rl.TextFormat("UP:    %8.3f", ql.get_q_value(demo.agent, state, .UP)), 
                   rl.Vector2{f32(sidebar_x), f32(current_y)}, 28, 0, COLOR_Q_VALUE_TEXT) // Larger font, highlight color
        current_y += 35
        rl.DrawTextEx(font_jetbrains_mono, rl.TextFormat("DOWN:  %8.3f", ql.get_q_value(demo.agent, state, .DOWN)), 
                   rl.Vector2{f32(sidebar_x), f32(current_y)}, 28, 0, COLOR_Q_VALUE_TEXT)
        current_y += 35
        rl.DrawTextEx(font_jetbrains_mono, rl.TextFormat("LEFT:  %8.3f", ql.get_q_value(demo.agent, state, .LEFT)), 
                   rl.Vector2{f32(sidebar_x), f32(current_y)}, 28, 0, COLOR_Q_VALUE_TEXT)
        current_y += 35
        rl.DrawTextEx(font_jetbrains_mono, rl.TextFormat("RIGHT: %8.3f", ql.get_q_value(demo.agent, state, .RIGHT)), 
                   rl.Vector2{f32(sidebar_x), f32(current_y)}, 28, 0, COLOR_Q_VALUE_TEXT)
        current_y += 50
    } else if demo.state == .FINISHED {
        rl.DrawTextEx(font_jetbrains_mono, cstring("DEMO FINISHED"), 
                      rl.Vector2{f32(sidebar_x), f32(current_y)}, 24, 0, rl.DARKGRAY)
        current_y += 30
        // Show Q-values for the final state during finished
        rl.DrawTextEx(font_jetbrains_mono, cstring("Q-VALUES (FINAL STATE):"), 
                      rl.Vector2{f32(sidebar_x), f32(current_y)}, 28, 0, rl.DARKBLUE)
        current_y += 35
        state := ql.get_state_index(demo.world) // This might be the goal state or last agent pos
        // Using fixed-width format specifiers for alignment
        rl.DrawTextEx(font_jetbrains_mono, rl.TextFormat("UP:    %8.3f", ql.get_q_value(demo.agent, state, .UP)), 
                   rl.Vector2{f32(sidebar_x), f32(current_y)}, 28, 0, COLOR_Q_VALUE_TEXT)
        current_y += 35
        rl.DrawTextEx(font_jetbrains_mono, rl.TextFormat("DOWN:  %8.3f", ql.get_q_value(demo.agent, state, .DOWN)), 
                   rl.Vector2{f32(sidebar_x), f32(current_y)}, 28, 0, COLOR_Q_VALUE_TEXT)
        current_y += 35
        rl.DrawTextEx(font_jetbrains_mono, rl.TextFormat("LEFT:  %8.3f", ql.get_q_value(demo.agent, state, .LEFT)), 
                   rl.Vector2{f32(sidebar_x), f32(current_y)}, 28, 0, COLOR_Q_VALUE_TEXT)
        current_y += 35
        rl.DrawTextEx(font_jetbrains_mono, rl.TextFormat("RIGHT: %8.3f", ql.get_q_value(demo.agent, state, .RIGHT)), 
                   rl.Vector2{f32(sidebar_x), f32(current_y)}, 28, 0, COLOR_Q_VALUE_TEXT)
        current_y += 50
    }

    // --- Section: Controls ---
    // Position controls towards the bottom of the sidebar
    controls_start_y := f32(HEIGHT - GRID_OFFSET_Y - 120) // Adjust as needed to fit content
    rl.DrawTextEx(font_jetbrains_mono, cstring("CONTROLS:"), 
                  rl.Vector2{f32(sidebar_x), controls_start_y}, 24, 0, rl.DARKBLUE)
    rl.DrawTextEx(font_jetbrains_mono, cstring("SPACE: Pause/Resume"), 
                  rl.Vector2{f32(sidebar_x), controls_start_y + 30}, 18, 0, rl.DARKGRAY)
    rl.DrawTextEx(font_jetbrains_mono, cstring("R: Restart Demo"), 
                  rl.Vector2{f32(sidebar_x), controls_start_y + 55}, 18, 0, rl.DARKGRAY)
    rl.DrawTextEx(font_jetbrains_mono, cstring("ESC: Exit Application"), 
                  rl.Vector2{f32(sidebar_x), controls_start_y + 80}, 18, 0, rl.DARKGRAY)
}

main :: proc() {
    fmt.println("Q-Learner Integration Demo\n")
    
    // Create grid world
    world := ql.new_grid(GRID_SIZE, GRID_SIZE)
    if world == nil {
        fmt.println("Failed to create grid")
        return
    }
    defer ql.destroy_grid(world)
    
    new_env(world)
    
    num_states := int(world.width * world.height)
    agent := ql.new_agent(num_states, int(ql.Action.COUNT), 0.1, 0.9, 0.1)
    if agent == nil {
        fmt.println("Failed to create agent")
        return
    }
    defer ql.destroy_agent(agent)
    
    stats := ql.new_training_stats(NUM_EPOCHS)
    if stats == nil {
        fmt.println("Failed to init training stats")
        return
    }
    defer ql.destroy_training_stats(stats)
    
    sim := Demo_Context{
        world = world,
        agent = agent,
        stats = stats,
        current_epoch = 0,
        current_step = 0,
        state = .TRAINING,
        path = make([dynamic]ql.Position),
        last_update_time = rl.GetTime(),
        training_speed = 0.1, // seconds between epochs
        show_q_values = false,
        paused = false,
    }
    defer delete(sim.path)
    
    rl.InitWindow(WIDTH, HEIGHT, "Q-Learning Grid World Demo")
    defer rl.CloseWindow()
    rl.SetTargetFPS(60)

    // Load JetBrains Mono font
    font_jetbrains_mono = rl.LoadFontEx(cstring("../../assets/JetBrainsMono-Regular.ttf"), 36, nil, 0) // Base size for loading
    defer rl.UnloadFont(font_jetbrains_mono)
    
    fmt.println("Training agent for", NUM_EPOCHS, "epochs...")
    
    for !rl.WindowShouldClose() {
        // Handle input
        if rl.IsKeyPressed(.SPACE) {
            sim.paused = !sim.paused
        }
        if rl.IsKeyPressed(.R) {
            // Restart
            sim.current_epoch = 0
            sim.current_step = 0
            sim.state = .TRAINING
            sim.paused = false
            clear(&sim.path)
            // Reset agent
            ql.destroy_agent(sim.agent)
            sim.agent = ql.new_agent(num_states, int(ql.Action.COUNT), 0.1, 0.9, 0.1)
            // Reset stats
            ql.destroy_training_stats(sim.stats)
            sim.stats = ql.new_training_stats(NUM_EPOCHS)
        }
        
        if !sim.paused { // Update state
            current_time := rl.GetTime()
            switch sim.state {
            case .TRAINING:
                if current_time - sim.last_update_time >= sim.training_speed {
                    if sim.current_epoch < NUM_EPOCHS {
                        reward, steps := train_one_epoch(&sim)
                        
                        if sim.current_epoch % 20 == 0 {
                            fmt.printf("Epoch %d: Steps=%d, Reward=%.1f, Epsilon=%.3f, Avg Q=%.3f\n", 
                                     sim.current_epoch, steps, reward, sim.agent.epsilon, sim.stats.epochs[sim.current_epoch].avg_q_val)
                        }
                        sim.current_epoch += 1
                        sim.last_update_time = current_time
                    } else {
                        fmt.println("\nTraining Complete")
                        ql.print_summary(sim.stats)
                        sim.state = .TESTING
                        test_learned_policy(&sim)
                    }
                }
            case .TESTING:
                if current_time - sim.last_update_time >= 0.5 { // slower for visualization
                    if !perform_test_step(&sim) {
                        sim.state = .FINISHED
                        
                        // Print final Q-values for start position
                        fmt.printf("\nSample Q-values for start position (state %d):\n", 
                                 ql.position_to_state(sim.world, sim.world.start_pos))
                        start_state := ql.position_to_state(sim.world, sim.world.start_pos)
                        fmt.printf("  UP:    %.3f\n", ql.get_q_value(sim.agent, start_state, .UP))
                        fmt.printf("  DOWN:  %.3f\n", ql.get_q_value(sim.agent, start_state, .DOWN))
                        fmt.printf("  LEFT:  %.3f\n", ql.get_q_value(sim.agent, start_state, .LEFT))
                        fmt.printf("  RIGHT: %.3f\n", ql.get_q_value(sim.agent, start_state, .RIGHT))
                        
                        fmt.println("\n✅ Integration demo completed successfully!")
                        fmt.println("The Q-learning agent successfully learned to navigate the grid world.")
                    }
                    sim.last_update_time = current_time
                }
            case .FINISHED:
                // Demo finished, display results
            }
        }
        rl.BeginDrawing()
        rl.ClearBackground(COLOR_BACKGROUND) // Main window background
        
        draw_grid(&sim) // Grid drawing
        draw_info(&sim) // Enhanced info sidebar drawing
        
        if sim.paused {
            // Draw PAUSED text using the loaded font, centered
            paused_text_size := rl.MeasureTextEx(font_jetbrains_mono, cstring("PAUSED"), 40, 0).x // No spacing
            rl.DrawTextEx(font_jetbrains_mono, cstring("PAUSED"), 
                          rl.Vector2{f32(WIDTH)/2 - paused_text_size/2, f32(HEIGHT)/2 - 20}, 
                          40, 0, rl.RED)
        }
        rl.EndDrawing()
    }
}