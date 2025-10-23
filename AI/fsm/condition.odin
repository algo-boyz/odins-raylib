package fsm

import "core:math"

ConditionType :: enum {
    DISTANCE,
}

Condition :: struct {
    type: ConditionType,
    data: union {
        DistanceCondition,
    },
}

DistanceCondition :: struct { distance:  f32, lt: bool }

new_distance_condition :: proc(distance: f32, less_than: bool) -> Condition {
    return Condition{
        type = .DISTANCE,
        data = DistanceCondition{
            distance  = distance,
            lt        = less_than,
        },
    }
}

condition_is_true :: proc(c: ^Condition, agent: ^Agent) -> bool {
    switch &data in c.data {
    case DistanceCondition:
        return is_near(&data, agent)
    }
    return false
}

is_near :: proc(dc: ^DistanceCondition, agent: ^Agent) -> bool {
    target := get_target(agent)
    if target == nil {
        return false
    }
    agent_pos := get_position(agent)
    target_pos := get_position(target)
    diff := agent_pos - target_pos
    distance := math.sqrt(diff.x * diff.x + diff.y * diff.y)
    if dc.lt {
        return distance < dc.distance
    } else {
        return distance > dc.distance
    }
}