# Voxel Space

This is an attempt at implementing voxel space from scratch using Raylib. The player or the camera can move forward, rotate, lift up and down, tilt left, right, front and back.
I have also tried to add fog effect using two different methods.
The rendered worlds look something like this:

https://github.com/djmgit/voxel_space/assets/16368427/20eb69ed-96bf-4ddb-a4a2-85214f3da049

## What is Voxel space?
Created by Novalogic developer Kyle Freeman ( <a href="https://patents.google.com/patent/US6020893"> patent </a>), this first of it's kind algorithm was used to create the signature game Comanche.
Voxel space renders graphics pixel by pixel on screen while casting rays from the camera location outwards by:
- a color map of each pixel in the terrain
- a height map defining the height each pixel has on screen

## How to build and run

- Run ```odin run .``` for running the project.

## Controls:

Up arraow  - Move front

Down arrow - Move down

W          - Tilt camera up

S          - Title camera down

Q          - Lift camera up

E          - Bring camera down

A          - Tilt camera on left

D          - Tilt camera on right

## Fog
Fog is a useful tool to hide clipping of the graphics at the far end of the z axis. Comes with two different
<a href="https://learn.microsoft.com/en-us/windows/win32/direct3d9/fog-formulas">fog implementations</a> :

- Linear: Which takes into consideration where the fog starts and ends.
- Exponential: Which applies a damping factor on the original color of the pixel as the z distance from camera increases.

## References

- Ported to Odin from [github.com/djmgit/voxel_space](https://github.com/djmgit/voxel_space)
- Video tutorial by Pikuma: https://www.youtube.com/watch?v=bQBY9BM9g_Y&t=3270s . He has explained Voxel space with great detail, one of the best videos for voxel space explanation out on Internet.
- Voxel space expanation by Sebastian Mackle: https://github.com/s-macke/VoxelSpace .
- Codermind article: https://web.archive.org/web/20131113094653/http://www.codermind.com/articles/Voxel-terrain-engine-building-the-terrain.html
- Article describing voxel culling optimizations: https://nickmcd.me/2021/04/04/high-performance-voxel-engine/

