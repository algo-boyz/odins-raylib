package tracer

import "core:math"

import rl "vendor:raylib"
import rlgl "vendor:raylib/rlgl"

TracingParams :: struct {
    camera_position:     i32,
    camera_direction:    i32,
    screen_center:       i32,
    view_params:        i32,
    resolution:         i32,
    current_frame:      i32,
    previous_frame:     i32,
    num_rendered_frames: i32,
    rays_per_pixel:     i32,
    max_bounces:        i32,
    denoise:            i32,
    blur:               i32,
    pause:              i32,
}

PostParams :: struct {
    resolution: i32,
    denoise:    i32,
}

SkyMaterial :: struct {
    sky_color_zenith:   rl.Color,
    sky_color_horizon:  rl.Color,
    ground_color:       rl.Color,
    sun_color:          rl.Color,
    sun_direction:      rl.Vector3,
    sun_focus:          f32,
    sun_intensity:      f32,
}

Material :: struct {
    color:    rl.Vector4,
    emission: rl.Vector4,
    e_s_b_b:  rl.Vector4,  // Expanded name needed - original unclear
}

Sphere :: struct {
    position: rl.Vector3,
    radius:   f32,
    mat:      Material,
}

Triangle :: struct {
    pos_a:     rl.Vector3,
    padding_a: f32,
    pos_b:     rl.Vector3,
    padding_b: f32,
    pos_c:     rl.Vector3,
    padding_c: f32,
    normal_a:  rl.Vector3,
    padding_d: f32,
    normal_b:  rl.Vector3,
    padding_e: f32,
    normal_c:  rl.Vector3,
    padding_f: f32,
}

Mesh :: struct {
    first_triangle_index: i32,
    num_triangles:        i32,
    root_node_index:      i32,
    bvh_depth:           i32,
    material:            Material,
    bounding_min:        rl.Vector4,
    bounding_max:        rl.Vector4,
}

PaddedBoundingBox :: struct {
    min:      rl.Vector3,
    padding1: f32,
    max:      rl.Vector3,
    padding2: f32,
}

Node :: struct {
    bounds:         ^PaddedBoundingBox,
    triangle_index: i32,
    num_triangles:  i32,
    child_index:    i32,
    padding:        f32,
}

SphereBuffer :: struct {
    spheres: [4]Sphere,
}

TriangleBuffer :: struct {
    triangles: [500000]Triangle,
}

MeshBuffer :: struct {
    meshes: [10]Mesh,
}

NodeBuffer :: struct {
    nodes: [1000000]Node,
}

TracingEngine :: struct {
    raytracing_shader:              rl.Shader,
    post_shader:                    rl.Shader,
    raytracing_render_texture:      rl.RenderTexture2D,
    previouse_frame_render_texture: rl.RenderTexture2D,
    tracing_params:                 TracingParams,
    post_params:                    PostParams,
    resolution:                     rl.Vector2,
    num_rendered_frames:            i32,
    max_bounces:                    i32,
    rays_per_pixel:                i32,
    blur:                          f32,
    nodes:                         [dynamic]Node,
    root:                          Node,
    sphere_ssbo:                   u32,
    triangles_ssbo:                u32,
    meshes_ssbo:                   u32,
    nodes_ssbo:                    u32,
    mesh_buffer:                   MeshBuffer,
    triangle_buffer:               TriangleBuffer,
    node_buffer:                   NodeBuffer,
    total_triangles:               i32,
    total_meshes:                  i32,
    sphere_buffer:                 SphereBuffer,
    models:                        [dynamic]rl.Model,
    meshes:                        [dynamic]Mesh,
    triangles:                     [dynamic]Triangle,
    spheres:                       [dynamic]Sphere,
    debug:                         bool,
    denoise:                       bool,
    pause:                         bool,
    sky_material:                  SkyMaterial,
}

