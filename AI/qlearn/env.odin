package qlearn

import "core:fmt"
import "core:mem"
import rl "vendor:raylib"

Action :: enum {
    UP,
    DOWN,
    LEFT,
    RIGHT,
    COUNT,
}

Position :: struct { x, y: i32 }

State :: struct {
    state_index: int,
    position: Position,
    is_terminal,
    is_valid: bool,
}

Step_Result :: struct {
    next_state: State,
    reward:       f32,
    done,
    valid_action: bool,
}

Environment_Config :: struct {
    width, height,
    max_steps: i32,
    step_penalty, goal_reward, wall_penalty: f32,
}

Grid :: struct {
    grid: [][]Cell_Type,

    width, height, epoch_steps, max_steps: i32,
    epoch_done: bool,
    
    agent_pos, start_pos, goal_pos: Position,

    step_penalty, goal_reward, wall_penalty, total_reward: f32,
}

// Create a new grid environment
new_grid :: proc(width, height: i32, allocator := context.allocator) -> ^Grid {
    // Validate input parameters
    if width <= 0 || height <= 0 {
        fmt.eprintf("Error: Grid dimensions must be positive (width=%d, height=%d)\n", width, height)
        return nil
    }
    
    // Allocate memory for the GridWorld structure
    world := new(Grid, allocator)
    
    // Init basic dimensions
    world.width = width
    world.height = height
    
    // Allocate memory for the 2D grid
    world.grid = make([][]Cell_Type, height, allocator)
    
    // Allocate memory for each row and initialize to empty
    for y in 0..<height {
        world.grid[y] = make([]Cell_Type, width, allocator)
        
        // Init all cells to empty
        for x in 0..<width {
            world.grid[y][x] = .EMPTY
        }
    }
    
    // Init positions (default: agent at top-left, goal at bottom-right)
    world.agent_pos = {}
    world.start_pos = {}
    world.goal_pos = {width - 1, height - 1}
    
    // Mark the start and goal positions in the grid
    world.grid[world.start_pos.y][world.start_pos.x] = .START
    world.grid[world.goal_pos.y][world.goal_pos.x] = .GOAL
    
    // Init epoch tracking variables
    world.epoch_steps = 0
    world.epoch_done = false
    world.total_reward = 0
    
    // Set default config values
    world.max_steps = width * height * 2  // Reasonable upper bound
    world.step_penalty = -1.              // Small penalty for each step
    world.goal_reward = 100               // Large reward for reaching goal
    world.wall_penalty = -10.             // Penalty for hitting walls
    
    fmt.printf("Created grid: %dx%d, agent at (%d,%d), goal at (%d,%d)\n", 
               width, height, world.agent_pos.x, world.agent_pos.y, 
               world.goal_pos.x, world.goal_pos.y)
    
    return world
}

// Create a grid from configuration
new_grid_from_config :: proc(config: Environment_Config, allocator := context.allocator) -> ^Grid {
    // Validate params
    if config.width <= 0 || config.height <= 0 {
        fmt.eprintf("Error: Grid dimensions must be positive (width=%d, height=%d)\n", 
                    config.width, config.height)
        return nil
    }
    if config.max_steps <= 0 {
        fmt.eprintf("Error: max_steps must be positive (max_steps=%d)\n", config.max_steps)
        return nil
    }
    // Create basic grid
    world := new_grid(config.width, config.height, allocator)
    if world == nil {
        return nil
    }
    // Apply config values
    world.step_penalty = config.step_penalty
    world.goal_reward = config.goal_reward
    world.wall_penalty = config.wall_penalty
    world.max_steps = config.max_steps
    // Validate reward values
    if !validate_reward_values(world) {
        fmt.eprintf("Warning: Reward values may not promote optimal learning\n")
    }
    fmt.printf("Created grid from config: %dx%d, rewards: goal=%.1f, wall=%.1f, step=%.1f\n",
               world.width, world.height, world.goal_reward, world.wall_penalty, world.step_penalty)
    
    return world
}

