package main

import "base:runtime"
import "core:fmt"
import "core:math"
import "core:math/rand"
import "core:mem"
import "core:time"
import "core:slice"

import rl "vendor:raylib"
import "../../../rlutil/noise"

perlin := noise.perlin_noise_init()

_generate_natural :: proc(m: ^Map, dist: TerrainDistribution, rng: ^runtime.Random_Generator) {
    // 1. generate height & moisture maps (Perlin)
    scale_height  := 0.04   // bigger = smoother continents
    scale_moist   := 0.06
    octaves       := 5

    height  := make([]f32, m.rows * m.cols)
    moist   := make([]f32, m.rows * m.cols)
    defer delete(height)
    defer delete(moist)

    for row in 0..<m.rows {
        for col in 0..<m.cols {
            x := f64(col) * scale_height
            y := f64(row) * scale_height
            h := noise.get_noise_2d_with_octaves(&perlin, x, y, octaves)
            height[row*m.cols + col] = f32(h) * 0.5 + 0.5   // 0..1

            x = f64(col) * scale_moist
            y = f64(row) * scale_moist
            moist[row*m.cols + col] = f32(noise.get_noise_2d_with_octaves(&perlin, x, y, octaves)) * 0.5 + 0.5
        }
    }

    // 2. assign biome by (height, moisture)
    for row in 0..<m.rows {
        for col in 0..<m.cols {
            h := height[row*m.cols + col]
            m_ := moist[row*m.cols + col]

            // simple Whittaker-style diagram (you can tune)
            t := _pick_biome(h, m_, dist)
            m.tiles[col][row].terrain = terrain_manager_get(&m.terrain_manager, t)
        }
    }

    // 3. small-scale clustering (your old annealing)
    _cluster_terrains(m, rng, 3)   // light clustering only
}

//  Biome picker – tweak thresholds to taste
_pick_biome :: proc(height, moisture: f32, dist: TerrainDistribution) -> TerrainType {
    // water first (very low height)
    if height < 0.20 {
        return .Water
    }

    // mountains (high height, any moisture)
    if height > 0.75 {
        return .Mountains
    }

    // hills (medium-high height)
    if height > 0.55 {
        return .Hills
    }

    // now moisture decides the rest
    if moisture < 0.25 {
        return .Plains
    }
    if moisture < 0.45 {
        return .Forest
    }
    if moisture < 0.70 {
        return .Marsh
    }
    return .Urban   // tiny urban blobs – will be overridden by count later
}

_init_tiles :: proc(m: ^Map, dist: TerrainDistribution, k: i32) {
    seed := rand.create(u64(time.now()._nsec))
    rng  := rand.default_random_generator(&seed)

    // 1. natural Perlin-based layout
    _generate_natural(m, dist, &rng)

    // 2. enforce *exact* distribution (optional but keeps UI honest)
    _enforce_distribution(m, dist, &rng)

    // 3. light clustering to smooth tiny noise
    if k > 0 {
        _cluster_terrains(m, &rng, k)
    }
}

//  Enforce exact counts (swap with random tiles until satisfied)
_enforce_distribution :: proc(m: ^Map, dist: TerrainDistribution, rng: ^runtime.Random_Generator) {
    n := i32(m.rows) * i32(m.cols)
    target := make(map[TerrainType]i32)
    defer delete(target)

    // compute target counts (same as before)
    target[.Forest]    = i32(dist.forest    * f32(n))
    target[.Hills]     = i32(dist.hills     * f32(n))
    target[.Marsh]     = i32(dist.marsh     * f32(n))
    target[.Mountains] = i32(dist.mountains * f32(n))
    target[.Water]     = i32(dist.water     * f32(n))
    target[.Urban]     = i32(dist.urban     * f32(n))
    target[.Plains]    = n - (target[.Forest] + target[.Hills] + target[.Marsh] +
                             target[.Mountains] + target[.Water] + target[.Urban])

    // count current
    cur := make(map[TerrainType]i32)
    defer delete(cur)
    for col in m.tiles {
        for tile in col {
            cur[tile.terrain.type_] += 1
        }
    }

    // swap until we match
    for t in TerrainType {
        diff := target[t] - cur[t]
        if diff == 0 { continue }

        // find random tiles of type t (or random tiles to replace)
        for abs(diff) > 0 {
            // pick a tile that should be changed
            src_type := diff > 0 ? _random_type_with_count(cur, rng) : t
            dst_type := diff > 0 ? t : _random_type_with_count(cur, rng)

            // find a tile with src_type
            p := _random_tile_of_type(m, src_type, rng)
            if p.x < 0 { break }

            // swap
            m.tiles[int(p.x)][int(p.y)].terrain = terrain_manager_get(&m.terrain_manager, dst_type)
            cur[src_type] -= 1
            cur[dst_type] += 1
            diff = target[t] - cur[t]
        }
    }
}

