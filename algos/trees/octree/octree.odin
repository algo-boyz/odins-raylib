package octree

import "core:math"
import "core:math/linalg"
import "core:slice"
import "../../../rlutil/geom"

Node :: struct($T: typeid) {
  bounds:      geom.Aabb,
  center:      [3]f32,
  children:    [8]^Node(T),
  items:       [dynamic]T,
  depth,
  num_items:   i32,
}

Octree :: struct($T: typeid) {
  root:        ^Node(T),
  max_depth,
  max_items:   i32,
  min_size:    f32,
  bounds_func: proc(t: T) -> geom.Aabb,
  point_func:  proc(t: T) -> [3]f32,
}

init :: proc(ot: ^Octree($T), bounds: geom.Aabb, max_depth: i32 = 8, max_items: i32 = 8) {
  ot.root = new(Node(T))
  ot.root.bounds = bounds
  ot.root.center = geom.aabb_center(bounds)
  ot.root.depth = 0
  ot.root.items = make([dynamic]T)
  ot.root.num_items = 0
  ot.max_depth = max_depth
  ot.max_items = max_items
  shift_val := u32(1) << u32(max_depth)
  ot.min_size = geom.min_vec3(geom.aabb_size(bounds)) / f32(shift_val)
}

deinit :: proc(ot: ^Octree($T)) {
  node_deinit(ot.root)
  free(ot.root)
  ot.root = nil
}

@(private)
node_deinit :: proc(node: ^Node($T)) {
  if node == nil do return
  for i in 0 ..< 8 {
    if node.children[i] != nil {
      node_deinit(node.children[i])
      free(node.children[i])
    }
  }
  delete(node.items)
}

@(private)
get_octant :: proc(center, point: [3]f32) -> i32 {
  octant: i32
  if point.x >= center.x do octant |= 0b001
  if point.y >= center.y do octant |= 0b010
  if point.z >= center.z do octant |= 0b100
  return octant
}

@(private)
get_octant_for_aabb :: proc(node_center: [3]f32, aabb: geom.Aabb) -> i32 {
  center := geom.aabb_center(aabb)
  if aabb.min.x < node_center.x && aabb.max.x > node_center.x do return -1
  if aabb.min.y < node_center.y && aabb.max.y > node_center.y do return -1
  if aabb.min.z < node_center.z && aabb.max.z > node_center.z do return -1
  return get_octant(node_center, center)
}

@(private)
get_child_bounds :: proc(parent: ^Node($T), octant: i32) -> geom.Aabb {
  size := (parent.bounds.max - parent.bounds.min) * 0.5
  min := parent.bounds.min
  if octant & 1 != 0 do min.x += size.x
  if octant & 2 != 0 do min.y += size.y
  if octant & 4 != 0 do min.z += size.z
  return geom.Aabb{min = min, max = min + size}
}

@(private)
get_child_center :: proc(parent_center, parent_size: [3]f32, octant: i32) -> [3]f32 {
  offset := parent_size * 0.25
  center := parent_center
  if octant & 1 != 0 {
    center.x += offset.x
  } else {
    center.x -= offset.x
  }
  if octant & 2 != 0 {
    center.y += offset.y
  } else {
    center.y -= offset.y
  }
  if octant & 4 != 0 {
    center.z += offset.z
  } else {
    center.z -= offset.z
  }
  return center
}

@(private)
subdivide :: proc(node: ^Node($T)) {
  parent_size := node.bounds.max - node.bounds.min
  for i in 0 ..< 8 {
    child := new(Node(T))
    child.bounds = get_child_bounds(node, i32(i))
    child.center = get_child_center(node.center, parent_size, i32(i))
    child.depth = node.depth + 1
    child.items = make([dynamic]T)
    child.num_items = 0
    node.children[i] = child
  }
}

@(private)
should_subdivide :: proc(ot: ^Octree($T), node: ^Node(T)) -> bool {
  if node.depth >= ot.max_depth do return false
  size := geom.min_vec3(node.bounds.max - node.bounds.min)
  if size <= ot.min_size do return false

  if i32(len(node.items)) <= ot.max_items do return false

  octant_counts: [8]i32
  for item in node.items {
    bounds := ot.bounds_func(item)
    octant := get_octant_for_aabb(node.center, bounds)
    if octant >= 0 do octant_counts[octant] += 1
    else do return true
  }
  non_empty: int
  for count in octant_counts {
    if count > 0 do non_empty += 1
  }
  return non_empty > 1
}

insert :: proc(ot: ^Octree($T), item: T) -> bool {
  bounds := ot.bounds_func(item)

  if !geom.aabb_contains(ot.root.bounds, bounds) do return false
  return node_insert(ot, ot.root, item, bounds)
}

