package al

when ODIN_OS == .Windows {
    foreign import alc "openal32.lib" // probably need to adjust path after compile/download
}
when ODIN_OS == .Darwin {
    foreign import alc "/openal-soft/build/libopenal.1.dylib" // tested working
}
when ODIN_OS == .Linux {
    foreign import alc "/openal-soft/build/libopenal.lib" // check path is correct
}

// Type Definitions
ALboolean :: b8
ALchar    :: ALubyte
ALbyte    :: i8
ALubyte   :: u8
ALshort   :: i16
ALushort  :: u16
ALint     :: i32
ALuint    :: u32
ALsizei   :: i32
ALenum    :: i32
ALfloat   :: f32
ALdouble  :: f64

// Standard Constants
FALSE                            : ALenum : 0
TRUE                             : ALenum : 1
NO_ERROR                         : ALenum : FALSE
INVALID_DEVICE                   : ALenum : 0xA001
INVALID_CONTEXT                  : ALenum : 0xA002
INVALID_ENUM                     : ALenum : 0xA003
INVALID_VALUE                    : ALenum : 0xA004
OUT_OF_MEMORY                    : ALenum : 0xA005

// Device Properties
FREQUENCY                        : ALenum : 0x1007
REFRESH                          : ALenum : 0x1008
SYNC                             : ALenum : 0x1009
MONO_SOURCES                     : ALenum : 0x1010
STEREO_SOURCES                   : ALenum : 0x1011
DEFAULT_DEVICE_SPECIFIER         : ALenum : 0x1004
DEVICE_SPECIFIER                 : ALenum : 0x1005
EXTENSIONS                       : ALenum : 0x1006
MAJOR_VERSION                    : ALenum : 0x1000
MINOR_VERSION                    : ALenum : 0x1001
ATTRIBUTES_SIZE                  : ALenum : 0x1002
ALL_ATTRIBUTES                   : ALenum : 0x1003
DEFAULT_ALL_DEVICES_SPECIFIER    : ALenum : 0x1012
ALL_DEVICES_SPECIFIER            : ALenum : 0x1013

// Capture Properties
CAPTURE_DEVICE_SPECIFIER         : ALenum : 0x310
CAPTURE_DEFAULT_DEVICE_SPECIFIER : ALenum : 0x311
CAPTURE_SAMPLES                  : ALenum : 0x312

// Alternative Namespace Constants (with  prefix)
INVALID                          : ALenum : -1
NONE                             : ALenum : 0
SOURCE_RELATIVE                  : ALenum : 0x202
CONE_INNER_ANGLE                 : ALenum : 0x1001
CONE_OUTER_ANGLE                 : ALenum : 0x1002
PITCH                            : ALenum : 0x1003
POSITION                         : ALenum : 0x1004
DIRECTION                        : ALenum : 0x1005
VELOCITY                         : ALenum : 0x1006
LOOPING                          : ALenum : 0x1007
BUFFER                           : ALenum : 0x1009
GAIN                             : ALenum : 0x100A
MIN_GAIN                         : ALenum : 0x100D
MAX_GAIN                         : ALenum : 0x100E
ORIENTATION                      : ALenum : 0x100F
CHANNEL_MASK                     : ALenum : 0x3000

// Source States
SOURCE_STATE                     : ALenum : 0x1010
INITIAL                          : ALenum : 0x1011
PLAYING                          : ALenum : 0x1012
PAUSED                           : ALenum : 0x1013
STOPPED                          : ALenum : 0x1014
BUFFERS_QUEUED                   : ALenum : 0x1015
BUFFERS_PROCESSED                : ALenum : 0x1016

// Source Properties
SEC_OFFSET                       : ALenum : 0x1024
SAMPLE_OFFSET                    : ALenum : 0x1025
BYTE_OFFSET                      : ALenum : 0x1026
SOURCE_TYPE                      : ALenum : 0x1027
STATIC                           : ALenum : 0x1028
STREAMING                        : ALenum : 0x1029
UNDETERMINED                     : ALenum : 0x1030

// Buffer Formats
FORMAT_MONO8                     : ALenum : 0x1100
FORMAT_MONO16                    : ALenum : 0x1101
FORMAT_STEREO8                   : ALenum : 0x1102
FORMAT_STEREO16                  : ALenum : 0x1103

