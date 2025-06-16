package mini


import "core:fmt"
import "core:os"
import "core:strings"
import rl "vendor:raylib"
import fp "core:path/filepath"
import ma"vendor:miniaudio"

Audio :: struct {
    duration: f32,
    sound: ^ma.sound,
    decoder: ^ma.decoder,
    file_data: []byte,
    cover: rl.Texture,
    loaded: bool,
    has_cover: bool,
    is_paused: bool,
    pause_position: f32, // Store position when paused
    // Audio format info
    total_frames: u64,
    sample_rate: u32,
    channels: u32,
    format: ma.format,
    bitrate: u32, // Estimated bitrate
}

Err :: enum {
    NONE,
    ENGINE_INIT_FAILED,
    FILE_NOT_FOUND,
    FILE_READ_FAILED,
    UNSUPPORTED_FORMAT,
    DECODER_INIT_FAILED,
    SOUND_INIT_FAILED,
    MEMORY_ALLOCATION_FAILED,
    INVALID_AUDIO_CLIP,
    PLAYBACK_FAILED,
    SEEK_FAILED,
}

@(private)
audio_engine: ma.engine
@(private)
audio_engine_initialized: bool = false

init_audio :: proc() -> (bool, Err) {
    if audio_engine_initialized {
        return true, .NONE
    }
    result := ma.engine_init(nil, &audio_engine)
    if result != .SUCCESS {
        fmt.printf("Failed to initialize audio engine: %v\n", result)
        return false, .ENGINE_INIT_FAILED
    }
    audio_engine_initialized = true
    return true, .NONE
}

cleanup_audio_engine :: proc() {
    if !audio_engine_initialized {
        return
    }
    ma.engine_uninit(&audio_engine)
    audio_engine_initialized = false
}

// Enhanced error checking for supported formats
is_audio_format_supported :: proc(filepath: string) -> bool {
    extension := strings.to_lower(fp.ext(filepath))
    switch extension {
    case ".mp3", ".wav":
        return true
    case:
        return false
    }
}

load_audio :: proc(filepath: string) -> (Audio, Err) {
    clip := Audio{}

    // Check if engine is initialized
    if !audio_engine_initialized {
        fmt.println("Audio engine not initialized. Call init_audio() first.")
        return {}, .ENGINE_INIT_FAILED
    }
    // Check if file exists
    if !os.exists(filepath) {
        fmt.printf("Audio file does not exist: '%s'\n", filepath)
        return {}, .FILE_NOT_FOUND
    }
    // Check if format is supported
    if !is_audio_format_supported(filepath) {
        fmt.printf("Unsupported audio format: '%s'\n", filepath)
        return {}, .UNSUPPORTED_FORMAT
    }
    file_data, read_ok := os.read_entire_file(filepath)
    if !read_ok {
        fmt.printf("Failed to read audio file '%s'\n", filepath)
        return {}, .FILE_READ_FAILED
    }
    clip.file_data = file_data

    clip.decoder = new(ma.decoder)
    if clip.decoder == nil {
        delete(clip.file_data)
        return {}, .MEMORY_ALLOCATION_FAILED
    }
    extension := strings.to_lower(fp.ext(filepath))
    decoder_config := ma.decoder_config_init(
        outputFormat = .f32,
        outputChannels = 0,
        outputSampleRate = 0,
    )
    switch extension {
    case ".mp3":
        decoder_config.encodingFormat = .mp3
    case ".wav":
        decoder_config.encodingFormat = .wav
    case:
        decoder_config.encodingFormat = .unknown
    }
    decoder_result := ma.decoder_init_memory(
        pData = raw_data(clip.file_data),
        dataSize = len(clip.file_data),
        pConfig = &decoder_config,
        pDecoder = clip.decoder,
    )
    if decoder_result != .SUCCESS {
        fmt.printf("Failed to initialize decoder for '%s': %v\n", filepath, decoder_result)
        delete(clip.file_data)
        free(clip.decoder)
        return {}, .DECODER_INIT_FAILED
    }
    clip.sound = new(ma.sound)
    if clip.sound == nil {
        ma.decoder_uninit(clip.decoder)
        free(clip.decoder)
        delete(clip.file_data)
        return {}, .MEMORY_ALLOCATION_FAILED
    }
    result := ma.sound_init_from_data_source(
        pEngine = &audio_engine,
        pDataSource = clip.decoder.ds.pCurrent,
        flags = {},
        pGroup = nil,
        pSound = clip.sound,
    )
    if result != .SUCCESS {
        fmt.printf("Failed to load audio file '%s': %v\n", filepath, result)
        ma.decoder_uninit(clip.decoder)
        free(clip.decoder)
        free(clip.sound)
        delete(clip.file_data)
        return {}, .SOUND_INIT_FAILED
    }
    // Get audio format information
    ma.decoder_get_length_in_pcm_frames(clip.decoder, &clip.total_frames)
    ma.decoder_get_data_format(clip.decoder, &clip.format, &clip.channels, &clip.sample_rate, nil, 0)

    clip.duration = f32(clip.total_frames) / f32(clip.sample_rate)
    
    // Estimate bitrate (rough calculation)
    file_size_bits := len(clip.file_data) * 8
    clip.bitrate = u32(f32(file_size_bits) / clip.duration)

    clip.loaded = true
    clip.is_paused = false
    clip.pause_position = 0.0

    // Try to load external cover art eg track.mp3 -> track.png
    if !clip.has_cover {
        stem := fp.stem(filepath);
        dir  := fp.dir(filepath);
        path := fmt.ctprintf("%s", strings.join({dir, "/", stem, ".png"}, ""));

        img := rl.LoadImage(path)
        cover := rl.LoadTextureFromImage(img)
        clip.cover = cover
        clip.has_cover = true
        rl.UnloadImage(img)
    }
    return clip, .NONE
}

