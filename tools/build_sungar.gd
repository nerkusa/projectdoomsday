extends "res://tools/build_act1.gd"
## Сунгар — бывший посёлок городского типа: три района (ворота и рынок, центр,
## жилой квартал) плотно застроены каменными домами в 2–4 этажа (постройки — из
## tools/build_city.gd). В гостиницу, универмаг, «Шалман», столовую, ДК, жилой дом
## и общежитие можно войти; в гостинице, жилом доме и общежитии по лестнице —
## на верхние этажи: это отдельные сцены sungar_hotel, sungar_dom, sungar_obshaga
## (скрипт scripts/locations/sungar_house.gd).
## Запуск: godot --headless --path . res://tools/build_sungar.tscn — только Сунгар;
## res://tools/build_act1.tscn — весь первый акт вместе с Сунгаром.

## Шаг между этажами в сцене дома (этажи лежат рядом)
const FLOOR_DX := 60.0
## Высота стен-срезов на верхних этажах (как у первого этажа, когда верх дома спрятан)
const WALL_H := 1.25
const GAP := 1.9

var only_sungar := false


func _build() -> void:
	only_sungar = scene_file_path == "res://tools/build_sungar.tscn"
	if not only_sungar:
		super._build()
	else:
		for n in ["cloth_sack", "cloth_red", "rope_mat", "rust", "metal_dark", "tin", "hay", "bark_dark", "planks_old",
				"stone_wall", "tire", "paper", "metal_roof", "glass", "paint_faded", "paint_white", "cloth", "water", "log_dark",
				"log_weathered", "ground_dirt"]:
			M[n] = load(MAT_DIR + n + ".tres")
	for n in ["screen_green", "screen_amber", "plastic_beige", "flag_red", "concrete", "coal", "window_sky", "plaster_yellow", "plaster_pink", "plaster_white", "brick", "brick_white",
			"wallpaper", "wallpaper_b", "paint_green", "paint_blue", "linoleum", "linoleum_b", "tiles", "frame_white", "tar", "felt"]:
		M[n] = load(MAT_DIR + n + ".tres")
	for n in ["st_hotel", "st_store", "st_res4", "st_obshaga", "st_bar", "st_canteen", "st_dk", "st_office", "st_block3a",
			"st_block3b", "st_block4", "st_block4b", "st_block2", "st_block2b", "st_barrack2", "heat_pipe_low", "heat_pipe_high",
			"heat_pipe_riser", "boiler_house", "water_tower", "garages", "kiosk", "kiosk_b", "bus_stop", "conc_fence", "paz_wreck",
			"bins", "f_bed", "f_wardrobe", "f_table", "f_table_kitchen", "f_card_table", "f_stove", "f_kitchen_stove", "f_sofa",
			"f_shelf", "f_sink", "f_tv", "f_plant", "f_radio", "f_stairs", "st_police", "st_admin", "cf_terminal", "cf_mainframe",
			"cf_info_screen", "loudspeaker", "power_pole", "sandbags", "checkpoint", "notice_board", "trash_pile", "trash_pile_b",
			"rubble", "car_wreck", "burnt_shed", "burn_barrel", "boardwalk"]:
		P[n] = load(PROP_DIR + n + ".tscn")
	_sungar()
	_sungar_center()
	_sungar_quarter()
	_hotel_floors()
	_dom_floors()
	_obshaga_floors()
	_admin_floors()


# ---------------- помощники ----------------
func _bld(parent: Node, prop: String, nm: String, pos: Vector3, rot := 0.0) -> Node3D:
	return put(P[prop], parent, pos, rot, nm)


## Мировая точка метки Slot_<s> постройки (группы-родители стоят в нуле)
func _slot(b: Node3D, s: String) -> Vector3:
	var m := b.get_node_or_null("Slot_" + s) as Node3D
	if m == null:
		push_error("нет метки %s у %s" % [s, b.name])
		return b.position
	return b.transform * m.position


## Поворот, чтобы смотреть из a на b
func _face(a: Vector3, b: Vector3) -> float:
	return atan2(b.x - a.x, b.z - a.z)


## Теплотрасса по прямой вдоль X или Z кусками по 6 м
func _pipes(parent: Node, kind: String, a: Vector3, b: Vector3) -> void:
	var d := b - a
	var n := maxi(1, int(round(d.length() / 6.0)))
	var rot := 0.0 if absf(d.x) > absf(d.z) else PI / 2.0
	for i in n:
		_bld(parent, "heat_pipe_" + kind, "Pipe", a + d.normalized() * (3.0 + 6.0 * i), rot)


## Тротуар из бетонных плит перед домом (без коллизии)
func _pavement(parent: Node, r: Rect2) -> void:
	var b := box(parent, Vector3(r.size.x, 0.05, r.size.y), Vector3(r.get_center().x, 0.025, r.get_center().y), "concrete")
	b.owner = root


## Стела у въезда: «ПГТ СУНГАР · 1930»
func _stele(parent: Node, pos: Vector3, rot: float) -> void:
	var s := Node3D.new()
	s.name = "Stele"
	parent.add_child(s)
	s.owner = root
	s.position = pos
	s.rotation.y = rot
	box(s, Vector3(2.2, 0.4, 1.0), Vector3(0, 0.2, 0), "concrete").owner = root
	box(s, Vector3(1.6, 4.6, 0.45), Vector3(0, 2.7, 0), "concrete").owner = root
	box(s, Vector3(1.7, 0.18, 0.55), Vector3(0, 5.05, 0), "metal_dark").owner = root
	# солнце-орнамент наверху
	cyl(s, 0.45, 0.45, 0.08, Vector3(0, 5.6, 0.0), "rust", Vector3(PI / 2.0, 0, 0), 14).owner = root
	_own(collider(s, Vector3(2.2, 2.0, 1.0), Vector3(0, 1.0, 0)), root)
	var l := Label3D.new()
	l.text = "ПГТ\nСУНГАР\n\n1930"
	l.font_size = 64
	l.pixel_size = 0.008
	l.modulate = Color("c8c0a8")
	l.outline_size = 6
	l.position = Vector3(0, 3.0, 0.24)
	s.add_child(l)
	l.owner = root


## Доска почёта на площади: рамки с «портретами»
func _honor_board(parent: Node, pos: Vector3, rot: float) -> void:
	var s := Node3D.new()
	s.name = "HonorBoard"
	parent.add_child(s)
	s.owner = root
	s.position = pos
	s.rotation.y = rot
	box(s, Vector3(4.6, 2.4, 0.25), Vector3(0, 1.6, 0), "plaster_white").owner = root
	box(s, Vector3(4.8, 0.2, 0.4), Vector3(0, 2.9, 0), "concrete").owner = root
	for i in 6:
		var x := -1.75 + (i % 3) * 1.75 - 0.0
		var y := 1.95 - int(i / 3) * 0.85
		box(s, Vector3(0.55, 0.7, 0.04), Vector3(x, y, 0.14), "frame_white").owner = root
		box(s, Vector3(0.45, 0.6, 0.03), Vector3(x, y, 0.16), "paper" if i != 4 else "metal_dark").owner = root
	_own(collider(s, Vector3(4.6, 2.4, 0.4), Vector3(0, 1.2, 0)), root)
	var l := Label3D.new()
	l.text = "ДОСКА ПОЧЁТА"
	l.font_size = 48
	l.pixel_size = 0.006
	l.modulate = Color("8a2a24")
	l.outline_size = 0
	l.position = Vector3(0, 2.68, 0.14)
	s.add_child(l)
	l.owner = root


## Вывеска над входом. У домов, куда можно войти, — дочерний узел дома с меткой
## with_upper: house.gd прячет её вместе с верхом дома, пока герой внутри
func _sign_on(vil: Node, b: Node3D, text: String, w: float, col := Color("e8d8a8"), off := Vector3.ZERO) -> void:
	var up := b.get_node_or_null("Upper")
	var m := b.get_node_or_null("Slot_sign") as Node3D
	if up and m:
		_signboard(b, text, m.position + off, 0.0, w, col)
		b.get_child(b.get_child_count() - 1).set_meta("with_upper", true)
	else:
		_signboard(vil, text, _slot(b, "sign") + Basis.from_euler(Vector3(0, b.rotation.y, 0)) * off, b.rotation.y, w, col)


## Город, а не тайга: деревья внутри черты города вырубить
func _clear_town(r: Rect2) -> void:
	for grp in ["Forest", "Yard"]:
		var g := root.get_node_or_null(grp)
		if g == null:
			continue
		for t in g.get_children():
			var sp := String(t.scene_file_path)
			var tree := false
			for k in ["spruce", "pine", "birch", "dead_tree", "larch"]:
				if sp.contains("/" + k):
					tree = true
			if tree and r.has_point(Vector2(t.position.x, t.position.z)):
				g.remove_child(t)
				t.free()


## Городские мелочи: [проп, x, z, поворот]; у бочки-жаровни — огонь
func _clutter(parent: Node, list: Array) -> void:
	for c in list:
		var rot: float = c[3] if c.size() > 3 else randf() * TAU
		_bld(parent, c[0], String(c[0]).to_pascal_case(), Vector3(c[1], 0, c[2]), rot)
		if c[0] == "burn_barrel":
			var f := put(P.fire, parent, Vector3(c[1], 0.85, c[2]), 0.0, "BarrelFire")
			f.set("strength", 0.45)


## Линия электропередачи: столбы по точкам, провода между верхушками с провисом
func _power_line(parent: Node, pts: Array) -> void:
	for i in pts.size():
		var a: Vector3 = pts[i]
		var nb: Vector3 = pts[i + 1] if i + 1 < pts.size() else pts[i - 1]
		var dir := (nb - a).normalized()
		_bld(parent, "power_pole", "PowerPole", a, atan2(dir.x, dir.z) + PI / 2.0)
		if i + 1 >= pts.size():
			continue
		var b: Vector3 = pts[i + 1]
		var side := Vector3(dir.z, 0, -dir.x)
		for off in [-0.8, -0.3, 0.3, 0.8]:
			var p0: Vector3 = a + side * off + Vector3(0, 6.8, 0)
			var p1: Vector3 = b + side * off + Vector3(0, 6.8, 0)
			var mid: Vector3 = (p0 + p1) / 2.0 - Vector3(0, 0.45, 0)
			for seg in [[p0, mid], [mid, p1]]:
				var s0: Vector3 = seg[0]
				var s1: Vector3 = seg[1]
				var d := s1 - s0
				var w := MeshInstance3D.new()
				var bm := BoxMesh.new()
				bm.size = Vector3(0.025, 0.025, d.length())
				w.mesh = bm
				w.material_override = M["metal_dark"]
				w.position = (s0 + s1) / 2.0
				w.basis = Basis.looking_at(d.normalized(), Vector3.UP)
				w.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				parent.add_child(w)
				w.owner = root


