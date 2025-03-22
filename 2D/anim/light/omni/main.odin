package lighting

/*******************************************************************************************
*
*   2d lighting effect using ray casting 
*   
*   Created by Evan Martinez (@Nave55)
*
*   https://github.com/Nave55/Odin-Raylib-Examples/blob/main/Random/2d_lighting.odin
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

S_WIDTH ::  1280
S_HEIGHT :: 800
obstacles:  [7]Obstacle
edges:      [8]rl.Vector2
intersects: [dynamic]rl.Vector2
m_pos:      rl.Vector2

main :: proc() {
    rl.InitWindow(S_WIDTH, S_HEIGHT, "Template")
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

rayCasting :: proc() {
    //cursor
    m_pos = rl.GetMousePosition()
    
    clear(&intersects)

    // create array of all intersects
    for i in obstacles {
        for j in i.vertices {
            new1 := lineOffset(m_pos, j, 0.00001)
            new2 := lineOffset(m_pos, j, -0.00001)
            append_elems(&intersects, j)
            append_elems(&intersects, (new1 + (new1 - m_pos) * 100))
            append_elems(&intersects, (new2 + (new2 - m_pos) * 100))
        }
    }

    // create rays that intersect with screen corners
    for i in 0..<4 {
        k := i < 2 ? 0 : 2
        l_inter := lineIntersect(m_pos, edges[i], edges[k], edges[k + 1])
        if l_inter.result do append(&intersects, l_inter.pos)
    }

    // check if a ray that collides with a screen edge collides with an obstacle first and then alter it's position
    for &i in intersects {
        tmp: [dynamic]rl.Vector2; defer delete(tmp)
        distances: [dynamic]f32; defer delete(distances)
        for &j in obstacles {
            for k in 0..<len(j.vertices) - 1 {
                inter: Intersect
                inter = lineIntersect(m_pos, i, j.vertices[k], j.vertices[k + 1])
                if inter.result do append_elems(&tmp, inter.pos)
                if k == len(j.vertices) - 2 {
                    inter = lineIntersect(m_pos, i, j.vertices[k + 1], j.vertices[0])
                    if inter.result do append_elems(&tmp, inter.pos)
                }
            }
        }
        for k in 0..<len(tmp) do append(&distances, lg.distance(m_pos, tmp[k]))
        if tmp != nil do i = tmp[slice.min_index(distances[:])]
    }
}

drawFan :: proc() {
    // sort intersects by angle
    slice.sort_by(intersects[:], proc(i, j: rl.Vector2) -> bool {return rl.Vector2LineAngle(m_pos, i) < rl.Vector2LineAngle(m_pos, j)})
    
    // insert mouse pos at index 0 and first ray to end of array 
    inject_at(&intersects, 0, m_pos)
    append(&intersects, intersects[1])
    rl.DrawTriangleFan(raw_data(intersects), i32(len(intersects)), rl.LIGHTGRAY)
}

drawGame :: proc() {
    rl.BeginDrawing()
    defer rl.EndDrawing()
    rl.ClearBackground(rl.BLACK)

    for i in obstacles do rl.DrawPoly(i.center, i.sides, i.radius, 0, i.color)
    drawFan()
    rl.DrawCircleV(m_pos, 10, rl.YELLOW)
}

updateGame :: proc() {
    rayCasting()
    drawGame()
}
 
unloadGame :: proc() {
    for i in obstacles do delete(i.vertices)
    delete(intersects)
}