extends Act1Location
## Случайная встреча в пути. Местность каждый раз собирается заново — по тому месту
## на карте мира, где героя застали: поле, лес, болото или мёртвый лес
## (Game.hero.flags["enc_biome"], см. WorldMap.biome_at).
## Кто здесь — data/world.json → encounters[Game.hero.flags["enc"]]: enemies (враги)
## и npcs (мирные; третий элемент — {"pose": "down"} и т. п.; разговор — dialogs/enc_<шаблон>.json).
## Как началось — Game.hero.flags["enc_mode"]:
##   fight  — бой сразу: герой в центре, враги кольцом вокруг;
##   caught — засада: то же, но враги ходят первыми;
##   first  — герой заметил первым и бьёт первым;
##   sneak  — герой подкрался: сидит в кустах у края, враги у костра его не видят;
##   peace  — мирная встреча.
## Состояние поляны не хранится: каждая встреча — заново.

const SIZE := 46.0
const BIOME_NAMES := {"field": "поле", "forest": "тайга", "swamp": "болото", "dead": "мёртвый лес"}

var enc_id := ""
var enc: Dictionary = {}
var biome := "forest"
var mode := "fight"
var rng := RandomNumberGenerator.new()
## Что уже стоит на поляне: [центр Vector2, радиус] — чтобы не ставить друг в друга
var _taken: Array = []
var _center := Vector2(SIZE / 2.0, SIZE / 2.0)
var _props := {}


func _ready() -> void:
	location_id = "encounter"
	autosave_on_enter = false
	map_rect = Rect2(0, 0, SIZE, SIZE)
	camera_start = Vector3(_center.x, 0, _center.y)
	Game.world.erase("encounter")
	enc_id = str(Game.hero.flags.get("enc", "dogs"))
	enc = DB._load("res://data/world.json").get("encounters", {}).get(enc_id, {})
	biome = str(Game.hero.flags.get("enc_biome", "forest"))
	mode = str(Game.hero.flags.get("enc_mode", "peace" if enc.get("enemies", []).is_empty() else "fight"))
	title = "%s · %s" % [enc.get("desc", "Тайга"), BIOME_NAMES.get(biome, "тайга")]
	rng.randomize()
	_build()
	super._ready()


# ---------------- местность ----------------
func _p(n: String) -> PackedScene:
	if not _props.has(n):
		_props[n] = load("res://scenes/props/%s.tscn" % n)
	return _props[n]


func _put(n: String, p: Vector2, sc := 1.0, parent: Node = null) -> Node3D:
	var node: Node3D = _p(n).instantiate()
	(parent if parent else get_node("Terrain")).add_child(node)
	node.position = Vector3(p.x, 0, p.y)
	node.rotation.y = rng.randf() * TAU
	node.scale = Vector3.ONE * sc
	return node


func _free(p: Vector2, r: float) -> bool:
	for t in _taken:
		if p.distance_to(t[0]) < r + float(t[1]):
			return false
	return true


## Разбросать count штук в кольце от r0 до r1 вокруг центра (или по всей карте)
func _scatter_props(names: Array, count: int, r0: float, r1: float, rad: float, sc_min := 0.8, sc_max := 1.25) -> void:
	var n := 0
	var tries := 0
	while n < count and tries < count * 30:
		tries += 1
		var p := Vector2(rng.randf_range(1.5, SIZE - 1.5), rng.randf_range(1.5, SIZE - 1.5))
		var d := p.distance_to(_center)
		if d < r0 or d > r1 or not _free(p, rad):
			continue
		_put(names[rng.randi() % names.size()], p, rng.randf_range(sc_min, sc_max))
		_taken.append([p, rad])
		n += 1


func _xf(p: Vector2, s: float, y := 0.006) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s, s)), Vector3(p.x, y, p.y))


func _multi(mesh: String, xf: Array, shadow := false) -> void:
	var mmi := MultiMeshInstance3D.new()
	mmi.set_script(load("res://scripts/world/scatter.gd"))
	mmi.set("mesh", load("res://assets/models/props/" + mesh + ".res"))
	var t: Array[Transform3D] = []
	for x in xf:
		t.append(x)
	mmi.set("transforms", t)
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_node("Terrain").add_child(mmi)


