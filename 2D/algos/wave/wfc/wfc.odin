package wfc

import "core:fmt"
import "core:math"
import "core:math/rand"
import "core:mem"
import rl "vendor:raylib"

Direction :: distinct u8

Pattern :: struct {
    pixels:    []rl.Color,
    frequency: int,
    overlaps:  []u8,
}

PatternSet :: struct {
    patterns:      []Pattern,
    pattern_count: int,
    pattern_dim:   int,
}

CellState :: struct {
    choices:            []int,
    choice_count:       int,
    stable_choices:     []int,
    stable_choice_count: int,
    is_visited:         bool,
    is_changed:         bool,
    is_collapsed:       bool,
    entropy:            f32,
}

WaveState :: struct {
    pattern_set:       PatternSet,
    width:             int,
    height:            int,
    max_depth:         int,
    collapse_counter:  int,
    cell_states:       []CellState,
    pixels:            []rl.Color,
    texture:           rl.Texture,
}

DIRECTION_VECTORS := [4]rl.Vector2{
    {1, 0}, {0, 1}, {-1, 0}, {0, -1},
}

get_opposite_direction :: proc(direction: Direction) -> Direction {
    return Direction((int(direction) + 2) % 4)
}

are_colors_equal :: proc(color_a, color_b: rl.Color) -> bool {
    return color_a.r == color_b.r && 
           color_a.g == color_b.g && 
           color_a.b == color_b.b && 
           color_a.a == color_b.a
}

pattern_pixels_from_source :: proc(pixels: []rl.Color, width, height, x, y, dim: int) -> []rl.Color {
    // Setup a pattern centered on a pixel from the source
    pattern_image := rl.GenImageColor(i32(dim), i32(dim), rl.PINK)
    pattern := rl.LoadImageColors(pattern_image)
    pattern_slice := make([]rl.Color, dim * dim)
    
    // Copy the data from the C array to our Odin slice
    for i := 0; i < dim * dim; i += 1 {
        pattern_slice[i] = pattern[i]
    }
    
    rl.UnloadImage(pattern_image)
    
    // For each pixel inside the dim sized square
    for pattern_y := 0; pattern_y < dim; pattern_y += 1 {
        for pattern_x := 0; pattern_x < dim; pattern_x += 1 {
            pixel_x := x - dim / 2 + pattern_x
            pixel_y := y - dim / 2 + pattern_y
            
            // Grab pixel from the source, wrapping coordinates
            wrapped_pixel_x := (pixel_x + width) % width
            wrapped_pixel_y := (pixel_y + height) % height
            pattern_slice[pattern_x + pattern_y * dim] = pixels[wrapped_pixel_x + wrapped_pixel_y * width]
        }
    }
    
    return pattern_slice
}

pattern_pixels_hash :: proc(pixels: []rl.Color, dim: int) -> u64 {
    // Hash the pattern pixels, considering the order of the pixels
    hash: u64 = 0
    
    for i := 0; i < dim * dim; i += 1 {
        hash = hash * 31 + u64(pixels[i].r)
        hash = hash * 31 + u64(pixels[i].g)
        hash = hash * 31 + u64(pixels[i].b)
        hash = hash * 31 + u64(pixels[i].a)
    }
    
    return hash
}

pattern_init :: proc(pattern: ^Pattern, pattern_set: ^PatternSet, pixels: []rl.Color, frequency: int) {
    pattern.pixels = pixels
    pattern.frequency = frequency
    pattern.overlaps = make([]u8, pattern_set.pattern_count)
    
    for i := 0; i < pattern_set.pattern_count; i += 1 {
        pattern.overlaps[i] = 0
    }
}

pattern_destroy :: proc(pattern: ^Pattern) {
    delete(pattern.pixels)
    delete(pattern.overlaps)
}

pattern_overlap_add :: proc(pattern: ^Pattern, index: int, direction: Direction) {
    pattern.overlaps[index] |= (1 << u8(direction))
}

pattern_overlap_check :: proc(pattern: ^Pattern, index: int, direction: Direction) -> bool {
    return (pattern.overlaps[index] & (1 << u8(direction))) > 0
}

