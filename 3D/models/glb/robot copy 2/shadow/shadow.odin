package shadow

import "core:math/linalg"
import rl "vendor:raylib"
import "vendor:raylib/rlgl"
import "core:fmt"
import "core:slice"
import "core:time"

// Configuration constants
DEFAULT_SHADOWMAP_RESOLUTION :: 1024
DEFAULT_LIGHT_DISTANCE :: 15.0
DEFAULT_LIGHT_FOV :: 20.0
DEFAULT_AMBIENT :: [4]f32{0.1, 0.1, 0.1, 1.0}

// Performance and quality enhancements
ShadowConfig :: struct {
    // Basic settings
    base_resolution:     i32,
    current_resolution:  i32,
    light_distance:      f32,
    light_fov:           f32,
    ambient:             [4]f32,
    texture_slot:        i32,
    
    // Performance settings
    quality_level:       f32,  // 0.25 to 2.0
    auto_scale:          bool,
    target_fps:          f32,
    enable_frustum_cull: bool,
    enable_lod_shadows:  bool,
    
    // Quality settings
    enable_pcf:          bool,
    pcf_samples:         i32,  // 4, 9, 16
    shadow_bias:         f32,
    slope_bias:          f32,
    max_bias:            f32,
    
    // Temporal settings
    enable_jitter:       bool,
    jitter_amount:       f32,
}

// Enhanced light with frustum culling
DirectionalLight :: struct {
    direction: rl.Vector3,
    color:     rl.Color,
    frustum:   LightFrustum,
}

// Light frustum for culling
LightFrustum :: struct {
    bounds: rl.BoundingBox,
    center: rl.Vector3,
    size:   f32,
}

// Performance metrics
PerformanceMetrics :: struct {
    shadow_render_time:   f32,
    main_render_time:     f32,
    total_frame_time:     f32,
    objects_culled:       i32,
    objects_rendered:     i32,
    last_fps:             f32,
    frame_count:          i32,
}

// Shadow cache for static objects
ShadowCache :: struct {
    needs_update:        bool,
    last_light_dir:      rl.Vector3,
    last_light_distance: f32,
    update_threshold:    f32, // How much light must move to trigger update
}

// LOD model for performance
ModelLOD :: struct {
    high_detail:   rl.Model,
    shadow_caster: rl.Model, // Simplified for shadows
    bounds:        rl.BoundingBox,
    position:      rl.Vector3,
    scale:         rl.Vector3,
    is_static:     bool,
}

// Enhanced shadow system
ShadowSystem :: struct {
    config:          ShadowConfig,
    light:           DirectionalLight,
    shader:          rl.Shader,
    shadow_map:      rl.RenderTexture2D,
    light_camera:    rl.Camera3D,
    
    // Shader locations
    light_dir_loc:   i32,
    light_col_loc:   i32,
    ambient_loc:     i32,
    light_vp_loc:    i32,
    shadow_map_loc:  i32,
    view_pos_loc:    i32,
    bias_loc:        i32,
    pcf_samples_loc: i32,
    
    // Performance tracking
    metrics:         PerformanceMetrics,
    cache:           ShadowCache,
    
    // Temporal jitter
    jitter_offset:   rl.Vector3,
}

// Render callback with LOD support
SceneRenderProc :: proc(user_data: rawptr, shadow_pass: bool)