init :: proc(resolution: rl.Vector2, max_bounces, rays_per_pixel: i32, blur: f32) -> ^TracingEngine {
    engine := new(TracingEngine)
    
    engine.num_rendered_frames = 0
    engine.resolution = resolution
    engine.max_bounces = max_bounces
    engine.rays_per_pixel = rays_per_pixel
    engine.blur = blur

    engine.raytracing_render_texture = rl.LoadRenderTexture(i32(resolution.x), i32(resolution.y))
    engine.previouse_frame_render_texture = rl.LoadRenderTexture(i32(resolution.x), i32(resolution.y))

    engine.raytracing_shader = rl.LoadShader("", "../assets/raytracer.fs")
    engine.post_shader = rl.LoadShader("", "../assets/post.fs")

    // Initialize shader locations
    engine.tracing_params = TracingParams{
        camera_position = rl.GetShaderLocation(engine.raytracing_shader, "cameraPosition"),
        camera_direction = rl.GetShaderLocation(engine.raytracing_shader, "cameraDirection"),
        screen_center = rl.GetShaderLocation(engine.raytracing_shader, "screenCenter"),
        view_params = rl.GetShaderLocation(engine.raytracing_shader, "viewParams"),
        resolution = rl.GetShaderLocation(engine.raytracing_shader, "resolution"),
        num_rendered_frames = rl.GetShaderLocation(engine.raytracing_shader, "numRenderedFrames"),
        previous_frame = rl.GetShaderLocation(engine.raytracing_shader, "previousFrame"),
        rays_per_pixel = rl.GetShaderLocation(engine.raytracing_shader, "raysPerPixel"),
        max_bounces = rl.GetShaderLocation(engine.raytracing_shader, "maxBounces"),
        denoise = rl.GetShaderLocation(engine.raytracing_shader, "denoise"),
        blur = rl.GetShaderLocation(engine.raytracing_shader, "blur"),
        pause = rl.GetShaderLocation(engine.raytracing_shader, "pause"),
    }

    engine.post_params = PostParams{
        resolution = rl.GetShaderLocation(engine.post_shader, "resolution"),
        denoise = rl.GetShaderLocation(engine.post_shader, "denoise"),
    }

    screen_center := rl.Vector2{resolution.x / 2.0, resolution.y / 2.0}
    rl.SetShaderValue(engine.raytracing_shader, engine.tracing_params.screen_center, &screen_center, rl.ShaderUniformDataType.VEC2)
    rl.SetShaderValue(engine.raytracing_shader, engine.tracing_params.resolution, &engine.resolution, rl.ShaderUniformDataType.VEC2)
    rl.SetShaderValue(engine.post_shader, engine.post_params.resolution, &engine.resolution, rl.ShaderUniformDataType.VEC2)

    rl.SetShaderValue(engine.raytracing_shader, engine.tracing_params.rays_per_pixel, &engine.rays_per_pixel, rl.ShaderUniformDataType.INT)
    rl.SetShaderValue(engine.raytracing_shader, engine.tracing_params.max_bounces, &engine.max_bounces, rl.ShaderUniformDataType.INT)
    rl.SetShaderValue(engine.raytracing_shader, engine.tracing_params.blur, &engine.blur, rl.ShaderUniformDataType.FLOAT)

    // Initialize SSBOs
    engine.sphere_ssbo = u32(rlgl.LoadShaderBuffer(size_of(SphereBuffer), nil, rlgl.DYNAMIC_COPY))
    engine.meshes_ssbo = u32(rlgl.LoadShaderBuffer(size_of(MeshBuffer), nil, rlgl.DYNAMIC_COPY))
    engine.triangles_ssbo = u32(rlgl.LoadShaderBuffer(size_of(TriangleBuffer), nil, rlgl.DYNAMIC_COPY))
    engine.nodes_ssbo = u32(rlgl.LoadShaderBuffer(size_of(NodeBuffer), nil, rlgl.DYNAMIC_COPY))

    return engine
}

