#version 330 core

uniform float u_time;
uniform float u_aspect;
uniform vec2 u_mouse_pos;
uniform vec2 u_resolution;

in vec2 v_tex_coord;
out vec4 frag_color;

// Configuration defines - converted to constants for easier tweaking
const float BETA = 0.8;
const bool SPACE_BACKGROUND_ON = true;
const bool SUN_LAVA_ON = true;
const bool SUN_ERUPTION_ON = true;
const bool SUN_3D_SURFACE_ON = true;
const bool LAYER_2D_ON = true;

#define globalTime (u_time + 28.48)
const float AnimationMoveRatio = 1.0;

// UY Scuti configuration - set to false for normal sun
const bool UY_Scuti = false;
const float LightSpeed = UY_Scuti ? (0.430735/1708.0) : 0.430735;
const float SUN_DENSITY = UY_Scuti ? 500.0 : 55.0;
const float SUN_RAD_PER_S = UY_Scuti ? 2.692E-9 : 2.692E-2;

// Optical speed effect
const float gDoppler = 1.0;      // Proportion Red/Blueshift rays (real = 1)
const float gIntensity = 0.5;    // Proportion Solid angle light flux (real = 1)
const float minIntensity = 0.05; // min visible gIntensity (real = 0)

float hash(in float n) { 
    return fract(sin(n) * 43758.5453123); 
}

// Simple noise function without texture lookup
float noise(in vec3 x) {
    vec3 p = floor(x);
    vec3 f = fract(x);
    f = f * f * (3.0 - 2.0 * f);
    
    float n = p.x + p.y * 157.0 + 113.0 * p.z;
    return mix(
        mix(mix(hash(n + 0.0), hash(n + 1.0), f.x),
            mix(hash(n + 157.0), hash(n + 158.0), f.x), f.y),
        mix(mix(hash(n + 113.0), hash(n + 114.0), f.x),
            mix(hash(n + 270.0), hash(n + 271.0), f.x), f.y), f.z);
}

bool intersectSphere(in vec3 ro, in vec3 rd, in float r, out float dist, out float edge) {
    float b = dot(rd, -ro);
    float d = b * b - dot(ro, ro) + r * r;
    if (d < 0.0) return false;
    edge = sqrt(d);
    dist = b - edge;
    return dist > 0.0;
}

// Space background
const int iterations = 17;
const float formuparam = 0.53;
const int volsteps = 6;
const float stepsize = 0.1;
const float tile = 0.850;
const float brightness = 0.0015;
const float darkmatter = 1.500;
const float distfading = 0.530;
const float saturation = 0.650;

vec4 space(in vec3 dir) {
    if (!SPACE_BACKGROUND_ON) return vec4(0);
    
    vec3 from = vec3(1.0, 0.5, 0.5);
    float s = 0.1, fade = 1.0;
    vec3 v = vec3(0.0);
    
    for (int r = 0; r < volsteps; r++) {
        vec3 p = from + s * dir * 0.5;
        p = abs(vec3(tile) - mod(p, vec3(tile * 2.0))); // tiling fold
        float a = 0.0, pa = 0.0;
        
        for (int i = 0; i < iterations; i++) { 
            p = abs(p) / dot(p, p) - formuparam; // the magic formula
            a += abs(length(p) - pa); // absolute sum of average change
            pa = length(p);
        }
        
        float dm = max(0.0, darkmatter - a * a * 0.001); //dark matter
        a *= a * a; // add contrast
        if (r > 6) fade *= 1.0 - dm; // dark matter, don't render near
        v += fade + vec3(s, s*s, s*s*s*s) * a * brightness * fade; // coloring based on distance
        fade *= distfading; // distance fading
        s += stepsize;
    }
    v = mix(vec3(length(v)), v, saturation); //color adjust
    return vec4(v * 0.02, 1.0);    
}

// Sun lava texture
const mat3 msun = mat3(0.0, 0.8, 0.6, -0.8, 0.36, -0.48, -0.6, -0.48, 0.64);

float smoothNoise(in vec3 q) {
    float f  = 0.5000 * noise(q); q = msun * q * 2.01;
    f += 0.2500 * noise(q); q = msun * q * 2.02;
    f += 0.1250 * noise(q);
    return f;
}

