package qlearn

import "core:fmt"
import "core:math"
import "core:mem"
import "core:slice"
import "core:strings"
import rl "vendor:raylib"

// Performance metrics structure
Performance_Metrics :: struct {
    moving_avg_rewards,
    moving_avg_steps,
    q_val_variance,
    epsilon_history:        []f32,
    success_epochs:         []b32,
    window_size,
    convergence_threshold,
    convergence_epoch:      i32,
    has_converged:          b32,
}

// Epoch statistics
Epoch_Stats :: struct {
    epoch,
    steps_taken:    i32,
    total_reward,
    epsilon_used,
    avg_q_val:      f32,
}

// Training statistics
Training_Stats :: struct {
    metrics:                    ^Performance_Metrics,
    epochs:                     []Epoch_Stats,
    max_epochs,
    current_epoch,
    best_epoch,
    worst_epoch,
    total_successful_epochs:    i32,
    best_reward,
    worst_reward,
    avg_reward_all_epochs,
    avg_steps_all_epochs:       f32,
}

// State visit tracker
State_Tracker :: struct {
    visit_counts:             []int,
    visit_priorities,
    exploration_bonuses,
    state_epsilons,
    state_learning_rates:     []f32,
    num_states:                 int,
    total_visits:               int,
    exploration_bonus_decay,
    min_exploration_bonus,
    prio_temperature:           f32,
    adaptive_epsilon,
    adaptive_learning_rate:     b32,
}

// Create new performance metrics
new_performance_metrics :: proc(max_epochs, window_size, convergence_threshold: i32, allocator := context.allocator) -> ^Performance_Metrics {
    metrics := new(Performance_Metrics, allocator)
    
    metrics.moving_avg_rewards = make([]f32, max_epochs, allocator)
    metrics.moving_avg_steps = make([]f32, max_epochs, allocator)
    metrics.success_epochs = make([]b32, max_epochs, allocator)
    metrics.q_val_variance = make([]f32, max_epochs, allocator)
    metrics.epsilon_history = make([]f32, max_epochs, allocator)
    
    metrics.window_size = window_size
    metrics.convergence_threshold = convergence_threshold
    metrics.has_converged = false
    metrics.convergence_epoch = -1
    
    return metrics
}

// Destroy performance metrics
destroy_performance_metrics :: proc(metrics: ^Performance_Metrics, allocator := context.allocator) {
    if metrics == nil do return
    
    delete(metrics.moving_avg_rewards, allocator)
    delete(metrics.moving_avg_steps, allocator)
    delete(metrics.success_epochs, allocator)
    delete(metrics.q_val_variance, allocator)
    delete(metrics.epsilon_history, allocator)
    free(metrics, allocator)
}

// Update performance metrics
update_performance_metrics :: proc(metrics: ^Performance_Metrics, stats: ^Training_Stats, epoch: i32, goal_reached: b32, q_variance: f32) {
    if metrics == nil || stats == nil || epoch >= stats.max_epochs do return
    
    ep_stats := &stats.epochs[epoch]
    
    // Store raw values
    metrics.success_epochs[epoch] = goal_reached
    metrics.q_val_variance[epoch] = q_variance
    metrics.epsilon_history[epoch] = ep_stats.epsilon_used
    
    // Calculate moving averages
    window_start := max(0, epoch - metrics.window_size + 1)
    window_count := epoch - window_start + 1
    
    // Calculate moving average of rewards
    reward_sum: f32
    for i in window_start..=epoch {
        reward_sum += stats.epochs[i].total_reward
    }
    metrics.moving_avg_rewards[epoch] = reward_sum / f32(window_count)
    
    // Calculate moving average of steps
    steps_sum: f32
    for i in window_start..=epoch {
        steps_sum += f32(stats.epochs[i].steps_taken)
    }
    metrics.moving_avg_steps[epoch] = steps_sum / f32(window_count)
}

