extends "res://tools/build_nyurba.gd"
## Локации востока по сюжету: Мар-Кун (финал Акта I), Промзона МИР, Мирный и ГЭС (Акт III),
## Рубикон, Горный и комплекс под ГРЭС-2 (Акт IV).
## Запуск: godot --headless --path . res://tools/build_east.tscn [-- markun|mir|mirny|ges|rubikon|gorny|complex]
## Без аргумента — всё.


func _build() -> void:
	super._load_all()
	for n in ["izba_small", "izba_lean", "shed", "burnt_shed", "fence_broken", "smokehouse", "fish_rack", "kennel", "dead_tree",
			"rock_big", "rock", "fire", "firewood", "barrel", "crates", "bench", "stump", "log_fallen", "spruce_b", "birch_b", "pine_b"]:
		if ResourceLoader.exists(PROP_DIR + n + ".tscn"):
			P[n] = load(PROP_DIR + n + ".tscn")
	for n in ["metal_green", "paint_orange", "roof_moss", "metal", "stone", "enamel", "sofa", "glass_city", "frame_white"]:
		if ResourceLoader.exists(MAT_DIR + n + ".tres"):
			M[n] = load(MAT_DIR + n + ".tres")
	for n in ["st_admin", "st_office", "st_police", "st_canteen", "st_obshaga", "st_store", "st_res4", "st_hotel"]:
		P[n] = load(PROP_DIR + n + ".tscn")
	var only := ""
	for a in OS.get_cmdline_user_args():
		only = a
	if only == "" or only == "markun":
		_markun()
	if only == "" or only == "mirny":
		_mirny()
		_quarry()


## Ржавый морской контейнер — жильё Мар-Куна: дверь прорезана, сверху мох и шкуры
func _container(parent: Node, pos: Vector3, rot: float, nm: String, col := "rust") -> Node3D:
	var g := Node3D.new()
	g.name = nm
	g.position = pos
	g.rotation.y = rot
	parent.add_child(g)
	g.owner = root
	box(g, Vector3(6.0, 2.5, 2.4), Vector3(0, 1.25, 0), col).owner = root
	for i in 9:
		box(g, Vector3(0.06, 2.4, 2.45), Vector3(-2.8 + i * 0.7, 1.25, 0), "metal_dark").owner = root
	box(g, Vector3(1.0, 1.9, 0.06), Vector3(1.4, 0.95, 1.22), "coal").owner = root
	box(g, Vector3(1.1, 1.8, 0.04), Vector3(1.4, 0.9, 1.26), "cloth_sack").owner = root
	box(g, Vector3(6.2, 0.12, 2.6), Vector3(0, 2.56, 0), "roof_moss").owner = root
	box(g, Vector3(2.0, 0.08, 1.4), Vector3(-1.4, 2.66, 0.3), "cloth_sack", Vector3(0, 0.3, 0)).owner = root
	var l := Label3D.new()
	l.text = "КОРП-%03d" % (randi() % 900 + 100)
	l.font_size = 48
	l.pixel_size = 0.008
	l.modulate = Color("d8d0b0")
	l.position = Vector3(-1.4, 1.6, 1.23)
	g.add_child(l)
	l.owner = root
	_own(collider(g, Vector3(6.0, 2.5, 2.4), Vector3(0, 1.25, 0)), root)
	return g


## Землянка: холм из дёрна, дощатый вход, труба с дымом
func _dugout(parent: Node, pos: Vector3, rot: float, nm: String) -> Node3D:
	var g := Node3D.new()
	g.name = nm
	g.position = pos
	g.rotation.y = rot
	parent.add_child(g)
	g.owner = root
	sphere(g, 2.4, Vector3(0, -0.6, 0), "roof_moss", Vector3(1.2, 0.75, 1.0)).owner = root
	box(g, Vector3(1.3, 1.6, 0.9), Vector3(0, 0.8, 2.1), "planks_old").owner = root
	box(g, Vector3(0.8, 1.4, 0.05), Vector3(0, 0.7, 2.56), "coal").owner = root
	cyl(g, 0.1, 0.1, 1.2, Vector3(0.8, 1.6, -0.4), "metal_dark").owner = root
	_own(collider(g, Vector3(4.6, 1.6, 4.0), Vector3(0, 0.8, 0)), root)
	return g


