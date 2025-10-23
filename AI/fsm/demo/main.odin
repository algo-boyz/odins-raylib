package main

import "core:fmt"
import "core:math/rand"
import "core:time"
import rl "vendor:raylib"
import fsm "../"
import "../../../rlutil"
import "../nodes"

main :: proc() {
    rlutil.seed_rand()

    rl.InitWindow(600, 400, "Finite State Machine")
    defer rl.CloseWindow()
    rl.SetTargetFPS(120)

    ascii_map := []string{
        "000000000000",
        "010111011100",
        "010101110110",
        "011100000010",
        "010111111110",
        "010000001000",
        "011111111110",
        "000000000000",
    }
    nodemap := nodes.create()
    defer nodes.destroy(&nodemap)
    nodes.init(&nodemap, ascii_map, 50)
    
    // Create agent with go to point behavior (player controlled)
    ag1 := fsm.new_agent()
    defer fsm.destroy_agent(&ag1)
    fsm.set_node_map(&ag1, &nodemap)
    nodes.set_speed(fsm.get_path(&ag1), 128)
    fsm.set_color(&ag1, {0, 255, 0, 255})  // Green
    
    // Create wander behaviour (random movement) for agent2
    ag2 := fsm.new_agent()
    defer fsm.destroy_agent(&ag2)
    fsm.set_node_map(&ag2, &nodemap)
    
    // Assign agent2 to random node
    rand_node := nodes.random_node(&nodemap)
    if rand_node != nil {
        nodes.set_node(fsm.get_path(&ag2), rand_node)
    }
    nodes.set_speed(&ag2.path, 64)
    fsm.set_color(&ag2, {0, 0, 255, 255})  // Blue
    
    wander_behavior := fsm.wander_behavior_create()
    fsm.set_behavior(&ag2, &wander_behavior)
    
    ag3 := fsm.new_agent()
    defer fsm.destroy_agent(&ag3)
    fsm.set_node_map(&ag3, &nodemap)
    
    random_node3 := nodes.random_node(&nodemap)
    if random_node3 != nil {
        nodes.set_node(fsm.get_path(&ag3), random_node3)
    }
    fsm.set_target(&ag3, &ag1)
    nodes.set_speed(fsm.get_path(&ag3), 32)
    fsm.set_color(&ag3, {255, 255, 0, 255})  // Yellow

    closer_than_threshold := fsm.new_distance_condition(90, true)    // Follow if closer than 90 units
    further_than_threshold := fsm.new_distance_condition(120, false) // Wander if farther than 120 units

    // Create behavior states
    wander_state := fsm.new_state()
    follow_state := fsm.new_state()
    
    // Create behaviors
    wander_behavior_fsm := fsm.wander_behavior_create()
    follow_behavior_fsm := fsm.follow_behavior_create()
    
    // Add behaviors to state
    fsm.state_add_behavior(wander_state, wander_behavior_fsm)
    fsm.state_add_behavior(follow_state, follow_behavior_fsm)
    
    // Add transitions
    fsm.state_add_transition(wander_state, closer_than_threshold, follow_state)
    fsm.state_add_transition(follow_state, further_than_threshold, wander_state)
    
    // Create finite state machine that starts wandering
    sm := fsm.create()
    defer fsm.destroy(&sm)
    
    // Add states to FSM
    fsm.add_state(&sm, wander_state)
    fsm.add_state(&sm, follow_state)
    
    // Wire agent3
    fsm.set_fsm(&ag3, &sm)
    fsm.enter(&sm, &ag3)  // Start in wander state
    
    for !rl.WindowShouldClose() {
        // Handle mouse input for agent1
        if rl.IsMouseButtonPressed(.LEFT) {  // Left click to set start node
            mouse_pos := rl.GetMousePosition()
            start_node := nodes.closest_node(&nodemap, {mouse_pos.x, mouse_pos.y})
            if start_node != nil {
                nodes.set_node(fsm.get_path(&ag1), start_node)
            } else {
                fmt.println("Failed to find a valid start node.")
            }
        }
        if rl.IsMouseButtonPressed(.RIGHT) {  // Right click to set goal node
            mouse_pos := rl.GetMousePosition()
            end_node := nodes.closest_node(&nodemap, {mouse_pos.x, mouse_pos.y})
            if end_node != nil {
                fsm.go_to(&ag1, {end_node.position.x, end_node.position.y})
            } else {
                fmt.println("Failed to find a valid end node.")
            }
        }
        dt := rl.GetFrameTime()

        fsm.agent_update(&ag1, dt)
        fsm.agent_update(&ag2, dt)
        fsm.update(&sm, &ag3, dt)

        rl.BeginDrawing()
        rl.ClearBackground(rl.BLACK)
            nodes.draw(&nodemap)
            
            fsm.draw_agent(&ag1)  // Player controlled (green)
            fsm.draw_agent(&ag2)  // Wandering (blue)
            fsm.draw_agent(&ag3)  // FSM controlled (yellow/changes based on state)
        rl.EndDrawing()
    }
}