## Неоновая надпись (светится ночью); with_upper — на доме, куда входят
func _neon(parent: Node, text: String, pos: Vector3, rot: float, col: Color, size := 72, with_upper := false) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = 0.007
	l.modulate = Color(col.r * 2.6, col.g * 2.6, col.b * 2.6)
	l.outline_size = 0
	l.position = pos
	l.rotation.y = rot
	if with_upper:
		l.set_meta("with_upper", true)
	parent.add_child(l)
	l.owner = root


## Надпись краской на стене
func _graffiti(parent: Node, text: String, pos: Vector3, rot: float, col := Color("7a1c16")) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = 64
	l.pixel_size = 0.007
	l.modulate = col
	l.outline_size = 0
	l.position = pos
	l.rotation = Vector3(0, rot, randf_range(-0.08, 0.08))
	parent.add_child(l)
	l.owner = root


## Уличный экран «Сунгар-информ» с бегущими сводками
func _info_screen(parent: Node, pos: Vector3, rot: float, text: String) -> void:
	var b := _bld(parent, "cf_info_screen", "InfoScreen", pos, rot)
	var l := Label3D.new()
	l.text = text
	l.font_size = 40
	l.pixel_size = 0.0055
	l.modulate = Color(2.2, 1.3, 0.35)
	l.outline_size = 0
	l.width = 1.35 / 0.0055
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	l.position = _slot(b, "text")
	l.rotation.y = rot
	parent.add_child(l)
	l.owner = root


func _cop(chars: Node, nm: String, pos: Vector3, rot: float, patrol := PackedVector3Array(), title := "Патрульный") -> void:
	var o := {"display_name": title, "dialog": "sg_cop", "armed": true, "groups": ["cops"]}
	if not patrol.is_empty():
		o["patrol"] = patrol
		o["patrol_wait"] = 5.0
	character(chars, nm, "sg_cop", pos, rot, o)


## Лестница в доме района: предмет у подножия марша и точка появления рядом
func _stairs_item(items: Node, b: Node3D, nm: String, label: String, spawn: String) -> void:
	var p := _slot(b, "stairs")
	_use(items, nm, label, p, Vector3(1.4, 2.0, 1.2))
	_spawn(spawn, p + Basis.from_euler(Vector3(0, b.rotation.y, 0)) * Vector3(0, 0, 1.0))


