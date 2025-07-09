#ifndef CORE_H
#define CORE_H

#include "rayconfig.h"
#include "raylib.h"
#include "raymath.h"

typedef struct {
    int x;
    int y;
} Point;

typedef struct {
    unsigned int width;
    unsigned int height;
} Size;

// Core global state context data
typedef struct CoreData {
    struct {
        const char *title;      // Window text title const pointer
        unsigned int flags;     // Configuration flags (bit based), keeps window state
        bool ready;             // Check if window has been initialized successfully
        bool fullscreen;        // Check if fullscreen mode is enabled
        bool shouldClose;       // Check if window set for closing
        bool resizedLastFrame;  // Check if window has been resized last frame
        bool eventWaiting;      // Wait for events before ending frame
        bool usingFbo;          // Using FBO (RenderTexture) for rendering instead of default framebuffer

        Point position;          // Window position (required on fullscreen toggle)
        Point previousPosition;  // Window previous position (required on borderless windowed toggle)
        Size display;            // Display width and height (monitor, device-screen, LCD, ...)
        Size screen;             // Screen width and height (used render area)
        Size previousScreen;     // Screen previous width and height (required on borderless windowed toggle)
        Size currentFbo;         // Current render width and height (depends on active fbo)
        Size render;             // Framebuffer width and height (render area, including black bars if required)
        Point renderOffset;      // Offset from render area (must be divided by 2)
        Size screenMin;          // Screen minimum width and height (for resizable window)
        Size screenMax;          // Screen maximum width and height (for resizable window)
        Matrix screenScale;      // Matrix to scale screen (framebuffer rendering)

        char **dropFilepaths;        // Store dropped files paths pointers (provided by GLFW)
        unsigned int dropFileCount;  // Count dropped files strings

    } Window;
    struct {
        const char *basePath;  // Base path for data storage

    } Storage;
    struct {
        struct {
            int exitKey;                               // Default exit key
            char currentKeyState[MAX_KEYBOARD_KEYS];   // Registers current frame key state
            char previousKeyState[MAX_KEYBOARD_KEYS];  // Registers previous frame key state

            // NOTE: Since key press logic involves comparing prev vs cur key state, we need to handle key repeats specially
            char keyRepeatInFrame[MAX_KEYBOARD_KEYS];  // Registers key repeats for current frame

            int keyPressedQueue[MAX_KEY_PRESSED_QUEUE];  // Input keys queue
            int keyPressedQueueCount;                    // Input keys queue count

            int charPressedQueue[MAX_CHAR_PRESSED_QUEUE];  // Input characters queue (unicode)
            int charPressedQueueCount;                     // Input characters queue count

        } Keyboard;
        struct {
            Vector2 offset;            // Mouse offset
            Vector2 scale;             // Mouse scaling
            Vector2 currentPosition;   // Mouse position on screen
            Vector2 previousPosition;  // Previous mouse position

            int cursor;           // Tracks current mouse cursor
            bool cursorHidden;    // Track if cursor is hidden
            bool cursorOnScreen;  // Tracks if cursor is inside client area

            char currentButtonState[MAX_MOUSE_BUTTONS];   // Registers current mouse button state
            char previousButtonState[MAX_MOUSE_BUTTONS];  // Registers previous mouse button state
            Vector2 currentWheelMove;                     // Registers current mouse wheel variation
            Vector2 previousWheelMove;                    // Registers previous mouse wheel variation

        } Mouse;
        struct {
            int pointCount;                             // Number of touch points active
            int pointId[MAX_TOUCH_POINTS];              // Point identifiers
            Vector2 position[MAX_TOUCH_POINTS];         // Touch position on screen
            char currentTouchState[MAX_TOUCH_POINTS];   // Registers current touch state
            char previousTouchState[MAX_TOUCH_POINTS];  // Registers previous touch state

        } Touch;
        struct {
            int lastButtonPressed;                                        // Register last gamepad button pressed
            int axisCount[MAX_GAMEPADS];                                  // Register number of available gamepad axis
            bool ready[MAX_GAMEPADS];                                     // Flag to know if gamepad is ready
            char name[MAX_GAMEPADS][64];                                  // Gamepad name holder
            char currentButtonState[MAX_GAMEPADS][MAX_GAMEPAD_BUTTONS];   // Current gamepad buttons state
            char previousButtonState[MAX_GAMEPADS][MAX_GAMEPAD_BUTTONS];  // Previous gamepad buttons state
            float axisState[MAX_GAMEPADS][MAX_GAMEPAD_AXIS];              // Gamepad axis state

        } Gamepad;
    } Input;
    struct {
        double current;               // Current time measure
        double previous;              // Previous time measure
        double update;                // Time measure for frame update
        double draw;                  // Time measure for frame draw
        double frame;                 // Time measure for one frame
        double target;                // Desired time for one frame, if 0 not applied
        unsigned long long int base;  // Base time measure for hi-res timer (PLATFORM_ANDROID, PLATFORM_DRM)
        unsigned int frameCounter;    // Frame counter

    } Time;
} CoreData;

extern CoreData CORE;

#endif  // CORE_H
