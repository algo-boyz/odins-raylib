package physac

import "core:math/linalg"
import "core:math"
import "core:thread"
import "core:time"

// when ODIN_DEBUG {
//     import "core:fmt"
// }

MAX_BODIES :: 64
MAX_MANIFOLDS :: 4096
MAX_VERTICES :: 24
CIRCLE_VERTICES :: 24

COLLISION_ITERATIONS :: 100
PENETRATION_ALLOWANCE :: 0.01
PENETRATION_CORRECTION :: 0.4

Vector2 :: linalg.Vector2f32
Vector3 :: linalg.Vector3f32
Vector4 :: linalg.Vector4f32
Mat2 :: linalg.Matrix2x2f32

PhysicsShapeType :: enum {
    CIRCLE,
    POLYGON,
    // TODO (phil): Possibly remove this case?
    INVALID,
}

PhysicsBody :: ^PhysicsBodyData
PhysicsManifold :: ^PhysicsManifoldData

PolygonData :: struct {
    vertexCount: int, // Current used vertex and normals count
    positions:   [MAX_VERTICES]Vector2, // Polygon vertex positions vectors
    normals:     [MAX_VERTICES]Vector2, // Polygon vertex normals vectors
}

PhysicsShape :: struct {
    type:       PhysicsShapeType, // Physics shape type (circle or polygon)
    body:       PhysicsBody, // Shape physics body reference
    radius:     f32, // Circle shape radius (used for circle shapes)
    transform:  Mat2, // Vertices transform matrix 2x2
    vertexData: PolygonData, // Polygon shape vertices position and normals data (just used for polygon shapes)
}

PhysicsBodyData :: struct {
    id:              int, // Reference unique identifier
    enabled:         bool, // Enabled dynamics state (collisions are calculated anyway)
    position:        Vector2, // Physics body shape pivot
    velocity:        Vector2, // Current linear velocity applied to position
    force:           Vector2, // Current linear force (reset to 0 every step)
    angularVelocity: f32, // Current angular velocity applied to orient
    torque:          f32, // Current angular force (reset to 0 every step)
    orient:          f32, // Rotation in radians
    inertia:         f32, // Moment of inertia
    inverseInertia:  f32, // Inverse value of inertia
    mass:            f32, // Physics body mass
    inverseMass:     f32, // Inverse value of mass
    staticFriction:  f32, // Friction when the body has not movement (0 to 1)
    dynamicFriction: f32, // Friction when the body has movement (0 to 1)
    restitution:     f32, // Restitution coefficient of the body (0 to 1)
    useGravity:      bool, // Apply gravity force to dynamics
    isGrounded:      bool, // Physics grounded on other body state
    freezeOrient:    bool, // Physics rotation constraint
    shape:           PhysicsShape, // Physics body shape information (type, radius, vertices, normals)
}

PhysicsManifoldData :: struct {
    id:              int, // Reference unique identifier
    bodyA:           PhysicsBody, // Manifold first physics body reference
    bodyB:           PhysicsBody, // Manifold second physics body reference
    penetration:     f32, // Depth of penetration from collision
    normal:          Vector2, // Normal direction vector from 'a' to 'b'
    contacts:        [2]Vector2, // Points of contact during collision
    contactsCount:   int, // Current collision number of contacts
    restitution:     f32, // Mixed restitution during collision
    dynamicFriction: f32, // Mixed dynamic friction during collision
    staticFriction:  f32, // Mixed static friction during collision
}

//----------------------------------------------------------------------------------
// Module Functions Declaration
//----------------------------------------------------------------------------------
/*InitPhysics :: proc()                                                                           // Initializes physics values, pointers and creates physics loop thread*/
/*RunPhysicsStep :: proc(*/
/*) // Run physics step, to be used if PHYSICS_NO_THREADS is set in your main loop*/
/*SetPhysicsTimeStep :: proc(*/
/*delta: f64,*/
/*) // Sets physics fixed time step in milliseconds. 1.666666 by default*/
/*IsPhysicsEnabled :: proc() -> bool                                                                      // Returns true if physics thread is currently enabled*/
/*SetPhysicsGravity :: proc(x, y: f32)                                                         // Sets physics global gravity force*/
/*CreatePhysicsBodyCircle:: proc(pos: Vector2, radius: f32, density: f32) -> PhysicsBody                    // Creates a new circle physics body with generic parameters*/
/*CreatePhysicsBodyRectangle :: proc(*/
/*pos: Vector2,*/
/*width: f32,*/
/*height: f32,*/
/*density: f32,*/
/*) ->*/
/*PhysicsBody // Creates a new rectangle physics body with generic parameters*/
/*CreatePhysicsBodyPolygon :: proc(*/
/*pos: Vector2,*/
/*radius: f32,*/
/*sides: int,*/
/*density: f32,*/
/*) -> PhysicsBody // Creates a new polygon physics body with generic parameters*/
/*PhysicsAddForce :: proc(*/
/*body: PhysicsBody,*/
/*force: Vector2,*/
/*) // Adds a force to a physics body*/
/*PhysicsAddTorque :: proc(*/
/*body: PhysicsBody,*/
/*amount: f32,*/
/*) // Adds an angular force to a physics body*/
/*PhysicsShatter :: proc(*/
/*body: PhysicsBody,*/
/*position: Vector2,*/
/*force: f32,*/
/*) // Shatters a polygon shape physics body to little physics bodies with explosion force*/
/*GetPhysicsBodiesCount :: proc() ->*/
/*int // Returns the current amount of created physics bodies*/

/*// Returns a physics body of the bodies pool at a specific index*/
/*GetPhysicsBody :: proc(index: int) -> PhysicsBody*/
/*// Returns the physics body shape type (PHYSICS_CIRCLE or PHYSICS_POLYGON)*/
/*GetPhysicsShapeType :: proc(index: int) -> PhysicsShapeType*/
/*// Returns the amount of vertices of a physics body shape*/
/*GetPhysicsShapeVerticesCount :: proc(index: int) -> int*/
// Returns transformed position of a body shape (body position + vertex transformed position)
/*GetPhysicsShapeVertex :: proc(body: PhysicsBody, vertex: int) -> Vector2*/
/*SetPhysicsBodyRotation :: proc(*/
/*body: PhysicsBody,*/
/*radians: f32,*/
/*) // Sets physics body shape transform based on radians parameter*/
/*DestroyPhysicsBody :: proc(*/
/*body: PhysicsBody,*/
/*) // Unitializes and destroy a physics body*/
/*ClosePhysics :: proc(*/

/*) // Unitializes physics pointers and closes physics loop thread*/

// Defines
EPSILON :: 0.000001
K :: 1.0 / 3.0

// Globals
usedMemory: f32
// TODO (phil): Handle no thread config
physicsThreadEnabled := false // Physics thread enabled state
g_thread: ^thread.Thread
// TODO (phil): I believe baseTime is unnecessary and can be removed
baseTime: time.Time = {} // Offset time for MONOTONIC clock
startTime: time.Time = {} // Start time in milliseconds
deltaTime: f64 = 1.0 / 60.0 / 10.0 * 1000 // Delta time used for physics steps, in milliseconds
currentTime: time.Time = {} // Current time in milliseconds
frequency: u64 = 0 // Hi-res clock frequency

accumulator: f64 = 0.0 // Physics time step delta time accumulator
stepsCount: int = 0 // Total physics steps processed
gravityForce := Vector2{0.0, 9.81} // Physics world gravity force
bodies: [MAX_BODIES]PhysicsBody // Physics bodies pointers array
physicsBodiesCount: int = 0 // Physics world current bodies counter
contacts: [MAX_MANIFOLDS]PhysicsManifold // Physics bodies pointers array
physicsManifoldsCount: int = 0 // Physics world current manifolds counter

// Skip module internal functions definitions

// Skip math functions

// Initializes physics values, pointers and creates physics loop thread
InitPhysics :: proc() {
    g_thread = thread.create(PhysicsLoop)
    thread.start(g_thread)

    InitTimer()

    accumulator = 0.0
}

