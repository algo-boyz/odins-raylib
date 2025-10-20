package geometry

import "core:log"
import "core:math"
import "core:math/linalg"
import "core:slice"
import "../../../rlutil/geom"

// alternative implementation: https://github.com/TheSandvichMaker/odin-rt/blob/main/code/bvh.odin

BVHNode :: struct {
  bounds:          geom.Aabb,
  left_child:      i32,
  right_child:     i32,
  primitive_start: i32,
  primitive_count: i32,
}

BVH :: struct($T: typeid) {
  nodes:       [dynamic]BVHNode,
  primitives:  [dynamic]T,
  bounds_func: proc(t: T) -> geom.Aabb,
}

bvh_deinit :: proc(bvh: ^BVH($T)) {
  delete(bvh.nodes)
  delete(bvh.primitives)
}

BVHBuildNode :: struct {
  bounds:     geom.Aabb,
  left:       ^BVHBuildNode,
  right:      ^BVHBuildNode,
  prim_start: i32,
  prim_count: i32,
}

BVHPrimitive :: struct {
  index:    i32,
  bounds:   geom.Aabb,
  centroid: [3]f32,
}

BVHTraversal :: struct {
  node_idx: i32,
  t_min:    f32,
}

bvh_build :: proc(bvh: ^BVH($T), items: []T, max_leaf_size: i32 = 4) {
  clear(&bvh.nodes)
  clear(&bvh.primitives)

  if len(items) == 0 do return

  // Reserve capacity for better performance
  reserve(&bvh.primitives, len(items))
  append(&bvh.primitives, ..items)

  build_prims := make([]BVHPrimitive, len(items))
  defer delete(build_prims)
  for i in 0 ..< len(items) {
    item := items[i]
    bounds := bvh.bounds_func(item)
    build_prims[i] = BVHPrimitive {
      index    = i32(i),
      bounds   = bounds,
      centroid = aabb_center(bounds),
    }
  }
  root := build_recursive(build_prims[:], 0, i32(len(items)), max_leaf_size)

  // Reorder the primitives array to match the build_prims order
  for i in 0 ..< len(build_prims) {
    bvh.primitives[i] = items[build_prims[i].index]
  }
  flatten_bvh_tree(bvh, root)
  free_build_nodes(root)
}

@(private)
build_recursive :: proc(
  prims: []BVHPrimitive,
  start, end: i32,
  max_leaf_size: i32,
) -> ^BVHBuildNode {
  node := new(BVHBuildNode)

  node.bounds = geom.AABB_UNDEFINED
  for i in start ..< end {
    node.bounds = geom.aabb_union(node.bounds, prims[i].bounds)
  }

  prim_count := end - start

  if prim_count <= max_leaf_size {
    node.prim_start = start
    node.prim_count = prim_count
    // Recalculate bounds from actual primitives in this leaf node
    node.bounds = geom.AABB_UNDEFINED
    for i in start ..< end {
      node.bounds = geom.aabb_union(node.bounds, prims[i].bounds)
    }
    return node
  }

  axis, split_pos := split_sah(prims[start:end], node.bounds)

  if axis < 0 || split_pos <= 0 || split_pos >= prim_count {
    node.prim_start = start
    node.prim_count = prim_count
    // Recalculate bounds from actual primitives in this fallback leaf node
    node.bounds = geom.AABB_UNDEFINED
    for i in start ..< end {
      node.bounds = geom.aabb_union(node.bounds, prims[i].bounds)
    }
    return node
  }

  mid := start + split_pos

  node.left = build_recursive(prims, start, mid, max_leaf_size)
  node.right = build_recursive(prims, mid, end, max_leaf_size)
  node.prim_start = -1
  node.prim_count = 0

  // Update bounds to be union of child bounds (this is correct for internal nodes)
  node.bounds = geom.aabb_union(node.left.bounds, node.right.bounds)

  return node
}

