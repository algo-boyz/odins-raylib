package main

import "core:math"
import "core:mem"
import rl "vendor:raylib"
import "vendor:raylib/rlgl"

// simple demo of FABRIK algorithm: http://www.andreasaristidou.com/FABRIK.html
SCREEN_WIDTH :: 1024
SCREEN_HEIGHT :: 1024

MAX_N_BONES :: 4
MAX_N_JOINTS :: MAX_N_BONES + 1

MAX_N_FABRIK_STEPS :: 20
FABRIK_ERROR_MARGIN :: 0.01

BACKGROUND_COLOR :: rl.Color{20, 20, 20, 255}

CAMERA := rl.Camera2D{
    offset = {0.5 * f32(SCREEN_WIDTH), 0.5 * f32(SCREEN_HEIGHT)},
    target = {0.0, 0.0},
    rotation = 0.0,
    zoom = 100.0,
}

Arm :: struct {
    start: rl.Vector2,
    target: rl.Vector2,
    
    n_bones: int,
    bone_angles: [MAX_N_BONES]f32,
    bone_lengths: [MAX_N_BONES]f32,
}

ARM: Arm

get_arm_joints :: proc(arm: ^Arm, joints: []rl.Vector2) -> int {
    joints[0] = arm.start
    n_joints := arm.n_bones + 1
    
    angle_total: f32 = 0.0
    
    for i in 1..<n_joints {
        length := arm.bone_lengths[i-1]
        angle_total += arm.bone_angles[i-1]
        
        bone := rl.Vector2{length, 0.0}
        bone = rl.Vector2Rotate(bone, angle_total)
        bone = bone + joints[i-1]
        
        joints[i] = bone
    }
    
    return n_joints
}

draw_arm :: proc(arm: ^Arm) {
    joints: [MAX_N_JOINTS]rl.Vector2
    n_joints := get_arm_joints(&ARM, joints[:])
    
    for i in 0..<n_joints {
        if i > 0 {
            rl.DrawLineV(joints[i-1], joints[i], rl.RAYWHITE)
        }
        rl.DrawCircleV(joints[i], 0.1, rl.RED)
    }
}

fabrik_step :: proc(arm: ^Arm) -> f32 {
    joints: [MAX_N_JOINTS]rl.Vector2
    n_joints := get_arm_joints(&ARM, joints[:])
    
    length_total: f32 = 0.0
    for i in 0..<arm.n_bones {
        length_total += arm.bone_lengths[i]
    }
    
    dist_to_target := rl.Vector2Distance(arm.start, arm.target)
    if dist_to_target >= length_total {
        // Clear all bone angles
        for i in 0..<len(arm.bone_angles) {
            arm.bone_angles[i] = 0
        }
        
        direction := rl.Vector2Normalize(arm.target - arm.start)
        arm.bone_angles[0] = rl.Vector2Angle({1.0, 0.0}, direction)
        
        return 0.0
    } else {
        // backward
        joints[n_joints-1] = arm.target
        for i := n_joints-2; i >= 0; i -= 1 {
            length := arm.bone_lengths[i]
            direction := rl.Vector2Normalize(joints[i] - joints[i+1])
            joints[i] = joints[i+1] + (direction * length)
        }
        
        // forward
        joints[0] = arm.start
        for i in 1..<n_joints {
            length := arm.bone_lengths[i-1]
            direction := rl.Vector2Normalize(joints[i] - joints[i-1])
            joints[i] = joints[i-1] + (direction * length)
        }
        
        // update arm angles
        angle_total: f32 = 0.0
        for i in 1..<n_joints {
            a := joints[i-1]
            b := joints[i]
            
            angle := rl.Vector2Angle({1.0, 0.0}, b - a)
            angle -= angle_total
            angle_total += angle
            
            arm.bone_angles[i-1] = angle
        }
        
        error := rl.Vector2Distance(joints[n_joints-1], arm.target)
        return error
    }
}

load :: proc() {
    // raylib
    rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "FABRIK Demo")
    rl.SetTargetFPS(60)
    rlgl.SetLineWidth(3.0)
    
    // arm
    ARM.start = {1.0, -1.0}
    ARM.n_bones = 4
    ARM.bone_angles[0] = -0.25 * math.PI
    ARM.bone_angles[1] = -0.25 * math.PI
    ARM.bone_angles[2] = -0.25 * math.PI
    ARM.bone_angles[3] = -0.25 * math.PI
    ARM.bone_lengths[0] = 0.9
    ARM.bone_lengths[1] = 1.0
    ARM.bone_lengths[2] = 1.5
    ARM.bone_lengths[3] = 0.7
}

update :: proc() {
    ARM.target = rl.GetScreenToWorld2D(rl.GetMousePosition(), CAMERA)
    
    for i in 0..<MAX_N_FABRIK_STEPS {
        error := fabrik_step(&ARM)
        if error < FABRIK_ERROR_MARGIN do break
    }
}

draw :: proc() {
    rl.BeginDrawing()
    rl.ClearBackground(BACKGROUND_COLOR)
    
    rl.BeginMode2D(CAMERA)
    
    draw_arm(&ARM)
    
    rl.EndMode2D()
    
    rl.DrawFPS(10, 10)
    rl.EndDrawing()
}

main :: proc() {
    load()
    
    for !rl.WindowShouldClose() {
        update()
        draw()
    }
    
    rl.CloseWindow()
}