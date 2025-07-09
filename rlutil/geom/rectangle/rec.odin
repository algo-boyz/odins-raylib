package rectangle

import rl "vendor:raylib"
import "core:math"

Rec :: rl.Rectangle

to_pos :: proc(r: Rec) -> rl.Vector2 {
    return {r.x, r.y}
}

to_size :: proc(r: Rec) -> rl.Vector2 {
    return {r.width, r.height}
}

is_point_in_rectangle :: proc(point: rl.Vector2, r: Rec) -> bool {
    return point.x >= r.x && 
           point.x <= r.x + r.width &&
           point.y >= r.y && 
           point.y <= r.y + r.height
}

overlaps :: proc(a, b: Rec) -> bool {
    return a.x < b.x + b.width && a.x + a.width > b.x &&
           a.y < b.y + b.height && a.y + a.height > b.y
}

contains_rect :: proc(outer, inner: Rec) -> bool {
    return inner.x >= outer.x &&
           inner.y >= outer.y &&
           inner.x + inner.width <= outer.x + outer.width &&
           inner.y + inner.height <= outer.y + outer.height
}

is_valid :: proc(r: Rec) -> bool {
    return r.width > 0 && r.height > 0
}

area :: proc(r: Rec) -> f32 {
    return r.width * r.height
}

perimeter :: proc(r: Rec) -> f32 {
    return 2 * (r.width + r.height)
}

center_point :: proc(r: Rec) -> (x, y: f32) {
    return r.x + r.width / 2, r.y + r.height / 2
}

corners :: proc(r: Rec) -> [4]rl.Vector2 {
    return {
        {r.x, r.y},                          // top-left
        {r.x + r.width, r.y},                // top-right
        {r.x + r.width, r.y + r.height},     // bottom-right
        {r.x, r.y + r.height},               // bottom-left
    }
}

intersect :: proc(a, b: Rec) -> bool {
    return !(b.x >= a.x + a.width || 
            b.x + b.width <= a.x || 
            b.y >= a.y + a.height || 
            b.y + b.height <= a.y);
}

intersects :: proc(r1, r2: Rec) -> Rec {
    x1 := max(r1.x, r2.x)
    y1 := max(r1.y, r2.y)
    x2 := min(r1.x + r1.width, r2.x + r2.width)
    y2 := min(r1.y + r1.height, r2.y + r2.height)
    if x2 < x1 { x2 = x1 }
    if y2 < y1 { y2 = y1 }
    return {x1, y1, x2 - x1, y2 - y1}
}

// Inward padding (shrinks rectangle)
pad_inward :: proc(r: Rec, padding: f32) -> Rec {
    r := r
    r.x += padding
    r.y += padding
    r.width -= padding * 2
    r.height -= padding * 2
    return r
}

// Outward padding (expands rectangle)
pad :: proc(r: Rec, padding: f32) -> Rec {
    r := r
    r.x -= padding
    r.y -= padding
    r.width += padding * 2
    r.height += padding * 2
    return r
}

// Allows for individual side padding
pad_ex :: proc(r: Rec, left, top, right, bottom: f32) -> Rec {
    r := r
    r.x -= left
    r.y -= top
    r.width += left + right
    r.height += top + bottom
    return r
}

// Inward padding with individual sides
pad_ex_inward :: proc(r: Rec, left, top, right, bottom: f32) -> Rec {
    r := r
    r.x += left
    r.y += top
    r.width -= left + right
    r.height -= top + bottom
    return r
}

move_to :: proc(r: ^Rec, x, y: f32) {
    r.x = x
    r.y = y
}

move_by :: proc(r: ^Rec, dx, dy: f32) {
    r.x += dx
    r.y += dy
}

center_on :: proc(r: ^Rec, target: Rec) {
    target_center_x, target_center_y := center_point(target)
    r.x = target_center_x - r.width / 2
    r.y = target_center_y - r.height / 2
}

align_left :: proc(r: ^Rec, target: Rec) {
    r.x = target.x
}

align_right :: proc(r: ^Rec, target: Rec) {
    r.x = target.x + target.width - r.width
}

align_top :: proc(r: ^Rec, target: Rec) {
    r.y = target.y
}

align_bottom :: proc(r: ^Rec, target: Rec) {
    r.y = target.y + target.height - r.height
}

align_center_x :: proc(r: ^Rec, target: Rec) {
    target_center_x, _ := center_point(target)
    r.x = target_center_x - r.width / 2
}

align_center_y :: proc(r: ^Rec, target: Rec) {
    _, target_center_y := center_point(target)
    r.y = target_center_y - r.height / 2
}

resize :: proc(r: ^Rec, new_width, new_height: f32) {
    r.width = new_width
    r.height = new_height
}