// Returns true if physics thread is currently enabled
IsPhysicsEnabled :: proc() -> bool {
    return physicsThreadEnabled
}

// Sets physics global gravity force
SetPhysicsGravity :: proc(x, y: f32) {
    gravityForce.x = x
    gravityForce.y = y
}

// Creates a new circle physics body with generic parameters
CreatePhysicsBodyCircle :: proc(
    pos: Vector2,
    radius: f32,
    density: f32,
    allocator := context.allocator,
) -> PhysicsBody {
    context.allocator = allocator
    newBody := new(PhysicsBodyData)
    usedMemory += size_of(PhysicsBodyData)

    newId := FindAvailableBodyIndex()
    if newId != -1 {
        // Initialize new body with generic values
        newBody.id = newId
        newBody.enabled = true
        newBody.position = pos
        newBody.velocity = {}
        newBody.force = {}
        newBody.angularVelocity = 0.0
        newBody.torque = 0.0
        newBody.orient = 0.0
        newBody.shape.type = .CIRCLE
        newBody.shape.body = newBody
        newBody.shape.radius = radius
        newBody.shape.transform = Mat2Radians(0.0)
        newBody.shape.vertexData = {}

        newBody.mass = math.PI * radius * radius * density
        newBody.inverseMass =
        ((newBody.mass != 0.0) ? 1.0 / newBody.mass : 0.0)
        newBody.inertia = newBody.mass * radius * radius
        newBody.inverseInertia =
        ((newBody.inertia != 0.0) ? 1.0 / newBody.inertia : 0.0)
        newBody.staticFriction = 0.4
        newBody.dynamicFriction = 0.2
        newBody.restitution = 0.0
        newBody.useGravity = true
        newBody.isGrounded = false
        newBody.freezeOrient = false

        // Add new body to bodies pointers array and update bodies count
        bodies[physicsBodiesCount] = newBody
        physicsBodiesCount += 1
        when ODIN_DEBUG {
            fmt.printf(
                "[PHYSAC] created polygon physics body id {}\n",
                newBody.id,
            )
        }
    } else {
        when ODIN_DEBUG {
            fmt.printf(
                "[PHYSAC] new physics body creation failed because there is any available id to use\n",
            )
        }
    }

    return newBody
}

// Creates a new rectangle physics body with generic parameters
CreatePhysicsBodyRectangle :: proc(
    pos: Vector2,
    width: f32,
    height: f32,
    density: f32,
    allocator := context.allocator,
) -> PhysicsBody {
    context.allocator = allocator
    newBody := new(PhysicsBodyData)
    usedMemory += size_of(PhysicsBodyData)

    newId := FindAvailableBodyIndex()
    if newId != -1 {
        // Initialize new body with generic values
        newBody.id = newId
        newBody.enabled = true
        newBody.position = pos
        newBody.velocity = {}
        newBody.force = {}
        newBody.angularVelocity = 0.0
        newBody.torque = 0.0
        newBody.orient = 0.0
        newBody.shape.type = .POLYGON
        newBody.shape.body = newBody
        newBody.shape.radius = 0.0
        newBody.shape.transform = Mat2Radians(0.0)
        newBody.shape.vertexData = CreateRectanglePolygon(
            pos,
            Vector2{width, height},
        )

        // Calculate centroid and moment of inertia
        center: Vector2 = {0.0, 0.0}
        area: f32 = 0.0
        inertia: f32 = 0.0

        for i := 0; i < newBody.shape.vertexData.vertexCount; i += 1 {
            // Triangle vertices, third vertex implied as (0, 0)
            p1 := newBody.shape.vertexData.positions[i]
            nextIndex := (((i + 1) <
                    newBody.shape.vertexData.vertexCount) ? (i + 1) : 0)
            p2 := newBody.shape.vertexData.positions[nextIndex]

            /*float D = MathCrossVector2(p1, p2);*/
            D := linalg.vector_cross2(p1, p2)
            triangleArea := D / 2

            area += triangleArea

            // Use area to weight the centroid average, not just vertex position
            center.x += triangleArea * K * (p1.x + p2.x)
            center.y += triangleArea * K * (p1.y + p2.y)

            intx2: f32 = p1.x * p1.x + p2.x * p1.x + p2.x * p2.x
            inty2: f32 = p1.y * p1.y + p2.y * p1.y + p2.y * p2.y
            inertia += (0.25 * K * D) * (intx2 + inty2)
        }

        center.x *= 1.0 / area
        center.y *= 1.0 / area

        // Translate vertices to centroid (make the centroid (0, 0) for the polygon in model space)
        // Note: this is not really necessary
        for i := 0; i < newBody.shape.vertexData.vertexCount; i += 1 {
            newBody.shape.vertexData.positions[i].x -= center.x
            newBody.shape.vertexData.positions[i].y -= center.y
        }

        newBody.mass = density * area
        newBody.inverseMass =
        ((newBody.mass != 0.0) ? 1.0 / newBody.mass : 0.0)
        newBody.inertia = density * inertia
        newBody.inverseInertia =
        ((newBody.inertia != 0.0) ? 1.0 / newBody.inertia : 0.0)
        newBody.staticFriction = 0.4
        newBody.dynamicFriction = 0.2
        newBody.restitution = 0.0
        newBody.useGravity = true
        newBody.isGrounded = false
        newBody.freezeOrient = false

        // Add new body to bodies pointers array and update bodies count
        bodies[physicsBodiesCount] = newBody
        physicsBodiesCount += 1

        when ODIN_DEBUG {
            fmt.printf(
                "[PHYSAC] created polygon physics body id %i\n",
                newBody.id,
            )
        }
    } else {
        when ODIN_DEBUG {
            fmt.printf(
                "[PHYSAC] new physics body creation failed because there is any available id to use\n",
            )
        }
    }

    return newBody
}

// Creates a new polygon physics body with generic parameters
CreatePhysicsBodyPolygon :: proc(
    pos: Vector2,
    radius: f32,
    sides: int,
    density: f32,
    allocator := context.allocator,
) -> PhysicsBody {
    context.allocator = allocator
    newBody := new(PhysicsBodyData)
    usedMemory += size_of(PhysicsBodyData)

    newId := FindAvailableBodyIndex()
    if newId != -1 {
        // Initialize new body with generic values
        newBody.id = newId
        newBody.enabled = true
        newBody.position = pos
        newBody.velocity = {}
        newBody.force = {}
        newBody.angularVelocity = 0.0
        newBody.torque = 0.0
        newBody.orient = 0.0
        newBody.shape.type = .POLYGON
        newBody.shape.body = newBody
        newBody.shape.transform = Mat2Radians(0.0)
        newBody.shape.vertexData = CreateRandomPolygon(radius, sides)

        // Calculate centroid and moment of inertia
        center := Vector2{}
        area: f32 = 0.0
        inertia: f32 = 0.0

        for i := 0; i < newBody.shape.vertexData.vertexCount; i += 1 {
            // Triangle vertices, third vertex implied as (0, 0)
            position1 := newBody.shape.vertexData.positions[i]
            nextIndex := (((i + 1) <
                    newBody.shape.vertexData.vertexCount) ? (i + 1) : 0)
            position2 := newBody.shape.vertexData.positions[nextIndex]

            cross := linalg.vector_cross2(position1, position2)
            triangleArea := cross / 2

            area += triangleArea

            // Use area to weight the centroid average, not just vertex position
            center.x += triangleArea * K * (position1.x + position2.x)
            center.y += triangleArea * K * (position1.y + position2.y)

            intx2 :=
                position1.x * position1.x +
                position2.x * position1.x +
                position2.x * position2.x
            inty2 :=
                position1.y * position1.y +
                position2.y * position1.y +
                position2.y * position2.y
            inertia += (0.25 * K * cross) * (intx2 + inty2)
        }

        center.x *= 1.0 / area
        center.y *= 1.0 / area

        // Translate vertices to centroid (make the centroid (0, 0) for the polygon in model space)
        // Note: this is not really necessary
        for i := 0; i < newBody.shape.vertexData.vertexCount; i += 1 {
            newBody.shape.vertexData.positions[i].x -= center.x
            newBody.shape.vertexData.positions[i].y -= center.y
        }

        newBody.mass = density * area
        newBody.inverseMass =
        ((newBody.mass != 0.0) ? 1.0 / newBody.mass : 0.0)
        newBody.inertia = density * inertia
        newBody.inverseInertia =
        ((newBody.inertia != 0.0) ? 1.0 / newBody.inertia : 0.0)
        newBody.staticFriction = 0.4
        newBody.dynamicFriction = 0.2
        newBody.restitution = 0.0
        newBody.useGravity = true
        newBody.isGrounded = false
        newBody.freezeOrient = false

        // Add new body to bodies pointers array and update bodies count
        bodies[physicsBodiesCount] = newBody
        physicsBodiesCount += 1

        when ODIN_DEBUG {
            fmt.printf(
                "[PHYSAC] created polygon physics body id %i\n",
                newBody.id,
            )
        }
    } else {
        when ODIN_DEBUG {
            fmt.printf(
                "[PHYSAC] new physics body creation failed because there is any available id to use\n",
            )
        }
    }

    return newBody
}

