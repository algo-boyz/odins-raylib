package rlutil

import "core:fmt"
import "core:time"
import "core:strings"
import rl "vendor:raylib"

take_screenshot :: proc() {
    rl.TakeScreenshot(fmt.ctprint(concat("screenshot_", time_print(time.now()), ".png")))
}