const int NB_LUT = 4;

vec3 mapping(float dist, float vmin, float vmax, mat4 LUT, vec4 LUT_DIST) {
    float distLut = (dist - vmin) / vmax;
    vec3 c = vec3(0);
    for (int i = 0; i < NB_LUT; ++i) {
        if (distLut < LUT_DIST[i + 1]) {
            c = mix(LUT[i].xyz, LUT[i + 1].xyz, (distLut - LUT_DIST[i]) / (LUT_DIST[i + 1] - LUT_DIST[i]));
            break;
        }
    }
    return c;
}

const mat4 LAVA_COLOR = mat4(0.0, 0.0, 0.0, 0.0, 0.7, 0.3, 0.1, 1.0, 0.9, 0.6, 0.3, 1.0, 2.0, 3.9, 2.5, 1.0);
const vec4 LAVA_COLOR_DIST = vec4(0.0, 0.35, 0.55, 1.0);

float SunTwinkleFac;

vec3 getSunColor(in vec3 p, in float time) {
    if (!SUN_LAVA_ON) return vec3(1.0, 0.8, 0.4);
    
    float lava = smoothNoise((p + vec3(time * 0.01)) * SUN_DENSITY);
    vec3 color = mapping(1.0 - sqrt(lava), 0.0, 1.0, LAVA_COLOR, LAVA_COLOR_DIST);
    color += color * color;
    return SunTwinkleFac * color;
}

// Eruption effect
const float ray_brightness = 15.0;
const float GAMMA = 6.0;
const float ray_density = 3.5;
const float curvature = 28.0;
const float RED = 4.0;
const float GREEN = 1.0;
const float BLUE = 0.3;
const float SIZE = 0.04;

mat2 m2 = mat2(0.8, 0.6, -0.6, 0.8);

float fbm(in vec2 p) {    
    float z = 2.0, rz = -0.0005;
    p *= 0.525;
    for (int i = 1; i < 7; i++) {
        rz += abs((noise(vec3(p * 0.01, globalTime)) - 0.5) * 2.0) / z;
        z = z * 2.0;
        p = p * 2.0 * m2;
    }
    return rz;
}

vec4 fireTexture(in vec2 uv, in float t, in float z) {
    uv *= curvature * SIZE;
    uv.y -= 1.5;
    float gam = mix(GAMMA * 2.0, 0.0, 0.5 + 0.5 * z);
    float density = ray_density;
    float r = sqrt(dot(uv, uv));
    float x = dot(normalize(uv), vec2(0.35, 0.0)) + t;
    float y = dot(normalize(uv), vec2(0.0, 0.65)) + t;
 
    float val = fbm(vec2(r + y * density, x + density));
    val = smoothstep(gam * 0.02 - 0.1, ray_brightness + (gam * 0.02 - 0.1) + 0.001, val);
    val *= 15.0;
    vec3 col = val / vec3(RED, GREEN, BLUE);
    col = 1.0 - col;
    float rad = 30.0 * noise(vec3(uv, globalTime));
    col = mix(col, vec3(1.0), rad - 266.667 * r);
    uv.y = uv.y + 1.2;
    r = length(uv);
    col = col * (1.0 - clamp(0.3 * abs(r * r), 0.0, 1.0));
    col = clamp(col, 0.0, 100.0);
    return vec4(col, smoothstep(length(col), 0.0, 0.2));
}

struct Base {
    mat3 base;
    vec3 o;
};

Base basis(in vec3 o, in vec3 n) { 
    Base b;
    float a = 1.0 / (1.0 + n.z);
    float c = -n.x * n.y * a;
    b.base = mat3(n.x, n.y, n.z, 
                  1.0 - n.x * n.x * a, c, -n.x,  
                  c, 1.0 - n.y * n.y * a, -n.y);
    b.o = o;
    return b;
}