// Initialize with default optimized settings
init_shadow_system :: proc(vertex_shader_path, fragment_shader_path: cstring) -> (ShadowSystem, bool) {
    config := ShadowConfig{
        base_resolution     = DEFAULT_SHADOWMAP_RESOLUTION,
        current_resolution  = DEFAULT_SHADOWMAP_RESOLUTION,
        light_distance      = DEFAULT_LIGHT_DISTANCE,
        light_fov           = DEFAULT_LIGHT_FOV,
        ambient             = DEFAULT_AMBIENT,
        texture_slot        = 10,
        
        // Performance defaults
        quality_level       = 1.0,
        auto_scale          = true,
        target_fps          = 60.0,
        enable_frustum_cull = true,
        enable_lod_shadows  = true,
        
        // Quality defaults
        enable_pcf          = true,
        pcf_samples         = 9,
        shadow_bias         = 0.002,
        slope_bias          = 0.05,
        max_bias            = 0.01,
        
        // Temporal defaults
        enable_jitter       = true,
        jitter_amount       = 0.0005,
    }
    
    light := DirectionalLight{
        direction = rl.Vector3Normalize({0.35, -1.0, -0.35}),
        color     = rl.WHITE,
    }
    
    return init_shadow_system_with_config(vertex_shader_path, fragment_shader_path, config, light)
}

// Initialize with custom configuration
init_shadow_system_with_config :: proc(vertex_shader_path, fragment_shader_path: cstring, 
                                      config: ShadowConfig, light: DirectionalLight) -> (ShadowSystem, bool) {
    system := ShadowSystem{}
    system.config = config
    system.light = light
    
    // Initialize cache
    system.cache.update_threshold = 0.01
    system.cache.needs_update = true
    
    // Load shader
    system.shader = rl.LoadShader(vertex_shader_path, fragment_shader_path)
    if system.shader.id == 0 {
        rl.TraceLog(rl.TraceLogLevel.ERROR, "SHADOWMAP: Failed to load shadow shader")
        return system, false
    }
    
    // Cache shader locations
    system.light_dir_loc = rl.GetShaderLocation(system.shader, "lightDir")
    system.light_col_loc = rl.GetShaderLocation(system.shader, "lightColor")
    system.ambient_loc = rl.GetShaderLocation(system.shader, "ambient")
    system.light_vp_loc = rl.GetShaderLocation(system.shader, "lightVP")
    system.shadow_map_loc = rl.GetShaderLocation(system.shader, "shadowMap")
    system.view_pos_loc = rl.GetShaderLocation(system.shader, "viewPos")
    system.bias_loc = rl.GetShaderLocation(system.shader, "shadowBias")
    system.pcf_samples_loc = rl.GetShaderLocation(system.shader, "pcfSamples")
    
    // Set up shader uniforms
    system.shader.locs[rl.ShaderLocationIndex.VECTOR_VIEW] = system.view_pos_loc
    system.shader.locs[rl.ShaderLocationIndex.MATRIX_MODEL] = rl.GetShaderLocation(system.shader, "matModel")
    
    // Initialize shader values
    light_color_normalized := rl.ColorNormalize(system.light.color)
    rl.SetShaderValue(system.shader, system.light_dir_loc, &system.light.direction, .VEC3)
    rl.SetShaderValue(system.shader, system.light_col_loc, &light_color_normalized, .VEC4)
    rl.SetShaderValue(system.shader, system.ambient_loc, &system.config.ambient, .VEC4)
    rl.SetShaderValue(system.shader, system.bias_loc, &system.config.shadow_bias, .FLOAT)
    rl.SetShaderValue(system.shader, system.pcf_samples_loc, &system.config.pcf_samples, .INT)
    
    // Create shadow map
    system.shadow_map = load_shadowmap_render_texture(system.config.current_resolution, system.config.current_resolution)
    if system.shadow_map.id == 0 {
        rl.TraceLog(rl.TraceLogLevel.ERROR, "SHADOWMAP: Failed to create shadow map")
        rl.UnloadShader(system.shader)
        return system, false
    }
    
    // Set up light camera
    system.light_camera = rl.Camera3D{
        position = system.light.direction * -system.config.light_distance,
        target = {0, 0, 0},
        up = {0, 1, 0},
        fovy = system.config.light_fov,
        projection = .ORTHOGRAPHIC,
    }
    
    // Calculate initial light frustum
    update_light_frustum(&system)
    
    rl.TraceLog(rl.TraceLogLevel.INFO, "SHADOWMAP: Enhanced shadow system initialized")
    return system, true
}

