package main

import "core:fmt"
import "core:math"
import "core:mem"
import "core:slice"
import "core:time"
import "core:strings"
import rl "vendor:raylib"
import kd "../../../trees/kd/kd2d"

WORLD_WIDTH :: 200.0
WORLD_HEIGHT :: 160.0
WINDOW_WIDTH :: 1200
WINDOW_HEIGHT :: 900
GRID_SIZE :: 4.0
MOVE_STEP :: 1.8
MOVE_OBJECT_NUM :: 1000
INFI :: 0xFFFFFFF
SPATIAL_CELL_SIZE :: 8.0
DEST_BASE_RADIUS :: 3.0
DEST_GROWTH_PER_UNIT :: 0.15
DEST_MAX_RADIUS :: 40.0
DEST_FLOW_DEADZONE :: 2
DEST_DAMPING_RADIUS :: 5.0 * GRID_SIZE
DEST_PACK_SPACING :: 2.0
DEST_CLUSTER_RANGE :: 4.0
DEST_MIN_OVERLAP_DIST :: 1.0

Direction :: enum i32 {
    Up = 3, Down = -3, Left = -30, Right = 30,
    UpLeft = -27, UpRight = 33, DownLeft = -33, DownRight = 27, Null = 10,
}

GridType :: enum { Normal, Open, Close, Obstacle, Destination }
GridInfo :: struct { cost: i32, path_length: i32, direction: i32, type: GridType, dirty: bool }
Point :: struct { x, y: f32 }
Coordinate :: struct { x, y: i32 }
MoveObject :: struct {
    pos: Point, velocity: Point, speed: f32, settled: bool, idle_timer: f32,
    target_pos: Point, has_target: bool, trail: [20]Point, trail_index: int,
}

g_map: []GridInfo
g_map_w, g_map_h: i32
g_cur_win_width: i32 = WINDOW_WIDTH
g_cur_win_height: i32 = WINDOW_HEIGHT
g_click_down_x: i32 = -1
g_click_down_y: i32 = -1
g_dest: Coordinate
g_object_positions: [MOVE_OBJECT_NUM]MoveObject
g_spatial_hash: kd.Tree
OverlayMode :: enum { None, Cost, FlowField, Trails }
g_overlay_mode: OverlayMode = .None
g_show_debug: bool = false
g_frame_count: int = 0

SEP_WEIGHT :: 2.0
COH_WEIGHT :: 0.8
ALI_WEIGHT :: 1.0
OBS_WEIGHT :: 2.0
MAX_ACC :: 25.0

UNIT_DIRS := [8]Point{
    {0.0, -1.0}, {0.0, 1.0}, {-1.0, 0.0}, {1.0, 0.0},
    {-0.7071, -0.7071}, {0.7071, -0.7071}, {-0.7071, 0.7071}, {0.7071, 0.7071},
}

valid :: proc(x, y: i32) -> bool { return x >= 0 && y >= 0 && x < g_map_w && y < g_map_h }
get_cell :: proc(x, y: i32) -> ^GridInfo { return &g_map[y * g_map_w + x] }

world_to_index :: proc(p: Point) -> Coordinate {
    x := math.clamp(i32(math.floor(p.x / GRID_SIZE)), 0, g_map_w - 1)
    y := math.clamp(i32(math.floor(p.y / GRID_SIZE)), 0, g_map_h - 1)
    return {x, y}
}

index_to_world :: proc(idx: Coordinate) -> Point {
    return {f32(idx.x) * GRID_SIZE + GRID_SIZE / 2, f32(idx.y) * GRID_SIZE + GRID_SIZE / 2}
}

pixel_to_world :: proc(pixel: Point) -> Point {
    return {pixel.x / f32(g_cur_win_width) * WORLD_WIDTH, pixel.y / f32(g_cur_win_height) * WORLD_HEIGHT}
}

get_dir_index :: proc(d: i32) -> int {
    switch d {
    case i32(Direction.Up): return 0
    case i32(Direction.Down): return 1
    case i32(Direction.Left): return 2
    case i32(Direction.Right): return 3
    case i32(Direction.UpLeft): return 4
    case i32(Direction.UpRight): return 5
    case i32(Direction.DownLeft): return 6
    case i32(Direction.DownRight): return 7
    case: return -1
    }
}

resolve_unit_obstacle :: proc(obj: ^MoveObject, old_pos: Point) {
    idx := world_to_index(obj.pos)
    if get_cell(idx.x, idx.y).type != .Obstacle { return }
    obj.pos = old_pos
    obj.velocity.x *= 0.6
    obj.velocity.y *= 0.6
}

main :: proc() {
    rl.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "Flow Field")
    defer rl.CloseWindow()
    defer delete(g_map)
    defer kd.destroy(&g_spatial_hash)
    rl.SetTargetFPS(60)
    initial()
    for !rl.WindowShouldClose() {
        update()
        rl.BeginDrawing()
        defer rl.EndDrawing()
        path_find_display()
        g_frame_count += 1
    }
}

initial :: proc() {
    g_dest = {0, 0}
    g_spatial_hash = kd.create(context.allocator)
    init_map()
    init_move_objects()
}

