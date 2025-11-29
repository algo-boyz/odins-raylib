package main

import "core:fmt"
import "core:os"
import "core:strconv"
import "core:strings"
import rl "vendor:raylib"

ChannelType :: enum {
    X_POSITION = 0,
    Y_POSITION = 1,
    Z_POSITION = 2,
    X_ROTATION = 3,
    Y_ROTATION = 4,
    Z_ROTATION = 5,
}

BVHJointData :: struct {
	parent:       int,
	name:         string,
	offset:       rl.Vector3,
	channels:     [dynamic]ChannelType,
	end_site:     bool,
}

BVHData :: struct {
    joints:       [dynamic]BVHJointData,
    joint_count:  i32,
    channel_count:i32,
    frame_count:  i32,
    frame_time:   f32,
    motion_data:  [dynamic]f32,
}

BVHError :: enum {
    None,
    FileNotFound,
    FileReadError,
    InvalidFormat,
    MissingHierarchy,
    MissingRoot,
    InvalidJoint,
    InvalidOffset,
    InvalidChannels,
    MissingMotion,
    InvalidFrameCount,
    InvalidFrameTime,
    InvalidMotionData,
}

Parser :: struct {
    filename: string,
    data:     string,
    cursor:   int,
    row, col: int,
    error_msg: string,
}

parser_init :: proc(filename: string, data: string) -> Parser {
    return Parser{filename = filename, data = data, cursor = 0, row = 0, col = 0}
}

parser_error :: proc(p: ^Parser, msg: string) {
    p.error_msg = fmt.aprintf("%s:%d:%d: %s", p.filename, p.row + 1, p.col + 1, msg)
}

parser_peek :: proc(p: ^Parser) -> u8 {
    if p.cursor >= len(p.data) do return 0
    return p.data[p.cursor]
}

parser_peek_forward :: proc(p: ^Parser, steps: int) -> u8 {
    if p.cursor + steps >= len(p.data) do return 0
    return p.data[p.cursor + steps]
}

parser_advance :: proc(p: ^Parser, n: int = 1) {
    for _ in 0 ..< n {
        if p.cursor < len(p.data) {
            if p.data[p.cursor] == '\n' {
                p.row += 1
                p.col = 0
            } else {
                p.col += 1
            }
            p.cursor += 1
        }
    }
}

parser_skip_whitespace :: proc(p: ^Parser) {
    for {
        c := parser_peek(p)
        if c == ' ' || c == '\t' || c == '\r' || c == '\v' {
            parser_advance(p)
        } else {
            break
        }
    }
}

parser_skip_newline :: proc(p: ^Parser) -> bool {
    parser_skip_whitespace(p)
    if parser_peek(p) == '\n' {
        parser_advance(p)
        parser_skip_whitespace(p)
        return true
    }
    return false
}

parser_match_string :: proc(p: ^Parser, s: string) -> bool {
    parser_skip_whitespace(p)
    remaining := p.data[p.cursor:]
    if len(remaining) >= len(s) && strings.equal_fold(remaining[:len(s)], s) {
        parser_advance(p, len(s))
        return true
    }
    return false
}

parser_expect_string :: proc(p: ^Parser, s: string) -> bool {
    if !parser_match_string(p, s) {
        parser_error(p, fmt.tprintf("Expected '%s'", s))
        return false
    }
    return true
}

parser_expect_newline :: proc(p: ^Parser) -> bool {
    if !parser_skip_newline(p) {
        parser_error(p, "Expected newline")
        return false
    }
    return true
}

