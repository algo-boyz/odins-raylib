#+build windows
package fibr

import win32 "core:sys/windows"

OS_Thread :: struct {
	// order relevant because of padding
	id:     win32.DWORD,
	handle: win32.HANDLE,
}

wrapper_fn :: proc "stdcall" (arg: win32.LPVOID) -> win32.DWORD {
	context = ctx
	data := cast(^Data)arg
	data.fn(data.arg)
	return 0
}

_init :: proc(t: ^OS_Thread, data: ^Data) {
	t.handle = win32.CreateThread(nil, 0, wrapper_fn, data, 0, &t.id)
	assert(t.handle != nil)
}

_join :: proc(t: ^OS_Thread) {
	win32.WaitForSingleObject(t.handle, win32.INFINITE)
	win32.CloseHandle(t.handle)
}

_detach :: proc(t: ^OS_Thread) {
	win32.WaitForSingleObject(t.handle, 0)
	win32.CloseHandle(t.handle)
}
