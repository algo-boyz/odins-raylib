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

# Shadow Mapping Performance & Quality Optimization Guide

## Performance Improvements

### 1. Dynamic Shadow Resolution Scaling
Instead of fixed resolution, implement adaptive quality based on performance:

```odin
// Add to ShadowConfig
ShadowConfig :: struct {
    base_resolution:     i32,
    current_resolution:  i32,
    quality_level:       f32, // 0.5 = half res, 1.0 = full res, 2.0 = double res
    auto_scale:          bool,
    target_fps:          f32,
    // ... other fields
}

// Dynamic resolution adjustment
adjust_shadow_quality :: proc(system: ^ShadowSystem, current_fps: f32) {
    if !system.config.auto_scale do return
    
    target_fps := system.config.target_fps
    quality := system.config.quality_level
    
    if current_fps < target_fps * 0.9 && quality > 0.25 {
        // Reduce quality if FPS is low
        quality -= 0.1
    } else if current_fps > target_fps * 1.1 && quality < 2.0 {
        // Increase quality if FPS is high
        quality += 0.05
    }
    
    new_resolution := i32(f32(system.config.base_resolution) * quality)
    if new_resolution != system.config.current_resolution {
        resize_shadow_map(system, new_resolution)
    }
}
```

### 2. Frustum Culling for Light Camera
Only render objects visible to the light:

```odin
// Add frustum culling data
LightFrustum :: struct {
    planes: [6]rl.Vector4, // 6 frustum planes
    bounds: rl.BoundingBox,
}

// Calculate light frustum
calculate_light_frustum :: proc(camera: rl.Camera3D, distance: f32, fov: f32) -> LightFrustum {
    frustum := LightFrustum{}
    
    // Calculate frustum bounds based on orthographic projection
    size := distance * linalg.tan(linalg.to_radians(fov * 0.5))
    
    frustum.bounds = rl.BoundingBox{
        min = camera.position + rl.Vector3{-size, -size, 0},
        max = camera.position + rl.Vector3{size, size, distance * 2},
    }
    
    return frustum
}

// Check if object should cast shadows
should_cast_shadow :: proc(frustum: LightFrustum, object_bounds: rl.BoundingBox) -> bool {
    return rl.CheckCollisionBoxes(frustum.bounds, object_bounds)
}
```

### 3. Level-of-Detail (LOD) Shadow Casting
Use simpler models for shadow casting:

```odin
ModelLOD :: struct {
    high_detail:   rl.Model,
    shadow_caster: rl.Model, // Simplified version for shadows
    bounds:        rl.BoundingBox,
}

render_with_lod_shadows :: proc(system: ^ShadowSystem, camera: rl.Camera3D, 
                               models: []ModelLOD) {
    // Phase 1: Shadow pass with LOD models
    rl.BeginTextureMode(system.shadow_map)
    rl.ClearBackground(rl.WHITE)
    rl.BeginMode3D(system.light_camera)
    
    for model in models {
        if should_cast_shadow(system.light_frustum, model.bounds) {
            // Use simplified shadow caster model
            rl.DrawModel(model.shadow_caster, {0,0,0}, 1.0, rl.WHITE)
        }
    }
    
    rl.EndMode3D()
    rl.EndTextureMode()
    
    // Phase 2: Main render with high-detail models
    rl.BeginMode3D(camera)
    for model in models {
        rl.DrawModel(model.high_detail, {0,0,0}, 1.0, rl.WHITE)
    }
    rl.EndMode3D()
}
```

### 4. Shadow Map Caching
Don't regenerate shadows every frame for static objects:

```odin
ShadowCache :: struct {
    needs_update:    bool,
    last_light_dir:  rl.Vector3,
    static_objects:  [dynamic]rl.Model,
    dynamic_objects: [dynamic]rl.Model,
}

// Only update shadows when needed
render_cached_shadows :: proc(system: ^ShadowSystem, cache: ^ShadowCache, camera: rl.Camera3D) {
    // Check if light moved significantly
    light_moved := linalg.distance(cache.last_light_dir, system.light.direction) > 0.01
    
    if cache.needs_update || light_moved {
        // Render static objects to shadow map
        rl.BeginTextureMode(system.shadow_map)
        rl.ClearBackground(rl.WHITE)
        rl.BeginMode3D(system.light_camera)
        
        for model in cache.static_objects {
            rl.DrawModel(model, {0,0,0}, 1.0, rl.WHITE)
        }
        
        rl.EndMode3D()
        rl.EndTextureMode()
        
        cache.needs_update = false
        cache.last_light_dir = system.light.direction
    }
    
    // Always render dynamic objects
    rl.BeginTextureMode(system.shadow_map)
    rl.BeginMode3D(system.light_camera)
    
    for model in cache.dynamic_objects {
        rl.DrawModel(model, {0,0,0}, 1.0, rl.WHITE)
    }
    
    rl.EndMode3D()
    rl.EndTextureMode()
}
```

## Quality Improvements

### 1. Cascade Shadow Maps (CSM)
Multiple shadow maps for different distances:

```odin
CascadeShadowSystem :: struct {
    cascades:     [4]ShadowSystem,
    distances:    [4]f32, // {5, 15, 50, 150}
    split_lambda: f32,     // 0.5 typical
}

// Calculate cascade splits
calculate_cascade_splits :: proc(near, far: f32, cascade_count: i32, lambda: f32) -> []f32 {
    splits := make([]f32, cascade_count + 1)
    splits[0] = near
    splits[cascade_count] = far
    
    for i in 1..<cascade_count {
        ratio := f32(i) / f32(cascade_count)
        
        // Logarithmic split
        log_split := near * linalg.pow(far / near, ratio)
        
        // Linear split
        linear_split := near + (far - near) * ratio
        
        // Combine using lambda
        splits[i] = linalg.lerp(linear_split, log_split, lambda)
    }
    
    return splits
}
```

### 2. Percentage Closer Filtering (PCF)
Softer shadow edges in shader:

```glsl
// In fragment shader
float shadow_pcf(sampler2D shadow_map, vec4 light_space_pos, float resolution) {
    vec3 proj_coords = light_space_pos.xyz / light_space_pos.w;
    proj_coords = proj_coords * 0.5 + 0.5;
    
    float current_depth = proj_coords.z;
    float bias = 0.005;
    
    float shadow = 0.0;
    vec2 texel_size = 1.0 / vec2(resolution);
    
    // 3x3 PCF kernel
    for(int x = -1; x <= 1; ++x) {
        for(int y = -1; y <= 1; ++y) {
            float pcf_depth = texture(shadow_map, proj_coords.xy + vec2(x, y) * texel_size).r;
            shadow += current_depth - bias > pcf_depth ? 1.0 : 0.0;
        }
    }
    
    return shadow / 9.0;
}
```

### 3. Shadow Bias Optimization
Reduce shadow acne and peter panning:

```odin
// Dynamic bias based on surface angle
BiasConfig :: struct {
    constant_bias: f32, // 0.001 - 0.01
    slope_bias:    f32, // 0.01 - 0.1
    max_bias:      f32, // 0.05
}

calculate_shadow_bias :: proc(light_dir, surface_normal: rl.Vector3, config: BiasConfig) -> f32 {
    cos_angle := linalg.dot(-light_dir, surface_normal)
    slope_factor := linalg.sqrt(1.0 - cos_angle * cos_angle) / cos_angle
    slope_bias := config.slope_bias * slope_factor
    
    return linalg.min(config.constant_bias + slope_bias, config.max_bias)
}
```

## Common Issues & Solutions

### Black Shadows/No Shadows

**Diagnostic Steps:**
```odin
debug_shadow_system :: proc(system: ^ShadowSystem) {
    fmt.printf("Shadow System Debug:\n")
    fmt.printf("- Shader ID: %d\n", system.shader.id)
    fmt.printf("- Shadow Map ID: %d\n", system.shadow_map.id)
    fmt.printf("- Light Direction: (%.3f, %.3f, %.3f)\n", 
               system.light.direction.x, system.light.direction.y, system.light.direction.z)
    fmt.printf("- Shadow Map Resolution: %dx%d\n", 
               system.config.resolution, system.config.resolution)
    
    // Check shader uniform locations
    if system.light_dir_loc == -1 do fmt.println("WARNING: lightDir uniform not found")
    if system.shadow_map_loc == -1 do fmt.println("WARNING: shadowMap uniform not found")
    if system.light_vp_loc == -1 do fmt.println("WARNING: lightVP uniform not found")
}

// Verify shadow map content
save_shadow_map_debug :: proc(system: ^ShadowSystem, filename: cstring) {
    image := rl.LoadImageFromTexture(system.shadow_map.depth)
    defer rl.UnloadImage(image)
    rl.ExportImage(image, filename)
}
```