// Check convergence
check_convergence :: proc(metrics: ^Performance_Metrics, current_epoch: i32) -> b32 {
    if metrics == nil || metrics.has_converged || current_epoch < metrics.convergence_threshold {
        return metrics.has_converged
    }
    // Check if reward variance is low over last threshold epochs
    start_epoch := current_epoch - metrics.convergence_threshold + 1
    
    // Calculate mean reward over convergence window
    mean_reward: f32
    for i in start_epoch..=current_epoch {
        mean_reward += metrics.moving_avg_rewards[i]
    }
    mean_reward /= f32(metrics.convergence_threshold)
    
    // Calculate variance of rewards over convergence window
    reward_variance: f32
    for i in start_epoch..=current_epoch {
        diff := metrics.moving_avg_rewards[i] - mean_reward
        reward_variance += diff * diff
    }
    reward_variance /= f32(metrics.convergence_threshold)
    
    // Calculate success rate
    success_rate: f32
    for i in start_epoch..=current_epoch {
        if metrics.success_epochs[i] do success_rate += 1
    }
    success_rate /= f32(metrics.convergence_threshold)
    
    // Convergence criteria: low reward variance and high success rate
    if reward_variance < 5 && success_rate > 0.8 {
        metrics.has_converged = true
        metrics.convergence_epoch = current_epoch
        return true
    }
    return false
}

// Print learning curves
print_learning_curves :: proc(stats: ^Training_Stats, last_n_epochs: i32) {
    if stats == nil || stats.metrics == nil do return
    
    fmt.printf("\nLearning Curves (Last %d Epochs)\n", last_n_epochs)
    start_epoch := max(0, stats.current_epoch - last_n_epochs)
    
    fmt.printf("Epoch | Reward | MovAvg | Steps | Success | Epsilon | Q-Var\n")
    for i in start_epoch..<stats.current_epoch {
        ep := &stats.epochs[i]
        metrics := stats.metrics
        
        success_str := "Yes" if metrics.success_epochs[i] else "No"
        fmt.printf("%7d | %6.1f | %6.1f | %5d | %7s | %7.3f | %6.2f\n",
            ep.epoch + 1,
            ep.total_reward,
            metrics.moving_avg_rewards[i],
            ep.steps_taken,
            success_str,
            metrics.epsilon_history[i],
            metrics.q_val_variance[i])
    }
}

// Print convergence status
print_convergence :: proc(metrics: ^Performance_Metrics, current_epoch: i32) {
    if metrics == nil do return
    
    fmt.printf("\nConvergence Status\n")
    if metrics.has_converged {
        fmt.printf("✓ CONVERGED at epoch %d\n", metrics.convergence_epoch + 1)
    } else {
        fmt.printf("⧗ Training in progress...\n")
    }
    // Calculate recent performance stats
    if current_epoch >= metrics.window_size {
        window_start := current_epoch - metrics.window_size + 1
        
        // Success rate in window
        success_rate: f32
        for i in window_start..=current_epoch {
            if metrics.success_epochs[i] do success_rate += 1
        }
        success_rate /= f32(metrics.window_size)
        
        // Average performance in window
        avg_reward := metrics.moving_avg_rewards[current_epoch]
        avg_steps := metrics.moving_avg_steps[current_epoch]
        current_q_var := metrics.q_val_variance[current_epoch]
        current_epsilon := metrics.epsilon_history[current_epoch]
        
        fmt.printf("Recent Performance (Window size: %d):\n", metrics.window_size)
        fmt.printf("  Success Rate: %.1f%%\n", success_rate * 100)
        fmt.printf("  Avg Reward: %.2f\n", avg_reward)
        fmt.printf("  Avg Steps: %.1f\n", avg_steps)
        fmt.printf("  Q-Value Variance: %.3f\n", current_q_var)
        fmt.printf("  Epsilon: %.3f\n", current_epsilon)
    }
}

// Create new training stats
new_training_stats :: proc(max_epochs: i32, allocator := context.allocator) -> ^Training_Stats {
    stats := new(Training_Stats, allocator)
    
    stats.epochs = make([]Epoch_Stats, max_epochs, allocator)
    stats.max_epochs = max_epochs
    stats.current_epoch = 0
    stats.best_reward = -math.INF_F32
    stats.best_epoch = 0
    stats.worst_reward = math.INF_F32
    stats.worst_epoch = 0
    stats.total_successful_epochs = 0
    stats.avg_reward_all_epochs  = 0
    stats.avg_steps_all_epochs  = 0
    
    // Create performance metrics with default values
    stats.metrics = new_performance_metrics(max_epochs, 100, 50, allocator)
    
    return stats
}

