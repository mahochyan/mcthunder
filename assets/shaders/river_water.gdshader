shader_type spatial;
render_mode diffuse_burley;
varying vec3 wp;
void vertex(){wp=(MODEL_MATRIX*vec4(VERTEX,1)).xyz;}
void fragment(){
	float ripple=sin(wp.x*.9+wp.z*1.7+TIME*.8)*sin(wp.z*2.1-wp.x*.7+TIME*.6);
	ALBEDO=mix(vec3(.025,.062,.055),vec3(.045,.089,.078),ripple*.5+.5);
	ROUGHNESS=.38; METALLIC=.15;
}