@(private)
node_insert :: proc(ot: ^Octree($T), node: ^Node(T), item: T, bounds: geom.Aabb) -> bool {
  if node.children[0] == nil {
    append(&node.items, item)
    node.num_items += 1
    if should_subdivide(ot, node) {
      subdivide(node)
      old := node.items[:]
      clear(&node.items)
      node.num_items = i32(len(node.items))

      for old_item in old {
        old_bounds := ot.bounds_func(old_item)
        node_insert_to_children(ot, node, old_item, old_bounds)
      }
    }
    return true
  }
  if node_insert_to_children(ot, node, item, bounds) {
    node.num_items += 1
    return true
  }
  return false
}

@(private)
node_insert_to_children :: proc(ot: ^Octree($T), node: ^Node(T), item: T, bounds: geom.Aabb) -> bool {
  octant := get_octant_for_aabb(node.center, bounds)
  if octant >= 0 {
    return node_insert(ot, node.children[octant], item, bounds)
  }
  append(&node.items, item)
  node.num_items += 1
  return true
}

query_aabb :: proc(ot: ^Octree($T), bounds: geom.Aabb, res: ^[dynamic]T) {
  clear(res)
  node_query_aabb(ot, ot.root, bounds, res)
}

query_aabb_lim :: proc(ot: ^Octree($T), bounds: geom.Aabb, res: ^[dynamic]T, max_res: int) {
  clear(res)
  node_query_aabb_lim(ot, ot.root, bounds, res, max_res)
}

@(private)
node_query_aabb :: proc(ot: ^Octree($T), node: ^Node(T), bounds: geom.Aabb, res: ^[dynamic]T) {
  if !geom.aabb_intersects(node.bounds, bounds) do return
  for item in node.items {
    bounds := ot.bounds_func(item)
    if geom.aabb_intersects(bounds, bounds) {
      append(res, item)
    }
  }
  if node.children[0] != nil {
    node_query_aabb(ot, node.children[0], bounds, res)
    node_query_aabb(ot, node.children[1], bounds, res)
    node_query_aabb(ot, node.children[2], bounds, res)
    node_query_aabb(ot, node.children[3], bounds, res)
    node_query_aabb(ot, node.children[4], bounds, res)
    node_query_aabb(ot, node.children[5], bounds, res)
    node_query_aabb(ot, node.children[6], bounds, res)
    node_query_aabb(ot, node.children[7], bounds, res)
  }
}

@(private)
node_query_aabb_lim :: proc(
  ot: ^Octree($T),
  node: ^Node(T),
  bounds: geom.Aabb,
  res: ^[dynamic]T,
  max_res: int,
) {
  if !geom.aabb_intersects(node.bounds, bounds) do return
  if len(res) >= max_res do return

  for item in node.items {
    if len(res) >= max_res do return
    bounds := ot.bounds_func(item)
    if geom.aabb_intersects(bounds, bounds) {
      append(res, item)
    }
  }
  if node.children[0] != nil {
    for i in 0 ..< 8 {
      if len(res) >= max_res do return
      node_query_aabb_lim(ot, node.children[i], bounds, res, max_res)
    }
  }
}

query_sphere :: proc(ot: ^Octree($T), center: [3]f32, radius: f32, res: ^[dynamic]T) {
  clear(res)
  node_query_sphere(ot, ot.root, center, radius, res)
}

@(private)
node_query_sphere :: proc(ot: ^Octree($T), node: ^Node(T), center: [3]f32, radius: f32, res: ^[dynamic]T) {
  if !geom.aabb_sphere_intersects(node.bounds, center, radius) do return
  for item in node.items {
    if geom.aabb_sphere_intersects(ot.bounds_func(item), center, radius) {
      append(res, item)
    }
  }
  if node.children[0] != nil {
    node_query_sphere(ot, node.children[0], center, radius, res)
    node_query_sphere(ot, node.children[1], center, radius, res)
    node_query_sphere(ot, node.children[2], center, radius, res)
    node_query_sphere(ot, node.children[3], center, radius, res)
    node_query_sphere(ot, node.children[4], center, radius, res)
    node_query_sphere(ot, node.children[5], center, radius, res)
    node_query_sphere(ot, node.children[6], center, radius, res)
    node_query_sphere(ot, node.children[7], center, radius, res)
  }
}

Ray :: struct { origin, direction: [3]f32 }

query_ray :: proc(ot: ^Octree($T), ray: Ray, max_dist: f32, res: ^[dynamic]T) {
  clear(res)
  inv_dir := [3]f32{ 1 / ray.direction.x, 1 / ray.direction.y, 1 / ray.direction.z }

  t_min, t_max := geom.ray_aabb_intersection(ray.origin, inv_dir, ot.root.bounds)
  if t_min > max_dist || t_max < 0 do return
  node_query_ray(ot, ot.root, ray, inv_dir, max(t_min, 0), min(t_max, max_dist), res)
}

