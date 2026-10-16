extends "res://tools/build_nyurba.gd"
## Локации востока по сюжету: Мар-Кун (финал Акта I), Мирный (центр с промзоной ГОК «Мир» и 4 района) и ГЭС (Акт III),
## Рубикон, Горный и комплекс под ГРЭС-2 (Акт IV).
## Запуск: godot --headless --path . res://tools/build_east.tscn [-- markun|mirny|ges|rubikon|gorny|complex]
## mirny — центр и четыре района фракций + дно карьера
## Без аргумента — всё.


func _build() -> void:
	super._load_all()
	for n in ["izba_small", "izba_lean", "shed", "burnt_shed", "fence_broken", "smokehouse", "fish_rack", "kennel", "dead_tree",
			"rock_big", "rock", "fire", "firewood", "barrel", "crates", "bench", "stump", "log_fallen", "spruce_b", "birch_b", "pine_b",
			"balagan_khoton", "balagan_khoton_b", "hay_stack", "pole_fence", "serge", "reeds", "palisade"]:
		if ResourceLoader.exists(PROP_DIR + n + ".tscn"):
			P[n] = load(PROP_DIR + n + ".tscn")
	for n in ["metal_green", "paint_orange", "roof_moss", "metal", "stone", "enamel", "sofa", "glass_city", "frame_white", "plastic_dark", "led_green", "led_red", "plywood", "glass", "plastic_beige", "screen_green", "screen_amber", "paper", "planks_old", "metal_dark", "paint_red", "paint_white", "brick", "coal", "concrete"]:
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
		_mr_kim()
		_mr_rep()
		_mr_work()
		_mr_raid()
		_quarry()
	if only == "" or only == "ges":
		_ges()
	if only == "" or only == "rubikon":
		_rubikon()
	if only == "" or only == "gorny":
		_gorny()
	if only == "" or only == "complex":
		_yakutsk()
		_complex()


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
## Озеро в аласе: тёмная вода диском, камыш по краю, в воду не зайти
func _alas_lake(parent: Node, c: Vector3, r: float) -> void:
	var lk := group(parent, "Lake")
	lk.set_meta("no_xray", true)
	cyl(lk, r + 0.8, r + 0.8, 0.02, c + Vector3(0, 0.01, 0), "coal", Vector3.ZERO, 32).owner = root
	cyl(lk, r, r, 0.03, c + Vector3(0, 0.03, 0), "water", Vector3.ZERO, 32).owner = root
	for k in int(r * 3.0):
		var a := randf() * TAU
		var q := c + Vector3(cos(a), 0, sin(a)) * (r + randf_range(-0.3, 0.6))
		if P.has("reeds"):
			put(P.reeds, lk, q, randf() * TAU, "", randf_range(0.7, 1.1))
	var sb := StaticBody3D.new()
	sb.name = "Collision"
	sb.collision_layer = 1
	sb.collision_mask = 0
	var cs := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = r - 0.3
	sh.height = 1.0
	cs.shape = sh
	sb.add_child(cs)
	sb.position = c + Vector3(0, 0.5, 0)
	lk.add_child(sb)
	_own(sb, root)


## Усадьба: балаган с хотоном лицом к центру аласа, стог в загоне-кюрюё, сэргэ у входа
func _homestead(parent: Node, pos: Vector3, toward: Vector3, nm: String, i: int) -> void:
	var dir := (toward - pos)
	dir.y = 0.0
	dir = dir.normalized()
	var yaw := atan2(dir.x, dir.z)
	var side := Vector3(dir.z, 0, -dir.x)
	put(P.balagan_khoton if i % 2 == 0 else P.balagan_khoton_b, parent, pos, yaw, nm)
	# сэргэ перед дверью жилья
	put(P.serge, parent, pos + dir * 5.2 + side * 2.4, yaw)
	# загон со стогом — за хлевом
	var pen := pos - dir * 8.0 + side * (2.0 if i % 2 == 0 else -2.0)
	put(P.hay_stack, parent, pen, randf() * TAU)
	for k in 4:
		var a := yaw + k * PI / 2.0
		var off := Vector3(sin(a), 0, cos(a)) * 3.1
		put(P.pole_fence, parent, pen + off, a)


