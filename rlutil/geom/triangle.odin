package geom

import "core:math"

import rl "vendor:raylib"

// http://blog.andreaskahler.com/2009/06/creating-icosphere-mesh-in-code.html

// Recursive method for subdividing each face of a polygon.
sub_divide_triangle :: proc(vertices: ^[dynamic]rl.Vector3, a, b, c: rl.Vector3, depth: u8) {
    // If we've reached the end, push the triangle face onto the vertices list and stop recursing.
    if (depth == 0)
    {
        append(vertices, a)
        append(vertices, b)
        append(vertices, c)
        return
    }
    /** For each triangle that's passed in, split it into 4 triangles and recursively subdivide those.
     *           a
     *           /\
     *          /  \
     *     ab  /----\  ca
     *        / \  / \
     *       /   \/   \
     *    b ------------ c
     *           bc
     */
    ab := rl.Vector3Normalize(a + b)
    bc := rl.Vector3Normalize(b + c)
    ca := rl.Vector3Normalize(c + a)

    sub_divide_triangle(vertices, a, ab, ca, depth - 1);
    sub_divide_triangle(vertices, b, bc, ab, depth - 1);
    sub_divide_triangle(vertices, ab, bc, ca, depth - 1);
    sub_divide_triangle(vertices, c, ca, bc, depth - 1);
}

/*
Generates a set of vertices for a regular unit-size triangulated icosphere.
The returned vertices form a triangle mesh that forms an approximation of a sphere.

subdivision_depth is currently capped at 9 just for sanity purposes. Here are the triangle counts at each depth:
  0 -> 20           5 -> 20480
  1 -> 80           6 -> 81920
  2 -> 320          7 -> 327680
  3 -> 1280         8 -> 1310720
  4 -> 5120         9 -> 5242880
Generally a depth of 3-6 will be sufficient for most purposes.
*/
generate_icosphere :: proc(subdivision_depth: u8) -> [dynamic]rl.Vector3 {
    ICOSAHEDRON_FACES :: 20

    // "phi" is the golden ratio, (1 + sqrt(5)) / 2
    phi := (1.0 + math.sqrt_f32(5.0)) * 0.5

    // Normalization factor to make the radius 1
    norm := 1.0 / math.sqrt_f32(1.0 + 1.0 / (phi * phi))
    
    // The 12 vertices of an icosahedron centered at the origin with edge length 1
    icosahedron_vertices := [12]rl.Vector3{
        // (+- 1, +- 1/phi, 0)
        {-norm, norm/phi, 0.0}, {norm, norm/phi, 0.0}, {-norm, -norm/phi, 0.0}, {norm, -norm/phi, 0.0},
        // (0, +- 1, +- 1/phi)
        {0.0, -norm, norm/phi}, {0.0, norm, norm/phi}, {0.0, -norm, -norm/phi}, {0.0, norm, -norm/phi},
        // (+- 1/phi, 0, +- 1)
        {norm/phi, 0.0, -norm}, {norm/phi, 0.0, norm}, {-norm/phi, 0.0, -norm}, {-norm/phi, 0.0, norm},
    }

    // The 20 triangles that make up the faces of the icosahedron
    face_indices := [ICOSAHEDRON_FACES][3]int{
        // The first 5 faces are around vertex 0
        {0, 11, 5}, {0, 5, 1}, {0, 1, 7}, {0, 7, 10}, {0, 10, 11},
        // The second 5 faces are the ones adjacent to those
        {1, 5, 9}, {5, 11, 4}, {11, 10, 2}, {10, 7, 6}, {7, 1, 8},
        // The third 5 faces are around vertex 3, which is directly opposite to vertex 0
        {3, 9, 4}, {3, 4, 2}, {3, 2, 6}, {3, 6, 8}, {3, 8, 9},
        // The final 5 faces are the ones adjacent to those
        {4, 9, 5}, {2, 4, 11}, {6, 2, 10}, {8, 6, 7}, {9, 8, 1},
    }

    // Cap the subdivision depth at 9
    capped_depth := min(subdivision_depth, 9)

    // Preallocate enough space for all the vertices we're going to generate
    sphere_vertices := make([dynamic]rl.Vector3, 0, ICOSAHEDRON_FACES * 3 * int(math.pow(4, f64(capped_depth))))

    // Generate the subdivided triangles for each face
    for face in 0..<ICOSAHEDRON_FACES {
        sub_divide_triangle(
            &sphere_vertices,
            icosahedron_vertices[face_indices[face][0]],
            icosahedron_vertices[face_indices[face][1]],
            icosahedron_vertices[face_indices[face][2]],
            capped_depth,
        )
    }

    return sphere_vertices
}