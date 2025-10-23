package input

import "core:mem"
import "core:math"
import rl "vendor:raylib"

Device :: i32
Action :: u32
Action_Size :: u32

DEVICE_NULL :: -2
DEVICE_DEFAULT :: -1
DEVICE_KEYBOARD_AND_MOUSE :: -1
DEVICE_FIRST_GAMEPAD :: 0
MAX_GAMEPADS :: 4
DEFAULT_MAP_ALLOC_SIZE :: 8

Method :: enum {
    METHOD_NONE,

    KEY_PRESSED,
    KEY_RELEASED,
    KEY_DOWN,
    KEY_UP,

    MOUSE_PRESSED,
    MOUSE_RELEASED,
    MOUSE_DOWN,
    MOUSE_UP,
    MOUSE_POS,
    MOUSE_MOVEMENT,
    MOUSE_SCROLL,

    PAD_PRESSED,
    PAD_RELEASED,
    PAD_DOWN,
    PAD_UP,
    PAD_TRIGGER,
    PAD_TRIGGER_NORM,
    JOYSTICK,
}

Mouse_Axis :: enum { X, Y }

Axis_Range :: enum { FULL, POSITIVE, NEGATIVE }

Device_State :: enum {
    INITIAL,
    ACTIVE,
    IDLE,
    MISSING_2_ACTIVE,
    IDLE_2_ACTIVE,
    MISSING_2_DEFAULT,
}

Movement_Data :: struct {
    axis: Mouse_Axis,
    threshold: u16,
}

Scroll_Data :: struct {
    threshold: u16,
}

Trigger_Data :: struct {
    type: rl.GamepadAxis,
    threshold: u16, // Using u16 to represent f16 threshold
}

Joystick_Data :: struct {
    type: rl.GamepadAxis,
    range: Axis_Range,
    threshold: u16,
}

Data :: union {
    rl.KeyboardKey,
    rl.MouseButton,
    rl.GamepadButton,
    Movement_Data,
    Scroll_Data,
    Trigger_Data,
    Joystick_Data,
}

Map :: struct {
    method: Method,
    data: Data,
    on_press: proc(data: rawptr),   // Callback for press events
    on_hold: proc(data: rawptr),    // Callback for held events
    on_release: proc(data: rawptr), // Callback for release events
    user_data: rawptr,              // Context for callbacks
}

Result :: struct {
    ok: bool,
    val: f32,
    released: bool, // Indicates if input was released this frame
}

map_create :: proc(method: Method, data: Data, on_press, on_hold, on_release: proc(data: rawptr), user_data: rawptr = nil) -> Map {
    return Map{
        method = method,
        data = data,
        on_press = on_press,
        on_hold = on_hold,
        on_release = on_release,
        user_data = user_data,
    }
}

from_keyboard_and_mouse :: proc(method: Method) -> bool {
    #partial switch method {
    case .KEY_PRESSED, .KEY_RELEASED, 
         .KEY_DOWN, .KEY_UP,
         .MOUSE_PRESSED, .MOUSE_RELEASED,
         .MOUSE_DOWN, .MOUSE_UP,
         .MOUSE_POS, .MOUSE_MOVEMENT, .MOUSE_SCROLL:
        return true
    }
    return false
}

@private
float_equals :: proc(a, b: f32) -> bool {
    return abs(a - b) < 0.00001
}

@private
u16_to_f32 :: proc(val: u16) -> f32 {
    return f32(val) / 65535.0
}

is_valid :: proc(device: Device, method: Method) -> bool {
    switch true {
    case device >= 0:
        return !from_keyboard_and_mouse(method)
    case device == DEVICE_KEYBOARD_AND_MOUSE:
        return from_keyboard_and_mouse(method)
    case device == DEVICE_NULL:
        return method == .METHOD_NONE
    }
    return false
}

handler_set :: proc(device: Device, mappings: []Map, action_id: Action, m: Map) -> bool {
    if is_valid(device, m.method) {
        mappings[action_id] = m
        return true
    }
    return false
}

