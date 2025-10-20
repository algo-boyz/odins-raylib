package mat

import "core:log"
import rl "vendor:raylib"
import rlgl "vendor:raylib/rlgl"

MMI :: rl.MaterialMapIndex
SLI :: rlgl.ShaderLocationIndex
SADT :: rlgl.ShaderAttributeDataType
SUDT :: rlgl.ShaderUniformDataType

MAX_MATERIAL_MAPS :: 12

ZeroPtr :: rawptr(uintptr(0)) // this is the same as c.NULL

RL_Flat4x4 :: [16]f32

Material :: struct {
  maps: [dynamic][11]rl.MaterialMap,
  mats: [dynamic]rl.Material,
  pointer: [^]rl.Material,
}

Assign :: struct {
  shader: int,
  texture: int,
  color: int,
  value: f32,
}

// For assignments, a zero value for shader, texture, or color in Assign leaves zero values
// in the resulting Material whereas 1 is the first element of the provided matching array.
// Example: Assign {1, 3, 0, 1.4} assigns shaders[0], the first shader in shaders, as the
// shader for the nth, with respect to assignments[n], Material, along with the third Texture,
// texures[2], and does not assign a color, thus leaving it at a zero value. And, while I'm
// pedantically documenting, value is set directly.
new_material :: proc(assignments: []Assign, shaders: []rl.Shader, textures: []rl.Texture, colors: []rl.Color) -> Material {
  sz := len(assignments)
  matmaps := make([dynamic][11]rl.MaterialMap,sz,sz)
  mats := make([dynamic]rl.Material,sz,sz)
  for a, i in assignments {
    matmaps[i] = [11]rl.MaterialMap {}
    mats[i].maps = raw_data(matmaps[i][:])
    if a.shader > 0 && a.shader <= len(shaders) {
      mats[i].shader = shaders[a.shader - 1]
    }
    if a.texture > 0 && a.texture <= len(textures) {
      mats[i].maps[0].texture = textures[a.texture - 1]
    }
    if a.color > 0 && a.color <= len(colors) {
      mats[i].maps[0].color = colors[a.color - 1]
    }
    mats[i].maps[0].value = a.value
  }
  return Material{matmaps, mats, raw_data(mats[:])}
}

destroy_material_helper :: proc(mh: Material) {
  delete(mh.maps)
  delete(mh.mats)
}

