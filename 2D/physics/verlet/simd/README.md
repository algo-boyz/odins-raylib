
# Steps

```
git clone --recurse-submodules https://github.com/oskarnp/odin-tracy
brew install pkg-config glfw freetype capstone
cd odin-tracy/tracy/profiler/build/unix
make release
./Tracy-release

```

1. Improve Spatial Grid Strategy
Either:

Place each particle individually in the grid (instead of clusters)
Or use a smaller cell size and place clusters in multiple cells when they span boundaries

2. Fix Collision Detection
Use a separate tracking system to ensure all particle pairs are checked:
odin// Track which cluster pairs have been checked this frame
checked_pairs := make(map[[2]int]bool)
defer delete(checked_pairs)

// In your collision loop:
pair_key := [2]int{min(i, j), max(i, j)}
if pair_key in checked_pairs do continue
checked_pairs[pair_key] = true

Checkout: https://github.com/Skovrup1/solver/blob/master/main.odin