package raydial

import "core:c"
import "core:fmt"
import "core:math"
import "core:strings"

import rl "vendor:raylib"

// Enums
Component_Type :: enum {
    Button,
    Label,
    Panel,
    Portrait_Dialogue,
    // TODO Textbox...
}

Text_Style_Type :: enum {
    Regular,
    Colored,
    Sized,
    Bold,
    Italic,
}

Callback :: proc "c" (user_data: rawptr)

Text_Style_Value :: struct {
    color: rl.Color,
    font_size: f32,
}

Text_Style :: struct {
    type: Text_Style_Type,
    value: Text_Style_Value,
    next: ^Text_Style,
}

Text_Segment :: struct {
    text: string,
    styles: ^Text_Style,
    next: ^Text_Segment,
}

Button_Data :: struct {
    text: string,
    text_color: rl.Color,
    background_color: rl.Color,
    hover_color: rl.Color,
    font_size: i32,
}

Label_Data :: struct {
    text: string,
    text_color: rl.Color,
    font_size: i32,
    wrap_text: bool,
    // Scrolling properties
    scroll_position: f32,
    content_height: f32,
    scrollable: bool,
    scrollbar_color: rl.Color,
    scrollbar_width: i32,
}

Panel_Data :: struct {
    background_color: rl.Color,
    border_color: rl.Color,
    border_width: f32,
    padding: f32,
}

Portrait_Dialogue_Data :: struct {
    speaker_name: string,
    dialogue_text: string, // Now used as a plain-text fallback
    portrait_color: rl.Color,
    portrait_texture: rl.Texture2D,
    use_texture: bool,
    name_tag_color: rl.Color,
    dialogue_box_color: rl.Color,
    text_color: rl.Color,
    name_color: rl.Color,
    font_size: i32,
    name_font_size: i32,
    wrap_text: bool,
    portrait_size: i32,
    show_on_right: bool,
    styled_text: ^Text_Segment,
    use_styled_text: bool,
}

Component :: struct {
    type: Component_Type,
    bounds: rl.Rectangle,
    visible: bool,
    enabled: bool,
    data: rawptr,
    on_click: Callback,
    user_data: rawptr,
    next: ^Component,
}

Node :: struct {
    id: string,
    text: string,
    components: ^Component,
    choices: [dynamic]^Node,
    on_enter: Callback,
    on_exit: Callback,
    user_data: rawptr,
}

Manager :: struct {
    root_node: ^Node,
    current_node: ^Node,
    active: bool,
    user_data: rawptr,
}

last_clicked_component: rawptr
last_click_time: i32 = -1

create_button :: proc(bounds: rl.Rectangle, text: string, on_click: Callback, user_data: rawptr, allocator := context.allocator) -> ^Component {
    component := new(Component, allocator)
    data := new(Button_Data, allocator)
    
    component^ = {
        type = .Button,
        bounds = bounds,
        visible = true,
        enabled = true,
        data = data,
        on_click = on_click,
        user_data = user_data,
        next = nil,
    }
    
    data^ = {
        text = text,
        text_color = rl.BLACK,
        background_color = rl.LIGHTGRAY,
        hover_color = rl.GRAY,
        font_size = 20,
    }
    
    return component
}

create_label :: proc(bounds: rl.Rectangle, text: string, wrap_text: bool, allocator := context.allocator) -> ^Component {
    component := new(Component, allocator)
    data := new(Label_Data, allocator)
    
    component^ = {
        type = .Label,
        bounds = bounds,
        visible = true,
        enabled = true,
        data = data,
        on_click = nil,
        user_data = nil,
        next = nil,
    }
    
    data^ = {
        text = text,
        text_color = rl.BLACK,
        font_size = 20,
        wrap_text = wrap_text,
        scroll_position = 0,
        content_height = 0,
        scrollable = true,
        scrollbar_color = rl.GRAY,
        scrollbar_width = 8,
    }
    
    return component
}

create_panel :: proc(bounds: rl.Rectangle, background_color: rl.Color, allocator := context.allocator) -> ^Component {
    component := new(Component, allocator)
    data := new(Panel_Data, allocator)
    
    component^ = {
        type = .Panel,
        bounds = bounds,
        visible = true,
        enabled = true,
        data = data,
        on_click = nil,
        user_data = nil,
        next = nil,
    }
    
    data^ = {
        background_color = background_color,
        border_color = rl.DARKGRAY,
        border_width = 2,
        padding = 10,
    }
    
    return component
}

