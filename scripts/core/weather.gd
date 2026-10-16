extends Node
## Погода (автозагрузка Weather): ясно, пасмурно, дождь, ливень, гроза, буря,
## радиационная буря, пепельная буря. Меняется сама каждые несколько часов
## (и во время ожидания), хранится в сохранении (Game.world["_weather"]).
## На улице: осадки и пыль вокруг героя, туман, тусклое солнце, молнии, звук.
## В игре: в непогоду враги видят хуже (легче красться), на карте мира идти дольше,
## в бурю жители прячутся по домам, радиационная буря жжёт без укрытия.

const KINDS := {
	"clear": {"name": "ясно", "fog": 0.0, "dim": 1.0, "vis": 1.0, "travel": 1.0, "w": 30},
	"overcast": {"name": "пасмурно", "fog": 0.002, "dim": 0.75, "vis": 1.0, "travel": 1.0, "w": 22},
	"rain": {"name": "дождь", "fog": 0.004, "dim": 0.6, "vis": 0.85, "travel": 1.15, "w": 16, "rain": 0.5},
	"downpour": {"name": "ливень", "fog": 0.008, "dim": 0.45, "vis": 0.65, "travel": 1.35, "w": 8, "rain": 1.0},
	"thunder": {"name": "гроза", "fog": 0.007, "dim": 0.4, "vis": 0.7, "travel": 1.3, "w": 7, "rain": 0.9, "lightning": true},
	"storm": {"name": "буря", "fog": 0.012, "dim": 0.5, "vis": 0.6, "travel": 1.5, "w": 6, "dust": Color(0.55, 0.45, 0.32), "shelter": true},
	"rad_storm": {"name": "радиационная буря", "fog": 0.011, "dim": 0.45, "vis": 0.55, "travel": 1.5, "w": 3,
		"dust": Color(0.36, 0.46, 0.24), "tint": Color(0.62, 0.8, 0.45), "shelter": true, "rad": true},
	"ash_storm": {"name": "пепельная буря", "fog": 0.018, "dim": 0.35, "vis": 0.45, "travel": 1.6, "w": 3,
		"ash": true, "dust": Color(0.42, 0.4, 0.38), "tint": Color(0.6, 0.58, 0.55), "shelter": true},
}

signal changed(kind: String)

var main: Node
var _fx: Node3D
var _rain: GPUParticles3D
var _dust: GPUParticles3D
var _snd_rain: AudioStreamPlayer
var _snd_wind: AudioStreamPlayer
var _flash_t := 0.0
var _flash := 0.0
var _rad_t := 0.0
## Для автотестов и снимков: погода не меняется сама
var frozen := false


func _st() -> Dictionary:
	if not Game.world.has("_weather"):
		Game.world["_weather"] = {"kind": "clear", "until": 6.0}
	return Game.world["_weather"]


func kind() -> String:
	return str(_st().kind)


func info() -> Dictionary:
	return KINDS.get(kind(), KINDS.clear)


func title() -> String:
	return str(info().name)


## Множитель дальности, на которой враги замечают героя
func vis_mult() -> float:
	return float(info().vis) if outdoor() else 1.0


## Множитель времени пути на карте мира
func travel_mult() -> float:
	return float(info().travel)


## Жители прячутся по домам
func shelter() -> bool:
	return info().get("shelter", false) and outdoor()


func set_kind(k: String, hours := 6.0) -> void:
	var st := _st()
	var was := str(st.kind)
	st.kind = k
	st["until"] = Clock.hours() + hours
	if was != k:
		changed.emit(k)
		_announce(was, k)
	refresh()


