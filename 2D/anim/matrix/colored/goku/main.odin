package main

import "core:fmt"
import "core:math"
import "core:mem"
import "core:time"
import rl "vendor:raylib"

Point :: struct {
    x: i32,
    y: i32,
}

RPixel :: struct {
    pos_x: i32,
    pos_y: i32,
    width: i32,
    height: i32,
    color: rl.Color,
}

WIDTH :: 800
HEIGHT :: 800

main :: proc() {
    rl.InitWindow(WIDTH, HEIGHT, "Window")
    defer rl.CloseWindow()

    // Load and check if image loaded successfully
    image := rl.LoadImage("../../assets/bg/alley.png")
    if image.data == nil {
        fmt.println("Failed to load image!")
        return
    }
    defer rl.UnloadImage(image)
    
    // Convert to RGBA format first to ensure compatibility
    rl.ImageFormat(&image, rl.PixelFormat.UNCOMPRESSED_R8G8B8A8)
    
    rl.ImageResize(&image, 400, 600)

    image_quantize_manhattan(&image)
    image_pixelate(&image, 16)

    rl.SetTargetFPS(60)
    offset :i32 = 100

    // render_booting(&image, offset, 1)
    // render_standard(&image, offset)
    // render_blocks(&image, offset, 16, 5)
    render_old_tv(&image, offset)

}

render_standard :: proc(image: ^rl.Image, offset: i32) {
    texture := rl.LoadTextureFromImage(image^)
    defer rl.UnloadTexture(texture)

    for !rl.WindowShouldClose() {
        rl.BeginDrawing()
        rl.ClearBackground(rl.BLACK)
        rl.DrawTexture(texture, offset, offset, rl.WHITE)
        rl.EndDrawing()
    }
}

render_blocks :: proc(image: ^rl.Image, offset: i32, pixel_size: i32, scale_factor: i32) {
    pixels := rl.LoadImageColors(image^)
    defer rl.UnloadImageColors(pixels)
    
    block_side_len := i32(math.sqrt(f32(pixel_size)))
    height := image.height / block_side_len
    width := image.width / block_side_len
    
    rpixels := make([]RPixel, height * width)
    defer delete(rpixels)
    
    rpix_size := 0

    for pi in 0..<(height * width) {
        block_point := get_point_from_index(pi, width)

        og_x := block_point.x * block_side_len
        og_y := block_point.y * block_side_len
        og_point := Point{og_x, og_y}
        og_index := get_index_from_point(og_point, width * block_side_len)
        
        // Bounds check
        if og_index >= 0 && og_index < (image.width * image.height) {
            og_pixel := pixels[og_index]

            if og_pixel.a != 0 {
                rpixels[rpix_size].pos_x = block_point.x * scale_factor + offset
                rpixels[rpix_size].pos_y = block_point.y * scale_factor + offset
                rpixels[rpix_size].width = block_side_len * scale_factor
                rpixels[rpix_size].height = block_side_len * scale_factor
                rpixels[rpix_size].color = og_pixel

                rpix_size += 1
            }
        }
    }

    for !rl.WindowShouldClose() {
        rl.BeginDrawing()
        rl.ClearBackground(rl.BLACK)
        
        for i in 0..<rpix_size {
            rl.DrawRectangle(rpixels[i].pos_x, rpixels[i].pos_y, 
                           rpixels[i].width, rpixels[i].height, 
                           rpixels[i].color)
        }

        rl.EndDrawing()
    }
}

render_old_tv :: proc(image: ^rl.Image, offset: i32) {
    pixels := rl.LoadImageColors(image^)
    defer rl.UnloadImageColors(pixels)

    for !rl.WindowShouldClose() {
        rl.BeginDrawing()
        rl.ClearBackground(rl.BLACK)

        for i in 0..<9000000 {
            p := rand_int() % (image.width * image.height)
            xy := get_point_from_index(p, image.width)
            color := rl.Color{pixels[p].r, pixels[p].g, pixels[p].b, pixels[p].a}
            rl.DrawPixel(xy.x + offset, xy.y + offset, color)
        }
        rl.EndDrawing()
    }
}

