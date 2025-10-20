package rlutil

import "base:runtime"
import "base:intrinsics"
import "core:math/rand"
import "core:time"

rng: runtime.Random_Generator

// Init a random number generator with a seed based on current time
@init
seed_rand :: proc() {
    seed := u64(time.now()._nsec)
    state := rand.create(seed)
    rng = rand.default_random_generator(&state)
    rand.reset( seed, rng )
}

// rng_from_seed creates a new random generator with the given seed and state.
// It is useful for creating reproducible random sequences.
rng_from_seed :: proc( seed: u64, state: ^rand.Default_Random_State ) -> rand.Generator {
    gen := rand.default_random_generator( state )
    rand.reset( seed, gen )
    return gen
}

/* Usage:
    int_v := rand_range(1, 10)
    i32_v := rand_range(i32(1), i32(10))
    f32_v := rand_range(1.0, 10.0)
    f64_v := rand_range(f64(1.0), f64(10.0))
*/
rand_range :: proc(min: $T, max: T) -> T  where intr.type_is_numeric(T) {
    when intrinsics.type_is_integer(T) {
        return T(rand.choice_enum(int(max - min + 1))) + min
    } else when intrinsics.type_is_float(T) {
        return rand.float64_range(f64(min), f64(max))
    }
}

// chance returns true with the given probability eg 0.5 for 50% chance
chance :: proc(probability: $F) -> bool  where intr.type_is_float(F) {
    // if random value is less than the probability
    return rand.float64() < clamp(probability, 0, 1)
}
