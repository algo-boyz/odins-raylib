package main

import "core:c"
import "core:fmt"
import gif "../"

main :: proc() {
    err: c.int
    file := gif.DGifOpenFileName("../../assets/nexus.gif", &err)
    if gif.is_err(err) {
        fmt.printf("Error opening GIF: %s\n", gif.err_msg(err))
        return
    }
    defer gif.DGifCloseFile(file, &err)
    if gif.is_err(err) {
        fmt.printf("Error closing GIF: %s\n", gif.err_msg(err))
        return
    }
    // Read images
    if gif.DGifSlurp(file) != gif.OK {
        fmt.printf("Error reading GIF\n")
        return
    }
    fmt.println("GIF loaded:", file.image_count)
    // Access data
    if file.saved_images != nil && file.image_count > 0 {
        image := file.saved_images[0]
        fmt.printf("Image 0: %dx%d\n", image.image_desc.width, image.image_desc.height)
    }
}