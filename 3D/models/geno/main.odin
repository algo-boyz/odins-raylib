package geno

import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:slice"

import rl "vendor:raylib"
import rlgl "vendor:raylib/rlgl"

// based on: https://github.com/orangeduck/GenoView
main :: proc() {
    screenWidth:i32  = 1280
    screenHeight:i32 = 720
    rl.SetConfigFlags({rl.ConfigFlag.VSYNC_HINT})
    rl.InitWindow(screenWidth, screenHeight, "Genotastic")
    rl.SetTargetFPS(60)
    
    // Load shaders
    shadowShader := rl.LoadShader("assets/shadow.vs", "assets/shadow.fs")
    shadowShaderLightClipNear := rl.GetShaderLocation(shadowShader, "lightClipNear")
    shadowShaderLightClipFar := rl.GetShaderLocation(shadowShader, "lightClipFar")
    
    skinnedShadowShader := rl.LoadShader("assets/skinnedShadow.vs", "assets/shadow.fs")
    skinnedShadowShaderLightClipNear := rl.GetShaderLocation(skinnedShadowShader, "lightClipNear")
    skinnedShadowShaderLightClipFar := rl.GetShaderLocation(skinnedShadowShader, "lightClipFar")
    
    skinnedBasicShader := rl.LoadShader("assets/skinnedBasic.vs", "assets/basic.fs")
    skinnedBasicShaderSpecularity := rl.GetShaderLocation(skinnedBasicShader, "specularity")
    skinnedBasicShaderGlossiness := rl.GetShaderLocation(skinnedBasicShader, "glossiness")
    skinnedBasicShaderCamClipNear := rl.GetShaderLocation(skinnedBasicShader, "camClipNear")
    skinnedBasicShaderCamClipFar := rl.GetShaderLocation(skinnedBasicShader, "camClipFar")
    
    basicShader := rl.LoadShader("assets/basic.vs", "assets/basic.fs")
    basicShaderSpecularity := rl.GetShaderLocation(basicShader, "specularity")
    basicShaderGlossiness := rl.GetShaderLocation(basicShader, "glossiness")
    basicShaderCamClipNear := rl.GetShaderLocation(basicShader, "camClipNear")
    basicShaderCamClipFar := rl.GetShaderLocation(basicShader, "camClipFar")

    lightingShader := rl.LoadShader("assets/post.vs", "assets/lighting.fs")
    lightingShaderGBufferColor := rl.GetShaderLocation(lightingShader, "gbufferColor")
    lightingShaderGBufferNormal := rl.GetShaderLocation(lightingShader, "gbufferNormal")
    lightingShaderGBufferDepth := rl.GetShaderLocation(lightingShader, "gbufferDepth")
    lightingShaderSSAO := rl.GetShaderLocation(lightingShader, "ssao")
    lightingShaderCamPos := rl.GetShaderLocation(lightingShader, "camPos")
    lightingShaderCamInvViewProj := rl.GetShaderLocation(lightingShader, "camInvViewProj")
    lightingShaderLightDir := rl.GetShaderLocation(lightingShader, "lightDir")
    lightingShaderSunColor := rl.GetShaderLocation(lightingShader, "sunColor")
    lightingShaderSunStrength := rl.GetShaderLocation(lightingShader, "sunStrength")
    lightingShaderSkyColor := rl.GetShaderLocation(lightingShader, "skyColor")
    lightingShaderSkyStrength := rl.GetShaderLocation(lightingShader, "skyStrength")
    lightingShaderGroundStrength := rl.GetShaderLocation(lightingShader, "groundStrength")
    lightingShaderAmbientStrength := rl.GetShaderLocation(lightingShader, "ambientStrength")
    lightingShaderExposure := rl.GetShaderLocation(lightingShader, "exposure")
    lightingShaderCamClipNear := rl.GetShaderLocation(lightingShader, "camClipNear")
    lightingShaderCamClipFar := rl.GetShaderLocation(lightingShader, "camClipFar")

    ssaoShader := rl.LoadShader("assets/post.vs", "assets/ssao.fs")
    ssaoShaderGBufferNormal := rl.GetShaderLocation(ssaoShader, "gbufferNormal")
    ssaoShaderGBufferDepth := rl.GetShaderLocation(ssaoShader, "gbufferDepth")
    ssaoShaderCamView := rl.GetShaderLocation(ssaoShader, "camView")
    ssaoShaderCamProj := rl.GetShaderLocation(ssaoShader, "camProj")
    ssaoShaderCamInvProj := rl.GetShaderLocation(ssaoShader, "camInvProj")
    ssaoShaderCamInvViewProj := rl.GetShaderLocation(ssaoShader, "camInvViewProj")
    ssaoShaderLightViewProj := rl.GetShaderLocation(ssaoShader, "lightViewProj")
    ssaoShaderShadowMap := rl.GetShaderLocation(ssaoShader, "shadowMap")
    ssaoShaderShadowInvResolution := rl.GetShaderLocation(ssaoShader, "shadowInvResolution")
    ssaoShaderCamClipNear := rl.GetShaderLocation(ssaoShader, "camClipNear")
    ssaoShaderCamClipFar := rl.GetShaderLocation(ssaoShader, "camClipFar")
    ssaoShaderLightClipNear := rl.GetShaderLocation(ssaoShader, "lightClipNear")
    ssaoShaderLightClipFar := rl.GetShaderLocation(ssaoShader, "lightClipFar")
    ssaoShaderLightDir := rl.GetShaderLocation(ssaoShader, "lightDir")

    blurShader := rl.LoadShader("assets/post.vs", "assets/blur.fs")
    blurShaderGBufferNormal := rl.GetShaderLocation(blurShader, "gbufferNormal")
    blurShaderGBufferDepth := rl.GetShaderLocation(blurShader, "gbufferDepth")
    blurShaderInputTexture := rl.GetShaderLocation(blurShader, "inputTexture")
    blurShaderCamInvProj := rl.GetShaderLocation(blurShader, "camInvProj")
    blurShaderCamClipNear := rl.GetShaderLocation(blurShader, "camClipNear")
    blurShaderCamClipFar := rl.GetShaderLocation(blurShader, "camClipFar")
    blurShaderInvTextureResolution := rl.GetShaderLocation(blurShader, "invTextureResolution")
    blurShaderBlurDirection := rl.GetShaderLocation(blurShader, "blurDirection")

    fxaaShader := rl.LoadShader("assets/post.vs", "assets/fxaa.fs")
    fxaaShaderInputTexture := rl.GetShaderLocation(fxaaShader, "inputTexture")
    fxaaShaderInvTextureResolution := rl.GetShaderLocation(fxaaShader, "invTextureResolution")

    // Objects

    groundMesh := rl.GenMeshPlane(20.0, 20.0, 10, 10)
    groundModel := rl.LoadModelFromMesh(groundMesh)
    groundPosition := rl.Vector3{0.0, -0.01, 0.0}

    genoModel := load_model("assets/Geno.bin") // Custom loading function needed
    genoPosition := rl.Vector3{0.0, 0.0, 0.0}

    // print_mesh_data(&genoModel.meshes[0])
    // print_bone_info(&genoModel)
    if !validate_mesh(&genoModel.meshes[0]) {
        fmt.println("Mesh validation failed!")
    }
    // Animation
    animation := load_empty_animation(genoModel)
    // animation := load_animation("asssets/Geno.bin")
    animationFrame: i32

    // Camera
    camera: OrbitCamera
    orbit_camera_init(&camera)
    
    // Shadows
    lightDir := rl.Vector3Normalize(rl.Vector3{0.35, -1.0, -0.35})
    shadowLight := ShadowLight{
        target = rl.Vector3{},
        position = lightDir * -5.0,
        up = {0.0, 1.0, 0.0},
        width = 5.0,
        height = 5.0,
        near = 0.01,
        far = 10.0,
    }
    shadowWidth:i32 = 1024
    shadowHeight:i32 = 1024
    shadowInvResolution := rl.Vector2{1.0 / f32(shadowWidth), 1.0 / f32(shadowHeight)}
    shadowMap := load_shadow_map(shadowWidth, shadowHeight)
    
    // GBuffer and Render Textures
    gbuffer := load_gbuffer(screenWidth, screenHeight)
    lighted := rl.LoadRenderTexture(screenWidth, screenHeight)
    ssaoFront := rl.LoadRenderTexture(screenWidth, screenHeight)
    ssaoBack := rl.LoadRenderTexture(screenWidth, screenHeight)
    
    drawBoneTransforms: bool
    
    for !rl.WindowShouldClose() {
        // Animation
        animationFrame = (animationFrame + 1) % animation.frameCount;
        rl.UpdateModelAnimationBones(genoModel, animation, animationFrame)

        // Shadow Light Tracks Character
        hipPosition := animation.framePoses[animationFrame][0].translation;
        shadowLight.target = rl.Vector3{ hipPosition.x, 0.0, hipPosition.z }
        shadowLight.position = shadowLight.target + (lightDir * -5.0)

        // Update camera
        orbit_camera_update_input(&camera, rl.Vector3{hipPosition.x, 0.75, hipPosition.z})

        // Render
        rlgl.DisableColorBlend()
        rl.BeginDrawing()

        // Render shadow maps
        begin_shadow_map(shadowMap, shadowLight)
        cullDistanceNear :=  0.01 // Default near cull distance
        cullDistanceFar := 1000.0 // Default far cull distance
        
        lightViewProj := rlgl.GetMatrixModelview() * rlgl.GetMatrixProjection()
        lightClipNear :=  cullDistanceNear
        lightClipFar := cullDistanceFar

        rl.SetShaderValue(shadowShader, shadowShaderLightClipNear, &lightClipNear, rl.ShaderUniformDataType.FLOAT)
        rl.SetShaderValue(shadowShader, shadowShaderLightClipFar, &lightClipFar, rl.ShaderUniformDataType.FLOAT)
        rl.SetShaderValue(skinnedShadowShader, skinnedShadowShaderLightClipNear, &lightClipNear, rl.ShaderUniformDataType.FLOAT)
        rl.SetShaderValue(skinnedShadowShader, skinnedShadowShaderLightClipFar, &lightClipFar, rl.ShaderUniformDataType.FLOAT)
        
        groundModel.materials[0].shader = shadowShader
        rl.DrawModel(groundModel, groundPosition, 1.0, rl.WHITE)

        genoModel.materials[0].shader = skinnedShadowShader
        rl.DrawModel(genoModel, genoPosition, 1.0, rl.WHITE)
        
        end_shadow_map()

        // Render GBuffer
        begin_gbuffer(gbuffer, camera.cam3d)

        camView := rlgl.GetMatrixModelview()
        camProj := rlgl.GetMatrixProjection()
        camInvProj := rl.MatrixInvert(camProj)
        camInvViewProj := rl.MatrixInvert(camView * camProj)
        camClipNear := cullDistanceNear
        camClipFar := cullDistanceFar

        specularity := 0.5
        glossiness := 10.0   

        rl.SetShaderValue(basicShader, basicShaderSpecularity, &specularity, rl.ShaderUniformDataType.FLOAT)
        rl.SetShaderValue(basicShader, basicShaderGlossiness, &glossiness, rl.ShaderUniformDataType.FLOAT)
        rl.SetShaderValue(basicShader, basicShaderCamClipNear, &camClipNear, rl.ShaderUniformDataType.FLOAT)
        rl.SetShaderValue(basicShader, basicShaderCamClipFar, &camClipFar, rl.ShaderUniformDataType.FLOAT)
        
        rl.SetShaderValue(skinnedBasicShader, skinnedBasicShaderSpecularity, &specularity, rl.ShaderUniformDataType.FLOAT)
        rl.SetShaderValue(skinnedBasicShader, skinnedBasicShaderGlossiness, &glossiness, rl.ShaderUniformDataType.FLOAT)
        rl.SetShaderValue(skinnedBasicShader, skinnedBasicShaderCamClipNear, &camClipNear, rl.ShaderUniformDataType.FLOAT)
        rl.SetShaderValue(skinnedBasicShader, skinnedBasicShaderCamClipFar, &camClipFar, rl.ShaderUniformDataType.FLOAT)        
        
        groundModel.materials[0].shader = basicShader
        rl.DrawModel(groundModel, groundPosition, 1.0, rl.WHITE)
        
        genoModel.materials[0].shader = skinnedBasicShader
        rl.DrawModel(genoModel, genoPosition, 1.0, rl.ORANGE)       
        
        end_gbuffer(screenWidth, screenHeight)

        // Render SSAO and Shadows
        rl.BeginTextureMode(ssaoFront)
        rl.BeginShaderMode(ssaoShader)

        rl.SetShaderValueTexture(ssaoShader, ssaoShaderGBufferNormal, gbuffer.normal)
        rl.SetShaderValueTexture(ssaoShader, ssaoShaderGBufferDepth, gbuffer.depth)
        rl.SetShaderValueMatrix(ssaoShader, ssaoShaderCamView, camView)
        rl.SetShaderValueMatrix(ssaoShader, ssaoShaderCamProj, camProj)
        rl.SetShaderValueMatrix(ssaoShader, ssaoShaderCamInvProj, camInvProj)
        rl.SetShaderValueMatrix(ssaoShader, ssaoShaderCamInvViewProj, camInvViewProj)
        rl.SetShaderValueMatrix(ssaoShader, ssaoShaderLightViewProj, lightViewProj)

        set_shader_value_shadow_map(ssaoShader, ssaoShaderShadowMap, shadowMap)
        
        rl.SetShaderValue(ssaoShader, ssaoShaderShadowInvResolution, &shadowInvResolution, rl.ShaderUniformDataType.VEC2)
        rl.SetShaderValue(ssaoShader, ssaoShaderCamClipNear, &camClipNear, rl.ShaderUniformDataType.FLOAT)
        rl.SetShaderValue(ssaoShader, ssaoShaderCamClipFar, &camClipFar, rl.ShaderUniformDataType.FLOAT)
        rl.SetShaderValue(ssaoShader, ssaoShaderLightClipNear, &lightClipNear, rl.ShaderUniformDataType.FLOAT)
        rl.SetShaderValue(ssaoShader, ssaoShaderLightClipFar, &lightClipFar, rl.ShaderUniformDataType.FLOAT)
        rl.SetShaderValue(ssaoShader, ssaoShaderLightDir, &lightDir, rl.ShaderUniformDataType.VEC3)
        
        rl.ClearBackground(rl.WHITE)

        rl.DrawTextureRec(
            ssaoFront.texture,
            rl.Rectangle{ 0, 0, f32(ssaoFront.texture.width), f32(-ssaoFront.texture.height) },
            rl.Vector2{ 0, 0 },
            rl.WHITE)

        rl.EndShaderMode()
        rl.EndTextureMode()

        // Blur Horizontal
        rl.BeginTextureMode(ssaoBack)
        rl.BeginShaderMode(blurShader)
        
        blurDirection := rl.Vector2{ 1.0, 0.0 }
        blurInvTextureResolution := rl.Vector2{ 1 / f32(ssaoFront.texture.width), 1 / f32(ssaoFront.texture.height) }
        
        rl.SetShaderValueTexture(blurShader, blurShaderGBufferNormal, gbuffer.normal)
        rl.SetShaderValueTexture(blurShader, blurShaderGBufferDepth, gbuffer.depth)
        rl.SetShaderValueTexture(blurShader, blurShaderInputTexture, ssaoFront.texture)
        rl.SetShaderValueMatrix(blurShader, blurShaderCamInvProj, camInvProj)
        rl.SetShaderValue(blurShader, blurShaderCamClipNear, &camClipNear, rl.ShaderUniformDataType.FLOAT)
        rl.SetShaderValue(blurShader, blurShaderCamClipFar, &camClipFar, rl.ShaderUniformDataType.FLOAT)
        rl.SetShaderValue(blurShader, blurShaderInvTextureResolution, &blurInvTextureResolution, rl.ShaderUniformDataType.VEC2)
        rl.SetShaderValue(blurShader, blurShaderBlurDirection, &blurDirection, rl.ShaderUniformDataType.VEC2)

        rl.DrawTextureRec(ssaoBack.texture,
            rl.Rectangle{ 0, 0, f32(ssaoBack.texture.width), f32(-ssaoBack.texture.height) },
            rl.Vector2{ 0, 0 },
            rl.WHITE)
        rl.EndShaderMode()
        rl.EndTextureMode()
      
        // Blur Vertical
        rl.BeginTextureMode(ssaoFront)
        rl.BeginShaderMode(blurShader)
        blurDirection = rl.Vector2{ 0.0, 1.0 }
        
        rl.SetShaderValueTexture(blurShader, blurShaderInputTexture, ssaoBack.texture)
        rl.SetShaderValue(blurShader, blurShaderBlurDirection, &blurDirection, rl.ShaderUniformDataType.VEC2)

        rl.DrawTextureRec(
            ssaoFront.texture,
            rl.Rectangle{ 0, 0, f32(ssaoFront.texture.width), -f32(ssaoFront.texture.height) },
            rl.Vector2{ 0, 0 },
            rl.WHITE)
        rl.EndShaderMode()
        rl.EndTextureMode()
      
        // Light GBuffer
        rl.BeginTextureMode(lighted)
        rl.BeginShaderMode(lightingShader)
        
        sunColor := rl.Vector3{ 253.0 / 255.0, 255.0 / 255.0, 232.0 / 255.0 }
        sunStrength := 0.25
        skyColor := rl.Vector3{ 174.0 / 255.0, 183.0 / 255.0, 190.0 / 255.0 }
        skyStrength := 0.2
        groundStrength := 0.1
        ambientStrength := 1.0
        exposure := 0.9
        
        rl.SetShaderValueTexture(lightingShader, lightingShaderGBufferColor, gbuffer.color)
        rl.SetShaderValueTexture(lightingShader, lightingShaderGBufferNormal, gbuffer.normal)
        rl.SetShaderValueTexture(lightingShader, lightingShaderGBufferDepth, gbuffer.depth)
        rl.SetShaderValueTexture(lightingShader, lightingShaderSSAO, ssaoFront.texture)
        rl.SetShaderValue(lightingShader, lightingShaderCamPos, &camera.cam3d.position, rl.ShaderUniformDataType.VEC3)
        rl.SetShaderValueMatrix(lightingShader, lightingShaderCamInvViewProj, camInvViewProj)
        rl.SetShaderValue(lightingShader, lightingShaderLightDir, &lightDir, rl.ShaderUniformDataType.VEC3)
        rl.SetShaderValue(lightingShader, lightingShaderSunColor, &sunColor, rl.ShaderUniformDataType.VEC3)
        rl.SetShaderValue(lightingShader, lightingShaderSunStrength, &sunStrength, rl.ShaderUniformDataType.FLOAT)
        rl.SetShaderValue(lightingShader, lightingShaderSkyColor, &skyColor, rl.ShaderUniformDataType.VEC3)
        rl.SetShaderValue(lightingShader, lightingShaderSkyStrength, &skyStrength, rl.ShaderUniformDataType.FLOAT)
        rl.SetShaderValue(lightingShader, lightingShaderGroundStrength, &groundStrength, rl.ShaderUniformDataType.FLOAT)
        rl.SetShaderValue(lightingShader, lightingShaderAmbientStrength, &ambientStrength, rl.ShaderUniformDataType.FLOAT)
        rl.SetShaderValue(lightingShader, lightingShaderExposure, &exposure, rl.ShaderUniformDataType.FLOAT)
        rl.SetShaderValue(lightingShader, lightingShaderCamClipNear, &camClipNear, rl.ShaderUniformDataType.FLOAT)
        rl.SetShaderValue(lightingShader, lightingShaderCamClipFar, &camClipFar, rl.ShaderUniformDataType.FLOAT)
        
        rl.ClearBackground(rl.RAYWHITE)
        
        rl.DrawTextureRec(
            gbuffer.color,
            rl.Rectangle{ 0, 0, f32(gbuffer.color.width), f32(-gbuffer.color.height) },
            rl.Vector2{ 0, 0 },
            rl.WHITE)

        rl.EndShaderMode() 

        // Draw 3D scene
        rl.BeginMode3D(camera.cam3d)
        if (drawBoneTransforms) {
            draw_model_animation_frame_skeleton(animation, animationFrame, rl.GRAY);
        }
        // rl.DrawTextureEx(gbuffer.color, rl.Vector2{0, 0}, 0, 0.25, rl.BLACK)
        // rl.DrawTextureEx(gbuffer.normal, rl.Vector2{200, 0}, 0, 0.25, rl.BLACK)
        rl.DrawTextureEx(gbuffer.depth, rl.Vector2{400, 0}, 0, 0.25, rl.BLACK)

        rl.EndMode3D();
        rl.EndTextureMode();
        
        // Render Final with FXAA
        rl.BeginShaderMode(fxaaShader);
        fxaaInvTextureResolution := rl.Vector2{ 1.0 / f32(lighted.texture.width), 1.0 / f32(lighted.texture.height) };
        rl.SetShaderValueTexture(fxaaShader, fxaaShaderInputTexture, lighted.texture);
        rl.SetShaderValue(fxaaShader, fxaaShaderInvTextureResolution, &fxaaInvTextureResolution, rl.ShaderUniformDataType.VEC2);
        
        rl.DrawTextureRec(
            lighted.texture,
            rl.Rectangle{ 0.0, 0.0, f32(lighted.texture.width), f32(-lighted.texture.height) },
            rl.Vector2{ 0.0, 0.0 },
            rl.WHITE);
        
        rl.EndShaderMode();

        // Draw UI
        rlgl.EnableColorBlend();

        rl.GuiGroupBox((rl.Rectangle){ 20, 10, 190, 180 }, "Camera");
        rl.GuiLabel((rl.Rectangle){ 30, 20, 150, 20 }, "Ctrl + Left Click - Rotate");
        rl.GuiLabel((rl.Rectangle){ 30, 40, 150, 20 }, "Ctrl + Right Click - Pan");
        rl.GuiLabel((rl.Rectangle){ 30, 60, 150, 20 }, "Mouse Scroll - Zoom");
        rl.GuiLabel((rl.Rectangle){ 30, 80, 150, 20 }, rl.TextFormat("Target: [%.3f %.3f %.3f]", camera.cam3d.target.x, camera.cam3d.target.y, camera.cam3d.target.z));
        rl.GuiLabel((rl.Rectangle){ 30, 100, 150, 20 }, rl.TextFormat("Offset: [%.3f %.3f %.3f]", camera.offset.x, camera.offset.y, camera.offset.z));
        rl.GuiLabel((rl.Rectangle){ 30, 120, 150, 20 }, rl.TextFormat("Azimuth: %.3f", camera.azimuth));
        rl.GuiLabel((rl.Rectangle){ 30, 140, 150, 20 }, rl.TextFormat("Altitude: %.3f", camera.altitude));
        rl.GuiLabel((rl.Rectangle){ 30, 160, 150, 20 }, rl.TextFormat("Distance: %.3f", camera.distance));
  
        rl.GuiGroupBox(rl.Rectangle{ f32(screenWidth - 260), 10, 240, 40 }, "Rendering");

        rl.GuiCheckBox(rl.Rectangle{ f32(screenWidth - 250), 20, 20, 20 }, "Draw Transfoms", &drawBoneTransforms);
        // End drawing
        rl.EndDrawing()
    }
    
    // Cleanup
    rl.UnloadRenderTexture(lighted);
    rl.UnloadRenderTexture(ssaoBack);
    rl.UnloadRenderTexture(ssaoFront);
    rl.UnloadRenderTexture(lighted);
    unload_gbuffer(gbuffer);

    unload_shadow_map(shadowMap);
    
    rl.UnloadModelAnimation(animation);
    
    rl.UnloadModel(genoModel);
    rl.UnloadModel(groundModel);
    
    rl.UnloadShader(fxaaShader);    
    rl.UnloadShader(blurShader);    
    rl.UnloadShader(ssaoShader);    
    rl.UnloadShader(lightingShader);    
    rl.UnloadShader(basicShader);    
    rl.UnloadShader(skinnedBasicShader);
    rl.UnloadShader(skinnedShadowShader);
    rl.UnloadShader(shadowShader);
    
    rl.CloseWindow()
}

