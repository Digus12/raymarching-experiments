// #define RGBCMY 1
// #define HUE 1
// #pragma glslify: hsv = require(glsl-hsv2rgb)

// #pragma glslify: hue2IOR = require(./dispersion-ray-direction)
#pragma glslify: hue2IOR = require(./dispersion/hue-to-ior-exponential)
// #pragma glslify: hue2IOR = require(./dispersion/hue-to-ior-polynomial)


vec3 refractColors (in vec3 nor, in vec3 eye, in float n2, in float n1, in vec3 lightColor) {
  const float between = amount;
  float greenIOR = n2;

  #ifdef RGBCMY
  float redIORRatio = hue2IOR(0.0, greenIOR, n1, between);
  float yellowIORRatio = hue2IOR(60.0, greenIOR, n1, between);
  float greenIORRatio = hue2IOR(120.0, greenIOR, n1, between);
  float cyanIORRatio = hue2IOR(180.0, greenIOR, n1, between);
  float blueIORRatio = hue2IOR(240.0, greenIOR, n1, between);
  float purpleIORRatio = hue2IOR(270.0, greenIOR, n1, between);

  vec3 redRefract = refract(eye, nor, redIORRatio);
  vec3 yellowRefract = refract(eye, nor, yellowIORRatio);
  vec3 greenRefract = refract(eye, nor, greenIORRatio);
  vec3 cyanRefract = refract(eye, nor, cyanIORRatio);
  vec3 blueRefract = refract(eye, nor, blueIORRatio);
  vec3 purpleRefract = refract(eye, nor, purpleIORRatio);

  float r = scene(redRefract).r * 0.5;
  float y = dot(scene(yellowRefract), vec3(2.0, 2.0, -1.0)) / 6.0;
  float g = scene(greenRefract).g * 0.5;
  float c = dot(scene(cyanRefract), vec3(-1.0, 2.0, 2.0)) / 6.0;
  float b = scene(blueRefract).b * 0.5;
  float p = dot(scene(purpleRefract), vec3(2.0, -1.0, 2.0)) / 6.0;

  float R = r + (2.0*p + 2.0*y - c)/3.0;
  float G = g + (2.0*y + 2.0*c - p)/3.0;
  float B = b + (2.0*c + 2.0*p - y)/3.0;

  #else

  #ifdef HUE
  float ior1 = hue2IOR(0.0, greenIOR, n1, between);
  float ior2 = hue2IOR(90.0, greenIOR, n1, between);
  float ior3 = hue2IOR(180.0, greenIOR, n1, between);
  float ior4 = hue2IOR(240.0, greenIOR, n1, between);

  vec3 ior1Refract = refract(eye, nor, ior1);
  vec3 ior2Refract = refract(eye, nor, ior2);
  vec3 ior3Refract = refract(eye, nor, ior3);
  vec3 ior4Refract = refract(eye, nor, ior4);

  vec3 color = vec3(0.);
  color += hsv(vec3(0.0, 1.0, 1.0)) * scene(ior1Refract);
  color += hsv(vec3(90.0, 1.0, 1.0)) * scene(ior2Refract);
  color += hsv(vec3(180.0, 1.0, 1.0)) * scene(ior3Refract);
  color += hsv(vec3(240.0, 1.0, 1.0)) * scene(ior4Refract);

  color *= 0.25;

  float R = color.r;
  float G = color.g;
  float B = color.b;

  #else

  float redIORRatio = hue2IOR(0.0, greenIOR, n1, between);
  float greenIORRatio = hue2IOR(120.0, greenIOR, n1, between);
  float blueIORRatio = hue2IOR(240.0, greenIOR, n1, between);

  vec3 redRefract = refract(eye, nor, redIORRatio);
  vec3 greenRefract = refract(eye, nor, greenIORRatio);
  vec3 blueRefract = refract(eye, nor, blueIORRatio);

  float r = scene(redRefract).r;
  float g = scene(greenRefract).g;
  float b = scene(blueRefract).b;

  float R = r;
  float G = g;
  float B = b;
  #endif
  #endif

  return vec3(R, G, B) * lightColor;
}
vec3 refractColors (in vec3 nor, in vec3 eye, in float n2) {
  return refractColors(nor, eye, n2, 1., vec3(1.0));
}
vec3 refractColors (in vec3 nor, in vec3 eye, in float n2, in float n1) {
  return refractColors(nor, eye, n2, n1, vec3(1.0));
}
vec3 refractColors (in vec3 nor, in vec3 eye, in float n2, in vec3 lightColor) {
  return refractColors(nor, eye, n2, 1., lightColor);
}

#pragma glslify: export(refractColors)