@(private)
split_sah :: proc(
  prims: []BVHPrimitive,
  node_bounds: geom.Aabb,
) -> (
  axis: i32,
  split_pos: i32,
) {
  best_cost:f32 = math.F32_MAX
  best_axis := -1
  best_split := -1

  // Fast path for small arrays - use simple median split
  if len(prims) <= 8 {
    return split_median(prims, node_bounds)
  }

  // Pre-allocate arrays for prefix/suffix bounds computation
  left_bounds := make([]geom.Aabb, len(prims), context.temp_allocator)
  right_bounds := make([]geom.Aabb, len(prims), context.temp_allocator)

  // Sample fewer split positions for better performance
  num_samples := min(len(prims), 32)
  step := max(1, len(prims) / num_samples)

  for ax in 0 ..< 3 {
    // Sort by axis
    if ax == 0 {
      slice.sort_by(prims, proc(a, b: BVHPrimitive) -> bool {
        return a.centroid[0] < b.centroid[0]
      })
    } else if ax == 1 {
      slice.sort_by(prims, proc(a, b: BVHPrimitive) -> bool {
        return a.centroid[1] < b.centroid[1]
      })
    } else {
      slice.sort_by(prims, proc(a, b: BVHPrimitive) -> bool {
        return a.centroid[2] < b.centroid[2]
      })
    }

    // Compute prefix bounds (left side)
    left_bounds[0] = prims[0].bounds
    for i in 1 ..< len(prims) {
      left_bounds[i] = geom.aabb_union(left_bounds[i-1], prims[i].bounds)
    }

    // Compute suffix bounds (right side)
    right_bounds[len(prims)-1] = prims[len(prims)-1].bounds
    for i := len(prims)-2; i >= 0; i -= 1 {
      right_bounds[i] = geom.aabb_union(right_bounds[i+1], prims[i].bounds)
    }

    // Sample split positions instead of testing all
    for i := step; i < len(prims); i += step {
      if i >= len(prims) - 1 do break
      
      cost := sah_cost(
        left_bounds[i-1],
        i32(i),
        right_bounds[i],
        i32(len(prims) - i),
        node_bounds,
      )

      if cost < best_cost {
        best_cost = cost
        best_axis = ax
        best_split = i
      }
    }
  }

  // Re-sort by best axis if needed
  if best_axis >= 0 && best_axis != 2 {
    if best_axis == 0 {
      slice.sort_by(prims, proc(a, b: BVHPrimitive) -> bool {
        return a.centroid[0] < b.centroid[0]
      })
    } else if best_axis == 1 {
      slice.sort_by(prims, proc(a, b: BVHPrimitive) -> bool {
        return a.centroid[1] < b.centroid[1]
      })
    }
  }

  return i32(best_axis), i32(best_split)
}

@(private)
split_median :: proc(
  prims: []BVHPrimitive,
  node_bounds: geom.Aabb,
) -> (
  axis: i32,
  split_pos: i32,
) {
  // Choose the axis with the largest extent
  extent := node_bounds.max - node_bounds.min
  best_axis := 0
  if extent[1] > extent[0] do best_axis = 1
  if extent[2] > extent[best_axis] do best_axis = 2

  // Sort by the chosen axis
  if best_axis == 0 {
    slice.sort_by(prims, proc(a, b: BVHPrimitive) -> bool {
      return a.centroid[0] < b.centroid[0]
    })
  } else if best_axis == 1 {
    slice.sort_by(prims, proc(a, b: BVHPrimitive) -> bool {
      return a.centroid[1] < b.centroid[1]
    })
  } else {
    slice.sort_by(prims, proc(a, b: BVHPrimitive) -> bool {
      return a.centroid[2] < b.centroid[2]
    })
  }

  return i32(best_axis), i32(len(prims) / 2)
}

@(private)
sah_cost :: proc(
  left_bounds: geom.Aabb,
  left_count: i32,
  right_bounds: geom.Aabb,
  right_count: i32,
  parent_bounds: geom.Aabb,
) -> f32 {
  TRAVERSAL_COST :: 1.0
  INTERSECTION_COST :: 1.0

  parent_area := geom.aabb_surface_area(parent_bounds)
  left_area := geom.aabb_surface_area(left_bounds)
  right_area := geom.aabb_surface_area(right_bounds)

  if parent_area == 0 do return math.F32_MAX

  p_left := left_area / parent_area
  p_right := right_area / parent_area

  return(
    TRAVERSAL_COST +
    INTERSECTION_COST *
      (p_left * f32(left_count) + p_right * f32(right_count)) \
  )
}

