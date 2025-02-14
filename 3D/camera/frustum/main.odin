package main

import "core:math"
import rl "vendor:raylib"
import rlgl "vendor:raylib/rlgl"

Camera_World_Ray :: struct {
    start: rl.Vector3,
    end:   rl.Vector3,
}

get_camera_projection_matrix :: proc(camera: rl.Camera3D, near, far: f32) -> rl.Matrix {
    aspect := f32(rl.GetScreenWidth()) / f32(rl.GetScreenHeight())
    
    if camera.projection == .PERSPECTIVE {
        return rl.MatrixPerspective(camera.fovy * math.RAD_PER_DEG, aspect, near, far)
    } else {
        // Orthographic projection has Y range [-fov/2, fov/2] and xrange aspect*Yrange
        top := camera.fovy / 2.0
        right := top * aspect
        return rl.MatrixOrtho(-right, right, -top, top, near, far)
    }
}

get_camera_world_ray :: proc(ndc: rl.Vector3, view, proj: rl.Matrix) -> Camera_World_Ray {
    inv_proj_view := rl.MatrixInvert(view * proj)
    line: Camera_World_Ray
    world_quat1 := rl.QuaternionTransform(
        transmute(quaternion128)[4]f32{ndc.x, ndc.y, -1, 1}, 
        inv_proj_view,
    )
    world_quat2 := rl.QuaternionTransform(
        transmute(quaternion128)[4]f32{ndc.x, ndc.y, 1, 1}, 
        inv_proj_view,
    )
    world_quat1 = rl.QuaternionScale(world_quat1, 1.0/world_quat1.w)
    world_quat2 = rl.QuaternionScale(world_quat2, 1.0/world_quat2.w)
    
    line.start = rl.Vector3Unproject({ndc.x, ndc.y, -1}, proj, view)
    line.end = rl.Vector3Unproject({ndc.x, ndc.y, 1}, proj, view)
    return line
}

draw_camera_frustum :: proc(main_camera, camera: rl.Camera3D, near, far: f32) {
    // 8 points for the corners of the frustum box
    ndc_points := [8]rl.Vector3{
        {-1,  1, -1},
        { 1,  1, -1},
        {-1, -1, -1},
        { 1, -1, -1},
        {-1,  1,  1},
        { 1,  1,  1},
        {-1, -1,  1},
        { 1, -1,  1},
    }
    
    view := rl.GetCameraMatrix(camera)
    proj := get_camera_projection_matrix(camera, near, far)
    inv_view := rl.MatrixInvert(view)
    inv_proj := rl.MatrixInvert(proj)
    
    world_points: [8]rl.Vector3
    for point, i in ndc_points {
        clip := point
        
        // For projection we scale by W coordinate
        w := camera.projection == .PERSPECTIVE ? (point.z < 0 ? near : far) : 1
        clip *= w
        
        // Transform from clip to view space
        clip_quat := transmute(quaternion128)[4]f32{clip.x, clip.y, clip.z, w}
        view_quat := rl.QuaternionTransform(clip_quat, inv_proj)
        view_pos := rl.Vector3{view_quat.x, view_quat.y, view_quat.z}
        
        // Transform from view to world space
        world_points[i] = rl.Vector3Transform(view_pos, inv_view)
    }
    
    // Draw frustum
    rl.DrawSphere(camera.position, 0.02, rl.GREEN)
    
    for p1, i in ndc_points {
        for p2, j in ndc_points {
            diff := int(p1.x != p2.x) + int(p1.y != p2.y) + int(p1.z != p2.z)
            if diff == 1 {
                rl.DrawLine3D(world_points[i], world_points[j], rl.RED)
            }
        }
    }
    
    color := rl.Fade(rl.RED, 0.4)
    
    // Draw near plane
    rl.DrawTriangle3D(world_points[0], world_points[2], world_points[1], color)
    rl.DrawTriangle3D(world_points[1], world_points[2], world_points[3], color)
    
    // Draw far plane
    rl.DrawTriangle3D(world_points[4], world_points[6], world_points[5], color)
    rl.DrawTriangle3D(world_points[5], world_points[6], world_points[7], color)
}

