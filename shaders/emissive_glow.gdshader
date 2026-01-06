shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// Emissive Glow Shader - Pulsating emission effect for weapon upgrades
// Supports color tinting, pulse animation, and intensity control

group_uniforms base_color;
uniform vec3 albedo_color : source_color = vec3(0.2, 0.2, 0.25);
uniform float metallic : hint_range(0.0, 1.0) = 0.7;
uniform float roughness : hint_range(0.0, 1.0) = 0.3;

group_uniforms emission;
uniform vec3 emission_color : source_color = vec3(0.0, 1.0, 1.0);
uniform float emission_strength : hint_range(0.0, 10.0) = 2.0;
uniform float pulse_speed : hint_range(0.0, 10.0) = 2.0;
uniform float pulse_min : hint_range(0.0, 1.0) = 0.3;
uniform float pulse_max : hint_range(0.0, 1.0) = 1.0;
uniform bool enable_pulse = true;

group_uniforms texture_scroll;
uniform sampler2D emission_texture : hint_default_white;
uniform vec2 scroll_speed = vec2(0.0, 0.5);
uniform float texture_scale : hint_range(0.1, 10.0) = 1.0;
uniform bool use_texture = false;

group_uniforms effects;
uniform float rim_power : hint_range(0.0, 10.0) = 0.0;
uniform vec3 rim_color : source_color = vec3(1.0, 1.0, 1.0);

void fragment() {
	// Base material
	ALBEDO = albedo_color;
	METALLIC = metallic;
	ROUGHNESS = roughness;

	// Calculate pulse factor
	float pulse_factor = 1.0;
	if (enable_pulse) {
		float raw_pulse = sin(TIME * pulse_speed) * 0.5 + 0.5;
		pulse_factor = mix(pulse_min, pulse_max, raw_pulse);
	}

	// Calculate emission
	vec3 final_emission = emission_color;

	// Apply scrolling texture if enabled
	if (use_texture) {
		vec2 scrolled_uv = UV * texture_scale + scroll_speed * TIME;
		vec3 tex_emission = texture(emission_texture, scrolled_uv).rgb;
		final_emission *= tex_emission;
	}

	// Apply pulse and strength
	EMISSION = final_emission * emission_strength * pulse_factor;

	// Rim lighting (optional)
	if (rim_power > 0.0) {
		float rim = 1.0 - dot(NORMAL, VIEW);
		rim = pow(rim, rim_power);
		EMISSION += rim_color * rim * pulse_factor;
	}
}