// Get color from name
get_color_from_name :: proc(color_name: string) -> rl.Color {
    if color_name == "" { return rl.BLACK }
    
    name := color_name
    // Convert to lowercase for comparison
    // name_lower := strings.to_lower(name, context.temp_allocator) 
    // Note: Odin strings are not guaranteed to be null-terminated for C-style to_lower
    // Simple switch is fine if we enforce lowercase in tags or data
    
    switch name {
    case "red": return rl.RED
    case "green": return rl.GREEN
    case "blue": return rl.BLUE
    case "yellow": return rl.YELLOW
    case "purple": return rl.PURPLE
    case "orange": return rl.ORANGE
    case "white": return rl.WHITE
    case "black": return rl.BLACK
    case "gray", "grey": return rl.GRAY
    case "darkgray": return rl.DARKGRAY
    case "lightgray": return rl.LIGHTGRAY
    }
    
    // TODO: Parse hex code #RRGGBB
    
    return rl.BLACK
}

// Starts with
starts_with :: proc(str, prefix: string) -> bool {
    if str == "" || prefix == "" { return false }
    return strings.starts_with(str, prefix)
}

// Free styled text segments
free_styled_text :: proc(styled_text: ^Text_Segment, allocator := context.allocator) {
    for current := styled_text; current != nil; {
        next := current.next
        
        delete(current.text, allocator) // Use allocator
        // Free styles
        for style := current.styles; style != nil; {
            next_style := style.next
            free(style, allocator)
            style = next_style
        }
        
        free(current, allocator)
        current = next
    }
}

// Parse formatted text with styling tags (Robust stack-based parser)
parse_styled_text :: proc(formatted_text: string, default_color: rl.Color, default_font_size: f32, allocator := context.allocator) -> ^Text_Segment {
    if formatted_text == "" { return nil }

    head: ^Text_Segment = nil
    current: ^Text_Segment = nil
    
    // Stack to keep track of active styles
    style_stack: [dynamic]^Text_Style
    defer {
        // Free any remaining styles on the stack (e.g., unclosed tags)
        for style in style_stack {
            free(style, allocator)
        }
        delete(style_stack)
    }

    i := 0
    segment_start := 0

    for i < len(formatted_text) {
        if formatted_text[i] == '[' {
            // --- 1. Found a tag, process text *before* it ---
            if i > segment_start {
                segment_text := formatted_text[segment_start:i]
                
                segment := new(Text_Segment, allocator)
                segment.text = strings.clone(segment_text, allocator)
                segment.next = nil
                
                // Apply styles from stack
                style_head: ^Text_Style = nil
                for style in style_stack {
                    // Clone style
                    cloned_style := new(Text_Style, allocator)
                    cloned_style^ = style^ // Copy value
                    cloned_style.next = style_head
                    style_head = cloned_style
                }
                segment.styles = style_head
                
                // Append segment to list
                if head == nil {
                    head = segment
                } else {
                    current.next = segment
                }
                current = segment
            }

            // --- 2. Process the tag itself ---
            j := strings.index_byte(formatted_text[i+1:], ']')
            if j == -1 { 
                // Malformed tag, treat rest of string as text
                break 
            }
            j += i + 1 // j is now the index of ']'
            
            tag_text := strings.trim_space(formatted_text[i+1:j])

            if starts_with(tag_text, "/") {
                // --- Closing Tag ---
                closing_tag_name := strings.trim_space(tag_text[1:])
                
                // Find and remove the most recent matching style from the stack
                for k := len(style_stack) - 1; k >= 0; k -= 1 {
                    style := style_stack[k]
                    tag_name: string
                    switch style.type {
                    case .Colored: tag_name = "color"
                    case .Sized:   tag_name = "size"
                    case .Bold:    tag_name = "b"
                    case .Italic:  tag_name = "i"
                    case .Regular: tag_name = ""
                    }
                    
                    if tag_name == closing_tag_name {
                        free(style, allocator) // Free the style we're popping
                        ordered_remove(&style_stack, k)
                        break // Only remove one
                    }
                }
            } else {
                // --- Opening Tag ---
                tag_parts := strings.split(tag_text, "=")
                tag_name := strings.trim_space(tag_parts[0])
                tag_value := len(tag_parts) > 1 ? strings.trim_space(tag_parts[1]) : ""

                style := new(Text_Style, allocator)
                style.next = nil
                style.type = .Regular // Default
                
                is_valid_style := true
                switch tag_name {
                case "color":
                    style.type = .Colored
                    style.value.color = get_color_from_name(tag_value)
                case "size":
                    style.type = .Sized
                    if tag_value == "large" {
                        style.value.font_size = default_font_size * 1.25
                    } else if tag_value == "small" {
                        style.value.font_size = default_font_size * 0.8
                    } else {
                        // TODO: Parse numeric value
                        style.value.font_size = default_font_size
                    }
                case "b":
                    style.type = .Bold
                case "i":
                    style.type = .Italic
                case:
                    is_valid_style = false
                    free(style, allocator) // Not a valid style, free it
                }
                
                if is_valid_style {
                    append(&style_stack, style)
                }
            }
            
            // Move index past the tag
            i = j + 1
            segment_start = i

        } else {
            // Not a tag, just advance
            i += 1
        }
    }

    // --- 3. Process any remaining text after the last tag ---
    if segment_start < len(formatted_text) {
        segment_text := formatted_text[segment_start:]
        
        segment := new(Text_Segment, allocator)
        segment.text = strings.clone(segment_text, allocator)
        segment.next = nil
        
        // Apply styles from stack
        style_head: ^Text_Style = nil
        for style in style_stack {
            cloned_style := new(Text_Style, allocator)
            cloned_style^ = style^
            cloned_style.next = style_head
            style_head = cloned_style
        }
        segment.styles = style_head
        
        if head == nil {
            head = segment
        } else {
            current.next = segment
        }
        current = segment
    }

    return head
}


