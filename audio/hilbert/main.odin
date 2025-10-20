package main

import "core:slice"
import "core:fmt"
import "core:log"
import "core:image"
import "core:image/bmp"

package main

import "core:log"
import "core:image"
import "core:image/bmp"
import "core:slice"
import "core:math"
import "core:io"
import "core:os"
import "core:fmt"
import "core:bytes"
import "core:flags"

// TODO: Use MINIAUDIO for audio decoding!!
SQUARE :: 16

main :: proc() {
    context.logger = log.create_console_logger()
    context.logger.options = { .Level, .Terminal_Color, .Line, .Procedure }

    hilbert, im_name, log_level := parse_args()
    context.logger.lowest_level = log_level

    if (im_name == "") { fmt.eprintln("No file specified to process"); os.exit(1) }

    // File error
    file, err_f := os.open(im_name)
    if err_f != nil {
        fmt.println("No such file:", im_name)
        log.debug(err_f)
        log.debug(im_name)
        os.exit(1)
    }

    // Buffer the whole file
    file_size, _ := os.file_size(file)
    buffer := make([]u8, file_size)
    n, err_r := os.read_full(file, buffer)
    if err_r != nil { log.debug(err_r); return }
    os.close(file)

    // Prepare for parsing
    reader: bytes.Reader
    bytes.reader_init(&reader, buffer)
    p_err : io.Error = .None

    // https://docs.fileformat.com/audio/wav/
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

    // DEBUG ------------------------------------------------------------------
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

    log.debug("")
    log.debugf("Audio len: %d", len(pcm_audio))
    log.debugf("Square side len: %d", square_side)
    log.debug("")
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

HELP_MESSAGE :: `-h --help      Prints help
-H --hilbert   Converts audio to a Hilbert curve
-L --linear    Converts audio to a linear representation
-D --debug     Show debug logs`

parse_args :: proc() -> (hilbert: bool, im_name: string, log_level: log.Level ) {
    hilbert = false
    im_name = ""
    log_level = .Error

    for arg in os.args[1:] {
        // log.debug(arg)
        switch arg {
        case "-h": fallthrough; case "--help"    : { fmt.println(HELP_MESSAGE); os.exit(0) }
        case "-H": fallthrough; case "--hilbert" : { hilbert = true }
        case "-L": fallthrough; case "--linear"  : { hilbert = false }
        case "-D": fallthrough; case "--debug"   : { log_level = .Debug }
        case: im_name = arg
        }
    }
    return hilbert, im_name, log_level
}

make_image :: proc() {
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