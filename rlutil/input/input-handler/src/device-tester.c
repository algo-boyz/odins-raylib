#include "input-handler.h"
#include "rayconfig.h"
#include "raylib.h"
#include "types.h"

// Macro definitions //

#define BOOLEAN_VARIATIONS 3
#define FLOAT_VARIATIONS   1

#define N_KEYBOARD_KEY_ACTIONS   (110 * BOOLEAN_VARIATIONS)  // Number of keyboard key actions
#define N_MOUSE_BUTTON_ACTIONS   (7 * BOOLEAN_VARIATIONS)    // Number of mouse button actions
#define N_MOUSE_POSITION_ACTIONS (2 * FLOAT_VARIATIONS)      // Number of mouse movement actions
#define N_MOUSE_MOVEMENT_ACTIONS (2 * FLOAT_VARIATIONS)      // Number of mouse movement actions
#define N_MOUSE_SCROLL_ACTIONS   (1 * FLOAT_VARIATIONS)      // Number of mouse movement actions
#define N_KEYBOARD_MOUSE_ACTIONS                                                                             \
    (N_KEYBOARD_KEY_ACTIONS + N_MOUSE_BUTTON_ACTIONS + N_MOUSE_POSITION_ACTIONS + N_MOUSE_MOVEMENT_ACTIONS + \
     N_MOUSE_SCROLL_ACTIONS)  // Size of the keyboard and mouse actions array

#define N_GAMEPAD_BUTTON_ACTIONS       (18 * BOOLEAN_VARIATIONS)  // Number of gamepad button actions
#define N_GAMEPAD_TRIGGER_ACTIONS      (2 * FLOAT_VARIATIONS)     // Number of gamepad axis actions
#define N_GAMEPAD_TRIGGER_NORM_ACTIONS (2 * FLOAT_VARIATIONS)     // Number of gamepad axis actions
#define N_GAMEPAD_JOYSTICK_ACTIONS     (4 * FLOAT_VARIATIONS)     // Number of gamepad axis actions
#define N_GAMEPAD_ACTIONS                                                                    \
    (N_GAMEPAD_BUTTON_ACTIONS + N_GAMEPAD_TRIGGER_ACTIONS + N_GAMEPAD_TRIGGER_NORM_ACTIONS + \
     N_GAMEPAD_JOYSTICK_ACTIONS)  // Size of the gamepad actions array

#define N_ACTIONS max(N_KEYBOARD_MOUSE_ACTIONS, N_GAMEPAD_ACTIONS)

#define MOUSE_MOVEMENT_THRESHOLD 2                           // Mouse movment minimal delta distance
#define MOUSE_SCROLL_THRESHOLD   1                           // Mouse movment minimal scroll
#define TRIGGER_THRESHOLD        0.2f                        // Gamepad trigger minimal pressure
#define TRIGGER_NORM_THRESHOLD   (TRIGGER_THRESHOLD * 0.5f)  // Gamepad trigger (normalized) minimal pressure
#define JOYSTICK_THRESHOLD       0.08f                       // Gamepad joystick minimal displacement

#define SCREEN_WIDTH  1400  // Screen width
#define SCREEN_HEIGHT 1000  // Screen height

#define FPS_PADDING_X 140  // FPS text horizontal padding from screen border
#define FPS_PADDING_Y 30   // FPS text vertical padding from screen border

#define FONT_SIZE  32        // Font size for rendering
#define FONT_COLOR RAYWHITE  // Font color

#define DEVICE_NAME_POS ((Vector2){30, 30})  // Device name text position

#define INPUT_TEXT_POS     ((Vector2){30, 60})  // Input text position
#define INPUT_TEXT_PADDING -35                  // Text spacing between lines
#define INPUT_TEXT_SPACING 24                   // Text spacing between lines

// Type definitions //

typedef struct {
    char str[1 << 8];
} String;

// Global definitions //

Font font = {0};

const char BOOLEAN_TEXTS[BOOLEAN_VARIATIONS][9] = {"Pressed ", "Released ", "Down "};

// Function definitions //

String textKeyboardKey(i32 key) {
    switch (key) {
        case KEY_NULL: return (String){"Null Key"};
        case KEY_APOSTROPHE: return (String){"'"};
        case KEY_COMMA: return (String){","};
        case KEY_MINUS: return (String){"-"};
        case KEY_PERIOD: return (String){"."};
        case KEY_SLASH: return (String){"/"};
        case KEY_ZERO: return (String){"0"};
        case KEY_ONE: return (String){"1"};
        case KEY_TWO: return (String){"2"};
        case KEY_THREE: return (String){"3"};
        case KEY_FOUR: return (String){"4"};
        case KEY_FIVE: return (String){"5"};
        case KEY_SIX: return (String){"6"};
        case KEY_SEVEN: return (String){"7"};
        case KEY_EIGHT: return (String){"8"};
        case KEY_NINE: return (String){"9"};
        case KEY_SEMICOLON: return (String){";"};
        case KEY_EQUAL: return (String){"="};
        case KEY_A: return (String){"A"};
        case KEY_B: return (String){"B"};
        case KEY_C: return (String){"C"};
        case KEY_D: return (String){"D"};
        case KEY_E: return (String){"E"};
        case KEY_F: return (String){"F"};
        case KEY_G: return (String){"G"};
        case KEY_H: return (String){"H"};
        case KEY_I: return (String){"I"};
        case KEY_J: return (String){"J"};
        case KEY_K: return (String){"K"};
        case KEY_L: return (String){"L"};
        case KEY_M: return (String){"M"};
        case KEY_N: return (String){"N"};
        case KEY_O: return (String){"O"};
        case KEY_P: return (String){"P"};
        case KEY_Q: return (String){"Q"};
        case KEY_R: return (String){"R"};
        case KEY_S: return (String){"S"};
        case KEY_T: return (String){"T"};
        case KEY_U: return (String){"U"};
        case KEY_V: return (String){"V"};
        case KEY_W: return (String){"W"};
        case KEY_X: return (String){"X"};
        case KEY_Y: return (String){"Y"};
        case KEY_Z: return (String){"Z"};
        case KEY_LEFT_BRACKET: return (String){"["};
        case KEY_BACKSLASH: return (String){"\\"};
        case KEY_RIGHT_BRACKET: return (String){"]"};
        case KEY_GRAVE: return (String){"`"};
        case KEY_SPACE: return (String){"Space"};
        case KEY_ESCAPE: return (String){"Escape"};
        case KEY_ENTER: return (String){"Enter"};
        case KEY_TAB: return (String){"Tab"};
        case KEY_BACKSPACE: return (String){"Backspace"};
        case KEY_INSERT: return (String){"Insert"};
        case KEY_DELETE: return (String){"Delete"};
        case KEY_RIGHT: return (String){"Right"};
        case KEY_LEFT: return (String){"Left"};
        case KEY_DOWN: return (String){"Down"};
        case KEY_UP: return (String){"Up"};
        case KEY_PAGE_UP: return (String){"Page Up"};
        case KEY_PAGE_DOWN: return (String){"Page Down"};
        case KEY_HOME: return (String){"Home"};
        case KEY_END: return (String){"End"};
        case KEY_CAPS_LOCK: return (String){"Caps Lock"};
        case KEY_SCROLL_LOCK: return (String){"Scroll Lock"};
        case KEY_NUM_LOCK: return (String){"Num Lock"};
        case KEY_PRINT_SCREEN: return (String){"Print Screen"};
        case KEY_PAUSE: return (String){"Pause"};
        case KEY_F1: return (String){"F1"};
        case KEY_F2: return (String){"F2"};
        case KEY_F3: return (String){"F3"};
        case KEY_F4: return (String){"F4"};
        case KEY_F5: return (String){"F5"};
        case KEY_F6: return (String){"F6"};
        case KEY_F7: return (String){"F7"};
        case KEY_F8: return (String){"F8"};
        case KEY_F9: return (String){"F9"};
        case KEY_F10: return (String){"F10"};
        case KEY_F11: return (String){"F11"};
        case KEY_F12: return (String){"F12"};
        case KEY_LEFT_SHIFT: return (String){"Shift (Left)"};
        case KEY_LEFT_CONTROL: return (String){"Control (Left)"};
        case KEY_LEFT_ALT: return (String){"Alt (Left)"};
        case KEY_LEFT_SUPER: return (String){"Command (Left)"};
        case KEY_RIGHT_SHIFT: return (String){"Shift (Right)"};
        case KEY_RIGHT_CONTROL: return (String){"Control (Right)"};
        case KEY_RIGHT_ALT: return (String){"Alt (Right)"};
        case KEY_RIGHT_SUPER: return (String){"Command (Right)"};
        case KEY_KB_MENU: return (String){"Menu"};
        case KEY_KP_0: return (String){"0 (Keypad)"};
        case KEY_KP_1: return (String){"1 (Keypad)"};
        case KEY_KP_2: return (String){"2 (Keypad)"};
        case KEY_KP_3: return (String){"3 (Keypad)"};
        case KEY_KP_4: return (String){"4 (Keypad)"};
        case KEY_KP_5: return (String){"5 (Keypad)"};
        case KEY_KP_6: return (String){"6 (Keypad)"};
        case KEY_KP_7: return (String){"7 (Keypad)"};
        case KEY_KP_8: return (String){"8 (Keypad)"};
        case KEY_KP_9: return (String){"9 (Keypad)"};
        case KEY_KP_DECIMAL: return (String){". (Keypad)"};
        case KEY_KP_DIVIDE: return (String){"\\ (Keypad)"};
        case KEY_KP_MULTIPLY: return (String){"* (Keypad)"};
        case KEY_KP_SUBTRACT: return (String){"- (Keypad)"};
        case KEY_KP_ADD: return (String){"+ (Keypad)"};
        case KEY_KP_ENTER: return (String){"Enter (Keypad)"};
        case KEY_KP_EQUAL: return (String){"= (Keypad)"};
        case KEY_BACK: return (String){"Back (Android)"};                // Android
        case KEY_MENU: return (String){"Menu (Android)"};                // Android
        case KEY_VOLUME_UP: return (String){"Volume Up (Android)"};      // Android
        case KEY_VOLUME_DOWN: return (String){"Volume Down (Android)"};  // Android
        default: return (String){"Unkown Keyboard Key"};
    }
}