// Helper functions
triangle_center :: proc(triangle: ^Triangle) -> rl.Vector3 {
    return (triangle.pos_a + triangle.pos_b + triangle.pos_c) / 3
}

bounding_box_center :: proc(box: ^PaddedBoundingBox) -> rl.Vector3 {
    return (box.min + box.max) / 2
}

// Helper utilities for BVH generation
bounding_box_center_on_axis :: proc(box: ^PaddedBoundingBox, axis: int) -> f32 {
    center := bounding_box_center(box)
    switch axis {
    case 0:
        return center.x
    case 1:
        return center.y
    case 2:
        return center.z
    }
    return 0
}

triangle_center_on_axis :: proc(triangle: ^Triangle, axis: int) -> f32 {
    center := triangle_center(triangle)
    switch axis {
    case 0:
        return center.x
    case 1:
        return center.y
    case 2:
        return center.z
    }
    return 0
}

grow_to_include :: proc(box: ^PaddedBoundingBox, point: rl.Vector3) {
    temp := box^
    box.min = {
        math.min(temp.min.x, point.x),
        math.min(temp.min.y, point.y),
        math.min(temp.min.z, point.z),
    }
    box.max = {
        math.max(temp.max.x, point.x),
        math.max(temp.max.y, point.y),
        math.max(temp.max.z, point.z),
    }
}

grow_to_include_triangle :: proc(box: ^PaddedBoundingBox, triangle: Triangle) {
    grow_to_include(box, triangle.pos_a)
    grow_to_include(box, triangle.pos_b)
    grow_to_include(box, triangle.pos_c)
}

split_node :: proc(engine: ^TracingEngine, parent_index: int, depth: i32, max_depth: i32) {
    if depth == max_depth {
        return
    }

    engine.nodes[parent_index].child_index = i32(len(engine.nodes))

    size := engine.nodes[parent_index].bounds.max - engine.nodes[parent_index].bounds.min
    split_axis := 0
    if size.x > math.max(size.y, size.z) {
        split_axis = 0
    } else if size.y > size.z {
        split_axis = 1
    } else {
        split_axis = 2
    }
    
    split_pos := bounding_box_center_on_axis(engine.nodes[parent_index].bounds, split_axis)

    child_a := Node{
        triangle_index = engine.nodes[parent_index].triangle_index,
        bounds = &{
            min = bounding_box_center(engine.nodes[parent_index].bounds),
            max = bounding_box_center(engine.nodes[parent_index].bounds),
        },
    }
    
    child_b := Node{
        triangle_index = engine.nodes[parent_index].triangle_index,
        bounds = &{
            min = bounding_box_center(engine.nodes[parent_index].bounds),
            max = bounding_box_center(engine.nodes[parent_index].bounds),
        },
    }

    for i:i32; i < engine.nodes[parent_index].num_triangles; i += 1 {
        tri_index := engine.nodes[parent_index].triangle_index + i
        is_side_a := triangle_center_on_axis(&engine.triangles[tri_index], split_axis) < split_pos
        
        child := is_side_a ? &child_a : &child_b
        grow_to_include_triangle(child.bounds, engine.triangles[tri_index])
        child.num_triangles += 1

        if is_side_a {
            swap := child.triangle_index + child.num_triangles - 1
            engine.triangles[tri_index], engine.triangles[swap] = engine.triangles[swap], engine.triangles[tri_index]
            child_b.triangle_index += 1
        }
    }

    append(&engine.nodes, child_a)
    append(&engine.nodes, child_b)

    split_node(engine, len(engine.nodes)-2, depth + 1, max_depth)
    split_node(engine, len(engine.nodes)-1, depth + 1, max_depth)
}

