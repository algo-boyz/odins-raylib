package fsm

// Finite State Machine
FSM :: struct {
    states:  [dynamic]^State,
    current: ^State,
}

State :: struct {
    behaviors:   [dynamic]Behavior,
    transitions: [dynamic]Transition,
}

Transition :: struct {
    condition:  Condition,
    target:     ^State,
}

// State operations
new_state :: proc() -> ^State {
    state := new(State)
    state.behaviors = make([dynamic]Behavior)
    state.transitions = make([dynamic]Transition)
    return state
}

destroy_state :: proc(s: ^State) {
    delete(s.behaviors)
    delete(s.transitions)
    free(s)
}

state_add_behavior :: proc(s: ^State, behavior: Behavior) {
    append(&s.behaviors, behavior)
}

state_add_transition :: proc(s: ^State, condition: Condition, target_state: ^State) {
    transition := Transition{
        condition = condition,
        target = target_state,
    }
    append(&s.transitions, transition)
}

state_enter :: proc(s: ^State, agent: ^Agent) {
    // Update agent based on first behavior
    if len(s.behaviors) > 0 {
        behavior_enter(&s.behaviors[0], agent)
    }
}

state_update :: proc(s: ^State, agent: ^Agent, delta_time: f32) {
    for &behavior in s.behaviors {
        behavior_update(&behavior, agent, delta_time)
    }
}

state_exit :: proc(s: ^State, agent: ^Agent) {
    // logic when exiting state goes here
}

state_get_transitions :: proc(s: ^State) -> [dynamic]Transition {
    return s.transitions
}

// Finite State Machine operations
create :: proc() -> (fsm: FSM) {
    fsm.states = make([dynamic]^State)
    fsm.current = nil
    return fsm
}

destroy :: proc(fsm: ^FSM) {
    for state in fsm.states {
        destroy_state(state)
    }
    delete(fsm.states)
    free(fsm)
}

add_state :: proc(fsm: ^FSM, state: ^State) {
    append(&fsm.states, state)
    if fsm.current == nil {
        fsm.current = state
    }
}

set_current :: proc(fsm: ^FSM, state: ^State) {
    fsm.current = state
}

update :: proc(fsm: ^FSM, agent: ^Agent, delta_time: f32) {
    new_state: ^State = nil
    
    // Check for transitions in the current state
    transitions := state_get_transitions(fsm.current)
    for &transition in transitions {
        if condition_is_true(&transition.condition, agent) {
            new_state = transition.target
            break
        }
    }
    // Transition to new state if found
    if new_state != nil && new_state != fsm.current {
        state_exit(fsm.current, agent)
        fsm.current = new_state
        state_enter(fsm.current, agent)
    }
    // Update current state
    state_update(fsm.current, agent, delta_time)
}

enter :: proc(fsm: ^FSM, agent: ^Agent) {
    if fsm.current != nil {
        state_enter(fsm.current, agent)
    }
}