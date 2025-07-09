package shadow

import "core:math/linalg"
import "core:math/rand"
import rl "vendor:raylib"
import "vendor:raylib/rlgl"
import "core:fmt"

// Configuration constants
DEFAULT_SHADOWMAP_RESOLUTION :: 1024
DEFAULT_LIGHT_DISTANCE :: 15.0
DEFAULT_LIGHT_FOV :: 20.0
DEFAULT_AMBIENT :: [4]f32{0.1, 0.1, 0.1, 1.0}

// Shadow system configuration
ShadowConfig :: struct {
    resolution:     i32,
    light_distance: f32,
    light_fov:      f32,
    ambient:        [4]f32,
    texture_slot:   i32, // Which texture slot to use for the shadow map
}

// Light configuration
DirectionalLight :: struct {
    direction: rl.Vector3,
    color:     rl.Color,
}

// Complete shadow mapping system
ShadowSystem :: struct {
    config:          ShadowConfig,
    light:           DirectionalLight,
    shader:          rl.Shader,
    shadow_map:      rl.RenderTexture2D,
    light_camera:    rl.Camera3D,
    
    // Shader locations (cached for performance)
    light_dir_loc:   i32,
    light_col_loc:   i32,
    ambient_loc:     i32,
    light_vp_loc:    i32,
    shadow_map_loc:  i32,
    view_pos_loc:    i32,
}

// Render callback type for drawing scenes
SceneRenderProc :: proc(user_data: rawptr)

// Initialize shadow system with default configuration
init_shadow_system :: proc(vertex_shader_path, fragment_shader_path: cstring) -> (ShadowSystem, bool) {
    config := ShadowConfig{
        resolution     = DEFAULT_SHADOWMAP_RESOLUTION,
        light_distance = DEFAULT_LIGHT_DISTANCE,
        light_fov      = DEFAULT_LIGHT_FOV,
        ambient        = DEFAULT_AMBIENT,
        texture_slot   = i32(rand.float32_range(10, 15)), // Use slots 10-15 to avoid conflicts with material textures
    }
    
    light := DirectionalLight{
        direction = rl.Vector3Normalize({0.35, -1.0, -0.35}),
        color     = rl.WHITE,
    }
    
    return init_shadow_system_with_config(vertex_shader_path, fragment_shader_path, config, light)
}