pattern_can_overlap :: proc(pattern_set: ^PatternSet, index_a, index_b: int, direction: Direction) -> bool {
    // For every pixel in pattern A
    for ay := 0; ay < pattern_set.pattern_dim; ay += 1 {
        for ax := 0; ax < pattern_set.pattern_dim; ax += 1 {
            // If it also inside pattern B
            opposite_dir := get_opposite_direction(direction)
            bx := i32(ax) + i32(DIRECTION_VECTORS[opposite_dir].x)
            by := i32(ay) + i32(DIRECTION_VECTORS[opposite_dir].y)
            
            if bx < 0 || bx >= i32(pattern_set.pattern_dim) || by < 0 || by >= i32(pattern_set.pattern_dim) {
                continue
            }
            
            // Check if they are different and if so return
            color_a := pattern_set.patterns[index_a].pixels[ax + ay * pattern_set.pattern_dim]
            color_b := pattern_set.patterns[index_b].pixels[int(bx) + int(by) * pattern_set.pattern_dim]
            
            if !are_colors_equal(color_a, color_b) {
                return false
            }
        }
    }
    
    return true
}

pattern_set_init :: proc(pattern_set: ^PatternSet, input_image_path: cstring, pattern_dim: int) {
    // Read source image colours
    source_image := rl.LoadImage(input_image_path)
    
    if source_image.width < 1 || source_image.height < 1 {
        fmt.printf("Failed to load image from path: %s\n", input_image_path)
        return
    }
    
    rl.ImageFormat(&source_image, rl.PixelFormat.UNCOMPRESSED_R8G8B8A8)
    source_pixels := rl.LoadImageColors(source_image)
    
    // Create a slice to reference the source pixels
    source_pixel_slice := make([]rl.Color, source_image.width * source_image.height)
    for i := 0; i < int(source_image.width * source_image.height); i += 1 {
        source_pixel_slice[i] = source_pixels[i]
    }
    
    rl.UnloadImage(source_image)
    
    // Setup to track each of the unique patterns
    pattern_set.pattern_count = 0
    pattern_set.pattern_dim = pattern_dim
    
    max_pattern_count := int(source_image.width * source_image.height)
    pattern_hashes := make([]u64, max_pattern_count)
    pattern_pixels := make([][]rl.Color, max_pattern_count)
    pattern_frequencies := make([]int, max_pattern_count)
    
    // Create a pattern from each source image pixel
    for centre_y := 0; centre_y < int(source_image.height); centre_y += 1 {
        for centre_x := 0; centre_x < int(source_image.width); centre_x += 1 {
            pixels := pattern_pixels_from_source(
                source_pixel_slice, 
                int(source_image.width), 
                int(source_image.height), 
                centre_x, 
                centre_y, 
                pattern_dim,
            )
            hash := pattern_pixels_hash(pixels, pattern_dim)
            
            // Update the frequency of any existing matching pattern
            found_index := -1
            for i := 0; i < pattern_set.pattern_count; i += 1 {
                if pattern_hashes[i] == hash {
                    found_index = i
                    break
                }
            }
            
            if found_index == -1 {
                pattern_hashes[pattern_set.pattern_count] = hash
                pattern_pixels[pattern_set.pattern_count] = pixels
                pattern_frequencies[pattern_set.pattern_count] = 1
                pattern_set.pattern_count += 1
            } else {
                pattern_frequencies[found_index] += 1
                delete(pixels)
            }
        }
    }
    
    // Load final patterns into the pattern set and delete temporary data
    pattern_set.patterns = make([]Pattern, pattern_set.pattern_count)
    
    for i := 0; i < pattern_set.pattern_count; i += 1 {
        pattern_init(&pattern_set.patterns[i], pattern_set, pattern_pixels[i], pattern_frequencies[i])
    }
    
    delete(pattern_hashes)
    delete(pattern_pixels)
    delete(pattern_frequencies)
    delete(source_pixel_slice)
    
    // Check each tile against each other tile in each direction
    for pattern_a := 0; pattern_a < pattern_set.pattern_count; pattern_a += 1 {
        for pattern_b := pattern_a; pattern_b < pattern_set.pattern_count; pattern_b += 1 {
            for direction: Direction = 0; direction < 4; direction += 1 {
                if pattern_can_overlap(pattern_set, pattern_a, pattern_b, direction) {
                    pattern_overlap_add(&pattern_set.patterns[pattern_a], pattern_b, direction)
                    pattern_overlap_add(&pattern_set.patterns[pattern_b], pattern_a, get_opposite_direction(direction))
                }
            }
        }
    }
}

pattern_set_destroy :: proc(pattern_set: ^PatternSet) {
    for i := 0; i < pattern_set.pattern_count; i += 1 {
        pattern_destroy(&pattern_set.patterns[i])
    }
    
    delete(pattern_set.patterns)
}