// Distance Model Properties
REFERENCE_DISTANCE               : ALenum : 0x1020
ROLLOFF_FACTOR                   : ALenum : 0x1021
CONE_OUTER_GAIN                  : ALenum : 0x1022
MAX_DISTANCE                     : ALenum : 0x1023

// Buffer Properties
FREQ_BUFFER                      : ALenum : 0x2001
BITS                             : ALenum : 0x2002
CHANNELS                         : ALenum : 0x2003
SIZE                             : ALenum : 0x2004

// Buffer States
UNUSED                           : ALenum : 0x2010
PENDING                          : ALenum : 0x2011
PROCESSED                        : ALenum : 0x2012

// Alternative Error Codes
INVALID_NAME                     : ALenum : 0xA001
ILLEGAL_ENUM                     : ALenum : 0xA002
ILLEGAL_COMMAND                  : ALenum : 0xA004
INVALID_OPERATION                : ALenum : 0xA004

// Context Properties
VENDOR                           : ALenum : 0xB001
VERSION                          : ALenum : 0xB002
RENDERER                         : ALenum : 0xB003
EXT                      		 : ALenum : 0xB004

// Global Properties
DOPPLER_FACTOR                   : ALenum : 0xC000
DOPPLER_VELOCITY                 : ALenum : 0xC001
SPEED_OF_SOUND                   : ALenum : 0xC003

// Distance Models
DISTANCE_MODEL                   : ALenum : 0xD000
INVERSE_DISTANCE                 : ALenum : 0xD001
INVERSE_DISTANCE_CLAMPED         : ALenum : 0xD002
LINEAR_DISTANCE                  : ALenum : 0xD003
LINEAR_DISTANCE_CLAMPED          : ALenum : 0xD004
EXPONENT_DISTANCE                : ALenum : 0xD005
EXPONENT_DISTANCE_CLAMPED        : ALenum : 0xD006
Device  :: distinct rawptr;
Context :: distinct rawptr;


@(default_calling_convention="c") 
foreign alc {
	@(link_name="alcCreateContext") create_context :: proc(device: Device, attrlist: ^ALint) -> Context ---
	@(link_name="alcMakeContextCurrent") make_context_current :: proc(ctx: Context) -> ALenum ---
	@(link_name="alcProcessContext") process_context :: proc(ctx: Context) ---
	@(link_name="alcSuspendContext") suspend_context :: proc(ctx: Context) ---
	@(link_name="alcDestroyContext") destroy_context :: proc(ctx: Context) ---
	@(link_name="alcGetCurrentContext") get_current_context :: proc() -> Context ---
	@(link_name="alcGetContextsDevice") get_contexts_device :: proc(ctx: Context) -> Device ---
	@(link_name="alcOpenDevice") open_device :: proc(devicename: ^u8) -> Device ---
	@(link_name="alcCloseDevice") close_device :: proc(device: Device) ---
	@(link_name="alcGetError") get_error :: proc(device: Device) -> ALenum ---
	@(link_name="alcIsExtensionPresent") is_extension_present :: proc(device: Device, extname: ^u8) -> ALboolean ---
	@(link_name="alcGetProcAddress") get_proc_address :: proc(device: Device, funcname: ^u8) -> ^u8 ---
	@(link_name="alcGetEnumValue") get_enum_value :: proc(device: Device, enumname: ^u8) -> ALenum ---
	@(link_name="alcGetString") get_string :: proc(device: Device, param: ALenum) -> ^u8 ---
	@(link_name="alcGetIntegerv") get_integerv :: proc(device: Device, param: ALenum, size: ALsizei, data: ^ALint) ---
	@(link_name="alcCaptureOpenDevice") capture_open_device :: proc(devicename: ^u8, frequency: ALuint, format: ALenum, buffersize: ALsizei) -> Device ---
	@(link_name="alcCaptureCloseDevice") capture_close_device :: proc(device: Device) ---
	@(link_name="alcCaptureStart") capture_start :: proc(device: Device) ---
	@(link_name="alcCaptureStop") capture_stop :: proc(device: Device) ---
	@(link_name="alcCaptureSamples") capture_samples :: proc(device: Device, buffer: ^u8, samples: ALsizei) ---
}
