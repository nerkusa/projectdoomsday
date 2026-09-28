shader_type spatial;
// Земля локации: трава, выгоревший луг, дорога и грязь смешиваются по карте
// смешивания (splat): R — луг, G — дорога, B — грязь. Текстуры — в мировых
// координатах, как у трипланарных материалов, поэтому стыков между кусками нет.

uniform sampler2D grass_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass_n : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D meadow_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D meadow_n : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt_n : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D mud_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D mud_n : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D splat : filter_linear, repeat_disable;
// x, z левого верхнего угла карты смешивания и её размер в метрах
uniform vec4 splat_rect = vec4(0.0, 0.0, 100.0, 100.0);
uniform vec3 meadow_tint : source_color = vec3(0.549, 0.525, 0.447);
uniform vec3 mud_tint : source_color = vec3(0.5, 0.42, 0.33);
// на крутых скатах (стенки рва) — больше голой земли
uniform float slope_mud = 1.0;

varying vec3 wpos;
varying vec3 wnrm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float lum(vec3 c) {
	return dot(c, vec3(0.3, 0.5, 0.2));
}

// Переход «по высоте»: вес подмешивается сначала там, где текстура светлее/выше,
// поэтому граница получается рваной, а не размытой полосой.
float blend_w(float w, float h, float n) {
	return smoothstep(0.0, 1.0, clamp((w - 0.5) * 3.0 + 0.5 + (h - 0.5) * 0.9 + (n - 0.5) * 0.8, 0.0, 1.0));
}

void fragment() {
	vec2 p = wpos.xz;
	vec3 s = texture(splat, (p - splat_rect.xy) / splat_rect.zw).rgb;
	float n = lum(texture(meadow_tex, p * 0.021).rgb) * 1.4 - 0.2;

	vec3 cg = texture(grass_tex, p * 0.18).rgb;
	vec3 cm = texture(meadow_tex, p * 0.15).rgb * meadow_tint;
	vec3 cd = texture(dirt_tex, p * 0.3).rgb;
	vec3 cu = texture(mud_tex, p * 0.35).rgb * mud_tint;
	vec3 ng = texture(grass_n, p * 0.18).rgb;
	vec3 nm = texture(meadow_n, p * 0.15).rgb;
	vec3 nd = texture(dirt_n, p * 0.3).rgb;
	vec3 nu = texture(mud_n, p * 0.35).rgb;

	float steep = clamp((1.0 - wnrm.y) * 4.0, 0.0, 1.0) * slope_mud;
	float wm = blend_w(s.r, lum(cm) * 1.6, n);
	float wd = blend_w(s.g, 1.0 - lum(cd) * 1.4, 1.0 - n);
	float wu = blend_w(max(s.b, steep * 0.8), 1.0 - lum(cu) * 2.2, n);

	vec3 c = mix(cg, cm, wm);
	vec3 nn = mix(ng, nm, wm);
	float r = 0.92;
	c = mix(c, cd, wd);
	nn = mix(nn, nd, wd);
	c = mix(c, cu, wu);
	nn = mix(nn, nu, wu);
	r = mix(r, 0.8, wu);

	ALBEDO = c;
	NORMAL_MAP = nn;
	ROUGHNESS = r;
}