generate_bvhs :: proc(engine: ^TracingEngine) {
    triangle_offset:i32

    for mesh, i in engine.meshes {
        bounds := PaddedBoundingBox{
            min = {mesh.bounding_min.x, mesh.bounding_min.y, mesh.bounding_min.z},
            max = {mesh.bounding_max.x, mesh.bounding_max.y, mesh.bounding_max.z},
        }

        root := Node{
            bounds = &bounds,
            triangle_index = mesh.first_triangle_index,
            num_triangles = mesh.num_triangles,
        }

        append(&engine.nodes, root)
        engine.meshes[i].root_node_index = i32(len(engine.nodes) - 1)
        triangle_offset += mesh.num_triangles

        split_node(engine, len(engine.nodes) - 1, 0, mesh.bvh_depth)
    }

    // Copy nodes to buffer
    for node, i in engine.nodes {
        engine.node_buffer.nodes[i] = node
    }
}

color_to_vector4 :: proc(color: rl.Color) -> rl.Vector4 {
    return {
        f32(color.r) / 255.0,
        f32(color.g) / 255.0,
        f32(color.b) / 255.0,
        f32(color.a) / 255.0,
    }
}

upload_sky :: proc(engine: ^TracingEngine) {
    sky_color_zenith_loc := rl.GetShaderLocation(engine.raytracing_shader, "skyMaterial.skyColorZenith")
    sky_color_horizon_loc := rl.GetShaderLocation(engine.raytracing_shader, "skyMaterial.skyColorHorizon")
    ground_color_loc := rl.GetShaderLocation(engine.raytracing_shader, "skyMaterial.groundColor")
    sun_color_loc := rl.GetShaderLocation(engine.raytracing_shader, "skyMaterial.sunColor")
    sun_direction_loc := rl.GetShaderLocation(engine.raytracing_shader, "skyMaterial.sunDirection")
    sun_focus_loc := rl.GetShaderLocation(engine.raytracing_shader, "skyMaterial.sunFocus")
    sun_intensity_loc := rl.GetShaderLocation(engine.raytracing_shader, "skyMaterial.sunIntensity")

    sky_color_zenith := color_to_vector4(engine.sky_material.sky_color_zenith)
    sky_color_horizon := color_to_vector4(engine.sky_material.sky_color_horizon)
    ground_color := color_to_vector4(engine.sky_material.ground_color)
    sun_color := color_to_vector4(engine.sky_material.sun_color)

    rl.SetShaderValue(engine.raytracing_shader, sky_color_zenith_loc, &sky_color_zenith, rlgl.ShaderUniformDataType.VEC4)
    rl.SetShaderValue(engine.raytracing_shader, sky_color_horizon_loc, &sky_color_horizon, rlgl.ShaderUniformDataType.VEC4)
    rl.SetShaderValue(engine.raytracing_shader, ground_color_loc, &ground_color, rlgl.ShaderUniformDataType.VEC4)
    rl.SetShaderValue(engine.raytracing_shader, sun_color_loc, &sun_color, rlgl.ShaderUniformDataType.VEC4)
    rl.SetShaderValue(engine.raytracing_shader, sun_direction_loc, &engine.sky_material.sun_direction, rlgl.ShaderUniformDataType.VEC3)
    rl.SetShaderValue(engine.raytracing_shader, sun_focus_loc, &engine.sky_material.sun_focus, rlgl.ShaderUniformDataType.FLOAT)
    rl.SetShaderValue(engine.raytracing_shader, sun_intensity_loc, &engine.sky_material.sun_intensity, rlgl.ShaderUniformDataType.FLOAT)
}

