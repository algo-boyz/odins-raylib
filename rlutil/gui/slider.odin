package gui

import rl "vendor:raylib"

controlExclusiveMode := false
controlExclusiveRec := rl.Rectangle{ 0, 0, 0, 0 }

// Add a slider with controlExclusiveMode, 
// this allows to keep dragging a slider outside of it's bounds
GuiSlider_Custom :: proc(bounds: rl.Rectangle, textLeft: cstring, textRight: cstring, val: ^f32, minVal: f32, maxVal: f32) {
    rl.GuiSlider(bounds, textLeft, textRight, val, minVal, maxVal)

    if rl.GuiState(rl.GuiGetState()) != .STATE_DISABLED && !rl.GuiIsLocked() {
        mousePoint := rl.GetMousePosition();

        if controlExclusiveMode {
            if !rl.IsMouseButtonDown(.LEFT) {
                controlExclusiveMode = false;
                controlExclusiveRec = rl.Rectangle{ 0, 0, 0, 0 }
            }
        }
        else if rl.CheckCollisionPointRec(mousePoint, bounds) {
            if rl.IsMouseButtonDown(.LEFT) {
                controlExclusiveMode = true;
                controlExclusiveRec = bounds; // Store bounds as an identifier when dragging starts
            }
        }
    }
}

// poor man's healthbar
healthbar :: proc (health: ^f32, bounds: rl.Rectangle) {
    rl.GuiProgressBar(bounds, "Health", "", health, 0, 100)
}
