class_name Graphics
extends RefCounted
## Настройки графики: хранятся в Game.settings (user://settings.json),
## применяются при старте, при загрузке локации и сразу при изменении в меню.

const OPTIONS := [
	{"id": "gfx_preset", "name": "Качество", "values": ["fast", "normal", "pretty"],
		"names": {"fast": "быстро", "normal": "обычно", "pretty": "красиво"}},
	{"id": "gfx_shadows", "name": "Тени", "values": ["off", "low", "high"],
		"names": {"off": "нет", "low": "простые", "high": "мягкие"}},
	{"id": "gfx_aa", "name": "Сглаживание", "values": ["off", "fxaa", "msaa2", "msaa4"],
		"names": {"off": "нет", "fxaa": "FXAA", "msaa2": "MSAA ×2", "msaa4": "MSAA ×4"}},
	{"id": "gfx_scale", "name": "Масштаб картинки", "values": ["0.5", "0.75", "1.0"],
		"names": {"0.5": "50%", "0.75": "75%", "1.0": "100%"}},
	{"id": "gfx_glow", "name": "Свечение огня", "values": ["off", "on"], "names": {"off": "нет", "on": "да"}},
	{"id": "gfx_window", "name": "Режим окна", "values": ["window", "fullscreen"],
		"names": {"window": "окно", "fullscreen": "весь экран"}},
	{"id": "gfx_vsync", "name": "Вертикальная синхронизация", "values": ["on", "off"], "names": {"on": "да", "off": "нет"}},
]

## Что меняет выбор «Качества»
const PRESETS := {
	"fast": {"gfx_shadows": "off", "gfx_aa": "off", "gfx_scale": "0.75", "gfx_glow": "off"},
	"normal": {"gfx_shadows": "low", "gfx_aa": "fxaa", "gfx_scale": "1.0", "gfx_glow": "on"},
	"pretty": {"gfx_shadows": "high", "gfx_aa": "msaa4", "gfx_scale": "1.0", "gfx_glow": "on"},
}

const DEFAULTS := {"gfx_preset": "normal", "gfx_shadows": "high", "gfx_aa": "fxaa", "gfx_scale": "1.0",
	"gfx_glow": "on", "gfx_window": "window", "gfx_vsync": "on"}


static func value(id: String) -> String:
	return str(Game.settings.get(id, DEFAULTS.get(id, "")))


static func value_name(id: String) -> String:
	for o in OPTIONS:
		if o.id == id:
			return o.names.get(value(id), value(id))
	return value(id)


## Следующее значение настройки; «Качество» заодно выставляет остальные
static func cycle(id: String) -> void:
	for o in OPTIONS:
		if o.id != id:
			continue
		var vals: Array = o.values
		var i := vals.find(value(id))
		var nv: String = vals[(i + 1) % vals.size()]
		Game.settings[id] = nv
		if id == "gfx_preset":
			for k in PRESETS[nv]:
				Game.settings[k] = PRESETS[nv][k]
	Game.save_settings()


static func apply(tree: SceneTree) -> void:
	var vp := tree.root.get_viewport()
	# сглаживание
	match value("gfx_aa"):
		"off":
			vp.msaa_3d = Viewport.MSAA_DISABLED
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
		"fxaa":
			vp.msaa_3d = Viewport.MSAA_DISABLED
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
		"msaa2":
			vp.msaa_3d = Viewport.MSAA_2X
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
		"msaa4":
			vp.msaa_3d = Viewport.MSAA_4X
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	# масштаб 3D-картинки (интерфейс остаётся чётким)
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	vp.scaling_3d_scale = float(value("gfx_scale"))
	# тени
	var sh := value("gfx_shadows")
	RenderingServer.directional_shadow_atlas_set_size(2048 if sh == "low" else 4096, true)
	RenderingServer.directional_soft_shadow_filter_set_quality(
		RenderingServer.SHADOW_QUALITY_HARD if sh == "low" else RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM)
	for sun in tree.get_nodes_in_group("sun_light"):
		(sun as DirectionalLight3D).shadow_enabled = sh != "off"
	# тени от ламп и костров (кубические карты — самые дорогие): только при «мягких»
	vp.positional_shadow_atlas_size = 4096 if sh == "high" else 2048
	var loc := tree.get_first_node_in_group("location")
	if loc:
		var s := loc.get_node_or_null("Env/Sun") as DirectionalLight3D
		if s:
			s.shadow_enabled = sh != "off"
		for l in loc.find_children("*", "OmniLight3D", true, false):
			var ol := l as OmniLight3D
			if not ol.has_meta("shadow0"):
				ol.set_meta("shadow0", ol.shadow_enabled)
			ol.shadow_enabled = bool(ol.get_meta("shadow0")) and sh == "high"
		var we := loc.get_node_or_null("Env/WorldEnvironment") as WorldEnvironment
		if we and we.environment:
			we.environment.glow_enabled = value("gfx_glow") == "on"
	# окно и синхронизация (в тестах без экрана пропускаем)
	if DisplayServer.get_name() != "headless":
		var fs := value("gfx_window") == "fullscreen"
		var cur := DisplayServer.window_get_mode()
		if fs and cur != DisplayServer.WINDOW_MODE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		elif not fs and cur == DisplayServer.WINDOW_MODE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if value("gfx_vsync") == "on" else DisplayServer.VSYNC_DISABLED)