func _markun() -> void:
	var rect := Rect2(0, 0, 124, 94)
	_begin("markun", "Мар-Кун", rect, "res://scripts/locations/markun.gd")
	var d := "ground_dirt"
	var C := Vector2(56, 48)  # главный алас: огонь планёрки, святыня
	var NE := Vector2(100, 24)  # северо-восточный алас, за ним ручей и лагерь серых
	var SW := Vector2(22, 72)  # юго-западный алас, отсюда тропа на юг
	_alas.append([C, 32.0])
	_alas.append([NE, 18.0])
	_alas.append([SW, 17.0])
	_alas.append([Vector2(112, 8), 9.0])
	var paths := [[Vector2(-6, 46), Vector2(34, 46), 2.4, 2.0], [Vector2(34, 46), Vector2(48, 45), 2.0, 1.6],
		[Vector2(66, 38), Vector2(92, 28), 1.6, 1.2], [Vector2(92, 28), Vector2(106, 14), 1.4, 1.0],
		[Vector2(42, 60), Vector2(28, 68), 1.4, 1.0], [Vector2(25, 86), Vector2(17, 98), 1.2, 1.0]]
	for pa in paths:
		strip(null, pa[0], pa[1], pa[2], d)
		road_segs.append([pa[0], pa[1], pa[3]])
	road_segs.append([Vector2(44, 40), Vector2(58, 50), 6.0])
	_mud.append(Rect2(44, 38, 14, 12))
	_mud.append(Rect2(98, 4, 16, 12))
	_ground_for("markun")
	var vil := group(root, "Village")
	# ручей на севере
	var cr := group(vil, "Creek")
	cr.set_meta("no_xray", true)
	for i in 24:
		var x := i * 5.5
		box(cr, Vector3(6.0, 0.03, 2.2), Vector3(x, 0.02, 2.4 + sin(i * 0.8) * 1.0), "tar").owner = root
	# озёра аласов
	_alas_lake(vil, Vector3(68, 0, 60), 6.5)
	_alas_lake(vil, Vector3(20, 0, 76), 4.0)
	# усадьбы: по краю главного аласа и в соседних
	var hs := [[Vector3(38, 0, 30), C], [Vector3(56, 0, 26), C], [Vector3(74, 0, 32), C], [Vector3(80, 0, 48), C],
		[Vector3(34, 0, 58), C], [Vector3(50, 0, 66), C], [Vector3(76, 0, 72), C],
		[Vector3(92, 0, 18), NE], [Vector3(110, 0, 24), NE], [Vector3(96, 0, 36), NE],
		[Vector3(14, 0, 64), SW], [Vector3(30, 0, 80), SW], [Vector3(10, 0, 82), SW]]
	var k := 0
	for h in hs:
		var c2: Vector2 = h[1]
		_homestead(vil, h[0], Vector3(c2.x, 0, c2.y), "Home%d" % k, k)
		k += 1
	# наследство дедов: ржавые контейнеры — теперь амбары
	_container(vil, Vector3(62, 0, 36), 0.3, "Store1", "rust")
	_container(vil, Vector3(42, 0, 52), -1.2, "Store2", "paint_faded")
	# огонь планёрки, брёвна-лавки
	var fire := Vector3(50, 0, 44)
	put(P.fire, vil, fire, 0.0, "Fire")
	for j in 5:
		var a := TAU * j / 5.0 + 0.3
		put(P.log_fallen, vil, fire + Vector3(cos(a) * 3.6, 0, sin(a) * 3.6), a + PI / 2.0)
	_lamp(vil, "FireLight", fire + Vector3(0, 1.4, 0), Color("ff9a4a"), 1.8, 9.0)
	# святыня: лист инструкции в раме на столбе, вокруг — амулеты из плат и ленты, как на сэргэ
	var sh := group(vil, "Shrine")
	sh.position = Vector3(45, 0, 40)
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
	put(P.serge, vil, Vector3(54, 0, 39.5), 0.4)
	put(P.serge, vil, Vector3(46, 0, 49.5), 2.6)
	# хозяйство у огня
	put(P.fish_rack, vil, Vector3(58, 0, 42), 0.2)
	put(P.fish_rack, vil, Vector3(60, 0, 56), 1.4)
	put(P.smokehouse, vil, Vector3(60, 0, 46), -0.8)
	put(P.firewood, vil, Vector3(40, 0, 44), 0.3)
	put(P.kennel, vil, Vector3(55, 0, 52), 2.0)
	for p in [Vector3(48, 0, 37), Vector3(57, 0, 49)]:
		box(vil, Vector3(1.4, 1.1, 0.04), p + Vector3(0, 0.9, 0), "cloth_sack", Vector3(0, randf() * PI, 0.08)).owner = root
	# скудная земля: валуны и сухостой по краям аласов
	for p in [Vector3(10, 0, 20), Vector3(88, 0, 70), Vector3(118, 0, 50), Vector3(8, 0, 50), Vector3(76, 0, 14), Vector3(40, 0, 86)]:
		put(P.rock_big, vil, p, randf() * TAU, "", randf_range(0.8, 1.3))
	for p in [Vector3(30, 0, 22), Vector3(82, 0, 60), Vector3(6, 0, 36), Vector3(116, 0, 40), Vector3(60, 0, 78), Vector3(46, 0, 30)]:
		put(P.dead_tree, vil, p, randf() * TAU)
	# лагерь чистильщиков у ручья: палатка, ящики, рация на треноге, костёр
	var camp := group(vil, "CleanerCamp")
	camp.position = Vector3(108, 0, 10)
	box(camp, Vector3(3.6, 0.05, 3.0), Vector3(0, 0.02, 0), "cloth_sack").owner = root
	prism(camp, Vector3(3.4, 1.9, 3.0), Vector3(0, 0.95, 0), "paint_faded").owner = root
	for i in 3:
		box(camp, Vector3(0.8, 0.5, 0.6), Vector3(-2.6, 0.25 + i * 0.5, 1.6), "metal_dark").owner = root
	cyl(camp, 0.03, 0.03, 1.4, Vector3(2.6, 0.7, 1.4), "metal_dark").owner = root
	box(camp, Vector3(0.5, 0.35, 0.3), Vector3(2.6, 1.45, 1.4), "metal_dark").owner = root
	box(camp, Vector3(0.3, 0.12, 0.02), Vector3(2.6, 1.5, 1.56), "screen_amber").owner = root
	_own(collider(camp, Vector3(3.6, 1.9, 3.0), Vector3(0, 0.95, 0)), root)
	put(P.fire, vil, Vector3(104.5, 0, 13.0), 0.0)
	_woods(260)
	_dress(Rect2(4, 4, 116, 86), 420)
	# --- люди Мар-Куна ---
	var chars := group(root, "Characters")
	character(chars, "Chief", "mk_chief", Vector3(51.6, 0, 41.2), -2.4, {"dialog": "mk_chief", "display_name": "Начальник участка"})
	character(chars, "Instructor", "mk_instructor", Vector3(45.8, 0, 41.4), PI, {"dialog": "mk_instructor", "display_name": "Инструктор по ТБ"})
	character(chars, "Hunter1", "mk_hunter", Vector3(39.0, 0, 46.5), PI / 2.0, {"display_name": "Сменный Отвёртка", "armed": true})
	character(chars, "Hunter2", "mk_hunter", Vector3(57.0, 0, 38.0), -2.0, {"display_name": "Сменный Ключ", "armed": true})
	character(chars, "Hunter3", "mk_hunter", Vector3(61.5, 0, 47.5), -1.2, {"display_name": "Сменный Табель", "armed": true})
	character(chars, "Woman1", "mk_woman", Vector3(52.4, 0, 37.6), 0.4, {"display_name": "Нормировщица"})
	character(chars, "Woman2", "mk_woman", Vector3(44.0, 0, 48.6), 2.2, {"display_name": "Накладная"})
	character(chars, "Old1", "mk_old", Vector3(48.0, 0, 46.8), -0.6, {"display_name": "Кладовщик", "start_pose": "sit"})
	character(chars, "Kid1", "kid", Vector3(53.0, 0, 46.5), 1.0, {"display_name": "Пропуск, мальчишка",
		"patrol": PackedVector3Array([Vector3(53.0, 0, 46.5), Vector3(41, 0, 41.0), Vector3(55, 0, 53.0)]), "patrol_wait": 3.0})
	character(chars, "Herder", "mk_old", Vector3(76.0, 0, 40.0), 2.0, {"display_name": "Скотник у хотона"})
	character(chars, "Woman3", "mk_woman", Vector3(24.0, 0, 70.0), 0.6, {"display_name": "Учётчица сена"})
	# чистильщики — пока ждут; станут врагами, когда пойдут на участок
	character(chars, "CleanerBoss", "cleaner_boss", Vector3(106.0, 0, 13.6), -2.4, {"squad": "mk_cleaners", "armed": true})
	k = 0
	for p in [Vector3(103.5, 0, 11.4), Vector3(110.8, 0, 13.6), Vector3(105.0, 0, 15.8), Vector3(112.0, 0, 8.0)]:
		character(chars, "Cleaner%d" % k, "cleaner", p, randf() * TAU, {"squad": "mk_cleaners", "armed": true})
		k += 1
	var items := group(root, "Items")
	_exit(items, "WestExit", "На тракт", Vector3(1.0, 0, 46.0), Vector3(1.6, 2.2, 4.0))
	_use(items, "Shrine", "Лист инструкции", Vector3(45, 0, 40.6), Vector3(1.2, 2.4, 0.6))
	_use(items, "Tent", "Палатка чистильщиков", Vector3(108, 0, 11.8), Vector3(3.0, 1.8, 1.0))
	_use(items, "Radio", "Рация на треноге", Vector3(110.6, 0, 11.4), Vector3(0.8, 1.6, 0.8))
	_spawn("Start", Vector3(4.0, 0, 46.0))
	_spawn("Road", Vector3(4.0, 0, 46.0))
	_spawn("Trail", Vector3(21.0, 0, 91.0))
	marker(root, "MarkFire", fire, "Огонь планёрки")
	marker(root, "MarkCamp", Vector3(108, 0, 10), "Лагерь серых")
	marker(root, "MarkTrail", Vector3(21, 0, 91), "Тропа на юг")
	marker(root, "MarkLake", Vector3(68, 0, 60), "Озеро аласа")
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
	_begin("mirny", "Мирный · центр", rect, "res://scripts/locations/mirny.gd")
	var d := "ground_dirt"
	# кольцо вокруг карьера, тракт запад — восток, дороги в промзону и на барахолку
	for k in 32:
		var a0 := TAU * k / 32.0
		var a1 := TAU * (k + 1) / 32.0
		var r := QR + 5.0
		var p0 := Vector2(QC.x + cos(a0) * r, QC.z + sin(a0) * r)
		var p1 := Vector2(QC.x + cos(a1) * r, QC.z + sin(a1) * r)
		strip(null, p0, p1, 5.0, d)
		road_segs.append([p0, p1, 2.4])
	for seg in [[Vector2(-8, 60), Vector2(QC.x - QR - 5, 60), 6.0], [Vector2(QC.x + QR + 5, 60), Vector2(MR + 8, 60), 6.0],
			[Vector2(60, 33), Vector2(60, 26), 5.0], [Vector2(60, 87), Vector2(60, 112), 5.0],
			# улицы в районы фракций — по диагоналям к углам
			[Vector2(41, 41), Vector2(2, 2), 5.0], [Vector2(79, 41), Vector2(118, 2), 5.0],
			[Vector2(41, 79), Vector2(2, 118), 5.0], [Vector2(79, 79), Vector2(118, 118), 5.0]]:
		strip(null, seg[0], seg[1], seg[2], d)
		road_segs.append([seg[0], seg[1], float(seg[2]) / 2.0])
	_street_out(Vector2(0, 60), -1.0)
	_street_out(Vector2(MR, 60), 1.0)
	_mud.append(Rect2(-6, -6, MR + 12, MR + 12))
	_mud.append(Rect2(36, 4, 48, 22))
	_mud.append(Rect2(40, 92, 40, 22))
	_clear.append(Rect2(-8, -8, MR + 16, MR + 16))
	_ground_for("mirny")
	var vil := group(root, "Village")
	_quarry_pit(vil)
	# --- север: промзона ГОК «Мир» за бетонным забором ---
	_wall(vil, Vector2(34, 26), Vector2(86, 26), [[24.0, 28.0]])
	_wall(vil, Vector2(34, 2), Vector2(34, 26))
	_wall(vil, Vector2(86, 2), Vector2(86, 26))
	_bld(vil, "nr_factory", "GokMill", Vector3(48, 0, 12.0))
	_bld(vil, "boiler_house", "GokBoiler", Vector3(74, 0, 10.0))
	_bld(vil, "water_tower", "GokTower", Vector3(80, 0, 20.0))
	_signboard(vil, "ГОК «МИР» · ПРОМЗОНА", Vector3(60, 3.6, 26.6), 0.0, 5.0, Color("e8d8a8"))
	for sx in [-3.2, 3.2]:
		box(vil, Vector3(0.3, 4.0, 0.3), Vector3(60 + sx, 2.0, 26.4), "rust").owner = root
	# --- юг: барахолка ничейной земли и склады ---
	var mk := group(vil, "Market")
	for i in 6:
		var p := Vector3(46.0 + (i % 3) * 14.0 if i % 3 != 1 else 60.0 + (6.0 if i < 3 else -6.0), 0, 96.0 + int(i / 3) * 9.0)
		put(P.kiosk if i % 2 == 0 else P.kiosk_b, mk, p, PI if i < 3 else 0.0)
	for p in [Vector3(52, 0, 100.5), Vector3(68, 0, 100.5)]:
		box(mk, Vector3(3.0, 0.9, 1.0), p + Vector3(0, 0.45, 0), "planks_old").owner = root
		box(mk, Vector3(3.4, 0.05, 1.8), p + Vector3(0, 2.2, 0), "tarp_blue" if M.has("tarp_blue") else "cloth_sack", Vector3(0.2, 0, 0)).owner = root
		for sx in [-1.5, 1.5]:
			box(mk, Vector3(0.08, 2.2, 0.08), p + Vector3(sx, 1.1, -0.6), "metal_dark").owner = root
		_own(collider(mk, Vector3(3.0, 1.0, 1.0), p + Vector3(0, 0.5, 0)), root)
	_bld(vil, "nr_warehouse", "Warehouse1", Vector3(40, 0, 113.5), PI)
	_bld(vil, "nr_warehouse", "Warehouse2", Vector3(80, 0, 113.5), PI)
	_signboard(vil, "БАРАХОЛКА · НИЧЕЙНАЯ ЗЕМЛЯ · ОРУЖИЕ НЕ ДОСТАВАТЬ", Vector3(60, 2.6, 89.6), PI, 5.6, Color("f0d890"))
	# --- кордоны фракций у выходов в районы ---
	var cd := group(vil, "Cordons")
	for p in [Vector3(9, 0, 16), Vector3(16, 0, 9)]:
		_flagpole(cd, p, "paint_white", "◬")
	put(P.checkpoint, cd, Vector3(19, 0, 13), PI / 4.0)
	_poster(cd, "«КИМБЕРЛИТ» · ПОРЯДОК", Vector3(22, 2.4, 22), PI / 4.0, Color("f0f0e8"))
	for p in [Vector3(111, 0, 16), Vector3(104, 0, 9)]:
		_flagpole(cd, p, "paint_blue", "♌")
	put(P.sandbags, cd, Vector3(102, 0, 15), -PI / 4.0)
	_poster(cd, "ВЫБОРЫ — ЛЮДЯМ", Vector3(98, 2.4, 22), -PI / 4.0, Color("e8e0c8"))
	for p in [Vector3(9, 0, 104), Vector3(16, 0, 111)]:
		_flagpole(cd, p, "paint_red", "☭")
	_poster(cd, "ТОК — ЛЮДЯМ!", Vector3(22, 2.4, 98), 3.0 * PI / 4.0, Color("ff9a6a"))
	var bar := group(cd, "Barricade")
	for i in 3:
		_junk_fence(bar, Vector3(100.0 + i * 2.8, 0, 94.0 + i * 2.8), -PI / 4.0, i == 1)
		_junk_fence(bar, Vector3(94.0 + i * 2.8, 0, 100.0 + i * 2.8), -PI / 4.0, false)
	_graffiti(vil, "ДАЛЬШЕ — ШРАМ", Vector3(86.0, 1.5, 104.0), PI / 2.0)
	# брошенные дома ничейной земли вдоль тракта: выгоревшие, без хозяев
	_ruin_block(vil, "st_block3a", Vector3(16, 0, 45.5), 0.0, "Empty1")
	_ruin_block(vil, "st_block2", Vector3(104, 0, 46.0), 0.0, "Empty2")
	_ruin_block(vil, "st_block3b", Vector3(16, 0, 74.5), PI, "Empty3")
	_ruin_block(vil, "st_block2b", Vector3(104, 0, 74.5), PI, "Empty4")
	# город за краем: дома районов видны в просветах улиц
	var far := group(root, "FarCity")
	far.set_meta("no_xray", true)
	for spec in [["nr_stalin4", Vector3(-10, 0, -10), PI / 4.0], ["st_admin", Vector3(130, 0, -10), -PI / 4.0],
			["st_barrack2", Vector3(-10, 0, 130), 3.0 * PI / 4.0], ["nr_shack", Vector3(130, 0, 130), -3.0 * PI / 4.0],
			["st_block3a", Vector3(-14, 0, 20), PI / 2.0], ["st_block2", Vector3(134, 0, 20), -PI / 2.0], ["st_block4", Vector3(-14, 0, 100), PI / 2.0], ["nr_shack_b", Vector3(132, 0, 100), -PI / 2.0]]:
		put(P[spec[0]], far, spec[1], spec[2])
	# мусор, фонари, скамейки
	var trash := group(vil, "Trash")
	for j in [["nr_junk_scrap", Vector3(28.0, 0, 30.0), 0.2], ["nr_junk_tires", Vector3(96.0, 0, 34.0), 0.0], ["nr_dumpster", Vector3(30.0, 0, 92.0), PI / 2.0],
			["nr_junk_bags", Vector3(90.0, 0, 88.0), 1.0], ["nr_junk_furniture", Vector3(98.0, 0, 70.0), 0.5]]:
		_junk(trash, j[0], j[1], j[2])
	_clutter(vil, [["burn_barrel", 55.0, 92.0], ["burn_barrel", 18.0, 66.0], ["car_wreck", 112.0, 36.0, 0.4], ["car_wreck", 30.0, 100.0, 2.0],
		["rubble", 100.0, 66.0], ["paz_wreck", 8.0, 34.0, 0.3]])
	for b in [[Vector3(16.0, 0, 55.0), 0.0], [Vector3(104.0, 0, 55.0), 0.0], [Vector3(64.0, 0, 92.0), PI]]:
		put(P.nr_bench, vil, b[0], b[1])
	for p in [Vector3(30, 0, 56), Vector3(90, 0, 56), Vector3(56, 0, 30), Vector3(56, 0, 90), Vector3(30, 0, 36), Vector3(90, 0, 84)]:
		_lamp_post(vil, p)
	_woods(40)
	_dress(Rect2(4, 4, MR - 8, MR - 8), 300)
	# --- люди ничейной земли ---
	var chars := group(root, "Characters")
	character(chars, "KimPost", "mr_kimber", Vector3(17.0, 0, 9.5), PI / 4.0, {"display_name": "Дружинник на кордоне", "armed": true})
	character(chars, "RepPost", "mr_jaeger", Vector3(103.0, 0, 9.5), -PI / 4.0, {"display_name": "Йегерь на кордоне", "armed": true})
	character(chars, "WorkPost", "nr_worker", Vector3(17.0, 0, 110.5), 3.0 * PI / 4.0, {"display_name": "Пикетчик на въезде"})
	character(chars, "RaidPost", "mr_raider", Vector3(108.0, 0, 103.0), -3.0 * PI / 4.0, {"display_name": "Рейдер у баррикады", "armed": true})
	character(chars, "Trader1", "town_m4", Vector3(52.0, 0, 102.0), PI, {"display_name": "Барыга с барахолки"})
	character(chars, "Trader2", "town_f3", Vector3(68.0, 0, 102.0), PI, {"display_name": "Торговка вяленой рыбой"})
	character(chars, "GokWatch", "town_old_m", Vector3(62.5, 0, 28.0), PI, {"display_name": "Сторож промзоны"})
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
	_exit(items, "ToKimberlit", "В район «Кимберлита»", Vector3(2.5, 0, 2.5), Vector3(3.0, 2.2, 3.0))
	_exit(items, "ToRepublic", "К совету и йегерям", Vector3(MR - 2.5, 0, 2.5), Vector3(3.0, 2.2, 3.0))
	_exit(items, "ToWorkers", "В рабочий посёлок", Vector3(2.5, 0, MR - 2.5), Vector3(3.0, 2.2, 3.0))
	_exit(items, "ToRaiders", "В квартал рейдеров", Vector3(MR - 2.5, 0, MR - 2.5), Vector3(3.0, 2.2, 3.0))
	_use(items, "ToQuarry", "Серпантин в карьер", QC + Vector3(0, 0, -QR - 0.6), Vector3(3.0, 1.6, 1.2))
	_use(items, "GokSign", "Вывеска промзоны", Vector3(60, 0, 27.4), Vector3(4.0, 2.0, 0.8))
	_spawn("Start", Vector3(4.0, 0, 60.0))
	_spawn("Road", Vector3(4.0, 0, 60.0))
	_spawn("FromEast", Vector3(MR - 4.0, 0, 60.0))
	_spawn("FromQuarry", QC + Vector3(1.5, 0, -QR - 2.4))
	_spawn("FromKimberlit", Vector3(8.0, 0, 8.0))
	_spawn("FromRepublic", Vector3(MR - 8.0, 0, 8.0))
	_spawn("FromWorkers", Vector3(8.0, 0, MR - 8.0))
	_spawn("FromRaiders", Vector3(MR - 8.0, 0, MR - 8.0))
	marker(root, "MarkQuarry", QC, "Карьер «Мир»")
	marker(root, "MarkGok", Vector3(60, 0, 14), "Промзона ГОК «Мир»")
	marker(root, "MarkMarket", Vector3(60, 0, 100), "Барахолка")
	marker(root, "MarkKim", Vector3(8, 0, 8), "→ «Кимберлит»")
	marker(root, "MarkRep", Vector3(MR - 8, 0, 8), "→ Совет и йегеря")
	marker(root, "MarkWork", Vector3(8, 0, MR - 8), "→ Рабочий посёлок")
	marker(root, "MarkRaid", Vector3(MR - 8, 0, MR - 8), "→ Рейдеры")
	_finish("mirny")


