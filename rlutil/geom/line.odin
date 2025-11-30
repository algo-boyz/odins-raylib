package geom

import rl "vendor:raylib"

LineDimensions_Orient :: enum { NONE, HOR, VER }

LineDimensions :: struct {
    using _ : struct #raw_union {
        using _: struct { x0, x1: i32 },
        x: i32
    },
    using _ : struct #raw_union {
        using _: struct { y0, y1: i32 },
        y: i32
    },
    orient: LineDimensions_Orient
}

line_midpoint :: proc(l: [2]rl.Vector2) -> rl.Vector2 {
    return { (l[0].x + l[1].x) / 2, (l[0].y + l[1].y) / 2 }
}

line_slope :: proc(l: [2]rl.Vector2) -> (result: f32, ok: bool) {
    num := l[1].y - l[0].y
    denom := l[1].x - l[0].x

    if denom == 0 { return 0, false }

    return num / denom, true
}

draw_line :: proc(line: LineDimensions, color: rl.Color) {
    using line
    switch orient {
        case .HOR:  rl.DrawLine(line.x0, line.y, line.x1, line.y, color)
        case .VER:  rl.DrawLine(line.x, line.y0, line.x, line.y1, color)
        case .NONE: rl.DrawLine(line.x0, line.y0, line.x1, line.y1, color)
    }
}

draw_vertical_line :: proc "contextless" (x: i32, color: rl.Color) {
    rl.DrawLine(x, 0, x, rl.GetScreenHeight(), color)
}

draw_horizontal_line :: proc "contextless" (y: i32, color: rl.Color) {
    rl.DrawLine(0, y, rl.GetScreenWidth(), y, color)
}

draw_polygon_lines :: proc(vertices: []rl.Vector2, color: rl.Color) {
    for v1, i in vertices {
        v2 := vertices[(i+1) % len(vertices)]
        rl.DrawLineV(v1, v2, color)
    }
}

LineIter :: struct {
	d, s, i, end:   [2]i32,
	err:               i32,
	next:     Maybe([2]i32),
}

// Creates a Bresenham line iterator, yielding a value per pixel
line_iter_new :: proc(from, to: [2]i32) -> LineIter {
	dx :=  abs(to.x - from.x)
	dy := -abs(to.y - from.y)
	sx : i32 = from.x < to.x ? 1 : -1
	sy : i32 = from.y < to.y ? 1 : -1

	return LineIter {
		d = {dx, dy},
		s = {sx, sy},
		err = dx + dy,
		i = from,
		end = to,
		next = [2]i32{from.x, from.y},
	}
}

line_iterate :: proc(iter: ^LineIter) -> ([2]i32, i32, bool) {
	for {
		if next, has_next := iter.next.([2]i32); has_next {
			iter.next = nil
			return next, 0, true
		}
		e := iter.err * 2
		if e >= iter.d.y {
			if iter.i.x == iter.end.x do break
			iter.err += iter.d.y
			iter.i.x += iter.s.x
		}
		if e <= iter.d.x {
			if iter.i.y == iter.end.y do break
			iter.err += iter.d.x
			iter.i.y += iter.s.y
		}
		iter.next = iter.i
	}
	return {}, 0, false
}

// Returns the first non-nil Maybe from the list, or nil if none present
maybe_any :: proc($T: typeid, maybes: []Maybe(T)) -> Maybe(T) {
	for maybe in maybes {
		val, ok := maybe.?
		if ok do return val
	}

	return nil
}