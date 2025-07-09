package fibr

import "base:runtime"

Thread :: struct {
	os_thread: OS_Thread,
	data:      ^Data,
}

Data :: struct {
	fn:  proc(_: rawptr),
	arg: rawptr,
}

ctx: runtime.Context

spawn :: proc(t: ^Thread, fn: proc(_: rawptr), arg: rawptr) {
	ctx = context
	data := new(Data)
	data.fn = fn
	data.arg = arg
	t.data = data
	_init(&t.os_thread, data)
}

join :: proc(t: ^Thread) {
	_join(&t.os_thread)
	free(t.data)
}

detach :: proc(t: ^Thread) {
	_detach(&t.os_thread)
}