init_map :: proc() {
    w := i32(WORLD_WIDTH / GRID_SIZE)
    h := i32(WORLD_HEIGHT / GRID_SIZE)
    g_map_w, g_map_h = w, h
    g_map = make([]GridInfo, w * h)
    seed := time.time_to_unix_nano(time.now())
    rl.SetRandomSeed(u32(seed % (1 << 32)))
    for y in 0..<h {
        for x in 0..<w {
            cell := get_cell(x, y)
            cell.direction = i32(Direction.Down)
            cell.path_length = INFI
            cell.dirty = false
            cell.type = .Normal
            cell.cost = i32(rl.GetRandomValue(10, 50))
        }
    }
    for x := w/5; x <= 4*w/5; x += 1 { set_obstacle(x, h/2) }
    for y := h/4; y <= 3*h/4; y += 1 { set_obstacle(w/2, y) }
    set_destination({w/2, h/2})
    calc_flow_field(g_dest)
}

set_obstacle :: proc(x, y: i32) {
    if !valid(x, y) { return }
    cell := get_cell(x, y)
    cell.cost = INFI
    cell.type = .Obstacle
    cell.direction = i32(Direction.Null)
    cell.dirty = true
    for dy in -1..=1 {
        for dx in -1..=1 {
            nx, ny := x + i32(dx), y + i32(dy)
            if valid(nx, ny) { get_cell(nx, ny).dirty = true }
        }
    }
}

set_destination :: proc(d: Coordinate) {
    if !valid(d.x, d.y) { return }
    if g_dest.x >= 0 {
        old := get_cell(g_dest.x, g_dest.y)
        old.type = .Normal
        old.path_length = INFI
    }
    cell := get_cell(d.x, d.y)
    cell.type = .Destination
    cell.cost = 20
    cell.direction = i32(Direction.Null)
    g_dest = d
    for &obj in g_object_positions {
        obj.settled = false
        obj.idle_timer = 0
        obj.has_target = false
    }
}

recover_grid_type :: proc() {
    for i in 0..<g_map_w * g_map_h {
        cell := &g_map[i]
        #partial switch cell.type {
        case .Destination, .Obstacle:
        case: cell.type = .Normal; cell.path_length = INFI
        }
    }
    g_map[g_dest.y * g_map_w + g_dest.x].path_length = 0
}

calc_flow_field :: proc(dest: Coordinate) {
    recover_grid_type()
    pq: [dynamic]OpenGridInfo
    defer delete(pq)
    g_score := make([]i32, g_map_w * g_map_h)
    defer delete(g_score)
    for &v in g_score { v = INFI }
    idx := dest.y * g_map_w + dest.x
    append(&pq, OpenGridInfo{dest, 0})
    g_score[idx] = 0
    dirs := [8][2]i32{{0,-1}, {0,1}, {-1,0}, {1,0}, {-1,-1}, {1,-1}, {-1,1}, {1,1}}
    dir_enum := [8]Direction{.Up, .Down, .Left, .Right, .UpLeft, .UpRight, .DownLeft, .DownRight}
    for len(pq) > 0 {
        min_i := 0
        for i in 1..<len(pq) {
            if pq[i].path_length < pq[min_i].path_length { min_i = i }
        }
        cur := pq[min_i]
        ordered_remove(&pq, min_i)
        x, y := cur.coord.x, cur.coord.y
        cell := get_cell(x, y)
        if cell.type == .Close { continue }
        cell.type = .Close
        for i in 0..<8 {
            nx, ny := x + dirs[i][0], y + dirs[i][1]
            if !valid(nx, ny) { continue }
            ncell := get_cell(nx, ny)
            if ncell.type == .Obstacle { continue }
            if abs(dirs[i][0]) + abs(dirs[i][1]) == 2 {
                if get_cell(x + dirs[i][0], y).type == .Obstacle || get_cell(x, y + dirs[i][1]).type == .Obstacle { continue }
            }
            move_cost := i32(10)
            if abs(dirs[i][0]) + abs(dirs[i][1]) == 2 { move_cost = 14 }
            tent := g_score[y * g_map_w + x] + ncell.cost + move_cost
            nidx := ny * g_map_w + nx
            if tent < g_score[nidx] {
                g_score[nidx] = tent
                ncell.path_length = tent
                ncell.direction = i32(dir_enum[i])
                append(&pq, OpenGridInfo{{nx, ny}, tent})
            }
        }
    }
    for y in 0..<g_map_h {
        for x in 0..<g_map_w {
            cell := get_cell(x, y)
            if cell.path_length == INFI || cell.type == .Obstacle {
                cell.direction = i32(Direction.Null)
                continue
            }
            best_dir := i32(Direction.Null)
            best_cost := cell.path_length
            for i in 0..<8 {
                nx := x + dirs[i][0]
                ny := y + dirs[i][1]
                if !valid(nx, ny) { continue }
                ncell := get_cell(nx, ny)
                if ncell.type == .Obstacle { continue }
                if abs(dirs[i][0]) + abs(dirs[i][1]) == 2 {
                    if get_cell(x + dirs[i][0], y).type == .Obstacle || get_cell(x, y + dirs[i][1]).type == .Obstacle { continue }
                }
                if ncell.path_length < best_cost {
                    best_cost = ncell.path_length
                    best_dir = i32(dir_enum[i])
                }
            }
            cell.direction = best_dir
        }
    }
    for dy in -DEST_FLOW_DEADZONE..=DEST_FLOW_DEADZONE {
        for dx in -DEST_FLOW_DEADZONE..=DEST_FLOW_DEADZONE {
            nx := dest.x + i32(dx)
            ny := dest.y + i32(dy)
            if valid(nx, ny) {
                cell := get_cell(nx, ny)
                if cell.type != .Obstacle { cell.direction = i32(Direction.Null) }
            }
        }
    }
    g_map[g_dest.y * g_map_w + g_dest.x].type = .Destination

    // Reset closed cells to normal after pathfinding
    for i in 0..<g_map_w * g_map_h {
        if g_map[i].type == .Close {
            g_map[i].type = .Normal
        }
    }
}

