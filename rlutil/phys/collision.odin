// Port of some collision functions to Odin by Jakub Tomšů: https://gist.github.com/jakubtomsu/2acd84731d3c2613c91e40c2e064ffe6
//
// from Real-Time Collision Detection by Christer Ericson, published by Morgan Kaufmann Publishers, © 2005 Elsevier Inc
//
// This should serve as an reference implementation for common collision queries for games.
// The goal is good numerical robustness, handling edge cases and optimized math equations.
// The code isn't necessarily very optimized.
//
// There are a few cases you don't want to use the procedures below directly, but instead manually inline the math and adapt it to your needs.
// In my experience this method is clearer when writing complex level queries where I need to handle edge cases differently etc.
package phys

import "core:math"
import "core:math/linalg"

Vec3 :: [3]f32

sqrt :: math.sqrt

dot :: linalg.dot
cross :: linalg.cross
length2 :: linalg.vector_length2

Aabb :: struct {
    min: Vec3,
    max: Vec3,
}

// Infinitely small
AABB_INVALID :: Aabb {
    min = 1e20,
    max = -1e20,
}

Sphere :: struct {
    pos: Vec3,
    rad: f32,
}

// Radius is the half size
Box :: struct {
    pos: Vec3,
    rad: Vec3,
}

Plane :: struct {
    normal: Vec3,
    dist:   f32,
}

Capsule :: struct {
    a:   Vec3,
    b:   Vec3,
    rad: f32,
}

// Same layout, slightly different meaning
Cylinder :: distinct Capsule


aabb_center :: proc(a: Aabb) -> Vec3 {
    return (a.min + a.max) * 0.5
}

aabb_half_size :: proc(a: Aabb) -> Vec3 {
    return (a.max - a.min) * 0.5
}

aabb_to_box :: proc(a: Aabb) -> Box {
    center := aabb_center(a)
    return {pos = center, rad = a.max - center}
}

box_to_aabb :: proc(a: Box) -> Aabb {
    return {min = a.pos - a.rad, max = a.pos + a.rad}
}

plane_from_point_normal :: proc(point: Vec3, normal: Vec3) -> Plane {
    return {normal = normal, dist = dot(point, normal)}
}



//////////////////////////////////////////////////////////////////////////////////
// Distance to closest point
//

signed_distance_plane :: proc(point: Vec3, plane: Plane) -> f32 {
    // If plane equation normalized (||p.n||==1)
    return dot(point, plane.normal) - plane.dist
    // If not normalized
    // return (dot(plane.normal, point) - plane.dist) / Ddt(plane.normal, plane.normal);
}

squared_distance_aabb :: proc(point: Vec3, aabb: Aabb) -> (dist: f32) {
    for i in 0 ..< 3 {
        // For each axis count any excess distance outside box extents
        if point[i] < aabb.min[i] do dist += (aabb.min[i] - point[i]) * (aabb.min[i] - point[i])
        if point[i] > aabb.max[i] do dist += (point[i] - aabb.max[i]) * (point[i] - aabb.max[i])
    }
    return dist
}

// Returns the squared distance between point and segment ab
squared_distance_segment :: proc(point, a, b: Vec3) -> f32 {
    ab := b - a
    ac := point - a
    bc := point - b
    e := dot(ac, ab)
    // Handle cases where c projects outside ab
    if e <= 0.0 {
        return dot(ac, ac)
    }
    f := dot(ab, ab)
    if e >= f {
        return dot(bc, bc)
    }
    // Handle cases where c projects onto ab
    return dot(ac, ac) - e * e / f
}



//////////////////////////////////////////////////////////////////////////////////
// Closest point
//

closest_point_plane :: proc(point: Vec3, plane: Plane) -> Vec3 {
    t := dot(plane.normal, point) - plane.dist
    return point - t * plane.normal
}

closest_point_aabb :: proc(point: Vec3, aabb: Aabb) -> Vec3 {
    return {
        clamp(point.x, aabb.min.x, aabb.max.x),
        clamp(point.y, aabb.min.y, aabb.max.y),
        clamp(point.z, aabb.min.z, aabb.max.z),
    }
}

