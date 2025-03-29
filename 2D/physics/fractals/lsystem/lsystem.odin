package main

import "core:fmt"
import "core:unicode/utf8"
import "core:math"

StackInfo :: struct {
    posx: f32,
    posy: f32,
    posz: f32,
    vertical_angle: f32,
    horizontal_angle: f32,
}

PositionInfo :: struct {
    start: [3]f32,
    end: [3]f32
}

Rules := [][]string{
    {"F", "FF"},
    {"X", "F[/+X]F[-X]+X"}
}

//Checks if char exists in the Rules array and returns the new string else it returns itself
apply_rules :: proc(char: string) -> string {
    newstr := ""
    for rule in Rules {
        if char == rule[0] {
            newstr = rule[1]
        }
    }
    if newstr == "" {
        newstr = char
    }
    return newstr
}

//Generates the new string by parsing each char
process_string :: proc(oldstring: string) -> string {
    newstr := ""

    for char in oldstring {
        str_char := utf8.runes_to_string({char})
        defer delete(str_char)

        temp := newstr
        newstr = fmt.aprintf("%s%s", newstr, apply_rules(str_char))
        delete(temp)
    }
    return newstr
}

//Generates the lsystem string
create_lsystem :: proc(iterations: int, axiom: string) -> string {
    start_string := axiom
    end_string := ""
    for i in 0..<iterations {
        temp := end_string
        end_string = process_string(start_string)
        start_string = end_string
        delete(temp)
    }
    return end_string
}

polar_to_cartesian :: proc(radian, horizontal_angle, vertical_angle: f32) -> (f32, f32, f32) {
    theta_horizontal := math.to_radians(horizontal_angle)
    theta_vertical := math.to_radians(vertical_angle)
    x := radian * math.cos_f32(theta_vertical)
    y := radian * math.sin_f32(theta_vertical)
    z := radian * math.cos_f32(theta_horizontal)
    return x, y, z
}

//Generates an array of position information for rendering the l-system
draw_lystem :: proc(instructions: string, distance, angle: f32, start_pos: [3]f32, angles: [2]f32) -> []PositionInfo {
    posx := start_pos[0]
    posy := start_pos[1]
    posz := start_pos[2]
    vertical_angle := angles[0]
    horizontal_angle := angles[1]
    stack: [dynamic]StackInfo
    defer delete(stack)
    meshes: [dynamic]PositionInfo

    for char in instructions {
        if char == 'F' {    
            end_pos_x, end_pos_y, end_pos_z := polar_to_cartesian(distance, horizontal_angle, vertical_angle)
            end_x := posx + end_pos_x
            end_y := posy + end_pos_y
            end_z := posz + end_pos_z

            append(&meshes, PositionInfo{
                start = {posx, posy, posz},
                end = {end_x, end_y, end_z}
            })

            posx = end_x
            posy = end_y
            posz = end_z
        } else if char == '+' {
            vertical_angle += angle
        } else if char == '-' {
            vertical_angle -= angle
        } else if char == '/' {
            horizontal_angle += angle
        } else if char == '\\' {
            horizontal_angle -= angle
        } else if char == '[' {
            append(&stack, StackInfo{
                posx = posx,
                posy = posy,
                posz = posz,
                vertical_angle = vertical_angle,
                horizontal_angle = horizontal_angle,
            })
        } else if char == ']' {
            item := pop(&stack)
            posx = item.posx
            posy = item.posy
            posz = item.posz
            vertical_angle = item.vertical_angle
            horizontal_angle = item.horizontal_angle
        }
    }

    fixed_data := make([]PositionInfo, len(meshes))
    copy(fixed_data, meshes[:])
    delete(meshes)

    return fixed_data
}