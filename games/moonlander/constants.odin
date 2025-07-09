package main

import rl "vendor:raylib"

// Constants
MAX_FUEL_CONSUMPTION :: 20.0
INITIAL_GRAVITY :: 1.0
MAX_GRAVITY :: 2.0
INITIAL_VELOCITY_LIMIT :: 0.8
MUSIC_VOLUME :: 1.0

// Colors
black :: rl.Color{0, 0, 0, 255}
grey :: rl.Color{29, 29, 27, 255}
yellow :: rl.Color{243, 216, 63, 255}

// Window and Game Screen
window_width :: 1920
window_height :: 1080
screen_width :: 960
screen_height :: 540

// State Flags
exit_requested := false
exit_window := false

border_offset_width :: 20.0
border_offset_height :: 50.0
offset :: 110

// Debug flags (can be set via build command or environment)
// For example: odin build . -define:GAME_DEBUG=true
DEBUG :: #config(GAME_DEBUG, false) 
DEBUG_COLLISION :: #config(GAME_DEBUG_COLLISION, false)