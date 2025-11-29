#version 330

#define AO_CAPSULES_MAX 32
#define SHADOW_CAPSULES_MAX 64
#define AO_RATIO_MAX 4.0
#define PI 3.14159265359
highp float;
precision mediump int;

in vec3 fragPosition;
in vec2 fragTexCoord;
in vec3 fragNormal;

uniform vec3 objectColor;
uniform float objectSpecularity;
uniform float objectGlossiness;
uniform float objectOpacity;

uniform int isCapsule;
uniform vec3 capsulePosition;
uniform vec4 capsuleRotation;
uniform float capsuleHalfLength;
uniform float capsuleRadius;
uniform vec3 capsuleStart;
uniform vec3 capsuleVector;

uniform int shadowCapsuleCount;
uniform vec3 shadowCapsuleStarts[SHADOW_CAPSULES_MAX];
uniform vec3 shadowCapsuleVectors[SHADOW_CAPSULES_MAX];
uniform float shadowCapsuleRadii[SHADOW_CAPSULES_MAX];
uniform sampler2D shadowLookupTable;
uniform vec2 shadowLookupResolution;

uniform int aoCapsuleCount;
uniform vec3 aoCapsuleStarts[AO_CAPSULES_MAX];
uniform vec3 aoCapsuleVectors[AO_CAPSULES_MAX];
uniform float aoCapsuleRadii[AO_CAPSULES_MAX];
uniform sampler2D aoLookupTable;
uniform vec2 aoLookupResolution;

uniform vec3 cameraPosition;

uniform float sunStrength;
uniform vec3 sunDir;
uniform vec3 sunColor;
uniform float skyStrength;
uniform vec3 skyColor;
uniform float ambientStrength;
uniform float groundStrength;
uniform float exposure;

out vec4 finalColor;

vec3 ToGamma(in vec3 col) {
    return vec3(pow(col.x, 2.2), pow(col.y, 2.2), pow(col.z, 2.2));
}

vec3 FromGamma(in vec3 col) {
    return vec3(pow(col.x, 1.0/2.2), pow(col.y, 1.0/2.2), pow(col.z, 1.0/2.2));
}

float Saturate(in float x) {
    return clamp(x, 0.0, 1.0);
}

float Square(in float x) {
    return x * x;
}

float FastAcos(in float x) {
    float y = abs(x);
    float p = -0.1565827 * y + 1.570796;
    p *= sqrt(max(1.0 - y, 0.0));
    return x >= 0.0 ? p : PI - p;
}

float FastPositiveAcos(in float x) {
    float p = -0.1565827 * x + 1.570796;
    return p * sqrt(max(1.0 - x, 0.0));
}

vec3 Rotate(in vec4 q, vec3 v) {
    vec3 t = 2.0 * cross(q.xyz, v);
    return v + q.w * t + cross(q.xyz, t);
}

vec3 Unrotate(in vec4 q, vec3 v) {
    return Rotate(vec4(-q.x, -q.y, -q.z, q.w), v);
}

float Checker(in vec2 uv) {
    vec4 uvDDXY = vec4(dFdx(uv), dFdy(uv));
    vec2 w = vec2(length(uvDDXY.xz), length(uvDDXY.yw));
    vec2 i = 2.0*(abs(fract((uv-0.5*w)*0.5)-0.5)-
                  abs(fract((uv+0.5*w)*0.5)-0.5))/w;
    return 0.5 - 0.5*i.x*i.y;
}

float Grid(in vec2 uv, in float lineWidth) {
    vec4 uvDDXY = vec4(dFdx(uv), dFdy(uv));
    vec2 uvDeriv = vec2(length(uvDDXY.xz), length(uvDDXY.yw));
    float targetWidth = lineWidth > 0.5 ? 1.0 - lineWidth : lineWidth;
    vec2 drawWidth = clamp(
        vec2(targetWidth, targetWidth), uvDeriv, vec2(0.5, 0.5));
    vec2 lineAA = uvDeriv * 1.5;
    vec2 gridUV = abs(fract(uv) * 2.0 - 1.0);
    gridUV = lineWidth > 0.5 ? gridUV : 1.0 - gridUV;
    vec2 g2 = smoothstep(drawWidth + lineAA, drawWidth - lineAA, gridUV);
    g2 *= clamp(targetWidth / drawWidth, 0.0, 1.0);
    g2 = mix(g2, vec2(targetWidth, targetWidth),
        clamp(uvDeriv * 2.0 - 1.0, 0.0, 1.0));
    g2 = lineWidth > 0.5 ? 1.0 - g2 : g2;
    return mix(g2.x, 1.0, g2.y);
}

float SphereOcclusion(in vec3 pos, in vec3 nor, in vec3 sph, in float rad) {
    vec3 di = sph - pos;
    float l = length(di);
    float nlAngle = FastAcos(dot(nor, di / l));
    float h  = l < rad ? 1.0 : l / rad;
    vec2 uvs = vec2(nlAngle / PI, (h - 1.0) / (AO_RATIO_MAX - 1.0));
    uvs = uvs * (aoLookupResolution - 1.0) / aoLookupResolution + 0.5 / aoLookupResolution;
    return texture(aoLookupTable, uvs).r;
}

