shader_type spatial;
render_mode blend_mix, cull_disabled;

uniform float wind_strength : hint_range(0.0, 2.0) = 0.5;
uniform float wind_speed : hint_range(0.0, 3.0) = 1.0;
uniform float wind_frequency : hint_range(0.1, 5.0) = 1.5;
uniform float wind_power : hint_range(0.5, 3.0) = 1.5;
uniform vec2 wind_direction = vec2(1.0, 0.5);
uniform vec4 color_tint : source_color = vec4(1.0);
uniform float turbulence : hint_range(0.0, 1.0) = 0.4;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
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
	float v = 0.0;
	float a = 0.5;
	vec2 q = p;
	for (int i = 0; i < 4; i++) {
		v += a * noise(q);
		q = q * 2.0 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v;
}

void vertex() {
	vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float t = TIME * wind_speed;

	vec2 noise_uv = world_pos.xz * wind_frequency + t;
	float wind = fbm(noise_uv) - 0.5;

	vec2 turb_uv = world_pos.xz * wind_frequency * 4.0 + t * 2.0;
	float turb = (fbm(turb_uv) - 0.5) * turbulence;

	vec2 gust_uv = world_pos.xz * wind_frequency * 0.2 + t * 0.3;
	float gust = fbm(gust_uv) * 0.5 + 0.5;

	wind = wind * gust + turb;

	float height_factor = pow(max(VERTEX.y, 0.001), wind_power) * 0.3;

	float bend = wind * wind_strength * height_factor;
	vec2 wdir = normalize(wind_direction);
	VERTEX.x += bend * wdir.x;
	VERTEX.z += bend * wdir.y;

	float twist_angle = wind * wind_strength * height_factor * 0.15;
	float cos_a = cos(twist_angle);
	float sin_a = sin(twist_angle);
	float vx = VERTEX.x;
	float vz = VERTEX.z;
	VERTEX.x = vx * cos_a - vz * sin_a;
	VERTEX.z = vx * sin_a + vz * cos_a;
}

void fragment() {
	vec3 col = COLOR.rgb * color_tint.rgb;

	float alpha = COLOR.a * color_tint.a;

	ALBEDO = col;
	ALPHA = alpha;
	ROUGHNESS = 0.8;
}