main :: proc() {
    rl.InitWindow(800, 800, "Projection")
    defer rl.CloseWindow()
    
    camera := rl.Camera3D{
        position = {1, 1, 1},
        target = {0, 0.25, 0},
        up = {0, 1, 0},
        fovy = 45.0,
        projection = .PERSPECTIVE,
    }
    
    main_camera := rl.Camera3D{
        position = {4, 4, 4},
        target = {0, 0, 0},
        up = {0, 1, 0},
        fovy = 45.0,
        projection = .PERSPECTIVE,
    }
    
    near_plane: f32 = 0.1
    far_plane: f32 = 2.0
    fovy: f32 = 45.0
    extents: f32 = 1.0
    orthographic := false
    
    render_texture := rl.LoadRenderTexture(800, 800)
    defer rl.UnloadRenderTexture(render_texture)
    
    for !rl.WindowShouldClose() {
        rl.UpdateCamera(&camera, .ORBITAL)
        camera.fovy = orthographic ? extents : fovy
        mouse_pos := rl.GetMousePosition()
        
        // Render to texture
        rl.BeginTextureMode(render_texture)
        rl.ClearBackground(rl.BLACK)
        
        rl.BeginMode3D(camera)
        proj := get_camera_projection_matrix(camera, near_plane, far_plane)
        view := rl.GetCameraMatrix(camera)
        rlgl.SetMatrixProjection(proj)
        
        rl.DrawGrid(8, 0.5)
        rl.DrawCube({0, 0.25, 0}, 0.5, 0.5, 0.5, rl.BLUE)
        rl.DrawCubeWires({0, 0.25, 0}, 0.5, 0.5, 0.5, rl.DARKBLUE)
        rl.EndMode3D()
        
        rl.DrawCircle(i32(mouse_pos.x), i32(mouse_pos.y), 15.0, rl.GREEN)
        rl.EndTextureMode()
        
        // Main render
        rl.BeginDrawing()
        rl.ClearBackground(rl.BLACK)
        
        rl.BeginMode3D(main_camera)
        rl.DrawGrid(8, 0.5)
        rl.DrawCube({0, 0.25, 0}, 0.5, 0.5, 0.5, rl.BLUE)
        rl.DrawCubeWires({0, 0.25, 0}, 0.5, 0.5, 0.5, rl.DARKBLUE)
        
        ndc := rl.Vector3{
            2 * mouse_pos.x / 800 - 1,
            -(2 * mouse_pos.y / 800 - 1),
            1,
        }
        line := get_camera_world_ray(ndc, view, proj)
        rl.DrawLine3D(line.start, line.end, rl.GREEN)
        
        draw_camera_frustum(main_camera, camera, near_plane, far_plane)
        rl.EndMode3D()
        
        // Draw render texture
        src := rl.Rectangle{0, 0, f32(render_texture.texture.width), -f32(render_texture.texture.height)}
        dst := rl.Rectangle{500, 500, 275, 275}
        rl.DrawTexturePro(render_texture.texture, src, dst, {0, 0}, 0, rl.WHITE)
        rl.DrawRectangleLines(500, 500, 275, 275, rl.DARKGRAY)
        
        // GUI
        if rl.GuiButton(rl.Rectangle{300, 10, 100, 20}, orthographic ? "Orthographic" : "Perspective") {
            orthographic = !orthographic
            camera.projection = orthographic ? .ORTHOGRAPHIC : .PERSPECTIVE
        }
        
        rl.GuiSlider(
            rl.Rectangle{50, 10, 200, 10},
            "Near",
            rl.TextFormat("%3.2f", near_plane),
            &near_plane,
            0.01,
            10.0,
        )
        
        rl.GuiSlider(
            rl.Rectangle{50, 25, 200, 10},
            "Far",
            rl.TextFormat("%3.2f", far_plane),
            &far_plane,
            0.01,
            10.0,
        )
        
        rl.GuiSlider(
            rl.Rectangle{50, 40, 200, 10},
            orthographic ? "Height" : "FOV y",
            rl.TextFormat("%3.2f", orthographic ? extents : fovy),
            orthographic ? &extents : &fovy,
            0.01,
            orthographic ? 10.0 : 179.9,
        )
        
        rl.EndDrawing()
    }
}