get_value :: proc(device: Device, mappings: []Map, action_id: Action) -> Result {
    m := mappings[action_id]
    
    #partial switch m.method {
    case .KEY_PRESSED:
        if key, ok := m.data.(rl.KeyboardKey); ok {
            value := rl.IsKeyPressed(key)
            if value && m.on_press != nil {
                m.on_press(m.user_data)
            }
            return {ok = value, val = f32(key)}
        }
    case .KEY_RELEASED:
        if key, ok := m.data.(rl.KeyboardKey); ok {
            value := rl.IsKeyReleased(key)
            if value && m.on_release != nil {
                m.on_release(m.user_data)
            }
            return {ok = value, val = f32(key), released = true}
        }
    case .KEY_DOWN:
        if key, ok := m.data.(rl.KeyboardKey); ok {
            value := rl.IsKeyDown(key)
            if value && m.on_hold != nil {
                m.on_hold(m.user_data)
            }
            return {ok = value, val = f32(key)}
        }
    case .KEY_UP:
        if key, ok := m.data.(rl.KeyboardKey); ok {
            value := rl.IsKeyUp(key)
            return {ok = value, val = f32(key)}
        }
    case .MOUSE_PRESSED:
        if key, ok := m.data.(rl.MouseButton); ok {
            value := rl.IsMouseButtonPressed(key)
            if value && m.on_press != nil {
                m.on_press(m.user_data)
            }
            return {ok = value, val = f32(key)}
        }
    case .MOUSE_RELEASED:
        if key, ok := m.data.(rl.MouseButton); ok {
            value := rl.IsMouseButtonReleased(key)
            if value && m.on_release != nil {
                m.on_release(m.user_data)
            }
            return {ok = value, val = f32(key), released = true}
        }
    case .MOUSE_DOWN:
        if key, ok := m.data.(rl.MouseButton); ok {
            value := rl.IsMouseButtonDown(key)
            if value && m.on_hold != nil {
                m.on_hold(m.user_data)
            }
            return {ok = value, val = f32(key)}
        }
    case .MOUSE_UP:
        if key, ok := m.data.(rl.MouseButton); ok {
            value := rl.IsMouseButtonUp(key)
            return {ok = value, val = f32(key)}
        }
    case .MOUSE_POS:
        if movement, ok := m.data.(Movement_Data); ok {
            value, delta: f32
            if movement.axis == .X {
                value = rl.GetMousePosition().x
                delta = rl.GetMouseDelta().x
            } else {
                value = rl.GetMousePosition().y
                delta = rl.GetMouseDelta().y
            }
            ok := abs(delta) >= f32(movement.threshold) && !float_equals(0, delta)
            if ok && m.on_hold != nil {
                m.on_hold(m.user_data)
            }
            return {val = value, ok = ok}
        }
    case .MOUSE_MOVEMENT:
        if movement, ok := m.data.(Movement_Data); ok {
            value := movement.axis == .X ? rl.GetMouseDelta().x : rl.GetMouseDelta().y
            ok := abs(value) >= f32(movement.threshold) && !float_equals(0, value)
            if ok && m.on_hold != nil {
                m.on_hold(m.user_data)
            }
            return {val = value, ok = ok}
        }
    case .MOUSE_SCROLL:
        if scroll, ok := m.data.(Scroll_Data); ok {
            value := rl.GetMouseWheelMove()
            ok := abs(value) >= f32(scroll.threshold) && !float_equals(0, value)
            if ok && m.on_hold != nil {
                m.on_hold(m.user_data)
            }
            return {val = value, ok = ok}
        }
    case .PAD_PRESSED:
        if key, ok := m.data.(rl.GamepadButton); ok {
            value := rl.IsGamepadButtonPressed(device, key)
            if value && m.on_press != nil {
                m.on_press(m.user_data)
            }
            return {ok = value, val = f32(key)}
        }
    case .PAD_RELEASED:
        if key, ok := m.data.(rl.GamepadButton); ok {
            value := rl.IsGamepadButtonReleased(device, key)
            if value && m.on_release != nil {
                m.on_release(m.user_data)
            }
            return {ok = value, val = f32(key), released = true}
        }
    case .PAD_DOWN:
        if key, ok := m.data.(rl.GamepadButton); ok {
            value := rl.IsGamepadButtonDown(device, key)
            if value && m.on_hold != nil {
                m.on_hold(m.user_data)
            }
            return {ok = value, val = f32(key)}
        }
    case .PAD_UP:
        if key, ok := m.data.(rl.GamepadButton); ok {
            value := rl.IsGamepadButtonUp(device, key)
            return {ok = value, val = f32(key)}
        }
    case .PAD_TRIGGER:
        if trigger, ok := m.data.(Trigger_Data); ok {
            value := rl.GetGamepadAxisMovement(device, trigger.type)
            ok := (value + 1) >= u16_to_f32(trigger.threshold) && !float_equals(-1, value)
            if ok && m.on_hold != nil {
                m.on_hold(m.user_data)
            }
            return {val = value, ok = ok}
        }
    case .PAD_TRIGGER_NORM:
        if trigger, ok := m.data.(Trigger_Data); ok {
            value := (rl.GetGamepadAxisMovement(device, trigger.type) + 1.0) * 0.5
            ok := value >= u16_to_f32(trigger.threshold) && !float_equals(0, value)
            if ok && m.on_hold != nil {
                m.on_hold(m.user_data)
            }
            return {val = value, ok = ok}
        }
    case .JOYSTICK:
        if joystick, ok := m.data.(Joystick_Data); ok {
            value := rl.GetGamepadAxisMovement(device, joystick.type)
            if (joystick.range == .POSITIVE && value <= 0) ||
               (joystick.range == .NEGATIVE && value >= 0) ||
               (abs(value) < u16_to_f32(joystick.threshold)) {
                return {val = 0, ok = false}
            }
            if m.on_hold != nil {
                m.on_hold(m.user_data)
            }
            return {val = value, ok = !float_equals(0, value)}
        }
    case:
        return {ok = false, val = 0}
    }
    return {ok = false, val = 0}
}

