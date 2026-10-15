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
	var only := ""
	for a in OS.get_cmdline_user_args():
		only = a
	if only == "" or only == "markun":
		_markun()


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
