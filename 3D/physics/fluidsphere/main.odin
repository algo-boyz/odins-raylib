package main

import "core:fmt"
import "core:math"
import "core:slice"
import rl "vendor:raylib"

CIRC_STEPS :: 240 // Determines fineness of voxels

Polar3 :: struct { r, th, phi: f32 }

SCube :: struct {
    polar_pos:  Polar3,
    vector_pos: rl.Vector3,
    idx:        u32,
    neighbors:  [dynamic]u32,
    rvel:       f32,
}

spherical_to_cartesian :: proc(p: Polar3) -> rl.Vector3 {
    res: rl.Vector3
    res.y = p.r * math.cos(p.phi)
    res.x = p.r * math.sin(p.phi) * math.cos(p.th)
    res.z = p.r * math.sin(p.phi) * math.sin(p.th)
    return res
}

cartesian_to_spherical :: proc(v: rl.Vector3) -> Polar3 {
    res: Polar3
    res.r = rl.Vector3Length(v)
    res.phi = math.acos(v.y / res.r)
    res.th = math.atan2(v.z, v.x)
    return res
}

main :: proc() {
    surface_cubes: [dynamic]SCube
    defer delete(surface_cubes)
    
    // Init vector containing a sphere, surface made up of small cubes
    // Theta goes from 0 to 2PI on x-z plane. Phi goes from 0 to PI on the x-y plane.
    spacing:f32 = 2 * math.PI / CIRC_STEPS
    radius: f32 = 100
    cube_size := radius * spacing
    counter: u32
    
    // North pole
    c := SCube{
        polar_pos = {radius, 0, 0},
        rvel = 0,
        idx = 0,
    }
    c.vector_pos = spherical_to_cartesian(c.polar_pos)
    c.neighbors = make([dynamic]u32)
    append(&surface_cubes, c)
    counter += 1
    
    // Generate cubes for the sphere surface
    for k in 0..<CIRC_STEPS/2 {
        phi := f32(k) * spacing
        if phi == 0 do continue // Skip north pole, already added
        
        theta_steps := u32(f32(CIRC_STEPS) * math.sin(phi))
        if theta_steps == 0 do continue
        
        theta_spacing := 2 * math.PI / f32(theta_steps)
        
        for j in 0..<theta_steps {
            theta := f32(j) * theta_spacing
            
            c = SCube{
                polar_pos = {radius, theta, phi},
                rvel = 0,
                idx = counter,
            }
            c.vector_pos = spherical_to_cartesian(c.polar_pos)
            c.neighbors = make([dynamic]u32)
            append(&surface_cubes, c)
            counter += 1
        }
    }
    // South pole
    c = SCube{
        polar_pos = {radius, 0, math.PI},
        rvel = 0,
        idx = counter,
    }
    c.vector_pos = spherical_to_cartesian(c.polar_pos)
    c.neighbors = make([dynamic]u32)
    append(&surface_cubes, c)
    
    fmt.println("Number of Surface Cubes =", len(surface_cubes))
    
    // Find neighbors for each cube
    sizer := rl.Vector3{ cube_size, cube_size, cube_size }
    num_checks: u32 = 5
    
    for i in 0..<len(surface_cubes) {
        bbox1 := rl.BoundingBox{
            min = surface_cubes[i].vector_pos - sizer/1.5,
            max = surface_cubes[i].vector_pos + sizer/1.5,
        }
        clear(&surface_cubes[i].neighbors)
        
        // Only check nearby cubes
        start_idx := max(0, int(i) - int(num_checks * CIRC_STEPS))
        end_idx := min(len(surface_cubes), int(i) + int(num_checks * CIRC_STEPS))
        
        for j in start_idx..<end_idx {
            if j == i do continue
            
            bbox2 := rl.BoundingBox{
                min = surface_cubes[j].vector_pos - sizer/1.5,
                max = surface_cubes[j].vector_pos + sizer/1.5,
            }
            if rl.CheckCollisionBoxes(bbox1, bbox2) {
                append(&surface_cubes[i].neighbors, u32(j))
            }
        }
        if len(surface_cubes[i].neighbors) == 0 {
            fmt.println("Cube #", i, "has", len(surface_cubes[i].neighbors), "neighbors")
        }
    }
    rl.InitWindow(1200, 900, "Sphere Surface Sim")
    rl.SetTargetFPS(30)
    
    cam := rl.Camera3D{
        position = {0, 0, 300},
        target   = {},
        up       = {0, 1, 0},
        fovy     = 45,
        projection = .PERSPECTIVE,
    }
    diag_idx: u32
    diag: bool
    for !rl.WindowShouldClose() {
        rl.UpdateCamera(&cam, .FREE)
        
        if rl.IsKeyDown(.P) {
            if len(surface_cubes) > 4000 {
                surface_cubes[4000].polar_pos.r = radius + 30
                surface_cubes[4000].vector_pos = spherical_to_cartesian(surface_cubes[4000].polar_pos)
            }
        }
        if rl.IsKeyDown(.D) do diag = true
        if rl.IsKeyDown(.F) do diag = false

        if diag {
            if rl.IsKeyDown(.V) {
                if diag_idx > 0 do diag_idx -= 1
            }
            if rl.IsKeyDown(.B) {
                diag_idx += 1
                if diag_idx >= u32(len(surface_cubes)) {
                    diag_idx = u32(len(surface_cubes) - 1)
                }
            }
            if rl.IsKeyDown(.C) {
                if diag_idx >= 10 do diag_idx -= 10
            }
            if rl.IsKeyDown(.N) {
                diag_idx += 10
                if diag_idx >= u32(len(surface_cubes)) {
                    diag_idx = u32(len(surface_cubes) - 1)
                }
            }
            fmt.println("Cube #", diag_idx, "Neighbors:", len(surface_cubes[diag_idx].neighbors))
        }
        // Calculate radial velocity based on neighbors
        for i in 0..<len(surface_cubes) {
            nbs := surface_cubes[i].neighbors
            rdiff: f32
            
            for n in 0..<len(nbs) {
                neighbor_idx := nbs[n]
                rdiff += surface_cubes[neighbor_idx].polar_pos.r - surface_cubes[i].polar_pos.r
            }
            if len(nbs) > 0 {
                rdiff /= f32(len(nbs))
            }
            surface_cubes[i].rvel += rdiff
        }
        // Update positions
        for i in 0..<len(surface_cubes) {
            surface_cubes[i].polar_pos.r += surface_cubes[i].rvel
            surface_cubes[i].vector_pos = spherical_to_cartesian(surface_cubes[i].polar_pos)
        }
        rl.BeginDrawing()
        rl.ClearBackground(rl.BLACK)
        
        rl.BeginMode3D(cam)
        
        // Draw coordinate axes
        rl.DrawCube({}, 1, 1, 400, rl.ORANGE)
        rl.DrawCube({}, 400, 1, 1, rl.GREEN)
        rl.DrawCube({}, 1, 400, 1, rl.PINK)
        
        rl.DrawGrid(10, 1)
        rl.DrawCube({}, 2, 2, 2, rl.BROWN)
        
        // Draw cubes
        for i in 0..<len(surface_cubes) {
            color := rl.Fade(rl.RED, diag ? 0.4 : 0.8)
            rl.DrawCube(surface_cubes[i].vector_pos, cube_size, cube_size, cube_size, color)
            rl.DrawCubeWires(surface_cubes[i].vector_pos, cube_size, cube_size, cube_size, rl.BLACK)
        }
        // Draw info
        if diag && diag_idx < u32(len(surface_cubes)) {
            rl.DrawCube(surface_cubes[diag_idx].vector_pos, cube_size, cube_size, cube_size, rl.WHITE)
            
            for k in 0..<len(surface_cubes[diag_idx].neighbors) {
                neighbor_idx := surface_cubes[diag_idx].neighbors[k]
                if neighbor_idx < u32(len(surface_cubes)) {
                    rl.DrawCube(surface_cubes[neighbor_idx].vector_pos, cube_size, cube_size, cube_size, rl.Fade(rl.LIME, 0.5))
                }
            }
        }
        rl.EndMode3D()
        rl.EndDrawing()
    }
    rl.CloseWindow()
    for cube in surface_cubes {
        delete(cube.neighbors)
    }
}