// Update system performance and quality
update_shadow_system :: proc(system: ^ShadowSystem, dt: f32) {
    system.metrics.frame_count += 1
    current_fps := 1.0 / dt
    system.metrics.last_fps = current_fps
    
    // Auto-scale quality based on performance
    if system.config.auto_scale {
        adjust_shadow_quality(system, current_fps)
    }
    
    // Apply temporal jitter
    if system.config.enable_jitter {
        apply_temporal_jitter(system, system.metrics.frame_count)
    }
    
    // Log performance metrics every second
    if system.metrics.frame_count % 60 == 0 {
        fmt.printf("Shadow Performance: %.1f FPS, Shadow: %.2fms, Main: %.2fms, Culled: %d/%d\n",
                   current_fps,
                   system.metrics.shadow_render_time * 1000,
                   system.metrics.main_render_time * 1000,
                   system.metrics.objects_culled,
                   system.metrics.objects_rendered)
    }
}

// Dynamic quality adjustment
adjust_shadow_quality :: proc(system: ^ShadowSystem, current_fps: f32) {
    target_fps := system.config.target_fps
    quality := system.config.quality_level
    
    if current_fps < target_fps * 0.85 && quality > 0.25 {
        // Reduce quality if FPS is too low
        quality -= 0.05
        system.config.quality_level = linalg.max(quality, 0.25)
        
        new_resolution := i32(f32(system.config.base_resolution) * system.config.quality_level)
        if new_resolution != system.config.current_resolution {
            resize_shadow_map(system, new_resolution)
        }
    } else if current_fps > target_fps * 1.1 && quality < 2.0 {
        // Increase quality if FPS is high
        quality += 0.02
        system.config.quality_level = linalg.min(quality, 2.0)
        
        new_resolution := i32(f32(system.config.base_resolution) * system.config.quality_level)
        if new_resolution != system.config.current_resolution {
            resize_shadow_map(system, new_resolution)
        }
    }
}

// Resize shadow map
resize_shadow_map :: proc(system: ^ShadowSystem, new_resolution: i32) {
    if new_resolution == system.config.current_resolution do return
    
    // Unload old shadow map
    unload_shadowmap_render_texture(system.shadow_map)
    
    // Create new shadow map
    system.shadow_map = load_shadowmap_render_texture(new_resolution, new_resolution)
    system.config.current_resolution = new_resolution
    
    // Update shader resolution uniform
    rl.SetShaderValue(system.shader, rl.GetShaderLocation(system.shader, "shadowMapResolution"), rawptr(uintptr(new_resolution)), .INT)
    
    rl.TraceLog(rl.TraceLogLevel.INFO, "SHADOWMAP: Resized to %dx%d", new_resolution, new_resolution)
}

// Apply temporal jitter for better quality
apply_temporal_jitter :: proc(system: ^ShadowSystem, frame_count: i32) {
    jitter_x := linalg.sin(f32(frame_count) * 0.1) * system.config.jitter_amount
    jitter_z := linalg.cos(f32(frame_count) * 0.1) * system.config.jitter_amount
    
    system.jitter_offset = rl.Vector3{jitter_x, 0, jitter_z}
    system.light_camera.position = system.light.direction * -system.config.light_distance + system.jitter_offset
}

// Update light and frustum
update_light :: proc(system: ^ShadowSystem, new_direction: rl.Vector3) {
    old_direction := system.light.direction
    system.light.direction = rl.Vector3Normalize(new_direction)
    
    // Check if light moved significantly
    if linalg.distance(old_direction, system.light.direction) > system.cache.update_threshold {
        system.cache.needs_update = true
        system.cache.last_light_dir = system.light.direction
    }
    
    system.light_camera.position = system.light.direction * -system.config.light_distance
    update_light_frustum(system)
    rl.SetShaderValue(system.shader, system.light_dir_loc, &system.light.direction, .VEC3)
}