// Create portrait dialogue
create_portrait_dialogue :: proc(bounds: rl.Rectangle, speaker_name, dialogue_text: string, portrait_color: rl.Color, allocator := context.allocator) -> ^Component {
    component := new(Component, allocator)
    data := new(Portrait_Dialogue_Data, allocator)
    
    component^ = {
        type = .Portrait_Dialogue,
        bounds = bounds,
        visible = true,
        enabled = true,
        data = data,
        on_click = nil,
        user_data = nil,
        next = nil,
    }
    
    // Use clone for strings
    data.speaker_name = strings.clone(speaker_name, allocator)
    data.dialogue_text = strings.clone(dialogue_text, allocator)
    data.styled_text = nil
    data.use_styled_text = false
    
    // Set remaining fields
    data.portrait_color = portrait_color
    data.use_texture = false
    data.name_tag_color = rl.DARKGRAY
    data.dialogue_box_color = rl.LIGHTGRAY
    data.text_color = rl.BLACK
    data.name_color = rl.WHITE
    data.font_size = 20
    data.name_font_size = 20
    data.wrap_text = true
    data.portrait_size = 100
    data.show_on_right = false
    
    return component
}

create_portrait_dialogue_with_texture :: proc(bounds: rl.Rectangle, speaker_name, dialogue_text: string, portrait_texture: rl.Texture2D, allocator := context.allocator) -> ^Component {
    component := create_portrait_dialogue(bounds, speaker_name, dialogue_text, rl.WHITE, allocator)
    data := cast(^Portrait_Dialogue_Data)component.data
    
    data.portrait_texture = portrait_texture
    data.use_texture = true
    
    return component
}

// Component management
add_component :: proc(parent, child: ^Component) {
    if parent == nil || child == nil { return }
    curr := parent
    for ; curr.next != nil; curr = curr.next {}
    curr.next = child
}

remove_component :: proc(parent, child: ^Component) {
    if parent == nil || child == nil { return }
    
    curr := parent
    for ; curr.next != nil && curr.next != child; curr = curr.next {}
    
    if curr.next == child {
        curr.next = child.next
        child.next = nil
    }
}

update_component :: proc(component: ^Component) {
    if component == nil || !component.visible || !component.enabled { return }
    
    #partial switch component.type {
    case .Button:
        if is_component_clicked(component) && component.on_click != nil {
            component.on_click(component.user_data)
        }
    case .Label:
        data := cast(^Label_Data)component.data
        
        if data.scrollable && data.content_height > 0 && is_component_hovered(component) {
            scroll_speed: f32 = 10
            
            // Use mouse wheel for scrolling
            wheel := rl.GetMouseWheelMove()
            if wheel != 0 {
                data.scroll_position -= wheel * 20
            }
            
            if rl.IsKeyDown(.UP) { data.scroll_position -= scroll_speed }
            else if rl.IsKeyDown(.DOWN) { data.scroll_position += scroll_speed }
            else if rl.IsKeyDown(.PAGE_UP) { data.scroll_position -= component.bounds.height / 2 }
            else if rl.IsKeyDown(.PAGE_DOWN) { data.scroll_position += component.bounds.height / 2 }
            
            data.scroll_position = math.clamp(data.scroll_position, 0, math.max(0, data.content_height - component.bounds.height))
        }
    case .Portrait_Dialogue:
        // No update logic
    }
    
    // Update children
    for child := component.next; child != nil; child = child.next {
        update_component(child)
    }
}

