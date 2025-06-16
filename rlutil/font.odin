package rlutil

import rl "vendor:raylib"

// 0x024F = end of Latin Extended-B
// 0x7F   = end of ASCII https://en.wikipedia.org/wiki/List_of_Unicode_characters
// SDF allows for better scaling of font compared to rasterization
LoadFontFromMemory :: proc(data: [] byte, text_size: int, SDF := false, glyph_count := 0x024F, filter := rl.TextureFilter.TRILINEAR) -> rl.Font {
    font: rl.Font
    font.baseSize = i32(text_size)
    font.glyphCount = 25000
    
    font.glyphs = rl.LoadFontData(transmute(rawptr) raw_data(data), i32(len(data)), 
                  font.baseSize, nil, font.glyphCount, .SDF if SDF else .DEFAULT);

    atlas := rl.GenImageFontAtlas(font.glyphs, &font.recs, font.glyphCount, font.baseSize, 4, 0);
    font.texture = rl.LoadTextureFromImage(atlas);
    rl.UnloadImage(atlas);

    rl.SetTextureFilter(font.texture, filter)
    
    return font
}