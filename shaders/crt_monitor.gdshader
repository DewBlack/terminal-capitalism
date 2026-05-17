shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;

uniform float effect_intensity : hint_range(0.0, 1.0, 0.01) = 0.52;
uniform float scanline_strength : hint_range(0.0, 0.8, 0.01) = 0.22;
uniform float glow_strength : hint_range(0.0, 0.8, 0.01) = 0.18;
uniform float curvature : hint_range(0.0, 0.12, 0.001) = 0.026;
uniform float aberration_strength : hint_range(0.0, 0.01, 0.0001) = 0.0022;
uniform float vignette_strength : hint_range(0.0, 1.0, 0.01) = 0.24;
uniform float noise_strength : hint_range(0.0, 0.2, 0.001) = 0.010;
uniform vec3 tint : source_color = vec3(0.76, 0.93, 0.84);

float _hash(vec2 value) {
	return fract(sin(dot(value, vec2(127.1, 311.7))) * 43758.5453123);
}


void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 centered = uv * 2.0 - 1.0;
	float radius_sq = dot(centered, centered);
	vec2 curved_uv = uv + centered * radius_sq * curvature;
	vec3 color = vec3(0.0);
	bool outside_bounds = curved_uv.x < 0.0 || curved_uv.x > 1.0 || curved_uv.y < 0.0 || curved_uv.y > 1.0;
	if (!outside_bounds) {
		float chroma_offset = aberration_strength * effect_intensity;
		float red = texture(screen_texture, curved_uv + vec2(chroma_offset, 0.0)).r;
		float green = texture(screen_texture, curved_uv).g;
		float blue = texture(screen_texture, curved_uv - vec2(chroma_offset, 0.0)).b;
		color = vec3(red, green, blue);

		float scanline_wave = sin(curved_uv.y * 960.0) * 0.5 + 0.5;
		float scanline_mix = 1.0 - scanline_strength * effect_intensity * scanline_wave;
		color *= scanline_mix;

		float glow = smoothstep(0.22, 1.0, max(max(color.r, color.g), color.b));
		color += vec3(glow_strength * effect_intensity * glow);

		float vignette = 1.0 - smoothstep(0.36, 1.0, radius_sq);
		color *= mix(1.0, vignette, vignette_strength * effect_intensity);

		float grain = _hash(curved_uv * vec2(1453.0, 947.0) + vec2(TIME * 41.0, TIME * 13.0)) - 0.5;
		color += grain * noise_strength * effect_intensity;
		color *= mix(vec3(1.0), tint, effect_intensity * 0.30);
	}

	COLOR = vec4(clamp(color, vec3(0.0), vec3(1.0)), 1.0);
}