// Reset the environment to initial state
reset_environment :: proc(world: ^Grid) {
    if world == nil {
        fmt.eprintf("Error: Cannot reset nil GridWorld\n")
        return
    }
    // Reset agent to starting position
    world.agent_pos = world.start_pos
    // Reset epoch tracking variables
    world.epoch_steps = 0
    world.epoch_done = false
    world.total_reward = 0.0
    
    fmt.printf("Environment reset: agent at (%d,%d), epoch ready\n", 
               world.agent_pos.x, world.agent_pos.y)
}

// Convert 2D position to 1D state index
get_state_index :: proc(world: ^Grid) -> int {
    if world == nil {
        fmt.eprintf("Error: Cannot get state index from nil GridWorld\n")
        return -1
    }
    return int(world.agent_pos.y * world.width + world.agent_pos.x)
}

// Check if a position is terminal
is_terminal_state :: proc(world: ^Grid, pos: Position) -> bool {
    if world == nil {
        fmt.eprintf("Error: Cannot check terminal state of nil GridWorld\n")
        return true // Safer to assume terminal if invalid
    }
    // Terminal if position reached the goal
    return positions_equal(pos, world.goal_pos)
}

// Execute an action and return the next state
step :: proc(world: ^Grid, action: Action) -> (next_state: int, reward: f32, ok: bool) {
    if world == nil {
        fmt.eprintf("Error: Invalid params for step function\n")
        return -1, 0.0, false
    }
    if world.epoch_done {
        fmt.eprintf("Warning: Epoch already completed, reset environment first\n")
        return get_state_index(world), 0.0, false
    }
    // Save current position
    old_pos := world.agent_pos
    new_pos := old_pos
    
    // Calculate new position based on action
    #partial switch action {
    case .UP:
        new_pos.y = old_pos.y - 1
    case .DOWN:
        new_pos.y = old_pos.y + 1
    case .LEFT:
        new_pos.x = old_pos.x - 1
    case .RIGHT:
        new_pos.x = old_pos.x + 1
    }
    // Check if new position is valid and walkable
    valid_move := is_valid_position(world, new_pos.x, new_pos.y) && 
                  is_walkable(world, new_pos.x, new_pos.y)
    if valid_move {
        // Move agent to new position
        world.agent_pos = new_pos
    }
    // Calculate reward
    reward = calculate_reward(world, old_pos, world.agent_pos, valid_move)
    world.total_reward += reward
    
    // Increment step counter
    world.epoch_steps += 1
    
    // Check if epoch is done
    world.epoch_done = is_terminal_state(world, world.agent_pos) || 
                         (world.epoch_steps >= world.max_steps)
    
    return get_state_index(world), reward, true
}

// Step environment with structured result
step_environment :: proc(world: ^Grid, action: Action) -> Step_Result {
    result := Step_Result{}
    
    if world == nil {
        fmt.eprintf("Error: Cannot step nil GridWorld\n")
        result.next_state.state_index = -1
        result.next_state.is_valid = false
        result.reward = 0.0
        result.done = true
        result.valid_action = false
        return result
    }
    if world.epoch_done {
        fmt.eprintf("Warning: Epoch already completed in step_environment\n")
        result.next_state = get_current_state(world)
        result.reward = 0.0
        result.done = true
        result.valid_action = false
        return result
    }
    // Save current position
    old_pos := world.agent_pos
    new_pos := old_pos
    
    // Calculate new position based on action
    #partial switch action {
    case .UP:
        new_pos.y = old_pos.y - 1
    case .DOWN:
        new_pos.y = old_pos.y + 1
    case .LEFT:
        new_pos.x = old_pos.x - 1
    case .RIGHT:
        new_pos.x = old_pos.x + 1
    }
    // Check if new position is valid and walkable
    valid_move := is_valid_position(world, new_pos.x, new_pos.y) && 
                  is_walkable(world, new_pos.x, new_pos.y)
    if valid_move {
        // Move agent to new position
        world.agent_pos = new_pos
    }
    // Calculate reward
    result.reward = calculate_reward(world, old_pos, world.agent_pos, valid_move)
    world.total_reward += result.reward
    
    // Increment step counter
    world.epoch_steps += 1
    
    // Check if epoch is done
    world.epoch_done = is_terminal_state(world, world.agent_pos) || 
                         (world.epoch_steps >= world.max_steps)
    // Fill result structure
    result.next_state = get_current_state(world)
    result.done = world.epoch_done
    result.valid_action = valid_move
    
    return result
}

