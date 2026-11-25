# **Isometric Camera**

A lightweight isometric camera controller for Raylib, written in Odin. Provides an orthographic camera with configurable viewing angles, smooth target follow, zooming, and mouse-driven panning.

Designed for isometric games where you need a consistent view of the world without perspective distortion, particularly RTS, tactical, and strategy games.

## **Features**

- **Orthographic projection** — consistent scale across the scene, no perspective distortion.
- **Isometric viewing angle** — default azimuth of 45° and elevation of 38°.
- **Zoom** — mouse wheel zoom with configurable minimum and maximum view height.
- **Pan** — Shift + Left Mouse drag to move the camera across the world.
- **Smooth following** — exponentially smoothed camera tracking of a target.
- **Configurable camera** — adjustable viewing angles, zoom limits, pan speed, and follow speed.
- **Raylib native integration** — uses `Camera3D` and standard Raylib input handling.

## **Controls**

| Input                   | Action                                |
| ----------------------- | ------------------------------------- |
| Mouse wheel             | Zoom in / out                         |
| Shift + Left Mouse drag | Pan camera                            |
| `camera_follow()`       | Smoothly follow a target when enabled |

## **Usage**

### **Initialize**

Create the camera with an optional target position and view height.

```
camera := isometric.camera_init()

// Or specify a starting target and zoom
camera = isometric.camera_init(
    target = {0, 0, 0},
    view_height = 32.0,
)
```

### **Update**

Call the camera update function once per frame, passing the frame delta time.

```
isometric.camera_update(&camera, dt)
```

### **Follow a target**

Enable camera following and update its target position each frame. The camera smoothly interpolates toward the target using exponential smoothing.

```
camera.follows = true

isometric.camera_follow(&camera, player_position, dt)
```

### **Render**

Pass the underlying Raylib camera into your 3D drawing context.

```
rl.BeginMode3D(camera.camera)

// Draw world here

rl.EndMode3D()
```

## **Configuration**

| Parameter         | Default | Description                           |
| ----------------- | ------- | ------------------------------------- |
| `azimuth`         | `45°`   | Horizontal rotation around the target |
| `elevation`       | `38°`   | Vertical viewing angle                |
| `view_height`     | `32.0`  | Orthographic camera view scale        |
| `min_view_height` | `10.0`  | Minimum zoom level                    |
| `max_view_height` | `70.0`  | Maximum zoom level                    |
| `follow_speed`    | `8.0`   | Smooth-follow response speed          |
| `pan_speed`       | `1.0`   | Pan sensitivity setting               |
| `follows`         | `false` | Enables target following              |

## **API**

| Function                             | Description                                      |
| ------------------------------------ | ------------------------------------------------ |
| `camera_init(target, view_height)`   | Initializes the isometric camera                 |
| `camera_rebuild(&camera)`            | Recalculates camera position and orientation     |
| `camera_follow(&camera, target, dt)` | Smoothly tracks a target if following is enabled |
| `camera_update(&camera, dt)`         | Processes zoom and pan input                     |

## **Design**

The camera uses spherical positioning around its target, derived from azimuth and elevation angles. Its distance is calculated from the view height to maintain a stable viewing configuration.

Zoom is implemented by adjusting the orthographic field of view (`fovy`), while panning translates the target along the camera-relative horizontal axes.

Follow movement uses exponential interpolation:

\\[ \alpha = 1 - e^{-k \Delta t} \\]

For smooth, frame-rate-independent camera motion.