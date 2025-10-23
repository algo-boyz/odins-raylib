package main

import rl "vendor:raylib"
import "core:math"

DrawWireframe :: proc(
    vertices: []Vector3,
    triangles: []Triangle, 
    projMat: Matrix4x4,
    color: rl.Color,
    cullBackFace: bool
) {
    for &tri in triangles {
        v1 := vertices[tri[0]]
        v2 := vertices[tri[1]]
        v3 := vertices[tri[2]]

        if cullBackFace && IsBackFace(v1, v2, v3) {
            continue
        }

        p1 := ProjectToScreen(projMat, v1)
        p2 := ProjectToScreen(projMat, v2)
        p3 := ProjectToScreen(projMat, v3)

        if (IsFaceOutsideFrustum(p1, p2, p3)) { 
            continue
        }

        DrawLine(p1.xy, p2.xy, color)
        DrawLine(p2.xy, p3.xy, color)
        DrawLine(p3.xy, p1.xy, color)
    }
}

IsBackFace :: proc(v1, v2, v3: Vector3) -> bool {
    edge1 := v2 - v1
    edge2 := v3 - v1

    cross := Vector3CrossProduct(edge1, edge2)
    crossNorm := Vector3Normalize(cross)
    toCamera := Vector3Normalize(v1)
    
    return Vector3DotProduct(crossNorm, toCamera) >= 0.0 
}

ProjectToScreen :: proc(mat: Matrix4x4, p: Vector3) -> Vector3 {
    clip := Mat4MulVec4(mat, Vector4{p.x, p.y, p.z, 1.0})

    invW : f32 = 1.0 / clip.w

    ndcX := clip.x * invW
    ndcY := clip.y * invW

    screenX := ( ndcX * 0.5 + 0.5) * WIDTH
    screenY := (-ndcY * 0.5 + 0.5) * HEIGHT

    return Vector3{screenX, screenY, invW}
}

IsFaceOutsideFrustum :: proc(p1, p2, p3: Vector3) -> bool {
    if (p1.z >  1.0 || p2.z >  1.0 || p3.z >  1.0) ||
       (p1.z < -1.0 || p2.z < -1.0 || p3.z < -1.0) {
        return true
    }

    minX := min(p1.x, min(p2.x, p3.x))
    maxX := max(p1.x, max(p2.x, p3.x))
    minY := min(p1.y, min(p2.y, p3.y))
    maxY := max(p1.y, max(p2.y, p3.y))

    if maxX < 0 || minX > WIDTH ||
       maxY < 0 || minY > HEIGHT {
        return true
    }

    return false
}

DrawLine :: proc(a, b: Vector2, color: rl.Color) {
    dX := b.x - a.x
    dY := b.y - a.y

    longerDelta := abs(dX) >= abs(dY) ? abs(dX) : abs(dY)

    incX := dX / longerDelta
    incY := dY / longerDelta

    x := a.x
    y := a.y

    for i := 0; i <= int(longerDelta); i += 1 {
        rl.DrawPixel(i32(x), i32(y), color)
        x += incX
        y += incY
    }
}