vec4 colorEruption(in vec3 ro, in vec3 rd, in float time, in float kMax, vec3 refVec, in float h, in vec2 scale) {
    if (!SUN_ERUPTION_ON) return vec4(0);
    
    refVec = normalize(refVec);
    vec3 pAnim = -(1.0 + h) * refVec;
    Base b = basis(pAnim, refVec);
    vec4 textColor, col = vec4(0);
    
    // Change basis
    ro = (ro - b.o) * b.base;
    rd = rd * b.base;
    float k = (abs(rd.z) < 0.0001) ? -1.0 : -ro.z / rd.z;   // intersection plane y=0
    float dk = abs(0.003 / rd.z);
    vec3 p = ro + k * rd;
    
    if (k > 0.0 && abs(p.x) < 0.1 * scale.x && abs(p.y) < 0.1 * scale.y) {
        k = max(0.0, k - 13.0 * dk); 
        float tSun = 10.0 * scale.x - time * 0.04;
        
        for (int i = 0; i < 26; i++) {
            if (k > kMax) break;
            p = ro + k * rd;
            textColor = fireTexture(scale * p.yx, tSun, 0.75 * float(i) * p.z / rd.z);
            col += 0.08 * textColor;
            k += dk;
        }
    }
    return col;
}

// 3D Surface
const float VOLUMIC_SURFACE_TICKNESS = 0.018;
const int VOLUMIC_SURFACE_NB_STEP = 40;
const float VOLUMIC_SURFACE_RAY_STEP = 0.0033;
const float VOLUMIC_SURFACE_INTENSITY = 0.04;

vec4 getLightRays(vec3 ro, vec3 rd, in float time) {
    if (!SUN_3D_SURFACE_ON) return vec4(0);
    
    vec3 p = vec3(0.0);
    float edge, dist, r = 1.0 + VOLUMIC_SURFACE_TICKNESS;
    bool hit = intersectSphere(ro - p, rd, r, dist, edge);
    vec2 uv;    
    vec4 sampleCol, c = vec4(0);
    
    if (hit) {
        vec3 pos = ro + rd * dist;
        float light, d, rout;
        
        // ray-march into volume
        for (int i = 0; i < VOLUMIC_SURFACE_NB_STEP; i++) {
            d = length(pos);
            if (d < 1.0 || d > r + 0.001 || c.a > 0.95) break;
            sampleCol.rgb = vec3(0.5, 0.01, 0.08) + getSunColor(normalize(pos), time);
            light = length(sampleCol.rgb);
            rout = 1.0 + VOLUMIC_SURFACE_TICKNESS * clamp(light * light, 0.0, 1.0);
            sampleCol.a = light * (rout - d) / (rout - 1.0);
            sampleCol.a *= sampleCol.a; 
            sampleCol.rgb *= sampleCol.a;                
            c += VOLUMIC_SURFACE_INTENSITY * sampleCol * (1.0 - c.a);
            pos += rd * VOLUMIC_SURFACE_RAY_STEP;
        }
    }    
    return c;
}

vec4 render(in vec3 ro, in vec3 rd, in float time) {
    // Rotate view to integrate sun rotation 
    float cosSunRot = cos(1.6 + time * SUN_RAD_PER_S);
    float sinSunRot = sin(1.6 + time * SUN_RAD_PER_S);
    mat2 rotSun = mat2(cosSunRot, sinSunRot, -sinSunRot, cosSunRot);
    vec3 rdSpace = rd.yzx;
    ro.zx *= rotSun;
    rd.zx *= rotSun;
    
    float dist, edge;
    vec4 color;
    
    if (intersectSphere(ro, rd, 1.0, dist, edge)) {
        vec3 pos = ro + rd * dist;
        vec3 nor = normalize(pos);
        float lDif = clamp(dot(nor, -rd), 0.01, 1.0);
        float a = smoothstep(0.0, 0.5, sqrt(edge)); 
        vec3 oCol = getSunColor(pos, time);
        oCol = mix(oCol, vec3(1.8, 0.4, 0.4), 1.0 - a * 0.95); // atmosphere
        oCol = oCol * (0.5 + 0.5 * lDif);
        color = vec4(oCol, a);
    } else {
        color = space(rdSpace);
        dist = 1000.0;
    }
    
    if (color.a < 1.0) {
        color = vec4(mix(space(rdSpace).rgb, color.rgb, color.a), 1.0);
    }   
    
    if (SUN_ERUPTION_ON) {
        vec4 textColor = colorEruption(ro, rd, time, dist, vec3(-0.4, 0.1, 0.35), 0.12, vec2(3.0, 6.0));
        vec4 textColor2 = colorEruption(ro, rd, time, dist, vec3(0.7, -1.0, 0.0), 0.2, vec2(6.0, 4.1));
        color = color * (1.0 - 0.3 * textColor.a) + 0.5 * textColor * textColor.a;
        color = color * (1.0 - 0.3 * textColor2.a) + 0.5 * textColor2 * textColor2.a;
    }
    
    if (SUN_3D_SURFACE_ON) {
        vec4 textColor3 = getLightRays(ro, rd, time);
        color = color * (1.0 - 0.3 * textColor3.a) + 0.5 * textColor3 * textColor3.a;
    }
    
    return color;
}