upload_ssbos :: proc(engine: ^TracingEngine) {
    rlgl.UpdateShaderBuffer(engine.sphere_ssbo, &engine.sphere_buffer, size_of(SphereBuffer), 0)
    rlgl.UpdateShaderBuffer(engine.meshes_ssbo, &engine.mesh_buffer, size_of(MeshBuffer), 0)
    rlgl.UpdateShaderBuffer(engine.triangles_ssbo, &engine.triangle_buffer, size_of(TriangleBuffer), 0)
    rlgl.UpdateShaderBuffer(engine.nodes_ssbo, &engine.node_buffer, size_of(NodeBuffer), 0)

    rlgl.EnableShader(engine.raytracing_shader.id)
    rlgl.BindShaderBuffer(u32(engine.sphere_ssbo), 1)
    rlgl.BindShaderBuffer(engine.meshes_ssbo, 2)
    rlgl.BindShaderBuffer(engine.triangles_ssbo, 3)
    rlgl.BindShaderBuffer(engine.nodes_ssbo, 4)
    rlgl.DisableShader()
}

upload_spheres :: proc(engine: ^TracingEngine) {
    for sphere, i in engine.spheres {
        if i < len(engine.sphere_buffer.spheres) {
            engine.sphere_buffer.spheres[i] = sphere
        }
    }
}

upload_triangles :: proc(engine: ^TracingEngine) {
    for triangle, i in engine.triangles {
        if i < len(engine.triangle_buffer.triangles) {
            engine.triangle_buffer.triangles[i] = triangle
        }
    }
}

upload_meshes :: proc(engine: ^TracingEngine) {
    for mesh, i in engine.meshes {
        if i < len(engine.mesh_buffer.meshes) {
            engine.mesh_buffer.meshes[i] = mesh
        }
    }
}

// https://github.com/raysan5/raylib/issues/4454
// https://github.com/raysan5/raylib/blob/a1de60f3ba253ce59b2e6fa5cdb69c15eaadc1cb/src/raymath.h#L2540
// Decompose a transformation matrix into its rotational, translational and scaling components
// MatrixDecompose :: proc "c" (mat: Matrix) -> (translation: Vector3, rotation: Quaternion, scale: Vector3) {
//     // Extract translation
//     translation.x = mat[0, 3]  // m03
//     translation.y = mat[1, 3]  // m13
//     translation.z = mat[2, 3]  // m23

//     // Extract upper-left for determinant computation
//     a := mat[0, 0]  // m00
//     b := mat[0, 1]  // m01
//     c := mat[0, 2]  // m02
//     d := mat[1, 0]  // m10
//     e := mat[1, 1]  // m11
//     f := mat[1, 2]  // m12
//     g := mat[2, 0]  // m20
//     h := mat[2, 1]  // m21
//     i := mat[2, 2]  // m22

//     A := e*i - f*h
//     B := f*g - d*i
//     C := d*h - e*g

//     // Extract scale
//     det := a*A + b*B + c*C
//     abc := Vector3{a, b, c}
//     def := Vector3{d, e, f}
//     ghi := Vector3{g, h, i}

//     scalex := Vector3Length(abc)
//     scaley := Vector3Length(def)
//     scalez := Vector3Length(ghi)
//     s := Vector3{scalex, scaley, scalez}

//     if det < 0 {
//         s = -s
//     }

//     scale = s

//     // Remove scale from the matrix if it is not close to zero
//     clone := mat
//     if !FloatEquals(det, 0) {
//         clone[0, 0] /= s.x
//         clone[0, 1] /= s.x
//         clone[0, 2] /= s.x
//         clone[1, 0] /= s.y
//         clone[1, 1] /= s.y
//         clone[1, 2] /= s.y
//         clone[2, 0] /= s.z
//         clone[2, 1] /= s.z
//         clone[2, 2] /= s.z

//         // Extract rotation
//         rotation = QuaternionFromMatrix(clone)
//     } else {
//         // Set to identity if close to zero
//         rotation = 1
//     }

//     return translation, rotation, scale
// }

