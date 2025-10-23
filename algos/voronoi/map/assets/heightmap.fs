#version 330

in vec2 posScreen;
out vec4 finalColour;
uniform vec2 screenRatio;

const float HEIGHT_NOISE_SCALE = 6.0;
const float HEIGHT_MOUNTAIN_SCALE = 1.1;
const float HEIGHT_MOUNTAIN_POWER = 1.6;
const int FBM_OCTAVE_COUNT = 8;
const float FBM_INITIAL_AMPLITUDE = 0.6;
const float FBM_INITIAL_AMPLITUDE_SCALE = 0.42;
const float FB_OCTAVE_SCALE = 2.0;
const float FBM_OCTAVE_SHIFT = 100.0;

float hash(vec2 p) {
  // 2D hash from: https://www.shadertoy.com/view/4dS3Wd
  vec3 p3 = fract(vec3(p.xyx) * 0.13);
  p3 += dot(p3, p3.yzx + 3.333);
  return fract((p3.x + p3.y) * p3.z);
}

float noise(vec2 x) {
  // 2D noise from: https://www.shadertoy.com/view/4dS3Wd
  // Lerp between 4 corners using smoothstep
  // Returns value between 0 - 1
  vec2 i = floor(x);
  vec2 f = fract(x);
  float a = hash(i);
  float b = hash(i + vec2(1.0, 0.0));
  float c = hash(i + vec2(0.0, 1.0));
  float d = hash(i + vec2(1.0, 1.0));
  vec2 u = f * f * (3.0 - 2.0 * f);
  return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

float fbm(vec2 x) {
  // Fractal Brownian Motion
  float value = 0.0;
  float amplitude = FBM_INITIAL_AMPLITUDE;

  // For each octave: grab noise, scale/rotate/shift sample position, then reduce amplitude
  mat2 octaveRot = mat2(cos(0.5), sin(0.5), -sin(0.5), cos(0.5));
  vec2 octaveShift = vec2(FBM_OCTAVE_SHIFT);
  for(int i = 0; i < FBM_OCTAVE_COUNT; ++i) {
    value += amplitude * noise(x);
    x = octaveRot * x * FB_OCTAVE_SCALE + octaveShift;
    amplitude *= FBM_INITIAL_AMPLITUDE_SCALE;
  }

  return value;
}

float getHeight(vec2 pos) {
  // Sample FBM noise with scaled position
  float n = fbm(pos * HEIGHT_NOISE_SCALE);

  // Scale the noise to be more mountainous
  n = pow(n * HEIGHT_MOUNTAIN_SCALE, HEIGHT_MOUNTAIN_POWER);

  // Gradient magnitude from centre
  float d = length(pos - vec2(0.5)) * 2.0;
  return clamp(n * (1.0 - d), 0, 1);
}

vec4 packHeight(float height) {
  // Packs the height value (0 - 1) across vec4
  vec4 packedHeight = vec4(0.0);
  height *= 4.0;
  packedHeight.r = clamp(height - 3.0, 0.0, 1.0);
  packedHeight.g = clamp(height - 2.0, 0.0, 1.0);
  packedHeight.b = clamp(height - 1.0, 0.0, 1.0);
  packedHeight.a = clamp(height, 0.0, 1.0);
  return packedHeight;
}

void main() {
  vec2 pos = posScreen * screenRatio;
  float height = getHeight(pos);
  finalColour = packHeight(height);
}
