package main

import "core:fmt"
import "core:log"
import "core:strings"
import "../"

worker :: proc(arg: rawptr) {
	n := cast(^u32)arg
	n^ = 42
	// alloc will break if ctx is passed wrong
	bla := make(map[int]string)
	defer delete(bla)
	s := strings.clone("blabla")
	defer delete(s)
	bla[5] = s
}

main :: proc() {
	thread: fibr.Thread
	// NOTE: stack not shared between threads
	// if main dies and another tries
	// to read the stack, it will blow
	arg := new(u32)
	arg^ = 0
	fibr.spawn(&thread, worker, arg)
	fibr.join(&thread)
	// or
	// fibr.detach(&thread)
	assert(arg^ == 42)
	fmt.printf("Thread finished with: %d\n", arg^)
}
