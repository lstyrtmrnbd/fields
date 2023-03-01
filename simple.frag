#version 330

// uniform int multiplicationFactor = 8;
// uniform float threshold = 0.133;

uniform sampler2D texs;

in vec4 colorsV;
in vec2 texCoords;
// flat in int instanceId;
// flat in int atlasIdxV;

out vec4 fragColor;

void main() {

  // // multiplicationFactor scales the number of stripes
  // vec2 t = texCoordV * multiplicationFactor;

  // // // the threshold constant defines the width of the lines
  // if (fract(t.s) < threshold  || fract(t.t) < threshold )
  //   fragColor = vec4(0.0, 0.0, 1.0, 1.0);	
  // else
  //   discard;

  vec4 texColor = texture(texs, texCoords);
  vec4 comboColor = mix(texColor, colorsV, vec4(vec3(0.5), 0.0));
  fragColor = comboColor;
}