// Destroy training stats
destroy_training_stats :: proc(stats: ^Training_Stats, allocator := context.allocator) {
    if stats == nil do return
    
    if stats.metrics != nil {
        destroy_performance_metrics(stats.metrics, allocator)
    }
    delete(stats.epochs, allocator)
    free(stats, allocator)
}

// Record epoch data
record_epoch :: proc(stats: ^Training_Stats, epoch: i32, total_reward: f32, steps_taken: i32, epsilon_used: f32, avg_q_val: f32) {
    if stats == nil || epoch >= stats.max_epochs do return
    
    ep_stats := &stats.epochs[epoch]
    ep_stats.epoch = epoch
    ep_stats.total_reward = total_reward
    ep_stats.steps_taken = steps_taken
    ep_stats.epsilon_used = epsilon_used
    ep_stats.avg_q_val = avg_q_val
    
    // Update best reward tracking
    if total_reward > stats.best_reward {
        stats.best_reward = total_reward
        stats.best_epoch = epoch
    }
    stats.current_epoch = epoch + 1
}

// Print training summary
print_summary :: proc(stats: ^Training_Stats) {
    if stats == nil do return
    
    fmt.printf("\nTraining Summary\n")
    fmt.printf("Total Epochs: %d\n", stats.current_epoch)
    fmt.printf("Best Epoch: %d (Reward: %.2f)\n", stats.best_epoch + 1, stats.best_reward)
    
    if stats.current_epoch > 0 {
        // Calculate average reward over all epochs
        total_reward: f32
        total_steps: i32 = 0
        
        for i in 0..<stats.current_epoch {
            total_reward += stats.epochs[i].total_reward
            total_steps += stats.epochs[i].steps_taken
        }
        avg_reward := total_reward / f32(stats.current_epoch)
        avg_steps := f32(total_steps) / f32(stats.current_epoch)
        
        fmt.printf("Average Reward: %.2f\n", avg_reward)
        fmt.printf("Average Steps per Epoch: %.1f\n", avg_steps)
        
        fmt.printf("\nLast 5 Epochs:\n")
        start_epoch := max(0, stats.current_epoch - 5)
        for i in start_epoch..<stats.current_epoch {
            ep := &stats.epochs[i]
            fmt.printf("Epoch %d: Reward=%.1f, Steps=%d, Epsilon=%.3f\n", 
                ep.epoch + 1, ep.total_reward, ep.steps_taken, ep.epsilon_used)
        }
    }
}

// Create state visit tracker
new_state_tracker :: proc(num_states: int, adaptive_epsilon: b32, adaptive_learning_rate: b32, allocator := context.allocator) -> ^State_Tracker {
    tracker := new(State_Tracker, allocator)
    
    tracker.visit_counts = make([]int, num_states, allocator)
    tracker.visit_priorities = make([]f32, num_states, allocator)
    tracker.exploration_bonuses = make([]f32, num_states, allocator)
    tracker.state_epsilons = make([]f32, num_states, allocator)
    tracker.state_learning_rates = make([]f32, num_states, allocator)
    
    tracker.num_states = num_states
    tracker.total_visits = 0
    tracker.exploration_bonus_decay = 0.999
    tracker.min_exploration_bonus = 0.01
    tracker.prio_temperature = 1
    tracker.adaptive_epsilon = adaptive_epsilon
    tracker.adaptive_learning_rate = adaptive_learning_rate
    // Init arrays
    for i in 0..<num_states {
        tracker.exploration_bonuses[i] = 1  // Start with high bonus
        tracker.state_epsilons[i] = 1
        tracker.state_learning_rates[i] = 1  // Start with normal rate
        tracker.visit_priorities[i] = 1  // Equal priority initially
    }
    return tracker
}

// Destroy sate tracker
destroy_state_tracker :: proc(tracker: ^State_Tracker, allocator := context.allocator) {
    if tracker == nil do return
    delete(tracker.visit_counts, allocator)
    delete(tracker.visit_priorities, allocator)
    delete(tracker.exploration_bonuses, allocator)
    delete(tracker.state_epsilons, allocator)
    delete(tracker.state_learning_rates, allocator)
    free(tracker, allocator)
}

