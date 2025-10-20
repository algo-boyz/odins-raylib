package main

import "core:fmt"
import "core:log"
import "core:image"
import "core:image/bmp"
import "core:slice"
import "core:math"
import "core:io"
import "core:os"
import "core:bytes"
import "core:flags"

// TODO: Use MINIAUDIO for decoding and Raylib for display
SQUARE :: 16

main :: proc() {
    context.logger = log.create_console_logger()
    context.logger.options = { .Level, .Terminal_Color, .Line, .Procedure }

    hilbert, name, log_lvl := parse_args()
    context.logger.lowest_lvl = log_lvl

    if (name == "") { fmt.eprintln("No file specified to process"); os.exit(1) }

    // File error
    file, err_f := os.open(name)
    if err_f != nil {
        fmt.println("No such file:", name)
        log.debug(err_f)
        log.debug(name)
        os.exit(1)
    }
    file_size, _ := os.file_size(file)
    buffer := make([]u8, file_size)
    n, err_r := os.read_full(file, buffer)
    if err_r != nil { log.debug(err_r); return }
    os.close(file)

    reader: bytes.Reader
    bytes.reader_init(&reader, buffer)
    p_err : io.Error = .None

    riff: [4]u8; _, p_err = bytes.reader_read(&reader, riff[:])
    cksize: [4]u8; _, p_err = bytes.reader_read(&reader, cksize[:])
    waveid: [4]u8; _, p_err = bytes.reader_read(&reader, waveid[:])

    subchunk_id: [4]u8; _, p_err = bytes.reader_read(&reader, subchunk_id[:])
    chunk_size:  [4]u8; _, p_err = bytes.reader_read(&reader, chunk_size[:])
    wFormatTag:  [2]u8; _, p_err = bytes.reader_read(&reader, wFormatTag[:])
    nChannels:   [2]u8; _, p_err = bytes.reader_read(&reader, nChannels[:])
    nSamplesPerSec:  [4]u8; _, p_err = bytes.reader_read(&reader, nSamplesPerSec[:])
    nAvgBytesPerSec: [4]u8; _, p_err = bytes.reader_read(&reader, nAvgBytesPerSec[:])
    nBlockAlign:    [2]u8; _, p_err = bytes.reader_read(&reader, nBlockAlign[:])
    wBitsPerSample: [2]u8; _, p_err = bytes.reader_read(&reader, wBitsPerSample[:])
    subchunk2_id:   [4]u8; _, p_err = bytes.reader_read(&reader, subchunk2_id[:])
    subchunk2_size: [4]u8; _, p_err = bytes.reader_read(&reader, subchunk2_size[:])

    if waveid != "WAVE" { fmt.eprintfln("The file needs to be in WAV format"); os.exit(1) }

    log.debugf("riff: %s", riff)
    log.debugf("cksize: %v", slice_to_T(cksize[:], ^u32)^ + 4)
    log.debugf("waveid: %s", waveid)
    log.debugf("subchunk_id: %s", subchunk_id)
    log.debugf("chunk_size: %v", chunk_size)
    log.debugf("wFormatTag: %x", wFormatTag[:])
    log.debugf("nChannels: %v", slice_to_T(nChannels[:], ^u16)^)
    log.debugf("nSamplesPerSec: %v", slice_to_T(nSamplesPerSec[:], ^u32)^)
    log.debugf("nAvgBytesPerSec: %d", slice_to_T(nAvgBytesPerSec[:], ^u32)^)
    log.debugf("nBlockAlign: %d", slice_to_T(nBlockAlign[:], ^u16)^)
    log.debugf("wBitsPerSample: %d", slice_to_T(wBitsPerSample[:], ^u16)^)
    log.debugf("subchunk2_id: %d", slice_to_T(subchunk2_id[:], ^u16)^)
    log.debugf("subchunk2_id: %s", subchunk2_id[:])
    log.debugf("subchunk2_size: %d", slice_to_T(subchunk2_size[:], ^u16)^)

    pcm_audio := buffer[reader.i:len(reader.s)]

    square_side := cast(int)math.floor(math.sqrt_f32(cast(f32)len(pcm_audio) / 3))
    side_power_2 := cast(int)math.ceil(math.log2(cast(f32)(square_side)))
    h_side := cast(int)math.pow2_f32(side_power_2)

    log.debugf("Audio len: %d", len(pcm_audio))
    log.debugf("Square side len: %d", square_side)
    log.debug("log2 ceil of side:", h_side)
    log.debug("hilbert buffer len:", h_side * h_side)
    if hilbert == true {
        pixels: [][3]u8 = make([][3]u8, h_side * h_side)
        for i in 0..<len(pcm_audio) {
            x, y := d2xy(side_power_2, i)
            pixels[x + (y * h_side)] = pcm_audio[i]
        }
        image_hilbert, ok_i_h := image.pixels_to_image(pixels[:], h_side, h_side)
        if !ok_i_h { log.debug("Error while making image") }
            ok_f_h := bmp.save_to_file("./audio_hilbert.bmp", &image_hilbert)
            log.debug(ok_f_h)
        } else {
            pixels: [][3]u8 = make([][3]u8, square_side * square_side)
            for i in 0..<(square_side * square_side) {
                pixels[i][0] = pcm_audio[i * 3 + 0]
                pixels[i][1] = pcm_audio[i * 3 + 1]
                pixels[i][2] = pcm_audio[i * 3 + 2]
        }
        image_linear, ok_i_l := image.pixels_to_image(pixels[:], square_side, square_side)
        if !ok_i_l { log.debug("Error while making image") }
        ok_f_l := bmp.save_to_file("./audio_linear.bmp", &image_linear)
        log.debug(ok_f_l)
    }
}

