package giflib

import "core:c"

MAJOR :: 5
MINOR :: 1
RELEASE :: 4
ERR :: 0
OK :: 1

STAMP :: "GIFVER"          /* First chars in file - GIF stamp.  */
STAMP_LEN :: len(STAMP) - 1
VERSION_POS :: 3           /* Version first character in stamp. */
GIF87_STAMP :: "GIF87a"    /* First chars in file - GIF stamp.  */
GIF89_STAMP :: "GIF89a"    /* First chars in file - GIF stamp.  */

PixelType :: c.uchar
RowType :: ^c.uchar
ByteType :: c.uchar
PrefixType :: c.uint
Word :: c.int

ColorType :: struct { r, g, b:   ByteType }

ColorMapObj :: struct {
    color_count:    c.int,
    bits_per_pixel: c.int,
    sort_flag:      c.bool,
    colors:      [^]ColorType,
}

ImgDesc :: struct {
    left:      Word,            /* Current image dimensions. */
    top:       Word,
    width:     Word,
    height:    Word,
    interlace: c.bool,          /* Sequential/Interlaced lines. */
    color_map:  ^ColorMapObj,   /* Local color map */
}

// Extension block func codes
CONTINUE_EXT    :: 0x00     /* continuation subblock */
COMMENT_EXT     :: 0xfe     /* comment */
GRAPHICS_EXT    :: 0xf9     /* graphics control (GIF89) */
PLAINTEXT_EXT   :: 0x01     /* plain text */
APPLICATION_EXT :: 0xff     /* application block */

ExtensionBlock :: struct {
    byte_count: c.int,
    bytes:   [^]ByteType,
    func:       c.int,    /* Block function code */
}

SavedImage :: struct {
    image_desc:           ImgDesc,
    raster_bits:          ^ByteType,
    extension_block_count: c.int,           /* Count of extensions before image */  
    extension_blocks:     ^ExtensionBlock,  /* Extensions before image */
}

FileType :: struct {
    width, height:         Word,            /* Size of virtual canvas */
    resolution:            Word,            /* How many colors can we generate? */
    background:            Word,	        /* Background color for virtual canvas */
    aspect_byte:           ByteType,        /* Used to compute pixel aspect ratio */
    color_map:            ^ColorMapObj,     /* Global colormap, NULL if nonexistent. */
    image_count:           c.int,           /* Number of current image (both APIs) */
    image:                 ImgDesc,         /* Current image (low-level API) */
    saved_images:       [^]SavedImage,      /* Image sequence (high-level API) */
    extension_block_count: c.int,           /* Count extensions past last image */
    extension_blocks:   [^]ExtensionBlock,  /* Extensions past last image */ 
    err:                   c.int,           /* Last error condition reported */
    user_data:             rawptr,          /* hook to attach user data (TVT) */
}

// FileType flags
aspect_ratio :: proc(n: f64) -> f64 {
    return n + 15.0/64.0
}

RecordType :: enum c.int {
    UNDEFINED = 0,
    SCREEN_DESC,
    IMAGE_DESC,
    EXTENSION,
    TERMINATE,
}

InputFunc :: proc "c" (gif_file: ^FileType, buffer: ^ByteType, count: c.int) -> c.int
OutputFunc :: proc "c" (gif_file: ^FileType, buffer: ^ByteType, count: c.int) -> c.int

// Graphics control block disposal modes
DISPOSAL_UNSPECIFIED ::  0  /* No disposal specified. */
DISPOSE_DO_NOT       ::  1  /* Leave image in place */
DISPOSE_BACKGROUND   ::  2  /* Set area too background color */
DISPOSE_PREVIOUS     ::  3  /* Restore to previous content */
NO_TRANSPARENT_COLOR :: -1

// Graphics control block
GraphicsControlBlock :: struct {
    disposal_mode:     c.int,
    user_input_flag:   c.bool,  /* User confirmation required before disposal */
    delay_time:        c.int,   /* Pre-display delay in 0.01sec units */
    transparent_color: c.int,   /* Palette index for transparency, -1 if none */
}

FONT_WIDTH  :: 8
FONT_HEIGHT :: 8
// Err codes encode (EGif)
E_GIF_SUCCESS            :: 0
E_GIF_ERR_OPEN_FAILED    :: 1
E_GIF_ERR_WRITE_FAILED   :: 2
E_GIF_ERR_HAS_SCRN_DSCR  :: 3
E_GIF_ERR_HAS_IMAG_DSCR  :: 4
E_GIF_ERR_NO_COLOR_MAP   :: 5
E_GIF_ERR_DATA_TOO_BIG   :: 6
E_GIF_ERR_NOT_ENOUGH_MEM :: 7
E_GIF_ERR_DISK_IS_FULL   :: 8
E_GIF_ERR_CLOSE_FAILED   :: 9
E_GIF_ERR_NOT_WRITEABLE  :: 10
// Err codes decode (DGif)
D_GIF_SUCCEESS           :: 0
D_GIF_ERR_OPEN_FAILED    :: 101
D_GIF_ERR_READ_FAILED    :: 102
D_GIF_ERR_NOT_GIF_FILE   :: 103
D_GIF_ERR_NO_SCRN_DSCR   :: 104
D_GIF_ERR_NO_IMAG_DSCR   :: 105
D_GIF_ERR_NO_COLOR_MAP   :: 106
D_GIF_ERR_WRONG_RECORD   :: 107
D_GIF_ERR_DATA_TOO_BIG   :: 108
D_GIF_ERR_NOT_ENOUGH_MEM :: 109
D_GIF_ERR_CLOSE_FAILED   :: 110
D_GIF_ERR_NOT_READABLE   :: 111
D_GIF_ERR_IMAGE_DEFECT   :: 112
D_GIF_ERR_EOF_TOO_SOON   :: 113

