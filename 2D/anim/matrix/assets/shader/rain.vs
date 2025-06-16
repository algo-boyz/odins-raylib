#version 330 core

#define PI 3.14159265359

layout(location = 0) in vec2 aPosition;
layout(location = 1) in vec2 aCorner;

out vec2 vUV;
out vec4 vRaindrop, vSymbol, vEffect;
out float vDepth;

uniform sampler2D raindropState, symbolState, effectState;
uniform float density;
uniform vec2 quadSize;
uniform float glyphHeightToWidth, glyphVerticalSpacing;
uniform mat4 camera, transform;
uniform vec2 screenSize;
uniform float time, animationSpeed, forwardSpeed;
uniform bool volumetric;

float rand(const in vec2 uv) {
    const float a = 12.9898, b = 78.233, c = 43758.5453;
    float dt = dot(uv.xy, vec2(a, b)), sn = mod(dt, PI);
    return fract(sin(sn) * c);
}

void main() {
    vUV = (aPosition + aCorner) * quadSize;
    vRaindrop = texture(raindropState, aPosition * quadSize);
    vSymbol = texture(symbolState, aPosition * quadSize);
    vEffect = texture(effectState, aPosition * quadSize);

    // Calculate the world space position
    float quadDepth = 0.0;
    if (volumetric) {
        float startDepth = rand(vec2(aPosition.x, 0.0));
        quadDepth = fract(startDepth + time * animationSpeed * forwardSpeed);
        vDepth = quadDepth;
    }
    vec2 position = (aPosition * vec2(1.0, glyphVerticalSpacing) + aCorner * vec2(density, 1.0)) * quadSize;
    if (volumetric) {
        position.y += rand(vec2(aPosition.x, 1.0)) * quadSize.y;
    }
    vec4 pos = vec4((position - 0.5) * 2.0, quadDepth, 1.0);

    // Convert the world space position to screen space
    if (volumetric) {
        pos.x /= glyphHeightToWidth;
        pos = camera * transform * pos;
    } else {
        pos.xy *= screenSize;
    }

    gl_Position = pos;
}