@(private)
node_query_ray :: proc(
  ot: ^Octree($T),
  node: ^Node(T),
  ray: Ray,
  inv_dir: [3]f32,
  t_min, t_max: f32,
  res: ^[dynamic]T,
) {
  for item in node.items {
    bounds := ot.bounds_func(item)
    t_near, t_far := geom.ray_aabb_intersection(ray.origin, inv_dir, bounds)
    if t_near <= t_max && t_far >= t_min {
      append(res, item)
    }
  }
  if node.children[0] == nil do return

  intersections: [8]struct {
    idx:   i32,
    t_min: f32,
  }
  valid_count: int
  for i in 0 ..< 8 {
    child_t_min, child_t_max := geom.ray_aabb_intersection(
      ray.origin,
      inv_dir,
      node.children[i].bounds,
    )
    if child_t_min <= t_max && child_t_max >= t_min {
      intersections[valid_count] = {
        idx   = i32(i),
        t_min = max(child_t_min, t_min),
      }
      valid_count += 1
    }
  }
  slice.sort_by(intersections[:valid_count], proc(a, b: struct {
      idx:   i32,
      t_min: f32,
    }) -> bool {
    return a.t_min < b.t_min
  })
  for i in 0 ..< valid_count {
    child_idx := intersections[i].idx
    child_t_min := intersections[i].t_min
    child_t_max := min(
      t_max, geom.ray_aabb_intersection_far(ray.origin, inv_dir, node.children[child_idx].bounds),
    )
    node_query_ray(
      ot,
      node.children[child_idx],
      ray,
      inv_dir,
      child_t_min,
      child_t_max,
      res,
    )
  }
}

remove :: proc(ot: ^Octree($T), item: T) -> bool {
  bounds := ot.bounds_func(item)
  return node_remove(ot, ot.root, item, bounds)
}

@(private)
node_remove :: proc(ot: ^Octree($T), node: ^Node(T), item: T, bounds: geom.Aabb) -> bool {
  if !geom.aabb_intersects(node.bounds, bounds) do return false
  for it, i in node.items {
    if item == it {
      unordered_remove(&node.items, i)
      node.num_items -= 1
      return true
    }
  }
  if node.children[0] != nil {
    for i in 0 ..< 8 {
      if node_remove(ot, node.children[i], item, bounds) {
        node.num_items -= 1
        if should_collapse(node) {
          collapse(node)
        }
        return true
      }
    }
  }
  return false
}

@(private)
should_collapse :: proc(node: ^Node($T)) -> bool {
  if node.children[0] == nil do return false
  // Count total items in all children
  num_items: i32
  for i in 0 ..< 8 {
    if node.children[i] != nil {
      num_items += node.children[i].num_items
    }
  }
  // Add items stored directly in this node
  num_items += i32(len(node.items))
  // Collapse if total items would fit in a single node
  // This helps maintain the octree's efficiency by reducing unnecessary subdivision
  return num_items <= 4  // or use a configurable threshold
}

@(private)
collapse :: proc(node: ^Node($T)) {
  if node.children[0] == nil do return

  // Pre-allocate space for all items using cached count
  reserve(&node.items, int(node.num_items))

  // Collect items from children
  for i in 0 ..< 8 {
    collect(node.children[i], &node.items)
  }
  // Clean up children
  for i in 0 ..< 8 {
    node_deinit(node.children[i])
    free(node.children[i])
    node.children[i] = nil
  }
}

@(private)
collect :: proc(node: ^Node($T), res: ^[dynamic]T) {
  if node == nil do return

  for item in node.items {
    append(res, item)
  }
  if node.children[0] != nil {
    for i in 0 ..< 8 {
      collect(node.children[i], res)
    }
  }
}

collect_all :: proc(node: ^Node($T), res: ^[dynamic]T) {
  if node == nil do return
  for item in node.items {
    append(res, item)
  }
  if node.children[0] != nil {
    for i in 0 ..< 8 {
      collect_all(node.children[i], res)
    }
  }
}

update :: proc(ot: ^Octree($T), old_item, new_item: T) -> bool {
  old := ot.bounds_func(old_item)
  new_bounds := ot.bounds_func(new_item)
  if geom.aabb_contains(old, new_bounds) && geom.aabb_contains(new_bounds, old) {
    return true
  }
  if node_remove(ot, ot.root,old_item, old) {
    return insert(ot, new_item)
  }
  return false
}

Stats :: struct {
  num_nodes,
  leaf_nodes,
  max_depth,
  num_items,
  max_items_node,
  empty_nodes:    i32,
}

get_stats :: proc(ot: ^Octree($T)) -> Stats {
  s: Stats
  if ot.root != nil {
    calc_stats(ot.root, &s, 0)
  }
  return s
}

@(private)
calc_stats :: proc(node: ^Node($T), s: ^Stats, depth: i32) {
  s.num_nodes += 1
  s.num_items += i32(len(node.items))
  s.max_depth = s.max_depth > depth ? s.max_depth : depth
  s.max_items_node =
    s.max_items_node > i32(len(node.items)) ? s.max_items_node : i32(len(node.items))

  if node.children[0] == nil {
    s.leaf_nodes += 1
    if len(node.items) == 0 do s.empty_nodes += 1
  } else {
    for i in 0 ..< 8 {
      calc_stats(node.children[i], s, depth + 1)
    }
  }
}