package fsm

import "core:math"
import rl "vendor:raylib"
import "nodes"

// Core type aliases
Vec2 :: rl.Vector2

// Agent represents a pathfinding entity with behaviors
Agent :: struct {
    fsm:        ^FSM,
    behavior:   ^Behavior,
    nodemap:    ^nodes.NodeMap,
    path:       nodes.Path,
    target:     ^Agent,
    color:      rl.Color,
}

// Agent constructor and destructor
new_agent :: proc() -> Agent {
    return Agent{
        fsm        = nil,
        nodemap    = nil,
        behavior   = nil,
        target     = nil,
        path       = nodes.new_path(),
        color      = {255, 255, 255, 255},
    }
}

destroy_agent :: proc(a: ^Agent) {
    nodes.destroy_path(&a.path)
    if a.fsm != nil {
        destroy(a.fsm)
    }
}

agent_update :: proc(a: ^Agent, delta_time: f32) {
    if a.fsm != nil {
        update(a.fsm, a, delta_time)
    } else if a.behavior != nil {
        behavior_update(a.behavior, a, delta_time)
    }
    nodes.update_path(&a.path, delta_time)
}

draw_agent :: proc(a: ^Agent) {
    position := nodes.path_position(&a.path)
    radius := f32(8.0)
    rl.DrawCircle(i32(position.x), i32(position.y), radius, a.color)
}

// Agent movement
go_to :: proc(a: ^Agent, point: Vec2) {
    start := nodes.closest_node(a.nodemap, nodes.path_position(&a.path))
    end := nodes.closest_node(a.nodemap, point)
    
    if start != nil && end != nil {
        nodes.go_to(&a.path, start, end, a.nodemap)
    }
}

go_to_node :: proc(a: ^Agent, node: ^nodes.Node) {
    start := nodes.closest_node(a.nodemap, nodes.path_position(&a.path))
    if start != nil && node != nil {
        nodes.go_to(&a.path, start, node, a.nodemap)
    }
}

reset :: proc(a: ^Agent) {
    nodes.clear_path(&a.path)
}

path_complete :: proc(a: ^Agent) -> bool {
    return len(nodes.get_path(&a.path)) == 0
}

// Agent setters and getters
set_color :: proc(a: ^Agent, color: rl.Color) {
    a.color = color
}

set_target :: proc(a: ^Agent, target: ^Agent) {
    a.target = target
}

set_node_map :: proc(a: ^Agent, node_map: ^nodes.NodeMap) {
    a.nodemap = node_map
}

set_fsm :: proc(a: ^Agent, fsm: ^FSM) {
    a.fsm = fsm
}

set_behavior :: proc(a: ^Agent, behavior: ^Behavior) {
    a.behavior = behavior
}

get_target :: proc(a: ^Agent) -> ^Agent {
    return a.target
}

get_position :: proc(a: ^Agent) -> Vec2 {
    return nodes.path_position(&a.path)
}

get_node_map :: proc(a: ^Agent) -> ^nodes.NodeMap {
    return a.nodemap
}

get_path :: proc(a: ^Agent) -> ^nodes.Path {
    return &a.path
}