// File: rlutil/shader_watcher.odin
package rlutil

import rl "vendor:raylib"
import "core:fmt"
import "core:os"
import "core:time"
import "core:strings"

// ShaderWatch now supports custom vertex shaders
ShaderWatch :: struct {
    vert_path:   string,
    frag_path:   string,
    name:        string, // Display name for the shader pair
    last_load:   i64,
    shader:      rl.Shader,
}

ShaderError :: enum {
    None,
    VertexFileReadFailed,
    FragmentFileReadFailed,
    CompileFailed,
    WatchFailed,
}

// ShaderPair represents a vertex/fragment shader combination
ShaderPair :: struct {
    vert_file: string, // Can be empty to use base vertex shader
    frag_file: string,
    name: string,      // Optional display name, will be generated if empty
}

// The shader manager now supports custom vertex shaders
ShaderWatcher :: struct {
    watches:              [dynamic]ShaderWatch,
    error_shader:         rl.Shader,
    current_index:        int,
    base_vert_path:       string,
    error_frag_path:      string,
    shader_dir:           string,
}

// Loads a single shader. Internal helper function.
_shader_load :: proc(vert_path, frag_path: string) -> (rl.Shader, ShaderError) {
    context.allocator = context.temp_allocator

    vert_bytes, vert_ok := os.read_entire_file_from_filename(vert_path)
    if !vert_ok {
        return {}, .VertexFileReadFailed
    }
    frag_bytes, frag_ok := os.read_entire_file_from_filename(frag_path)
    if !frag_ok {
        return {}, .FragmentFileReadFailed
    }
    // Raylib's LoadShaderFromMemory expects c-strings.
    shader := rl.LoadShaderFromMemory(fmt.ctprintf("%s", vert_bytes), fmt.ctprintf("%s", frag_bytes))
    if !rl.IsShaderReady(shader) {
        return {}, .CompileFailed
    }
    return shader, .None
}

// Helper to generate a display name from shader filenames
_generate_shader_name :: proc(vert_file, frag_file: string) -> string {
    if vert_file == "" {
        // Just fragment shader name without extension
        return strings.trim_suffix(frag_file, ".fs")
    } else {
        // Combine both names
        vert_name := strings.trim_suffix(vert_file, ".vs")
        frag_name := strings.trim_suffix(frag_file, ".fs")
        return fmt.tprintf("%s+%s", vert_name, frag_name)
    }
}

// watcher_create_pairs initializes the shader system with custom vertex/fragment pairs
watcher_create_pairs :: proc(base_vert_path, error_frag_path, shader_dir: string, shader_pairs: []ShaderPair) -> (watcher: ShaderWatcher, ok: bool) {
    watcher.base_vert_path = base_vert_path
    watcher.error_frag_path = error_frag_path
    watcher.shader_dir = shader_dir

    // Load the fallback error shader first.
    error_shader, err := _shader_load(base_vert_path, error_frag_path)
    if err != .None {
        fmt.eprintln("FATAL: Could not load the fallback error shader. Error:", err)
        return {}, false
    }
    watcher.error_shader = error_shader

    // Load all shader pairs
    for pair in shader_pairs {
        // Determine vertex shader path
        vert_path := base_vert_path
        if pair.vert_file != "" {
            vert_path = fmt.tprintf("%s/%s", shader_dir, pair.vert_file)
        }
        
        frag_path := fmt.tprintf("%s/%s", shader_dir, pair.frag_file)
        
        // Generate display name if not provided
        display_name := pair.name
        if display_name == "" {
            display_name = _generate_shader_name(pair.vert_file, pair.frag_file)
        }
        
        shader, err := _shader_load(vert_path, frag_path)
        sw := ShaderWatch{
            vert_path = vert_path,
            frag_path = frag_path,
            name      = display_name,
            shader    = shader,
        }
        
        if err != .None {
            fmt.eprintln("ERROR: Failed to load shader:", display_name, "| Error:", err, "| Using fallback.")
            sw.shader = watcher.error_shader
            // We don't set last_load time, so it will try to reload next time.
        } else {
            v_stat, _ := os.stat(vert_path)
            f_stat, _ := os.stat(frag_path)
            sw.last_load = max(v_stat.modification_time._nsec, f_stat.modification_time._nsec)
        }
        append(&watcher.watches, sw)
    }
    return watcher, true
}

