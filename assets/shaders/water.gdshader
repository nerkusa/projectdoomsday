shader_type spatial;
// Река: мелкая рябь (две карты нормалей с течением), блик неба по Френелю,
// тёмная глубина к середине, пена и мутная полоса у берега (shore_z — линия берега).
render_mode blend_mix, cull_disabled, depth_draw_opaque, specular_schlick_ggx;

uniform vec4 deep_color : source_color = vec4(0.05, 0.08, 0.07, 0.94);
uniform vec4 shallow_color : source_color = vec4(0.22, 0.24, 0.17, 0.82);
uniform vec4 sky_color : source_color = vec4(0.55, 0.62, 0.66, 1.0);
uniform vec4 foam_color : source_color = vec4(0.78, 0.76, 0.66, 1.0);
uniform sampler2D normal_a : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_b : hint_normal, filter_linear_mipmap, repeat_enable;
uniform vec2 flow = vec2(0.06, 0.01);
uniform float scale_a = 0.09;
uniform float scale_b = 0.21;
uniform float wave_height = 0.035;
// берег: z линии берега и в какую сторону от неё вода (+1 — к +z)
uniform float shore_z = 64.0;
uniform float shore_dir = 1.0;
uniform float shallow_width = 5.0;
uniform float foam_width = 0.9;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float t = TIME;
	VERTEX.y += (sin(wpos.x * 0.7 + t * 1.3) * 0.5 + sin(wpos.z * 1.1 - t * 0.9) * 0.5) * wave_height;
}

void fragment() {
	vec2 uv1 = wpos.xz * scale_a + flow * TIME;
	vec2 uv2 = wpos.xz * scale_b - flow.yx * TIME * 1.7;
	vec3 n1 = texture(normal_a, uv1).rgb;
	vec3 n2 = texture(normal_b, uv2).rgb;
	NORMAL_MAP = normalize(mix(n1, n2, 0.5));
	NORMAL_MAP_DEPTH = 0.6;
	float from_shore = (wpos.z - shore_z) * shore_dir;
	float depth_k = smoothstep(0.0, shallow_width, from_shore);
	vec3 col = mix(shallow_color.rgb, deep_color.rgb, depth_k);
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	col = mix(col, sky_color.rgb, fres * 0.55);
	// пена у самого берега, рваная от ряби
	float foam = (1.0 - smoothstep(0.0, foam_width, from_shore)) * smoothstep(0.35, 0.75, n1.r + n2.g * 0.6 - 0.3);
	col = mix(col, foam_color.rgb, clamp(foam, 0.0, 0.8));
	ALBEDO = col;
	ROUGHNESS = mix(0.08, 0.35, foam);
	METALLIC = 0.0;
	SPECULAR = 0.6;
	ALPHA = mix(shallow_color.a, deep_color.a, depth_k);
}