foreign import giflib "system:gif"

@(default_calling_convention="c")
foreign giflib {
    // Encoder
    EGifOpenFileName    :: proc(filename: cstring, test_existence: c.bool, err: ^c.int) -> ^FileType ---
    EGifOpenFileHandle  :: proc(file_handle, err: ^c.int) -> ^FileType ---
    EGifOpen            :: proc(user_ptr: rawptr, write_func: OutputFunc, err: ^c.int) -> ^FileType ---
    EGifSpew            :: proc(gif_file: ^FileType) -> c.int ---
    EGifGetGifVersion   :: proc(gif_file: ^FileType) -> cstring ---
    EGifCloseFile       :: proc(gif_file: ^FileType, err: ^c.int) -> c.int ---
    // Decoder
    DGifOpenFileName    :: proc(filename: cstring, err: ^c.int) -> ^FileType ---
    DGifOpenFileHandle  :: proc(file_handle, err: ^c.int) -> ^FileType ---
    DGifSlurp           :: proc(gif_file: ^FileType) -> c.int ---
    DGifOpen            :: proc(user_ptr: rawptr, read_func: InputFunc, err: ^c.int) -> ^FileType ---
    DGifCloseFile       :: proc(gif_file: ^FileType, err: ^c.int) -> c.int ---
    // Util
    GifQuantizeBuffer   :: proc(width, height, size: ^c.int, r, g, b, out_buf: ^ByteType, out_color_map: ^ColorType) -> c.int ---
    GifErrorString      :: proc(err: c.int) -> cstring ---
    // Color map
    GifMakeMapObject    :: proc(color_count: c.int, color_map: ^ColorType) -> ^ColorMapObj ---
    GifFreeMapObject    :: proc(object: ^ColorMapObj) ---
    GifUnionColorMap    :: proc(color_in1, color_in2: ^ColorMapObj, color_trans_in2: ^PixelType) -> ^ColorMapObj ---
    GifBitSize          :: proc(n: c.int) -> c.int ---
    // Mem alloc
    reallocarray        :: proc(optr: rawptr, nmemb, size: c.size_t) -> rawptr ---
    // Image manipulation
    GifApplyTranslation :: proc(image: ^SavedImage, translation: ^PixelType) ---
    GifAddExtensionBlock :: proc(extension_block_count: ^c.int, extension_blocks: ^^ExtensionBlock,
                                function, len: c.uint, ext_data: ^c.uchar) -> c.int ---
    GifFreeExtensions   :: proc(extension_block_count: ^c.int, extension_blocks: ^^ExtensionBlock) ---
    GifMakeSavedImage   :: proc(gif_file: ^FileType, copy_from: ^SavedImage) -> ^SavedImage ---
    GifFreeSavedImages  :: proc(gif_file: ^FileType) ---
    // Graphics control block
    DGifExtensionToGCB  :: proc(gif_extension_length: c.size_t, gif_extension: ^ByteType,
                               gcb: ^GraphicsControlBlock) -> c.int ---
    EGifGCBToExtension  :: proc(gcb: ^GraphicsControlBlock, gif_extension: ^ByteType) -> c.size_t ---
    DGifSavedExtensionToGCB :: proc(gif_file: ^FileType, image_index: c.int,
                                   gcb: ^GraphicsControlBlock) -> c.int ---
    EGifGCBToSavedExtension :: proc(gcb: ^GraphicsControlBlock, gif_file: ^FileType,
                                   image_index: c.int) -> c.int ---
    // Drawing
    GifDrawText8x8      :: proc(image: ^SavedImage, x, y: c.int, legend: cstring, color: c.int) ---
    GifDrawBox          :: proc(image: ^SavedImage, x, y, w, d, color: c.int) ---
    GifDrawRectangle    :: proc(image: ^SavedImage, x, y, w, d, color: c.int) ---
    GifDrawBoxedText8x8 :: proc(image: ^SavedImage, x, y: c.int, legend: cstring, border, bg, fg: c.int) ---
}

// Check if error code is a giflib error
is_err :: proc(code: c.int) -> bool {
    return code != OK && code != E_GIF_SUCCESS && code != D_GIF_SUCCEESS
}

// Get error message for a given error code
err_msg :: proc(code: c.int) -> string {
    return string(GifErrorString(code))
}