OpenGridInfo :: struct { coord: Coordinate, path_length: i32 }

init_move_objects :: proc() {
    for i in 0..<MOVE_OBJECT_NUM {
        pos: Point
        for {
            pos.x = f32(rl.GetRandomValue(0, i32(WORLD_WIDTH)))
            pos.y = f32(rl.GetRandomValue(0, i32(WORLD_HEIGHT)))
            idx := world_to_index(pos)
            if get_cell(idx.x, idx.y).type != .Obstacle { break }
        }
        g_object_positions[i].pos = pos
        g_object_positions[i].velocity = {0, 0}
        g_object_positions[i].speed = f32(rl.GetRandomValue(5, 15)) * 0.1
        g_object_positions[i].settled = false
        g_object_positions[i].idle_timer = 0
        g_object_positions[i].has_target = false
        g_object_positions[i].target_pos = {0, 0}
        g_object_positions[i].trail_index = 0
        for j in 0..<20 { g_object_positions[i].trail[j] = pos }
    }
}

separation_force :: proc(i: int, sep_dist: f32 = 5.0, strength: f32 = 0.3) -> Point {
    sep: Point = {0, 0}
    count := 0
    d2 := sep_dist * sep_dist
    nearby: [dynamic]int
    defer delete(nearby)
    kd.in_range_query(&g_spatial_hash, g_object_positions[i].pos.x, g_object_positions[i].pos.y, sep_dist * 2, &nearby)
    for j in nearby {
        if i == j { continue }
        dx := g_object_positions[i].pos.x - g_object_positions[j].pos.x
        dy := g_object_positions[i].pos.y - g_object_positions[j].pos.y
        dist2 := dx*dx + dy*dy
        if dist2 > 0 && dist2 < d2 {
            dist := math.sqrt(dist2)
            sep.x += dx / dist
            sep.y += dy / dist
            count += 1
        }
    }
    if count == 0 { return {0, 0} }
    len := math.sqrt(sep.x*sep.x + sep.y*sep.y)
    if len > 0 { sep.x = sep.x / len * strength; sep.y = sep.y / len * strength }
    return sep
}

cohesion_force :: proc(i: int, coh_dist: f32 = 8.0, strength: f32 = 0.2) -> Point {
    coh: Point = {0, 0}
    count := 0
    d2 := coh_dist * coh_dist
    nearby: [dynamic]int
    defer delete(nearby)
    kd.in_range_query(&g_spatial_hash, g_object_positions[i].pos.x, g_object_positions[i].pos.y, coh_dist * 2, &nearby)
    for j in nearby {
        if i == j { continue }
        dx := g_object_positions[j].pos.x - g_object_positions[i].pos.x
        dy := g_object_positions[j].pos.y - g_object_positions[i].pos.y
        dist2 := dx*dx + dy*dy
        if dist2 > 0 && dist2 < d2 {
            coh.x += g_object_positions[j].pos.x
            coh.y += g_object_positions[j].pos.y
            count += 1
        }
    }
    if count == 0 { return {0, 0} }
    coh.x = coh.x / f32(count) - g_object_positions[i].pos.x
    coh.y = coh.y / f32(count) - g_object_positions[i].pos.y
    len := math.sqrt(coh.x*coh.x + coh.y*coh.y)
    if len > 0 { coh.x = coh.x / len * strength; coh.y = coh.y / len * strength }
    return coh
}

alignment_force :: proc(i: int, align_dist: f32 = 6.0, strength: f32 = 0.25) -> Point {
    align: Point = {0, 0}
    count := 0
    d2 := align_dist * align_dist
    nearby: [dynamic]int
    defer delete(nearby)
    kd.in_range_query(&g_spatial_hash, g_object_positions[i].pos.x, g_object_positions[i].pos.y, align_dist * 2, &nearby)
    for j in nearby {
        if i == j { continue }
        dx := g_object_positions[j].pos.x - g_object_positions[i].pos.x
        dy := g_object_positions[j].pos.y - g_object_positions[i].pos.y
        dist2 := dx*dx + dy*dy
        if dist2 > 0 && dist2 < d2 {
            align.x += g_object_positions[j].velocity.x
            align.y += g_object_positions[j].velocity.y
            count += 1
        }
    }
    if count == 0 { return {0, 0} }
    align.x /= f32(count)
    align.y /= f32(count)
    len := math.sqrt(align.x*align.x + align.y*align.y)
    if len > 0 { align.x = align.x / len * strength; align.y = align.y / len * strength }
    return align
}

