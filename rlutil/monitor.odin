package rlutil

import "vendor:glfw"
import "vendor:raylib"

// Set raylib window to primary monitor
set_window_to_primary_monitor :: proc(setFps: bool = false, fullscreen: bool = false) {
	assert(raylib.GetMonitorCount() > 0, "Error: No monitors detected")

	monitorIndex := get_primary_monitor()
	assert(monitorIndex >= 0, "Error: No primary monitor detected")

	if setFps {raylib.SetTargetFPS(raylib.GetMonitorRefreshRate(monitorIndex))}
	if fullscreen {
		p := get_primary_monitor()
		monitor_position := raylib.GetMonitorPosition(p)
		raylib.SetWindowPosition(i32(monitor_position.x), i32(monitor_position.y))
		raylib.SetWindowState({.WINDOW_MAXIMIZED, .WINDOW_RESIZABLE})
		raylib.SetWindowState({.WINDOW_MAXIMIZED})
		raylib.ToggleFullscreen()
	}
	raylib.SetWindowMonitor(monitorIndex)
}

// Returns the index of the primary monitor
get_primary_monitor :: proc() -> i32 {
	for i in 0 ..< raylib.GetMonitorCount() {
		if string(raylib.GetMonitorName(i)) == glfw.GetMonitorName(glfw.GetPrimaryMonitor()) {
			return i
		}
	}
	return -1
}

VideoMode :: struct { width, height, refresh_rate: int }

Monitor :: struct {
	index:    int,
	modes:    [dynamic]VideoMode,
	name:     string,
	position: [2]i32,
	primary:  bool,
}

get_monitor_properties :: proc() -> []Monitor {
	handle := glfw.GetMonitors()
	defer delete(handle)

	primary_handle := glfw.GetPrimaryMonitor()
	primary_name := glfw.GetMonitorName(primary_handle)

	monitors: [dynamic]Monitor
	defer delete(monitors)

	for i in 0 ..< len(handle) {
		monitor := Monitor{}
		monitor.modes = [dynamic]VideoMode{}
		mh := glfw.GetVideoModes(handle[i])
		defer delete(mh)
		monitor.name = glfw.GetMonitorName(handle[i])
		monitor.primary = monitor.name == primary_name
		monitor.index = i
		x, y := glfw.GetMonitorPos(handle[i])
		monitor.position = [2]i32{x, y}
		for j in 0 ..< len(mh) {
			append(
				&monitor.modes,
				VideoMode {
					width = int(mh[j].width),
					height = int(mh[j].height),
					refresh_rate = int(mh[j].refresh_rate),
				},
			)
		}
		append(&monitors, monitor)
	}
	return monitors[:]
}