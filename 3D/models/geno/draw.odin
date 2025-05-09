package geno

import rl "vendor:raylib"

// Debug Draw
draw_transform :: proc(t: rl.Transform, scale: f32) {
    rot_matrix := rl.QuaternionToMatrix(t.rotation)
    rl.DrawLine3D(
        t.translation,
        t.translation + rl.Vector3{scale * rot_matrix[0][0], scale * rot_matrix[1][0], scale * rot_matrix[2][0]},
        rl.RED)
        
    rl.DrawLine3D(
        t.translation,
        t.translation + rl.Vector3{scale * rot_matrix[0][1], scale * rot_matrix[1][1], scale * rot_matrix[1][2]},
        rl.GREEN)
        
    rl.DrawLine3D(
        t.translation,
        t.translation + rl.Vector3{scale * rot_matrix[0][2], scale * rot_matrix[1][2], scale * rot_matrix[2][2]},
        rl.BLUE)
}

draw_model_animation_frame_skeleton :: proc(animation: rl.ModelAnimation, frame: i32, color: rl.Color) {
    for i:i32 = 0; i < animation.boneCount; i += 1 {
        rl.DrawSphereWires(
            animation.framePoses[frame][i].translation,
            0.01,
            4,
            6,
            color)

        draw_transform(animation.framePoses[frame][i], 0.1)

        if animation.bones[i].parent != -1 {
            rl.DrawLine3D(
                animation.framePoses[frame][i].translation,
                animation.framePoses[frame][animation.bones[i].parent].translation,
                color)
        }
    }
}