String textMouseButton(i32 button) {
    switch (button) {
        case MOUSE_BUTTON_LEFT: return (String){"Mouse Left"};
        case MOUSE_BUTTON_RIGHT: return (String){"Mouse Right"};
        case MOUSE_BUTTON_MIDDLE: return (String){"Mouse Middle"};
        case MOUSE_BUTTON_SIDE: return (String){"Mouse Side"};
        case MOUSE_BUTTON_EXTRA: return (String){"Mouse Extra"};
        case MOUSE_BUTTON_FORWARD: return (String){"Mouse Forward"};
        case MOUSE_BUTTON_BACK: return (String){"Mouse Back"};
        default: return (String){"Unkown Mouse Button"};
    }
}

String textMousePosition(i32 axis) {
    switch (axis) {
        case MOUSE_AXIS_X: return (String){"Mouse Position X"};
        case MOUSE_AXIS_Y: return (String){"Mouse Position Y"};
        default: return (String){"Unkown Mouse Position Axis"};
    }
}

String textMouseMovement(i32 axis) {
    switch (axis) {
        case MOUSE_AXIS_X: return (String){"Mouse Movement X"};
        case MOUSE_AXIS_Y: return (String){"Mouse Movement Y"};
        default: return (String){"Unkown Mouse Movement Axis"};
    }
}

String textMouseScroll(i32 scroll) {
    switch (scroll) {
        case MOUSE_SCROLL_WHEEL: return (String){"Mouse Scroll Wheel"};
        default: return (String){"Unkown Mouse Scroll"};
    }
}

String textGamepadButton(i32 button) {
    switch (button) {
        case GAMEPAD_BUTTON_UNKNOWN: return (String){"Null Button"};
        case GAMEPAD_BUTTON_LEFT_FACE_UP: return (String){"Up Button (Left Face)"};
        case GAMEPAD_BUTTON_LEFT_FACE_RIGHT: return (String){"Right Button (Left Face)"};
        case GAMEPAD_BUTTON_LEFT_FACE_DOWN: return (String){"Down Button (Left Face)"};
        case GAMEPAD_BUTTON_LEFT_FACE_LEFT: return (String){"Left Button (Left Face)"};
        case GAMEPAD_BUTTON_RIGHT_FACE_UP: return (String){"Up Button (Right Face)"};
        case GAMEPAD_BUTTON_RIGHT_FACE_RIGHT: return (String){"Right Button (Right Face)"};
        case GAMEPAD_BUTTON_RIGHT_FACE_DOWN: return (String){"Down Button (Right Face)"};
        case GAMEPAD_BUTTON_RIGHT_FACE_LEFT: return (String){"Left Button (Right Face)"};
        case GAMEPAD_BUTTON_LEFT_TRIGGER_1: return (String){"Left Up Trigger Button"};
        case GAMEPAD_BUTTON_LEFT_TRIGGER_2: return (String){"Left Down Trigger Button"};
        case GAMEPAD_BUTTON_RIGHT_TRIGGER_1: return (String){"Right Up Trigger Button"};
        case GAMEPAD_BUTTON_RIGHT_TRIGGER_2: return (String){"Right Down Trigger Button"};
        case GAMEPAD_BUTTON_MIDDLE_LEFT: return (String){"Middle Left Button"};
        case GAMEPAD_BUTTON_MIDDLE: return (String){"Middle Button"};
        case GAMEPAD_BUTTON_MIDDLE_RIGHT: return (String){"Middle Right Button"};
        case GAMEPAD_BUTTON_LEFT_THUMB: return (String){"Left Joystick Button"};
        case GAMEPAD_BUTTON_RIGHT_THUMB: return (String){"Right Joystick Button"};
        default: return (String){"Unkown Gamepad Button"};
    }
}

String textGamepadTrigger(i32 trigger) {
    switch (trigger) {
        case GAMEPAD_TRIGGER_LEFT: return (String){"Left Trigger (Pressure)"};
        case GAMEPAD_TRIGGER_RIGHT: return (String){"Right Trigger (Pressure)"};
        default: return (String){"Unkown Gamepad Trigger (Pressure)"};
    }
}

String textGamepadTriggerNormalized(i32 trigger) {
    switch (trigger) {
        case GAMEPAD_TRIGGER_LEFT: return (String){"Left Trigger Normalized (Pressure)"};
        case GAMEPAD_TRIGGER_RIGHT: return (String){"Right Trigger Normalized (Pressure)"};
        default: return (String){"Unkown Gamepad Trigger Normalized (Pressure)"};
    }
}