// Wavelengths
const float lUltraViolet = 340.0;
const float lBlue = 460.0;
const float lGreen = 520.0;
const float lRed = 700.0;
const float lInfraRed = 1000.0;

float initRayForSpeed(in vec3 ro, in vec3 rd, in vec3 velocity, out vec3 ray, out float intensity, out float relativeTime) {
    float beta = length(velocity); // = (velocity of observer) / (speed of light)
    float gamma = 1.0 / sqrt(1.0 - beta * beta);
    
    if (beta == 0.0) { // No speed => classical case
        ray = rd;
        intensity = 1.0;
        relativeTime = globalTime;
        return 1.0;
    }
    
    // Relative time for non moving scene
    relativeTime = gamma * globalTime;
    
    // Angular Compression
    vec3 vn = normalize(velocity);     // Velocity normal
    float cosa = dot(rd, vn);         // Length of parallel component to velocity
    float cosb = (cosa - beta) / (1.0 - cosa * beta);
    vec3 p = rd - cosa * vn;          // Perpendicular component to velocity
    ray = cosb * vn + sqrt(1.0 - cosb * cosb) * normalize(p); 

    intensity = gamma * (1.0 - beta * cosb) * (1.0 - beta * cosb);
    intensity = 1.0 + (intensity - 1.0) * gIntensity; // Partial intensities for clarity
    return (gDoppler == 0.0) ? 1.0 : gamma * (1.0 - beta * cosb);
}

float shiftColor(in float sb, in vec3 c, in float cuv, in float cir) {
    if (sb < lUltraViolet) return cuv * sb / lUltraViolet;
    if (sb < lBlue)        return (c.b - cuv) * (sb - lUltraViolet) / (lBlue - lUltraViolet) + cuv;
    if (sb < lGreen)       return (c.g - c.b) * (sb - lBlue)        / (lGreen - lBlue)       + c.b;
    if (sb < lRed)         return (c.r - c.g) * (sb - lGreen)       / (lRed - lGreen)        + c.g;
    if (sb < lInfraRed)    return (cir - c.r) * (sb - lRed)         / (lInfraRed - lRed)     + c.r;
    return (lInfraRed / sb) * cir;
}

vec3 relativisticRayTracing(in vec3 ro, in vec3 rd, in vec3 velocity) {
    float relativeTime; // Relative time for non moving objects
    vec3 r;             // New ray
    float doppler;      // Spectrum shift
    float illumination, intensity;
    
    // Shift ray
    doppler = initRayForSpeed(ro, rd, velocity, r, intensity, relativeTime);  
    
    //Raymarch
    vec3 c = render(ro, r, relativeTime).xyz;
    
    if (gIntensity != 0.0 && length(c) > minIntensity) {
        c = clamp(c / intensity, minIntensity, 100.0);
    }
    
    if (gDoppler != 0.0) {
        doppler = 1.0 + (doppler - 1.0) * gDoppler;
        float cuv = (0.5 * c.b + 0.25 * c.g + 0.125 * c.r); // ultraviolet
        float cir = (0.5 * c.r + 0.25 * c.g + 0.125 * c.b); // infrared
        return vec3(shiftColor(lRed / doppler,   c, cuv, cir), // Shifted wavelengths
                    shiftColor(lGreen / doppler, c, cuv, cir),
                    shiftColor(lBlue / doppler,  c, cuv, cir));
    }
    return c;
}

