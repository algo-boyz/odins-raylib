package main

import "core:fmt"
import "core:math"
import "core:math/rand"
import "core:slice"
import rl "vendor:raylib"
import "../../../rlutil/noise"

CUBE_SIZE :: 1.0;
TERRAIN_SIZE :: 400;

// Cube holds the data for a single cube in the world.
Cube :: struct {
	pos: rl.Vector3,
	color:    rl.Color,
}

/*
  Checks if the cube is visible on screen.
 
  This is a simple form of frustum culling that checks if the cube's projected
  2D screen coordinates are within the window bounds. It doesn't account for
  objects being behind the camera but still projecting onto the screen.
 
  @param c A pointer to the cube instance.
  @param camera The camera viewing the scene.
  @return true if the cube is on screen, false otherwise.
 */
is_cube_visible :: proc(c: ^Cube, camera: rl.Camera) -> bool {
	// Project the cube's 3D world pos to 2D screen coordinates.
	cube_screen_pos := rl.GetWorldToScreen(c.pos, camera)

	// Check if the projected pos is outside the screen dimensions.
	if cube_screen_pos.x < 0 || cube_screen_pos.x > cast(f32)rl.GetScreenWidth() ||
	   cube_screen_pos.y < 0 || cube_screen_pos.y > cast(f32)rl.GetScreenHeight() {
		return false
	}
	// TODO: A more robust check would also consider the distance from the camera's near plane.
	// We can check if the cube is behind the camera by projecting the camera's forward vector
	// and the vector from the camera to the cube, then taking the dot product.
	
	// Vector from camera to cube
	to_cube := c.pos - camera.position
	// Camera forward vector
	forward := rl.Vector3Normalize(camera.target - camera.position)
	
	// If the dot product is negative, the cube is behind the camera.
	if rl.Vector3DotProduct(forward, to_cube) < 0 {
		return false
	}
	return true // The cube is visible.
}

main :: proc() {
	seed: u64 = 21 // Set a seed for reproducibility.
	pn := noise.perlin_noise_init_with_seed(seed)

	rl.SetConfigFlags({.WINDOW_RESIZABLE, .MSAA_4X_HINT, .WINDOW_HIGHDPI})
	rl.InitWindow(800 * 2, 450 * 2, "FOV")
	defer rl.CloseWindow()

	camera: rl.Camera
	camera.position     = {30.0, 20.0, 30.0}
	camera.target       = {0.0, 0.0, 0.0}
	camera.up           = {0.0, 1.0, 0.0}
	camera.fovy         = 45.0
	camera.projection   = .PERSPECTIVE

	cubes := make([dynamic]Cube)

	fmt.printf("Generating terrain...\n")

	for x in 0..<TERRAIN_SIZE {
		for y in 0..<TERRAIN_SIZE {
			// Generate a noise value for the current (x, y) coordinate.
			// The values are scaled to make the terrain more varied.
			freq := 10.0
			nf := noise.perlin_noise(&pn, cast(f64)x / (cast(f64)TERRAIN_SIZE/freq), cast(f64)y / (cast(f64)TERRAIN_SIZE/freq))
			// Calculate the cube's height
			// We map the noise value [-1, 1] to a height range.
			height := cast(f32)math.round(nf * 10)
			// Create the cube.
			cube: Cube
			cube.pos = {
				(cast(f32)x - cast(f32)TERRAIN_SIZE/2) * CUBE_SIZE,
				height * CUBE_SIZE,
				(cast(f32)y - cast(f32)TERRAIN_SIZE/2) * CUBE_SIZE,
			}
			// Color the cube based on its height.
			// We map the noise value to green and blue channels for a nice gradient.
			green := cast(u8)math.round(150 * (nf + 1) / 2) + 50
			blue := cast(u8)math.round(200 * (nf + 1) / 2) + 55
			cube.color = {10, green, blue, 255}
			
			// Add the new cube to our dynamic array.
			append(&cubes, cube)
		}
	}
	fmt.printf("Generated %v cubes.\n", len(cubes))
	rl.SetTargetFPS(60)

	for !rl.WindowShouldClose() {
		rl.UpdateCamera(&camera, .FIRST_PERSON)

		rl.BeginDrawing()
		rl.ClearBackground(rl.RAYWHITE)
        {
            visible_cubes := 0
            rl.BeginMode3D(camera)
            {
                // Iterate through all cubes and draw only the visible ones.
                // We iterate by pointer (&cube) to avoid making a copy of each cube.
                for &cube in cubes {
                    if is_cube_visible(&cube, camera) {
                        visible_cubes += 1
                        rl.DrawCube(cube.pos, CUBE_SIZE, CUBE_SIZE, CUBE_SIZE, cube.color)
                    }
                }
            }
            rl.EndMode3D() 

            // Draw a grid on the scene.
            rl.DrawGrid(TERRAIN_SIZE/10, 10.0)

            // Display the number of visible cubes and total cubes.
            visible_text := fmt.ctprintf("Visible Cubes: %v / %v", visible_cubes, len(cubes))
            rl.DrawText(visible_text, 10, 10, 20, rl.BLACK)
            
            // Display the current seed.
            seed_text := fmt.ctprintf("Seed: %v", seed)
            rl.DrawText(seed_text, 10, 40, 20, rl.BLACK)
            rl.DrawFPS(10, 70)
        }
        rl.EndDrawing()
	}
}
