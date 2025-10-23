package obb

import m "core:math/linalg/glsl"

import gl "vendor:OpenGL"

OBB :: struct {
    min: m.vec3,
    max: m.vec3,
}

@(private)
obb_vao, obb_vbo, obb_ebo: u32

@(private)
init_obb :: proc() {
    indices := []u32{
        0, 1, 2, 2, 3, 0, // front
        1, 5, 6, 6, 2, 1, // right
        5, 4, 7, 7, 6, 5, // back
        4, 0, 3, 3, 7, 4, // left
        3, 2, 6, 6, 7, 3, // top
        4, 5, 1, 1, 0, 4, // bottom
    }
    gl.GenVertexArrays(1, &obb_vao)
    gl.GenBuffers(1, &obb_vbo)
    gl.GenBuffers(1, &obb_ebo)

    gl.BindVertexArray(obb_vao)
    gl.BindBuffer(gl.ARRAY_BUFFER, obb_vbo)
    gl.BufferData(gl.ARRAY_BUFFER, size_of(m.vec3) * 8, nil, gl.DYNAMIC_DRAW)

    gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, obb_ebo)
    gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, size_of(u32) * len(indices), raw_data(indices), gl.STATIC_DRAW)

    gl.EnableVertexAttribArray(0)
    gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, size_of(m.vec3), 0)

    gl.BindBuffer(gl.ARRAY_BUFFER, 0)
    gl.BindVertexArray(0)
}
