package controller

import rl "vendor:raylib"

// --- Sphere State ---
spherePos: rl.Vector3 = {5.0, 1.0, -3.0}
sphereVelocity: rl.Vector3
sphereAcceleration: rl.Vector3
sphereRotation: rl.Vector3
sphereAngularVelocity: rl.Vector3

// --- Constants ---
MAX_ACCELERATION: f32 = 2.0
MAX_VELOCITY: f32 = 5.0
MAX_ANGULAR_VELOCITY: f32 = 0.5
SPHERE_RADIUS: f32 = 1.0

// update_controller updates the sphere's position and rotation based on keyboard input.
update_controller :: proc(deltaTime: f32) {
    // --- Translational Movement ---
    inputAccel: rl.Vector3
    if rl.IsKeyDown(.W) { inputAccel.z -= 1.0 }
    if rl.IsKeyDown(.S) { inputAccel.z += 1.0 }
    if rl.IsKeyDown(.A) { inputAccel.x -= 1.0 }
    if rl.IsKeyDown(.D) { inputAccel.x += 1.0 }
    if rl.IsKeyDown(.E) { inputAccel.y += 1.0 }
    if rl.IsKeyDown(.Q) { inputAccel.y -= 1.0 }

    if rl.Vector3LengthSqr(inputAccel) > 0 {
        inputAccel = rl.Vector3Normalize(inputAccel)
        inputAccel *= MAX_ACCELERATION
    }

    sphereAcceleration = inputAccel
    sphereVelocity += (sphereAcceleration * deltaTime)

    // Clamp velocity to max speed
    if rl.Vector3LengthSqr(sphereVelocity) > MAX_VELOCITY * MAX_VELOCITY {
        sphereVelocity = rl.Vector3Normalize(sphereVelocity) * MAX_VELOCITY
    }

    spherePos += (sphereVelocity * deltaTime)

    // --- Rotational Movement ---
    inputAngVel: rl.Vector3
    if rl.IsKeyDown(.UP)    { inputAngVel.x -= 1.0 }
    if rl.IsKeyDown(.DOWN)  { inputAngVel.x += 1.0 }
    if rl.IsKeyDown(.LEFT)  { inputAngVel.y -= 1.0 }
    if rl.IsKeyDown(.RIGHT) { inputAngVel.y += 1.0 }
    if rl.IsKeyDown(.Z)     { inputAngVel.z -= 1.0 }
    if rl.IsKeyDown(.X)     { inputAngVel.z += 1.0 }

    if rl.Vector3LengthSqr(inputAngVel) > 0 {
        inputAngVel = rl.Vector3Normalize(inputAngVel)
        inputAngVel *= MAX_ANGULAR_VELOCITY
    }

    sphereAngularVelocity = inputAngVel
    sphereRotation.x += sphereAngularVelocity.x * deltaTime
    sphereRotation.y += sphereAngularVelocity.y * deltaTime
    sphereRotation.z += sphereAngularVelocity.z * deltaTime
}

// draw_sphere draws the controllable sphere.
draw_sphere :: proc() {
    // Note: The original DrawSphereEx with rotation is not directly available.
    // We can use DrawSphere and manually apply rotation if needed.
    rl.DrawSphereEx(spherePos, SPHERE_RADIUS, 16, 16, rl.BLUE)
}