## Сменить погоду, если подошло время. Соседние состояния вероятнее:
## из ясной — в пасмурную, из дождя — в ливень или грозу, бури бывают редко и коротко.
func tick() -> void:
	if frozen:
		return
	var st := _st()
	if Clock.hours() < float(st.get("until", 0.0)):
		return
	var cur := kind()
	var w := {}
	for k in KINDS:
		w[k] = float(KINDS[k].w)
	match cur:
		"clear":
			w.overcast *= 2.0
			w.downpour *= 0.3
			w.thunder *= 0.4
		"overcast":
			w.rain *= 2.0
			w.clear *= 1.5
		"rain":
			w.downpour *= 2.0
			w.thunder *= 2.0
			w.overcast *= 1.5
		"downpour", "thunder":
			w.rain *= 2.5
			w.overcast *= 1.5
		_:
			w.overcast *= 2.5
			w.clear *= 1.5
	w[cur] = w[cur] * 0.5
	var total := 0.0
	for k in w:
		total += w[k]
	var r := randf() * total
	var nxt := "clear"
	for k in w:
		r -= w[k]
		if r <= 0.0:
			nxt = k
			break
	var dur := randf_range(3.0, 8.0)
	if KINDS[nxt].get("shelter", false):
		dur = randf_range(1.5, 3.5)
	set_kind(nxt, dur)


func _announce(was: String, k: String) -> void:
	if main == null or main.location == null or not outdoor():
		return
	var lines := {
		"clear": "Тучи разошлись. Проясняется.",
		"overcast": "Небо затянуло серым.",
		"rain": "Закрапал дождь.",
		"downpour": "Хлынул ливень — стеной.",
		"thunder": "Где-то за лесом громыхнуло. Гроза идёт.",
		"storm": "Поднялся ветер — несёт пыль и сор. Буря.",
		"rad_storm": "Небо позеленело, воздух горчит. Радиационная буря — надо в укрытие.",
		"ash_storm": "С неба посыпался серый пепел. Пепельная буря.",
	}
	if lines.has(k):
		main.think(lines[k])
	if k == "rad_storm" and Game.item_count("dosimeter") > 0:
		main.sfx("geiger", -6.0)
		Game.log_line("Дозиметр затрещал.", "", "miss")


# ---------------- где идёт погода ----------------
## Под открытым небом: есть солнце и место большое (не дом, не подвал)
func outdoor() -> bool:
	if main == null or main.location == null:
		return false
	var loc: Node = main.location
	# в Нахарро пролог со своим туманом и пожаром — без погоды
	if str(loc.location_id).begins_with("nakharro"):
		return false
	if loc.get_node_or_null("Env/Sun") == null:
		return false
	return (loc.map_rect as Rect2).get_area() >= 1500.0


# ---------------- вид ----------------
func setup(m: Node) -> void:
	main = m
	_snd_rain = _player("rain_loop")
	_snd_wind = _player("wind_loop")


func _player(n: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = "Ambient"
	var path := "res://assets/sounds/%s.wav" % n
	if ResourceLoader.exists(path):
		p.stream = load(path)
	p.volume_db = -80.0
	p.finished.connect(func(): if p.volume_db > -60.0: p.play())
	add_child(p)
	return p


## Новая локация: частицы заново (старые ушли вместе со сценой)
func attach(loc: Node) -> void:
	_fx = null
	_rain = null
	_dust = null
	if loc == null:
		return
	_fx = Node3D.new()
	_fx.name = "WeatherFX"
	loc.add_child(_fx)
	_rain = _make_rain()
	_fx.add_child(_rain)
	_dust = _make_dust()
	_fx.add_child(_dust)
	var amb := AmbientFX.new()
	amb.visible = Graphics.value("gfx_particles") == "on"
	_fx.add_child(amb)
	refresh()


func _make_rain() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 2600
	p.lifetime = 0.9
	p.visibility_aabb = AABB(Vector3(-30, -5, -30), Vector3(60, 30, 60))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(24, 1, 24)
	pm.direction = Vector3(0.15, -1, 0.05)
	pm.spread = 3.0
	pm.initial_velocity_min = 22.0
	pm.initial_velocity_max = 26.0
	pm.gravity = Vector3(0, -9.8, 0)
	p.process_material = pm
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.03, 0.7)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	mat.albedo_color = Color(0.75, 0.82, 0.9, 0.45)
	mesh.material = mat
	p.draw_pass_1 = mesh
	p.position = Vector3(0, 16, 0)
	p.emitting = false
	return p


