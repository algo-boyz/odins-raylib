package input

import "core:math"
import rl "vendor:raylib"

// Type aliases to match the original code style
Device :: i32
Action :: u32
Action_Size :: u32
// Constants
DEVICE_NULL :: -2
DEVICE_DEFAULT :: -1
DEVICE_KEYBOARD_AND_MOUSE :: -1
DEVICE_FIRST_GAMEPAD :: 0
MAX_GAMEPADS :: 4

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
}

Result :: struct {
    ok: bool,
    val: f32,
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

// Convert u16 to f32 (simulating f16tof conversion)
@private
u16_to_f32 :: proc(val: u16) -> f32 {
    return f32(val) / 65535.0
}

// Check if the input method is valid for the specified input device
is_valid :: proc(device: Device, method: Method) -> bool {
    // Gamepad check
    switch true {
    case device >= 0:
        return !from_keyboard_and_mouse(method)
    case device == DEVICE_KEYBOARD_AND_MOUSE:
        // Keyboard & Mouse check
        return from_keyboard_and_mouse(method)
    case device == DEVICE_NULL:
        // No input method
        return method == .METHOD_NONE
    }
    return false
}

// Set an input map - action_id must be a valid index for the actions array
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
    // Keyboard Key - bool
    case .KEY_PRESSED:
        if key, ok := m.data.(rl.KeyboardKey); ok {
            value := rl.IsKeyPressed(key)
            return {ok = value, val = f32(key)}
        }
    case .KEY_RELEASED:
        if key, ok := m.data.(rl.KeyboardKey); ok {
            value := rl.IsKeyReleased(key)
            return {ok = value, val = f32(key)}
        }
    case .KEY_DOWN:
        if key, ok := m.data.(rl.KeyboardKey); ok {
            value := rl.IsKeyDown(key)
            return {ok = value, val = f32(key)}
        }
    case .KEY_UP:
        if key, ok := m.data.(rl.KeyboardKey); ok {
            value := rl.IsKeyUp(key)
            return {ok = value, val = f32(key)}
        }
    
    // Mouse Button - bool
    case .MOUSE_PRESSED:
        if key, ok := m.data.(rl.MouseButton); ok {
            value := rl.IsMouseButtonPressed(key)
            return {ok = value, val = f32(key)}
        }
    case .MOUSE_RELEASED:
        if key, ok := m.data.(rl.MouseButton); ok {
            value := rl.IsMouseButtonReleased(key)
            return {ok = value, val = f32(key)}
        }
    case .MOUSE_DOWN:
        if key, ok := m.data.(rl.MouseButton); ok {
            value := rl.IsMouseButtonDown(key)
            return {ok = value, val = f32(key)}
        }
    case .MOUSE_UP:
        if key, ok := m.data.(rl.MouseButton); ok {
            value := rl.IsMouseButtonUp(key)
            return {ok = value, val = f32(key)}
        }
    
    // Mouse Position - float
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
            return abs(delta) >= f32(movement.threshold) ? {val = value, ok = !float_equals(0, delta)} : {val = 0, ok = false}
        }
    
    // Mouse Movement - float
    case .MOUSE_MOVEMENT:
        if movement, ok := m.data.(Movement_Data); ok {
            value := movement.axis == .X ? rl.GetMouseDelta().x : rl.GetMouseDelta().y
            return abs(value) >= f32(movement.threshold) ? {val = value, ok = !float_equals(0, value)} : {val = 0, ok = false}
        }
    
    // Mouse Scroll - float
    case .MOUSE_SCROLL:
        if scroll, ok := m.data.(Scroll_Data); ok {
            value := rl.GetMouseWheelMove()
            return abs(value) >= f32(scroll.threshold) ? {val = value, ok = !float_equals(0, value)} : {val = 0, ok = false}
        }
    
    // Gamepad Button - bool
    case .PAD_PRESSED:
        if key, ok := m.data.(rl.GamepadButton); ok {
            value := rl.IsGamepadButtonPressed(device, key)
            return {ok = value, val = f32(key)}
        }
    case .PAD_RELEASED:
        if key, ok := m.data.(rl.GamepadButton); ok {
            value := rl.IsGamepadButtonReleased(device, key)
            return {ok = value, val = f32(key)}
        }
    case .PAD_DOWN:
        if key, ok := m.data.(rl.GamepadButton); ok {
            value := rl.IsGamepadButtonDown(device, key)
            return {ok = value, val = f32(key)}
        }
    case .PAD_UP:
        if key, ok := m.data.(rl.GamepadButton); ok {
            value := rl.IsGamepadButtonUp(device, key)
            return {ok = value, val = f32(key)}
        }
    
    // Gamepad Trigger - float
    case .PAD_TRIGGER:
        if trigger, ok := m.data.(Trigger_Data); ok {
            value := rl.GetGamepadAxisMovement(device, trigger.type)
            return (value + 1) >= u16_to_f32(trigger.threshold) ? {val = value, ok = !float_equals(-1, value)} : {val = 0, ok = false}
        }
    
    // Gamepad Trigger (normalized) - float - from `-1..1` to `0..1`
    case .PAD_TRIGGER_NORM:
        if trigger, ok := m.data.(Trigger_Data); ok {
            value := (rl.GetGamepadAxisMovement(device, trigger.type) + 1.0) * 0.5
            return value >= u16_to_f32(trigger.threshold) ? {val = value, ok = !float_equals(0, value)} : {val = 0, ok = false}
        }
    
    // Gamepad Joystick - float
    case .JOYSTICK:
        if joystick, ok := m.data.(Joystick_Data); ok {
            value := rl.GetGamepadAxisMovement(device, joystick.type)
            if (joystick.range == .POSITIVE && value <= 0) ||
               (joystick.range == .NEGATIVE && value >= 0) ||
               (abs(value) < u16_to_f32(joystick.threshold)) {
                return {val = 0, ok = false}
            }
            return {val = value, ok = !float_equals(0, value)}
        }
    
    // No input method - false
    case:
        return {ok = false, val = 0}
    }
    
    return {ok = false, val = 0}
}