parse_f32 :: proc(p: ^Parser) -> (f32, bool) {
    parser_skip_whitespace(p)
    remaining := p.data[p.cursor:]
    
    // Find the end of the number
    i := 0
    has_digits := false
    for i < len(remaining) {
        c := remaining[i]
        if (c >= '0' && c <= '9') {
            has_digits = true
            i += 1
        } else if c == '.' || c == '-' || c == '+' || c == 'e' || c == 'E' {
            i += 1
        } else {
            break
        }
    }
    if !has_digits {
        parser_error(p, "Expected floating point number")
        return 0, false
    }
    val, ok := strconv.parse_f32(remaining[:i])
    if !ok {
        parser_error(p, fmt.tprintf("Failed to parse float: '%s'", remaining[:i]))
        return 0, false
    }
    parser_advance(p, i)
    return val, true
}

parse_int :: proc(p: ^Parser) -> (int, bool) {
    parser_skip_whitespace(p)
    remaining := p.data[p.cursor:]
    i: int
    has_digits := false
    if i < len(remaining) && remaining[i] == '-' {
        i += 1
    }
    for i < len(remaining) {
        c := remaining[i]
        if c >= '0' && c <= '9' {
            has_digits = true
            i += 1
        } else {
            break
        }
    }
    if !has_digits {
        parser_error(p, "Expected integer")
        return 0, false
    }
    val, ok := strconv.parse_int(remaining[:i])
    if !ok {
        parser_error(p, fmt.tprintf("Failed to parse integer: '%s'", remaining[:i]))
        return 0, false
    }
    parser_advance(p, i)
    return val, true
}

