shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// Metallic Reflection Shader - Chrome/mirror effect for Ricochet upgrade
// Creates highly reflective surface with animated reflections

group_uniforms metal;
uniform vec3 metal_color : source_color = vec3(0.9, 0.9, 0.95);
uniform vec3 tint_color : source_color = vec3(0.8, 0.85, 0.7);
uniform float metallic : hint_range(0.0, 1.0) = 1.0;
uniform float roughness : hint_range(0.0, 1.0) = 0.05;

group_uniforms reflection;
uniform float reflection_strength : hint_range(0.0, 2.0) = 1.0;
uniform float fresnel_power : hint_range(0.1, 10.0) = 5.0;
uniform vec3 fresnel_color : source_color = vec3(1.0, 1.0, 0.8);

group_uniforms animation;
uniform float shimmer_speed : hint_range(0.0, 5.0) = 1.0;
uniform float shimmer_scale : hint_range(1.0, 20.0) = 5.0;
uniform float shimmer_intensity : hint_range(0.0, 1.0) = 0.3;

group_uniforms facets;
uniform bool show_facets = true;
uniform float facet_scale : hint_range(5.0, 50.0) = 15.0;
uniform float facet_intensity : hint_range(0.0, 1.0) = 0.2;

// Hash for pseudo-random
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	// Fresnel effect
	float fresnel = pow(1.0 - dot(NORMAL, VIEW), fresnel_power);

	// Shimmer animation
	float shimmer = sin(UV.x * shimmer_scale + TIME * shimmer_speed) *
	                cos(UV.y * shimmer_scale * 0.7 - TIME * shimmer_speed * 0.5);
	shimmer = shimmer * 0.5 + 0.5;
	shimmer *= shimmer_intensity;

	// Faceted look (angular reflections)
	float facet = 0.0;
	if (show_facets) {
		vec2 facet_uv = floor(UV * facet_scale) / facet_scale;
		facet = hash(facet_uv) * facet_intensity;
	}

	// Base color with tint
	vec3 final_color = mix(metal_color, tint_color, 0.3 + shimmer * 0.2);
	final_color += facet * 0.1;

	ALBEDO = final_color;
	METALLIC = metallic;
	ROUGHNESS = roughness + facet * 0.1;

	// Emission for extra shine
	vec3 edge_glow = fresnel_color * fresnel * reflection_strength;
	vec3 shimmer_glow = tint_color * shimmer * 0.5;

	EMISSION = edge_glow + shimmer_glow;
}
