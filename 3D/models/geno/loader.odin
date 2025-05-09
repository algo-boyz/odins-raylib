package geno

import "base:runtime"
import end "core:encoding/endian"
import "core:fmt"
import "core:math"
import "core:mem"
import "core:os"
import "core:strings"
import "core:slice"

import rl "vendor:raylib"

BoneInfo :: struct {
    name: [32]u8,
    parent: i32,
}

Transform :: struct {
    translation: rl.Vector3,
    rotation: rl.Quaternion,
    scale: rl.Vector3,
}

load_model :: proc(filepath: string) -> (rl.Model) {
    model: rl.Model
    data, ok := os.read_entire_file(filepath)
    if !ok {
        fmt.println("ERROR: Unable to read model file:", filepath)
        return model
    }
    defer delete(data)

    // Initialize model with zero values
    model.transform = rl.Matrix(1)
    model.materials = make([^]rl.Material, 1)
    model.materials[0] = rl.LoadMaterialDefault()
    model.materialCount = 1
    
    // Initialize meshes
    model.meshes = make([^]rl.Mesh, 1)
    model.meshes[0] = {}  // Zero initialize the mesh structure
    model.meshCount = 1
    
    model.meshMaterial = make([^]i32, 1)
    model.meshMaterial[0] = 0

    // Read header information
    offset:i32
    vertexCount, _ := end.get_i32(data[offset:], end.Byte_Order.Little)
    offset += 4
    triangleCount, _ := end.get_i32(data[offset:], end.Byte_Order.Little)
    offset += 4
    boneCount, _ := end.get_i32(data[offset:], end.Byte_Order.Little)
    offset += 4

    model.meshes[0].vertexCount = vertexCount
    model.meshes[0].triangleCount = triangleCount
    model.boneCount = boneCount
    model.meshes[0].boneCount = boneCount
    
    // Allocate arrays
    vertices := make([^]f32, vertexCount * 3)
    texcoords := make([^]f32, vertexCount * 2)
    normals := make([^]f32, vertexCount * 3)
    boneIds := make([^]u8, vertexCount * 4)
    boneWeights := make([^]f32, vertexCount * 4)
    indices := make([^]u16, triangleCount * 3)
    size3 := int(vertexCount * 3 * size_of(f32))
    size2 := int(vertexCount * 3 * size_of(f32))
    size4 := int(vertexCount * 4 * size_of(f32))
    tSize := int(triangleCount * 3 * size_of(u16))
    // Convert raw data to slices for vertices
    vertex_data := mem.slice_ptr(([^]u8)(&data[offset]), size3)
    mem.copy(([^]u8)(vertices), &vertex_data[0], size3)
    offset += vertexCount * 3 * size_of(f32)
    
    // Convert raw data to slices for texcoords
    texcoord_data := mem.slice_ptr(([^]u8)(&data[offset]), size2)
    mem.copy(([^]u8)(texcoords), &texcoord_data[0], size2)
    offset += vertexCount * 2 * size_of(f32)
    
    // Convert raw data to slices for normals
    normal_data := mem.slice_ptr(([^]u8)(&data[offset]), size3)
    mem.copy(([^]u8)(normals), &normal_data[0], size3)
    offset += vertexCount * 3 * size_of(f32)
    
    // Convert raw data to slices for boneIds
    boneid_data := mem.slice_ptr(([^]u8)(&data[offset]), int(vertexCount * 4))
    mem.copy(boneIds, &boneid_data[0], int(vertexCount * 4))
    offset += vertexCount * 4
    
    // Convert raw data to slices for boneWeights
    boneweight_data := mem.slice_ptr(([^]u8)(&data[offset]), size4)
    mem.copy(([^]u8)(boneWeights), &boneweight_data[0], size4)
    offset += vertexCount * 4 * size_of(f32)
    
    // Convert raw data to slices for indices
    index_data := mem.slice_ptr(([^]u8)(&data[offset]), tSize)
    mem.copy(([^]u8)(indices), &index_data[0], tSize)
    offset += triangleCount * 3 * size_of(u16)

    // Assign arrays to mesh
    model.meshes[0].vertices = vertices
    model.meshes[0].texcoords = texcoords
    model.meshes[0].normals = normals
    model.meshes[0].boneIds = boneIds
    model.meshes[0].boneWeights = boneWeights
    model.meshes[0].indices = indices

    // Create and copy animation vertices/normals
    animVertices := make([^]f32, vertexCount * 3)
    mem.copy(([^]u8)(animVertices), ([^]u8)(vertices), size3)
    model.meshes[0].animVertices = animVertices

    animNormals := make([^]f32, vertexCount * 3)
    mem.copy(([^]u8)(animNormals), ([^]u8)(normals), size3)
    model.meshes[0].animNormals = animNormals

    // Read bones and transforms
    bSize := int(boneCount * size_of(rl.BoneInfo))
    bones := make([^]rl.BoneInfo, boneCount)
    bone_data := mem.slice_ptr(([^]u8)(&data[offset]), bSize)
    mem.copy(([^]u8)(bones), &bone_data[0], bSize)
    offset += boneCount * size_of(rl.BoneInfo)
    model.bones = bones

    pSize := int(boneCount * size_of(rl.Transform))
    poses := make([^]rl.Transform, boneCount)
    pose_data := mem.slice_ptr(([^]u8)(&data[offset]), pSize)
    mem.copy(([^]u8)(poses), &pose_data[0], pSize)
    offset += boneCount * size_of(rl.Transform)
    model.bindPose = poses

    // Initialize bone matrices
    boneMatrices := make([^]rl.Matrix, boneCount)
    for i in 0..<boneCount {
        boneMatrices[i] = rl.Matrix(1)
    }
    model.meshes[0].boneMatrices = boneMatrices

    rl.UploadMesh(&model.meshes[0], true)

    return model
}