obstacle_repulsion_force :: proc(i: int, rep_dist: f32 = 6.0, rep_strength: f32 = 1.5) -> Point {
    op := world_to_index(g_object_positions[i].pos)
    rep: Point = {0, 0}
    count := 0
    for dy in -3..=3 {
        for dx in -3..=3 {
            nx := op.x + i32(dx)
            ny := op.y + i32(dy)
            if !valid(nx, ny) { continue }
            cell := get_cell(nx, ny)
            if cell.type != .Obstacle { continue }
            dist2 := f32(dx*dx + dy*dy)
            if dist2 == 0 || dist2 > rep_dist*rep_dist { continue }
            dist := math.sqrt(dist2)
            rep.x -= f32(dx) / (dist + 0.1)
            rep.y -= f32(dy) / (dist + 0.1)
            count += 1
        }
    }
    if count == 0 { return {0, 0} }
    len := math.sqrt(rep.x*rep.x + rep.y*rep.y)
    if len > 0 { rep.x = rep.x / len * rep_strength; rep.y = rep.y / len * rep_strength }
    return rep
}

update :: proc() {
    if rl.IsKeyPressed(.O) { g_overlay_mode = cast(OverlayMode)((cast(int)g_overlay_mode + 1) % 4) }
    if rl.IsKeyPressed(.D) { g_show_debug = !g_show_debug }
    if rl.IsMouseButtonPressed(.LEFT) {
        mouse_pos := rl.GetMousePosition()
        g_click_down_x = i32(mouse_pos.x)
        g_click_down_y = i32(mouse_pos.y)
    } else if rl.IsMouseButtonReleased(.LEFT) {
        mouse_pos := rl.GetMousePosition()
        click_up_x := i32(mouse_pos.x)
        click_up_y := i32(mouse_pos.y)
        ci := world_to_index(pixel_to_world(Point{f32(click_up_x), f32(click_up_y)}))
        if abs(click_up_x - g_click_down_x) < 10 && abs(click_up_y - g_click_down_y) < 10 {
            if get_cell(ci.x, ci.y).cost != INFI {
                set_destination(ci)
                calc_flow_field(ci)
            }
        }
        g_click_down_x = -1
        g_click_down_y = -1
    } else if rl.IsMouseButtonDown(.LEFT) && g_click_down_x != -1 {
        mouse_move()
    }
    change_object_position()
}

mouse_move :: proc() {
    mouse_pos := rl.GetMousePosition()
    x := i32(mouse_pos.x)
    y := i32(mouse_pos.y)
    d_idx := world_to_index(pixel_to_world(Point{f32(x), f32(y)}))
    draw_obs := false
    if abs(x - g_click_down_x) >= 10 {
        direction := (x - g_click_down_x) / abs(x - g_click_down_x)
        g_click_down_x = math.clamp(x + direction * 10, 0, g_cur_win_width)
        draw_obs = true
    }
    if abs(y - g_click_down_y) >= 10 {
        direction := (y - g_click_down_y) / abs(y - g_click_down_y)
        g_click_down_y = math.clamp(y + direction * 10, 0, g_cur_win_height)
        draw_obs = true
    }
    if draw_obs && get_cell(d_idx.x, d_idx.y).type != .Destination {
        set_obstacle(d_idx.x, d_idx.y)
        calc_flow_field(g_dest)
    }
}

