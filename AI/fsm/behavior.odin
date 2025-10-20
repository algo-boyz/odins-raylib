package fsm

import "nodes"

// Behavior system
BehaviorType :: enum {
    FOLLOW,
    WANDER,
}

Behavior :: struct {
    type: BehaviorType,
    data: union {
        FollowBehavior,
        WanderBehavior,
    },
}

FollowBehavior :: struct {}
WanderBehavior :: struct {}

// Behavior constructors
follow_behavior_create :: proc() -> Behavior {
    return Behavior{
        type = .FOLLOW,
        data = FollowBehavior{},
    }
}

wander_behavior_create :: proc() -> Behavior {
    return Behavior{
        type = .WANDER,
        data = WanderBehavior{},
    }
}

// Behavior operations
behavior_update :: proc(b: ^Behavior, agent: ^Agent, delta_time: f32) {
    switch &data in b.data {
    case FollowBehavior:
        follow_behavior_update(&data, agent, delta_time)
    case WanderBehavior:
        wander_behavior_update(&data, agent, delta_time)
    }
}

behavior_enter :: proc(b: ^Behavior, agent: ^Agent) {
    switch &data in b.data {
    case FollowBehavior:
        follow_behavior_enter(&data, agent)
    case WanderBehavior:
        wander_behavior_enter(&data, agent)
    }
}

// Follow behavior implementation
follow_behavior_update :: proc(fb: ^FollowBehavior, agent: ^Agent, delta_time: f32) {
    target := get_target(agent)
    if target != nil {
        target_position := get_position(target)
        closest_node := nodes.closest_node(get_node_map(agent), target_position)
        
        if closest_node != nil {
            path := nodes.get_path(&agent.path)
            
            // Check if we need a new path
            if len(path) == 0 || (len(path) > 0 && closest_node != path[len(path) - 1]) {
                go_to(agent, closest_node.position)
            }
        }
        nodes.update_path(&agent.path, delta_time)
    }
}

follow_behavior_enter :: proc(fb: ^FollowBehavior, agent: ^Agent) {
    set_color(agent, {255, 0, 0, 255}) // Red when following
    reset(agent)
}

// Wander behavior implementation
wander_behavior_update :: proc(wb: ^WanderBehavior, agent: ^Agent, delta_time: f32) {
    if path_complete(agent) {
        random_node := nodes.random_node(get_node_map(agent))
        go_to_node(agent, random_node)
    }
    nodes.update_path(&agent.path, delta_time)
}

wander_behavior_enter :: proc(wb: ^WanderBehavior, agent: ^Agent) {
    set_color(agent, {255, 255, 0, 255}) // Yellow when wandering
    reset(agent)
}