package geom

import "core:math"
import "core:math/linalg"

Aabb :: struct {
  min: [3]f32,
  max: [3]f32,
}

AABB_UNDEFINED := Aabb {
  min = {math.F32_MAX, math.F32_MAX, math.F32_MAX},
  max = {math.F32_MIN, math.F32_MIN, math.F32_MIN},
}

Vertex :: struct {
  position: [3]f32,
  normal:   [3]f32,
  color:    [4]f32,
  uv:       [2]f32,
  tangent:  [4]f32, // xyz = tangent, w = handedness
}

aabb_from_vertices :: proc(vertices: []Vertex) -> (ret: Aabb) {
  ret = AABB_UNDEFINED
  for vertex in vertices {
    ret.min = linalg.min(ret.min, vertex.position)
    ret.max = linalg.max(ret.max, vertex.position)
  }
  if len(vertices) == 0 {
    ret.min, ret.max = {0, 0, 0}, {0, 0, 0}
  }
  return ret
}

aabb_union :: proc(a, b: Aabb) -> Aabb {
  return Aabb{
    min = linalg.min(a.min, b.min),
    max = linalg.max(a.max, b.max),
  }
}

aabb_transform :: proc(aabb: Aabb, mat_transform: matrix[4,4]f32) -> (res: Aabb) {
  min_p := aabb.min
  max_p := aabb.max
  corners: [8][4]f32
  corners[0] = {min_p.x, min_p.y, min_p.z, 1.0}
  corners[1] = {max_p.x, min_p.y, min_p.z, 1.0}
  corners[2] = {min_p.x, max_p.y, min_p.z, 1.0}
  corners[3] = {min_p.x, min_p.y, max_p.z, 1.0}
  corners[4] = {max_p.x, max_p.y, min_p.z, 1.0}
  corners[5] = {max_p.x, min_p.y, max_p.z, 1.0}
  corners[6] = {min_p.x, max_p.y, max_p.z, 1.0}
  corners[7] = {max_p.x, max_p.y, max_p.z, 1.0}
  res = AABB_UNDEFINED
  for corner in corners {
    transformed_corner := mat_transform * corner
    res.min = linalg.min(res.min, transformed_corner.xyz)
    res.max = linalg.max(res.max, transformed_corner.xyz)
  }
  return
}

aabb_intersects :: proc(a, b: Aabb) -> bool {
  return a.min.x <= b.max.x && a.max.x >= b.min.x &&
         a.min.y <= b.max.y && a.max.y >= b.min.y &&
         a.min.z <= b.max.z && a.max.z >= b.min.z
}

aabb_contains :: proc(outer, inner: Aabb) -> bool {
  return inner.min.x >= outer.min.x && inner.max.x <= outer.max.x &&
         inner.min.y >= outer.min.y && inner.max.y <= outer.max.y &&
         inner.min.z >= outer.min.z && inner.max.z <= outer.max.z
}

aabb_contains_approx :: proc(outer, inner: Aabb, epsilon: f32 = 1e-6) -> bool {
  return inner.min.x >= outer.min.x - epsilon && inner.max.x <= outer.max.x + epsilon &&
         inner.min.y >= outer.min.y - epsilon && inner.max.y <= outer.max.y + epsilon &&
         inner.min.z >= outer.min.z - epsilon && inner.max.z <= outer.max.z + epsilon
}

aabb_contains_point :: proc(aabb: Aabb, point: [3]f32) -> bool {
  return point.x >= aabb.min.x && point.x <= aabb.max.x &&
         point.y >= aabb.min.y && point.y <= aabb.max.y &&
         point.z >= aabb.min.z && point.z <= aabb.max.z
}

aabb_center :: proc(aabb: Aabb) -> [3]f32 {
  return (aabb.min + aabb.max) * 0.5
}

aabb_size :: proc(aabb: Aabb) -> [3]f32 {
  return aabb.max - aabb.min
}

aabb_surface_area :: proc(aabb: Aabb) -> f32 {
  d := aabb.max - aabb.min
  return 2.0 * (d.x * d.y + d.y * d.z + d.z * d.x)
}

aabb_volume :: proc(aabb: Aabb) -> f32 {
  d := aabb.max - aabb.min
  return d.x * d.y * d.z
}

aabb_sphere_intersects :: proc(aabb: Aabb, center: [3]f32, radius: f32) -> bool {
  closest := linalg.clamp(center, aabb.min, aabb.max)
  diff := center - closest
  return linalg.dot(diff, diff) <= radius * radius
}

distance_point_aabb :: proc(point: [3]f32, aabb: Aabb) -> f32 {
  closest := linalg.clamp(point, aabb.min, aabb.max)
  return linalg.length(point - closest)
}

ray_aabb_intersection :: proc(origin: [3]f32, inv_dir: [3]f32, aabb: Aabb) -> (t_near, t_far: f32) {
  t_min := [3]f32{-math.F32_MAX, -math.F32_MAX, -math.F32_MAX}
  t_max := [3]f32{math.F32_MAX, math.F32_MAX, math.F32_MAX}

  for i in 0..<3 {
    if math.abs(inv_dir[i]) < 1e-6 {
      // Ray is parallel to this axis
      if origin[i] < aabb.min[i] || origin[i] > aabb.max[i] {
        // Ray is outside the slab, no intersection
        return math.F32_MAX, -math.F32_MAX
      }
      // Ray is inside the slab, use the full range
    } else {
      t1 := (aabb.min[i] - origin[i]) * inv_dir[i]
      t2 := (aabb.max[i] - origin[i]) * inv_dir[i]

      t_min[i] = min_f32(t1, t2)
      t_max[i] = max_f32(t1, t2)
    }
  }

  t_near = max_f32(max_f32(t_min.x, t_min.y), t_min.z)
  t_far = min_f32(min_f32(t_max.x, t_max.y), t_max.z)

  return
}

ray_aabb_intersection_far :: proc(origin: [3]f32, inv_dir: [3]f32, aabb: Aabb) -> f32 {
  t1 := (aabb.min - origin) * inv_dir
  t2 := (aabb.max - origin) * inv_dir

  t_max := linalg.max(t1, t2)

  return min(min(t_max.x, t_max.y), t_max.z)
}

min_f32 :: proc(a, b: f32) -> f32 {
  return a < b ? a : b
}

max_f32 :: proc(a, b: f32) -> f32 {
  return a > b ? a : b
}

min_vec3 :: proc(v: [3]f32) -> f32 {
  return min_f32(min_f32(v.x, v.y), v.z)
}

max_vec3 :: proc(v: [3]f32) -> f32 {
  return max_f32(max_f32(v.x, v.y), v.z)
}