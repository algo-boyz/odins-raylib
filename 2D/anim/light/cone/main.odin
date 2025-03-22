package lighting

/*******************************************************************************************
*
*   2d view cone effect using ray casting for RTS game mechanics
*   
*   Modified from Evan Martinez (@Nave55)'s lighting example
*
********************************************************************************************/

import rl "vendor:raylib"
import lg "core:math/linalg"
import "core:math"
import "core:fmt"
import "core:slice"

Intersect :: struct {
    result: bool,
    pos:    rl.Vector2,
}

Obstacle :: struct {
    center:   rl.Vector2,
    radius:   f32,
    sides:    i32,
    color:    rl.Color,
    vertices: [dynamic]rl.Vector2,
}

Player :: struct {
    position:    rl.Vector2,
    direction:   f32,  // Direction in radians
    speed:       f32,
    view_angle:  f32,  // Field of view angle in radians
    view_range:  f32,  // How far the player can see
}

S_WIDTH ::  1280
S_HEIGHT :: 800
obstacles:  [7]Obstacle
edges:      [8]rl.Vector2
intersects: [dynamic]rl.Vector2
player:     Player

main :: proc() {
    rl.InitWindow(S_WIDTH, S_HEIGHT, "RTS View Cone Demo")
    defer rl.CloseWindow()
    rl.SetTargetFPS(60)
    defer unloadGame() 
    initGame()

    for !rl.WindowShouldClose() do updateGame()
}

// create polygon based off values
createPoly :: proc(i: ^Obstacle, center: rl.Vector2, sides: i32, radius: f32, color: rl.Color, ) {
    i.center = center
    i.sides = sides
    i.radius = radius
    i.color = color

    // create list of vertices for poly
    for j in 0..<i.sides {
        pos: rl.Vector2 = {i.center.x + math.sin(f32(j * 360 / i.sides + 90) * rl.DEG2RAD) * i.radius, 
                           i.center.y + math.cos(f32(j * 360 / i.sides + 90) * rl.DEG2RAD) * i.radius}
        append(&i.vertices, pos)
    }
}
 
initGame :: proc() {
    // screen edges
    edges = {{-S_WIDTH, -S_HEIGHT}, {S_WIDTH * 2, -S_HEIGHT},  // top edge
             {-S_WIDTH, S_HEIGHT * 2}, {S_WIDTH * 2, S_HEIGHT * 2},  // bottom edge
             {-S_WIDTH, -S_HEIGHT}, {-S_WIDTH, S_HEIGHT * 2}, // left edge
             {S_WIDTH * 2, -S_HEIGHT}, {S_WIDTH * 2, S_HEIGHT * 2}} // right edge

    // create polys
    createPoly(&obstacles[0], {100, 300}, 3, 90, rl.DARKGRAY)
    createPoly(&obstacles[1], {260, 130}, 4, 80, rl.DARKGRAY)
    createPoly(&obstacles[2], {1100, 400}, 5, 60, rl.DARKGRAY)
    createPoly(&obstacles[3], {700, 200}, 6, 80, rl.DARKGRAY)
    createPoly(&obstacles[4], {320, 600}, 7, 70, rl.DARKGRAY)
    createPoly(&obstacles[5], {800, 700}, 8, 100, rl.DARKGRAY)
    createPoly(&obstacles[6], {620, 450}, 3, 75, rl.DARKGRAY)
    
    // Initialize player
    player = {
        position = {S_WIDTH / 2, S_HEIGHT / 2},
        direction = 0,                      // Facing right initially
        speed = 5.0,                        // Movement speed
        view_angle = 90 * rl.DEG2RAD,       // 90 degree field of view
        view_range = 500,                   // View distance
    }
}

// checks if two lines intersect
lineIntersect :: proc(a, b, c, d: rl.Vector2) -> Intersect {
    r := (b - a)
    s := (d - c)
    rxs := lg.vector_cross2(r, s)
    cma := c - a
    t := lg.vector_cross2(cma, s) / rxs
    u := lg.vector_cross2(cma, r) / rxs
    if t >= 0 && t <= 1 && u >= 0 && u <= 1 do return {true, {a.x + t * r.x, a.y + t * r.y}}
    else do return {false, {0, 0}}
}