String textGamepadJoystick(i32 joystick) {
    switch (joystick) {
        case GAMEPAD_JOYSTICK_LEFT_X: return (String){"Left Joystick (X Axis)"};
        case GAMEPAD_JOYSTICK_LEFT_Y: return (String){"Left Joystick (Y Axis)"};
        case GAMEPAD_JOYSTICK_RIGHT_X: return (String){"Right Joystick (X Axis)"};
        case GAMEPAD_JOYSTICK_RIGHT_Y: return (String){"Right Joystick (Y Axis)"};
        default: return (String){"Unkown Gamepad Joytick"};
    }
}

void screenText(const char* text, u32 x, u32 y) { DrawTextEx(font, text, (Vector2){x, y}, FONT_SIZE, 1, FONT_COLOR); }

bool hasResults(InputResult results[], action_size size) {
    for (action_size i = 0; i < size; ++i) {
        if (results[i].bool_v) { return true; }
    }
    return false;
}

const char* concatBooleanVariationResults(const char* input_text, InputResult results[BOOLEAN_VARIATIONS]) {
    return TextFormat("%*s [ %s%s%s]",
                      INPUT_TEXT_PADDING,
                      input_text,
                      results[0].bool_v ? BOOLEAN_TEXTS[0] : "",
                      results[1].bool_v ? BOOLEAN_TEXTS[1] : "",
                      results[2].bool_v ? BOOLEAN_TEXTS[2] : "");
}

const char* concatFloatVariationResults(const char* input_text, InputResult results[FLOAT_VARIATIONS], u16 threshold, bool isFloat) {
    return TextFormat("%*s [ Value %.3f, Threshold %.3f ]",
                      INPUT_TEXT_PADDING,
                      input_text,
                      results[0].float_v,
                      isFloat ? f16tof(threshold) : (f32)threshold);
}

void displayBoolValue(action_size* i, action_size limit, InputMap* mappings, InputResult* results, String (*textFn)(i32), u32* y) {
    for (; *i < limit; *i += BOOLEAN_VARIATIONS) {
        if (hasResults(&results[*i], BOOLEAN_VARIATIONS)) {
            screenText(concatBooleanVariationResults(textFn(mappings[*i].data.key).str, &results[*i]), INPUT_TEXT_POS.x, *y);
            *y += INPUT_TEXT_SPACING;
        }
    }
}

void displayIntValue(action_size* i, action_size limit, InputMap* mappings, InputResult* results, String (*textFn)(i32), u32* y) {
    for (; *i < limit; *i += FLOAT_VARIATIONS) {
        if (hasResults(&results[*i], FLOAT_VARIATIONS)) {
            screenText(concatFloatVariationResults(
                           textFn(mappings[*i].data.movement.axis).str, &results[*i], mappings[*i].data.movement.threshold, false),
                       INPUT_TEXT_POS.x,
                       *y);
            *y += INPUT_TEXT_SPACING;
        }
    }
}

void displayFloatValue(action_size* i, action_size limit, InputMap* mappings, InputResult* results, String (*textFn)(i32), u32* y) {
    for (; *i < limit; *i += FLOAT_VARIATIONS) {
        if (hasResults(&results[*i], FLOAT_VARIATIONS)) {
            screenText(
                concatFloatVariationResults(textFn(mappings[*i].data.axis.type).str, &results[*i], mappings[*i].data.axis.threshold, true),
                INPUT_TEXT_POS.x,
                *y);
            *y += INPUT_TEXT_SPACING;
        }
    }
}

void displayDeviceKM(InputMap mappings[N_ACTIONS], InputResult results[N_ACTIONS]) {
    u32 y = INPUT_TEXT_POS.y;

    action_size limit = 0, i = 0;

    limit += N_KEYBOARD_KEY_ACTIONS;
    displayBoolValue(&i, limit, mappings, results, textKeyboardKey, &y);

    limit += N_MOUSE_BUTTON_ACTIONS;
    displayBoolValue(&i, limit, mappings, results, textMouseButton, &y);

    limit += N_MOUSE_POSITION_ACTIONS;
    displayIntValue(&i, limit, mappings, results, textMousePosition, &y);

    limit += N_MOUSE_MOVEMENT_ACTIONS;
    displayIntValue(&i, limit, mappings, results, textMouseMovement, &y);

    limit += N_MOUSE_SCROLL_ACTIONS;
    displayIntValue(&i, limit, mappings, results, textMouseScroll, &y);
}

void displayDeviceGP(InputMap mappings[N_ACTIONS], InputResult results[N_ACTIONS]) {
    u32 y = INPUT_TEXT_POS.y;

    action_size limit = 0, i;

    limit += N_GAMEPAD_BUTTON_ACTIONS;
    displayBoolValue(&i, limit, mappings, results, textGamepadButton, &y);

    limit += N_GAMEPAD_TRIGGER_ACTIONS;
    displayFloatValue(&i, limit, mappings, results, textGamepadTrigger, &y);

    limit += N_GAMEPAD_TRIGGER_NORM_ACTIONS;
    displayFloatValue(&i, limit, mappings, results, textGamepadTriggerNormalized, &y);

    limit += N_GAMEPAD_JOYSTICK_ACTIONS;
    displayFloatValue(&i, limit, mappings, results, textGamepadJoystick, &y);
}

void displayGreedyInputHandler(GreedyInputHandler handler) {
    u32 x = DEVICE_NAME_POS.x, y = DEVICE_NAME_POS.y;

    if (handler.active_device >= 0) {
        screenText(TextFormat("Gamepad #%d [%s]", handler.active_device, GetGamepadName(handler.active_device)), x, y);
        displayDeviceGP(handler.gamepad_mappings, handler.results);
    } else if (handler.active_device == INPUT_DEVICE_ID_KEYBOARD_AND_MOUSE) {
        screenText("Keyboard And Mouse", x, y);
        displayDeviceKM(handler.keyboard_mouse_mappings, handler.results);
    } else {
        screenText("Unkown device", x, y);
    }
}