cell_state_calculate_entropy :: proc(cell_state: ^CellState, pattern_set: ^PatternSet) {
    // Calculate using shannon entropy
    cell_state.entropy = 0
    total_frequency := 0

    for i := 0; i < cell_state.choice_count; i += 1 {
        total_frequency += pattern_set.patterns[cell_state.choices[i]].frequency
    }

    for i := 0; i < cell_state.choice_count; i += 1 {
        frequency := pattern_set.patterns[cell_state.choices[i]].frequency
        probability := f32(frequency) / f32(total_frequency)
        cell_state.entropy -= probability * math.log2(probability)
    }

    // Alternative calculation simply using the number of choices
    // cell_state.entropy = f32(cell_state.choice_count)
}

cell_state_reset :: proc(cell_state: ^CellState, wave_state: ^WaveState) {
    // Reset the cell to the initial state
    cell_state.choice_count = wave_state.pattern_set.pattern_count
    cell_state.stable_choice_count = wave_state.pattern_set.pattern_count
    cell_state.is_visited = false
    cell_state.is_changed = false
    cell_state.is_collapsed = false
    cell_state.entropy = 0
    
    for i := 0; i < cell_state.choice_count; i += 1 {
        cell_state.choices[i] = i
        cell_state.stable_choices[i] = i
    }
    
    cell_state_calculate_entropy(cell_state, &wave_state.pattern_set)
}

cell_state_init :: proc(cell_state: ^CellState, wave_state: ^WaveState) {
    // Initialize the cell state with the pattern set
    cell_state.choice_count = wave_state.pattern_set.pattern_count
    cell_state.stable_choice_count = wave_state.pattern_set.pattern_count
    cell_state.choices = make([]int, cell_state.choice_count)
    cell_state.stable_choices = make([]int, cell_state.stable_choice_count)
    cell_state_reset(cell_state, wave_state)
}

cell_state_destroy :: proc(cell_state: ^CellState) {
    delete(cell_state.choices)
    delete(cell_state.stable_choices)
}

cell_state_block :: proc(cell_state: ^CellState, choice: int) {
    // Remove the pattern from the list at the index
    // This is done by moving the last pattern to the index and decrementing the count
    cell_state.choices[choice] = cell_state.choices[cell_state.choice_count - 1]
    cell_state.choice_count -= 1
    cell_state.is_changed = true
}

cell_state_reset_to_stable :: proc(cell_state: ^CellState) {
    // Reset the cell to the stable state only if it has changed
    if !cell_state.is_changed {
        return
    }
    
    cell_state.choice_count = cell_state.stable_choice_count
    
    for i := 0; i < cell_state.choice_count; i += 1 {
        cell_state.choices[i] = cell_state.stable_choices[i]
    }
    
    cell_state.is_changed = false
}

cell_state_save_as_stable :: proc(cell_state: ^CellState) {
    // Save the current state as the stable state only if it has changed
    if !cell_state.is_changed {
        return
    }
    
    cell_state.stable_choice_count = cell_state.choice_count
    
    for i := 0; i < cell_state.choice_count; i += 1 {
        cell_state.stable_choices[i] = cell_state.choices[i]
    }
    
    cell_state.is_changed = false
}

get_best_cell :: proc(wave_state: ^WaveState) -> int {
    // Grab all the cells with the lowest entropy
    min_entropy :f32 = math.F32_MAX
    min_index_list := make([]int, wave_state.width * wave_state.height)
    min_index_count := 0
    
    for i := 0; i < wave_state.width * wave_state.height; i += 1 {
        if wave_state.cell_states[i].is_collapsed {
            continue
        }
        
        entropy := wave_state.cell_states[i].entropy
        
        // Overwrite the list if a new minimum is found
        if entropy < min_entropy {
            min_entropy = entropy
            min_index_list[0] = i
            min_index_count = 1
        } else if entropy == min_entropy {
            // Add to list if it matches current elements
            min_index_list[min_index_count] = i
            min_index_count += 1
        }
    }
    
    // Choose a random cell from the list, or otherwise return -1
    chosen := -1
    
    if min_index_count > 0 {
        chosen = min_index_list[rand.int_max(min_index_count)]
    }
    
    delete(min_index_list)
    return chosen
}

