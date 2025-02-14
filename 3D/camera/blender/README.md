<h2 align="center">
    Blender Style Camera
</h2>

<p align="center">
  <a href="main.odin">
    <img src="assets/preview.gif" alt="blender" width="960">
  </a>
</p>
This project provides a blender style camera (with both orbit and fly modes) in 3 lines of Odin

### **Supported Modes/Features**

1. Gimbal Orbit (Pan, Zoom, Orbit Rotate)
2. Free Fly Mode (WASD + QE with normal, fast, and slow mode)


## Keyboard Controls

_Free Fly Mode_

- `LSHIFT + F` to toggle free fly mode
- `WASD` to move
- `QE` to move up and down

_Gimbal Orbit Mode_

- `MIDDLE MOUSE MOVE` Orbit
- `LSHIFT + MIDDLE MOUSE` Pan
- `SCROLL WHEEL` Zoom
- `TRACK_PAD` two finger drag left/right up/down for pitch and yaw

## Usage with Raylib

Here's how you can use `BlenderCamera` with Raylib.

```odin
package main

import "core:math"

import rl "vendor:raylib"
import rlgl "vendor:raylib/rlgl"


main :: proc() {
    screenWidth :: 800
    screenHeight :: 450

    rl.InitWindow(screenWidth, screenHeight, "Blender Camera")

    // Initialize the camera (Line 1 of 2!)
    bcam := camera_init()

    // VSYNC and Hide Cursor
    rl.SetTargetFPS(60)
    rl.DisableCursor()

    // Define the cube position
     cubePosition := rl.Vector3{0, 0, 0}

    while (!WindowShouldClose())
    {
        // Update the camera (Line 2 of 3)
        rl.BlenderCameraUpdate(&bcam)

        rl.BeginDrawing()
            rl.ClearBackground(BLENDER_DARK_GREY)

            // Use the camera in 3D mode (Line 3 of 3!)
            rl.BeginMode3D(bcam.camera)

                rl.DrawCube(cubePosition, 2.0f, 2.0f, 2.0f, BLENDER_GREY)
                rl.DrawCubeWires(cubePosition, 2.0f, 2.0f, 2.0f, ORANGE)

                rl.DrawGridEx(20, 1.0f)

            rl.EndMode3D()

            if (bcam.freeFly)
            {
                rl.DrawText("Blender Camera Mode: FREE_FLY", 10, 10, 20, BLENDER_GREY)
            }
            else
            {
                rl.DrawText("Blender Camera Mode: GIMBAL_ORBIT", 10, 10, 20, BLENDER_GREY)
            }


            rl.DrawFPS(10, screenHeight - 30)

        rl.EndDrawing()
    }

    rl.CloseWindow()
}

```

## Camera Options

Here are the default settings from `camera_init()` which you can modify on the instatiated struct.

```odin
    bcamera := BlenderCamera{
        camera = rl.Camera{
            position = {10.0, 10.0, 10.0},
            target = {0.0, 0.0, 0.0},
            up = {0.0, 1.0, 0.0},
            fovy = 45.0,
            projection = rl.CameraProjection.PERSPECTIVE,
        },
        previous_mouse_position = {0, 0},
        is_mouse_dragging = false,
        move_speed = 0.2,
        move_speed_fast = 0.4,
        move_speed_slow = 0.1,
        free_fly_rotation_speed = 0.001,
        free_fly = true,
        rotation_speed = 0.005,  // Reduced for smoother trackpad control
        pan_speed = 0.005,      // Reduced for smoother trackpad control
        zoom_speed = 0.2,       // Adjusted for trackpad zoom
        min_pitch = -89.5 * math.PI / 180.0,  // Just shy of -90 degrees
        max_pitch = 89.5 * math.PI / 180.0,   // Just shy of 90 degrees
        current_pitch = 0.0,
    }
```

Like so:

```c
bcam = blender.camera_init()
bcam.camera.fovy = 70
```

## Todo ૮( OᴗO)っ Contributions welcome

- [ ] Orthographic Support
- [ ] Track object