unload_audio :: proc(clip: ^Audio) {
    if !clip.loaded {
        return
    }
    if clip.has_cover {
        rl.UnloadTexture(clip.cover)
        clip.has_cover = false
    }
    if clip.sound != nil {
        ma.sound_uninit(clip.sound)
        free(clip.sound)
        clip.sound = nil
    }
    if clip.decoder != nil {
        ma.decoder_uninit(clip.decoder)
        free(clip.decoder)
        clip.decoder = nil
    }
    if clip.file_data != nil {
        delete(clip.file_data)
        clip.file_data = nil
    }
    clip.loaded = false
    clip.is_paused = false
    clip.pause_position = 0.0
}

// Enhanced Playback Control
play_audio :: proc(clip: ^Audio) -> Err {
    if !clip.loaded {
        fmt.println("Audio clip not loaded!")
        return .INVALID_AUDIO_CLIP
    }
    // If paused, resume from pause position
    if clip.is_paused {
        if !set_time(clip, clip.pause_position) {
            return .SEEK_FAILED
        }
        clip.is_paused = false
    }
    result := ma.sound_start(clip.sound)
    if result != .SUCCESS {
        fmt.printf("Failed to play audio: %v\n", result)
        return .PLAYBACK_FAILED
    }
    return .NONE
}

stop_audio :: proc(clip: ^Audio) -> Err {
    if !clip.loaded {
        return .INVALID_AUDIO_CLIP
    }
    result := ma.sound_stop(clip.sound)
    if result != .SUCCESS {
        return .PLAYBACK_FAILED
    }
    clip.is_paused = false
    clip.pause_position = 0.0
    
    // Reset to beginning
    set_time(clip, 0.0)
    
    return .NONE
}

pause_audio :: proc(clip: ^Audio) -> Err {
    if !clip.loaded {
        return .INVALID_AUDIO_CLIP
    }
    if !is_playing(clip) {
        return .NONE // Already paused/stopped
    }
    // Store current position
    clip.pause_position = get_time(clip)
    clip.is_paused = true

    result := ma.sound_stop(clip.sound)
    if result != .SUCCESS {
        return .PLAYBACK_FAILED
    }
    return .NONE
}

resume_audio :: proc(clip: ^Audio) -> Err {
    if !clip.loaded {
        return .INVALID_AUDIO_CLIP
    }
    if !clip.is_paused {
        return .NONE // Not paused
    }
    return play_audio(clip)
}

restart_audio :: proc(clip: ^Audio) -> Err {
    if !clip.loaded {
        return .INVALID_AUDIO_CLIP
    }
    if !set_time(clip, 0.0) {
        return .SEEK_FAILED
    }
    clip.is_paused = false
    clip.pause_position = 0.0

    return play_audio(clip)
}