change_object_position :: proc() {
    dt := rl.GetFrameTime()
    kd.destroy(&g_spatial_hash)
    g_spatial_hash = kd.create(context.allocator)
    for i in 0..<MOVE_OBJECT_NUM {
        pos := g_object_positions[i].pos
        kd.insert(&g_spatial_hash, pos.x, pos.y, rawptr(uintptr(i)))
    }
    settled_count := 0
    for &obj in g_object_positions { if obj.settled { settled_count += 1 } }
    current_arrival_radius := min(DEST_BASE_RADIUS + f32(settled_count) * DEST_GROWTH_PER_UNIT, DEST_MAX_RADIUS)
    dest_world := index_to_world(g_dest)
    
    for i in 0..<MOVE_OBJECT_NUM {
        obj := &g_object_positions[i]
        old_pos := obj.pos
        idx := world_to_index(obj.pos)
        cell := get_cell(idx.x, idx.y)
        dist_to_dest := math.hypot(obj.pos.x - dest_world.x, obj.pos.y - dest_world.y)
        
        if dist_to_dest < current_arrival_radius {
            if !obj.has_target {
                best_pos := obj.pos
                best_score := f32(-1e9)
                has_valid_target := false
                // Increased samples for denser coverage
                for attempt in 0..<100 {
                    // Add more jitter based on unit ID for irregularity
                    angle_jitter := f32(i % 10) * 0.5  // Varies per unit
                    angle := f32(attempt) * (2 * math.TAU / 100) + f32(i) * 0.1 + angle_jitter
                    // Slight outward bias for outer units (encourages puddle spread)
                    base_radius := f32(rl.GetRandomValue(0, i32(current_arrival_radius * 0.9)))
                    radius_bias := f32(settled_count > 500 ? 1.2 : 1.0)  // Grow outer layer
                    test_radius := base_radius * radius_bias
                    test_x := math.clamp(dest_world.x + math.cos_f32(angle) * test_radius, 2.0, WORLD_WIDTH - 2.0)
                    test_y := math.clamp(dest_world.y + math.sin_f32(angle) * test_radius, 2.0, WORLD_HEIGHT - 2.0)
                    test_idx := world_to_index(Point{test_x, test_y})
                    test_cell := get_cell(test_idx.x, test_idx.y)
                    if test_cell.type == .Obstacle { continue }

                    // HARD CHECK: Reject if overlaps any settled unit
                    overlaps := false
                    nearby: [dynamic]int
                    defer delete(nearby)
                    kd.in_range_query(&g_spatial_hash, test_x, test_y, 2 * UNIT_RADIUS, &nearby)
                    for j in nearby {
                        if i == j { continue }
                        other := &g_object_positions[j]
                        if !other.settled { continue }
                        dx := test_x - other.pos.x
                        dy := test_y - other.pos.y
                        dist := math.hypot(dx, dy)
                        if dist < 2 * UNIT_RADIUS {
                            overlaps = true
                            break
                        }
                    }
                    if overlaps { continue }  // Skip this proposal

                    score := f32(0)
                    // Re-use nearby for scoring (now safe, no overlaps)
                    for j in nearby {
                        if i == j { continue }
                        other := &g_object_positions[j]
                        if !other.settled { continue }
                        dx := test_x - other.pos.x
                        dy := test_y - other.pos.y
                        dist := math.hypot(dx, dy)
                        if dist > 0 && dist < DEST_CLUSTER_RANGE {
                            // Soft linear attraction (fades with distance)
                            attract_amount := 1.0 - (dist / DEST_CLUSTER_RANGE)
                            score += 8.0 * attract_amount  // Tunable: higher = tighter cluster
                        }
                    }
                    center_dist := math.hypot(test_x - dest_world.x, test_y - dest_world.y)
                    score -= center_dist * 0.1  // Weakened for more organic spread
                    if score > best_score {
                        best_score = score
                        best_pos = Point{test_x, test_y}
                        has_valid_target = true
                    }
                }
                // Fallback: If no valid target found, pick a safe random spot around edge
                if !has_valid_target {
                    for fallback in 0..<20 {  // Try a few times
                        angle := f32(rl.GetRandomValue(0, 360)) * math.TAU / 360.0
                        test_radius := current_arrival_radius * 0.95  // Outer edge
                        test_x := dest_world.x + math.cos_f32(angle) * test_radius
                        test_y := dest_world.y + math.sin_f32(angle) * test_radius
                        test_x = math.clamp(test_x, 2.0, WORLD_WIDTH - 2.0)
                        test_y = math.clamp(test_y, 2.0, WORLD_HEIGHT - 2.0)
                        overlaps := false
                        nearby: [dynamic]int
                        defer delete(nearby)
                        kd.in_range_query(&g_spatial_hash, test_x, test_y, 2 * UNIT_RADIUS, &nearby)
                        for j in nearby {
                            other := &g_object_positions[j]
                            if !other.settled { continue }
                            dx := test_x - other.pos.x
                            dy := test_y - other.pos.y
                            dist := math.hypot(dx, dy)
                            if dist < 2 * UNIT_RADIUS {
                                overlaps = true
                                break
                            }
                        }
                        if !overlaps {
                            best_pos = Point{test_x, test_y}
                            has_valid_target = true
                            break
                        }
                    }
                    if !has_valid_target { best_pos = obj.pos }  // Last resort: stay put
                }
                obj.target_pos = best_pos
                obj.has_target = true
            }
            dx := obj.target_pos.x - obj.pos.x
            dy := obj.target_pos.y - obj.pos.y
            dist := math.hypot(dx, dy)
            if dist < 0.5 {
                // ENHANCED: For settled units, apply tuned boids for dynamic puddle reshaping
                if obj.settled {
                    // Compute local group center for cohesion (puddle integrity)
                    local_center: Point = dest_world  // Fallback to dest
                    coh_count := 0
                    nearby: [dynamic]int
                    defer delete(nearby)
                    kd.in_range_query(&g_spatial_hash, obj.pos.x, obj.pos.y, DEST_CLUSTER_RANGE * 2, &nearby)
                    for j in nearby {
                        if i == j { continue }
                        other := &g_object_positions[j]
                        if !other.settled { continue }
                        local_center.x += other.pos.x
                        local_center.y += other.pos.y
                        coh_count += 1
                    }
                    if coh_count > 0 {
                        local_center.x /= f32(coh_count + 1)  // +1 to include self
                        local_center.y /= f32(coh_count + 1)
                    }

                    // Tuned boid forces for settled blob (high sep, med coh to local center, low obs)
                    sep := separation_force(i, DEST_PACK_SPACING, 3.0)  // Higher weight for no-overlap
                    coh_dir := Point{local_center.x - obj.pos.x, local_center.y - obj.pos.y}
                    coh_len := math.hypot(coh_dir.x, coh_dir.y)
                    coh := Point{0, 0}
                    if coh_len > 0 {
                        coh = {coh_dir.x / coh_len * 1.5, coh_dir.y / coh_len * 1.5}  // Medium pull to blob center
                    }
                    obs := obstacle_repulsion_force(i, 4.0, 1.0)  // Low, since near dest
                    ali := Point{0, 0}  // No alignment in blob

                    // Weak pull to global dest to prevent drift
                    dest_pull := Point{dest_world.x - obj.pos.x, dest_world.y - obj.pos.y}
                    dest_len := math.hypot(dest_pull.x, dest_pull.y)
                    if dest_len > 0 {
                        dest_pull = {dest_pull.x / dest_len * 0.5, dest_pull.y / dest_len * 0.5}  // Very weak
                    }

                    // Combine and limit
                    total_force := Point{
                        sep.x + coh.x + obs.x + dest_pull.x,
                        sep.y + coh.y + obs.y + dest_pull.y,
                    }
                    force_len := math.hypot(total_force.x, total_force.y)
                    if force_len > 10.0 {  // Lower max for gentle movement
                        total_force.x = total_force.x / force_len * 10.0
                        total_force.y = total_force.y / force_len * 10.0
                    }

                    // Integrate slowly
                    obj.velocity.x += total_force.x * dt * 0.5  // Slower for settled
                    obj.velocity.y += total_force.y * dt * 0.5
                    speed := math.hypot(obj.velocity.x, obj.velocity.y)
                    if speed > obj.speed * 0.3 {  // Cap low speed
                        obj.velocity.x = obj.velocity.x / speed * (obj.speed * 0.3)
                        obj.velocity.y = obj.velocity.y / speed * (obj.speed * 0.3)
                    }

                    // Move and damp if too slow
                    obj.pos.x += obj.velocity.x * dt * MOVE_STEP * 0.8  // Slightly slower step
                    obj.pos.y += obj.velocity.y * dt * MOVE_STEP * 0.8
                    resolve_unit_obstacle(obj, old_pos)
                    if speed < 0.05 { obj.velocity = {0, 0} }

                    // Re-check settled (allow un-settle if pushed far)
                    obj.settled = (dist_to_dest < current_arrival_radius * 1.1)
                } else {
                    // Transition to settled
                    obj.settled = true
                    obj.idle_timer = 0
                }
            } else if dist > 0.1 {
                move_speed := obj.settled ? obj.speed * 0.4 : obj.speed * 0.7
                obj.velocity.x = (dx / dist) * move_speed
                obj.velocity.y = (dy / dist) * move_speed
                // FIXED: Add movement step for approaching target
                obj.pos.x += obj.velocity.x * dt * MOVE_STEP * 0.8
                obj.pos.y += obj.velocity.y * dt * MOVE_STEP * 0.8
                resolve_unit_obstacle(obj, old_pos)
            } else {
                obj.velocity.x *= 0.95
                obj.velocity.y *= 0.95
                obj.settled = true
            }
            if obj.settled && math.hypot(obj.velocity.x, obj.velocity.y) < 0.02 { obj.velocity = {0, 0} }
            obj.trail[obj.trail_index] = obj.pos
            obj.trail_index = (obj.trail_index + 1) % 20
            continue
        }

        //  B)  FLOW FIELD DIRECTION (unchanged from original)
        flow_dir := Point{0, 0}
        has_flow := false

        if cell.path_length != INFI && cell.direction != i32(Direction.Null) {
            dir_idx := get_dir_index(cell.direction)
            if dir_idx >= 0 && dir_idx < 8 {
                flow_dir = UNIT_DIRS[dir_idx]
                has_flow = true
            }
        }

        // fallback neighbour search
        if !has_flow || (flow_dir.x == 0 && flow_dir.y == 0) {
            best_length := cell.path_length
            best_dx := 0
            best_dy := 0

            for dy in -1..=1 {
                for dx in -1..=1 {
                    if dx == 0 && dy == 0 { continue }
                    nx := idx.x + i32(dx)
                    ny := idx.y + i32(dy)
                    if !valid(nx, ny) { continue }
                    ncell := get_cell(nx, ny)
                    if ncell.type == .Obstacle { continue }
                    if ncell.path_length < best_length {
                        best_length = ncell.path_length
                        best_dx = dx
                        best_dy = dy
                    }
                }
            }

            if best_dx != 0 || best_dy != 0 {
                len := math.sqrt(f32(best_dx*best_dx + best_dy*best_dy))
                flow_dir = {f32(best_dx)/len, f32(best_dy)/len}
                has_flow = true
            }
        }


        //  C)  BOID FORCES (unchanged)
        sep := Point{0, 0}
        coh := Point{0, 0}
        ali := Point{0, 0}
        obs := Point{0, 0}
        sep = separation_force(i, 5.0, SEP_WEIGHT)
        coh = cohesion_force(i, 8.0, COH_WEIGHT)
        ali = alignment_force(i, 6.0, ALI_WEIGHT)
        obs = obstacle_repulsion_force(i, 6.0, OBS_WEIGHT)


        //  D)  STEERING (unchanged)
        steering := Point{
            sep.x + coh.x + ali.x + obs.x,
            sep.y + coh.y + ali.y + obs.y,
        }

        // dampen steering when approaching destination
        if dist_to_dest < DEST_DAMPING_RADIUS {
            damp_factor := dist_to_dest / DEST_DAMPING_RADIUS
            damp_factor = 0.3 + 0.7 * damp_factor // 30 % to 100 %
            steering.x *= damp_factor
            steering.y *= damp_factor
        }

        steer_len := math.hypot(steering.x, steering.y)
        if steer_len > MAX_ACC {
            steering.x = steering.x / steer_len * MAX_ACC
            steering.y = steering.y / steer_len * MAX_ACC
        }


        //  E)  INTEGRATE (unchanged)
        obj.velocity.x += steering.x * dt
        obj.velocity.y += steering.y * dt

        // flow bias
        if has_flow {
            target := Point{flow_dir.x * obj.speed, flow_dir.y * obj.speed}
            blend :f32 = 0.5
            obj.velocity.x += (target.x - obj.velocity.x) * blend
            obj.velocity.y += (target.y - obj.velocity.y) * blend
        }

        // clamp speed
        speed := math.hypot(obj.velocity.x, obj.velocity.y)
        if speed > obj.speed {
            obj.velocity.x = obj.velocity.x / speed * obj.speed
            obj.velocity.y = obj.velocity.y / speed * obj.speed
        }

        // move----
        obj.pos.x += obj.velocity.x * dt * MOVE_STEP
        obj.pos.y += obj.velocity.y * dt * MOVE_STEP
        resolve_unit_obstacle(obj, old_pos)

        // world wrap-
        if obj.pos.x < 0          do obj.pos.x += WORLD_WIDTH
        if obj.pos.x > WORLD_WIDTH do obj.pos.x -= WORLD_WIDTH
        if obj.pos.y < 0          do obj.pos.y += WORLD_HEIGHT
        if obj.pos.y > WORLD_HEIGHT do obj.pos.y -= WORLD_HEIGHT

        // trail & idle timer
        obj.trail[obj.trail_index] = obj.pos
        obj.trail_index = (obj.trail_index + 1) % 20

        if speed < 0.08 {
            obj.idle_timer += dt
            if obj.idle_timer > 2.0 { obj.settled = true }
        } else {
            obj.idle_timer = 0
            obj.settled = false
        }
    }

    // NEW: HARD COLLISION RESOLUTION PASS (enforces no overlaps post-movement)
    resolve_collisions()
}

