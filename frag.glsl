#define PI 3.1415926536
#define TWO_PI 6.2831853072
#define PHI (1.618033988749895)

// #define debugMapCalls
// #define debugMapMaxed
#define SS 2

precision highp float;

varying vec2 fragCoord;
uniform vec2 resolution;
uniform float time;
uniform bool BLOOM;
uniform vec3 cOffset;
uniform vec3 cameraRo;
uniform mat4 cameraMatrix;
uniform mat4 orientation;
uniform mat4 projectionMatrix;

// KIFS
uniform mat4 kifsM;
uniform float scale;
uniform vec3 offset;

// Greatest precision = 0.000001;
uniform float epsilon;
#define maxSteps 256
#define maxDistance 50.0
#pragma glslify: import(./background)

#define slowTime time * .01
#define Iterations 8

vec3 lightPos = normalize(vec3(1., .75, 0.));

const vec3 un = vec3(1., -1., 0.);

// Utils
#pragma glslify: getRayDirection = require(./ray-apply-proj-matrix)
#pragma glslify: snoise2 = require(glsl-noise/simplex/2d)
#pragma glslify: snoise3 = require(glsl-noise/simplex/3d)
#pragma glslify: cnoise3 = require(glsl-noise/classic/3d)
#pragma glslify: cnoise2 = require(glsl-noise/classic/2d)
#pragma glslify: voronoi = require(./voronoi)

// 3D noise function (IQ)
float noise(vec3 p) {
  vec3 ip=floor(p);
    p-=ip;
    vec3 s=vec3(7,157,113);
    vec4 h=vec4(0.,s.yz,s.y+s.z)+dot(ip,s);
    p=p*p*(3.-2.*p);
    h=mix(fract(sin(h)*43758.5),fract(sin(h+s.x)*43758.5),p.x);
    h.xy=mix(h.xz,h.yw,p.y);
    return mix(h.x,h.y,p.z);
}

float iqFBM (vec3 p) {
  float f = 0.0;

  f += 0.5000*noise( p ); p = p*2.02;
  f += 0.2500*noise( p ); p = p*2.03;
  f += 0.1250*noise( p ); p = p*2.01;
  f += 0.0625*noise( p );

  return f * 1.066667;
}

// Orbit Trap
float trapCalc (in vec3 p, in float k) {
  return dot(p, p) / (k * k);
}

// The "Round" variant uses a quarter-circle to join the two objects smoothly:
float fOpUnionRound(float a, float b, float r) {
  vec2 u = max(vec2(r - a,r - b), vec2(0));
  return max(r, min (a, b)) - length(u);
}

// IQ's capsule
float sdCapsule( vec3 p, vec3 a, vec3 b, float r )
{
    vec3 pa = p - a, ba = b - a;
    float h = clamp( dot(pa,ba)/dot(ba,ba), 0.0, 1.0 );
    return length( pa - ba*h ) - r;
}
float sdBox( vec3 p, vec3 b )
{
  vec3 d = abs(p) - b;
  return min(max(d.x,max(d.y,d.z)),0.0) + length(max(d,0.0));
}
float sdHexPrism( vec3 p, vec2 h )
{
    vec3 q = abs(p);
    return max(q.z-h.y,max((q.x*0.866025+q.y*0.5),q.y)-h.x);
}

#pragma glslify: mandelbox = require(./mandelbox, trap=Iterations, maxDistance=maxDistance, foldLimit=1., s=scale, minRadius=0.5, rotM=kifsM)
// #pragma glslify: octahedron = require(./octahedron, scale=scale, kifsM=kifsM)

#pragma glslify: dodecahedron = require(./dodecahedron, Iterations=Iterations, scale=scale, kifsM=kifsM)
#pragma glslify: mengersphere = require(./menger-sphere, intrad=1., scale=scale, kifsM=kifsM)

#define octaPreFold 6
mat4 octaM = mat4(
scale, 0., 0., 0.,
0., scale, 0., 0.,
0., 0., scale, 0.,
1., 1., 1., 1.) * mat4(
1., 0., 0.1, .0,
0., 1., 0., 0.,
0., 0.2, 1., 0.,
0., 0., 0., 1.);
#pragma glslify: octahedronFold = require(./folds/octahedron-fold, Iterations=octaPreFold, kifsM=octaM, trapCalc=trapCalc)

#pragma glslify: fold = require(./folds)
#pragma glslify: foldNd = require(./foldNd)
#pragma glslify: twist = require(./twist)