draw_component :: proc(component: ^Component) {
    if component == nil || !component.visible { return }
    
    switch component.type {
    case .Button:
        data := cast(^Button_Data)component.data
        hovered := is_component_hovered(component)
        
        rl.DrawRectangleRec(component.bounds, hovered ? data.hover_color : data.background_color)
        text := fmt.ctprint(data.text)
        text_width := rl.MeasureText(text, data.font_size)
        text_x := i32(component.bounds.x + (component.bounds.width - f32(text_width)) / 2)
        text_y := i32(component.bounds.y + (component.bounds.height - f32(data.font_size)) / 2)
        rl.DrawText(text, text_x, text_y, data.font_size, data.text_color)
        
    case .Label:
        data := cast(^Label_Data)component.data
        scissor_rect := component.bounds
        rl.BeginScissorMode(i32(scissor_rect.x), i32(scissor_rect.y), i32(scissor_rect.width), i32(scissor_rect.height))
        defer rl.EndScissorMode()
        
        line_height := f32(data.font_size) * 1.5
        
        if data.wrap_text {
            words := strings.split_multi(data.text, []string{" ", "\n"})
            defer delete(words)
            
            x: f32 = component.bounds.x
            y: f32 = component.bounds.y - data.scroll_position
            max_width := component.bounds.width - f32(data.scrollable ? data.scrollbar_width + 5 : 0)
            
            data.content_height = line_height
            
            line := strings.builder_make(context.temp_allocator)
            defer strings.builder_destroy(&line)
            
            for word in words {
                if word == "" { continue }
                
                test_line := strings.to_string(line)
                if test_line != "" { test_line = strings.concatenate({test_line, " "}, context.temp_allocator) }
                test_line = strings.concatenate({test_line, word}, context.temp_allocator)
                
                test_width := rl.MeasureTextEx(rl.GetFontDefault(), fmt.ctprint(test_line), f32(data.font_size), 1).x
                
                if test_width > max_width && strings.to_string(line) != "" {
                    // Draw line
                    if y + line_height > component.bounds.y && y < component.bounds.y + component.bounds.height {
                        rl.DrawTextEx(rl.GetFontDefault(), strings.to_cstring(&line), {x, y}, f32(data.font_size), 1, data.text_color)
                    }
                    
                    y += line_height
                    data.content_height += line_height
                    strings.builder_reset(&line)
                    // Add the word that didn't fit to the new line
                    strings.write_string(&line, word)
                } else {
                    // Add word to current line
                    if strings.to_string(line) != "" {
                        strings.write_rune(&line, ' ')
                    }
                    strings.write_string(&line, word)
                }
            }
            
            // Final line
            if strings.to_string(line) != "" && y + line_height > component.bounds.y && y < component.bounds.y + component.bounds.height {
                rl.DrawTextEx(rl.GetFontDefault(), strings.to_cstring(&line), {x, y}, f32(data.font_size), 1, data.text_color)
            }
            if data.content_height == line_height { data.content_height = y + line_height - (component.bounds.y - data.scroll_position) }
            else { data.content_height = y + line_height - (component.bounds.y - data.scroll_position) }


            
            // Scrollbar
            if data.scrollable && data.content_height > component.bounds.height {
                sb_bg := rl.Rectangle{
                    component.bounds.x + component.bounds.width - f32(data.scrollbar_width),
                    component.bounds.y,
                    f32(data.scrollbar_width),
                    component.bounds.height,
                }
                rl.DrawRectangleRec(sb_bg, rl.Fade(data.scrollbar_color, 0.2))
                
                scroll_ratio := component.bounds.height / data.content_height
                sb_height := math.max(component.bounds.height * scroll_ratio, 20) // Min handle height
                sb_y := component.bounds.y + (data.scroll_position / data.content_height) * component.bounds.height
                sb_y = math.clamp(sb_y, component.bounds.y, component.bounds.y + component.bounds.height - sb_height)
                
                sb := rl.Rectangle{
                    sb_bg.x, sb_y, sb_bg.width, sb_height,
                }
                rl.DrawRectangleRec(sb, data.scrollbar_color)
            }
        } else {
            rl.DrawTextEx(rl.GetFontDefault(), fmt.ctprint(data.text), {component.bounds.x, component.bounds.y - data.scroll_position}, f32(data.font_size), 1, data.text_color)
            data.content_height = line_height
        }
        
    case .Panel:
        data := cast(^Panel_Data)component.data
        
        rl.DrawRectangleRec(component.bounds, data.background_color)
        rl.DrawRectangleLinesEx(component.bounds, data.border_width, data.border_color)
        
    case .Portrait_Dialogue:
        data := cast(^Portrait_Dialogue_Data)component.data
        
        portrait_size := data.portrait_size
        padding: i32 = 10
        name_height := data.speaker_name != "" ? 40 : 0
        
        portrait_x := f32(data.show_on_right ? (component.bounds.x + component.bounds.width - f32(portrait_size) - f32(padding)) : (component.bounds.x + f32(padding)))
        portrait_y := component.bounds.y + f32(padding)
        
        // Dialogue box
        rl.DrawRectangleRec(component.bounds, data.dialogue_box_color)
        rl.DrawRectangleLinesEx(component.bounds, 2, rl.DARKGRAY)
        
        // Portrait
        portrait_rect := rl.Rectangle{portrait_x, portrait_y, f32(portrait_size), f32(portrait_size)}
        if data.use_texture {
            rl.DrawTexturePro(data.portrait_texture, {0, 0, f32(data.portrait_texture.width), f32(data.portrait_texture.height)}, portrait_rect, {}, 0, rl.WHITE)
        } else {
            rl.DrawRectangleRec(portrait_rect, data.portrait_color)
            rl.DrawRectangleLinesEx(portrait_rect, 2, rl.DARKGRAY)
        }
        
        // Name tag
        if data.speaker_name != "" {
            name_tag_rect: rl.Rectangle
            name_tag_width: f32 = 120 // Default width
            
            // Measure name text
            name_c := fmt.ctprint(data.speaker_name)
            name_width := rl.MeasureText(name_c, data.name_font_size)
            name_tag_width = max(f32(name_width) + 20, name_tag_width) // Add padding
            
            if data.show_on_right {
                name_tag_rect = {portrait_x - name_tag_width, portrait_y, name_tag_width, f32(name_height)}
            } else {
                name_tag_rect = {portrait_x + f32(portrait_size), portrait_y, name_tag_width, f32(name_height)}
            }
            
            rl.DrawRectangleRec(name_tag_rect, data.name_tag_color)
            rl.DrawRectangleLinesEx(name_tag_rect, 2, rl.DARKGRAY)
            
            name_x := name_tag_rect.x + (name_tag_rect.width - f32(name_width)) / 2
            name_y := name_tag_rect.y + (name_tag_rect.height - f32(data.name_font_size)) / 2
            rl.DrawText(name_c, i32(name_x), i32(name_y), data.name_font_size, data.name_color)
        }
        
        // Text
        if data.dialogue_text != "" || data.styled_text != nil {
            text_area_x: f32
            text_area_width: f32
            
            if data.show_on_right {
                text_area_x = component.bounds.x + f32(padding)
                text_area_width = portrait_x - component.bounds.x - f32(padding * 2)
            } else {
                text_area_x = portrait_x + f32(portrait_size) + f32(padding)
                text_area_width = component.bounds.x + component.bounds.width - text_area_x - f32(padding)
            }
            
            text_area_y := portrait_y + f32(name_height) + f32(padding)
            if name_height == 0 { // No name, start text lower
                text_area_y = portrait_y + f32(padding)
            }
            text_area_height := component.bounds.y + component.bounds.height - text_area_y - f32(padding)
            
            text_area := rl.Rectangle{text_area_x, text_area_y, text_area_width, text_area_height}
            
            rl.BeginScissorMode(i32(text_area.x), i32(text_area.y), i32(text_area.width), i32(text_area.height))
            defer rl.EndScissorMode()
            
if data.use_styled_text && data.styled_text != nil {
                // --- Draw Styled Text ---
                curr_x: f32 = text_area.x
                curr_y: f32 = text_area.y
                base_fs := f32(data.font_size)
                line_h := base_fs * 1.5 // Constant line height for simplicity
                space_w := rl.MeasureTextEx(rl.GetFontDefault(), " ", base_fs, 1).x
                max_w := text_area.width
                
                for segment := data.styled_text; segment != nil; segment = segment.next {
                    if segment.text == "" { continue }
                    
                    // Determine styles for this segment
                    seg_color := data.text_color
                    seg_fs := base_fs
                    is_bold := false
                    
                    for style := segment.styles; style != nil; style = style.next {
                        switch style.type {
                        case .Colored: seg_color = style.value.color
                        case .Sized:   seg_fs = style.value.font_size
                        case .Bold:    is_bold = true
                        case .Italic:  // Not implemented
                        case .Regular: // Do nothing
                        }
                    }
                    
                    // Word wrap this segment (FIXED: Handle \n properly)
                    i := 0
                    for i < len(segment.text) {
                        if segment.text[i] == '\n' {
                            // Force newline
                            curr_x = text_area.x
                            curr_y += line_h
                            if curr_y + line_h > text_area.y + text_area.height { break }
                            i += 1
                            continue
                        }
                        
                        start := i
                        for i < len(segment.text) && segment.text[i] != ' ' && segment.text[i] != '\n' {
                            i += 1
                        }
                        word := segment.text[start:i]
                        if word == "" { continue }  // Skip empties
                        
                        include_space := i < len(segment.text) && segment.text[i] == ' '
                        full_word : string = word
                        if include_space {
                            strings.concatenate({full_word, " "})
                            i += 1  // Advance past space
                        }
                        
                        w_str := strings.clone_to_cstring(full_word, context.temp_allocator)
                        w_size := rl.MeasureTextEx(rl.GetFontDefault(), w_str, seg_fs, 1)
                        
                        // Check for new line (add space width if not first on line)
                        if curr_x > text_area.x && curr_x + w_size.x > text_area.x + max_w {
                            curr_x = text_area.x
                            curr_y += line_h
                            if curr_y + line_h > text_area.y + text_area.height { break } // Stop if next line is out of bounds
                        }
                        
                        // Add space if not first word on line (but since full_word includes it, adjust)
                        // Note: Logic assumes full_word includes trailing space; no extra add here
                        
                        // Check if current word is visible
                        if curr_y + line_h > text_area.y && curr_y < text_area.y + text_area.height {
                            if is_bold {
                                // Faux-bold: draw offset
                                rl.DrawTextEx(rl.GetFontDefault(), w_str, {curr_x + 1, curr_y}, seg_fs, 1, seg_color)
                            }
                            rl.DrawTextEx(rl.GetFontDefault(), w_str, {curr_x, curr_y}, seg_fs, 1, seg_color)
                        }
                        
                        curr_x += w_size.x
                    }
                    
                    if curr_y + line_h > text_area.y + text_area.height { break } // Stop processing segments
                }
            } else if data.wrap_text && data.dialogue_text != "" {
                // --- Draw Plain Text (Fallback) ---
                // This logic can be simpler now, using the label's logic as a base
                text_y: f32 = text_area.y
                fs_f := f32(data.font_size)
                spacing: f32 = 1 // Default spacing
                line_h := fs_f * 1.5
                
                words := strings.split_multi(data.dialogue_text, []string{" ", "\n"})
                defer delete(words)
            
                line := strings.builder_make(context.temp_allocator)
                defer strings.builder_destroy(&line)

                for word in words {
                    if word == "" { continue }

                    test_line := strings.to_string(line)
                    if test_line != "" { test_line = strings.concatenate({test_line, " "}, context.temp_allocator) }
                    test_line = strings.concatenate({test_line, word}, context.temp_allocator)
                    
                    test_width := rl.MeasureTextEx(rl.GetFontDefault(), fmt.ctprint(test_line), fs_f, spacing).x

                    if test_width > text_area.width && strings.to_string(line) != "" {
                        // Draw line
                        if text_y + line_h > text_area.y && text_y < text_area.y + text_area.height {
                             rl.DrawTextEx(rl.GetFontDefault(), strings.to_cstring(&line), {text_area.x, text_y}, fs_f, spacing, data.text_color)
                        }
                        text_y += line_h
                        strings.builder_reset(&line)
                        strings.write_string(&line, word)
                    } else {
                         if strings.to_string(line) != "" { strings.write_rune(&line, ' ') }
                         strings.write_string(&line, word)
                    }
                    if text_y + line_h > text_area.y + text_area.height { break }
                }

                // Final line
                if strings.to_string(line) != "" && text_y + line_h > text_area.y && text_y < text_area.y + text_area.height {
                     rl.DrawTextEx(rl.GetFontDefault(), strings.to_cstring(&line), {text_area.x, text_y}, fs_f, spacing, data.text_color)
                }

            } else if data.dialogue_text != "" {
                rl.DrawText(fmt.ctprint(data.dialogue_text), i32(text_area.x), i32(text_area.y), data.font_size, data.text_color)
            }
        }
    }
    
    // Draw children
    for child := component.next; child != nil; child = child.next {
        draw_component(child)
    }
}