# ======================================================================
# ВОРОТА И РЫНОК
# ======================================================================
func _sungar() -> void:
	var rect := Rect2(0, 0, 84, 62)
	_begin("sungar", "Сунгар · ворота и рынок", rect, "res://scripts/locations/sungar.gd")
	var d := "ground_dirt"
	strip(null, Vector2(-6, 30), Vector2(90, 30), 3.4, d)
	strip(null, Vector2(40, 30), Vector2(40, 56), 2.0, d)
	road_segs.append([Vector2(-6, 30), Vector2(90, 30), 2.6])
	road_segs.append([Vector2(34, 30), Vector2(56, 30), 7.5])  # рыночная площадь
	road_segs.append([Vector2(40, 30), Vector2(40, 55), 1.6])
	road_segs.append([Vector2(14, 22), Vector2(82, 22), 1.2])  # вдоль домов
	_mud.append(Rect2(-10, 54, 110, 4))
	_mud.append(Rect2(30, 42, 22, 8))
	_clear.append(Rect2(10, 2, 72, 54))
	_clear.append(Rect2(-6, 20, 18, 16))
	_no_edge.append(Rect2(-40, 55, 180, 40))
	_ground_for("sungar")
	_river_south(58.0)
	var vil := group(root, "Village")
	# стена с воротами: частокол по x = 12, проход — дорога
	for z in [4.0, 8.0, 12.0, 16.0, 20.0, 24.0, 36.0, 40.0, 44.0, 48.0, 52.0]:
		put(P.palisade, vil, Vector3(12, 0, z), PI / 2.0)
	_own(collider(vil, Vector3(0.7, 2.6, 26.5), Vector3(12, 1.3, 13.0)), root)
	_own(collider(vil, Vector3(0.7, 2.6, 25.0), Vector3(12, 1.3, 46.0)), root)
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
	_stele(vil, Vector3(6.5, 0, 25.2), 0.0)
	# северный ряд: гостиница, универмаг, жилые дома
	var hotel := _bld(vil, "st_hotel", "Hotel", Vector3(24, 0, 13.5))
	_sign_on(vil, hotel, "ГОСТИНИЦА «ВИЛЮЙ»", 4.8, Color("f0d890"))
	var store := _bld(vil, "st_store", "Store", Vector3(44.5, 0, 13.0))
	_sign_on(vil, store, "УНИВЕРМАГ", 3.6, Color("e8e0c8"))
	var police := _bld(vil, "st_police", "Police", Vector3(62, 0, 12.5))
	_sign_on(vil, police, "ПОЛИЦИЯ СУНГАРА", 4.0, Color("d8e0f0"))
	_neon(police, "02", Vector3(4.6, 3.6, 4.1), 0.0, Color("3a7aff"), 96, true)
	_bld(vil, "st_block2b", "House2", Vector3(77.5, 0, 12.5))
	# южный ряд, лицом к улице
	var bakery := _bld(vil, "st_block2", "House3", Vector3(21, 0, 46), PI)
	_signboard(vil, "ХЛЕБ", _slot(bakery, "sign"), PI, 2.2, Color("f0d890"))
	_bld(vil, "st_block4b", "House4", Vector3(75, 0, 47.5), PI)
	var k1 := _bld(vil, "kiosk", "Kiosk1", Vector3(58, 0, 41.0), PI)
	_signboard(vil, "ТАБАК", _slot(k1, "sign"), PI, 1.6, Color("e8e0c8"))
	_bld(vil, "kiosk_b", "Kiosk2", Vector3(61.6, 0, 41.0), PI)
	_bld(vil, "water_tower", "WaterTower", Vector3(64, 0, 52))
	_bld(vil, "bus_stop", "BusStop", Vector3(20, 0, 26.2))
	_bld(vil, "paz_wreck", "Paz", Vector3(31, 0, 46.5), 0.1)
	# блокпост на выезде в центр
	_bld(vil, "checkpoint", "Checkpoint", Vector3(77.5, 0, 25.0))
	_bld(vil, "sandbags", "Sandbags", Vector3(79.5, 0, 35.2))
	_bld(vil, "sandbags", "Sandbags", Vector3(75.5, 0, 22.4))
	# столбы ЛЭП, громкоговоритель, экран, мусор, жаровни, пожарище
	_power_line(vil, [Vector3(16, 0, 26.8), Vector3(31, 0, 26.8), Vector3(45, 0, 26.6), Vector3(59, 0, 26.8), Vector3(72.5, 0, 26.8)])
	_bld(vil, "loudspeaker", "Loudspeaker", Vector3(38.5, 0, 26.8))
	_info_screen(vil, Vector3(18, 0, 34.4), 0.0, "СУНГАР-ИНФОРМ\nКурс: 1 соль = 5 р.\nКомендантский час с 23:00\nПрописка — в администрации")
	_bld(vil, "notice_board", "NoticeBoard", Vector3(54.5, 0, 18.6))
	_clutter(vil, [["trash_pile", 14.8, 40.5], ["trash_pile_b", 53.5, 41.2], ["burn_barrel", 24, 33.2], ["burn_barrel", 70, 33.8],
		["rubble", 80, 38.5], ["car_wreck", 8, 40.5, 0.3], ["burnt_shed", 50, 47, 0.2], ["boardwalk", 40, 44.6, 0.0], ["boardwalk", 40, 47.8, 0.0],
		["trash_pile", 36.5, 7.6], ["rubble", 70.5, 7.4]])
	_graffiti(vil, "КОНТОРА — ВОРЫ", Vector3(26.03, 1.7, 46), PI / 2.0)
	_graffiti(vil, "ВЕРНИТЕ СВЕТ", Vector3(50.53, 1.8, 13.5), PI / 2.0, Color("1c1c1c"))
	_graffiti(vil, "ЗДЕСЬ БЫЛ БООТУР", Vector3(79.5, 1.9, 16.03), 0.0)
	_graffiti(vil, "ВСЁ ПО ТАЛОНАМ", Vector3(82.03, 1.6, 47.5), PI / 2.0, Color("1c1c1c"))
	_bld(vil, "bins", "Bins1", Vector3(35.2, 0, 18.4))
	# теплотрасса: над улицей на П-опорах, за домами — низом
	_pipes(vil, "high", Vector3(66.5, 0, 16.5), Vector3(66.5, 0, 40.5))
	_bld(vil, "heat_pipe_low", "Pipe", Vector3(66.5, 0, 43.5), PI / 2.0)
	_pipes(vil, "low", Vector3(16, 0, 5.2), Vector3(82, 0, 5.2))
	# тротуары
	var pav := group(vil, "Pavement")
	pav.set_meta("no_xray", true)
	_pavement(pav, Rect2(15, 18.2, 40, 2.4))
	_pavement(pav, Rect2(56, 16.2, 26, 2.2))
	_pavement(pav, Rect2(15, 40.2, 12, 2.0))
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
	# рыбная пристань
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
			["cart", Vector3(60, 0, 35)], ["crates", Vector3(44, 0, 41.5)], ["barrel", Vector3(36, 0, 52)],
			["hay_bale", Vector3(20, 0, 34.5)], ["cart", Vector3(26, 0, 34.8)], ["barrel", Vector3(18, 0, 22.6)], ["junk", Vector3(70, 0, 54)]]:
		put(P[dd[0]], det, dd[1], randf() * TAU)
	for p in [Vector3(28, 0, 27.5), Vector3(52, 0, 27.5), Vector3(28, 0, 32.5), Vector3(62, 0, 32.5), Vector3(40, 0, 50), Vector3(72, 0, 27.5)]:
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
	character(chars, "Shopper1", "town_m1", Vector3(36, 0, 30), 1.0, {"display_name": "Покупатель",
		"patrol": PackedVector3Array([Vector3(36, 0, 30), Vector3(52, 0, 29), Vector3(47, 0, 33)]), "patrol_wait": 4.0})
	character(chars, "Shopper2", "town_f1", Vector3(50, 0, 32), -1.0, {"display_name": "Горожанка",
		"patrol": PackedVector3Array([Vector3(50, 0, 32), Vector3(33, 0, 31), Vector3(40, 0, 45)]), "patrol_wait": 5.0})
	character(chars, "Porter", "town_worker", Vector3(30, 0, 26), 0.0, {"display_name": "Грузчик",
		"patrol": PackedVector3Array([Vector3(30, 0, 26), Vector3(40, 0, 52)]), "patrol_wait": 6.0})
	# гостиница: дежурная за конторкой, постоялец на диване
	var kp := _slot(hotel, "keeper")
	character(chars, "Innkeeper", "sg_innkeeper", kp, PI / 2.0, {"dialog": "sg_innkeeper"})
	character(chars, "Lodger", "town_m2", _slot(hotel, "sofa"), 0.0, {"display_name": "Постоялец", "start_pose": "sit"})
	# универмаг
	character(chars, "Storekeeper", "sg_storekeeper", _slot(store, "seller"), 0.0, {"dialog": "sg_storekeeper"})
	character(chars, "StoreBuyer", "town_old_f", _slot(store, "buyer"), PI, {"display_name": "Старушка с авоськой"})
	# улица: прохожие, остановка, дети у водокачки
	character(chars, "BusWaiter", "town_old_m", Vector3(20, 0, 25.85), 0.0, {"display_name": "Старик на остановке", "start_pose": "sit"})
	character(chars, "Walker1", "town_f2", Vector3(24, 0, 20.5), PI / 2.0, {"display_name": "Горожанка",
		"patrol": PackedVector3Array([Vector3(24, 0, 20.5), Vector3(52, 0, 19.6), Vector3(70, 0, 19.0), Vector3(36, 0, 20)]), "patrol_wait": 3.0})
	character(chars, "Walker2", "town_m3", Vector3(70, 0, 30), -PI / 2.0, {"display_name": "Прохожий",
		"patrol": PackedVector3Array([Vector3(70, 0, 30), Vector3(18, 0, 30.5), Vector3(60, 0, 31)]), "patrol_wait": 4.0})
	character(chars, "Kid1", "kid", Vector3(60, 0, 48), 0.5, {"display_name": "Мальчишка",
		"patrol": PackedVector3Array([Vector3(60, 0, 48), Vector3(66.4, 0, 49), Vector3(56, 0, 52)]), "patrol_wait": 2.0})
	character(chars, "KioskMan", "town_m4", _slot(k1, "seller"), PI, {"display_name": "Киоскёр"})
	# полиция: капитан, дежурный, задержанный; патрули и блокпост
	character(chars, "Chief", "sg_chief", _slot(police, "chief"), PI / 2.0, {"dialog": "sg_chief"})
	_cop(chars, "DeskCop", _slot(police, "cop"), PI, PackedVector3Array(), "Дежурный")
	character(chars, "Prisoner", "villager", _slot(police, "cell1"), 0.0, {"display_name": "Задержанный", "start_pose": "sit"})
	_cop(chars, "Patrol1", Vector3(30, 0, 28.6), PI / 2.0, PackedVector3Array([Vector3(30, 0, 28.6), Vector3(64, 0, 28.8), Vector3(52, 0, 33.6), Vector3(22, 0, 31.6)]))
	_cop(chars, "Patrol2", Vector3(56, 0, 19.6), -PI / 2.0, PackedVector3Array([Vector3(56, 0, 19.6), Vector3(20, 0, 20.2), Vector3(40, 0, 43.0)]))
	_cop(chars, "PostCop1", Vector3(76.0, 0, 28.0), -PI / 2.0, PackedVector3Array(), "Постовой")
	_cop(chars, "PostCop2", Vector3(76.2, 0, 33.4), -PI / 2.0 + 0.4, PackedVector3Array(), "Постовой")
	character(chars, "Bum1", "town_old_m", Vector3(24.9, 0, 33.9), -0.8, {"display_name": "Бродяга у бочки"})
	character(chars, "Bum2", "villager", Vector3(70.8, 0, 34.6), -1.2, {"display_name": "Греется у бочки"})
	var items := group(root, "Items")
	_exit(items, "WestExit", "Дорога из города", Vector3(1.0, 0, 30), Vector3(1.6, 2.2, 5.0))
	_exit(items, "ToCenter", "В центр города", Vector3(83.0, 0, 30), Vector3(1.6, 2.2, 5.0))
	_use(items, "BankPath", "Берег под обрывом", Vector3(9.0, 0, 55.6), Vector3(1.6, 1.2, 1.6))
	_use(items, "Stele", "Стела у въезда", Vector3(6.5, 0, 25.9), Vector3(2.2, 3.0, 1.2))
	var k := 1
	for sp in [Vector3(34, 0, 23.4), Vector3(41, 0, 23.4), Vector3(48, 0, 23.4), Vector3(55, 0, 23.4)]:
		_use(items, "Stall%d" % k, "Весы на прилавке", sp, Vector3(2.2, 1.2, 1.2))
		k += 1
	_stairs_item(items, hotel, "HotelStairs", "Гостиница", "FromHotel")
	_use(items, "Ashes", "Пожарище", Vector3(50.3, 0, 49.2), Vector3(3.0, 1.0, 1.4))
	_use(items, "WantedBoard", "Доска «Их разыскивает»", _slot(police, "board"), Vector3(1.6, 1.4, 0.8)).set("reach", 2)
	_use(items, "NoticeBoard", "Доска объявлений", Vector3(54.5, 0, 19.3), Vector3(2.2, 1.8, 0.6))
	_use(items, "InfoScreen", "Экран «Сунгар-информ»", Vector3(18, 0, 35.0), Vector3(1.4, 3.6, 0.6))
	_spawn("Start", Vector3(4.5, 0, 30))
	_spawn("Road", Vector3(4.5, 0, 30))
	_spawn("FromCenter", Vector3(79, 0, 30))
	_spawn("Bank", Vector3(17, 0, 52.5))
	marker(root, "MarkGate", Vector3(13, 0, 30), "Ворота")
	marker(root, "MarkMarket", Vector3(44, 0, 30), "Рынок")
	marker(root, "MarkPier", Vector3(40, 0, 56), "Пристань")
	marker(root, "MarkHotel", Vector3(24, 0, 13.5), "Гостиница «Вилюй»")
	marker(root, "MarkStore", Vector3(44.5, 0, 13), "Универмаг")
	marker(root, "MarkPolice", Vector3(62, 0, 12.5), "Полиция")
	marker(root, "MarkAshes", Vector3(50, 0, 47), "Пожарище")
	_dress(Rect2(12, 4, 70, 50), 350)
	_clear_town(Rect2(12.5, 1, 72, 57))
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