vec2 dMin (vec2 d1, vec2 d2) {
  return (d1.x < d2.x) ? d1 : d2;
}
vec3 dMin (vec3 d1, vec3 d2) {
  return (d1.x < d2.x) ? d1 : d2;
}
vec3 dMax (vec3 d1, vec3 d2) {
  return (d1.x > d2.x) ? d1 : d2;
}

float gRAngle = TWO_PI * 0.05 * time;
float gRc = cos(gRAngle);
float gRs = sin(gRAngle);
mat3 globalRot = mat3(
  gRc, 0.0, -gRs,
  0.0, 1.0,  0.0,
  gRs, 0.0,  gRc);

#pragma glslify: rotationMatrix = require(./rotation-matrix3)

const float transitionLength = 9.0;
float animationTime = time;

vec3 transform ( in vec3 p, in float time ) {
  float up = (p.y - time) / transitionLength;
  p.y = time + 1. / (1. - up) - 1.;

  return p;
}
vec3 reverseTransform ( in vec3 p, in float time ) {
  p.y = 0.1 * transitionLength / (p.y - time + 1.);

  return p;
}

float noiseGrid (in vec3 p, in vec3 transformedP, in float time) {
  float morphK = 1.6 - 1.6 * time;

  float cellSize = 0.2;
  float bubbleRadius = cellSize * 0.3;
  vec3 cellPosCenter = floor(p / cellSize);

  float totalDistance = 1000.0;
  for (int x = -1; x <= 1; x++) for (int y = -1; y <= 1; y++) for (int z = -1; z <= 1; z++) {
    vec3 cellPos = cellPosCenter + vec3(x, y, z);
    vec3 cellNoise = vec3(
      noise(cellPos),
      noise(cellPos + 1230.23),
      noise(cellPos + 8456.34));
    vec3 pos = (cellPos + cellNoise) * cellSize;
    float radius = clamp(bubbleRadius * cellNoise.x, 0., 1.);

    // No point drawing a sphere w/ a negative radius
    if (radius < 0.0) continue;

    // float d = length(transformedP - transform(pos, animationTime)) - radius;
    float d = length(transformedP - pos) - radius;

    // Merge op
    float k = mix(cellSize*1.5, cellSize*0.5, morphK);
    float h = clamp(0.5 + 0.5*(totalDistance - d)/k, 0.0, 1.0);
    totalDistance = mix(totalDistance, d, h) - k*h*(1.0-h);

    // Union
    // totalDistance = min(d, totalDistance);
  }

  return totalDistance;
}

// IQ
float sdCylinder( vec3 p, vec3 c )
{
  return length(p.xz-c.xy)-c.z;
}

vec3 n4 = vec3(0.577,0.577,0.577);
vec3 n5 = vec3(-0.577,0.577,0.577);
vec3 n6 = vec3(0.577,-0.577,0.577);
vec3 n7 = vec3(0.577,0.577,-0.577);
vec3 n8 = vec3(0.000,0.357,0.934);
vec3 n9 = vec3(0.000,-0.357,0.934);
vec3 n10 = vec3(0.934,0.000,0.357);
vec3 n11 = vec3(-0.934,0.000,0.357);
vec3 n12 = vec3(0.357,0.934,0.000);
vec3 n13 = vec3(-0.357,0.934,0.000);
vec3 n14 = vec3(0.000,0.851,0.526);
vec3 n15 = vec3(0.000,-0.851,0.526);
vec3 n16 = vec3(0.526,0.000,0.851);
vec3 n17 = vec3(-0.526,0.000,0.851);
vec3 n18 = vec3(0.851,0.526,0.000);
vec3 n19 = vec3(-0.851,0.526,0.000);

// p as usual, e exponent (p in the paper), r radius or something like that
float octahedral(vec3 p, float e, float r) {
  float s = pow(abs(dot(p,n4)),e);
  s += pow(abs(dot(p,n5)),e);
  s += pow(abs(dot(p,n6)),e);
  s += pow(abs(dot(p,n7)),e);
  s = pow(s, 1./e);
  return s-r;
}

bool insideSphere = false;

// Return value is (distance, material, orbit trap)
vec3 map (in vec3 p) {
  vec3 outD = vec3(10000., 0., 0.);

  p *= globalRot;

  // Timing
  animationTime = mod(time, transitionLength) / transitionLength;
  float toOct = 0.5 + 0.5 * sin(TWO_PI * 0.1 * time);

  vec3 q = p; // Unwarped coordinate

  q *= mix(1.0, 1.33, toOct);

  vec3 s = vec3(sdBox(q, vec3(mix(0.5, 1.5, toOct))), 1.0, 0.0);
  outD = dMin(outD, s);

  float o = octahedral(q, 70.0, 0.875);
  outD.x = max(outD.x, o);

  q *= 10.0;

  outD.x += 0.004 * iqFBM(q + iqFBM(q + iqFBM(q)));

  outD.x *= mix(1.0, 0.75188, toOct);

  return outD;
}