free_component :: proc(component: ^Component, allocator := context.allocator) {
    if component == nil { return }
    
    // Free children recursively
    child := component.next
    for child != nil {
        next_child := child.next
        free_component(child, allocator)
        child = next_child
    }
    
    // Free data
    if component.data != nil {
        switch component.type {
        case .Button:
            data := cast(^Button_Data)component.data
            delete(data.text, allocator)
            free(data, allocator)
        case .Label:
            data := cast(^Label_Data)component.data
            delete(data.text, allocator)
            free(data, allocator)
        case .Panel:
            free(cast(^Panel_Data)component.data, allocator)
        case .Portrait_Dialogue:
            data := cast(^Portrait_Dialogue_Data)component.data
            if data.speaker_name != "" { delete(data.speaker_name, allocator) }
            if data.dialogue_text != "" { delete(data.dialogue_text, allocator) }
            if data.styled_text != nil { free_styled_text(data.styled_text, allocator) }
            free(data, allocator)
        }
    }
    
    free(component, allocator)
}

// Dialogue nodes
create_dialogue_node :: proc(id, text: string, allocator := context.allocator) -> ^Node {
    node := new(Node, allocator)
    node.id = strings.clone(id, allocator)
    node.text = strings.clone(text, allocator)
    node.components = nil
    node.choices = make([dynamic]^Node, 0, 4, allocator)
    node.on_enter = nil
    node.on_exit = nil
    node.user_data = nil
    return node
}

