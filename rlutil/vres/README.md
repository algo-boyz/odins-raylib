# Virtual Screen Resolution Component

A reusable virtual resolution component for **Raylib** games written in **Odin**. Maintain pixel-perfect scaling across all screen sizes, resolutions, and aspect ratios while keeping your game logic simple.

- **Fixed Virtual Resolution**: Draw in a consistent coordinate space (e.g., 320x180)
- **Integer Scaling**: Crisp pixel art scaling (no blurry interpolation)
- **Automatic Letterboxing**: Black bars maintain aspect ratio
- **Fullscreen Toggle**: F1 key for seamless fullscreen/windowed switching
- **Virtual Mouse Coordinates**: Mouse input automatically mapped to virtual space
- **Window Resizing**: Handles DPI scaling and resize glitches
- **Drop-in Integration**: Minimal API - just `begin_drawing()` / `end_drawing()`

## 🚀 Quick Start

```odin
import vr "vres"

V_WIDTH  :: 320
V_HEIGHT :: 180

main :: proc() {
    // Init with your desired virtual resolution
    vres: vr.VirtualRes
    vr.init(&vres, V_WIDTH, V_HEIGHT, "My Game")
    defer vr.destroy(&vres)
    
    // Load assets
    sprite := rl.LoadTexture("sprite.png")
    defer rl.UnloadTexture(sprite)
    
    // Game loop
    for !rl.WindowShouldClose() {
        vr.update(&vres)
        
        vr.begin_drawing(&vres)
        // Draw in VIRTUAL coordinates (0,0 -> 320,180)
        rl.DrawTexture(sprite, 10, 10, rl.WHITE)
        vr.end_drawing(&vres)
        
        vr.finish_frame(&vres)
    }
}
```

## How It Works

```
┌─────────────────────────────────────┐  ← Real screen (any size)
│                │                    │
│   ┌─────────┐  │  Letterbox bars    │
│   │         │  │                    │
│   │ 320×180 │◀─┼─── Virtual canvas ───┘
│   │         │  │                    │
│   └─────────┘  │                    │
│                │                    │
└─────────────────────────────────────┘
```

1. **Draw to Virtual Canvas**: Render everything at fixed resolution (320×180)
2. **Scale & Center**: Automatically scales up with integer scaling
3. **Letterbox**: Black bars fill any unused screen space