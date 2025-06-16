package main

import "core:fmt"
import "core:math"
import "core:math/rand"
import rl "vendor:raylib"
import controller "controller"
import "env"
import planner "planner"

// based on: https://github.com/harsh2507/3d_mapping_rrt-

main :: proc() {
    // --- Initialization ---
    screenWidth: i32 = 1000
    screenHeight: i32 = 800

    rl.InitWindow(screenWidth, screenHeight, "RRT* 3D Navigation in Odin")
    defer rl.CloseWindow()

    rl.SetTargetFPS(60)

    // --- Camera Setup ---
    camera := rl.Camera3D{
        position   = {20.0, 20.0, 20.0},
        target     = {0.0, 0.0, 0.0},
        up         = {0.0, 1.0, 0.0},
        fovy       = 60.0,
        projection = .PERSPECTIVE,
    }

    // --- Scene and Planner Setup ---
    startPos := rl.Vector3{5.0, 1.0, -3.0}
    goalPos := rl.Vector3{-8.0, 1.0, -5.0}
    robotPosition := startPos
    robotRadius: f32 = 1.0

    // Initialize the planner with start, goal, and the environment's obstacles
    planner.initialize_planner(startPos, goalPos, &env.obstacles, robotRadius)

    pathPoints := planner.get_full_path()
    currentPathIndex := 0
    reachThreshold: f32 = 0.5

    // --- Main Game Loop ---
    for !rl.WindowShouldClose() {
        deltaTime := rl.GetFrameTime()

        // --- Camera Controls ---
        // Zoom with mouse wheel
        wheel := rl.GetMouseWheelMove()
        if wheel != 0 {
            forward := rl.Vector3Normalize(camera.target - camera.position)
            camera.position += (forward * wheel * 2)
        }
        // Use standard camera controls
        rl.UpdateCamera(&camera, .ORBITAL)


        // --- Planner and Path Following ---
        // Keep planning until the goal is reached
        if !planner.is_planning_complete() {
            planner.plan_step()
            // Get the updated path if it has changed
            pathPoints = planner.get_full_path()
            currentPathIndex = 0 // Reset path index when path updates
        }

        // Move the robot along the generated path
        if len(pathPoints) > 0 && currentPathIndex < len(pathPoints) {
            targetPoint := pathPoints[currentPathIndex]
            toTarget := targetPoint - robotPosition
            distToTarget := rl.Vector3Length(toTarget)

            // If we've reached the current target, move to the next one
            if distToTarget < reachThreshold && currentPathIndex < len(pathPoints)-1 {
                currentPathIndex += 1
            } else {
                // Move towards the target point
                dir := rl.Vector3Normalize(toTarget)
                speed: f32 = 4.0
                robotPosition = (dir * speed * deltaTime)
            }
        }

        // --- Drawing ---
        rl.BeginDrawing()
        rl.ClearBackground(rl.RAYWHITE)

        rl.BeginMode3D(camera)
        {
            env.draw_environment()
            planner.draw_planner()
            
            // Draw the robot, goal, and start positions
            rl.DrawSphere(robotPosition, robotRadius, rl.BLUE)
            rl.DrawSphere(goalPos, robotRadius * 0.5, rl.GREEN)
            rl.DrawSphere(startPos, robotRadius * 0.5, rl.ORANGE)

            // Draw a ground plane for better visualization
            rl.DrawGrid(20, 2.0)
        }
        rl.EndMode3D()

        rl.DrawText("RRT* Path Planning in Odin", 10, 10, 20, rl.DARKGRAY)
        rl.DrawFPS(10, 40)

        rl.EndDrawing()
    }
}