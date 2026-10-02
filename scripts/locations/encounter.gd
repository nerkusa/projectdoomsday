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
	return "2062 · в пути · " + main.world_map.time_text().to_lower()
