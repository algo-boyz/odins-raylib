#include "input-handler.h"

#include "rayconfig.h"
#include "raylib.h"
#include "raymath.h"
#include "types.h"

// Check if the input method is valid for the specified input device
bool IsValidInputMethod(InputDeviceID device, InputMethod method) {
    // Gamepad check
    if (device >= 0) {
        return !IS_METHOD_FROM_KEYBOARD_AND_MOUSE(method);
    }
    // Keyboard & Mouse check
    else if (device == INPUT_DEVICE_ID_KEYBOARD_AND_MOUSE) {
        return IS_METHOD_FROM_KEYBOARD_AND_MOUSE(method);
    }
    // No input method
    else if (device == INPUT_DEVICE_ID_NULL) {
        return method == METHOD_NONE;
    }
    // Other configuration
    return false;
}

// Set an input map - action_id must be a valid index for the actions array
bool InputHandlerSet(InputDeviceID device, InputMap *mappings, InputActionID action_id, const InputMap map) {
    if (IsValidInputMethod(device, map.method)) {
        mappings[action_id] = map;
        return true;
    }
    return false;
}

InputResult InputHandlerGetValue(InputDeviceID device, const InputMap mappings[], InputActionID action_id) {
    InputMap map = mappings[action_id];
    switch (map.method) {
        // Keyboard Key - bool
        case METHOD_KEYBOARD_KEY_PRESSED: {
            bool value = IsKeyPressed(map.data.key);
            return (InputResult){.bool_v = value, .float_v = value};
        }
        case METHOD_KEYBOARD_KEY_RELEASED: {
            bool value = IsKeyReleased(map.data.key);
            return (InputResult){.bool_v = value, .float_v = value};
        }
        case METHOD_KEYBOARD_KEY_DOWN: {
            bool value = IsKeyDown(map.data.key);
            return (InputResult){.bool_v = value, .float_v = value};
        }
        case METHOD_KEYBOARD_KEY_UP: {
            bool value = IsKeyUp(map.data.key);
            return (InputResult){.bool_v = value, .float_v = value};
        }

        // Mouse Button - bool
        case METHOD_MOUSE_BUTTON_PRESSED: {
            bool value = IsMouseButtonPressed(map.data.button);
            return (InputResult){.bool_v = value, .float_v = value};
        }
        case METHOD_MOUSE_BUTTON_RELEASED: {
            bool value = IsMouseButtonReleased(map.data.button);
            return (InputResult){.bool_v = value, .float_v = value};
        }
        case METHOD_MOUSE_BUTTON_DOWN: {
            bool value = IsMouseButtonDown(map.data.button);
            return (InputResult){.bool_v = value, .float_v = value};
        }
        case METHOD_MOUSE_BUTTON_UP: {
            bool value = IsMouseButtonUp(map.data.button);
            return (InputResult){.bool_v = value, .float_v = value};
        }

        // Mouse Position - float
        case METHOD_MOUSE_POSITION: {
            f32 value;
            f32 delta;
            if (map.data.movement.axis == MOUSE_AXIS_X) {
                value = GetMousePosition().x;
                delta = GetMouseDelta().x;
            } else {
                value = GetMousePosition().y;
                delta = GetMouseDelta().y;
            }
            return fabsf(delta) >= (f32)map.data.movement.threshold ? (InputResult){.float_v = value, .bool_v = !FloatEquals(0, delta)}
                                                                    : (InputResult){.float_v = 0, .bool_v = false};
        }

        // Mouse Movement - float
        case METHOD_MOUSE_MOVEMENT: {
            f32 value = map.data.movement.axis == MOUSE_AXIS_X ? GetMouseDelta().x : GetMouseDelta().y;
            return fabsf(value) >= (f32)map.data.movement.threshold ? (InputResult){.float_v = value, .bool_v = !FloatEquals(0, value)}
                                                                    : (InputResult){.float_v = 0, .bool_v = false};
        }

        // Mouse Scroll - float
        case METHOD_MOUSE_SCROLL: {
            f32 value = GetMouseWheelMove();
            return fabsf(value) >= (f32)map.data.scroll.threshold ? (InputResult){.float_v = value, .bool_v = !FloatEquals(0, value)}
                                                                  : (InputResult){.float_v = 0, .bool_v = false};
        }

        // Gamepad Button - bool
        case METHOD_GAMEPAD_BUTTON_PRESSED: {
            bool value = IsGamepadButtonPressed(device, map.data.button);
            return (InputResult){.bool_v = value, .float_v = value};
        }
        case METHOD_GAMEPAD_BUTTON_RELEASED: {
            bool value = IsGamepadButtonReleased(device, map.data.button);
            return (InputResult){.bool_v = value, .float_v = value};
        }
        case METHOD_GAMEPAD_BUTTON_DOWN: {
            bool value = IsGamepadButtonDown(device, map.data.button);
            return (InputResult){.bool_v = value, .float_v = value};
        }
        case METHOD_GAMEPAD_BUTTON_UP: {
            bool value = IsGamepadButtonUp(device, map.data.button);
            return (InputResult){.bool_v = value, .float_v = value};
        }

        // Gamepad Trigger - float
        case METHOD_GAMEPAD_TRIGGER: {
            f32 value = GetGamepadAxisMovement(device, map.data.trigger.type);
            return (value + 1) >= f16tof(map.data.trigger.threshold) ? (InputResult){.float_v = value, .bool_v = !FloatEquals(-1, value)}
                                                                     : (InputResult){.float_v = 0, .bool_v = false};
        }

        // Gamepad Trigger (normalized) - float - from `-1..1` to `0..1`
        case METHOD_GAMEPAD_TRIGGER_NORM: {
            f32 value = (GetGamepadAxisMovement(device, map.data.trigger.type) + 1.0f) * 0.5f;
            return value >= f16tof(map.data.trigger.threshold) ? (InputResult){.float_v = value, .bool_v = !FloatEquals(0, value)}
                                                               : (InputResult){.float_v = 0, .bool_v = false};
        }

        // Gamepad Joystick - float
        case METHOD_GAMEPAD_JOYSTICK: {
            f32 value = GetGamepadAxisMovement(device, map.data.joystick.type);
            return ((map.data.joystick.range == AXIS_RANGE_POSITIVE && value <= 0) ||
                    (map.data.joystick.range == AXIS_RANGE_NEGATIVE && value >= 0) || (fabsf(value) < f16tof(map.data.joystick.threshold)))
                       ? (InputResult){.float_v = 0, .bool_v = false}
                       : (InputResult){.float_v = value, .bool_v = !FloatEquals(0, value)};
        }

        // No input method - false
        default: return (InputResult){.bool_v = false, .float_v = 0};
    }
}

