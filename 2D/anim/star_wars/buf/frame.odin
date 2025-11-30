package buf

import rl "vendor:raylib"
import "vendor:raylib/rlgl"
import "core:fmt"

// Anti-aliasing methods
AAMethod :: enum {
    NONE,
    BILINEAR,
    TRILINEAR,
    MANUAL_MSAA,
    FXAA, // For the future
}

// Generate multi-sampled framebuffers using rlgl
FrameBuffer :: struct {
    id:            u32,
    color_tex_id:  u32,
    depth_rb_id:   u32,
    num_samples:   i32,
    width:         i32,
    height:        i32,
    render_target: rl.RenderTexture2D,
    aa_method:     AAMethod,
}

// Error handling
FrameBufferError :: enum {
    NONE,
    FAILED_TO_CREATE,
    INVALID_DIMENSIONS,
}

FrameBufferResult :: union {
    FrameBuffer,
    FrameBufferError,
}

// Creates a multi-sampled framebuffer using rlgl
init :: proc(width, height: i32, num_samples := 4) -> FrameBufferResult {
    if width <= 0 || height <= 0 {
        return FrameBufferError.INVALID_DIMENSIONS
    }
    
    buf := FrameBuffer{
        width = width,
        height = height,
        num_samples = i32(num_samples),
        aa_method = .BILINEAR,
    }
    
    // Generate framebuffer
    buf.id = rlgl.LoadFramebuffer()
    
    if buf.id == 0 {
        fmt.println("Failed to create framebuffer")
        return FrameBufferError.FAILED_TO_CREATE
    }
    
    // Bind the framebuffer
    rlgl.EnableFramebuffer(buf.id)
    
    // Load a multisampled color texture
    buf.color_tex_id = rlgl.LoadTextureDepth(width, height, false)
    
    // Disable framebuffer to finish setup
    rlgl.DisableFramebuffer()
    
    // Set up the render target structure
    buf.render_target = _setup_render_target(buf.id, buf.color_tex_id, width, height)
    
    return buf
}

// Init with post-processing (most reliable)
init_with_postprocessing :: proc(width, height: i32, aa_method := AAMethod.BILINEAR) -> FrameBufferResult {
    if width <= 0 || height <= 0 {
        return FrameBufferError.INVALID_DIMENSIONS
    }
    
    buf := FrameBuffer{
        width = width,
        height = height,
        num_samples = 1,
        aa_method = aa_method,
    }
    
    // Use Raylib's standard render texture
    buf.render_target = rl.LoadRenderTexture(width, height)
    buf.id = buf.render_target.id
    buf.color_tex_id = buf.render_target.texture.id
    
    return buf
}

// Init with explicit batch flushing
init_with_flush :: proc(width, height: i32, num_samples := 4) -> FrameBufferResult {
    if width <= 0 || height <= 0 {
        return FrameBufferError.INVALID_DIMENSIONS
    }
    
    buf := FrameBuffer{
        width = width,
        height = height,
        num_samples = i32(num_samples),
        aa_method = .BILINEAR,
    }
    
    when ODIN_DEBUG {
        fmt.println("Initializing framebuffer with explicit flush")
    }
    
    // Ensure any pending draws are completed
    rlgl.End()
    rlgl.Begin(rlgl.TRIANGLES)
    
    // Generate and bind framebuffer
    buf.id = rlgl.LoadFramebuffer()
    
    if buf.id == 0 {
        fmt.println("Failed to create framebuffer")
        return FrameBufferError.FAILED_TO_CREATE
    }
    
    // Bind the framebuffer
    rlgl.EnableFramebuffer(buf.id)
    
    // Load a texture for the framebuffer
    buf.color_tex_id = rlgl.LoadTextureDepth(width, height, false)
    
    // Disable framebuffer to finish setup
    rlgl.DisableFramebuffer()
    
    // Set up the render target
    buf.render_target = _setup_render_target(buf.id, buf.color_tex_id, width, height)
    
    return buf
}

// Helper to set up render target (DRY principle)
_setup_render_target :: proc(id, color_tex_id: u32, width, height: i32) -> rl.RenderTexture2D {
    render_target := rl.RenderTexture2D{}
    render_target.id                = id
    render_target.texture.id        = color_tex_id
    render_target.texture.width     = width
    render_target.texture.height    = height
    render_target.texture.mipmaps   = 1
    render_target.texture.format    = rl.PixelFormat.UNCOMPRESSED_R8G8B8A8
    render_target.depth.id          = 0
    render_target.depth.width       = width
    render_target.depth.height      = height
    render_target.depth.mipmaps     = 1
    render_target.depth.format      = rl.PixelFormat.UNCOMPRESSED_GRAYSCALE
    return render_target
}

// Begin rendering to the framebuffer
begin :: proc(buf: ^FrameBuffer) {
    rl.BeginTextureMode(buf.render_target)
}