UNIT_RADIUS :: 0.5

// NEW PROC: Hard resolution - detects and fixes all overlaps
resolve_collisions :: proc() {
    // Rebuild kd-tree for post-move positions
    kd.destroy(&g_spatial_hash)
    g_spatial_hash = kd.create(context.allocator)
    for i in 0..<MOVE_OBJECT_NUM {
        pos := g_object_positions[i].pos
        kd.insert(&g_spatial_hash, pos.x, pos.y, rawptr(uintptr(i)))
    }

    // Simple iterative resolution: 3 passes to propagate fixes
    for pass in 0..<3 {
        for i in 0..<MOVE_OBJECT_NUM {
            pos_i := g_object_positions[i].pos
            nearby: [dynamic]int
            defer delete(nearby)
            kd.in_range_query(&g_spatial_hash, pos_i.x, pos_i.y, 2 * UNIT_RADIUS, &nearby)
            for j in nearby {
                if i >= j { continue }  // Avoid double-counting pairs
                pos_j := g_object_positions[j].pos
                dx := pos_i.x - pos_j.x
                dy := pos_i.y - pos_j.y
                dist := math.hypot(dx, dy)
                if dist < 2 * UNIT_RADIUS && dist > 0 {
                    // Overlap! Push apart along line, split overlap equally
                    overlap := 2 * UNIT_RADIUS - dist
                    push := overlap * 0.5  // Each moves half
                    dir_x := dx / dist
                    dir_y := dy / dist
                    // Displace i away from j
                    g_object_positions[i].pos.x += dir_x * push
                    g_object_positions[i].pos.y += dir_y * push
                    // Displace j away from i (opposite dir)
                    g_object_positions[j].pos.x -= dir_x * push
                    g_object_positions[j].pos.y -= dir_y * push
                }
            }
        }
        // Rebuild kd-tree after pass for next iteration
        kd.destroy(&g_spatial_hash)
        g_spatial_hash = kd.create(context.allocator)
        for k in 0..<MOVE_OBJECT_NUM {
            pos_k := g_object_positions[k].pos
            kd.insert(&g_spatial_hash, pos_k.x, pos_k.y, rawptr(uintptr(k)))
        }
    }

    // Optional: Damp velocities if big displacements happened (prevents jitter)
    for &obj in g_object_positions {
        obj.velocity.x *= 0.95
        obj.velocity.y *= 0.95
    }
}