# ---------------- районы Мирного: квадрат 84 м, проспект z = 42 и улица x = 42 ----------------
const MD := 84.0


## Каркас района: проспект и улица, выход в центр на востоке (east) или западе,
## за выходом — дома центра в просвете улицы
func _mr_frame(id: String, title: String, script: String, east: bool) -> Node:
	var rect := Rect2(0, 0, MD, MD)
	_begin(id, title, rect, script)
	var d := "ground_dirt"
	strip(null, Vector2(-8, 42), Vector2(MD + 8, 42), 7.0, d)
	strip(null, Vector2(42, -8), Vector2(42, MD + 8), 5.0, d)
	road_segs.append([Vector2(-8, 42), Vector2(MD + 8, 42), 3.3])
	road_segs.append([Vector2(42, -8), Vector2(42, MD + 8), 2.3])
	for seg in [[Vector2(10, 18), Vector2(MD - 10, 18)], [Vector2(10, 66), Vector2(MD - 10, 66)]]:
		strip(null, seg[0], seg[1], 3.6, d)
		road_segs.append([seg[0], seg[1], 1.6])
	_street_out(Vector2(MD if east else 0.0, 42), 1.0 if east else -1.0)
	_clear.append(Rect2(-8, -8, MD + 16, MD + 16))
	_mud.append(Rect2(-6, -6, MD + 12, MD + 12))
	_ground_for(id)
	var vil := group(root, "Village")
	var pav := group(vil, "Pavement")
	pav.set_meta("no_xray", true)
	for r in [Rect2(4, 36.6, 34, 1.3), Rect2(46, 36.6, 34, 1.3), Rect2(4, 46.1, 34, 1.3), Rect2(46, 46.1, 34, 1.3)]:
		_walk(pav, r)
	_edges(rect, [["E" if east else "W", 42.0]], [])
	var items := group(root, "Items")
	_exit(items, "ToCenter", "В центр Мирного", Vector3(MD - 1.0 if east else 1.0, 0, 42.0), Vector3(1.6, 2.2, 6.0))
	_spawn("Start", Vector3(MD - 4.0 if east else 4.0, 0, 42.0))
	_spawn("FromCenter", Vector3(MD - 4.0 if east else 4.0, 0, 42.0))
	return vil


func _mr_close(id: String, vil: Node, lamps: Array, fill := []) -> void:
	# дома во дворах у главной улицы
	var k := 0
	for f in fill:
		_bld(vil, f[0], "Yard%d" % k, f[1], f[2])
		k += 1
	for p in lamps:
		_lamp_post(vil, p)
	_woods(20)
	_dress(Rect2(4, 4, MD - 8, MD - 8), 180)
	_clear_town(Rect2(2, 2, MD - 4, MD - 4))
	_junk_items(root.get_node("Items"))
	_finish(id)


## «Кимберлит» — северо-запад города: побелено, флаги, плац с трибуной, штаб Бельского
func _mr_kim() -> void:
	var vil := _mr_frame("mirny_kimberlit", "Мирный · «Кимберлит»", "res://scripts/locations/mirny_kimberlit.gd", true)
	var kim := _bld(vil, "nr_gov", "KimberlitHQ", Vector3(20.0, 0, 26.5))
	_sign_on(vil, kim, "«КИМБЕРЛИТ» · ПОРЯДОК · СВЕТ · РАБОТА", 7.0, Color("f0f0e8"))
	_bld(vil, "nr_stalin4", "KimHouse1", Vector3(64.0, 0, 27.0))
	_bld(vil, "nr_stalin3", "KimHouse2", Vector3(20.0, 0, 54.0), PI)
	_bld(vil, "nr_stalin4b", "KimHouse3", Vector3(64.0, 0, 54.5), PI)
	_bld(vil, "st_res4", "KimHouse4", Vector3(20.0, 0, 6.5))
	_bld(vil, "st_block3a", "KimHouse5", Vector3(64.0, 0, 77.0), PI)
	# плац у перекрёстка: трибуна, флаги, плакаты
	var pl := group(vil, "Parade")
	box(pl, Vector3(4.0, 1.2, 2.4), Vector3(52, 0.6, 48.6), "plaster_white").owner = root
	box(pl, Vector3(4.4, 0.12, 2.8), Vector3(52, 1.26, 48.6), "paint_white").owner = root
	_own(collider(pl, Vector3(4.0, 1.2, 2.4), Vector3(52, 0.6, 48.6)), root)
	for x in [47.0, 57.0, 62.0, 67.0]:
		_flagpole(vil, Vector3(x, 0, 48.0), "paint_white", "◬")
	for x in [10.0, 30.0]:
		_flagpole(vil, Vector3(x, 0, 36.0), "paint_white", "◬")
	_poster(vil, "ПОРЯДОК · СВЕТ · РАБОТА", Vector3(52, 2.6, 49.9), PI, Color("f0f0e8"))
	_poster(vil, "«ГОРИЗОНТ» ДАСТ СВЕТ. А ТЫ — ЧТО ДАШЬ?", Vector3(34.0, 2.2, 36.0), 0.0, Color("f0f0e8"))
	put(P.checkpoint, vil, Vector3(78, 0, 35.5), 0.0)
	for b in [[Vector3(12.0, 0, 47.6), PI], [Vector3(28.0, 0, 47.6), PI], [Vector3(72.0, 0, 36.4), 0.0]]:
		put(P.nr_bench, vil, b[0], b[1])
	var chars := group(root, "Characters")
	character(chars, "Belsky", "mr_belsky", _slot(kim, "garik"), PI / 2.0, {"dialog": "mr_belsky"})
	character(chars, "Buyer", "nr_buyer", _slot(kim, "apovich"), 0.0, {"dialog": "mr_buyer", "display_name": "Покупатель"})
	character(chars, "KimSecretary", "mr_kimber", _slot(kim, "secretary"), PI / 2.0, {"display_name": "Секретарь «Кимберлита»"})
	character(chars, "KimGuard1", "mr_kimber", _slot(kim, "guard"), PI, {"display_name": "Дружинник «Кимберлита»", "armed": true})
	character(chars, "KimGuard2", "mr_kimber", Vector3(20.0, 0, 37.0), 0.0, {"display_name": "Дружинник у штаба", "armed": true})
	character(chars, "KimGate", "mr_kimber", Vector3(78.5, 0, 38.6), -PI / 2.0, {"display_name": "Дружинник на въезде", "armed": true})
	character(chars, "Orator", "mr_kimber", Vector3(52.0, 1.3, 48.4), PI, {"display_name": "Оратор «Кимберлита»"})
	character(chars, "Listener1", "town_m1", Vector3(51.0, 0, 44.6), 0.0, {"display_name": "Слушает оратора"})
	character(chars, "Listener2", "town_f2", Vector3(53.6, 0, 44.4), 0.0, {"display_name": "Значок «Горизонта» на пальто"})
	character(chars, "KimPatrol", "mr_kimber", Vector3(10, 0, 41.0), PI / 2.0, {"display_name": "Патруль дружины", "armed": true,
		"patrol": PackedVector3Array([Vector3(10, 0, 41.0), Vector3(74, 0, 41.0), Vector3(43, 0, 70.0), Vector3(43, 0, 14.0)]), "patrol_wait": 4.0})
	marker(root, "MarkKim", Vector3(20, 0, 26), "Штаб «Кимберлита»")
	marker(root, "MarkParade", Vector3(52, 0, 49), "Плац")
	_mr_close("mirny_kimberlit", vil, [Vector3(36, 0, 37.0), Vector3(48, 0, 47.2), Vector3(72, 0, 47.2), Vector3(12, 0, 37.0), Vector3(43.6, 0, 24), Vector3(40.4, 0, 60)], [["st_block2b", Vector3(34.5, 0, 8.5), 0.0], ["st_block2b", Vector3(49.5, 0, 8.5), 0.0], ["st_block2", Vector3(34.0, 0, 76.0), PI], ["st_block2b", Vector3(49.5, 0, 76.0), PI]])