// offsets vector2 by radian value
lineOffset :: proc(start, end: rl.Vector2, angle: f32) -> rl.Vector2 {
    x_diff := end.x - start.x
    y_diff := end.y - start.y

    new_x := start.x + math.cos(angle) * x_diff - math.sin(angle) * y_diff
    new_y := start.y + math.sin(angle) * x_diff + math.cos(angle) * y_diff

    return {new_x, new_y}
}

// Get a point at a certain angle and distance from the player
getPointOnViewCone :: proc(angle: f32, distance: f32) -> rl.Vector2 {
    return {
        player.position.x + math.cos(player.direction + angle) * distance,
        player.position.y + math.sin(player.direction + angle) * distance,
    }
}

rayCasting :: proc() {
    clear(&intersects)

    // Create rays that form the view cone
    num_rays := 50 // Number of rays to cast within the view cone
    half_angle := player.view_angle / 2

    // Add rays for view cone edges
    left_edge := getPointOnViewCone(-half_angle, player.view_range)
    right_edge := getPointOnViewCone(half_angle, player.view_range)
    
    append(&intersects, left_edge)
    append(&intersects, right_edge)

    // Add rays within the view cone
    for i in 1..<num_rays-1 {
        angle := -half_angle + (player.view_angle * f32(i) / f32(num_rays-1))
        ray_end := getPointOnViewCone(angle, player.view_range)
        append(&intersects, ray_end)
    }

    // Create rays to vertices of obstacles within view cone
    for i in obstacles {
        for j in i.vertices {
            // Check if vertex is within view cone
            angle_to_vertex := math.atan2(j.y - player.position.y, j.x - player.position.x)
            
            // Normalize angle difference to be between -π and π
            angle_diff := angle_to_vertex - player.direction
            for angle_diff > math.PI do angle_diff -= 2 * math.PI
            for angle_diff < -math.PI do angle_diff += 2 * math.PI
            
            if math.abs(angle_diff) <= half_angle {
                // Vertex is within view cone
                distance := lg.distance(player.position, j)
                if distance <= player.view_range {
                    new1 := lineOffset(player.position, j, 0.00001)
                    new2 := lineOffset(player.position, j, -0.00001)
                    append_elems(&intersects, j)
                    append_elems(&intersects, (new1 + (new1 - player.position) * 100))
                    append_elems(&intersects, (new2 + (new2 - player.position) * 100))
                }
            }
        }
    }

    // Check for screen edge intersections within view cone
    for i in 0..<4 {
        k := i < 2 ? 0 : 2
        
        // Check left edge ray intersection
        l_inter := lineIntersect(player.position, left_edge, edges[k], edges[k + 1])
        if l_inter.result do append(&intersects, l_inter.pos)
        
        // Check right edge ray intersection
        r_inter := lineIntersect(player.position, right_edge, edges[k], edges[k + 1])
        if r_inter.result do append(&intersects, r_inter.pos)
    }

    // Check if rays collide with obstacles and adjust accordingly
    for &i in intersects {
        tmp: [dynamic]rl.Vector2; defer delete(tmp)
        distances: [dynamic]f32; defer delete(distances)
        
        // First add the view range limited ray end point
        ray_dir := rl.Vector2Normalize({i.x - player.position.x, i.y - player.position.y})
        ray_limit := rl.Vector2{
            player.position.x + ray_dir.x * player.view_range,
            player.position.y + ray_dir.y * player.view_range
        }
        
        // Check distance to original point
        original_distance := lg.distance(player.position, i)
        
        // If original point is beyond view range, use the limited point instead
        if original_distance > player.view_range {
            append(&tmp, ray_limit)
            append(&distances, player.view_range)
        }
        
        // Check obstacle intersections
        for &j in obstacles {
            for k in 0..<len(j.vertices) - 1 {
                inter := lineIntersect(player.position, i, j.vertices[k], j.vertices[k + 1])
                if inter.result {
                    dist := lg.distance(player.position, inter.pos)
                    if dist <= player.view_range {
                        append(&tmp, inter.pos)
                        append(&distances, dist)
                    }
                }
                
                if k == len(j.vertices) - 2 {
                    inter = lineIntersect(player.position, i, j.vertices[k + 1], j.vertices[0])
                    if inter.result {
                        dist := lg.distance(player.position, inter.pos)
                        if dist <= player.view_range {
                            append(&tmp, inter.pos)
                            append(&distances, dist)
                        }
                    }
                }
            }
        }
        
        // Update the ray endpoint to the closest intersection
        if len(tmp) > 0 {
            i = tmp[slice.min_index(distances[:])]
        } else {
            // If no intersections, make sure the ray doesn't exceed view range
            ray_dist := lg.distance(player.position, i)
            if ray_dist > player.view_range {
                i = ray_limit
            }
        }
    }
}

