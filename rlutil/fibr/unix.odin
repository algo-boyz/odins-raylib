// #+build darwin, linux, freebsd, openbsd, netbsd, haiku
package fibr

import "core:sys/posix"

OS_Thread :: struct {
	handle: posix.pthread_t,
}

wrapper_fn :: proc "c" (arg: rawptr) -> rawptr {
	context = ctx

	data := cast(^Data)arg
	data.fn(data.arg)
	return nil
}

_init :: proc(os_t: ^OS_Thread, data: ^Data) {
	res := posix.pthread_create(&os_t.handle, nil, wrapper_fn, data)
	assert(res == posix.Errno.NONE)
}

_join :: proc(os_t: ^OS_Thread) {
	res := posix.pthread_join(os_t.handle, nil)
	assert(res == posix.Errno.NONE)
}

_detach :: proc(os_t: ^OS_Thread) {
	res := posix.pthread_detach(os_t.handle)
	assert(res == posix.Errno.NONE)
}
