extends "res://tools/build_nakharro.gd"
## Генератор локаций первого акта: Кресты (живое поселение у реки) и
## Лагерь оборванцев (беженцы у старой лесопилки).
## Постройки — из tools/build_props.gd (как и в Нахарро).
## Сунгар (три района и дома с этажами) — в tools/build_sungar.gd, он же собирает и всё это.
## Запуск: godot --headless --path . res://tools/build_act1.tscn
## ВНИМАНИЕ: перезаписывает scenes/locations/kresty.tscn и camp.tscn.

## Для карты смешивания текущей локации
var _splat_rect := Rect2()
var _mud: Array = []
var _meadow: Array = []
var _clear: Array = []  # Rect2 полян: там не растёт лес
var _no_edge: Array = []  # Rect2, где нет и пояса леса за краем (река)


func _build() -> void:
	for n in ["cloth_sack", "cloth_red", "rope_mat", "rust", "metal_dark", "tin", "hay", "bark_dark", "planks_old",
			"stone_wall", "tire", "paper", "metal_roof", "glass", "paint_faded", "paint_white", "cloth", "rope_mat", "water", "log_dark", "log_weathered", "metal_dark", "ground_dirt"]:
		M[n] = load(MAT_DIR + n + ".tres")
	for n in ["concrete", "coal", "soot", "manure"]:
		M[n] = load(MAT_DIR + n + ".tres")
	for n in ["banya", "chapel", "smokehouse", "outhouse", "kennel", "coop", "well_crane", "serge", "manure", "fish_rack", "reeds",
			"samovar", "buckets", "boots", "axe_stump", "fishing_rods", "sledge", "toy_horse", "pot", "yoke", "firewood", "bundle",
			"boardwalk", "trash_pile", "burn_barrel"]:
		P[n] = load(PROP_DIR + n + ".tscn")
	_water_mats()
	_kresty()
	_camp()
	_encounter()
	_zaimka()
	_convoy()
	_ruin()
	_cellar()
	_upper()
	_radio_post()
	_bunker()


func _begin(id: String, title: String, rect: Rect2, script: String) -> void:
	seed(hash(id))
	root = Node3D.new()
	root.name = id.capitalize()
	root.set_script(load(script))
	root.set("location_id", id)
	root.set("title", title)
	root.set("map_rect", rect)
	root.set("camera_start", Vector3(rect.get_center().x, 0, rect.get_center().y))
	roads.clear()
	road_segs.clear()
	_mud.clear()
	_meadow.clear()
	_clear.clear()
	_no_edge.clear()
	_splat_rect = rect.grow(24.0)
	_env()


func _finish(id: String) -> void:
	var ps := PackedScene.new()
	var err := ps.pack(root)
	if err != OK:
		push_error("pack failed %d" % err)
	ResourceSaver.save(ps, "res://scenes/locations/%s.tscn" % id)
	root.free()
	print("Собрано: ", id)


# ---------------- вода ----------------
## Материал реки на каждую локацию: у шейдера своя линия берега
func _water_mats() -> void:
	for spec in [["kresty", 66.0], ["sungar", 58.0], ["sungar_center", 57.0]]:
		var m := ShaderMaterial.new()
		m.shader = load("res://assets/shaders/water.gdshader")
		m.set_shader_parameter("normal_a", load("res://assets/textures/water_n1.png"))
		m.set_shader_parameter("normal_b", load("res://assets/textures/water_n2.png"))
		m.set_shader_parameter("shore_z", spec[1])
		m.set_shader_parameter("shore_dir", 1.0)
		ResourceSaver.save(m, MAT_DIR + "water_%s.tres" % spec[0])