// Adds a force to a physics body
PhysicsAddForce :: proc(body: PhysicsBody, force: Vector2) {
    if body != nil {
        body.force = body.force + force
    }
}

// Adds an angular force to a physics body
PhysicsAddTorque :: proc(body: PhysicsBody, amount: f32) {
    if body != nil {
        body.torque += amount
    }
}

// Shatters a polygon shape physics body to little physics bodies with explosion force
PhysicsShatter :: proc(
    body: PhysicsBody,
    position: Vector2,
    force: f32,
    allocator := context.allocator,
) {
    context.allocator = allocator
    if body != nil {
        if body.shape.type == .POLYGON {
            vertexData := body.shape.vertexData
            collision := false

            for i := 0; i < vertexData.vertexCount; i += 1 {
                positionA := body.position
                positionB :=
                    body.shape.transform *
                    (body.position + vertexData.positions[i])
                nextIndex := (((i + 1) < vertexData.vertexCount) ? (i + 1) : 0)
                positionC :=
                    body.shape.transform *
                    (body.position + vertexData.positions[nextIndex])

                // Check collision between each triangle
                alpha :=
                    ((positionB.y - positionC.y) * (position.x - positionC.x) +
                        (positionC.x - positionB.x) *
                            (position.y - positionC.y)) /
                    ((positionB.y - positionC.y) *
                                (positionA.x - positionC.x) +
                            (positionC.x - positionB.x) *
                                (positionA.y - positionC.y))

                beta :=
                    ((positionC.y - positionA.y) * (position.x - positionC.x) +
                        (positionA.x - positionC.x) *
                            (position.y - positionC.y)) /
                    ((positionB.y - positionC.y) *
                                (positionA.x - positionC.x) +
                            (positionC.x - positionB.x) *
                                (positionA.y - positionC.y))

                gamma := 1.0 - alpha - beta

                if (alpha > 0.0) && (beta > 0.0) && (gamma > 0.0) {
                    collision = true
                    break
                }
            }

            if collision {
                count := vertexData.vertexCount
                bodyPos := body.position
                /*Vector2 *vertices = (Vector2*)PHYSAC_MALLOC(sizeof(Vector2) * count);*/
                vertices := make([dynamic]Vector2, count)
                defer delete(vertices)
                trans := body.shape.transform

                for i := 0; i < count; i += 1 {
                    vertices[i] = vertexData.positions[i]
                }

                // Destroy shattered physics body
                DestroyPhysicsBody(body)

                for i := 0; i < count; i += 1 {
                    nextIndex := (((i + 1) < count) ? (i + 1) : 0)
                    center := TriangleBarycenter(
                        vertices[i],
                        vertices[nextIndex],
                        Vector2{},
                    )
                    center += bodyPos
                    offset := center - bodyPos

                    newBody := CreatePhysicsBodyPolygon(center, 10, 3, 10) // Create polygon physics body with relevant values

                    newData := PolygonData{}
                    newData.vertexCount = 3

                    newData.positions[0] = vertices[i] - offset
                    newData.positions[1] = vertices[nextIndex] - offset
                    newData.positions[2] = position - center

                    // Separate vertices to avoid unnecessary physics collisions
                    newData.positions[0].x *= 0.95
                    newData.positions[0].y *= 0.95
                    newData.positions[1].x *= 0.95
                    newData.positions[1].y *= 0.95
                    newData.positions[2].x *= 0.95
                    newData.positions[2].y *= 0.95

                    // Calculate polygon faces normals
                    for j := 0; j < newData.vertexCount; j += 1 {
                        nextVertex := (((j + 1) < newData.vertexCount) ? (j +
                                1) : 0)
                        face :=
                            newData.positions[nextVertex] -
                            newData.positions[j]

                        newData.normals[j] = Vector2{face.y, -face.x}
                        newData.normals[j] = linalg.normalize(
                            newData.normals[j],
                        )
                    }

                    // Apply computed vertex data to new physics body shape
                    newBody.shape.vertexData = newData
                    newBody.shape.transform = trans

                    // Calculate centroid and moment of inertia
                    center = {}
                    area: f32 = 0.0
                    inertia: f32 = 0.0

                    for j := 0;
                        j < newBody.shape.vertexData.vertexCount;
                        j += 1 {
                        // Triangle vertices, third vertex implied as (0, 0)
                        p1 := newBody.shape.vertexData.positions[j]
                        nextVertex := (((j + 1) <
                                newBody.shape.vertexData.vertexCount) ? (j +
                                1) : 0)
                        p2 := newBody.shape.vertexData.positions[nextVertex]

                        D := linalg.vector_cross2(p1, p2)
                        triangleArea := D / 2

                        area += triangleArea

                        // Use area to weight the centroid average, not just vertex position
                        center.x += triangleArea * K * (p1.x + p2.x)
                        center.y += triangleArea * K * (p1.y + p2.y)

                        intx2 := p1.x * p1.x + p2.x * p1.x + p2.x * p2.x
                        inty2 := p1.y * p1.y + p2.y * p1.y + p2.y * p2.y
                        inertia += (0.25 * K * D) * (intx2 + inty2)
                    }

                    center.x *= 1.0 / area
                    center.y *= 1.0 / area

                    newBody.mass = area
                    newBody.inverseMass =
                    ((newBody.mass != 0.0) ? 1.0 / newBody.mass : 0.0)
                    newBody.inertia = inertia
                    newBody.inverseInertia =
                    ((newBody.inertia != 0.0) ? 1.0 / newBody.inertia : 0.0)

                    // Calculate explosion force direction
                    pointA := newBody.position
                    pointB := newData.positions[1] - newData.positions[0]
                    pointB.x /= 2.0
                    pointB.y /= 2.0
                    forceDirection :=
                        pointA +
                        newData.positions[0] +
                        pointB -
                        newBody.position
                    forceDirection = linalg.normalize(forceDirection)
                    forceDirection.x *= force
                    forceDirection.y *= force

                    // Apply force to new physics body
                    PhysicsAddForce(newBody, forceDirection)
                }
            }
        }
    } else {
        when ODIN_DEBUG {
            fmt.println(
                "[PHYSAC] error when trying to shatter a null reference physics body",
            )
        }
    }
}

// Returns the current amount of created physics bodies
GetPhysicsBodiesCount :: proc() -> int {
    return int(physicsBodiesCount)
}

// Returns a physics body of the bodies pool at a specific index
GetPhysicsBody :: proc(index: int) -> PhysicsBody {
    if index < physicsBodiesCount {
        if bodies[index] == nil {
            when ODIN_DEBUG {
                fmt.printf(
                    "[PHYSAC] error when trying to get a null reference physics body",
                )
            }
        }
    } else {
        when ODIN_DEBUG {
            fmt.printf("[PHYSAC] physics body index is out of bounds")
        }
    }

    return bodies[index]
}