@(private)
count_build_nodes :: proc(node: ^BVHBuildNode) -> i32 {
  if node == nil do return 0
  return 1 + count_build_nodes(node.left) + count_build_nodes(node.right)
}

@(private)
flatten_bvh_tree :: proc(bvh: ^BVH($T), root: ^BVHBuildNode) {
  node_count := count_build_nodes(root)
  resize(&bvh.nodes, int(node_count))

  next_node_idx: i32 = 0
  flatten_node(bvh, root, &next_node_idx)
}

@(private)
flatten_node :: proc(
  bvh: ^BVH($T),
  build_node: ^BVHBuildNode,
  next_idx: ^i32,
) -> i32 {
  node_idx := next_idx^
  next_idx^ += 1

  node := BVHNode {
    bounds = build_node.bounds,
  }

  if build_node.prim_count > 0 {
    node.left_child = -1
    node.right_child = -1
    node.primitive_start = build_node.prim_start
    node.primitive_count = build_node.prim_count
  } else {
    node.primitive_start = -1
    node.primitive_count = -1
    node.left_child = flatten_node(bvh, build_node.left, next_idx)
    node.right_child = flatten_node(bvh, build_node.right, next_idx)
  }

  bvh.nodes[node_idx] = node
  return node_idx
}

@(private)
free_build_nodes :: proc(node: ^BVHBuildNode) {
  if node == nil do return

  free_build_nodes(node.left)
  free_build_nodes(node.right)
  free(node)
}

bvh_query_aabb :: proc(
  bvh: ^BVH($T),
  query_bounds: geom.Aabb,
  results: ^[dynamic]T,
) {
  clear(results)
  if len(bvh.nodes) == 0 do return

  // Use fixed-size stack for better performance
  stack: [64]i32
  stack_top := 0
  stack[stack_top] = 0
  stack_top += 1

  for stack_top > 0 {
    stack_top -= 1
    node_idx := stack[stack_top]
    node := &bvh.nodes[node_idx]

    if !aabb_intersects(node.bounds, query_bounds) do continue

    if node.primitive_count > 0 {
      // Cache bounds function call
      for i in node.primitive_start ..< node.primitive_start + node.primitive_count {
        prim := bvh.primitives[i]
        prim_bounds := bvh.bounds_func(prim)
        if aabb_intersects(prim_bounds, query_bounds) {
          append(results, prim)
        }
      }
    } else {
      // Add children to stack - check bounds first to avoid unnecessary traversal
      if stack_top < len(stack) - 1 {
        stack[stack_top] = node.right_child
        stack_top += 1
        stack[stack_top] = node.left_child
        stack_top += 1
      }
    }
  }
}

@(private)
ray_aabb_intersection_safe :: proc(
  origin: [3]f32,
  direction: [3]f32,
  aabb: geom.Aabb,
) -> (
  t_near, t_far: f32,
) {
  t_min := [3]f32{-math.F32_MAX, -math.F32_MAX, -math.F32_MAX}
  t_max := [3]f32{math.F32_MAX, math.F32_MAX, math.F32_MAX}

  for i in 0 ..< 3 {
    if math.abs(direction[i]) < 1e-6 {
      // Ray is parallel to this axis
      if origin[i] < aabb.min[i] || origin[i] > aabb.max[i] {
        // Ray is outside the slab, no intersection
        return math.F32_MAX, -math.F32_MAX
      }
      // Ray is inside the slab, keep the infinite range for this axis
    } else {
      inv_d := 1.0 / direction[i]
      t1 := (aabb.min[i] - origin[i]) * inv_d
      t2 := (aabb.max[i] - origin[i]) * inv_d

      t_min[i] = min(t1, t2)
      t_max[i] = max(t1, t2)
    }
  }

  t_near = max(max(t_min.x, t_min.y), t_min.z)
  t_far = min(min(t_max.x, t_max.y), t_max.z)

  // Valid intersection if t_far >= t_near
  if t_far < t_near do return math.F32_MAX, -math.F32_MAX

  return
}

