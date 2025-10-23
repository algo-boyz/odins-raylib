package main

import rl "vendor:raylib"

main :: proc() {
    rl.InitWindow(WIDTH, HEIGHT, "Renderer")

    mesh := MakeCube()
    camera := MakeCamera({0.0, 0.0, -3.0}, {0.0, 0.0, -1.0})

    translation := Vector3{0.0, 0.0, 0.0}
    rotation := Vector3{0.0, 0.0, 0.0}
    scale: f32 = 1.0

    renderModesCount :: 2
    renderMode: i8 = renderModesCount - 1

    projectionMatrix := MakeProjectionMatrix(FOV, WIDTH, HEIGHT, NEAR_PLANE, FAR_PLANE)

    for !rl.WindowShouldClose() {
        deltaTime := rl.GetFrameTime()
        HandleInputs(&translation, &rotation, &scale, &renderMode, renderModesCount, deltaTime)

        translationMatrix := MakeTranslationMatrix(translation.x, translation.y, translation.z)
        rotationMatrix    := MakeRotationMatrix(rotation.x, rotation.y, rotation.z)
        scaleMatrix       := MakeScaleMatrix(scale, scale, scale)
        modelMatrix       := Mat4Mul(translationMatrix, Mat4Mul(rotationMatrix, scaleMatrix))
        viewMatrix        := MakeViewMatrix(camera.position, camera.target)
        viewMatrix         = Mat4Mul(viewMatrix, modelMatrix)
        
        ApplyTransformations(&mesh.transformedVertices, mesh.vertices, viewMatrix)

        rl.BeginDrawing()
        
        switch renderMode {
            case 0: DrawWireframe(mesh.transformedVertices, mesh.triangles, projectionMatrix, rl.GREEN, false)
            case 1: DrawWireframe(mesh.transformedVertices, mesh.triangles, projectionMatrix, rl.GREEN, true)
        }

        rl.EndDrawing()
        
        rl.ClearBackground(rl.BLACK)
    }

    rl.CloseWindow()
}

ApplyTransformations :: proc(transformed: ^[]Vector3, original: []Vector3, mat: Matrix4x4) {
    for i in 0..<len(original) {
        transformed[i] = Mat4MulVec3(mat, original[i])
    }
}