func _make_dust() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 1600
	p.lifetime = 3.5
	p.visibility_aabb = AABB(Vector3(-30, -5, -30), Vector3(60, 30, 60))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(26, 5, 26)
	pm.direction = Vector3(1, -0.15, 0.3)
	pm.spread = 25.0
	pm.initial_velocity_min = 5.0
	pm.initial_velocity_max = 9.0
	pm.gravity = Vector3(0, -0.6, 0)
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 2.0
	pm.scale_min = 0.6
	pm.scale_max = 1.6
	p.process_material = pm
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.12, 0.12)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.albedo_color = Color(0.5, 0.45, 0.35, 0.55)
	mesh.material = mat
	p.draw_pass_1 = mesh
	p.position = Vector3(0, 4, 0)
	p.emitting = false
	return p


## Включить нужные частицы и звук под текущую погоду
func refresh() -> void:
	var inf := info()
	var out := outdoor()
	var r := float(inf.get("rain", 0.0))
	if is_instance_valid(_rain):
		_rain.emitting = out and r > 0.0
		_rain.amount_ratio = clampf(r, 0.1, 1.0)
	if is_instance_valid(_dust):
		var dusty: bool = inf.has("dust")
		_dust.emitting = out and dusty
		if dusty:
			var m := (_dust.draw_pass_1 as QuadMesh).material as StandardMaterial3D
			var c: Color = inf.dust
			m.albedo_color = Color(c.r, c.g, c.b, 0.6)
			var pm := _dust.process_material as ParticleProcessMaterial
			if inf.get("ash", false):
				pm.direction = Vector3(0.2, -1, 0.1)
				pm.initial_velocity_min = 1.0
				pm.initial_velocity_max = 2.5
			else:
				pm.direction = Vector3(1, -0.15, 0.3)
				pm.initial_velocity_min = 5.0
				pm.initial_velocity_max = 9.0
	_snd_rain.volume_db = (-14.0 + 8.0 * r) if out and r > 0.0 else -80.0
	_snd_wind.volume_db = -10.0 if out and inf.has("dust") else (-22.0 if out and kind() in ["downpour", "thunder"] else -80.0)
	for p in [_snd_rain, _snd_wind]:
		if p.stream and p.volume_db > -60.0 and not p.playing:
			p.play()
		elif p.volume_db <= -60.0 and p.playing:
			p.stop()


## Свет и туман поверх времени суток (вызывает Clock.apply_light)
func apply(loc: Node) -> void:
	var inf := info()
	if not outdoor():
		return
	var sun := loc.get_node_or_null("Env/Sun") as DirectionalLight3D
	var we := loc.get_node_or_null("Env/WorldEnvironment") as WorldEnvironment
	if sun:
		sun.light_energy *= float(inf.dim) + _flash * 3.0
		if inf.has("tint"):
			sun.light_color = sun.light_color.lerp(inf.tint, 0.4)
	if we and we.environment:
		var e := we.environment
		if not we.has_meta("fog_base"):
			we.set_meta("fog_base", e.fog_density)
			we.set_meta("fog_on", e.fog_enabled)
		var f := float(inf.fog)
		e.fog_enabled = bool(we.get_meta("fog_on")) or f > 0.0
		e.fog_density = float(we.get_meta("fog_base")) + f
		if inf.has("dust"):
			e.fog_light_color = e.fog_light_color.lerp(inf.dust, 0.55)
		elif f > 0.0:
			e.fog_light_color = e.fog_light_color.lerp(Color(0.45, 0.48, 0.52), 0.5)
		e.ambient_light_energy *= lerpf(1.0, float(inf.dim), 0.5) + _flash * 2.0


# ---------------- кадр ----------------
func _process(delta: float) -> void:
	if main == null or main.location == null or main.player == null:
		return
	if is_instance_valid(_fx):
		_fx.global_position = main.player.global_position
	# молнии в грозу: вспышка, через миг — гром
	if info().get("lightning", false) and outdoor():
		_flash_t -= delta
		if _flash_t <= 0.0:
			_flash_t = randf_range(6.0, 16.0)
			_flash = 1.0
			var d := randf_range(0.3, 2.0)
			get_tree().create_timer(d, false).timeout.connect(func(): main.sfx("thunder", -4.0 - d * 3.0, randf_range(0.85, 1.1), "Ambient"))
			Clock.apply_light(main.location)
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 6.0)
		Clock.apply_light(main.location)
	# радиационная буря жжёт под открытым небом


## Радиационная буря под открытым небом — доза идёт через Rad (для автотеста)
func rad_step(delta: float) -> void:
	Rad.tick(delta)
