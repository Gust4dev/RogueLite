shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// Organic Lifesteal Shader - Living, organic look for Lifesteal upgrade
// Creates veins, pulsing organic texture, and soul-absorption aesthetic

group_uniforms organic;
uniform vec3 base_color : source_color = vec3(0.15, 0.1, 0.2);
uniform vec3 vein_color : source_color = vec3(0.4, 0.8, 0.3);
uniform vec3 glow_color : source_color = vec3(0.6, 0.1, 0.8);
uniform float metallic : hint_range(0.0, 1.0) = 0.2;
uniform float roughness : hint_range(0.0, 1.0) = 0.7;

group_uniforms veins;
uniform float vein_scale : hint_range(1.0, 20.0) = 8.0;
uniform float vein_intensity : hint_range(0.0, 2.0) = 1.0;
uniform float vein_pulse_speed : hint_range(0.0, 5.0) = 1.5;
uniform float vein_thickness : hint_range(0.01, 0.3) = 0.1;

group_uniforms heartbeat;
uniform float heartbeat_speed : hint_range(0.0, 5.0) = 1.2;
uniform float heartbeat_intensity : hint_range(0.0, 1.0) = 0.5;

group_uniforms absorption;
uniform float absorption_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec3 absorption_color : source_color = vec3(1.0, 0.3, 0.3);

// Noise functions
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

// Voronoi for vein-like patterns
vec2 voronoi(vec2 x) {
	vec2 p = floor(x);
	vec2 f = fract(x);

	float min_dist = 1.0;
	vec2 min_point = vec2(0.0);

	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 b = vec2(float(i), float(j));
			vec2 r = b - f + hash(p + b);
			float d = dot(r, r);

			if (d < min_dist) {
				min_dist = d;
				min_point = r;
			}
		}
	}

	return vec2(sqrt(min_dist), length(min_point));
}

void fragment() {
	// Heartbeat pulse
	float heartbeat = pow(abs(sin(TIME * heartbeat_speed * PI)), 4.0);
	float pulse = 1.0 + heartbeat * heartbeat_intensity;

	// Vein pattern using voronoi
	vec2 vein_uv = UV * vein_scale;
	vec2 v = voronoi(vein_uv + TIME * 0.1);

	// Create vein lines at cell edges
	float vein = 1.0 - smoothstep(0.0, vein_thickness, v.x);

	// Flowing veins animation
	float flow = sin(v.y * 10.0 - TIME * vein_pulse_speed) * 0.5 + 0.5;
	vein *= flow * vein_intensity;

	// Base organic texture
	float organic_noise = noise(UV * 15.0 + TIME * 0.2) * 0.3;

	// Mix colors
	vec3 final_color = base_color + organic_noise * 0.1;
	final_color = mix(final_color, vein_color, vein * 0.7);

	ALBEDO = final_color;
	METALLIC = metallic;
	ROUGHNESS = roughness - vein * 0.2;

	// Emission from veins and edges
	float edge = pow(1.0 - dot(NORMAL, VIEW), 2.0);
	vec3 vein_emission = vein_color * vein * pulse * 1.5;
	vec3 edge_emission = glow_color * edge * 0.5;

	// Absorption glow (when healing)
	vec3 absorb_emission = absorption_color * absorption_amount * 2.0;

	EMISSION = vein_emission + edge_emission + absorb_emission;
	EMISSION *= pulse;
}
