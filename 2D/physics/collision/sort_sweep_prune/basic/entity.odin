package  main

import "core:math/rand"

Entity :: struct {
    id: int,
    position: [2]f32,
    chunk_index: int,
    velocity: [2]f32,
}

add_entity :: proc(world: ^World, position: [2]f32) -> ^Entity {
    entity := new(Entity)
    entity.id = len(world.entities)
    entity.position = position
    entity.velocity = [2]f32{
        rand.float32_range(-4,4),
        rand.float32_range(-4,4)
    }
    world.entities[entity.id] = entity

    chunk_x, chunk_y := get_chunk_coords(position)
    chunk_idx := get_chunk_index(int(chunk_x), int(chunk_y))

    entity.chunk_index = chunk_idx
    append(&world.chunks[chunk_idx].entities, entity.id)
    return entity
}

get_entities_in_chunk :: proc(world: ^World, chunk: int) -> []int {
    if chunk < 0 || chunk >= NUM_CHUNKS || chunk < 0 {
        return nil
    }
    return world.chunks[chunk].entities[:]
}

remove_entity_from_chunk :: proc(world: ^World, entity: ^Entity) {
    chunk := &world.chunks[entity.chunk_index]
    for e, i in chunk.entities {
        if e == entity.id {
            unordered_remove(&chunk.entities, i)
        }
    }
}

remove_entity :: proc(world: ^World, entity: ^Entity) {
    remove_entity_from_chunk(world, entity)
    delete_key(&world.entities, entity.id)
    free(entity)
}

move_entity :: proc(world: ^World, entity: ^Entity) {
    chunk_x, chunk_y := get_chunk_coords(entity.position)
    chunk_idx := get_chunk_index(int(chunk_x), int(chunk_y))

    if chunk_idx != entity.chunk_index {
        remove_entity_from_chunk(world, entity)
        append(&world.chunks[chunk_idx].entities, entity.id)
        entity.chunk_index = chunk_idx
    }
}