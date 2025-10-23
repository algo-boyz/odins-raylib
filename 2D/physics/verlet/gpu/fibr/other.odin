#+build js, wasi, orca
package fibr

OS_Thread :: struct {}

_os_thread_init :: proc(os_t: ^OS_Thread, data: ^Data) {
	unimplemented("thread procedure not supported on target")
}

_os_thread_join :: proc(os_t: ^OS_Thread) {
	unimplemented("thread procedure not supported on target")
}

_os_thread_detach :: proc(os_t: ^OS_Thread) {
	unimplemented("thread procedure not supported on target")
}