/*
   The rest of the file (drawing, overlays, etc.) is unchanged.
   Only the functions below are kept exactly as you had them.
*/

path_find_display :: proc() {
    rl.ClearBackground(rl.BLACK)
    draw_map()
    draw_destination(index_to_world(g_dest))

    switch g_overlay_mode {
    case .Cost:      draw_cost_overlay()
    case .FlowField:
        if g_show_debug {
            draw_flow_field()
        }
    case .Trails:    draw_trails()
    case .None:
    }

    draw_move_object()

    if g_show_debug { draw_debug_info() }

    rl.DrawText("O: Overlay | D: Debug (flow + unit markers) | Click: Dest | Drag: Walls", 10, 10, 16, rl.RAYWHITE)
}

draw_map :: proc() {
    scale_x := f32(g_cur_win_width) / WORLD_WIDTH
    scale_y := f32(g_cur_win_height) / WORLD_HEIGHT

    for y in 0..<g_map_h {
        for x in 0..<g_map_w {
            cell := get_cell(x, y)
            p1 := index_to_world({x, y})

            color: rl.Color
            #partial switch cell.type {
            case .Normal:     color = rl.BLACK
            case .Obstacle:   color = {178, 34, 34, 255} // Firebrick
            case .Destination: color = rl.BLUE
            case .Open:       color = rl.GREEN
            case .Close:      color = rl.DARKGRAY
            case:             color = rl.LIGHTGRAY
            }

            rl.DrawRectangleRec(
                rl.Rectangle{p1.x * scale_x, p1.y * scale_y, GRID_SIZE * scale_x, GRID_SIZE * scale_y},
                color,
            )
            rl.DrawRectangleLines(
                i32(p1.x * scale_x),
                i32(p1.y * scale_y),
                i32(GRID_SIZE * scale_x),
                i32(GRID_SIZE * scale_y),
                rl.DARKGRAY,
            )
        }
    }
}