// Given segment ab and point c, computes closest point d on ab.
// Also returns t for the position of d, d(t)=a+ t*(b - a)
closest_point_segment :: proc(pos, a, b: Vec3) -> (t: f32, point: Vec3) {
    ab := b - a
    // Project pos onto ab, computing parameterized position d(t)=a+ t*(b – a)
    t = dot(pos - a, ab) / dot(ab, ab)
    t = clamp(t, 0, 1)
    // Compute projected position from the clamped t
    point = a + t * ab
    return t, point
}

// Computes closest points C1 and C2 of S1(s)=P1+s*(Q1-P1) and
// S2(t)=P2+t*(Q2-P2), returning s and t. Function result is squared
// distance between between S1(s) and S2(t)
// TODO: [2]Vec3
closest_point_between_segments :: proc(p1, q1, p2, q2: Vec3) -> (t: [2]f32, points: [2]Vec3) {
    d1 := q1 - p1 // Direction vector of segment S1
    d2 := q2 - p2 // Direction vector of segment S2
    r := p1 - p2
    a := dot(d1, d1) // Squared length of segment S1, always nonnegative
    e := dot(d2, d2) // Squared length of segment S2, always nonnegative
    f := dot(d2, r)

    EPS :: 1e-6

    // Check if either or both segments degenerate into points
    if a <= EPS && e <= EPS {
        // Both segments degenerate into points
        t = 0
        points = {p1, p2}
        return t, points
    }
    if a <= EPS {
        // First segment degenerates into a point
        t[0] = 0
        t[1] = clamp(f / e, 0, 1) // s = 0 => t = (b*s + f) / e = f / e
    } else {
        c := dot(d1, r)
        if e <= EPS {
            // Second segment degenerates into a point
            t[1] = 0
            t[0] = clamp(-c / a, 0, 1) // t = 0 => s = (b*t - c) / a = -c / a
        } else {
            // The general nondegenerate case starts here
            b := dot(d1, d2)
            denom := a * e - b * b // Always nonnegative

            // If segments not parallel, compute closest point on L1 to L2 and
            // clamp to segment S1. Else pick arbitrary s (here 0)
            if denom != 0.0 {
                t[0] = clamp((b * f - c * e) / denom, 0, 1)
            } else {
                t[0] = 0
            }
            // Compute point on L2 closest to S1(s) using
            // t = Dot((P1 + D1*s) - P2,D2) / Dot(D2,D2) = (b*s + f) / e
            tnom := (b * t[0] + f) / e

            // If t in [0,1] done. Else clamp t, recompute s for the new value
            // of t using s = Dot((P2 + D2*t) - P1,D1) / Dot(D1,D1)= (t*b - c) / a
            // and clamp s to [0, 1]
            if tnom < 0 {
                t[1] = 0
                t[0] = clamp(-c / a, 0, e)
            } else if tnom > 1 {
                t[1] = 1
                t[0] = clamp((b - c) / a, 0, e)
            } else {
                t[1] = tnom / e
            }
        }
    }

    points[0] = p1 + d1 * t[0]
    points[1] = p2 + d2 * t[1]
    return t, points
}

