shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// Holographic Shader - Tech/holographic effect for Fast Reload upgrade
// Creates scanning lines, transparency, and tech aesthetic

group_uniforms hologram;
uniform vec3 primary_color : source_color = vec3(0.0, 1.0, 0.5);
uniform vec3 secondary_color : source_color = vec3(0.0, 0.5, 1.0);
uniform float transparency : hint_range(0.0, 1.0) = 0.4;
uniform float edge_glow : hint_range(0.0, 5.0) = 2.0;

group_uniforms scanlines;
uniform float scanline_density : hint_range(10.0, 200.0) = 60.0;
uniform float scanline_speed : hint_range(0.0, 10.0) = 2.0;
uniform float scanline_intensity : hint_range(0.0, 1.0) = 0.3;
uniform bool horizontal_lines = true;

group_uniforms glitch;
uniform float glitch_intensity : hint_range(0.0, 1.0) = 0.1;
uniform float glitch_speed : hint_range(0.0, 10.0) = 5.0;
uniform bool enable_glitch = true;

group_uniforms led_dots;
uniform float led_scale : hint_range(10.0, 100.0) = 40.0;
uniform float led_intensity : hint_range(0.0, 2.0) = 0.5;
uniform bool show_leds = true;

// Pseudo-random
float random(vec2 st) {
	return fract(sin(dot(st.xy, vec2(12.9898, 78.233))) * 43758.5453123);
}

void fragment() {
	vec2 uv = UV;

	// Glitch effect
	if (enable_glitch) {
		float glitch_time = floor(TIME * glitch_speed);
		float glitch_factor = step(0.95 - glitch_intensity * 0.1, random(vec2(glitch_time, 0.0)));
		if (glitch_factor > 0.0) {
			float offset = (random(vec2(glitch_time, UV.y)) - 0.5) * glitch_intensity * 0.1;
			uv.x += offset;
		}
	}

	// Scanlines
	float scanline = 1.0;
	if (horizontal_lines) {
		scanline = sin((uv.y + TIME * scanline_speed * 0.1) * scanline_density * PI) * 0.5 + 0.5;
	} else {
		scanline = sin((uv.x + TIME * scanline_speed * 0.1) * scanline_density * PI) * 0.5 + 0.5;
	}
	scanline = 1.0 - scanline * scanline_intensity;

	// LED dot pattern
	float led_pattern = 1.0;
	if (show_leds) {
		vec2 led_uv = fract(uv * led_scale);
		float led = smoothstep(0.4, 0.3, length(led_uv - 0.5));
		led_pattern = 1.0 + led * led_intensity;
	}

	// Fresnel edge glow
	float fresnel = pow(1.0 - dot(NORMAL, VIEW), 2.0);

	// Color mixing with time-based shift
	float color_shift = sin(TIME * 0.5) * 0.5 + 0.5;
	vec3 base_color = mix(primary_color, secondary_color, color_shift);

	// Final color
	ALBEDO = base_color * scanline * 0.3;
	METALLIC = 0.0;
	ROUGHNESS = 1.0;

	// Strong emission for holographic look
	float pulse = sin(TIME * 3.0) * 0.2 + 0.8;
	EMISSION = base_color * scanline * led_pattern * (1.0 + fresnel * edge_glow) * pulse;

	// Transparency
	ALPHA = (1.0 - transparency) + fresnel * 0.3;
	ALPHA *= scanline;
}