MatrixDecompose :: proc "c" (mat: rl.Matrix) -> (translation: rl.Vector3, rotation: rl.Quaternion, scale: rl.Vector3) {
    // Extract translation
    translation.x = mat[0, 3]  // m03
    translation.y = mat[1, 3]  // m13
    translation.z = mat[2, 3]  // m23

    // Extract upper-left for determinant computation
    a := mat[0, 0]  // m00
    b := mat[0, 1]  // m01
    c := mat[0, 2]  // m02
    d := mat[1, 0]  // m10
    e := mat[1, 1]  // m11
    f := mat[1, 2]  // m12
    g := mat[2, 0]  // m20
    h := mat[2, 1]  // m21
    i := mat[2, 2]  // m22

    A := e*i - f*h
    B := f*g - d*i
    C := d*h - e*g

    // Extract scale
    det := a*A + b*B + c*C
    abc := rl.Vector3{a, b, c}
    def := rl.Vector3{d, e, f}
    ghi := rl.Vector3{g, h, i}

    scalex := rl.Vector3Length(abc)
    scaley := rl.Vector3Length(def)
    scalez := rl.Vector3Length(ghi)
    s := rl.Vector3{scalex, scaley, scalez}

    if det < 0 {
        s = -s
    }

    scale = s

    // Remove scale from the matrix if it is not close to zero
    clone := mat
    if !rl.FloatEquals(det, 0) {
        clone[0, 0] /= s.x
        clone[0, 1] /= s.x
        clone[0, 2] /= s.x
        clone[1, 0] /= s.y
        clone[1, 1] /= s.y
        clone[1, 2] /= s.y
        clone[2, 0] /= s.z
        clone[2, 1] /= s.z
        clone[2, 2] /= s.z

        // Extract rotation
        rotation = rl.QuaternionFromMatrix(clone)
    } else {
        // Set to identity if close to zero
        rotation = 1
    }

    return translation, rotation, scale
}

upload_raylib_model :: proc(engine: ^TracingEngine, model: rl.Model, material: Material, indexed: bool, bvh_depth: i32) {
    for mesh_idx:i32; mesh_idx < model.meshCount; mesh_idx += 1 {
        mesh := model.meshes[mesh_idx]
        bounds := rl.GetMeshBoundingBox(mesh)
        
        position, rotation, scale := MatrixDecompose(model.transform)
        
        bounds.min = bounds.min + position
        bounds.max = bounds.max + position
        
        first_tri_index := engine.total_triangles
        
        if indexed {
            for i:i32; i < mesh.triangleCount; i += 1 {
                tri: Triangle
                
                // Get indices for the triangle
                idx1 := mesh.indices[i * 3]
                idx2 := mesh.indices[i * 3 + 1]
                idx3 := mesh.indices[i * 3 + 2]
                
                // Transform vertices
                temp1 := rl.Vector3Transform(
                    (^rl.Vector3)(&mesh.vertices[idx1 * 3])^,
                    model.transform,
                )
                temp2 := rl.Vector3Transform(
                    (^rl.Vector3)(&mesh.vertices[idx2 * 3])^,
                    model.transform,
                )
                temp3 := rl.Vector3Transform(
                    (^rl.Vector3)(&mesh.vertices[idx3 * 3])^,
                    model.transform,
                )
                
                tri.pos_a = temp1
                tri.pos_b = temp2
                tri.pos_c = temp3
                
                // Transform normals
                temp_a := rl.Vector3RotateByQuaternion(
                    (^rl.Vector3)(&mesh.normals[idx1 * 3])^,
                    rotation,
                )
                temp_b := rl.Vector3RotateByQuaternion(
                    (^rl.Vector3)(&mesh.normals[idx2 * 3])^,
                    rotation,
                )
                temp_c := rl.Vector3RotateByQuaternion(
                    (^rl.Vector3)(&mesh.normals[idx3 * 3])^,
                    rotation,
                )
                
                tri.normal_a = temp_a
                tri.normal_b = temp_b
                tri.normal_c = temp_c
                
                append(&engine.triangles, tri)
                engine.total_triangles += 1
            }
        } else {
            for i:i32; i < mesh.triangleCount; i += 1 {
                tri: Triangle
                
                idx1 := i * 3
                idx2 := i * 3 + 1
                idx3 := i * 3 + 2
                
                // Transform vertices
                temp1 := rl.Vector3Transform(
                    (^rl.Vector3)(&mesh.vertices[idx1 * 3])^,
                    model.transform,
                )
                temp2 := rl.Vector3Transform(
                    (^rl.Vector3)(&mesh.vertices[idx2 * 3])^,
                    model.transform,
                )
                temp3 := rl.Vector3Transform(
                    (^rl.Vector3)(&mesh.vertices[idx3 * 3])^,
                    model.transform,
                )
                
                tri.pos_a = temp1
                tri.pos_b = temp2
                tri.pos_c = temp3
                
                // Transform normals
                temp_a := rl.Vector3RotateByQuaternion(
                    (^rl.Vector3)(&mesh.normals[idx1 * 3])^,
                    rotation,
                )
                temp_b := rl.Vector3RotateByQuaternion(
                    (^rl.Vector3)(&mesh.normals[idx2 * 3])^,
                    rotation,
                )
                temp_c := rl.Vector3RotateByQuaternion(
                    (^rl.Vector3)(&mesh.normals[idx3 * 3])^,
                    rotation,
                )
                
                tri.normal_a = temp_a
                tri.normal_b = temp_b
                tri.normal_c = temp_c
                
                append(&engine.triangles, tri)
                engine.total_triangles += 1
            }
        }
        
        rmesh := Mesh{
            first_triangle_index = first_tri_index,
            num_triangles = mesh.triangleCount,
            bvh_depth = bvh_depth,
            material = material,
            bounding_min = {bounds.min.x, bounds.min.y, bounds.min.z, 0},
            bounding_max = {bounds.max.x, bounds.max.y, bounds.max.z, 0},
        }
        
        append(&engine.meshes, rmesh)
    }
    
    append(&engine.models, model)
}

