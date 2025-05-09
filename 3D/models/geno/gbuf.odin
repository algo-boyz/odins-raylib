package geno

import "core:math"

import rl "vendor:raylib"
import rlgl "vendor:raylib/rlgl"

GBuffer :: struct {
    id: u32,
    color: rl.Texture,
    normal: rl.Texture,
    depth: rl.Texture,
}

load_gbuffer :: proc(width, height: i32) -> GBuffer {
    target: GBuffer
    target.id = rlgl.LoadFramebuffer(width, height)
    assert(target.id != 0)
    
    rlgl.EnableFramebuffer(target.id)

    target.color.id = rlgl.LoadTexture(nil, width, height, i32(rl.PixelFormat.UNCOMPRESSED_R8G8B8A8), 1)
    target.color.width = width
    target.color.height = height
    target.color.format = rl.PixelFormat.UNCOMPRESSED_R8G8B8A8
    target.color.mipmaps = 1
    rlgl.FramebufferAttach(target.id, target.color.id, i32(rlgl.FramebufferAttachType.COLOR_CHANNEL0), i32(rlgl.FramebufferAttachTextureType.TEXTURE2D), 0)
    
    target.normal.id = rlgl.LoadTexture(nil, width, height, i32(rl.PixelFormat.UNCOMPRESSED_R16G16B16A16), 1)
    target.normal.width = width
    target.normal.height = height
    target.normal.format = .UNCOMPRESSED_R16G16B16A16
    target.normal.mipmaps = 1
    rlgl.FramebufferAttach(target.id, target.normal.id, i32(rlgl.FramebufferAttachType.COLOR_CHANNEL1), i32(rlgl.FramebufferAttachTextureType.TEXTURE2D), 0)
    
    target.depth.id = rlgl.LoadTextureDepth(width, height, false)
    target.depth.width = width
    target.depth.height = height
    target.depth.format = rl.PixelFormat.UNCOMPRESSED_R8G8B8A8  // DEPTH_COMPONENT_24BIT
    target.depth.mipmaps = 1
    rlgl.FramebufferAttach(target.id, target.depth.id, i32(rlgl.FramebufferAttachType.DEPTH), i32(rlgl.FramebufferAttachTextureType.TEXTURE2D), 0)

    assert(rlgl.FramebufferComplete(target.id))

    rlgl.DisableFramebuffer()

    return target
}

unload_gbuffer :: proc(target: GBuffer) {
    if target.id > 0 {
        rlgl.UnloadFramebuffer(target.id)
    }
}

begin_gbuffer :: proc(target: GBuffer, camera: rl.Camera3D) {
    rlgl.DrawRenderBatchActive()

    rlgl.EnableFramebuffer(target.id)
    rlgl.ActiveDrawBuffers(2)

    rlgl.Viewport(0, 0, target.color.width, target.color.height)
    rlgl.SetFramebufferWidth(target.color.width)
    rlgl.SetFramebufferHeight(target.color.height)

    rl.ClearBackground(rl.BLACK)

    rlgl.MatrixMode(rlgl.PROJECTION)
    rlgl.PushMatrix()
    rlgl.LoadIdentity()

    aspect := f32(target.color.width) / f32(target.color.height)

    if camera.projection == .PERSPECTIVE {
        top := f64(rlgl.CULL_DISTANCE_NEAR * math.tan_f32(camera.fovy * 0.5 * rl.DEG2RAD))
        right := top * f64(aspect)
        rlgl.Frustum(-right, right, -top, top, rlgl.CULL_DISTANCE_NEAR, rlgl.CULL_DISTANCE_FAR)
    } else if camera.projection == .ORTHOGRAPHIC {
        top := f64(camera.fovy / 2.0)
        right := top * f64(aspect)
        rlgl.Ortho(-right, right, -top, top, rlgl.CULL_DISTANCE_NEAR, rlgl.CULL_DISTANCE_FAR)
    }

    rlgl.MatrixMode(rlgl.MODELVIEW)
    rlgl.LoadIdentity()

    mat_view := rl.MatrixLookAt(camera.position, camera.target, camera.up)
    mat_view_array := [16]f32{
        mat_view[0][0], mat_view[0][1], mat_view[0][2], mat_view[0][3],
        mat_view[1][0], mat_view[1][1], mat_view[1][2], mat_view[1][3],
        mat_view[2][0], mat_view[2][1], mat_view[2][2], mat_view[2][3],
        mat_view[3][0], mat_view[3][1], mat_view[3][2], mat_view[3][3],
    }
    rlgl.MultMatrixf(&mat_view_array[0])

    rlgl.EnableDepthTest()
}

end_gbuffer :: proc(window_width, window_height: i32) {
    rlgl.DrawRenderBatchActive()
    
    rlgl.DisableDepthTest()
    rlgl.ActiveDrawBuffers(1)
    rlgl.DisableFramebuffer()

    rlgl.MatrixMode(rlgl.PROJECTION)
    rlgl.PopMatrix()
    rlgl.LoadIdentity()
    rlgl.Ortho(0, f64(window_width), f64(window_height), 0, 0.0, 1.0)

    rlgl.MatrixMode(rlgl.MODELVIEW)
    rlgl.LoadIdentity()
}