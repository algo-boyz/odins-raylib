# Odin L-system
This code is a simple example of creating L-system strings and plants.

## Example Usage

Provide an axiom (Start string)

```odin
  lsystem := create_lsystem(6, "X")
  defer delete(lsystem)
```
you can add new rules or change them like this in `lsystem.odin`

```odin
Rules := [][]string{
    {"F", "FF"},
    {"X", "F[/+X]F[-X]+X"}
}
```

Use the lsystem string to generate a mesh with defined parameters

```odin
draw_lystem :: proc(instructions: string, distance, angle: f32, start_pos: [3]f32, angles: [2]f32)
```
example use of draw_lsystem

```odin
meshes := draw_lystem(lsystem, 0.2, 35, {0,0,0}, {90,90})
defer delete(meshes)
```
you can then use that array of details for whatever you want here's an example with Raylib

```odin
rl.InitWindow(1920, 1080, "L-System")
    rl.SetTargetFPS(60)

    cam := rl.Camera3D{
        position ={10,20,10}, 
        target = {0, 15,0},
        up =  {0,1,0},
        fovy =  90,
    }

    for !rl.WindowShouldClose() {
        rl.UpdateCamera(&cam, .ORBITAL);

        rl.BeginDrawing()
        rl.ClearBackground(rl.RAYWHITE)
        rl.BeginMode3D(cam)

        rl.DrawGrid(10, 1)

        for mesh in meshes {
            rl.DrawCylinderEx(mesh.start, mesh.end, 0.1, 0.1, 6, rl.GREEN)
        }

	    rl.EndMode3D()
        rl.EndDrawing()
    }

    rl.CloseWindow()
```
