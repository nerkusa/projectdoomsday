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
	for n in ["cloth_sack", "cloth_red", "rope_mat", "rust", "metal_dark", "tin", "hay", "bark_dark", "planks_old"]:
		M[n] = load(MAT_DIR + n + ".tres")
	_kresty()
	_camp()


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
	_clear.append(Rect2(60, 4, 30, 18))
	_clear.append(Rect2(-2, 24, 20, 30))
	_clear.append(Rect2(-10, 60, 112, 30))
	_no_edge.append(Rect2(-40, 63, 180, 35))
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
	character(chars, "Thug2", "camp_thug2", Vector3(15.5, 0, 27.8), -PI / 2.0 - 0.4, {"dialog": "camp_thug", "squad": "thugs", "armed": true})
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