# ======================================================================
# ЦЕНТР
# ======================================================================
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
	road_segs.append([Vector2(10, 19.5), Vector2(60, 19.5), 1.4])
	_mud.append(Rect2(-10, 54, 110, 4))
	_clear.append(Rect2(2, 2, 80, 54))
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
	# жилой дом на площади (четыре этажа, с подъездом — наверх по лестнице)
	var dom := _bld(vil, "st_res4", "Dom", Vector3(20, 0, 12))
	_sign_on(vil, dom, "ул. ЛЕНИНА, 3", 2.8, Color("d8dce8"))
	# Дом культуры: внизу — игорный зал
	var dk := _bld(vil, "st_dk", "HouseOfCulture", Vector3(40, 0, 9.0))
	_sign_on(vil, dk, "ДОМ КУЛЬТУРЫ · ИГОРНЫЙ ЗАЛ", 6.0, Color("ffcf7a"), Vector3(0, 3.2, 2.35))
	# контора «отдела ф. м.» — кирпичная, три этажа, флаг
	var office := _bld(vil, "st_office", "Office", Vector3(64, 0, 17.5))
	_signboard(vil, "КОНТОРА · ОТДЕЛ Ф. М.", _slot(office, "sign"), 0.0, 5.2, Color("d8dce8"))
	# южная сторона площади
	_bld(vil, "st_block4b", "House1", Vector3(14, 0, 45.5), PI)
	var cant := _bld(vil, "st_canteen", "Canteen", Vector3(58, 0, 44.5), PI)
	_sign_on(vil, cant, "СТОЛОВАЯ", 3.4, Color("f0e0c0"))
	var admin := _bld(vil, "st_admin", "Admin", Vector3(74, 0, 46.2), PI)
	_sign_on(vil, admin, "АДМИНИСТРАЦИЯ ПГТ СУНГАР", 5.6, Color("e8e0c8"))
	_neon(admin, "СУНГАР — ГОРОД БУДУЩЕГО", Vector3(-8.04, 7.6, 0), -PI / 2.0, Color("ff5a3a"), 64, true)
	# блокпост к кварталу, патрули, мелочи
	_bld(vil, "checkpoint", "Checkpoint", Vector3(75.5, 0, 11.2))
	_bld(vil, "sandbags", "Sandbags", Vector3(80.0, 0, 10.6))
	_power_line(vil, [Vector3(8, 0, 26.8), Vector3(22, 0, 26.6), Vector3(38, 0, 26.8), Vector3(53.5, 0, 26.8), Vector3(66, 0, 26.6)])
	_bld(vil, "loudspeaker", "Loudspeaker", Vector3(44.6, 0, 35.4))
	_info_screen(vil, Vector3(48.2, 0, 34.4), 0.0, "СУНГАР-ИНФОРМ\nДолги — в контору отдела ф. м.\nТалоны — по прописке\nПожарная безопасность — долг каждого")
	_clutter(vil, [["trash_pile", 61.5, 37.2], ["burn_barrel", 8.5, 36.5], ["rubble", 26, 49.2], ["car_wreck", 52, 53, 0.4],
		["trash_pile_b", 79.5, 54.0], ["boardwalk", 38, 47.5, 0.0], ["trash_pile", 4.5, 13.5]])
	_graffiti(vil, "ТАЛОНЫ — НЕ ЕДА", Vector3(28.03, 1.8, 12), PI / 2.0)
	_graffiti(vil, "ОТДЕЛ Ф. М. = СМЕРТЬ", Vector3(69.53, 1.6, 17.5), PI / 2.0, Color("1c1c1c"))
	_graffiti(vil, "Б. + С.", Vector3(21.03, 1.4, 45.5), PI / 2.0)
	_bld(vil, "garages", "Garages", Vector3(6.5, 0, 21.2))
	_bld(vil, "bins", "Bins1", Vector3(66.5, 0, 39.6), PI)
	_bld(vil, "kiosk_b", "Kiosk1", Vector3(30.5, 0, 17.5))
	_honor_board(vil, Vector3(31.5, 0, 38.5), PI / 2.0)
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
	var pav := group(vil, "Pavement")
	pav.set_meta("no_xray", true)
	_pavement(pav, Rect2(10, 17.2, 48, 2.0))
	_pavement(pav, Rect2(33, 35, 14, 9))
	_pavement(pav, Rect2(6, 40.0, 76, 1.8))
	# теплотрасса через улицу и за ДК
	_pipes(vil, "high", Vector3(56.0, 0, 21.5), Vector3(56.0, 0, 39.5))
	_pipes(vil, "low", Vector3(28, 0, 2.6), Vector3(52, 0, 2.6))
	# «Счастливая лодка» и сходни
	_barge(vil, Vector3(38, 0, 62.5))
	for k in 6:
		box(vil, Vector3(1.6, 0.08, 0.7), Vector3(38, 0.14 + k * 0.17, 54.6 + k * 0.7), "planks_old").owner = root
	put(P.table, vil, Vector3(46, 0, 49.2), 0.0, "DiceTable")
	put(P.barrel, vil, Vector3(30, 0, 52), 0.0)
	put(P.barrel, vil, Vector3(30.8, 0, 52.6), 0.0)
	var det := group(root, "Yard")
	for dd in [["crates", Vector3(52, 0, 26)], ["crates", Vector3(58, 0, 34)], ["barrel", Vector3(70, 0, 24)],
			["crates", Vector3(12, 0, 35)], ["barrel", Vector3(50, 0, 50)]]:
		put(P[dd[0]], det, dd[1], randf() * TAU)
	for p in [Vector3(30, 0, 33), Vector3(50, 0, 33), Vector3(36, 0, 50), Vector3(60, 0, 27.5), Vector3(70, 0, 27.5), Vector3(20, 0, 33)]:
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
	character(chars, "Walker1", "town_f1", Vector3(30, 0, 30), 1.2, {"display_name": "Горожанка",
		"patrol": PackedVector3Array([Vector3(30, 0, 30), Vector3(60, 0, 31), Vector3(40, 0, 44)]), "patrol_wait": 5.0})
	character(chars, "Walker2", "town_m1", Vector3(54, 0, 36), -1.2, {"display_name": "Горожанин",
		"patrol": PackedVector3Array([Vector3(54, 0, 36), Vector3(16, 0, 31), Vector3(38, 0, 52)]), "patrol_wait": 6.0})
	character(chars, "Walker3", "town_m3", Vector3(14, 0, 18.4), PI / 2.0, {"display_name": "Прохожий",
		"patrol": PackedVector3Array([Vector3(14, 0, 18.4), Vector3(56, 0, 18.4), Vector3(30, 0, 19.5)]), "patrol_wait": 3.0})
	character(chars, "Walker4", "town_old_f", Vector3(70, 0, 38.5), -PI / 2.0, {"display_name": "Пенсионерка",
		"patrol": PackedVector3Array([Vector3(70, 0, 38.5), Vector3(46, 0, 37.5), Vector3(60, 0, 39)]), "patrol_wait": 6.0})
	character(chars, "BenchOld", "town_old_m", Vector3(36.5, 0, 41.9), 0.0, {"display_name": "Пенсионер с газетой", "start_pose": "sit"})
	# игорный зал в ДК: крупье у колеса, игроки за столами
	character(chars, "Croupier", "town_m2", _slot(dk, "croupier"), -PI / 2.0, {"display_name": "Крупье у колеса"})
	character(chars, "HallPlayer1", "town_m4", _slot(dk, "t1"), 0.0, {"display_name": "Игрок в карты"})
	character(chars, "HallPlayer2", "town_worker", _slot(dk, "t2"), 0.0, {"display_name": "Подёнщик за картами"})
	character(chars, "HallPlayer3", "town_f2", _slot(dk, "t3"), 0.0, {"display_name": "Игрочица"})
	# жилой дом: жильцы первого этажа
	character(chars, "DomOld", "town_old_f", _slot(dom, "flatL"), PI, {"display_name": "Соседка с первого этажа"})
	character(chars, "DomKid", "kid", _slot(dom, "flatR"), -PI / 2.0, {"display_name": "Девочка с куклой"})
	# столовая
	character(chars, "Cook", "town_f3", _slot(cant, "cook"), PI, {"display_name": "Повариха"})
	character(chars, "Eater1", "town_worker", _slot(cant, "t1"), PI, {"display_name": "Обедающий"})
	character(chars, "Eater2", "town_m1", _slot(cant, "t3"), PI, {"display_name": "Обедающий"})
	# администрация: паспортистка, очередь, охрана
	character(chars, "Passport", "sg_passport", _slot(admin, "clerk"), -PI / 2.0, {"dialog": "sg_passport"})
	_cop(chars, "AdminGuard", _slot(admin, "guard"), PI, PackedVector3Array(), "Охранник администрации")
	var q := _slot(admin, "queue")
	character(chars, "Queue1", "town_old_f", q + Vector3(-0.9, 0, 0), 0.0, {"display_name": "Очередь за талонами", "start_pose": "sit"})
	character(chars, "Queue2", "town_m3", q + Vector3(0.4, 0, 0), 0.0, {"display_name": "Очередь за справкой", "start_pose": "sit"})
	_cop(chars, "Patrol1", Vector3(30, 0, 31.4), PI / 2.0, PackedVector3Array([Vector3(30, 0, 31.4), Vector3(66, 0, 31.6), Vector3(46, 0, 38.0), Vector3(14, 0, 30.5)]))
	_cop(chars, "Patrol2", Vector3(60, 0, 39.0), -PI / 2.0, PackedVector3Array([Vector3(60, 0, 39.0), Vector3(20, 0, 38.0), Vector3(36, 0, 46.0)]))
	_cop(chars, "PostCop1", Vector3(77.4, 0, 14.2), PI / 2.0, PackedVector3Array(), "Постовой")
	character(chars, "Bum1", "villager", Vector3(9.3, 0, 37.3), -0.8, {"display_name": "Бродяга у бочки"})
	var items := group(root, "Items")
	_exit(items, "ToGate", "К воротам и рынку", Vector3(1.0, 0, 30), Vector3(1.6, 2.2, 5.0))
	_exit(items, "ToQuarter", "В жилой квартал", Vector3(83.0, 0, 14.5), Vector3(1.6, 2.2, 5.0))
	_use(items, "OfficeWindow", "Окно конторы", Vector3(58.2, 0, 16.0), Vector3(0.8, 2.0, 2.2))
	_use(items, "Monument", "Памятник", Vector3(40, 0, 37.4), Vector3(1.8, 3.4, 1.8))
	_use(items, "HonorBoard", "Доска почёта", Vector3(32.3, 0, 38.5), Vector3(0.8, 2.6, 4.4))
	_use(items, "Wheel", "Колесо фортуны", _slot(dk, "croupier") + Vector3(0.8, 0, 0), Vector3(0.8, 1.6, 1.4))
	_stairs_item(items, dom, "DomStairs", "Дом на площади", "FromDom")
	_stairs_item(items, admin, "AdminStairs", "Администрация", "FromAdmin")
	_use(items, "InfoScreen", "Экран «Сунгар-информ»", Vector3(48.2, 0, 35.0), Vector3(1.4, 3.6, 0.6))
	_spawn("Start", Vector3(4.5, 0, 30))
	_spawn("FromGate", Vector3(4.5, 0, 30))
	_spawn("FromQuarter", Vector3(79, 0, 16.5))
	marker(root, "MarkRows", Vector3(34, 0, 23), "Торговые ряды")
	marker(root, "MarkBoat", Vector3(38, 0, 56), "«Счастливая лодка»")
	marker(root, "MarkOffice", Vector3(64, 0, 17.5), "Контора")
	marker(root, "MarkDK", Vector3(40, 0, 9), "Дом культуры")
	marker(root, "MarkDom", Vector3(20, 0, 12), "Дом на площади")
	marker(root, "MarkCanteen", Vector3(58, 0, 44.5), "Столовая")
	marker(root, "MarkAdmin", Vector3(74, 0, 46.2), "Администрация")
	_dress(Rect2(4, 4, 78, 50), 300)
	_clear_town(Rect2(1, 1, 82, 56))
	_finish("sungar_center")


