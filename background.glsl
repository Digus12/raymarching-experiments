// cnoise loaded in frag.glsl & final-pass.glsl respectively

vec3 getBackground (in vec2 uv) {
  float coord = 1.0 * uv.y;

  return mix(#888888, #FFFFFF, coord);
}
vec3 background = vec3(0.);
