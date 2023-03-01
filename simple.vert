#version 330

uniform mat4 viewProjection;

uniform sampler1D atlasCoords;

in vec3 position;
in ivec2 texIdx; // location of subtex in texture
in int atlasIdx; // location of texcoords in atlas
in vec4 colors;

in mat4 model;

out vec2 texCoords;
out vec4 colorsV;
// flat out int atlasIdxV;
// flat out int instanceId;

void main() {

  // not extremely necessary
  // instanceId = gl_InstanceID;

  // derive texcoords from atlas info
  vec4 texCs = texelFetch(atlasCoords, atlasIdx);
  texCoords = vec2(texCs[texIdx.x], texCs[texIdx.y]);

  colorsV = colors;
  
  vec4 worldPos = model * vec4(position, 1.0);

  gl_Position = viewProjection * worldPos;
}