// Very unsafe
slice_to_T :: #force_inline proc(slice: $S, $T: typeid) -> T {
    return (cast(T)(raw_data(slice[:])))
}

HELP :: `-h --help      Prints help
-H --hilbert   Converts audio to a Hilbert curve
-L --linear    Converts audio to a linear representation
-D --debug     Show debug logs`

parse_args :: proc() -> (hilbert: bool, name: string, log_lvl: log.Level ) {
    hilbert = false
    name = ""
    log_lvl = .Error
    for arg in os.args[1:] {
        switch arg {
        case "-h": fallthrough; case "--help"    : { fmt.println(HELP); os.exit(0) }
        case "-H": fallthrough; case "--hilbert" : { hilbert = true }
        case "-L": fallthrough; case "--linear"  : { hilbert = false }
        case "-D": fallthrough; case "--debug"   : { log_lvl = .Debug }
        case: name = arg
        }
    }
    return hilbert, name, log_lvl
}

write_image :: proc(name) {
    pixels: [SQUARE * SQUARE][3]u8 = {}
    slice.fill(pixels[:], 0)
        for i in 0..<SQUARE {
        for j in 0..<SQUARE {
            m := j
            n := i
            pixels[m + (n * SQUARE)] = {255, 255, 255}
        }
    }
    image, ok_i := image.pixels_to_image(pixels[:], SQUARE, SQUARE)
    if !ok_i { log.debug("Fuck") }
    ok_f := bmp.save_to_file("./image.bmp", &image)
    log.debug(ok_f)
}

d2xy :: proc(m, d: int) -> (int, int) {
    n, rx, ry, s, x, y: int
    t := d
    n = i4_power( 2, m )
    for s := 1; s < n; s = s * 2 {
        rx = 1 & ( t / 2 )
        ry = 1 & ( t ~ rx )
        x, y = rot ( s, x, y, rx, ry )
        x = x + s * rx
        y = y + s * ry
        t = t / 4
    }
    return x, y
}

i4_power :: proc(i, j: int) -> int {
    k, value: int
    if ( j < 0 ) {
        if ( i == 1 ) { value = 1 }
        else if ( i == 0 ) {
            fmt.eprintf( "\nI4_POWER - Fatal error!\n" );
            fmt.eprintf( "  I^J requested, with I = 0 and J negative.\n" );
            os.exit ( 1 );
        } else {
            value = 0
        }
    }
    else if ( j == 0 ) {
        if ( i == 0 ) {
            fmt.eprintf ( "\nI4_POWER - Fatal error!\n" )
            fmt.eprintf ( "  I^J requested, with I = 0 and J = 0.\n" )
            os.exit ( 1 )
        }
        else { value = 1 }
    }
    else if ( j == 1 ) { value = i }
    else {
        value = 1;
        for k := 1; k <= j; k += 1 { value = value * i }
    }
    return value
}

rot :: proc( n, x, y, rx, ry: int ) -> (int, int) {
    t: int
    x := x
    y := y
    if ( ry == 0 ) {
        // Reflect
        if ( rx == 1 ) {
            x = n - 1 - x
            y = n - 1 - y
        }
        // Flip
        t = x
        x = y
        y = t
    }
    return x, y
}

xy2d :: proc( m, x, y: int ) -> int {
    d, n, rx, ry, s: int
    x := x
    y := y
    n = i4_power ( 2, m )
    for s := n / 2; s > 0; s = s / 2 {
        rx = auto_cast(( x & s ) > 0)
        ry = auto_cast(( y & s ) > 0)
        d = d + s * s * ( ( 3 * rx ) ~ ry )
        x, y = rot ( s, x, y, rx, ry )
    }
    return d
}