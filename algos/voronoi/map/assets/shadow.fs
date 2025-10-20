#version 330

in vec2 posScreen;
out vec4 finalColour;

uniform sampler2D heightmapTex;
uniform sampler2D voronoiTex;
uniform vec2 pixelSize;
uniform vec3 sunDir;
uniform float globalLightStrength;
uniform vec3 globalLightColour;
uniform float directLightStrength;
uniform vec3 directLightColour;
uniform float timeMs;
uniform float waterLevel;

const int MAX_RAYCAST_ITERATIONS = 200;
const float NORMAL_HEIGHT_MULT = 200.0;
const float SUN_SHADOW_COEF = 0.4;
const float NORMALS_SHADOW_COEF = 0.6;
const float HEIGHT_IS_HIGH_THRESHOLD = 0.3;
const float NORMAL_IS_SLOPE_THRESHOLD = 0.3;
const vec3 COL_SHORELINE = vec3(1.0, 1.0, 1.0);
const vec3 COL_DEEP_WATER = vec3(0.0, 0.431, 0.694);
const vec3 COL_WATER = vec3(0.384, 0.651, 0.663);
const vec3 COL_SAND = vec3(0.839, 0.714, 0.62);
const vec3 COL_GRASS = vec3(0.596, 0.678, 0.353);
const vec3 COL_BUSH = vec3(0.396, 0.522, 0.255);
const vec3 COL_FOREST = vec3(0.278, 0.463, 0.271);
const vec3 COL_STONE = vec3(0.427, 0.463, 0.529);
const vec3 COL_SNOW = vec3(0.824, 0.878, 0.871);
const vec3 COL_SLATE = vec3(0.518, 0.553, 0.604);
const float HEIGHT_SAND = 0.2;
const float HEIGHT_GRASS = 0.275;
const float HEIGHT_BUSH = 0.32;
const float HEIGHT_FOREST = 0.4;
const float HEIGHT_STONE = 0.5;
const float HEIGHT_SNOW = 0.7;
const float HEIGHT_VARIATION_MAGNITUDE = 0.004;
const float WAVE_HEIGHT = 0.001;
const vec2 HEIGHT_VARIATION_FREQ = vec2(0.1);
const float SPECULAR_POWER = 32.0;
const float SPECULAR_LIGHT_STRENGTH = 0.4;

#define HASH_M1 1597334677U
#define HASH_M2 3812015801U

float hash(vec2 p) {
  // Hash function from: https://www.shadertoy.com/view/4dVBzz
  uvec2 q = uvec2(p);
  q *= uvec2(HASH_M1, HASH_M2);
  uint n = q.x ^ q.y;
  n = n * (n ^ (n >> 15));
  return float(n) * (1.0 / float(0xffffffffU));
}

float easeOut(float x, float factor) {
  if (x <= 0.001) return 0.0;
  return clamp(1.0 - pow(1.0 - x, factor), 0.0, 1.0);
}

float unpackHeight(vec4 color) {
  // Unpack a vec4 into a height (0 - 1)
  return (color.r + color.g + color.b + color.a) / 4.0;
}

float getHeightmapHeight(vec2 posScreen) {
  // Extract the exact pixel position
  vec2 posWorld = posScreen / pixelSize;
  vec2 pix = floor(posWorld);
  vec2 pct = fract(posWorld);

  // Sample the texture at the 4 surrounding pixels
  float tl = unpackHeight(texture(heightmapTex, vec2((pix.x - 0.5) * pixelSize.x, (pix.y - 0.5) * pixelSize.y)));
  float bl = unpackHeight(texture(heightmapTex, vec2((pix.x - 0.5) * pixelSize.x, (pix.y + 0.5) * pixelSize.y)));
  float tr = unpackHeight(texture(heightmapTex, vec2((pix.x + 0.5) * pixelSize.x, (pix.y - 0.5) * pixelSize.y)));
  float br = unpackHeight(texture(heightmapTex, vec2((pix.x + 0.5) * pixelSize.x, (pix.y + 0.5) * pixelSize.y)));

  // Interpolate between the 4 pixels
  float t = mix(tl, tr, pct.x);
  float b = mix(bl, br, pct.x);
  return mix(t, b, pct.y);
}

float getWaterNoise(vec2 posScreen) {
  return WAVE_HEIGHT * (texture(voronoiTex, fract(posScreen * 10)).r * 2.0 - 1.0);
}

float getWaterHeight(vec2 posScreen) {
  // Sample wave noise at two different angles with a 200s loop
  float t = timeMs / 200000.0;
  mat2 rot = mat2(cos(0.5), sin(0.5), -sin(0.5), cos(0.50));
  float waveNoise0 = getWaterNoise(posScreen + t);
  float waveNoise1 = getWaterNoise(posScreen * rot - vec2(t, 0.0));
  float waveHeight = waveNoise0 + waveNoise1;

  return waterLevel + waveHeight;
}

float getHeight(vec2 posScreen) {
  // Get the highest height at this position
  return max(getHeightmapHeight(posScreen), getWaterHeight(posScreen));
}

vec3 getSurfaceNormal(vec2 posScreen) {
  // Calculate the normal based on the surrounding heights
  float l = getHeight(vec2(posScreen.x - pixelSize.x, posScreen.y));
  float r = getHeight(vec2(posScreen.x + pixelSize.x, posScreen.y));
  float d = getHeight(vec2(posScreen.x, posScreen.y - pixelSize.y));
  float u = getHeight(vec2(posScreen.x, posScreen.y + pixelSize.y));
  return normalize(vec3((l - r) * NORMAL_HEIGHT_MULT, (d - u) * NORMAL_HEIGHT_MULT, 1.0));
}

