shader_type spatial;

render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 shallow_color : source_color = vec4(0.22, 0.72, 0.82, 0.72);
uniform vec4 deep_color : source_color = vec4(0.03, 0.28, 0.45, 0.88);
uniform vec4 foam_color : source_color = vec4(0.85, 0.97, 1.0, 0.75);

uniform float wave_speed = 1.0;
uniform float wave_scale = 12.0;
uniform float secondary_scale = 20.0;

uniform float fresnel_power = 4.0;
uniform float fresnel_strength = 0.25;

uniform float foam_threshold = 0.75;
uniform float foam_strength = 0.35;

uniform float roughness_val = 0.08;
uniform float metallic_val = 0.0;

void fragment() {
	float t = TIME * wave_speed;

	vec2 uv1 = UV * wave_scale + vec2(t * 0.08, t * 0.05);
	vec2 uv2 = UV * secondary_scale + vec2(-t * 0.05, t * 0.07);

	float wave1 = sin(uv1.x) * cos(uv1.y);
	float wave2 = sin(uv2.x + 1.4) * cos(uv2.y - 0.8);

	float pattern = (wave1 + wave2) * 0.5;
	pattern = pattern * 0.5 + 0.5;

	vec3 base_color = mix(deep_color.rgb, shallow_color.rgb, pattern);

	float foam_mask = smoothstep(foam_threshold, 1.0, pattern);
	vec3 foam = foam_color.rgb * foam_mask * foam_strength;

	float fresnel = pow(1.0 - max(dot(normalize(VIEW), NORMAL), 0.0), fresnel_power);
	vec3 fresnel_tint = vec3(fresnel * fresnel_strength);

	ALBEDO = base_color + foam + fresnel_tint;
	ALPHA = mix(deep_color.a, shallow_color.a, pattern);

	ROUGHNESS = roughness_val;
	METALLIC = metallic_val;
}