# ======================================================================
# МАР-КУН — внуки беглецов другой корпорации: скудная злая земля, жильё из ржавых
# контейнеров и землянок, «планёрка» у огня, «инструкция по ТБ» — святыня.
# У ручья на севере стоят лагерем чистильщики: ждут проводника.
# ======================================================================
func _markun() -> void:
	var rect := Rect2(0, 0, 72, 60)
	_begin("markun", "Мар-Кун", rect, "res://scripts/locations/markun.gd")
	var d := "ground_dirt"
	strip(null, Vector2(-6, 32), Vector2(30, 32), 2.4, d)
	strip(null, Vector2(36, 32), Vector2(60, 12), 1.6, d)
	strip(null, Vector2(30, 36), Vector2(6, 58), 1.2, d)
	road_segs.append([Vector2(-6, 32), Vector2(30, 32), 2.0])
	road_segs.append([Vector2(36, 32), Vector2(60, 12), 1.2])
	road_segs.append([Vector2(30, 36), Vector2(6, 58), 1.0])
	road_segs.append([Vector2(30, 28), Vector2(42, 36), 7.0])
	_mud.append(Rect2(20, 20, 32, 24))
	_mud.append(Rect2(54, 2, 16, 14))
	_clear.append(Rect2(8, 8, 60, 50))
	_clear.append(Rect2(50, 0, 22, 18))
	_ground_for("markun")
	var vil := group(root, "Village")
	# ручей на севере: тёмная вода в русле
	var cr := group(vil, "Creek")
	cr.set_meta("no_xray", true)
	for i in 14:
		var x := i * 5.5
		box(cr, Vector3(6.0, 0.03, 2.2), Vector3(x, 0.02, 3.0 + sin(i * 0.8) * 1.2), "tar").owner = root
	# частокол из плавника — кусками, недоделан
	for z in [18.0, 22.0, 26.0, 38.0, 42.0, 46.0]:
		put(P.fence_broken if int(z) % 8 == 2 else P.palisade, vil, Vector3(16, 0, z), PI / 2.0)
	# жильё кольцом вокруг огня планёрки
	var homes := [
		["Cont1", "c", Vector3(26, 0, 22), 0.4], ["Cont2", "c", Vector3(40, 0, 20), -0.3], ["Cont3", "c", Vector3(48, 0, 30), -1.4],
		["Cont4", "c", Vector3(44, 0, 44), 2.6], ["Dug1", "d", Vector3(24, 0, 42), 2.4], ["Dug2", "d", Vector3(33, 0, 47), 3.1],
		["Dug3", "d", Vector3(20, 0, 32), 1.6], ["Hut1", "h", Vector3(52, 0, 40), -2.2]]
	for h in homes:
		match str(h[1]):
			"c":
				_container(vil, h[2], h[3], h[0], "rust" if h[0] != "Cont3" else "paint_faded")
			"d":
				_dugout(vil, h[2], h[3], h[0])
			_:
				put(P.izba_lean, vil, h[2], h[3], h[0])
	# огонь планёрки: кострище, брёвна-лавки
	put(P.fire, vil, Vector3(35, 0, 33), 0.0, "Fire")
	for k in 5:
		var a := TAU * k / 5.0 + 0.3
		put(P.log_fallen, vil, Vector3(35 + cos(a) * 3.2, 0, 33 + sin(a) * 3.2), a + PI / 2.0)
	_lamp(vil, "FireLight", Vector3(35, 1.4, 33), Color("ff9a4a"), 1.8, 9.0)
	# святыня: лист инструкции в раме на столбе, вокруг — амулеты из плат
	var sh := group(vil, "Shrine")
	sh.position = Vector3(30, 0, 29)
	box(sh, Vector3(0.25, 2.4, 0.25), Vector3(0, 1.2, 0), "log_dark").owner = root
	box(sh, Vector3(1.3, 1.0, 0.08), Vector3(0, 1.9, 0.15), "planks_old").owner = root
	box(sh, Vector3(1.1, 0.8, 0.02), Vector3(0, 1.9, 0.2), "paper").owner = root
	for i in 6:
		box(sh, Vector3(0.18, 0.12, 0.02), Vector3(-0.55 + i * 0.22, 1.2 + (i % 2) * 0.12, 0.17), "screen_green" if i % 3 == 0 else "paint_green").owner = root
	var t := Label3D.new()
	t.text = "ИНСТРУКЦИЯ\nпо технике\nбезопасности"
	t.font_size = 40
	t.pixel_size = 0.004
	t.modulate = Color("2a2a26")
	t.position = Vector3(0, 1.95, 0.22)
	sh.add_child(t)
	t.owner = root
	_own(collider(sh, Vector3(0.4, 2.4, 0.4), Vector3(0, 1.2, 0)), root)
	# хозяйство: сушилки с рыбой, шкуры, поленница, коптильня
	put(P.fish_rack, vil, Vector3(38, 0, 26), 0.2)
	put(P.fish_rack, vil, Vector3(28, 0, 38), 1.4)
	put(P.smokehouse, vil, Vector3(46, 0, 24), -0.8)
	put(P.firewood, vil, Vector3(22, 0, 27), 0.3)
	put(P.kennel, vil, Vector3(42, 0, 38), 2.0)
	for p in [Vector3(30, 0, 24), Vector3(41, 0, 40)]:
		box(vil, Vector3(1.4, 1.1, 0.04), p + Vector3(0, 0.9, 0), "cloth_sack", Vector3(0, randf() * PI, 0.08)).owner = root
	# скудная земля: валуны, сухостой
	for p in [Vector3(10, 0, 12), Vector3(58, 0, 52), Vector3(64, 0, 34), Vector3(8, 0, 48), Vector3(52, 0, 18), Vector3(12, 0, 24)]:
		put(P.rock_big, vil, p, randf() * TAU, "", randf_range(0.8, 1.3))
	for p in [Vector3(18, 0, 10), Vector3(60, 0, 44), Vector3(6, 0, 40), Vector3(66, 0, 24), Vector3(50, 0, 54)]:
		put(P.dead_tree, vil, p, randf() * TAU)
	# лагерь чистильщиков у ручья: палатка, ящики, рация на треноге, костёр
	var camp := group(vil, "CleanerCamp")
	camp.position = Vector3(62, 0, 10)
	box(camp, Vector3(3.6, 0.05, 3.0), Vector3(0, 0.02, 0), "cloth_sack").owner = root
	prism(camp, Vector3(3.4, 1.9, 3.0), Vector3(0, 0.95, 0), "paint_faded").owner = root
	for i in 3:
		box(camp, Vector3(0.8, 0.5, 0.6), Vector3(-2.6, 0.25 + i * 0.5, 1.6), "metal_dark").owner = root
	cyl(camp, 0.03, 0.03, 1.4, Vector3(2.6, 0.7, 1.4), "metal_dark").owner = root
	box(camp, Vector3(0.5, 0.35, 0.3), Vector3(2.6, 1.45, 1.4), "metal_dark").owner = root
	box(camp, Vector3(0.3, 0.12, 0.02), Vector3(2.6, 1.5, 1.56), "screen_amber").owner = root
	_own(collider(camp, Vector3(3.6, 1.9, 3.0), Vector3(0, 0.95, 0)), root)
	put(P.fire, vil, Vector3(58.5, 0, 13.0), 0.0)
	_woods(70)
	_dress(Rect2(4, 4, 64, 52), 240)
	# --- люди Мар-Куна ---
	var chars := group(root, "Characters")
	character(chars, "Chief", "mk_chief", Vector3(36.6, 0, 30.2), -2.4, {"dialog": "mk_chief", "display_name": "Начальник участка"})
	character(chars, "Instructor", "mk_instructor", Vector3(30.8, 0, 30.4), PI, {"dialog": "mk_instructor", "display_name": "Инструктор по ТБ"})
	character(chars, "Hunter1", "mk_hunter", Vector3(24.0, 0, 33.5), PI / 2.0, {"display_name": "Сменный Отвёртка", "armed": true})
	character(chars, "Hunter2", "mk_hunter", Vector3(42.0, 0, 27.0), -2.0, {"display_name": "Сменный Ключ", "armed": true})
	character(chars, "Hunter3", "mk_hunter", Vector3(46.5, 0, 36.5), -1.2, {"display_name": "Сменный Табель", "armed": true})
	character(chars, "Woman1", "mk_woman", Vector3(37.4, 0, 26.6), 0.4, {"display_name": "Нормировщица"})
	character(chars, "Woman2", "mk_woman", Vector3(29.0, 0, 37.6), 2.2, {"display_name": "Накладная"})
	character(chars, "Old1", "mk_old", Vector3(33.0, 0, 35.8), -0.6, {"display_name": "Кладовщик", "start_pose": "sit"})
	character(chars, "Kid1", "kid", Vector3(38.0, 0, 35.5), 1.0, {"display_name": "Пропуск, мальчишка",
		"patrol": PackedVector3Array([Vector3(38.0, 0, 35.5), Vector3(26, 0, 30.0), Vector3(40, 0, 42.0)]), "patrol_wait": 3.0})
	# чистильщики — пока ждут; станут врагами, когда пойдут на участок
	character(chars, "CleanerBoss", "cleaner_boss", Vector3(60.0, 0, 13.6), -2.4, {"squad": "mk_cleaners", "armed": true})
	var k := 0
	for p in [Vector3(57.5, 0, 11.4), Vector3(64.8, 0, 13.6), Vector3(59.0, 0, 15.8), Vector3(66.0, 0, 8.0)]:
		character(chars, "Cleaner%d" % k, "cleaner", p, randf() * TAU, {"squad": "mk_cleaners", "armed": true})
		k += 1
	var items := group(root, "Items")
	_exit(items, "WestExit", "На тракт", Vector3(1.0, 0, 32.0), Vector3(1.6, 2.2, 4.0))
	_use(items, "Shrine", "Лист инструкции", Vector3(30, 0, 29.6), Vector3(1.2, 2.4, 0.6))
	_use(items, "Tent", "Палатка чистильщиков", Vector3(62, 0, 11.8), Vector3(3.0, 1.8, 1.0))
	_use(items, "Radio", "Рация на треноге", Vector3(64.6, 0, 11.4), Vector3(0.8, 1.6, 0.8))
	_spawn("Start", Vector3(4.0, 0, 32.0))
	_spawn("Road", Vector3(4.0, 0, 32.0))
	_spawn("Trail", Vector3(8.0, 0, 55.0))
	marker(root, "MarkFire", Vector3(35, 0, 33), "Огонь планёрки")
	marker(root, "MarkCamp", Vector3(62, 0, 10), "Лагерь серых")
	marker(root, "MarkTrail", Vector3(8, 0, 56), "Тропа на юг")
	_finish("markun")