_random_type_with_count :: proc(counts: map[TerrainType]i32, rng: ^runtime.Random_Generator) -> TerrainType {
    total := 0
    for _, c in counts { total += int(c) }
    r := rand.int_max(total, rng^)
    acc := 0
    for t, c in counts {
        acc += int(c)
        if r < acc { return t }
    }
    return .Plains
}

_random_tile_of_type :: proc(m: ^Map, tt: TerrainType, rng: ^runtime.Random_Generator) -> rl.Vector2 {
    // simple linear scan – fine for demo
    for _ in 0..<1000 {
        col := rand.int_max(int(m.cols), rng^)
        row := rand.int_max(int(m.rows), rng^)
        if m.tiles[col][row].terrain.type_ == tt {
            return rl.Vector2{f32(col), f32(row)}
        }
    }
    return {-1, -1}
}
TerrainDistribution :: struct {
    hills:     f32,
    mountains: f32,
    marsh:     f32,
    forest:    f32,
    water:     f32,
    urban:     f32,
    plains:    f32, // will be computed as remainder
}

Map :: struct {
    rows:            i32,
    cols:            i32,
    tiles:           [][]Tile,
    terrain_manager: TerrainManager,
    compat:          map[TerrainType]map[TerrainType]f64,
    neighbor_cache:  map[rl.Vector2][dynamic]rl.Vector2,
}

map_create :: proc(rows, cols: i32, dist: TerrainDistribution, k_cluster: i32) -> Map {
    m := Map{
        rows = rows,
        cols = cols,
    }
    terrain_manager_init(&m.terrain_manager)
    _init_size(&m)
    _init_compatibility(&m)
    _init_tiles(&m, dist, k_cluster)
    return m
}

map_destroy :: proc(m: ^Map) {
    for col in m.tiles {
        delete(col)
    }
    delete(m.tiles)
    terrain_manager_destroy(&m.terrain_manager)
    for _, arr in m.neighbor_cache {
        delete(arr)
    }
    delete(m.neighbor_cache)
    delete(m.compat)
}

map_get_tile :: proc(m: ^Map, pos: rl.Vector2) -> ^Tile {
    return &m.tiles[int(pos.x)][int(pos.y)]
}

_init_size :: proc(m: ^Map) {
    m.tiles = make([][]Tile, m.cols)
    for col in 0..<m.cols {
        m.tiles[col] = make([]Tile, m.rows)
        for row in 0..<m.rows {
            m.tiles[col][row].position = rl.Vector2{f32(col), f32(row)}
        }
    }
}

_init_compatibility :: proc(m: ^Map) {
    m.compat = make(map[TerrainType]map[TerrainType]f64)

    // Helper to fill a row (symmetric)
    fill := proc(m: ^Map, a: TerrainType, vals: []struct{t: TerrainType, v: f64}) {
        inner := make(map[TerrainType]f64, len(vals))
        for v in vals {
            inner[v.t] = v.v
        }
        m.compat[a] = inner
    }

    fill(m, .Plains,   []struct{t:TerrainType,v:f64}{{.Plains,0.85},{.Hills,0.5},{.Mountains,0.2},{.Marsh,0.3},{.Forest,0.5},{.Water,0.3},{.Urban,0.0}})
    fill(m, .Hills,    []struct{t:TerrainType,v:f64}{{.Hills,0.85},{.Plains,0.5},{.Mountains,0.8},{.Marsh,0.1},{.Forest,0.4},{.Water,0.4}})
    fill(m, .Mountains,[]struct{t:TerrainType,v:f64}{{.Mountains,0.9},{.Plains,0.5},{.Hills,0.8},{.Marsh,0.05},{.Forest,0.3},{.Water,0.5},{.Urban,0.0}})
    fill(m, .Marsh,    []struct{t:TerrainType,v:f64}{{.Marsh,0.85},{.Plains,0.3},{.Hills,0.1},{.Mountains,0.05},{.Forest,0.7},{.Water,0.7},{.Urban,0.0}})
    fill(m, .Forest,   []struct{t:TerrainType,v:f64}{{.Forest,1.0},{.Plains,0.5},{.Hills,0.4},{.Mountains,0.3},{.Marsh,0.7},{.Water,0.3},{.Urban,0.0}})
    fill(m, .Water,    []struct{t:TerrainType,v:f64}{{.Water,0.8},{.Plains,0.3},{.Hills,0.4},{.Mountains,0.5},{.Marsh,0.7},{.Forest,0.3},{.Urban,0.3}})
    fill(m, .Urban,    []struct{t:TerrainType,v:f64}{{.Urban,1.0},{.Water,0.3}})
}