// Destroy and free all memory associated with the grid
destroy_grid :: proc(world: ^Grid, allocator := context.allocator) {
    if world == nil {
        return // Nothing to destroy
    }
    // Free the 2D grid
    for row in world.grid {
        delete(row, allocator)
    }
    delete(world.grid, allocator)
    
    // Free the main structure
    free(world, allocator)
    
    fmt.printf("GridWorld destroyed and memory freed\n")
}

// Check if a position is valid (within bounds)
is_valid_position :: proc(world: ^Grid, x, y: i32) -> bool {
    if world == nil do return false
    return x >= 0 && x < world.width && y >= 0 && y < world.height
}

// Check if a position is walkable (not a wall or obstacle)
is_walkable :: proc(world: ^Grid, x, y: i32) -> bool {
    if world == nil || !is_valid_position(world, x, y) {
        return false
    }
    cell := world.grid[y][x]
    return cell != .WALL && cell != .OBSTACLE
}

// Calculate reward based on move
calculate_reward :: proc(world: ^Grid, old_pos, new_pos: Position, valid_move: bool) -> f32 {
    if world == nil do return 0.0
    
    // If invalid move (hit wall), return wall penalty
    if !valid_move {
        return world.wall_penalty
    }
    // If reached goal, return goal reward
    if positions_equal(new_pos, world.goal_pos) {
        return world.goal_reward
    }
    // Otherwise, return step penalty (encourages efficiency)
    return world.step_penalty
}

// Check if two positions are equal
positions_equal :: proc(a, b: Position) -> bool {
    return a.x == b.x && a.y == b.y
}

// Convert 2D position to 1D state index
position_to_state :: proc(world: ^Grid, pos: Position) -> int {
    if world == nil do return -1
    return int(pos.y * world.width + pos.x)
}

// Convert 1D state index to 2D position
state_to_position :: proc(world: ^Grid, state: int) -> Position {
    pos := Position{-1, -1}
    if world == nil || state < 0 || i32(state) >= world.width * world.height {
        return pos
    }
    pos.x = i32(state) % world.width
    pos.y = i32(state) / world.width
    return pos
}

// Get current state structure
get_current_state :: proc(world: ^Grid) -> State {
    state := State{}
    if world == nil {
        state.state_index = -1
        state.position = {-1, -1}
        state.is_terminal = true
        state.is_valid = false
        return state
    }
    state.state_index = get_state_index(world)
    state.position = world.agent_pos
    state.is_terminal = is_terminal_state(world, world.agent_pos)
    state.is_valid = is_valid_position(world, world.agent_pos.x, world.agent_pos.y)
    
    return state
}

// Set cell type at position
set_cell :: proc(world: ^Grid, x, y: i32, type: Cell_Type) {
    if world == nil || !is_valid_position(world, x, y) {
        return
    }
    world.grid[y][x] = type
}

// Get cell type at position
get_cell :: proc(world: ^Grid, x, y: i32) -> Cell_Type {
    if world == nil || !is_valid_position(world, x, y) {
        return .WALL // Safe default for out-of-bounds
    }
    return world.grid[y][x]
}

print_env_info :: proc(world: ^Grid) {
    if world == nil {
        fmt.printf("Error: Cannot print info for nil GridWorld\n")
        return
    }
    fmt.printf("\nEnvironment:\n")
    fmt.printf("Grid size: %dx%d (%d total states)\n", world.width, world.height, 
               world.width * world.height)
    fmt.printf("Agent pos: (%d, %d)\n", world.agent_pos.x, world.agent_pos.y)
    fmt.printf("Start pos: (%d, %d)\n", world.start_pos.x, world.start_pos.y)
    fmt.printf("Goal pos: (%d, %d)\n", world.goal_pos.x, world.goal_pos.y)
    fmt.printf("Rewards: Goal=%.1f, Wall=%.1f, Step=%.1f\n", 
               world.goal_reward, world.wall_penalty, world.step_penalty)
    fmt.printf("Max steps per epoch: %d\n", world.max_steps)
    fmt.printf("Epoch: %s (steps taken: %d)\n", 
               world.epoch_done ? "Done" : "Active", world.epoch_steps)
    fmt.printf("Total reward: %.2f\n", world.total_reward)
    // Count different cell types
    wall_count := 0
    obstacle_count := 0
    for y in 0..<world.height {
        for x in 0..<world.width {
            cell := world.grid[y][x]
            if cell == .WALL do wall_count += 1
            else if cell == .OBSTACLE do obstacle_count += 1
        }
    }
    fmt.printf("Obstacles: %d walls, %d obstacles\n", wall_count, obstacle_count)
}