# ======================================================================
# МИРНЫЙ — город контрастов вокруг мёртвого карьера. Кольцевая дорога, четыре района:
# северо-запад — «Кимберлит» (штаб, флаги), северо-восток — совет республиканцев и штаб
# йегерей с площадью суда, юго-запад — рабочие (профком, цех, бараки), юго-восток — рейдеры
# (баррикады из лома, притон). С севера к карьеру — серпантин вниз (сцена mirny_quarry).
# ======================================================================
const MR := 120.0
const QC := Vector3(60, 0, 60)
const QR := 22.0


func _quarry_pit(parent: Node) -> void:
	var g := group(parent, "Quarry")
	g.set_meta("no_xray", true)
	# воронка: кольца уступов светлее у края и темнее к дну — сверху читается как глубина
	var cols := ["#5e5a50", "#504c44", "#433f39", "#36332e", "#2a2824", "#1f1d1a", "#151412", "#0c0b0a"]
	for i in cols.size():
		var r := QR - i * 2.6
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(cols[i])
		m.roughness = 1.0
		M["pit%d" % i] = m
		cyl(g, r, r + 0.4, 0.06, QC + Vector3(0, 0.03 + i * 0.004, 0), "pit%d" % i, Vector3.ZERO, 48).owner = root
		# бровка уступа: светлая полоса по кругу
		if i > 0:
			var mb := StandardMaterial3D.new()
			mb.albedo_color = Color(cols[i - 1]).lightened(0.08)
			M["pitb%d" % i] = mb
			cyl(g, r + 0.25, r + 0.3, 0.07, QC + Vector3(0, 0.035 + i * 0.004, 0), "pitb%d" % i, Vector3.ZERO, 48).owner = root
	# серпантин: светлая лента по спирали от северной бровки вниз
	var sp := StandardMaterial3D.new()
	sp.albedo_color = Color("6a6252")
	M["ramp"] = sp
	for k in 26:
		var a := -PI / 2.0 + k * 0.42
		var r := QR - 1.0 - k * 0.7
		if r < 3.0:
			break
		box(g, Vector3(2.0, 0.02, r * 0.42 + 0.4), QC + Vector3(cos(a) * r, 0.1, sin(a) * r), "ramp", Vector3(0, -a, 0)).owner = root
	# бруствер и ограждение по краю, с проходом к серпантину на севере
	for k in 64:
		var a := TAU * k / 64.0
		if absf(wrapf(a + PI / 2.0, -PI, PI)) < 0.12:
			continue
		var p := QC + Vector3(cos(a), 0, sin(a)) * (QR + 0.8)
		box(g, Vector3(0.12, 1.2, 0.12), p + Vector3(0, 0.6, 0), "rust").owner = root
		box(g, Vector3(2.3, 0.06, 0.06), p + Vector3(0, 1.0, 0), "rust", Vector3(0, -a + PI / 2.0, 0)).owner = root
		_own(collider(g, Vector3(2.4, 1.4, 0.4), p + Vector3(0, 0.7, 0), -a + PI / 2.0), root)
	# брошенная техника у бровки: БелАЗ без колёс, экскаватор
	var tr := group(g, "Belaz")
	tr.position = QC + Vector3(-QR - 5.0, 0, -8.0)
	box(tr, Vector3(4.2, 2.4, 7.0), Vector3(0, 2.0, 0), "paint_orange").owner = root
	box(tr, Vector3(3.8, 1.6, 2.2), Vector3(0, 2.4, 4.2), "rust").owner = root
	for sx in [-1, 1]:
		for sz in [-2.2, 2.4]:
			cyl(tr, 1.0, 1.0, 0.9, Vector3(sx * 2.2, 1.0, sz), "tire", Vector3(0, 0, PI / 2.0), 14).owner = root
	_own(collider(tr, Vector3(5.0, 3.0, 8.0), Vector3(0, 1.5, 0.6)), root)
	var ex := group(g, "Excavator")
	ex.position = QC + Vector3(QR + 5.5, 0, 9.0)
	ex.rotation.y = PI / 2.0
	box(ex, Vector3(4.0, 2.8, 4.0), Vector3(0, 2.2, 0), "paint_orange").owner = root
	box(ex, Vector3(4.6, 0.8, 5.4), Vector3(0, 0.4, 0), "metal_dark").owner = root
	box(ex, Vector3(0.6, 0.6, 8.0), Vector3(0, 4.2, -5.0), "rust", Vector3(0.45, 0, 0)).owner = root
	_own(collider(ex, Vector3(4.6, 3.0, 5.4), Vector3(0, 1.5, 0)), root)


