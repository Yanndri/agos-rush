shader_type sky;

uniform vec3 zenith_color : source_color = vec3(0.14, 0.55, 0.95);
uniform vec3 upper_sky_color : source_color = vec3(0.25, 0.72, 1.0);
uniform vec3 horizon_color : source_color = vec3(0.75, 0.92, 1.0);
uniform vec3 ground_horizon_color : source_color = vec3(0.85, 0.93, 1.0);
uniform vec3 ground_color : source_color = vec3(0.62, 0.78, 0.95);

uniform vec3 sun_color : source_color = vec3(1.0, 0.92, 0.75);
uniform float sun_size = 0.03;
uniform float sun_blur = 0.08;
uniform float sun_strength = 1.2;

uniform vec3 cloud_color : source_color = vec3(1.0, 1.0, 1.0);
uniform float cloud_scale = 4.0;
uniform float cloud_speed = 0.01;
uniform float cloud_density = 0.35;
uniform float cloud_softness = 0.18;
uniform float cloud_strength = 0.22;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);

	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));

	vec2 u = f * f * (3.0 - 2.0 * f);

	return mix(a, b, u.x) +
		(c - a) * u.y * (1.0 - u.x) +
		(d - b) * u.x * u.y;
}

float fbm(vec2 p) {
	float value = 0.0;
	float amp = 0.5;

	for (int i = 0; i < 4; i++) {
		value += noise(p) * amp;
		p *= 2.0;
		amp *= 0.5;
	}

	return value;
}

void sky() {
	float y = clamp(EYEDIR.y * 0.5 + 0.5, 0.0, 1.0);

	// Main vertical sky gradient
	vec3 col = mix(horizon_color, upper_sky_color, smoothstep(0.0, 0.45, y));
	col = mix(col, zenith_color, smoothstep(0.45, 1.0, y));

	// Softer horizon / atmospheric lift
	float horizon_lift = 1.0 - abs(EYEDIR.y);
	col += horizon_color * pow(horizon_lift, 6.0) * 0.08;

	// Ground tint below horizon
	float ground_mask = smoothstep(-0.08, 0.03, EYEDIR.y);
	vec3 below_horizon = mix(ground_color, ground_horizon_color, smoothstep(-0.25, 0.02, EYEDIR.y));
	col = mix(below_horizon, col, ground_mask);

	// Sun glow
	if (LIGHT0_ENABLED) {
		float sun_dot = max(dot(EYEDIR, LIGHT0_DIRECTION), 0.0);

		float sun_core = smoothstep(1.0 - sun_size, 1.0, sun_dot);
		float sun_halo = smoothstep(1.0 - (sun_size + sun_blur), 1.0, sun_dot);

		col += sun_color * sun_halo * sun_strength * 0.35;
		col += sun_color * sun_core * sun_strength;
	}

	// Clouds only in upper sky
	vec2 cloud_uv = EYEDIR.xz / max(EYEDIR.y + 0.25, 0.12);
	cloud_uv *= cloud_scale;
	cloud_uv += vec2(TIME * cloud_speed, TIME * cloud_speed * 0.6);

	float cloud_noise = fbm(cloud_uv);
	float cloud_mask = smoothstep(cloud_density, cloud_density + cloud_softness, cloud_noise);

	// Fade clouds near horizon and below
	float sky_only = smoothstep(0.02, 0.18, EYEDIR.y);
	cloud_mask *= sky_only;

	col = mix(col, col + cloud_color * cloud_strength, cloud_mask);

	COLOR = col;
}