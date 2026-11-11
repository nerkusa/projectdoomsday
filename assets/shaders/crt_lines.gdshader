shader_type canvas_item;
// Экран КПК: строчная развёртка, медленно ползущая полоса и затемнение к краям — как у ЭЛТ.
uniform float lines = 0.16;
uniform float band = 0.05;
uniform float edge = 0.45;

void fragment() {
	float row = step(2.0, mod(FRAGCOORD.y, 3.0));
	float b = smoothstep(0.0, 0.08, abs(fract(UV.y - TIME * 0.07) - 0.5) - 0.42);
	vec2 d = UV - 0.5;
	float v = smoothstep(0.25, 0.75, dot(d, d) * 2.0);
	COLOR = vec4(0.0, 0.0, 0.0, row * lines + v * edge);
	COLOR.rgb += vec3(0.55, 1.0, 0.7) * b * band;
	COLOR.a = max(COLOR.a, b * band);
}
