#version 330

// Input vertex attributes (from vertex shader)
in vec3 fragPosition;
in vec2 fragTexCoord;
in vec3 fragNormal;

// Input uniform values
uniform sampler2D texture0;
uniform vec4 colDiffuse;

// Output fragment color
out vec4 finalColor;

#define MAX_LIGHTS 4
#define LIGHT_DIRECTIONAL 0
#define LIGHT_POINT 1

struct Light {
    int enabled;
    int type;
    vec3 position;
    vec3 target;
    vec4 color;
};

// Input lighting values
uniform Light lights[MAX_LIGHTS];
uniform vec4 ambient;
uniform vec3 viewPos;

void main()
{
    // Texel color fetching from texture sampler
    vec4 texelColor = texture(texture0, fragTexCoord);
    vec3 lightDot = vec3(0.0);
    vec3 normal = normalize(fragNormal);
    vec3 viewD = normalize(viewPos - fragPosition);
    vec3 specular = vec3(0.0);

    // Process all lights
    for(int i = 0; i < MAX_LIGHTS; i++) {
        if (lights[i].enabled == 1) {
            vec3 lightDir = vec3(0.0);
            
            if (lights[i].type == LIGHT_DIRECTIONAL) {
                lightDir = -normalize(lights[i].target - lights[i].position);
            }
            else if (lights[i].type == LIGHT_POINT) {
                lightDir = normalize(lights[i].position - fragPosition);
            }

            // Calculate diffuse lighting
            float NdotL = max(dot(normal, lightDir), 0.0);
            lightDot += lights[i].color.rgb * NdotL;

            // Calculate specular lighting
            float specCo = 0.0;
            if (NdotL > 0.0) {
                specCo = pow(max(0.0, dot(viewD, reflect(-lightDir, normal))), 32.0); // Increased shine
            }
            specular += lights[i].color.rgb * specCo;
        }
    }

    // Combine diffuse and specular
    finalColor = (texelColor * ((colDiffuse + vec4(specular, 1.0)) * vec4(lightDot, 1.0)));
    
    // Add ambient lighting
    finalColor += texelColor * (ambient * 2.0) * colDiffuse; // Slightly increased ambient
    
    // Ensure we don't exceed 1.0
    finalColor = clamp(finalColor, 0.0, 1.0);

    // Gamma correction
    finalColor = pow(finalColor, vec4(1.0/2.2));
}