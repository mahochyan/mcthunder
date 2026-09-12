shader_type spatial;
render_mode diffuse_burley;
varying vec3 world_point;
varying vec3 world_normal;
float hash(vec2 p) {return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p) {
	vec2 i=floor(p); vec2 f=fract(p); f=f*f*(3.0-2.0*f);
	return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
void vertex(){world_point=(MODEL_MATRIX*vec4(VERTEX,1)).xyz;world_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);}
void fragment(){
	float broad=noise(world_point.xz*.014);
	float patches=noise(world_point.xz*.17);
	float grains=noise(world_point.xz*3.0);
	vec3 grass=mix(vec3(.20,.25,.105),vec3(.39,.41,.22),broad);
	vec3 soil=mix(vec3(.29,.26,.20),vec3(.43,.40,.32),patches);
	float bank=1.0-smoothstep(0.0,6.5,world_point.y);
	float slope=1.0-smoothstep(.65,.96,world_normal.y);
	ALBEDO=pow(mix(grass,soil,max(bank,slope)),vec3(1.45))*(.85+.18*patches+.10*grains);
	ROUGHNESS=.97;
}
