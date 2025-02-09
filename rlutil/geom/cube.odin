package geom

import rl "vendor:raylib"
import rlgl "vendor:raylib/rlgl"

/*
 *  Adapted from https://github.com/raysan5/raylib/blob/master/examples/models/models_draw_cube_texture.c
 *  Since this is no longer a part of Raylib core itself
 */

draw_cube_texture :: proc(
    texture: rl.Texture2D,
    position: rl.Vector3,
    width, height, length: f32,
    color: rl.Color,
) {
    x := position.x
    y := position.y
    z := position.z

    rlgl.SetTexture(texture.id)

    rlgl.Begin(rlgl.QUADS)

    rlgl.Color4ub(color.r, color.g, color.b, color.a)
    // Front Face
    rlgl.Normal3f(0.0, 0.0, 1.0) // Normal Pointing Towards Viewer
    rlgl.TexCoord2f(0.0, 0.0)
    rlgl.Vertex3f(x - width / 2, y - height / 2, z + length / 2) // Bottom Left Of The Texture and Quad
    rlgl.TexCoord2f(1.0, 0.0)
    rlgl.Vertex3f(x + width / 2, y - height / 2, z + length / 2) // Bottom Right Of The Texture and Quad
    rlgl.TexCoord2f(1.0, 1.0)
    rlgl.Vertex3f(x + width / 2, y + height / 2, z + length / 2) // Top Right Of The Texture and Quad
    rlgl.TexCoord2f(0.0, 1.0)
    rlgl.Vertex3f(x - width / 2, y + height / 2, z + length / 2) // Top Left Of The Texture and Quad
    // Back Face
    rlgl.Normal3f(0.0, 0.0, -1.0) // Normal Pointing Away From Viewer
    rlgl.TexCoord2f(1.0, 0.0)
    rlgl.Vertex3f(x - width / 2, y - height / 2, z - length / 2) // Bottom Right Of The Texture and Quad
    rlgl.TexCoord2f(1.0, 1.0)
    rlgl.Vertex3f(x - width / 2, y + height / 2, z - length / 2) // Top Right Of The Texture and Quad
    rlgl.TexCoord2f(0.0, 1.0)
    rlgl.Vertex3f(x + width / 2, y + height / 2, z - length / 2) // Top Left Of The Texture and Quad
    rlgl.TexCoord2f(0.0, 0.0)
    rlgl.Vertex3f(x + width / 2, y - height / 2, z - length / 2) // Bottom Left Of The Texture and Quad
    // Top Face
    rlgl.Normal3f(0.0, 1.0, 0.0) // Normal Pointing Up
    rlgl.TexCoord2f(0.0, 1.0)
    rlgl.Vertex3f(x - width / 2, y + height / 2, z - length / 2) // Top Left Of The Texture and Quad
    rlgl.TexCoord2f(0.0, 0.0)
    rlgl.Vertex3f(x - width / 2, y + height / 2, z + length / 2) // Bottom Left Of The Texture and Quad
    rlgl.TexCoord2f(1.0, 0.0)
    rlgl.Vertex3f(x + width / 2, y + height / 2, z + length / 2) // Bottom Right Of The Texture and Quad
    rlgl.TexCoord2f(1.0, 1.0)
    rlgl.Vertex3f(x + width / 2, y + height / 2, z - length / 2) // Top Right Of The Texture and Quad
    // Bottom Face
    rlgl.Normal3f(0.0, -1.0, 0.0) // Normal Pointing Down
    rlgl.TexCoord2f(1.0, 1.0)
    rlgl.Vertex3f(x - width / 2, y - height / 2, z - length / 2) // Top Right Of The Texture and Quad
    rlgl.TexCoord2f(0.0, 1.0)
    rlgl.Vertex3f(x + width / 2, y - height / 2, z - length / 2) // Top Left Of The Texture and Quad
    rlgl.TexCoord2f(0.0, 0.0)
    rlgl.Vertex3f(x + width / 2, y - height / 2, z + length / 2) // Bottom Left Of The Texture and Quad
    rlgl.TexCoord2f(1.0, 0.0)
    rlgl.Vertex3f(x - width / 2, y - height / 2, z + length / 2) // Bottom Right Of The Texture and Quad
    // Right face
    rlgl.Normal3f(1.0, 0.0, 0.0) // Normal Pointing Right
    rlgl.TexCoord2f(1.0, 0.0)
    rlgl.Vertex3f(x + width / 2, y - height / 2, z - length / 2) // Bottom Right Of The Texture and Quad
    rlgl.TexCoord2f(1.0, 1.0)
    rlgl.Vertex3f(x + width / 2, y + height / 2, z - length / 2) // Top Right Of The Texture and Quad
    rlgl.TexCoord2f(0.0, 1.0)
    rlgl.Vertex3f(x + width / 2, y + height / 2, z + length / 2) // Top Left Of The Texture and Quad
    rlgl.TexCoord2f(0.0, 0.0)
    rlgl.Vertex3f(x + width / 2, y - height / 2, z + length / 2) // Bottom Left Of The Texture and Quad
    // Left Face
    rlgl.Normal3f(-1.0, 0.0, 0.0) // Normal Pointing Left
    rlgl.TexCoord2f(0.0, 0.0)
    rlgl.Vertex3f(x - width / 2, y - height / 2, z - length / 2) // Bottom Left Of The Texture and Quad
    rlgl.TexCoord2f(1.0, 0.0)
    rlgl.Vertex3f(x - width / 2, y - height / 2, z + length / 2) // Bottom Right Of The Texture and Quad
    rlgl.TexCoord2f(1.0, 1.0)
    rlgl.Vertex3f(x - width / 2, y + height / 2, z + length / 2) // Top Right Of The Texture and Quad
    rlgl.TexCoord2f(0.0, 1.0)
    rlgl.Vertex3f(x - width / 2, y + height / 2, z - length / 2) // Top Left Of The Texture and Quad

    rlgl.End()
    rlgl.SetTexture(0)
}