closest_point_triangle :: proc(point, a, b, c: Vec3) -> Vec3 {
    ab := b - a
    ac := c - a
    ap := point - a
    d1 := dot(ab, ap)
    d2 := dot(ac, ap)
    if d1 <= 0 && d2 <= 0 do return a // barycentric coordinates (1,0,0)

    // Check if P in vertex region outside B
    bp := point - b
    d3 := dot(ab, bp)
    d4 := dot(ac, bp)
    if d3 >= 0 && d4 <= d3 do return b // barycentric coordinates (0,1,0)

    // Check if P in edge region of AB, if so return projection of P onto AB
    vc := d1 * d4 - d3 * d2
    if vc < 0 && d1 >= 0 && d3 <= 0 {
        v := d1 / (d1 - d3)
        return a + v * ab // barycentric coordinates (1-v,v,0)
    }

    // Check if P in vertex region outside C
    cp := point - c
    d5 := dot(ab, cp)
    d6 := dot(ac, cp)
    if d6 >= 0 && d5 <= d6 do return c // barycentric coordinates (0,0,1)

    // Check if P in edge region of AC, if so return projection of P onto AC
    vb := d5 * d2 - d1 * d6
    if vb <= 0 && d2 >= 0 && d6 <= 0 {
        w := d2 / (d2 - d6)
        return a + w * ac // barycentric coordinates (1-w,0,w)
    }

    // Check if P in edge region of BC, if so return projection of P onto BC
    va := d3 * d6 - d5 * d4
    if va <= 0 && (d4 - d3) >= 0 && (d5 - d6) >= 0 {
        w := (d4 - d3) / ((d4 - d3) + (d5 - d6))
        return b + w * (c - b) // barycentric coordinates (0,1-w,w)
    }

    // P inside face region. Compute Q through its barycentric coordinates (u,v,w)
    denom := 1.0 / (va + vb + vc)
    v := vb * denom
    w := vc * denom
    return a + ab * v + ac * w // = u*a + v*b + w*c, u = va * denom = 1.0f-v-w
}



//////////////////////////////////////////////////////////////////////////////////
// Tests
//

test_aabb_vs_aabb :: proc(a, b: Aabb) -> bool {
    // Exit with no intersection if separated along an axis
    if a.max[0] < b.min[0] || a.min[0] > b.max[0] do return false
    if a.max[1] < b.min[1] || a.min[1] > b.max[1] do return false
    if a.max[2] < b.min[2] || a.min[2] > b.max[2] do return false
    // Overlapping on all axes means AABBs are intersecting
    return true
}

test_sphere_vs_aabb :: proc(sphere: Sphere, aabb: Aabb) -> bool {
    s := squared_distance_aabb(sphere.pos, aabb)
    return s <= sphere.rad * sphere.rad
}

test_sphere_vs_plane :: proc(sphere: Sphere, plane: Plane) -> bool {
    dist := signed_distance_plane(sphere.pos, plane)
    return abs(dist) <= sphere.rad
}

test_point_vs_halfspace :: proc(pos: Vec3, plane: Plane) -> bool {
    return signed_distance_plane(pos, plane) <= 0.0
}

test_sphere_vs_halfspace :: proc(sphere: Sphere, plane: Plane) -> bool {
    dist := signed_distance_plane(sphere.pos, plane)
    return dist <= sphere.rad
}

test_box_vs_plane :: proc(box: Box, plane: Plane) -> bool {
    // Compute the projection interval radius of b onto L(t) = b.c + t * p.n
    r := box.rad.x * abs(plane.normal.x) + box.rad.y * abs(plane.normal.y) + box.rad.z * abs(plane.normal.z)
    s := signed_distance_plane(box.pos, plane)
    return abs(s) <= r
}

test_capsule_vs_capsule :: proc(a, b: Capsule) -> bool {
    // Compute (squared) distance between the inner structures of the capsules
    _, points := closest_point_between_segments(a.a, a.b, b.a, b.b)
    squared_dist := length2(points[1] - points[0])
    // If (squared) distance smaller than (squared) sum of radii, they collide
    rad := a.rad + b.rad
    return squared_dist <= rad * rad
}

test_sphere_vs_capsule :: proc(sphere: Sphere, capsule: Capsule) -> bool {
    // Compute (squared) distance between sphere center and capsule line segment
    dist2 := squared_distance_segment(point = sphere.pos, a = capsule.a, b = capsule.b)
    // If (squared) distance smaller than (squared) sum of radii, they collide
    rad := sphere.rad + capsule.rad
    return dist2 <= rad * rad
}

test_capsule_vs_plane :: proc(capsule: Capsule, plane: Plane) -> bool {
    adist := dot(capsule.a, plane.normal) - plane.dist
    bdist := dot(capsule.b, plane.normal) - plane.dist
    // Intersects if on different sides of plane (distances have different signs)
    if adist * bdist < 0.0 do return true
    // Intersects if start or end position within radius from plane
    if abs(adist) <= capsule.rad || abs(bdist) <= capsule.rad do return true
    return false
}