parse_name :: proc(p: ^Parser) -> (string, bool) {
    parser_skip_whitespace(p)
    start := p.cursor
    for p.cursor < len(p.data) {
        c := p.data[p.cursor]
        if (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || 
           (c >= '0' && c <= '9') || c == '_' || c == ':' || c == '-' || c == '.' {
            parser_advance(p)
        } else {
            break
        }
    }
    if p.cursor == start {
        parser_error(p, "Expected name/identifier")
        return "", false
    }
    return p.data[start:p.cursor], true
}

parse_channel :: proc(p: ^Parser) -> (ChannelType, bool) {
    parser_skip_whitespace(p)
    c := parser_peek(p)
    if c == 0 {
        parser_error(p, "Unexpected end of file while parsing channel")
        return .X_POSITION, false
    }
    next := parser_peek_forward(p, 1)
    
    if c == 'X' && next == 'p' {
        if parser_match_string(p, "Xposition") do return .X_POSITION, true
    } else if c == 'Y' && next == 'p' {
        if parser_match_string(p, "Yposition") do return .Y_POSITION, true
    } else if c == 'Z' && next == 'p' {
        if parser_match_string(p, "Zposition") do return .Z_POSITION, true
    } else if c == 'X' && next == 'r' {
        if parser_match_string(p, "Xrotation") do return .X_ROTATION, true
    } else if c == 'Y' && next == 'r' {
        if parser_match_string(p, "Yrotation") do return .Y_ROTATION, true
    } else if c == 'Z' && next == 'r' {
        if parser_match_string(p, "Zrotation") do return .Z_ROTATION, true
    }
    // Show what we actually found
    end := p.cursor + 20
    if end > len(p.data) do end = len(p.data)
    parser_error(p, fmt.tprintf("Invalid channel type, got: '%s'", p.data[p.cursor:end]))
    return .X_POSITION, false
}

parse_joint :: proc(p: ^Parser, bvh: ^BVHData, parent_idx: int) -> bool {
    joint_idx := len(bvh.joints)
    append(&bvh.joints, BVHJointData{parent = parent_idx})
    
    is_end_site := false
    
    // Parse joint type and name
    if parser_match_string(p, "JOINT") {
        name, ok := parse_name(p)
        if !ok do return false
        bvh.joints[joint_idx].name = strings.clone(name)
    } else if parser_match_string(p, "End Site") {
        bvh.joints[joint_idx].name = strings.clone("End Site")
        bvh.joints[joint_idx].end_site = true
        is_end_site = true
    } else {
        parser_error(p, "Expected 'JOINT' or 'End Site'")
        return false
    }
    if !parser_expect_newline(p) do return false
    if !parser_expect_string(p, "{") do return false
    if !parser_expect_newline(p) do return false
    
    // Parse offset
    if !parser_expect_string(p, "OFFSET") do return false
    ox, ok_x := parse_f32(p)
    if !ok_x do return false
    oy, ok_y := parse_f32(p)
    if !ok_y do return false
    oz, ok_z := parse_f32(p)
    if !ok_z do return false
    bvh.joints[joint_idx].offset = {ox, oy, oz}
    if !parser_expect_newline(p) do return false
    
    if !is_end_site {
        // Parse channels
        if !parser_expect_string(p, "CHANNELS") do return false
        count, ok_count := parse_int(p)
        if !ok_count do return false
        
        if count < 0 || count > 6 {
            parser_error(p, fmt.tprintf("Invalid channel count: %d (expected 0-6)", count))
            return false
        }
        for i in 0 ..< count {
            channel, ok := parse_channel(p)
            if !ok {
                parser_error(p, fmt.tprintf("Failed to parse channel %d of %d", i + 1, count))
                return false
            }
            append(&bvh.joints[joint_idx].channels, channel)
        }
        if !parser_expect_newline(p) do return false
        
        // Parse children
        for {
            parser_skip_whitespace(p)
            c := parser_peek(p)
            if c == '}' do break
            if c == 'J' || c == 'j' || c == 'E' || c == 'e' {
                if !parse_joint(p, bvh, joint_idx) do return false
            } else {
                break
            }
        }
    }
    if !parser_expect_string(p, "}") do return false
    if !parser_expect_newline(p) do return false
    return true
}

bvh_load :: proc(filename: string) -> (BVHData, BVHError) {
    data, ok := os.read_entire_file(filename)
    if !ok {
        if !os.exists(filename) {
            fmt.eprintln("File not found:", filename)
            return {}, .FileNotFound
        }
        fmt.eprintln("Failed to read file:", filename)
        return {}, .FileReadError
    }
    defer delete(data)
    
    text_data := string(data)
    p := parser_init(filename, text_data)
    bvh := BVHData{}

    // Parse HIERARCHY
    if !parser_match_string(&p, "HIERARCHY") {
        fmt.eprintln("Error: Missing HIERARCHY section")
        if p.error_msg != "" {
            fmt.eprintln(p.error_msg)
            delete(p.error_msg)
        }
        return bvh, .MissingHierarchy
    }
    if !parser_expect_newline(&p) {
        fmt.eprintln("Error: Expected newline after HIERARCHY")
        if p.error_msg != "" {
            fmt.eprintln(p.error_msg)
            delete(p.error_msg)
        }
        return bvh, .InvalidFormat
    }
    // Parse ROOT
    if !parser_match_string(&p, "ROOT") {
        fmt.eprintln("Error: Missing ROOT joint")
        if p.error_msg != "" {
            fmt.eprintln(p.error_msg)
            delete(p.error_msg)
        }
        return bvh, .MissingRoot
    }
    root_idx := len(bvh.joints)
    append(&bvh.joints, BVHJointData{parent = -1})
    
    name, name_ok := parse_name(&p)
    if !name_ok {
        fmt.eprintln("Error: Failed to parse ROOT name")
        if p.error_msg != "" {
            fmt.eprintln(p.error_msg)
            delete(p.error_msg)
        }
        return bvh, .InvalidJoint
    }
    bvh.joints[root_idx].name = strings.clone(name)
    
    if !parser_expect_newline(&p) {
        fmt.eprintln("Error: Expected newline after ROOT name")
        if p.error_msg != "" {
            fmt.eprintln(p.error_msg)
            delete(p.error_msg)
        }
        return bvh, .InvalidFormat
    }
    if !parser_expect_string(&p, "{") {
        fmt.eprintln("Error: Expected '{' after ROOT")
        if p.error_msg != "" {
            fmt.eprintln(p.error_msg)
            delete(p.error_msg)
        }
        return bvh, .InvalidFormat
    }
    if !parser_expect_newline(&p) {
        fmt.eprintln("Error: Expected newline after '{'")
        if p.error_msg != "" {
            fmt.eprintln(p.error_msg)
            delete(p.error_msg)
        }
        return bvh, .InvalidFormat
    }
    // Parse root offset
    if !parser_expect_string(&p, "OFFSET") {
        fmt.eprintln("Error: Expected OFFSET for ROOT")
        if p.error_msg != "" {
            fmt.eprintln(p.error_msg)
            delete(p.error_msg)
        }
        return bvh, .InvalidOffset
    }
    ox, ok_x := parse_f32(&p)
    oy, ok_y := parse_f32(&p)
    oz, ok_z := parse_f32(&p)
    if !ok_x || !ok_y || !ok_z {
        fmt.eprintln("Error: Failed to parse ROOT offset values")
        if p.error_msg != "" {
            fmt.eprintln(p.error_msg)
            delete(p.error_msg)
        }
        return bvh, .InvalidOffset
    }
    bvh.joints[root_idx].offset = {ox, oy, oz}
    
    if !parser_expect_newline(&p) {
        fmt.eprintln("Error: Expected newline after OFFSET")
        if p.error_msg != "" {
            fmt.eprintln(p.error_msg)
            delete(p.error_msg)
        }
        return bvh, .InvalidFormat
    }
    // Parse root channels
    if !parser_expect_string(&p, "CHANNELS") {
        fmt.eprintln("Error: Expected CHANNELS for ROOT")
        if p.error_msg != "" {
            fmt.eprintln(p.error_msg)
            delete(p.error_msg)
        }
        return bvh, .InvalidChannels
    }
    count, count_ok := parse_int(&p)
    if !count_ok {
        fmt.eprintln("Error: Failed to parse channel count")
        if p.error_msg != "" {
            fmt.eprintln(p.error_msg)
            delete(p.error_msg)
        }
        return bvh, .InvalidChannels
    }
    for i in 0 ..< count {
        channel, ok := parse_channel(&p)
        if !ok {
            fmt.eprintln("Error: Failed to parse ROOT channel", i + 1, "of", count)
            if p.error_msg != "" {
                fmt.eprintln(p.error_msg)
                delete(p.error_msg)
            }
            return bvh, .InvalidChannels
        }
        append(&bvh.joints[root_idx].channels, channel)
    }
    if !parser_expect_newline(&p) {
        fmt.eprintln("Error: Expected newline after CHANNELS")
        if p.error_msg != "" {
            fmt.eprintln(p.error_msg)
            delete(p.error_msg)
        }
        return bvh, .InvalidFormat
    }
    // Parse child joints
    for {
        parser_skip_whitespace(&p)
        c := parser_peek(&p)
        if c == '}' do break
        if !parse_joint(&p, &bvh, root_idx) {
            fmt.eprintln("Error: Failed to parse child joint")
            if p.error_msg != "" {
                fmt.eprintln(p.error_msg)
                delete(p.error_msg)
            }
            return bvh, .InvalidJoint
        }
    }
    if !parser_expect_string(&p, "}") {
        fmt.eprintln("Error: Expected '}' to close ROOT")
        if p.error_msg != "" {
            fmt.eprintln(p.error_msg)
            delete(p.error_msg)
        }
        return bvh, .InvalidFormat
    }
    if !parser_expect_newline(&p) {
        fmt.eprintln("Error: Expected newline after ROOT closing '}'")
        if p.error_msg != "" {
            fmt.eprintln(p.error_msg)
            delete(p.error_msg)
        }
        return bvh, .InvalidFormat
    }
    // Parse MOTION
    if !parser_match_string(&p, "MOTION") {
        fmt.eprintln("Error: Missing MOTION section")
        if p.error_msg != "" {
            fmt.eprintln(p.error_msg)
            delete(p.error_msg)
        }
        return bvh, .MissingMotion
    }
    if !parser_expect_newline(&p) {
        fmt.eprintln("Error: Expected newline after MOTION")
        if p.error_msg != "" {
            fmt.eprintln(p.error_msg)
            delete(p.error_msg)
        }
        return bvh, .InvalidFormat
    }
    // Parse Frames
    if !parser_expect_string(&p, "Frames:") {
        fmt.eprintln("Error: Expected 'Frames:'")
        if p.error_msg != "" {
            fmt.eprintln(p.error_msg)
            delete(p.error_msg)
        }
        return bvh, .InvalidFormat
    }
    frames, frames_ok := parse_int(&p)
    if !frames_ok {
        fmt.eprintln("Error: Failed to parse frame count")
        if p.error_msg != "" {
            fmt.eprintln(p.error_msg)
            delete(p.error_msg)
        }
        return bvh, .InvalidFrameCount
    }
    bvh.frame_count = i32(frames)
    
    if !parser_expect_newline(&p) {
        fmt.eprintln("Error: Expected newline after Frames")
        if p.error_msg != "" {
            fmt.eprintln(p.error_msg)
            delete(p.error_msg)
        }
        return bvh, .InvalidFormat
    }
    // Parse Frame Time
    if !parser_expect_string(&p, "Frame Time:") {
        fmt.eprintln("Error: Expected 'Frame Time:'")
        if p.error_msg != "" {
            fmt.eprintln(p.error_msg)
            delete(p.error_msg)
        }
        return bvh, .InvalidFormat
    }
    ft, ft_ok := parse_f32(&p)
    if !ft_ok {
        fmt.eprintln("Error: Failed to parse frame time")
        if p.error_msg != "" {
            fmt.eprintln(p.error_msg)
            delete(p.error_msg)
        }
        return bvh, .InvalidFrameTime
    }
    bvh.frame_time = ft
    if bvh.frame_time == 0 do bvh.frame_time = 1.0/60.0
    
    if !parser_expect_newline(&p) {
        fmt.eprintln("Error: Expected newline after Frame Time")
        if p.error_msg != "" {
            fmt.eprintln(p.error_msg)
            delete(p.error_msg)
        }
        return bvh, .InvalidFormat
    }
    // Calculate total channels
    total_channels := 0
    for j in bvh.joints {
        total_channels += len(j.channels)
    }
    bvh.channel_count = i32(total_channels)
    
    fmt.println("Parsing motion data:", frames, "frames,", total_channels, "channels per frame")
    
    // Parse Motion Data
    expected_floats := bvh.frame_count * i32(total_channels)
    reserve(&bvh.motion_data, expected_floats)
    
    for frame_idx in 0..<bvh.frame_count {
        for channel_idx in 0..<total_channels {
            val, ok := parse_f32(&p)
            if !ok {
                fmt.eprintln("Error: Failed to parse motion data at frame", frame_idx, "channel", channel_idx)
                fmt.eprintln("Expected", expected_floats, "floats, got", len(bvh.motion_data))
                if p.error_msg != "" {
                    fmt.eprintln(p.error_msg)
                    delete(p.error_msg)
                }
                return bvh, .InvalidMotionData
            }
            append(&bvh.motion_data, val)
        }
        // Newline handling
        if frame_idx < bvh.frame_count - 1 {
            if !parser_skip_newline(&p) {
                // Some files might not have newlines between frames
                parser_skip_whitespace(&p)
            }
        }
    }
    fmt.println("Successfully parsed", len(bvh.joints), "joints and", len(bvh.motion_data), "motion values")
    
    // Clean up any error message
    if p.error_msg != "" {
        delete(p.error_msg)
    }
    return bvh, .None
}

bvh_free :: proc(bvh: ^BVHData) {
	for j in bvh.joints {
		delete(j.name)
		delete(j.channels)
	}
	delete(bvh.joints)
	delete(bvh.motion_data)
}