Handler :: struct {
    device: Device,
    mappings: []Map,
    size: Action_Size,
}

handler_create :: proc(device: Device, n_actions: Action_Size) -> Handler {
    mappings := make([]Map, n_actions)
    return Handler {
        device = device,
        mappings = mappings,
        size = n_actions,
    }
}

handler_delete :: proc(handler: ^Handler) {
    delete(handler.mappings)
}

handler_map_set :: proc(handler: ^Handler, action_id: Action, m: Map) -> bool {
    return handler_set(handler.device, handler.mappings, action_id, m)
}

handler_mappings_set :: proc(handler: ^Handler, mappings: []Map) -> Action_Size {
    errors: Action_Size = 0
    for i in 0..<handler.size {
        if !handler_set(handler.device, handler.mappings, i, mappings[i]) {
            errors += 1
        }
    }
    return errors
}

handler_get_value :: proc(handler: Handler, action_id: Action) -> Result {
    return get_value(handler.device, handler.mappings, action_id)
}

Device_Results :: struct {
    device: Device,
    results: []Result,
}

Greedy_Handler :: struct {
    keyboard_mouse_map: []Map,
    gamepad_map: []Map,
    results: []Result,
    size: Action_Size,
    active_device: Device,
    active_device_state: Device_State,
}

greedy_handler_create :: proc(n_actions: Action_Size) -> Greedy_Handler {
    keyboard_mouse_mappings := make([]Map, n_actions)
    gamepad_mappings := make([]Map, n_actions)
    results := make([]Result, n_actions)
    
    return Greedy_Handler {
        keyboard_mouse_map = keyboard_mouse_mappings,
        gamepad_map = gamepad_mappings,
        results = results,
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

greedy_handler_map_set :: proc(handler: ^Greedy_Handler, device: Device, action_id: Action, m: Map) -> bool {
    if device >= 0 {
        return handler_set(DEVICE_FIRST_GAMEPAD, handler.gamepad_map, action_id, m)
    } else if device == DEVICE_KEYBOARD_AND_MOUSE {
        return handler_set(DEVICE_KEYBOARD_AND_MOUSE, handler.keyboard_mouse_map, action_id, m)
    }
    return false
}

greedy_handler_device_mappings_set :: proc(handler: ^Greedy_Handler, device: Device, mappings: []Map) -> Action_Size {
    errors: Action_Size = 0
    
    current_mappings: []Map
    if device >= 0 {
        current_mappings = handler.gamepad_map
    } else if device == DEVICE_KEYBOARD_AND_MOUSE {
        current_mappings = handler.keyboard_mouse_map
    }
    
    if len(current_mappings) > 0 {
        for i in 0..<handler.size {
            if !handler_set(device, current_mappings, i, mappings[i]) {
                errors += 1
            }
        }
    } else {
        errors += handler.size
    }
    
    return errors
}

greedy_handler_mappings_set :: proc(handler: ^Greedy_Handler, keyboard_mouse_mappings: []Map, gamepad_mappings: []Map) -> Action_Size {
    errors: Action_Size = 0
    
    for i in 0..<handler.size {
        if !handler_set(DEVICE_KEYBOARD_AND_MOUSE, handler.keyboard_mouse_map, i, keyboard_mouse_mappings[i]) {
            errors += 1
        }
    }
    
    for i in 0..<handler.size {
        if !handler_set(DEVICE_FIRST_GAMEPAD, handler.gamepad_map, i, gamepad_mappings[i]) {
            errors += 1
        }
    }
    
    return errors
}

// Returns `true` if an input had a boolean value different from `false` (representing the device being the one used)
greedy_handler_update_results_with_device :: proc(handler: ^Greedy_Handler, device: Device) -> bool {
    is_being_used := false
    mappings: []Map
    
    // Special devices
    if device < 0 {
        if device == DEVICE_KEYBOARD_AND_MOUSE {
            mappings = handler.keyboard_mouse_map
        }
    } else {
        // Gamepads
        if rl.IsGamepadAvailable(device) {
            mappings = handler.gamepad_map
        }
    }
    
    if len(mappings) > 0 {
        for action_id in 0..<handler.size {
            result := get_value(device, mappings, action_id)
            handler.results[action_id] = result
            is_being_used = result.ok || is_being_used
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

greedy_handler_get_value :: proc(handler: Greedy_Handler, action_id: Action) -> Result {
    return handler.results[action_id]
}

greedy_handler_get_all_values :: proc(handler: Greedy_Handler) -> []Result {
    return handler.results
}

/* Example usage of the input handler
This example sets up a basic input handler for a jump action using the space key.

main :: proc() {
    // Create a basic input handler
    handler := handler_create(DEVICE_KEYBOARD_AND_MOUSE, 5)
    defer handler_delete(&handler)

    // Set up a mapping for jump action
    jump_map := Map{
        method = .KEY_PRESSED,
        data = .SPACE,
    }
    handler_map_set(&handler, 0, jump_map)

    // Get input value
    result := handler_get_value(handler, 0)
    if result.ok {
        // Player pressed jump!
    }
}
*/