upload_static_data :: proc(engine: ^TracingEngine) {
    upload_spheres(engine)
    upload_sky(engine)
    
    generate_bvhs(engine)
    upload_triangles(engine)
    upload_meshes(engine)
    
    upload_ssbos(engine)
}

upload_data :: proc(engine: ^TracingEngine, camera: ^rl.Camera3D) {
    plane_height := 0.01 * math.tan_f32(camera.fovy * 0.5 * rl.DEG2RAD) * 2
    plane_width := plane_height * (engine.resolution.x / engine.resolution.y)
    view_params := rl.Vector3{plane_width, plane_height, 0.01}
    
    rl.SetShaderValue(engine.raytracing_shader, engine.tracing_params.view_params, &view_params, rlgl.ShaderUniformDataType.VEC3)
    
    if engine.denoise {
        if !engine.pause {
            engine.num_rendered_frames += 1
        }
    } else {
        engine.num_rendered_frames = 0
    }
    
    rl.SetShaderValue(engine.raytracing_shader, engine.tracing_params.num_rendered_frames, &engine.num_rendered_frames, rlgl.ShaderUniformDataType.INT)
    rl.SetShaderValue(engine.raytracing_shader, engine.tracing_params.camera_position, &camera.position, rlgl.ShaderUniformDataType.VEC3)
    
    cam_dist := 1.0 / math.tan_f32(camera.fovy * 0.5 * rl.DEG2RAD)
    target_diff := camera.target - camera.position
    cam_dir := rl.Vector3Normalize(target_diff) * cam_dist
    
    rl.SetShaderValue(engine.raytracing_shader, engine.tracing_params.camera_direction, &cam_dir, rlgl.ShaderUniformDataType.VEC3)
    rl.SetShaderValue(engine.raytracing_shader, engine.tracing_params.denoise, &engine.denoise, rlgl.ShaderUniformDataType.INT)
    rl.SetShaderValue(engine.raytracing_shader, engine.tracing_params.pause, &engine.pause, rlgl.ShaderUniformDataType.INT)
    rl.SetShaderValue(engine.post_shader, engine.post_params.denoise, &engine.denoise, rlgl.ShaderUniformDataType.INT)
}

