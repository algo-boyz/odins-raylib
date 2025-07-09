# Shadowmapping Package for Raylib + Odin

A plug-and-play shadowmapping utility package that makes it easy to add realistic shadows to your 3D scenes using Raylib and Odin.

## Features

- **Easy Integration**: Simple API that handles all the complexity of shadow mapping
- **Configurable**: Customizable shadow resolution, light parameters, and rendering settings
- **Performance Optimized**: Cached shader locations and efficient rendering pipeline
- **Multiple Light Types**: Support for directional lights with orthographic projection
- **Memory Safe**: Proper resource management with clear initialization/cleanup
- **Debug Friendly**: Built-in logging and error handling

## Quick Start

### 1. Basic Usage

```odin
import sm "./shadowmap"

// Initialize shadow system
shadow_system, ok := sm.init_shadow_system("shadow.vs", "shadow.fs")
if !ok {
    // Handle error
    return
}
defer sm.destroy_shadow_system(&shadow_system)

// Apply shadow shader to your models
sm.apply_shadow_shader(&shadow_system, &your_model)

// In your render loop:
sm.render_with_shadows(&shadow_system, camera, draw_scene_proc, &scene_data)
```

### 2. Scene Rendering Callback

Create a procedure that draws your scene:

```odin
draw_scene :: proc(user_data: rawptr) {
    scene := cast(^YourSceneData)user_data
    
    // Draw your models here
    rl.DrawModelEx(scene.ground, {0, 0, 0}, {0, 1, 0}, 0.0, {10, 1, 10}, rl.BLUE)
    rl.DrawModelEx(scene.object, {0, 1, 0}, {0, 1, 0}, 0.0, {1, 1, 1}, rl.WHITE)
}
```

## API Reference

### Core Types

#### `ShadowConfig`
Configuration structure for shadow system settings:

```odin
ShadowConfig :: struct {
    resolution:     i32,    // Shadow map resolution (default: 1024)
    light_distance: f32,    // Distance of light from origin (default: 15.0)
    light_fov:      f32,    // Light camera field of view (default: 20.0)
    ambient:        [4]f32, // Ambient light color (default: {0.1, 0.1, 0.1, 1.0})
    texture_slot:   i32,    // Texture slot for shadow map (default: 10)
}
```

#### `DirectionalLight`
Light configuration:

```odin
DirectionalLight :: struct {
    direction: rl.Vector3,  // Light direction (normalized)
    color:     rl.Color,    // Light color
}
```

#### `ShadowSystem`
Main shadow system structure (opaque - use provided procedures to interact with it).

### Core Procedures

#### Initialization

```odin
// Initialize with default settings
init_shadow_system :: proc(vertex_shader_path, fragment_shader_path: cstring) -> (ShadowSystem, bool)

// Initialize with custom configuration
init_shadow_system_with_config :: proc(vertex_shader_path, fragment_shader_path: cstring, 
                                      config: ShadowConfig, light: DirectionalLight) -> (ShadowSystem, bool)

// Clean up resources
destroy_shadow_system :: proc(system: ^ShadowSystem)
```

#### Model Management

```odin
// Apply shadow shader to a model
apply_shadow_shader :: proc(system: ^ShadowSystem, model: ^rl.Model)
```

#### Rendering

```odin
// Render scene with shadows
render_with_shadows :: proc(system: ^ShadowSystem, camera: rl.Camera3D, 
                           scene_render_proc: SceneRenderProc, user_data: rawptr = nil)
```

#### Light Control

```odin
// Update light direction
update_light :: proc(system: ^ShadowSystem, new_direction: rl.Vector3)

// Update light color
update_light_color :: proc(system: ^ShadowSystem, new_color: rl.Color)

// Smooth light direction interpolation
interpolate_light_direction :: proc(system: ^ShadowSystem, target_direction: rl.Vector3, speed: f32, dt: f32)

// Get current light direction
get_light_direction :: proc(system: ^ShadowSystem) -> rl.Vector3
```

#### Debug Utilities

```odin
// Get shadow map texture for debugging
get_shadow_map_texture :: proc(system: ^ShadowSystem) -> rl.Texture2D
```

## Advanced Usage

### Custom Configuration Example

```odin
// High-quality shadows with custom lighting
custom_config := sm.ShadowConfig{
    resolution     = 2048,                    // Higher resolution
    light_distance = 25.0,                    // Further light
    light_fov      = 15.0,                    // Tighter cone
    ambient        = {0.15, 0.15, 0.2, 1.0}, // Cooler ambient
    texture_slot   = 5,                       // Different slot
}

warm_light := sm.DirectionalLight{
    direction = rl.Vector3Normalize({0.3, -0.7, 0.5}),
    color     = rl.Color{255, 240, 200, 255}, // Warm white
}

shadow_system, ok := sm.init_shadow_system_with_config(
    "shadow.vs", "shadow.fs", custom_config, warm_light
)
```

### Dynamic Light Control

```odin
// Smooth light movement
target_direction := calculate_sun_position(time_of_day)
sm.interpolate_light_direction(&shadow_system, target_direction, 2.0, dt)

// Instant light changes
if player_toggled_flashlight {
    new_direction := get_player_forward_vector()
    sm.update_light(&shadow_system, new_direction)
    sm.update_light_color(&shadow_system, rl.YELLOW)
}
```

## Shader Requirements

Your vertex and fragment shaders need specific uniforms and attributes. Here's what the package expects:

### Vertex Shader Uniforms
- `mat4 matModel` - Model matrix
- `mat4 matView` - View matrix  
- `mat4 matProjection` - Projection matrix
- `mat4 lightVP` - Light view-projection matrix

### Fragment Shader Uniforms
- `vec3 lightDir` - Light direction
- `vec4 lightColor` - Light color
- `vec4 ambient` - Ambient light
- `vec3 viewPos` - Camera position
- `sampler2D shadowMap` - Shadow map texture
- `int shadowMapResolution` - Shadow map resolution

## Performance Improvements

1. **Shadow Resolution**: Start with 1024x1024, increase to 2048x2048 only if needed
2. **Light Distance**: Adjust based on your scene size - closer lights = better shadow quality
3. **Batch Models**: Apply the same shadow shader to multiple models to reduce state changes

## Common Issues

### Black Shadows/No Shadows
- Check that your shader files are loading correctly
- Ensure models have the shadow shader applied
- Verify light direction is normalized

### Low Shadow Quality
- Increase shadow map resolution
- Adjust light distance and FOV
- Check that your scene fits within the light's view frustum

### Performance Issues
- Lower shadow map resolution
- Use fewer texture slots
- Profile your scene rendering callback

## File Structure

```
root/
├── shadow/
│   └── shadow.odin
├── assets/
│   ├── shadow.vs
│   └── shadow.fs
└── main.odin
```
