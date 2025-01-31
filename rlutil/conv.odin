package rlutil

bytes_to_int32 :: proc(buf: []u8) -> (res: i32) {
    assert(len(buf) == 4)
    res = 0
    res |= i32(buf[0])
    res |= i32(buf[1]) << 8
    res |= i32(buf[2]) << 16
    res |= i32(buf[3]) << 24
    return
}

bytes_to_int64 :: proc(buf: []u8) -> (res: i64) {
    assert(len(buf) == 8)
    res = 0
    res |= i64(buf[0])
    res |= i64(buf[1]) << 8
    res |= i64(buf[2]) << 16
    res |= i64(buf[3]) << 24
    res |= i64(buf[4]) << 32
    res |= i64(buf[5]) << 40
    res |= i64(buf[6]) << 48
    res |= i64(buf[7]) << 56
    return
}