## Совет и йегеря — северо-восток: здание совета, штаб йегерей, площадь суда с помостом
func _mr_rep() -> void:
	var vil := _mr_frame("mirny_republic", "Мирный · совет и йегеря", "res://scripts/locations/mirny_republic.gd", false)
	var council := _bld(vil, "st_admin", "Council", Vector3(64.0, 0, 30.0))
	_sign_on(vil, council, "СОВЕТ МИРНОГО · ВЫБОРЫ — ЛЮДЯМ", 6.0, Color("e8e0c8"))
	var jhq := _bld(vil, "st_office", "JaegerHQ", Vector3(64.0, 0, 51.5), PI)
	_signboard(vil, "JAEGER CORP · ХАХАЙ", _slot(jhq, "sign"), PI, 4.6, Color("e8c060"))
	_bld(vil, "nr_stalin3", "RepHouse", Vector3(20.0, 0, 54.0), PI)
	_bld(vil, "st_block3b", "RepHouse2", Vector3(64.0, 0, 8.0))
	_bld(vil, "st_block2", "RepHouse3", Vector3(20.0, 0, 77.0), PI)
	_bld(vil, "st_police", "JaegerPost", Vector3(64.0, 0, 76.0), PI)
	# площадь суда: помост, столб, ступени
	_walk(group(vil, "SquarePave"), Rect2(8, 18, 26, 17))
	var sc := group(vil, "Scaffold")
	sc.position = Vector3(20.0, 0, 24.0)
	box(sc, Vector3(5.0, 1.0, 4.0), Vector3(0, 0.5, 0), "planks_old").owner = root
	box(sc, Vector3(0.25, 3.6, 0.25), Vector3(-1.6, 2.8, -1.2), "log_dark").owner = root
	box(sc, Vector3(2.0, 0.2, 0.2), Vector3(-0.7, 4.5, -1.2), "log_dark").owner = root
	box(sc, Vector3(0.04, 1.2, 0.04), Vector3(0.2, 3.8, -1.2), "rope_mat").owner = root
	for i in 3:
		box(sc, Vector3(1.6, 0.25, 0.4), Vector3(1.2, 0.12 + i * 0.25, 2.2 - i * 0.4), "planks_old").owner = root
	_own(collider(sc, Vector3(5.0, 1.0, 4.0), Vector3(0, 0.5, 0)), root)
	_poster(vil, "СУД ПОЛИСА — ЗДЕСЬ", Vector3(20.0, 2.6, 21.6), PI, Color("e8c060"))
	for x in [12.0, 28.0]:
		_flagpole(vil, Vector3(x, 0, 34.0), "paint_blue", "♌")
	for x in [52.0, 76.0]:
		_flagpole(vil, Vector3(x, 0, 37.0), "paint_blue", "♌")
	put(P.notice_board, vil, Vector3(56.0, 0, 46.8), PI)
	put(P.sandbags, vil, Vector3(6.0, 0, 35.5), 0.0)
	_poster(vil, "СПИСКИ ПОСОБНИКОВ «ГОРИЗОНТА» — У ШТАБА", Vector3(30.0, 2.4, 47.0), PI, Color("e8c060"))
	var chars := group(root, "Characters")
	character(chars, "Slepcova", "mr_slepcova", council.transform * Vector3(2.4, 0, 0.6), PI, {"dialog": "mr_slepcova"})
	character(chars, "CouncilGuard", "mr_jaeger", _slot(council, "guard"), PI, {"display_name": "Йегерь у совета", "armed": true})
	character(chars, "Judge", "mr_judge", Vector3(18.0, 1.0, 24.6), PI, {"dialog": "mr_judge"})
	character(chars, "Accused", "mr_accused", Vector3(21.2, 1.0, 23.4), PI, {"display_name": "Рабочий Пётр", "start_pose": "yield"})
	character(chars, "Jaeger1", "mr_jaeger", Vector3(16.0, 0, 27.6), PI, {"display_name": "Йегерь", "armed": true})
	character(chars, "Jaeger2", "mr_jaeger", Vector3(24.4, 0, 27.6), PI, {"display_name": "Йегерь", "armed": true})
	character(chars, "Gosha", "mr_denouncer", Vector3(12.0, 0, 28.0), 0.6, {"dialog": "mr_denouncer"})
	character(chars, "Crowd1", "town_m1", Vector3(20.0, 0, 29.4), PI, {"display_name": "Зевака"})
	character(chars, "Crowd2", "town_f2", Vector3(22.4, 0, 29.8), PI, {"display_name": "Плачет в платок"})
	character(chars, "JaegerHQGuard", "mr_jaeger", _slot(jhq, "sign") + Vector3(-1.2, -_slot(jhq, "sign").y, -0.6), PI, {"display_name": "Часовой штаба", "armed": true})
	character(chars, "RepGate", "mr_jaeger", Vector3(6.0, 0, 38.0), PI / 2.0, {"display_name": "Йегерь на въезде", "armed": true})
	character(chars, "Deputy", "town_m3", Vector3(58.0, 0, 38.6), 0.0, {"display_name": "Депутат совета"})
	marker(root, "MarkCouncil", Vector3(64, 0, 30), "Совет Мирного")
	marker(root, "MarkJudge", Vector3(20, 0, 24), "Площадь суда")
	marker(root, "MarkJaeger", Vector3(64, 0, 51.5), "Штаб йегерей")
	var items := root.get_node("Items")
	_use(items, "Scaffold", "Помост суда", Vector3(20.0, 0, 26.2), Vector3(5.0, 1.6, 1.0))
	_use(items, "Lists", "Списки пособников", Vector3(56.0, 0, 46.2), Vector3(2.0, 2.0, 0.6))
	_mr_close("mirny_republic", vil, [Vector3(36, 0, 37.0), Vector3(48, 0, 47.2), Vector3(72, 0, 37.0), Vector3(12, 0, 47.2), Vector3(43.6, 0, 24), Vector3(40.4, 0, 60)], [["st_block2b", Vector3(34.5, 0, 8.5), 0.0], ["st_block2b", Vector3(49.5, 0, 8.5), 0.0], ["st_block2", Vector3(34.0, 0, 76.0), PI], ["st_block2b", Vector3(49.5, 0, 76.0), PI]])


## Рабочий посёлок — юго-запад: профком, мастерские, бараки, общежитие, пикет
func _mr_work() -> void:
	var vil := _mr_frame("mirny_workers", "Мирный · рабочий посёлок", "res://scripts/locations/mirny_workers.gd", true)
	var union := _bld(vil, "st_canteen", "Union", Vector3(20.0, 0, 31.0))
	_sign_on(vil, union, "ПРОФКОМ «КАРЬЕР»", 3.8, Color("f0e0c0"))
	_bld(vil, "nr_factory_b", "Workshop", Vector3(22.0, 0, 55.0), PI)
	_bld(vil, "st_barrack2", "Barrack1", Vector3(62.0, 0, 32.5))
	_bld(vil, "st_obshaga", "Obshaga", Vector3(64.0, 0, 52.5), PI)
	_bld(vil, "st_barrack2", "Barrack2", Vector3(20.0, 0, 8.5))
	_bld(vil, "st_barrack2", "Barrack3", Vector3(64.0, 0, 8.5))
	_bld(vil, "garages", "Garages", Vector3(20.0, 0, 76.0), PI)
	_bld(vil, "boiler_house", "Boiler", Vector3(64.0, 0, 76.0), PI)
	for x in [12.0, 30.0, 54.0]:
		_flagpole(vil, Vector3(x, 0, 36.0), "paint_red", "☭")
	_poster(vil, "ТОК — ЛЮДЯМ!", Vector3(34.0, 2.4, 47.6), PI, Color("ff7a4a"))
	_poster(vil, "НЕ ПРОДАДИМ ГОРОД ВМЕСТЕ С НАМИ", Vector3(52.0, 2.4, 36.2), 0.0, Color("ff9a6a"))
	_banner(vil, Vector3(74.0, 0, 37.6), Vector3(74.0, 0, 46.4), "ПРОФСОЮЗ «КАРЬЕР» · ТОК — ЛЮДЯМ")
	# бельё на верёвках между бараками
	for z in [18.0, 66.0]:
		for x in [8.0, 30.0, 54.0]:
			cyl(vil, 0.01, 0.01, 8.0, Vector3(x + 4.0, 2.2, z + 2.6), "rope_mat", Vector3(0, 0, PI / 2.0), 4).owner = root
			for k in 5:
				box(vil, Vector3(0.6, 0.7, 0.02), Vector3(x + 1.0 + k * 1.5, 1.8, z + 2.6), ["cloth", "cloth_red", "paint_white", "cloth_sack", "paint_blue"][k]).owner = root
	_clutter(vil, [["burn_barrel", 46.0, 50.0], ["burn_barrel", 36.0, 36.0], ["trash_pile", 34.0, 72.0]])
	for b in [[Vector3(12.0, 0, 47.6), PI], [Vector3(56.0, 0, 47.6), PI]]:
		put(P.nr_bench, vil, b[0], b[1])
	var chars := group(root, "Characters")
	character(chars, "Ivanov", "mr_ivanov", _slot(union, "t1"), PI, {"dialog": "mr_ivanov"})
	character(chars, "UnionCook", "town_f3", _slot(union, "cook"), PI, {"display_name": "Повариха профкома"})
	character(chars, "Worker1", "nr_worker", _slot(union, "t3"), PI, {"display_name": "Электрик"})
	character(chars, "Worker2", "nr_worker", Vector3(36.0, 0, 38.0), PI, {"display_name": "Пикетчик"})
	character(chars, "Worker3", "nr_worker", Vector3(38.0, 0, 38.6), -2.4, {"display_name": "Пикетчик"})
	character(chars, "Worker4", "town_worker", Vector3(24.0, 0, 46.2), 0.0, {"display_name": "Слесарь со смены"})
	character(chars, "Worker5", "town_f1", Vector3(60.0, 0, 46.8), PI, {"display_name": "Прачка"})
	character(chars, "Kid1", "kid", Vector3(44.0, 0, 50.0), 1.0, {"display_name": "Чумазый пацан",
		"patrol": PackedVector3Array([Vector3(44.0, 0, 50.0), Vector3(20, 0, 44.0), Vector3(66, 0, 44.0)]), "patrol_wait": 3.0})
	marker(root, "MarkUnion", Vector3(20, 0, 31), "Профком «Карьер»")
	marker(root, "MarkWorkshop", Vector3(22, 0, 55), "Мастерские")
	_mr_close("mirny_workers", vil, [Vector3(36, 0, 47.2), Vector3(48, 0, 37.0), Vector3(72, 0, 47.2), Vector3(12, 0, 37.0), Vector3(43.6, 0, 24), Vector3(40.4, 0, 60)], [["st_block2b", Vector3(34.5, 0, 8.5), 0.0], ["st_block2b", Vector3(49.5, 0, 8.5), 0.0], ["st_block2", Vector3(34.0, 0, 76.0), PI], ["st_block2b", Vector3(49.5, 0, 76.0), PI]])