draw_destination :: proc(p: Point) {
    scale_x := f32(g_cur_win_width) / WORLD_WIDTH
    scale_y := f32(g_cur_win_height) / WORLD_HEIGHT
    rl.DrawCircle(i32(p.x * scale_x), i32(p.y * scale_y), 7, rl.BLUE)
    rl.DrawCircleLines(i32(p.x * scale_x), i32(p.y * scale_y), 10, rl.DARKBLUE)
}

draw_flow_field :: proc() {
    scale_x := f32(g_cur_win_width) / WORLD_WIDTH
    scale_y := f32(g_cur_win_height) / WORLD_HEIGHT
    for y in 0..<g_map_h {
        for x in 0..<g_map_w {
            cell := get_cell(x, y)
            if cell.direction == i32(Direction.Null) { continue }
            sp := index_to_world({x, y})
            dir_idx := get_dir_index(cell.direction)
            if dir_idx < 0 || dir_idx >= 8 { continue }
            dir := UNIT_DIRS[dir_idx]
            ep := Point{sp.x + dir.x * GRID_SIZE/2, sp.y + dir.y * GRID_SIZE/2}
            rl.DrawLine(i32(sp.x * scale_x), i32(sp.y * scale_y), i32(ep.x * scale_x), i32(ep.y * scale_y), rl.YELLOW)
            rl.DrawCircle(i32(sp.x * scale_x), i32(sp.y * scale_y), 2, {127, 26, 77, 255})
        }
    }
}

draw_cost_overlay :: proc() {
    max_cost := i32(1)
    for i in 0..<g_map_w * g_map_h {
        if g_map[i].path_length != INFI &&
           g_map[i].type != .Obstacle {
            max_cost = max(max_cost, g_map[i].path_length)
        }
    }

    scale_x := f32(g_cur_win_width) / WORLD_WIDTH
    scale_y := f32(g_cur_win_height) / WORLD_HEIGHT

    for y in 0..<g_map_h {
        for x in 0..<g_map_w {
            cell := get_cell(x, y)
            if cell.path_length == INFI { continue }
            if cell.type == .Destination { continue }

            p := index_to_world({x, y})
            ratio := f32(cell.path_length) / f32(max_cost)

            r := u8(255 * ratio)
            g := u8(30)
            b := u8(255 * (1 - ratio))
            col := rl.Color{r, g, b, 120}

            rl.DrawRectangleRec(
                rl.Rectangle{p.x * scale_x, p.y * scale_y,
                             GRID_SIZE * scale_x, GRID_SIZE * scale_y},
                col,
            )
        }
    }
}

draw_trails :: proc() {
    scale_x := f32(g_cur_win_width) / WORLD_WIDTH
    scale_y := f32(g_cur_win_height) / WORLD_HEIGHT
    for &obj in g_object_positions {
        for i in 0..<20 {
            idx := (obj.trail_index + i) % 20
            p := obj.trail[idx]
            alpha := u8(255 * (f32(i) / 20.0))
            col := rl.Color{0, 0, 255, alpha}
            rl.DrawCircle(i32(p.x * scale_x), i32(p.y * scale_y), 2, col)
        }
    }
}

draw_move_object :: proc() {
    scale_x := f32(g_cur_win_width) / WORLD_WIDTH
    scale_y := f32(g_cur_win_height) / WORLD_HEIGHT
    for &obj in g_object_positions {
        col := rl.SKYBLUE
        rl.DrawCircle(i32(obj.pos.x * scale_x), i32(obj.pos.y * scale_y), 4, col)
    }
}

draw_debug_info :: proc() {
    fps := rl.GetFPS()
    ms  := 1000.0 / f32(fps)
    text := fmt.tprintf("FPS:%d  ms:%.2f  Obj:%d  Frame:%d", fps, ms, MOVE_OBJECT_NUM, g_frame_count)
    cstr := strings.clone_to_cstring(text, context.temp_allocator)
    rl.DrawText(cstr, 10, 40, 16, rl.RAYWHITE)
}