add_choice :: proc(node: ^Node, choice: ^Node) {
    if node == nil || choice == nil { return }
    append(&node.choices, choice)
}

set_node_callbacks :: proc(node: ^Node, on_enter, on_exit: Callback, user_data: rawptr) {
    if node == nil { return }
    node.on_enter = on_enter
    node.on_exit = on_exit
    node.user_data = user_data
}

// Manager
create_dialogue_manager :: proc(root_node: ^Node, allocator := context.allocator) -> ^Manager {
    manager := new(Manager, allocator)
    manager.root_node = root_node
    manager.current_node = root_node
    manager.active = true
    manager.user_data = nil
    return manager
}

update_dialogue_manager :: proc(manager: ^Manager) {
    if manager == nil || !manager.active || manager.current_node == nil { return }
    
    if manager.current_node.components != nil {
        update_component(manager.current_node.components)
    }
}

draw_dialogue_manager :: proc(manager: ^Manager) {
    if manager == nil || !manager.active || manager.current_node == nil { return }
    
    if manager.current_node.components != nil {
        draw_component(manager.current_node.components)
    }
}


free_dialogue_node_recursive :: proc(node: ^Node, allocator := context.allocator) {
    if node == nil { return }

    // Free choices recursively
    for choice in node.choices {
        free_dialogue_node_recursive(choice, allocator)
    }
    delete(node.choices)

    // Free components
    if node.components != nil {
        free_component(node.components, allocator)
    }

    // Free node data
    delete(node.id, allocator)
    delete(node.text, allocator)
    
    // Free node itself
    free(node, allocator)
}