## Квартал рейдеров — юго-восток: баррикады из лома, лачуги, притон «Дыра»
func _mr_raid() -> void:
	var vil := _mr_frame("mirny_raiders", "Мирный · квартал рейдеров", "res://scripts/locations/mirny_raiders.gd", false)
	var den := _bld(vil, "nr_ryumka", "RaiderDen", Vector3(62.0, 0, 33.0))
	_sign_on(vil, den, "ПРИТОН «ДЫРА»", 3.0, Color("ffb23a"))
	_bld(vil, "nr_nochlezhka", "Flophouse", Vector3(22.0, 0, 54.0), PI)
	var bar := group(vil, "Barricade")
	for i in 7:
		if i == 3:
			continue
		_junk_fence(bar, Vector3(10.0, 0, 30.0 + i * 4.0), PI / 2.0, false)
	_junk_fence(bar, Vector3(10.0, 0, 42.0), PI / 2.0, true)
	var shk := group(vil, "Shacks")
	for spec in [[Vector3(20, 0, 30), 0.1, 0], [Vector3(30, 0, 29), -0.2, 1], [Vector3(60, 0, 54), 3.0, 1], [Vector3(72, 0, 55), 3.1, 0],
			[Vector3(20, 0, 10), 0.0, 1], [Vector3(64, 0, 10), 0.2, 0], [Vector3(20, 0, 76), 3.0, 0], [Vector3(64, 0, 76), 3.2, 1], [Vector3(74, 0, 31), -0.1, 0]]:
		put(P.nr_shack if spec[2] == 0 else P.nr_shack_b, shk, spec[0], spec[1])
	_graffiti(vil, "ШРАМ — ХОЗЯИН", Vector3(56.97, 1.5, 33.0), -PI / 2.0)
	var trash := group(vil, "Trash")
	for j in [["nr_junk_scrap", Vector3(50.0, 0, 50.0), 0.2], ["nr_junk_tires", Vector3(34.0, 0, 48.0), 0.0], ["nr_junk_bags", Vector3(50.0, 0, 34.0), 1.0]]:
		_junk(trash, j[0], j[1], j[2])
	_clutter(vil, [["burn_barrel", 46.0, 36.0], ["burn_barrel", 30.0, 48.0], ["car_wreck", 74.0, 47.0, 0.4], ["car_wreck", 52.0, 70.0, 2.0],
		["paz_wreck", 30.0, 72.0, 0.3], ["rubble", 74.0, 66.0]])
	var chars := group(root, "Characters")
	character(chars, "Scar", "mr_scar", _slot(den, "t1"), PI, {"dialog": "mr_scar", "start_pose": "sit"})
	character(chars, "DenBarman", "nr_barman", _slot(den, "barman"), PI / 2.0, {"display_name": "Наливает в «Дыре»"})
	character(chars, "Raider1", "mr_raider", Vector3(12.0, 0, 39.0), -PI / 2.0, {"display_name": "Рейдер на баррикаде", "armed": true})
	character(chars, "Raider2", "mr_raider", Vector3(12.0, 0, 45.6), -PI / 2.0, {"display_name": "Рейдер на баррикаде", "armed": true})
	character(chars, "Raider3", "mr_raider", Vector3(48.0, 0, 37.4), 0.4, {"display_name": "Рейдер"})
	character(chars, "Raider4", "mr_raider", Vector3(32.0, 0, 46.6), 2.0, {"display_name": "Греется у бочки"})
	character(chars, "Fence", "nr_fence", Vector3(54.0, 0, 46.4), PI, {"display_name": "Скупщик краденого"})
	marker(root, "MarkDen", Vector3(62, 0, 33), "Притон «Дыра»")
	_mr_close("mirny_raiders", vil, [Vector3(36, 0, 47.2), Vector3(52, 0, 47.2)])

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


# ======================================================================
# ВИЛЮЙСКАЯ ГЭС — плотина и машинный зал, где живёт «Смена». Подступы заминированы всеми
# фракциями, на гребне — снайпер. У дороги — портфель прежнего начальника отдела ф. м.
# с пропуском. Внутри: турбина «Она», теплицы, радиорубка с диктором, пульт с журналом
# и терминалом (взлом браслета).
# ======================================================================
const GES_MINES := [Rect2(8, 12, 26, 13), Rect2(8, 41, 26, 16)]


func _ges() -> void:
	var rect := Rect2(0, 0, 90, 64)
	_begin("ges", "Вилюйская ГЭС", rect, "res://scripts/locations/ges.gd")
	var d := "ground_dirt"
	strip(null, Vector2(-6, 32), Vector2(40, 36), 2.6, d)
	road_segs.append([Vector2(-6, 32), Vector2(40, 36), 2.0])
	for r in GES_MINES:
		_mud.append(r)
	_clear.append(Rect2(0, 0, 90, 64))
	_no_edge.append(Rect2(-40, -40, 170, 52))
	_no_edge.append(Rect2(-40, 58, 170, 40))
	_ground_for("ges")
	var vil := group(root, "Village")
	# водохранилище на севере и река внизу на юге
	var wm := StandardMaterial3D.new()
	wm.albedo_color = Color("2a3c44")
	wm.roughness = 0.1
	wm.metallic = 0.2
	M["reservoir"] = wm
	box(vil, Vector3(200, 0.04, 40), Vector3(45, 0.03, -10), "reservoir").owner = root
	box(vil, Vector3(200, 0.04, 30), Vector3(45, 0.03, 76), "reservoir").owner = root
	# тело плотины: бетонная стена с гребнем, водосливы
	var dam := group(vil, "Dam")
	box(dam, Vector3(120, 3.2, 4.0), Vector3(45, 1.6, 10.0), "concrete").owner = root
	box(dam, Vector3(120, 0.4, 4.6), Vector3(45, 3.4, 10.0), "concrete").owner = root
	for x in range(0, 100, 8):
		box(dam, Vector3(0.6, 1.2, 0.6), Vector3(x, 4.2, 8.2), "metal_dark").owner = root
	for x in [56.0, 64.0, 72.0]:
		box(dam, Vector3(5.0, 3.0, 0.3), Vector3(x, 1.6, 12.1), "rust").owner = root
	_own(collider(dam, Vector3(120, 3.2, 4.0), Vector3(45, 1.6, 10.0)), root)
	_own(collider(vil, Vector3(200, 2.0, 1.0), Vector3(45, 1.0, 59.6)), root)
	# здание станции: машинный зал, радиорубка, пульт — стены-срезы
	var hall := Rect2(40, 22, 22, 22)
	var radio := Rect2(62, 22, 14, 10)
	var ctrl := Rect2(62, 32, 14, 12)
	_room_walls(vil, hall, 1.6, "concrete", [[Vector2(40, 38), 2.4], [Vector2(62, 27), 2.0], [Vector2(62, 38), 2.0]])
	_room_walls(vil, radio, 1.6, "concrete", [[Vector2(62, 27), 2.0]])
	_room_walls(vil, ctrl, 1.6, "concrete", [[Vector2(62, 38), 2.0]])
	for r in [hall, radio, ctrl]:
		box(vil, Vector3(r.size.x, 0.04, r.size.y), Vector3(r.get_center().x, 0.02, r.get_center().y), "concrete").owner = root
	_signboard(vil, "ВИЛЮЙСКАЯ ГЭС · ПОСТОРОННИМ ВХОД ВОСПРЕЩЁН", Vector3(39.6, 2.4, 33.0), -PI / 2.0, 5.6, Color("e8e0c8"))
	# турникет на входе: пока нет допуска — не пройти
	var ts := Node3D.new()
	ts.name = "Turnstile"
	vil.add_child(ts)
	ts.owner = root
	box(ts, Vector3(0.3, 1.1, 2.4), Vector3(40, 0.55, 38), "metal_dark").owner = root
	for i in 3:
		box(ts, Vector3(0.06, 0.06, 2.3), Vector3(40.2, 0.6 + i * 0.25, 38), "rust").owner = root
	_own(collider(ts, Vector3(0.4, 2.2, 2.4), Vector3(40, 1.1, 38)), root)
	# турбина «Она»: кожух, кольцо, жёлтые полосы; вокруг — теплицы под лампами
	cyl(vil, 4.0, 4.2, 2.6, Vector3(51, 1.3, 31), "metal_green", Vector3.ZERO, 32).owner = root
	cyl(vil, 4.3, 4.3, 0.2, Vector3(51, 2.6, 31), "paint_orange", Vector3.ZERO, 32).owner = root
	cyl(vil, 1.2, 1.2, 1.0, Vector3(51, 3.2, 31), "metal_dark", Vector3.ZERO, 16).owner = root
	_own(collider(vil, Vector3(8.4, 2.6, 8.4), Vector3(51, 1.3, 31)), root)
	for p in [Vector3(51, 0, 24.5), Vector3(51, 0, 41.5)]:
		for i in 4:
			box(vil, Vector3(3.6, 0.5, 1.2), p + Vector3(-7.5 + i * 5.0, 0.25, 0), "planks_old").owner = root
			box(vil, Vector3(3.4, 0.35, 1.0), p + Vector3(-7.5 + i * 5.0, 0.6, 0), "leaves").owner = root
			_own(collider(vil, Vector3(3.6, 0.8, 1.2), p + Vector3(-7.5 + i * 5.0, 0.4, 0)), root)
	var gl := group(vil, "GreenLights")
	for x in [44.0, 51.0, 58.0]:
		for z in [24.5, 41.5]:
			_lamp(gl, "Grow", Vector3(x, 2.4, z), Color("ff7ad8"), 1.2, 5.0).shadow_enabled = false
	_lamp(vil, "TurbineLight", Vector3(51, 3.6, 31), Color("a0ffb0"), 1.0, 7.0)
	# радиорубка: стол, магнитофон, микрофон
	box(vil, Vector3(3.0, 0.8, 1.0), Vector3(69, 0.4, 23.2), "planks_old").owner = root
	_own(collider(vil, Vector3(3.0, 0.8, 1.0), Vector3(69, 0.4, 23.2)), root)
	box(vil, Vector3(0.8, 0.4, 0.5), Vector3(68, 1.0, 23.2), "plastic_beige").owner = root
	cyl(vil, 0.02, 0.02, 0.5, Vector3(70, 1.05, 23.4), "metal_dark").owner = root
	box(vil, Vector3(1.2, 1.8, 0.4), Vector3(74.5, 0.9, 23.0), "metal_dark").owner = root
	# пульт: длинный стол со шкалами, журнал, терминал ЭЛТ
	box(vil, Vector3(10.0, 1.0, 1.0), Vector3(69, 0.5, 42.6), "metal_green").owner = root
	_own(collider(vil, Vector3(10.0, 1.0, 1.0), Vector3(69, 0.5, 42.6)), root)
	for i in 8:
		box(vil, Vector3(0.5, 0.4, 0.05), Vector3(65 + i * 1.1, 1.3, 43.1), "screen_amber" if i % 3 else "screen_green").owner = root
	box(vil, Vector3(0.7, 0.55, 0.6), Vector3(64.6, 1.3, 42.4), "plastic_beige").owner = root
	box(vil, Vector3(0.5, 0.35, 0.03), Vector3(64.6, 1.35, 42.08), "screen_green").owner = root
	box(vil, Vector3(0.6, 0.08, 0.45), Vector3(72.0, 1.04, 42.4), "paper").owner = root
	_lamp(vil, "CtrlLight", Vector3(69, 2.2, 38), Color("ffd08a"), 0.8, 7.0)
	# подступы: руины, таблички минных полей, череп, портфель
	_clutter(vil, [["rubble", 18.0, 22.0], ["burnt_shed", 22.0, 50.0, 0.4], ["car_wreck", 14.0, 30.0, 1.2], ["rubble", 30.0, 46.0]])
	var signs := [[Vector3(12.0, 0, 26.6), "МИНЫ · «КИМБЕРЛИТ»"], [Vector3(26.0, 0, 26.6), "НЕ ХОДИ · ШРАМ"], [Vector3(12.0, 0, 40.4), "МИНЫ · ПРОФСОЮЗ"],
		[Vector3(26.0, 0, 40.4), "МИНИРОВАНО · СОВЕТ"]]
	for sg in signs:
		cyl(vil, 0.05, 0.05, 1.4, sg[0] + Vector3(0, 0.7, 0), "planks_old").owner = root
		_signboard(vil, sg[1], sg[0] + Vector3(0, 1.4, 0), 0.0, 2.6, Color("e85a3a"))
	for r in GES_MINES:
		for k in 10:
			box(vil, Vector3(0.3, 0.06, 0.3), Vector3(randf_range(r.position.x, r.end.x), 0.03, randf_range(r.position.y, r.end.y)), "metal_dark").owner = root
	box(vil, Vector3(0.5, 0.35, 0.12), Vector3(19.6, 0.18, 36.6), "planks_old").owner = root
	sphere(vil, 0.15, Vector3(18.8, 0.15, 36.9), "paint_white").owner = root
	_woods(40)
	_dress(Rect2(2, 14, 36, 44), 160)
	# люди
	var chars := group(root, "Characters")
	character(chars, "Watch", "ges_watch", Vector3(38.6, 0, 36.2), -PI / 2.0, {"dialog": "ges_watch"})
	character(chars, "Chief", "ges_chief", Vector3(51.0, 0, 26.0), 0.0, {"dialog": "ges_chief"})
	character(chars, "Announcer", "ges_announcer", Vector3(69.0, 0, 24.6), PI, {"dialog": "ges_announcer", "start_pose": "sit"})
	character(chars, "Duty1", "ges_duty", Vector3(46.0, 0, 40.0), 0.0, {"display_name": "Дежурная по теплице"})
	character(chars, "Duty2", "ges_duty", Vector3(57.0, 0, 26.0), PI, {"display_name": "Дежурный по Ней"})
	character(chars, "Duty3", "ges_duty", Vector3(69.0, 0, 41.2), PI, {"display_name": "Дежурный у пульта"})
	character(chars, "Kid", "kid", Vector3(55.0, 0, 36.0), 1.0, {"display_name": "Ребёнок Смены"})
	character(chars, "Sniper", "ges_sniper", Vector3(26.0, 3.6, 10.0), PI, {"hostile": true, "aggro_radius": 15.0, "squad": "ges_sniper", "armed": true})
	var items := group(root, "Items")
	_exit(items, "WestRoad", "Дорога в Мирный", Vector3(1.0, 0, 32.0), Vector3(1.6, 2.2, 4.0))
	_use(items, "Briefcase", "Портфель у дороги", Vector3(19.6, 0, 36.6), Vector3(1.0, 0.6, 0.8))
	_use(items, "Turnstile", "Турникет проходной", Vector3(40.0, 0, 38.0), Vector3(0.6, 1.4, 2.4))
	_use(items, "Journal", "Журнал дежурств", Vector3(72.0, 0, 41.6), Vector3(1.0, 1.2, 0.8))
	_use(items, "Terminal", "Терминал ЭВМ", Vector3(64.6, 0, 41.6), Vector3(1.0, 1.4, 0.8))
	_use(items, "Overload", "Аварийный рубильник", Vector3(75.0, 0, 34.0), Vector3(0.8, 1.6, 0.8))
	box(vil, Vector3(0.4, 1.0, 0.3), Vector3(75.6, 1.0, 34.0), "paint_red").owner = root
	_spawn("Start", Vector3(3.0, 0, 32.0))
	_spawn("Road", Vector3(3.0, 0, 32.0))
	marker(root, "MarkHall", Vector3(51, 0, 33), "Машинный зал")
	marker(root, "MarkRadio", Vector3(69, 0, 27), "Радиорубка")
	marker(root, "MarkCtrl", Vector3(69, 0, 38), "Пульт")
	_finish("ges")


