package main

import rl "vendor:raylib"
import vr ".."
import "core:fmt"

V_WIDTH  :: 320
V_HEIGHT :: 180

main :: proc() {
    // Init virtual resolution
    vres: vr.VirtualRes
    vr.init(&vres, V_WIDTH, V_HEIGHT, "ALIENS")
    
    alien := rl.LoadTexture("alien.png")
    defer rl.UnloadTexture(alien)
    
    for !rl.WindowShouldClose() {
        vr.update(&vres)
        
        // Begin drawing to virtual canvas
        vr.begin_drawing(&vres)
        
        // Your game drawing code here (all in virtual resolution coordinates)
        rl.DrawTexture(alien, 10, 10, rl.WHITE)
        
        // Example: Use v_mouse coordinates
        if vr.get_mouse_button(.LEFT) {
            fmt.printf("v_mouse_pos: (%.0f, %.0f)\n", vr.VRES_MOUSE(&vres).x, vr.VRES_MOUSE(&vres).y)
        }
        // End virtual drawing, begin screen drawing
        vr.end_drawing(&vres)
        // Finish frame
        vr.finish_frame(&vres)
    }
    vr.destroy(&vres)
    rl.CloseWindow()
}