Handler :: struct {
    device: Device,
    mappings: [dynamic]Map, // Changed to dynamic array
    size: Action_Size,
}

handler_create :: proc(device: Device, n_actions: Action_Size = 0) -> Handler {
    mappings := make([dynamic]Map, 0, max(n_actions, DEFAULT_MAP_ALLOC_SIZE))
    return Handler{
        device = device,
        mappings = mappings,
        size = n_actions,
    }
}

handler_delete :: proc(handler: ^Handler) {
    delete(handler.mappings)
}

handler_add_map :: proc(handler: ^Handler, m: Map) -> bool {
    if is_valid(handler.device, m.method) {
        if len(handler.mappings) >= cap(handler.mappings) {
            new_cap := cap(handler.mappings) + DEFAULT_MAP_ALLOC_SIZE
            reserve(&handler.mappings, new_cap)
        }
        append(&handler.mappings, m)
        handler.size += 1
        return true
    }
    return false
}

handler_add_action :: proc(handler: ^Handler, method: Method, data: Data, on_press, on_hold, on_release: proc(data: rawptr), user_data: rawptr = nil) -> bool {
    m := map_create(method, data, on_press, on_hold, on_release, user_data)
    return handler_add_map(handler, m)
}

handler_map_set :: proc(handler: ^Handler, action_id: Action, m: Map) -> bool {
    if action_id >= handler.size {
        return false
    }
    return handler_set(handler.device, handler.mappings[:], action_id, m)
}

handler_mappings_set :: proc(handler: ^Handler, mappings: []Map) -> Action_Size {
    errors: Action_Size = 0
    for i in 0..<min(handler.size, Action_Size(len(mappings))) {
        if !handler_set(handler.device, handler.mappings[:], i, mappings[i]) {
            errors += 1
        }
    }
    return errors
}

handler_get_value :: proc(handler: Handler, action_id: Action) -> Result {
    if action_id >= handler.size {
        return {ok = false, val = 0}
    }
    return get_value(handler.device, handler.mappings[:], action_id)
}