float SphereDirectionalOcclusion(
    in vec3 pos, in vec3 sphere, in float radius, in vec3 coneDir)
{
    vec3 occluder = sphere - pos;
    float occluderLen2 = dot(occluder, occluder);
    vec3 occluderDir = occluder * inversesqrt(occluderLen2);
    float phi = FastAcos(dot(occluderDir, -coneDir));
    float theta = FastPositiveAcos(sqrt(occluderLen2 / (Square(radius) + occluderLen2)));

    vec2 uvs = vec2(phi / PI, theta / (PI / 2.0));
    uvs = uvs * (shadowLookupResolution - 1.0) / shadowLookupResolution + 0.5 / shadowLookupResolution;
    return texture(shadowLookupTable, uvs).r;
}

float CapsuleOcclusion(
    in vec3 pos, in vec3 nor, in vec3 capStart, in vec3 capVec, in float radius)
{
    vec3 ba = capVec;
    vec3 pa = pos - capStart;
    float l = dot(ba, ba);
    float t = abs(l) < 1e-8f ? 0.0 : Saturate(dot(pa, ba) / l);
    return SphereOcclusion(pos, nor, capStart + t * ba, radius);
}

float CapsuleDirectionalOcclusion(
    in vec3 pos, in vec3 capStart, in vec3 capVec, in float capRadius, in vec3 coneDir)
{
    vec3 ba = capVec;
    vec3 pa = capStart - pos;
    vec3 cba = dot(-coneDir, ba) * -coneDir - ba;
    float t = Saturate(dot(pa, cba) / dot(cba, cba));

    return SphereDirectionalOcclusion(pos, capStart + t * ba, capRadius, coneDir);
}

vec2 CapsuleUVs(
    in vec3 pos, in vec3 capPos,
    in vec4 capRot, in float capHalfLength,
    in float capRadius, in vec2 scale)
{
    vec3 loc = Unrotate(capRot, pos - capPos);

    vec2 limit = vec2(
        2.0 * capHalfLength + 2.0 * capRadius,
        PI * capRadius);

    vec2 repeat = max(round(scale * limit), 1.0);

    return (repeat / limit) * vec2(loc.x, capRadius * atan(loc.z, loc.y));
}

vec3 CapsuleNormal(
    in vec3 pos, in vec3 capStart, in vec3 capVec)
{
    vec3 ba = capVec;
    vec3 pa = pos - capStart;
    float h = Saturate(dot(pa, ba) / dot(ba, ba));
    return normalize(pa - h*ba);
}

void main() {
    vec3 pos = fragPosition;
    vec3 nor = fragNormal;
    vec2 uvs = fragTexCoord;

    // Recompute uvs and normals if capsule
    if (isCapsule == 1) {
        uvs = CapsuleUVs(
            pos,
            capsulePosition,
            capsuleRotation,
            capsuleHalfLength,
            capsuleRadius,
            vec2(4.0, 4.0));
        
        nor = CapsuleNormal(pos, capsuleStart, capsuleVector);
    }
    // Compute sun shadow amount
    float sunShadow = 1.0;
    for (int i = 0; i < shadowCapsuleCount; i++) {
        sunShadow = min(sunShadow, CapsuleDirectionalOcclusion(
            pos,
            shadowCapsuleStarts[i],
            shadowCapsuleVectors[i],
            shadowCapsuleRadii[i],
            sunDir));
    }
    // Compute ambient shadow amount
    float ambShadow = 1.0;
    for (int i = 0; i < aoCapsuleCount; i++) {
        ambShadow = min(ambShadow, CapsuleOcclusion(
            pos, nor,
            aoCapsuleStarts[i],
            aoCapsuleVectors[i],
            aoCapsuleRadii[i]));
    }
    // Compute albedo from grid and checker
    float gridFine = Grid(20.0 * uvs, 0.025);
    float gridCoarse = Grid(2.0 * uvs, 0.02);
    float check = Checker(2.0 * uvs);

    vec3 albedo = FromGamma(objectColor) * mix(mix(mix(0.9, 0.95, check), 0.85, gridFine), 1.0, gridCoarse);
    float specularity = objectSpecularity * mix(mix(0.0, 0.75, check), 1.0, gridCoarse);
    
    // Compute lighting
    vec3 eyeDir = normalize(pos - cameraPosition);

    vec3 lightSunColor = FromGamma(sunColor);
    vec3 lightSunHalf = normalize(sunDir + eyeDir);

    vec3 lightSkyColor = FromGamma(skyColor);
    vec3 skyDir = vec3(0.0, -1.0, 0.0);
    vec3 lightSkyHalf = normalize(skyDir + eyeDir);

    float sunFactorDiff = max(dot(nor, -sunDir), 0.0);
    float sunFactorSpec = specularity *
        ((objectGlossiness+2.0) / (8.0 * PI)) *
        pow(max(dot(nor, lightSunHalf), 0.0), objectGlossiness);

    float skyFactorDiff = max(dot(nor, -skyDir), 0.0);
    float skyFactorSpec = specularity *
        ((objectGlossiness+2.0) / (8.0 * PI)) *
        pow(max(dot(nor, lightSkyHalf), 0.0), objectGlossiness);

    float groundFactorDiff = max(dot(nor, skyDir), 0.0);
    
    // Combine
    vec3 ambient = ambShadow * ambientStrength * lightSkyColor * albedo;

    vec3 diffuse = sunShadow * sunStrength * lightSunColor * albedo * sunFactorDiff +
        groundStrength * lightSkyColor * albedo * groundFactorDiff +
        skyStrength * lightSkyColor * albedo * skyFactorDiff;

    float specular = sunShadow * sunStrength * sunFactorSpec + skyStrength * skyFactorSpec;

    vec3 final = diffuse + ambient + specular;
    finalColor = vec4(ToGamma(exposure * final), objectOpacity);
}