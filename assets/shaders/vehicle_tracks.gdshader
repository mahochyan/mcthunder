shader_type spatial;
render_mode cull_disabled;
uniform sampler2D atlas : source_color, filter_linear_mipmap, repeat_disable;
uniform float travel = 0.0;
void fragment() {
	vec2 sample_uv = UV;
	// Atlas row 2, column 1 is the repeating tread strip. Other tiles stay fixed.
	if (UV.x < 0.25 && UV.y > 0.25 && UV.y < 0.5) {
		float local_y = (UV.y - 0.25) * 4.0;
		local_y = fract((local_y - 0.018) / 0.964 + travel);
		sample_uv.y = 0.25 + (0.018 + local_y * 0.964) * 0.25;
	}
	ALBEDO = texture(atlas, sample_uv).rgb;
	ROUGHNESS = 0.9;
}