// Pitch/Speed Control (Essential Audio Features)
set_pitch :: proc(clip: ^Audio, pitch: f32) -> Err {
    if !clip.loaded {
        return .INVALID_AUDIO_CLIP
    }
    // Clamp pitch to reasonable range (0.25x to 4.0x)
    clamped_pitch := clamp(pitch, 0.25, 4.0)
    ma.sound_set_pitch(clip.sound, clamped_pitch)
    return .NONE
}

get_pitch :: proc(clip: ^Audio) -> f32 {
    if !clip.loaded {
        return 1.0
    }
    return ma.sound_get_pitch(clip.sound)
}

// Note: This affects both pitch and speed together
set_playback_rate :: proc(clip: ^Audio, rate: f32) -> Err {
    return set_pitch(clip, rate)
}

get_playback_rate :: proc(clip: ^Audio) -> f32 {
    return get_pitch(clip)
}

// Audio Format Information (Metadata & Information)
get_sample_rate :: proc(clip: ^Audio) -> u32 {
    if !clip.loaded {
        return 0
    }
    return clip.sample_rate
}

get_channels :: proc(clip: ^Audio) -> u32 {
    if !clip.loaded {
        return 0
    }
    return clip.channels
}

get_format :: proc(clip: ^Audio) -> ma.format {
    if !clip.loaded {
        return .unknown
    }
    return clip.format
}

get_bitrate :: proc(clip: ^Audio) -> u32 {
    if !clip.loaded {
        return 0
    }
    return clip.bitrate
}

get_total_frames :: proc(clip: ^Audio) -> u64 {
    if !clip.loaded {
        return 0
    }
    return clip.total_frames
}

// Enhanced state checking
is_paused :: proc(clip: ^Audio) -> bool {
    if !clip.loaded {
        return false
    }
    return clip.is_paused
}

get_playback_state :: proc(clip: ^Audio) -> string {
    if !clip.loaded {
        return "unloaded"
    }
    if clip.is_paused {
        return "paused"
    } else if is_playing(clip) {
        return "playing"
    } else {
        return "stopped"
    }
}

// Existing functions (unchanged)
set_volume :: proc(clip: ^Audio, volume: f32) -> bool {
    if !clip.loaded {
        return false
    }
    clamped_volume := clamp(volume, 0.0, 1.0)
    ma.sound_set_volume(clip.sound, clamped_volume)
    return true
}

get_volume :: proc(clip: ^Audio) -> f32 {
    if !clip.loaded {
        return 0.0
    }
    return ma.sound_get_volume(clip.sound)
}

set_time :: proc(clip: ^Audio, time_seconds: f32) -> bool {
    if !clip.loaded {
        return false
    }
    frame_position := u64(time_seconds * f32(clip.sample_rate))

    if frame_position > clip.total_frames {
        frame_position = clip.total_frames
    }
    result := ma.sound_seek_to_pcm_frame(clip.sound, frame_position)
    
    // Update pause position if currently paused
    if clip.is_paused {
        clip.pause_position = time_seconds
    }
    return result == .SUCCESS
}

get_time :: proc(clip: ^Audio) -> f32 {
    if !clip.loaded {
        return 0.0
    }
    // If paused, return stored position
    if clip.is_paused {
        return clip.pause_position
    }
    cursor: u64
    result := ma.sound_get_cursor_in_pcm_frames(clip.sound, &cursor)

    if result != .SUCCESS {
        return 0.0
    }
    if cursor > clip.total_frames {
        cursor = clip.total_frames
    }
    return f32(cursor) / f32(clip.sample_rate)
}

get_duration :: proc(clip: ^Audio) -> f32 {
    if !clip.loaded {
        return 0.0
    }
    return clip.duration
}

is_playing :: proc(clip: ^Audio) -> bool {
    if !clip.loaded {
        return false
    }
    return bool(ma.sound_is_playing(clip.sound))
}

set_looping :: proc(clip: ^Audio, loop: bool) -> bool {
    if !clip.loaded {
        return false
    }
    ma.sound_set_looping(clip.sound, b32(loop))
    return true
}

is_looping :: proc(clip: ^Audio) -> bool {
    if !clip.loaded {
        return false
    }
    return bool(ma.sound_is_looping(clip.sound))
}