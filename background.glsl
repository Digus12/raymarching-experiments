vec3 getBackground (in vec2 uv) {
  // Convert from [-1,1] -> [0, 1]
  vec2 coord = 0.5 * (uv.xy + vec2(1.0));

  vec3 color = mix(pow(#FFC4CB, vec3(2.2)), pow(#FFF0E5, vec3(2.2)), coord.y);
  color = vec3(0.8);
  return color;
}
vec3 background = vec3(0.);
