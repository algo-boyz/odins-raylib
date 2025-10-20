package main

Triangle :: [9]int

Mesh :: struct {
    transformedVertices: []Vector3,
    transformedNormals: []Vector3,
    vertices: []Vector3,
    normals: []Vector3,
    uvs: []Vector2,
    triangles: []Triangle, 
}

MakeCube :: proc() -> Mesh {
    vertices := make([]Vector3, 8)
    vertices[0] = Vector3{-1.0, -1.0, -1.0}
    vertices[1] = Vector3{-1.0,  1.0, -1.0}
    vertices[2] = Vector3{ 1.0,  1.0, -1.0}
    vertices[3] = Vector3{ 1.0, -1.0, -1.0}
    vertices[4] = Vector3{ 1.0,  1.0,  1.0}
    vertices[5] = Vector3{ 1.0, -1.0,  1.0}
    vertices[6] = Vector3{-1.0,  1.0,  1.0}
    vertices[7] = Vector3{-1.0, -1.0,  1.0}

    normals := make([]Vector3, 6)
    normals[0] = {-0.0, -0.0, -1.0}
    normals[1] = { 1.0, -0.0, -0.0}
    normals[2] = {-0.0, -0.0,  1.0}
    normals[3] = {-1.0, -0.0, -0.0}
    normals[4] = {-0.0,  1.0, -0.0}
    normals[5] = {-0.0, -1.0, -0.0}

    uvs := make([]Vector2, 4)
    uvs[0] =  Vector2{0.0, 0.0}
    uvs[1] =  Vector2{0.0, 1.0}
    uvs[2] =  Vector2{1.0, 1.0}
    uvs[3] =  Vector2{1.0, 0.0}

    triangles := make([]Triangle, 12)
    // Front                 vert.     uvs       norm.
    triangles[0] =  Triangle{0, 1, 2,  0, 1, 2,  0, 0, 0}
    triangles[1] =  Triangle{0, 2, 3,  0, 2, 3,  0, 0, 0}
    // Right
    triangles[2] =  Triangle{3, 2, 4,  0, 1, 2,  1, 1, 1}
    triangles[3] =  Triangle{3, 4, 5,  0, 2, 3,  1, 1, 1}
    // Back
    triangles[4] =  Triangle{5, 4, 6,  0, 1, 2,  2, 2, 2}
    triangles[5] =  Triangle{5, 6, 7,  0, 2, 3,  2, 2, 2}
    // Left
    triangles[6] =  Triangle{7, 6, 1,  0, 1, 2,  3, 3, 3}
    triangles[7] =  Triangle{7, 1, 0,  0, 2, 3,  3, 3, 3}
    // Top
    triangles[8] =  Triangle{1, 6, 4,  0, 1, 2,  4, 4, 4}
    triangles[9] =  Triangle{1, 4, 2,  0, 2, 3,  4, 4, 4}
    // Bottom
    triangles[10] = Triangle{5, 7, 0,  0, 1, 2,  5, 5, 5}
    triangles[11] = Triangle{5, 0, 3,  0, 2, 3,  5, 5, 5}

    return Mesh{
        transformedVertices = make([]Vector3, 8),
        transformedNormals = make([]Vector3, 6),
        vertices = vertices,
        normals = normals,
        triangles = triangles,
        uvs = uvs
    }
}