shader_type spatial;
varying vec3 wp;
varying vec3 wn;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
void vertex(){wp=(MODEL_MATRIX*vec4(VERTEX,1)).xyz;wn=normalize(MODEL_NORMAL_MATRIX*NORMAL);}
void fragment(){
	vec2 uv=vec2(abs(wn.x)>.5?wp.z:wp.x,wp.y);
	float row=floor(uv.y*3.0);
	vec2 brick=vec2(uv.x*1.65+mod(row,2.0)*.5,uv.y*3.0);
	vec2 edge=abs(fract(brick)-.5);
	float mortar=smoothstep(.45,.49,max(edge.x,edge.y));
	float rough=hash(floor(wp.xz*24.0)+floor(wp.y*20.0));
	float surface=abs(wn.y)<.2?(.91+.07*hash(floor(brick))-.035*mortar):(.90+.08*rough);
	ALBEDO=pow(COLOR.rgb,vec3(1.5))*surface;
	ROUGHNESS=.95;
}
