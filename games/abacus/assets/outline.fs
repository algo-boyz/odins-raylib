#version 330

// modified sobel shader to create outlines from map of model/view rotated normals


// Input vertex attributes (from vertex shader)
in vec2 fragTexCoord;
in vec4 fragColor;

// Input uniform values
uniform sampler2D texture0;
uniform vec4 colDiffuse;

// Output fragment color
out vec4 finalColor;

// NOTE: Add here your custom variables
uniform vec2 resolution = vec2(1280, 720);

void main() 
{
	float x = 1.0/resolution.x;
	float y = 1.0/resolution.y;
  
	vec4 horizEdge = vec4(0.0);
	horizEdge -= texture2D(texture0, vec2(fragTexCoord.x - x, fragTexCoord.y - y))*0.5;
	//horizEdge -= texture2D(texture0, vec2(fragTexCoord.x - x, fragTexCoord.y    ))*2.0;
	horizEdge -= texture2D(texture0, vec2(fragTexCoord.x - x, fragTexCoord.y    ))*1.0;
	horizEdge -= texture2D(texture0, vec2(fragTexCoord.x - x, fragTexCoord.y + y))*0.5;
	horizEdge += texture2D(texture0, vec2(fragTexCoord.x + x, fragTexCoord.y - y))*0.5;
	//horizEdge += texture2D(texture0, vec2(fragTexCoord.x + x, fragTexCoord.y    ))*2.0;
	horizEdge += texture2D(texture0, vec2(fragTexCoord.x + x, fragTexCoord.y    ))*1.0;
	horizEdge += texture2D(texture0, vec2(fragTexCoord.x + x, fragTexCoord.y + y))*0.5;
    
	vec4 vertEdge = vec4(0.0);
	vertEdge -= texture2D(texture0, vec2(fragTexCoord.x - x, fragTexCoord.y - y))*0.5;
	//vertEdge -= texture2D(texture0, vec2(fragTexCoord.x    , fragTexCoord.y - y))*2.0;
	vertEdge -= texture2D(texture0, vec2(fragTexCoord.x    , fragTexCoord.y - y))*1.0;
	vertEdge -= texture2D(texture0, vec2(fragTexCoord.x + x, fragTexCoord.y - y))*0.5;
	vertEdge += texture2D(texture0, vec2(fragTexCoord.x - x, fragTexCoord.y + y))*0.5;
	//vertEdge += texture2D(texture0, vec2(fragTexCoord.x    , fragTexCoord.y + y))*2.0;
	vertEdge += texture2D(texture0, vec2(fragTexCoord.x    , fragTexCoord.y + y))*1.0;
	vertEdge += texture2D(texture0, vec2(fragTexCoord.x + x, fragTexCoord.y + y))*0.5;
    
	vec3 edge = sqrt((horizEdge.rgb*horizEdge.rgb) + (vertEdge.rgb*vertEdge.rgb));
    
    const float t = .6; // should be a uniform

    if (length(edge)>t) {
        finalColor = vec4(0,0,0,1);
    } else {
        finalColor = vec4(0,0,0,0);
    }

}
