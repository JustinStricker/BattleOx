shader_type spatial;
render_mode blend_mix, cull_disabled;

uniform float wave_speed : hint_range(0.1, 3.0) = 1.2;
uniform float wave_height : hint_range(0.0, 1.0) = 0.35;
uniform float wave_freq : hint_range(0.5, 5.0) = 0.8;
uniform float wave_steepness : hint_range(0.0, 1.0) = 0.4;

uniform vec4 shallow_col : source_color = vec4(0.10, 0.48, 0.40, 0.72);
uniform vec4 deep_col : source_color = vec4(0.01, 0.05, 0.14, 0.92);

uniform float spec_intensity : hint_range(0.0, 2.0) = 0.8;
uniform float fresnel_power : hint_range(0.0, 5.0) = 3.0;
uniform float foam_intensity : hint_range(0.0, 1.0) = 0.5;

uniform sampler2D DEPTH_TEXTURE : hint_depth_texture, filter_linear_mipmap;

varying vec3 v_world_pos;
varying float v_water_height;

void vertex() {
	vec3 pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_world_pos = pos;

	float t = TIME * wave_speed;

	vec3 disp = vec3(0.0);
	float dxdx0 = 1.0, dxdz0 = 0.0;
	float dzdx0 = 0.0, dzdz0 = 1.0;
	float dydx0 = 0.0, dydz0 = 0.0;

	const int N = 6;
	for (int i = 0; i < N; i++) {
		float a, w, p;
		vec2 d;

		if (i == 0) { a = wave_height * 0.40; w = wave_freq * 1.00; p = t * 1.00; d = vec2(1.00, 0.00); }
		if (i == 1) { a = wave_height * 0.30; w = wave_freq * 1.20; p = t * 0.80; d = vec2(0.00, 1.00); }
		if (i == 2) { a = wave_height * 0.25; w = wave_freq * 0.90; p = t * 1.30; d = normalize(vec2(0.70, 0.70)); }
		if (i == 3) { a = wave_height * 0.20; w = wave_freq * 1.40; p = t * 0.60; d = normalize(vec2(-0.50, 0.80)); }
		if (i == 4) { a = wave_height * 0.15; w = wave_freq * 1.10; p = t * 1.10; d = normalize(vec2(0.90, -0.30)); }
		if (i == 5) { a = wave_height * 0.10; w = wave_freq * 0.80; p = t * 0.90; d = normalize(vec2(-0.60, -0.60)); }

		float qi = wave_steepness / (w * a * float(N));
		float theta = w * dot(d, pos.xz) + p;
		float s = sin(theta);
		float c = cos(theta);

		disp += vec3(qi * a * d.x * c, qi * a * d.y * c, a * s);
		float ws = w * s;
		float wc = w * c;
		dxdx0 -= qi * a * d.x * d.x * ws;
		dxdz0 -= qi * a * d.x * d.y * ws;
		dzdx0 -= qi * a * d.x * d.y * ws;
		dzdz0 -= qi * a * d.y * d.y * ws;
		dydx0 += a * d.x * wc;
		dydz0 += a * d.y * wc;
	}

	pos.x += disp.x;
	pos.z += disp.y;
	pos.y += disp.z;

	v_water_height = pos.y;

	vec3 tangent = vec3(dxdx0, dydx0, dzdx0);
	vec3 binormal = vec3(dxdz0, dydz0, dzdz0);
	NORMAL = normalize(cross(binormal, tangent));

	VERTEX = (inverse(MODEL_MATRIX) * vec4(pos, 1.0)).xyz;
}

void fragment() {
	vec3 wpos = v_world_pos;
	float water_y = v_water_height;

	float water_depth;
	float scene_depth = texture(DEPTH_TEXTURE, SCREEN_UV).r;
	if (scene_depth >= 0.99999) {
		water_depth = 12.0;
	} else {
		vec4 clip = vec4(SCREEN_UV * 2.0 - 1.0, scene_depth * 2.0 - 1.0, 1.0);
		vec4 view = INV_PROJECTION_MATRIX * clip;
		vec3 view_pos = view.xyz / view.w;
		vec3 bg_world = (INV_VIEW_MATRIX * vec4(view_pos, 1.0)).xyz;
		water_depth = clamp(bg_world.y - water_y, 0.0, 12.0);
	}
	float depth_factor = water_depth / 12.0;

	vec3 V = normalize((INV_VIEW_MATRIX[3] - vec4(wpos, 1.0)).xyz);
	float ndotv = max(dot(NORMAL, V), 0.0);
	float fresnel = pow(1.0 - ndotv, fresnel_power);

	vec3 col = mix(shallow_col.rgb, deep_col.rgb, depth_factor);
	float alpha = mix(shallow_col.a, deep_col.a, depth_factor);

	float sss = exp(-water_depth * 0.5) * 0.12;
	col += vec3(0.04, 0.10, 0.06) * sss;

	col = mix(col, vec3(0.45, 0.55, 0.75), fresnel * 0.5);

	float foam = 0.0;
	if (water_depth < 1.5) {
		float fn = sin(wpos.x * 3.0 + wpos.z * 2.7 + TIME * 0.5) * 0.30
				 + sin(wpos.x * 5.1 - wpos.z * 4.3 + TIME * 0.8) * 0.25
				 + sin((wpos.x + wpos.z) * 2.3 + TIME * 0.3) * 0.20;
		fn = fn * 0.5 + 0.5;
		float edge = 1.0 - smoothstep(0.0, 1.5, water_depth);
		foam = edge * fn * foam_intensity;
	}
	col += foam;

	vec3 L = normalize(vec3(0.6, 0.5, 0.6));
	vec3 H = normalize(L + V);
	float spec = pow(max(dot(NORMAL, H), 0.0), 128.0);
	col += vec3(1.0, 0.95, 0.85) * spec * spec_intensity;

	ALBEDO = col;
	METALLIC = 0.0;
	ROUGHNESS = mix(0.25, 0.05, fresnel);
	ALPHA = alpha;
}
