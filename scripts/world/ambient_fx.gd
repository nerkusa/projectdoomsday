class_name AmbientFX
extends Node3D
## Атмосферные частицы вокруг героя (узел едет вместе с ним, его создаёт Weather.attach):
## пылинки в солнечном свете, падающие листья в тайге, светлячки ночью, пепел и тлеющие
## хлопья над войной (Мирный, Рубикон, ГРЭС-2). Только на улице; выключается в настройках.

## Локации, где идёт война: сверху сыплется пепел
const WAR := ["mirny", "rubikon", "yakutsk"]
## Города: без листьев и светлячков
const CITY := ["sungar", "nyurba", "mirny", "rubikon", "yakutsk", "ges", "gorny"]

var _motes: GPUParticles3D
var _leaves: GPUParticles3D
var _flies: GPUParticles3D
var _ash: GPUParticles3D
var _embers: GPUParticles3D
var _t := 0.0


func _ready() -> void:
	add_to_group("ambient_fx")
	_motes = _make(220, 7.0, Vector3(18, 4, 18), Vector3(0, 2.5, 0), Color(1.0, 0.92, 0.7, 0.6), 0.09, 0.25, Vector3(0, 0.05, 0), true)
	_leaves = _make(140, 9.0, Vector3(22, 2, 22), Vector3(0, 9, 0), Color(0.85, 0.6, 0.18, 1.0), 0.32, 0.6, Vector3(0.4, -0.9, 0.2), false)
	_flies = _make(90, 6.0, Vector3(16, 1.6, 16), Vector3(0, 1.4, 0), Color(0.8, 1.0, 0.35, 1.0), 0.14, 0.6, Vector3.ZERO, true)
	_ash = _make(700, 9.0, Vector3(24, 2, 24), Vector3(0, 10, 0), Color(0.42, 0.4, 0.38, 0.85), 0.13, 0.3, Vector3(0.2, -0.7, 0.1), false)
	_embers = _make(110, 6.0, Vector3(20, 4, 20), Vector3(0, 3, 0), Color(1.0, 0.45, 0.1, 1.0), 0.1, 0.9, Vector3(0.1, 0.25, 0.05), true)
	# листья разных оттенков и кувыркаются
	var lm := _leaves.process_material as ParticleProcessMaterial
	lm.angular_velocity_min = -180.0
	lm.angular_velocity_max = 180.0
	var lg := Gradient.new()
	lg.set_color(0, Color(0.9, 0.7, 0.2))
	lg.set_color(1, Color(0.6, 0.25, 0.1))
	var lt := GradientTexture1D.new()
	lt.gradient = lg
	lm.color_initial_ramp = lt
	var lmat := (_leaves.draw_pass_1 as QuadMesh).material as StandardMaterial3D
	lmat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	lmat.albedo_texture = _leaf()
	# светлячки мерцают
	var fg := Gradient.new()
	fg.offsets = PackedFloat32Array([0.0, 0.2, 0.5, 0.8, 1.0])
	fg.colors = PackedColorArray([Color(0.8, 1, 0.35, 0), Color(0.8, 1, 0.35, 1), Color(0.8, 1, 0.35, 0.2), Color(0.8, 1, 0.35, 1), Color(0.8, 1, 0.35, 0)])
	var ft := GradientTexture1D.new()
	ft.gradient = fg
	(_flies.process_material as ParticleProcessMaterial).color_ramp = ft
	for p in [_motes, _leaves, _flies, _ash, _embers]:
		add_child(p)
	refresh()


## Частицы: amount штук живут life сек в коробке ext над героем (смещение off)
func _make(amount: int, life: float, ext: Vector3, off: Vector3, col: Color, size: float, turb: float, vel: Vector3, glow: bool) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.preprocess = life
	p.visibility_aabb = AABB(Vector3(-30, -12, -30), Vector3(60, 30, 60))
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	m.emission_box_extents = ext
	m.direction = vel.normalized() if vel != Vector3.ZERO else Vector3.UP
	m.spread = 25.0
	m.initial_velocity_min = vel.length() * 0.6
	m.initial_velocity_max = vel.length() * 1.4
	m.gravity = Vector3(0, -0.15 if vel.y < 0.0 else 0.0, 0)
	m.turbulence_enabled = turb > 0.0
	m.turbulence_noise_strength = turb * 4.0
	m.turbulence_noise_scale = 3.0
	m.scale_min = 0.6
	m.scale_max = 1.4
	var g := Gradient.new()
	g.set_color(0, Color(col.r, col.g, col.b, 0.0))
	g.add_point(0.15, col)
	g.add_point(0.8, col)
	g.set_color(g.get_point_count() - 1, Color(col.r, col.g, col.b, 0.0))
	var gt := GradientTexture1D.new()
	gt.gradient = g
	m.color_ramp = gt
	p.process_material = m
	var q := QuadMesh.new()
	q.size = Vector2(size, size * (0.7 if not glow else 1.0))
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if glow:
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_texture = _dot(glow)
	q.material = mat
	p.draw_pass_1 = q
	p.position = off
	p.emitting = false
	return p


## Что сейчас должно сыпаться: по локации, времени суток и погоде
func refresh() -> void:
	var loc: Node = Weather.main.location if Weather.main else null
	var out: bool = Weather.outdoor() and loc != null
	var id := str(loc.location_id) if loc else ""
	var war := false
	for w in WAR:
		if id.begins_with(w):
			war = true
	var city := false
	for c in CITY:
		if id.begins_with(c):
			city = true
	var night: bool = Clock.is_night()
	var wet: bool = float(Weather.info().get("rain", 0.0)) > 0.0
	_ash.emitting = out and war
	_embers.emitting = out and war
	_motes.emitting = out and not war and not night and not wet
	_leaves.emitting = out and not city and not wet
	_flies.emitting = out and not city and night and not wet


func _process(delta: float) -> void:
	_t -= delta
	if _t <= 0.0:
		_t = 2.0
		refresh()


## Мягкая круглая точка: светящаяся (glow) — с ярким центром и размытым ореолом
static func _dot(glow: bool) -> ImageTexture:
	var n := 32
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var d := Vector2(x - n / 2.0 + 0.5, y - n / 2.0 + 0.5).length() / (n / 2.0)
			var a := clampf(1.0 - d, 0.0, 1.0)
			a = pow(a, 1.6) if glow else smoothstep(0.0, 0.5, a)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)


## Лист: вытянутый овал с прожилкой
static func _leaf() -> ImageTexture:
	var n := 32
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var u := (x - n / 2.0 + 0.5) / (n / 2.0)
			var v := (y - n / 2.0 + 0.5) / (n / 2.0)
			var d := sqrt(u * u * 3.2 + v * v)
			var a := smoothstep(1.0, 0.85, d)
			var c := 0.8 if absf(u) < 0.06 and absf(v) < 0.9 else 1.0
			img.set_pixel(x, y, Color(c, c, c, a))
	return ImageTexture.create_from_image(img)