// TODO apply callbacks and helper procs similarly to Greedy_Handler and update main to reflect changes
Device_Results :: struct {
    device: Device,
    results: []Result,
}

Greedy_Handler :: struct {
    keyboard_mouse_map, gamepad_map: [dynamic]Map,
    results: []Result,
    size: Action_Size,
    active_device: Device,
    active_device_state: Device_State,
}

greedy_handler_create :: proc(n_actions: Action_Size) -> Greedy_Handler {
    keyboard_mouse_mappings := make([dynamic]Map, 0, max(n_actions, DEFAULT_MAP_ALLOC_SIZE))
    gamepad_mappings := make([dynamic]Map, 0, max(n_actions, DEFAULT_MAP_ALLOC_SIZE))
    res := make([]Result, n_actions)
    return Greedy_Handler {
        keyboard_mouse_map = keyboard_mouse_mappings,
        gamepad_map = gamepad_mappings,
        results = res,
        size = n_actions,
        active_device = DEVICE_DEFAULT,
        active_device_state = .INITIAL,
    }
}

greedy_handler_delete :: proc(handler: ^Greedy_Handler) {
    delete(handler.keyboard_mouse_map)
    delete(handler.gamepad_map)
    delete(handler.results)
}

greedy_handler_add_map :: proc(handler: ^Greedy_Handler, device: Device, m: Map) -> bool {
    if is_valid(device, m.method) {
        mappings: ^[dynamic]Map
        if device >= 0 {
            mappings = &handler.gamepad_map
        } else if device == DEVICE_KEYBOARD_AND_MOUSE {
            mappings = &handler.keyboard_mouse_map
        } else {
            return false
        }
        if len(mappings^) >= cap(mappings^) {
            new_cap := cap(mappings^) + DEFAULT_MAP_ALLOC_SIZE
            reserve(mappings, new_cap)
        }
        append(mappings, m)
        handler.size = max(handler.size, Action_Size(len(mappings^)))
        return true
    }
    return false
}

greedy_handler_map_set :: proc(handler: ^Greedy_Handler, device: Device, action_id: Action, m: Map) -> bool {
    if action_id >= handler.size || !is_valid(device, m.method) {
        return false
    }
    if device >= 0 {
        if action_id >= Action_Size(len(handler.gamepad_map)) {
            resize(&handler.gamepad_map, int(action_id + 1))
        }
        handler.gamepad_map[action_id] = m
        return true
    } else if device == DEVICE_KEYBOARD_AND_MOUSE {
        if action_id >= Action_Size(len(handler.keyboard_mouse_map)) {
            resize(&handler.keyboard_mouse_map, int(action_id + 1))
        }
        handler.keyboard_mouse_map[action_id] = m
        return true
    }
    return false
}

greedy_handler_device_mappings_set :: proc(handler: ^Greedy_Handler, device: Device, mappings: []Map) -> Action_Size {
    errors: Action_Size = 0
    mappings_dynamic: ^[dynamic]Map
    if device >= 0 {
        mappings_dynamic = &handler.gamepad_map
    } else if device == DEVICE_KEYBOARD_AND_MOUSE {
        mappings_dynamic = &handler.keyboard_mouse_map
    } else {
        return handler.size
    }
    if len(mappings_dynamic^) < len(mappings) {
        resize(mappings_dynamic, len(mappings))
    }
    for i in 0..<min(handler.size, Action_Size(len(mappings))) {
        if !handler_set(device, mappings_dynamic^[:], i, mappings[i]) {
            errors += 1
        }
    }
    handler.size = max(handler.size, Action_Size(len(mappings_dynamic^)))
    return errors
}

greedy_handler_mappings_set :: proc(handler: ^Greedy_Handler, keyboard_mouse_mappings: []Map, gamepad_mappings: []Map) -> Action_Size {
    errs: Action_Size = 0
    // Set keyboard/mouse mappings
    errs += greedy_handler_device_mappings_set(handler, DEVICE_KEYBOARD_AND_MOUSE, keyboard_mouse_mappings)
    // Set gamepad mappings
    errs += greedy_handler_device_mappings_set(handler, DEVICE_FIRST_GAMEPAD, gamepad_mappings)
    return errs
}