// Returns the physics body shape type (PHYSICS_CIRCLE or PHYSICS_POLYGON)
GetPhysicsShapeType :: proc(index: int) -> PhysicsShapeType {
    result := PhysicsShapeType.INVALID

    if index < physicsBodiesCount {
        if bodies[index] != nil {
            result = bodies[index].shape.type
        } else {
            when ODIN_DEBUG {
                fmt.printf(
                    "[PHYSAC] error when trying to get a null reference physics body",
                )
            }
        }
    } else {
        when ODIN_DEBUG {
            fmt.printf("[PHYSAC] physics body index is out of bounds")
        }
    }

    return result
}

// Returns the amount of vertices of a physics body shape
GetPhysicsShapeVerticesCount :: proc(index: int) -> int {
    result := 0

    if index < physicsBodiesCount {
        if bodies[index] != nil {
            switch bodies[index].shape.type {
            case .CIRCLE:
                result = CIRCLE_VERTICES
            case .POLYGON:
                result = int(bodies[index].shape.vertexData.vertexCount)
            case .INVALID:
                break
            }
        } else {
            when ODIN_DEBUG {
                fmt.printf(
                    "[PHYSAC] error when trying to get a null reference physics body",
                )
            }
        }
    } else {
        when ODIN_DEBUG {
            fmt.printf("[PHYSAC] physics body index is out of bounds")
        }
    }

    return result
}

// Returns transformed position of a body shape (body position + vertex transformed position)
GetPhysicsShapeVertex :: proc(body: PhysicsBody, vertex: int) -> Vector2 {
    position := Vector2{}

    if body != nil {
        switch body.shape.type {
        case .CIRCLE:
            {
                position.x =
                    body.position.x +
                    math.cos(
                            360.0 /
                            f32(CIRCLE_VERTICES) *
                            f32(vertex) *
                            f32(math.RAD_PER_DEG),
                        ) *
                        body.shape.radius
                position.y =
                    body.position.y +
                    math.sin(
                            360.0 /
                            f32(CIRCLE_VERTICES) *
                            f32(vertex) *
                            f32(math.RAD_PER_DEG),
                        ) *
                        body.shape.radius
            }
        case .POLYGON:
            {
                vertexData := body.shape.vertexData
                position =
                    body.position +
                    body.shape.transform * vertexData.positions[vertex]
            }
        case .INVALID:
            {
            }
        }
    } else {
        when ODIN_DEBUG {
            fmt.printf(
                "[PHYSAC] error when trying to get a null reference physics body",
            )

        }
    }

    return position
}

// Sets physics body shape transform based on radians parameter
SetPhysicsBodyRotation :: proc(body: PhysicsBody, radians: f32) {
    if body != nil {
        body.orient = radians

        if body.shape.type == .POLYGON {
            body.shape.transform = Mat2Radians(radians)
        }
    }
}
// Unitializes and destroys a physics body
DestroyPhysicsBody :: proc(body: PhysicsBody, allocator := context.allocator) {
    context.allocator = allocator
    if body != nil {
        id := body.id
        index := -1

        for i := 0; i < physicsBodiesCount; i += 1 {
            if bodies[i].id == id {
                index = int(i)
                break
            }
        }

        if index == -1 {
            when ODIN_DEBUG {
                fmt.printf(
                    "[PHYSAC] Not possible to find body id %i in pointers array\n",
                    id,
                )
            }
            return
        }

        // Free body allocated memory
        free(body)
        usedMemory -= size_of(PhysicsBodyData)
        bodies[index] = nil

        // Reorder physics bodies pointers array and its cached index
        for i := index; i < physicsBodiesCount; i += 1 {
            if (i + 1) < physicsBodiesCount {
                bodies[i] = bodies[i + 1]
            }
        }

        // Update physics bodies count
        physicsBodiesCount -= 1

        when ODIN_DEBUG {
            fmt.printf("[PHYSAC] destroyed physics body id %i\n", id)
        }
    } else {
        when ODIN_DEBUG {
            fmt.printf(
                "[PHYSAC] error trying to destroy a null referenced body\n",
            )
        }
    }
}

// Unitializes physics pointers and exits physics loop thread
ClosePhysics :: proc() {
    // Exit physics loop thread
    physicsThreadEnabled = false

    // TODO (phil): Handle no thread config
    thread.join(g_thread)

    // Unitialize physics manifolds dynamic memory allocations
    for i := physicsManifoldsCount - 1; i >= 0; i -= 1 {
        DestroyPhysicsManifold(contacts[i])
    }

    // Unitialize physics bodies dynamic memory allocations
    for i := physicsBodiesCount - 1; i >= 0; i -= 1 {
        DestroyPhysicsBody(bodies[i])
    }

    when ODIN_DEBUG {
        if physicsBodiesCount > 0 || usedMemory != 0 {
            fmt.printf(
                "[PHYSAC] physics module closed with %i still allocated bodies [MEMORY: %i bytes]\n",
                physicsBodiesCount,
                usedMemory,
            )
        } else if (physicsManifoldsCount > 0 || usedMemory != 0) {
            fmt.printf(
                "[PHYSAC] physics module closed with %i still allocated manifolds [MEMORY: %i bytes]\n",
                physicsManifoldsCount,
                usedMemory,
            )
        } else {
            fmt.printf("[PHYSAC] physics module closed successfully\n")
        }
    }

}

//----------------------------------------------------------------------------------
// Module Internal Functions Definition
//----------------------------------------------------------------------------------

// Finds a valid index for a new physics body initialization
FindAvailableBodyIndex :: proc() -> int {
    index := -1
    for i := 0; i < MAX_BODIES; i += 1 {
        currentId := i

        // Check if current id already exist in other physics body
        for k := 0; k < physicsBodiesCount; k += 1 {
            if bodies[k].id == currentId {
                currentId += 1
                break
            }
        }

        // If it is not used, use it as new physics body id
        if currentId == i {
            index = int(i)
            break
        }
    }

    return index
}

// Creates a random polygon shape with max vertex distance from polygon pivot
CreateRandomPolygon :: proc(radius: f32, sides: int) -> PolygonData {
    data := PolygonData{}
    data.vertexCount = sides

    // Calculate polygon vertices positions
    for i := 0; i < data.vertexCount; i += 1 {
        data.positions[i].x =
            math.cos(360.0 / f32(sides) * f32(i) * math.RAD_PER_DEG) * radius
        data.positions[i].y =
            math.sin(360.0 / f32(sides) * f32(i) * math.RAD_PER_DEG) * radius
    }

    // Calculate polygon faces normals
    for i := 0; i < data.vertexCount; i += 1 {
        nextIndex := (((i + 1) < sides) ? (i + 1) : 0)
        face := data.positions[nextIndex] - data.positions[i]

        data.normals[i] = Vector2{face.y, -face.x}
        data.normals[i] = linalg.normalize(data.normals[i])
    }

    return data
}

// Creates a rectangle polygon shape based on a min and max positions
CreateRectanglePolygon :: proc(pos: Vector2, size: Vector2) -> PolygonData {
    data := PolygonData{}
    data.vertexCount = 4

    // Calculate polygon vertices positions
    data.positions[0] = Vector2{pos.x + size.x / 2, pos.y - size.y / 2}
    data.positions[1] = Vector2{pos.x + size.x / 2, pos.y + size.y / 2}
    data.positions[2] = Vector2{pos.x - size.x / 2, pos.y + size.y / 2}
    data.positions[3] = Vector2{pos.x - size.x / 2, pos.y - size.y / 2}

    // Calculate polygon faces normals
    for i := 0; i < data.vertexCount; i += 1 {
        nextIndex := (((i + 1) < data.vertexCount) ? (i + 1) : 0)
        face := data.positions[nextIndex] - data.positions[i]

        data.normals[i] = Vector2{face.y, -face.x}
        data.normals[i] = linalg.normalize(data.normals[i])
    }

    return data
}

// Physics loop thread function
PhysicsLoop: thread.Thread_Proc : proc(arg: ^thread.Thread) {
    when ODIN_DEBUG {
        fmt.printf("[PHYSAC] physics thread created successfully\n")
    }

    // Initialize physics loop thread values
    physicsThreadEnabled = true

    // Physics update loop
    for physicsThreadEnabled {
        RunPhysicsStep()
    }
}