test_capsule_vs_halfspace :: proc(capsule: Capsule, plane: Plane) -> bool {
    adist := dot(capsule.a, plane.normal) - plane.dist
    bdist := dot(capsule.b, plane.normal) - plane.dist
    return min(adist, bdist) <= capsule.rad
}

test_ray_sphere :: proc(pos, dir: Vec3, sphere: Sphere) -> bool {
    m := pos - sphere.pos
    c := dot(m, m) - sphere.rad * sphere.rad
    // If there is definitely at least one real root, there must be an intersection
    if c <= 0 do return true
    b := dot(m, dir)
    // Early exit if ray origin outside sphere and ray pointing away from sphere
    if b > 0 do return false
    discr := b * b - c
    // A negative discriminant corresponds to ray missing sphere
    return discr >= 0
}

test_point_polyhedron :: proc(pos: Vec3, planes: []Plane) -> bool {
    for plane in planes {
        if signed_distance_plane(pos, plane) > 0.0 {
            return false
        }
    }
    return true
}

// Intersections
// Given planes a and b, compute line L = p+t*d of their intersection.
intersect_planes :: proc(a, b: Plane) -> (point, dir: Vec3, ok: bool) {
    // Compute direction of intersection line
    dir = cross(a.normal, b.normal)
    // If d is (near) zero, the planes are parallel (and separated)
    // or coincident, so they’re not considered intersecting
    denom := dot(dir, dir)
    EPS :: 1e-6
    if denom < EPS do return {}, dir, false
    // Compute point on intersection line
    point = cross(a.dist * b.normal - b.dist * a.normal, dir) / denom
    return point, dir, true
}

// TODO: moving vs static
intersect_moving_spheres :: proc(a, b: Sphere, vel_a, vel_b: Vec3) -> (t: f32, ok: bool) {
    s := b.pos - a.pos
    v := vel_b - vel_a // Relative motion of s1 with respect to stationary s0
    r := a.rad + b.rad
    c := dot(s, s) - r * r
    if c < 0 {
        // Spheres initially overlapping so exit directly
        return 0, true
    }
    a := dot(v, v)
    EPS :: 1e-6
    if a < EPS {
        return 1, false // Spheres not moving relative each other
    }
    b := dot(v, s)
    if b >= 0 {
        return 1, false // Spheres not moving towards each other
    }
    d := b * b - a * c
    if d < 0 {
        return 1, false // No real-valued root, spheres do not intersect
    }
    t = (-b - sqrt(d)) / a
    return t, true
}

intersect_moving_aabbs :: proc(a, b: Aabb, vel_a, vel_b: Vec3) -> (t: [2]f32, ok: bool) {
    // Use relative velocity; effectively treating ’a’ as stationary
    return intersect_static_aabb_vs_moving_aabb(a, b, vel_relative = vel_b - vel_a)
}

// 'a' is static, 'b' is moving
intersect_static_aabb_vs_moving_aabb :: proc(a, b: Aabb, vel_relative: Vec3) -> (t: [2]f32, ok: bool) {
    // Exit early if ‘a’ and ‘b’ initially overlapping
    if test_aabb_vs_aabb(a, b) {
        return 0, true
    }

    // Initialize ts of first and last contact
    t = {0, 1}

    // For each axis, determine ts of first and last contact, if any
    for i in 0 ..< 3 {
        if vel_relative[i] < 0.0 {
            if b.max[i] < a.min[i] do return 1, false // Nonintersecting and moving apart
            if a.max[i] < b.min[i] do t[0] = max(t[0], (a.max[i] - b.min[i]) / vel_relative[i])
            if b.max[i] > a.min[i] do t[1] = min(t[1], (a.min[i] - b.max[i]) / vel_relative[i])
        }

        if vel_relative[i] > 0.0 {
            if b.min[i] > a.max[i] do return 1, false // Nonintersecting and moving apart
            if b.max[i] < a.min[i] do t[0] = max(t[0], (a.min[i] - b.max[i]) / vel_relative[i])
            if a.max[i] > b.min[i] do t[1] = min(t[1], (a.max[i] - b.min[i]) / vel_relative[i])
        }

        // No overlap possible if t of first contact occurs after t of last contact
        if t[0] > t[1] do return 1, false
    }

    return t, true
}

