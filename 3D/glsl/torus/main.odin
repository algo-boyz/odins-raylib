package main

import rl "vendor:raylib"

main :: proc() {
  rl.SetTraceLogLevel(rl.TraceLogLevel.WARNING)
  rl.InitWindow(400, 400, "Torus")
  rl.SetTargetFPS(60)

  shader := rl.LoadShader("assets/torus.vs", "assets/torus.fs")

  camera: rl.Camera3D
  {
    using rl.CameraProjection
    camera = rl.Camera3D{{0.0, 1.0, 4.0}, {0.0, 0.0, 0.0}, {0.0, 1.0, 0.0}, 45.0, .PERSPECTIVE}
  }

  model := rl.LoadModelFromMesh(rl.GenMeshTorus(0.4, 1, 16, 32))
  model.materials[0].shader = shader // miss this and the shader won't be applied to the torus object

  ambientColor_loc := rl.GetShaderLocation(shader, "ambientColor")
  ambientColor := rl.Vector3{1.0, 1.0, 1.0}
  {
    using rl.ShaderUniformDataType
    rl.SetShaderValue(shader, rl.ShaderLocationIndex(ambientColor_loc), &ambientColor, VEC3)
  }

  for (!rl.WindowShouldClose()) {
    rl.UpdateCamera(&camera, rl.CameraMode.ORBITAL)
    rl.BeginDrawing()
    rl.ClearBackground(rl.BLACK)
    rl.BeginMode3D(camera)
    rl.DrawModel(model, rl.Vector3{0, 0, 0}, 1.0, rl.WHITE)
    rl.EndMode3D()
    rl.DrawFPS(10, 10)
    rl.EndDrawing()
  }
  rl.UnloadModel(model)
  rl.UnloadShader(shader)
  rl.CloseWindow()
}