greedy_handler_update_results_with_device :: proc(handler: ^Greedy_Handler, device: Device) -> bool {
    is_being_used := false
    mappings: []Map
    
    // Special devices
    if device < 0 {
        if device == DEVICE_KEYBOARD_AND_MOUSE {
            mappings = handler.keyboard_mouse_map[:]
        }
    } else {
        // Gamepads
        if rl.IsGamepadAvailable(device) {
            mappings = handler.gamepad_map[:]
        }
    }
    if len(mappings) > 0 {
        for action_id in 0..<handler.size {
            if action_id < Action_Size(len(mappings)) {
                result := get_value(device, mappings, action_id)
                handler.results[action_id] = result
                is_being_used = result.ok || is_being_used
            }
        }
    }
    return is_being_used
}

greedy_handler_update :: proc(handler: ^Greedy_Handler) -> Device_Results {
    active_device_missing := false
    active_device_used := false
    
    // Current device missing check
    if handler.active_device >= 0 && !rl.IsGamepadAvailable(handler.active_device) {
        active_device_missing = true
        handler.active_device = DEVICE_DEFAULT
    } else if greedy_handler_update_results_with_device(handler, handler.active_device) {
        // Current device usage check
        active_device_used = true
    }
    if active_device_missing || !active_device_used {
        // Gamepad usage check
        for device in 0..<MAX_GAMEPADS {
            if i32(device) != handler.active_device && greedy_handler_update_results_with_device(handler, i32(device)) {
                handler.active_device = i32(device)
                handler.active_device_state = active_device_missing ? .MISSING_2_ACTIVE : .IDLE_2_ACTIVE
                return Device_Results {
                    device = handler.active_device,
                    results = handler.results,
                }
            }
        }
        // K&M usage check
        if greedy_handler_update_results_with_device(handler, DEVICE_KEYBOARD_AND_MOUSE) {
            handler.active_device = DEVICE_KEYBOARD_AND_MOUSE
            handler.active_device_state = active_device_missing ? .MISSING_2_ACTIVE : .IDLE_2_ACTIVE
            return Device_Results {
                device = handler.active_device,
                results = handler.results,
            }
        }
    }
    handler.active_device_state = active_device_missing ? .MISSING_2_DEFAULT : (active_device_used ? .ACTIVE : .IDLE)
    
    return Device_Results {
        device = handler.active_device,
        results = handler.results,
    }
}

/* Example sets up a full input handler for a jump action using SPACE

main :: proc() {
    // Create greedy input handler for 5 actions
    handler := greedy_handler_create(5)
    defer greedy_handler_delete(&handler)

    // Callbacks for jump action
    jump_press :: proc "c" (data: rawptr) {
        fmt.println("Jump pressed!")
    }
    jump_hold :: proc "c" (data: rawptr) {
        fmt.println("Jump held!")
    }
    jump_release :: proc "c" (data: rawptr) {
        fmt.println("Jump released!")
    }

    greedy_handler_map_set(&handler, DEVICE_KEYBOARD_AND_MOUSE, 0, map_create(
        method = .KEY_PRESSED,
        data = rl.KeyboardKey.SPACE,
        on_press = jump_press,
        on_hold = jump_hold,
        on_release = jump_release,
    ))
        
    greedy_handler_map_set(&handler, DEVICE_FIRST_GAMEPAD, 0, map_create(
        method = .PAD_PRESSED,
        data = rl.GamepadButton.A,
        on_press = jump_press,
        on_hold = jump_hold,
        on_release = jump_release,
    ))

    for !rl.WindowShouldClose() {
        device_results := greedy_handler_update(&handler)
        
        // Check jump action result
        jump := greedy_handler_get_value(handler, 0)
        if jump.ok {
            fmt.println("Jump action triggered on device:", device_results.device)
        }
        rl.BeginDrawing()
        rl.ClearBackground(rl.RAYWHITE)
        rl.EndDrawing()
    }
}
*/

