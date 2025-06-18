#version 330

// Input vertex attributes (from vertex shader)
in vec2 fragTexCoord;
in vec4 fragColor;
in vec3 fragPosition;
in vec3 fragNormal;

// Input uniform values
uniform sampler2D texture0;
uniform vec4 colDiffuse;

// Output fragment color
out vec4 finalColor;

// NOTE: Add here your custom variables

#define     MAX_LIGHTS              4
#define     LIGHT_DIRECTIONAL       0
#define     LIGHT_POINT             1

struct MaterialProperty {
    vec3 color;
    int useSampler;
    sampler2D sampler;
};

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

    // NOTE: Implement here your fragment shader code
    float NdotL;
    for (int i = 0; i < MAX_LIGHTS; i++)
    {
        if (lights[i].enabled == 1)
        {
            vec3 light = vec3(0.0);
            if (lights[i].type == LIGHT_DIRECTIONAL) {
                light = -normalize(lights[i].target - lights[i].position);
            }
            if (lights[i].type == LIGHT_POINT) {
                light = normalize(lights[i].position - fragPosition);
            }
            NdotL = max(dot(normal, light), 0.0);
            lightDot += lights[i].color.rgb * NdotL;

        }
    }
    
    // create a banding effect
    if (NdotL > 0.95)
		NdotL = 1;
	else if (NdotL > 0.6)
		NdotL = .9;
	else if (NdotL > 0.4)
		NdotL = .8;
	else
		NdotL = .7;
    
    finalColor = texelColor * colDiffuse * NdotL;
    finalColor.a = 1.0;

}