# ======================================================================
# ЖИЛОЙ КВАРТАЛ
# ======================================================================
func _sungar_quarter() -> void:
	var rect := Rect2(0, 0, 76, 60)
	_begin("sungar_quarter", "Сунгар · жилой квартал", rect, "res://scripts/locations/sungar_quarter.gd")
	var d := "ground_dirt"
	strip(null, Vector2(-6, 40), Vector2(80, 40), 3.0, d)
	road_segs.append([Vector2(-6, 40), Vector2(80, 40), 2.4])
	road_segs.append([Vector2(14, 20), Vector2(60, 20), 3.0])  # двор за бараками
	_mud.append(Rect2(10, 14, 50, 10))
	_mud.append(Rect2(40, 42, 20, 6))
	_clear.append(Rect2(2, 4, 72, 52))
	_ground_for("sungar_quarter")
	var vil := group(root, "Village")
	# северный ряд: общежитие, кирпичный барак, деревянный барак проводника, «Шалман»
	var ob := _bld(vil, "st_obshaga", "Obshaga", Vector3(14, 0, 30.5))
	_sign_on(vil, ob, "ОБЩЕЖИТИЕ № 2", 3.4, Color("d8dce8"))
	_bld(vil, "st_barrack2", "House1", Vector3(28.5, 0, 31))
	put(P.izba_long, vil, Vector3(42, 0, 31), -0.02, "GuideBarrack")
	var bar := _bld(vil, "st_bar", "Shalman", Vector3(58, 0, 30))
	_sign_on(vil, bar, "ШАЛМАН", 3.0, Color("ffcf7a"))
	# южный ряд
	var gun := _bld(vil, "st_block2", "Gunsmith", Vector3(16, 0, 51), PI)
	_signboard(vil, "ОРУЖЕЙНАЯ", _slot(gun, "sign"), PI, 3.6, Color("c8d0d8"))
	_bld(vil, "st_block3a", "House2", Vector3(32, 0, 50.5), PI)
	put(P.izba_long, vil, Vector3(46, 0, 50), PI + 0.02, "Barrack4")
	_bld(vil, "st_block2b", "House3", Vector3(60, 0, 51), PI)
	# котельная с трубой, гаражи, теплотрасса через двор
	_bld(vil, "boiler_house", "BoilerHouse", Vector3(68, 0, 12))
	_bld(vil, "garages", "Garages", Vector3(40, 0, 9.5))
	_pipes(vil, "high", Vector3(21.5, 0, 25.0), Vector3(63.5, 0, 25.0))
	_bld(vil, "heat_pipe_riser", "PipeRiser", Vector3(64.5, 0, 25.0), PI)
	_bld(vil, "heat_pipe_low", "Pipe", Vector3(66.0, 0, 20.4), PI / 2.0)
	_bld(vil, "bins", "Bins1", Vector3(48.5, 0, 36.6))
	_neon(bar, "ПИВО · ВОДКА", Vector3(5.03, 3.4, 1.0), PI / 2.0, Color("ff3a5a"), 72, true)
	_power_line(vil, [Vector3(6, 0, 43.4), Vector3(22, 0, 43.4), Vector3(36, 0, 43.2), Vector3(52, 0, 43.4), Vector3(70, 0, 43.4)])
	_bld(vil, "loudspeaker", "Loudspeaker", Vector3(50.5, 0, 38.6))
	_info_screen(vil, Vector3(25.5, 0, 37.0), 0.0, "СУНГАР-ИНФОРМ\nНабор на баржи: 3 р./день\nДолжникам — явка в контору\nУголь — по талонам")
	_clutter(vil, [["trash_pile", 16, 14.2], ["trash_pile_b", 28, 13.0], ["burn_barrel", 12, 18.2], ["rubble", 70, 49],
		["car_wreck", 6, 47.5, 1.2], ["boardwalk", 33, 20.0, PI / 2.0], ["boardwalk", 40, 20.2, PI / 2.0], ["trash_pile", 66.5, 36.0]])
	_graffiti(vil, "ДЕНЕГ НЕТ", Vector3(35.53, 1.6, 31), PI / 2.0)
	_graffiti(vil, "СЕНЬКА — КРЫСА", Vector3(20.03, 1.5, 30.5), PI / 2.0, Color("1c1c1c"))
	for t in [Vector3(54, 0, 37.4), Vector3(61.5, 0, 37.2)]:
		put(P.table, vil, t, 0.1)
		put(P.bench, vil, t + Vector3(0, 0, 0.9), 0.1)
	for bp in [Vector3(64.6, 0, 35.2), Vector3(52, 0, 35.2)]:
		put(P.barrel, vil, bp, randf() * TAU)
	# круг для кулачных боёв за «Шалманом»
	var ring := group(vil, "Ring")
	ring.position = Vector3(58, 0, 18)
	for c in [Vector2(-3, -3), Vector2(3, -3), Vector2(3, 3), Vector2(-3, 3)]:
		cyl(ring, 0.08, 0.08, 1.2, Vector3(c.x, 0.6, c.y), "log_dark").owner = root
	for e in [[Vector3(0, 1.0, -3), 0.0], [Vector3(0, 1.0, 3), 0.0], [Vector3(-3, 1.0, 0), PI / 2.0], [Vector3(3, 1.0, 0), PI / 2.0]]:
		box(ring, Vector3(6, 0.04, 0.04), e[0], "rope_mat", Vector3(0, e[1], 0)).owner = root
	put(P.bench, vil, Vector3(53.5, 0, 18), PI / 2.0)
	_laundry(vil, Vector3(22, 0, 21.5), Vector3(30, 0, 22.4))
	_laundry(vil, Vector3(36, 0, 44.5), Vector3(42, 0, 45))
	put(P.bench, vil, Vector3(28, 0, 44.6), PI, "GrannyBench")
	put(P.woodpile, vil, Vector3(4.5, 0, 22), 0.0)
	var pav := group(vil, "Pavement")
	pav.set_meta("no_xray", true)
	_pavement(pav, Rect2(7, 34.8, 58, 1.8))
	_pavement(pav, Rect2(9, 44.8, 60, 1.6))
	var det := group(root, "Yard")
	for dd in [["junk", Vector3(24, 0, 17)], ["junk", Vector3(36, 0, 15.5)], ["junk", Vector3(46, 0, 18.5)], ["crates", Vector3(10, 0, 44)],
			["cart", Vector3(68, 0, 44)], ["barrel", Vector3(50, 0, 45.4)], ["crates", Vector3(70, 0, 28)]]:
		put(P[dd[0]], det, dd[1], randf() * TAU)
	for p in [Vector3(22, 0, 37.5), Vector3(48, 0, 38.4), Vector3(66, 0, 42.5), Vector3(36, 0, 42.6)]:
		_lamp_post(vil, p, Color("ffb050"))
	_woods(450)
	var chars := group(root, "Characters")
	character(chars, "Barman", "sg_barman", _slot(bar, "barman"), PI / 2.0, {"dialog": "sg_barman"})
	character(chars, "Brawler", "sg_brawler", Vector3(58, 0, 18), PI, {"dialog": "sg_brawler"})
	character(chars, "Gunsmith", "sg_gunsmith", Vector3(16, 0, 46.6), PI, {"dialog": "sg_gunsmith"})
	character(chars, "Runaway", "sg_runaway", Vector3(5.5, 0, 26.0), 0.6, {"dialog": "sg_runaway", "start_pose": "sit"})
	character(chars, "Collector1", "sg_collector", Vector3(36, 0, 41.4), -0.6, {"dialog": "sg_collector", "squad": "collectors", "groups": ["collectors"]})
	character(chars, "Collector2", "sg_collector", Vector3(37.4, 0, 42.6), -1.0, {"dialog": "sg_collector", "squad": "collectors", "groups": ["collectors"]})
	character(chars, "Granny", "sg_granny", Vector3(28, 0, 45.1), PI, {"dialog": "sg_granny", "start_pose": "sit"})
	character(chars, "Drinker1", "villager", Vector3(54, 0, 38.3), PI, {"display_name": "Пьющий подёнщик", "start_pose": "sit"})
	character(chars, "Drinker2", "villager", Vector3(61.5, 0, 38.1), PI, {"display_name": "Грузчик с баржи", "start_pose": "sit"})
	character(chars, "QuarterKid", "kid", Vector3(30, 0, 38), 0.0, {"display_name": "Мальчишка с бараков",
		"patrol": PackedVector3Array([Vector3(30, 0, 38), Vector3(44, 0, 41), Vector3(20, 0, 41)]), "patrol_wait": 2.5})
	character(chars, "Washer", "villager_f", Vector3(26, 0, 21.0), 0.0, {"display_name": "Прачка"})
	# в «Шалмане»
	character(chars, "BarGuest1", "town_worker", _slot(bar, "t1"), PI, {"display_name": "Мужик с кружкой"})
	character(chars, "BarGuest2", "town_m3", _slot(bar, "t3"), PI, {"display_name": "Рыбак"})
	# общежитие: вахтёрша
	character(chars, "Watchwoman", "sg_watchwoman", _slot(ob, "watch"), 0.0, {"dialog": "sg_watchwoman"})
	character(chars, "ObKid", "kid", _slot(ob, "flatR"), PI, {"display_name": "Мальчишка у телевизора"})
	# котельная и двор
	character(chars, "Stoker", "sg_stoker", Vector3(70, 0, 17.6), PI, {"dialog": "sg_stoker"})
	_cop(chars, "Patrol1", Vector3(12, 0, 39.2), PI / 2.0, PackedVector3Array([Vector3(12, 0, 39.2), Vector3(66, 0, 40.4), Vector3(46, 0, 22.0), Vector3(20, 0, 41.5)]), "Дружинник")
	_cop(chars, "Patrol2", Vector3(64, 0, 42.6), -PI / 2.0, PackedVector3Array([Vector3(64, 0, 42.6), Vector3(8, 0, 42.4)]))
	character(chars, "Bum1", "villager", Vector3(12.6, 0, 18.7), -0.7, {"display_name": "Бродяга у бочки"})
	character(chars, "Bum2", "town_old_m", Vector3(11.5, 0, 17.6), 0.9, {"display_name": "Старик у бочки", "start_pose": "sit"})
	character(chars, "Walker1", "town_f1", Vector3(10, 0, 42), PI / 2.0, {"display_name": "Жиличка",
		"patrol": PackedVector3Array([Vector3(10, 0, 42), Vector3(66, 0, 41), Vector3(40, 0, 38.5)]), "patrol_wait": 4.0})
	character(chars, "Walker2", "town_m4", Vector3(64, 0, 22), PI, {"display_name": "Слесарь",
		"patrol": PackedVector3Array([Vector3(64, 0, 22), Vector3(30, 0, 19.5), Vector3(48, 0, 23.0)]), "patrol_wait": 5.0})
	var items := group(root, "Items")
	_exit(items, "ToCenter", "В центр города", Vector3(1.0, 0, 40), Vector3(1.6, 2.2, 5.0))
	_use(items, "ScrapA", "Куча хлама", Vector3(24, 0, 17), Vector3(1.8, 1.0, 1.8))
	_use(items, "ScrapB", "Куча хлама", Vector3(36, 0, 15.5), Vector3(1.8, 1.0, 1.8))
	_use(items, "ScrapC", "Куча хлама", Vector3(46, 0, 18.5), Vector3(1.8, 1.0, 1.8))
	_use(items, "GuideRoom", "Каморка в бараке", Vector3(45.2, 0, 31.2), Vector3(1.4, 2.0, 1.4))
	_use(items, "Chimney", "Труба котельной", Vector3(61.4, 0, 12.6), Vector3(1.6, 3.0, 1.6))
	_use(items, "InfoScreen", "Экран «Сунгар-информ»", Vector3(25.5, 0, 37.6), Vector3(1.4, 3.6, 0.6))
	_stairs_item(items, ob, "ObshagaStairs", "Общежитие", "FromObshaga")
	_spawn("Start", Vector3(4.5, 0, 40))
	_spawn("FromCenter", Vector3(4.5, 0, 40))
	marker(root, "MarkBar", Vector3(58, 0, 30), "«Шалман»")
	marker(root, "MarkGuns", Vector3(16, 0, 51), "Оружейная")
	marker(root, "MarkRing", Vector3(58, 0, 18), "Круг")
	marker(root, "MarkObshaga", Vector3(14, 0, 30.5), "Общежитие")
	marker(root, "MarkBoiler", Vector3(68, 0, 12), "Котельная")
	_dress(Rect2(4, 6, 68, 48), 300)
	_clear_town(Rect2(2, 5, 72, 52))
	_finish("sungar_quarter")