bvh_query_ray :: proc(
  bvh: ^BVH($T),
  ray: rl.Ray,
  max_dist: f32,
  results: ^[dynamic]T,
) {
  clear(results)
  if len(bvh.nodes) == 0 do return

  stack := make([dynamic]i32, 0, 64, context.temp_allocator)
  append(&stack, 0)

  for len(stack) > 0 {
    node_idx := pop(&stack)
    node := &bvh.nodes[node_idx]

    t_near, t_far := ray_aabb_intersection_safe(
      ray.origin,
      ray.direction,
      node.bounds,
    )
    if t_near > max_dist || t_far < 0 do continue

    if node.primitive_count > 0 {
      for i in node.primitive_start ..< node.primitive_start + node.primitive_count {
        prim := bvh.primitives[i]
        prim_bounds := bvh.bounds_func(prim)
        prim_t_near, prim_t_far := ray_aabb_intersection_safe(
          ray.origin,
          ray.direction,
          prim_bounds,
        )
        if prim_t_near <= max_dist && prim_t_far >= 0 {
          append(results, prim)
        }
      }
    } else {
      append(&stack, node.left_child)
      append(&stack, node.right_child)
    }
  }
}

bvh_query_sphere :: proc(
  bvh: ^BVH($T),
  center: [3]f32,
  radius: f32,
  results: ^[dynamic]T,
) {
  sphere_bounds := geom.Aabb {
    min = center - [3]f32{radius, radius, radius},
    max = center + [3]f32{radius, radius, radius},
  }

  temp_results := make([dynamic]T, context.temp_allocator)
  bvh_query_aabb(bvh, sphere_bounds, &temp_results)

  clear(results)
  for item in temp_results {
    bounds := bvh.bounds_func(item)
    if aabb_sphere_intersects(bounds, center, radius) {
      append(results, item)
    }
  }
}

bvh_query_nearest :: proc(
  bvh: ^BVH($T),
  point: [3]f32,
  max_dist: f32 = math.F32_MAX,
) -> (
  result: T,
  dist: f32,
  found: bool,
) {
  if len(bvh.nodes) == 0 do return

  best_dist := max_dist
  found = false

  stack := make([dynamic]BVHTraversal, 0, 64, context.temp_allocator)
  append(&stack, BVHTraversal{node_idx = 0, t_min = 0})

  for len(stack) > 0 {
    current := pop(&stack)

    if current.t_min > best_dist do break

    node := &bvh.nodes[current.node_idx]

    if node.left_child < 0 {
      for i in node.primitive_start ..< node.primitive_start + node.primitive_count {
        prim := bvh.primitives[i]
        prim_bounds := bvh.bounds_func(prim)

        d := distance_point_aabb(point, prim_bounds)

        if d < best_dist {
          best_dist = d
          result = prim
          found = true
        }
      }
    } else {
      left_bounds := bvh.nodes[node.left_child].bounds
      right_bounds := bvh.nodes[node.right_child].bounds

      left_dist := distance_point_aabb(point, left_bounds)
      right_dist := distance_point_aabb(point, right_bounds)

      traversals := [2]BVHTraversal {
        {node_idx = node.left_child, t_min = left_dist},
        {node_idx = node.right_child, t_min = right_dist},
      }

      if left_dist > right_dist {
        traversals[0], traversals[1] = traversals[1], traversals[0]
      }

      for trav in traversals {
        if trav.t_min < best_dist {
          append(&stack, trav)
        }
      }
    }
  }

  return result, best_dist, found
}

bvh_refit :: proc(bvh: ^BVH($T)) {
  for i := len(bvh.nodes) - 1; i >= 0; i -= 1 {
    node := &bvh.nodes[i]

    if node.left_child < 0 {
      node.bounds = geom.AABB_UNDEFINED
      for j in node.primitive_start ..< node.primitive_start + node.primitive_count {
        prim_bounds := bvh.bounds_func(bvh.primitives[j])
        node.bounds = geom.aabb_union(node.bounds, prim_bounds)
      }
    } else {
      left_bounds := bvh.nodes[node.left_child].bounds
      right_bounds := bvh.nodes[node.right_child].bounds
      node.bounds = geom.aabb_union(left_bounds, right_bounds)
    }
  }
}