// Update state visit count and derived metrics
update_state :: proc(tracker: ^State_Tracker, state: int) {
    if tracker == nil || state < 0 || state >= tracker.num_states do return
    
    tracker.visit_counts[state] += 1
    tracker.total_visits += 1
    
    // Update exploration bonus (decreases with visits)
    tracker.exploration_bonuses[state] = max(
        tracker.min_exploration_bonus,
        1 / math.sqrt(f32(tracker.visit_counts[state]) + 1)
    )
    // Update epsilon (explore well-visited states less)
    if tracker.adaptive_epsilon {
        tracker.state_epsilons[state] = tracker.exploration_bonuses[state]
    }
    // Update learning rate (faster learning in new states)
    if tracker.adaptive_learning_rate {
        tracker.state_learning_rates[state] = min(2, 1 + tracker.exploration_bonuses[state])
    }
    update_state_priorities(tracker)
}

// Get exploration bonus for a state
get_exploration_bonus :: proc(tracker: ^State_Tracker, state: int) -> f32 {
    if tracker == nil || state < 0 || state >= tracker.num_states do return 0
    return tracker.exploration_bonuses[state]
}

// Get state-specific epsilon
get_state_epsilon :: proc(tracker: ^State_Tracker, state: int, base_epsilon: f32) -> f32 {
    if tracker == nil || state < 0 || state >= tracker.num_states || !tracker.adaptive_epsilon {
        return base_epsilon
    }
    return base_epsilon * tracker.state_epsilons[state]
}

// Get state-specific learning rate
get_state_learning_rate :: proc(tracker: ^State_Tracker, state: int, base_learning_rate: f32) -> f32 {
    if tracker == nil || state < 0 || state >= tracker.num_states || !tracker.adaptive_learning_rate {
        return base_learning_rate
    }
    return base_learning_rate * tracker.state_learning_rates[state]
}

// Decay exploration bonuses over time
decay_exploration_bonuses :: proc(tracker: ^State_Tracker) {
    if tracker == nil do return
    
    for i in 0..<tracker.num_states {
        tracker.exploration_bonuses[i] *= tracker.exploration_bonus_decay
        tracker.exploration_bonuses[i] = max(
            tracker.exploration_bonuses[i],
            tracker.min_exploration_bonus
        )
    }
}

// Select state with highest priority
select_priority_state :: proc(tracker: ^State_Tracker) -> int {
    if tracker == nil do return 0
    
    best_state: int
    best_priority := tracker.visit_priorities[0]
    
    for i in 1..<tracker.num_states {
        if tracker.visit_priorities[i] > best_priority {
            best_priority = tracker.visit_priorities[i]
            best_state = i
        }
    }
    return best_state
}

// Update state priorities based on visits and bonuses
update_state_priorities :: proc(tracker: ^State_Tracker) {
    if tracker == nil do return
    
    // Find min and max visits for normalization
    min_visits := tracker.visit_counts[0]
    max_visits := tracker.visit_counts[0]
    
    for i in 1..<tracker.num_states {
        if tracker.visit_counts[i] < min_visits do min_visits = tracker.visit_counts[i]
        if tracker.visit_counts[i] > max_visits do max_visits = tracker.visit_counts[i]
    }
    // Calculate priorities
    for i in 0..<tracker.num_states {
        if max_visits == min_visits {
            tracker.visit_priorities[i] = 1  // Equal priority if all same
        } else {
            // Higher priority for less visited states
            visit_norm := 1 - f32(tracker.visit_counts[i] - min_visits) / f32(max_visits - min_visits)
            tracker.visit_priorities[i] = visit_norm + tracker.exploration_bonuses[i]
        }
    }
}

// Reset state tracker
reset_state_tracker :: proc(tracker: ^State_Tracker) {
    if tracker == nil do return
    
    // Reset visit counts
    for i in 0..<tracker.num_states {
        tracker.visit_counts[i] = 0
    }
    tracker.total_visits = 0
    
    // Reset to initial values
    for i in 0..<tracker.num_states {
        tracker.exploration_bonuses[i] = 1
        tracker.state_epsilons[i] = 1
        tracker.state_learning_rates[i] = 1
        tracker.visit_priorities[i] = 1
    }
}

