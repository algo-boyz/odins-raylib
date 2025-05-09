package geno

import rl "vendor:raylib"
import rlgl "vendor:raylib/rlgl"

// Shadow Maps
ShadowLight :: struct {
    target: rl.Vector3,
    position: rl.Vector3,
    up: rl.Vector3,
    width: f64,
    height: f64,
    near: f64,
    far: f64,
}

load_shadow_map :: proc(width, height: i32) -> rl.RenderTexture2D {
    target: rl.RenderTexture2D
    target.id = rlgl.LoadFramebuffer(width, height)
    target.texture.width = width
    target.texture.height = height
    assert(target.id != 0)
    
    rlgl.EnableFramebuffer(target.id)

    target.depth.id = rlgl.LoadTextureDepth(width, height, false)
    target.depth.width = width
    target.depth.height = height
    target.depth.format = rl.PixelFormat.UNCOMPRESSED_R8G8B8A8  // DEPTH_COMPONENT_24BIT
    target.depth.mipmaps = 1
    rlgl.FramebufferAttach(
        target.id, 
        target.depth.id, 
        i32(rlgl.FramebufferAttachType.DEPTH), 
        i32(rlgl.FramebufferAttachTextureType.TEXTURE2D), 
        0)
    assert(rlgl.FramebufferComplete(target.id))

    rlgl.DisableFramebuffer()

    return target
}

unload_shadow_map :: proc(target: rl.RenderTexture2D) {
    if target.id > 0 {
        rlgl.UnloadFramebuffer(target.id)
    }
}

begin_shadow_map :: proc(target: rl.RenderTexture2D, shadow_light: ShadowLight) {
    rl.BeginTextureMode(target)
    rl.ClearBackground(rl.WHITE)
    
    rlgl.DrawRenderBatchActive()

    rlgl.MatrixMode(rlgl.PROJECTION)
    rlgl.PushMatrix()
    rlgl.LoadIdentity()

    rlgl.Ortho(
        -shadow_light.width/2, shadow_light.width/2, 
        -shadow_light.height/2, shadow_light.height/2, 
        shadow_light.near, shadow_light.far)

    rlgl.MatrixMode(rlgl.MODELVIEW)
    rlgl.LoadIdentity()

    mat_view := rl.MatrixLookAt(shadow_light.position, shadow_light.target, shadow_light.up)
    mat_view_array := [16]f32{
        mat_view[0][0], mat_view[0][1], mat_view[0][2], mat_view[0][3],
        mat_view[1][0], mat_view[1][1], mat_view[1][2], mat_view[1][3],
        mat_view[2][0], mat_view[2][1], mat_view[2][2], mat_view[2][3],
        mat_view[3][0], mat_view[3][1], mat_view[3][2], mat_view[3][3],
    }
    rlgl.MultMatrixf(&mat_view_array[0])

    rlgl.EnableDepthTest()
}

end_shadow_map :: proc() {
    rlgl.DrawRenderBatchActive()

    rlgl.MatrixMode(rlgl.PROJECTION)
    rlgl.PopMatrix()

    rlgl.MatrixMode(rlgl.MODELVIEW)
    rlgl.LoadIdentity()

    rlgl.DisableDepthTest()

    rl.EndTextureMode()
}

set_shader_value_shadow_map :: proc(shader: rl.Shader, loc_index: i32, target: rl.RenderTexture2D) {
    if loc_index > -1 {
        rlgl.EnableShader(shader.id)
        slot := i32(10)  // Can be anything 0 to 15, but 0 will probably be taken up
        rlgl.ActiveTextureSlot(slot)
        rlgl.EnableTexture(target.depth.id)
        rlgl.SetUniform(loc_index, &slot, i32(rl.ShaderUniformDataType.INT), 1)
    }
}