// Update light frustum for culling
update_light_frustum :: proc(system: ^ShadowSystem) {
    size := system.config.light_distance * linalg.tan(linalg.to_radians(system.config.light_fov * 0.5))
    
    system.light.frustum.center = system.light_camera.target
    system.light.frustum.size = size
    system.light.frustum.bounds = rl.BoundingBox{
        min = system.light.frustum.center - rl.Vector3{size, size, size},
        max = system.light.frustum.center + rl.Vector3{size, size, size},
    }
}

// Check if object should cast shadows (frustum culling)
should_cast_shadow :: proc(system: ^ShadowSystem, object_bounds: rl.BoundingBox) -> bool {
    if !system.config.enable_frustum_cull do return true
    return rl.CheckCollisionBoxes(system.light.frustum.bounds, object_bounds)
}

// Enhanced render with LOD and caching
render_with_shadows_lod :: proc(system: ^ShadowSystem, camera: rl.Camera3D, 
                               models: []ModelLOD, user_data: rawptr = nil) {
    start_time := time.now()
    
    // Update view position
    camera_pos := camera.position
    rl.SetShaderValue(system.shader, system.view_pos_loc, &camera_pos, .VEC3)
    
    // Reset metrics
    system.metrics.objects_culled = 0
    system.metrics.objects_rendered = 0
    
    // Phase 1: Shadow pass with LOD and culling
    shadow_start := time.now()
    
    rl.BeginTextureMode(system.shadow_map)
    rl.ClearBackground(rl.WHITE)
    rl.BeginMode3D(system.light_camera)
    
    for model in models {
        if should_cast_shadow(system, model.bounds) {
            // Use LOD shadow caster if available
            shadow_model := model.shadow_caster if system.config.enable_lod_shadows && model.shadow_caster.meshCount > 0 else model.high_detail
            
            rl.DrawModelEx(shadow_model, model.position, {0, 1, 0}, 0.0, model.scale, rl.WHITE)
            system.metrics.objects_rendered += 1
        } else {
            system.metrics.objects_culled += 1
        }
    }
    
    rl.EndMode3D()
    rl.EndTextureMode()
    
    shadow_end := time.now()
    system.metrics.shadow_render_time = f32(time.duration_seconds(time.diff(shadow_start, shadow_end)))
    
    // Phase 2: Main render with high detail models
    main_start := time.now()
    
    // Calculate and set light matrix
    light_view := rlgl.GetMatrixModelview()
    light_proj := rlgl.GetMatrixProjection()
    light_proj_view := light_proj * light_view
    rl.SetShaderValueMatrix(system.shader, system.light_vp_loc, light_proj_view)
    
    // Bind shadow map texture
    rlgl.EnableShader(system.shader.id)
    rlgl.ActiveTextureSlot(system.config.texture_slot)
    rlgl.EnableTexture(system.shadow_map.depth.id)
    rlgl.SetUniform(system.shadow_map_loc, &system.config.texture_slot, i32(rl.ShaderUniformDataType.INT), 1)
    
    rl.BeginMode3D(camera)
    
    for model in models {
        rl.DrawModelEx(model.high_detail, model.position, {0, 1, 0}, 0.0, model.scale, rl.WHITE)
    }
    
    rl.EndMode3D()
    
    main_end := time.now()
    system.metrics.main_render_time = f32(time.duration_seconds(time.diff(main_start, main_end)))
    
    end_time := time.now()
    system.metrics.total_frame_time = f32(time.duration_seconds(time.diff(start_time, end_time)))
}