propogate_entropy :: proc(wave_state: ^WaveState, cell_index, depth: int) -> bool {
    cell_state := &wave_state.cell_states[cell_index]
    cell_x := cell_index % wave_state.width
    cell_y := cell_index / wave_state.width
    
    // Don't visit a cell if it is already visited
    if depth > wave_state.max_depth || cell_state.is_visited {
        return true
    }
    
    cell_state.is_visited = true
    
    // For each neighbour direction of the current cell
    for direction: Direction = 0; direction < 4; direction += 1 {
        // Within bounds
        nb_cell_x := cell_x + int(DIRECTION_VECTORS[direction].x)
        nb_cell_y := cell_y + int(DIRECTION_VECTORS[direction].y)
        if nb_cell_x < 0 || nb_cell_x >= wave_state.width || nb_cell_y < 0 || nb_cell_y >= wave_state.height {
            continue
        }
        
        // Not collapsed
        nb_cell_index := nb_cell_x + nb_cell_y * wave_state.width
        nb_cell_state := &wave_state.cell_states[nb_cell_index]
        if nb_cell_state.is_collapsed {
            continue
        }
        
        // Check each of the neighbours patterns overlaps at least 1 of this cells
        i := 0
        for i < nb_cell_state.choice_count {
            found := false
            for j := 0; j < cell_state.choice_count && !found; j += 1 {
                cell_pattern_index := cell_state.choices[j]
                nb_cell_pattern_index := nb_cell_state.choices[i]
                cell_pattern := &wave_state.pattern_set.patterns[cell_pattern_index]
                found |= pattern_overlap_check(cell_pattern, nb_cell_pattern_index, direction)
            }
            
            // If none was found then block the pattern
            if !found {
                cell_state_block(nb_cell_state, i)
                // Don't increment i since we just moved an element to this position
            } else {
                i += 1
            }
        }
        
        // Propogate the entropy if the neighbour is changed
        // Also have guards for checking the neighbour was reduced to 0 choices
        if nb_cell_state.is_changed {
            if nb_cell_state.choice_count == 0 {
                return false
            }
            
            cell_state_calculate_entropy(nb_cell_state, &wave_state.pattern_set)
            
            if !propogate_entropy(wave_state, nb_cell_index, depth + 1) {
                return false
            }
        }
    }
    
    // All neighbours collapsed without conflict
    return true
}

update_texture :: proc(wave_state: ^WaveState) {
    // Calculate colour of each cell in the output
    pos := wave_state.pattern_set.pattern_dim / 2
    
    for i_cell := 0; i_cell < wave_state.width * wave_state.height; i_cell += 1 {
        // If cell is collapsed then take the colour of the collapsed pattern
        if wave_state.cell_states[i_cell].is_collapsed {
            pattern := &wave_state.pattern_set.patterns[wave_state.cell_states[i_cell].choices[0]]
            pattern_color := pattern.pixels[pos + pos * wave_state.pattern_set.pattern_dim]
            wave_state.pixels[i_cell] = pattern_color
        } else if wave_state.cell_states[i_cell].choice_count == 0 {
            // If cell is not collapsed but has no options then it is a conflict
            wave_state.pixels[i_cell] = rl.PINK
        } else {
            // Otherwise average the colour of each possible pattern
            total_r, total_g, total_b, total_a: u32
            
            for i_pattern := 0; i_pattern < wave_state.cell_states[i_cell].choice_count; i_pattern += 1 {
                pattern := &wave_state.pattern_set.patterns[wave_state.cell_states[i_cell].choices[i_pattern]]
                pattern_color := pattern.pixels[pos + pos * wave_state.pattern_set.pattern_dim]
                
                total_r += u32(pattern_color.r)
                total_g += u32(pattern_color.g)
                total_b += u32(pattern_color.b)
                total_a += u32(pattern_color.a)
            }
            
            count := wave_state.cell_states[i_cell].choice_count
            average_color := rl.Color{
                u8(total_r / u32(count)),
                u8(total_g / u32(count)),
                u8(total_b / u32(count)),
                u8(total_a / u32(count)),
            }
            
            wave_state.pixels[i_cell] = average_color
        }
    }
    
    rl.UpdateTexture(wave_state.texture, raw_data(wave_state.pixels))
}

init :: proc(wave_state: ^WaveState, input_image_path: cstring, width, height, pattern_dim, max_depth: int) {
    // Setup a new wave data output with the given pattern set
    pattern_set_init(&wave_state.pattern_set, input_image_path, pattern_dim)
    
    wave_state.width = width
    wave_state.height = height
    wave_state.max_depth = max_depth
    wave_state.collapse_counter = 0
    wave_state.cell_states = make([]CellState, wave_state.width * wave_state.height)
    
    image := rl.GenImageColor(i32(wave_state.width), i32(wave_state.height), rl.BLUE)
    wave_state.pixels = make([]rl.Color, wave_state.width * wave_state.height)
    
    // Copy image pixels to our slice
    image_colors := rl.LoadImageColors(image)
    for i := 0; i < wave_state.width * wave_state.height; i += 1 {
        wave_state.pixels[i] = image_colors[i]
    }
    
    wave_state.texture = rl.LoadTextureFromImage(image)
    rl.UnloadImageColors(image_colors)
    rl.UnloadImage(image)
    
    for i := 0; i < wave_state.width * wave_state.height; i += 1 {
        cell_state_init(&wave_state.cell_states[i], wave_state)
    }
}