// Intersect sphere s with movement vector v with plane p. If intersecting
// return t t of collision and point at which sphere hits plane
intersect_moving_sphere_vs_plane :: proc(sphere: Sphere, vel: Vec3, plane: Plane) -> (t: f32, point: Vec3, ok: bool) {
    // Compute distance of sphere center to plane
    dist := dot(plane.normal, sphere.pos) - plane.dist
    if abs(dist) <= sphere.rad {
        // The sphere is already overlapping the plane. Set t of
        // intersection to zero and q to sphere center
        return 0.0, sphere.pos, true
    }

    denom := dot(plane.normal, vel)
    if (denom * dist >= 0.0) {
        // No intersection as sphere moving parallel to or away from plane
        return 1.0, sphere.pos, false
    }

    // Sphere is moving towards the plane

    // Use +r in computations if sphere in front of plane, else -r
    r := dist > 0.0 ? sphere.rad : -sphere.rad
    t = (r - dist) / denom
    point = sphere.pos + vel * t - r * plane.normal
    return t, point, t <= 1.0
}

intersect_ray_sphere :: proc(pos: Vec3, dir: Vec3, sphere: Sphere) -> (t: f32, ok: bool) {
    m := pos - sphere.pos
    b := dot(m, dir)
    c := dot(m, m) - sphere.rad * sphere.rad
    // Exit if r’s origin outside s (c > 0) and r pointing away from s (b > 0)
    if c > 0 && b > 0 {
        return 0, false
    }
    discr := b * b - c
    // A negative discriminant corresponds to ray missing sphere
    if discr < 0 do return 0, false
    // Ray now found to intersect sphere, compute smallest t value of intersection
    t = -b - sqrt(discr)
    // If t is negative, ray started inside sphere so clamp t to zero
    t = max(0, t)
    return t, true
}

intersect_ray_aabb :: proc(pos: Vec3, dir: Vec3, aabb: Aabb, range: f32 = max(f32)) -> (t: [2]f32, ok: bool) {
    // https://tavianator.com/cgit/dimension.git/tree/libdimension/bvh/bvh.c#n196

    // This is actually correct, even though it appears not to handle edge cases
    // (dir.{x,y,z} == 0).  It works because the infinities that result from
    // dividing by zero will still behave correctly in the comparisons.  Rays
    // which are parallel to an axis and outside the box will have tmin == inf
    // or tmax == -inf, while rays inside the box will have tmin and tmax
    // unchanged.

    inv_dir := 1.0 / dir

    t1 := (aabb.min - pos) * inv_dir
    t2 := (aabb.max - pos) * inv_dir

    t = {max(min(t1.x, t2.x), min(t1.y, t2.y), min(t1.z, t2.z)), min(max(t1.x, t2.x), max(t1.y, t2.y), max(t1.z, t2.z))}

    return t, t[1] >= max(0.0, t[0]) && t[0] < range
}

intersect_ray_polyhedron :: proc(pos, dir: Vec3, planes: []Plane, segment: [2]f32 = {0.0, max(f32)}) -> (t: [2]f32, ok: bool) {
    t = segment
    for plane in planes {
        denom := dot(plane.normal, dir)
        dist := plane.dist - dot(plane.normal, pos)
        // Test if segment runs parallel to the plane
        if denom == 0.0 {
            // If so, return “no intersection” if segment lies outside plane
            if dist > 0.0 {
                return 0, false
            }
        } else {
            // Compute parameterized t value for intersection with current plane
            tplane := dist / denom
            if denom < 0.0 {
                // When entering halfspace, update tfirst if t is larger
                t[0] = max(t[0], tplane)
            } else {
                // When exiting halfspace, update tlast if t is smaller
                t[1] = min(t[1], tplane)
            }
            if t[0] > t[1] {
                return 0, false
            }
        }
    }
    return t, true
}

