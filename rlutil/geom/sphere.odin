package geom

import "core:math"
import "core:math/linalg"
import "core:math/rand"
import rl "vendor:raylib"

GOLDEN_RATIO :: 1.6180339887

gen_points_on_sphere :: proc(num_points: int) -> (res: []rl.Vector3) {
	res = make_slice([]rl.Vector3, num_points)

	for i := 0; i < num_points; i += 1 {
		theta := math.TAU * f32(i) / GOLDEN_RATIO
		phi := math.acos(1.0 - 2.0 * (f32(i) + 0.5) / f32(num_points))
		point: rl.Vector3
		point.z = math.cos(phi)
		point.x = math.cos(theta) * math.sin(phi)
		point.y = math.sin(theta) * math.sin(phi)
		res[i] = point
	}
	return res
}

gen_points_on_hemisphere :: proc(num_points: int) -> (res: []rl.Vector3) {
	res = make_slice([]rl.Vector3, num_points)

	for i:= 0; i < num_points; i += 1 {
		theta := math.TAU * f32(i) / GOLDEN_RATIO
		phi := math.acos(1.0 - 2.0 * (f32(i) + 0.5) / (f32(num_points) * 2.0))
		point: rl.Vector3
		point.z = math.cos(phi)
		point.x = math.cos(theta) * math.sin(phi)
		point.y = math.sin(theta) * math.sin(phi)
		res[i] = point
	}
	return res
}

cosine_weight_to_points_on_hemisphere :: proc(points: []rl.Vector3, weight: f32) {
	for i: int = 0; i < len(points); i+=1 {
		c := linalg.dot(points[i], rl.Vector3{0, 0, 1})
		points[i] = linalg.normalize(points[i] + rl.Vector3{0, 0, 1} * (weight * c))
	}
}