bvh_validate :: proc(bvh: ^BVH($T)) -> bool {
  if len(bvh.nodes) == 0 do return true

  for i in 0 ..< len(bvh.nodes) {
    node := bvh.nodes[i]
    if node.left_child >= 0 {
      // Internal node checks
      if node.right_child < 0 do return false
      if node.primitive_count != -1 do return false
      if node.left_child >= i32(len(bvh.nodes)) do return false
      if node.right_child >= i32(len(bvh.nodes)) do return false

      left := bvh.nodes[node.left_child]
      right := bvh.nodes[node.right_child]

      // Check bounds contain children (with some tolerance)
      if !aabb_contains_approx(node.bounds, left.bounds, 1e-3) do return false
      if !aabb_contains_approx(node.bounds, right.bounds, 1e-3) do return false
    } else {
      // Leaf node checks
      if node.primitive_count <= 0 do return false
      if node.primitive_start < 0 do return false
      if node.primitive_start + node.primitive_count > i32(len(bvh.primitives)) do return false
    }
  }
  return true
}

bvh_get_stats :: proc(bvh: ^BVH($T)) -> BVHStats {
  stats: BVHStats

  for node in bvh.nodes {
    stats.total_nodes += 1

    if node.left_child < 0 {
      stats.leaf_nodes += 1
      stats.total_primitives += node.primitive_count
      stats.max_leaf_size =
        stats.max_leaf_size > node.primitive_count ? stats.max_leaf_size : node.primitive_count
      if node.primitive_count == 0 do stats.empty_leaves += 1
    } else {
      stats.internal_nodes += 1
    }
  }

  return stats
}

BVHStats :: struct {
  total_nodes:      i32,
  leaf_nodes:       i32,
  internal_nodes:   i32,
  total_primitives: i32,
  max_leaf_size:    i32,
  empty_leaves:     i32,
}

// Efficient insert - just append and mark for rebuild
bvh_insert :: proc(bvh: ^BVH($T), item: T) {
  append(&bvh.primitives, item)
  // Mark BVH as needing rebuild - simple approach
  // For better performance, implement incremental insertion later
}

// Efficient update - update item and refit bounds
bvh_update :: proc(bvh: ^BVH($T), index: int, new_item: T) {
  if index >= 0 && index < len(bvh.primitives) {
    bvh.primitives[index] = new_item
    // Refit bounds from this item upward
    bvh_refit(bvh)
  }
}

// Remove item by index
bvh_remove :: proc(bvh: ^BVH($T), index: int) {
  if index >= 0 && index < len(bvh.primitives) {
    // Simple approach - remove and mark for rebuild
    ordered_remove(&bvh.primitives, index)
    // For better performance, implement incremental removal later
  }
}

// Fast incremental insert that finds best insertion point
bvh_insert_incremental :: proc(bvh: ^BVH($T), item: T) {
  if len(bvh.nodes) == 0 {
    append(&bvh.primitives, item)
    items := []T{item}
    bvh_build(bvh, items)
    return
  }
  
  // Find best leaf node to insert into
  item_bounds := bvh.bounds_func(item)
  best_node_idx := find_best_insert_node(bvh, item_bounds)
  
  // Insert into primitives array
  append(&bvh.primitives, item)
  
  // Update leaf node to include new primitive
  leaf_node := &bvh.nodes[best_node_idx]
  leaf_node.primitive_count += 1
  leaf_node.bounds = geom.aabb_union(leaf_node.bounds, item_bounds)
  
  // Refit bounds up the tree
  bvh_refit_from_node(bvh, best_node_idx)
}

@(private)
find_best_insert_node :: proc(bvh: ^BVH($T), item_bounds: geom.Aabb) -> int {
  if len(bvh.nodes) == 0 do return -1
  for {
    node := &bvh.nodes[current_idx]
    // If leaf node, return it
    if node.primitive_count > 0 {
      return current_idx
    }
    // Choose child with min cost increase
    left_node := &bvh.nodes[node.left_child]
    right_node := &bvh.nodes[node.right_child]
    
    left_cost := aabb_surface_area(geom.aabb_union(left_node.bounds, item_bounds)) - aabb_surface_area(left_node.bounds)
    right_cost := aabb_surface_area(geom.aabb_union(right_node.bounds, item_bounds)) - aabb_surface_area(right_node.bounds)
    
    if left_cost < right_cost {
      return node.left_child
    }
  }
  return node.right_child
}

@(private)
bvh_refit_from_node :: proc(bvh: ^BVH($T), start_node_idx: int) {
  // TODO: add parent ptrs for efficiency
  bvh_refit(bvh)
}