intersect_segment_triangle :: proc(
    segment: [2]Vec3,
    triangle: [3]Vec3,
) -> (
    t: f32,
    normal: Vec3,
    barycentric: [3]f32,
    ok: bool,
) {
    ab := triangle[1] - triangle[0]
    ac := triangle[2] - triangle[0]
    qp := segment[0] - segment[1]

    normal = cross(ab, ac)

    denom := dot(qp, normal)
    // If denom <= 0, segment is parallel to or points away from triangle
    if denom <= 0 {
        return 0, normal, 0, false
    }

    // Compute intersection t value of pq with plane of triangle. A ray
    // intersects if 0 <= t. Segment intersects iff 0 <= t <= 1. Delay
    // dividing by d until intersection has been found to pierce triangle
    ap := segment[0] - triangle[0]
    t = dot(ap, normal)
    if t < 0 {
        return
    }
    if t > denom {
        // For segment; exclude this code line for a ray test
        return
    }

    // Compute barycentric coordinate components and test if within bounds
    e := cross(qp, ap)
    barycentric.y = dot(ac, e)
    if barycentric.y < 0 || barycentric.y > denom {
        return
    }
    barycentric.z = -dot(ab, e)
    if barycentric.z < 0 || barycentric.y + barycentric.z > denom {
        return
    }

    // Segment/ray intersects triangle. Perform delayed division and
    // compute the last barycentric coordinate component
    ood := 1.0 / denom
    t *= ood
    barycentric.yz *= ood
    barycentric.x = 1.0 - barycentric.y - barycentric.z
    return t, normal, barycentric, true
}

intersect_segment_plane :: proc(segment: [2]Vec3, plane: Plane) -> (t: f32, point: Vec3, ok: bool) {
    ab := segment[1] - segment[0]
    t = (plane.dist - dot(plane.normal, segment[0])) / dot(plane.normal, ab)

    if t >= 0 && t <= 1 {
        point = segment[0] + t * ab
        return t, point, true
    }

    return t, segment[0], false
}

// TODO: alternative with capsule endcaps
intersect_segment_cylinder :: proc(segment: [2]Vec3, cylinder: Cylinder) -> (t: f32, ok: bool) {
    d := cylinder.b - cylinder.a
    m := segment[0] - cylinder.a
    n := segment[1] - segment[0]
    md := dot(m, d)
    nd := dot(n, d)
    dd := dot(d, d)
    // Test if segment fully outside either endcap of cylinder
    if md < 0 && md + nd < 0 {
        return 0, false // Segment outside ’a’ side of cylinder
    }
    if md > dd && md + nd > dd {
        return 0, false // Segment outside ’b’ side of cylinder
    }
    nn := dot(n, n)
    mn := dot(m, n)
    a := dd * nn - nd * nd
    k := dot(m, m) - cylinder.rad * cylinder.rad
    c := dd * k - md * md
    EPS :: 1e-6
    if abs(a) < EPS {
        // Segment runs parallel to cylinder axis
        if c > 0 {
            return 0, false
        }
        // Now known that segment intersects cylinder; figure out how it intersects
        if md < 0 {
            // Intersect segment against ’a’ endcap
            t = -mn / nn
        } else if md > dd {
            // Intersect segment against ’b’ endcap
            t = (nd - mn) / nn
        } else {
            // ’a’ lies inside cylinder
            t = 0
        }
        return t, true
    }
    b := dd * mn - nd * md
    discr := b * b - a * c
    if discr < 0 {
        return 0, false // no real roots
    }
    t = (-b - sqrt(discr)) / a
    if t < 0 || t > 1 {
        return 0, false // intersection outside segment
    }
    if md + t * nd < 0 {
        // Intersection outside cylinder on ’a’ side
        if nd <= 0 {
            // Segment pointing away from endcap
            return 0, false
        }
        t = -md / nd
        ok = k + 2 * t * (mn + t * nn) <= 0
        return t, ok
    } else if md + t * nd > dd {
        // Intersection outside cylinder on ’b’ side
        if nd >= 0 {
            // Segment pointing away from endcap
            return 0, false
        }
        t = (dd - md) / nd
        ok = k + dd - 2 * md + t * (2 * (mn - nd) + t * nn) <= 0
        return t, ok
    }
    return t, true
}