// Physics steps calculations (dynamics, collisions and position corrections)
PhysicsStep :: proc() {
    // Update current steps count
    stepsCount += 1

    // Clear previous generated collisions information
    for i := physicsManifoldsCount - 1; i >= 0; i -= 1 {
        manifold := contacts[i]

        if manifold != nil {
            DestroyPhysicsManifold(manifold)
        }
    }

    // Reset physics bodies grounded state
    for i := 0; i < physicsBodiesCount; i += 1 {
        body := bodies[i]
        body.isGrounded = false
    }

    // Generate new collision information
    for i := 0; i < physicsBodiesCount; i += 1 {
        bodyA := bodies[i]

        if bodyA != nil {
            for j := i + 1; j < physicsBodiesCount; j += 1 {
                bodyB := bodies[j]

                if bodyB != nil {
                    if (bodyA.inverseMass == 0) && (bodyB.inverseMass == 0) {
                        continue
                    }

                    manifold := CreatePhysicsManifold(bodyA, bodyB)
                    SolvePhysicsManifold(manifold)

                    if manifold.contactsCount > 0 {
                        // Create a new manifold with same information as previously solved manifold and add it to the manifolds pool last slot
                        newManifold := CreatePhysicsManifold(bodyA, bodyB)
                        newManifold.penetration = manifold.penetration
                        newManifold.normal = manifold.normal
                        newManifold.contacts[0] = manifold.contacts[0]
                        newManifold.contacts[1] = manifold.contacts[1]
                        newManifold.contactsCount = manifold.contactsCount
                        newManifold.restitution = manifold.restitution
                        newManifold.dynamicFriction = manifold.dynamicFriction
                        newManifold.staticFriction = manifold.staticFriction
                    }
                }
            }
        }
    }

    // Integrate forces to physics bodies
    for i := 0; i < physicsBodiesCount; i += 1 {
        body := bodies[i]

        if body != nil {
            IntegratePhysicsForces(body)
        }
    }

    // Initialize physics manifolds to solve collisions
    for i := 0; i < physicsManifoldsCount; i += 1 {
        manifold := contacts[i]

        if manifold != nil {
            InitializePhysicsManifolds(manifold)
        }
    }

    // Integrate physics collisions impulses to solve collisions
    for i := 0; i < COLLISION_ITERATIONS; i += 1 {
        for j := 0; j < physicsManifoldsCount; j += 1 {
            manifold := contacts[i]

            if manifold != nil {
                IntegratePhysicsImpulses(manifold)
            }
        }
    }

    // Integrate velocity to physics bodies
    for i := 0; i < physicsBodiesCount; i += 1 {
        body := bodies[i]

        if body != nil {
            IntegratePhysicsVelocity(body)
        }
    }

    // Correct physics bodies positions based on manifolds collision information
    for i := 0; i < physicsManifoldsCount; i += 1 {
        manifold := contacts[i]

        if manifold != nil {
            CorrectPhysicsPositions(manifold)
        }
    }

    // Clear physics bodies forces
    for i := 0; i < physicsBodiesCount; i += 1 {
        body := bodies[i]

        if body != nil {
            body.force = {}
            body.torque = 0.0
        }
    }
}

// Wrapper to ensure PhysicsStep is run with at a fixed time step
RunPhysicsStep :: proc() {
    // Calculate current time
    currentTime = time.now()

    // Calculate current delta time
    delta: f64 = f64(
        time.duration_milliseconds(time.diff(startTime, currentTime)),
    )

    // Store the time elapsed since the last frame began
    accumulator += delta

    // Fixed time stepping loop
    for accumulator >= deltaTime {
        PhysicsStep()
        accumulator -= deltaTime
    }

    // Record the starting of this frame
    startTime = currentTime
}

SetPhysicsTimeStep :: proc(delta: f64) {
    deltaTime = delta
}

// Finds a valid index for a new manifold initialization
FindAvailableManifoldIndex :: proc() -> int {
    index := -1
    for i := 0; i < MAX_MANIFOLDS; i += 1 {
        currentId := i

        // Check if current id already exist in other physics body
        for k := 0; k < physicsManifoldsCount; k += 1 {
            if contacts[k].id == currentId {
                currentId += 1
                break
            }
        }

        // If it is not used, use it as new physics body id
        if currentId == i {
            index = i
            break
        }
    }

    return index
}

// Creates a new physics manifold to solve collision
CreatePhysicsManifold :: proc(a, b: PhysicsBody) -> PhysicsManifold {
    /*newManifold := (PhysicsManifold)PHYSAC_MALLOC(sizeof(PhysicsManifoldData));*/
    newManifold := new(PhysicsManifoldData)
    usedMemory += size_of(PhysicsManifoldData)

    newId := FindAvailableManifoldIndex()
    if newId != -1 {
        // Initialize new manifold with generic values
        newManifold.id = newId
        newManifold.bodyA = a
        newManifold.bodyB = b
        newManifold.penetration = 0
        newManifold.normal = {}
        newManifold.contacts[0] = {}
        newManifold.contacts[1] = {}
        newManifold.contactsCount = 0
        newManifold.restitution = 0.0
        newManifold.dynamicFriction = 0.0
        newManifold.staticFriction = 0.0

        // Add new body to bodies pointers array and update bodies count
        contacts[physicsManifoldsCount] = newManifold
        physicsManifoldsCount += 1
    } else {
        when ODIN_DEBUG {

            fmt.printf(
                "[PHYSAC] new physics manifold creation failed because there is any available id to use\n",
            )
        }
    }

    return newManifold
}

// Unitializes and destroys a physics manifold
DestroyPhysicsManifold :: proc(
    manifold: PhysicsManifold,
    allocator := context.allocator,
) {
    context.allocator = allocator
    if manifold != nil {
        id := manifold.id
        index := -1

        for i := 0; i < physicsManifoldsCount; i += 1 {
            if contacts[i].id == id {
                index = int(i)
                break
            }
        }

        if index == -1 {
            when ODIN_DEBUG {
                fmt.printf(
                    "[PHYSAC] Not possible to manifold id %i in pointers array\n",
                    id,
                )
            }
            return
        }

        // Free manifold allocated memory
        free(manifold)
        usedMemory -= size_of(PhysicsManifoldData)
        contacts[index] = nil

        // Reorder physics manifolds pointers array and its catched index
        for i := index; i < physicsManifoldsCount; i += 1 {
            if (i + 1) < physicsManifoldsCount {
                contacts[i] = contacts[i + 1]
            }
        }

        // Update physics manifolds count
        physicsManifoldsCount -= 1
    } else {
        when ODIN_DEBUG {
            fmt.printf(
                "[PHYSAC] error trying to destroy a null referenced manifold\n",
            )

        }
    }
}

// Solves a created physics manifold between two physics bodies
SolvePhysicsManifold :: proc(manifold: PhysicsManifold) {
    switch manifold.bodyA.shape.type 
    {
    case .CIRCLE:
        {
            switch manifold.bodyB.shape.type 
            {
            case .CIRCLE:
                SolveCircleToCircle(manifold)
            case .POLYGON:
                SolveCircleToPolygon(manifold)
            case .INVALID:
            }
        }
    case .POLYGON:
        {
            switch manifold.bodyB.shape.type 
            {
            case .CIRCLE:
                SolvePolygonToCircle(manifold)
            case .POLYGON:
                SolvePolygonToPolygon(manifold)
            case .INVALID:
            }
        }
    case .INVALID:
    }

    // Update physics body grounded state if normal direction is down and grounded state is not set yet in previous manifolds
    if !manifold.bodyB.isGrounded {
        manifold.bodyB.isGrounded = (manifold.normal.y < 0)
    }
}

