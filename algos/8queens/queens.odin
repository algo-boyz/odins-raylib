package main

import "base:runtime"
import "core:fmt"
import "core:math/rand"
import "core:mem"
import "core:slice"
import "core:time"
import rl "vendor:raylib"
import "../../rlutil/gif"

CHROMOSOME_LEN :: 8
POP_SIZE :: 50
MU_RATE :: 0.2
MAX_STUCK :: 700

best_: int // index of local-best chromosome
gen: int = 0 // num gens elapsed so far
stuck: int = 0 // iterations no new global-best was found
fit_best_: int // fitness of the global-best chromosome
xover_point: int // cross-over point when copying chromosome info
best_ind: [CHROMOSOME_LEN]int // best chromosome evolved so far
chromosomes: [POP_SIZE][CHROMOSOME_LEN]int // row-position of each queen
fitness: [POP_SIZE]Fitness // fitness of individuals
fitness_off: [POP_SIZE/2]Fitness // fitness of their offspring

Fitness :: struct {
    val: int,
    idx: int,
}

// Random number generator
seed := rand.create(u64(time.now()._nsec))
rng := rand.default_random_generator(&seed)

// Place eight queens on the board
place_queens :: proc(tex: rl.Texture2D, placements: []int, x, y, tile_w, tile_h: i32) {
    dx := (tile_w - tex.width) / 2
    dy := (tile_h - tex.height) / 2
    for i in 0..<8 {
        rl.DrawTexture(tex, dx + (i32(i) * tile_w + x), dy + (i32(placements[i]) * tile_h + y), rl.BLACK)
    }
}

// Check for diagonal attacks between two queens
same_diagonal :: proc(placements: []int, i, j: int) -> bool {
    diff_a := i - placements[i]
    diff_b := j - placements[j]
    sum_a := i + placements[i]
    sum_b := j + placements[j]
    return diff_a == diff_b || sum_a == sum_b
}

// Compute fitness of a chromosome representing a solution to the 8-queens problem defined: #pairs - #attacking_pairs
compute_fit :: proc(placements: []int) -> int {
    no_of_pairs := 28
    no_attack_pairs := 0
    for i in 0..=7 {
        for j in i+1..=7 {
            if placements[i] == placements[j] || same_diagonal(placements, i, j) {
                no_attack_pairs += 1
            }
        }
    }
    return no_of_pairs - no_attack_pairs
}

// Roulette wheel selection
rws_select :: proc(first: int = POP_SIZE) -> int {
    sum_fitness, select_i: int
    for i in 0..<POP_SIZE {
        if i == first do continue
        sum_fitness += fitness[i].val
    }
    if first == 0 do select_i += 1
    accumulation := fitness[select_i].val
    cut_off := rand.float32_range(0.0, 1.0, rng) * f32(sum_fitness)
    for f32(accumulation) < cut_off {
        select_i += 1
        if select_i == first do select_i += 1
        accumulation += fitness[select_i].val
    }
    return select_i
}

mutate :: proc(chromosome: []int) {
    for i in 0..<CHROMOSOME_LEN {
        chance := rand.float32_range(0.0, 1.0, rng)
        if chance < MU_RATE {
            mut := int(rand.float32_range(0, 7, rng))
            for mut == chromosome[i] {
                mut = int(rand.float32_range(0, 7, rng))
            }
            chromosome[i] = mut
        }
    }
}

// Recombine using single-point exchange
crossover :: proc(p1, p2: []int) -> [2][CHROMOSOME_LEN]int {
    offspring: [2][CHROMOSOME_LEN]int
    // Perform crossover
    for i in 0..<xover_point { // section 1
        offspring[0][i] = p1[i]
        offspring[1][i] = p2[i]
    }
    for i in xover_point..<CHROMOSOME_LEN { // section 2
        offspring[0][i] = p2[i]
        offspring[1][i] = p1[i]
    }
    return offspring
}

// Sort fitness values in descending order
sort_fitness :: proc(arr: []Fitness) {
    slice.sort_by(arr, proc(a, b: Fitness) -> bool {
        return a.val > b.val
    })
}

// Evaluate fitness of offspring after crossover
evaluate_pop_offspring :: proc(chromosomes_off: [][CHROMOSOME_LEN]int) {
    for i in 0..<POP_SIZE/2 {
        fitness_off[i].val = compute_fit(chromosomes_off[i][:])
        fitness_off[i].idx = i
    }
}

// Compute fitness values of initial population
evaluate_pop :: proc(chroms: [][CHROMOSOME_LEN]int) {
    _fit := -1
    for i in 0..<POP_SIZE {
        fitness[i].val = compute_fit(chroms[i][:])
        fitness[i].idx = i
        if fitness[i].val > _fit {
            _fit = fitness[i].val
            fit_best_ = _fit
            best_ = i
        }
    }
}

