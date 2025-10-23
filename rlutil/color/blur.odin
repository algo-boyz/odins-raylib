package color

import "core:math"

Gaussian :: struct {
	width, height, radius: int,
	filter: []f32
}

generate_gaussian_filter_1d :: proc(radius: int, sigma: f32 = 1, allocator := context.allocator) -> (filter: Gaussian) {
	filter.width = radius * 2 + 1
	filter.height = 1
	filter.radius = radius
	filter.filter = make_slice([]f32, filter.width * filter.height, allocator)
	sigma_sqr := 1 / (2 * sigma * sigma)
	sqrtau_sigma := 1 / (math.sqrt(f32(math.TAU)) * sigma)
	sum: f32
	for x in -radius..=radius {
		val := math.exp(f32(-x) * f32(x) * sigma_sqr) * sqrtau_sigma
		sum += val
		filter.filter[x + radius] = val
	}
	for i in 0..<len(filter.filter) {
		filter.filter[i] /= sum
	}
	return
}

generate_gaussian_filter_2d :: proc(radius: int, sigma: f32 = 1, allocator := context.allocator) -> (filter: Gaussian) {
	filter.width = radius * 2 + 1
	filter.height = filter.width
	filter.radius = radius
	filter.filter = make_slice([]f32, filter.width * filter.height, allocator)
	sigma_sqr := 1 / (2 * sigma * sigma)
	sqrtau_sigma := 1 / (math.TAU * sigma * sigma)
	sum: f32
	for y in -radius..=radius {
		for x in -radius..=radius {
			xf, yf := f32(x), f32(y)
			val := math.exp(-(xf * xf + yf * yf) * sigma_sqr) * sqrtau_sigma
			sum += val
			idx := (y + radius) * filter.width + (x + radius)
			filter.filter[idx] = val
		}
	}
	for i in 0..<len(filter.filter) {
		filter.filter[i] /= sum
	}
	return
}