// Backwards compatibility with original render function
render_with_shadows :: proc(system: ^ShadowSystem, camera: rl.Camera3D, 
                           scene_render_proc: SceneRenderProc, user_data: rawptr = nil) {
    start_time := time.now()
    
    // Update view position
    camera_pos := camera.position
    rl.SetShaderValue(system.shader, system.view_pos_loc, &camera_pos, .VEC3)
    
    // Phase 1: Shadow pass
    shadow_start := time.now()
    
    rl.BeginTextureMode(system.shadow_map)
    rl.ClearBackground(rl.WHITE)
    rl.BeginMode3D(system.light_camera)
    
    scene_render_proc(user_data, true) // shadow_pass = true
    
    rl.EndMode3D()
    rl.EndTextureMode()
    
    shadow_end := time.now()
    system.metrics.shadow_render_time = f32(time.duration_seconds(time.diff(shadow_start, shadow_end)))
    
    // Phase 2: Main render
    main_start := time.now()
    
    light_view := rlgl.GetMatrixModelview()
    light_proj := rlgl.GetMatrixProjection()
    light_proj_view := light_proj * light_view
    rl.SetShaderValueMatrix(system.shader, system.light_vp_loc, light_proj_view)
    
    // Bind shadow map texture
    rlgl.EnableShader(system.shader.id)
    rlgl.ActiveTextureSlot(system.config.texture_slot)
    rlgl.EnableTexture(system.shadow_map.depth.id)
    rlgl.SetUniform(system.shadow_map_loc, &system.config.texture_slot, i32(rl.ShaderUniformDataType.INT), 1)
    
    rl.BeginMode3D(camera)
    scene_render_proc(user_data, false) // shadow_pass = false
    rl.EndMode3D()
    
    main_end := time.now()
    system.metrics.main_render_time = f32(time.duration_seconds(time.diff(main_start, main_end)))
    
    end_time := time.now()
    system.metrics.total_frame_time = f32(time.duration_seconds(time.diff(start_time, end_time)))
}

// Apply shadow shader to model
apply_shadow_shader :: proc(system: ^ShadowSystem, model: ^rl.Model) {
    for i in 0..<model.materialCount {
        model.materials[i].shader = system.shader
    }
}

// Create ModelLOD from regular model
create_model_lod :: proc(model: rl.Model, position, scale: rl.Vector3, is_static: bool = false) -> ModelLOD {
    // Calculate bounding box
    bounds := rl.GetModelBoundingBox(model)
    bounds.min = bounds.min * scale + position
    bounds.max = bounds.max * scale + position
    
    return ModelLOD{
        high_detail   = model,
        shadow_caster = model, // Use same model for now, could be simplified
        bounds        = bounds,
        position      = position,
        scale         = scale,
        is_static     = is_static,
    }
}

// Debug functions
debug_shadow_system :: proc(system: ^ShadowSystem) {
    fmt.printf("=== Shadow System Debug ===\n")
    fmt.printf("Shader ID: %d\n", system.shader.id)
    fmt.printf("Shadow Map ID: %d\n", system.shadow_map.id)
    fmt.printf("Resolution: %dx%d (Quality: %.2f)\n", 
               system.config.current_resolution, system.config.current_resolution, system.config.quality_level)
    fmt.printf("Light Direction: (%.3f, %.3f, %.3f)\n", 
               system.light.direction.x, system.light.direction.y, system.light.direction.z)
    fmt.printf("Performance: %.1f FPS, Shadow: %.2fms, Main: %.2fms\n",
               system.metrics.last_fps,
               system.metrics.shadow_render_time * 1000,
               system.metrics.main_render_time * 1000)
    
    // Check critical shader locations
    if system.light_dir_loc == -1 do fmt.println("WARNING: lightDir uniform not found!")
    if system.shadow_map_loc == -1 do fmt.println("WARNING: shadowMap uniform not found!")
    if system.light_vp_loc == -1 do fmt.println("WARNING: lightVP uniform not found!")
}

// Save shadow map for debugging
save_shadow_map_debug :: proc(system: ^ShadowSystem, filename: cstring) {
    image := rl.LoadImageFromTexture(system.shadow_map.depth)
    defer rl.UnloadImage(image)
    rl.ExportImage(image, filename)
    fmt.printf("Shadow map saved to %s\n", filename)
}

