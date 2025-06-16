# Rayl
3D camera rail system featuring smooth path interpolation and mouse look controls.

## Overview

Rayl demonstrates a camera system that follows a predefined 3D path while allowing free-look mouse controls. 
The camera smoothly interpolates between waypoints using spline-based movement, creating a rail-like experience 
similar to scripted sequences in games or architectural walkthroughs.

## Features

- **Rail Camera System**: Automatic movement along a predefined 3D path
- **Mouse Look Controls**: Free-look camera rotation with configurable sensitivity
- **Smooth Interpolation**: Vector3 lerping for seamless path transitions
- **Cross-Platform**: Native Windows builds and WebAssembly for browsers
- **Real-time Debug Info**: On-screen display of camera state and timing

## Controls

- **Mouse**: Look around (yaw and pitch rotation)
- **F9**: Toggle cursor capture on/off
