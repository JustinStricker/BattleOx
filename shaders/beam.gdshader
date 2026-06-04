shader_type spatial;
render_mode blend_add, cull_disabled, unshaded;

uniform float pulse_speed : hint_range(0.1, 5.0) = 2.0;
uniform float scroll_speed : hint_range(0.1, 5.0) = 1.5;
uniform float distortion : hint_range(0.0, 0.5) = 0.05;
uniform vec4 core_color : source_color = vec4(0.5, 0.85, 1.0, 1.0);
uniform vec4 edge_color : source_color = vec4(0.15, 0.35, 0.75, 0.3);
uniform float emission_strength : hint_range(0.0, 10.0) = 6.0;

varying vec2 v_uv;

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
	for (int i = 0; i < 5; i++) {
		v += a * noise(q);
		q = q * 2.0 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v;
}

void vertex() {
	v_uv = UV;

	vec2 noise_uv = vec2(UV.x * 4.0 + TIME * 0.6, TIME * 0.3);
	float displace = (fbm(noise_uv) - 0.5) * distortion * 2.0;
	VERTEX.x += displace;
}

void fragment() {
	float center_dist = abs(v_uv.x - 0.5) * 2.0;
	float height_fade = 1.0 - abs(v_uv.y - 0.5) * 2.0;

	float core = 1.0 - smoothstep(0.0, 0.5, center_dist);

	float scroll = v_uv.x * 8.0 - TIME * scroll_speed;
	float bands = sin(scroll) * 0.5 + 0.5;
	bands = bands * bands;
	bands = smoothstep(0.3, 0.9, bands);

	vec2 noise_uv = v_uv * 4.0 + vec2(TIME * pulse_speed * 0.25, TIME * 0.2);
	float pulse = fbm(noise_uv);

	float rim = smoothstep(0.5, 1.0, center_dist);

	float alpha = core + bands * 0.3 + pulse * 0.2 + rim * 0.4;
	alpha *= height_fade;
	alpha = clamp(alpha, 0.0, 1.0);

	vec3 col = mix(core_color.rgb, edge_color.rgb, smoothstep(0.0, 0.6, center_dist));
	col += bands * core_color.rgb * 0.25;
	col += pulse * core_color.rgb * 0.15;
	col += (core_color.rgb + vec3(0.3)) * rim * 0.35;

	ALBEDO = col;
	ALPHA = alpha;
	EMISSION = col * emission_strength * alpha;
}