// Merge previous population with offspring based on fitness
merge_population :: proc(new_pop: [][CHROMOSOME_LEN]int) {
    evaluate_pop_offspring(new_pop) // evaluate offspring fitness
    if gen == 1 {
        sort_fitness(fitness[:]) // sort prev generation fitness
    }
    sort_fitness(fitness_off[:]) // sort offspring fitness
    // Create copies
    old_p: int // ptr to curr item in old population
    new_p: int // ptr to curr item in offspring
    chromosomes_cpy: [POP_SIZE][CHROMOSOME_LEN]int
    fitness_cpy: [POP_SIZE]Fitness
    copy(chromosomes_cpy[:], chromosomes[:])
    copy(fitness_cpy[:], fitness[:])
    
    for i in 0..<POP_SIZE {
        if new_p > POP_SIZE/2 - 1 || fitness_cpy[old_p].val >= fitness_off[new_p].val {
            chromosomes[i] = chromosomes_cpy[fitness_cpy[old_p].idx]
            fitness[i].val = fitness_cpy[old_p].val
            old_p += 1
        } else {
            chromosomes[i] = new_pop[fitness_off[new_p].idx]
            fitness[i].val = fitness_off[new_p].val
            new_p += 1
        }
        if i == 0 {
            best_ = i
            best_ind = chromosomes[best_]
            if fit_best_ == fitness[i].val {
                stuck += 1
            } else {
                stuck = 0
            }
            fit_best_ = fitness[i].val
        }
        fitness[i].idx = i
    }
}

// Carry out recombination, mutation, and population merge steps
reproduce :: proc() {
    new_pop: [POP_SIZE/2][CHROMOSOME_LEN]int
    count: int
    for count < POP_SIZE / 2 {
        first := rws_select()
        second := rws_select(first)
        xover_point = 1 + int(rand.float32_range(0, CHROMOSOME_LEN - 2, rng))
        
        offsprings := crossover(chromosomes[first][:], chromosomes[second][:])
        new_pop[count] = offsprings[0]
        mutate(new_pop[count][:])
        count += 1
        if count == POP_SIZE / 2 do break

        new_pop[count] = offsprings[1]
        mutate(new_pop[count][:])
        count += 1
    }
    merge_population(new_pop[:])
    gen += 1
}

main :: proc() {
        rec := gif.new_recorder("preview.gif", 24, 600)
    defer gif.recorder_cleanup(&rec)
    // Init genetics
    best_ = 0
    stuck = 0
    gen = 0
    // Init population
    for i in 0..<POP_SIZE {
        for j in 0..<CHROMOSOME_LEN {
            chromosomes[i][j] = int(rand.float32_range(0, 7, rng))
        }
    }
    evaluate_pop(chromosomes[:])
    best_ind = chromosomes[best_]
    gen += 1
    // Init window
    screen_w: i32 = 345
    screen_h: i32 = 400
    stat_display_h: i32 = 100
    res_h := screen_h - stat_display_h
    tile_colours := [2]rl.Color{rl.BLUE, rl.WHITE}
    colour_idx := 0
    tile_h := res_h / 8
    tile_w := screen_w / 8
    rl.InitWindow(screen_w, screen_h, "8-Queens Problem")
    defer rl.CloseWindow()
    rl.SetTargetFPS(60)
    // Load queen texture
    img := rl.LoadImage("bq.png")
    defer rl.UnloadImage(img)
    // Resize image
    orig_w := img.width
    orig_h := img.height
    new_w := orig_w / 10
    new_h := orig_h / 10
    rl.ImageResize(&img, new_w, new_h)

    queen := rl.LoadTextureFromImage(img)
    defer rl.UnloadTexture(queen)

    for !rl.WindowShouldClose() {
                gif.recorder_update(&rec)

        num_conflicts := 28 - fit_best_
        rl.BeginDrawing()        
        rl.ClearBackground(rl.WHITE)
        // Metrics
        gen_text := fmt.ctprintf("Gen: %d", gen)
        fitness_text := fmt.ctprintf("Fitness: %d", fit_best_)
        conflicts_text := fmt.ctprintf("Total Conflicts: %d", num_conflicts)
        start_y: i32 = 10
        line_spacing: i32 = 3
        font_size: i32 = 20
        texts := [3]cstring{gen_text, fitness_text, conflicts_text}
        for i in 0..<3 {
            text_w := rl.MeasureText(texts[i], font_size)
            start_x := (screen_w - text_w) / 2
            rl.DrawText(texts[i], start_x, start_y + i32(i) * (font_size + line_spacing), font_size, rl.BLACK)
        }
        // Draw board
        pos_y := stat_display_h
        pos_x: i32
        for i in 0..<8 {
            for j in 0..<8 {
                rl.DrawRectangle(pos_x, pos_y, tile_w, tile_h, tile_colours[colour_idx])
                if j < 7 {
                    colour_idx = (colour_idx + 1) % 2
                }
                pos_x += tile_w
            }
            pos_x = 0
            pos_y += tile_h
        }
        place_queens(queen, best_ind[:], 0, stat_display_h, tile_w, tile_h)
        if num_conflicts > 0 && stuck < MAX_STUCK {
            reproduce() // Continue evolution if unsolved or stuck
        }
        rl.EndDrawing()
    }
}