// watcher_create maintains backward compatibility - creates watcher with fragment shaders only
watcher_create :: proc(base_vert_path, error_frag_path: string, frag_files: []string) -> (watcher: ShaderWatcher, ok: bool) {
    shader_pairs := make([]ShaderPair, len(frag_files))
    defer delete(shader_pairs)
    
    for frag_file, i in frag_files {
        shader_pairs[i] = ShaderPair{
            vert_file = "", // Use base vertex shader
            frag_file = frag_file,
            name = "",      // Auto-generate name
        }
    }
    
    return watcher_create_pairs(base_vert_path, error_frag_path, "assets/shader", shader_pairs)
}

// watcher_destroy unloads all shaders managed by the watcher.
watcher_destroy :: proc(watcher: ^ShaderWatcher) {
    for i in 0..<len(watcher.watches) {
        // Avoid double-unloading the error shader
        if watcher.watches[i].shader.id != watcher.error_shader.id {
            rl.UnloadShader(watcher.watches[i].shader)
        }
    }
    rl.UnloadShader(watcher.error_shader)
    delete(watcher.watches)
}

// UpdateResult informs the main loop about what happened.
UpdateResult :: enum {
    NoChange,
    ReloadSuccess,
    ReloadFailed,
}

// watcher_update checks the current shader for changes and reloads it if necessary.
// This should be called once per frame.
watcher_update :: proc(watcher: ^ShaderWatcher) -> UpdateResult {
    if watcher.current_index < 0 || watcher.current_index >= len(watcher.watches) {
        return .NoChange
    }
    // Use a pointer to modify the struct in the array directly.
    watch := &watcher.watches[watcher.current_index]

    v_stat, v_err := os.stat(watch.vert_path)
    f_stat, f_err := os.stat(watch.frag_path)
    if v_err != nil || f_err != nil {
        return .NoChange // Don't attempt reload if files can't be stat'd
    }
    last_modified := max(v_stat.modification_time._nsec, f_stat.modification_time._nsec)
    if last_modified <= watch.last_load {
        return .NoChange
    }
    time.sleep(50 * time.Millisecond) // Ensure file write is complete.

    new_shader, err := _shader_load(watch.vert_path, watch.frag_path)
    if err != .None {
        fmt.eprintln("Failed to reload shader:", watch.name, "| Error:", err)
        // Set to error shader, but keep paths so it can try reloading again.
        if watch.shader.id != watcher.error_shader.id {
            rl.UnloadShader(watch.shader)
        }
        watch.shader = watcher.error_shader
        watch.last_load = 0 // Reset last_load to force a retry next frame.
        return .ReloadFailed
    }
    fmt.println("✅ Shader reloaded", watch.name)
    
    // Unload the old shader if it wasn't the error shader
    if watch.shader.id != watcher.error_shader.id {
        rl.UnloadShader(watch.shader)
    }
    watch.shader = new_shader
    watch.last_load = last_modified
    return .ReloadSuccess
}

// watcher_get_current returns the active shader for drawing.
watcher_get_current :: proc(watcher: ^ShaderWatcher) -> rl.Shader {
    if watcher.current_index < 0 || watcher.current_index >= len(watcher.watches) {
        return watcher.error_shader
    }
    return watcher.watches[watcher.current_index].shader
}

// watcher_get_current_name returns the name of the active shader.
watcher_get_current_name :: proc(watcher: ^ShaderWatcher) -> string {
    if watcher.current_index < 0 || watcher.current_index >= len(watcher.watches) {
        return "None"
    }
    return watcher.watches[watcher.current_index].name
}

// watcher_next cycles to the next shader.
watcher_next :: proc(watcher: ^ShaderWatcher) {
    if len(watcher.watches) == 0 { return }
    watcher.current_index = (watcher.current_index + 1) % len(watcher.watches)
}

// watcher_previous cycles to the previous shader.
watcher_previous :: proc(watcher: ^ShaderWatcher) {
    if len(watcher.watches) == 0 { return }
    watcher.current_index = (watcher.current_index - 1 + len(watcher.watches)) % len(watcher.watches)
}