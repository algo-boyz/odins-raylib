#version 330

in vec3 vertexPosition;
in vec4 vertexBoneIds;
in vec4 vertexBoneWeights;

#define MAX_BONE_NUM 128
uniform mat4 boneMatrices[MAX_BONE_NUM];

uniform mat4 mvp;

void main()
{
    int boneIndex0 = int(vertexBoneIds.x);
    int boneIndex1 = int(vertexBoneIds.y);
    int boneIndex2 = int(vertexBoneIds.z);
    int boneIndex3 = int(vertexBoneIds.w);
    
    vec4 skinnedPosition =
        vertexBoneWeights.x * (boneMatrices[boneIndex0] * vec4(vertexPosition, 1.0)) +
        vertexBoneWeights.y * (boneMatrices[boneIndex1] * vec4(vertexPosition, 1.0)) + 
        vertexBoneWeights.z * (boneMatrices[boneIndex2] * vec4(vertexPosition, 1.0)) + 
        vertexBoneWeights.w * (boneMatrices[boneIndex3] * vec4(vertexPosition, 1.0));
    
    gl_Position = mvp * vec4(skinnedPosition.xyz / skinnedPosition.w, 1.0);
}