// 2D UI Elements
float sdCircle(vec2 p, float s) {
    return length(p) - s;
}

float sdEllipse(vec2 p, in vec2 ab) {
    p = abs(p); 
    if (p.x > p.y) { p = p.yx; ab = ab.yx; }
    float l = ab.y * ab.y - ab.x * ab.x;
    float m = ab.x * p.x / l; 
    float n = ab.y * p.y / l; 
    float m2 = m * m;
    float n2 = n * n;
    float c = (m2 + n2 - 1.0) / 3.0; 
    float c3 = c * c * c;
    float d = c3 + m2 * n2, q = d + m2 * n2;
    float g = m + m * n2;
    float co;
    
    if (d < 0.0) {
        float p = acos(q / c3) / 3.0;
        float s = cos(p);
        float t = sin(p) * sqrt(3.0);
        float rx = sqrt(-c * (s + t + 2.0) + m2);
        float ry = sqrt(-c * (s - t + 2.0) + m2);
        co = (ry + sign(l) * rx + abs(g) / (rx * ry) - m) / 2.0;
    } else {
        float h = 2.0 * m * n * sqrt(d);
        float s = sign(q + h) * pow(abs(q + h), 1.0 / 3.0);
        float u = sign(q - h) * pow(abs(q - h), 1.0 / 3.0);
        float rx = -s - u - c * 4.0 + 2.0 * m2;
        float ry = (s - u) * sqrt(3.0);
        float rm = sqrt(rx * rx + ry * ry);
        float p = ry / sqrt(rm - rx);
        co = (p + 2.0 * g / rm - m) / 2.0;
    }
    float si = sqrt(1.0 - co * co);
    vec2 closestPoint = vec2(ab.x * co, ab.y * si);    
    return length(closestPoint - p) * sign(p.y - closestPoint.y);
}

float udRoundBox(vec2 p, vec2 b, float r) {
    return length(max(abs(p) - b, 0.0)) - r;
}

float sunIcon(vec2 p, float s, float k) {
    vec2 ab = vec2(s * k, s);
    float d = sdEllipse(p, ab);
    return d;
}

float spaceshipIcon(in vec2 p) {
    p.x += 1.5;
    return min(sdEllipse(p, vec2(3.0, 1.35)), 
           min(sdEllipse(p - vec2(-2.7, 1.125), vec2(1.65, 0.75)),
               sdEllipse(p - vec2(-2.7, -1.125), vec2(1.65, 0.75))));
}

float clock(in vec2 p, in float r, in float time) {
    time *= -1.0 / 12.0;
    float s = sin(6.28 * time), c = cos(6.28 * time);
    vec2 p1 = p * mat2(c, s, -s, c);
    float d = udRoundBox(p1 - vec2(r * 0.35, 0), vec2(r * 0.35, 0), 0.8);
    s = sin(12.0 * 6.28 * time); c = cos(12.0 * 6.28 * time);
    p1 = p * mat2(c, s, -s, c);
    d = min(d, udRoundBox(p1 - vec2(r * 0.5, 0), vec2(r * 0.5, 0), 0.8));
    return d;
}