# ======================================================================
# ВЕРХНИЕ ЭТАЖИ: общий каркас
# ======================================================================
## Начать сцену дома: этажи first..first+n-1, ширина w и глубина d как у постройки
func _house_begin(id: String, title: String, n: int, w: float, d: float, exit_loc: String, exit_spawn: String, house_name: String) -> void:
	# скрипт дома: scripts/locations/<id>.gd (наследник SungarHouse)
	seed(hash(id))
	root = Node3D.new()
	root.name = id.to_pascal_case()
	root.set_script(load("res://scripts/locations/%s.gd" % id))
	root.set("location_id", id)
	root.set("title", title)
	root.set("map_rect", Rect2(-2, -2, (n - 1) * FLOOR_DX + w + 4, d + 4))
	root.set("camera_start", Vector3(w / 2.0, 0, d / 2.0))
	root.set("floor_count", n)
	root.set("floor_dx", FLOOR_DX)
	root.set("exit_loc", exit_loc)
	root.set("exit_spawn", exit_spawn)
	root.set("house_name", house_name)
	_dark_env(Color("9a8a70"), 0.62)
	var fill := DirectionalLight3D.new()
	fill.name = "Fill"
	fill.light_color = Color("e8dcc8")
	fill.light_energy = 0.45
	fill.rotation = Vector3(deg_to_rad(-60), deg_to_rad(-130), 0)
	root.get_node("Env").add_child(fill)
	fill.owner = root
	group(root, "Village")
	group(root, "Characters")
	group(root, "Items")


func _house_finish(id: String) -> void:
	_finish(id)


## Горожане без своего разговора — с репликами над головой (как жители в Нахарро)
func _finish(id: String) -> void:
	var chars := root.get_node_or_null("Characters")
	if chars and id.begins_with("sungar"):
		for c in chars.get_children():
			if str(c.get("dialog")) == "" and not c.get("hostile"):
				c.set("dialog", "rumors")
	super._finish(id)


## Низкая стена-срез; windows — с окнами «в небо» каждые 2,6 м
func _lw(fl: Node3D, a: Vector2, b: Vector2, mat: String, windows := false) -> void:
	var horiz := absf(a.y - b.y) < 0.01
	var ln := a.distance_to(b)
	if ln < 0.05:
		return
	var mid := (a + b) / 2.0
	var size := Vector3(ln + 0.25, WALL_H, 0.25) if horiz else Vector3(0.25, WALL_H, ln + 0.25)
	box(fl, size, Vector3(mid.x, WALL_H / 2.0, mid.y), mat).owner = root
	_own(collider(fl, Vector3(size.x, 2.6, size.z), Vector3(mid.x, 1.3, mid.y)), root)
	if windows:
		var cnt := int(ln / 2.6)
		for i in cnt:
			var t := (i + 0.5) / float(cnt)
			var p := a.lerp(b, t)
			var ws := Vector3(1.1, 0.32, 0.29) if horiz else Vector3(0.29, 0.32, 1.1)
			box(fl, ws, Vector3(p.x, WALL_H - 0.2, p.y), "window_sky").owner = root


## Стена с проёмами (gaps — координаты середин проёмов вдоль стены).
## _lw удлиняет кусок на 0,125 с каждой стороны (стык углов) — проём режем шире на столько же
func _lw_gaps(fl: Node3D, a: Vector2, b: Vector2, mat: String, gaps: Array) -> void:
	var horiz := absf(a.y - b.y) < 0.01
	var hg := GAP / 2.0 + 0.125
	var cuts := [[a, b]]
	for g in gaps:
		var nc := []
		for c in cuts:
			var c0: Vector2 = c[0]
			var c1: Vector2 = c[1]
			var lo := c0.x if horiz else c0.y
			var hi := c1.x if horiz else c1.y
			var gv: float = g
			if gv > lo and gv < hi:
				if horiz:
					nc.append([c0, Vector2(gv - hg, c0.y)])
					nc.append([Vector2(gv + hg, c0.y), c1])
				else:
					nc.append([c0, Vector2(c0.x, gv - hg)])
					nc.append([Vector2(c0.x, gv + hg), c1])
			else:
				nc.append(c)
		cuts = nc
	for c in cuts:
		_lw(fl, c[0], c[1], mat)


func _bulb(fl: Node3D, pos: Vector3, energy := 0.9, rng := 5.5) -> void:
	var l := OmniLight3D.new()
	l.light_color = Color("ffd9a0")
	l.light_energy = energy
	l.omni_range = rng
	l.position = pos + Vector3(0, 2.4, 0)
	fl.add_child(l)
	l.owner = root


## Табличка с номером над дверью (смотрит в коридор)
func _door_no(fl: Node3D, p: Vector3, txt: String, face_z: float) -> void:
	var l := Label3D.new()
	l.text = txt
	l.font_size = 56
	l.pixel_size = 0.006
	l.modulate = Color("e8e0c8")
	l.outline_size = 8
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.position = p + Vector3(0, WALL_H + 0.35, 0.0 * face_z)
	fl.add_child(l)
	l.owner = root


## Коридорный этаж f: лестничная клетка у западного торца (марш наверх и пролёт вниз),
## коридор вдоль X, комнаты по обе стороны. kinds — сначала северные комнаты (с запада
## на восток), потом южные. Возвращает комнаты: {rect, door, side, kind, no}
func _corridor_floor(f: int, first: int, w: float, d: float, per_side: int, kinds: Array, top: bool,
		wall_out: String, wall_in: String, floor_mat: String, room_floor: String, numbers: int) -> Array:
	var ox := (f - first) * FLOOR_DX
	var fl := group(root.get_node("Village"), "Floor%d" % f)
	var items := root.get_node("Items")
	var cz0 := d / 2.0 - 1.1
	var cz1 := d / 2.0 + 1.1
	var sx := ox + 3.4
	_floor(fl, Rect2(ox, 0, w, d), floor_mat)
	# наружные стены с окнами
	_lw(fl, Vector2(ox, 0), Vector2(ox + w, 0), wall_out, true)
	_lw(fl, Vector2(ox, d), Vector2(ox + w, d), wall_out, true)
	_lw(fl, Vector2(ox, 0), Vector2(ox, d), wall_out, true)
	_lw(fl, Vector2(ox + w, 0), Vector2(ox + w, d), wall_out, true)
	# лестничная клетка отделена от комнат
	_lw(fl, Vector2(sx, 0), Vector2(sx, cz0), wall_in)
	_lw(fl, Vector2(sx, cz1), Vector2(sx, d), wall_in)
	var rw := (w - 3.4) / float(per_side)
	var rooms := []
	var no := numbers
	for side in [0, 1]:
		var z0 := 0.0 if side == 0 else cz1
		var z1 := cz0 if side == 0 else d
		var wz := cz0 if side == 0 else cz1
		var gaps := []
		for i in per_side:
			gaps.append(sx + rw * (i + 0.5))
		_lw_gaps(fl, Vector2(sx, wz), Vector2(ox + w, wz), wall_in, gaps)
		for i in range(1, per_side):
			_lw(fl, Vector2(sx + rw * i, z0), Vector2(sx + rw * i, z1), wall_in)
		for i in per_side:
			var r := Rect2(sx + rw * i, z0, rw, z1 - z0)
			var kind: String = kinds[side * per_side + i] if side * per_side + i < kinds.size() else "bed"
			var dp := Vector3(sx + rw * (i + 0.5), 0, wz)
			var rf := r.grow(-0.12)
			box(fl, Vector3(rf.size.x, 0.02, rf.size.y), Vector3(rf.get_center().x, 0.012, rf.get_center().y),
				room_floor if kind != "kitchen" and kind != "wash" else "tiles").owner = root
			rooms.append({"rect": r, "door": dp, "side": side, "kind": kind, "no": no})
			_door_no(fl, dp + Vector3(0, 0, 0.18 if side == 0 else -0.18), str(no), 1.0 if side == 0 else -1.0)
			_furnish(fl, r, side, kind)
			_bulb(fl, Vector3(r.get_center().x, 0, r.get_center().y), 0.8, 4.5)
			no += 1
	# лестница: марш наверх (если не последний этаж) и пролёт вниз
	if not top:
		put(P.f_stairs, fl, Vector3(ox + 1.0, 0, 1.9), 0.0, "StairsUp")
		_use(items, "Up%d" % f, "Лестница наверх", Vector3(ox + 1.0, 0, 3.55), Vector3(1.3, 1.8, 1.0))
	else:
		box(fl, Vector3(1.4, 0.9, 2.4), Vector3(ox + 1.0, 0.45, 1.9), "planks_old").owner = root
		_own(collider(fl, Vector3(1.4, 1.2, 2.4), Vector3(ox + 1.0, 0.6, 1.9)), root)
	box(fl, Vector3(1.3, 0.03, 2.4), Vector3(ox + 2.55, 0.02, 1.9), "coal").owner = root
	for k in 3:
		box(fl, Vector3(1.3, 0.16, 0.3), Vector3(ox + 2.55, -0.1 - k * 0.2, 2.8 - k * 0.35), "concrete").owner = root
	box(fl, Vector3(0.05, 0.05, 2.4), Vector3(ox + 3.22, 0.95, 1.9), "metal_dark").owner = root
	box(fl, Vector3(1.3, 0.05, 0.05), Vector3(ox + 2.55, 0.95, 0.72), "metal_dark").owner = root
	_own(collider(fl, Vector3(1.3, 1.2, 2.2), Vector3(ox + 2.55, 0.6, 1.8)), root)
	_use(items, "Down%d" % f, "Лестница вниз", Vector3(ox + 2.55, 0, 3.55), Vector3(1.3, 1.4, 1.0))
	_spawn("F%dBelow" % f, Vector3(ox + 2.55, 0, 4.4))
	_spawn("F%dAbove" % f, Vector3(ox + 1.0, 0, 4.4))
	# коридор: свет, батарея, мусор
	for i in int(w / 5.0) + 1:
		_bulb(fl, Vector3(ox + 1.6 + i * 5.0, 0, d / 2.0), 0.7, 5.0)
	box(fl, Vector3(0.9, 0.5, 0.1), Vector3(ox + w - 1.0, 0.45, cz1 - 0.15), "metal_dark").owner = root
	var lbl := Label3D.new()
	lbl.text = "%d ЭТАЖ" % f
	lbl.font_size = 44
	lbl.pixel_size = 0.006
	lbl.modulate = Color("c8c0a8")
	lbl.outline_size = 6
	lbl.position = Vector3(ox + 1.8, WALL_H + 0.3, 0.2)
	fl.add_child(lbl)
	lbl.owner = root
	return rooms