draw_debug_bounds :: proc(box: ^PaddedBoundingBox, color: rl.Color) {
    dimensions := box.max - box.min
    center := bounding_box_center(box)
    rl.DrawCubeWires(center, dimensions.x, dimensions.y, dimensions.z, color)
}

draw_debug :: proc(engine: ^TracingEngine, camera: ^rl.Camera3D) {
    rl.BeginMode3D(camera^)
    
    for sphere in engine.spheres {
        rl.DrawSphereWires(sphere.position, sphere.radius, 10, 10, rl.RED)
    }
    
    for node in engine.nodes {
        if node.child_index == 0 {
            draw_debug_bounds(node.bounds, rl.ORANGE)
        }
    }
    
    rl.DrawGrid(10, 1)
    
    rl.EndMode3D()
    
    rl.DrawFPS(10, 10)
    rl.DrawText(rl.TextFormat("triangles: %d", len(engine.triangles)), 10, 30, 20, rl.RED)
    rl.DrawText(rl.TextFormat("nodes: %d", len(engine.nodes)), 10, 50, 20, rl.RED)
    
    if engine.debug do rl.DrawText("DEBUG MODE ACTIVE", 10, 70, 20, rl.WHITE)
    if !engine.pause && engine.denoise do rl.DrawText("TEMPORAL DENOISING ACTIVE", 10, 90, 20, rl.WHITE)
    if engine.pause && engine.denoise do rl.DrawText("STATIC DENOISING ACTIVE", 10, 90, 20, rl.WHITE)
    if engine.pause && !engine.denoise do rl.DrawText("PAUSED", 10, 90, 20, rl.WHITE)
}

render :: proc(engine: ^TracingEngine, camera: ^rl.Camera3D) {
    rl.BeginTextureMode(engine.raytracing_render_texture)
    rl.ClearBackground(rl.BLACK)
    
    rlgl.EnableDepthTest()
    rl.BeginShaderMode(engine.raytracing_shader)
    
    rl.DrawTextureRec(
        engine.previouse_frame_render_texture.texture,
        {0, 0, engine.resolution.x, -engine.resolution.y},
        {0, 0},
        rl.WHITE,
    )
    
    rl.EndShaderMode()
    rl.EndTextureMode()
    
    rl.BeginDrawing()
    rl.ClearBackground(rl.BLACK)
    
    if engine.denoise && engine.pause {
        rl.BeginShaderMode(engine.post_shader)
        rl.DrawTextureRec(
            engine.raytracing_render_texture.texture,
            {0, 0, engine.resolution.x, -engine.resolution.y},
            {0, 0},
            rl.WHITE,
        )
        rl.EndShaderMode()
    } else {
        rl.DrawTextureRec(
            engine.raytracing_render_texture.texture,
            {0, 0, engine.resolution.x, -engine.resolution.y},
            {0, 0},
            rl.WHITE,
        )
    }
    
    if engine.debug {
        draw_debug(engine, camera)
    }
    
    rl.EndDrawing()
    
    rl.BeginTextureMode(engine.previouse_frame_render_texture)
    rl.ClearBackground(rl.WHITE)
    rl.DrawTextureRec(
        engine.raytracing_render_texture.texture,
        {0, 0, engine.resolution.x, -engine.resolution.y},
        {0, 0},
        rl.WHITE,
    )
    rl.EndTextureMode()
}

unload :: proc(engine: ^TracingEngine) {
    rl.UnloadRenderTexture(engine.raytracing_render_texture)
    rl.UnloadShader(engine.raytracing_shader)
    delete(engine.nodes)
    delete(engine.models)
    delete(engine.meshes)
    delete(engine.triangles)
    delete(engine.spheres)
    free(engine)
}
