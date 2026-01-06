shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// Ice/Frost Shader - Frozen effect for Freeze Bullets upgrade
// Creates icy surface with frost patterns and subsurface scattering look

group_uniforms ice_properties;
uniform vec3 ice_color : source_color = vec3(0.6, 0.85, 0.95);
uniform vec3 deep_ice_color : source_color = vec3(0.2, 0.5, 0.8);
uniform float transparency : hint_range(0.0, 1.0) = 0.15;
uniform float metallic : hint_range(0.0, 1.0) = 0.1;
uniform float roughness : hint_range(0.0, 1.0) = 0.15;

group_uniforms frost_pattern;
uniform float frost_scale : hint_range(1.0, 50.0) = 15.0;
uniform float frost_intensity : hint_range(0.0, 2.0) = 1.0;
uniform float frost_coverage : hint_range(0.0, 1.0) = 0.7;
uniform bool animate_frost = true;
uniform float frost_speed : hint_range(0.0, 2.0) = 0.3;

group_uniforms glow;
uniform vec3 emission_color : source_color = vec3(0.4, 0.8, 1.0);
uniform float emission_strength : hint_range(0.0, 3.0) = 0.8;
uniform float pulse_speed : hint_range(0.0, 5.0) = 1.5;

// Simple noise function
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);

	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));

	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float value = 0.0;
	float amplitude = 0.5;

	for (int i = 0; i < 4; i++) {
		value += amplitude * noise(p);
		p *= 2.0;
		amplitude *= 0.5;
	}

	return value;
}

void fragment() {
	// Calculate frost pattern
	vec2 frost_uv = UV * frost_scale;
	float time_offset = 0.0;
	if (animate_frost) {
		time_offset = TIME * frost_speed;
	}

	float frost_pattern = fbm(frost_uv + time_offset);
	float frost = smoothstep(1.0 - frost_coverage, 1.0, frost_pattern) * frost_intensity;

	// Mix colors based on frost and viewing angle
	float depth_factor = 1.0 - dot(NORMAL, VIEW);
	vec3 final_color = mix(ice_color, deep_ice_color, depth_factor * 0.5 + frost * 0.3);

	// Add white frost highlights
	final_color = mix(final_color, vec3(0.95, 0.98, 1.0), frost * 0.4);

	ALBEDO = final_color;
	METALLIC = metallic;
	ROUGHNESS = mix(roughness, 0.6, frost);

	// Pulsing emission
	float pulse = sin(TIME * pulse_speed) * 0.5 + 0.5;
	float edge_glow = pow(1.0 - dot(NORMAL, VIEW), 2.0);

	EMISSION = emission_color * emission_strength * (0.5 + pulse * 0.5) * (0.3 + edge_glow * 0.7);
	EMISSION += vec3(0.9, 0.95, 1.0) * frost * 0.3;

	// Slight transparency at edges
	ALPHA = 1.0 - transparency * edge_glow;
}