vec3 getTerrainColour(vec2 posScreen, float height, vec3 normal) {
  // Add some variation for the bands
  height += (hash(HEIGHT_VARIATION_FREQ * posScreen / pixelSize) * 2.0 - 1.0) * HEIGHT_VARIATION_MAGNITUDE;

  // If steep and high up then use snow
  float flatness = dot(normal, vec3(0.0, 0.0, 1.0));
  float isSteep = 1.0 - step(NORMAL_IS_SLOPE_THRESHOLD, flatness);
  float isHigh = step(HEIGHT_IS_HIGH_THRESHOLD, height);
  if ((isSteep * isHigh) == 1) {
    return COL_SLATE;
  }

  // Otherwise return colour based on height
  if (height < HEIGHT_SAND) {
    return COL_SAND;
  } else if (height < HEIGHT_GRASS) {
    return COL_GRASS;
  } else if (height < HEIGHT_BUSH) {
    return COL_BUSH;
  } else if (height < HEIGHT_FOREST) {
    return COL_FOREST;
  } else if (height < HEIGHT_STONE) {
    return COL_STONE;
  } else if (height < HEIGHT_SNOW) {
    return COL_SNOW;
  } else {
    return vec3(0);
  }
}

vec3 getSceneColour(vec2 posScreen, float terrainHeight, float waterHeight, vec3 normal) {
  float waterDepth = waterHeight - terrainHeight;
  float isWater = step(terrainHeight, waterHeight);

  // Oscillating shoreline effect
  float shorelineAmount = isWater * (1.0 - smoothstep(0.0, 0.01, waterDepth));
  shorelineAmount *= (sin(cos(timeMs / 500.0) * 2.0 + waterDepth * 500.0) + 1.0) / 2.0;

  // Lerp between water colours based on depth
  float shallowDeepLerp = easeOut(waterDepth / waterHeight, 2.0);
  vec3 waterColour = mix(COL_WATER, COL_DEEP_WATER, shallowDeepLerp);
  waterColour = mix(waterColour, COL_SHORELINE, shorelineAmount);

  // Mix water colour with terrain colour
  float terrainWaterLerp = easeOut(waterDepth / waterHeight, 6.0);
  vec3 terrainColour = getTerrainColour(posScreen, terrainHeight, normal);
  vec3 finalColour = mix(terrainColour, waterColour, terrainWaterLerp);

  // Add shoreline effect
  finalColour += shorelineAmount * 0.167;

  return finalColour;
}

void main() {
  // Variables for raycasting from the current position to the sun
  float currentHeight = getHeight(posScreen);
  vec3 currentPos = vec3(posScreen, currentHeight);
  vec3 startPos = currentPos;
  float minStepSize = min(pixelSize.x, pixelSize.y);
  vec3 stepDir = normalize(sunDir);
  float inShadow = 0.0;
  int iterations = 0;

  // Perform raymarching until we know for sure if we are in shadow
  for(; iterations <= MAX_RAYCAST_ITERATIONS; iterations++) {
    if(iterations >= MAX_RAYCAST_ITERATIONS) {
      inShadow = 1.0;
      break;
    }
    currentPos += stepDir * max(minStepSize, (currentPos.z - currentHeight) * 0.05);
    if(currentPos.z > 1.0) {
      inShadow = 0.0;
      break;
    }
    if(currentPos.x < 0.0 || currentPos.x > 1.0 || currentPos.y < 0.0 || currentPos.y > 1.0) {
      inShadow = 0.0;
      break;
    }
    currentHeight = getHeight(currentPos.xy);
    if(currentHeight > currentPos.z) {
      inShadow = 1.0;
      break;
    }
  }

  // Calculate shadow, light and colour values
  float rayDist = length(currentPos - startPos);
  float sunShadow = inShadow * (0.5 * (1.0 - smoothstep(0.0, 0.7, rayDist)));
  vec3 normal = getSurfaceNormal(posScreen);
  float normalsShadow = (1.0 - dot(normal, stepDir)) / 2.0;

  float terrainHeight = getHeightmapHeight(posScreen);
  float waterHeight = getWaterHeight(posScreen);
  vec3 sceneColour = getSceneColour(posScreen, terrainHeight, waterHeight, normal);

  float directShadow = clamp(sunShadow * SUN_SHADOW_COEF + normalsShadow * NORMALS_SHADOW_COEF, 0.0, 1.0);
  vec3 directLight = clamp(directLightColour * (1.0 - directShadow) * directLightStrength, 0.0, 1.0);
  vec3 globalLight = clamp(globalLightColour * globalLightStrength, 0.0, 1.0);

  vec3 viewPos = vec3(0.5, 0.5, 1.0) + sunDir;
  vec3 viewDir = normalize(viewPos - vec3(0.5, 0.5, 0.5));
  float isWater = step(terrainHeight, waterHeight);
  float specularValue = pow(max(dot(normal, viewDir), 0.0), SPECULAR_POWER);
  vec3 specularLight = (1.0 - inShadow) * isWater * SPECULAR_LIGHT_STRENGTH * specularValue * directLightColour;

  // Calculate final light based on the components
  vec3 finalLight = directLight + globalLight + specularLight;
  finalColour = vec4(finalLight * sceneColour, 1.0);
}
