package rectangle

import rl "vendor:raylib"

Panel :: struct {
    rect: rl.Rectangle,
    minimized: bool,
}

@(deferred_none=end_panel)
begin_panel :: proc(title: cstring, rect: rl.Rectangle) -> bool {
    fmt.assertf(state.panel == nil || state.panel == title, "already building panel %q; did you forget an end()?", title)
    if title not_in state.panels {
        state.panels[title] = { rect = rect }
    }
    state.panel = title
    state.panel_row = 0

    panel := &state.panels[title]
    rect := state.panels[title].rect

    if rl.CheckCollisionPointRec(state.mouse, rect) {
        state.hovered_panel = title // Storing this for reporting to rest of application in want_mouse().
    }

    // Title bar.
    title_rect := rect
    title_rect.height = TITLE_HEIGHT

    // Minimize button.
    minimize_button_rect := rl.Rectangle{
        title_rect.x + title_rect.width - TITLE_HEIGHT, title_rect.y,
        TITLE_HEIGHT, TITLE_HEIGHT,
    }
    hover_minimize := rl.CheckCollisionPointRec(state.mouse, minimize_button_rect)
    hover_title := !hover_minimize && rl.CheckCollisionPointRec(state.mouse, title_rect)
    if rl.IsMouseButtonPressed(.LEFT) && hover_title {
        state.dragging = title
        state.drag_offset = rl.Vector2{title_rect.x, title_rect.y} - state.mouse
    }

    // Right click title bar to print panel rectangle to console.
    if rl.IsMouseButtonPressed(.RIGHT) && hover_title {
        fmt.println(int(rect.x), int(rect.y), int(rect.width), int(rect.height), sep = ", ")
    }

    rl.DrawRectangleRec(title_rect, title_color(state.dragging == title))
    rl.DrawText(title, i32(title_rect.x + 5), i32(title_rect.y + 5), TITLE_FONT, rl.WHITE)
    if button_rect(minimize_button_rect, "+" if panel.minimized else "-") {
        panel.minimized = !panel.minimized
    }
    if panel.minimized {
        return false
    }
    // Panel Body. Note: height is resized to fit contents every frame.
    body_rect := rect
    body_rect.height = rect.height - TITLE_HEIGHT
    body_rect.y = rect.y + TITLE_HEIGHT
    rl.DrawRectangleRec(body_rect, PANEL_COLOR)
    rl.DrawRectangleLinesEx(body_rect, 1, title_color(state.dragging == title)) // Border around body.
    {
        // Resize window.
        using body_rect
        SIZE :: 10
        // Resize triangle drawn in bottom right corner.
        a, b, c: rl.Vector2
        a = {x + width, y + height}
        b = a - {0, SIZE}
        c = a - {SIZE, 0}

        // Circle around the bottom-right corner for mouse collision. The actual resize
        // triangle is way too small to click.
        hovered := rl.CheckCollisionPointCircle(state.mouse, a, SIZE * 1.5)

        resize_key := fmt.ctprintf("%s#resize", title)
        if hovered && rl.IsMouseButtonPressed(.LEFT) {
            state.dragging = resize_key
            state.drag_offset = a - state.mouse
        }
        if state.dragging == resize_key {
            mouse := state.mouse + state.drag_offset
            panel.rect.width  = mouse.x - panel.rect.x
            panel.rect.height = mouse.y - panel.rect.y
            panel.rect.width  = clamp(panel.rect.width,  150, f32(rl.GetScreenWidth()))
            panel.rect.height = clamp(panel.rect.height,  50, f32(rl.GetScreenHeight()))
        }
        rl.DrawTriangle(a, b, c, title_color(hovered))
    }
    return true
}

end_panel :: proc() {
    body_height := f32(state.panel_row) * PANEL_HEIGHT
    p := &state.panels[state.panel] or_else panic("end_panel() called on a missing panel")
    if body_height > p.rect.height - TITLE_HEIGHT {
        p.rect.height = body_height + 2 * TITLE_HEIGHT
    }
    state.panel = nil
    state.panel_row = 0
}

@(deferred_none=end_row)
flex_row :: proc(column_widths: []f32) -> bool {
    state.column_widths = column_widths
    state.panel_column = 0
    return true
}

end_row :: proc() {
    state.panel_row += 1
}

PANEL_HEIGHT  :: TITLE_HEIGHT * 1.5
PADDING :: rl.Vector2{5, 2}

flex_rect :: proc(loc := #caller_location) -> rl.Rectangle {
    p := state.panels[state.panel] or_else panic("Must be called between begin_panel() and end_panel()", loc = loc)
    defer state.panel_column += 1

    row_rect := rl.Rectangle{
        p.rect.x,
        p.rect.y + TITLE_HEIGHT + f32(state.panel_row) * PANEL_HEIGHT,
        p.rect.width,
        PANEL_HEIGHT,
    }
    row_rect = padding(row_rect, PADDING)

    fmt.assertf(state.panel_column < len(state.column_widths),
                "Too many components in row. Must be 1:1 with row's column widths: Panel = %s, row = %v", state.panel, state.panel_row)

    rect := row_rect
    rect.width = row_rect.width * state.column_widths[state.panel_column] - PADDING.x
    for pct in state.column_widths[:state.panel_column] {
        rect.x += pct * row_rect.width // - PADDING.x
    }

    return rect
}