validate_env :: proc(world: ^Grid) -> bool {
    if world == nil {
        fmt.printf("Error: nil GridWorld\n")
        return false
    }
    if world.width <= 0 || world.height <= 0 {
        fmt.printf("Error: Invalid grid dimensions: %dx%d\n", world.width, world.height)
        return false
    }
    if world.max_steps <= 0 {
        fmt.printf("Error: Invalid max_steps: %d\n", world.max_steps)
        return false
    }
    // Check positions are within bounds
    if !is_valid_position(world, world.start_pos.x, world.start_pos.y) {
        fmt.printf("Error: Start position (%d, %d) is out of bounds\n", 
                   world.start_pos.x, world.start_pos.y)
        return false
    }
    if !is_valid_position(world, world.goal_pos.x, world.goal_pos.y) {
        fmt.printf("Error: Goal position (%d, %d) is out of bounds\n", 
                   world.goal_pos.x, world.goal_pos.y)
        return false
    }
    if !is_valid_position(world, world.agent_pos.x, world.agent_pos.y) {
        fmt.printf("Error: Agent position (%d, %d) is out of bounds\n", 
                   world.agent_pos.x, world.agent_pos.y)
        return false
    }
    // Check that start and goal positions are walkable
    if !is_walkable(world, world.start_pos.x, world.start_pos.y) {
        fmt.printf("Error: Start position (%d, %d) is not walkable\n", 
                   world.start_pos.x, world.start_pos.y)
        return false
    }
    if !is_walkable(world, world.goal_pos.x, world.goal_pos.y) {
        fmt.printf("Error: Goal position (%d, %d) is not walkable\n", 
                   world.goal_pos.x, world.goal_pos.y)
        return false
    }
    // Check that start and goal are different
    if positions_equal(world.start_pos, world.goal_pos) {
        fmt.printf("Warning: Start and goal positions are the same\n")
    }
    return true
}

/* validate_reward_values checks:

    1. Goal reward positive.
    2. Wall penalty negative.
    3. Step penalty negative.
    4. Goal reward significantly larger than magnitude of penalties
       (goal_reward > |step_penalty| and goal_reward > |wall_penalty|)
*/
validate_reward_values :: proc(world: ^Grid) -> bool {
    if world == nil do return false

    if world.goal_reward <= 0 {
        fmt.printf("Error: Goal reward %.2f is not positive. It must be > 0.\n", world.goal_reward)
        return false
    }
    if world.wall_penalty >= 0 {
        fmt.printf("Error: Wall penalty %.2f is not negative. It must be < 0.\n", world.wall_penalty)
        return false
    }
    if world.step_penalty >= 0 {
        fmt.printf("Error: Step penalty %.2f is not negative. It must be < 0.\n", world.step_penalty)
        return false
    }
    // Ensure reaching goal is always more rewarding than taking penalties.
    if world.goal_reward <= -world.step_penalty {
        fmt.printf("Error: Goal reward %.2f is not sufficiently larger than step penalty magnitude %.2f. Goal reward should be > |step_penalty|.\n",
                   world.goal_reward, -world.step_penalty)
        return false
    }
    if world.goal_reward <= -world.wall_penalty {
        fmt.printf("Error: Goal reward %.2f is not sufficiently larger than wall penalty magnitude %.2f. Goal reward should be > |wall_penalty|.\n",
                   world.goal_reward, -world.wall_penalty)
        return false
    }
    return true
}