// Random fill (exact counts)
_random_fill :: proc(m: ^Map, dist: TerrainDistribution, rng: ^runtime.Random_Generator) {
    n := i32(m.rows) * i32(m.cols)

    forest_amt   := i32(dist.forest   * f32(n))
    hills_amt    := i32(dist.hills    * f32(n))
    marsh_amt    := i32(dist.marsh    * f32(n))
    mountains_amt:= i32(dist.mountains* f32(n))
    water_amt    := i32(dist.water    * f32(n))
    urban_amt    := i32(dist.urban    * f32(n))
    plains_amt   := n - (forest_amt + hills_amt + marsh_amt + mountains_amt + water_amt + urban_amt)

    terrains := make([dynamic]^Terrain, 0, n)
    defer delete(terrains)

    append_n := proc(m: ^Map, slice: ^[dynamic]^Terrain, t: TerrainType, cnt: i32) {
        terr := terrain_manager_get(&m.terrain_manager, t)
        for _ in 0..<cnt {
            runtime.append_elem(slice, terr)
        }
    }

    append_n(m, &terrains, .Forest,    forest_amt)
    append_n(m, &terrains, .Hills,     hills_amt)
    append_n(m, &terrains, .Marsh,     marsh_amt)
    append_n(m, &terrains, .Mountains,mountains_amt)
    append_n(m, &terrains, .Water,     water_amt)
    append_n(m, &terrains, .Urban,     urban_amt)
    append_n(m, &terrains, .Plains,    plains_amt)

    rand.shuffle(terrains[:], rng^)

    idx := 0
    for col in 0..<m.cols {
        for row in 0..<m.rows {
            m.tiles[col][row].terrain = terrains[idx]
            idx += 1
        }
    }
}

// Simulated annealing clustering
_cluster_terrains :: proc(m: ^Map, rng: ^runtime.Random_Generator, k: i32) {
    n := i32(m.rows) * i32(m.cols)
    iterations := n * k
    temperature := 0.75
    final_temp  := 0.001
    cool_rate   := math.pow(final_temp / temperature, 1.0 / f64(iterations))

    for _ in 0..<iterations {
        x1 := rand.float32_uniform(0, f32(m.cols), rng^)  // inclusive upper bound
        y1 := rand.float32_uniform(0, f32(m.rows), rng^)

        col1 := int(math.floor(x1))
        row1 := int(math.floor(y1))
        if i32(col1) >= m.cols || i32(row1) >= m.rows { continue }

        neigh := map_neighbors(m, rl.Vector2{f32(col1), f32(row1)})
        if len(neigh) == 0 { continue }

        ni := rand.int_max(len(neigh), rng^)
        p2 := neigh[ni]
        col2 := int(p2.x)
        row2 := int(p2.y)

        t1 := m.tiles[col1][row1].terrain
        t2 := m.tiles[col2][row2].terrain
        if t1 == t2 { continue }

        prev1 := _happiness(m, rl.Vector2{f32(col1), f32(row1)})
        prev2 := _happiness(m, p2)

        // swap
        m.tiles[col1][row1].terrain = t2
        m.tiles[col2][row2].terrain = t1

        new1 := _happiness(m, rl.Vector2{f32(col1), f32(row1)})
        new2 := _happiness(m, p2)
        delta := (new1 - prev1) + (new2 - prev2)

        if delta > 0 && rand.float64_uniform(0.0, 1.0, rng^) > math.exp(delta / temperature) {
            m.tiles[col1][row1].terrain = t1
            m.tiles[col2][row2].terrain = t2
        }
        temperature *= cool_rate
    }
}

// Neighbor handling (cached, 8-directional)
map_neighbors :: proc(m: ^Map, pos: rl.Vector2, include_self := false) -> [dynamic]rl.Vector2 {
    if cached, ok := m.neighbor_cache[pos]; ok {
        return cached
    }

    i_min, i_max := -1, 1
    j_min, j_max := -1, 1

    if pos.x == 0          do i_min = 0
    else if i32(pos.x) == m.cols-1 do i_max = 0
    if pos.y == 0          do j_min = 0
    else if i32(pos.y) == m.rows-1 do j_max = 0

    neigh := make([dynamic]rl.Vector2, 0, 8)
    for i in i_min..=i_max {
        for j in j_min..=j_max {
            if !include_self && i == 0 && j == 0 { continue }
            np := rl.Vector2{pos.x + f32(i), pos.y + f32(j)}
            runtime.append_elem(&neigh, np)
        }
    }
    m.neighbor_cache[pos] = neigh
    return neigh
}

// Happiness = average compatibility with neighbours
_happiness :: proc(m: ^Map, pos: rl.Vector2) -> f64 {
    neigh := map_neighbors(m, pos)
    if len(neigh) == 0 { return 0 }

    total: f64 = 0
    self_type := m.tiles[int(pos.x)][int(pos.y)].terrain.type_

    for n in neigh {
        nb_type := m.tiles[int(n.x)][int(n.y)].terrain.type_
        total += _compatibility(m, self_type, nb_type)
    }
    return total / f64(len(neigh))
}

_compatibility :: proc(m: ^Map, a, b: TerrainType) -> f64 {
    if inner, ok := m.compat[a]; ok {
        if v, ok2 := inner[b]; ok2 {
            return v
        }
    }
    return 0.0
}