// Initialize shadow system with custom configuration
init_shadow_system_with_config :: proc(vertex_shader_path, fragment_shader_path: cstring, 
                                      config: ShadowConfig, light: DirectionalLight) -> (ShadowSystem, bool) {
    system := ShadowSystem{}
    system.config = config
    system.light = light
    
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
    
    // Set up shader uniforms
    system.shader.locs[rl.ShaderLocationIndex.VECTOR_VIEW] = system.view_pos_loc
    system.shader.locs[rl.ShaderLocationIndex.MATRIX_MODEL] = rl.GetShaderLocation(system.shader, "matModel")
    
    // Initialize shader values
    light_color_normalized := rl.ColorNormalize(system.light.color)
    rl.SetShaderValue(system.shader, system.light_dir_loc, &system.light.direction, .VEC3)
    rl.SetShaderValue(system.shader, system.light_col_loc, &light_color_normalized, .VEC4)
    rl.SetShaderValue(system.shader, system.ambient_loc, &system.config.ambient, .VEC4)
    rl.SetShaderValue(system.shader, rl.GetShaderLocation(system.shader, "shadowMapResolution"), &system.config.resolution, .INT)
    
    // Create shadow map render texture
    system.shadow_map = load_shadowmap_render_texture(system.config.resolution, system.config.resolution)
    if system.shadow_map.id == 0 {
        rl.TraceLog(rl.TraceLogLevel.ERROR, "SHADOWMAP: Failed to create shadow map render texture")
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
    
    rl.TraceLog(rl.TraceLogLevel.INFO, "SHADOWMAP: Shadow system initialized successfully")
    return system, true
}

// Clean up shadow system resources
destroy_shadow_system :: proc(system: ^ShadowSystem) {
    if system.shadow_map.id > 0 {
        unload_shadowmap_render_texture(system.shadow_map)
        system.shadow_map.id = 0
    }
    
    if system.shader.id > 0 {
        rl.UnloadShader(system.shader)
        system.shader.id = 0
    }
    
    rl.TraceLog(rl.TraceLogLevel.INFO, "SHADOWMAP: Shadow system destroyed")
}

// Update light direction and camera
update_light :: proc(system: ^ShadowSystem, new_direction: rl.Vector3) {
    system.light.direction = rl.Vector3Normalize(new_direction)
    system.light_camera.position = system.light.direction * -system.config.light_distance
    rl.SetShaderValue(system.shader, system.light_dir_loc, &system.light.direction, .VEC3)
}

// Update light color
update_light_color :: proc(system: ^ShadowSystem, new_color: rl.Color) {
    system.light.color = new_color
    light_color_normalized := rl.ColorNormalize(new_color)
    rl.SetShaderValue(system.shader, system.light_col_loc, &light_color_normalized, .VEC4)
}

// Apply shadow shader to a model
apply_shadow_shader :: proc(system: ^ShadowSystem, model: ^rl.Model) {
    for i in 0..<model.materialCount {
        model.materials[i].shader = system.shader
    }
}

// Render scene with shadows
render_with_shadows :: proc(system: ^ShadowSystem, camera: rl.Camera3D, 
                           scene_render_proc: SceneRenderProc, user_data: rawptr = nil) {
    // Update view position for shader
    camera_pos := camera.position
    rl.SetShaderValue(system.shader, system.view_pos_loc, &camera_pos, .VEC3)
    
    // Phase 1: Render shadow map from light's perspective
    light_view: rl.Matrix
    light_proj: rl.Matrix
    
    rl.BeginTextureMode(system.shadow_map)
    {
        rl.ClearBackground(rl.WHITE)
        rl.BeginMode3D(system.light_camera)
        {
            light_view = rlgl.GetMatrixModelview()
            light_proj = rlgl.GetMatrixProjection()
            scene_render_proc(user_data)
        }
        rl.EndMode3D()
    }
    rl.EndTextureMode()
    
    // Phase 2: Render scene from camera's perspective with shadows
    light_proj_view := light_proj * light_view
    rl.SetShaderValueMatrix(system.shader, system.light_vp_loc, light_proj_view)
    
    // Bind shadow map texture
    rlgl.EnableShader(system.shader.id)
    rlgl.ActiveTextureSlot(system.config.texture_slot)
    rlgl.EnableTexture(system.shadow_map.depth.id)
    rlgl.SetUniform(system.shadow_map_loc, &system.config.texture_slot, i32(rl.ShaderUniformDataType.INT), 1)
    
    rl.BeginMode3D(camera)
    {
        scene_render_proc(user_data)
    }
    rl.EndMode3D()
}

// Utility function for smooth light direction interpolation
interpolate_light_direction :: proc(system: ^ShadowSystem, target_direction: rl.Vector3, speed: f32, dt: f32) {
    current := system.light.direction
    target := rl.Vector3Normalize(target_direction)
    
    // Simple linear interpolation (could be replaced with slerp for better results)
    new_direction := linalg.lerp(current, target, speed * dt)
    update_light(system, new_direction)
}

// Get current light direction (useful for debugging or UI)
get_light_direction :: proc(system: ^ShadowSystem) -> rl.Vector3 {
    return system.light.direction
}

// Get shadow map texture (useful for debugging)
get_shadow_map_texture :: proc(system: ^ShadowSystem) -> rl.Texture2D {
    return system.shadow_map.depth
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
        
        // Create depth texture
        target.depth.id = rlgl.LoadTextureDepth(width, height, false)
        target.depth.width = width
        target.depth.height = height
        target.depth.format = rl.PixelFormat(19) // 24BIT DEPTH
        target.depth.mipmaps = 1
        
        // Attach depth texture to FBO
        rlgl.FramebufferAttach(target.id, target.depth.id, 
                              i32(rlgl.FramebufferAttachType.DEPTH), 
                              i32(rlgl.FramebufferAttachTextureType.TEXTURE2D), 0)
        
        // Check if fbo is complete
        if rlgl.FramebufferComplete(target.id) {
            rl.TraceLog(rl.TraceLogLevel.INFO, "SHADOWMAP: [ID %i] Framebuffer created successfully", target.id)
        } else {
            rl.TraceLog(rl.TraceLogLevel.ERROR, "SHADOWMAP: [ID %i] Framebuffer incomplete", target.id)
        }
        
        rlgl.DisableFramebuffer()
    } else {
        rl.TraceLog(rl.TraceLogLevel.ERROR, "SHADOWMAP: Failed to create framebuffer")
    }
    
    return target
}

@(private)
unload_shadowmap_render_texture :: proc(target: rl.RenderTexture2D) {
    if target.id > 0 {
        rlgl.UnloadFramebuffer(target.id)
    }
}


/* Alternative: Custom shadow config

example_custom_config :: proc() {
    // Create custom shadow configuration
    custom_config := sm.ShadowConfig{
        resolution     = 2048,  // Higher resolution shadows
        light_distance = 20.0,  // Further light distance
        light_fov      = 15.0,  // Tighter light cone
        ambient        = {0.2, 0.2, 0.3, 1.0}, // Slightly blue ambient
        texture_slot   = 5,     // Different texture slot
    }
    
    // Create custom light
    custom_light := sm.DirectionalLight{
        direction = {0.5, -0.8, 0.3},
        color     = rl.Color{255, 220, 180, 255}, // Warm light
    }
    
    // Initialize with custom settings
    shadow_system, ok := sm.init_shadow_system_with_config(
        "../assets/shadow.vs", 
        "../assets/shadow.fs",
        custom_config,
        custom_light
    )
    
    if ok {
        fmt.println("Custom shadow system initialized!")
        // Use shadow_system...
        sm.destroy_shadow_system(&shadow_system)
    }
}
*/