// Print state visit analysis
print_state_analysis :: proc(tracker: ^State_Tracker) {
    if tracker == nil do return
    
    fmt.printf("\nState Visit Analysis\n")
    fmt.printf("Total visits across %d states: %d\n", tracker.num_states, tracker.total_visits)
    
    // Calculate coverage stats
    visited_states: i32 = 0
    unvisited_states: i32 = 0
    min_visits := max(int)
    max_visits: int = 0
    total_exploration_bonus: f32
    
    for i in 0..<tracker.num_states {
        if tracker.visit_counts[i] > 0 {
            visited_states += 1
            if tracker.visit_counts[i] < min_visits do min_visits = tracker.visit_counts[i]
        } else {
            unvisited_states += 1
        }
        if tracker.visit_counts[i] > max_visits do max_visits = tracker.visit_counts[i]
        total_exploration_bonus += tracker.exploration_bonuses[i]
    }
    if visited_states == 0 do min_visits = 0
    
    fmt.printf("Coverage:\n")
    fmt.printf("  Visited: %d (%.1f%%)\n", visited_states, 
        f32(visited_states) / f32(tracker.num_states) * 100)
    fmt.printf("  Unvisited: %d (%.1f%%)\n", unvisited_states,
        f32(unvisited_states) / f32(tracker.num_states) * 100)
    fmt.printf("  Min visits per state: %d\n", min_visits)
    fmt.printf("  Max visits per state: %d\n", max_visits)
    fmt.printf("  Avg visits per state: %.1f\n", f32(tracker.total_visits) / f32(tracker.num_states))
    fmt.printf("  Avg exploration bonus: %.3f\n", total_exploration_bonus / f32(tracker.num_states))
    
    // Find and display extreme states
    least_visited := get_least_visited_state(tracker)
    most_visited := get_most_visited_state(tracker)
    highest_priority := select_priority_state(tracker)
    
    fmt.printf("\nExtreme States:\n")
    fmt.printf("  Least visited: %d (%d visits, bonus: %.3f)\n", 
        least_visited, tracker.visit_counts[least_visited], 
        tracker.exploration_bonuses[least_visited])
    fmt.printf("  Most visited: %d (%d visits, bonus: %.3f)\n", 
        most_visited, tracker.visit_counts[most_visited], 
        tracker.exploration_bonuses[most_visited])
    fmt.printf("  Highest priority: %d (%.3f)\n", 
        highest_priority, tracker.visit_priorities[highest_priority])
    
    fmt.printf("\nSettings:\n")
    fmt.printf("  Adaptive epsilon: %s\n", "enabled" if tracker.adaptive_epsilon else "disabled")
    fmt.printf("  Adaptive learning rate: %s\n", "enabled" if tracker.adaptive_learning_rate else "disabled")
    fmt.printf("  Exploration bonus decay: %.4f\n", tracker.exploration_bonus_decay)
    fmt.printf("  Min exploration bonus: %.4f\n", tracker.min_exploration_bonus)
}

// Calculate exploration coverage percentage
calc_exploration_coverage :: proc(tracker: ^State_Tracker) -> f32 {
    if tracker == nil do return 0
    visited: int
    for i in 0..<tracker.num_states {
        if tracker.visit_counts[i] > 0 {
            visited += 1
        }
    }
    return f32(visited) / f32(tracker.num_states) * 100
}

// Get least visited state
get_least_visited_state :: proc(tracker: ^State_Tracker) -> int {
    if tracker == nil do return 0
    
    least_state: int
    min_visits := tracker.visit_counts[0]
    
    for i in 1..<tracker.num_states {
        if tracker.visit_counts[i] < min_visits {
            min_visits = tracker.visit_counts[i]
            least_state = i
        }
    }
    return least_state
}

// Get most visited state
get_most_visited_state :: proc(tracker: ^State_Tracker) -> int {
    if tracker == nil do return 0
    
    most_state: int
    max_visits := tracker.visit_counts[0]
    
    for i in 1..<tracker.num_states {
        if tracker.visit_counts[i] > max_visits {
            max_visits = tracker.visit_counts[i]
            most_state = i
        }
    }
    return most_state
}

// TODO: Save performance data to CSV
save_performance_data :: proc(stats: ^Training_Stats, filename: string) {
    fmt.printf("Performance metrics saved to %s\n", filename)
}

// TODO: Save state visit data to CSV
save_state_data :: proc(tracker: ^State_Tracker, filename: string) {
    fmt.printf("State visit data saved to %s\n", filename)
}