// Solves collision between two circle shape physics bodies
SolveCircleToCircle :: proc(manifold: PhysicsManifold) {
    bodyA := manifold.bodyA
    bodyB := manifold.bodyB

    if (bodyA == nil) || (bodyB == nil) {
        return
    }

    // Calculate translational vector, which is normal
    normal := bodyB.position - bodyA.position

    /*distSqr := MathLenSqr(normal)*/
    distSqr := linalg.length2(normal)
    radius := bodyA.shape.radius + bodyB.shape.radius

    // Check if circles are not in contact
    if distSqr >= radius * radius {
        manifold.contactsCount = 0
        return
    }

    /*distance = sqrtf(distSqr)*/
    distance := math.sqrt(distSqr)
    manifold.contactsCount = 1

    if distance == 0.0 {
        manifold.penetration = bodyA.shape.radius
        manifold.normal = Vector2{1.0, 0.0}
        manifold.contacts[0] = bodyA.position
    } else {
        manifold.penetration = radius - distance
        manifold.normal = Vector2{normal.x / distance, normal.y / distance} // Faster than using MathNormalize() due to sqrt is already performed
        manifold.contacts[0] = Vector2{
            manifold.normal.x * bodyA.shape.radius + bodyA.position.x,
            manifold.normal.y * bodyA.shape.radius + bodyA.position.y,
        }
    }

    // Update physics body grounded state if normal direction is down
    if !bodyA.isGrounded {
        bodyA.isGrounded = (manifold.normal.y < 0)
    }
}

// Solves collision between a circle to a polygon shape physics bodies
SolveCircleToPolygon :: proc(manifold: PhysicsManifold) {
    bodyA := manifold.bodyA
    bodyB := manifold.bodyB

    if (bodyA == nil) || (bodyB == nil) {
        return
    }

    SolveDifferentShapes(manifold, bodyA, bodyB)
}

// Solves collision between a circle to a polygon shape physics bodies
SolvePolygonToCircle :: proc(manifold: PhysicsManifold) {
    bodyA := manifold.bodyA
    bodyB := manifold.bodyB

    if (bodyA == nil) || (bodyB == nil) {
        return
    }

    SolveDifferentShapes(manifold, bodyB, bodyA)

    manifold.normal.x *= -1.0
    manifold.normal.y *= -1.0
}

// Solve collision between two different types of shapes
SolveDifferentShapes :: proc(
    manifold: PhysicsManifold,
    bodyA,
    bodyB: PhysicsBody,
) {
    manifold.contactsCount = 0

    // Transform circle center to polygon transform space
    center := bodyA.position
    center =
        linalg.transpose(bodyB.shape.transform) * (center - bodyB.position)

    // Find edge with minimum penetration
    // It is the same concept as using support points in SolvePolygonToPolygon
    separation := min(f32)
    faceNormal := 0
    vertexData := bodyB.shape.vertexData

    for i := 0; i < vertexData.vertexCount; i += 1 {
        currentSeparation := linalg.dot(
            vertexData.normals[i],
            (center - vertexData.positions[i]),
        )

        if currentSeparation > bodyA.shape.radius {
            return
        }

        if currentSeparation > separation {
            separation = currentSeparation
            faceNormal = int(i)
        }
    }

    // Grab face's vertices
    v1 := vertexData.positions[faceNormal]
    nextIndex := (((faceNormal + 1) < vertexData.vertexCount) ? (faceNormal +
            1) : 0)
    v2 := vertexData.positions[nextIndex]

    // Check to see if center is within polygon
    if separation < EPSILON {
        manifold.contactsCount = 1
        normal := bodyB.shape.transform * vertexData.normals[faceNormal]
        manifold.normal = Vector2{-normal.x, -normal.y}
        manifold.contacts[0] = Vector2{
            manifold.normal.x * bodyA.shape.radius + bodyA.position.x,
            manifold.normal.y * bodyA.shape.radius + bodyA.position.y,
        }
        manifold.penetration = bodyA.shape.radius
        return
    }

    // Determine which voronoi region of the edge center of circle lies within
    dot1 := linalg.dot((center - v1), (v2 - v1))
    dot2 := linalg.dot((center - v2), (v1 - v2))
    manifold.penetration = bodyA.shape.radius - separation

    if dot1 <= 0.0 // Closest to v1
    {
        if linalg.length2(center - v1) >
           bodyA.shape.radius * bodyA.shape.radius {
            return
        }

        manifold.contactsCount = 1
        normal := v1 - center
        normal = bodyB.shape.transform * normal
        normal = linalg.normalize(normal)
        manifold.normal = normal
        v1 = bodyB.shape.transform * v1
        v1 = v1 + bodyB.position
        manifold.contacts[0] = v1
    } else if dot2 <= 0.0 // Closest to v2
    {
        if linalg.length2(center - v2) >
           bodyA.shape.radius * bodyA.shape.radius {
            return
        }

        manifold.contactsCount = 1
        normal := v2 - center
        v2 = bodyB.shape.transform * v2
        v2 = v2 + bodyB.position
        manifold.contacts[0] = v2
        normal = bodyB.shape.transform * normal
        normal = linalg.normalize(normal)
        manifold.normal = normal
    } else // Closest to face
    {
        normal := vertexData.normals[faceNormal]

        if linalg.dot((center - v1), normal) > bodyA.shape.radius {
            return
        }

        normal = bodyB.shape.transform * normal
        manifold.normal = Vector2{-normal.x, -normal.y}
        manifold.contacts[0] = Vector2{
            manifold.normal.x * bodyA.shape.radius + bodyA.position.x,
            manifold.normal.y * bodyA.shape.radius + bodyA.position.y,
        }
        manifold.contactsCount = 1
    }
}

// Solves collision between two polygons shape physics bodies
SolvePolygonToPolygon :: proc(manifold: PhysicsManifold) {
    if (manifold.bodyA == nil) || (manifold.bodyB == nil) {
        return
    }

    bodyA := manifold.bodyA.shape
    bodyB := manifold.bodyB.shape
    manifold.contactsCount = 0

    // Check for separating axis with A shape's face planes
    faceA := 0
    penetrationA := FindAxisLeastPenetration(&faceA, bodyA, bodyB)

    if penetrationA >= 0.0 {
        return
    }

    // Check for separating axis with B shape's face planes
    faceB := 0
    penetrationB := FindAxisLeastPenetration(&faceB, bodyB, bodyA)

    if penetrationB >= 0.0 {
        return
    }

    referenceIndex := 0
    flip := false // Always point from A shape to B shape

    refPoly: PhysicsShape // Reference
    incPoly: PhysicsShape // Incident

    // Determine which shape contains reference face
    if BiasGreaterThan(penetrationA, penetrationB) {
        refPoly = bodyA
        incPoly = bodyB
        referenceIndex = faceA
    } else {
        refPoly = bodyB
        incPoly = bodyA
        referenceIndex = faceB
        flip = true
    }

    // World space incident face
    incidentFace: [2]Vector2
    FindIncidentFace(
        &incidentFace[0],
        &incidentFace[1],
        refPoly,
        incPoly,
        referenceIndex,
    )

    // Setup reference face vertices
    refData := refPoly.vertexData
    v1 := refData.positions[referenceIndex]
    referenceIndex =
    (((referenceIndex + 1) < refData.vertexCount) ? (referenceIndex + 1) : 0)
    v2 := refData.positions[referenceIndex]

    // Transform vertices to world space
    v1 = refPoly.transform * v1
    v1 = v1 + refPoly.body.position
    v2 = refPoly.transform * v2
    v2 = v2 + refPoly.body.position

    // Calculate reference face side normal in world space
    sidePlaneNormal := v2 - v1
    sidePlaneNormal = linalg.normalize(sidePlaneNormal)

    // Orthogonalize
    refFaceNormal := Vector2{sidePlaneNormal.y, -sidePlaneNormal.x}
    refC := linalg.dot(refFaceNormal, v1)
    negSide := linalg.dot(sidePlaneNormal, v1) * -1
    posSide := linalg.dot(sidePlaneNormal, v2)

    // Clip incident face to reference face side planes (due to floating point error, possible to not have required points
    if Clip(
           (Vector2){-sidePlaneNormal.x, -sidePlaneNormal.y},
           negSide,
           &incidentFace[0],
           &incidentFace[1],
       ) <
       2 {
        return

    }

    if Clip(sidePlaneNormal, posSide, &incidentFace[0], &incidentFace[1]) < 2 {
        return
    }

    // Flip normal if required
    manifold.normal =
    (flip ? Vector2{-refFaceNormal.x, -refFaceNormal.y} : refFaceNormal)

    // Keep points behind reference face
    currentPoint := 0 // Clipped points behind reference face
    separation := linalg.dot(refFaceNormal, incidentFace[0]) - refC

    if separation <= 0.0 {
        manifold.contacts[currentPoint] = incidentFace[0]
        manifold.penetration = -separation
        currentPoint += 1
    } else {
        manifold.penetration = 0.0
    }

    separation = linalg.dot(refFaceNormal, incidentFace[1]) - refC

    if separation <= 0.0 {
        manifold.contacts[currentPoint] = incidentFace[1]
        manifold.penetration += -separation
        currentPoint += 1

        // Calculate total penetration average
        manifold.penetration /= f32(currentPoint)
    }

    manifold.contactsCount = currentPoint
}