func _flagpole(parent: Node, pos: Vector3, mat: String, emblem := "") -> void:
	cyl(parent, 0.05, 0.06, 6.0, pos + Vector3(0, 3.0, 0), "metal_dark").owner = root
	box(parent, Vector3(1.6, 1.0, 0.03), pos + Vector3(0.8, 5.4, 0), mat).owner = root
	if emblem != "":
		var l := Label3D.new()
		l.text = emblem
		l.font_size = 96
		l.pixel_size = 0.006
		l.modulate = Color("f0f0e8")
		l.position = pos + Vector3(0.8, 5.4, 0.03)
		parent.add_child(l)
		l.owner = root


func _poster(parent: Node, text: String, pos: Vector3, rot: float, col: Color) -> void:
	_signboard(parent, text, pos, rot, 3.0, col)


func _mirny() -> void:
	var rect := Rect2(0, 0, MR, MR)
	_begin("mirny", "Мирный", rect, "res://scripts/locations/mirny.gd")
	var d := "ground_dirt"
	# кольцо вокруг карьера и четыре луча
	for k in 32:
		var a0 := TAU * k / 32.0
		var a1 := TAU * (k + 1) / 32.0
		var r := QR + 5.0
		var p0 := Vector2(QC.x + cos(a0) * r, QC.z + sin(a0) * r)
		var p1 := Vector2(QC.x + cos(a1) * r, QC.z + sin(a1) * r)
		strip(null, p0, p1, 5.0, d)
		road_segs.append([p0, p1, 2.4])
	for seg in [[Vector2(-8, 60), Vector2(QC.x - QR - 5, 60)], [Vector2(QC.x + QR + 5, 60), Vector2(MR + 8, 60)],
			[Vector2(60, -8), Vector2(60, QC.z - QR - 5)], [Vector2(60, QC.z + QR + 5), Vector2(60, MR + 8)]]:
		strip(null, seg[0], seg[1], 6.0, d)
		road_segs.append([seg[0], seg[1], 3.0])
	_street_out(Vector2(0, 60), -1.0)
	_street_out(Vector2(MR, 60), 1.0)
	_mud.append(Rect2(84, 74, 30, 30))
	_mud.append(Rect2(6, 76, 30, 20))
	_clear.append(Rect2(-8, -8, MR + 16, MR + 16))
	_ground_for("mirny")
	var vil := group(root, "Village")
	_quarry_pit(vil)
	# --- северо-запад: «Кимберлит» — чисто, побелено, флаги ---
	var kim := _bld(vil, "nr_gov", "KimberlitHQ", Vector3(26.0, 0, 24.0))
	_sign_on(vil, kim, "«КИМБЕРЛИТ» · ПОРЯДОК · СВЕТ · РАБОТА", 7.0, Color("f0f0e8"))
	_bld(vil, "nr_stalin4", "KimHouse1", Vector3(24.0, 0, 6.0))
	_bld(vil, "nr_stalin3", "KimHouse2", Vector3(46.0, 0, 8.0))
	for x in [12.0, 18.0, 34.0, 40.0]:
		_flagpole(vil, Vector3(x, 0, 33.6), "paint_white", "◬")
	_poster(vil, "ПОРЯДОК · СВЕТ · РАБОТА", Vector3(46.0, 2.2, 38.0), 0.0, Color("f0f0e8"))
	# --- северо-восток: совет республиканцев, штаб йегерей, площадь суда ---
	var council := _bld(vil, "st_admin", "Council", Vector3(92.0, 0, 22.0))
	_sign_on(vil, council, "СОВЕТ МИРНОГО · ВЫБОРЫ — ЛЮДЯМ", 6.0, Color("e8e0c8"))
	var jhq := _bld(vil, "st_office", "JaegerHQ", Vector3(106.0, 0, 40.0), -PI / 2.0)
	_signboard(vil, "JAEGER CORP · ХАХАЙ", _slot(jhq, "sign"), -PI / 2.0, 4.6, Color("e8c060"))
	_bld(vil, "nr_stalin3", "RepHouse", Vector3(96.0, 0, 6.0))
	# помост суда: доски, столб, ступени
	var sc := group(vil, "Scaffold")
	sc.position = Vector3(84.0, 0, 42.0)
	box(sc, Vector3(5.0, 1.0, 4.0), Vector3(0, 0.5, 0), "planks_old").owner = root
	box(sc, Vector3(0.25, 3.6, 0.25), Vector3(-1.6, 2.8, -1.2), "log_dark").owner = root
	box(sc, Vector3(2.0, 0.2, 0.2), Vector3(-0.7, 4.5, -1.2), "log_dark").owner = root
	box(sc, Vector3(0.04, 1.2, 0.04), Vector3(0.2, 3.8, -1.2), "rope_mat").owner = root
	for i in 3:
		box(sc, Vector3(1.6, 0.25, 0.4), Vector3(1.2, 0.12 + i * 0.25, 2.2 - i * 0.4), "planks_old").owner = root
	_own(collider(sc, Vector3(5.0, 1.0, 4.0), Vector3(0, 0.5, 0)), root)
	_poster(vil, "СУД ПОЛИСА — ЗДЕСЬ", Vector3(84.0, 2.6, 39.6), PI, Color("e8c060"))
	for x in [78.0, 90.0]:
		_flagpole(vil, Vector3(x, 0, 34.0), "paint_blue", "♌")
	# --- юго-запад: рабочие ---
	var union := _bld(vil, "st_canteen", "Union", Vector3(26.0, 0, 92.0), PI)
	_sign_on(vil, union, "ПРОФКОМ «КАРЬЕР»", 3.8, Color("f0e0c0"))
	_bld(vil, "nr_factory_b", "Workshop", Vector3(28.0, 0, 110.0), PI)
	_bld(vil, "st_barrack2", "Barrack1", Vector3(8.0, 0, 84.0), PI / 2.0)
	_bld(vil, "st_obshaga", "Obshaga", Vector3(46.0, 0, 104.0), PI)
	_poster(vil, "ТОК — ЛЮДЯМ!", Vector3(40.0, 2.4, 84.0), PI, Color("ff7a4a"))
	# --- юго-восток: рейдеры — баррикады из лома, лачуги, притон ---
	var den := _bld(vil, "nr_ryumka", "RaiderDen", Vector3(94.0, 0, 96.0), PI)
	_sign_on(vil, den, "ПРИТОН «ДЫРА»", 3.0, Color("ffb23a"))
	var bar := group(vil, "Barricade")
	for i in 7:
		_junk_fence(bar, Vector3(78.0 + i * 4.0, 0, 82.0), 0.0, i == 3)
	for i in 5:
		_junk_fence(bar, Vector3(78.0, 0, 86.0 + i * 4.0), PI / 2.0, false)
	var shk := group(vil, "Shacks")
	for spec in [[Vector3(104, 0, 88), 0.1, 0], [Vector3(110, 0, 92), -0.2, 1], [Vector3(84, 0, 108), 3.0, 1], [Vector3(102, 0, 110), 3.1, 0],
			[Vector3(112, 0, 104), 2.9, 0]]:
		put(P.nr_shack if spec[2] == 0 else P.nr_shack_b, shk, spec[0], spec[1])
	_graffiti(vil, "ШРАМ — ХОЗЯИН", Vector3(88.97, 1.5, 96.0), -PI / 2.0)
	# мусор и уличная жизнь
	var trash := group(vil, "Trash")
	for j in [["nr_junk_scrap", Vector3(90.0, 0, 88.0), 0.2], ["nr_junk_tires", Vector3(100.0, 0, 84.0), 0.0], ["nr_dumpster", Vector3(14.0, 0, 100.0), PI / 2.0],
			["nr_junk_bags", Vector3(38.0, 0, 96.0), 1.0], ["nr_junk_furniture", Vector3(110.0, 0, 30.0), 0.5]]:
		_junk(trash, j[0], j[1], j[2])
	_clutter(vil, [["burn_barrel", 88.0, 90.0], ["burn_barrel", 16.0, 80.0], ["car_wreck", 108.0, 76.0, 0.4], ["car_wreck", 70.0, 108.0, 2.0],
		["rubble", 104.0, 66.0], ["paz_wreck", 12.0, 66.0, 0.3]])
	for b in [[Vector3(16.0, 0, 52.0), 0.0], [Vector3(104.0, 0, 52.0), 0.0], [Vector3(48.0, 0, 90.0), PI], [Vector3(72.0, 0, 30.0), PI]]:
		put(P.nr_bench, vil, b[0], b[1])
	for p in [Vector3(30, 0, 56), Vector3(90, 0, 56), Vector3(56, 0, 30), Vector3(56, 0, 90), Vector3(20, 0, 40), Vector3(100, 0, 80)]:
		_lamp_post(vil, p)
	_woods(80)
	_dress(Rect2(4, 4, MR - 8, MR - 8), 300)
	# --- люди ---
	var chars := group(root, "Characters")
	character(chars, "Belsky", "mr_belsky", _slot(kim, "garik"), PI / 2.0, {"dialog": "mr_belsky"})
	character(chars, "Buyer", "nr_buyer", _slot(kim, "apovich"), 0.0, {"dialog": "mr_buyer", "display_name": "Покупатель"})
	character(chars, "KimSecretary", "mr_kimber", _slot(kim, "secretary"), PI / 2.0, {"display_name": "Секретарь «Кимберлита»"})
	character(chars, "KimGuard1", "mr_kimber", _slot(kim, "guard"), PI, {"display_name": "Дружинник «Кимберлита»", "armed": true})
	character(chars, "KimGuard2", "mr_kimber", Vector3(24.0, 0, 31.4), 0.0, {"display_name": "Дружинник «Кимберлита»", "armed": true})
	character(chars, "Gosha", "mr_denouncer", Vector3(76.0, 0, 46.0), 0.6, {"dialog": "mr_denouncer"})
	character(chars, "Slepcova", "mr_slepcova", council.transform * Vector3(2.4, 0, 0.6), PI, {"dialog": "mr_slepcova"})
	character(chars, "CouncilGuard", "mr_jaeger", _slot(council, "guard"), PI, {"display_name": "Йегерь у совета", "armed": true})
	character(chars, "Judge", "mr_judge", Vector3(82.0, 1.0, 42.6), PI, {"dialog": "mr_judge"})
	character(chars, "Accused", "mr_accused", Vector3(85.2, 1.0, 41.4), PI, {"display_name": "Рабочий Пётр", "start_pose": "yield"})
	character(chars, "Jaeger1", "mr_jaeger", Vector3(80.0, 0, 45.6), PI, {"display_name": "Йегерь", "armed": true})
	character(chars, "Jaeger2", "mr_jaeger", Vector3(88.4, 0, 45.6), PI, {"display_name": "Йегерь", "armed": true})
	character(chars, "JaegerHQGuard", "mr_jaeger", _slot(jhq, "sign") + Vector3(-1.2, -_slot(jhq, "sign").y, 0), -PI / 2.0, {"display_name": "Часовой штаба", "armed": true})
	character(chars, "Crowd1", "town_m1", Vector3(84.0, 0, 47.4), PI, {"display_name": "Зевака"})
	character(chars, "Crowd2", "town_f2", Vector3(86.4, 0, 47.8), PI, {"display_name": "Плачет в платок"})
	character(chars, "Ivanov", "mr_ivanov", _slot(union, "t1"), PI, {"dialog": "mr_ivanov"})
	character(chars, "UnionCook", "town_f3", _slot(union, "cook"), PI, {"display_name": "Повариха профкома"})
	character(chars, "Worker1", "nr_worker", _slot(union, "t3"), PI, {"display_name": "Электрик"})
	character(chars, "Worker2", "nr_worker", Vector3(36.0, 0, 86.0), PI, {"display_name": "Пикетчик"})
	character(chars, "Worker3", "nr_worker", Vector3(38.0, 0, 86.6), -2.4, {"display_name": "Пикетчик"})
	character(chars, "Scar", "mr_scar", _slot(den, "t1"), PI, {"dialog": "mr_scar", "start_pose": "sit"})
	character(chars, "DenBarman", "nr_barman", _slot(den, "barman"), PI / 2.0, {"display_name": "Наливает в «Дыре»"})
	character(chars, "Raider1", "mr_raider", Vector3(90.0, 0, 84.4), PI, {"display_name": "Рейдер на баррикаде", "armed": true})
	character(chars, "Raider2", "mr_raider", Vector3(80.4, 0, 92.0), -PI / 2.0, {"display_name": "Рейдер на баррикаде", "armed": true})
	character(chars, "Raider3", "mr_raider", Vector3(100.0, 0, 92.0), 0.4, {"display_name": "Рейдер"})
	character(chars, "Walker1", "town_m3", Vector3(30, 0, 61.0), PI / 2.0, {"display_name": "Горожанин",
		"patrol": PackedVector3Array([Vector3(30, 0, 61.0), Vector3(60, 0, 34.0), Vector3(90, 0, 61.0)]), "patrol_wait": 5.0})
	character(chars, "Walker2", "town_f1", Vector3(60, 0, 88.0), 0.0, {"display_name": "Горожанка",
		"patrol": PackedVector3Array([Vector3(60, 0, 88.0), Vector3(34, 0, 60.0), Vector3(60, 0, 32.0)]), "patrol_wait": 6.0})
	character(chars, "JPatrol", "mr_jaeger", Vector3(86, 0, 60.0), PI / 2.0, {"display_name": "Патруль йегерей", "armed": true,
		"patrol": PackedVector3Array([Vector3(86, 0, 60.0), Vector3(60, 0, 86.0), Vector3(34, 0, 60.0), Vector3(60, 0, 34.0)]), "patrol_wait": 4.0})
	var items := group(root, "Items")
	_junk_items(items)
	_exit(items, "WestRoad", "На тракт — к Нью-Рбе", Vector3(1.0, 0, 60.0), Vector3(1.6, 2.2, 5.0))
	_exit(items, "EastRoad", "К плотине ГЭС", Vector3(MR - 1.0, 0, 60.0), Vector3(1.6, 2.2, 5.0))
	_use(items, "ToQuarry", "Серпантин в карьер", QC + Vector3(0, 0, -QR - 0.6), Vector3(3.0, 1.6, 1.2))
	_use(items, "Scaffold", "Помост суда", Vector3(84.0, 0, 44.2), Vector3(5.0, 1.6, 1.0))
	_spawn("Start", Vector3(4.0, 0, 60.0))
	_spawn("Road", Vector3(4.0, 0, 60.0))
	_spawn("FromEast", Vector3(MR - 4.0, 0, 60.0))
	_spawn("FromQuarry", QC + Vector3(1.5, 0, -QR - 2.4))
	marker(root, "MarkQuarry", QC, "Карьер")
	marker(root, "MarkKim", Vector3(26, 0, 24), "Штаб «Кимберлита»")
	marker(root, "MarkCouncil", Vector3(92, 0, 22), "Совет Мирного")
	marker(root, "MarkJudge", Vector3(84, 0, 42), "Площадь суда")
	marker(root, "MarkUnion", Vector3(26, 0, 92), "Профком «Карьер»")
	marker(root, "MarkDen", Vector3(94, 0, 96), "Притон «Дыра»")
	_finish("mirny")


