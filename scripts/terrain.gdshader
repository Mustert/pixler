shader_type canvas_item;

uniform sampler2D tmap : filter_nearest;
uniform vec2 msize = vec2(128.0, 128.0);

float h21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vn(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1.0, 0.0)), f.x), mix(h21(i + vec2(0.0, 1.0)), h21(i + vec2(1.0, 1.0)), f.x), f.y);
}

int gt(vec2 tp) {
	ivec2 c = clamp(ivec2(floor(tp)), ivec2(0), ivec2(msize) - ivec2(1));
	return int(texelFetch(tmap, c, 0).r * 255.0 + 0.5);
}

bool isw(int t) {
	return t <= 1 || t == 9;
}

void fragment() {
	vec2 P = floor(UV * msize * 16.0);
	vec2 Q = P * 0.5;
	vec2 j = (vec2(vn(Q / 6.0), vn(Q / 6.0 + vec2(31.7, 17.3))) - 0.5) * 14.0;
	vec2 tp = (P + j) / 16.0;
	int T = gt(tp);
	float n = vn(Q / 8.0);
	float n2 = vn(Q / 3.0 + 9.0);
	float hh = h21(P);
	vec3 col = vec3(0.4, 0.7, 0.35);

	if (T == 3) { // Gras
		col = n < 0.38 ? vec3(0.36, 0.62, 0.31) : (n < 0.66 ? vec3(0.42, 0.68, 0.34) : vec3(0.48, 0.74, 0.39));
		if (hh < 0.05) col *= 0.86;
		else if (hh > 0.994) {
			float c = h21(P + 7.0);
			col = c < 0.25 ? vec3(0.96, 0.95, 0.9) : (c < 0.5 ? vec3(0.96, 0.85, 0.3) : (c < 0.75 ? vec3(0.94, 0.55, 0.7) : vec3(0.55, 0.72, 0.94)));
		}
	} else if (T == 2) { // Sand
		col = n < 0.5 ? vec3(0.92, 0.83, 0.6) : vec3(0.88, 0.79, 0.56);
		if (sin(Q.x * 0.3 + Q.y * 0.5 + n * 5.0) > 0.92) col *= 0.93;
		if (hh > 0.99) col = vec3(0.98, 0.93, 0.78);
	} else if (T == 4) { // Fels
		col = n < 0.4 ? vec3(0.5, 0.49, 0.55) : (n < 0.7 ? vec3(0.55, 0.53, 0.6) : vec3(0.61, 0.59, 0.66));
		float st = vn(vec2(Q.x / 12.0, Q.y / 4.0) + 3.0);
		if (st > 0.72) col *= 0.88;
		if (hh < 0.02) col *= 0.7;
	} else if (T == 6) { // Asche
		col = n < 0.5 ? vec3(0.27, 0.25, 0.31) : vec3(0.32, 0.29, 0.36);
		if (hh > 0.997) col = vec3(1.0, 0.5, 0.15);
		else if (hh < 0.04) col *= 0.8;
	} else if (T == 7) { // Feenwald
		col = n < 0.4 ? vec3(0.5, 0.8, 0.66) : (n < 0.7 ? vec3(0.58, 0.78, 0.76) : vec3(0.66, 0.74, 0.86));
		if (n2 > 0.75) col = mix(col, vec3(0.76, 0.66, 0.9), 0.5);
		if (hh > 0.995) col = vec3(0.98, 0.9, 1.0);
		else if (hh > 0.988) col = vec3(0.7, 0.9, 1.0);
	} else if (T == 8) { // Sumpf
		col = n < 0.45 ? vec3(0.3, 0.42, 0.27) : vec3(0.35, 0.47, 0.3);
		if (n2 > 0.68) col = vec3(0.37, 0.33, 0.22);
		if (hh < 0.05) col *= 0.85;
		else if (hh > 0.996) col = vec3(0.7, 0.9, 0.5);
	} else if (T == 10) { // Wueste
		float band = sin(Q.x * 0.08 + Q.y * 0.05 + n * 5.0);
		col = band > 0.3 ? vec3(0.96, 0.84, 0.55) : (band > -0.3 ? vec3(0.91, 0.78, 0.48) : vec3(0.85, 0.71, 0.42));
		if (hh > 0.99) col *= 1.06;
		else if (hh < 0.03) col *= 0.93;
	} else if (T == 11) { // Schnee
		col = n < 0.45 ? vec3(0.93, 0.96, 0.99) : vec3(0.85, 0.9, 0.96);
		if (hh > 0.99) col = vec3(1.0);
		else if (hh < 0.03) col = vec3(0.78, 0.85, 0.94);
	} else if (T == 12) { // Eis
		col = n < 0.5 ? vec3(0.66, 0.86, 0.95) : vec3(0.74, 0.91, 0.98);
		if (abs(vn(Q / 9.0 + 5.0) - 0.5) < 0.02) col = vec3(0.95, 0.99, 1.0);
		if (hh > 0.995) col = vec3(1.0);
	} else if (T == 5) { // Lava
		float v = vn(Q / 6.0 + vec2(TIME * 0.25, TIME * 0.1));
		v += 0.25 * sin(TIME * 1.5 + vn(Q / 3.0) * 6.28);
		col = v < 0.35 ? vec3(0.55, 0.14, 0.07) : (v < 0.6 ? vec3(0.9, 0.34, 0.1) : (v < 0.85 ? vec3(1.0, 0.66, 0.16) : vec3(1.0, 0.9, 0.45)));
		bool rim = false;
		for (int k = 0; k < 4; k++) {
			vec2 o = k == 0 ? vec2(2.0, 0.0) : (k == 1 ? vec2(-2.0, 0.0) : (k == 2 ? vec2(0.0, 2.0) : vec2(0.0, -2.0)));
			if (gt((P + j + o) / 16.0) != 5) rim = true;
		}
		if (rim) col = mix(vec3(0.3, 0.08, 0.08), vec3(0.85, 0.3, 0.1), h21(P) * 0.6);
	} else { // Wasser: 0 tief, 1 flach, 9 Moor
		if (T == 0) col = n < 0.5 ? vec3(0.17, 0.35, 0.65) : vec3(0.2, 0.4, 0.72);
		else if (T == 1) col = n < 0.5 ? vec3(0.27, 0.55, 0.83) : vec3(0.33, 0.62, 0.88);
		else {
			col = n < 0.5 ? vec3(0.23, 0.37, 0.3) : vec3(0.27, 0.43, 0.34);
			if (vn(Q / 5.0 + 20.0) > 0.78) col = vec3(0.35, 0.6, 0.35);
		}
		float rp = sin((Q.x * 0.35 + Q.y * 0.22) + TIME * 1.5 + n * 6.0);
		if (rp > 0.94) col += 0.07;
		float k = h21(floor(P / 2.0) + 3.0);
		if (k < 0.04 && fract(k * 77.0 + TIME * 0.7) < 0.25) col = vec3(0.9, 0.97, 1.0);
		if (T <= 1) {
			bool shore = false;
			for (int q = 0; q < 4; q++) {
				vec2 o = q == 0 ? vec2(2.0, 0.0) : (q == 1 ? vec2(-2.0, 0.0) : (q == 2 ? vec2(0.0, 2.0) : vec2(0.0, -2.0)));
				if (!isw(gt((P + j + o) / 16.0))) shore = true;
			}
			if (shore) {
				float w = 0.5 + 0.5 * sin(TIME * 2.0 + (P.x + P.y) * 0.4);
				col = mix(col, vec3(0.92, 0.98, 1.0), 0.4 + 0.4 * w);
			}
		}
	}
	COLOR = vec4(col, 1.0);
}