load_empty_animation :: proc(model: rl.Model) -> rl.ModelAnimation {
    animation: rl.ModelAnimation
    animation.frameCount = 1
    animation.boneCount = model.boneCount
    animation.bones = model.bones
    animation.framePoses = make([^][^]rl.Transform, animation.frameCount)
    for i in 0..<animation.frameCount {
        animation.framePoses[i] = model.bindPose
    }
    return animation
}

load_animation :: proc(filepath: string) -> (rl.ModelAnimation) {
    animation: rl.ModelAnimation
    data, ok := os.read_entire_file(filepath)
    if !ok {
        fmt.println("ERROR: Unable to read animation file:", filepath)
        return animation
    }
    defer delete(data)
    // Read frame count and bone count
    frameCount, _ := end.get_i32(data, end.Byte_Order.Little)
    animation.frameCount = frameCount
    boneCount, _ := end.get_i32(data[4:], end.Byte_Order.Little)
    animation.boneCount = boneCount
    offset:i32 = 8  // After reading the two integers
    // Read bones
    bones := make([^]rl.BoneInfo, boneCount)
    for i in 0..<boneCount {
        bones[i] = read_bone(&data, &offset)
    }
    animation.bones = bones
    // Allocate and read frame poses
    framePoses := make([^][^]rl.Transform, frameCount)
    for i in 0..<frameCount {
        // Allocate transforms for each bone in this frame
        poses := make([^]rl.Transform, boneCount)
        // Read transforms for each bone
        for j in 0..<boneCount {
            poses[j] = read_pose(&data, &offset)
        }
        framePoses[i] = poses
    }
    animation.framePoses = framePoses

    return animation
}

read_bone :: proc(data: ^[]u8, position: ^i32) -> rl.BoneInfo {
    offset := position^
    // Read name as fixed [32]byte array
    name: [32]byte
    copy(name[:], data[offset:offset+32])
    offset += 32
    // Read parent as c.int
    parent, _ := end.get_i32(data[offset:], end.Byte_Order.Little)
    offset += 4
    return rl.BoneInfo{
        name = name,
        parent = parent,
    }
}

read_pose :: proc(data: ^[]u8, position: ^i32) -> rl.Transform {
    offset := position^
    // fmt.println("Raw bytes at offset", offset, ":")
    // for i:i32 = 0; i < 40; i += 4 {
    //     value, _ := end.get_f32(data[offset + i:], end.Byte_Order.Little)
        // fmt.printf("Bytes %d-%d: %f\n", i, i+3, value)
    // }

    // Read translation Vector3
    translation_x, _ := end.get_f32(data[offset:], end.Byte_Order.Little)
    offset += 4
    translation_y, _ := end.get_f32(data[offset:], end.Byte_Order.Little)
    offset += 4
    translation_z, _ := end.get_f32(data[offset:], end.Byte_Order.Little)
    offset += 4
    // Read rotation Quaternion
    rotation_x, _ := end.get_f32(data[offset:], end.Byte_Order.Little)
    offset += 4
    rotation_y, _ := end.get_f32(data[offset:], end.Byte_Order.Little)
    offset += 4
    rotation_z, _ := end.get_f32(data[offset:], end.Byte_Order.Little)
    offset += 4
    rotation_w, _ := end.get_f32(data[offset:], end.Byte_Order.Little)
    offset += 4
    // Read scale Vector3
    scale_x, _ := end.get_f32(data[offset:], end.Byte_Order.Little)
    offset += 4
    scale_y, _ := end.get_f32(data[offset:], end.Byte_Order.Little)
    offset += 4
    scale_z, _ := end.get_f32(data[offset:], end.Byte_Order.Little)
    offset += 4
    return rl.Transform{
        rl.Vector3{translation_x, translation_y, translation_z},
        transmute(quaternion128)[4]f32{rotation_x, rotation_y, rotation_z, rotation_w},
        rl.Vector3{scale_x, scale_y, scale_z},
    }
}