destroy :: proc(wave_state: ^WaveState) {
    pattern_set_destroy(&wave_state.pattern_set)
    
    for i_result := 0; i_result < wave_state.width * wave_state.height; i_result += 1 {
        cell_state_destroy(&wave_state.cell_states[i_result])
    }
    
    delete(wave_state.cell_states)
    delete(wave_state.pixels)
    rl.UnloadTexture(wave_state.texture)
}

restart :: proc(wave_state: ^WaveState) {
    for i := 0; i < wave_state.width * wave_state.height; i += 1 {
        cell_state_reset(&wave_state.cell_states[i], wave_state)
    }
    
    wave_state.collapse_counter = 0
}

collapse :: proc(wave_state: ^WaveState) -> int {
    // Grab the non-collapsed cell with the lowest entropy
    best_cell_index := get_best_cell(wave_state)
    
    // If no cell is returned then all are collapsed the wave is successful
    if best_cell_index < 0 {
        fmt.println("Wave state finalized: All cells collapsed.")
        return 1
    }
    
    // Copy all of the possible choices
    best_cell := &wave_state.cell_states[best_cell_index]
    remaining_choices := make([]int, best_cell.choice_count)
    remaining_choice_count := best_cell.choice_count
    
    for i := 0; i < best_cell.choice_count; i += 1 {
        remaining_choices[i] = best_cell.choices[i]
    }
    
    // While there are possible choices
    success := false
    
    for remaining_choice_count > 0 {
        // Pick one at random and remove from the list
        choice := rand.int_max(remaining_choice_count)
        best_cell.choices[0] = remaining_choices[choice]
        best_cell.choice_count = 1
        best_cell.is_changed = true
        remaining_choices[choice] = remaining_choices[remaining_choice_count - 1]
        remaining_choice_count -= 1
        
        // Propogate the entropy reduction between neighbours in the wave
        success = propogate_entropy(wave_state, best_cell_index, 0)
        
        // Successful so mark as collapsed and exit
        if success {
            best_cell.is_collapsed = true
            break
        } else {
            // There was a conflict so reset all the states back to their stable states
            for i := 0; i < wave_state.width * wave_state.height; i += 1 {
                wave_state.cell_states[i].is_visited = false
                cell_state_reset_to_stable(&wave_state.cell_states[i])
            }
        }
    }
    
    delete(remaining_choices)
    
    // None of the choices were successful
    if !success {
        fmt.println("Wave state finalized: No choices without conflicts available.")
        return -1
    }
    
    // There was a successful choice so save the new stable state configuration
    wave_state.collapse_counter += 1
    
    for i := 0; i < wave_state.width * wave_state.height; i += 1 {
        wave_state.cell_states[i].is_visited = false
        cell_state_save_as_stable(&wave_state.cell_states[i])
    }
    
    return 0
}

draw :: proc(wave_state: ^WaveState, draw_cell_count: bool) {
    update_texture(wave_state)
    
    // Draw the output wave state
    draw_size := int(f32(rl.GetScreenWidth()) * 0.8)
    draw_scale := draw_size / wave_state.height
    draw_pos := rl.Vector2{
        f32(rl.GetScreenWidth()) / 2 - f32(draw_size) / 2,
        f32(rl.GetScreenHeight()) / 2 - f32(draw_size) / 2,
    }
    
    rl.DrawTextureEx(wave_state.texture, draw_pos, 0.0, f32(draw_scale), rl.WHITE)
    
    // Draw the number of states on each cell
    if draw_cell_count {
        for y := 0; y < wave_state.height; y += 1 {
            for x := 0; x < wave_state.width; x += 1 {
                cell := x + y * wave_state.width
                count := wave_state.cell_states[cell].choice_count
                
                if count == 0 {
                    rl.DrawText(
                        "!!!", 
                        i32(draw_pos.x) + i32(x * draw_scale) + 10, 
                        i32(draw_pos.y) + i32(y * draw_scale) + 10, 
                        20, 
                        rl.LIGHTGRAY,
                    )
                } else if !wave_state.cell_states[cell].is_collapsed {
                    text := fmt.ctprintf("%d", count)
                    rl.DrawText(
                        text, 
                        i32(draw_pos.x) + i32(x * draw_scale) + 10, 
                        i32(draw_pos.y) + i32(y * draw_scale) + 10, 
                        10, 
                        rl.LIGHTGRAY,
                    )
                }
            }
        }
    }
}