render_booting :: proc(image: ^rl.Image, offset: i32, render_rate: i32) {
    pixels := rl.LoadImageColors(image^)
    defer rl.UnloadImageColors(pixels)
    
    rendered:i32 = 1
    for !rl.WindowShouldClose() {
        rl.BeginDrawing()
        rl.ClearBackground(rl.BLACK)
        
        for i in 0..<rendered {
            p := rand_int() % (image.width * image.height)
            xy := get_point_from_index(p, image.width)
            color := rl.Color{pixels[p].r, pixels[p].g, pixels[p].b, pixels[p].a}
            rl.DrawPixel(xy.x + offset, xy.y + offset, color)
        }

        rendered += render_rate
        rl.EndDrawing()
    }
}

// Improved quantization function - works directly with image data
image_quantize_manhattan :: proc(image: ^rl.Image) {
    if image.data == nil || image.width == 0 || image.height == 0 do return

    pixels := rl.LoadImageColors(image^)
    defer rl.UnloadImageColors(pixels)
    
    colors := [5]rl.Color{
        {121, 235, 0, 255},
        {70, 180, 33, 255},
        {30, 127, 35, 255},
        {4, 76, 26, 255},
        {0, 31, 8, 255},
    }

    pixel_count := image.width * image.height
    for p in 0..<pixel_count {
        r := pixels[p].r
        g := pixels[p].g
        b := pixels[p].b
        a := pixels[p].a

        if a != 0 {
            min_distance: i32 = max(i32)
            closest_index: i32 = 0

            for c in 0..<5 {
                r_diff := abs(i32(colors[c].r) - i32(r))
                g_diff := abs(i32(colors[c].g) - i32(g))
                b_diff := abs(i32(colors[c].b) - i32(b))
                distance := r_diff + g_diff + b_diff

                if distance < min_distance {
                    closest_index = i32(c)
                    min_distance = distance
                }
            }

            pixels[p] = colors[closest_index]
        }
    }

    // Update image data directly
    update_image_from_pixels(image, pixels)
}

// Improved pixelate function
image_pixelate :: proc(image: ^rl.Image, pixel_size: i32) {
    if image.data == nil || image.width == 0 || image.height == 0 do return

    pixels := rl.LoadImageColors(image^)
    defer rl.UnloadImageColors(pixels)
    
    block_side_len := i32(math.sqrt(f32(pixel_size)))
    height := image.height / block_side_len
    width := image.width / block_side_len

    for b in 0..<(width * height) {
        point := get_point_from_index(b, width)
        
        og_x := point.x * block_side_len
        og_y := point.y * block_side_len
        
        // Calculate average color for this block
        r, g, b_sum, a := i32(0), i32(0), i32(0), i32(0)
        valid_pixels := i32(0)

        for x in 0..<block_side_len {
            for y in 0..<block_side_len {
                px := x + og_x
                py := y + og_y
                
                if px < image.width && py < image.height {
                    pixel_idx := py * image.width + px
                    if pixel_idx < (image.width * image.height) {
                        r += i32(pixels[pixel_idx].r)
                        g += i32(pixels[pixel_idx].g)
                        b_sum += i32(pixels[pixel_idx].b)
                        a += i32(pixels[pixel_idx].a)
                        valid_pixels += 1
                    }
                }
            }
        }

        if valid_pixels > 0 {
            block_rgba := rl.Color{
                u8(r / valid_pixels), 
                u8(g / valid_pixels), 
                u8(b_sum / valid_pixels), 
                u8(a / valid_pixels),
            }

            // Apply average color to all pixels in this block
            for x in 0..<block_side_len {
                for y in 0..<block_side_len {
                    px := x + og_x
                    py := y + og_y
                    
                    if px < image.width && py < image.height {
                        pixel_idx := py * image.width + px
                        if pixel_idx < (image.width * image.height) {
                            pixels[pixel_idx] = block_rgba
                        }
                    }
                }
            }
        }
    }

    // Update image data
    update_image_from_pixels(image, pixels)
}

// Helper function to update image from pixel array
update_image_from_pixels :: proc(image: ^rl.Image, pixels: [^]rl.Color) {
    pixel_count := image.width * image.height
    if pixel_count == 0 do return
    
    // Get the raw data pointer and update it
    // pixel_data := cast(^rl.Color)image.data
    // for i in 0..<pixel_count {
    //     pixel_data[i] = pixels[i].g
    // }
}

