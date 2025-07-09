package rlutil

import "core:time"

profiles: map[string]Profile

Profile :: struct{
    cnt: int,
    total: time.Duration,
    stopwatch: time.Stopwatch,
}

profile_init   :: proc(size: int) { reserve(&profiles, size) }
profile_deinit :: proc()          { delete(profiles) }

profile_get :: proc(label: string) -> Profile { return profiles[label] }

@(deferred_in=profile_end)
profile_begin :: proc(label: string) -> bool {
    if label not_in profiles {
        profiles[label] = Profile{}
    }

    p := &profiles[label]
    time.stopwatch_reset(&p.stopwatch)
    time.stopwatch_start(&p.stopwatch)

    return true
}

profile_end :: proc(label: string) {
    p := &profiles[label]
    time.stopwatch_stop(&p.stopwatch)

    p.cnt += 1
    p.total += time.stopwatch_duration(p.stopwatch)
}