// Integrates physics forces into velocity
IntegratePhysicsForces :: proc(body: PhysicsBody) {
    if (body == nil) || (body.inverseMass == 0.0) || !body.enabled {
        return
    }

    body.velocity.x += f32(
        f64(body.force.x * body.inverseMass) * (deltaTime / 2.0),
    )
    body.velocity.y += f32(
        f64(body.force.y * body.inverseMass) * (deltaTime / 2.0),
    )

    if body.useGravity {
        body.velocity.x += f32(f64(gravityForce.x) * (deltaTime / 1000 / 2.0))
        body.velocity.y += f32(f64(gravityForce.y) * (deltaTime / 1000 / 2.0))
    }

    if !body.freezeOrient {
        body.angularVelocity += f32(
            f64(body.torque) * f64(body.inverseInertia) * (deltaTime / 2.0),
        )
    }
}

// TODO (phil): Better name for this? Cross product generally only applies to vectors
MathCross :: #force_inline proc(value: f32, vector: Vector2) -> Vector2 {
    return Vector2{-value * vector.y, value * vector.x}
}

// Initializes physics manifolds to solve collisions
InitializePhysicsManifolds :: proc(manifold: PhysicsManifold) {
    bodyA := manifold.bodyA
    bodyB := manifold.bodyB

    if (bodyA == nil) || (bodyB == nil) {
        return
    }

    // Calculate average restitution, static and dynamic friction
    manifold.restitution = linalg.sqrt(bodyA.restitution * bodyB.restitution)
    manifold.staticFriction = linalg.sqrt(
        bodyA.staticFriction * bodyB.staticFriction,
    )
    manifold.dynamicFriction = linalg.sqrt(
        bodyA.dynamicFriction * bodyB.dynamicFriction,
    )

    for i := 0; i < manifold.contactsCount; i += 1 {
        // Caculate radius from center of mass to contact
        radiusA := manifold.contacts[i] - bodyA.position
        radiusB := manifold.contacts[i] - bodyB.position

        crossA := MathCross(bodyA.angularVelocity, radiusA)
        crossB := MathCross(bodyB.angularVelocity, radiusB)

        radiusV := Vector2{}
        radiusV.x = bodyB.velocity.x + crossB.x - bodyA.velocity.x - crossA.x
        radiusV.y = bodyB.velocity.y + crossB.y - bodyA.velocity.y - crossA.y

        // Determine if we should perform a resting collision or not;
        // The idea is if the only thing moving this object is gravity, then the collision should be performed without any restitution
        if linalg.length2(radiusV) <
           (linalg.length2(
                       Vector2{
                           f32(f64(gravityForce.x) * deltaTime / 1000),
                           f32(f64(gravityForce.y) * deltaTime / 1000),
                       },
                   ) +
                   EPSILON) {
            manifold.restitution = 0
        }
    }
}

// Integrates physics collisions impulses to solve collisions
IntegratePhysicsImpulses :: proc(manifold: PhysicsManifold) {
    bodyA := manifold.bodyA
    bodyB := manifold.bodyB

    if (bodyA == nil) || (bodyB == nil) {
        return
    }

    // Early out and positional correct if both objects have infinite mass
    if abs(bodyA.inverseMass + bodyB.inverseMass) <= EPSILON {
        bodyA.velocity = {}
        bodyB.velocity = {}
        return
    }

    for i := 0; i < manifold.contactsCount; i += 1 {
        // Calculate radius from center of mass to contact
        radiusA := manifold.contacts[i] - bodyA.position
        radiusB := manifold.contacts[i] - bodyB.position

        // Calculate relative velocity
        radiusV := Vector2{}
        radiusV.x =
            bodyB.velocity.x +
            MathCross(bodyB.angularVelocity, radiusB).x -
            bodyA.velocity.x -
            MathCross(bodyA.angularVelocity, radiusA).x
        radiusV.y =
            bodyB.velocity.y +
            MathCross(bodyB.angularVelocity, radiusB).y -
            bodyA.velocity.y -
            MathCross(bodyA.angularVelocity, radiusA).y

        // Relative velocity along the normal
        contactVelocity := linalg.dot(radiusV, manifold.normal)

        // Do not resolve if velocities are separating
        if contactVelocity > 0.0 {
            return
        }

        raCrossN := linalg.cross(radiusA, manifold.normal)
        rbCrossN := linalg.cross(radiusB, manifold.normal)

        inverseMassSum :=
            bodyA.inverseMass +
            bodyB.inverseMass +
            (raCrossN * raCrossN) * bodyA.inverseInertia +
            (rbCrossN * rbCrossN) * bodyB.inverseInertia

        // Calculate impulse scalar value
        impulse := -(1.0 + manifold.restitution) * contactVelocity
        impulse /= inverseMassSum
        impulse /= f32(manifold.contactsCount)

        // Apply impulse to each physics body
        impulseV := Vector2{
            manifold.normal.x * impulse,
            manifold.normal.y * impulse,
        }

        if bodyA.enabled {
            bodyA.velocity.x += bodyA.inverseMass * (-impulseV.x)
            bodyA.velocity.y += bodyA.inverseMass * (-impulseV.y)

            if (!bodyA.freezeOrient) {
                bodyA.angularVelocity +=
                    bodyA.inverseInertia *
                    linalg.cross(radiusA, Vector2{-impulseV.x, -impulseV.y})
            }
        }

        if bodyB.enabled {
            bodyB.velocity.x += bodyB.inverseMass * (impulseV.x)
            bodyB.velocity.y += bodyB.inverseMass * (impulseV.y)

            if (!bodyB.freezeOrient) {
                bodyB.angularVelocity +=
                    bodyB.inverseInertia * linalg.cross(radiusB, impulseV)
            }
        }

        // Apply friction impulse to each physics body
        radiusV.x =
            bodyB.velocity.x +
            MathCross(bodyB.angularVelocity, radiusB).x -
            bodyA.velocity.x -
            MathCross(bodyA.angularVelocity, radiusA).x
        radiusV.y =
            bodyB.velocity.y +
            MathCross(bodyB.angularVelocity, radiusB).y -
            bodyA.velocity.y -
            MathCross(bodyA.angularVelocity, radiusA).y

        tangent := Vector2{
            radiusV.x -
            (manifold.normal.x * linalg.dot(radiusV, manifold.normal)),
            radiusV.y -
            (manifold.normal.y * linalg.dot(radiusV, manifold.normal)),
        }

        // NOTE(phil): Handle zero vector as an input to linalg.normalize() resulting in NaN values.
        if !(linalg.length2(tangent) == 0.0) {
            tangent = linalg.normalize(tangent)
        }

        // Calculate impulse tangent magnitude
        impulseTangent := -linalg.dot(radiusV, tangent)
        impulseTangent /= inverseMassSum
        impulseTangent /= f32(manifold.contactsCount)

        absImpulseTangent := abs(impulseTangent)

        // Don't apply tiny friction impulses
        if absImpulseTangent <= EPSILON {
            return
        }

        // Apply coulumb's law
        tangentImpulse := Vector2{}
        if absImpulseTangent < (impulse * manifold.staticFriction) {
            tangentImpulse = Vector2{
                tangent.x * impulseTangent,
                tangent.y * impulseTangent,
            }
        } else {
            tangentImpulse = Vector2{
                tangent.x * -impulse * manifold.dynamicFriction,
                tangent.y * -impulse * manifold.dynamicFriction,
            }
        }

        // Apply friction impulse
        if bodyA.enabled {
            bodyA.velocity.x += bodyA.inverseMass * (-tangentImpulse.x)
            bodyA.velocity.y += bodyA.inverseMass * (-tangentImpulse.y)

            if !bodyA.freezeOrient {
                bodyA.angularVelocity +=
                    bodyA.inverseInertia *
                    linalg.cross(
                            radiusA,
                            Vector2{-tangentImpulse.x, -tangentImpulse.y},
                        )
            }
        }

        if bodyB.enabled {
            bodyB.velocity.x += bodyB.inverseMass * (tangentImpulse.x)
            bodyB.velocity.y += bodyB.inverseMass * (tangentImpulse.y)

            if !bodyB.freezeOrient {
                bodyB.angularVelocity +=
                    bodyB.inverseInertia *
                    linalg.cross(radiusB, tangentImpulse)
            }
        }
    }
}

