package environment

import rl "vendor:raylib"

// --- Environment Constants ---
GRID_SIZE: i32 = 10
TILE_SIZE: f32 = 2.0
OBSTACLE_RADIUS: f32 = 0.5
OBSTACLE_HEIGHT: f32 = 2.0

// Obstacle defines a cylindrical obstacle with a position and radius.
Obstacle :: struct {
    position: rl.Vector3,
    radius: f32,
}

// A dynamic array to hold all obstacles in the scene.
obstacles: [dynamic]Obstacle

// Initialize the obstacles. This is called implicitly when the package is loaded.
@(init)
init_obstacles :: proc() {
    // Use a fixed-size array literal to define the obstacles,
    // then append them to the dynamic array.
    initial_obstacles := []Obstacle{
        {{2 * TILE_SIZE, OBSTACLE_HEIGHT / 2.0, 3 * TILE_SIZE}, OBSTACLE_RADIUS},
        {{-1 * TILE_SIZE, OBSTACLE_HEIGHT / 2.0, -4 * TILE_SIZE}, OBSTACLE_RADIUS},
        {{0 * TILE_SIZE, OBSTACLE_HEIGHT / 2.0, 0 * TILE_SIZE}, OBSTACLE_RADIUS},
        {{4 * TILE_SIZE, OBSTACLE_HEIGHT / 2.0, -2 * TILE_SIZE}, OBSTACLE_RADIUS},
        {{-3 * TILE_SIZE, OBSTACLE_HEIGHT / 2.0, 1 * TILE_SIZE}, OBSTACLE_RADIUS},
        {{1 * TILE_SIZE, OBSTACLE_HEIGHT / 2.0, -6 * TILE_SIZE}, OBSTACLE_RADIUS},
        {{-5 * TILE_SIZE, OBSTACLE_HEIGHT / 2.0, -1 * TILE_SIZE}, OBSTACLE_RADIUS},
        {{3 * TILE_SIZE, OBSTACLE_HEIGHT / 2.0, 4 * TILE_SIZE}, OBSTACLE_RADIUS},
        {{-8 * TILE_SIZE, OBSTACLE_HEIGHT / 2.0, 4 * TILE_SIZE}, OBSTACLE_RADIUS},
        {{8 * TILE_SIZE, OBSTACLE_HEIGHT / 2.0, 5 * TILE_SIZE}, OBSTACLE_RADIUS},
        {{3 * TILE_SIZE, OBSTACLE_HEIGHT / 2.0, -9 * TILE_SIZE}, OBSTACLE_RADIUS},
        {{7 * TILE_SIZE, OBSTACLE_HEIGHT / 2.0, -7 * TILE_SIZE}, OBSTACLE_RADIUS},
        {{6 * TILE_SIZE, OBSTACLE_HEIGHT / 2.0, 6 * TILE_SIZE}, OBSTACLE_RADIUS},
    }
    
    // Reserve memory for efficiency and append all initial obstacles.
    reserve(&obstacles, len(initial_obstacles))
    for obs in initial_obstacles {
        append(&obstacles, obs)
    }
}

// draw_environment renders the checkerboard grid and all obstacles.
draw_environment :: proc() {
    // Draw the checkerboard grid (now handled by DrawGrid in main)
    // You could draw it here as well if you prefer.
    
    // Draw each obstacle from the dynamic array.
    for obs in obstacles {
        rl.DrawCylinder(obs.position, obs.radius, obs.radius, OBSTACLE_HEIGHT, 16, rl.RED)
        // Draw a wireframe to make the cylinder more visible
        rl.DrawCylinderWires(obs.position, obs.radius, obs.radius, OBSTACLE_HEIGHT, 16, rl.DARKGRAY)
    }
}
