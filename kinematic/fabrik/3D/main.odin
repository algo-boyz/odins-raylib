package main

import "core:fmt"
import "core:math"
import rl "vendor:raylib"

WIDTH       :: 800
HEIGHT      :: 600
SPEED       :: 0.1
DBG         :: true
STEP_TIME   :: 0.20
LINK_SIZE   :: 1.0
LINK_NUM    :: 4
SPACING     :: 0.2
IV_ITER     :: 1
VERLET_ITER :: 8
BORDER      :: 4.0
BOUNCE      :: 0.5
JOINT_RAD   :: 0.1
LINK_RAD    :: 0.05
LINK_SEG    :: 16
GRAVITY     :: rl.Vector3{0, -9.81, 0}
cam: rl.Camera3D
cnt: int

ClothPoint :: struct {
    position, old_position, acceleration: rl.Vector3,
    constrained:  bool,
}

ClothLink :: struct {
    x1, x2: int,
    target: f32,
}

Cloth :: struct {
    points: [dynamic]ClothPoint,
    links:  [dynamic]ClothLink,
    n_point, n_link:  int,
}

ArmLink :: struct {
    start, end:  rl.Vector3,
    length: f32,
}

Arm :: struct {
    links:   [LINK_NUM]ArmLink,
    anchor:  rl.Vector3,
    n_links: int,
}

Plant :: struct {
    cloths:  [LINK_NUM]^Cloth,
    arm:     ^Arm,
    n_cloth: int,
}

init_cam :: proc() {
    cam = rl.Camera3D{
        position   = {4.0, 4.0, 4.0},
        target     = {0.0, 0.0, 0.0},
        up         = {0.0, 1.0, 0.0},
        fovy       = 45.0,
        projection = .PERSPECTIVE,
    }
}

move_cam_dir :: proc(direction: rl.Vector3) {
    cam.position = cam.position + direction
    cam.target = cam.target + direction
    rl.UpdateCamera(&cam, .FREE)
}

move_cam_target :: proc(target: rl.Vector3) {
    cam.target += target
    rl.UpdateCamera(&cam, .FREE)
}

move_cam_forward :: proc(speed: f32) {
    forward := rl.Vector3Normalize(cam.target - cam.position)
    move_cam_dir(forward * speed)
}

strafe_cam :: proc(speed: f32) {
    forward := rl.Vector3Normalize(cam.target - cam.position)
    up := rl.Vector3{0.0, 1.0, 0.0}
    side := rl.Vector3Normalize(rl.Vector3CrossProduct(forward, up))
    move_cam_dir(side * speed)
}

handle_input :: proc() {
    if rl.IsKeyDown(.RIGHT) {
        strafe_cam(SPEED)
    }
    if rl.IsKeyDown(.LEFT) {
        strafe_cam(-SPEED)
    }
    if rl.IsKeyDown(.PAGE_UP) {
        move_cam_dir({0.0, SPEED, 0.0})
    }
    if rl.IsKeyDown(.PAGE_DOWN) {
        move_cam_dir({0.0, -SPEED, 0.0})
    }
    if rl.IsKeyDown(.DOWN) {
        move_cam_forward(SPEED)
    }
    if rl.IsKeyDown(.UP) {
        move_cam_forward(-SPEED)
    }
    if rl.IsMouseButtonDown(.LEFT) {
        delta := rl.GetMouseDelta()
        move_cam_target({-delta.x * 0.05, -delta.y * 0.05, 0.0})
    }
}

draw :: proc(step: int) {
    rl.DrawText(fmt.ctprintf("%d", rl.GetFPS()), 10, 10, 16, rl.RAYWHITE)
    when DBG {
        rl.DrawText(fmt.ctprintf("Position: (%.2f, %.2f, %.2f)", cam.position.x, cam.position.y, cam.position.z), 10, 30, 16, rl.RAYWHITE)
        rl.DrawText(fmt.ctprintf("Step: %d", step), 10, 50, 16, rl.RAYWHITE)
    }
}

find_point :: proc(cloth: ^Cloth, pos: rl.Vector3, eps: f32) -> int {
    for i in 0..<cloth.n_point {
        p := cloth.points[i].position
        if abs(p.x - pos.x) < eps && 
           abs(p.y - pos.y) < eps && 
           abs(p.z - pos.z) < eps {
            return i
        }
    }
    return -1
}

