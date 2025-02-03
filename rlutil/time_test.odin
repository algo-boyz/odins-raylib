package rlutil

import "core:fmt"
import tt "core:testing"
import "core:time"

@(test)
test_clock_from_nano :: proc(t: ^tt.T) {
    nsec := i64(3661000000000) // 1 hour, 1 minute, 1 second, 0 milliseconds
    hour, min, sec, ms := clock_from_nano(nsec)
    tt.expect(t, hour == 1, "Expected 1 hour, got")
    tt.expect(t, min == 1, "Expected 1 minute, got")
    tt.expect(t, sec == 1, "Expected 1 second, got")
    tt.expect(t, ms == 0, "Expected 0 milliseconds, got")
}

@(test)
test_clock_from_nano_ex :: proc(t: ^tt.T) {
    nsec := i64(90061000000000) // 1 day, 1 hour, 1 minute, 1 second, 0 milliseconds
    day, hour, min, sec, ms := clock_from_nano_ex(nsec)
    tt.expect(t, day == 1, "Expected 1 day, got")
    tt.expect(t, hour == 1, "Expected 1 hour, got")
    tt.expect(t, min == 1, "Expected 1 minute, got")
    tt.expect(t, sec == 1, "Expected 1 second, got")
    tt.expect(t, ms == 0, "Expected 0 milliseconds, got")
}

@(test)
test_time_to_hmsms :: proc(t: ^tt.T) {
    nsec := i64(3661000000000) // 1 hour, 1 minute, 1 second, 0 milliseconds
    buf := make([]u8, MIN_HMSMS_LEN)
    res := time_to_hmsms(nsec, buf)
    expected := "01:01:01.000"
    tt.expectf(t, res == expected, "Expected %v\nActual %v", expected, res)
}