func _build() -> void:
	var terrain := Node3D.new()
	terrain.name = "Terrain"
	add_child(terrain)
	var nz := FastNoiseLite.new()
	nz.seed = rng.randi()
	nz.frequency = 0.07
	var nf := FastNoiseLite.new()
	nf.seed = rng.randi()
	nf.frequency = 0.3
	# тропа через поляну — откуда-то куда-то, всегда через середину
	var a := rng.randf() * TAU
	var t0 := _center + Vector2(cos(a), sin(a)) * 30.0
	var t1 := _center - Vector2(cos(a), sin(a)) * 30.0
	_ground(nz, nf, t0, t1)
	_taken.append([_center, 3.5])
	_landmarks(t0, t1)
	match biome:
		"field":
			_scatter_props(["birch", "birch_b"], 10, 12, 40, 2.0)
			_scatter_props(["bush"], 22, 5, 40, 1.2, 0.9, 1.5)
			_scatter_props(["rock", "rock_small", "rock_big"], 10, 4, 40, 1.2)
			_scatter_props(["hay_bale", "log_fallen", "stump"], 6, 6, 40, 1.4)
		"forest":
			_scatter_props(["spruce", "spruce_b", "pine", "pine_b", "spruce", "birch"], 75, 11, 40, 1.8)
			_scatter_props(["bush"], 18, 4, 40, 1.2, 0.9, 1.4)
			_scatter_props(["rock", "rock_big", "log_fallen", "stump", "stump"], 18, 4, 40, 1.3)
		"swamp":
			_ponds(nz)
			_scatter_props(["birch_b", "dead_tree", "pine_b", "birch", "dead_tree"], 32, 8, 40, 1.6)
			_scatter_props(["bush"], 14, 4, 40, 1.2)
			_scatter_props(["log_fallen", "stump"], 8, 4, 40, 1.3)
		"dead":
			_scatter_props(["dead_tree"], 70, 8, 40, 1.4, 0.8, 1.4)
			_scatter_props(["stump", "stump", "log_fallen", "rock", "rock_big"], 30, 4, 40, 1.3)
	# трава и мелочь
	var tufts := []
	var nt: int = {"field": 1100, "forest": 350, "swamp": 300, "dead": 160}[biome]
	for i in nt:
		var p := Vector2(rng.randf_range(0, SIZE), rng.randf_range(0, SIZE))
		if _seg_d(p, t0, t1) > 1.4:
			tufts.append(_xf(p, rng.randf_range(0.7, 1.5) * (0.7 if biome == "dead" else 1.0)))
	_multi("scatter_tuft", tufts)
	var pud := []
	for i in (14 if biome == "swamp" else 5):
		var p := t0.lerp(t1, rng.randf_range(0.2, 0.8)) + Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1))
		pud.append(_xf(p, rng.randf_range(0.4, 0.9), 0.01))
	_multi("scatter_puddle", pud)
	_edge()
	# выходы — по всем четырём краям
	var items := get_node("Items")
	for e in [["NorthExit", Vector3(_center.x, 0, 0.8), Vector3(10, 2.2, 1.6)], ["SouthExit", Vector3(_center.x, 0, SIZE - 0.8), Vector3(10, 2.2, 1.6)],
			["WestExit", Vector3(0.8, 0, _center.y), Vector3(1.6, 2.2, 10)], ["EastExit", Vector3(SIZE - 0.8, 0, _center.y), Vector3(1.6, 2.2, 10)]]:
		var ex := Interactable.new()
		ex.name = e[0]
		ex.kind = "use"
		ex.label = "Уйти"
		ex.pick_size = e[2]
		ex.reach = 2
		ex.position = e[1]
		items.add_child(ex)
	_spawn_people()


# ---------------- следы старого мира ----------------
## Разбитая дорога, самолёт, техника, руины, ЛЭП — то, что осталось с войны.
## Ставятся до деревьев: лес обходит их, а не растёт сквозь.
func _landmarks(t0: Vector2, t1: Vector2) -> void:
	var road_ch: float = {"field": 0.55, "dead": 0.5, "forest": 0.25, "swamp": 0.15}[biome]
	if rng.randf() < road_ch:
		_asphalt(t0, t1)
	if rng.randf() < 0.35:
		_power_line()
	var n := 0
	if rng.randf() < 0.8:
		n = 1 if rng.randf() < 0.7 else 2
	var kinds := ["plane", "vehicle", "ruin", "vehicle", "ruin"]
	if biome == "swamp":
		kinds = ["plane", "vehicle", "ruin"]
	for i in n:
		var k: String = kinds[rng.randi() % kinds.size()]
		var r: float = {"plane": 6.5, "vehicle": 3.6, "ruin": 4.5}[k]
		for t in 40:
			var a := rng.randf() * TAU
			var p := _center + Vector2(cos(a), sin(a)) * rng.randf_range(9.0, 15.0)
			if p.x < r + 2 or p.y < r + 2 or p.x > SIZE - r - 2 or p.y > SIZE - r - 2 or not _free(p, r):
				continue
			_taken.append([p, r])
			match k:
				"plane":
					_plane(p, rng.randf() * TAU)
				"vehicle":
					_vehicle(p, rng.randf() * TAU)
				"ruin":
					_ruin_house(p, rng.randf() * TAU)
			_wreck_loot(p, k, i)
			break


func _m(n: String) -> Material:
	return load("res://assets/materials/%s.tres" % n)


var _cmats := {}


func _cm(hex: String, rough := 0.9, metal := 0.0) -> Material:
	if not _cmats.has(hex):
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(hex)
		m.roughness = rough
		m.metallic = metal
		_cmats[hex] = m
	return _cmats[hex]