vec3 draw2D(vec2 uv, vec3 cScreen, float gamma, float xstart, float xend, float sx) {
    if (!LAYER_2D_ON || gamma > 100.0) { 
        return cScreen;
    }
    
    float xdist = 9.5 * abs(xend - xstart) / gamma;
    xstart = 9.5 * abs(xstart / gamma);
    
    vec2 p = uv * 150.0;
    float s = 300.0;
    vec3 cFill, cBack = cScreen; 
    float d, d2, a0, a1;
    
    d = sdCircle(p - vec2(-70.0, -65.0), 6.0);
    cFill = 0.1 + cScreen * 0.5;
    d = min(d, sdCircle(p - vec2(-45.0, -65.0), 6.0));
    a1 = clamp(max(d - 0.35, 0.0) * u_resolution.x / s, 0.0, 1.0);
    a0 = clamp(max(abs(d - 0.35) - 0.25, 0.0) * u_resolution.x / s, 0.0, 1.0);
    cBack = clamp(mix(cBack, a0 * cFill, (1.0 - a1)), 0.0, 1.0);
    
    d = clock(p - vec2(-70, -65), 6.0, globalTime);
    d2 = clock(p - vec2(-45, -65), 6.0, globalTime * gamma);
    
    p += vec2(-50, 70);
    d = min(d, udRoundBox(p + vec2(xstart - xdist * 0.5, -11.5), vec2(xdist * 0.5, 0.0), 0.2));
    d = min(d, spaceshipIcon(p + vec2(mix(xstart, xstart + xdist, sx), -14.5)));   
    d2 = min(d2, sunIcon(p, 9.5, 1.0 / gamma));
    cFill = (d2 < d ? vec3(1.0, 0.8, 0.1) : vec3(0, 1.0, 0));
    d = min(d, d2);
    a1 = clamp(max(d - 0.35, 0.0) * u_resolution.x / s, 0.0, 1.0);
    a0 = clamp(max(abs(d - 0.35) - 0.25, 0.0) * u_resolution.x / s, 0.0, 1.0); 
    return mix(cBack, a0 * cFill, (1.0 - a1));
}

void main() {
    // Use mouse for speed control if clicked, otherwise use default BETA
    bool isMouseCtrl = (u_mouse_pos.y > 0.0);
    float beta = clamp(isMouseCtrl ? u_mouse_pos.y : BETA, 0.0, 1.0);
    float gamma = 1.0 / sqrt(1.0 - beta * beta);
    float v = beta * LightSpeed * AnimationMoveRatio;  // Velocity
    
    vec3 color;
    
    // Speed indicator on right edge
    if (v_tex_coord.x > 0.97) {
        color = (v_tex_coord.y < beta) ? mix(vec3(0.3, 1.0, 0.3), vec3(1.0, 0.0, 0.0), beta) : vec3(0.3); 
    } else {
        float relativeTime = gamma * globalTime; // Relative time for the planet
        SunTwinkleFac = (1.0 + 0.03 * cos(5.0 * relativeTime + 2.0 * hash(relativeTime)));

        vec2 q = v_tex_coord - 0.5;
        q.x *= u_aspect;
        
        float height = 1.001 * (1.0 + VOLUMIC_SURFACE_TICKNESS);
        float shipX, xstart, xend;
        
        // Mouse control for ship position
        if (u_mouse_pos.x > 0.0) {
            shipX = 7.0 - 8.0 * u_mouse_pos.x;
            xstart = 7.0; 
            xend = -1.0;
        } else {
            if (!UY_Scuti) {
                shipX = mod(6.0 - gamma * v * globalTime, 6.0) - 1.0;  // gamma*v because of length contraction
                xstart = 5.0;
                xend = -1.0;
            } else {
                shipX = mod(1.5 - gamma * v * globalTime, 1.5) - 0.5; // gamma*v because of length contraction
                xstart = 1.0;
                xend = -0.5;
            }
        }
        
        vec3 ro = vec3(shipX, height, 0);
        float a = -0.5, ca = cos(a), sa = sin(a); // Small rotation to watch the planet
        ro.yz *= mat2(ca, sa, -sa, ca);
        
        vec3 ww = normalize(vec3(-1.0, 0.0, 0.0));
        a = 0.15; 
        ca = cos(a); 
        sa = sin(a); // Small rotation to watch the planet
        ww.zx *= mat2(ca, sa, -sa, ca);
        vec3 uu = normalize(cross(ww, vec3(0.0, 1.0, 0.0)));
        vec3 vv = normalize(cross(uu, ww));
        
        // Render scene
        vec3 rd = normalize(q.x * uu + q.y * vv + 1.5 * ww);
        
        color = relativisticRayTracing(ro, rd, vec3(-1.0, 0.0, 0.0) * beta);
        
        // 2D UI layer
        if (LAYER_2D_ON && v_tex_coord.y < 0.15) {
            color = draw2D(q, color.rgb, gamma, xstart, xend, (xstart - shipX) / (xend - xstart));
        }
    }
    
    frag_color = vec4(clamp(color, 0.0, 1.0), 1.0);
}