// TODO: Anything in core to replace this?
// Set values from radians to a created matrix 2x2
Mat2Set :: proc(mat: ^Mat2, radians: f32) {
    cos := linalg.cos(radians)
    sin := linalg.sin(radians)

    mat[0, 0] = cos
    mat[0, 1] = -sin
    mat[1, 0] = sin
    mat[1, 1] = cos
}
// Integrates physics velocity into position and forces
IntegratePhysicsVelocity :: proc(body: PhysicsBody) {
    if (body == nil) || !body.enabled {
        return
    }

    body.position.x += f32(f64(body.velocity.x) * deltaTime)
    body.position.y += f32(f64(body.velocity.y) * deltaTime)

    if !body.freezeOrient {
        body.orient += f32(f64(body.angularVelocity) * deltaTime)
    }


    Mat2Set(&body.shape.transform, body.orient)

    IntegratePhysicsForces(body)
}

// Corrects physics bodies positions based on manifolds collision information
CorrectPhysicsPositions :: proc(manifold: PhysicsManifold) {
    bodyA := manifold.bodyA
    bodyB := manifold.bodyB

    if (bodyA == nil) || (bodyB == nil) {
        return
    }

    correction := Vector2{}
    correction.x =
        (max(manifold.penetration - PENETRATION_ALLOWANCE, 0.0) /
            (bodyA.inverseMass + bodyB.inverseMass)) *
        manifold.normal.x *
        PENETRATION_CORRECTION
    correction.y =
        (max(manifold.penetration - PENETRATION_ALLOWANCE, 0.0) /
            (bodyA.inverseMass + bodyB.inverseMass)) *
        manifold.normal.y *
        PENETRATION_CORRECTION

    if bodyA.enabled {
        bodyA.position.x -= correction.x * bodyA.inverseMass
        bodyA.position.y -= correction.y * bodyA.inverseMass
    }

    if bodyB.enabled {
        bodyB.position.x += correction.x * bodyB.inverseMass
        bodyB.position.y += correction.y * bodyB.inverseMass
    }
}

// Returns the extreme point along a direction within a polygon
GetSupport :: proc(shape: PhysicsShape, dir: Vector2) -> Vector2 {
    bestProjection := min(f32)
    /*bestProjection := -FLOAT_MAX*/
    bestVertex := Vector2{}
    data := shape.vertexData

    for i := 0; i < data.vertexCount; i += 1 {
        vertex := data.positions[i]
        projection := linalg.dot(vertex, dir)

        if projection > bestProjection {
            bestVertex = vertex
            bestProjection = projection
        }
    }

    return bestVertex
}
// Finds polygon shapes axis least penetration
FindAxisLeastPenetration :: proc(
    faceIndex: ^int,
    shapeA,
    shapeB: PhysicsShape,
) -> f32 {
    bestDistance := min(f32)
    bestIndex := 0

    dataA := shapeA.vertexData

    for i := 0; i < dataA.vertexCount; i += 1 {
        // Retrieve a face normal from A shape
        normal := dataA.normals[i]
        transNormal := shapeA.transform * normal

        // Transform face normal into B shape's model space
        buT := linalg.transpose(shapeB.transform)
        normal = buT * transNormal

        // Retrieve support point from B shape along -n
        support := GetSupport(shapeB, Vector2{-normal.x, -normal.y})

        // Retrieve vertex on face from A shape, transform into B shape's model space
        vertex := dataA.positions[i]
        vertex = shapeA.transform * vertex
        vertex = vertex + shapeA.body.position
        vertex = vertex - shapeB.body.position
        vertex = buT * vertex

        // Compute penetration distance in B shape's model space
        distance := linalg.dot(normal, (support - vertex))

        // Store greatest distance
        if distance > bestDistance {
            bestDistance = distance
            bestIndex = int(i)
        }
    }

    faceIndex^ = bestIndex
    return bestDistance
}

// Finds two polygon shapes incident face
FindIncidentFace :: proc(
    v0,
    v1: ^Vector2,
    ref,
    inc: PhysicsShape,
    index: int,
) {
    refData := ref.vertexData
    incData := inc.vertexData

    referenceNormal := refData.normals[index]

    // Calculate normal in incident's frame of reference
    referenceNormal = ref.transform * referenceNormal // To world space
    referenceNormal = linalg.transpose(inc.transform) * referenceNormal // To incident's model space

    // Find most anti-normal face on polygon
    incidentFace := 0
    minDot := max(f32)

    for i := 0; i < incData.vertexCount; i += 1 {
        dot := linalg.dot(referenceNormal, incData.normals[i])

        if dot < minDot {
            minDot = dot
            incidentFace = int(i)
        }
    }

    // Assign face vertices for incident face
    v0^ = inc.transform * incData.positions[incidentFace]
    v0^ = v0^ + inc.body.position
    incidentFace =
    (((incidentFace + 1) < incData.vertexCount) ? (incidentFace + 1) : 0)
    v1^ = inc.transform * incData.positions[incidentFace]
    v1^ = v1^ + inc.body.position
}

// Calculates clipping based on a normal and two faces
Clip :: proc(normal: Vector2, clip: f32, faceA, faceB: ^Vector2) -> int {
    sp := 0
    out := [2]Vector2{faceA^, faceB^}

    // Retrieve distances from each endpoint to the line
    distanceA := linalg.dot(normal, faceA^) - clip
    distanceB := linalg.dot(normal, faceB^) - clip

    // If negative (behind plane)
    if distanceA <= 0.0 {
        /*out[sp++] = ^faceA*/
        out[sp] = faceA^
        sp += 1
    }

    if distanceB <= 0.0 {
        /*out[sp++] = *faceB;*/
        out[sp] = faceB^
        sp += 1
    }

    // If the points are on different sides of the plane
    if (distanceA * distanceB) < 0.0 {
        // Push intersection point
        alpha := distanceA / (distanceA - distanceB)
        out[sp] = faceA^
        delta := faceB^ - faceA^
        delta.x *= alpha
        delta.y *= alpha
        out[sp] = out[sp] + delta
        sp += 1
    }

    // Assign the new converted values
    faceA^ = out[0]
    faceB^ = out[1]

    return sp
}

// Check if values are between bias range
BiasGreaterThan :: proc(valueA, valueB: f32) -> bool {
    return (valueA >= (valueB * 0.95 + valueA * 0.01))
}

// Creates a matrix 2x2 from a given radians value
Mat2Radians :: proc(radians: f32) -> Mat2 {
    c := math.cos(radians)
    s := math.sin(radians)

    return Mat2{c, -s, s, c}
}

// Returns the barycenter of a triangle given by 3 points
TriangleBarycenter :: proc(v1, v2, v3: Vector2) -> Vector2 {
    result := Vector2{}

    result.x = (v1.x + v2.x + v3.x) / 3
    result.y = (v1.y + v2.y + v3.y) / 3

    return result
}

InitTimer :: proc() {
    baseTime = time.now()
    startTime = time.now()
}