# ---------------- дно карьера ----------------
func _quarry() -> void:
	var rect := Rect2(0, 0, 60, 48)
	_begin("mirny_quarry", "Мирный · дно карьера", rect, "res://scripts/locations/mirny_quarry.gd")
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("4a4842")
	m.roughness = 1.0
	M["rockfloor"] = m
	var m2 := StandardMaterial3D.new()
	m2.albedo_color = Color("6a665c")
	m2.roughness = 1.0
	M["rockwall"] = m2
	_dark_env(Color("8a8a80"), 0.55)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_energy = 0.55
	sun.light_color = Color("d8d0c0")
	sun.rotation = Vector3(-1.2, 0.6, 0)
	sun.shadow_enabled = true
	root.add_child(sun)
	sun.owner = root
	var v := group(root, "Village")
	_floor(v, rect.grow(4.0), "rockfloor")
	# стенки карьера уступами по краю
	for side in 4:
		for k in 3:
			var off := 0.6 + k * 1.4
			var h := 1.4 + k * 1.6
			var sz: Vector3
			var p: Vector3
			match side:
				0:
					sz = Vector3(rect.size.x + 8, h, 1.4)
					p = Vector3(rect.size.x / 2.0, h / 2.0, -off)
				1:
					sz = Vector3(rect.size.x + 8, h, 1.4)
					p = Vector3(rect.size.x / 2.0, h / 2.0, rect.size.y + off)
				2:
					sz = Vector3(1.4, h, rect.size.y + 8)
					p = Vector3(-off, h / 2.0, rect.size.y / 2.0)
				_:
					sz = Vector3(1.4, h, rect.size.y + 8)
					p = Vector3(rect.size.x + off, h / 2.0, rect.size.y / 2.0)
			box(v, sz, p, "rockwall").owner = root
	# лужи, валуны, брошенный БелАЗ, кабина экскаватора
	for p in [Vector3(14, 0, 18), Vector3(36, 0, 30), Vector3(46, 0, 12), Vector3(8, 0, 36), Vector3(28, 0, 8)]:
		put(P.rock_big, v, p, randf() * TAU, "", randf_range(0.9, 1.5))
	for r in [Rect2(20, 24, 8, 5), Rect2(40, 36, 6, 4)]:
		box(v, Vector3(r.size.x, 0.02, r.size.y), Vector3(r.get_center().x, 0.02, r.get_center().y), "tar").owner = root
	var tr := group(v, "Belaz")
	tr.position = Vector3(22, 0, 34)
	tr.rotation.y = 0.5
	box(tr, Vector3(4.2, 2.4, 7.0), Vector3(0, 2.0, 0), "paint_orange").owner = root
	box(tr, Vector3(3.6, 1.2, 5.0), Vector3(0, 3.6, -0.8), "rust", Vector3(0.3, 0, 0)).owner = root
	_own(collider(tr, Vector3(4.6, 3.0, 7.4), Vector3(0, 1.5, 0)), root)
	# вход в лабораторию обогащения: бетонный портал в стене, внутри — комната
	var lab := Rect2(40, 2, 16, 12)
	_room_walls(v, lab, 1.4, "concrete", [[Vector2(48, 14), 2.4]])
	box(v, Vector3(16, 0.04, 12), Vector3(48, 0.02, 8), "concrete").owner = root
	for i in 3:
		box(v, Vector3(2.4, 1.0, 0.8), Vector3(43 + i * 4.0, 0.5, 3.0), "metal_green").owner = root
		_own(collider(v, Vector3(2.4, 1.0, 0.8), Vector3(43 + i * 4.0, 0.5, 3.0)), root)
	box(v, Vector3(1.0, 0.8, 0.8), Vector3(53.5, 0.4, 10.5), "metal_dark").owner = root
	_signboard(v, "ЛАБОРАТОРИЯ ОБОГАЩЕНИЯ · ГОК «МИРНЫЙ»", Vector3(48, 2.2, 14.2), 0.0, 5.2, Color("e8e0c8"))
	_lamp(v, "LabLamp", Vector3(48, 2.2, 8), Color("e8d49a"), 1.2, 8.0)
	var chars := group(root, "Characters")
	var k := 0
	for p in [Vector3(30, 0, 20), Vector3(33, 0, 22), Vector3(28, 0, 23)]:
		character(chars, "Dog%d" % k, "wild_dog", p, randf() * TAU, {"hostile": true, "aggro_radius": 8.0, "squad": "q_dogs"})
		k += 1
	character(chars, "DeadDigger", "cleaner_dead", Vector3(12, 0, 28), 0.4, {"start_dead": true, "display_name": "Мёртвый старатель"})
	var items := group(root, "Items")
	_use(items, "UpRamp", "Серпантин наверх", Vector3(4.0, 0, 4.0), Vector3(2.4, 2.0, 2.4))
	_use(items, "LabCrate", "Опечатанный ящик", Vector3(53.5, 0, 11.4), Vector3(1.2, 1.0, 1.0))
	_use(items, "LabDesk", "Журналы лаборатории", Vector3(47.0, 0, 3.8), Vector3(2.4, 1.0, 0.8))
	_spawn("Start", Vector3(5.5, 0, 6.0))
	_spawn("FromTop", Vector3(5.5, 0, 6.0))
	marker(root, "MarkLab", Vector3(48, 0, 8), "Лаборатория")
	_finish("mirny_quarry")
