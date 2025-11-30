package texture

import rl "vendor:raylib"
import "core:strings"
import "core:fmt"

Background :: struct {
    texture: rl.Texture2D,
    color:   rl.Color,
    loaded:  bool,
}

// Try to load texture by filename
load :: proc(filename: string) -> Background {
    filename_cstring := strings.clone_to_cstring(filename)
    defer delete(filename_cstring)
    
    if rl.FileExists(filename_cstring) {
        fmt.printf("Trying to load: %s\n", filename)
        
        img := rl.LoadImage(filename_cstring)
        
        if img.data != nil && img.width > 0 && img.height > 0 {
            fmt.printf("Successfully loaded image: %s (%dx%d)\n", filename, img.width, img.height)
            
            texture := rl.LoadTextureFromImage(img)
            rl.UnloadImage(img)
            
            if texture.id != 0 {
                fmt.println("Texture created successfully")
                return {texture = texture, loaded = true}
            }
        } else if img.data != nil {
            rl.UnloadImage(img)
        }
    }
    fmt.println("No valid image texture found, using fallback background")
    return {loaded = false}
}

// Cleanup parchment resources
unload :: proc(parchment: ^Background) {
    if parchment.loaded {
        rl.UnloadTexture(parchment.texture)
        parchment.loaded = false
    }
}