# ======================================================================
# РУБИКОН — бывший Вилюйск, куда упала бомба. Пепел, стекло, остовы домов, кратер.
# Мутанты (Вурды, Рогачи, Топтун, Ушаны) и чёрный конь Харат, который бродит по проспекту.
# Тайная тропа по северной опушке — только если браслет расшифрован (там чучуна).
# ======================================================================
func _ruin_block(parent: Node, prop: String, pos: Vector3, rot: float, nm: String) -> void:
	var b := _bld(parent, prop, nm, pos, rot)
	# копоть и провалы — дом выгорел
	for k in 4:
		box(parent, Vector3(randf_range(2.0, 4.0), randf_range(1.5, 3.0), 0.05), pos + Vector3(randf_range(-5, 5), randf_range(2.0, 6.0), 5.6 if rot == 0.0 else -5.6), "coal").owner = root
	for k in 6:
		box(parent, Vector3(randf_range(0.6, 1.4), randf_range(0.3, 0.7), randf_range(0.6, 1.2)), pos + Vector3(randf_range(-6, 6), 0.3, randf_range(5.5, 8.0) * (1.0 if rot == 0.0 else -1.0)), "concrete", Vector3(randf(), randf() * TAU, randf())).owner = root


func _rubikon() -> void:
	var rect := Rect2(0, 0, 100, 70)
	_begin("rubikon", "Рубикон", rect, "res://scripts/locations/rubikon.gd")
	var d := "ground_dirt"
	strip(null, Vector2(-6, 38), Vector2(106, 38), 5.0, d)
	road_segs.append([Vector2(-6, 38), Vector2(106, 38), 2.6])
	strip(null, Vector2(4, 9), Vector2(96, 9), 1.4, d)
	road_segs.append([Vector2(4, 9), Vector2(96, 9), 0.8])
	_mud.append(Rect2(0, 18, 100, 52))
	_clear.append(Rect2(0, 16, 100, 54))
	_ground_for("rubikon")
	_env_dim()
	var vil := group(root, "Village")
	# кратер: оплавленное стекло кольцами
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color("2a3a34")
	gm.roughness = 0.05
	gm.metallic = 0.4
	M["glassed"] = gm
	for i in 5:
		cyl(vil, 13.0 - i * 2.4, 13.2 - i * 2.4, 0.05, Vector3(56, 0.03 + i * 0.005, 58), "glassed" if i % 2 == 0 else "coal", Vector3.ZERO, 40).owner = root
	_own(collider(vil, Vector3(14.0, 1.0, 10.0), Vector3(56, 0.5, 60)), root)
	# остовы домов вдоль проспекта
	var k := 0
	for spec in [["nr_stalin4", Vector3(14, 0, 26), 0.0], ["st_block4", Vector3(36, 0, 25), 0.0], ["nr_stalin3", Vector3(62, 0, 26), 0.0], ["st_block3a", Vector3(86, 0, 25), 0.0],
			["st_block3b", Vector3(18, 0, 50), PI], ["st_block2", Vector3(34, 0, 49), PI], ["st_barrack2", Vector3(84, 0, 49), PI]]:
		_ruin_block(vil, spec[0], spec[1], spec[2], "Ruin%d" % k)
		k += 1
	_clutter(vil, [["car_wreck", 24, 36.0, 0.3], ["car_wreck", 48, 40.0, 2.4], ["paz_wreck", 72, 36.5, 0.1], ["car_wreck", 92, 40.0, 1.0],
		["rubble", 30, 34], ["rubble", 54, 42], ["rubble", 78, 34], ["burnt_shed", 46, 30, 0.6], ["rubble", 66, 46], ["rubble", 8, 44]])
	for p in [Vector3(6, 0, 30), Vector3(44, 0, 46), Vector3(70, 0, 30), Vector3(96, 0, 46), Vector3(28, 0, 60), Vector3(80, 0, 62)]:
		put(P.dead_tree, vil, p, randf() * TAU)
	# кости и черепа у дороги
	for p in [Vector3(20, 0, 41), Vector3(52, 0, 35), Vector3(76, 0, 41)]:
		sphere(vil, 0.14, p + Vector3(0, 0.14, 0), "paint_white").owner = root
		box(vil, Vector3(0.6, 0.06, 0.08), p + Vector3(0.4, 0.04, 0.2), "paint_white", Vector3(0, 0.6, 0)).owner = root
	_harat(vil, Vector3(12, 0, 38))
	_signboard(vil, "ВИЛЮЙСК · 1634", Vector3(4.0, 1.6, 34.0), 0.0, 3.0, Color("b0a890"))
	_woods(220)
	# люди и звери
	var chars := group(root, "Characters")
	var muts := [["Vurd1", "mt_vurd", Vector3(30, 0, 42)], ["Vurd2", "mt_vurd", Vector3(32, 0, 44)], ["Vurd3", "mt_vurd", Vector3(28.5, 0, 45)],
		["Rogach1", "mt_rogach", Vector3(66, 0, 34)], ["Rogach2", "mt_rogach", Vector3(69, 0, 33)], ["Toptun", "mt_toptun", Vector3(56, 0, 48)],
		["Ushan1", "mt_ushan", Vector3(84, 0, 42)], ["Ushan2", "mt_ushan", Vector3(86, 0, 44)], ["Ushan3", "mt_ushan", Vector3(10, 0, 50)]]
	for m in muts:
		character(chars, m[0], m[1], m[2], randf() * TAU, {"hostile": true, "aggro_radius": 7.5, "squad": "rb_" + str(m[0]).left(4)})
	character(chars, "Chuchuna", "chuchuna", Vector3(50, 0, 9.5), PI / 2.0, {"hostile": true, "aggro_radius": 8.0, "squad": "rb_trail"})
	for i in 3:
		character(chars, "Ally%d" % i, "ally_militia", Vector3(6 + i * 1.5, 0, 40.5), 0.0, {"display_name": "Ополченец", "armed": true})
	var items := group(root, "Items")
	_exit(items, "WestExit", "Назад, на тракт", Vector3(1.0, 0, 38.0), Vector3(1.6, 2.2, 5.0))
	_exit(items, "EastExit", "Дальше на восток — к Горному", Vector3(99.0, 0, 38.0), Vector3(1.6, 2.2, 5.0))
	_use(items, "TrailIn", "Тропа в чаще", Vector3(4.0, 0, 11.0), Vector3(1.6, 2.0, 1.6))
	_use(items, "TrailOut", "Конец тропы", Vector3(96.0, 0, 9.0), Vector3(1.6, 2.0, 1.6))
	_spawn("Start", Vector3(4.0, 0, 38.0))
	_spawn("Road", Vector3(4.0, 0, 38.0))
	_spawn("Trail", Vector3(6.0, 0, 9.0))
	_spawn("FromEast", Vector3(96.0, 0, 38.0))
	marker(root, "MarkCrater", Vector3(56, 0, 58), "Кратер")
	_finish("rubikon")


