# FiniteStateMachine (C++ with Raylib)

This project demonstrates a Non-Player Character (NPC) using a Finite State Machine (FSM) to switch between two AI behaviors: **Wander** and **Follow**.  The demo is written in C++ using Raylib for rendering and integrates Dijkstra’s algorithm ('DijkstrasPathfinding' project) for pathfinding between nodes on a grid.

---

## AI Architecture

### Behaviors Implemented

1. **WanderBehaviour**  
   - Agent moves randomly to new nodes on the grid.
   - Behavior triggers when the player is *farther than 120 units*.

2. **FollowBehaviour**  
   - Agent pursues a target agent by recalculating a path when the target moves.
   - Behavior triggers when the player is *closer than 90 units*.

##  Agent Overview

| Agent        | Color      | Behavior         |
|--------------|------------|------------------|
| Player       | Green      | Controlled via mouse clicks |
| Wanderer     | Blue       | Wanders randomly |
| FSM Agent    | Yellow/Red | Switches between wander (yellow) and follow (red) |

---

##  Controls

| Input        | Action                                   |
|--------------|------------------------------------------|
| Left Click   | Sets the **start node** for player agent  |
| Right Click  | Sets the **end node** for player agent   |
| ESC          | Exit the program                         |