i32 main(void) {
    InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "Input Handler - Demo");
    SetExitKey(KEY_NULL);
    SetTargetFPS(30);

    font = LoadFont("assets/fonts/SpaceMono-Regular.ttf");
    SetTextLineSpacing(16);

    InputMap km_maps[N_ACTIONS] = {
        // Keyboard keys //

        MAP_KEYBOARD_KEY_PRESSED(KEY_NULL),
        MAP_KEYBOARD_KEY_RELEASED(KEY_NULL),
        MAP_KEYBOARD_KEY_DOWN(KEY_NULL),
        MAP_KEYBOARD_KEY_PRESSED(KEY_APOSTROPHE),
        MAP_KEYBOARD_KEY_RELEASED(KEY_APOSTROPHE),
        MAP_KEYBOARD_KEY_DOWN(KEY_APOSTROPHE),
        MAP_KEYBOARD_KEY_PRESSED(KEY_COMMA),
        MAP_KEYBOARD_KEY_RELEASED(KEY_COMMA),
        MAP_KEYBOARD_KEY_DOWN(KEY_COMMA),
        MAP_KEYBOARD_KEY_PRESSED(KEY_MINUS),
        MAP_KEYBOARD_KEY_RELEASED(KEY_MINUS),
        MAP_KEYBOARD_KEY_DOWN(KEY_MINUS),
        MAP_KEYBOARD_KEY_PRESSED(KEY_PERIOD),
        MAP_KEYBOARD_KEY_RELEASED(KEY_PERIOD),
        MAP_KEYBOARD_KEY_DOWN(KEY_PERIOD),
        MAP_KEYBOARD_KEY_PRESSED(KEY_SLASH),
        MAP_KEYBOARD_KEY_RELEASED(KEY_SLASH),
        MAP_KEYBOARD_KEY_DOWN(KEY_SLASH),
        MAP_KEYBOARD_KEY_PRESSED(KEY_ZERO),
        MAP_KEYBOARD_KEY_RELEASED(KEY_ZERO),
        MAP_KEYBOARD_KEY_DOWN(KEY_ZERO),
        MAP_KEYBOARD_KEY_PRESSED(KEY_ONE),
        MAP_KEYBOARD_KEY_RELEASED(KEY_ONE),
        MAP_KEYBOARD_KEY_DOWN(KEY_ONE),
        MAP_KEYBOARD_KEY_PRESSED(KEY_TWO),
        MAP_KEYBOARD_KEY_RELEASED(KEY_TWO),
        MAP_KEYBOARD_KEY_DOWN(KEY_TWO),
        MAP_KEYBOARD_KEY_PRESSED(KEY_THREE),
        MAP_KEYBOARD_KEY_RELEASED(KEY_THREE),
        MAP_KEYBOARD_KEY_DOWN(KEY_THREE),
        MAP_KEYBOARD_KEY_PRESSED(KEY_FOUR),
        MAP_KEYBOARD_KEY_RELEASED(KEY_FOUR),
        MAP_KEYBOARD_KEY_DOWN(KEY_FOUR),
        MAP_KEYBOARD_KEY_PRESSED(KEY_FIVE),
        MAP_KEYBOARD_KEY_RELEASED(KEY_FIVE),
        MAP_KEYBOARD_KEY_DOWN(KEY_FIVE),
        MAP_KEYBOARD_KEY_PRESSED(KEY_SIX),
        MAP_KEYBOARD_KEY_RELEASED(KEY_SIX),
        MAP_KEYBOARD_KEY_DOWN(KEY_SIX),
        MAP_KEYBOARD_KEY_PRESSED(KEY_SEVEN),
        MAP_KEYBOARD_KEY_RELEASED(KEY_SEVEN),
        MAP_KEYBOARD_KEY_DOWN(KEY_SEVEN),
        MAP_KEYBOARD_KEY_PRESSED(KEY_EIGHT),
        MAP_KEYBOARD_KEY_RELEASED(KEY_EIGHT),
        MAP_KEYBOARD_KEY_DOWN(KEY_EIGHT),
        MAP_KEYBOARD_KEY_PRESSED(KEY_NINE),
        MAP_KEYBOARD_KEY_RELEASED(KEY_NINE),
        MAP_KEYBOARD_KEY_DOWN(KEY_NINE),
        MAP_KEYBOARD_KEY_PRESSED(KEY_SEMICOLON),
        MAP_KEYBOARD_KEY_RELEASED(KEY_SEMICOLON),
        MAP_KEYBOARD_KEY_DOWN(KEY_SEMICOLON),
        MAP_KEYBOARD_KEY_PRESSED(KEY_EQUAL),
        MAP_KEYBOARD_KEY_RELEASED(KEY_EQUAL),
        MAP_KEYBOARD_KEY_DOWN(KEY_EQUAL),
        MAP_KEYBOARD_KEY_PRESSED(KEY_A),
        MAP_KEYBOARD_KEY_RELEASED(KEY_A),
        MAP_KEYBOARD_KEY_DOWN(KEY_A),
        MAP_KEYBOARD_KEY_PRESSED(KEY_B),
        MAP_KEYBOARD_KEY_RELEASED(KEY_B),
        MAP_KEYBOARD_KEY_DOWN(KEY_B),
        MAP_KEYBOARD_KEY_PRESSED(KEY_C),
        MAP_KEYBOARD_KEY_RELEASED(KEY_C),
        MAP_KEYBOARD_KEY_DOWN(KEY_C),
        MAP_KEYBOARD_KEY_PRESSED(KEY_D),
        MAP_KEYBOARD_KEY_RELEASED(KEY_D),
        MAP_KEYBOARD_KEY_DOWN(KEY_D),
        MAP_KEYBOARD_KEY_PRESSED(KEY_E),
        MAP_KEYBOARD_KEY_RELEASED(KEY_E),
        MAP_KEYBOARD_KEY_DOWN(KEY_E),
        MAP_KEYBOARD_KEY_PRESSED(KEY_F),
        MAP_KEYBOARD_KEY_RELEASED(KEY_F),
        MAP_KEYBOARD_KEY_DOWN(KEY_F),
        MAP_KEYBOARD_KEY_PRESSED(KEY_G),
        MAP_KEYBOARD_KEY_RELEASED(KEY_G),
        MAP_KEYBOARD_KEY_DOWN(KEY_G),
        MAP_KEYBOARD_KEY_PRESSED(KEY_H),
        MAP_KEYBOARD_KEY_RELEASED(KEY_H),
        MAP_KEYBOARD_KEY_DOWN(KEY_H),
        MAP_KEYBOARD_KEY_PRESSED(KEY_I),
        MAP_KEYBOARD_KEY_RELEASED(KEY_I),
        MAP_KEYBOARD_KEY_DOWN(KEY_I),
        MAP_KEYBOARD_KEY_PRESSED(KEY_J),
        MAP_KEYBOARD_KEY_RELEASED(KEY_J),
        MAP_KEYBOARD_KEY_DOWN(KEY_J),
        MAP_KEYBOARD_KEY_PRESSED(KEY_K),
        MAP_KEYBOARD_KEY_RELEASED(KEY_K),
        MAP_KEYBOARD_KEY_DOWN(KEY_K),
        MAP_KEYBOARD_KEY_PRESSED(KEY_L),
        MAP_KEYBOARD_KEY_RELEASED(KEY_L),
        MAP_KEYBOARD_KEY_DOWN(KEY_L),
        MAP_KEYBOARD_KEY_PRESSED(KEY_M),
        MAP_KEYBOARD_KEY_RELEASED(KEY_M),
        MAP_KEYBOARD_KEY_DOWN(KEY_M),
        MAP_KEYBOARD_KEY_PRESSED(KEY_N),
        MAP_KEYBOARD_KEY_RELEASED(KEY_N),
        MAP_KEYBOARD_KEY_DOWN(KEY_N),
        MAP_KEYBOARD_KEY_PRESSED(KEY_O),
        MAP_KEYBOARD_KEY_RELEASED(KEY_O),
        MAP_KEYBOARD_KEY_DOWN(KEY_O),
        MAP_KEYBOARD_KEY_PRESSED(KEY_P),
        MAP_KEYBOARD_KEY_RELEASED(KEY_P),
        MAP_KEYBOARD_KEY_DOWN(KEY_P),
        MAP_KEYBOARD_KEY_PRESSED(KEY_Q),
        MAP_KEYBOARD_KEY_RELEASED(KEY_Q),
        MAP_KEYBOARD_KEY_DOWN(KEY_Q),
        MAP_KEYBOARD_KEY_PRESSED(KEY_R),
        MAP_KEYBOARD_KEY_RELEASED(KEY_R),
        MAP_KEYBOARD_KEY_DOWN(KEY_R),
        MAP_KEYBOARD_KEY_PRESSED(KEY_S),
        MAP_KEYBOARD_KEY_RELEASED(KEY_S),
        MAP_KEYBOARD_KEY_DOWN(KEY_S),
        MAP_KEYBOARD_KEY_PRESSED(KEY_T),
        MAP_KEYBOARD_KEY_RELEASED(KEY_T),
        MAP_KEYBOARD_KEY_DOWN(KEY_T),
        MAP_KEYBOARD_KEY_PRESSED(KEY_U),
        MAP_KEYBOARD_KEY_RELEASED(KEY_U),
        MAP_KEYBOARD_KEY_DOWN(KEY_U),
        MAP_KEYBOARD_KEY_PRESSED(KEY_V),
        MAP_KEYBOARD_KEY_RELEASED(KEY_V),
        MAP_KEYBOARD_KEY_DOWN(KEY_V),
        MAP_KEYBOARD_KEY_PRESSED(KEY_W),
        MAP_KEYBOARD_KEY_RELEASED(KEY_W),
        MAP_KEYBOARD_KEY_DOWN(KEY_W),
        MAP_KEYBOARD_KEY_PRESSED(KEY_X),
        MAP_KEYBOARD_KEY_RELEASED(KEY_X),
        MAP_KEYBOARD_KEY_DOWN(KEY_X),
        MAP_KEYBOARD_KEY_PRESSED(KEY_Y),
        MAP_KEYBOARD_KEY_RELEASED(KEY_Y),
        MAP_KEYBOARD_KEY_DOWN(KEY_Y),
        MAP_KEYBOARD_KEY_PRESSED(KEY_Z),
        MAP_KEYBOARD_KEY_RELEASED(KEY_Z),
        MAP_KEYBOARD_KEY_DOWN(KEY_Z),
        MAP_KEYBOARD_KEY_PRESSED(KEY_LEFT_BRACKET),
        MAP_KEYBOARD_KEY_RELEASED(KEY_LEFT_BRACKET),
        MAP_KEYBOARD_KEY_DOWN(KEY_LEFT_BRACKET),
        MAP_KEYBOARD_KEY_PRESSED(KEY_BACKSLASH),
        MAP_KEYBOARD_KEY_RELEASED(KEY_BACKSLASH),
        MAP_KEYBOARD_KEY_DOWN(KEY_BACKSLASH),
        MAP_KEYBOARD_KEY_PRESSED(KEY_RIGHT_BRACKET),
        MAP_KEYBOARD_KEY_RELEASED(KEY_RIGHT_BRACKET),
        MAP_KEYBOARD_KEY_DOWN(KEY_RIGHT_BRACKET),
        MAP_KEYBOARD_KEY_PRESSED(KEY_GRAVE),
        MAP_KEYBOARD_KEY_RELEASED(KEY_GRAVE),
        MAP_KEYBOARD_KEY_DOWN(KEY_GRAVE),
        MAP_KEYBOARD_KEY_PRESSED(KEY_SPACE),
        MAP_KEYBOARD_KEY_RELEASED(KEY_SPACE),
        MAP_KEYBOARD_KEY_DOWN(KEY_SPACE),
        MAP_KEYBOARD_KEY_PRESSED(KEY_ESCAPE),
        MAP_KEYBOARD_KEY_RELEASED(KEY_ESCAPE),
        MAP_KEYBOARD_KEY_DOWN(KEY_ESCAPE),
        MAP_KEYBOARD_KEY_PRESSED(KEY_ENTER),
        MAP_KEYBOARD_KEY_RELEASED(KEY_ENTER),
        MAP_KEYBOARD_KEY_DOWN(KEY_ENTER),
        MAP_KEYBOARD_KEY_PRESSED(KEY_TAB),
        MAP_KEYBOARD_KEY_RELEASED(KEY_TAB),
        MAP_KEYBOARD_KEY_DOWN(KEY_TAB),
        MAP_KEYBOARD_KEY_PRESSED(KEY_BACKSPACE),
        MAP_KEYBOARD_KEY_RELEASED(KEY_BACKSPACE),
        MAP_KEYBOARD_KEY_DOWN(KEY_BACKSPACE),
        MAP_KEYBOARD_KEY_PRESSED(KEY_INSERT),
        MAP_KEYBOARD_KEY_RELEASED(KEY_INSERT),
        MAP_KEYBOARD_KEY_DOWN(KEY_INSERT),
        MAP_KEYBOARD_KEY_PRESSED(KEY_DELETE),
        MAP_KEYBOARD_KEY_RELEASED(KEY_DELETE),
        MAP_KEYBOARD_KEY_DOWN(KEY_DELETE),
        MAP_KEYBOARD_KEY_PRESSED(KEY_RIGHT),
        MAP_KEYBOARD_KEY_RELEASED(KEY_RIGHT),
        MAP_KEYBOARD_KEY_DOWN(KEY_RIGHT),
        MAP_KEYBOARD_KEY_PRESSED(KEY_LEFT),
        MAP_KEYBOARD_KEY_RELEASED(KEY_LEFT),
        MAP_KEYBOARD_KEY_DOWN(KEY_LEFT),
        MAP_KEYBOARD_KEY_PRESSED(KEY_DOWN),
        MAP_KEYBOARD_KEY_RELEASED(KEY_DOWN),
        MAP_KEYBOARD_KEY_DOWN(KEY_DOWN),
        MAP_KEYBOARD_KEY_PRESSED(KEY_UP),
        MAP_KEYBOARD_KEY_RELEASED(KEY_UP),
        MAP_KEYBOARD_KEY_DOWN(KEY_UP),
        MAP_KEYBOARD_KEY_PRESSED(KEY_PAGE_UP),
        MAP_KEYBOARD_KEY_RELEASED(KEY_PAGE_UP),
        MAP_KEYBOARD_KEY_DOWN(KEY_PAGE_UP),
        MAP_KEYBOARD_KEY_PRESSED(KEY_PAGE_DOWN),
        MAP_KEYBOARD_KEY_RELEASED(KEY_PAGE_DOWN),
        MAP_KEYBOARD_KEY_DOWN(KEY_PAGE_DOWN),
        MAP_KEYBOARD_KEY_PRESSED(KEY_HOME),
        MAP_KEYBOARD_KEY_RELEASED(KEY_HOME),
        MAP_KEYBOARD_KEY_DOWN(KEY_HOME),
        MAP_KEYBOARD_KEY_PRESSED(KEY_END),
        MAP_KEYBOARD_KEY_RELEASED(KEY_END),
        MAP_KEYBOARD_KEY_DOWN(KEY_END),
        MAP_KEYBOARD_KEY_PRESSED(KEY_CAPS_LOCK),
        MAP_KEYBOARD_KEY_RELEASED(KEY_CAPS_LOCK),
        MAP_KEYBOARD_KEY_DOWN(KEY_CAPS_LOCK),
        MAP_KEYBOARD_KEY_PRESSED(KEY_SCROLL_LOCK),
        MAP_KEYBOARD_KEY_RELEASED(KEY_SCROLL_LOCK),
        MAP_KEYBOARD_KEY_DOWN(KEY_SCROLL_LOCK),
        MAP_KEYBOARD_KEY_PRESSED(KEY_NUM_LOCK),
        MAP_KEYBOARD_KEY_RELEASED(KEY_NUM_LOCK),
        MAP_KEYBOARD_KEY_DOWN(KEY_NUM_LOCK),
        MAP_KEYBOARD_KEY_PRESSED(KEY_PRINT_SCREEN),
        MAP_KEYBOARD_KEY_RELEASED(KEY_PRINT_SCREEN),
        MAP_KEYBOARD_KEY_DOWN(KEY_PRINT_SCREEN),
        MAP_KEYBOARD_KEY_PRESSED(KEY_PAUSE),
        MAP_KEYBOARD_KEY_RELEASED(KEY_PAUSE),
        MAP_KEYBOARD_KEY_DOWN(KEY_PAUSE),
        MAP_KEYBOARD_KEY_PRESSED(KEY_F1),
        MAP_KEYBOARD_KEY_RELEASED(KEY_F1),
        MAP_KEYBOARD_KEY_DOWN(KEY_F1),
        MAP_KEYBOARD_KEY_PRESSED(KEY_F2),
        MAP_KEYBOARD_KEY_RELEASED(KEY_F2),
        MAP_KEYBOARD_KEY_DOWN(KEY_F2),
        MAP_KEYBOARD_KEY_PRESSED(KEY_F3),
        MAP_KEYBOARD_KEY_RELEASED(KEY_F3),
        MAP_KEYBOARD_KEY_DOWN(KEY_F3),
        MAP_KEYBOARD_KEY_PRESSED(KEY_F4),
        MAP_KEYBOARD_KEY_RELEASED(KEY_F4),
        MAP_KEYBOARD_KEY_DOWN(KEY_F4),
        MAP_KEYBOARD_KEY_PRESSED(KEY_F5),
        MAP_KEYBOARD_KEY_RELEASED(KEY_F5),
        MAP_KEYBOARD_KEY_DOWN(KEY_F5),
        MAP_KEYBOARD_KEY_PRESSED(KEY_F6),
        MAP_KEYBOARD_KEY_RELEASED(KEY_F6),
        MAP_KEYBOARD_KEY_DOWN(KEY_F6),
        MAP_KEYBOARD_KEY_PRESSED(KEY_F7),
        MAP_KEYBOARD_KEY_RELEASED(KEY_F7),
        MAP_KEYBOARD_KEY_DOWN(KEY_F7),
        MAP_KEYBOARD_KEY_PRESSED(KEY_F8),
        MAP_KEYBOARD_KEY_RELEASED(KEY_F8),
        MAP_KEYBOARD_KEY_DOWN(KEY_F8),
        MAP_KEYBOARD_KEY_PRESSED(KEY_F9),
        MAP_KEYBOARD_KEY_RELEASED(KEY_F9),
        MAP_KEYBOARD_KEY_DOWN(KEY_F9),
        MAP_KEYBOARD_KEY_PRESSED(KEY_F10),
        MAP_KEYBOARD_KEY_RELEASED(KEY_F10),
        MAP_KEYBOARD_KEY_DOWN(KEY_F10),
        MAP_KEYBOARD_KEY_PRESSED(KEY_F11),
        MAP_KEYBOARD_KEY_RELEASED(KEY_F11),
        MAP_KEYBOARD_KEY_DOWN(KEY_F11),
        MAP_KEYBOARD_KEY_PRESSED(KEY_F12),
        MAP_KEYBOARD_KEY_RELEASED(KEY_F12),
        MAP_KEYBOARD_KEY_DOWN(KEY_F12),
        MAP_KEYBOARD_KEY_PRESSED(KEY_LEFT_SHIFT),
        MAP_KEYBOARD_KEY_RELEASED(KEY_LEFT_SHIFT),
        MAP_KEYBOARD_KEY_DOWN(KEY_LEFT_SHIFT),
        MAP_KEYBOARD_KEY_PRESSED(KEY_LEFT_CONTROL),
        MAP_KEYBOARD_KEY_RELEASED(KEY_LEFT_CONTROL),
        MAP_KEYBOARD_KEY_DOWN(KEY_LEFT_CONTROL),
        MAP_KEYBOARD_KEY_PRESSED(KEY_LEFT_ALT),
        MAP_KEYBOARD_KEY_RELEASED(KEY_LEFT_ALT),
        MAP_KEYBOARD_KEY_DOWN(KEY_LEFT_ALT),
        MAP_KEYBOARD_KEY_PRESSED(KEY_LEFT_SUPER),
        MAP_KEYBOARD_KEY_RELEASED(KEY_LEFT_SUPER),
        MAP_KEYBOARD_KEY_DOWN(KEY_LEFT_SUPER),
        MAP_KEYBOARD_KEY_PRESSED(KEY_RIGHT_SHIFT),
        MAP_KEYBOARD_KEY_RELEASED(KEY_RIGHT_SHIFT),
        MAP_KEYBOARD_KEY_DOWN(KEY_RIGHT_SHIFT),
        MAP_KEYBOARD_KEY_PRESSED(KEY_RIGHT_CONTROL),
        MAP_KEYBOARD_KEY_RELEASED(KEY_RIGHT_CONTROL),
        MAP_KEYBOARD_KEY_DOWN(KEY_RIGHT_CONTROL),
        MAP_KEYBOARD_KEY_PRESSED(KEY_RIGHT_ALT),
        MAP_KEYBOARD_KEY_RELEASED(KEY_RIGHT_ALT),
        MAP_KEYBOARD_KEY_DOWN(KEY_RIGHT_ALT),
        MAP_KEYBOARD_KEY_PRESSED(KEY_RIGHT_SUPER),
        MAP_KEYBOARD_KEY_RELEASED(KEY_RIGHT_SUPER),
        MAP_KEYBOARD_KEY_DOWN(KEY_RIGHT_SUPER),
        MAP_KEYBOARD_KEY_PRESSED(KEY_KB_MENU),
        MAP_KEYBOARD_KEY_RELEASED(KEY_KB_MENU),
        MAP_KEYBOARD_KEY_DOWN(KEY_KB_MENU),
        MAP_KEYBOARD_KEY_PRESSED(KEY_KP_0),
        MAP_KEYBOARD_KEY_RELEASED(KEY_KP_0),
        MAP_KEYBOARD_KEY_DOWN(KEY_KP_0),
        MAP_KEYBOARD_KEY_PRESSED(KEY_KP_1),
        MAP_KEYBOARD_KEY_RELEASED(KEY_KP_1),
        MAP_KEYBOARD_KEY_DOWN(KEY_KP_1),
        MAP_KEYBOARD_KEY_PRESSED(KEY_KP_2),
        MAP_KEYBOARD_KEY_RELEASED(KEY_KP_2),
        MAP_KEYBOARD_KEY_DOWN(KEY_KP_2),
        MAP_KEYBOARD_KEY_PRESSED(KEY_KP_3),
        MAP_KEYBOARD_KEY_RELEASED(KEY_KP_3),
        MAP_KEYBOARD_KEY_DOWN(KEY_KP_3),
        MAP_KEYBOARD_KEY_PRESSED(KEY_KP_4),
        MAP_KEYBOARD_KEY_RELEASED(KEY_KP_4),
        MAP_KEYBOARD_KEY_DOWN(KEY_KP_4),
        MAP_KEYBOARD_KEY_PRESSED(KEY_KP_5),
        MAP_KEYBOARD_KEY_RELEASED(KEY_KP_5),
        MAP_KEYBOARD_KEY_DOWN(KEY_KP_5),
        MAP_KEYBOARD_KEY_PRESSED(KEY_KP_6),
        MAP_KEYBOARD_KEY_RELEASED(KEY_KP_6),
        MAP_KEYBOARD_KEY_DOWN(KEY_KP_6),
        MAP_KEYBOARD_KEY_PRESSED(KEY_KP_7),
        MAP_KEYBOARD_KEY_RELEASED(KEY_KP_7),
        MAP_KEYBOARD_KEY_DOWN(KEY_KP_7),
        MAP_KEYBOARD_KEY_PRESSED(KEY_KP_8),
        MAP_KEYBOARD_KEY_RELEASED(KEY_KP_8),
        MAP_KEYBOARD_KEY_DOWN(KEY_KP_8),
        MAP_KEYBOARD_KEY_PRESSED(KEY_KP_9),
        MAP_KEYBOARD_KEY_RELEASED(KEY_KP_9),
        MAP_KEYBOARD_KEY_DOWN(KEY_KP_9),
        MAP_KEYBOARD_KEY_PRESSED(KEY_KP_DECIMAL),
        MAP_KEYBOARD_KEY_RELEASED(KEY_KP_DECIMAL),
        MAP_KEYBOARD_KEY_DOWN(KEY_KP_DECIMAL),
        MAP_KEYBOARD_KEY_PRESSED(KEY_KP_DIVIDE),
        MAP_KEYBOARD_KEY_RELEASED(KEY_KP_DIVIDE),
        MAP_KEYBOARD_KEY_DOWN(KEY_KP_DIVIDE),
        MAP_KEYBOARD_KEY_PRESSED(KEY_KP_MULTIPLY),
        MAP_KEYBOARD_KEY_RELEASED(KEY_KP_MULTIPLY),
        MAP_KEYBOARD_KEY_DOWN(KEY_KP_MULTIPLY),
        MAP_KEYBOARD_KEY_PRESSED(KEY_KP_SUBTRACT),
        MAP_KEYBOARD_KEY_RELEASED(KEY_KP_SUBTRACT),
        MAP_KEYBOARD_KEY_DOWN(KEY_KP_SUBTRACT),
        MAP_KEYBOARD_KEY_PRESSED(KEY_KP_ADD),
        MAP_KEYBOARD_KEY_RELEASED(KEY_KP_ADD),
        MAP_KEYBOARD_KEY_DOWN(KEY_KP_ADD),
        MAP_KEYBOARD_KEY_PRESSED(KEY_KP_ENTER),
        MAP_KEYBOARD_KEY_RELEASED(KEY_KP_ENTER),
        MAP_KEYBOARD_KEY_DOWN(KEY_KP_ENTER),
        MAP_KEYBOARD_KEY_PRESSED(KEY_KP_EQUAL),
        MAP_KEYBOARD_KEY_RELEASED(KEY_KP_EQUAL),
        MAP_KEYBOARD_KEY_DOWN(KEY_KP_EQUAL),
        MAP_KEYBOARD_KEY_PRESSED(KEY_BACK),
        MAP_KEYBOARD_KEY_RELEASED(KEY_BACK),
        MAP_KEYBOARD_KEY_DOWN(KEY_BACK),
        MAP_KEYBOARD_KEY_PRESSED(KEY_MENU),
        MAP_KEYBOARD_KEY_RELEASED(KEY_MENU),
        MAP_KEYBOARD_KEY_DOWN(KEY_MENU),
        MAP_KEYBOARD_KEY_PRESSED(KEY_VOLUME_UP),
        MAP_KEYBOARD_KEY_RELEASED(KEY_VOLUME_UP),
        MAP_KEYBOARD_KEY_DOWN(KEY_VOLUME_UP),
        MAP_KEYBOARD_KEY_PRESSED(KEY_VOLUME_DOWN),
        MAP_KEYBOARD_KEY_RELEASED(KEY_VOLUME_DOWN),
        MAP_KEYBOARD_KEY_DOWN(KEY_VOLUME_DOWN),

        // Mouse buttons //

        MAP_MOUSE_BUTTON_PRESSED(MOUSE_BUTTON_LEFT),
        MAP_MOUSE_BUTTON_RELEASED(MOUSE_BUTTON_LEFT),
        MAP_MOUSE_BUTTON_DOWN(MOUSE_BUTTON_LEFT),
        MAP_MOUSE_BUTTON_PRESSED(MOUSE_BUTTON_RIGHT),
        MAP_MOUSE_BUTTON_RELEASED(MOUSE_BUTTON_RIGHT),
        MAP_MOUSE_BUTTON_DOWN(MOUSE_BUTTON_RIGHT),
        MAP_MOUSE_BUTTON_PRESSED(MOUSE_BUTTON_MIDDLE),
        MAP_MOUSE_BUTTON_RELEASED(MOUSE_BUTTON_MIDDLE),
        MAP_MOUSE_BUTTON_DOWN(MOUSE_BUTTON_MIDDLE),
        MAP_MOUSE_BUTTON_PRESSED(MOUSE_BUTTON_SIDE),
        MAP_MOUSE_BUTTON_RELEASED(MOUSE_BUTTON_SIDE),
        MAP_MOUSE_BUTTON_DOWN(MOUSE_BUTTON_SIDE),
        MAP_MOUSE_BUTTON_PRESSED(MOUSE_BUTTON_EXTRA),
        MAP_MOUSE_BUTTON_RELEASED(MOUSE_BUTTON_EXTRA),
        MAP_MOUSE_BUTTON_DOWN(MOUSE_BUTTON_EXTRA),
        MAP_MOUSE_BUTTON_PRESSED(MOUSE_BUTTON_FORWARD),
        MAP_MOUSE_BUTTON_RELEASED(MOUSE_BUTTON_FORWARD),
        MAP_MOUSE_BUTTON_DOWN(MOUSE_BUTTON_FORWARD),
        MAP_MOUSE_BUTTON_PRESSED(MOUSE_BUTTON_BACK),
        MAP_MOUSE_BUTTON_RELEASED(MOUSE_BUTTON_BACK),
        MAP_MOUSE_BUTTON_DOWN(MOUSE_BUTTON_BACK),

        // Mouse movments //

        MAP_MOUSE_POSITION_T(MOUSE_AXIS_X, MOUSE_MOVEMENT_THRESHOLD),
        MAP_MOUSE_POSITION_T(MOUSE_AXIS_Y, MOUSE_MOVEMENT_THRESHOLD),

        MAP_MOUSE_MOVEMENT_T(MOUSE_AXIS_X, MOUSE_MOVEMENT_THRESHOLD),
        MAP_MOUSE_MOVEMENT_T(MOUSE_AXIS_Y, MOUSE_MOVEMENT_THRESHOLD),

        MAP_MOUSE_SCROLL_T(MOUSE_SCROLL_WHEEL, MOUSE_SCROLL_THRESHOLD),
    };
    InputMap gp_maps[N_ACTIONS] = {
        // Gamepad buttons //

        MAP_GAMEPAD_BUTTON_PRESSED(GAMEPAD_BUTTON_UNKNOWN),
        MAP_GAMEPAD_BUTTON_RELEASED(GAMEPAD_BUTTON_UNKNOWN),
        MAP_GAMEPAD_BUTTON_DOWN(GAMEPAD_BUTTON_UNKNOWN),
        MAP_GAMEPAD_BUTTON_PRESSED(GAMEPAD_BUTTON_LEFT_FACE_UP),
        MAP_GAMEPAD_BUTTON_RELEASED(GAMEPAD_BUTTON_LEFT_FACE_UP),
        MAP_GAMEPAD_BUTTON_DOWN(GAMEPAD_BUTTON_LEFT_FACE_UP),
        MAP_GAMEPAD_BUTTON_PRESSED(GAMEPAD_BUTTON_LEFT_FACE_RIGHT),
        MAP_GAMEPAD_BUTTON_RELEASED(GAMEPAD_BUTTON_LEFT_FACE_RIGHT),
        MAP_GAMEPAD_BUTTON_DOWN(GAMEPAD_BUTTON_LEFT_FACE_RIGHT),
        MAP_GAMEPAD_BUTTON_PRESSED(GAMEPAD_BUTTON_LEFT_FACE_DOWN),
        MAP_GAMEPAD_BUTTON_RELEASED(GAMEPAD_BUTTON_LEFT_FACE_DOWN),
        MAP_GAMEPAD_BUTTON_DOWN(GAMEPAD_BUTTON_LEFT_FACE_DOWN),
        MAP_GAMEPAD_BUTTON_PRESSED(GAMEPAD_BUTTON_LEFT_FACE_LEFT),
        MAP_GAMEPAD_BUTTON_RELEASED(GAMEPAD_BUTTON_LEFT_FACE_LEFT),
        MAP_GAMEPAD_BUTTON_DOWN(GAMEPAD_BUTTON_LEFT_FACE_LEFT),
        MAP_GAMEPAD_BUTTON_PRESSED(GAMEPAD_BUTTON_RIGHT_FACE_UP),
        MAP_GAMEPAD_BUTTON_RELEASED(GAMEPAD_BUTTON_RIGHT_FACE_UP),
        MAP_GAMEPAD_BUTTON_DOWN(GAMEPAD_BUTTON_RIGHT_FACE_UP),
        MAP_GAMEPAD_BUTTON_PRESSED(GAMEPAD_BUTTON_RIGHT_FACE_RIGHT),
        MAP_GAMEPAD_BUTTON_RELEASED(GAMEPAD_BUTTON_RIGHT_FACE_RIGHT),
        MAP_GAMEPAD_BUTTON_DOWN(GAMEPAD_BUTTON_RIGHT_FACE_RIGHT),
        MAP_GAMEPAD_BUTTON_PRESSED(GAMEPAD_BUTTON_RIGHT_FACE_DOWN),
        MAP_GAMEPAD_BUTTON_RELEASED(GAMEPAD_BUTTON_RIGHT_FACE_DOWN),
        MAP_GAMEPAD_BUTTON_DOWN(GAMEPAD_BUTTON_RIGHT_FACE_DOWN),
        MAP_GAMEPAD_BUTTON_PRESSED(GAMEPAD_BUTTON_RIGHT_FACE_LEFT),
        MAP_GAMEPAD_BUTTON_RELEASED(GAMEPAD_BUTTON_RIGHT_FACE_LEFT),
        MAP_GAMEPAD_BUTTON_DOWN(GAMEPAD_BUTTON_RIGHT_FACE_LEFT),
        MAP_GAMEPAD_BUTTON_PRESSED(GAMEPAD_BUTTON_LEFT_TRIGGER_1),
        MAP_GAMEPAD_BUTTON_RELEASED(GAMEPAD_BUTTON_LEFT_TRIGGER_1),
        MAP_GAMEPAD_BUTTON_DOWN(GAMEPAD_BUTTON_LEFT_TRIGGER_1),
        MAP_GAMEPAD_BUTTON_PRESSED(GAMEPAD_BUTTON_LEFT_TRIGGER_2),
        MAP_GAMEPAD_BUTTON_RELEASED(GAMEPAD_BUTTON_LEFT_TRIGGER_2),
        MAP_GAMEPAD_BUTTON_DOWN(GAMEPAD_BUTTON_LEFT_TRIGGER_2),
        MAP_GAMEPAD_BUTTON_PRESSED(GAMEPAD_BUTTON_RIGHT_TRIGGER_1),
        MAP_GAMEPAD_BUTTON_RELEASED(GAMEPAD_BUTTON_RIGHT_TRIGGER_1),
        MAP_GAMEPAD_BUTTON_DOWN(GAMEPAD_BUTTON_RIGHT_TRIGGER_1),
        MAP_GAMEPAD_BUTTON_PRESSED(GAMEPAD_BUTTON_RIGHT_TRIGGER_2),
        MAP_GAMEPAD_BUTTON_RELEASED(GAMEPAD_BUTTON_RIGHT_TRIGGER_2),
        MAP_GAMEPAD_BUTTON_DOWN(GAMEPAD_BUTTON_RIGHT_TRIGGER_2),
        MAP_GAMEPAD_BUTTON_PRESSED(GAMEPAD_BUTTON_MIDDLE_LEFT),
        MAP_GAMEPAD_BUTTON_RELEASED(GAMEPAD_BUTTON_MIDDLE_LEFT),
        MAP_GAMEPAD_BUTTON_DOWN(GAMEPAD_BUTTON_MIDDLE_LEFT),
        MAP_GAMEPAD_BUTTON_PRESSED(GAMEPAD_BUTTON_MIDDLE),
        MAP_GAMEPAD_BUTTON_RELEASED(GAMEPAD_BUTTON_MIDDLE),
        MAP_GAMEPAD_BUTTON_DOWN(GAMEPAD_BUTTON_MIDDLE),
        MAP_GAMEPAD_BUTTON_PRESSED(GAMEPAD_BUTTON_MIDDLE_RIGHT),
        MAP_GAMEPAD_BUTTON_RELEASED(GAMEPAD_BUTTON_MIDDLE_RIGHT),
        MAP_GAMEPAD_BUTTON_DOWN(GAMEPAD_BUTTON_MIDDLE_RIGHT),
        MAP_GAMEPAD_BUTTON_PRESSED(GAMEPAD_BUTTON_LEFT_THUMB),
        MAP_GAMEPAD_BUTTON_RELEASED(GAMEPAD_BUTTON_LEFT_THUMB),
        MAP_GAMEPAD_BUTTON_DOWN(GAMEPAD_BUTTON_LEFT_THUMB),
        MAP_GAMEPAD_BUTTON_PRESSED(GAMEPAD_BUTTON_RIGHT_THUMB),
        MAP_GAMEPAD_BUTTON_RELEASED(GAMEPAD_BUTTON_RIGHT_THUMB),
        MAP_GAMEPAD_BUTTON_DOWN(GAMEPAD_BUTTON_RIGHT_THUMB),

        // Gamepad axis //

        MAP_GAMEPAD_TRIGGER_T(GAMEPAD_TRIGGER_LEFT, TRIGGER_THRESHOLD),
        MAP_GAMEPAD_TRIGGER_T(GAMEPAD_TRIGGER_RIGHT, TRIGGER_THRESHOLD),
        MAP_GAMEPAD_TRIGGER_NORM_T(GAMEPAD_TRIGGER_LEFT, TRIGGER_NORM_THRESHOLD),
        MAP_GAMEPAD_TRIGGER_NORM_T(GAMEPAD_TRIGGER_RIGHT, TRIGGER_NORM_THRESHOLD),
        MAP_GAMEPAD_JOYSTICK_T(GAMEPAD_JOYSTICK_LEFT_X, JOYSTICK_THRESHOLD),
        MAP_GAMEPAD_JOYSTICK_T(GAMEPAD_JOYSTICK_LEFT_Y, JOYSTICK_THRESHOLD),
        MAP_GAMEPAD_JOYSTICK_T(GAMEPAD_JOYSTICK_RIGHT_X, JOYSTICK_THRESHOLD),
        MAP_GAMEPAD_JOYSTICK_T(GAMEPAD_JOYSTICK_RIGHT_Y, JOYSTICK_THRESHOLD),

        // Zero'd the rest of the array //
    };

    GreedyInputHandler handler = GreedyInputHandlerCreate(N_ACTIONS);
    GreedyInputHandlerMappingsSet(&handler, km_maps, gp_maps);

    while (!WindowShouldClose()) {
        BeginDrawing();
        ClearBackground(BLACK);

        DrawFPS(SCREEN_WIDTH - FPS_PADDING_X, FPS_PADDING_Y);

        displayGreedyInputHandler(handler);

        EndDrawing();

        GreedyInputHandlerUpdate(&handler);
    }

    UnloadFont(font);

    return 0;
}