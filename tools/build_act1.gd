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
			"stone_wall", "tire", "paper", "metal_roof", "glass", "paint_faded", "paint_white", "cloth", "rope_mat", "water", "log_dark", "log_weathered", "metal_dark", "ground_dirt"]:
		M[n] = load(MAT_DIR + n + ".tres")
	_kresty()
	_camp()
	_encounter()
	_zaimka()
	_convoy()
	_ruin()
	_cellar()
	_bunker()
	_sungar()
	_sungar_center()
	_sungar_quarter()


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
	character(chars, "KrOld", "kr_old", Vector3(38.6, 0, 62.4), 0.2, {"dialog": "kr_old"})
	var tbl: Node3D = root.get_node("Village/SquareTable")
	var s1 := _seat(tbl, -0.6, 1.0)
	var s2 := _seat(tbl, 0.5, -1.0)
	character(chars, "Drunk", "kr_drunk", s1[0], s1[1], {"dialog": "kr_drunk", "start_pose": "sit"})
	character(chars, "Granny", "villager_f", s2[0], s2[1], {"display_name": "Бабка Мотрёна", "dialog": "kr_rumors", "start_pose": "sit"})
	character(chars, "KrVillager1", "villager", Vector3(24, 0, 38.8), 1.4, {"display_name": "Крестовский мужик", "dialog": "kr_rumors",
		"patrol": PackedVector3Array([Vector3(24, 0, 38.8), Vector3(80, 0, 38.8)]), "patrol_wait": 5.0})
	character(chars, "KrVillager2", "villager_f", Vector3(64, 0, 49.5), 0.0, {"display_name": "Хозяйка", "dialog": "kr_rumors",
		"patrol": PackedVector3Array([Vector3(64, 0, 49.5), Vector3(47, 0, 49.5), Vector3(47, 0, 58)]), "patrol_wait": 4.0})
	character(chars, "KrKid", "kid", Vector3(44, 0, 44), 0.5, {"display_name": "Мальчишка Уйгун", "dialog": "kr_kid",
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


# ---------------- бункер под Сытыганом ----------------
func _bunker() -> void:
	var rect := Rect2(0, 0, 34, 22)
	seed(1414)
	root = Node3D.new()
	root.name = "RuinBunker"
	root.set_script(load("res://scripts/locations/ruin_bunker.gd"))
	root.set("location_id", "ruin_bunker")
	root.set("title", "Бункер под Сытыганом")
	root.set("map_rect", rect)
	root.set("camera_start", Vector3(4, 0, 4))
	_dark_env(Color("2a2a30"), 0.18)
	var v := group(root, "Village")
	_floor(v, rect.grow(0.3), "stone")
	# комнаты: шахта (вход), коридор, казарма, генераторная, архив
	var shaft := Rect2(1, 1, 6, 6)
	var corr := Rect2(7, 2.5, 20, 3)
	var bar := Rect2(9, 7, 9, 7)
	var gen := Rect2(19, 7, 7, 6)
	var arch := Rect2(27, 1, 6, 12)
	_room_walls(v, shaft, 1.3, "stone_wall", [[Vector2(7, 4), 2.0]])
	_room_walls(v, corr, 1.3, "stone_wall", [[Vector2(7, 4), 2.0], [Vector2(13.5, 5.5), 1.6], [Vector2(22.5, 5.5), 1.6], [Vector2(27, 4), 1.6]])
	_room_walls(v, bar, 1.3, "stone_wall", [[Vector2(13.5, 7), 1.6]])
	_room_walls(v, gen, 1.3, "stone_wall", [[Vector2(22.5, 7), 1.6]])
	_room_walls(v, arch, 1.3, "stone_wall", [[Vector2(27, 4), 1.6]])
	# дверь архива — электрозамок: коллизия, пока не открыта
	var door := Node3D.new()
	door.name = "ArchiveDoor"
	v.add_child(door)
	door.owner = root
	box(door, Vector3(0.2, 1.3, 1.6), Vector3(27, 0.65, 4), "metal_dark").owner = root
	var dc := collider(door, Vector3(0.3, 2.2, 1.6), Vector3(27, 1.1, 4))
	_own(dc, root)
	# завал под шахтой и свет сверху
	for i in 6:
		put(P.rock_small, v, Vector3(randf_range(2, 5), 0, randf_range(2, 5)), randf() * TAU, "", randf_range(0.8, 1.4))
	_lamp(v, "ShaftLight", Vector3(3.5, 3.5, 3.5), Color("c8c0a8"), 1.2, 6.0)
	# аварийные красные лампы
	var em := group(v, "Emergency")
	for p in [Vector3(10, 2.2, 4), Vector3(17, 2.2, 4), Vector3(24, 2.2, 4), Vector3(13.5, 2.2, 10.5), Vector3(22.5, 2.2, 10)]:
		_lamp(em, "Red", p, Color("ff3322"), 0.9, 6.5)
	# основной свет (включается генератором)
	var main_l := group(v, "MainLights")
	for p in [Vector3(4, 2.4, 4), Vector3(12, 2.4, 4), Vector3(20, 2.4, 4), Vector3(13.5, 2.4, 10.5), Vector3(22.5, 2.4, 10), Vector3(30, 2.4, 7)]:
		_lamp(main_l, "Lamp", p, Color("e8f0ff"), 1.6, 8.0, false)
	# казарма: двухъярусные койки и шкафчики
	for i in 3:
		var bx := 10.5 + i * 2.6
		box(v, Vector3(0.9, 0.08, 2.0), Vector3(bx, 0.45, 12.6), "metal_dark").owner = root
		box(v, Vector3(0.9, 0.08, 2.0), Vector3(bx, 1.35, 12.6), "metal_dark").owner = root
		box(v, Vector3(0.85, 0.15, 1.9), Vector3(bx, 0.55, 12.6), "cloth_sack").owner = root
		_own(collider(v, Vector3(0.9, 1.5, 2.0), Vector3(bx, 0.75, 12.6)), root)
	for i in 4:
		box(v, Vector3(0.6, 1.9, 0.5), Vector3(10.0 + i * 0.65, 0.95, 7.45), "paint_faded").owner = root
	_own(collider(v, Vector3(2.6, 1.9, 0.5), Vector3(11.0, 0.95, 7.45)), root)
	# генераторная
	box(v, Vector3(2.4, 1.4, 1.4), Vector3(22.5, 0.7, 11.6), "metal_dark").owner = root
	cyl(v, 0.35, 0.35, 1.6, Vector3(21.0, 0.8, 11.6), "rust").owner = root
	_own(collider(v, Vector3(3.6, 1.5, 1.5), Vector3(22.0, 0.75, 11.6)), root)
	# архив: стеллажи с папками
	for z in [2.2, 5.6, 9.0, 11.8]:
		box(v, Vector3(4.5, 2.0, 0.5), Vector3(30.5, 1.0, z), "metal_dark").owner = root
		for k in 9:
			box(v, Vector3(0.12, 0.32, 0.3), Vector3(28.6 + k * 0.45, 1.25, z), "paper").owner = root
		_own(collider(v, Vector3(4.5, 2.0, 0.5), Vector3(30.5, 1.0, z)), root)
	for i in 10:
		box(v, Vector3(0.3, 0.01, 0.4), Vector3(randf_range(8, 26), 0.02, randf_range(3, 5)), "paper", Vector3(0, randf() * TAU, 0)).owner = root
	var chars := group(root, "Characters")
	character(chars, "DeadCleaner", "cleaner_dead", Vector3(15.5, 0, 9.5), 0.6, {"start_dead": true})
	character(chars, "Squatter1", "ruin_looter", Vector3(12.5, 0, 10.5), -0.8, {"hostile": true, "aggro_radius": 7.0, "squad": "squat"})
	character(chars, "Squatter2", "ruin_looter_gun", Vector3(16.0, 0, 11.5), -1.4, {"hostile": true, "aggro_radius": 7.0, "squad": "squat"})
	var items := group(root, "Items")
	var up := _use(items, "UpRope", "Верёвка наверх", Vector3(3.2, 0, 3.2), Vector3(1.0, 2.4, 1.0))
	cyl(up, 0.03, 0.03, 3.6, Vector3(0, 1.8, 0), "rope_mat").owner = root
	_use(items, "Generator", "Генератор", Vector3(22.5, 0, 10.4), Vector3(2.4, 1.6, 1.2))
	_use(items, "DoorLock", "Электрозамок", Vector3(26.4, 0, 4.0), Vector3(0.8, 1.8, 1.6))
	_use(items, "Lockers", "Шкафчики", Vector3(11.0, 0, 8.2), Vector3(2.6, 1.8, 0.8))
	_use(items, "Files", "Шкаф с делами", Vector3(30.5, 0, 6.5), Vector3(3.5, 2.0, 1.0))
	_use(items, "Registry", "Ведомость", Vector3(30.5, 0, 10.2), Vector3(3.5, 2.0, 1.0))
	_spawn("Start", Vector3(3.8, 0, 4.6))
	_spawn("Down", Vector3(3.8, 0, 4.6))
	_finish("ruin_bunker")


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
	box(river, Vector3(220, 0.02, 44), Vector3(42, 0.035, z_edge + 22), "water").owner = root
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
	l.width = w / 0.006
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


func _sungar() -> void:
	var rect := Rect2(0, 0, 84, 62)
	_begin("sungar", "Сунгар · ворота и рынок", rect, "res://scripts/locations/sungar.gd")
	var d := "ground_dirt"
	strip(null, Vector2(-6, 30), Vector2(90, 30), 3.4, d)
	strip(null, Vector2(40, 30), Vector2(40, 56), 2.0, d)
	road_segs.append([Vector2(-6, 30), Vector2(90, 30), 2.6])
	road_segs.append([Vector2(34, 30), Vector2(56, 30), 7.5])  # рыночная площадь
	road_segs.append([Vector2(40, 30), Vector2(40, 55), 1.6])
	_mud.append(Rect2(-10, 54, 110, 4))
	_mud.append(Rect2(30, 42, 22, 8))
	_clear.append(Rect2(10, 2, 72, 54))
	_clear.append(Rect2(-6, 24, 18, 12))
	_no_edge.append(Rect2(-40, 55, 180, 40))
	_ground_for("sungar")
	_river_south(58.0)
	var vil := group(root, "Village")
	# стена с воротами: частокол по x = 12, проход — дорога
	for z in [4.0, 8.0, 12.0, 16.0, 20.0, 24.0, 36.0, 40.0, 44.0, 48.0, 52.0]:
		put(P.palisade, vil, Vector3(12, 0, z), PI / 2.0)
	_own(collider(vil, Vector3(0.7, 2.6, 26.5), Vector3(12, 1.3, 13.0)), root)
	_own(collider(vil, Vector3(0.7, 2.6, 25.0), Vector3(12, 1.3, 46.0)), root)
	# у самой воды — обрыв и камни: мимо стены здесь не пройти, только по берегу под обрывом
	for z in [55.4, 56.8]:
		put(P.rock_big, vil, Vector3(12.2, 0, z), randf() * TAU, "", 1.2)
	_own(collider(vil, Vector3(1.6, 2.0, 4.0), Vector3(12, 1.0, 56.5)), root)
	put(P.tower, vil, Vector3(12.4, 0, 25.6), 0.0, "GateTowerN")
	put(P.tower, vil, Vector3(12.4, 0, 34.4), 0.0, "GateTowerS")
	box(vil, Vector3(0.14, 0.14, 6.4), Vector3(13.2, 1.05, 30), "paint_white").owner = root
	for zz in [27.0, 33.0]:
		cyl(vil, 0.09, 0.09, 1.2, Vector3(13.2, 0.6, zz), "metal_dark").owner = root
	_signboard(vil, "СУНГАР", Vector3(10.6, 4.2, 30), -PI / 2.0, 3.6)
	put(P.shed, vil, Vector3(16.5, 0, 23.5), PI / 2.0, "GuardBooth")
	# дома вокруг
	put(P.izba_long, vil, Vector3(22, 0, 12), 0.02, "Izba1")
	put(P.barn, vil, Vector3(36, 0, 10), 0.0, "Warehouse")
	put(P.izba_tall, vil, Vector3(52, 0, 11), -0.02, "Izba2")
	put(P.izba, vil, Vector3(64, 0, 12), 0.03, "Izba3")
	put(P.izba_long, vil, Vector3(76, 0, 13), 0.0, "Izba4")
	put(P.izba_small, vil, Vector3(22, 0, 46), PI, "Izba5")
	put(P.shed, vil, Vector3(66, 0, 45), PI)
	put(P.izba, vil, Vector3(76, 0, 46), PI, "Izba6")
	# рынок: два ряда лотков
	var mk := group(vil, "Market")
	var cl := ["cloth_red", "cloth_sack", "cloth_red", "cloth_sack"]
	var i := 0
	for x in [34.0, 41.0, 48.0, 55.0]:
		_stall(mk, "StallN%d" % i, Vector3(x, 0, 22.5), 0.0, cl[i % 4])
		i += 1
	for x in [34.0, 41.0, 48.0]:
		_stall(mk, "StallS%d" % i, Vector3(x, 0, 37.5), PI, cl[(i + 1) % 4])
		i += 1
	# рыбная пристань: мостки в реку, лодки, сушилки
	for k in 10:
		box(vil, Vector3(1.6, 0.08, 0.6), Vector3(40, 0.12, 55.2 + k * 0.65), "planks_old").owner = root
	for x in [39.0, 41.0]:
		for z in [57.0, 60.0]:
			cyl(vil, 0.07, 0.07, 1.0, Vector3(x, 0.1, z), "log_dark").owner = root
	_boat(vil, Vector3(37, 0, 59.5), 0.4)
	_boat(vil, Vector3(43.5, 0, 60.2), -0.3)
	_net_rack(vil, Vector3(32, 0, 53), 0.1)
	_net_rack(vil, Vector3(48, 0, 53.2), -0.1)
	var det := group(root, "Yard")
	for dd in [["crates", Vector3(30, 0, 25)], ["crates", Vector3(31, 0, 25.6)], ["barrel", Vector3(58, 0, 24)], ["barrel", Vector3(58.8, 0, 24.6)],
			["cart", Vector3(60, 0, 35)], ["crates", Vector3(44, 0, 41.5)], ["barrel", Vector3(36, 0, 52)], ["crates", Vector3(70, 0, 34)],
			["hay_bale", Vector3(20, 0, 34.5)], ["cart", Vector3(26, 0, 34.8)], ["barrel", Vector3(18, 0, 26)], ["junk", Vector3(70, 0, 52)]]:
		put(P[dd[0]], det, dd[1], randf() * TAU)
	for p in [Vector3(28, 0, 27.5), Vector3(52, 0, 27.5), Vector3(28, 0, 32.5), Vector3(62, 0, 32.5), Vector3(40, 0, 50)]:
		_lamp_post(vil, p)
	_woods(500)
	var chars := group(root, "Characters")
	character(chars, "GateGuard", "sg_guard", Vector3(14.4, 0, 28.2), -PI / 2.0, {"display_name": "Стражник Уйгулаан", "dialog": "sg_guard", "armed": true})
	character(chars, "GateGuard2", "sg_guard", Vector3(14.2, 0, 32.4), -PI / 2.0 + 0.3, {"display_name": "Стражник", "armed": true})
	character(chars, "MarketBoss", "sg_market_boss", Vector3(44, 0, 29.5), 0.3, {"dialog": "sg_market_boss",
		"patrol": PackedVector3Array([Vector3(44, 0, 29.5), Vector3(50, 0, 30.5), Vector3(38, 0, 31)]), "patrol_wait": 7.0})
	character(chars, "Butcher", "sg_butcher", Vector3(55, 0, 21.4), 0.0, {"dialog": "sg_butcher"})
	character(chars, "Fishwife", "sg_fishwife", Vector3(42.2, 0, 53.8), PI * 0.85, {"dialog": "sg_fishwife"})
	character(chars, "Seller1", "villager_f", Vector3(34, 0, 21.4), 0.0, {"display_name": "Торговка зеленью"})
	character(chars, "Seller2", "villager", Vector3(41, 0, 21.4), 0.0, {"display_name": "Скорняк"})
	character(chars, "Seller3", "villager_f", Vector3(41, 0, 38.6), PI, {"display_name": "Торговка соленьями"})
	character(chars, "Shopper1", "villager", Vector3(36, 0, 30), 1.0, {"display_name": "Покупатель",
		"patrol": PackedVector3Array([Vector3(36, 0, 30), Vector3(52, 0, 29), Vector3(47, 0, 33)]), "patrol_wait": 4.0})
	character(chars, "Shopper2", "villager_f", Vector3(50, 0, 32), -1.0, {"display_name": "Горожанка",
		"patrol": PackedVector3Array([Vector3(50, 0, 32), Vector3(33, 0, 31), Vector3(40, 0, 45)]), "patrol_wait": 5.0})
	character(chars, "Porter", "villager", Vector3(30, 0, 26), 0.0, {"display_name": "Грузчик",
		"patrol": PackedVector3Array([Vector3(30, 0, 26), Vector3(40, 0, 52)]), "patrol_wait": 6.0})
	var items := group(root, "Items")
	_exit(items, "WestExit", "Дорога из города", Vector3(1.0, 0, 30), Vector3(1.6, 2.2, 5.0))
	_exit(items, "ToCenter", "В центр города", Vector3(83.0, 0, 30), Vector3(1.6, 2.2, 5.0))
	_use(items, "BankPath", "Берег под обрывом", Vector3(9.0, 0, 55.6), Vector3(1.6, 1.2, 1.6))
	var k := 1
	for sp in [Vector3(34, 0, 23.4), Vector3(41, 0, 23.4), Vector3(48, 0, 23.4), Vector3(55, 0, 23.4)]:
		_use(items, "Stall%d" % k, "Весы на прилавке", sp, Vector3(2.2, 1.2, 1.2))
		k += 1
	_spawn("Start", Vector3(4.5, 0, 30))
	_spawn("Road", Vector3(4.5, 0, 30))
	_spawn("FromCenter", Vector3(79, 0, 30))
	_spawn("Bank", Vector3(17, 0, 52.5))
	marker(root, "MarkGate", Vector3(13, 0, 30), "Ворота")
	marker(root, "MarkMarket", Vector3(44, 0, 30), "Рынок")
	marker(root, "MarkPier", Vector3(40, 0, 56), "Пристань")
	_dress(Rect2(12, 4, 70, 50), 500)
	_finish("sungar")


## Баржа-казино «Счастливая лодка» у берега
func _barge(parent: Node, pos: Vector3) -> void:
	var b := Node3D.new()
	b.name = "LuckyBoat"
	parent.add_child(b, true)
	b.owner = root
	b.position = pos
	box(b, Vector3(24, 1.8, 8), Vector3(0, 0.2, 0), "rust").owner = root
	box(b, Vector3(23.4, 0.14, 7.4), Vector3(0, 1.16, 0), "planks_old").owner = root
	box(b, Vector3(14, 2.6, 5.4), Vector3(-1.5, 2.5, 0), "paint_faded").owner = root
	box(b, Vector3(14.6, 0.16, 6.0), Vector3(-1.5, 3.86, 0), "metal_roof").owner = root
	for x in [-7.0, -4.0, -1.0, 2.0, 5.0]:
		box(b, Vector3(1.4, 1.0, 0.06), Vector3(x + 0.0, 2.7, -2.72), "glass").owner = root
	# вывеска и гирлянда — видно издалека, особенно ночью
	var l := Label3D.new()
	l.text = "СЧАСТЛИВАЯ ЛОДКА"
	l.font_size = 72
	l.pixel_size = 0.009
	l.modulate = Color("ff5a3a")
	l.outline_size = 10
	l.position = Vector3(-1.5, 4.6, -2.0)
	l.rotation.y = PI
	l.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	b.add_child(l)
	l.owner = root
	for x in range(-8, 6, 2):
		var lamp := OmniLight3D.new()
		lamp.light_color = Color("ffb04a") if x % 4 == 0 else Color("ff4a4a")
		lamp.light_energy = 0.7
		lamp.omni_range = 4.0
		lamp.position = Vector3(x, 4.0, -3.0)
		b.add_child(lamp)
		lamp.owner = root
		box(b, Vector3(0.12, 0.12, 0.12), Vector3(x, 4.0, -3.0), "glass").owner = root
	cyl(b, 0.12, 0.14, 5.0, Vector3(8, 3.6, 0), "metal_dark").owner = root


func _sungar_center() -> void:
	var rect := Rect2(0, 0, 84, 62)
	_begin("sungar_center", "Сунгар · центр", rect, "res://scripts/locations/sungar_center.gd")
	var d := "ground_dirt"
	strip(null, Vector2(-6, 30), Vector2(90, 30), 3.6, d)
	strip(null, Vector2(64, 30), Vector2(88, 14), 2.4, d)
	strip(null, Vector2(38, 30), Vector2(38, 56), 2.2, d)
	road_segs.append([Vector2(-6, 30), Vector2(90, 30), 3.0])
	road_segs.append([Vector2(30, 34), Vector2(50, 42), 6.5])  # площадь
	road_segs.append([Vector2(64, 30), Vector2(88, 14), 1.8])
	road_segs.append([Vector2(38, 30), Vector2(38, 55), 1.8])
	_mud.append(Rect2(-10, 54, 110, 4))
	_clear.append(Rect2(4, 4, 78, 52))
	_no_edge.append(Rect2(-40, 55, 180, 40))
	_ground_for("sungar_center")
	_river_south(57.0)
	var vil := group(root, "Village")
	# торговые ряды вдоль улицы
	var rows := group(vil, "TradeRows")
	var cl := ["cloth_sack", "cloth_red", "cloth_sack", "cloth_red", "cloth_sack"]
	var i := 0
	for x in [18.0, 26.0, 34.0, 42.0, 50.0]:
		_stall(rows, "Row%d" % i, Vector3(x, 0, 23.0), 0.0, cl[i])
		i += 1
	_signboard(vil, "ТОРГОВЫЕ РЯДЫ", Vector3(34, 3.2, 21.4), 0.0, 5.0)
	put(P.izba_long, vil, Vector3(22, 0, 12), 0.0, "Izba1")
	put(P.hall, vil, Vector3(40, 0, 11), 0.0, "HouseOfCulture")
	put(P.izba_tall, vil, Vector3(76, 0, 40), PI, "Izba2")
	put(P.izba, vil, Vector3(14, 0, 44), PI, "Izba3")
	# контора «отдела ф. м.» — кирпичная, с вывеской
	_block(vil, "Office", Vector3(64, 0, 17.5), Vector3(11, 4.6, 7))
	_signboard(vil, "КОНТОРА · ОТДЕЛ Ф. М.", Vector3(64, 3.9, 21.1), 0.0, 5.2, Color("d8dce8"))
	# площадь: памятник «мужику в беретке» — тому, что на купюрах
	var mon := group(vil, "Monument")
	mon.position = Vector3(40, 0, 39)
	box(mon, Vector3(1.6, 1.4, 1.6), Vector3(0, 0.7, 0), "stone_wall").owner = root
	cyl(mon, 0.42, 0.5, 1.5, Vector3(0, 2.15, 0), "metal_dark").owner = root
	cyl(mon, 0.24, 0.24, 0.36, Vector3(0, 3.1, 0), "metal_dark").owner = root
	cyl(mon, 0.32, 0.32, 0.08, Vector3(0.05, 3.32, 0), "metal_dark", Vector3(0, 0, 0.2)).owner = root
	_own(collider(mon, Vector3(1.6, 3.5, 1.6), Vector3(0, 1.7, 0)), root)
	for b in [Vector3(36.5, 0, 41.5), Vector3(43.5, 0, 41.5)]:
		put(P.bench, vil, b, 0.0)
	# «Счастливая лодка» и сходни
	_barge(vil, Vector3(38, 0, 62.5))
	for k in 6:
		box(vil, Vector3(1.6, 0.08, 0.7), Vector3(38, 0.14 + k * 0.17, 54.6 + k * 0.7), "planks_old").owner = root
	put(P.table, vil, Vector3(46, 0, 49.2), 0.0, "DiceTable")
	put(P.barrel, vil, Vector3(30, 0, 52), 0.0)
	put(P.barrel, vil, Vector3(30.8, 0, 52.6), 0.0)
	var det := group(root, "Yard")
	for dd in [["crates", Vector3(56, 0, 26)], ["cart", Vector3(10, 0, 26)], ["crates", Vector3(58, 0, 34)], ["barrel", Vector3(70, 0, 24)],
			["crates", Vector3(12, 0, 35)], ["junk", Vector3(74, 0, 50)], ["barrel", Vector3(52, 0, 46)]]:
		put(P[dd[0]], det, dd[1], randf() * TAU)
	for p in [Vector3(30, 0, 33), Vector3(50, 0, 33), Vector3(36, 0, 50), Vector3(58, 0, 27.5), Vector3(70, 0, 27.5), Vector3(20, 0, 33)]:
		_lamp_post(vil, p)
	_woods(400)
	var chars := group(root, "Characters")
	character(chars, "Merchant", "sg_merchant", Vector3(26, 0, 22.0), 0.0, {"dialog": "sg_merchant"})
	character(chars, "Rival", "sg_rival", Vector3(42, 0, 22.0), 0.0, {"dialog": "sg_rival"})
	character(chars, "RowSeller", "villager", Vector3(18, 0, 22.0), 0.0, {"display_name": "Лоточник"})
	character(chars, "RowSeller2", "villager_f", Vector3(50, 0, 22.0), 0.0, {"display_name": "Торговка тканями"})
	character(chars, "Hostess", "sg_hostess", Vector3(35.8, 0, 52.6), PI, {"dialog": "sg_hostess"})
	character(chars, "Dealer", "sg_dealer", Vector3(46, 0, 48.2), 0.0, {"dialog": "sg_dealer"})
	character(chars, "Clerk", "sg_clerk", Vector3(62.8, 0, 22.4), 0.0, {"dialog": "sg_clerk"})
	character(chars, "OfficeGuard", "sg_office_guard", Vector3(66.6, 0, 22.6), 0.2, {"display_name": "Охранник конторы", "armed": true})
	character(chars, "Gambler1", "villager", Vector3(44.6, 0, 50.6), PI, {"display_name": "Игрок"})
	character(chars, "Walker1", "villager_f", Vector3(30, 0, 30), 1.2, {"display_name": "Горожанка",
		"patrol": PackedVector3Array([Vector3(30, 0, 30), Vector3(60, 0, 31), Vector3(40, 0, 44)]), "patrol_wait": 5.0})
	character(chars, "Walker2", "villager", Vector3(54, 0, 36), -1.2, {"display_name": "Горожанин",
		"patrol": PackedVector3Array([Vector3(54, 0, 36), Vector3(16, 0, 31), Vector3(38, 0, 52)]), "patrol_wait": 6.0})
	var items := group(root, "Items")
	_exit(items, "ToGate", "К воротам и рынку", Vector3(1.0, 0, 30), Vector3(1.6, 2.2, 5.0))
	_exit(items, "ToQuarter", "В жилой квартал", Vector3(83.0, 0, 14.5), Vector3(1.6, 2.2, 5.0))
	_use(items, "OfficeWindow", "Окно конторы", Vector3(58.2, 0, 16.0), Vector3(0.8, 2.0, 2.2))
	_use(items, "Monument", "Памятник", Vector3(40, 0, 37.4), Vector3(1.8, 3.4, 1.8))
	_spawn("Start", Vector3(4.5, 0, 30))
	_spawn("FromGate", Vector3(4.5, 0, 30))
	_spawn("FromQuarter", Vector3(79, 0, 16.5))
	marker(root, "MarkRows", Vector3(34, 0, 23), "Торговые ряды")
	marker(root, "MarkBoat", Vector3(38, 0, 56), "«Счастливая лодка»")
	marker(root, "MarkOffice", Vector3(64, 0, 17.5), "Контора")
	_dress(Rect2(4, 4, 78, 50), 400)
	_finish("sungar_center")


func _sungar_quarter() -> void:
	var rect := Rect2(0, 0, 76, 60)
	_begin("sungar_quarter", "Сунгар · жилой квартал", rect, "res://scripts/locations/sungar_quarter.gd")
	var d := "ground_dirt"
	strip(null, Vector2(-6, 40), Vector2(80, 40), 3.0, d)
	road_segs.append([Vector2(-6, 40), Vector2(80, 40), 2.4])
	road_segs.append([Vector2(14, 20), Vector2(60, 20), 3.0])  # двор за бараками
	_mud.append(Rect2(10, 14, 50, 10))
	_mud.append(Rect2(40, 42, 20, 6))
	_clear.append(Rect2(4, 6, 68, 50))
	_ground_for("sungar_quarter")
	var vil := group(root, "Village")
	put(P.izba_long, vil, Vector3(14, 0, 31), 0.0, "Barrack1")
	put(P.izba_long, vil, Vector3(28, 0, 31), 0.02, "Barrack2")
	put(P.izba_long, vil, Vector3(42, 0, 31), -0.02, "GuideBarrack")
	put(P.izba_tall, vil, Vector3(58, 0, 31), 0.0, "Shalman")
	_signboard(vil, "ШАЛМАН", Vector3(58, 3.6, 33.8), 0.0, 3.0, Color("ffcf7a"))
	put(P.workshop, vil, Vector3(16, 0, 51), PI, "Gunsmith")
	_signboard(vil, "ОРУЖЕЙНАЯ", Vector3(16, 3.2, 48.2), PI, 3.6, Color("c8d0d8"))
	put(P.izba_long, vil, Vector3(32, 0, 50), PI, "Barrack3")
	put(P.izba_long, vil, Vector3(46, 0, 50), PI + 0.02, "Barrack4")
	put(P.shed, vil, Vector3(62, 0, 52), PI)
	for t in [Vector3(54, 0, 37.4), Vector3(61.5, 0, 37.2)]:
		put(P.table, vil, t, 0.1)
		put(P.bench, vil, t + Vector3(0, 0, 0.9), 0.1)
	for bp in [Vector3(64, 0, 34.6), Vector3(64.8, 0, 35.2), Vector3(52, 0, 34.8)]:
		put(P.barrel, vil, bp, randf() * TAU)
	# круг для кулачных боёв за «Шалманом»
	var ring := group(vil, "Ring")
	ring.position = Vector3(58, 0, 18)
	for c in [Vector2(-3, -3), Vector2(3, -3), Vector2(3, 3), Vector2(-3, 3)]:
		cyl(ring, 0.08, 0.08, 1.2, Vector3(c.x, 0.6, c.y), "log_dark").owner = root
	for e in [[Vector3(0, 1.0, -3), 0.0], [Vector3(0, 1.0, 3), 0.0], [Vector3(-3, 1.0, 0), PI / 2.0], [Vector3(3, 1.0, 0), PI / 2.0]]:
		box(ring, Vector3(6, 0.04, 0.04), e[0], "rope_mat", Vector3(0, e[1], 0)).owner = root
	put(P.bench, vil, Vector3(53.5, 0, 18), PI / 2.0)
	_laundry(vil, Vector3(22, 0, 22), Vector3(30, 0, 23))
	_laundry(vil, Vector3(36, 0, 44.5), Vector3(42, 0, 45))
	put(P.bench, vil, Vector3(28, 0, 44.6), PI, "GrannyBench")
	put(P.woodpile, vil, Vector3(6, 0, 24), 0.0)
	var det := group(root, "Yard")
	for dd in [["junk", Vector3(24, 0, 17)], ["junk", Vector3(36, 0, 15.5)], ["junk", Vector3(46, 0, 18.5)], ["crates", Vector3(10, 0, 44)],
			["cart", Vector3(68, 0, 44)], ["barrel", Vector3(50, 0, 45)], ["crates", Vector3(70, 0, 26)]]:
		put(P[dd[0]], det, dd[1], randf() * TAU)
	for p in [Vector3(22, 0, 37.5), Vector3(48, 0, 37.5), Vector3(66, 0, 42.5)]:
		_lamp_post(vil, p, Color("ffb050"))
	_woods(450)
	var chars := group(root, "Characters")
	character(chars, "Barman", "sg_barman", Vector3(58, 0, 34.6), 0.0, {"dialog": "sg_barman"})
	character(chars, "Brawler", "sg_brawler", Vector3(58, 0, 18), PI, {"dialog": "sg_brawler"})
	character(chars, "Gunsmith", "sg_gunsmith", Vector3(16, 0, 46.8), PI, {"dialog": "sg_gunsmith"})
	character(chars, "Runaway", "sg_runaway", Vector3(7.5, 0, 26.5), 0.6, {"dialog": "sg_runaway", "start_pose": "sit"})
	character(chars, "Collector1", "sg_collector", Vector3(36, 0, 41.4), -0.6, {"dialog": "sg_collector", "squad": "collectors", "groups": ["collectors"]})
	character(chars, "Collector2", "sg_collector", Vector3(37.4, 0, 42.6), -1.0, {"dialog": "sg_collector", "squad": "collectors", "groups": ["collectors"]})
	character(chars, "Granny", "sg_granny", Vector3(28, 0, 45.1), PI, {"dialog": "sg_granny", "start_pose": "sit"})
	character(chars, "Drinker1", "villager", Vector3(54, 0, 38.3), PI, {"display_name": "Пьющий подёнщик", "start_pose": "sit"})
	character(chars, "Drinker2", "villager", Vector3(61.5, 0, 38.1), PI, {"display_name": "Грузчик с баржи", "start_pose": "sit"})
	character(chars, "QuarterKid", "kid", Vector3(30, 0, 38), 0.0, {"display_name": "Мальчишка с бараков",
		"patrol": PackedVector3Array([Vector3(30, 0, 38), Vector3(44, 0, 41), Vector3(20, 0, 41)]), "patrol_wait": 2.5})
	character(chars, "Washer", "villager_f", Vector3(26, 0, 21.5), 0.0, {"display_name": "Прачка"})
	var items := group(root, "Items")
	_exit(items, "ToCenter", "В центр города", Vector3(1.0, 0, 40), Vector3(1.6, 2.2, 5.0))
	_use(items, "ScrapA", "Куча хлама", Vector3(24, 0, 17), Vector3(1.8, 1.0, 1.8))
	_use(items, "ScrapB", "Куча хлама", Vector3(36, 0, 15.5), Vector3(1.8, 1.0, 1.8))
	_use(items, "ScrapC", "Куча хлама", Vector3(46, 0, 18.5), Vector3(1.8, 1.0, 1.8))
	_use(items, "GuideRoom", "Каморка в бараке", Vector3(45.2, 0, 31.2), Vector3(1.4, 2.0, 1.4))
	_spawn("Start", Vector3(4.5, 0, 40))
	_spawn("FromCenter", Vector3(4.5, 0, 40))
	marker(root, "MarkBar", Vector3(58, 0, 31), "«Шалман»")
	marker(root, "MarkGuns", Vector3(16, 0, 51), "Оружейная")
	marker(root, "MarkRing", Vector3(58, 0, 18), "Круг")
	_dress(Rect2(4, 6, 68, 48), 400)
	_finish("sungar_quarter")
