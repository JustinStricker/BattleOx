shader_type spatial;
render_mode blend_mix, cull_disabled, specular_disabled;

uniform float cloud_density : hint_range(0.0, 1.0) = 0.6;
uniform float cloud_softness : hint_range(0.0, 0.5) = 0.2;
uniform vec4 cloud_color : source_color = vec4(0.92, 0.93, 0.97, 1.0);
uniform vec4 cloud_shadow : source_color = vec4(0.55, 0.58, 0.65, 1.0);
uniform float drift_speed : hint_range(0.0, 0.5) = 0.05;

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
	for (int i = 0; i < 6; i++) {
		v += a * noise(q);
		q = q * 2.0 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v;
}

float fbm_warp(vec2 p) {
	vec2 q = vec2(fbm(p + vec2(0.0, 0.0)), fbm(p + vec2(5.2, 1.3)));
	vec2 r = vec2(fbm(p + q * 1.5 + vec2(1.7, 9.2)), fbm(p + q * 1.5 + vec2(8.3, 2.8)));
	return fbm(p + r * 1.0);
}

void vertex() {
	v_uv = UV;
}

void fragment() {
	vec2 uv = v_uv;
	vec2 center = uv - 0.5;
	float dist = length(center);
	float vignette = 1.0 - smoothstep(0.1, 0.5, dist);

	float t = TIME * drift_speed;
	vec2 noise_uv = uv * 4.0 + vec2(t * 0.3, t * 0.15);

	float n = fbm_warp(noise_uv);

	float edge_mask = smoothstep(0.5, 0.1, dist);
	n = smoothstep(1.0 - cloud_density - cloud_softness, 1.0 - cloud_density + cloud_softness, n);
	n *= edge_mask;
	n = clamp(n, 0.0, 1.0);

	float detail = fbm(uv * 8.0 - vec2(t * 0.5, t * 0.25));
	n = mix(n, n * (0.8 + detail * 0.2), 0.3);

	n *= 0.85 + vignette * 0.15;

	float eps = 0.002;
	float n_x = fbm(noise_uv + vec2(eps, 0.0));
	float n_y = fbm(noise_uv + vec2(0.0, eps));
	vec3 bump = normalize(vec3(n - n_x, n - n_y, 0.4));

	vec3 view_dir = normalize(-VIEW);
	NORMAL = normalize(view_dir + bump * 1.5);

	float rim = 1.0 - max(dot(NORMAL, view_dir), 0.0);
	rim = pow(rim, 4.0) * 0.4;
	EMISSION = rim * cloud_color.rgb * 1.5;

	vec3 col = mix(cloud_shadow.rgb, cloud_color.rgb, n);

	float alpha = n * cloud_color.a;

	ALBEDO = col;
	ALPHA = alpha;
}