## Обстановка комнаты: мебель — вдоль дальней от двери стены (и боковой), чтобы
## от двери до середины комнаты оставался свободный проход
func _furnish(fl: Node3D, r: Rect2, side: int, kind: String) -> void:
	# «задняя» стена — дальняя от коридора
	var back := r.position.y + 0.25 if side == 0 else r.end.y - 0.25
	var sgn := 1.0 if side == 0 else -1.0
	var rot := 0.0 if side == 0 else PI
	var x0 := r.position.x + 0.7
	var x1 := r.end.x - 0.7
	var cx := r.get_center().x
	var wide := r.size.x > 3.2
	# кровать вдоль задней стены: изголовьем к левой стене
	var bed_back := func(left: bool) -> void:
		var bx := r.position.x + 1.25 if left else r.end.x - 1.25
		put(P.f_bed, fl, Vector3(bx, 0, back + sgn * 0.5), PI / 2.0 if left else -PI / 2.0)
	match kind:
		"bed":
			bed_back.call(true)
			if wide:
				put(P.f_wardrobe, fl, Vector3(x1, 0, back + sgn * 0.3), rot)
		"beds2":
			bed_back.call(true)
			put(P.f_wardrobe, fl, Vector3(x1, 0, back + sgn * 0.3), rot)
			box(fl, Vector3(0.8, 0.012, 1.2), Vector3(cx, 0.05, back + sgn * 1.7), "cloth_sack").owner = root
		"kitchen":
			put(P.f_kitchen_stove, fl, Vector3(x0, 0, back + sgn * 0.3), rot)
			put(P.f_sink, fl, Vector3(x0 + 0.85, 0, back + sgn * 0.3), rot)
			if wide:
				put(P.f_table_kitchen, fl, Vector3(x1 - 0.1, 0, back + sgn * 0.75), rot + PI / 2.0)
		"wash":
			put(P.f_sink, fl, Vector3(x0, 0, back + sgn * 0.3), rot)
			put(P.f_sink, fl, Vector3(x0 + 0.8, 0, back + sgn * 0.3), rot)
			box(fl, Vector3(0.9, 0.5, 0.55), Vector3(x1, 0.25, back + sgn * 0.3), "tin").owner = root
		"cards":
			put(P.f_card_table, fl, Vector3(cx, 0, back + sgn * 1.0), rot)
		"family":
			bed_back.call(true)
			if wide:
				put(P.f_stove, fl, Vector3(x1, 0, back + sgn * 0.4), rot)
			box(fl, Vector3(1.4, 0.012, 1.0), Vector3(cx, 0.05, back + sgn * 1.8), "cloth_red").owner = root
		"radio":
			put(P.f_radio, fl, Vector3(x0 + 0.1, 0, back + sgn * 0.3), rot)
			if wide:
				bed_back.call(false)
		"office":
			put(P.f_shelf, fl, Vector3(cx, 0, back + sgn * 0.25), rot)
			put(P.f_plant, fl, Vector3(x1, 0, back + sgn * 0.3), rot)
			box(fl, Vector3(1.6, 0.012, 1.0), Vector3(cx, 0.05, back + sgn * 1.6), "cloth_red").owner = root
		"store":
			put(P.f_shelf, fl, Vector3(cx, 0, back + sgn * 0.25), rot)
			put(P.crates, fl, Vector3(x0, 0, back + sgn * 0.95), rot)
		"empty":
			put(P.crates, fl, Vector3(x0 + 0.2, 0, back + sgn * 0.5), rot)
			put(P.junk, fl, Vector3(x1 - 0.2, 0, back + sgn * 0.6), rot)
		"tv":
			put(P.f_sofa, fl, Vector3(cx, 0, back + sgn * 0.45), rot)
			put(P.f_plant, fl, Vector3(x1, 0, back + sgn * 0.3), rot)
		"head":
			put(P.cf_terminal, fl, Vector3(cx, 0, back + sgn * 1.0), rot + PI)
			put(P.f_shelf, fl, Vector3(x1 - 0.3, 0, back + sgn * 0.25), rot)
			cyl(fl, 0.03, 0.03, 2.0, Vector3(x0 - 0.2, 1.0, back + sgn * 0.3), "metal_dark").owner = root
			box(fl, Vector3(0.7, 0.45, 0.02), Vector3(x0 + 0.15, 1.7, back + sgn * 0.3), "flag_red").owner = root
			box(fl, Vector3(1.8, 0.012, 1.1), Vector3(cx, 0.05, back + sgn * 2.2), "cloth_red").owner = root
		"meeting":
			put(P.f_table, fl, Vector3(cx - 0.6, 0, back + sgn * 1.0), rot)
			put(P.f_table, fl, Vector3(cx + 0.6, 0, back + sgn * 1.0), rot)
		"computer":
			for k in 3:
				put(P.cf_mainframe, fl, Vector3(r.position.x + 0.75 + k * (r.size.x - 1.5) / 2.0, 0, back + sgn * 0.3), rot)
			put(P.cf_terminal, fl, Vector3(cx, 0, back + sgn * 1.5), rot + PI)
		"archive":
			put(P.f_shelf, fl, Vector3(cx - 1.05, 0, back + sgn * 0.25), rot)
			put(P.f_shelf, fl, Vector3(cx + 1.05, 0, back + sgn * 0.25), rot)
			put(P.crates, fl, Vector3(x1 - 0.2, 0, back + sgn * 1.0), rot)


## Точка в комнате: перед мебелью, ближе к двери
func _rp(room: Dictionary, fx := 0.5, fz := 0.62) -> Vector3:
	var r: Rect2 = room.rect
	var t := fz if int(room.side) == 0 else 1.0 - fz
	return Vector3(r.position.x + r.size.x * fx, 0, r.position.y + r.size.y * t)


## Смотреть из комнаты в коридор
func _to_door(room: Dictionary) -> float:
	return 0.0 if int(room.side) == 0 else PI


# ======================================================================
# ГОСТИНИЦА «ВИЛЮЙ»: 2–3 этажи
# ======================================================================
func _hotel_floors() -> void:
	var w := 14.0
	var d := 9.0
	_house_begin("sungar_hotel", "Гостиница «Вилюй»", 2, w, d, "sungar", "FromHotel", "гостиница")
	var r2 := _corridor_floor(2, 2, w, d, 3, ["beds2", "bed", "wash", "bed", "beds2", "bed"], false,
		"plaster_yellow", "wallpaper", "linoleum", "planks_old", 1)
	var r3 := _corridor_floor(3, 2, w, d, 3, ["cards", "bed", "bed", "bed", "store", "beds2"], true,
		"plaster_yellow", "wallpaper", "linoleum", "planks_old", 7)
	var chars := root.get_node("Characters")
	var items := root.get_node("Items")
	# 2 этаж: торговец Ньургун (украли чемодан), командированный, горничная
	character(chars, "Guest", "sg_guest", _rp(r2[1], 0.55, 0.6), _to_door(r2[1]), {"dialog": "sg_guest"})
	character(chars, "Envoy", "town_m2", _rp(r2[3], 0.5, 0.62), PI, {"display_name": "Командированный"})
	character(chars, "Maid", "town_f3", Vector3(6.0, 0, 4.5), PI / 2.0, {"display_name": "Горничная",
		"patrol": PackedVector3Array([Vector3(6.0, 0, 4.5), Vector3(12.8, 0, 4.4)]), "patrol_wait": 6.0})
	# номер 6 — герою, если заплатил дежурной
	var r6: Dictionary = r2[5]
	_use(items, "HotelBed", "Кровать в номере 6", _rp(r6, 0.36, 0.2), Vector3(2.0, 1.0, 1.2)).set("reach", 2)
	# 3 этаж: картёжники, старый Арчылан (говорит только по-старому), номер 9 Боотура
	var rc: Dictionary = r3[0]
	var ct := _rp(rc, 0.5, 0.3)
	for k in 3:
		var p: Vector3 = ct + [Vector3(-1.05, 0, 0), Vector3(1.05, 0, 0), Vector3(0, 0, 0.75)][k]
		character(chars, "Card%d" % (k + 1), ["town_m4", "town_worker", "town_m1"][k], p, _face(p, ct),
			{"display_name": ["Картёжник", "Подёнщик за картами", "Шулер с золотым зубом"][k]})
	character(chars, "Archylan", "sg_archylan", _rp(r3[3], 0.6, 0.6), _to_door(r3[3]), {"dialog": "sg_archylan"})
	var r9: Dictionary = r3[2]
	_use(items, "LooseBoard", "Половица в номере 9", _rp(r9, 0.6, 0.55), Vector3(1.0, 0.4, 1.0))
	character(chars, "Drunk", "villager", _rp(r3[4], 0.5, 0.6), PI, {"display_name": "Спящий постоялец", "start_pose": "down"})
	_house_finish("sungar_hotel")


