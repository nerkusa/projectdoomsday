shader_type spatial;
// Силуэт персонажа, видимый сквозь дома и деревья.
// Накладывается поверх (material_overlay): рисуется только там, где персонажа
// что-то заслоняет (глубина сцены ближе к камере, чем сам персонаж).
render_mode unshaded, depth_test_disabled, depth_draw_never, cull_back, blend_mix, shadows_disabled;
// Тело персонажа пишет в трафарет 1 там, где его видно. Силуэт рисуется только
// вне этих пикселей — поэтому своя рука или нога не дают пятна на теле.
stencil_mode read, compare_not_equal, 1;

uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform vec4 color : source_color = vec4(0.55, 0.8, 1.0, 0.5);
// «Призрак»: там, где персонажа ничего не заслоняет, — лёгкая дымка этого цвета
// (герой крадётся). 0 — только силуэт за препятствиями.
uniform float ghost = 0.0;

void fragment() {
	float scene = texture(depth_tex, SCREEN_UV).r;
	// обратная глубина (reverse-Z): больше — ближе к камере.
	// Запас ~0,6 м (камера ортогональная, дальность 200 м), чтобы персонаж
	// не «заслонял сам себя» рукой или оружием.
	if (scene <= FRAGCOORD.z + 0.003) {
		if (ghost <= 0.0) {
			discard;
		}
		ALBEDO = color.rgb;
		ALPHA = ghost;
	} else {
		ALBEDO = color.rgb;
		ALPHA = color.a;
	}
}
