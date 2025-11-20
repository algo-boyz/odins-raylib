package main

import rl "vendor:raylib"

WIDTH  :: 1280
HEIGHT :: 720

Link :: struct {
    position: rl.Vector2,
    size: f32,
}

Chain :: struct {
    joints: [dynamic]Link,
    link_size: f32,
    mode: int, // 0: keyboard, 1: mouse follow, 2: FABRIK
    anchor_position: rl.Vector2,
}

new_chain :: proc(chain_size: int, link_size: f32) -> (chain: Chain) {
    chain.link_size = link_size
    chain.mode = 0  // Start in keyboard mode
    chain.anchor_position = rl.Vector2{cast(f32)(WIDTH / 2), cast(f32)(HEIGHT / 2)}
    chain.joints = make([dynamic]Link)

    first_joint := Link {
        position = rl.Vector2{
            cast(f32)(WIDTH / 2 - 150), 
            cast(f32)(HEIGHT / 2)
        },
        size = 8,
    }
    append(&chain.joints, first_joint)

    for i in 1..<chain_size {
        prev_joint := chain.joints[i-1]
        next_joint := Link {
            position = rl.Vector2{
                prev_joint.position.x + link_size, 
                prev_joint.position.y  // Keep same Y to start straight
            },
            size = 8,
        }
        append(&chain.joints, next_joint)
    }

    return chain
}

update_position :: proc(chain: ^Chain) {
    // Toggle between modes
    if rl.IsKeyPressed(rl.KeyboardKey.SPACE) {
        chain.mode = (chain.mode + 1) % 3
    }
    
    if chain.mode == 0 {
        // Keyboard control
        if rl.IsKeyDown(rl.KeyboardKey.UP) {
            chain.joints[0].position.y -= 3
        }
        if rl.IsKeyDown(rl.KeyboardKey.DOWN) {
            chain.joints[0].position.y += 3
        }
        if rl.IsKeyDown(rl.KeyboardKey.LEFT) {
            chain.joints[0].position.x -= 3
        }
        if rl.IsKeyDown(rl.KeyboardKey.RIGHT) {
            chain.joints[0].position.x += 3
        }
    } else if chain.mode == 1 {
        // Mouse following mode - only update head pos
        mouse_pos := rl.GetMousePosition()
        chain.joints[0].position = mouse_pos
    } else if chain.mode == 2 {
        // FABRIK mode - target follows mouse, chain is anchored
        // Target position is the mouse, anchor is fixed
    }
    // Solve Chain
    move_body(chain)
}

move_body :: proc(chain: ^Chain) {
    if chain.mode == 0 {
        // Keyboard mode - apply constraints multiple times for stability
        for iteration in 0..<3 {
            for i in 1..<len(chain.joints) {
                constraint_distance(&chain.joints[i-1], &chain.joints[i], chain.link_size)
            }
        }
    } else if chain.mode == 1 {
        // Mouse follow mode
        for i in 1..<len(chain.joints) {
            target := chain.joints[i-1].position
            current := chain.joints[i].position
            
            delta := target - current
            distance := rl.Vector2Length(delta)
            
            if distance > chain.link_size {
                // Pull joint toward target if too distant
                chain.joints[i].position = constrain_distance(current, target, chain.link_size)
            }
        }
    } else if chain.mode == 2 {
        // FABRIK mode
        fabrik_solve(chain)
    }
}

constraint_distance :: proc(head, tail: ^Link, link_size: f32) {
    delta := head.position - tail.position
    current_distance := rl.Vector2Length(delta)
    
    if current_distance < 0.001 do return  // Avoid division by zero
    
    if current_distance > link_size {
        // Only adjust when distance is greater than link size
        scale := link_size / current_distance
        direction := delta * scale
        tail.position = head.position - direction
    }
}

// Constraint function for mouse follow
constrain_distance :: proc(point, anchor: rl.Vector2, distance: f32) -> rl.Vector2 {
    delta := point - anchor
    length := rl.Vector2Length(delta)
    
    if length < 0.001 do return point  // Avoid division by zero
    
    normalized := delta * 1.0 / length
    return anchor + (normalized * distance)
}

// FABRIK algorithm implementation
fabrik_solve :: proc(chain: ^Chain) {
    if len(chain.joints) < 2 do return
    
    target := rl.GetMousePosition()
    anchor := chain.anchor_position
    
    // Forward reaching - start from target and work backwards
    chain.joints[0].position = target
    
    for i in 0..<len(chain.joints)-1 {
        current := chain.joints[i].position
        next := chain.joints[i+1].position
        
        chain.joints[i+1].position = constrain_distance(next, current, chain.link_size)
    }
    
    // Backward reaching - start from anchor and work forwards
    last_index := len(chain.joints) - 1
    chain.joints[last_index].position = anchor
    
    for i := last_index; i > 0; i -= 1 {
        current := chain.joints[i].position
        prev := chain.joints[i-1].position
        
        chain.joints[i-1].position = constrain_distance(prev, current, chain.link_size)
    }
}

main :: proc() {
    rl.InitWindow(WIDTH, HEIGHT, "Procedural Chain Animation")
    defer rl.CloseWindow()

    chain := new_chain(8, 50)
    defer delete(chain.joints)

    rl.SetTargetFPS(60)

    for !rl.WindowShouldClose() {
        update_position(&chain)

        rl.BeginDrawing()
        rl.ClearBackground(rl.DARKGRAY)

        // Draw mode indicator
        mode_names := [3]string{"Keyboard Mode", "Mouse Follow", "FABRIK Mode"}
        rl.DrawText(rl.TextFormat("%s (Press SPACE to cycle)", mode_names[chain.mode]), 10, 10, 20, rl.WHITE)
        
        // Draw mouse cursor in mouse modes
        if chain.mode == 1 || chain.mode == 2 {
            mouse_pos := rl.GetMousePosition()
            rl.DrawCircleV(mouse_pos, 3, rl.RED)
        }
        
        // Draw anchor point in FABRIK mode
        if chain.mode == 2 {
            rl.DrawCircleV(chain.anchor_position, 8, rl.GREEN)
            rl.DrawText("ANCHOR", cast(i32)(chain.anchor_position.x - 25), cast(i32)(chain.anchor_position.y + 15), 16, rl.GREEN)
        }

        // Draw links between joints
        for i in 1..<len(chain.joints) {
            rl.DrawLineEx(
                chain.joints[i-1].position, 
                chain.joints[i].position, 
                3.0, 
                rl.LIGHTGRAY
            )
        }

        // Draw joints with different colors for different modes
        joint_color := rl.WHITE
        if chain.mode == 2 do joint_color = rl.YELLOW
        
        for joint in chain.joints {
            rl.DrawCircleV(joint.position, joint.size, joint_color)
        }

        rl.EndDrawing()
    }
}