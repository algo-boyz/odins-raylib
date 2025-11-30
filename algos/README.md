### [Algorithms by Jeff Erickson](https://jeffe.cs.illinois.edu/teaching/algorithms/)

1. **Quadtree**

<p align="center">
  <a href="trees/quad/main.odin">
    <img src="trees/quad/preview.gif" alt="quad" width="960">
  </a>
</p>

Quadtree stands out as a pivotal data structure, especially in 2D game development. It excels at spatial partitioning, efficiently organizing and searching for objects in a hierarchical tree structure. This enhances critical aspects such as collision detection and rendering, contributing to smoother gameplay experiences.

2. **Octree**

Extending the concept of the quadtree into three-dimensional space, the octree is a crucial asset for 3D game development. It efficiently organizes and queries objects within a three-dimensional environment, proving indispensable for managing complex scenes and optimizing rendering processes.

3. **(A Star) Algorithms**

<p align="center">
  <a href="astar/README.md">
    <img src="astar/naive/assets/preview.gif" alt="a_star" width="960">
  </a>
</p>

A* is a versatile pathfinding algorithm that serves as the backbone for determining optimal paths between points in game environments. Its applications range from ensuring intelligent NPC movement to facilitating efficient player navigation, enhancing overall gameplay and user experience.

4. **Bit-Matrix Transpose**

<p align="center">
  <a href="bit_matrix/README.md">
    <img src="bit_matrix/demo/preview.gif" alt="naive_a_star" width="960">
  </a>
</p>
<hr>

Optimized algo to transpose a square bit-matrix, by swapping bits across top-right to bottom-left diagonally.
Taking advantage of [Binary Code Modulation](http://www.batsocks.co.uk/readme/art_bcm_1.htm). This technique allows the value of a cpu register to control the duty-cycle. Only requiring a single hardware timer to control multiple outputs. Super fast and efficient.

5. **Bloom**

<hr>
<p align="center">
  <a href="bloom/main.odin">
    <img src="bloom/assets/preview.png" alt="bloom" width="960">
  </a>
</p>

[Next Generation Post Processing in Call of Duty](https://www.iryoku.com/next-generation-post-processing-in-call-of-duty-advanced-warfare/) by Jorge Jimenez introduced a type of [Physics Based Bloom](https://learnopengl.com/Guest-Articles/2022/Phys.-Based-Bloom) that is both computationally efficient and looks really good for most use-cases.

6. **Collision Detection Algorithms**

Various collision detection algorithms such as Separating Axis Theorem (SAT) and Gilbert–Johnson–Keerthi (GJK) are fundamental for realistic interactions between game entities. They are crucial for detecting and resolving collisions, ensuring accurate and engaging gameplay.

7. **Entity Component System**

<p align="center">
  <a href="ecs/octree/main.odin">
    <img src="ecs/assets/preview.gif" alt="ecs" width="960">
  </a>
</p>
<hr>

8. **Flood Fill** 


9. **Marching Squares**

<p align="center">
  <a href="marching/demo/main.odin">
    <img src="marching/demo/preview.gif" alt="marching_squares" width="960">
  </a>
</p>
<hr>

10. **Rule 30**

<p align="center">
  <a href="rule30/main.odin">
    <img src="rule30/preview.gif" alt="rule30" width="960">
  </a>
</p>
<hr>


11. **Wave Function Collapse** 
WFC (Wave Function Collapse) is a type of PCG (Procedural Contents Generation) algorithm that analyzes the connectivity patterns of source material to generate output with identical connectivity relationships. Texture Synthesis is the general term for this technique, which creates large result images from small source images.

[Nurikabe Map Generation with WFC algorithm](https://sublevelgames.github.io/blogs/2025-06-22-nurikabe-map-gen-with-wfc/) Captcha solver