drawViewCone :: proc() {
    // Sort intersects by angle from player position
    slice.sort_by(intersects[:], proc(i, j: rl.Vector2) -> bool {
        return rl.Vector2LineAngle(player.position, i) < rl.Vector2LineAngle(player.position, j)
    })
    
    // Insert player position at beginning and first ray at end to complete the fan
    inject_at(&intersects, 0, player.position)
    append(&intersects, intersects[1])
    
    // Draw the view cone
    rl.DrawTriangleFan(raw_data(intersects), i32(len(intersects)), {200, 200, 230, 180}) // Light blue with transparency
}

drawDirectionIndicator :: proc() {
    // Draw a line indicating the player's direction
    indicator_length :f32 = 30.0
    end_point := rl.Vector2{
        player.position.x + math.cos(player.direction) * indicator_length,
        player.position.y + math.sin(player.direction) * indicator_length,
    }
    rl.DrawLineEx(player.position, end_point, 3, rl.RED)
}

updatePlayer :: proc() {
    // Rotate player with A and D keys
    if rl.IsKeyDown(.A) do player.direction -= 0.05
    if rl.IsKeyDown(.D) do player.direction += 0.05
    
    // Move player forward and backward with W and S keys
    move_dir := rl.Vector2{0, 0}
    if rl.IsKeyDown(.W) {
        move_dir.x += math.cos(player.direction) * player.speed
        move_dir.y += math.sin(player.direction) * player.speed
    }
    if rl.IsKeyDown(.S) {
        move_dir.x -= math.cos(player.direction) * player.speed
        move_dir.y -= math.sin(player.direction) * player.speed
    }
    
    // Move player sideways with Q and E keys (strafe)
    if rl.IsKeyDown(.Q) {
        move_dir.x += math.cos(player.direction - math.PI/2) * player.speed
        move_dir.y += math.sin(player.direction - math.PI/2) * player.speed
    }
    if rl.IsKeyDown(.E) {
        move_dir.x += math.cos(player.direction + math.PI/2) * player.speed
        move_dir.y += math.sin(player.direction + math.PI/2) * player.speed
    }
    
    // Apply movement
    player.position.x += move_dir.x
    player.position.y += move_dir.y
    
    // Keep player within screen bounds
    player.position.x = math.clamp(player.position.x, 20, S_WIDTH - 20)
    player.position.y = math.clamp(player.position.y, 20, S_HEIGHT - 20)
}

drawGame :: proc() {
    rl.BeginDrawing()
    defer rl.EndDrawing()
    rl.ClearBackground(rl.BLACK)
    
    // Draw game elements
    for i in obstacles do rl.DrawPoly(i.center, i.sides, i.radius, 0, i.color)
    
    // Draw visible area
    drawViewCone()
    
    // Draw player
    rl.DrawCircleV(player.position, 15, rl.YELLOW)
    drawDirectionIndicator()
    
    // Draw instructions
    rl.DrawText("Controls: W/S - Move forward/backward, A/D - Rotate, Q/E - Strafe", 20, 20, 20, rl.WHITE)
}

updateGame :: proc() {
    updatePlayer()
    rayCasting()
    drawGame()
}
 
unloadGame :: proc() {
    for i in obstacles do delete(i.vertices)
    delete(intersects)
}