// Preset configurations
get_indoor_config :: proc() -> ShadowConfig {
    return ShadowConfig{
        base_resolution     = 1024,
        current_resolution  = 1024,
        light_distance      = 8.0,
        light_fov           = 30.0,
        ambient             = {0.3, 0.3, 0.35, 1.0},
        texture_slot        = 10,
        quality_level       = 1.0,
        auto_scale          = true,
        target_fps          = 60.0,
        enable_frustum_cull = true,
        enable_lod_shadows  = true,
        enable_pcf          = true,
        pcf_samples         = 9,
        shadow_bias         = 0.003,
        slope_bias          = 0.03,
        max_bias            = 0.015,
        enable_jitter       = true,
        jitter_amount       = 0.0003,
    }
}

get_outdoor_config :: proc() -> ShadowConfig {
    return ShadowConfig{
        base_resolution     = 2048,
        current_resolution  = 2048,
        light_distance      = 25.0,
        light_fov           = 15.0,
        ambient             = {0.1, 0.1, 0.15, 1.0},
        texture_slot        = 10,
        quality_level       = 1.0,
        auto_scale          = true,
        target_fps          = 60.0,
        enable_frustum_cull = true,
        enable_lod_shadows  = true,
        enable_pcf          = true,
        pcf_samples         = 16,
        shadow_bias         = 0.001,
        slope_bias          = 0.05,
        max_bias            = 0.008,
        enable_jitter       = true,
        jitter_amount       = 0.0005,
    }
}

get_mobile_config :: proc() -> ShadowConfig {
    return ShadowConfig{
        base_resolution     = 512,
        current_resolution  = 512,
        light_distance      = 12.0,
        light_fov           = 25.0,
        ambient             = {0.25, 0.25, 0.3, 1.0},
        texture_slot        = 10,
        quality_level       = 1.0,
        auto_scale          = true,
        target_fps          = 30.0,
        enable_frustum_cull = true,
        enable_lod_shadows  = true,
        enable_pcf          = false, // Disabled for performance
        pcf_samples         = 4,
        shadow_bias         = 0.005,
        slope_bias          = 0.02,
        max_bias            = 0.02,
        enable_jitter       = false, // Disabled for performance
        jitter_amount       = 0.0,
    }
}

// Clean up
destroy_shadow_system :: proc(system: ^ShadowSystem) {
    if system.shadow_map.id > 0 {
        unload_shadowmap_render_texture(system.shadow_map)
        system.shadow_map.id = 0
    }
    
    if system.shader.id > 0 {
        rl.UnloadShader(system.shader)
        system.shader.id = 0
    }
    
    rl.TraceLog(rl.TraceLogLevel.INFO, "SHADOWMAP: Enhanced shadow system destroyed")
}

// Internal helper functions
@(private)
load_shadowmap_render_texture :: proc(width, height: i32) -> rl.RenderTexture2D {
    target := rl.RenderTexture2D{}
    
    target.id = rlgl.LoadFramebuffer(width, height)
    target.texture.width = width
    target.texture.height = height
    
    if target.id > 0 {
        rlgl.EnableFramebuffer(target.id)
        
        target.depth.id = rlgl.LoadTextureDepth(width, height, false)
        target.depth.width = width
        target.depth.height = height
        target.depth.format = rl.PixelFormat(19) // 24BIT DEPTH
        target.depth.mipmaps = 1
        
        rlgl.FramebufferAttach(target.id, target.depth.id, 
                              i32(rlgl.FramebufferAttachType.DEPTH), 
                              i32(rlgl.FramebufferAttachTextureType.TEXTURE2D), 0)
        
        if rlgl.FramebufferComplete(target.id) {
            rl.TraceLog(rl.TraceLogLevel.INFO, "SHADOWMAP: [ID %i] Enhanced framebuffer created", target.id)
        } else {
            rl.TraceLog(rl.TraceLogLevel.ERROR, "SHADOWMAP: [ID %i] Enhanced framebuffer incomplete", target.id)
        }
        
        rlgl.DisableFramebuffer()
    }
    
    return target
}

@(private)
unload_shadowmap_render_texture :: proc(target: rl.RenderTexture2D) {
    if target.id > 0 {
        rlgl.UnloadFramebuffer(target.id)
    }
}