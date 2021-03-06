// Source: https://www.shadertoy.com/view/Xds3zN
float softshadow( in vec3 ro, in vec3 rd, in float mint, in float tmax ) {
  float res = 1.0;
    float t = mint;
    for( int i=0; i<16; i++ ) {
      vec3 h = map(ro + rd*t);
      res = min( res, 4.0*h.x/t );
      t += clamp( h.x, 0.02, 0.10 );
      if( h.x<0.001 || t>tmax ) break;
    }
    return clamp( res, 0.0, 1.0 );
}

#pragma glslify: export(softshadow)
