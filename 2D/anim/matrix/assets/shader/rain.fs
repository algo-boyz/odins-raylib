#version 330

#define PI 3.14159265359

in vec2 vUV;
in vec4 vRaindrop, vSymbol, vEffect;
in float vDepth;
out vec4 FragColor;

uniform sampler2D raindropState, symbolState, effectState;
uniform float numColumns, numRows;
uniform sampler2D glyphMSDF, glintMSDF, baseTexture, glintTexture;
uniform float msdfPxRange;
uniform vec2 glyphMSDFSize, glintMSDFSize;
uniform bool hasBaseTexture, hasGlintTexture;
uniform float glyphHeightToWidth, glyphSequenceLength, glyphEdgeCrop;
uniform float baseContrast, baseBrightness, glintContrast, glintBrightness;
uniform float brightnessOverride, brightnessThreshold;
uniform vec2 glyphTextureGridSize;
uniform vec2 slantVec;
uniform float slantScale;
uniform bool isPolar;
uniform bool showDebugView;
uniform bool volumetric;
uniform bool isolateCursor, isolateGlint;

uniform mat2 glyphTransform;

float median3(vec3 i) {
    return max(min(i.r, i.g), min(max(i.r, i.g), i.b));
}

float modI(float a, float b) {
    float m = a - floor((a + 0.5) / b) * b;
    return floor(m + 0.5);
}

vec2 getUV(vec2 uv) {
    if (volumetric) {
        return uv;
    }

    if (isPolar) {
        // Curved space that makes letters appear to radiate from up above
        uv -= 0.5;
        uv *= 0.5;
        uv.y -= 0.5;
        float radius = length(uv);
        float angle = atan(uv.y, uv.x) / (2.0 * PI) + 0.5;
        uv = vec2(fract(angle * 4.0 - 0.5), 1.5 * (1.0 - sqrt(radius)));
    } else {
        // Applies the slant and scales space so the viewport is fully covered
        uv = vec2(
            (uv.x - 0.5) * slantVec.x + (uv.y - 0.5) * slantVec.y,
            (uv.y - 0.5) * slantVec.x - (uv.x - 0.5) * slantVec.y
        ) * slantScale + 0.5;
    }

    uv.y /= glyphHeightToWidth;

    return uv;
}

vec3 getBrightness(vec4 raindrop, vec4 effect, float quadDepth, vec2 uv) {
    float base = raindrop.r + max(0.0, 1.0 - raindrop.a * 5.0);
    bool isCursor = bool(raindrop.g) && isolateCursor;
    float glint = base;
    float multipliedEffects = effect.r;
    float addedEffects = effect.g;

    vec2 textureUV = fract(uv * vec2(numColumns, numRows));
    base = base * baseContrast + baseBrightness;
    if (hasBaseTexture) {
        base *= texture(baseTexture, textureUV).r;
    }
    glint = glint * glintContrast + glintBrightness;
    if (hasGlintTexture) {
        glint *= texture(glintTexture, textureUV).r;
    }

    // Modes that don't fade glyphs set their actual brightness here
    if (brightnessOverride > 0.0 && base > brightnessThreshold && !isCursor) {
        base = brightnessOverride;
    }

    base = base * multipliedEffects + addedEffects;
    glint = glint * multipliedEffects + addedEffects;

    // In volumetric mode, distant glyphs are dimmer
    if (volumetric && !showDebugView) {
        base = base * min(1.0, quadDepth);
        glint = glint * min(1.0, quadDepth);
    }

    return vec3(
        (isCursor ? vec2(0.0, 1.0) : vec2(1.0, 0.0)) * base,
        glint
    ) * raindrop.b;
}

vec2 getSymbolUV(float index) {
    float symbolX = modI(index, glyphTextureGridSize.x);
    float symbolY = (index - symbolX) / glyphTextureGridSize.x;
    symbolY = glyphTextureGridSize.y - symbolY - 1.0;
    return vec2(symbolX, symbolY);
}

vec2 getSymbol(vec2 uv, float index) {
    // resolve UV to cropped position of glyph in MSDF texture
    uv = fract(uv * vec2(numColumns, numRows));
    uv -= 0.5;
    uv = glyphTransform * uv;
    uv *= clamp(1.0 - glyphEdgeCrop, 0.0, 1.0);
    uv += 0.5;
    uv = (uv + getSymbolUV(index)) / glyphTextureGridSize;

    // MSDF: calculate brightness of fragment based on distance to shape
    vec2 symbol;
    {
        vec2 unitRange = vec2(msdfPxRange) / glyphMSDFSize;
        vec2 screenTexSize = vec2(1.0) / fwidth(uv);
        float screenPxRange = max(0.5 * dot(unitRange, screenTexSize), 1.0);

        float signedDistance = median3(texture(glyphMSDF, uv).rgb);
        float screenPxDistance = screenPxRange * (signedDistance - 0.5);
        symbol.r = clamp(screenPxDistance + 0.5, 0.0, 1.0);
    }

    if (isolateGlint) {
        vec2 unitRange = vec2(msdfPxRange) / glintMSDFSize;
        vec2 screenTexSize = vec2(1.0) / fwidth(uv);
        float screenPxRange = max(0.5 * dot(unitRange, screenTexSize), 1.0);

        float signedDistance = median3(texture(glintMSDF, uv).rgb);
        float screenPxDistance = screenPxRange * (signedDistance - 0.5);
        symbol.g = clamp(screenPxDistance + 0.5, 0.0, 1.0);
    }

    return symbol;
}

void main() {
    vec2 uv = getUV(vUV);

    // Unpack the values from the data textures
    vec4 raindropData = volumetric ? vRaindrop : texture(raindropState, uv);
    vec4 symbolData = volumetric ? vSymbol : texture(symbolState, uv);
    vec4 effectData = volumetric ? vEffect : texture(effectState, uv);

    vec3 brightness = getBrightness(
        raindropData,
        effectData,
        vDepth,
        uv
    );
    vec2 symbol = getSymbol(uv, symbolData.r);

    if (showDebugView) {
        FragColor = vec4(
            vec3(
                raindropData.g,
                vec2(
                    1.0 - ((1.0 - raindropData.r) * 3.0),
                    1.0 - ((1.0 - raindropData.r) * 8.0)
                ) * (1.0 - raindropData.g)
            ) * symbol.r,
            1.0
        );
    } else {
        FragColor = vec4(brightness.rg * symbol.r, brightness.b * symbol.g, 0.0);
    }
}