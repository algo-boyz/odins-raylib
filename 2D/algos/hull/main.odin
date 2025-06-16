package main

import "core:fmt"
import "core:math"
import "core:mem"
import "core:sort"
import rl "vendor:raylib"

// todo: https://github.com/jdeokkim/algoitni/blob/main/algorithms/convex-hull/graham-scan.c

DEBUG :: false

SCREEN_WIDTH :: 800
SCREEN_HEIGHT :: 600
RADIUS :: 3
FPS :: 30
N :: 1000

x, y: [N]f64
pt, in_hull, hull: [N]int
hull_size: int = 0
hull_midpoint: rl.Vector2

cross :: proc(c, a, b: int) -> f64 {
    return (x[a] - x[c]) * (y[b] - y[c]) - (y[a] - y[c]) * (x[b] - x[c])
}

is_left :: proc(a, b, c: int) -> bool {
    return cross(c, a, b) > 0.0
}

// Get all points left of vector ab
get_left :: proc(sz: ^int, points: []int, a, b: int) -> []int {
    // Allocate initial array with capacity of points.len
    left := make([]int, len(points))
    left[0] = a
    left[1] = b
    new_sz := 2
    
    for i := 0; i < sz^; i += 1 {
        if points[i] != a && points[i] != b && is_left(a, b, points[i]) {
            new_sz += 1
            left[i] = points[i]
        }
    }
    
    sz^ = new_sz
    return left
}

// Init the first line for quickhull
init_hull :: proc(points: []int, sz: int, minx, maxx: ^int) {
    minx^ = points[0]
    maxx^ = points[0]
    
    for i := 1; i < sz; i += 1 {
        if x[points[i]] < x[minx^] do minx^ = points[i]
        if x[points[i]] > x[maxx^] do maxx^ = points[i]
    }
    
    in_hull[minx^] = 1
    in_hull[maxx^] = 1
}

// Find the point farthest from line ab
find_farthest :: proc(points: []int, sz: int, a, b: int) -> int {
    farthest := points[0]
    max_distance := 0.0
    
    for i := 0; i < sz; i += 1 {
        if points[i] != a && points[i] != b {
            distance := math.abs(cross(points[i], a, b))
            if distance > max_distance {
                max_distance = distance
                farthest = points[i]
            }
        }
    }
    
    return farthest
}

// quickhull algorithm, divide and conquer
qhull :: proc(points: []int, sz: int, a, b: int) {
    if sz == 2 {
        in_hull[points[0]] = 1
        in_hull[points[1]] = 1
        return
    }
    
    farthest := find_farthest(points, sz, a, b)
    in_hull[farthest] = 1
    
    leftsz := sz
    half := get_left(&leftsz, points, a, farthest)
    qhull(half, leftsz, a, farthest)
    delete(half)
    
    leftsz = sz
    half = get_left(&leftsz, points, farthest, b)
    qhull(half, leftsz, farthest, b)
    delete(half)
}

// Calculate the convex hull
calc_hull :: proc(points: []int, sz: int) {
    hull_size = 0
    
    for i := 0; i < sz; i += 1 do in_hull[i] = 0
    
    minpt, maxpt: int
    init_hull(points, sz, &minpt, &maxpt)
    
    uppercnt, lowercnt := sz, sz
    upper := get_left(&uppercnt, points[:sz], minpt, maxpt)
    lower := get_left(&lowercnt, points[:sz], maxpt, minpt)
    
    qhull(upper, uppercnt, minpt, maxpt)
    qhull(lower, lowercnt, maxpt, minpt)
    
    delete(upper)
    delete(lower)
    
    // Collect hull points
    for i := 0; i < sz; i += 1 {
        if in_hull[i] == 1 {
            hull[hull_size] = i
            hull_size += 1
        }
    }
}

// Compare sorting hull points by polar angle
hull_cmp :: proc(a, b: int) -> int {
    vec1 := rl.Vector2{
        f32(x[a] - f64(hull_midpoint.x)),
        f32(y[a] - f64(hull_midpoint.y)),
    }
    
    vec2 := rl.Vector2{
        f32(x[b] - f64(hull_midpoint.x)),
        f32(y[b] - f64(hull_midpoint.y)),
    }
    
    th1 := math.atan2(f64(vec1.y), f64(vec1.x))
    th2 := math.atan2(f64(vec2.y), f64(vec2.x))
    
    if th1 < th2 do return -1
    if th1 > th2 do return 1
    return 0
}

calc_midpoint :: proc() {
    xsum, ysum := 0.0, 0.0
    
    for i := 0; i < hull_size; i += 1 {
        xsum += x[hull[i]]
        ysum += y[hull[i]]
    }
    
    xsum /= f64(hull_size)
    ysum /= f64(hull_size)
    
    hull_midpoint = rl.Vector2{f32(xsum), f32(ysum)}
}

// Draw convex hull
draw_hull :: proc() {
    calc_midpoint()
    
    when DEBUG {
        fmt.printf("Midpoint: %.3f %.3f\n", hull_midpoint.x, hull_midpoint.y)
        
        fmt.print("Hull before sort: ")
        for i := 0; i < hull_size; i += 1 {
            fmt.printf("%d ", hull[i])
        }
        fmt.println()
    }
    
    // Sort hull points by polar angle around midpoint
    hull_slice := hull[:hull_size]
    sort.quick_sort_proc(hull_slice, hull_cmp)
    
    when DEBUG {
        fmt.print("Hull after sort: ")
        for i := 0; i < hull_size; i += 1 {
            fmt.printf("%d ", hull[i])
        }
        fmt.println()
    }
    
    for i := 0; i < hull_size - 1; i += 1 {
        rl.DrawLine(
            i32(x[hull[i]]), 
            i32(y[hull[i]]), 
            i32(x[hull[i+1]]), 
            i32(y[hull[i+1]]), 
            rl.BLACK
        )
    }
    // Connect the last point to the first
    rl.DrawLine(
        i32(x[hull[hull_size-1]]), 
        i32(y[hull[hull_size-1]]), 
        i32(x[hull[0]]), 
        i32(y[hull[0]]), 
        rl.BLACK
    )
}

main :: proc() {
    rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "QuickHull")
    defer rl.CloseWindow()
    rl.SetTargetFPS(FPS)
    
    sz := 0
    for !rl.WindowShouldClose() {
        if rl.IsMouseButtonPressed(.LEFT) {
            point := rl.GetMousePosition()
            if sz < N {
                pt[sz] = sz
                x[sz] = f64(point.x)
                y[sz] = f64(point.y)
                sz += 1
            }
        }
        if rl.IsMouseButtonPressed(.RIGHT) && sz > 2 {
            calc_hull(pt[:sz], sz)
        }
        if rl.IsMouseButtonPressed(.MIDDLE) {
            sz = 0
            hull_size = 0
        }
        rl.BeginDrawing()
        rl.ClearBackground(rl.RAYWHITE)
        
        for i := 0; i < sz; i += 1 {
            rl.DrawCircle(i32(x[i]), i32(y[i]), RADIUS, rl.RED)
        }
        if hull_size > 0 {
            draw_hull()
        }
        rl.EndDrawing()
    }
}