free_dialogue_manager :: proc(manager: ^Manager, allocator := context.allocator) {
    if manager == nil { return }
    
    // The manager only holds references.
    // The caller is responsible for freeing the node tree if it's no longer needed.
    // Example: free_dialogue_node_recursive(manager.root_node, allocator)
    
    free(manager, allocator)
}

find_node_by_id :: proc(node: ^Node, id: string) -> ^Node {
    if node == nil || id == "" { return nil }
    
    if node.id == id { return node }
    
    for choice in node.choices {
        if found := find_node_by_id(choice, id); found != nil { return found }
    }
    
    return nil
}

transition_to_node :: proc(manager: ^Manager, node_id: string) {
    if manager == nil || node_id == "" { return }
    
    // Exit current
    if manager.current_node != nil && manager.current_node.on_exit != nil {
        manager.current_node.on_exit(manager.current_node.user_data)
    }
    
    // Find target
    target: ^Node = nil
    if node_id == "root" {
        target = manager.root_node
    } else {
        target = find_node_by_id(manager.root_node, node_id)
    }
    
    if target != nil {
        manager.current_node = target
    } else {
        fmt.printf("Warning: Node '%s' not found, returning to root.\n", node_id)
        manager.current_node = manager.root_node
    }
    
    // Enter new
    if manager.current_node != nil && manager.current_node.on_enter != nil {
        manager.current_node.on_enter(manager.current_node.user_data)
    }
}

// Utilities
is_component_clicked :: proc(component: ^Component) -> bool {
    if component == nil || !component.enabled || !component.visible { return false } // Added visible check
    
    current_time := i32(rl.GetTime() * 1000)
    
    mouse_pos := rl.GetMousePosition()
    collision := rl.CheckCollisionPointRec(mouse_pos, component.bounds)
    clicked := collision && rl.IsMouseButtonPressed(.LEFT)
    
    if clicked {
        comp_ptr := component
        // Simple click debounce
        if comp_ptr == last_clicked_component && current_time - last_click_time < 200 { // Increased debounce
            return false
        }
        
        last_clicked_component = comp_ptr
        last_click_time = current_time
        return true
    }
    
    if rl.IsMouseButtonReleased(.LEFT) {
        last_clicked_component = nil
    }
    
    return false
}

is_component_hovered :: proc(component: ^Component) -> bool {
    if component == nil || !component.enabled || !component.visible { return false } // Added visible check

    return rl.CheckCollisionPointRec(rl.GetMousePosition(), component.bounds)
}

set_component_enabled :: proc(component: ^Component, enabled: bool) {
    if component != nil { component.enabled = enabled }
}

set_component_visible :: proc(component: ^Component, visible: bool) {
    if component != nil { component.visible = visible }
}

// Portrait utils
set_portrait_dialogue_text :: proc(component: ^Component, dialogue_text: string, allocator := context.allocator) {
    if component == nil || component.type != .Portrait_Dialogue { return }
    
    data := cast(^Portrait_Dialogue_Data)component.data
    
    // Free old text
    if data.dialogue_text != "" { delete(data.dialogue_text, allocator) }
    if data.styled_text != nil { 
        free_styled_text(data.styled_text, allocator)
        data.styled_text = nil
    }
    
    data.dialogue_text = strings.clone(dialogue_text, allocator)
    data.use_styled_text = false
}

set_portrait_dialogue_speaker :: proc(component: ^Component, speaker_name: string, allocator := context.allocator) {
    if component == nil || component.type != .Portrait_Dialogue { return }
    
    data := cast(^Portrait_Dialogue_Data)component.data
    if data.speaker_name != "" { delete(data.speaker_name, allocator) }
    data.speaker_name = strings.clone(speaker_name, allocator)
}

set_portrait_dialogue_color :: proc(component: ^Component, portrait_color: rl.Color) {
    if component == nil || component.type != .Portrait_Dialogue { return }
    
    data := cast(^Portrait_Dialogue_Data)component.data
    data.portrait_color = portrait_color
    data.use_texture = false
}

