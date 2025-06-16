package mcts

// Array utility for MCTS
Array :: struct($N: int, $T: typeid) {
    data: [N]T,
    len: int,
}

array_push :: proc(arr: ^Array($N, $T), item: T) -> bool {
    if arr.len >= N do return false
    arr.data[arr.len] = item
    arr.len += 1
    return true
}

array_get :: proc(arr: Array($N, $T), idx: int) -> T {
    return arr.data[idx]
}

array_clear :: proc(arr: ^Array($N, $T)) {
    arr.len = 0
}

array_is_full :: proc(arr: Array($N, $T)) -> bool {
    return arr.len >= N
}