vec4 march (in vec3 rayOrigin, in vec3 rayDirection) {
  float t = 0.00001;
  float maxI = 0.;

  float trap = maxDistance;

  for (int i = 0; i < maxSteps; i++) {
    vec3 d = map(rayOrigin + rayDirection * t);
    if (d.x < epsilon) return vec4(t + d.x, d.y, float(i), d.z);
    t += d.x;
    maxI = float(i);
    trap = d.z;
    if (t > maxDistance) break;
  }
  return vec4(-1., 0., maxI, trap);
}

#pragma glslify: getNormal = require(./get-normal, map=map)
vec3 getNormal2 (in vec3 p, in float eps) {
  vec2 e = vec2(1.,0.) * .015 * eps;
  return normalize(vec3(
    map(p + e.xyy).x - map(p - e.xyy).x,
    map(p + e.yxy).x - map(p - e.yxy).x,
    map(p + e.yyx).x - map(p - e.yyx).x));
}

// Material Functions
float diffuse (in vec3 nor, in vec3 lightPos) {
  return dot(lightPos, nor);
}

#pragma glslify: softshadow = require(./soft-shadows, map=map)
#pragma glslify: calcAO = require(./ao, map=map)

void colorMap (inout vec3 color) {
  float l = length(vec4(color, 1.));
  // Light
  color = mix(#ef78FF, color, 1. - l * .0625);
  // Dark
  color = mix(#043210, color, clamp(exp(l) * .325, 0., 1.));
}

#pragma glslify: hsv = require(glsl-hsv2rgb)
#pragma glslify: checker = require(glsl-checker)
#pragma glslify: debugColor = require(./debug-color-clip)

const float n1 = 1.0;
const float n2 = 1.50;

vec3 textures (in vec3 rd) {
  vec3 color = vec3(0.);

  // float v = 2.1 * noise(rd);
  float v = noise(2. * rd);
  // v = smoothstep(-1.0, 1.0, v);

  // vec3 maxRd = abs(rd);
  // float v = max(maxRd.x, maxRd.y);

  // color = vec3(v);
  // color = mix(#FF1F99, #FF7114, v);
  color = .5 + vec3(.5, .3, .6) * cos(TWO_PI * (v + vec3(0.0, 0.33, 0.67)));
  // color += #61FF77 * (0.5 * abs(rd.y));

  // color *= 1.1 * cos(rd);

  return clamp(color, 0., 1.);
}

vec3 scene (in vec3 rd) {
  vec3 color = vec3(0.);

  rd = normalize(rd);
  color = textures(rd);

  return color;
}

#pragma glslify: dispersion = require(./glsl-dispersion, scene=scene, amount=0.5)
bool isMaterial( float m, float goal ) {
  return m < goal + 1. && m > goal - .1;
}
float isMaterialSmooth( float m, float goal ) {
  const float eps = .1;
  return 1. - smoothstep(0., eps, abs(m - goal));
}

vec3 baseColor(in vec3 pos, in vec3 nor, in vec3 rd, in float m, in float trap) {
  return #020202;
}

vec4 marchRef (in vec3 rayOrigin, in vec3 rayDirection) {
  float t = 0.;
  float maxI = 0.;

  float trap = maxDistance;

  for (int i = 0; i < maxSteps / 3; i++) {
    vec3 d = map(rayOrigin + rayDirection * t);
    if (d.x < epsilon) return vec4(t + d.x, d.y, float(i), d.z);
    t += d.x;
    maxI = float(i);
    trap = d.z;
    if (t > maxDistance) break;
  }
  return vec4(-1., 0., maxI, trap);
}
vec3 reflection (in vec3 ro, in vec3 rd) {
  rd = normalize(rd);
  vec4 t = marchRef(ro + rd * .09, rd);
  vec3 pos = ro + rd * t.x;
  vec3 color = vec3(0.);
  if (t.x > 0.) {
    vec3 nor = getNormal(pos, .0001);
    color = baseColor(pos, nor, rd, t.y, t.w);
  }

  return color;
}

const vec3 glowColor = #39CCA1;

#pragma glslify: innerGlow = require(./inner-glow, glowColor=glowColor)

vec4 shade( in vec3 rayOrigin, in vec3 rayDirection, in vec4 t, in vec2 uv ) {
    vec3 pos = rayOrigin + rayDirection * t.x;
    if (t.x>0.) {
      vec3 color = background;

      vec3 nor = getNormal2(pos, 0.001 * t.x);
      vec3 ref = reflect(rayDirection, nor);
      ref = normalize(ref);

      // Basic Diffusion
      vec3 diffusColor = baseColor(pos, nor, rayDirection, t.y, t.w);

      // Declare lights
      struct light {
        vec3 position;
      };
      const int NUM_OF_LIGHTS = 2;
      light lights[NUM_OF_LIGHTS];
      lights[0] = light(normalize(vec3(1., .75, 0.)));
      lights[1] = light(normalize(vec3(-1., -.5, -.5)));

      float occ = calcAO(pos, nor);
      float amb = clamp( 0.5+0.5*nor.y, 0.0, 1.0  );
      for (int i = 0; i < NUM_OF_LIGHTS; i++ ) {
        vec3 lightPos = lights[i].position;
        float dif = diffuse(nor, lightPos);
        float spec = pow(clamp( dot(ref, (lightPos)), 0., 1. ), 16.);
        const float ReflectionFresnel = pow((n1 - n2) / (n1 + n2), 2.);
        float fre = ReflectionFresnel + pow(clamp( 1. + dot(nor, rayDirection), 0., 1. ), 5.) * (1. - ReflectionFresnel);

        // dif *= min(0.1 + softshadow(pos, lightPos, 0.02, 1.5), 1.);
        vec3 lin = vec3(0.);

        // Specular Lighting
        lin += spec * (1. - fre);
        lin += 0.01 * fre * occ;

        // Ambient
        lin += 0.001 * amb * occ * #ffcccc;

        float conserve = max(0., 1. - length(lin));
        color += (conserve * dif) * diffusColor + clamp(lin, 0., 1.);
      }

      // color += .09 * reflection(pos, ref) * isMaterialSmooth(t.y, 1.);
      color += 0.003 * dispersion(nor, rayDirection, n2) * isMaterialSmooth(t.y, 1.);

      // Fog
      // color = mix(background, color, clamp(1.1 * ((maxDistance-t.x) / maxDistance), 0., 1.));
      // color *= exp(-t.x * .1);

      // Inner Glow
      // color += innerGlow(t.w);

      // Post process
      // colorMap(color);

      // Debugging
      #ifdef debugMapMaxed
      if (t.z / float(maxSteps) > 0.9) {
        color = vec3(1., 0., 1.);
      }
      #endif

      #ifdef debugMapCalls
      color = vec3(t.z / float(maxSteps));
      #endif

      return vec4(color, 1.);
    } else {
      vec4 color = vec4(background, 0.);
      if (!BLOOM) {
        color.a = 1.0;
      }

      // Radial Gradient
      // color.xyz *= mix(vec3(1.), background, length(uv) / 2.);

      // Glow
      color = mix(vec4(#FFC594, 1.0), color, 1. - .99 * clamp(t.z / (7.0 * float(maxSteps)), 0., 1.));

      return color;
    }
}

vec4 sample (in vec3 ro, in vec3 rd, in vec2 uv) {
  vec4 t = march(ro, rd);
  return shade(ro, rd, t, uv);
}

void main() {
    vec3 ro = cameraRo + cOffset;

    vec2 uv = fragCoord.xy;
    background = getBackground(uv);

    #ifdef SS
    // Antialias by averaging all adjacent values
    vec4 color = vec4(0.);
    vec2 R = resolution * 2.;

    for (int x = - SS / 2; x < SS / 2; x++) {
        for (int y = - SS / 2; y < SS / 2; y++) {
            vec3 rd = getRayDirection(vec2(
                  float(x) / R.y + uv.x,
                  float(y) / R.y + uv.y),
                  projectionMatrix);
            rd = (vec4(rd, 1.) * cameraMatrix).xyz;
            rd = normalize(rd);
            color += sample(ro, rd, uv);
        }
    }
    gl_FragColor = color / float(SS * SS);

    #else
    vec3 rd = getRayDirection(uv, projectionMatrix);
    rd = (vec4(rd, 1.) * cameraMatrix).xyz;
    rd = normalize(rd);
    gl_FragColor = sample(ro, rd, uv);
    #endif

    // gamma
    gl_FragColor.rgb = pow(gl_FragColor.rgb, vec3(0.454545));

    // 'Film' Noise
    // gl_FragColor.rgb += .03 * (cnoise2((500. + 1.1 * time) * uv + sin(uv + time)) + cnoise2((500. + time) * uv + 253.5));
}
