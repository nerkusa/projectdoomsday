shader_type canvas_item;
// Фильтр поверх 3D-картинки (интерфейс не трогает): чёткость, контраст, насыщенность,
// раздельный тон теней и светов, виньетка и лёгкое плёночное зерно.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float sharpen = 0.25;
uniform float contrast = 1.08;
uniform float saturation = 1.05;
uniform float exposure = 1.0;
uniform vec3 shadow_tint = vec3(0.0, 0.0, 0.0);
uniform vec3 light_tint = vec3(1.0, 1.0, 1.0);
uniform float vignette = 0.35;
uniform float grain = 0.035;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 px = SCREEN_PIXEL_SIZE;
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	// чёткость: разница с размытым соседством
	vec3 blur = (texture(screen_tex, SCREEN_UV + vec2(px.x, 0.0)).rgb + texture(screen_tex, SCREEN_UV - vec2(px.x, 0.0)).rgb
		+ texture(screen_tex, SCREEN_UV + vec2(0.0, px.y)).rgb + texture(screen_tex, SCREEN_UV - vec2(0.0, px.y)).rgb) * 0.25;
	c += (c - blur) * sharpen;
	c *= exposure;
	// контраст вокруг середины и насыщенность
	c = (c - 0.5) * contrast + 0.5;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(l), c, saturation);
	// раздельный тон: тени подкрашиваем, светлое — тонируем
	l = clamp(dot(c, vec3(0.299, 0.587, 0.114)), 0.0, 1.0);
	c += shadow_tint * (1.0 - l) * 0.6;
	c *= mix(vec3(1.0), light_tint, l);
	// виньетка
	vec2 d = SCREEN_UV - 0.5;
	d.x *= SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	float v = smoothstep(0.35, 1.05, length(d) * 1.25);
	c *= 1.0 - v * vignette;
	// зерно
	float n = hash(SCREEN_UV / px + fract(TIME) * 61.0) - 0.5;
	c += n * grain;
	COLOR = vec4(clamp(c, 0.0, 1.0), 1.0);
}
