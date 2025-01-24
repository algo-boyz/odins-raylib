package main

import rl "vendor:raylib"

AnimationType :: enum {
    Repeating = 1,
    OneShot = 2,
}

Direction :: enum {
    Left = -1,
    Right = 1,
}

Animation :: struct {
    first: int,           // Index of first frame
    last: int,            // Index of last frame
    cur: int,             // Current frame index
    step: int,            // Frame increment value
    speed: f32,           // Duration of each frame
    duration_left: f32,   // Time remaining on current frame
    type: AnimationType,  // Animation type (repeating or one-shot)
}

animation_update :: proc(self: ^Animation) {
    dt := rl.GetFrameTime()
    self.duration_left -= dt
    
    if self.duration_left <= 0.0 {
        // Reset frame duration and move to next frame
        self.duration_left = self.speed
        self.cur += self.step
        
        // Handle animation bounds based on direction and type
        if (self.step > 0 && self.cur > self.last) || 
           (self.step < 0 && self.cur < self.first) {
            switch self.type {
            case .Repeating:
                self.cur = self.step > 0 ? self.first : self.last
            case .OneShot:
                self.cur = self.step > 0 ? self.last : self.first
            }
        }
    }
}

animation_frame :: proc(self: ^Animation, num_frames_per_row: int) -> rl.Rectangle {
    // Convert 1D frame index to 2D coordinates
    x := (self.cur % num_frames_per_row) * 16
    y := (self.cur / num_frames_per_row) * 16
    
    return rl.Rectangle{
        x = f32(x),
        y = f32(y),
        width = 16,
        height = 16,
    }
}

main :: proc() {
    rl.InitWindow(600, 400, "𓂀aᛉlib animations 🔆")
    
    player_idle_texture := rl.LoadTexture("assets/hero.png")
    
    // Forward animation
    anim := Animation{
        first = 0,
        last = 3,
        cur = 0,
        step = 1,
        speed = 0.1,
        duration_left = 0.1,
        type = .Repeating,
    }
    
    player_direction := Direction.Left
    
    for !rl.WindowShouldClose() {
        // Input handling
        if rl.IsKeyPressed(.SPACE) {
            anim.cur = anim.first
        }
        if rl.IsKeyPressed(.A) {
            player_direction = .Left
        }
        if rl.IsKeyPressed(.D) {
            player_direction = .Right
        }
        
        // Update animations
        animation_update(&anim)
        
        // Drawing
        rl.BeginDrawing()
        rl.ClearBackground(rl.SKYBLUE)
        
        // Draw first sprite with direction
        player_frame := animation_frame(&anim, 4)
        player_frame.width *= f32(player_direction)
        
        dest_rect1 := rl.Rectangle{200, 150, 100, 100}
        origin := rl.Vector2{0, 0}
        
        rl.DrawTexturePro(
            player_idle_texture, 
            player_frame, 
            dest_rect1, 
            origin, 
            0.0, 
            rl.WHITE,
        )
        
        rl.EndDrawing()
    }
    
    rl.UnloadTexture(player_idle_texture)
    rl.CloseWindow()
}