// End rendering to the framebuffer
end :: proc(buf: ^FrameBuffer) {
    rl.EndTextureMode()
}

// Set anti-aliasing method
set_aa_method :: proc(buf: ^FrameBuffer, method: AAMethod) {
    buf.aa_method = method
}

// Draw the framebuffer to screen with specified anti-aliasing
draw :: proc(buf: ^FrameBuffer, aa_method: AAMethod = AAMethod.BILINEAR) {
    switch aa_method {
    case .NONE:
        _draw_no_filtering(buf)
    case .BILINEAR:
        _draw_bilinear(buf)
    case .TRILINEAR:
        _draw_trilinear(buf)
    case .MANUAL_MSAA:
        _draw_manual_msaa(buf)
    case .FXAA:
        _draw_fxaa(buf) // Future implementation
    }
}

// Draw with current AA method
draw_current :: proc(buf: ^FrameBuffer) {
    draw(buf, buf.aa_method)
}

// Private drawing methods
_draw_no_filtering :: proc(buf: ^FrameBuffer) {
    rl.SetTextureFilter(buf.render_target.texture, rl.TextureFilter.POINT)
    _draw_texture(buf, rl.WHITE)
}

_draw_bilinear :: proc(buf: ^FrameBuffer) {
    rl.SetTextureFilter(buf.render_target.texture, rl.TextureFilter.BILINEAR)
    _draw_texture(buf, rl.WHITE)
}

_draw_trilinear :: proc(buf: ^FrameBuffer) {
    // Generate mipmaps for trilinear filtering
    rl.GenTextureMipmaps(&buf.render_target.texture)
    rl.SetTextureFilter(buf.render_target.texture, rl.TextureFilter.TRILINEAR)
    _draw_texture(buf, rl.WHITE)
}

_draw_manual_msaa :: proc(buf: ^FrameBuffer) {
    // Manual multi-sampling with sub-pixel offsets
    src := rl.Rectangle{0, 0, f32(buf.render_target.texture.width), -f32(buf.render_target.texture.height)}
    dest := rl.Rectangle{0, 0, f32(buf.width), f32(buf.height)}
    
    // Use alpha blending for sample accumulation
    rl.BeginBlendMode(rl.BlendMode.ALPHA)
    
    // MSAA sample pattern (rotated grid)
    samples := []rl.Vector2{
        {-0.125, -0.375}, {0.375, -0.125},
        {-0.375, 0.125},  {0.125, 0.375},
    }
    
    alpha := u8(255 / len(samples))
    color := rl.Color{255, 255, 255, alpha}
    
    for sample in samples {
        offset_dest := rl.Rectangle{
            dest.x + sample.x, 
            dest.y + sample.y, 
            dest.width, 
            dest.height
        }
        rl.DrawTexturePro(buf.render_target.texture, src, offset_dest, {0, 0}, 0.0, color)
    }
    
    rl.EndBlendMode()
}

_draw_fxaa :: proc(buf: ^FrameBuffer) {
    // Placeholder for FXAA implementation
    // Would require custom shader for proper FXAA
    fmt.println("FXAA not implemented yet, falling back to bilinear")
    _draw_bilinear(buf)
}

_draw_texture :: proc(buf: ^FrameBuffer, tint: rl.Color) {
    src := rl.Rectangle{0, 0, f32(buf.render_target.texture.width), -f32(buf.render_target.texture.height)}
    dest := rl.Rectangle{0, 0, f32(buf.width), f32(buf.height)}
    rl.DrawTexturePro(buf.render_target.texture, src, dest, {0, 0}, 0.0, tint)
}

// Resize framebuffer (useful when window resizing)
resize :: proc(buf: ^FrameBuffer, new_width, new_height: i32) -> bool {
    if new_width <= 0 || new_height <= 0 {
        return false
    }
    
    // Unload old render texture
    rl.UnloadRenderTexture(buf.render_target)
    
    // Create new one
    buf.render_target = rl.LoadRenderTexture(new_width, new_height)
    buf.width = new_width
    buf.height = new_height
    buf.id = buf.render_target.id
    buf.color_tex_id = buf.render_target.texture.id
    
    return buf.render_target.id != 0
}

// Get framebuffer info
get_info :: proc(buf: ^FrameBuffer) -> (width, height, samples: i32, method: AAMethod) {
    return buf.width, buf.height, buf.num_samples, buf.aa_method
}

// Check if framebuffer is valid
is_valid :: proc(buf: ^FrameBuffer) -> bool {
    return buf.id != 0 && buf.render_target.id != 0
}

destroy :: proc(buf: ^FrameBuffer) {
    if is_valid(buf) {
        rl.UnloadRenderTexture(buf.render_target)
        buf.id = 0
        buf.color_tex_id = 0
    }
}