// Quantization performed using euclidean distance
image_quantize_euclidean :: proc(image: ^rl.Image) {
    if image.data == nil || image.width == 0 || image.height == 0 do return
    
    pixels := rl.LoadImageColors(image^)
    defer rl.UnloadImageColors(pixels)
    
    colors := [5]rl.Color{
        {121, 235, 0, 255},
        {70, 180, 33, 255},
        {30, 127, 35, 255},
        {4, 76, 26, 255},
        {0, 31, 8, 255},
    }

    pixel_count := image.width * image.height
    for p in 0..<pixel_count {
        r := pixels[p].r
        g := pixels[p].g
        b := pixels[p].b
        a := pixels[p].a

        if a != 0 {
            min_distance := f32(max(f32))
            closest_index := 0

            for c in 0..<5 {
                r_diff := f32(colors[c].r) - f32(r)
                g_diff := f32(colors[c].g) - f32(g)
                b_diff := f32(colors[c].b) - f32(b)
                distance := math.sqrt((r_diff * r_diff) + (g_diff * g_diff) + (b_diff * b_diff))

                if distance < min_distance {
                    closest_index = c
                    min_distance = distance
                }
            }

            pixels[p] = colors[closest_index]
        }
    }

    // Update image data
    update_image_from_pixels(image, pixels)
}

// Pixel Size must be square rootable with no remainder
image_pixelate_degrade :: proc(image: ^rl.Image, pixel_size: i32) {
    pixels := rl.LoadImageColors(image^)
    defer rl.UnloadImageColors(pixels)

    pixel_lh := i32(math.sqrt(f32(pixel_size)))
    height := image.height / pixel_lh
    width := image.width / pixel_lh

    new_pixels := make([]rl.Color, width * height)
    defer delete(new_pixels)

    for p in 0..<(width * height) {
        point := get_point_from_index(p, width)
        
        og_x := point.x * pixel_lh
        og_y := point.y * pixel_lh
        
        r, g, b, a := i32(0), i32(0), i32(0), i32(0)
        
        for x in 0..<pixel_lh {
            for y in 0..<pixel_lh {
                px := x + og_x
                py := y + og_y
                
                if px < image.width && py < image.height {
                    pixel_idx := py * image.width + px
                    if pixel_idx < (image.width * image.height) {
                        r += i32(pixels[pixel_idx].r)
                        g += i32(pixels[pixel_idx].g)
                        b += i32(pixels[pixel_idx].b)
                        a += i32(pixels[pixel_idx].a)
                    }
                }
            }
        }

        new_pixels[p] = rl.Color{
            u8(r / pixel_size), 
            u8(g / pixel_size), 
            u8(b / pixel_size), 
            u8(a / pixel_size),
        }
    }

    // Recreate image with new dimensions
    rl.UnloadImage(image^)
    image^ = rl.LoadImageFromMemory(".raw", raw_data(new_pixels), i32(width * height * size_of(rl.Color)))
    image.height = height
    image.width = width
    image.format = rl.PixelFormat.UNCOMPRESSED_R8G8B8A8
}

get_point_from_index :: proc(pixel: i32, width: i32) -> Point {
    point := Point{}
    point.x = pixel % width
    point.y = pixel / width
    return point
}

get_index_from_point :: proc(point: Point, width: i32) -> i32 {
    return point.y * width + point.x
}

image_resize_nearest_neighbor :: proc(image: rl.Image, new_width: i32, new_height: i32) -> rl.Image {
    pixels := rl.LoadImageColors(image)
    defer rl.UnloadImageColors(pixels)
    
    new_pixels := make([]rl.Color, new_width * new_height)
    defer delete(new_pixels)

    x_ratio := (image.width << 16) / new_width + 1
    y_ratio := (image.height << 16) / new_height + 1

    for i in 0..<new_height {
        for j in 0..<new_width {
            x := ((j * x_ratio) >> 16)
            y := ((i * y_ratio) >> 16)
            new_pixels[i * new_width + j] = pixels[y * image.width + x]
        }
    }

    new_image := rl.LoadImageFromMemory(".raw", raw_data(new_pixels), i32(new_width * new_height * size_of(rl.Color)))
    return new_image
}

// Simple random number generator
rand_state: u64

rand_int :: proc() -> i32 {
    if rand_state == 0 {
        rand_state = u64(time.now()._nsec)
    }
    rand_state = rand_state * 1103515245 + 12345
    return i32((rand_state >> 16) & 0x7fff)
}