set_portrait_dialogue_texture :: proc(component: ^Component, portrait_texture: rl.Texture2D) {
    if component == nil || component.type != .Portrait_Dialogue { return }
    
    data := cast(^Portrait_Dialogue_Data)component.data
    data.portrait_texture = portrait_texture
    data.use_texture = true
}

set_portrait_dialogue_position :: proc(component: ^Component, show_on_right: bool) {
    if component == nil || component.type != .Portrait_Dialogue { return }
    
    data := cast(^Portrait_Dialogue_Data)component.data
    data.show_on_right = show_on_right
}

set_portrait_dialogue_styled_text :: proc(component: ^Component, formatted_text: string, allocator := context.allocator) {
    if component == nil || component.type != .Portrait_Dialogue { return }
    
    data := cast(^Portrait_Dialogue_Data)component.data
    
    // Free old styled text
    if data.styled_text != nil {
        free_styled_text(data.styled_text, allocator)
        data.styled_text = nil
    }
    
    // Free old plain text
    if data.dialogue_text != "" {
        delete(data.dialogue_text, allocator)
        data.dialogue_text = ""
    }
// Parse
    data.styled_text = parse_styled_text(formatted_text, data.text_color, f32(data.font_size), allocator)
    data.use_styled_text = data.styled_text != nil
    
    // Build a plain-text version from the segments
    builder := strings.builder_make(context.temp_allocator)
    defer strings.builder_destroy(&builder)

    if data.use_styled_text {
        for segment := data.styled_text; segment != nil; segment = segment.next {
            strings.write_string(&builder, segment.text)
        }
        plain_text := strings.to_string(builder)
        data.dialogue_text = strings.clone(plain_text, allocator)  // FIXED: Clone to heap
    } else {
        data.dialogue_text = strings.clone(formatted_text, allocator)
    }
}

// Localized
create_localized_button :: proc(bounds: rl.Rectangle, text_key: string, on_click: Callback, user_data: rawptr, i18n_ctx: ^I18N, allocator := context.allocator) -> ^Component {
    return create_button(bounds, get_localized_text(i18n_ctx, text_key), on_click, user_data, allocator)
}

create_localized_label :: proc(bounds: rl.Rectangle, text_key: string, wrap_text: bool, i18n_ctx: ^I18N, allocator := context.allocator) -> ^Component {
    return create_label(bounds, get_localized_text(i18n_ctx, text_key), wrap_text, allocator)
}

create_localized_portrait_dialogue :: proc(bounds: rl.Rectangle, speaker_name_key, dialogue_text_key: string, portrait_color: rl.Color, i18n_ctx: ^I18N, allocator := context.allocator) -> ^Component {
    loc_speaker := get_localized_text(i18n_ctx, speaker_name_key)
    loc_text := get_localized_text(i18n_ctx, dialogue_text_key)
    return create_portrait_dialogue(bounds, loc_speaker, loc_text, portrait_color, allocator)
}

set_localized_button_text :: proc(component: ^Component, text_key: string, i18n_ctx: ^I18N, allocator := context.allocator) {
    if component == nil || text_key == "" || i18n_ctx == nil || component.type != .Button { return }
    
    data := cast(^Button_Data)component.data
    delete(data.text, allocator) // free old
    data.text = get_localized_text(i18n_ctx, text_key)
}

set_localized_label_text :: proc(component: ^Component, text_key: string, i18n_ctx: ^I18N, allocator := context.allocator) {
    if component == nil || text_key == "" || i18n_ctx == nil || component.type != .Label { return }
    
    data := cast(^Label_Data)component.data
    delete(data.text, allocator) // free old
    data.text = get_localized_text(i18n_ctx, text_key)
}

set_localized_portrait_dialogue_text :: proc(component: ^Component, dialogue_text_key: string, i18n_ctx: ^I18N, allocator := context.allocator) {
    if component == nil || dialogue_text_key == "" || i18n_ctx == nil || component.type != .Portrait_Dialogue { return }
    
    set_portrait_dialogue_text(component, get_localized_text(i18n_ctx, dialogue_text_key), allocator)
}

set_localized_portrait_dialogue_speaker :: proc(component: ^Component, speaker_name_key: string, i18n_ctx: ^I18N, allocator := context.allocator) {
    if component == nil || speaker_name_key == "" || i18n_ctx == nil || component.type != .Portrait_Dialogue { return }
    
    set_portrait_dialogue_speaker(component, get_localized_text(i18n_ctx, speaker_name_key), allocator)
}

set_localized_portrait_dialogue_styled_text :: proc(component: ^Component, formatted_text_key: string, i18n_ctx: ^I18N, allocator := context.allocator) {
    if component == nil || formatted_text_key == "" || i18n_ctx == nil || component.type != .Portrait_Dialogue { return }
    
    loc_formatted := get_localized_text(i18n_ctx, formatted_text_key)
    set_portrait_dialogue_styled_text(component, loc_formatted, allocator)
}