// ----------------------------------------------------------------------------
// ---- Basic Input Handler ---------------------------------------------------
// ----------------------------------------------------------------------------

BasicInputHandler BasicInputHandlerCreate(InputDeviceID device, action_size n_actions) {
    return (BasicInputHandler){
        .device = device,
        .mappings = reserve_zero_a(InputMap, n_actions),
        .size = n_actions,
    };
}

void BasicInputHandlerDelete(BasicInputHandler *handler) { free(handler->mappings); }

bool BasicInputHandlerMapSet(BasicInputHandler *handler, InputActionID action_id, const InputMap map) {
    return InputHandlerSet(handler->device, handler->mappings, action_id, map);
}

action_size BasicInputHandlerMappingsSet(BasicInputHandler *handler, const InputMap mappings[]) {
    action_size errors = 0;
    for (action_size i = 0; i < handler->size; ++i) { errors += InputHandlerSet(handler->device, handler->mappings, i, mappings[i]); }
    return errors;
}

InputResult BasicInputHandlerGetValue(BasicInputHandler handler, InputActionID action_id) {
    return InputHandlerGetValue(handler.device, handler.mappings, action_id);
}

// ----------------------------------------------------------------------------
// ---- Greedy Input Handler --------------------------------------------------
// ----------------------------------------------------------------------------

GreedyInputHandler GreedyInputHandlerCreate(action_size n_actions) {
    byte *buffer = (byte *)malloc((sizeof(InputMap) * n_actions * 2) + (sizeof(InputResult) * n_actions));
    return (GreedyInputHandler){
        .keyboard_mouse_mappings = (InputMap *)buffer,
        .gamepad_mappings = (InputMap *)&buffer[sizeof(InputMap) * n_actions],
        .results = (InputResult *)&buffer[sizeof(InputMap) * n_actions * 2],
        .size = n_actions,
        .active_device = INPUT_DEVICE_ID_DEFAULT,
        .active_device_state = INPUT_DEVICE_STATE_INITIAL,
    };
}

void GreedyInputHandlerDelete(GreedyInputHandler *handler) { free(handler->keyboard_mouse_mappings); }

bool GreedyInputHandlerMapSet(GreedyInputHandler *handler, InputDeviceID device, InputActionID action_id, const InputMap map) {
    if (device >= 0) {
        return InputHandlerSet(INPUT_DEVICE_ID_FIRST_GAMEPAD, handler->gamepad_mappings, handler->size, map);
    } else if (device == INPUT_DEVICE_ID_KEYBOARD_AND_MOUSE) {
        return InputHandlerSet(INPUT_DEVICE_ID_KEYBOARD_AND_MOUSE, handler->keyboard_mouse_mappings, handler->size, map);
    }
    return false;
}

