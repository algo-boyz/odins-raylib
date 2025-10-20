package main

Camera :: struct {
    position: Vector3,
    target: Vector3
}

MakeCamera :: proc(position, target: Vector3) -> Camera {
    camera: Camera
    camera.position = position
    camera.target = target
    return camera
}