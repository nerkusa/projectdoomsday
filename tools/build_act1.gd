extends "res://tools/build_nakharro.gd"
## Генератор локаций первого акта: Кресты (живое поселение у реки) и
## Лагерь оборванцев (беженцы у старой лесопилки).
## Постройки — из tools/build_props.gd (как и в Нахарро).
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
			"stone_wall", "tire", "paper", "metal_roof", "glass", "paint_faded"]:
		M[n] = load(MAT_DIR + n + ".tres")
	_kresty()
	_camp()
	_encounter()
	_zaimka()
	_convoy()
	_ruin()


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
	var rect := Rect2(0, 0, 92, 78)
	_begin("kresty", "Кресты", rect, "res://scripts/locations/kresty.gd")
	var d := "ground_dirt"
	strip(null, Vector2(-4, 38), Vector2(96, 38), 3.0, d)
	strip(null, Vector2(47, 38), Vector2(47, 64), 2.2, d)
	strip(null, Vector2(47, 38), Vector2(47, 24), 2.0, d)
	strip(null, Vector2(64, 38), Vector2(72, 20), 1.6, d)
	road_segs.append([Vector2(41, 36), Vector2(53, 40), 3.5])  # площадь
	_meadow.append(Rect2(62, 6, 26, 14))  # выгон
	_meadow.append(Rect2(4, 28, 12, 7))  # погост
	_mud.append(Rect2(-10, 64.5, 112, 3.0))  # берег
	_clear.append(Rect2(14, 20, 76, 46))
	_clear.append(Rect2(80, 26, 14, 26))
	_clear.append(Rect2(60, 4, 30, 18))
	_clear.append(Rect2(-2, 24, 20, 30))
	_clear.append(Rect2(-10, 60, 112, 30))
	_no_edge.append(Rect2(-40, 63, 180, 35))
	_no_edge.append(Rect2(-14, 28, 14, 20))  # у въезда с запада лес реже — не закрывает героя
	_ground_for("kresty")
	# река: вода и невидимая стена по берегу
	var river := group(root, "River")
	river.set_meta("no_xray", true)
	var wtr := box(river, Vector3(160, 0.02, 30), Vector3(46, 0.035, 82.5), "water")
	wtr.owner = root
	_own(collider(river, Vector3(160, 1.5, 12), Vector3(46, 0.75, 73.5)), root)
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
	put(P.shed, vil, Vector3(86, 0, 44.5), -0.1)
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
	for p in [Vector3(20, 0, 60), Vector3(28, 0, 62), Vector3(76, 0, 60), Vector3(84, 0, 62), Vector3(88, 0, 58)]:
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
	var tbl: Node3D = root.get_node("Village/SquareTable")
	var s1 := _seat(tbl, -0.6, 1.0)
	var s2 := _seat(tbl, 0.5, -1.0)
	character(chars, "Drunk", "kr_drunk", s1[0], s1[1], {"dialog": "kr_drunk", "start_pose": "sit"})
	character(chars, "Granny", "villager_f", s2[0], s2[1], {"display_name": "Бабка Мотрёна", "dialog": "kr_rumors", "start_pose": "sit"})
	character(chars, "KrVillager1", "villager", Vector3(24, 0, 38.8), 1.4, {"display_name": "Крестовский мужик", "dialog": "kr_rumors",
		"patrol": PackedVector3Array([Vector3(24, 0, 38.8), Vector3(80, 0, 38.8)]), "patrol_wait": 5.0})
	character(chars, "KrVillager2", "villager_f", Vector3(64, 0, 49.5), 0.0, {"display_name": "Хозяйка", "dialog": "kr_rumors",
		"patrol": PackedVector3Array([Vector3(64, 0, 49.5), Vector3(47, 0, 49.5), Vector3(47, 0, 58)]), "patrol_wait": 4.0})
	character(chars, "KrKid", "kid", Vector3(44, 0, 44), 0.5, {"display_name": "Мальчишка", "dialog": "kr_rumors",
		"patrol": PackedVector3Array([Vector3(44, 0, 44), Vector3(40, 0, 40), Vector3(45, 0, 38.5)]), "patrol_wait": 2.0})
	# псы на выгоне: появляются, когда староста попросит
	for i in 3:
		character(chars, "Dog%d" % (i + 1), "wild_dog", Vector3(72 + i * 3.5, 0, 9 + (i % 2) * 3.0), randf() * TAU,
			{"hostile": true, "aggro_radius": 7.0, "squad": "dogs", "groups": ["kr_dogs"]})

	var items := group(root, "Items")
	_exit(items, "WestExit", "Дорога на запад", Vector3(1.0, 0, 38), Vector3(1.6, 2.2, 5.0))
	_exit(items, "EastExit", "Дорога на восток", Vector3(91.0, 0, 38), Vector3(1.6, 2.2, 5.0))
	_use(items, "NetTracks", "Следы у сушилки", Vector3(62.6, 0, 62.4), Vector3(1.6, 0.4, 1.4))
	_use(items, "Cemetery", "Погост", Vector3(10, 0, 31.2), Vector3(8.0, 1.5, 4.0))
	item(items, P.item_herbs, "Take_Herbs", Vector3(26.3, 0, 60.5))
	_spawn("Start", Vector3(4.5, 0, 38))
	_spawn("Road", Vector3(4.5, 0, 38))
	marker(root, "MarkHead", Vector3(47, 0, 25.5), "Староста")
	marker(root, "MarkBrew", Vector3(33, 0, 46.5), "Пивоварня")
	marker(root, "MarkRiver", Vector3(47, 0, 64), "Мостки")
	marker(root, "MarkPasture", Vector3(76, 0, 12), "Выгон")
	_dress(Rect2(4, 22, 86, 44), 1200)
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
	_woods(800)
	var chars := group(root, "Characters")
	character(chars, "Hermit", "hermit", Vector3(27.5, 0, 29.5), 0.3, {"dialog": "hermit", "armed": true})
	character(chars, "Chuchuna", "chuchuna", Vector3(44, 0, 2.5), -PI / 2.0, {"hostile": true, "aggro_radius": 11.0, "groups": ["chuchuna"]})
	var items := group(root, "Items")
	_exit(items, "WestExit", "Тропа обратно", Vector3(1.0, 0, 30), Vector3(1.6, 2.2, 5.0))
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
	# заваренный люк бункера
	cyl(vil, 0.9, 0.9, 0.25, Vector3(40, 0.12, 22.5), "metal_dark", Vector3.ZERO, 16).owner = root
	box(vil, Vector3(1.6, 0.06, 0.12), Vector3(40, 0.27, 22.5), "rust").owner = root
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
	_use(items, "Hatch", "Люк", Vector3(40, 0, 22.5), Vector3(1.8, 0.5, 1.8))
	_use(items, "ContainerUse", "Контейнер", Vector3(27.5, 0, 30.5), Vector3(1.4, 2.0, 2.0))
	_use(items, "Papers", "Бумаги", Vector3(32, 0, 22.5), Vector3(3.0, 0.4, 2.0))
	_use(items, "Burnt", "Пепелище", Vector3(9, 0, 45), Vector3(5.0, 1.0, 5.0))
	_spawn("Start", Vector3(4.5, 0, 27))
	_spawn("Road", Vector3(4.5, 0, 27))
	_dress(Rect2(14, 6, 42, 40), 500)
	_finish("ruin")