scale :: proc(r: Rec, factor: f32) -> Rec {
    center_x, center_y := center_point(r)
    new_width := r.width * factor
    new_height := r.height * factor
    return {
        center_x - new_width / 2,
        center_y - new_height / 2,
        new_width,
        new_height,
    }
}

scale_xy :: proc(r: Rec, factor_x, factor_y: f32) -> Rec {
    center_x, center_y := center_point(r)
    new_width := r.width * factor_x
    new_height := r.height * factor_y
    return {
        center_x - new_width / 2,
        center_y - new_height / 2,
        new_width,
        new_height,
    }
}

fit_aspect_ratio :: proc(r: Rec, aspect: f32) -> Rec {
    current_aspect := r.width / r.height
    result := r
    
    if current_aspect > aspect {
        // Too wide, fit to height
        result.width = r.height * aspect
        result.x = r.x + (r.width - result.width) / 2
    } else {
        // Too tall, fit to width
        result.height = r.width / aspect
        result.y = r.y + (r.height - result.height) / 2
    }
    
    return result
}

distance_to_point :: proc(r: Rec, point: rl.Vector2) -> f32 {
    if is_point_in_rectangle(point, r) {
        return 0
    }
    
    dx := max(0, max(r.x - point.x, point.x - (r.x + r.width)))
    dy := max(0, max(r.y - point.y, point.y - (r.y + r.height)))
    
    return math.sqrt(dx*dx + dy*dy)
}

closest_point_on_edge :: proc(r: Rec, point: rl.Vector2) -> rl.Vector2 {
    clamped_x := max(r.x, min(point.x, r.x + r.width))
    clamped_y := max(r.y, min(point.y, r.y + r.height))
    
    // If point is inside, find closest edge
    if is_point_in_rectangle(point, r) {
        dist_to_left := point.x - r.x
        dist_to_right := (r.x + r.width) - point.x
        dist_to_top := point.y - r.y
        dist_to_bottom := (r.y + r.height) - point.y
        
        min_dist := min(dist_to_left, min(dist_to_right, min(dist_to_top, dist_to_bottom)))
        
        if min_dist == dist_to_left {
            return {r.x, point.y}
        } else if min_dist == dist_to_right {
            return {r.x + r.width, point.y}
        } else if min_dist == dist_to_top {
            return {point.x, r.y}
        } else {
            return {point.x, r.y + r.height}
        }
    }
    
    return {clamped_x, clamped_y}
}

extend_top :: proc(r: ^Rec, amount: f32) -> (res: Rec) {
    res = {
        r.x,
        r.y - amount,
        r.width,
        amount,
    }
    r.y -= amount
    r.height += amount
    return res
}

take_right :: proc(r: ^Rec, amount: f32) -> Rec {
    return {
        r.x + r.width - amount,
        r.y,
        amount,
        r.height,
    }
}

delete_top :: proc(r: ^Rec, amount: f32) {
    r.y += amount
    r.height -= amount
}

cut_top :: proc(r: ^Rec, amount: f32) -> (res: Rec) {
    res = {
        r.x,
        r.y,
        r.width,
        amount,
    }
    r.y += amount
    r.height -= amount
    return res
}

cut_bottom :: proc(r: ^Rec, amount: f32) -> (res: Rec) {
    res = {
        r.x,
        r.y + r.height - amount,
        r.width,
        amount,
    }
    r.height -= amount
    return res
}

cut_left :: proc(r: ^Rec, amount: f32) -> (res: Rec) {
    res = {
        r.x,
        r.y,
        amount,
        r.height,
    }
    r.x += amount
    r.width -= amount
    return res
}

cut_right :: proc(r: ^Rec, amount: f32) -> (res: Rec) {
    res = {
        r.x + r.width - amount,
        r.y,
        amount,
        r.height,
    }
    r.width -= amount
    return res
}

relative :: #force_inline proc "contextless" (r: Rec) -> Rec {
    return {
        r.x,
        r.y,
        r.width - r.x,
        r.height - r.y,
    }
}

lerp :: proc(a, b: rl.Rectangle, t: f32) -> rl.Rectangle {
	return {
		a.x + (b.x - a.x) * t,
		a.y + (b.y - a.y) * t,
		a.width + (b.width - a.width) * t,
		a.height + (b.height - a.height) * t,
	}
}

to_vec :: proc(r: rl.Rectangle) -> [2]f32 {
	return {r.x, r.y}
}

mouse_on :: proc(r: rl.Rectangle) -> bool {
	relPos := Input.mousePosition - RectPos(r)
	return relPos.x > 0 && relPos.x < r.width && relPos.y > 0 && relPos.y < r.height
}