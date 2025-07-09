package memtrack

import "base:runtime"
import "core:fmt"
import "core:log"
import "core:mem"

MemoryTracker :: struct {
    default: runtime.Allocator,
    tracking: mem.Tracking_Allocator
}

init ::  proc(m: ^MemoryTracker, default_allocator: runtime.Allocator) -> runtime.Allocator {
    m.default = default_allocator
    mem.tracking_allocator_init(&m.tracking, m.default) 
    return mem.tracking_allocator(&m.tracking)
}

terminate :: proc(m: ^MemoryTracker) {
    clear(m)
}

clear :: proc(m: ^MemoryTracker) {
    mem.tracking_allocator_clear(&m.tracking)
}

check_leaks :: proc(m: ^MemoryTracker) -> bool {
    err := false

    if len(m.tracking.allocation_map) > 0 {
        fmt.eprintfln("===== Allocations not freed: %v =====", len(m.tracking.allocation_map))
        for _, entry in m.tracking.allocation_map {
            fmt.eprintfln(" - %v bytes at %v", entry.size, entry.location)
        }
    }
    if len(m.tracking.bad_free_array) > 0 {
        fmt.eprintfln("===== Bad frees: %v =====", len(m.tracking.bad_free_array))
        for entry in m.tracking.bad_free_array {
            fmt.eprintfln(" = %p at @%v", entry.memory, entry.location)
        }
    }

    return err
}

panic_if_leaks :: proc(m: ^MemoryTracker) {
    if check_leaks(m) {
        log.panicf("Memory leaked!")
    }
}

check_bad_frees :: proc(m: ^MemoryTracker) -> bool {
    err := false

    for value in m.tracking.bad_free_array {

        log.errorf("Bad free at: %v\n", value.location)
        err = true
    }

    return err
}

panic_if_bad_frees :: proc(m: ^MemoryTracker) {
    if check_bad_frees(m) {
        log.panicf("\nBad free!")
    }
}

panic_if_bad_frees_or_leaks :: proc(m: ^MemoryTracker) {
    panic_if_bad_frees(m)
    panic_if_leaks(m)
}