### Performance Monitoring
```odin
PerformanceMetrics :: struct {
    shadow_render_time: f32,
    main_render_time:   f32,
    total_frame_time:   f32,
    shadow_map_updates: i32,
}

measure_shadow_performance :: proc(system: ^ShadowSystem, metrics: ^PerformanceMetrics) {
    start_time := rl.GetTime()
    
    // Shadow pass
    shadow_start := rl.GetTime()
    // ... shadow rendering ...
    metrics.shadow_render_time = f32(rl.GetTime() - shadow_start)
    
    // Main pass  
    main_start := rl.GetTime()
    // ... main rendering ...
    metrics.main_render_time = f32(rl.GetTime() - main_start)
    
    metrics.total_frame_time = f32(rl.GetTime() - start_time)
    
    // Log every second
    if i32(rl.GetTime()) % 60 == 0 {
        fmt.printf("Shadow: %.2fms, Main: %.2fms, Total: %.2fms\n",
                   metrics.shadow_render_time * 1000,
                   metrics.main_render_time * 1000, 
                   metrics.total_frame_time * 1000)
    }
}
```

## Recommended Settings by Scene Type

### Indoor Scenes
```odin
indoor_config := ShadowConfig{
    resolution     = 1024,
    light_distance = 8.0,
    light_fov      = 30.0,
    ambient        = {0.3, 0.3, 0.35, 1.0}, // Higher ambient
}
```

### Outdoor Scenes  
```odin
outdoor_config := ShadowConfig{
    resolution     = 2048,
    light_distance = 25.0,
    light_fov      = 15.0,
    ambient        = {0.1, 0.1, 0.15, 1.0}, // Lower ambient
}
```

### Mobile/Low-End
```odin
mobile_config := ShadowConfig{
    resolution     = 512,
    light_distance = 12.0,
    light_fov      = 25.0,
    ambient        = {0.25, 0.25, 0.3, 1.0}, // Higher ambient to hide quality loss
}
```

## Advanced Optimizations

### Temporal Shadow Map Jittering
Reduce aliasing by slightly jittering the light position each frame:

```odin
apply_temporal_jitter :: proc(system: ^ShadowSystem, frame_count: i32) {
    jitter_amount: f32 = 0.001
    jitter_x := linalg.sin(f32(frame_count) * 0.1) * jitter_amount
    jitter_z := linalg.cos(f32(frame_count) * 0.1) * jitter_amount
    
    jittered_pos := system.light_camera.position + rl.Vector3{jitter_x, 0, jitter_z}
    system.light_camera.position = jittered_pos
}
```

### Shadow Map Pooling
Reuse shadow maps for multiple lights:

```odin
ShadowMapPool :: struct {
    available_maps: [dynamic]rl.RenderTexture2D,
    in_use_maps:    [dynamic]rl.RenderTexture2D,
    resolution:     i32,
}

acquire_shadow_map :: proc(pool: ^ShadowMapPool) -> rl.RenderTexture2D {
    if len(pool.available_maps) > 0 {
        shadow_map := pop(&pool.available_maps)
        append(&pool.in_use_maps, shadow_map)
        return shadow_map
    }
    
    // Create new shadow map if pool is empty
    new_map := load_shadowmap_render_texture(pool.resolution, pool.resolution)
    append(&pool.in_use_maps, new_map)
    return new_map
}

release_shadow_map :: proc(pool: ^ShadowMapPool, shadow_map: rl.RenderTexture2D) {
    // Move from in_use back to available
    for i, map in pool.in_use_maps {
        if map.id == shadow_map.id {
            ordered_remove(&pool.in_use_maps, i)
            append(&pool.available_maps, map)
            break
        }
    }
}
```