## Сумрак: низкое солнце сквозь пепел
func _env_dim() -> void:
	var env := root.get_node("Env/WorldEnvironment").environment as Environment
	env.ambient_light_color = Color("8a8070")
	env.ambient_light_energy = 0.3
	env.fog_light_color = Color("6a6050")
	env.fog_density = 0.004
	env.adjustment_saturation = 0.55


## Харат — чёрный конь: собран из коробок, бродит сам (его водит скрипт локации)
func _harat(parent: Node, pos: Vector3) -> Node3D:
	var h := Node3D.new()
	h.name = "Harat"
	h.position = pos
	parent.add_child(h)
	h.owner = root
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Color("0c0b0b")
	bm.roughness = 0.4
	M["harat"] = bm
	var em := StandardMaterial3D.new()
	em.albedo_color = Color("ff3020")
	em.emission_enabled = true
	em.emission = Color("ff2010")
	em.emission_energy_multiplier = 3.0
	M["harat_eye"] = em
	box(h, Vector3(1.3, 1.5, 3.6), Vector3(0, 2.6, 0), "harat").owner = root
	box(h, Vector3(0.7, 1.8, 0.8), Vector3(0, 3.8, 1.9), "harat", Vector3(-0.5, 0, 0)).owner = root
	box(h, Vector3(0.6, 0.6, 1.4), Vector3(0, 4.6, 2.7), "harat", Vector3(0.3, 0, 0)).owner = root
	for sx in [-0.2, 0.2]:
		box(h, Vector3(0.1, 0.1, 0.05), Vector3(sx, 4.75, 3.35), "harat_eye").owner = root
	for i in 4:
		var leg := Node3D.new()
		leg.name = "Leg%d" % i
		leg.position = Vector3(-0.45 if i % 2 == 0 else 0.45, 2.0, 1.3 if i < 2 else -1.3)
		h.add_child(leg)
		leg.owner = root
		box(leg, Vector3(0.3, 2.0, 0.3), Vector3(0, -1.0, 0), "harat").owner = root
	box(h, Vector3(0.2, 1.4, 0.2), Vector3(0, 2.6, -2.0), "harat", Vector3(0.7, 0, 0)).owner = root
	return h


# ======================================================================
# ГОРНЫЙ — посёлок под «Горизонтом»: свет, еда, порядок. Ровные улицы, фонари,
# теплицы, плакаты. Но люди уходят «на работы» и не возвращаются, а у северной ограды
# по ночам кормят Ушана в детской шапке.
# ======================================================================
func _gorny() -> void:
	var rect := Rect2(0, 0, 72, 56)
	_begin("gorny", "Горный", rect, "res://scripts/locations/gorny.gd")
	var d := "ground_dirt"
	strip(null, Vector2(-6, 30), Vector2(78, 30), 3.4, d)
	strip(null, Vector2(36, 8), Vector2(36, 52), 2.4, d)
	road_segs.append([Vector2(-6, 30), Vector2(78, 30), 2.4])
	road_segs.append([Vector2(36, 8), Vector2(36, 52), 1.6])
	_clear.append(Rect2(4, 4, 64, 48))
	_ground_for("gorny")
	var vil := group(root, "Village")
	# ограда: бетонные плиты, на севере — с проходом к лесу
	_wall(vil, Vector2(6, 6), Vector2(66, 6), [[28.0, 34.0]])
	_wall(vil, Vector2(6, 52), Vector2(66, 52))
	_wall(vil, Vector2(6, 6), Vector2(6, 26))
	_wall(vil, Vector2(6, 34), Vector2(6, 52))
	_wall(vil, Vector2(66, 6), Vector2(66, 26))
	_wall(vil, Vector2(66, 34), Vector2(66, 52))
	# дома: аккуратные, побелённые, с горящими окнами
	var houses := [["st_block2b", Vector3(16, 0, 18), 0.0], ["st_block2b", Vector3(54, 0, 18), 0.0], ["st_block2", Vector3(16, 0, 42), PI],
		["st_block3b", Vector3(56, 0, 43), PI], ["st_store", Vector3(26, 0, 18.5), 0.0]]
	var k := 0
	for h in houses:
		_bld(vil, h[0], "House%d" % k, h[1], h[2])
		k += 1
	var club := _bld(vil, "st_canteen", "Canteen", Vector3(46, 0, 18.5))
	_sign_on(vil, club, "СТОЛОВАЯ · ПО ТАЛОНАМ", 3.8, Color("e8f0ff"))
	for p in [Vector3(26, 0, 42), Vector3(40, 0, 43)]:
		put(P.greenhouse, vil, p, 0.0)
	_signboard(vil, "«ГОРИЗОНТ» ЗАБОТИТСЯ О ВАС", Vector3(36, 3.0, 26.6), 0.0, 5.0, Color("e8f0ff"))
	_signboard(vil, "НАБОР НА РАБОТЫ В ЯКУТСК · ХОРОШАЯ ОПЛАТА", Vector3(8.6, 2.0, 22.0), PI / 2.0, 4.6, Color("e8f0ff"))
	_info_screen(vil, Vector3(30, 0, 33.6), PI, "ГОРНЫЙ\nСвет: 24 ч\nТалоны: выдача в 9:00")
	for p in [Vector3(12, 0, 27.6), Vector3(24, 0, 27.6), Vector3(48, 0, 27.6), Vector3(60, 0, 27.6), Vector3(12, 0, 32.4), Vector3(60, 0, 32.4),
			Vector3(33.6, 0, 12), Vector3(33.6, 0, 48)]:
		_lamp_post(vil, p, Color("e8f0ff"))
	for b in [[Vector3(20, 0, 32.4), PI], [Vector3(52, 0, 32.4), PI]]:
		put(P.nr_bench, vil, b[0], b[1])
	_woods(140)
	var chars := group(root, "Characters")
	character(chars, "Elder", "gr_elder", Vector3(36.8, 0, 28.2), PI, {"dialog": "gr_elder"})
	character(chars, "Mother", "gr_mother", Vector3(30.0, 0, 12.0), 0.0, {"dialog": "gr_mother"})
	character(chars, "Hunter1", "gr_hunter", Vector3(56.0, 0, 26.0), PI, {"display_name": "Охотник", "armed": true})
	character(chars, "Hunter2", "gr_hunter", Vector3(22.0, 0, 26.0), PI, {"display_name": "Охотник", "armed": true})
	character(chars, "HzPatrol", "hz_guard", Vector3(20, 0, 31), PI / 2.0, {"display_name": "Патруль «Горизонта»",
		"patrol": PackedVector3Array([Vector3(20, 0, 31), Vector3(56, 0, 31), Vector3(36, 0, 46), Vector3(36, 0, 14)]), "patrol_wait": 5.0})
	character(chars, "Kid1", "kid", Vector3(40, 0, 32), 1.0, {"display_name": "Чистый, сытый мальчишка"})
	character(chars, "Woman1", "town_f1", Vector3(46, 0, 23), PI, {"display_name": "Жительница с талонами"})
	character(chars, "Ushan", "mt_ushan", Vector3(31.0, 0, 2.0), 0.0, {"display_name": "Ушан в детской шапке", "look": {"skin": "#a8a094", "cap": "#c83a2a"}})
	var items := group(root, "Items")
	_exit(items, "WestExit", "На запад, к Рубикону", Vector3(1.0, 0, 30.0), Vector3(1.6, 2.2, 5.0))
	_exit(items, "EastExit", "На восток — к ГРЭС-2", Vector3(71.0, 0, 30.0), Vector3(1.6, 2.2, 5.0))
	_spawn("Start", Vector3(3.0, 0, 30.0))
	_spawn("Road", Vector3(3.0, 0, 30.0))
	marker(root, "MarkElder", Vector3(36, 0, 28), "Староста")
	_finish("gorny")


# ======================================================================
# ГРЭС-2: поверхность у Якутска — кратер, мёртвые трубы, пост «Горизонта» и шахта лифта.
# Подземный комплекс (сцена complex): лифт с музыкой, офис, кабинет и. о. генерального,
# лаборатория Виктора, серверный зал с Киршем. Кирк — у дверей серверной.
# ======================================================================
func _yakutsk() -> void:
	var rect := Rect2(0, 0, 70, 56)
	_begin("yakutsk", "ГРЭС-2", rect, "res://scripts/locations/yakutsk.gd")
	var d := "ground_dirt"
	strip(null, Vector2(-6, 30), Vector2(50, 30), 3.0, d)
	road_segs.append([Vector2(-6, 30), Vector2(50, 30), 2.0])
	_mud.append(Rect2(0, 0, 70, 56))
	_clear.append(Rect2(0, 0, 70, 56))
	_ground_for("yakutsk")
	_env_dim()
	var vil := group(root, "Village")
	# кратер от бомбы на юге
	for i in 4:
		cyl(vil, 14.0 - i * 3.0, 14.2 - i * 3.0, 0.05, Vector3(24, 0.03 + i * 0.005, 52), "coal" if i % 2 else "concrete", Vector3.ZERO, 40).owner = root
	# ГРЭС-2: корпус и трубы
	box(vil, Vector3(20, 12, 10), Vector3(56, 6, 10), "brick").owner = root
	_own(collider(vil, Vector3(20, 12, 10), Vector3(56, 6, 10)), root)
	for x in [50.0, 58.0, 66.0]:
		cyl(vil, 1.4, 2.0, 30.0, Vector3(x, 15.0, 4.0), "concrete", Vector3.ZERO, 16).owner = root
		for k in 3:
			cyl(vil, 2.1, 2.1, 0.5, Vector3(x, 10.0 + k * 8.0, 4.0), "paint_red" if k % 2 == 0 else "paint_white", Vector3.ZERO, 16).owner = root
	_signboard(vil, "ГРЭС-2 · ООО «ГОРИЗОНТ» · ОБЪЕКТ «ВОЗРОЖДЕНИЕ»", Vector3(56, 4.0, 15.1), 0.0, 8.0, Color("e8f0ff"))
	# пост и будка лифта
	_bld(vil, "checkpoint", "Post", Vector3(40, 0, 26.0), PI / 2.0)
	_bld(vil, "sandbags", "Sand1", Vector3(42, 0, 34.0), PI / 2.0)
	var lift := group(vil, "LiftHouse")
	lift.position = Vector3(52, 0, 30)
	box(lift, Vector3(6, 4, 6), Vector3(0, 2, 0), "concrete").owner = root
	box(lift, Vector3(2.4, 2.8, 0.1), Vector3(0, 1.4, 3.05), "metal_dark").owner = root
	box(lift, Vector3(0.3, 0.3, 0.1), Vector3(1.6, 1.4, 3.1), "led_green" if M.has("led_green") else "screen_green").owner = root
	_own(collider(lift, Vector3(6, 4, 6), Vector3(0, 2, 0)), root)
	for p in [Vector3(14, 0, 20), Vector3(30, 0, 40), Vector3(8, 0, 44)]:
		put(P.dead_tree, vil, p, randf() * TAU)
	_clutter(vil, [["car_wreck", 20, 33, 0.4], ["rubble", 30, 22], ["rubble", 46, 44]])
	_woods(60)
	var chars := group(root, "Characters")
	for i in 2:
		character(chars, "Gate%d" % i, "hz_guard", Vector3(44.0, 0, 27.0 + i * 5.5), -PI / 2.0, {"hostile": true, "aggro_radius": 9.0, "squad": "yk_gate", "armed": true})
	var items := group(root, "Items")
	_exit(items, "WestExit", "Назад, к Горному", Vector3(1.0, 0, 30.0), Vector3(1.6, 2.2, 5.0))
	_use(items, "Lift", "Лифт вниз", Vector3(52, 0, 33.6), Vector3(2.4, 2.4, 1.0))
	_spawn("Start", Vector3(3.0, 0, 30.0))
	_spawn("Road", Vector3(3.0, 0, 30.0))
	_spawn("FromLift", Vector3(52, 0, 35.5))
	marker(root, "MarkLift", Vector3(52, 0, 30), "Лифт")
	_finish("yakutsk")


