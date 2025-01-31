package rlutil

import rl "vendor:raylib"

guiControlExclusiveMode := false
guiControlExclusiveRec := rl.Rectangle{ 0, 0, 0, 0 }


// Add a slider with guiControlExclusiveMode, 
// this allows to keep dragging a slider outside of it's bounds
GuiSlider_Custom :: proc(bounds: rl.Rectangle, textLeft: cstring, textRight: cstring, val: ^f32, minVal: f32, maxVal: f32) {
    rl.GuiSlider(bounds, textLeft, textRight, val, minVal, maxVal)

    if rl.GuiState(rl.GuiGetState()) != .STATE_DISABLED && !rl.GuiIsLocked() {
        mousePoint := rl.GetMousePosition();

        if guiControlExclusiveMode {
            if !rl.IsMouseButtonDown(.LEFT) {
                guiControlExclusiveMode = false;
                guiControlExclusiveRec = rl.Rectangle{ 0, 0, 0, 0 }
            }
        }
        else if rl.CheckCollisionPointRec(mousePoint, bounds) {
            if rl.IsMouseButtonDown(.LEFT) {
                guiControlExclusiveMode = true;
                guiControlExclusiveRec = bounds; // Store bounds as an identifier when dragging starts
            }
        }
    }
}