// Draw multiple mesh instances with material and different transforms
draw_mesh_instanced :: proc (mesh: rl.Mesh, material: rl.Material, transforms: ^[dynamic]rl.Matrix) {
  instances: int = len(transforms)
  if instances < 1 { return }
  
  // Bind shader program
  rlgl.EnableShader(material.shader.id)
  defer rlgl.DisableShader()
  
  // Send required data to shader (matrices, values)

  // Upload to shader material.colDiffuse
  if material.shader.locs[SLI.COLOR_DIFFUSE] != -1 {
    values: [4]f32 = {
      f32(material.maps[MMI.ALBEDO].color.r),
      f32(material.maps[MMI.ALBEDO].color.g),
      f32(material.maps[MMI.ALBEDO].color.b),
      f32(material.maps[MMI.ALBEDO].color.a),
    }/255.0 // Divides each element by 255.0 to get values between 0.0 and 1.0
    rlgl.SetUniform(
      locIndex = material.shader.locs[SLI.COLOR_DIFFUSE], 
      value = &values[0], 
      uniformType = i32(SUDT.VEC4), 
      count = 1,
    )
  }
  // Upload to shader material.colSpecular (if loc available)
  if material.shader.locs[SLI.COLOR_SPECULAR] != -1 {
    values: [4]f32 = {
      f32(material.maps[SLI.COLOR_SPECULAR].color.r),
      f32(material.maps[SLI.COLOR_SPECULAR].color.g),
      f32(material.maps[SLI.COLOR_SPECULAR].color.b),
      f32(material.maps[SLI.COLOR_SPECULAR].color.a),
    }/255.0
    rlgl.SetUniform(
      locIndex = material.shader.locs[SLI.COLOR_SPECULAR], 
      value = &values[0], 
      uniformType = i32(SUDT.VEC4), 
      count = 1,
    )
  }
  // Get a copy of current matrices
  // NOTE: At this point the model view matrix just contains the view matrix (camera)
  // That's because BeginMode3D() sets it and there is no model-drawing function
  // that modifies it, all use rlgl PushMatrix() and PopMatrix()
  mat_model: rl.Matrix = rl.Matrix(1)
  mat_view: rl.Matrix = rlgl.GetMatrixModelview()
  mat_model_view: rl.Matrix
  mat_proj: rl.Matrix = rlgl.GetMatrixProjection()
  
  // Upload view and projection matrices (if locations available)
  if material.shader.locs[SLI.MATRIX_VIEW] != -1 {
    rlgl.SetUniformMatrix(
      locIndex = material.shader.locs[SLI.MATRIX_VIEW], 
      mat = mat_view,
    )
  }
  if material.shader.locs[SLI.MATRIX_PROJECTION] != -1 {
    rlgl.SetUniformMatrix(
      locIndex = material.shader.locs[SLI.MATRIX_PROJECTION],
      mat = mat_proj,
    )
  }
  // Create instances buffer
  instanceTransforms := (cast ([^]RL_Flat4x4) rl.MemAlloc(cast (u32) instances * size_of(RL_Flat4x4)))
  defer rl.MemFree(instanceTransforms)
  
  // Fill buffer with instances transformations as float16 arrays
  for i in 0..<instances {
    instanceTransforms[i] = transmute ([16]f32) transpose(transforms[i])
  }
  // Enable mesh VAO to attach new buffer
  rlgl.EnableVertexArray(mesh.vaoId)
  
  // This could alternatively use a static VBO and either glMapBuffer() or glBufferSubData()
  // It isn't clear which would be reliably faster in all cases and on all platforms,
  // anecdotally glMapBuffer() seems very slow (syncs) while glBufferSubData() seems
  // no faster, since we're transferring all the transform matrices anyway
  instancesVboId := rlgl.LoadVertexBuffer(instanceTransforms, cast (i32) instances * size_of(RL_Flat4x4), false)
  defer rlgl.UnloadVertexBuffer(instancesVboId)
  
  // Instances transformation matrices are sent to shader attribute location: SLI.MATRIX_MODEL
  for i in 0..<i32(4) {
    rlgl.EnableVertexAttribute(u32(material.shader.locs[SLI.MATRIX_MODEL] + i))
    rlgl.SetVertexAttribute(
      index = u32(material.shader.locs[SLI.MATRIX_MODEL] + i),
      compSize = 4,
      type = rlgl.FLOAT,
      normalized = false,
      stride = size_of(rl.Matrix),
      offset = i * size_of(rl.Vector4),
    )
    rlgl.SetVertexAttributeDivisor(u32(material.shader.locs[SLI.MATRIX_MODEL] + i), 1)
  }
  rlgl.DisableVertexBuffer()
  rlgl.DisableVertexArray()
  
  // Accumulate internal matrix transform (push/pop) and view matrix
  // NOTE: In this case, model instance transformation must be computed in the shader
  mat_model_view = mat_view * rlgl.GetMatrixTransform() // So far this doesn't seem to matter which way, probably one or both are Identity
  
  // Upload model normal matrix (if loc available)
  if material.shader.locs[SLI.MATRIX_NORMAL] != -1 {
    rlgl.SetUniformMatrix(
      material.shader.locs[SLI.MATRIX_NORMAL], 
      mat_model,
    )
  }
  // Bind active texture maps (if available)
  for i in 0..<MAX_MATERIAL_MAPS {
    if (material.maps[i].texture.id > 0) {
      // Select current shader texture slot
      rlgl.ActiveTextureSlot(i32(i))
      // Enable texture for active slot
      #partial switch cast(MMI) i {
      case .IRRADIANCE, .PREFILTER, .CUBEMAP:
        rlgl.EnableTextureCubemap(material.maps[i].texture.id)
      case:
        rlgl.EnableTexture(material.maps[i].texture.id)
      }
      value :int = i
      rlgl.SetUniform(material.shader.locs[SLI.MAP_ALBEDO + SLI(i)], &value, i32(SUDT.INT), 1)
    }
  }
  // Try binding vertex array objects (VAO) or use VBOs if not
  if !rlgl.EnableVertexArray(mesh.vaoId) {
    // Bind mesh VBO data: vertex position (shader-location = 0)
    rlgl.EnableVertexBuffer(mesh.vboId[0])
    rlgl.SetVertexAttribute(u32(material.shader.locs[SLI.VERTEX_POSITION]), 3, rlgl.FLOAT, false, 0, 0)
    rlgl.EnableVertexAttribute(u32(material.shader.locs[SLI.VERTEX_POSITION]))
    // Bind mesh VBO data: vertex texcoords (shader-location = 1)
    rlgl.EnableVertexBuffer(mesh.vboId[1])
    rlgl.SetVertexAttribute(u32(material.shader.locs[SLI.VERTEX_TEXCOORD01]), 2, rlgl.FLOAT, false, 0, 0)
    rlgl.EnableVertexAttribute(u32(material.shader.locs[SLI.VERTEX_TEXCOORD01]))
    
    if material.shader.locs[SLI.VERTEX_NORMAL] != -1 {
      // Bind mesh VBO data: vertex normals (shader-location = 2)
      rlgl.EnableVertexBuffer(mesh.vboId[2])
      rlgl.SetVertexAttribute(u32(material.shader.locs[SLI.VERTEX_NORMAL]), 3, rlgl.FLOAT, false, 0, 0)
      rlgl.EnableVertexAttribute(u32(material.shader.locs[SLI.VERTEX_NORMAL]))
    }
    // Bind mesh VBO data: vertex colors (shader-location = 3, if available)
    if (material.shader.locs[SLI.VERTEX_COLOR] != -1) {
      if (mesh.vboId[3] != 0) {
        rlgl.EnableVertexBuffer(mesh.vboId[3])
        rlgl.SetVertexAttribute(u32(material.shader.locs[SLI.VERTEX_COLOR]), 4, rlgl.UNSIGNED_BYTE, true, 0, 0)
        rlgl.EnableVertexAttribute(u32(material.shader.locs[SLI.VERTEX_COLOR]))
      } else {
        // Set default value for unused attribute
        // NOTE: Required when using default shader and no VAO support
        value: [4]f32 = { 1, 1, 1, 1 }
        rlgl.SetVertexAttributeDefault(material.shader.locs[SLI.VERTEX_COLOR], raw_data(value[:]), i32(SADT.VEC4), 4)
        rlgl.DisableVertexAttribute(u32(material.shader.locs[SLI.VERTEX_COLOR]))
      }
    }
    // Bind mesh VBO data: vertex tangents (shader-location = 4, if available)
    if (material.shader.locs[SLI.VERTEX_TANGENT] != -1) {
      rlgl.EnableVertexBuffer(mesh.vboId[4])
      rlgl.SetVertexAttribute(u32(material.shader.locs[SLI.VERTEX_TANGENT]), 4, rlgl.FLOAT, false, 0, 0)
      rlgl.EnableVertexAttribute(u32(material.shader.locs[SLI.VERTEX_TANGENT]))
    }
    // Bind mesh VBO data: vertex texcoords2 (shader-location = 5, if available)
    if material.shader.locs[SLI.VERTEX_TEXCOORD02] != -1 {
      rlgl.EnableVertexBuffer(mesh.vboId[5])
      rlgl.SetVertexAttribute(u32(material.shader.locs[SLI.VERTEX_TEXCOORD02]), 2, rlgl.FLOAT, false, 0, 0)
      rlgl.EnableVertexAttribute(u32(material.shader.locs[SLI.VERTEX_TEXCOORD02]))
    }
    if mesh.indices != ZeroPtr { rlgl.EnableVertexBufferElement(mesh.vboId[6]) }
  }
  eye_count:i32 = 1
  if rlgl.IsStereoRenderEnabled() { eye_count = 2 }
  
  for eye in 0..<eye_count {
    // Calculate model-view-projection matrix (MVP)
    view_proj := rl.Matrix(1)
    if eye_count == 1 {
      // view_proj = mat_model_view * mat_proj // This doesn't work
      view_proj = mat_proj * mat_model_view
    } else {
      // Setup current eye viewport (half screen width)
      rlgl.Viewport(eye * rlgl.GetFramebufferWidth() / 2, 0, rlgl.GetFramebufferWidth() / 2, rlgl.GetFramebufferHeight())
      view_proj = rlgl.GetMatrixProjectionStereo(eye) * // no idea if this works
        (rlgl.GetMatrixViewOffsetStereo(eye) * mat_model_view)
    }
    // Send combined model-view-projection matrix to shader
    rlgl.SetUniformMatrix(material.shader.locs[SLI.MATRIX_MVP], view_proj)
    // Draw mesh instanced
    if mesh.indices != ZeroPtr {
      rlgl.DrawVertexArrayElementsInstanced(0, mesh.triangleCount * 3, ZeroPtr, i32(instances))
    } else {
      rlgl.DrawVertexArrayInstanced(0, mesh.vertexCount, i32(instances)) // We call this one.
    }
  }
  // Unbind all bound texture maps
  for i in 0..<MAX_MATERIAL_MAPS {
    if material.maps[i].texture.id > 0 {
      // Select current shader texture slot
      rlgl.ActiveTextureSlot( i32(i) )
      #partial switch cast(MMI) i {
      case .IRRADIANCE, .PREFILTER, .CUBEMAP:
        rlgl.DisableTextureCubemap()
      case:
        rlgl.DisableTexture()
      }
    }
  }
  // Disable all possible vertex array objects (or VBOs)
  rlgl.DisableVertexArray()
  rlgl.DisableVertexBuffer()
  rlgl.DisableVertexBufferElement()
}