func _bx(parent: Node3D, size: Vector3, pos: Vector3, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


func _cy(parent: Node3D, r_top: float, r_bot: float, h: float, pos: Vector3, mat: Material, rot := Vector3.ZERO, seg := 12) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = r_top
	c.bottom_radius = r_bot
	c.height = h
	c.radial_segments = seg
	c.rings = 1
	mi.mesh = c
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


func _col(parent: Node3D, size: Vector3, pos: Vector3, rot_y := 0.0) -> void:
	var sb := StaticBody3D.new()
	sb.collision_mask = 0
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size
	cs.shape = b
	sb.add_child(cs)
	sb.position = pos
	sb.rotation.y = rot_y
	parent.add_child(sb)


func _holder(p: Vector2, rot: float, nm: String) -> Node3D:
	var h := Node3D.new()
	h.name = nm
	h.position = Vector3(p.x, 0, p.y)
	h.rotation.y = rot
	get_node("Terrain").add_child(h)
	return h


## Разбитый асфальт по тропе: плиты с выбоинами, остатки разметки, покосившийся знак
func _asphalt(t0: Vector2, t1: Vector2) -> void:
	var road := Node3D.new()
	road.name = "OldRoad"
	get_node("Terrain").add_child(road)
	var dir := (t1 - t0).normalized()
	var ang := atan2(dir.x, dir.y)
	var asph := _cm("3b3a37", 0.97)
	var asph2 := _cm("4a4843", 0.97)
	var line := _cm("c9c3a8", 0.9)
	var len := t0.distance_to(t1)
	var step := 2.2
	var k := 0
	var d := 0.0
	while d < len:
		var c := t0 + dir * d
		d += step
		k += 1
		if rng.randf() < 0.22:
			continue  # выбоина — плита провалилась
		var w := rng.randf_range(3.6, 4.4)
		var tilt := Vector3(rng.randf_range(-0.03, 0.03), ang + rng.randf_range(-0.06, 0.06), rng.randf_range(-0.04, 0.04))
		var y := 0.03 + rng.randf_range(0.0, 0.05)
		_bx(road, Vector3(w, 0.08, step - rng.randf_range(0.05, 0.35)), Vector3(c.x, y, c.y), asph if k % 3 else asph2, tilt)
		if k % 2 == 0 and rng.randf() < 0.7:
			_bx(road, Vector3(0.14, 0.02, 1.0), Vector3(c.x, y + 0.05, c.y), line, tilt)
		# обломки асфальта по обочине
		if rng.randf() < 0.25:
			var side := Vector2(dir.y, -dir.x) * (w / 2.0 + rng.randf_range(0.3, 1.0)) * (1.0 if rng.randf() < 0.5 else -1.0)
			var q := c + side
			_bx(road, Vector3(rng.randf_range(0.5, 1.1), 0.12, rng.randf_range(0.4, 0.9)), Vector3(q.x, 0.06, q.y), asph,
				Vector3(rng.randf_range(-0.3, 0.3), rng.randf() * TAU, rng.randf_range(-0.3, 0.3)))
	# столбик и знак у дороги
	var sp := t0.lerp(t1, rng.randf_range(0.25, 0.4)) + Vector2(dir.y, -dir.x) * 3.0
	if _free(sp, 0.8) and sp.distance_to(_center) > 4.0:
		var sign := _holder(sp, ang + rng.randf_range(-0.3, 0.3), "RoadSign")
		_cy(sign, 0.04, 0.04, 2.2, Vector3(0, 1.1, 0), _m("metal_dark"), Vector3(0, 0, rng.randf_range(-0.25, 0.25)))
		_bx(sign, Vector3(0.9, 0.6, 0.04), Vector3(0, 2.0, 0), _cm("2d5a8a", 0.7), Vector3(0, 0, rng.randf_range(-0.2, 0.2)))
		_taken.append([sp, 0.8])


## Разбившийся Ан-2: фюзеляж переломлен, крыло отломано, хвост торчит вверх
func _plane(p: Vector2, rot: float) -> void:
	var h := _holder(p, rot, "Plane")
	var body := _cm("4f574c", 0.85, 0.0)
	var rust := _m("rust")
	var white := _m("paint_white")
	# передняя часть: кабина и мотор
	_cy(h, 0.85, 0.95, 4.2, Vector3(0, 0.9, 1.6), body, Vector3(PI / 2.0, 0, 0.08))
	_cy(h, 0.75, 0.85, 0.9, Vector3(0, 0.95, 4.1), _m("metal_dark"), Vector3(PI / 2.0, 0, 0))
	_bx(h, Vector3(0.12, 2.2, 0.18), Vector3(0, 1.0, 4.65), _m("metal_dark"), Vector3(0, 0, 0.6))
	_bx(h, Vector3(1.1, 0.5, 0.05), Vector3(0, 1.75, 3.1), _m("glass"), Vector3(-0.5, 0, 0))
	# хвостовая часть — отломилась и лежит под углом
	_cy(h, 0.5, 0.85, 4.6, Vector3(0.6, 0.7, -3.0), body, Vector3(PI / 2.0 - 0.12, 0.35, 0))
	_bx(h, Vector3(0.12, 1.6, 1.2), Vector3(1.4, 1.6, -5.0), white, Vector3(0, 0.35, 0.1))
	_bx(h, Vector3(2.8, 0.08, 0.8), Vector3(1.4, 0.75, -5.0), white, Vector3(0, 0.35, 0.2))
	# крылья: верхнее целое, нижнее отломано и лежит рядом
	_bx(h, Vector3(12.0, 0.14, 1.7), Vector3(0, 2.1, 2.2), body, Vector3(0, 0, -0.05))
	for x in [-3.0, 3.0]:
		_cy(h, 0.04, 0.04, 1.3, Vector3(x, 1.45, 2.2), _m("metal_dark"))
	_bx(h, Vector3(5.5, 0.12, 1.5), Vector3(-3.4, 0.35, 2.4), body, Vector3(0, 0, 0.0))
	_bx(h, Vector3(4.0, 0.12, 1.5), Vector3(5.6, 0.12, 0.6), rust, Vector3(0.1, 0.5, 0.15))
	# звезда/бортовой номер полосой
	_bx(h, Vector3(0.02, 0.35, 2.0), Vector3(0.93, 1.0, 1.0), _cm("8a2a22", 0.7))
	# гарь под мотором
	var ash := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(5, 7)
	ash.mesh = pm
	ash.material_override = _cm("201c18", 1.0)
	ash.position = Vector3(0, 0.015, 1.5)
	h.add_child(ash)
	_col(h, Vector3(2.0, 2.0, 5.0), Vector3(0, 1.0, 1.8))
	_col(h, Vector3(1.6, 1.6, 4.6), Vector3(0.6, 0.8, -3.0), 0.35)
	_col(h, Vector3(5.4, 0.6, 1.5), Vector3(-3.4, 0.3, 2.4))


## Брошенная техника: грузовик, автобус или БТР
func _vehicle(p: Vector2, rot: float) -> void:
	var h := _holder(p, rot, "Vehicle")
	var kind := rng.randi() % 3
	var tire := _m("tire")
	match kind:
		0:  # грузовик
			var paint := _cm(["5a6a4a", "6a3a2a", "3a4a5a"][rng.randi() % 3], 0.85)
			_bx(h, Vector3(2.3, 1.1, 1.9), Vector3(0, 1.05, 2.6), paint)
			_bx(h, Vector3(2.2, 0.9, 1.6), Vector3(0, 2.0, 2.5), paint)
			_bx(h, Vector3(2.0, 0.55, 0.05), Vector3(0, 2.05, 3.32), _m("glass"))
			_bx(h, Vector3(2.4, 0.25, 4.6), Vector3(0, 0.75, -0.9), _m("rust"))
			for sx in [-1.18, 1.18]:
				_bx(h, Vector3(0.08, 0.6, 4.6), Vector3(sx, 1.15, -0.9), _m("planks_old"))
			for wz in [2.6, -0.4, -2.2]:
				for sx in [-1.15, 1.15]:
					if rng.randf() < 0.85:
						_cy(h, 0.48, 0.48, 0.32, Vector3(sx, 0.48, wz), tire, Vector3(0, 0, PI / 2.0))
			h.rotation.z = rng.randf_range(-0.08, 0.08)
			_col(h, Vector3(2.5, 2.4, 6.8), Vector3(0, 1.2, 0.0))
		1:  # автобус ПАЗ — ржавая коробка с окнами
			var paint := _cm("7d6c34", 0.9)
			_bx(h, Vector3(2.4, 2.4, 7.2), Vector3(0, 1.55, 0), paint)
			_bx(h, Vector3(2.45, 0.35, 7.25), Vector3(0, 0.55, 0), _m("rust"))
			for z in range(-3, 4):
				for sx in [-1.21, 1.21]:
					_bx(h, Vector3(0.03, 0.75, 0.8), Vector3(sx, 2.0, z * 0.95), _m("glass") if rng.randf() < 0.4 else _cm("1c1a18"))
			for wz in [2.5, -2.5]:
				for sx in [-1.1, 1.1]:
					_cy(h, 0.5, 0.5, 0.3, Vector3(sx, 0.5, wz), tire, Vector3(0, 0, PI / 2.0))
			h.rotation.z = rng.randf_range(0.05, 0.15)
			_col(h, Vector3(2.5, 2.8, 7.4), Vector3(0, 1.4, 0))
		_:  # БТР — сгоревший, люки открыты
			var olive := _cm("4a5236", 0.8, 0.1)
			_bx(h, Vector3(2.8, 1.3, 7.0), Vector3(0, 1.25, 0), olive)
			_bx(h, Vector3(2.4, 0.7, 2.0), Vector3(0, 2.1, 2.6), olive, Vector3(-0.35, 0, 0))
			_cy(h, 0.6, 0.65, 0.5, Vector3(0, 2.15, 0.3), olive)
			_cy(h, 0.07, 0.07, 2.2, Vector3(0, 2.2, 1.6), _m("metal_dark"), Vector3(PI / 2.0 - 0.15, 0, 0))
			for wz in [2.4, 0.8, -0.8, -2.4]:
				for sx in [-1.35, 1.35]:
					_cy(h, 0.55, 0.55, 0.4, Vector3(sx, 0.55, wz), tire, Vector3(0, 0, PI / 2.0))
			var burn := MeshInstance3D.new()
			var pm := PlaneMesh.new()
			pm.size = Vector2(4.5, 8.5)
			burn.mesh = pm
			burn.material_override = _cm("201c18", 1.0)
			burn.position = Vector3(0, 0.015, 0)
			h.add_child(burn)
			_col(h, Vector3(2.9, 2.4, 7.2), Vector3(0, 1.2, 0))


## Руины: кирпичная коробка дома без крыши, стены обломаны на разной высоте
func _ruin_house(p: Vector2, rot: float) -> void:
	var h := _holder(p, rot, "Ruin")
	var brick := _m("stone_wall")
	var w := rng.randf_range(5.0, 7.0)
	var d := rng.randf_range(4.0, 5.5)
	var segs := 6
	for side in 4:
		var horiz := side < 2
		var ln := w if horiz else d
		for k in segs:
			var t := (k + 0.5) / segs - 0.5
			if side == 0 and k == segs / 2:
				continue  # дверной проём
			if rng.randf() < 0.18:
				continue  # обрушено
			var hh := rng.randf_range(0.6, 3.0)
			var seg_l := ln / segs + 0.05
			var pos := Vector3(t * w, hh / 2.0, (d / 2.0) * (1 if side == 0 else -1)) if horiz else Vector3((w / 2.0) * (1 if side == 2 else -1), hh / 2.0, t * d)
			var sz := Vector3(seg_l, hh, 0.35) if horiz else Vector3(0.35, hh, seg_l)
			_bx(h, sz, pos, brick)
			_col(h, sz, pos)
	# мусор внутри и рядом
	for i in rng.randi_range(3, 6):
		var q := Vector2(rng.randf_range(-w / 2.0, w / 2.0), rng.randf_range(-d / 2.0, d / 2.0))
		_bx(h, Vector3(rng.randf_range(0.3, 0.8), rng.randf_range(0.15, 0.4), rng.randf_range(0.3, 0.7)), Vector3(q.x, 0.15, q.y), brick,
			Vector3(rng.randf_range(-0.4, 0.4), rng.randf() * TAU, rng.randf_range(-0.4, 0.4)))
	if rng.randf() < 0.5:
		var bed := _bx(h, Vector3(0.9, 0.08, 1.9), Vector3(w / 2.0 - 1.0, 0.35, 0), _m("rust"), Vector3(0, 0.2, 0.15))
		bed.name = "BedFrame"


## ЛЭП: деревянные опоры через поляну, провода, одна опора упала
func _power_line() -> void:
	var a := rng.randf() * TAU
	var dir := Vector2(cos(a), sin(a))
	var off := Vector2(dir.y, -dir.x) * rng.randf_range(6.0, 14.0) * (1.0 if rng.randf() < 0.5 else -1.0)
	var base := _center + off
	var poles := []
	for k in range(-3, 4):
		var q := base + dir * (k * 9.0)
		if q.x < -10 or q.y < -10 or q.x > SIZE + 10 or q.y > SIZE + 10:
			continue
		poles.append(q)
	var fallen := rng.randi() % maxi(1, poles.size())
	var wood := _m("log_dark")
	var wire := _cm("1a1a1a", 0.6, 0.4)
	var tops := []
	for i in poles.size():
		var q: Vector2 = poles[i]
		var h := _holder(q, atan2(dir.x, dir.y), "Pole")
		if i == fallen:
			_cy(h, 0.12, 0.16, 7.0, Vector3(0, 0.25, 3.0), wood, Vector3(PI / 2.0 - 0.05, 0, 0))
			_bx(h, Vector3(2.0, 0.12, 0.12), Vector3(0, 0.3, 6.2), wood)
			_col(h, Vector3(0.5, 0.6, 6.6), Vector3(0, 0.3, 3.0))
			tops.append(null)
		else:
			var lean := rng.randf_range(-0.08, 0.08)
			_cy(h, 0.11, 0.15, 7.0, Vector3(0, 3.5, 0), wood, Vector3(lean, 0, 0))
			_bx(h, Vector3(2.0, 0.12, 0.12), Vector3(0, 6.6, 0), wood)
			_col(h, Vector3(0.4, 3.0, 0.4), Vector3(0, 1.5, 0))
			tops.append(Vector3(q.x, 6.7, q.y))
		_taken.append([q, 0.7])
	# провода между стоящими опорами
	for i in poles.size() - 1:
		if tops[i] == null or tops[i + 1] == null:
			continue
		for side in [-0.9, 0.9]:
			var sv: Vector3 = Vector3(dir.y, 0, -dir.x) * float(side)
			var p0: Vector3 = tops[i] + sv
			var p1: Vector3 = tops[i + 1] + sv
			var mid := (p0 + p1) / 2.0 - Vector3(0, 0.8, 0)
			for seg in [[p0, mid], [mid, p1]]:
				var s0: Vector3 = seg[0]
				var s1: Vector3 = seg[1]
				var mi := MeshInstance3D.new()
				var bm := BoxMesh.new()
				bm.size = Vector3(0.025, 0.025, s0.distance_to(s1))
				mi.mesh = bm
				mi.material_override = wire
				get_node("Terrain").add_child(mi)
				mi.look_at_from_position((s0 + s1) / 2.0, s1, Vector3.UP)


## В обломках можно порыться: что-то да найдётся
func _wreck_loot(p: Vector2, kind: String, i: int) -> void:
	var it := Interactable.new()
	it.name = "Wreck%d" % i
	it.kind = "use"
	it.label = {"plane": "Обломки самолёта", "vehicle": "Брошенная машина", "ruin": "Руины"}[kind]
	it.pick_size = Vector3(3.0, 1.6, 3.0)
	it.reach = 2
	it.position = Vector3(p.x, 0, p.y)
	it.set_meta("kind", kind)
	get_node("Items").add_child(it)


func _seg_d(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return p.distance_to(a + ab * t)


## Земля: тот же шейдер, что в деревнях, карта смешивания рисуется на лету по типу местности
func _ground(nz: FastNoiseLite, nf: FastNoiseLite, t0: Vector2, t1: Vector2) -> void:
	var r := Rect2(-20, -20, SIZE + 40, SIZE + 40)
	var ppm := 1.5
	var w := int(r.size.x * ppm)
	var img := Image.create(w, w, false, Image.FORMAT_RGB8)
	for j in w:
		for i in w:
			var p := r.position + Vector2(i + 0.5, j + 0.5) / ppm
			var n := nz.get_noise_2dv(p)
			var f := nf.get_noise_2dv(p)
			var m := 0.0
			var u := 0.0
			match biome:
				"field":
					m = clampf(0.65 + n * 0.8 + f * 0.2, 0.0, 1.0)
				"forest":
					m = clampf(n * 0.6, 0.0, 0.5)
				"swamp":
					m = clampf(0.3 + n * 0.5, 0.0, 0.7)
					u = smoothstep(-0.05, 0.25, n + f * 0.25)
				"dead":
					m = clampf(0.75 + n * 0.5, 0.0, 1.0)
					u = smoothstep(0.25, 0.5, f) * 0.5
			var d := 1.0 - smoothstep(-0.4, 0.8, _seg_d(p, t0, t1) - 0.9 + f * 0.6)
			if biome == "dead":
				d = maxf(d, smoothstep(0.15, 0.45, n) * 0.6)
			img.set_pixel(i, j, Color(m, d, u))
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/shaders/ground_blend.gdshader")
	var t := "res://assets/textures/"
	for pair in [["grass", "grass_dark"], ["meadow", "meadow"], ["dirt", "dirt_road"], ["mud", "mud"]]:
		mat.set_shader_parameter(pair[0] + "_tex", load(t + pair[1] + ".png"))
		mat.set_shader_parameter(pair[0] + "_n", load(t + pair[1] + "_n.png"))
	mat.set_shader_parameter("splat", ImageTexture.create_from_image(img))
	mat.set_shader_parameter("splat_rect", Vector4(r.position.x, r.position.y, r.size.x, r.size.y))
	if biome == "dead":
		mat.set_shader_parameter("meadow_tint", Vector3(0.48, 0.44, 0.38))
	var gp := MeshInstance3D.new()
	gp.name = "Ground"
	var pm := PlaneMesh.new()
	pm.size = r.size
	gp.mesh = pm
	gp.material_override = mat
	gp.position = Vector3(r.get_center().x, 0, r.get_center().y)
	get_node("Terrain").add_child(gp)
	var far := MeshInstance3D.new()
	var fpm := PlaneMesh.new()
	fpm.size = Vector2(500, 500)
	far.mesh = fpm
	far.material_override = mat
	far.position = Vector3(_center.x, -0.03, _center.y)
	get_node("Terrain").add_child(far)


## Болото: окна воды (не пройти), камыш и кочки вокруг
func _ponds(nz: FastNoiseLite) -> void:
	var reeds := []
	var hum := []
	var body := StaticBody3D.new()
	body.name = "Ponds"
	body.collision_mask = 0
	get_node("Terrain").add_child(body)
	var made := 0
	for i in 60:
		if made >= rng.randi_range(4, 7):
			break
		var p := Vector2(rng.randf_range(4, SIZE - 4), rng.randf_range(4, SIZE - 4))
		var sz := Vector2(rng.randf_range(3, 7), rng.randf_range(2.5, 5))
		if p.distance_to(_center) < 8.0 + sz.length() * 0.5 or not _free(p, sz.length() * 0.5):
			continue
		made += 1
		_taken.append([p, sz.length() * 0.5])
		var w := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = sz + Vector2(2, 2)
		w.mesh = pm
		w.material_override = load("res://assets/materials/swamp_patch.tres")
		w.position = Vector3(p.x, 0.015, p.y)
		get_node("Terrain").add_child(w)
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(sz.x * 0.75, 1.2, sz.y * 0.75)
		cs.shape = bs
		cs.position = Vector3(p.x, 0.6, p.y)
		body.add_child(cs)
		for k in 30:
			var a := rng.randf() * TAU
			var q := p + Vector2(cos(a) * sz.x * 0.55, sin(a) * sz.y * 0.55) * rng.randf_range(0.8, 1.2)
			reeds.append(_xf(q, rng.randf_range(0.7, 1.2)))
		for k in 10:
			hum.append(_xf(p + Vector2(rng.randf_range(-sz.x, sz.x), rng.randf_range(-sz.y, sz.y)) * 0.7, rng.randf_range(0.7, 1.2)))
	for i in 120:
		hum.append(_xf(Vector2(rng.randf_range(2, SIZE - 2), rng.randf_range(2, SIZE - 2)), rng.randf_range(0.6, 1.1)))
	_multi("scatter_reeds", reeds, true)
	_multi("scatter_hummock", hum, true)


## Пояс деревьев за краем: туда не пройти, но пустоты не видно
func _edge() -> void:
	var names: Array = {"field": ["birch", "birch_b", "pine"], "forest": ["spruce", "spruce_b", "pine", "pine_b"],
		"swamp": ["birch_b", "dead_tree", "pine_b"], "dead": ["dead_tree", "dead_tree", "dead_tree", "pine_b"]}[biome]
	var edge := Node3D.new()
	edge.name = "ForestEdge"
	edge.set_meta("no_xray", true)
	add_child(edge)
	var count: int = {"field": 90, "forest": 320, "swamp": 160, "dead": 220}[biome]
	var placed := 0
	for i in count * 6:
		var p := Vector2(rng.randf_range(-24, SIZE + 24), rng.randf_range(-24, SIZE + 24))
		if Rect2(-0.5, -0.5, SIZE + 1, SIZE + 1).has_point(p):
			continue
		_put(names[rng.randi() % names.size()], p, rng.randf_range(0.9, 1.4), edge)
		placed += 1
		if placed >= count:
			break


# ---------------- люди ----------------
func _ring_point(r0: float, r1: float) -> Vector2:
	for i in 80:
		var a := rng.randf() * TAU
		var p := _center + Vector2(cos(a), sin(a)) * rng.randf_range(r0, r1)
		if p.x > 3 and p.y > 3 and p.x < SIZE - 3 and p.y < SIZE - 3 and _free(p, 0.9):
			_taken.append([p, 0.9])
			return p
	return _center + Vector2(r0, 0)


func _spawn_people() -> void:
	var chars := get_node("Characters")
	var hero_at := _center
	var foes_at := [5.5, 8.5]
	if mode == "sneak":
		# враги у костра в центре, герой — в кустах у края поляны
		foes_at = [1.6, 3.2]
		hero_at = _ring_point(13.5, 15.5)
		for k in 3:
			var b := _put("bush", hero_at + Vector2(rng.randf_range(-1.2, 1.2), rng.randf_range(-1.2, 1.2)), rng.randf_range(1.2, 1.5))
			b.set_meta("hide", true)
	var sp := get_node("Spawns/Start") as Node3D
	sp.position = Vector3(hero_at.x, 0, hero_at.y)
	var i := 0
	for pair in enc.get("enemies", []):
		for k in int(pair[1]):
			i += 1
			var p := _ring_point(foes_at[0], foes_at[1])
			# пока бой не начат сценой (засада / первый удар), сами не замечают —
			# иначе успевают «заметить» раньше и перехватывают ход
			var aggro := 12.0 if pair[0] == "chuchuna" else 9.0
			_char(chars, str(pair[0]), i, p, {"hostile": true, "aggro_radius": aggro if mode == "sneak" else 0.0, "squad": "enc"})
	i = 0
	for pair in enc.get("npcs", []):
		var extra: Dictionary = pair[2] if pair.size() > 2 else {}
		for k in int(pair[1]):
			i += 1
			var p := _ring_point(2.4, 4.5)
			var props := {"dialog": str(extra.get("dialog", "enc_" + str(pair[0]))), "armed": extra.get("armed", false)}
			if extra.has("pose"):
				props["start_pose"] = str(extra.pose)
			if extra.has("name"):
				props["display_name"] = str(extra.name)
			_char(chars, str(pair[0]), 10 + i, p, props)
	if enc.get("fire", false) or mode == "sneak":
		var fp := _center if mode == "sneak" else _center + Vector2(2.6, 0.4)
		var fire := _put("fire", fp, 0.8)
		fire.position.y = 0.2
		fire.set("strength", 0.7)


## Свойства (поза, разговор, враждебность) задаются до добавления в сцену —
## персонаж читает их в своём _ready
func _char(parent: Node, tpl_id: String, i: int, p: Vector2, props := {}) -> Character:
	var ch := Character.new()
	ch.name = "%s_%d" % [tpl_id, i]
	ch.char_id = tpl_id
	ch.position = Vector3(p.x, 0, p.y)
	ch.rotation.y = atan2(_center.x - p.x, _center.y - p.y)
	for k in props:
		ch.set(k, props[k])
	parent.add_child(ch)
	return ch


func foes() -> Array:
	var out := []
	for ch in characters():
		if ch.squad == "enc" and ch.pose != "dead":
			out.append(ch)
	return out


# ---------------- ход встречи ----------------
func on_enter() -> void:
	super.on_enter()
	var f := foes()
	if f.is_empty():
		return
	main.player.face_towards((f[0] as Character).global_position)
	match mode:
		"sneak":
			main.hidden = true
			Game.hero.sneak = true
			Game.hero_changed.emit()
			main.think("Сижу в кустах. Они меня не видят. Подобраться и ударить первым — или уйти краем поляны.")
		"first":
			main.think("Я их увидел первым.")
			main.start_fight([f[0]], {"ambush": true})
		"caught":
			main.think("Засада!")
			main.start_fight([f[0]], {"enemy_first": true})
		_:
			main.start_fight([f[0]])
	# дальше — как обычные враги: кто отстал от боя, заметит сам
	for ch in f:
		ch.aggro_radius = 12.0 if ch.char_id == "chuchuna" else 9.0


func leave_hide() -> void:
	main.hidden = false


const WRECK_LOOT := {
	"plane": [["ammo9", 4], ["medkit", 1], ["rope", 1], ["t_badge", 1], ["canned", 2], ["t_postcard", 1], ["bandage", 2]],
	"vehicle": [["screwdriver", 1], ["ammo762", 3], ["canned", 1], ["t_lighter", 1], ["matches", 1], ["rope", 1], ["t_coin", 2]],
	"ruin": [["t_photo", 1], ["t_cross", 1], ["herbs", 1], ["rusks", 1], ["t_coin", 1], ["bandage", 1], ["hairpin", 1]],
}


func on_interact(it: Interactable) -> bool:
	if String(it.name).begins_with("Wreck"):
		if ws().misc.has("searched_" + it.name):
			main.think("Больше ничего полезного.")
			return true
		ws().misc["searched_" + it.name] = true
		var kind := str(it.get_meta("kind", "ruin"))
		var table: Array = WRECK_LOOT.get(kind, [])
		var picks := []
		var used := {}
		for k in rng.randi_range(1, 3):
			var e: Array = table[rng.randi() % table.size()]
			if used.has(e[0]):
				continue
			used[e[0]] = true
			picks.append({"id": e[0], "n": int(e[1]), "name": DB.item_name(e[0])})
		var line: String = {"plane": "В кабине — истлевшие ремни, планшет пилота, сумка. Пятьдесят лет никто не заглядывал.",
			"vehicle": "Бардачок, ящик под сиденьем, кузов. Растащили почти всё — почти.",
			"ruin": "Под обломками кирпича — чья-то жизнь: посуда, тряпки, жестянка."}[kind]
		main.think(line)
		main.loot_win.open(it.label, picks, func(e):
			Game.add_item(e.id, int(e.get("n", 1)))
			return true)
		return true
	return super.on_interact(it)


func item_actions(it: Interactable) -> Array:
	if String(it.name).begins_with("Wreck"):
		return [["Обыскать", "use"]]
	return super.item_actions(it)


func describe(it: Interactable) -> String:
	if String(it.name).begins_with("Wreck"):
		match str(it.get_meta("kind", "")):
			"plane":
				return "Ан-2, «кукурузник». Упал давно — крыло отломано, хвост в стороне. На борту ещё читается красная полоса."
			"vehicle":
				return "Брошенная довоенная техника. Ржавчина, выбитые стёкла, спущенные колёса."
			"ruin":
				return "Кирпичная коробка дома. Крыши нет, стены обломаны, внутри — березняк."
	return ""


## Действия из разговоров на встрече
func on_dialog_action(a: String, sp: Character) -> bool:
	match a:
		"enc_hostile":
			# мирные стали врагами: все, кто пришёл вместе
			main.dialog.close()
			for ch in characters():
				if ch.squad == "" and ch.dialog != "" and ch.pose != "dead" and not ch.start_pose in ["down", "yield"]:
					ch.hostile = true
					ch.squad = "enc"
					ch.dialog = ""
			var f := foes()
			if not f.is_empty():
				main.start_fight([f[0]])
			return true
		"enc_npc_leave":
			# собеседник уходит с поляны
			if sp:
				_walk_off(sp)
			return true
		"enc_all_leave":
			for ch in characters():
				if ch.squad == "" and ch.pose != "dead":
					_walk_off(ch)
			return true
		"enc_execute":
			# приговор приведён в исполнение
			for ch in characters():
				if ch.char_id == "accused" and ch.pose != "dead":
					var j := _first_of("jaeger")
					if j:
						j.face_towards(ch.global_position)
						j.act("fire", Callable(), {"n": 1})
					ch.pose = "dead"
					ws().dead[ch.uid()] = true
			_jaegers_leave()
			return true
		"enc_kill_npc":
			# беззащитного — никто не видел, но сам герой помнит
			if sp:
				sp.pose = "dead"
				sp.dialog = ""
				ws().dead[sp.uid()] = true
				Game.change_rep(-6, "добил раненого", false)
				main.think("Никто не видел. Но я — видел.")
			return true
		"enc_free":
			for ch in characters():
				if ch.char_id == "accused":
					ch.pose = ""
					_walk_off(ch)
			_jaegers_leave()
			return true
	return super.on_dialog_action(a, sp)


func _jaegers_leave() -> void:
	await get_tree().create_timer(1.5, false).timeout
	for ch in characters():
		if ch.char_id == "jaeger" and ch.pose != "dead" and not ch.hostile:
			_walk_off(ch)


## Сканер у чистильщика: они ищут не деревни — браслет
func on_looted(ch: Character) -> void:
	if ch.char_id == "cleaner" and not Game.flag("scanner_seen"):
		Game.set_flag("scanner_seen")
		Game.add_note("У чистильщика — прибор с экраном: «Э-1 · сигнал браслета · пеленг». Они ищут браслет. Мой браслет.")
		main.say("thoughts", "scanner")


func _first_of(tpl: String) -> Character:
	for ch in characters():
		if ch.char_id == tpl and ch.pose != "dead":
			return ch
	return null


func _walk_off(ch: Character) -> void:
	var d := (Vector2(ch.global_position.x, ch.global_position.z) - _center).normalized()
	if d == Vector2.ZERO:
		d = Vector2(1, 0)
	var to := _center + d * (SIZE * 0.5 + 4.0)
	ch.dialog = ""
	ch.move_along([Vector3(to.x, 0, to.y)], func():
		ch.visible = false
		ws().misc["gone_" + ch.uid()] = true, 2.0)


func on_combat_end(res: String, _kind: String) -> void:
	if res == "win" and squad_cleared("enc"):
		main.think("Тихо. Можно обыскать и уходить.")
		Game.set_flag("enc_won_" + enc_id)
		main.hud.refresh_objective()


func objective() -> String:
	if not squad_cleared("enc"):
		if main.hidden:
			return "Подкрасться и ударить первым — или уйти краем поляны."
		return "Отбиться — или уйти краем поляны."
	return "Уйти краем поляны — дальше в путь."


func status_line() -> String:
	return "2062 · в пути"
