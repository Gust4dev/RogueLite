shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// Fresnel Edge Shader - Edge glow effect for weapon upgrades
// Creates glowing edges with customizable falloff and colors

group_uniforms base_material;
uniform vec3 albedo_color : source_color = vec3(0.15, 0.15, 0.2);
uniform float metallic : hint_range(0.0, 1.0) = 0.8;
uniform float roughness : hint_range(0.0, 1.0) = 0.2;

group_uniforms fresnel_effect;
uniform vec3 fresnel_color : source_color = vec3(0.0, 0.8, 1.0);
uniform float fresnel_power : hint_range(0.1, 10.0) = 3.0;
uniform float fresnel_strength : hint_range(0.0, 5.0) = 2.0;
uniform bool fresnel_additive = true;

group_uniforms animation;
uniform float pulse_speed : hint_range(0.0, 10.0) = 0.0;
uniform float pulse_intensity : hint_range(0.0, 1.0) = 0.3;
uniform float shimmer_speed : hint_range(0.0, 10.0) = 0.0;
uniform float shimmer_intensity : hint_range(0.0, 1.0) = 0.2;

group_uniforms inner_glow;
uniform vec3 inner_color : source_color = vec3(0.0, 0.5, 1.0);
uniform float inner_strength : hint_range(0.0, 3.0) = 0.5;
uniform float inner_falloff : hint_range(0.1, 5.0) = 2.0;

void fragment() {
	// Base material
	ALBEDO = albedo_color;
	METALLIC = metallic;
	ROUGHNESS = roughness;

	// Calculate fresnel (edge glow)
	float fresnel = 1.0 - dot(NORMAL, VIEW);
	fresnel = pow(fresnel, fresnel_power);

	// Pulse animation
	float pulse = 1.0;
	if (pulse_speed > 0.0) {
		pulse = 1.0 + sin(TIME * pulse_speed) * pulse_intensity;
	}

	// Shimmer effect (moving pattern)
	float shimmer = 1.0;
	if (shimmer_speed > 0.0) {
		float shimmer_pattern = sin(UV.y * 20.0 + TIME * shimmer_speed) * 0.5 + 0.5;
		shimmer = 1.0 + shimmer_pattern * shimmer_intensity;
	}

	// Calculate fresnel emission
	vec3 fresnel_emission = fresnel_color * fresnel * fresnel_strength * pulse * shimmer;

	// Inner glow (inverse fresnel)
	float inner_fresnel = dot(NORMAL, VIEW);
	inner_fresnel = pow(inner_fresnel, inner_falloff);
	vec3 inner_emission = inner_color * inner_fresnel * inner_strength;

	// Combine emissions
	EMISSION = fresnel_emission + inner_emission;

	// Apply fresnel to albedo if not additive
	if (!fresnel_additive) {
		ALBEDO = mix(albedo_color, fresnel_color, fresnel * 0.5);
	}
}