action_size GreedyInputHandlerDeviceMappingsSet(GreedyInputHandler *handler, InputDeviceID device, const InputMap mappings[]) {
    action_size errors = 0;

    InputMap *current_mappings =
        device >= 0 ? handler->gamepad_mappings : (device == INPUT_DEVICE_ID_KEYBOARD_AND_MOUSE ? handler->keyboard_mouse_mappings : NULL);

    if (current_mappings != NULL) {
        for (action_size i = 0; i < handler->size; ++i) { errors += InputHandlerSet(device, current_mappings, i, mappings[i]); }
    } else {
        errors += handler->size;
    }

    return errors;
}

action_size GreedyInputHandlerMappingsSet(GreedyInputHandler *handler,
                                          const InputMap keyboard_mouse_mappings[],
                                          const InputMap gamepad_mappings[]) {
    action_size errors = 0;

    for (action_size i = 0; i < handler->size; ++i) {
        errors += InputHandlerSet(INPUT_DEVICE_ID_KEYBOARD_AND_MOUSE, handler->keyboard_mouse_mappings, i, keyboard_mouse_mappings[i]);
    }

    for (action_size i = 0; i < handler->size; ++i) {
        errors += InputHandlerSet(INPUT_DEVICE_ID_FIRST_GAMEPAD, handler->gamepad_mappings, i, gamepad_mappings[i]);
    }

    return errors;
}

// Returns `true` if an input had a boolean value different from `0` (representing the device being the one used)
bool GreedyInputHandlerUpdateResultsWithDevice(GreedyInputHandler *handler, InputDeviceID device) {
    bool is_being_used = false;
    InputMap *mappings = NULL;

    // Special devices
    if (device < 0) {
        if (device == INPUT_DEVICE_ID_KEYBOARD_AND_MOUSE) { mappings = handler->keyboard_mouse_mappings; }
    }
    // Gamepads
    else {
        if (IsGamepadAvailable(device)) { mappings = handler->gamepad_mappings; }
    }

    if (mappings != NULL) {
        for (InputActionID action_id = 0; action_id < handler->size; ++action_id) {
            is_being_used = (handler->results[action_id] = InputHandlerGetValue(device, mappings, action_id)).bool_v || is_being_used;
        }
    }
    return is_being_used;
}

InputDeviceResults GreedyInputHandlerUpdate(GreedyInputHandler *handler) {
    bool active_device_missing = false;
    bool active_device_used = false;

    // Current device missing check
    if (handler->active_device >= 0 && !IsGamepadAvailable(handler->active_device)) {
        active_device_missing = true;
        handler->active_device = INPUT_DEVICE_ID_DEFAULT;  // Set default input device in case no other device is used
    }
    // Current device usage check
    else if (GreedyInputHandlerUpdateResultsWithDevice(handler, handler->active_device)) {
        active_device_used = true;
    }

    if (active_device_missing || !active_device_used) {
        // Gamepad usage check
        for (InputDeviceID device = 0; device < MAX_GAMEPADS; ++device) {
            if (device != handler->active_device && GreedyInputHandlerUpdateResultsWithDevice(handler, device)) {
                handler->active_device = device;
                handler->active_device_state = active_device_missing
                                                   ? INPUT_DEVICE_STATE_CHANGE_MISSING_2_ACTIVE  // Last active device went missing - Change
                                                   : INPUT_DEVICE_STATE_CHANGE_IDLE_2_ACTIVE;    // Last active device was idle - Change

                return (InputDeviceResults){
                    .device = handler->active_device,
                    .results = handler->results,
                };
            }
        }

        // K&M usage check
        if (GreedyInputHandlerUpdateResultsWithDevice(handler, INPUT_DEVICE_ID_KEYBOARD_AND_MOUSE)) {
            handler->active_device = INPUT_DEVICE_ID_KEYBOARD_AND_MOUSE;
            handler->active_device_state = active_device_missing
                                               ? INPUT_DEVICE_STATE_CHANGE_MISSING_2_ACTIVE  // Last active device went missing - Change
                                               : INPUT_DEVICE_STATE_CHANGE_IDLE_2_ACTIVE;    // Last active device was idle - Change

            return (InputDeviceResults){
                .device = handler->active_device,
                .results = handler->results,
            };
        }
    }

    handler->active_device_state = active_device_missing
                                       ? INPUT_DEVICE_STATE_CHANGE_MISSING_2_DEFAULT      // Active device went missing - Default selected
                                       : (active_device_used ? INPUT_DEVICE_STATE_ACTIVE  // Active device in use - No change
                                                             : INPUT_DEVICE_STATE_IDLE);  // Active device is idle - No change

    return (InputDeviceResults){
        .device = handler->active_device,
        .results = handler->results,
    };
}

InputResult GreedyInputHandlerGetValue(GreedyInputHandler handler, InputActionID action_id) { return handler.results[action_id]; }

InputResult *GreedyInputHandlerGetAllValues(GreedyInputHandler handler) { return handler.results; }