add_point :: proc(cloth: ^Cloth, pos: rl.Vector3, constrained: bool) -> int {
    idx := find_point(cloth, pos, 0.001)
    if idx >= 0 {
        return idx
    }
    append(&cloth.points, ClothPoint{
        position     = pos,
        old_position = pos,
        acceleration = {0.0, 0.0, 0.0},
        constrained  = constrained,
    })
    cloth.n_point += 1
    return cloth.n_point - 1
}

add_link :: proc(cloth: ^Cloth, x1, x2: rl.Vector3, target: f32, constrained: bool) {
    idx1 := add_point(cloth, x1, constrained)
    idx2 := add_point(cloth, x2, constrained)
    if idx1 == idx2 {
        return
    }
    // Check if link already exists
    for i in 0..<cloth.n_link {
        if (cloth.links[i].x1 == idx1 && cloth.links[i].x2 == idx2) ||
           (cloth.links[i].x1 == idx2 && cloth.links[i].x2 == idx1) {
            return
        }
    }
    append(&cloth.links, ClothLink{x1 = idx1, x2 = idx2, target = target})
    cloth.n_link += 1
}

cloth_new :: proc(position, directionx, directiony: rl.Vector3, n_node_x, n_node_y: int) -> ^Cloth {
    cloth := new(Cloth)
    cloth.points = make([dynamic]ClothPoint)
    cloth.links = make([dynamic]ClothLink)
    cloth.n_point = 0
    cloth.n_link = 0
    for y in 0..<n_node_y {
        for x in 0..<n_node_x {
            x1 := (position + (directiony * f32(y))) + (directionx * f32(x))
            if x != n_node_x - 1 {
                x2 := (position + (directiony * f32(y))) + (directionx * f32(x + 1))
                if y == 0 {
                    add_link(cloth, x1, x2, rl.Vector3Length(directionx), true)
                } else {
                    add_link(cloth, x1, x2, rl.Vector3Length(directionx), false)
                }
            }
            if y == n_node_y - 1 {
                continue
            }
            y2 := x1 + directiony
            add_link(cloth, x1, y2, rl.Vector3Length(directionx), false)
        }
    }
    return cloth
}

move_cloth :: proc(cloth: ^Cloth, position, directionx: rl.Vector3) {
    count := 0
    for i in 0..<cloth.n_point {
        if cloth.points[i].constrained {
            cloth.points[i].position = position + directionx * f32(count)
            count += 1
        }
    }
}

draw_cloth :: proc(cloth: ^Cloth) {
    for i in 0..<cloth.n_link {
        link := cloth.links[i]
        rl.DrawLine3D(cloth.points[link.x1].position, cloth.points[link.x2].position, rl.RAYWHITE)
    }
}

free_cloth :: proc(cloth: ^Cloth) {
    if cloth == nil do return
    delete(cloth.points)
    delete(cloth.links)
    free(cloth)
}

// Verlet integration
verlet_point :: proc(point: ^ClothPoint, dt: f32) {
    if point.constrained {
        return
    }
    velocity := point.position - point.old_position
    point.old_position = point.position
    point.position = point.position + velocity + point.acceleration * dt * dt
}

verlet_point_solver :: proc(cloth: ^Cloth, dt: f32) {
    for i in 0..<cloth.n_point {
        cloth.points[i].acceleration = GRAVITY
        verlet_point(&cloth.points[i], dt)
    }
}

verlet_link :: proc(cloth: ^Cloth, link: ^ClothLink) {
    x1 := &cloth.points[link.x1]
    x2 := &cloth.points[link.x2]
    
    axis := x1.position - x2.position
    length := rl.Vector3Length(axis)
    
    if length < 0.0001 {
        return
    }
    n := axis * ( 1 / length )
    delta := link.target - length
    
    if x1.constrained && x2.constrained {
        return
    } else if x1.constrained {
        x2.position = x2.position - (n * delta)
    } else if x2.constrained {
        x1.position += (n * delta)
    } else {
        x1.position += (n * delta * 0.5)
        x2.position -= (n * delta * 0.5)
    }
}

update_cloth :: proc(cloth: ^Cloth, dt: f32) {
    verlet_point_solver(cloth, dt)
    for _ in 0..<VERLET_ITER {
        for i in 0..<cloth.n_link {
            verlet_link(cloth, &cloth.links[i])
        }
    }
}

