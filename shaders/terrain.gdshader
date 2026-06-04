shader_type spatial;
render_mode cull_disabled;

uniform float snow_elevation : hint_range(2.0, 10.0) = 4.5;
uniform float snow_transition : hint_range(0.1, 3.0) = 1.2;
uniform float noise_scale : hint_range(0.01, 0.5) = 0.08;
uniform float noise_strength : hint_range(0.0, 0.5) = 0.12;
uniform float slope_strength : hint_range(0.0, 0.5) = 0.25;
uniform float detail_strength : hint_range(0.0, 0.2) = 0.08;

varying vec3 v_world_pos;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);

	float a = hash(i + vec3(0.0, 0.0, 0.0));
	float b = hash(i + vec3(1.0, 0.0, 0.0));
	float c = hash(i + vec3(0.0, 1.0, 0.0));
	float d = hash(i + vec3(1.0, 1.0, 0.0));
	float e = hash(i + vec3(0.0, 0.0, 1.0));
	float ff = hash(i + vec3(1.0, 0.0, 1.0));
	float g = hash(i + vec3(0.0, 1.0, 1.0));
	float hh = hash(i + vec3(1.0, 1.0, 1.0));

	float u1 = mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
	float u2 = mix(mix(e, ff, f.x), mix(g, hh, f.x), f.y);
	return mix(u1, u2, f.z);
}

float fbm(vec3 p) {
	float v = 0.0;
	float a = 0.5;
	vec3 q = p;
	for (int i = 0; i < 6; i++) {
		v += a * noise3(q);
		q = q * 2.0 + vec3(1.7, 9.2, 5.1);
		a *= 0.5;
	}
	return v;
}

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	COLOR = COLOR;
}

void fragment() {
	vec3 base = COLOR.rgb;
	vec3 wpos = v_world_pos;

	float detail = fbm(wpos * noise_scale);

	float height = wpos.y;
	float snow = smoothstep(snow_elevation - snow_transition, snow_elevation + snow_transition, height);

	vec3 snow_col = mix(vec3(0.82, 0.84, 0.90), vec3(0.95, 0.96, 1.00), detail);

	vec3 col = base + (detail - 0.5) * noise_strength;

	float slope = 1.0 - NORMAL.y;
	float rock_mask = smoothstep(0.35, 0.7, slope) * slope_strength * 2.0;
	vec3 rock_col = mix(vec3(0.25, 0.22, 0.18), vec3(0.4, 0.38, 0.32), detail);
	col = mix(col, rock_col, rock_mask);

	col = mix(col, snow_col, snow);

	float micro = fbm(wpos * noise_scale * 6.0 + vec3(12.7, 0.0, 5.3));
	col += (micro - 0.5) * detail_strength;

	col = clamp(col, 0.0, 1.0);

	ALBEDO = col;
	ROUGHNESS = 0.85;

	float nx1 = fbm(wpos * noise_scale * 3.0 + vec3(1.2, 0.0, 0.0)) - 0.5;
	float nz1 = fbm(wpos * noise_scale * 3.0 + vec3(0.0, 0.0, 1.2)) - 0.5;
	float nx2 = fbm(wpos * noise_scale * 6.0 + vec3(3.7, 1.2, 0.0)) - 0.5;
	float nz2 = fbm(wpos * noise_scale * 6.0 + vec3(0.0, 1.2, 8.4)) - 0.5;
	NORMAL = normalize(NORMAL + vec3(nx1 + nx2 * 0.5, 0.0, nz1 + nz2 * 0.5) * 0.15);
}