func _complex() -> void:
	var rect := Rect2(0, 0, 64, 40)
	seed(2062)
	root = Node3D.new()
	root.name = "Complex"
	root.set_script(load("res://scripts/locations/complex.gd"))
	root.set("location_id", "complex")
	root.set("title", "Комплекс «Возрождение»")
	root.set("map_rect", rect)
	root.set("camera_start", Vector3(6, 0, 20))
	var plain := func(c: String, rough: float, metal := 0.0) -> StandardMaterial3D:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(c)
		m.roughness = rough
		m.metallic = metal
		return m
	M["of_floor"] = plain.call("5a5248", 0.9)
	M["of_wall"] = plain.call("b8b0a0", 0.8)
	M["of_carpet"] = plain.call("4a5a6a", 1.0)
	M["srv"] = plain.call("2a2c30", 0.4, 0.4)
	_dark_env(Color("6a6a70"), 0.45)
	var v := group(root, "Village")
	_floor(v, rect.grow(0.3), "of_floor")
	var lobby := Rect2(1, 14, 11, 12)
	var office := Rect2(12, 3, 28, 34)
	var cab := Rect2(40, 3, 12, 14)
	var lab := Rect2(40, 23, 12, 14)
	var srv := Rect2(52, 3, 11, 34)
	_room_walls(v, lobby, 1.4, "of_wall", [[Vector2(12, 20), 2.4]])
	_room_walls(v, office, 1.4, "of_wall", [[Vector2(12, 20), 2.4], [Vector2(40, 10), 2.0], [Vector2(40, 30), 2.0], [Vector2(40, 20), 2.0]])
	_room_walls(v, cab, 1.4, "of_wall", [[Vector2(40, 10), 2.0]])
	_room_walls(v, lab, 1.4, "of_wall", [[Vector2(40, 30), 2.0]])
	_room_walls(v, Rect2(40, 17, 12, 6), 1.4, "of_wall", [[Vector2(40, 20), 2.0], [Vector2(52, 20), 2.0]])
	_room_walls(v, srv, 1.4, "of_wall", [[Vector2(52, 20), 2.0]])
	box(v, Vector3(28, 0.02, 34), Vector3(26, 0.02, 20), "of_carpet").owner = root
	# лифт: двери, динамик с музыкой
	box(v, Vector3(0.2, 2.6, 2.4), Vector3(1.2, 1.3, 20), "metal_dark").owner = root
	box(v, Vector3(0.4, 0.4, 0.3), Vector3(1.4, 2.3, 18.2), "plastic_dark").owner = root
	# офис: столы с ЭЛТ, доска «Лучший сотрудник месяца», стенгазета, пальма
	for row in 3:
		for col in 4:
			var p := Vector3(16 + col * 6.0, 0, 8 + row * 9.0)
			box(v, Vector3(2.2, 0.75, 1.0), p + Vector3(0, 0.38, 0), "planks_old").owner = root
			box(v, Vector3(0.5, 0.42, 0.45), p + Vector3(-0.4, 0.96, -0.1), "plastic_beige").owner = root
			box(v, Vector3(0.36, 0.28, 0.02), p + Vector3(-0.4, 0.98, 0.13), "screen_green" if (row + col) % 2 else "screen_amber").owner = root
			_own(collider(v, Vector3(2.2, 0.8, 1.0), p + Vector3(0, 0.4, 0)), root)
	box(v, Vector3(10.0, 2.2, 0.08), Vector3(26, 1.5, 3.1), "planks_old").owner = root
	for i in 20:
		box(v, Vector3(0.7, 0.85, 0.02), Vector3(21.8 + (i % 10) * 0.85, 1.0 + int(i / 10) * 1.0, 3.16), "paper" if i % 7 else "coal").owner = root
	var lb := Label3D.new()
	lb.text = "ЛУЧШИЙ СОТРУДНИК МЕСЯЦА"
	lb.font_size = 48
	lb.pixel_size = 0.006
	lb.modulate = Color("2a2a26")
	lb.position = Vector3(26, 2.45, 3.18)
	v.add_child(lb)
	lb.owner = root
	box(v, Vector3(4.0, 1.4, 0.06), Vector3(34, 1.4, 36.9), "paper").owner = root
	cyl(v, 0.35, 0.3, 0.6, Vector3(13.5, 0.3, 35.5), "brick").owner = root
	for k in 4:
		box(v, Vector3(0.06, 1.2, 0.5), Vector3(13.5, 1.2, 35.5), "plywood" if M.has("plywood") else "planks_old", Vector3(0.6, k * 0.8, 0)).owner = root
	# кабинет и. о. генерального: стол, архив, портрет молодого Кирша
	box(v, Vector3(3.0, 0.8, 1.2), Vector3(46, 0.4, 8), "planks_old").owner = root
	_own(collider(v, Vector3(3.0, 0.8, 1.2), Vector3(46, 0.4, 8)), root)
	box(v, Vector3(1.6, 1.2, 0.06), Vector3(46, 1.6, 3.1), "frame_white").owner = root
	box(v, Vector3(2.0, 2.0, 0.6), Vector3(50.5, 1.0, 5.0), "metal_dark").owner = root
	_own(collider(v, Vector3(2.0, 2.0, 0.6), Vector3(50.5, 1.0, 5.0)), root)
	_signboard(v, "И. О. ГЕНЕРАЛЬНОГО ДИРЕКТОРА Р. О. КИРШ", Vector3(39.8, 2.0, 12.0), -PI / 2.0, 3.6, Color("e8e0c8"))
	# лаборатория Виктора: стол с осциллографом, капсула
	box(v, Vector3(4.0, 0.9, 1.0), Vector3(46, 0.45, 35), "metal_green").owner = root
	_own(collider(v, Vector3(4.0, 0.9, 1.0), Vector3(46, 0.45, 35)), root)
	cyl(v, 0.9, 0.9, 2.2, Vector3(49, 1.1, 27), "glass", Vector3.ZERO, 16).owner = root
	_own(collider(v, Vector3(1.8, 2.2, 1.8), Vector3(49, 1.1, 27)), root)
	# серверный зал: стойки рядами, кресло Генерального с трубками
	for row in 2:
		for i in 6:
			var p := Vector3(54.5 + row * 6.0, 0, 6.0 + i * 5.0)
			if absf(p.z - 20) < 3.0:
				continue
			box(v, Vector3(1.0, 2.2, 3.4), p + Vector3(0, 1.1, 0), "srv").owner = root
			for l in 4:
				box(v, Vector3(0.05, 0.08, 0.08), p + Vector3(0.52, 0.5 + l * 0.4, -1.2 + l * 0.7), "led_green" if (i + l) % 2 else "led_red").owner = root
			_own(collider(v, Vector3(1.0, 2.2, 3.4), p + Vector3(0, 1.1, 0)), root)
	box(v, Vector3(1.4, 1.2, 1.4), Vector3(60.5, 0.6, 20), "sofa").owner = root
	cyl(v, 0.04, 0.04, 2.0, Vector3(61.6, 1.0, 21.0), "metal_dark").owner = root
	box(v, Vector3(0.3, 0.4, 0.1), Vector3(61.6, 1.9, 21.0), "glass").owner = root
	_own(collider(v, Vector3(1.4, 1.2, 1.4), Vector3(60.5, 0.6, 20)), root)
	# дверь серверной: закрыта, пока Кирк стоит на пути
	var sd := Node3D.new()
	sd.name = "SrvDoor"
	v.add_child(sd)
	sd.owner = root
	box(sd, Vector3(0.24, 1.4, 2.0), Vector3(52, 0.7, 20), "metal_dark").owner = root
	_own(collider(sd, Vector3(0.3, 2.2, 2.0), Vector3(52, 1.1, 20)), root)
	var lamps := group(v, "Lamps")
	for p in [Vector3(6, 2.4, 20), Vector3(19, 2.4, 10), Vector3(33, 2.4, 10), Vector3(19, 2.4, 30), Vector3(33, 2.4, 30), Vector3(46, 2.4, 10),
			Vector3(46, 2.4, 30), Vector3(46, 2.4, 20), Vector3(57, 2.4, 10), Vector3(57, 2.4, 30)]:
		_lamp(lamps, "Lamp", p, Color("e8f0ff"), 1.2, 9.0).shadow_enabled = false
	var chars := group(root, "Characters")
	character(chars, "Kirk", "hz_kirk", Vector3(49.5, 0, 20.0), -PI / 2.0, {"dialog": "hz_kirk"})
	character(chars, "Viktor", "hz_viktor", Vector3(46.0, 0, 33.6), PI, {"dialog": "hz_viktor"})
	character(chars, "Kirsh", "hz_kirsh", Vector3(60.5, 0, 20.0), -PI / 2.0, {"dialog": "hz_kirsh", "start_pose": "sit"})
	character(chars, "Clerk1", "hz_clerk", Vector3(16.6, 0, 9.0), PI, {"display_name": "Сотрудница отдела учёта", "start_pose": "sit"})
	character(chars, "Clerk2", "hz_clerk", Vector3(28.6, 0, 18.0), PI, {"display_name": "Сотрудник планового отдела", "start_pose": "sit"})
	character(chars, "Clerk3", "hz_clerk", Vector3(22.6, 0, 27.0), PI, {"display_name": "Сотрудница архива", "start_pose": "sit"})
	for i in 4:
		character(chars, "Guard%d" % i, "hz_guard", Vector3(18 + i * 6.0, 0, 21.6), -PI / 2.0, {"hostile": true, "aggro_radius": 8.0, "squad": "cx_guard%d" % (i / 2), "armed": true})
	for i in 3:
		character(chars, "Ally%d" % i, "ally_militia", Vector3(4.5 + i * 1.2, 0, 22.0), 0.0, {"display_name": "Ополченец", "armed": true})
	var items := group(root, "Items")
	_use(items, "LiftUp", "Лифт наверх", Vector3(2.0, 0, 20), Vector3(1.0, 2.4, 2.4))
	_use(items, "Archive", "Архив отдела", Vector3(50.5, 0, 6.0), Vector3(2.0, 2.0, 0.8))
	_use(items, "Board", "«Лучший сотрудник месяца»", Vector3(26, 0, 3.8), Vector3(10.0, 2.4, 0.6))
	_use(items, "Palm", "Пальма в кадке", Vector3(13.5, 0, 35.5), Vector3(0.9, 1.8, 0.9))
	_spawn("Start", Vector3(4.0, 0, 20.0))
	_spawn("FromLift", Vector3(4.0, 0, 20.0))
	marker(root, "MarkOffice", Vector3(26, 0, 20), "Офис")
	marker(root, "MarkSrv", Vector3(57, 0, 20), "Серверный зал")
	_finish("complex")