// Kinematics
init_arm :: proc(start: rl.Vector3) -> ^Arm {
    arm := new(Arm)
    arm.n_links = 0
    
    for i in 0..<LINK_NUM {
        link := ArmLink{
            start  = {f32(i), f32(i), 0.0},
            end    = {f32(i + 1), f32(i + 1), 0.0},
            length = LINK_SIZE,
        }
        arm.links[i] = link
        arm.n_links += 1
    }
    arm.anchor = start
    return arm
}

backward_kinematics :: proc(arm: ^Arm, target: rl.Vector3) {
    arm.links[arm.n_links - 1].end = target
    
    for i := arm.n_links - 1; i > 0; i -= 1 {
        curr := &arm.links[i]
        dir := curr.start - curr.end
        norm := rl.Vector3Normalize(dir)
        curr.start = curr.end + (norm * curr.length)
        arm.links[i - 1].end = curr.start
    }
}

forward_kinematics :: proc(arm: ^Arm) {
    arm.links[0].start = arm.anchor
    
    for i in 0..<arm.n_links {
        curr := &arm.links[i]
        dir := curr.end - curr.start
        norm := rl.Vector3Normalize(dir)
        curr.end = curr.start + (norm * curr.length)
        
        if i < arm.n_links - 1 {
            arm.links[i + 1].start = curr.end
        }
    }
}

fabrik :: proc(arm: ^Arm, target: rl.Vector3) {
    for _ in 0..<IV_ITER {
        backward_kinematics(arm, target)
        forward_kinematics(arm)
    }
}

render_arm :: proc(arm: ^Arm) {
    for i in 0..<arm.n_links {
        start := arm.links[i].start
        end := arm.links[i].end
        rl.DrawSphere(start, JOINT_RAD, rl.WHITE)
        rl.DrawCylinderEx(start, end, LINK_RAD, LINK_RAD, LINK_SEG, rl.WHITE)
    }
}

init_plant :: proc(position: rl.Vector3) -> ^Plant {
    plant := new(Plant)
    plant.arm = init_arm(position)
    
    for i in 0..<LINK_NUM {
        start := plant.arm.links[i].start
        end := plant.arm.links[i].end
        axis := end - start
        dirx := axis * (1.0 / 5.0)
        diry := rl.Vector3{0, -1, 0} * ( 1.0 / 5.0 )
        cloth := cloth_new(start, dirx, diry, 5, 5)
        plant.cloths[i] = cloth
    }
    plant.n_cloth = LINK_NUM
    return plant
}

update_plant :: proc(plant: ^Plant, target: rl.Vector3, dt: f32) {
    fabrik(plant.arm, target)
    
    for i in 0..<plant.n_cloth {
        start := plant.arm.links[i].start
        end := plant.arm.links[i].end
        axis := end - start
        move_cloth(plant.cloths[i], start, axis * ( 1.0 / 5.0 ))
        update_cloth(plant.cloths[i], dt)
    }
}

draw_plant :: proc(plant: ^Plant) {
    render_arm(plant.arm)
    for i in 0..<plant.n_cloth {
        draw_cloth(plant.cloths[i])
    }
}

destroy :: proc(plant: ^Plant) {
    free(plant.arm)
    for i in 0..<plant.n_cloth {
        free_cloth(plant.cloths[i])
    }
    free(plant)
}

// Step checking
count_step :: proc(now: f32) -> int {
    step := int(now / STEP_TIME)
    if step > cnt {
        cnt = step
    }
    return cnt
}

main :: proc() {
    rl.InitWindow(WIDTH, HEIGHT, "Inverse Kinematics 3D Cloth Sim")
    defer rl.CloseWindow()
    rl.SetTargetFPS(60)
    
    plant := init_plant({0, 0, 0})
    defer destroy(plant)

    init_cam()
    now: f32

    for !rl.WindowShouldClose() {
        handle_input()
        dt := clamp(rl.GetFrameTime(), 0.001, 0.016)
        now += dt
        target := rl.Vector3{
            2.0 * math.cos(now) * math.sin(3.0 * now),
            2.0 * abs(math.cos(0.5 * now)),
            2.0 * math.sin(1.0 * now),
        }
        update_plant(plant, target, dt)

        rl.BeginDrawing()
        rl.ClearBackground({50, 50, 50, 255})
        
        rl.BeginMode3D(cam)
        rl.DrawGrid(16, BORDER)
        rl.DrawSphere(target, 0.1, rl.RED)
        draw_plant(plant)
        rl.EndMode3D()
        
        draw(count_step(now))
        rl.EndDrawing()
    }
}