# ======================================================================
# ДОМ НА ПЛОЩАДИ (ул. Ленина, 3): 2–4 этажи
# ======================================================================
func _dom_floors() -> void:
	var w := 16.0
	var d := 9.0
	_house_begin("sungar_dom", "Дом на площади", 3, w, d, "sungar_center", "FromDom", "жилой дом")
	var r2 := _corridor_floor(2, 2, w, d, 3, ["family", "kitchen", "bed", "office", "bed", "tv"], false,
		"plaster_pink", "wallpaper_b", "linoleum", "planks_old", 4)
	var r3 := _corridor_floor(3, 2, w, d, 3, ["kitchen", "family", "bed", "family", "bed", "empty"], false,
		"plaster_pink", "wallpaper", "linoleum", "planks_old", 10)
	var r4 := _corridor_floor(4, 2, w, d, 3, ["radio", "bed", "empty", "cards", "bed", "kitchen"], true,
		"plaster_pink", "wallpaper_b", "linoleum_b", "planks_old", 16)
	var chars := root.get_node("Characters")
	var items := root.get_node("Items")
	# 2 этаж: учительница Сахая, соседи
	character(chars, "Teacher", "sg_teacher", _rp(r2[3], 0.5, 0.55), _to_door(r2[3]), {"dialog": "sg_teacher"})
	character(chars, "Neighbor1", "town_f2", _rp(r2[1], 0.35, 0.5), _to_door(r2[1]) + PI, {"display_name": "Соседка у плиты"})
	character(chars, "Neighbor2", "town_old_m", _rp(r2[5], 0.5, 0.13), _to_door(r2[5]), {"display_name": "Дед на диване", "start_pose": "sit"})
	character(chars, "StairKid", "kid", Vector3(7.0, 0, 4.4), PI / 2.0, {"display_name": "Мальчишка в коридоре",
		"patrol": PackedVector3Array([Vector3(7.0, 0, 4.4), Vector3(15.0, 0, 4.6)]), "patrol_wait": 2.0})
	# 3 этаж: мать с больным сыном, старик
	var rm: Dictionary = r3[1]
	character(chars, "Mother", "sg_mother", _rp(rm, 0.42, 0.6), _to_door(rm) + PI, {"dialog": "sg_mother"})
	var sb := _rp(rm, 0.62, 0.32)
	box(root.get_node("Village/Floor3"), Vector3(0.9, 0.12, 1.6), sb + Vector3(0, 0.06, 0), "cloth_sack").owner = root
	character(chars, "SickBoy", "kid", sb, PI / 2.0, {"display_name": "Больной мальчик", "start_pose": "sit"})
	character(chars, "Neighbor3", "town_old_f", _rp(r3[0], 0.4, 0.5), _to_door(r3[0]) + PI, {"display_name": "Бабушка с кастрюлей"})
	character(chars, "Neighbor4", "town_m3", _rp(r3[3], 0.6, 0.6), _to_door(r3[3]), {"display_name": "Сосед в майке"})
	# 4 этаж: радиолюбитель Кеша, картёжники
	character(chars, "Radio", "sg_radio", _rp(r4[0], 0.25, 0.45), _to_door(r4[0]) + PI, {"dialog": "sg_radio"})
	_use(items, "RadioSet", "Радиостанция Кеши", _rp(r4[0], 0.19, 0.12), Vector3(1.2, 1.6, 0.8)).set("reach", 2)
	var rc: Dictionary = r4[3]
	var ct := _rp(rc, 0.5, 0.3)
	for k in 2:
		var p := ct + Vector3(-1.05 + k * 2.1, 0, 0)
		character(chars, "Card%d" % (k + 1), ["town_worker", "town_m4"][k], p, _face(p, ct), {"display_name": ["Пьяный картёжник", "Сосед-картёжник"][k]})
	_house_finish("sungar_dom")


# ======================================================================
# ОБЩЕЖИТИЕ № 2: 2–4 этажи
# ======================================================================
func _obshaga_floors() -> void:
	var w := 12.0
	var d := 8.5
	_house_begin("sungar_obshaga", "Общежитие № 2", 3, w, d, "sungar_quarter", "FromObshaga", "общежитие")
	var r2 := _corridor_floor(2, 2, w, d, 3, ["kitchen", "kitchen", "wash", "bed", "family", "bed"], false,
		"brick_white", "paint_blue", "linoleum_b", "linoleum", 201)
	var r3 := _corridor_floor(3, 2, w, d, 3, ["bed", "cards", "bed", "beds2", "bed", "empty"], false,
		"brick_white", "paint_green", "linoleum_b", "linoleum", 301)
	var r4 := _corridor_floor(4, 2, w, d, 3, ["bed", "beds2", "bed", "store", "bed", "empty"], true,
		"brick_white", "paint_blue", "linoleum_b", "linoleum", 401)
	var chars := root.get_node("Characters")
	var items := root.get_node("Items")
	# 2 этаж: общая кухня
	character(chars, "Cook1", "town_f1", _rp(r2[0], 0.45, 0.5), _to_door(r2[0]) + PI, {"display_name": "Жиличка у плиты"})
	character(chars, "Cook2", "town_f3", _rp(r2[1], 0.5, 0.62), _to_door(r2[1]), {"display_name": "Жиличка с тазом"})
	character(chars, "ObKid2", "kid", _rp(r2[4], 0.7, 0.7), 0.3, {"display_name": "Девочка"})
	character(chars, "Mom", "town_f2", _rp(r2[4], 0.35, 0.55), PI, {"display_name": "Молодая мать"})
	# 3 этаж: подёнщики режутся в карты, пьяный в коридоре
	var rc: Dictionary = r3[1]
	var ct := _rp(rc, 0.5, 0.3)
	for k in 3:
		var p: Vector3 = ct + [Vector3(-1.0, 0, 0), Vector3(1.0, 0, 0), Vector3(0, 0, 0.75)][k]
		character(chars, "Card%d" % (k + 1), ["town_worker", "town_m3", "villager"][k], p, _face(p, ct),
			{"display_name": ["Подёнщик", "Грузчик с баржи", "Сезонник"][k]})
	character(chars, "DrunkOb", "villager", Vector3(9.5 + FLOOR_DX, 0, 4.0), 0.0, {"display_name": "Пьяный в коридоре", "start_pose": "down"})
	character(chars, "Smoker", "town_m1", _rp(r3[3], 0.4, 0.65), PI, {"display_name": "Курильщик"})
	# 4 этаж: Сенька-вор и его каморка с краденым
	var rt: Dictionary = r4[3]
	character(chars, "Thief", "sg_thief", _rp(rt, 0.55, 0.65), _to_door(rt), {"dialog": "sg_thief"})
	_use(items, "Suitcase", "Чемодан под кроватью", _rp(rt, 0.75, 0.3), Vector3(1.0, 0.7, 0.8))
	character(chars, "Old4", "town_old_m", _rp(r4[0], 0.5, 0.62), _to_door(r4[0]), {"display_name": "Старый вахтёр на пенсии"})
	_house_finish("sungar_obshaga")


# ======================================================================
# АДМИНИСТРАЦИЯ ПГТ СУНГАР: 2–3 этажи (глава посёлка, ЭВМ «Искра-1030»)
# ======================================================================
func _admin_floors() -> void:
	var w := 16.0
	var d := 10.0
	_house_begin("sungar_admin", "Администрация ПГТ Сунгар", 2, w, d, "sungar_center", "FromAdmin", "администрация")
	var r2 := _corridor_floor(2, 2, w, d, 3, ["head", "office", "meeting", "office", "archive", "wash"], false,
		"plaster_white", "wallpaper_b", "linoleum", "planks_old", 201)
	var r3 := _corridor_floor(3, 2, w, d, 3, ["computer", "computer", "office", "archive", "bed", "empty"], true,
		"plaster_white", "wallpaper", "linoleum_b", "linoleum", 301)
	var chars := root.get_node("Characters")
	var items := root.get_node("Items")
	# 2 этаж: глава посёлка, секретарша, бухгалтер, охрана в коридоре
	var rh: Dictionary = r2[0]
	character(chars, "Head", "sg_head", _rp(rh, 0.5, 0.15), _to_door(rh), {"dialog": "sg_head"})
	character(chars, "Secretary", "town_f2", _rp(r2[1], 0.5, 0.6), _to_door(r2[1]), {"display_name": "Секретарша"})
	character(chars, "Accountant", "town_m2", _rp(r2[3], 0.5, 0.6), _to_door(r2[3]), {"display_name": "Бухгалтер с калькулятором"})
	_cop(chars, "FloorCop", Vector3(9.0, 0, d / 2.0), PI / 2.0, PackedVector3Array([Vector3(9.0, 0, d / 2.0), Vector3(15.0, 0, d / 2.0)]), "Охранник администрации")
	# 3 этаж: машинный зал ЭВМ, оператор Люда
	var rc: Dictionary = r3[0]
	character(chars, "Operator", "sg_operator", _rp(rc, 0.3, 0.65), _to_door(rc) + PI, {"dialog": "sg_operator"})
	_use(items, "Mainframe", "ЭВМ «Искра-1030»", _rp(rc, 0.18, 0.2), Vector3(1.2, 1.9, 0.8)).set("reach", 2)
	var rt: Dictionary = r3[1]
	_use(items, "ArchiveTerminal", "Терминал архива", _rp(rt, 0.5, 0.38), Vector3(1.2, 1.2, 0.9)).set("reach", 2)
	character(chars, "Tech", "town_m4", _rp(r3[2], 0.5, 0.6), _to_door(r3[2]), {"display_name": "Техник с паяльником"})
	_house_finish("sungar_admin")
