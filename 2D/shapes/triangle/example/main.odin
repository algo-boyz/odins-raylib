package main

import "core:fmt"
import "core:strings"
import "core:math"

import "../"

import rl "vendor:raylib"

main :: proc() {
    rl.InitWindow(800, 800, "Triangles")
    rl.SetConfigFlags({.VSYNC_HINT})
    defer rl.CloseWindow()
    
    net := triangle.make_triangle_net()
    net.position = rl.Vector2{400, 400}
    
    verts := []rl.Vector2{
        {0, 0},
        {1, 0},
        {1, 1},
        {0, 0},
        {0, 1},
        {1, 1},
    }
    triangle.add_triangles(net, verts)
    
    selected_verts := make([dynamic]rl.Vector2)
    polygon := triangle.get_polygon(net)
    mouse_inv: rl.Vector2
    nearest_vertex: rl.Vector2
    snap_distance: f32 = 0.3
    
    timer: f32 = 0
    until_counter: int = 0
    
    for !rl.WindowShouldClose() {
        mouse_inv = triangle.inv_transform(net, rl.GetMousePosition())
        nearest_vertex = triangle.get_nearest_vertex(net, mouse_inv, snap_distance)
        
        if timer > 0.3 {
            until_counter = (until_counter + 1) % (len(polygon) + 1)
            timer = 0
        }
        timer += rl.GetFrameTime()
        
        rl.BeginDrawing()        
        rl.ClearBackground(rl.BLACK)
        
        triangle.draw(net, rl.BLUE, rl.RED)
        rl.DrawCircleLinesV(triangle.transform(net, nearest_vertex), 5, rl.GREEN)
        rl.DrawCircleLinesV(rl.GetMousePosition(), net.scale * snap_distance, rl.DARKGREEN)
        triangle.draw_labels(net, 20, rl.DARKGRAY)
        triangle.draw_polygon(net, selected_verts[:], rl.GREEN)
        triangle.draw_polygon(net, polygon, rl.MAGENTA, until_counter)
        
        if rl.IsMouseButtonPressed(.LEFT) {
            append(&selected_verts, nearest_vertex)
            if len(selected_verts) == 3 {
                triangle.add_triangles(net, selected_verts[:])
                polygon = triangle.get_polygon(net)
                free(&selected_verts)
            }
        }
        
        if rl.IsMouseButtonPressed(.RIGHT) {
            min_dist := f32(9999)
            nearest := 0
            for vert, i in selected_verts {
                dist := rl.Vector2Distance(mouse_inv, vert)
                if dist < min_dist {
                    nearest = i
                    min_dist = dist
                }
            }
            ordered_remove(&selected_verts, nearest)
        }
        
        text := fmt.tprintf("%3.2f %3.2f %d", nearest_vertex.x, nearest_vertex.y, until_counter)
        rl.DrawText(strings.clone_to_cstring(text), 10, 10, 20, rl.DARKGRAY)
        
        for vert, i in polygon {
            text := fmt.tprintf("%3.2f, %3.2f", vert.x, vert.y)
            rl.DrawText(strings.clone_to_cstring(text), 600, 10 + 20 * i32(i), 20, rl.WHITE)
        }
        rl.EndDrawing()
    }
}