validate_mesh :: proc(mesh: ^rl.Mesh) -> bool {
    vertex_slice := slice.from_ptr(mesh.vertices, int(mesh.vertexCount) * 3)
    for i := 0; i < len(vertex_slice); i += 1 {
        value := vertex_slice[i]
        if value == math.INF_F32 || 
           value == -math.INF_F32 || 
           math.is_nan(value) {
            fmt.printf("Invalid vertex value at index %d: %f\n", i, value)
            return false
        }
    }
    return true
}

print_bone_info :: proc(model: ^rl.Model) {
    for i:i32; i < model.boneCount; i += 1 {
        bone := &model.bones[i]
        pose := &model.bindPose[i]
        fmt.printf("Bone %d:\n", i)
        fmt.printf("  Name: %s\n", string(bone.name[:]))
        fmt.printf("  Parent: %d\n", bone.parent)
        fmt.printf("  Translation: (%f, %f, %f)\n", 
            pose.translation.x,
            pose.translation.y,
            pose.translation.z)
        fmt.printf("  Scale: (%f, %f, %f)\n", 
            pose.scale.x,
            pose.scale.y,
            pose.scale.z)
    }
}

print_mesh_data :: proc(mesh: ^rl.Mesh) {
    vertex_slice := slice.from_ptr(mesh.vertices, int(mesh.vertexCount) * 3)
    fmt.println("First 10 vertices:")
    for i := 0; i < min(30, len(vertex_slice)); i += 3 {
        fmt.printf("v%d: (%f, %f, %f)\n", i/3, vertex_slice[i], vertex_slice[i+1], vertex_slice[i+2])
    }
    
    weight_slice := slice.from_ptr(mesh.boneWeights, int(mesh.vertexCount) * 4)
    fmt.println("\nFirst 10 bone weights:")
    for i := 0; i < min(40, len(weight_slice)); i += 4 {
        fmt.printf("w%d: (%f, %f, %f, %f)\n", i/4, 
            weight_slice[i], weight_slice[i+1], 
            weight_slice[i+2], weight_slice[i+3])
    }
}