## Гладь реки: сетка с рябью и шейдером воды; z0 — берег, вода к +z
func _river_plane(parent: Node, id: String, x0: float, x1: float, z0: float, z1: float) -> void:
	var mi := MeshInstance3D.new()
	mi.name = "Water"
	var pm := PlaneMesh.new()
	pm.size = Vector2(x1 - x0, z1 - z0)
	pm.subdivide_width = int((x1 - x0) / 2.0)
	pm.subdivide_depth = int((z1 - z0) / 2.0)
	mi.mesh = pm
	mi.material_override = load(MAT_DIR + "water_%s.tres" % id)
	mi.position = Vector3((x0 + x1) / 2.0, 0.04, (z0 + z1) / 2.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.owner = root


## Метка постройки Slot_<s> в мировых координатах (группы-родители стоят в нуле)
func _slot_of(b: Node3D, s: String) -> Vector3:
	var m := b.get_node_or_null("Slot_" + s) as Node3D
	return b.transform * m.position if m else b.position


## Жилая изба: внутри — самовар, чугунок на печи, сапоги, узелок; у крыльца — хозяйство
func _homely(parent: Node, b: Node3D, outside: Array) -> void:
	var inside := {"table": ["samovar", "pot"], "stove": ["pot"], "floor": ["boots", "bundle", "toy_horse"], "chest": ["bundle"]}
	for sl in inside:
		if b.get_node_or_null("Slot_" + sl) == null:
			continue
		var opts: Array = inside[sl]
		var p := _slot_of(b, sl)
		put(P[opts[randi() % opts.size()]], parent, p, randf() * TAU)
	# у крыльца: door — середина дверного проёма в координатах дома
	var door: Vector3 = b.get("door") if b.get("door") != null else Vector3.ZERO
	var k := 0
	for o in outside:
		var side := -1.0 if k % 2 == 0 else 1.0
		var local := door + Vector3(side * (1.6 + 0.6 * int(k / 2)), 0, 1.0 + 0.3 * k)
		put(P[o], parent, b.transform * local, randf() * TAU)
		k += 1


# ---------------- земля ----------------
func _ground_for(id: String) -> void:
	var ground := group(root, "Ground")
	var tex := ImageTexture.create_from_image(_paint(id))
	var tpath := "res://assets/textures/%s_splat.res" % id
	ResourceSaver.save(tex, tpath)
	var m := ShaderMaterial.new()
	m.shader = load("res://assets/shaders/ground_blend.gdshader")
	var t := "res://assets/textures/"
	for pair in [["grass", "grass_dark"], ["meadow", "meadow"], ["dirt", "dirt_road"], ["mud", "mud"]]:
		m.set_shader_parameter(pair[0] + "_tex", load(t + pair[1] + ".png"))
		m.set_shader_parameter(pair[0] + "_n", load(t + pair[1] + "_n.png"))
	m.set_shader_parameter("splat", load(tpath))
	var r := _splat_rect
	m.set_shader_parameter("splat_rect", Vector4(r.position.x, r.position.y, r.size.x, r.size.y))
	ResourceSaver.save(m, MAT_DIR + "ground_%s.tres" % id)
	ground_mat = load(MAT_DIR + "ground_%s.tres" % id)
	var gp := MeshInstance3D.new()
	gp.name = "Ground"
	var pm := PlaneMesh.new()
	pm.size = r.size
	gp.mesh = pm
	gp.material_override = ground_mat
	gp.position = Vector3(r.get_center().x, 0, r.get_center().y)
	ground.add_child(gp)
	gp.owner = root
	var far := MeshInstance3D.new()
	far.name = "FarGround"
	var fpm := PlaneMesh.new()
	fpm.size = Vector2(600, 600)
	far.mesh = fpm
	far.material_override = ground_mat
	far.position = Vector3(r.get_center().x, -0.03, r.get_center().y)
	ground.add_child(far)
	far.owner = root


func _paint(id: String) -> Image:
	_nz.seed = hash(id) % 10000
	_nz.frequency = 0.06
	_nz.fractal_octaves = 3
	_nf.seed = 77 + hash(id) % 100
	_nf.frequency = 0.35
	_nf.fractal_octaves = 2
	var w := int(_splat_rect.size.x * SPLAT_PPM)
	var h := int(_splat_rect.size.y * SPLAT_PPM)
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	for j in h:
		for i in w:
			var p := _splat_rect.position + Vector2(i + 0.5, j + 0.5) / SPLAT_PPM
			var n := _nz.get_noise_2dv(p)
			var f := _nf.get_noise_2dv(p)
			var m := smoothstep(0.2, 0.5, n) * 0.7
			for mr in _meadow:
				m = maxf(m, smoothstep(-2.5, 3.0, _sd_rect(p, mr) + n * 4.0 + f * 1.2))
			var d := 0.0
			for sg in road_segs:
				var dist := _seg_dist(p, sg[0], sg[1]) - float(sg[2])
				d = maxf(d, 1.0 - smoothstep(-0.6, 0.8, dist + f * 0.7 + n * 0.3))
			var u := 0.0
			for z in _mud:
				u = maxf(u, smoothstep(-1.5, 2.0, _sd_rect(p, z) + n * 3.0) * smoothstep(-0.25, 0.3, f + n * 0.5))
			img.set_pixel(i, j, Color(m, d, u))
	return img


# ---------------- лес вокруг и дымка за краем ----------------
func _woods(count: int) -> void:
	var forest := group(root, "Forest")
	var trees := [P.spruce, P.spruce_b, P.spruce, P.spruce_b, P.pine, P.pine_b, P.birch, P.birch_b, P.dead_tree]
	var mr: Rect2 = root.get("map_rect")
	var n := 0
	for i in 9000:
		var p := Vector2(randf_range(mr.position.x + 1, mr.end.x - 1), randf_range(mr.position.y + 1, mr.end.y - 1))
		if _blocked(p, 1.8):
			continue
		put(trees[randi() % trees.size()], forest, Vector3(p.x, 0, p.y), randf() * TAU, "", randf_range(0.8, 1.3))
		n += 1
		if n >= count:
			break
	var edge := group(root, "ForestEdge")
	edge.set_meta("no_xray", true)
	var inner := mr.grow(0.5)
	var outer := mr.grow(28.0)
	var placed := 0
	for i in 5000:
		var p := Vector2(randf_range(outer.position.x, outer.end.x), randf_range(outer.position.y, outer.end.y))
		if inner.has_point(p) or _blocked(p, 1.5, true):
			continue
		var wet := false
		for r in _no_edge:
			if (r as Rect2).has_point(p):
				wet = true
		if wet:
			continue
		var d := -_sd_rect(p, inner)
		if randf() < clampf(d / 40.0, 0.0, 0.6):
			continue
		put(trees[randi() % 7], edge, Vector3(p.x, 0, p.y), randf() * TAU, "", randf_range(0.9, 1.4))
		placed += 1
		if placed >= 600:
			break


## Место занято: поляна, дорога (с запасом) — деревья туда не ставим
func _blocked(p: Vector2, margin: float, roads_only := false) -> bool:
	if not roads_only:
		for c in _clear:
			if (c as Rect2).has_point(p):
				return true
	for sg in road_segs:
		if _seg_dist(p, sg[0], sg[1]) < float(sg[2]) + margin:
			return true
	return false


func _free2(boxes: Array, x: float, z: float) -> bool:
	if _inside(boxes, Vector3(x, 0, z), 0.4):
		return false
	for sg in road_segs:
		if _seg_dist(Vector2(x, z), sg[0], sg[1]) < float(sg[2]) + 0.3:
			return false
	return true


func _boxes_of(grp_names: Array) -> Array:
	var boxes := []
	for grp in grp_names:
		var g := root.get_node_or_null(grp)
		if g == null:
			continue
		for b in g.get_children():
			var sp := String(b.scene_file_path)
			if _is_plant(sp):
				continue
			var bd := b.get_node_or_null("Collision")
			if bd:
				for cs in bd.get_children():
					if cs is CollisionShape3D and cs.shape is BoxShape3D:
						boxes.append([b.transform * bd.transform * cs.transform, (cs.shape as BoxShape3D).size])
			var inn = b.get("inner")
			if inn is Vector2 and inn != Vector2.ZERO:
				boxes.append([b.transform, Vector3(inn.x + 1.0, 3.0, inn.y + 1.0)])
			if sp.ends_with("/garden.tscn"):
				boxes.append([b.transform, Vector3(5, 1, 3)])
	return boxes


## Трава, мелочь в лесу; убирает деревья из построек
func _dress(zone: Rect2, tufts_n: int) -> void:
	var det := group(root, "Details")
	var boxes := _boxes_of(["Village"])
	for grp in ["Forest", "Village"]:
		var g := root.get_node_or_null(grp)
		if g == null:
			continue
		for t in g.get_children():
			if _is_plant(String(t.scene_file_path)) and _inside(boxes, t.position, 1.5):
				t.get_parent().remove_child(t)
				t.free()
	var tufts := []
	var guard := 0
	while tufts.size() < tufts_n and guard < 20000:
		guard += 1
		var x := randf_range(zone.position.x, zone.end.x)
		var z := randf_range(zone.position.y, zone.end.y)
		if _free2(boxes, x, z):
			tufts.append(_xf(x, z, randf_range(0.7, 1.4)))
	_multi(det, "scatter_tuft", tufts, "Tufts")
	var pud := []
	for i in 6:
		var sg: Array = road_segs[randi() % road_segs.size()]
		var a: Vector2 = sg[0].lerp(sg[1], randf())
		pud.append(_xf(a.x + randf_range(-1, 1), a.y + randf_range(-1, 1), randf_range(0.4, 0.8), 1.0))
	_multi(det, "scatter_puddle", pud, "Puddles")
	for i in 40:
		var p := Vector2(randf_range(zone.position.x - 10, zone.end.x + 10), randf_range(zone.position.y - 10, zone.end.y + 10))
		if zone.has_point(p) or _blocked(p, 1.0, true):
			continue
		put([P.stump, P.log_fallen, P.rock_small, P.rock][i % 4], det, Vector3(p.x, 0, p.y), randf() * TAU, "", randf_range(0.8, 1.2))


# ---------------- самодельные постройки ----------------
## Старый крест-голбец: столб, перекладины и двускатная крышечка сверху
func _cross(parent: Node, pos: Vector3, h: float, tilt := 0.0) -> void:
	var c := Node3D.new()
	c.name = "Cross"
	parent.add_child(c, true)
	c.owner = root
	c.position = pos
	c.rotation = Vector3(tilt, randf_range(-0.15, 0.15), tilt * 0.5)
	box(c, Vector3(0.16, h, 0.16), Vector3(0, h / 2.0, 0), "log_dark").owner = root
	box(c, Vector3(h * 0.5, 0.14, 0.14), Vector3(0, h * 0.66, 0), "log_dark").owner = root
	box(c, Vector3(h * 0.26, 0.1, 0.1), Vector3(0, h * 0.82, 0), "log_dark").owner = root
	box(c, Vector3(h * 0.3, 0.1, 0.1), Vector3(0, h * 0.3, 0), "log_dark", Vector3(0, 0, 0.35)).owner = root
	prism(c, Vector3(h * 0.36, 0.22, 0.34), Vector3(0, h + 0.06, 0), "roof_moss").owner = root
	var sb := collider(c, Vector3(0.3, h, 0.3), Vector3(0, h / 2.0, 0))
	_own(sb, root)


## Могильный холмик
func _mound(parent: Node, pos: Vector3, rot: float) -> void:
	var m := sphere(parent, 0.7, pos + Vector3(0, -0.12, 0.75), "dirt", Vector3(0.75, 0.32, 1.35))
	m.rotation.y = rot
	m.owner = root


## Сушилка для сетей: два столба, жердь и сеть
func _net_rack(parent: Node, pos: Vector3, rot: float) -> void:
	var r := Node3D.new()
	r.name = "NetRack"
	parent.add_child(r, true)
	r.owner = root
	r.position = pos
	r.rotation.y = rot
	for x in [-1.3, 1.3]:
		cyl(r, 0.06, 0.07, 1.9, Vector3(x, 0.95, 0), "log_dark").owner = root
	cyl(r, 0.04, 0.04, 2.8, Vector3(0, 1.8, 0), "log", Vector3(0, 0, PI / 2.0)).owner = root
	for i in 13:
		box(r, Vector3(0.018, 1.25, 0.018), Vector3(-1.2 + i * 0.2, 1.16, 0), "rope_mat").owner = root
	for j in 7:
		box(r, Vector3(2.42, 0.018, 0.018), Vector3(0, 0.56 + j * 0.2, 0), "rope_mat").owner = root
	for k in 4:
		cyl(r, 0.05, 0.05, 0.07, Vector3(-0.9 + k * 0.6, 0.55, 0), "bark_birch").owner = root
	_own(collider(r, Vector3(2.8, 1.8, 0.3), Vector3(0, 0.9, 0)), root)


## Палатка из брезента
func _tent(parent: Node, pos: Vector3, rot: float, mat := "cloth_sack", sz := 1.0) -> Node3D:
	var t := Node3D.new()
	t.name = "Tent"
	parent.add_child(t, true)
	t.owner = root
	t.position = pos
	t.rotation.y = rot
	t.scale = Vector3.ONE * sz
	prism(t, Vector3(2.4, 1.6, 3.0), Vector3(0, 0.8, 0), mat).owner = root
	cyl(t, 0.03, 0.03, 1.8, Vector3(0, 0.9, 1.52), "log").owner = root
	_own(collider(t, Vector3(2.2, 1.4, 2.8), Vector3(0, 0.7, 0)), root)
	return t


## Навес: жерди и скат из досок
func _lean_to(parent: Node, pos: Vector3, rot: float) -> void:
	var t := Node3D.new()
	t.name = "LeanTo"
	parent.add_child(t, true)
	t.owner = root
	t.position = pos
	t.rotation.y = rot
	for x in [-1.4, 1.4]:
		cyl(t, 0.05, 0.06, 1.9, Vector3(x, 0.95, 0.9), "log").owner = root
	box(t, Vector3(3.2, 0.06, 2.4), Vector3(0, 1.3, 0.1), "planks_old", Vector3(-0.55, 0, 0)).owner = root
	box(t, Vector3(2.6, 0.25, 1.6), Vector3(0, 0.12, -0.2), "cloth_sack").owner = root
	_own(collider(t, Vector3(3.0, 1.5, 1.2), Vector3(0, 0.75, -0.4)), root)


## Лодка кверху дном
func _boat(parent: Node, pos: Vector3, rot: float) -> void:
	var b := prism(parent, Vector3(1.1, 0.5, 3.6), pos + Vector3(0, 0.25, 0), "planks_old", Vector3(PI, rot, 0))
	b.name = "Boat"
	b.owner = root
	var sb := collider(parent, Vector3(1.1, 0.6, 3.6), pos + Vector3(0, 0.3, 0), rot)
	sb.name = "BoatCol"
	_own(sb, root)


func _exit(items: Node, nm: String, label: String, pos: Vector3, size: Vector3) -> void:
	var ex := _item_base(nm)
	ex.set("kind", "use")
	ex.set("label", label)
	ex.set("pick_size", size)
	ex.set("reach", 2)
	ex.position = pos
	items.add_child(ex)
	ex.owner = root


func _use(items: Node, nm: String, label: String, pos: Vector3, size := Vector3(1.2, 1.0, 1.2)) -> Node3D:
	var u := _item_base(nm)
	u.set("kind", "use")
	u.set("label", label)
	u.set("pick_size", size)
	u.position = pos
	items.add_child(u)
	u.owner = root
	return u


func _spawn(nm: String, pos: Vector3) -> void:
	var sp := root.get_node_or_null("Spawns")
	if sp == null:
		sp = group(root, "Spawns")
	var m := Marker3D.new()
	m.name = nm
	m.position = pos
	sp.add_child(m)
	m.owner = root


# ======================================================================
# КРЕСТЫ: улица с запада на восток, площадь, пивоварня, погост у въезда,
# река на юге с мостками и сушилками для сетей, выгон на северо-востоке.
# ======================================================================
func _kresty() -> void:
	var rect := Rect2(0, 0, 116, 80)
	_begin("kresty", "Кресты", rect, "res://scripts/locations/kresty.gd")
	var d := "ground_dirt"
	strip(null, Vector2(-4, 38), Vector2(120, 38), 3.0, d)
	strip(null, Vector2(100, 38), Vector2(100, 58), 1.8, d)
	strip(null, Vector2(47, 38), Vector2(47, 64), 2.2, d)
	strip(null, Vector2(47, 38), Vector2(47, 24), 2.0, d)
	strip(null, Vector2(64, 38), Vector2(72, 20), 1.6, d)
	road_segs.append([Vector2(41, 36), Vector2(53, 40), 3.5])  # площадь
	_meadow.append(Rect2(62, 6, 26, 14))  # выгон
	_meadow.append(Rect2(4, 28, 12, 7))  # погост
	_mud.append(Rect2(-10, 64.5, 140, 3.0))  # берег
	# грязь: у колодца, у пивоварни, у ворот выгона, на восточной улице, у бани
	for r in [Rect2(38.5, 38.5, 7, 6), Rect2(27, 39.5, 11, 4.5), Rect2(59, 19.5, 11, 5), Rect2(54, 35.6, 14, 4.6),
			Rect2(86, 35.5, 24, 5), Rect2(21, 55, 9, 5), Rect2(97, 40, 7, 6), Rect2(55, 55, 9, 6)]:
		_mud.append(r)
	_clear.append(Rect2(14, 20, 98, 46))
	_clear.append(Rect2(80, 22, 34, 34))
	_clear.append(Rect2(60, 4, 30, 18))
	_clear.append(Rect2(-2, 24, 20, 30))
	_clear.append(Rect2(-10, 60, 112, 30))
	_no_edge.append(Rect2(-40, 63, 180, 35))
	_no_edge.append(Rect2(-14, 28, 14, 20))  # у въезда с запада лес реже — не закрывает героя
	_ground_for("kresty")
	# река: гладь с рябью, невидимая стена по берегу, камыш
	var river := group(root, "River")
	river.set_meta("no_xray", true)
	_river_plane(river, "kresty", -40, 160, 66.0, 100.0)
	_own(collider(river, Vector3(200, 1.5, 12), Vector3(60, 0.75, 73.5)), root)
	for x in [6.0, 13.0, 19.5, 31.0, 35.5, 52.0, 61.5, 71.0, 78.0, 84.5, 92.0, 99.0, 106.5, 112.0]:
		put(P.reeds, river, Vector3(x + randf_range(-1, 1), 0, 66.2 + randf_range(-0.2, 0.6)), randf() * TAU, "", randf_range(0.8, 1.3))
	# мостки
	for i in 6:
		box(river, Vector3(1.4, 0.08, 0.5), Vector3(47, 0.12, 64.8 + i * 0.55), "planks_old").owner = root
	for x in [46.3, 47.7]:
		cyl(river, 0.06, 0.06, 0.8, Vector3(x, 0.0, 67.8), "log_dark").owner = root

	var vil := group(root, "Village")
	put(P.izba, vil, Vector3(20, 0, 31.5), 0.02, "Izba1")
	put(P.izba_small, vil, Vector3(31, 0, 31.5), -0.04, "Izba2")
	put(P.hall, vil, Vector3(47, 0, 25.5), 0.0, "HeadHouse")
	put(P.izba_long, vil, Vector3(60, 0, 31.5), 0.03, "Izba3")
	put(P.izba_tall, vil, Vector3(72, 0, 31.2), -0.02, "Izba4")
	put(P.izba_lean, vil, Vector3(84, 0, 31.5), 0.0, "Izba5")
	put(P.izba, vil, Vector3(22, 0, 44.5), PI, "Izba6")
	put(P.workshop, vil, Vector3(33, 0, 46.5), PI, "Brewery")
	put(P.izba_small, vil, Vector3(62, 0, 44.8), PI + 0.03, "Izba7")
	put(P.izba_long, vil, Vector3(75, 0, 44.5), PI, "Izba8")
	put(P.izba_small, vil, Vector3(58, 0, 57), PI / 2.0, "FisherHut")
	put(P.shed, vil, Vector3(38, 0, 57), 0.1)
	put(P.shed, vil, Vector3(87.5, 0, 44.5), -0.1)
	# восточный конец: новые избы, кузница, колодец-журавль
	put(P.izba, vil, Vector3(96, 0, 31.5), 0.03, "Izba9")
	put(P.izba_tall, vil, Vector3(107, 0, 31.2), -0.02, "Izba10")
	put(P.izba_long, vil, Vector3(96.5, 0, 44.6), PI - 0.02, "Izba11")
	put(P.workshop, vil, Vector3(108.5, 0, 45.2), PI, "Smithy")
	put(P.well_crane, vil, Vector3(103.0, 0, 40.6), 0.3, "WellCrane")
	put(P.woodpile, vil, Vector3(112.5, 0, 42.5), 1.5)
	# баня у реки, часовня у погоста, коптильня у рыбака
	put(P.banya, vil, Vector3(24.5, 0, 59.0), 0.0, "Banya")
	put(P.chapel, vil, Vector3(14.5, 0, 24.0), 0.0, "Chapel")
	put(P.smokehouse, vil, Vector3(63.0, 0, 58.8), 0.2, "Smokehouse")
	# сэргэ на площади и у дома старосты
	for sp in [Vector3(43.2, 0, 34.4), Vector3(44.6, 0, 34.0), Vector3(40.6, 0, 31.2)]:
		put(P.serge, vil, sp, randf() * TAU)
	# хозяйство: нужники за избами, будки, курятник, навоз, вешала с рыбой
	for op in [Vector3(16.5, 0, 27.0), Vector3(56.5, 0, 27.6), Vector3(89.0, 0, 27.6), Vector3(101.5, 0, 27.6)]:
		put(P.outhouse, vil, op, randf_range(-0.2, 0.2))
	for kp in [Vector3(63.8, 0, 35.0), Vector3(90.8, 0, 34.6), Vector3(18.0, 0, 41.2)]:
		put(P.kennel, vil, kp, randf() * TAU)
	put(P.coop, vil, Vector3(60.0, 0, 50.0), PI)
	for mp in [Vector3(61.5, 0, 24.6), Vector3(40.0, 0, 52.8), Vector3(110.5, 0, 50.5)]:
		put(P.manure, vil, mp, randf() * TAU)
	put(P.fish_rack, vil, Vector3(34.0, 0, 62.4), 0.05)
	put(P.fish_rack, vil, Vector3(73.0, 0, 62.6), -0.04)
	for bw in [[Vector3(41.6, 0, 41.4), 0.0], [Vector3(60.5, 0, 37.9), PI / 2.0], [Vector3(64.0, 0, 37.9), PI / 2.0], [Vector3(98.0, 0, 37.9), PI / 2.0]]:
		put(P.boardwalk, vil, bw[0], bw[1])
	# личные вещи в избах и у крыльца
	var outs := {"Izba1": ["axe_stump", "buckets"], "Izba2": ["yoke", "firewood"], "Izba3": ["sledge", "buckets"], "Izba4": ["firewood", "axe_stump"],
		"Izba5": ["buckets"], "Izba6": ["toy_horse", "yoke"], "Izba7": ["buckets", "firewood"], "Izba8": ["sledge", "toy_horse"],
		"FisherHut": ["fishing_rods", "buckets"], "Izba9": ["axe_stump", "yoke"], "Izba10": ["firewood", "sledge"], "Izba11": ["buckets", "firewood"]}
	for nm in outs:
		var b := vil.get_node_or_null(nm) as Node3D
		if b:
			_homely(vil, b, outs[nm])
	put(P.well, vil, Vector3(42, 0, 41.8), 0.0, "Well")
	put(P.table_long, vil, Vector3(52.5, 0, 43.2), 0.0, "SquareTable")
	put(P.table, vil, Vector3(50.8, 0, 35.4), 0.0, "TradeTable")
	for p in [Vector3(20, 0, 50.5), Vector3(66, 0, 50.5), Vector3(78, 0, 50.5), Vector3(28, 0, 26), Vector3(72, 0, 25.8)]:
		put(P.garden, vil, p, 0.0)
	put(P.greenhouse, vil, Vector3(86, 0, 52), 0.0)
	put(P.woodpile, vil, Vector3(14.5, 0, 45), 0.2)
	put(P.woodpile, vil, Vector3(66.5, 0, 26), -0.1)
	put(P.tractor, vil, Vector3(80, 0, 24.5), 2.4, "OldTractor")
	for f in [[Vector3(15.5, 0, 48.5), PI / 2.0], [Vector3(25.5, 0, 53.5), 0.0], [Vector3(61.5, 0, 53.5), 0.0], [Vector3(70.5, 0, 53.5), 0.0],
			[Vector3(82.5, 0, 53.5), 0.0]]:
		put(P.fence, vil, f[0], f[1])
	# выгон: изгородь из жердей
	for i in 6:
		put(P.fence_broken if i == 2 else P.fence, vil, Vector3(64 + i * 4.0, 0, 21.5), 0.0)
	for p in [Vector3(70, 0, 12), Vector3(78, 0, 9), Vector3(82, 0, 15)]:
		put(P.hay_bale, vil, p, randf() * TAU)
	# погост у въезда — отсюда и название
	var cem := group(vil, "Cemetery")
	var graves := [[Vector3(6, 0, 30), 2.0, 0.0], [Vector3(8.5, 0, 29.4), 1.7, 0.08], [Vector3(11, 0, 30.3), 1.9, -0.05],
			[Vector3(7, 0, 32.6), 1.5, 0.12], [Vector3(10, 0, 33), 1.8, 0.0], [Vector3(13, 0, 32.2), 1.6, -0.1], [Vector3(15, 0, 29.8), 1.4, 0.15]]
	for c in graves:
		_cross(cem, c[0] + Vector3(0, 0, -0.9), c[1], c[2])
		_mound(cem, c[0] + Vector3(0, 0, -0.9), 0.0)
	# низкая ограда погоста
	for x in [5.0, 9.0, 13.0]:
		put(P.fence_broken if x == 9.0 else P.fence, cem, Vector3(x, 0, 34.4), 0.0)
	# два высоких креста у въезда со стороны черты (с запада) — по ним и название
	_cross(vil, Vector3(9.5, 0, 35.4), 3.2)
	_cross(vil, Vector3(9.5, 0, 40.6), 3.2)
	# у реки
	_net_rack(vil, Vector3(53.5, 0, 63.0), 0.0)
	_net_rack(vil, Vector3(60, 0, 63.3), 0.08)
	_boat(vil, Vector3(40.5, 0, 63.5), 0.3)
	_boat(vil, Vector3(66, 0, 63.8), -0.2)
	for p in [Vector3(76, 0, 60), Vector3(84, 0, 62), Vector3(88, 0, 58), Vector3(104, 0, 60), Vector3(112, 0, 57)]:
		put(P.bush, vil, p, randf() * TAU)
	for p in [Vector3(40, 0, 50), Vector3(56, 0, 50), Vector3(36, 0, 22)]:
		put(P.birch, vil, p, randf() * TAU, "", 1.1)
	# двор пивовара: бочки
	var det0 := group(root, "Yard")
	for p in [Vector3(29.2, 0, 42.4), Vector3(30.1, 0, 42.1), Vector3(29.6, 0, 41.3), Vector3(36.8, 0, 42.5), Vector3(37.6, 0, 42.2)]:
		put(P.barrel, det0, p, randf() * TAU)
	for dd in [["crates", Vector3(53.2, 0, 34.6)], ["crates", Vector3(49.0, 0, 34.2)], ["cart", Vector3(55.5, 0, 35.2)],
			["bench", Vector3(44.5, 0, 45.0)], ["crates", Vector3(57.2, 0, 60.8)], ["barrel", Vector3(56.2, 0, 60.4)],
			["hay_bale", Vector3(77, 0, 36.2)], ["barrel", Vector3(18, 0, 36.4)], ["cart", Vector3(82, 0, 36.4)]]:
		put(P[dd[0]], det0, dd[1], randf() * TAU)
	_woods(900)

	var chars := group(root, "Characters")
	character(chars, "KrGuard", "kr_guard", Vector3(12.5, 0, 36.2), -PI / 2.0, {"dialog": "kr_guard", "armed": true})
	character(chars, "KrHead", "kr_head", Vector3(47, 0, 30.2), 0.0, {"dialog": "kr_head"})
	character(chars, "Brewer", "kr_brewer", Vector3(33, 0, 42.2), 0.0, {"dialog": "kr_brewer"})
	character(chars, "Trader", "kr_trader", Vector3(50.8, 0, 36.6), 0.0, {"dialog": "kr_trader"})
	character(chars, "Fisher", "kr_fisher", Vector3(50.5, 0, 62.2), -0.4, {"dialog": "kr_fisher"})
	character(chars, "KrOld", "kr_old", Vector3(38.6, 0, 62.4), 0.2, {"dialog": "kr_old"})
	var tbl: Node3D = root.get_node("Village/SquareTable")
	var s1 := _seat(tbl, -0.6, 1.0)
	var s2 := _seat(tbl, 0.5, -1.0)
	character(chars, "Drunk", "kr_drunk", s1[0], s1[1], {"dialog": "kr_drunk", "start_pose": "sit"})
	character(chars, "Granny", "kr_motryona", s2[0], s2[1], {"dialog": "kr_motryona", "start_pose": "sit"})
	character(chars, "KrVillager1", "villager", Vector3(24, 0, 38.8), 1.4, {"display_name": "Крестовский мужик", "dialog": "kr_rumors",
		"patrol": PackedVector3Array([Vector3(24, 0, 38.8), Vector3(80, 0, 38.8)]), "patrol_wait": 5.0})
	character(chars, "KrVillager2", "villager_f", Vector3(64, 0, 49.5), 0.0, {"display_name": "Хозяйка", "dialog": "kr_rumors",
		"patrol": PackedVector3Array([Vector3(64, 0, 49.5), Vector3(47, 0, 49.5), Vector3(47, 0, 58)]), "patrol_wait": 4.0})
	character(chars, "KrKid", "kid", Vector3(44, 0, 44), 0.5, {"display_name": "Мальчишка Уйгун", "dialog": "kr_kid",
		"patrol": PackedVector3Array([Vector3(44, 0, 44), Vector3(40, 0, 40), Vector3(45, 0, 38.5)]), "patrol_wait": 2.0})
	# новые жители: кузнец, банщица, пастух (если помог ему в дороге), бабы у колодца, детвора
	character(chars, "Smith", "kr_smith", Vector3(107.4, 0, 41.8), 0.3, {"dialog": "kr_smith"})
	character(chars, "BanyaWoman", "kr_banya", Vector3(26.6, 0, 61.4), -0.6, {"dialog": "kr_banya"})
	character(chars, "Herder", "kr_herder", Vector3(70, 0, 18.0), 0.5, {"dialog": "kr_herder",
		"patrol": PackedVector3Array([Vector3(70, 0, 18.0), Vector3(78, 0, 12.0), Vector3(84, 0, 17.0)]), "patrol_wait": 6.0})
	character(chars, "WellWoman", "kr_woman", Vector3(41.2, 0, 43.8), 2.6, {"dialog": "kr_rumors", "display_name": "Кулустаана с вёдрами",
		"patrol": PackedVector3Array([Vector3(41.2, 0, 43.8), Vector3(24, 0, 40.5)]), "patrol_wait": 8.0})
	character(chars, "Maaya", "kr_woman2", Vector3(101.6, 0, 42.8), -2.2, {"dialog": "kr_rumors", "display_name": "Тётка Маайа у журавля"})
	character(chars, "OldYldya", "kr_oldman", Vector3(57.0, 0, 60.6), 0.6, {"dialog": "kr_rumors", "display_name": "Дед Ылдьа", "start_pose": "sit"})
	character(chars, "Aanys", "kr_woman", Vector3(33.4, 0, 61.4), 0.0, {"dialog": "kr_rumors", "display_name": "Рыбачка Ааныс у вешал"})
	character(chars, "Girl", "kid", Vector3(84, 0, 40.5), 0.0, {"dialog": "kr_rumors", "display_name": "Девчонка Сардаана",
		"patrol": PackedVector3Array([Vector3(84, 0, 40.5), Vector3(96, 0, 41.0), Vector3(90, 0, 36.6)]), "patrol_wait": 3.0})
	character(chars, "EastMan", "kr_man", Vector3(95, 0, 36.6), PI / 2.0, {"dialog": "kr_rumors", "display_name": "Мужик с топором",
		"patrol": PackedVector3Array([Vector3(95, 0, 36.6), Vector3(112, 0, 41.2), Vector3(104, 0, 36.8)]), "patrol_wait": 6.0})
	# псы на выгоне: появляются, когда староста попросит
	for i in 3:
		character(chars, "Dog%d" % (i + 1), "wild_dog", Vector3(72 + i * 3.5, 0, 9 + (i % 2) * 3.0), randf() * TAU,
			{"hostile": true, "aggro_radius": 7.0, "squad": "dogs", "groups": ["kr_dogs"]})

	var items := group(root, "Items")
	_exit(items, "WestExit", "Дорога на запад", Vector3(1.0, 0, 38), Vector3(1.6, 2.2, 5.0))
	_exit(items, "EastExit", "Дорога на восток", Vector3(115.0, 0, 38), Vector3(1.6, 2.2, 5.0))
	_use(items, "Banya", "Баня", Vector3(24.5, 0, 61.0), Vector3(2.0, 2.0, 1.2))
	_use(items, "Chapel", "Часовня", Vector3(14.5, 0, 26.2), Vector3(1.6, 2.4, 1.0))
	for k in 3:
		var wp: Vector3 = [Vector3(14.5, 0, 45.8), Vector3(66.5, 0, 26.9), Vector3(112.5, 0, 43.4)][k]
		_use(items, "Woodpile%d" % (k + 1), "Поленница", wp, Vector3(1.6, 1.2, 1.2))
	_use(items, "Anvil", "Наковальня у кузницы", Vector3(108.5, 0, 42.4), Vector3(1.2, 1.2, 1.2))
	box(items.get_node("Anvil"), Vector3(0.7, 0.35, 0.3), Vector3(0, 0.75, 0), "metal_dark").owner = root
	cyl(items.get_node("Anvil"), 0.22, 0.26, 0.6, Vector3(0, 0.3, 0), "log_dark").owner = root
	_own(collider(items.get_node("Anvil"), Vector3(0.7, 0.9, 0.6), Vector3(0, 0.45, 0)), root)
	var hp := _use(items, "HeadPhoto", "Фотография на стене", _slot_of(vil.get_node("HeadHouse"), "table") + Vector3(0, 0, -0.5), Vector3(0.8, 1.2, 0.6))
	hp.set("reach", 2)
	_use(items, "KidStash", "Тайник под крыльцом", Vector3(77.2, 0, 41.9), Vector3(0.8, 0.5, 0.8))
	_use(items, "NetTracks", "Следы у сушилки", Vector3(62.6, 0, 62.4), Vector3(1.6, 0.4, 1.4))
	_use(items, "Cemetery", "Погост", Vector3(10, 0, 31.2), Vector3(8.0, 1.5, 4.0))
	# одинокая лиственница у восточной дороги: под ней сын Байбала зарыл карабин
	put(P.pine_b, vil, Vector3(84.5, 0, 32.2), 0.7, "OldLarchTree", 1.35)
	var lr := _use(items, "OldLarch", "Одинокая лиственница", Vector3(84.5, 0, 33.6), Vector3(1.6, 0.6, 1.4))
	box(lr, Vector3(1.0, 0.12, 0.8), Vector3(0, 0.03, 0), "ground_dirt", Vector3(0, 0.4, 0)).owner = root
	item(items, P.item_herbs, "Take_Herbs", Vector3(26.3, 0, 60.5))
	_spawn("Start", Vector3(4.5, 0, 38))
	_spawn("Road", Vector3(4.5, 0, 38))
	marker(root, "MarkHead", Vector3(47, 0, 25.5), "Староста")
	marker(root, "MarkBrew", Vector3(33, 0, 46.5), "Пивоварня")
	marker(root, "MarkRiver", Vector3(47, 0, 64), "Мостки")
	marker(root, "MarkPasture", Vector3(76, 0, 12), "Выгон")
	_dress(Rect2(4, 22, 108, 44), 1500)
	# мусор и лужи на задах
	put(P.trash_pile, vil, Vector3(37.0, 0, 52.5), 0.4)
	_finish("kresty")


# ======================================================================
# ЛАГЕРЬ ОБОРВАНЦЕВ: старая лесопилка на поляне, палатки и навесы вокруг
# костра, кучи хлама. Дорога приходит с запада.
# ======================================================================
func _camp() -> void:
	var rect := Rect2(0, 0, 72, 60)
	_begin("camp", "Лагерь оборванцев", rect, "res://scripts/locations/camp.gd")
	var d := "ground_dirt"
	strip(null, Vector2(-4, 30), Vector2(30, 30), 2.4, d)
	strip(null, Vector2(30, 30), Vector2(44, 24), 2.0, d)
	road_segs.append([Vector2(30, 33), Vector2(34, 35), 4.0])  # вытоптано у костра
	_mud.append(Rect2(26, 28, 12, 10))
	_mud.append(Rect2(40, 18, 14, 10))
	_meadow.append(Rect2(12, 14, 48, 34))
	_clear.append(Rect2(12, 12, 50, 38))
	_clear.append(Rect2(-4, 25, 18, 10))
	_ground_for("camp")
	var vil := group(root, "Village")
	# лесопилка: сарай без стены, брёвна, ржавая пила
	put(P.barn, vil, Vector3(48, 0, 20), PI / 2.0, "Sawmill")
	put(P.shed, vil, Vector3(56, 0, 28), -PI / 2.0)
	var saw := cyl(vil, 0.9, 0.9, 0.04, Vector3(42.5, 0.95, 26.5), "rust", Vector3(PI / 2.0, 0.3, 0), 18)
	saw.name = "SawBlade"
	saw.owner = root
	box(vil, Vector3(3.2, 0.9, 0.8), Vector3(42.5, 0.45, 26.5), "planks_old", Vector3(0, 0.3, 0)).owner = root
	_own(collider(vil, Vector3(3.2, 1.2, 1.0), Vector3(42.5, 0.6, 26.5), 0.3), root)
	for p in [Vector3(52, 0, 30.5), Vector3(38, 0, 17.5), Vector3(56, 0, 14)]:
		put(P.woodpile, vil, p, randf_range(-0.3, 0.3))
	# палатки и навесы вокруг костра
	_tent(vil, Vector3(24, 0, 38.5), 0.3)
	_tent(vil, Vector3(30, 0, 41.5), -0.1, "cloth_red", 0.9)
	_tent(vil, Vector3(38.5, 0, 40.5), -0.5)
	_tent(vil, Vector3(20, 0, 24), 2.6, "cloth_sack", 1.1)
	_tent(vil, Vector3(40, 0, 33.5), -1.4, "cloth_red")
	_lean_to(vil, Vector3(26, 0, 22.5), PI)
	_lean_to(vil, Vector3(18.5, 0, 33.5), PI / 2.0)
	var fire := put(P.fire, vil, Vector3(32, 0.2, 34), 0.0, "Campfire")
	fire.set("strength", 0.8)
	var ring := group(vil, "FireRing")
	for i in 10:
		var a := i * TAU / 10.0
		put(P.rock_small, ring, Vector3(32 + cos(a) * 0.9, 0, 34 + sin(a) * 0.9), a, "", 0.5)
	var det0 := group(root, "Yard")
	for lg in [[Vector3(32, 0, 31.6), 0.0], [Vector3(29.4, 0, 34.2), PI / 2.0], [Vector3(34.6, 0, 35.8), 0.4]]:
		put(P.log_fallen, det0, lg[0], lg[1], "", 0.8)
	for dd in [["crates", Vector3(25.5, 0, 35.2)], ["crates", Vector3(26.8, 0, 35.5)], ["barrel", Vector3(24.8, 0, 36.4)],
			["junk", Vector3(44, 0, 36)], ["junk", Vector3(16.5, 0, 28)], ["cart", Vector3(36, 0, 27)], ["barrel", Vector3(45.5, 0, 31)],
			["junk", Vector3(54, 0, 36)], ["crates", Vector3(21.5, 0, 20.5)]]:
		put(P[dd[0]], det0, dd[1], randf() * TAU)
	_woods(700)

	var chars := group(root, "Characters")
	character(chars, "Thug", "camp_thug", Vector3(13.5, 0, 30.4), -PI / 2.0, {"dialog": "camp_thug", "squad": "thugs", "armed": true})
	character(chars, "Thug2", "camp_thug2", Vector3(15.5, 0, 27.8), -PI / 2.0 - 0.4, {"squad": "thugs", "armed": true})
	character(chars, "Boss", "camp_boss", Vector3(33.6, 0, 31.4), -0.6, {"dialog": "camp_boss"})
	character(chars, "Nyurgun", "camp_nyurgun", Vector3(45.5, 0, 29.5), -1.2, {"dialog": "camp_nyurgun",
		"patrol": PackedVector3Array([Vector3(45.5, 0, 29.5), Vector3(50, 0, 32.5)]), "patrol_wait": 6.0})
	character(chars, "CampTrader", "camp_trader", Vector3(26.2, 0, 33.8), PI / 2.0, {"dialog": "camp_trader"})
	character(chars, "Wounded", "camp_wounded", Vector3(38.8, 0, 37.6), 0.4, {"dialog": "camp_wounded", "start_pose": "down"})
	character(chars, "Refugee1", "villager_f", Vector3(30, 0, 36.6), 2.4, {"display_name": "Беженка", "dialog": "camp_rumors"})
	character(chars, "Refugee2", "villager", Vector3(35.4, 0, 33.2), -2.0, {"display_name": "Беженец", "dialog": "camp_rumors"})
	character(chars, "CampKid", "kid", Vector3(22, 0, 31), 0.0, {"display_name": "Чумазый малец", "dialog": "camp_rumors",
		"patrol": PackedVector3Array([Vector3(22, 0, 31), Vector3(28, 0, 29), Vector3(24, 0, 27)]), "patrol_wait": 3.0})

	var items := group(root, "Items")
	_exit(items, "WestExit", "Дорога", Vector3(1.0, 0, 30), Vector3(1.6, 2.2, 5.0))
	_use(items, "Stash", "Тайник под брёвнами", Vector3(57.5, 0, 14.6), Vector3(1.4, 0.8, 1.4))
	item(items, P.bandage, "Take_Bandage", Vector3(20.2, 0, 22.4))
	_spawn("Start", Vector3(4.5, 0, 30))
	_spawn("Road", Vector3(4.5, 0, 30))
	marker(root, "MarkFire", Vector3(32, 0, 34), "Костёр")
	marker(root, "MarkMill", Vector3(48, 0, 20), "Лесопилка")
	_dress(Rect2(8, 12, 56, 38), 700)
	_finish("camp")


# ======================================================================
# СЛУЧАЙНАЯ ВСТРЕЧА: в сцене только свет и пустые группы — местность
# (поле, лес, болото, мёртвый лес) и людей собирает scripts/locations/encounter.gd на лету.
# ======================================================================
func _encounter() -> void:
	var rect := Rect2(0, 0, 46, 46)
	_begin("encounter", "Тайга", rect, "res://scripts/locations/encounter.gd")
	group(root, "Characters")
	group(root, "Items")
	_spawn("Start", Vector3(23, 0, 23))
	_finish("encounter")


func _spawn_mark(parent: Node, nm: String, pos: Vector3) -> void:
	var m := Marker3D.new()
	m.name = nm
	m.position = pos
	parent.add_child(m)
	m.owner = root


# ======================================================================
# ЗАИМКА ДЬААКЫПА: избушка охотника в распадке, коптильня, вешала с рыбой,
# тропа на север к капканам. Там, когда Дьаакып попросит, — чучуна.
# ======================================================================
func _zaimka() -> void:
	var rect := Rect2(0, 0, 60, 50)
	_begin("zaimka", "Заимка Дьаакыпа", rect, "res://scripts/locations/zaimka.gd")
	var d := "ground_dirt"
	strip(null, Vector2(-4, 30), Vector2(28, 28), 2.0, d)
	strip(null, Vector2(30, 24), Vector2(30, 4), 1.3, d)
	strip(null, Vector2(30, 4), Vector2(42, 3), 1.2, d)
	road_segs.append([Vector2(26, 26), Vector2(34, 30), 3.0])
	_meadow.append(Rect2(16, 16, 26, 20))
	_clear.append(Rect2(14, 14, 32, 26))
	_clear.append(Rect2(18, 0, 28, 8))
	_clear.append(Rect2(-4, 25, 20, 10))
	_ground_for("zaimka")
	var vil := group(root, "Village")
	put(P.izba_small, vil, Vector3(30, 0, 20.5), 0.05, "Hut")
	put(P.shed, vil, Vector3(39, 0, 22), -0.15, "Smokehouse")
	put(P.woodpile, vil, Vector3(23.5, 0, 19), 0.1)
	put(P.table, vil, Vector3(26.5, 0, 31), 0.2, "Table")
	put(P.bench, vil, Vector3(26.5, 0, 32.4), 0.2)
	_net_rack(vil, Vector3(36, 0, 31), 0.1)
	for p in [Vector3(34.6, 0, 30.4), Vector3(37.4, 0, 30.6)]:
		put(P.barrel, vil, p, randf() * TAU)
	put(P.hay_bale, vil, Vector3(42, 0, 27), 0.4)
	# конура
	var k := group(vil, "Kennel")
	k.position = Vector3(22, 0, 25)
	box(k, Vector3(1.0, 0.8, 1.2), Vector3(0, 0.4, 0), "planks_old").owner = root
	prism(k, Vector3(1.2, 0.4, 1.3), Vector3(0, 1.0, 0), "roof").owner = root
	_own(collider(k, Vector3(1.0, 1.0, 1.2), Vector3(0, 0.5, 0)), root)
	# черепа и рога на стене — охотник
	for x in [-0.8, 0.8]:
		box(vil, Vector3(0.6, 0.06, 0.06), Vector3(30 + x, 2.0, 22.9), "bark_birch", Vector3(0, 0, 0.5)).owner = root
	# араҥас — могила ойууна на помосте, в лесу к северо-западу
	_clear.append(Rect2(5, 3, 15, 14))
	strip(null, Vector2(18, 12), Vector2(12, 10), 1.0, d)
	var ar := group(vil, "Arangas")
	ar.position = Vector3(11.5, 0, 9.5)
	ar.rotation.y = 0.35
	for c in [Vector2(-0.9, -0.5), Vector2(0.9, -0.5), Vector2(-0.9, 0.5), Vector2(0.9, 0.5)]:
		cyl(ar, 0.09, 0.11, 2.3, Vector3(c.x, 1.15, c.y), "log_dark").owner = root
	box(ar, Vector3(2.3, 0.1, 1.4), Vector3(0, 2.3, 0), "log_dark").owner = root
	box(ar, Vector3(1.9, 0.5, 0.7), Vector3(0, 2.6, 0), "log_weathered").owner = root
	prism(ar, Vector3(2.0, 0.3, 0.8), Vector3(0, 3.0, 0), "log_dark").owner = root
	_own(collider(ar, Vector3(2.0, 2.4, 1.2), Vector3(0, 1.2, 0)), root)
	var mir := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.13
	cm.bottom_radius = 0.13
	cm.height = 0.02
	mir.mesh = cm
	var mm := StandardMaterial3D.new()
	mm.albedo_color = Color(0.72, 0.45, 0.22)
	mm.metallic = 0.8
	mm.roughness = 0.35
	mir.material_override = mm
	mir.name = "Mirror"
	mir.position = Vector3(1.0, 1.7, 0.6)
	mir.rotation = Vector3(PI / 2.0, 0, 0)
	ar.add_child(mir)
	mir.owner = root
	_woods(800)
	var chars := group(root, "Characters")
	character(chars, "Hermit", "hermit", Vector3(27.5, 0, 29.5), 0.3, {"dialog": "hermit", "armed": true})
	character(chars, "Chuchuna", "chuchuna", Vector3(44, 0, 2.5), -PI / 2.0, {"hostile": true, "aggro_radius": 11.0, "groups": ["chuchuna"]})
	var items := group(root, "Items")
	_exit(items, "WestExit", "Тропа обратно", Vector3(1.0, 0, 30), Vector3(1.6, 2.2, 5.0))
	_use(items, "Arangas", "Араҥас", Vector3(13.5, 0, 11.0), Vector3(2.6, 3.2, 1.8))
	var t1 := _use(items, "Trap1", "Капкан", Vector3(24.5, 0, 5.5), Vector3(1.2, 0.5, 1.2))
	box(t1, Vector3(0.7, 0.08, 0.7), Vector3(0, 0.04, 0), "rust").owner = root
	var t2 := _use(items, "Trap2", "Капкан", Vector3(36.5, 0, 3.0), Vector3(1.2, 0.5, 1.2))
	box(t2, Vector3(0.7, 0.08, 0.7), Vector3(0, 0.04, 0), "rust", Vector3(0, 0.6, 0.3)).owner = root
	item(items, P.item_herbs, "Take_Herbs", Vector3(18, 0, 10))
	# дикий хмель в распадке — для Дьулуса
	var hi := 0
	for p in [Vector3(44, 0, 14), Vector3(46.5, 0, 17.5), Vector3(42.5, 0, 33.5), Vector3(17, 0, 21)]:
		hi += 1
		var h := item(items, P.item_herbs, "Take_Hops%d" % hi, p)
		h.set("item_id", "hops")
		h.set("label", "Дикий хмель")
	_spawn("Start", Vector3(4.5, 0, 29.8))
	_spawn("Road", Vector3(4.5, 0, 29.8))
	marker(root, "MarkHut", Vector3(30, 0, 20.5), "Избушка")
	marker(root, "MarkTraps", Vector3(30, 0, 4), "Капканы")
	_dress(Rect2(14, 2, 32, 36), 600)
	_finish("zaimka")


# ======================================================================
# РЖАВЫЙ КОНВОЙ: три грузовика на старой дороге, разбитый караван, засада.
# ======================================================================
func _truck(parent: Node, nm: String, pos: Vector3, rot: float, tilt := 0.0, paint := "paint_faded") -> Node3D:
	var t := Node3D.new()
	t.name = nm
	parent.add_child(t, true)
	t.owner = root
	t.position = pos
	t.rotation = Vector3(0, rot, tilt)
	# кабина спереди (+z), кузов сзади
	box(t, Vector3(2.3, 1.1, 1.9), Vector3(0, 1.05, 2.6), paint).owner = root
	box(t, Vector3(2.2, 0.9, 1.6), Vector3(0, 2.0, 2.5), paint).owner = root
	box(t, Vector3(2.0, 0.55, 0.05), Vector3(0, 2.05, 3.32), "glass").owner = root
	box(t, Vector3(2.4, 0.25, 4.6), Vector3(0, 0.75, -0.9), "rust").owner = root
	for sx in [-1.18, 1.18]:
		box(t, Vector3(0.08, 0.6, 4.6), Vector3(sx, 1.15, -0.9), "planks_old").owner = root
	box(t, Vector3(2.4, 0.6, 0.08), Vector3(0, 1.15, -3.2), "planks_old").owner = root
	for wz in [2.6, -0.4, -2.2]:
		for sx in [-1.15, 1.15]:
			cyl(t, 0.48, 0.48, 0.32, Vector3(sx, 0.48, wz), "tire", Vector3(0, 0, PI / 2.0), 12).owner = root
	_own(collider(t, Vector3(2.5, 2.4, 6.8), Vector3(0, 1.2, 0.0)), root)
	return t


func _convoy() -> void:
	var rect := Rect2(0, 0, 66, 42)
	_begin("convoy", "Ржавый конвой", rect, "res://scripts/locations/convoy.gd")
	strip(null, Vector2(-4, 20), Vector2(70, 22.5), 3.4, "ground_dirt")
	_meadow.append(Rect2(10, 10, 46, 22))
	_mud.append(Rect2(26, 24, 9, 4))
	_clear.append(Rect2(8, 8, 50, 26))
	_clear.append(Rect2(-4, 15, 14, 10))
	_ground_for("convoy")
	var vil := group(root, "Village")
	_truck(vil, "Truck1", Vector3(23, 0, 19.0), PI / 2.0 + 0.08)
	_truck(vil, "Truck2", Vector3(32.5, 0, 25.8), PI / 2.0 + 0.5, 0.12, "rust")
	_truck(vil, "Truck3", Vector3(42, 0, 19.2), PI / 2.0 - 0.15)
	put(P.cart, vil, Vector3(48.5, 0, 24.5), 2.6, "BrokenCart")
	for dd in [["crates", Vector3(27.5, 0, 17.0)], ["crates", Vector3(28.6, 0, 16.4)], ["barrel", Vector3(36.5, 0, 17.4)],
			["crates", Vector3(46.5, 0, 16.0)], ["barrel", Vector3(19.5, 0, 22.6)], ["junk", Vector3(38.5, 0, 28.0)],
			["hay_bale", Vector3(50.5, 0, 21.0)]]:
		put(P[dd[0]], vil, dd[1], randf() * TAU)
	_woods(700)
	var chars := group(root, "Characters")
	character(chars, "Driver", "driver_dead", Vector3(29.5, 0, 21.2), 1.2, {"start_dead": true})
	character(chars, "Ambusher1", "convoy_raider", Vector3(44.5, 0, 15.0), -PI / 2.0, {"hostile": true, "aggro_radius": 9.0, "squad": "ambush"})
	character(chars, "Ambusher2", "convoy_raider2", Vector3(47.5, 0, 26.0), -PI / 2.0, {"hostile": true, "aggro_radius": 9.0, "squad": "ambush"})
	var items := group(root, "Items")
	_exit(items, "WestExit", "Дорога назад", Vector3(1.0, 0, 20), Vector3(1.6, 2.2, 5.0))
	_exit(items, "EastExit", "Дорога к Сунгару", Vector3(65.0, 0, 22.5), Vector3(1.6, 2.2, 5.0))
	_use(items, "CabSafe", "Ящик в кабине", Vector3(23.3, 0, 21.6), Vector3(1.4, 1.6, 1.4))
	_use(items, "Cargo", "Разбитые ящики", Vector3(28, 0, 16.6), Vector3(2.2, 1.0, 1.6))
	_spawn("Start", Vector3(4.5, 0, 20.2))
	_spawn("Road", Vector3(4.5, 0, 20.2))
	_dress(Rect2(8, 8, 50, 26), 700)
	_finish("convoy")


# ======================================================================
# БАЗА НА СЫТЫГАНЕ: бетонная ограда, два корпуса, вышка, заваренный люк.
# Здесь весной сожгли стоянку оборванцев и вывезли бумаги. Внутри — копатели.
# ======================================================================
func _block(parent: Node, nm: String, pos: Vector3, size: Vector3, rot := 0.0) -> Node3D:
	var b := Node3D.new()
	b.name = nm
	parent.add_child(b, true)
	b.owner = root
	b.position = pos
	b.rotation.y = rot
	box(b, size, Vector3(0, size.y / 2.0, 0), "stone_wall").owner = root
	box(b, Vector3(size.x + 0.3, 0.2, size.z + 0.3), Vector3(0, size.y + 0.1, 0), "metal_roof").owner = root
	# окна-проёмы и дверь по фасаду (+z)
	for x in range(int(-size.x / 2.0) + 1, int(size.x / 2.0), 2):
		box(b, Vector3(0.9, 0.7, 0.05), Vector3(x, size.y * 0.62, size.z / 2.0 + 0.01), "metal_dark").owner = root
	box(b, Vector3(1.2, 2.1, 0.06), Vector3(0, 1.05, size.z / 2.0 + 0.02), "rust").owner = root
	_own(collider(b, size, Vector3(0, size.y / 2.0, 0)), root)
	return b


func _ruin() -> void:
	var rect := Rect2(0, 0, 66, 54)
	_begin("ruin", "База на Сытыгане", rect, "res://scripts/locations/ruin.gd")
	strip(null, Vector2(-4, 27), Vector2(22, 27), 2.6, "ground_dirt")
	strip(null, Vector2(22, 27), Vector2(44, 27), 3.0, "ground_dirt")
	_mud.append(Rect2(24, 34, 14, 6))
	_mud.append(Rect2(4, 40, 12, 8))
	_meadow.append(Rect2(18, 10, 34, 32))
	_clear.append(Rect2(14, 6, 42, 40))
	_clear.append(Rect2(-4, 22, 20, 10))
	_clear.append(Rect2(2, 36, 16, 14))
	_ground_for("ruin")
	var vil := group(root, "Village")
	# ограда из бетонных плит с проломом-воротами на западе
	var fence := group(vil, "Fence")
	var x := 19.0
	while x < 52.0:
		box(fence, Vector3(2.0, 2.2, 0.25), Vector3(x + 1.0, 1.1, 10.0), "stone_wall").owner = root
		if not (x > 33 and x < 37):  # пролом в южной стене
			box(fence, Vector3(2.0, 2.2, 0.25), Vector3(x + 1.0, 1.1, 42.0), "stone_wall").owner = root
		x += 2.05
	var z := 10.0
	while z < 42.0:
		if absf(z + 1.0 - 27.0) > 2.2:
			box(fence, Vector3(0.25, 2.2, 2.0), Vector3(19.0, 1.1, z + 1.0), "stone_wall").owner = root
		box(fence, Vector3(0.25, 2.2, 2.0), Vector3(52.0, 1.1, z + 1.0), "stone_wall").owner = root
		z += 2.05
	var fb := StaticBody3D.new()
	fb.name = "Collision"
	fence.add_child(fb)
	fb.owner = root
	for c in [[Vector3(35.5, 1.1, 10.0), Vector3(33.5, 2.2, 0.4)], [Vector3(26.5, 1.1, 42.0), Vector3(15.5, 2.2, 0.4)],
			[Vector3(45.0, 1.1, 42.0), Vector3(14.5, 2.2, 0.4)], [Vector3(19.0, 1.1, 17.7), Vector3(0.4, 2.2, 15.4)],
			[Vector3(19.0, 1.1, 36.3), Vector3(0.4, 2.2, 11.4)], [Vector3(52.0, 1.1, 26.0), Vector3(0.4, 2.2, 32.4)]]:
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = c[1]
		cs.shape = bs
		cs.position = c[0]
		fb.add_child(cs)
		cs.owner = root
	_block(vil, "Office", Vector3(30, 0, 16.5), Vector3(10, 3.4, 6))
	_block(vil, "Store", Vector3(44, 0, 33), Vector3(8, 3.0, 6), PI)
	put(P.tower, vil, Vector3(48.5, 0, 14), 0.0, "Watchtower")
	put(P.shed, vil, Vector3(24, 0, 37.5), 0.3)
	_bunker_portal(vil)
	# пустой контейнер и бумаги
	box(vil, Vector3(2.4, 2.4, 5.6), Vector3(26, 1.2, 30), "paint_faded", Vector3(0, 0.2, 0), "Container").owner = root
	_own(collider(vil, Vector3(2.4, 2.4, 5.6), Vector3(26, 1.2, 30), 0.2), root)
	for i in 14:
		box(vil, Vector3(0.3, 0.01, 0.4), Vector3(randf_range(27, 37), 0.02, randf_range(20, 25)), "paper", Vector3(0, randf() * TAU, 0)).owner = root
	for dd in [["crates", Vector3(36.5, 0, 31.5)], ["barrel", Vector3(47.5, 0, 26.5)], ["junk", Vector3(33, 0, 36)],
			["crates", Vector3(22.5, 0, 22.0)], ["barrel", Vector3(22.0, 0, 21.0)]]:
		put(P[dd[0]], vil, dd[1], randf() * TAU)
	# сгоревшая стоянка оборванцев за оградой
	var burnt := group(vil, "Burnt")
	for p in [Vector3(7, 0, 42), Vector3(11, 0, 45), Vector3(8.5, 0, 47.5)]:
		box(burnt, Vector3(2.4, 0.04, 2.8), p + Vector3(0, 0.03, 0), "ash").owner = root
		cyl(burnt, 0.04, 0.04, 1.3, p + Vector3(0.9, 0.5, 1.2), "log_dark", Vector3(0.6, 0, 0.3)).owner = root
	_woods(700)
	var chars := group(root, "Characters")
	character(chars, "Digger1", "ruin_looter", Vector3(33, 0, 22.5), 0.4, {"hostile": true, "aggro_radius": 8.0, "squad": "diggers"})
	character(chars, "Digger2", "ruin_looter", Vector3(41, 0, 25.0), -1.2, {"hostile": true, "aggro_radius": 8.0, "squad": "diggers"})
	character(chars, "Digger3", "ruin_looter_gun", Vector3(44, 0, 29.0), PI, {"hostile": true, "aggro_radius": 8.0, "squad": "diggers"})
	var items := group(root, "Items")
	_exit(items, "WestExit", "Дорога назад", Vector3(1.0, 0, 27), Vector3(1.6, 2.2, 5.0))
	_use(items, "WallMap", "Карта на стене", Vector3(28, 0, 19.8), Vector3(1.6, 2.0, 0.8))
	_use(items, "Terminal", "Терминал", Vector3(32.5, 0, 19.9), Vector3(1.0, 1.6, 0.8))
	var bg := _use(items, "BunkerGate", "Гермоворота бункера", Vector3(40.0, 0, 21.3), Vector3(3.0, 2.6, 1.2))
	bg.set("reach", 2)
	_spawn("Ramp", Vector3(40.0, 0, 23.4))
	_use(items, "ContainerUse", "Контейнер", Vector3(27.5, 0, 30.5), Vector3(1.4, 2.0, 2.0))
	_use(items, "Papers", "Бумаги", Vector3(32, 0, 22.5), Vector3(3.0, 0.4, 2.0))
	_use(items, "Burnt", "Пепелище", Vector3(9, 0, 45), Vector3(5.0, 1.0, 5.0))
	_spawn("Start", Vector3(4.5, 0, 27))
	_spawn("Road", Vector3(4.5, 0, 27))
	# вентиляционная шахта бункера — с решёткой; по верёвке — вниз
	var sh := _use(items, "Shaft", "Вентшахта", Vector3(46.5, 0, 22.0), Vector3(1.6, 1.4, 1.6))
	box(sh, Vector3(1.3, 0.9, 1.3), Vector3(0, 0.45, 0), "stone_wall").owner = root
	box(sh, Vector3(1.1, 0.04, 1.1), Vector3(0, 0.92, 0), "metal_dark").owner = root
	for i in 5:
		box(sh, Vector3(0.04, 0.05, 1.1), Vector3(-0.44 + i * 0.22, 0.96, 0), "rust").owner = root
	_own(collider(sh, Vector3(1.3, 0.9, 1.3), Vector3(0, 0.45, 0)), root)
	_spawn("Shaft", Vector3(45.0, 0, 22.0))
	_dress(Rect2(14, 6, 42, 40), 500)
	_finish("ruin")


## Въезд в бункер «Сытыган-14»: бетонная дорога от пролома в ограде, траншея-пандус
## с подпорными стенками, портал и круглые гермоворота (открытые и закрытые — для ruin.gd)
func _bunker_portal(vil: Node) -> void:
	var g := group(vil, "BunkerPortal")
	var cd: StandardMaterial3D = (load(MAT_DIR + "concrete.tres") as StandardMaterial3D).duplicate()
	cd.albedo_color = Color("8a867c")
	M["concrete_dark"] = cd
	# дорога: бетонные плиты от пролома в ограде к пандусу, по краям — столбики
	strip(g, Vector2(19.5, 27), Vector2(33.5, 27), 3.4, "concrete_dark", 0.02)
	strip(g, Vector2(33.5, 27), Vector2(40.0, 27.6), 3.4, "concrete_dark", 0.02)
	for x in [23.0, 27.0, 31.0]:
		for dz in [-1.9, 1.9]:
			cyl(g, 0.07, 0.07, 0.8, Vector3(x, 0.4, 27 + dz), "paint_faded").owner = root
	# траншея-пандус с юга на север: стенки растут к воротам — будто пол уходит вниз
	for k in 4:
		var z0 := 26.4 - k * 1.5
		var h := 0.35 + k * 0.33
		for x in [38.2, 41.8]:
			box(g, Vector3(0.35, h, 1.52), Vector3(x, h / 2.0, z0 - 0.75), "concrete_dark").owner = root
	_own(collider(g, Vector3(0.4, 1.5, 6.0), Vector3(38.2, 0.75, 23.4)), root)
	_own(collider(g, Vector3(0.4, 1.5, 6.0), Vector3(41.8, 0.75, 23.4)), root)
	box(g, Vector3(3.3, 0.03, 6.0), Vector3(40.0, 0.03, 23.4), "coal").owner = root
	for k in 9:
		for x in [38.55, 41.45]:
			box(g, Vector3(0.12, 0.035, 0.3), Vector3(x, 0.04, 26.0 - k * 0.62), "paint_faded" if k % 2 == 0 else "tire").owner = root
	# портал: торцевая стена, балка с надписью над воротами
	box(g, Vector3(5.6, 2.8, 0.9), Vector3(40.0, 1.4, 19.9), "concrete_dark").owner = root
	box(g, Vector3(5.6, 0.5, 1.4), Vector3(40.0, 2.85, 20.6), "concrete_dark").owner = root
	_own(collider(g, Vector3(5.6, 2.8, 0.9), Vector3(40.0, 1.4, 19.9)), root)
	var l := Label3D.new()
	l.text = "СЫТЫГАН-14"
	l.font_size = 64
	l.pixel_size = 0.006
	l.modulate = Color("e3a23a")
	l.position = Vector3(40.0, 2.85, 21.32)
	fit_label(l, 5.4, 0.5)
	g.add_child(l)
	l.owner = root
	# гермоворота: закрытые — диск в проёме, открытые — диск откатился вбок, за ним темнота
	for st in ["GateClosed", "GateOpen"]:
		var d := Node3D.new()
		d.name = st
		g.add_child(d)
		d.owner = root
		var dx := 0.0 if st == "GateClosed" else 1.7
		if st == "GateOpen":
			box(d, Vector3(2.2, 2.2, 0.05), Vector3(40.0, 1.2, 20.37), "coal").owner = root
		cyl(d, 1.15, 1.15, 0.35, Vector3(40.0 + dx, 1.2, 20.5), "metal_dark", Vector3(PI / 2.0, 0, 0), 24).owner = root
		cyl(d, 0.35, 0.35, 0.06, Vector3(40.0 + dx, 1.2, 20.7), "paint_faded", Vector3(PI / 2.0, 0, 0), 12).owner = root
		for k in 3:
			box(d, Vector3(0.9, 0.07, 0.05), Vector3(40.0 + dx, 1.2, 20.74), "rust", Vector3(0, 0, k * PI / 3.0)).owner = root
	# полуобвал: плита съехала в траншею с западной стенки, щебень
	box(g, Vector3(1.4, 0.25, 2.4), Vector3(38.9, 0.5, 24.2), "concrete_dark", Vector3(0.1, 0.2, 0.5)).owner = root
	for k in 6:
		put(P.rock_small, g, Vector3(randf_range(38.5, 39.1), 0, randf_range(22.5, 25.5)), randf() * TAU, "", randf_range(0.5, 0.9))
	_signboard(g, "ОБЪЕКТ «СЫТЫГАН-14» · ВЪЕЗД ПО ПРОПУСКАМ", Vector3(34.6, 1.6, 29.0), 0.0, 3.2)
	for x in [33.2, 36.0]:
		cyl(g, 0.06, 0.06, 1.6, Vector3(x, 0.8, 28.95), "rust").owner = root


# ======================================================================
# ПОСТ СВЯЗИ: ретранслятор наёмников на сопке — решётчатая мачта, кунг с рацией,
# генератор, палатка. Откуда идёт сигнал из модуля «Связь». Туда ведёт кассета «Эфир».
# ======================================================================
func _radio_post() -> void:
	var rect := Rect2(0, 0, 56, 46)
	_begin("radio_post", "Пост связи", rect, "res://scripts/locations/radio_post.gd")
	var cg := StandardMaterial3D.new()
	cg.albedo_color = Color("4a5232")
	cg.roughness = 1.0
	M["cloth_green"] = cg
	M["glow_green"] = load(MAT_DIR + "screen_green.tres")
	var d := "ground_dirt"
	strip(null, Vector2(-4, 26), Vector2(18, 25), 2.4, d)
	strip(null, Vector2(18, 25), Vector2(28, 23), 2.6, d)
	road_segs.append([Vector2(24, 22), Vector2(36, 22), 4.0])
	_meadow.append(Rect2(12, 6, 36, 34))
	# поляна на сопке широкая: камера смотрит с юго-востока, лес не должен закрывать лагерь
	_clear.append(Rect2(8, 2, 44, 44))
	_clear.append(Rect2(-4, 21, 22, 10))
	_mud.append(Rect2(22, 24, 8, 4))
	_ground_for("radio_post")
	var vil := group(root, "Village")
	# решётчатая мачта: четыре ноги, раскосы, красно-белые пояса, антенны наверху
	var m := group(vil, "Mast")
	m.position = Vector3(36, 0, 16)
	var H := 16.0
	for c in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		box(m, Vector3(0.12, H, 0.12), Vector3(c.x * 0.9, H / 2.0, c.y * 0.9), "metal_dark", Vector3(-c.y * 0.035, 0, c.x * 0.035)).owner = root
	for k in 8:
		var y := 1.0 + k * 1.9
		var w := 1.8 - y * 0.06
		var band := "paint_white" if k % 2 == 0 else "cloth_red"
		for side in 4:
			var a := side * PI / 2.0
			box(m, Vector3(w, 0.08, 0.08), Vector3(cos(a) * w / 2.0, y, sin(a) * w / 2.0), band, Vector3(0, a + PI / 2.0, 0)).owner = root
			box(m, Vector3(w * 1.3, 0.05, 0.05), Vector3(cos(a) * w / 2.0, y + 0.95, sin(a) * w / 2.0), "metal_dark", Vector3(0, a + PI / 2.0, 0.6)).owner = root
	for k in 3:
		var a := k * TAU / 3.0
		cyl(m, 0.45, 0.45, 0.08, Vector3(cos(a) * 0.5, H - 1.5 - k * 0.6, sin(a) * 0.5), "paint_white", Vector3(PI / 2.0, a, 0), 14).owner = root
	cyl(m, 0.03, 0.03, 2.4, Vector3(0, H + 1.2, 0), "metal_dark").owner = root
	_lamp(m, "Beacon", Vector3(0, H + 2.4, 0), Color("ff3a2a"), 1.2, 4.0).shadow_enabled = false
	_own(collider(m, Vector3(2.2, 3.0, 2.2), Vector3(0, 1.5, 0)), root)
	# растяжки к бетонным якорям
	for a in [0.4, 2.5, 4.6]:
		var anc := Vector3(36 + cos(a) * 8.0, 0.2, 16 + sin(a) * 8.0)
		box(vil, Vector3(0.6, 0.4, 0.6), anc, "concrete").owner = root
		var top := Vector3(36, H * 0.7, 16)
		var mid := (anc + top) / 2.0
		var dv := top - anc
		var cable := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.012
		cm.bottom_radius = 0.012
		cm.height = dv.length()
		cm.radial_segments = 4
		cable.mesh = cm
		cable.material_override = M["metal_dark"]
		cable.position = mid
		cable.basis = Basis(Quaternion(Vector3.UP, dv.normalized()))
		vil.add_child(cable)
		cable.owner = root
	# кунг на шасси: будка связи, дверь открыта, внутри светятся шкалы
	var k := group(vil, "Kung")
	k.position = Vector3(26, 0, 17)
	k.rotation.y = 0.15
	box(k, Vector3(2.6, 2.2, 5.0), Vector3(0, 1.9, 0), "paint_faded").owner = root
	box(k, Vector3(2.62, 0.12, 5.02), Vector3(0, 3.05, 0), "metal_dark").owner = root
	box(k, Vector3(2.4, 1.0, 1.8), Vector3(0, 1.3, 3.4), "paint_faded").owner = root
	box(k, Vector3(2.2, 0.5, 0.05), Vector3(0, 1.6, 4.31), "glass").owner = root
	for wz in [3.2, -0.8, -1.9]:
		for sx in [-1.2, 1.2]:
			cyl(k, 0.5, 0.5, 0.34, Vector3(sx, 0.5, wz), "tire", Vector3(0, 0, PI / 2.0), 12).owner = root
	box(k, Vector3(0.05, 1.7, 0.9), Vector3(1.32, 1.85, -1.0), "coal").owner = root
	box(k, Vector3(0.05, 1.7, 0.9), Vector3(1.9, 1.85, -0.3), "paint_faded", Vector3(0, -1.2, 0)).owner = root
	box(k, Vector3(0.02, 0.4, 0.5), Vector3(1.28, 2.0, -1.0), "glow_green").owner = root
	_lamp(k, "Dial", Vector3(1.8, 2.0, -1.0), Color("8fe08a"), 0.5, 3.0).shadow_enabled = false
	cyl(k, 0.03, 0.03, 4.0, Vector3(-0.9, 5.0, -2.0), "metal_dark").owner = root
	for st in 3:
		box(k, Vector3(0.7, 0.06, 0.28), Vector3(1.5 + st * 0.2, 0.3 + st * 0.3, -1.0), "metal_dark").owner = root
	_own(collider(k, Vector3(2.7, 3.0, 7.0), Vector3(0, 1.5, 0.6)), root)
	# кабель от кунга к мачте, генератор, бочки
	box(vil, Vector3(9.5, 0.05, 0.08), Vector3(31.2, 0.03, 16.6), "tire", Vector3(0, -0.06, 0)).owner = root
	box(vil, Vector3(1.6, 1.0, 0.9), Vector3(29.5, 0.5, 21.0), "metal_dark").owner = root
	box(vil, Vector3(0.5, 0.3, 0.5), Vector3(29.5, 1.15, 21.0), "rust").owner = root
	_own(collider(vil, Vector3(1.6, 1.2, 0.9), Vector3(29.5, 0.6, 21.0)), root)
	for p in [Vector3(31.2, 0, 21.4), Vector3(31.9, 0, 20.6), Vector3(31.4, 0, 22.3)]:
		put(P.barrel, vil, p, randf() * TAU)
	# палатка, стол с картой под маскировочной сетью, костровище
	var t := group(vil, "Tent")
	t.position = Vector3(41, 0, 27)
	t.rotation.y = -0.3
	prism(t, Vector3(3.2, 1.8, 4.2), Vector3(0, 0.9, 0), "cloth_sack").owner = root
	_own(collider(t, Vector3(3.2, 1.8, 4.2), Vector3(0, 0.9, 0)), root)
	put(P.table, vil, Vector3(32, 0, 27), 0.2, "MapTable")
	box(vil, Vector3(1.0, 0.01, 0.7), Vector3(32, 0.8, 27), "paper", Vector3(0, 0.3, 0)).owner = root
	for c in [Vector2(30, 25.5), Vector2(34, 25.5), Vector2(30, 28.5), Vector2(34, 28.5)]:
		cyl(vil, 0.04, 0.04, 2.3, Vector3(c.x, 1.15, c.y), "log_dark").owner = root
	box(vil, Vector3(4.6, 0.04, 3.6), Vector3(32, 2.3, 27), "cloth_green").owner = root
	put(P.bench, vil, Vector3(32, 0, 28.3), 0.2)
	var fire := put(P.fire, vil, Vector3(37, 0.2, 31), 0.0, "Fire", 0.7)
	fire.set("strength", 0.6)
	# ограда из колючей проволоки на кольях с проходом с запада
	for i in 14:
		var a := i * TAU / 14.0
		var pp := Vector3(33 + cos(a) * 13.0, 0, 21 + sin(a) * 11.0)
		if pp.x < 22.0 and absf(pp.z - 23.0) < 4.0:
			continue
		cyl(vil, 0.05, 0.06, 1.3, pp + Vector3(0, 0.65, 0), "log_dark").owner = root
	_woods(450)
	var chars := group(root, "Characters")
	character(chars, "Merc1", "raider_gun", Vector3(27.5, 0, 24.5), PI * 0.7, {"display_name": "Охранник поста", "hostile": true,
		"aggro_radius": 9.0, "squad": "post", "patrol": PackedVector3Array([Vector3(27.5, 0, 24.5), Vector3(40, 0, 22.5)]), "patrol_wait": 5.0})
	character(chars, "Merc2", "raider_gun", Vector3(38.5, 0, 19.5), -PI / 2.0, {"display_name": "Охранник поста", "hostile": true,
		"aggro_radius": 9.0, "squad": "post"})
	character(chars, "Operator", "raider", Vector3(32.3, 0, 28.0), PI, {"display_name": "Радист", "hostile": true,
		"aggro_radius": 7.0, "squad": "post", "start_pose": "sit"})
	var items := group(root, "Items")
	_exit(items, "WestExit", "Тропа назад", Vector3(1.0, 0, 26), Vector3(1.6, 2.2, 5.0))
	var rs := _use(items, "RadioSet", "Рация в кунге", Vector3(28.2, 0, 16.6), Vector3(1.2, 2.2, 1.4))
	rs.set("reach", 2)
	_use(items, "Logbook", "Журнал радиста", Vector3(32, 0, 26.4), Vector3(1.4, 1.0, 1.0))
	var mc := _use(items, "MastClimb", "Лестница на мачту", Vector3(36, 0, 17.6), Vector3(1.4, 3.0, 1.0))
	mc.set("reach", 2)
	var ac := _use(items, "AmmoCrate", "Ящик с патронами", Vector3(40.2, 0, 24.6), Vector3(0.9, 0.8, 0.8))
	box(ac, Vector3(0.9, 0.5, 0.6), Vector3(0, 0.25, 0), "cloth_green").owner = root
	_own(collider(ac, Vector3(0.9, 0.5, 0.6), Vector3(0, 0.25, 0)), root)
	_spawn("Start", Vector3(4.5, 0, 26))
	_spawn("Road", Vector3(4.5, 0, 26))
	_dress(Rect2(14, 8, 32, 28), 350)
	_finish("radio_post")


# ======================================================================
# ПОДЗЕМНЫЕ УРОВНИ: темно, свет — свой. Сцены без выхода на карту мира:
# наверх ведёт лестница / верёвка обратно в ту локацию, откуда спустились.
# ======================================================================
func _dark_env(ambient: Color, energy: float) -> void:
	var env_g := group(root, "Env")
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("050403")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = ambient
	env.ambient_light_energy = energy
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.8
	we.environment = env
	env_g.add_child(we)
	we.owner = root


func _lamp(parent: Node, nm: String, pos: Vector3, col: Color, energy: float, rng_m := 7.0, on := true) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.name = nm
	l.position = pos
	l.light_color = col
	l.light_energy = energy
	l.omni_range = rng_m
	l.shadow_enabled = true
	l.visible = on
	parent.add_child(l)
	l.owner = root
	return l


## Пол, стены, потолка нет (камера сверху): комната = прямоугольник стен
func _room_walls(parent: Node, r: Rect2, h: float, mat: String, gaps := []) -> void:
	var sides := [[Vector2(r.position.x, r.position.y), Vector2(r.end.x, r.position.y)], [Vector2(r.position.x, r.end.y), Vector2(r.end.x, r.end.y)],
		[Vector2(r.position.x, r.position.y), Vector2(r.position.x, r.end.y)], [Vector2(r.end.x, r.position.y), Vector2(r.end.x, r.end.y)]]
	for sd in sides:
		var a: Vector2 = sd[0]
		var b: Vector2 = sd[1]
		var horiz := absf(a.y - b.y) < 0.01
		# стену режем проёмами
		var cuts := [[a, b]]
		for g in gaps:
			var gp: Vector2 = g[0]
			var gw: float = g[1]
			var nc := []
			for c in cuts:
				var c0: Vector2 = c[0]
				var c1: Vector2 = c[1]
				var on_line := (horiz and absf(gp.y - c0.y) < 0.2 and gp.x > c0.x and gp.x < c1.x) or (not horiz and absf(gp.x - c0.x) < 0.2 and gp.y > c0.y and gp.y < c1.y)
				if on_line:
					if horiz:
						nc.append([c0, Vector2(gp.x - gw / 2.0, c0.y)])
						nc.append([Vector2(gp.x + gw / 2.0, c0.y), c1])
					else:
						nc.append([c0, Vector2(c0.x, gp.y - gw / 2.0)])
						nc.append([Vector2(c0.x, gp.y + gw / 2.0), c1])
				else:
					nc.append(c)
			cuts = nc
		for c in cuts:
			var c0: Vector2 = c[0]
			var c1: Vector2 = c[1]
			var ln := c0.distance_to(c1)
			if ln < 0.05:
				continue
			var mid := (c0 + c1) / 2.0
			var size := Vector3(ln + 0.3, h, 0.3) if horiz else Vector3(0.3, h, ln + 0.3)
			box(parent, size, Vector3(mid.x, h / 2.0, mid.y), mat).owner = root
			_own(collider(parent, size, Vector3(mid.x, h / 2.0, mid.y)), root)


func _floor(parent: Node, r: Rect2, mat: String) -> void:
	box(parent, Vector3(r.size.x, 0.1, r.size.y), Vector3(r.get_center().x, -0.05, r.get_center().y), mat).owner = root


# ---------------- подпол избы деда ----------------
func _cellar() -> void:
	var rect := Rect2(0, 0, 8, 7)
	seed(77)
	root = Node3D.new()
	root.name = "NakharroCellar"
	root.set_script(load("res://scripts/locations/nakharro_cellar.gd"))
	root.set("location_id", "nakharro_cellar")
	root.set("title", "Подпол деда")
	root.set("map_rect", rect)
	root.set("camera_start", Vector3(4, 0, 3.5))
	_dark_env(Color("3a2c1c"), 0.25)
	var v := group(root, "Village")
	_floor(v, rect.grow(0.3), "planks_old")
	_room_walls(v, rect, 1.6, "log_weathered")
	# полки с банками вдоль северной стены
	for x in [1.6, 4.0, 6.4]:
		box(v, Vector3(2.0, 0.06, 0.45), Vector3(x, 0.7, 0.45), "planks_old").owner = root
		box(v, Vector3(2.0, 0.06, 0.45), Vector3(x, 1.2, 0.45), "planks_old").owner = root
		for k in 5:
			cyl(v, 0.09, 0.09, 0.22, Vector3(x - 0.8 + k * 0.4, 0.84, 0.45), "glass").owner = root
			cyl(v, 0.08, 0.08, 0.2, Vector3(x - 0.7 + k * 0.35, 1.33, 0.45), "berry" if k % 2 else "glass").owner = root
	_own(collider(v, Vector3(7.0, 1.4, 0.5), Vector3(4.0, 0.7, 0.45)), root)
	put(P.barrel, v, Vector3(6.9, 0, 5.9), 0.3)
	put(P.barrel, v, Vector3(6.2, 0, 6.1), 1.0)
	put(P.crates, v, Vector3(1.0, 0, 5.8), 0.2)
	# лестница наверх
	for i in 6:
		box(v, Vector3(0.7, 0.05, 0.08), Vector3(4.0, 0.25 + i * 0.25, 6.6), "log").owner = root
	for x in [3.65, 4.35]:
		box(v, Vector3(0.06, 1.6, 0.06), Vector3(x, 0.8, 6.62), "log").owner = root
	var items := group(root, "Items")
	var up := _use(items, "UpExit", "Лестница наверх", Vector3(4.0, 0, 6.3), Vector3(1.2, 1.8, 0.8))
	up.set("reach", 2)
	var candle := _use(items, "Candle", "Свеча в плошке", Vector3(2.4, 0, 3.4), Vector3(0.8, 1.0, 0.8))
	box(candle, Vector3(0.6, 0.6, 0.6), Vector3(0, 0.3, 0), "planks_old").owner = root
	cyl(candle, 0.05, 0.05, 0.16, Vector3(0, 0.68, 0), "paper").owner = root
	_own(collider(candle, Vector3(0.6, 0.6, 0.6), Vector3(0, 0.3, 0)), root)
	_lamp(candle, "Flame", Vector3(0, 1.0, 0), Color("ffb060"), 2.2, 7.0, false)
	var jar := _use(items, "Jam", "Банка варенья", Vector3(4.4, 0, 0.9), Vector3(0.8, 1.4, 0.6))
	jar.set("reach", 2)
	var trunk := _use(items, "Trunk", "Старый сундук", Vector3(1.6, 0, 3.9), Vector3(1.2, 0.8, 0.8))
	box(trunk, Vector3(1.1, 0.55, 0.65), Vector3(0, 0.28, 0), "log_dark").owner = root
	box(trunk, Vector3(1.12, 0.06, 0.67), Vector3(0, 0.58, 0), "metal_dark").owner = root
	_own(collider(trunk, Vector3(1.1, 0.6, 0.65), Vector3(0, 0.3, 0)), root)
	# тусклый свет из люка сверху
	_lamp(v, "HatchLight", Vector3(4.0, 2.4, 6.2), Color("c8b48a"), 0.9, 4.5)
	group(root, "Characters")
	_spawn("Start", Vector3(4.0, 0, 5.6))
	_spawn("Down", Vector3(4.0, 0, 5.6))
	_finish("nakharro_cellar")


# ---------------- вторые этажи изб Нахарро ----------------
## Светёлки трёх двухэтажных изб лежат в одной сцене рядом (виден только тот дом,
## где стоит герой). Люк с лестницей — над стремянкой первого этажа (у задней стены).
const UPPER_ROOMS := {"Izba5": Rect2(0, 0, 5.4, 4.6), "Izba9": Rect2(12, 0, 5.4, 4.6), "Izba13": Rect2(24, 0, 7.4, 4.4)}


func _glow(col: Color, e := 1.6) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col.darkened(0.4)
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = e
	return m


func _upper() -> void:
	seed(5959)
	root = Node3D.new()
	root.name = "NakharroUpper"
	root.set_script(load("res://scripts/locations/nakharro_upper.gd"))
	root.set("location_id", "nakharro_upper")
	root.set("title", "Нахарро · светёлка")
	root.set("map_rect", Rect2(-2, -2, 36, 9))
	root.set("camera_start", Vector3(2.7, 0, 2.3))
	for n in ["herb", "brass", "whitewash", "trim"]:
		M[n] = load(MAT_DIR + n + ".tres")
	M["dial_glow"] = _glow(Color("8fe08a"))
	M["lamp_glow"] = _glow(Color("ffb347"), 2.2)
	M["board"] = _glow(Color("1c2a22"), 0.0)
	M["book_a"] = _glow(Color("6a2e24"), 0.0)
	M["book_b"] = _glow(Color("2e4a5a"), 0.0)
	M["book_c"] = _glow(Color("5a5a2e"), 0.0)
	_dark_env(Color("8a7a62"), 0.55)
	var items := group(root, "Items")
	var chars := group(root, "Characters")
	var vil := group(root, "Village")
	for hn in UPPER_ROOMS:
		var r: Rect2 = UPPER_ROOMS[hn]
		var g := group(vil, "Room_" + hn)
		_floor(g, r.grow(0.15), "planks_old")
		# дальние стены — в рост, ближние к камере (юг и восток) — по пояс, как в разрезе
		for w in [[Vector3(r.size.x + 0.3, 1.5, 0.3), Vector3(r.get_center().x, 0.75, r.position.y)],
				[Vector3(0.3, 1.5, r.size.y + 0.3), Vector3(r.position.x, 0.75, r.get_center().y)],
				[Vector3(r.size.x + 0.3, 0.55, 0.3), Vector3(r.get_center().x, 0.275, r.end.y)],
				[Vector3(0.3, 0.55, r.size.y + 0.3), Vector3(r.end.x, 0.275, r.get_center().y)]]:
			box(g, w[0], w[1], "log_weathered").owner = root
			_own(collider(g, Vector3(w[0].x, 1.5, w[0].z), Vector3(w[1].x, 0.75, w[1].z)), root)
		# окна в торцах и в фасаде, тёплый свет дня
		box(g, Vector3(0.08, 0.6, 0.6), Vector3(r.position.x + 0.17, 1.0, r.get_center().y), "glass").owner = root
		box(g, Vector3(0.7, 0.6, 0.08), Vector3(r.get_center().x + 1.4, 1.0, r.position.y + 0.17), "glass").owner = root
		_lamp(g, "Day", Vector3(r.get_center().x, 2.6, r.get_center().y), Color("f2dcb0"), 1.1, 7.0)
		# люк и стремянка вниз — над лестницей первого этажа
		var hx := r.get_center().x - 0.15
		var hz := r.position.y + 0.75
		box(g, Vector3(0.9, 0.04, 0.9), Vector3(hx, 0.01, hz), "coal").owner = root
		for sx in [-1, 1]:
			box(g, Vector3(0.06, 0.8, 0.06), Vector3(hx + sx * 0.5, 0.4, hz + 0.5), "planks_old").owner = root
			box(g, Vector3(0.06, 0.06, 1.0), Vector3(hx + sx * 0.5, 0.8, hz), "planks_old").owner = root
		_own(collider(g, Vector3(1.0, 0.8, 0.9), Vector3(hx, 0.4, hz)), root)
		var dn := _use(items, "Down_" + hn, "Люк вниз", Vector3(hx, 0, hz), Vector3(1.0, 1.0, 1.0))
		dn.set("reach", 2)
		_spawn("From_" + hn, Vector3(hx, 0, hz + 1.0))
		# балки потолка по краям — без перекрытия (камера сверху)
		box(g, Vector3(r.size.x, 0.14, 0.14), Vector3(r.get_center().x, 1.55, r.position.y + 0.2), "log_dark").owner = root
	# --- светёлка Туйгуна: самодельный приёмник, провода, слуховое окно на крышу ---
	var ra: Rect2 = UPPER_ROOMS["Izba5"]
	var gA: Node = vil.get_node("Room_Izba5")
	box(gA, Vector3(0.8, 0.06, 1.5), Vector3(4.75, 0.76, 2.7), "planks_old").owner = root
	for lz in [-0.6, 0.6]:
		box(gA, Vector3(0.06, 0.74, 0.06), Vector3(4.75, 0.37, 2.7 + lz), "planks_old").owner = root
	_own(collider(gA, Vector3(0.8, 0.8, 1.5), Vector3(4.75, 0.4, 2.7)), root)
	box(gA, Vector3(0.45, 0.3, 0.6), Vector3(4.85, 0.95, 2.5), "metal_dark").owner = root
	box(gA, Vector3(0.02, 0.12, 0.3), Vector3(4.61, 0.98, 2.5), "dial_glow").owner = root
	for k in 3:
		cyl(gA, 0.035, 0.035, 0.04, Vector3(4.6, 0.88, 2.3 + k * 0.1), "brass", Vector3(0, 0, PI / 2.0)).owner = root
	box(gA, Vector3(0.3, 0.2, 0.25), Vector3(4.8, 0.89, 3.15), "tire").owner = root
	cyl(gA, 0.09, 0.09, 0.06, Vector3(4.7, 0.82, 3.0), "tin", Vector3(PI / 2.0, 0, 0)).owner = root
	cyl(gA, 0.09, 0.09, 0.06, Vector3(4.7, 0.82, 3.25), "tin", Vector3(PI / 2.0, 0, 0)).owner = root
	box(gA, Vector3(0.4, 0.45, 0.4), Vector3(3.95, 0.22, 2.7), "planks_old").owner = root
	box(gA, Vector3(1.6, 0.06, 0.35), Vector3(4.3, 1.1, 0.3), "planks_old").owner = root
	for k in 6:
		cyl(gA, 0.04, 0.05, 0.14, Vector3(3.7 + k * 0.22, 1.2, 0.3), "glass").owner = root
	box(gA, Vector3(0.9, 0.22, 1.9), Vector3(0.75, 0.11, 3.4), "cloth_sack").owner = root
	box(gA, Vector3(0.6, 0.12, 0.4), Vector3(0.75, 0.28, 2.65), "cloth_red").owner = root
	box(gA, Vector3(0.02, 0.5, 0.7), Vector3(0.17, 1.0, 1.4), "paper").owner = root
	_lamp(gA, "Dial", Vector3(4.4, 1.1, 2.5), Color("8fe08a"), 0.5, 2.5)
	var rcv := _use(items, "Receiver", "Самодельный приёмник", Vector3(4.75, 0, 2.5), Vector3(0.8, 1.1, 0.8))
	rcv.set("reach", 2)
	var rw := _use(items, "RoofWindow", "Слуховое окно на крышу", Vector3(ra.end.x - 0.35, 0, 1.0), Vector3(0.6, 1.6, 1.0))
	rw.set("reach", 2)
	box(gA, Vector3(0.1, 0.7, 0.7), Vector3(ra.end.x - 0.2, 0.9, 1.0), "planks_old").owner = root
	box(gA, Vector3(0.06, 0.5, 0.5), Vector3(ra.end.x - 0.27, 0.95, 1.0), "glass").owner = root
	character(chars, "Tuygun", "radio_kid", Vector3(4.12, 0, 2.7), PI / 2.0, {"dialog": "radio_kid", "start_pose": "sit"})
	# --- светёлка бабушки (Izba9): ткацкий станок, прялка, травы, приданое ---
	var gB: Node = vil.get_node("Room_Izba9")
	var lx := 13.7
	var lz2 := 2.6
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			box(gB, Vector3(0.08, 1.3, 0.08), Vector3(lx + sx * 0.7, 0.65, lz2 + sz * 0.4), "log_dark").owner = root
	box(gB, Vector3(1.5, 0.08, 0.08), Vector3(lx, 1.25, lz2 - 0.4), "log_dark").owner = root
	box(gB, Vector3(1.5, 0.08, 0.08), Vector3(lx, 0.7, lz2 + 0.4), "log_dark").owner = root
	box(gB, Vector3(1.2, 0.6, 0.02), Vector3(lx, 0.95, lz2), "cloth_red").owner = root
	box(gB, Vector3(1.2, 0.02, 0.5), Vector3(lx, 0.72, lz2 + 0.2), "cloth_sack").owner = root
	_own(collider(gB, Vector3(1.5, 1.3, 0.9), Vector3(lx, 0.65, lz2)), root)
	cyl(gB, 0.35, 0.35, 0.05, Vector3(16.5, 0.75, 3.5), "planks_old", Vector3(0, 0, PI / 2.0), 14).owner = root
	box(gB, Vector3(0.5, 0.3, 0.2), Vector3(16.5, 0.25, 3.5), "planks_old").owner = root
	box(gB, Vector3(3.4, 0.03, 0.03), Vector3(14.9, 1.45, 3.9), "rope_mat").owner = root
	for k in 7:
		cyl(gB, 0.08, 0.03, 0.35, Vector3(13.4 + k * 0.5, 1.25, 3.9), "herb", Vector3.ZERO, 6).owner = root
	box(gB, Vector3(0.9, 0.5, 0.5), Vector3(16.7, 0.25, 0.55), "planks_old").owner = root
	box(gB, Vector3(0.92, 0.06, 0.52), Vector3(16.7, 0.52, 0.55), "brass").owner = root
	_own(collider(gB, Vector3(0.9, 0.55, 0.5), Vector3(16.7, 0.27, 0.55)), root)
	box(gB, Vector3(0.9, 0.3, 1.8), Vector3(12.65, 0.15, 1.3), "cloth_sack").owner = root
	_use(items, "Loom", "Ткацкий станок", Vector3(lx, 0, lz2), Vector3(1.5, 1.3, 0.9))
	_use(items, "Dowry", "Сундук", Vector3(16.7, 0, 0.55), Vector3(0.9, 0.7, 0.6))
	var hr := _use(items, "HerbRack", "Травы на верёвке", Vector3(14.9, 0, 3.9), Vector3(3.0, 1.6, 0.5))
	hr.set("reach", 2)
	character(chars, "HideKid3", "hs_kid3", Vector3(13.2, 0, 3.55), PI, {"dialog": "hs_kid3", "start_pose": "sit"})
	# --- светёлка учительницы (Izba13): полки с книгами, доска, парты, глобус ---
	var rc: Rect2 = UPPER_ROOMS["Izba13"]
	var gC: Node = vil.get_node("Room_Izba13")
	for sx in [rc.position.x + 1.3, rc.end.x - 1.3]:
		box(gC, Vector3(2.0, 1.4, 0.35), Vector3(sx, 0.7, rc.position.y + 0.3), "planks_old").owner = root
		_own(collider(gC, Vector3(2.0, 1.4, 0.4), Vector3(sx, 0.7, rc.position.y + 0.3)), root)
		for row in 3:
			var bx: float = sx - 0.9
			while bx < sx + 0.9:
				var bw := randf_range(0.05, 0.11)
				var bh := randf_range(0.26, 0.36)
				box(gC, Vector3(bw, bh, 0.24), Vector3(bx + bw / 2.0, 0.3 + row * 0.45 + bh / 2.0, rc.position.y + 0.5),
					["book_a", "book_b", "book_c", "paper"][randi() % 4]).owner = root
				bx += bw + 0.01
	box(gC, Vector3(0.06, 0.9, 1.7), Vector3(rc.position.x + 0.2, 1.0, 2.4), "board").owner = root
	var lbl := Label3D.new()
	lbl.text = "2062. Август.\nжи — ши"
	lbl.font_size = 40
	lbl.pixel_size = 0.004
	lbl.modulate = Color("e8e4d8")
	lbl.position = Vector3(rc.position.x + 0.25, 1.05, 2.4)
	fit_label(lbl, 1.6, 0.85)
	lbl.rotation.y = PI / 2.0
	gC.add_child(lbl)
	lbl.owner = root
	# две парты у передней стены — проход к полкам и глобусу остаётся свободным
	for dx in [27.3, 28.9]:
		box(gC, Vector3(0.9, 0.05, 0.55), Vector3(dx, 0.65, 3.55), "planks_old").owner = root
		box(gC, Vector3(0.9, 0.6, 0.05), Vector3(dx, 0.32, 3.3), "planks_old").owner = root
		box(gC, Vector3(0.8, 0.35, 0.3), Vector3(dx, 0.18, 4.0), "planks_old").owner = root
		_own(collider(gC, Vector3(1.0, 0.7, 1.0), Vector3(dx, 0.35, 3.75)), root)
	cyl(gC, 0.03, 0.12, 0.8, Vector3(30.8, 0.4, 2.2), "brass").owner = root
	sphere(gC, 0.25, Vector3(30.8, 1.05, 2.2), "book_b").owner = root
	box(gC, Vector3(0.4, 0.1, 0.3), Vector3(30.75, 1.07, 2.15), "book_c", Vector3(0, 0.4, 0.4)).owner = root
	_use(items, "Globe", "Глобус", Vector3(30.8, 0, 2.2), Vector3(0.7, 1.4, 0.7))
	var bb := _use(items, "Blackboard", "Школьная доска", Vector3(rc.position.x + 0.45, 0, 2.4), Vector3(0.5, 1.6, 1.8))
	bb.set("reach", 2)
	var sh := _use(items, "Shelves", "Книжные полки", Vector3(rc.end.x - 1.3, 0, rc.position.y + 0.6), Vector3(2.0, 1.6, 0.6))
	sh.set("reach", 2)
	character(chars, "Teacher", "teacher", Vector3(25.8, 0, 2.5), PI / 2.0, {"dialog": "teacher"})
	_spawn("Start", Vector3(UPPER_ROOMS["Izba5"].get_center().x - 0.15, 0, 1.75))
	_finish("nakharro_upper")


# ---------------- бункер под Сытыганом ----------------
func _bunker() -> void:
	var rect := Rect2(0, 0, 42, 24)
	seed(1414)
	root = Node3D.new()
	root.name = "RuinBunker"
	root.set_script(load("res://scripts/locations/ruin_bunker.gd"))
	root.set("location_id", "ruin_bunker")
	root.set("title", "Бункер «Сытыган-14»")
	root.set("map_rect", rect)
	root.set("camera_start", Vector3(5, 0, 5))
	_bunker_mats()
	_dark_env(Color("262830"), 0.2)
	var v := group(root, "Village")
	_floor(v, rect.grow(0.3), "bk_floor")
	# помещения: шахта, шлюз с гермоворотами, коридор, пульт, казарма, генераторная, архив
	var shaft := Rect2(1, 1, 8, 9)
	var gate := Rect2(1, 10, 8, 8)
	var corr := Rect2(9, 10.5, 23, 4)
	var ctrl := Rect2(12, 1, 16, 9.5)
	var bar := Rect2(10, 14.5, 9, 8)
	var gen := Rect2(20, 14.5, 10, 8)
	var arch := Rect2(32, 3, 9, 18)
	_room_walls(v, shaft, 1.3, "concrete", [[Vector2(5, 10), 2.4]])
	_room_walls(v, gate, 1.3, "concrete", [[Vector2(5, 10), 2.4], [Vector2(9, 12.5), 2.4]])
	_room_walls(v, corr, 1.3, "concrete", [[Vector2(9, 12.5), 2.4], [Vector2(17, 10.5), 2.0], [Vector2(24, 10.5), 2.0],
		[Vector2(14, 14.5), 2.0], [Vector2(25, 14.5), 2.0], [Vector2(32, 12.5), 2.0]])
	_room_walls(v, ctrl, 1.3, "concrete", [[Vector2(17, 10.5), 2.0], [Vector2(24, 10.5), 2.0]])
	_room_walls(v, bar, 1.3, "concrete", [[Vector2(14, 14.5), 2.0]])
	_room_walls(v, gen, 1.3, "concrete", [[Vector2(25, 14.5), 2.0]])
	_room_walls(v, arch, 1.3, "concrete", [[Vector2(32, 12.5), 2.0]])
	# облицовка: бежевые панели с тёмными швами и оранжевой полосой — кассетный футуризм
	for r in [gate, corr, ctrl, bar, gen, arch]:
		_bk_panels(v, r)
	# дверь архива — электрозамок: коллизия, пока не открыта
	var door := Node3D.new()
	door.name = "ArchiveDoor"
	v.add_child(door)
	door.owner = root
	box(door, Vector3(0.22, 1.3, 2.0), Vector3(32, 0.65, 12.5), "bk_dark").owner = root
	box(door, Vector3(0.24, 0.12, 2.0), Vector3(32, 0.95, 12.5), "bk_orange").owner = root
	box(door, Vector3(0.26, 0.4, 0.06), Vector3(32, 0.6, 11.7), "bk_yellow").owner = root
	_own(collider(door, Vector3(0.3, 2.2, 2.0), Vector3(32, 1.1, 12.5)), root)
	_hazard(v, Vector2(31.2, 11.5), Vector2(31.7, 13.5))
	_hazard(v, Vector2(9.2, 11.3), Vector2(9.8, 13.7))
	_bk_shaft(v, shaft)
	_bk_gate(v, gate)
	_bk_corridor(v, corr)
	_bk_control(v, ctrl)
	_bk_barracks(v, bar)
	_bk_generator(v, gen)
	_bk_archive(v, arch)
	# аварийные красные лампы (горят всегда), основной свет — от генератора
	var em := group(v, "Emergency")
	for pt in [Vector3(5, 2.2, 5), Vector3(5, 2.2, 14), Vector3(12, 2.2, 12.5), Vector3(19, 2.2, 12.5), Vector3(28, 2.2, 12.5),
			Vector3(20, 2.2, 5), Vector3(14.5, 2.2, 18.5), Vector3(25, 2.2, 18.5), Vector3(36.5, 2.2, 12)]:
		_lamp(em, "Red", pt, Color("ff3322"), 0.9, 6.5).shadow_enabled = false
	var main_l := group(v, "MainLights")
	for pt in [Vector3(5, 2.4, 14), Vector3(13, 2.4, 12.5), Vector3(27, 2.4, 12.5), Vector3(16, 2.4, 5.5), Vector3(22, 2.4, 6),
			Vector3(14.5, 2.4, 18.5), Vector3(25, 2.4, 18.5), Vector3(36.5, 2.4, 7.5), Vector3(36.5, 2.4, 16.5)]:
		_lamp(main_l, "Lamp", pt, Color("e8f0ff"), 1.5, 8.0, false)
	var chars := group(root, "Characters")
	character(chars, "DeadCleaner", "cleaner_dead", Vector3(19.5, 0, 8.6), 0.6, {"start_dead": true})
	character(chars, "Squatter1", "ruin_looter", Vector3(13.0, 0, 18.6), -0.8, {"hostile": true, "aggro_radius": 7.0, "squad": "squat"})
	character(chars, "Squatter2", "ruin_looter_gun", Vector3(16.2, 0, 19.2), -1.4, {"hostile": true, "aggro_radius": 7.0, "squad": "squat"})
	var items := group(root, "Items")
	var up := _use(items, "UpRope", "Верёвка наверх", Vector3(3.2, 0, 3.2), Vector3(1.0, 2.4, 1.0))
	cyl(up, 0.03, 0.03, 3.6, Vector3(0, 1.8, 0), "rope_mat").owner = root
	var gd := _use(items, "GateDoor", "Гермоворота", Vector3(1.9, 0, 14), Vector3(1.0, 2.6, 3.2))
	gd.set("reach", 2)
	_use(items, "Generator", "Дизель-генератор", Vector3(25, 0, 19.6), Vector3(3.0, 1.6, 1.2))
	_use(items, "DoorLock", "Электрозамок", Vector3(31.4, 0, 11.2), Vector3(0.8, 1.8, 0.8))
	_use(items, "Lockers", "Шкафчики", Vector3(16.6, 0, 15.7), Vector3(3.0, 1.8, 0.8))
	_use(items, "Files", "Шкаф с делами", Vector3(36.5, 0, 9.0), Vector3(3.5, 2.0, 1.0))
	_use(items, "Registry", "Ведомость", Vector3(36.5, 0, 15.5), Vector3(3.5, 2.0, 1.0))
	var tp := _use(items, "TapeDeck", "Магнитофон «Электроника»", Vector3(13.3, 0, 4.0), Vector3(1.0, 1.6, 1.4))
	tp.set("reach", 2)
	var wall := _use(items, "WallScreen", "Табло «Контур»", Vector3(20, 0, 1.8), Vector3(6.0, 1.6, 0.8))
	wall.set("reach", 2)
	_use(items, "Console", "Пульт оператора", Vector3(17.5, 0, 7.4), Vector3(1.8, 1.2, 1.0))
	_spawn("Start", Vector3(4.6, 0, 5.4))
	_spawn("Down", Vector3(4.6, 0, 5.4))
	_spawn("Gate", Vector3(3.4, 0, 14))
	_finish("ruin_bunker")


## Материалы бункера: беж и белый пластик, тёмный металл, оранжевые и бирюзовые акценты, светящиеся экраны
func _bunker_mats() -> void:
	M["concrete"] = load(MAT_DIR + "concrete.tres")
	for n in ["brass", "trim", "coal"]:
		M[n] = load(MAT_DIR + n + ".tres")
	var plain := func(c: String, rough: float, metal := 0.0) -> StandardMaterial3D:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(c)
		m.roughness = rough
		m.metallic = metal
		return m
	M["bk_panel"] = plain.call("d8cfb8", 0.55)
	M["bk_beige"] = plain.call("b8a882", 0.6)
	M["bk_dark"] = plain.call("34383a", 0.45, 0.5)
	M["bk_orange"] = plain.call("c8582a", 0.5)
	M["bk_teal"] = plain.call("3a6a6e", 0.5)
	M["bk_floor"] = plain.call("3c3f3e", 0.85)
	M["bk_yellow"] = plain.call("c9a234", 0.6)
	M["bk_black"] = plain.call("161616", 0.7)
	M["bk_screen"] = plain.call("0c120e", 0.15)
	M["scr_green"] = _glow(Color("8fe08a"), 1.8)
	M["scr_amber"] = _glow(Color("ffb347"), 1.8)
	M["strip"] = _glow(Color("dfe8ff"), 2.4)
	M["btn_red"] = _glow(Color("ff4a2a"), 1.2)
	M["btn_green"] = _glow(Color("6aff7a"), 1.0)


## Стеновые панели по периметру комнаты: секции с швами, полоса на уровне пояса
func _bk_panels(v: Node, r: Rect2) -> void:
	for side in 4:
		var horiz := side < 2
		var ln := r.size.x if horiz else r.size.y
		var n := int(ln / 1.2)
		for k in n:
			var t := (k + 0.5) * ln / n
			var pos: Vector3
			if side == 0:
				pos = Vector3(r.position.x + t, 0.62, r.position.y + 0.19)
			elif side == 1:
				pos = Vector3(r.position.x + t, 0.62, r.end.y - 0.19)
			elif side == 2:
				pos = Vector3(r.position.x + 0.19, 0.62, r.position.y + t)
			else:
				pos = Vector3(r.end.x - 0.19, 0.62, r.position.y + t)
			var sz := Vector3(ln / n - 0.06, 1.1, 0.05) if horiz else Vector3(0.05, 1.1, ln / n - 0.06)
			box(v, sz, pos, "bk_panel").owner = root
		var band := Vector3(ln, 0.08, 0.07) if horiz else Vector3(0.07, 0.08, ln)
		var bp: Vector3
		if side == 0:
			bp = Vector3(r.get_center().x, 0.9, r.position.y + 0.22)
		elif side == 1:
			bp = Vector3(r.get_center().x, 0.9, r.end.y - 0.22)
		elif side == 2:
			bp = Vector3(r.position.x + 0.22, 0.9, r.get_center().y)
		else:
			bp = Vector3(r.end.x - 0.22, 0.9, r.get_center().y)
		box(v, band, bp, "bk_orange").owner = root


## Жёлто-чёрная разметка на полу у проёма (прямоугольник от a до b)
func _hazard(v: Node, a: Vector2, b: Vector2) -> void:
	var along_z := absf(b.y - a.y) > absf(b.x - a.x)
	var ln := absf(b.y - a.y) if along_z else absf(b.x - a.x)
	var n := int(ln / 0.3)
	for k in n:
		var t := (k + 0.5) / n
		var p := a.lerp(b, t)
		var sz := Vector3(absf(b.x - a.x), 0.012, ln / n) if along_z else Vector3(ln / n, 0.012, absf(b.y - a.y))
		box(v, sz, Vector3(p.x, 0.01, p.y), "bk_yellow" if k % 2 == 0 else "bk_black").owner = root


## Обвал: наклонные плиты, арматура, щебень (плюс коллизия на завал)
func _collapse(v: Node, c: Vector3, size: Vector2, blocker := true) -> void:
	for k in 4:
		var off := Vector3(randf_range(-size.x, size.x) * 0.35, 0, randf_range(-size.y, size.y) * 0.35)
		box(v, Vector3(randf_range(1.2, 2.2), 0.22, randf_range(0.9, 1.6)), c + off + Vector3(0, randf_range(0.3, 0.8), 0), "concrete",
			Vector3(randf_range(-0.6, 0.6), randf() * TAU, randf_range(-0.5, 0.5))).owner = root
	for k in 6:
		cyl(v, 0.015, 0.015, randf_range(0.8, 1.6), c + Vector3(randf_range(-size.x, size.x) * 0.4, 0.6, randf_range(-size.y, size.y) * 0.4), "rust",
			Vector3(randf_range(-1.2, 1.2), 0, randf_range(-1.2, 1.2)), 5).owner = root
	for k in 10:
		put(P.rock_small, v, c + Vector3(randf_range(-size.x, size.x) * 0.5, 0, randf_range(-size.y, size.y) * 0.5), randf() * TAU, "",
			randf_range(0.5, 1.1))
	if blocker:
		_own(collider(v, Vector3(size.x * 0.8, 1.2, size.y * 0.8), c + Vector3(0, 0.6, 0)), root)


func _bk_shaft(v: Node, r: Rect2) -> void:
	# вентшахта: кожух вентилятора, сорванная решётка, свет сверху
	cyl(v, 1.1, 1.1, 0.5, Vector3(3.2, 0.25, 3.2), "bk_dark", Vector3.ZERO, 18).owner = root
	for k in 6:
		box(v, Vector3(0.9, 0.04, 0.22), Vector3(3.2, 0.52, 3.2), "bk_panel", Vector3(0, k * PI / 3.0, 0.3)).owner = root
	box(v, Vector3(1.4, 0.05, 1.4), Vector3(5.6, 0.03, 2.4), "rust", Vector3(0, 0.5, 0.1)).owner = root
	for k in 6:
		put(P.rock_small, v, Vector3(randf_range(2, 7), 0, randf_range(5, 8.5)), randf() * TAU, "", randf_range(0.7, 1.2))
	box(v, Vector3(0.4, 1.2, 2.8), Vector3(r.end.x - 0.4, 0.6, 3.0), "bk_dark").owner = root
	for k in 3:
		cyl(v, 0.06, 0.06, 2.8, Vector3(r.end.x - 0.65, 0.3 + k * 0.35, 3.0), ["bk_orange", "bk_teal", "bk_yellow"][k], Vector3(PI / 2.0, 0, 0)).owner = root
	_own(collider(v, Vector3(0.6, 1.2, 2.8), Vector3(r.end.x - 0.4, 0.6, 3.0)), root)
	_lamp(v, "ShaftLight", Vector3(3.2, 3.5, 3.2), Color("c8c0a8"), 1.2, 6.0)


func _bk_gate(v: Node, r: Rect2) -> void:
	# круглые гермоворота в западной стене: диск, штурвал, петли, гидроцилиндры
	var g := Node3D.new()
	g.name = "Gate"
	v.add_child(g)
	g.owner = root
	cyl(g, 1.55, 1.55, 0.45, Vector3(1.35, 1.2, 14), "bk_dark", Vector3(0, 0, PI / 2.0), 28).owner = root
	cyl(g, 1.2, 1.2, 0.08, Vector3(1.6, 1.2, 14), "bk_panel", Vector3(0, 0, PI / 2.0), 24).owner = root
	cyl(g, 0.45, 0.45, 0.06, Vector3(1.66, 1.2, 14), "bk_orange", Vector3(0, 0, PI / 2.0), 16).owner = root
	for k in 4:
		box(g, Vector3(0.05, 0.08, 1.0), Vector3(1.72, 1.2, 14), "brass", Vector3(k * PI / 4.0, 0, 0)).owner = root
	for dz in [-1.75, 1.75]:
		box(g, Vector3(0.3, 0.5, 0.3), Vector3(1.4, 1.2, 14 + dz), "bk_dark").owner = root
		cyl(g, 0.08, 0.08, 1.6, Vector3(1.9, 1.7, 14 + dz * 0.8), "brass", Vector3(0.9 * signf(dz), 0, 0)).owner = root
	_hazard(v, Vector2(1.9, 12.2), Vector2(2.4, 15.8))
	# будка пропускного поста со стеклом и турникет
	box(v, Vector3(1.6, 1.0, 1.4), Vector3(7.0, 0.5, 16.6), "bk_beige").owner = root
	box(v, Vector3(1.62, 0.5, 1.42), Vector3(7.0, 1.25, 16.6), "glass").owner = root
	box(v, Vector3(0.5, 0.35, 0.05), Vector3(7.0, 1.2, 15.88), "bk_screen").owner = root
	_own(collider(v, Vector3(1.6, 1.5, 1.4), Vector3(7.0, 0.75, 16.6)), root)
	for k in 3:
		box(v, Vector3(0.06, 0.06, 0.6), Vector3(6.0, 0.8, 15.4 + k * 0.1), "brass", Vector3(0, 0, k * 0.4)).owner = root
	var sign := Label3D.new()
	sign.text = "ОБЪЕКТ «СЫТЫГАН-14»\nПРЕДЪЯВИТЕ ПРОПУСК"
	sign.font_size = 44
	sign.pixel_size = 0.005
	sign.modulate = Color("e8d8a8")
	sign.position = Vector3(5, 1.15, r.position.y + 0.25)
	fit_label(sign, 3.6, 0.6)
	v.add_child(sign)
	sign.owner = root
	# обвал в юго-западном углу и трещина со светом с поверхности
	_collapse(v, Vector3(2.8, 0, 16.8), Vector2(2.4, 1.6))
	_lamp(v, "Crack", Vector3(2.2, 3.2, 16.5), Color("b8c4d0"), 0.8, 5.0)
	var strips := v.get_node_or_null("Strips")
	if strips == null:
		strips = group(v, "Strips")
	for x in [4.0, 7.0]:
		box(strips, Vector3(1.4, 0.06, 0.08), Vector3(x, 1.27, r.position.y + 0.25), "strip").owner = root
	_lamp(v, "GateWork", Vector3(6.0, 2.0, 12.0), Color("ffd9a0"), 0.5, 5.0)


func _bk_corridor(v: Node, r: Rect2) -> void:
	# кабельный лоток под потолком, трубы, полосы светильников (горят от генератора)
	box(v, Vector3(r.size.x, 0.08, 0.35), Vector3(r.get_center().x, 1.22, r.position.y + 0.45), "bk_dark").owner = root
	for k in 3:
		cyl(v, 0.04, 0.04, r.size.x, Vector3(r.get_center().x, 1.3, r.position.y + 0.35 + k * 0.1), ["bk_orange", "bk_teal", "bk_black"][k],
			Vector3(0, 0, PI / 2.0), 6).owner = root
	cyl(v, 0.12, 0.12, r.size.x, Vector3(r.get_center().x, 1.15, r.end.y - 0.4), "bk_beige", Vector3(0, 0, PI / 2.0), 10).owner = root
	var strips := v.get_node_or_null("Strips")
	if strips == null:
		strips = group(v, "Strips")
	for x in range(int(r.position.x) + 2, int(r.end.x) - 1, 3):
		for z in [r.position.y + 0.25, r.end.y - 0.25]:
			box(strips, Vector3(1.4, 0.06, 0.08), Vector3(x, 1.27, z), "strip").owner = root
	# обвал посреди коридора: потолок рухнул на северную половину, проход — вдоль южной стены
	_collapse(v, Vector3(20.5, 0, 11.7), Vector2(3.0, 1.8))
	for k in 4:
		box(v, Vector3(0.03, randf_range(0.6, 1.1), 0.03), Vector3(19.5 + k * 0.6, 0.9, 12.4), "bk_orange", Vector3(randf_range(-0.4, 0.4), 0, randf_range(-0.4, 0.4))).owner = root
	_lamp(v, "Sparks", Vector3(20.5, 1.2, 12.6), Color("ffb060"), 0.6, 3.0)
	# указатели на стенах
	for t in [["ПУЛЬТ ↑", Vector3(17, 1.05, 10.75)], ["АРХИВ →", Vector3(29.5, 1.05, 10.75)], ["КАЗАРМА ↓", Vector3(14, 1.05, 14.25)],
			["ДЭС ↓", Vector3(25, 1.05, 14.25)]]:
		var l := Label3D.new()
		l.text = t[0]
		l.font_size = 40
		l.pixel_size = 0.005
		l.modulate = Color("e3a23a")
		l.position = t[1] + Vector3(1.4, 0, 0.05 if (t[1] as Vector3).z < 12 else -0.05)
		l.rotation.y = 0.0 if (t[1] as Vector3).z < 12 else PI
		v.add_child(l)
		l.owner = root


## Пульт оператора: бежевая тумба, наклонная панель с кнопками, ЭЛТ-монитор, кресло
func _console(v: Node, scr: Node, at: Vector3, rot: float, amber := false) -> void:
	var b := Basis.from_euler(Vector3(0, rot, 0))
	var f := func(l: Vector3) -> Vector3: return at + b * l
	box(v, Vector3(1.6, 0.72, 0.7), f.call(Vector3(0, 0.36, 0)), "bk_beige", Vector3(0, rot, 0)).owner = root
	box(v, Vector3(1.6, 0.06, 0.55), f.call(Vector3(0, 0.78, 0.05)), "bk_panel", Vector3(-0.35, rot, 0)).owner = root
	for k in 8:
		var col: String = ["btn_red", "bk_orange", "bk_teal", "bk_panel", "btn_green", "bk_yellow"][k % 6]
		box(v, Vector3(0.09, 0.04, 0.07), f.call(Vector3(-0.6 + k * 0.17, 0.83, 0.14)), col, Vector3(-0.35, rot, 0)).owner = root
	for k in 3:
		cyl(v, 0.05, 0.05, 0.04, f.call(Vector3(0.35 + k * 0.17, 0.82, -0.02)), "brass", Vector3(-0.35, rot, 0) + Vector3(PI / 2.0, 0, 0), 8).owner = root
	# ЭЛТ: корпус, тёмный кинескоп; светящийся экран — в группе Screens (горит от генератора)
	box(v, Vector3(0.55, 0.48, 0.5), f.call(Vector3(-0.35, 1.05, -0.12)), "bk_panel", Vector3(0, rot, 0)).owner = root
	box(v, Vector3(0.42, 0.34, 0.02), f.call(Vector3(-0.35, 1.06, 0.135)), "bk_screen", Vector3(0, rot, 0)).owner = root
	box(scr, Vector3(0.38, 0.3, 0.01), f.call(Vector3(-0.35, 1.06, 0.15)), "scr_amber" if amber else "scr_green", Vector3(0, rot, 0)).owner = root
	_own(collider(v, Vector3(1.6, 1.3, 0.8), at + Vector3(0, 0.65, 0), rot), root)
	# кресло на колёсиках
	var c: Vector3 = f.call(Vector3(0.2, 0, 0.85))
	cyl(v, 0.03, 0.03, 0.4, c + Vector3(0, 0.2, 0), "bk_dark").owner = root
	box(v, Vector3(0.48, 0.08, 0.46), c + Vector3(0, 0.45, 0), "bk_orange", Vector3(0, rot, 0)).owner = root
	box(v, Vector3(0.48, 0.5, 0.08), f.call(Vector3(0.2, 0.72, 1.08)), "bk_orange", Vector3(0, rot, 0)).owner = root


## Магнитофонная стойка: шкаф с двумя бобинами за стеклом
func _reel_unit(v: Node, scr: Node, at: Vector3, rot: float) -> void:
	var b := Basis.from_euler(Vector3(0, rot, 0))
	box(v, Vector3(0.8, 1.45, 0.6), at + Vector3(0, 0.725, 0), "bk_panel", Vector3(0, rot, 0)).owner = root
	for k in 2:
		var rp := at + b * Vector3(-0.18 + k * 0.36, 1.08, 0.31)
		cyl(v, 0.16, 0.16, 0.03, rp, "bk_dark", Vector3(PI / 2.0, rot, 0), 16).owner = root
		cyl(v, 0.05, 0.05, 0.04, rp + b * Vector3(0, 0, 0.01), "brass", Vector3(PI / 2.0, rot, 0), 8).owner = root
	box(v, Vector3(0.7, 0.2, 0.02), at + b * Vector3(0, 0.55, 0.31), "bk_dark", Vector3(0, rot, 0)).owner = root
	box(scr, Vector3(0.08, 0.04, 0.01), at + b * Vector3(0.25, 0.7, 0.32), "btn_red", Vector3(0, rot, 0)).owner = root
	_own(collider(v, Vector3(0.8, 1.45, 0.6), at + Vector3(0, 0.725, 0), rot), root)


func _bk_control(v: Node, r: Rect2) -> void:
	var scr := v.get_node_or_null("Screens")
	if scr == null:
		scr = group(v, "Screens")
	# большое табло на северной стене: тёмное стекло, светящаяся сетка и контур района
	box(v, Vector3(6.4, 1.15, 0.1), Vector3(20, 0.75, r.position.y + 0.28), "bk_dark").owner = root
	box(v, Vector3(6.0, 0.95, 0.03), Vector3(20, 0.75, r.position.y + 0.35), "bk_screen").owner = root
	for k in 7:
		box(scr, Vector3(0.015, 0.9, 0.01), Vector3(17.3 + k * 0.9, 0.75, r.position.y + 0.37), "scr_green").owner = root
	for k in 4:
		box(scr, Vector3(5.9, 0.012, 0.01), Vector3(20, 0.38 + k * 0.25, r.position.y + 0.37), "scr_green").owner = root
	for p in [Vector2(18.1, 0.9), Vector2(19.3, 0.6), Vector2(21.4, 1.0), Vector2(22.2, 0.5), Vector2(20.4, 0.75)]:
		box(scr, Vector3(0.12, 0.12, 0.01), Vector3(p.x, p.y, r.position.y + 0.38), "scr_amber").owner = root
	var lb := Label3D.new()
	lb.text = "КОНТУР «ГОРИЗОНТ» · ОБЪЕКТОВ 14 · АКТИВНЫХ 0"
	lb.font_size = 36
	lb.pixel_size = 0.004
	lb.modulate = Color("8fe08a")
	lb.position = Vector3(20, 1.42, r.position.y + 0.36)
	fit_label(lb, 6.2, 0.3)
	scr.add_child(lb)
	lb.owner = root
	_own(collider(v, Vector3(6.4, 1.2, 0.3), Vector3(20, 0.6, r.position.y + 0.3)), root)
	# два ряда пультов лицом к табло
	for x in [15.5, 17.5, 19.5, 21.5]:
		_console(v, scr, Vector3(x, 0, 4.2), 0.0, x > 18.0)
	for x in [15.5, 17.5, 19.5]:
		_console(v, scr, Vector3(x, 0, 6.6), 0.0, x < 16.0)
	# магнитофонные стойки вдоль западной стены
	for z in [2.6, 3.5, 4.4]:
		_reel_unit(v, scr, Vector3(12.6, 0, z), PI / 2.0)
	# столик с дисковым телефоном и пепельницей
	box(v, Vector3(0.8, 0.05, 0.6), Vector3(13.4, 0.72, 8.6), "bk_beige").owner = root
	box(v, Vector3(0.3, 0.12, 0.22), Vector3(13.3, 0.8, 8.6), "bk_orange").owner = root
	cyl(v, 0.07, 0.07, 0.02, Vector3(13.3, 0.87, 8.62), "bk_panel", Vector3.ZERO, 12).owner = root
	_own(collider(v, Vector3(0.8, 0.8, 0.6), Vector3(13.4, 0.4, 8.6)), root)
	# северо-восточный угол обрушен: плиты, раздавленные пульты, висящие кабели
	_collapse(v, Vector3(25.8, 0, 3.6), Vector2(4.0, 4.4))
	box(v, Vector3(1.6, 0.4, 0.7), Vector3(24.6, 0.2, 6.4), "bk_beige", Vector3(0.2, 0.7, 0.4)).owner = root
	for k in 5:
		box(v, Vector3(0.025, randf_range(0.7, 1.2), 0.025), Vector3(24.0 + k * 0.5, 0.75, 5.8 + randf_range(-0.4, 0.4)), ["bk_orange", "bk_teal", "bk_black"][k % 3],
			Vector3(randf_range(-0.5, 0.5), 0, randf_range(-0.5, 0.5))).owner = root
	for k in 12:
		box(v, Vector3(0.3, 0.01, 0.4), Vector3(randf_range(13, 23), 0.02, randf_range(5, 9.8)), "paper", Vector3(0, randf() * TAU, 0)).owner = root
	for pt in [Vector3(17.5, 1.3, 4.6), Vector3(20.5, 1.3, 4.6), Vector3(16.5, 1.3, 7.0)]:
		var gl := _lamp(scr, "Glow", pt, Color("8fe08a"), 0.35, 2.5)
		gl.shadow_enabled = false


func _bk_barracks(v: Node, r: Rect2) -> void:
	for i in 3:
		var bx := 11.3 + i * 2.6
		box(v, Vector3(0.9, 0.08, 2.0), Vector3(bx, 0.45, 21.1), "bk_dark").owner = root
		box(v, Vector3(0.9, 0.08, 2.0), Vector3(bx, 1.3, 21.1), "bk_dark").owner = root
		box(v, Vector3(0.85, 0.15, 1.9), Vector3(bx, 0.55, 21.1), "cloth_sack").owner = root
		box(v, Vector3(0.85, 0.12, 1.9), Vector3(bx, 1.38, 21.1), "bk_teal").owner = root
		for c in [[-0.42, -0.95], [0.42, -0.95], [-0.42, 0.95], [0.42, 0.95]]:
			box(v, Vector3(0.05, 1.4, 0.05), Vector3(bx + c[0], 0.7, 21.1 + c[1]), "bk_dark").owner = root
		_own(collider(v, Vector3(0.9, 1.5, 2.0), Vector3(bx, 0.75, 21.1)), root)
	# шкафчики охраны у северной стены (справа от проёма)
	for i in 4:
		box(v, Vector3(0.62, 1.8, 0.5), Vector3(15.6 + i * 0.66, 0.9, 15.0), "bk_teal" if i % 2 else "bk_beige").owner = root
		box(v, Vector3(0.3, 0.05, 0.02), Vector3(15.6 + i * 0.66, 1.55, 15.26), "bk_dark").owner = root
	_own(collider(v, Vector3(2.7, 1.8, 0.5), Vector3(16.6, 0.9, 15.0)), root)
	# стол: карты, кружки, кассетный магнитофон
	box(v, Vector3(1.4, 0.05, 0.8), Vector3(12.2, 0.74, 17.6), "bk_beige").owner = root
	box(v, Vector3(0.5, 0.2, 0.15), Vector3(12.0, 0.87, 17.5), "bk_dark").owner = root
	for k in 2:
		cyl(v, 0.05, 0.05, 0.02, Vector3(11.88 + k * 0.24, 0.87, 17.58), "bk_panel", Vector3(PI / 2.0, 0, 0), 10).owner = root
	for k in 5:
		box(v, Vector3(0.06, 0.005, 0.09), Vector3(12.5 + randf_range(-0.2, 0.2), 0.77, 17.7 + randf_range(-0.2, 0.2)), "paper",
			Vector3(0, randf() * TAU, 0)).owner = root
	_own(collider(v, Vector3(1.4, 0.8, 0.8), Vector3(12.2, 0.4, 17.6)), root)
	# плакат по технике безопасности
	box(v, Vector3(0.7, 0.9, 0.02), Vector3(18.3, 0.9, 18.5), "paper", Vector3(0, PI / 2.0, 0)).owner = root
	# одна койка рухнула: верхний ярус на нижнем, лужа
	box(v, Vector3(0.9, 0.08, 2.0), Vector3(17.5, 0.6, 18.4), "bk_dark", Vector3(0.3, 0.6, 0.2)).owner = root
	box(v, Vector3(1.6, 0.01, 1.1), Vector3(16.8, 0.012, 17.2), "glass").owner = root


func _bk_generator(v: Node, r: Rect2) -> void:
	var scr := v.get_node("Screens")
	# дизель-генератор на раме, глушитель, бак
	box(v, Vector3(3.2, 1.3, 1.4), Vector3(25, 0.65, 20.8), "bk_dark").owner = root
	box(v, Vector3(3.3, 0.15, 1.5), Vector3(25, 0.07, 20.8), "bk_yellow").owner = root
	box(v, Vector3(1.0, 0.5, 1.2), Vector3(26.2, 1.55, 20.8), "bk_orange").owner = root
	cyl(v, 0.15, 0.15, 1.6, Vector3(23.6, 1.6, 21.3), "rust").owner = root
	cyl(v, 0.45, 0.45, 1.8, Vector3(21.2, 0.9, 21.2), "bk_teal").owner = root
	_own(collider(v, Vector3(4.6, 1.6, 1.6), Vector3(24.4, 0.8, 20.9)), root)
	# конденсаторные банки и щит с манометрами
	for k in 6:
		cyl(v, 0.16, 0.16, 0.9, Vector3(28.6, 0.45, 16.0 + k * 0.42), "bk_panel").owner = root
	_own(collider(v, Vector3(0.5, 1.0, 2.6), Vector3(28.6, 0.5, 17.05)), root)
	box(v, Vector3(1.8, 1.2, 0.2), Vector3(22.2, 0.8, 15.05), "bk_beige").owner = root
	for k in 3:
		cyl(v, 0.14, 0.14, 0.04, Vector3(21.6 + k * 0.6, 1.0, 15.17), "bk_panel", Vector3(PI / 2.0, 0, 0), 14).owner = root
		box(v, Vector3(0.02, 0.1, 0.01), Vector3(21.6 + k * 0.6, 1.03, 15.2), "bk_black", Vector3(0, 0, 0.6 - k * 0.4)).owner = root
	box(scr, Vector3(0.1, 0.05, 0.01), Vector3(22.8, 0.55, 15.17), "btn_green").owner = root
	_own(collider(v, Vector3(1.8, 1.2, 0.3), Vector3(22.2, 0.6, 15.05)), root)


func _bk_archive(v: Node, r: Rect2) -> void:
	# стеллажи с папками и полки с магнитной лентой
	for z in [5.0, 9.0, 16.0, 19.5]:
		box(v, Vector3(4.5, 2.0, 0.5), Vector3(36.8, 1.0, z), "bk_dark").owner = root
		for k in 9:
			box(v, Vector3(0.12, 0.32, 0.3), Vector3(34.9 + k * 0.45, 1.25, z), "paper" if z < 12 else "bk_beige").owner = root
			if z > 12:
				cyl(v, 0.14, 0.14, 0.03, Vector3(34.9 + k * 0.45, 0.6, z), "bk_black", Vector3(PI / 2.0, 0, 0), 12).owner = root
		_own(collider(v, Vector3(4.5, 2.0, 0.5), Vector3(36.8, 1.0, z)), root)
	# стол архивариуса с терминалом
	var scr := v.get_node("Screens")
	box(v, Vector3(1.4, 0.05, 0.7), Vector3(39.4, 0.74, 12.5), "bk_beige").owner = root
	box(v, Vector3(0.5, 0.45, 0.45), Vector3(39.5, 1.0, 12.5), "bk_panel").owner = root
	box(scr, Vector3(0.01, 0.3, 0.38), Vector3(39.24, 1.0, 12.5), "scr_amber").owner = root
	_own(collider(v, Vector3(1.4, 0.8, 0.7), Vector3(39.4, 0.4, 12.5)), root)
	for k in 8:
		box(v, Vector3(0.3, 0.01, 0.4), Vector3(randf_range(33, 40), 0.02, randf_range(10.5, 14.5)), "paper", Vector3(0, randf() * TAU, 0)).owner = root


# ======================================================================
# СУНГАР: торговый город на берегу большой реки (по снимку Сунтара: река
# по юго-восточному краю, дорога заходит с запада). Три района — три локации:
#   sungar          — ворота с платой и рынок, рыбная пристань;
#   sungar_center   — торговые ряды, «Счастливая лодка» (баржа-казино), контора «отдела ф. м.»;
#   sungar_quarter  — бараки, бар «Шалман», оружейная, круг для кулачных боёв.
# С карты мира попадаешь к воротам; дальше — улицами (выходы To*).
# ======================================================================
func _river_south(z_edge: float) -> void:
	# у воды и на воде лес не растёт
	_clear.append(Rect2(-60, z_edge - 1.5, 220, 80))
	var river := group(root, "River")
	river.set_meta("no_xray", true)
	_river_plane(river, str(root.get("location_id")), -70, 150, z_edge, z_edge + 44)
	_own(collider(river, Vector3(220, 1.5, 6), Vector3(42, 0.75, z_edge + 3.2)), root)


## Торговый лоток: прилавок к +z, навес, столбы. Продавец стоит с -z стороны.
func _stall(parent: Node, nm: String, pos: Vector3, rot: float, cloth := "cloth_red") -> Node3D:
	var s := Node3D.new()
	s.name = nm
	parent.add_child(s, true)
	s.owner = root
	s.position = pos
	s.rotation.y = rot
	box(s, Vector3(2.4, 0.85, 0.8), Vector3(0, 0.425, 0.2), "planks_old").owner = root
	for x in [-1.3, 1.3]:
		for z in [-0.9, 0.7]:
			cyl(s, 0.05, 0.05, 2.3, Vector3(x, 1.15, z), "log_dark").owner = root
	box(s, Vector3(3.0, 0.05, 2.2), Vector3(0, 2.32, -0.1), cloth, Vector3(-0.1, 0, 0)).owner = root
	# товар на прилавке
	for i in 3:
		box(s, Vector3(0.35, 0.22, 0.3), Vector3(-0.8 + i * 0.8, 0.96, 0.2), ["cloth_sack", "paper", "tin"][i]).owner = root
	_own(collider(s, Vector3(2.4, 1.0, 0.8), Vector3(0, 0.5, 0.2)), root)
	return s


## Вывеска с надписью над дверью или на столбах
func _signboard(parent: Node, text: String, pos: Vector3, rot: float, w := 3.4, col := Color("e8d8a8")) -> void:
	var b := Node3D.new()
	parent.add_child(b, true)
	b.owner = root
	b.position = pos
	b.rotation.y = rot
	box(b, Vector3(w, 0.7, 0.08), Vector3.ZERO, "planks_old").owner = root
	var l := Label3D.new()
	l.text = text
	l.font_size = 56
	l.pixel_size = 0.006
	l.modulate = col
	l.outline_size = 6
	l.position = Vector3(0, 0, 0.06)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fit_label(l, w, 0.7)
	b.add_child(l)
	l.owner = root


func _lamp_post(parent: Node, pos: Vector3, col := Color("ffc06a")) -> void:
	cyl(parent, 0.06, 0.08, 3.2, pos + Vector3(0, 1.6, 0), "metal_dark").owner = root
	box(parent, Vector3(0.3, 0.3, 0.3), pos + Vector3(0, 3.3, 0), "glass").owner = root
	var l := OmniLight3D.new()
	l.light_color = col
	l.light_energy = 0.9
	l.omni_range = 7.0
	l.position = pos + Vector3(0, 3.2, 0)
	l.add_to_group("night_lamps", true)
	parent.add_child(l)
	l.owner = root


## Бельевые верёвки во дворе бараков
func _laundry(parent: Node, a: Vector3, b: Vector3) -> void:
	for p in [a, b]:
		cyl(parent, 0.05, 0.05, 2.2, p + Vector3(0, 1.1, 0), "log_dark").owner = root
	var d := b - a
	box(parent, Vector3(0.02, 0.02, d.length()), (a + b) / 2.0 + Vector3(0, 2.0, 0), "rope_mat", Vector3(0, atan2(d.x, d.z), 0)).owner = root
	var cols := ["cloth_red", "cloth_sack", "paper", "cloth"]
	for i in 4:
		var t := 0.2 + i * 0.2
		box(parent, Vector3(0.5, 0.6, 0.02), a.lerp(b, t) + Vector3(0, 1.68, 0), cols[i], Vector3(0, atan2(d.x, d.z) + PI / 2.0, 0)).owner = root


