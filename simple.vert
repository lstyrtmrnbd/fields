#version 330

uniform mat4 viewProjection;

in vec3 position;
in vec2 texCoord;
in int texIndex;
in vec4 colors;

in mat4 model;

out vec2 texCoordV;
out vec4 colorsV;
flat out int texIndexV;
flat out int instanceId;

void main() {
  
  texCoordV = texCoord;
  texIndexV = texIndex;
  colorsV = colors;
  instanceId = gl_InstanceID;

  vec4 worldPos = model * vec4(position, 1.0);

  gl_Position = viewProjection * worldPos;
}
