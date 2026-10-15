extends "res://tools/build_sungar.gd"
## Нью-Рба — большой алмазный город на месте Нюрбы (Акт II). Город квадратный,
## четыре квадратных района 2×2: Проход (вход и низы, юго-запад), Центр (юго-восток),
## Промрайон (северо-запад), Чёрный район (северо-восток). Старые дома — сталинки
## (руст, пилястры, шпиль с часами) и кирпичные лабазы со складами (tools/build_city.gd,
## nr_*). Улицы — прямая сетка, кварталы квадратные.
## Запуск: godot --headless --path . res://tools/build_nyurba.tscn

## Сторона района, м
const NR := 84.0
## Проспект (запад — восток) и улица (север — юг) — ширина
const AVE_W := 7.0
const LANE_W := 4.0


func _build() -> void:
	_load_all()
	_proxod()
	_sewer()
	_center()
	_prom()
	_black()


## Материалы и пропы города (их же берёт tools/build_east.gd)
func _load_all() -> void:
	for n in ["cloth_sack", "cloth_red", "rope_mat", "rust", "metal_dark", "tin", "hay", "bark_dark", "planks_old",
			"stone_wall", "tire", "paper", "metal_roof", "glass", "paint_faded", "paint_white", "cloth", "water", "log_dark",
			"log_weathered", "ground_dirt", "concrete", "coal", "soot", "manure"]:
		M[n] = load(MAT_DIR + n + ".tres")
	for n in ["screen_green", "screen_amber", "plastic_beige", "flag_red", "window_sky", "plaster_yellow", "plaster_pink", "plaster_white",
			"plaster_ochre", "plaster_cream", "brick", "brick_white", "paint_green", "paint_blue", "paint_red", "tar", "felt", "frame_white"]:
		M[n] = load(MAT_DIR + n + ".tres")
	for n in ["nr_stalin3", "nr_stalin4", "nr_stalin4b", "nr_stalin_spire", "nr_bank", "nr_hotel", "nr_labaz", "nr_labaz_bar",
			"nr_labaz_pawn", "nr_labaz_row", "nr_labaz_row2", "nr_warehouse",
			"nr_stalin3_in", "nr_stalin4b_in", "nr_labaz_row_in", "nr_warehouse_in", "nr_wall", "nr_wall_tower",
			"nr_junk_bags", "nr_junk_scrap", "nr_junk_furniture", "nr_junk_tires", "nr_dumpster", "nr_manhole", "nr_manhole_open",
			"nr_drain", "nr_bench", "nr_casino", "nr_gov", "nr_barracks", "nr_factory", "nr_factory_b", "nr_nochlezhka", "nr_ryumka",
			"nr_shack", "nr_shack_b", "st_canteen", "st_obshaga",
			"st_block3a", "st_block3b", "st_block4", "st_block4b", "st_block2", "st_block2b", "st_barrack2",
			"heat_pipe_low", "heat_pipe_high", "heat_pipe_riser", "boiler_house", "water_tower", "garages", "kiosk", "kiosk_b",
			"bus_stop", "conc_fence", "paz_wreck", "bins", "cf_info_screen", "loudspeaker", "power_pole", "sandbags", "checkpoint",
			"notice_board", "trash_pile", "trash_pile_b", "rubble", "car_wreck", "burnt_shed", "burn_barrel", "boardwalk"]:
		P[n] = load(PROP_DIR + n + ".tscn")


## Горожане без своего разговора — с репликами над головой
func _finish(id: String) -> void:
	var chars := root.get_node_or_null("Characters")
	if chars:
		for c in chars.get_children():
			if str(c.get("dialog")) == "" and not c.get("hostile"):
				c.set("dialog", "rumors")
	super._finish(id)


## Бетонная стена по линии (a → b) из плит по 4 м; gaps — [[t0, t1], …] проёмы вдоль линии
func _wall(parent: Node, a: Vector2, b: Vector2, gaps := []) -> void:
	var dir := (b - a).normalized()
	var l := a.distance_to(b)
	var rot := -atan2(dir.y, dir.x)
	var t := 2.0
	while t < l:
		var open := false
		for g in gaps:
			if t > float(g[0]) - 2.0 and t < float(g[1]) + 2.0:
				open = true
		if not open:
			var p := a + dir * t
			put(P.conc_fence, parent, Vector3(p.x, 0, p.y), rot)
		t += 4.0


## Кучи мусора, в которых можно порыться (раз в сутки): ставятся сейчас, точки «Junk*» — в конце
var _junk_spots := []
const JUNK_LABEL := {"nr_junk_bags": "Мешки с мусором", "nr_junk_scrap": "Куча железа", "nr_junk_furniture": "Сломанная мебель",
	"nr_junk_tires": "Покрышки", "nr_dumpster": "Мусорный бак", "trash_pile": "Куча мусора", "trash_pile_b": "Куча мусора"}


func _junk(parent: Node, kind: String, pos: Vector3, rot := 0.0) -> void:
	put(P[kind], parent, pos, rot)
	_junk_spots.append([kind, pos])


func _junk_items(items: Node) -> void:
	var i := 0
	for j in _junk_spots:
		var it := _use(items, "Junk%d" % i, str(JUNK_LABEL.get(j[0], "Мусор")), j[1], Vector3(1.8, 1.2, 1.6))
		it.set_meta("junk", str(j[0]))
		i += 1
	_junk_spots.clear()


## Городская стена из пролётов по 6 м по линии a → b (без проёмов), башни — в towers
func _city_wall(parent: Node, a: Vector2, b: Vector2, towers := []) -> void:
	var dir := (b - a).normalized()
	var l := a.distance_to(b)
	var rot := -atan2(dir.y, dir.x)
	var t := 3.0
	while t < l + 0.1:
		var p := a + dir * t
		put(P.nr_wall, parent, Vector3(p.x, 0, p.y), rot)
		t += 6.0
	for tw in towers:
		var q := a + dir * float(tw)
		put(P.nr_wall_tower, parent, Vector3(q.x, 0, q.y), 0.0)


## Ворота: две створки на петлях (узлы GateLeafN / GateLeafS — их крутит скрипт локации),
## над проёмом — кирпичная арка с вывеской. hinge_z — петли, створка длиной len к центру
func _city_gate(parent: Node, x: float, zc: float, half: float, title: String) -> void:
	box(parent, Vector3(1.6, 1.4, half * 2.0 + 1.6), Vector3(x, 6.2, zc), "brick").owner = root
	box(parent, Vector3(1.8, 0.25, half * 2.0 + 1.8), Vector3(x, 7.0, zc), "concrete").owner = root
	for k in 5:
		box(parent, Vector3(1.0, 0.6, 0.8), Vector3(x, 7.4, zc - half + k * half / 2.0), "brick").owner = root
	_signboard(parent, title, Vector3(x - 0.85, 6.2, zc), -PI / 2.0, half * 1.4, Color("f0d890"))
	for side in [["GateLeafN", -1.0], ["GateLeafS", 1.0]]:
		var leaf := Node3D.new()
		leaf.name = side[0]
		parent.add_child(leaf)
		leaf.owner = root
		var sg: float = -side[1]  # створка тянется к центру проёма
		leaf.position = Vector3(x, 0, zc + float(side[1]) * half)
		var ln := half - 0.05
		box(leaf, Vector3(0.18, 4.4, ln), Vector3(0, 2.3, sg * ln / 2.0), "rust").owner = root
		for y in [0.6, 2.3, 4.0]:
			box(leaf, Vector3(0.26, 0.16, ln), Vector3(0, y, sg * ln / 2.0), "metal_dark").owner = root
		box(leaf, Vector3(0.24, 0.14, ln * 1.25), Vector3(0, 1.45, sg * ln / 2.0), "metal_dark", Vector3(atan2(1.7, ln) * sg, 0, 0)).owner = root
		for k in int(ln / 0.4):
			box(leaf, Vector3(0.06, 0.4, 0.06), Vector3(0, 4.7, sg * (0.2 + k * 0.4)), "metal_dark").owner = root
		cyl(leaf, 0.12, 0.12, 4.6, Vector3(0, 2.3, 0), "metal_dark").owner = root
		_own(collider(leaf, Vector3(0.3, 3.0, ln), Vector3(0, 1.5, sg * ln / 2.0)), root)


## Тротуар вдоль фасада: плитка поверх земли
func _walk(parent: Node, r: Rect2) -> void:
	_pavement(parent, r)


# ======================================================================
# ПРОХОД — вход в город и низы: ворота с охраной, банк, ломбард, бар «Забой»,
# лавки в лабазах, склады; бичи у бочек, банда во дворе
# ======================================================================
func _proxod() -> void:
	var rect := Rect2(0, 0, NR, NR)
	_begin("nyurba", "Нью-Рба · Проход", rect, "res://scripts/locations/nyurba.gd")
	var d := "ground_dirt"
	# сетка улиц: проспект z = 40, улица x = 44 (на север — в Промрайон), переулки z = 16, z = 64, x = 20
	strip(null, Vector2(-8, 40), Vector2(NR + 8, 40), AVE_W, d)
	strip(null, Vector2(44, -8), Vector2(44, 70), AVE_W, d)
	for seg in [[Vector2(20, 16), Vector2(NR, 16)], [Vector2(20, 64), Vector2(NR, 64)], [Vector2(20, 12), Vector2(20, 68)]]:
		strip(null, seg[0], seg[1], LANE_W, d)
	_street_out(Vector2(NR, 40), 1.0)
	_street_out(Vector2(0, 40), -1.0)
	road_segs.append([Vector2(-8, 40), Vector2(NR + 8, 40), 3.3])
	road_segs.append([Vector2(44, -8), Vector2(44, 70), 3.3])
	road_segs.append([Vector2(39, 35), Vector2(49, 45), 6.0])  # площадь на перекрёстке
	for seg in [[Vector2(20, 16), Vector2(NR, 16)], [Vector2(20, 64), Vector2(NR, 64)], [Vector2(20, 12), Vector2(20, 68)]]:
		road_segs.append([seg[0], seg[1], 1.8])
	_mud.append(Rect2(8, 66, 12, 10))
	_mud.append(Rect2(23, 54, 14, 7))
	_clear.append(Rect2(-8, -8, NR + 16, NR + 16))
	_no_edge.append(Rect2(-60, -60, NR + 120, 60))  # север — город дальше
	_ground_for("nyurba")
	var vil := group(root, "Village")
	var pav := group(vil, "Pavement")
	pav.set_meta("no_xray", true)
	# --- ворота: бетонная стена по x = 6, проём проспекта, вышки, шлагбаум, будка ---
	# городская стена: кирпич на бутовом цоколе, 5 м, башни; запад и юг — внешние стороны города
	var cw := group(root, "CityWall")
	_city_wall(cw, Vector2(6, -4), Vector2(6, 32), [12.0])
	_city_wall(cw, Vector2(6, 48), Vector2(6, 84), [])
	_city_wall(cw, Vector2(6, 84.6), Vector2(NR + 12, 84.6), [24.0, 54.0])
	put(P.nr_wall_tower, cw, Vector3(6, 0, 34.0), 0.0, "GateTowerN")
	put(P.nr_wall_tower, cw, Vector3(6, 0, 46.0), 0.0, "GateTowerS")
	put(P.nr_wall_tower, cw, Vector3(6, 0, 84.6), 0.0, "CornerTower")
	_city_gate(cw, 6.0, 40.0, 3.8, "НЬЮ-РБА")
	box(vil, Vector3(0.14, 0.14, 6.4), Vector3(9.0, 1.05, 40.0), "paint_white").owner = root
	for i in 4:
		box(vil, Vector3(0.15, 0.15, 0.8), Vector3(9.0, 1.06, 37.2 + i * 1.6), "flag_red").owner = root
	for zz in [36.6, 43.4]:
		cyl(vil, 0.09, 0.09, 1.2, Vector3(9.0, 0.6, zz), "metal_dark").owner = root
	_bld(vil, "checkpoint", "GateBooth", Vector3(12.0, 0, 33.0), PI / 2.0)
	_bld(vil, "sandbags", "Sandbags1", Vector3(10.5, 0, 46.5), PI / 2.0)
	_bld(vil, "sandbags", "Sandbags2", Vector3(10.5, 0, 33.5 - 3.0), PI / 2.0)
	_info_screen(vil, Vector3(13.5, 0, 46.8), PI, "НЬЮ-РБА\nВход: 5 р. с носа\nОружие — в чехол")
	# --- северная сторона проспекта ---
	# высокие дома — на северной стороне улиц (камера смотрит с юга и не теряет улицу за ними)
	# банк в сталинке (квартал 22–40 × 18–36)
	var bank := _bld(vil, "nr_bank", "Bank", Vector3(31.0, 0, 29.0))
	_sign_on(vil, bank, "АЛМАЗНЫЙ БАНК", 5.6, Color("f0d890"))
	# угловая сталинка со шпилем — у перекрёстка, видна от ворот
	var spire := _bld(vil, "nr_stalin_spire", "SpireHouse", Vector3(58.0, 0, 28.6))
	_sign_on(vil, spire, "пр. АЛМАЗНЫЙ, 1", 3.0, Color("d8dce8"))
	var pawn := _bld(vil, "nr_labaz_pawn", "Pawnshop", Vector3(75.5, 0, 31.5))
	_sign_on(vil, pawn, "ЛОМБАРД · СКУПКА", 4.0, Color("e8c060"))
	_neon(pawn, "КУПИМ ВСЁ", Vector3(0, 6.2, 4.1), 0.0, Color("ff5a3a"), 72, true)
	# лавка «Карат» — лицом к переулку z = 16
	var shop := _bld(vil, "nr_labaz", "Shop", Vector3(75.5, 0, 21.5), PI)
	_sign_on(vil, shop, "ЛАВКА «КАРАТ»", 3.4, Color("f0d890"))
	# склады за переулком z = 16 (на север — к Промрайону)
	var wh := _bld(vil, "nr_warehouse_in", "Warehouse1", Vector3(31.0, 0, 7.5))
	_sign_on(vil, wh, "СКЛАД № 3", 2.6, Color("e8e0c8"))
	_bld(vil, "nr_warehouse", "Warehouse2", Vector3(68.0, 0, 7.5))
	_graffiti(vil, "ПАЛЬ", Vector3(42.03, 1.8, 7.5), PI / 2.0)
	# --- южная сторона проспекта ---
	# бар «Забой» (квартал 22–40 × 44–62)
	var bar := _bld(vil, "nr_labaz_bar", "Bar", Vector3(31.0, 0, 49.0), PI)
	_sign_on(vil, bar, "БАР «ЗАБОЙ»", 3.6, Color("ffcf7a"))
	_neon(bar, "ЗАБОЙ", Vector3(0, 4.6, 4.6), 0.0, Color("ffb23a"), 96, true)
	# торговые ряды в одноэтажном лабазе
	var row := _bld(vil, "nr_labaz_row_in", "ShopsRow", Vector3(57.0, 0, 48.5), PI)
	_signboard(vil, "ТОВАРЫ · СОЛЬ · ПАТРОНЫ", _slot(row, "sign"), PI, 5.2, Color("e8d8a8"))
	var lab2 := _bld(vil, "nr_labaz_row2", "Shops2", Vector3(76.5, 0, 49.5), PI)
	_signboard(vil, "ОБМЕН · ВАЛЮТА · ТАЛОНЫ", _slot(lab2, "sign"), PI, 4.6, Color("e8e0c8"))
	# жилые сталинки за переулком z = 64
	var h1 := _bld(vil, "nr_stalin3_in", "House1", Vector3(32.0, 0, 72.0), PI)
	_sign_on(vil, h1, "ул. ШАХТЁРОВ, 4", 2.6, Color("d8dce8"))
	var h2 := _bld(vil, "nr_stalin4b_in", "House2", Vector3(64.0, 0, 73.5), PI)
	_sign_on(vil, h2, "ул. ШАХТЁРОВ, 6", 2.6, Color("d8dce8"))
	# у ворот на юге — барак охраны и гаражи
	_bld(vil, "st_barrack2", "GuardBarrack", Vector3(12.5, 0, 56.0), PI / 2.0)
	_bld(vil, "garages", "Garages", Vector3(12.5, 0, 72.0), PI / 2.0)
	# площадь на перекрёстке: фонтан без воды, скамейки, экран, громкоговоритель
	var fnt := group(vil, "Fountain")
	fnt.position = Vector3(44, 0, 40)
	cyl(fnt, 1.9, 2.0, 0.6, Vector3(0, 0.3, 0), "stone_wall", Vector3.ZERO, 16).owner = root
	cyl(fnt, 1.6, 1.6, 0.05, Vector3(0, 0.6, 0), "coal", Vector3.ZERO, 16).owner = root
	cyl(fnt, 0.3, 0.4, 1.6, Vector3(0, 1.1, 0), "stone_wall", Vector3.ZERO, 10).owner = root
	cyl(fnt, 0.7, 0.4, 0.3, Vector3(0, 2.0, 0), "stone_wall", Vector3.ZERO, 12).owner = root
	_own(collider(fnt, Vector3(3.8, 1.0, 3.8), Vector3(0, 0.5, 0)), root)
	# скамейки: у фонтана, вдоль проспекта, во дворах
	for b in [[Vector3(41.5, 0, 37.4), PI], [Vector3(46.5, 0, 37.4), PI], [Vector3(41.5, 0, 42.6), 0.0], [Vector3(46.5, 0, 42.6), 0.0],
			[Vector3(68.0, 0, 44.6), PI], [Vector3(15.5, 0, 35.6), 0.0], [Vector3(68.5, 0, 35.4), 0.0],
			[Vector3(34.0, 0, 62.6), 0.0], [Vector3(60.0, 0, 62.6), 0.0], [Vector3(56.0, 0, 17.6), PI]]:
		put(P.nr_bench, vil, b[0], b[1])
	_bld(vil, "loudspeaker", "Loudspeaker", Vector3(40.6, 0, 46.5))
	_info_screen(vil, Vector3(39.4, 0, 43.9), PI, "РАДИОЛОТЕРЕЯ\nРозыгрыш — в 20:00\nБилет 2 р.")
	_bld(vil, "bus_stop", "BusStop", Vector3(16.0, 0, 44.8), PI)
	_bld(vil, "kiosk", "Kiosk1", Vector3(14.5, 0, 22.0), PI / 2.0)
	_bld(vil, "kiosk_b", "Kiosk2", Vector3(40.0, 0, 56.5), PI / 2.0)
	# тротуары
	_walk(pav, Rect2(22, 35.6, 18, 1.3))
	_walk(pav, Rect2(48, 35.6, 36, 1.3))
	_walk(pav, Rect2(22, 43.2, 18, 1.3))
	_walk(pav, Rect2(48, 43.2, 36, 1.3))
	_walk(pav, Rect2(39.8, 18, 1.2, 17))
	_walk(pav, Rect2(47.2, 18, 1.2, 17))
	_walk(pav, Rect2(39.8, 45, 1.2, 17))
	_walk(pav, Rect2(47.2, 45, 1.2, 17))
	_walk(pav, Rect2(38, 34, 12, 12))
	# столбы, фонари, теплотрасса, мусор
	_power_line(vil, [Vector3(14, 0, 36.2), Vector3(26, 0, 36.0), Vector3(40, 0, 36.0), Vector3(56, 0, 35.8), Vector3(72, 0, 36.0)])
	for p in [Vector3(18, 0, 44.2), Vector3(30, 0, 36.2), Vector3(52, 0, 44.2), Vector3(70, 0, 44.2), Vector3(40, 0, 26), Vector3(48, 0, 56),
			Vector3(48, 0, 24), Vector3(26, 0, 64.0 + 2.4)]:
		_lamp_post(vil, p)
	_pipes(vil, "high", Vector3(50.0, 0, 13.6), Vector3(82.0, 0, 13.6))
	_pipes(vil, "low", Vector3(23.0, 0, 61.5), Vector3(39.0, 0, 61.5))
	_clutter(vil, [["burn_barrel", 25.0, 58.0], ["burn_barrel", 16.0, 26.0], ["burn_barrel", 52.0, 60.5],
		["trash_pile", 37.5, 58.5], ["trash_pile_b", 23.5, 25.0], ["trash_pile", 80.0, 60.0], ["rubble", 70.0, 58.0],
		["car_wreck", 46.0, 74.0, 1.2], ["car_wreck", 81.5, 3.0, 0.3], ["paz_wreck", 80.0, 71.0, PI / 2.0], ["bins", 50.5, 20.0, PI / 2.0]])
	_broken_road(Vector2(8, 40), Vector2(NR, 40), 3.2, 24)
	var trash := group(vil, "Trash")
	for j in [["nr_junk_bags", Vector3(28.5, 0, 59.8), 0.3], ["nr_dumpster", Vector3(36.6, 0, 60.4), PI], ["nr_junk_furniture", Vector3(22.5, 0, 55.5), 1.0],
			["nr_junk_scrap", Vector3(17.0, 0, 30.5), 0.4], ["nr_junk_tires", Vector3(14.5, 0, 63.0), 0.0], ["nr_dumpster", Vector3(50.5, 0, 22.5), PI / 2.0],
			["nr_junk_bags", Vector3(66.5, 0, 59.5), 2.0], ["nr_junk_scrap", Vector3(78.0, 0, 13.0), 0.8], ["nr_junk_furniture", Vector3(46.5, 0, 66.5), 2.4],
			["nr_dumpster", Vector3(71.0, 0, 61.5), 0.0], ["nr_junk_bags", Vector3(42.0, 0, 13.5), 1.4], ["nr_junk_tires", Vector3(81.5, 0, 34.0), 0.0],
			["trash_pile", Vector3(38.0, 0, 58.0), 0.0], ["trash_pile_b", Vector3(23.0, 0, 25.0), 0.0], ["nr_junk_bags", Vector3(10.0, 0, 76.0), 0.5]]:
		_junk(trash, j[0], j[1], j[2])
	# канализация: люки на проспекте и улицах, решётки ливнёвки у бордюров; открытый люк — во дворе за баром
	var sew := group(vil, "Sewer")
	sew.set_meta("no_xray", true)
	for m in [Vector3(30.0, 0, 40.0), Vector3(60.0, 0, 39.5), Vector3(44.0, 0, 26.0), Vector3(44.0, 0, 54.0), Vector3(74.0, 0, 40.5), Vector3(20.0, 0, 50.0)]:
		put(P.nr_manhole, sew, m, randf() * TAU)
	put(P.nr_manhole_open, sew, Vector3(26.5, 0, 61.5), 0.0, "HatchOpen")
	for dr in [Vector3(26.0, 0, 36.6), Vector3(52.0, 0, 36.6), Vector3(36.0, 0, 43.4), Vector3(64.0, 0, 43.4), Vector3(40.6, 0, 30.0), Vector3(47.4, 0, 50.0)]:
		put(P.nr_drain, sew, dr, 0.0 if absf(dr.z - 40.0) < 5.0 else PI / 2.0)
	_graffiti(vil, "АПОВИЧ — ВОР", Vector3(22.97, 1.6, 29.0), -PI / 2.0)
	_graffiti(vil, "ЗАБОЙ — НАШ", Vector3(23.97, 1.5, 49.0), -PI / 2.0, Color("1c1c1c"))
	var det := group(root, "Yard")
	for dd in [["crates", Vector3(26, 0, 59)], ["crates", Vector3(36, 0, 57.5)], ["barrel", Vector3(54, 0, 59)],
			["crates", Vector3(68, 0, 36.6 - 2.0)], ["barrel", Vector3(62, 0, 21.5)], ["crates", Vector3(16, 0, 20)]]:
		put(P[dd[0]], det, dd[1], randf() * TAU)
	_edges(rect, [["E", 40.0]], [])
	_no_edge.append(Rect2(-10, NR - 2, NR + 40, 30))
	# город за северным краем (Промрайон): склады и трубы
	var far := group(root, "FarNorth")
	far.set_meta("no_xray", true)
	for i in 4:
		put(P.nr_warehouse if i % 2 == 0 else P.st_barrack2, far, Vector3(14.0 + i * 22.0 + (8.0 if i >= 2 else 0.0), 0, -14.0), 0.0)
	put(P.boiler_house, far, Vector3(58, 0, -30), 0.0)
	_woods(40)
	# --- люди ---
	var chars := group(root, "Characters")
	_place_sentries(chars)
	character(chars, "GateGuard1", "nr_guard", Vector3(10.4, 0, 37.0), -PI / 2.0, {"display_name": "Охранник ворот", "armed": true})
	character(chars, "GateGuard2", "nr_guard", Vector3(10.4, 0, 43.4), -PI / 2.0, {"display_name": "Охранник ворот", "armed": true})
	character(chars, "TollMan", "town_m2", Vector3(13.6, 0, 35.6), -PI / 2.0, {"display_name": "Сборщик пошлины"})
	# банк
	character(chars, "Teller", "nr_teller", _slot(bank, "teller"), 0.0, {"display_name": "Кассирша Алмазного банка"})
	character(chars, "Teller2", "town_f2", _slot(bank, "teller2"), 0.0, {"display_name": "Кассирша"})
	character(chars, "BankGuard", "nr_guard", _slot(bank, "guard"), PI, {"display_name": "Охранник банка", "armed": true})
	character(chars, "BankClient", "town_m2", _slot(bank, "client"), PI, {"display_name": "Посетитель в пальто"})
	character(chars, "BankDoorGuard", "nr_guard", Vector3(33.4, 0, 35.4), 0.0, {"display_name": "Охранник у банка", "armed": true})
	# ломбард, лавки
	character(chars, "Pawnbroker", "nr_pawn", _slot(pawn, "seller"), 0.0, {"display_name": "Оценщик Семён Маркович"})
	character(chars, "Shopkeeper", "nr_shop", _slot(shop, "seller"), PI, {"display_name": "Лавочница Туяра"})
	character(chars, "ShopBuyer", "town_old_f", _slot(shop, "buyer"), 0.0, {"display_name": "Покупательница"})
	character(chars, "RowSeller1", "villager", Vector3(52.0, 0, 43.4), PI, {"display_name": "Торговец с лотка"})
	character(chars, "Changer", "town_m4", Vector3(76.5, 0, 44.2), PI, {"display_name": "Меняла"})
	# бар «Забой»
	character(chars, "Barman", "nr_barman", _slot(bar, "barman"), PI / 2.0, {"display_name": "Бармен Жора"})
	character(chars, "Drinker1", "town_worker", _slot(bar, "t1"), PI, {"display_name": "Шахтёр после смены"})
	character(chars, "Drinker2", "town_m4", _slot(bar, "t2"), PI, {"display_name": "Пьёт в долг"})
	character(chars, "Drinker3", "nr_bandit", _slot(bar, "t3"), PI, {"display_name": "Хмурый в кепке"})
	# жильцы сталинок, торговцы в рядах, кладовщик на складе
	character(chars, "H1Old", "town_old_f", _slot(h1, "flatL"), 0.0, {"display_name": "Старуха с первого этажа"})
	character(chars, "H1Kid", "kid", _slot(h1, "flatR"), PI, {"display_name": "Девочка у плиты"})
	character(chars, "H2Man", "town_worker", _slot(h2, "flatL"), 0.0, {"display_name": "Шахтёр после ночной"})
	character(chars, "H2Wife", "town_f3", _slot(h2, "flatR"), PI, {"display_name": "Жена шахтёра"})
	character(chars, "RowIn1", "villager", _slot(row, "seller"), 0.0, {"display_name": "Торговец солью"})
	character(chars, "RowIn2", "villager_f", _slot(row, "seller2"), 0.0, {"display_name": "Торговка патронами"})
	character(chars, "Storekeeper", "town_m4", _slot(wh, "keeper"), 0.0, {"display_name": "Кладовщик склада № 3"})
	character(chars, "Porter", "town_worker", _slot(wh, "porter"), 1.2, {"display_name": "Грузчик"})
	# бичи у бочек
	character(chars, "Bum1", "nr_bum", Vector3(25.8, 0, 59.2), -2.4, {"display_name": "Бич у бочки"})
	character(chars, "Bum2", "nr_bum", Vector3(24.0, 0, 57.4), 0.8, {"display_name": "Бич", "start_pose": "sit"})
	character(chars, "Bum3", "nr_bum", Vector3(16.8, 0, 27.2), PI, {"display_name": "Бич с гармошкой", "start_pose": "sit"})
	character(chars, "Bum4", "nr_bum", Vector3(53.0, 0, 61.6), PI, {"display_name": "Спит у трубы", "start_pose": "sleep"})
	character(chars, "Beggar", "town_old_m", Vector3(41.0, 0, 44.6), PI, {"display_name": "Просит у фонтана", "start_pose": "sit"})
	# банда «забойских» во дворе за баром — смотрят, кто пришёл
	character(chars, "Gang1", "nr_bandit", Vector3(30.0, 0, 57.8), PI, {"display_name": "Забойский"})
	character(chars, "Gang2", "nr_bandit_b", Vector3(33.0, 0, 58.6), -2.6, {"display_name": "Забойский с трубой"})
	character(chars, "Gang3", "nr_bandit", Vector3(31.2, 0, 60.2), 0.2, {"display_name": "Главный забойский"})
	# прохожие и патруль
	character(chars, "Walker1", "town_f1", Vector3(30, 0, 39.0), PI / 2.0, {"display_name": "Горожанка",
		"patrol": PackedVector3Array([Vector3(30, 0, 39.0), Vector3(70, 0, 38.0), Vector3(46, 0, 30)]), "patrol_wait": 5.0})
	character(chars, "Walker2", "town_m1", Vector3(62, 0, 42.0), -PI / 2.0, {"display_name": "Горожанин",
		"patrol": PackedVector3Array([Vector3(62, 0, 42.0), Vector3(22, 0, 41.5), Vector3(44, 0, 58)]), "patrol_wait": 6.0})
	character(chars, "Walker3", "town_m3", Vector3(45.5, 0, 20.0), 0.0, {"display_name": "Прохожий",
		"patrol": PackedVector3Array([Vector3(45.5, 0, 20.0), Vector3(45.5, 0, 60.0), Vector3(60, 0, 64)]), "patrol_wait": 4.0})
	character(chars, "Walker4", "town_worker", Vector3(44.5, 0, 4.0), 0.0, {"display_name": "Рабочий с промзоны",
		"patrol": PackedVector3Array([Vector3(44.5, 0, 4.0), Vector3(43.5, 0, 38.0), Vector3(30, 0, 16.0)]), "patrol_wait": 5.0})
	character(chars, "Kid1", "kid", Vector3(42.0, 0, 37.5), 1.0, {"display_name": "Мальчишка-газетчик",
		"patrol": PackedVector3Array([Vector3(42.0, 0, 37.5), Vector3(20, 0, 41.0), Vector3(66, 0, 37.5)]), "patrol_wait": 3.0})
	character(chars, "Patrol1", "nr_guard", Vector3(24, 0, 41.0), PI / 2.0, {"display_name": "Патруль охраны", "armed": true,
		"patrol": PackedVector3Array([Vector3(24, 0, 41.0), Vector3(78, 0, 41.0), Vector3(44.5, 0, 62.0), Vector3(44.5, 0, 18.0)]), "patrol_wait": 4.0})
	# --- выходы, точки ---
	var items := group(root, "Items")
	_exit(items, "ToCenter", "В Центр", Vector3(NR - 1.0, 0, 40.0), Vector3(1.6, 2.2, 5.0))
	_exit(items, "ToProm", "В Промрайон", Vector3(44.0, 0, 1.0), Vector3(5.0, 2.2, 1.6))
	_exit(items, "ToRoad", "Из города — на тракт", Vector3(3.0, 0, 40.0), Vector3(1.6, 2.2, 5.0))
	_junk_items(items)
	_use(items, "Hatch", "Открытый люк", Vector3(26.5, 0, 61.5), Vector3(1.2, 0.6, 1.2))
	_use(items, "Fountain", "Сухой фонтан", Vector3(44, 0, 42.2), Vector3(3.6, 2.4, 1.2))
	_use(items, "InfoScreen", "Экран у ворот", Vector3(13.5, 0, 46.3), Vector3(1.4, 3.6, 0.6))
	_spawn("Start", Vector3(2.5 + 2.0, 0, 40.0))
	_spawn("Road", Vector3(2.5 + 2.0, 0, 40.0))
	_spawn("FromCenter", Vector3(NR - 4.5, 0, 41.5))
	_spawn("FromProm", Vector3(45.5, 0, 4.5))
	_spawn("FromSewer", Vector3(27.8, 0, 60.4))
	marker(root, "MarkGate", Vector3(10, 0, 40), "Ворота")
	marker(root, "MarkBank", Vector3(31, 0, 29), "Алмазный банк")
	marker(root, "MarkPawn", Vector3(75.5, 0, 31.5), "Ломбард")
	marker(root, "MarkBar", Vector3(31, 0, 49), "Бар «Забой»")
	marker(root, "MarkShop", Vector3(75.5, 0, 21.5), "Лавка «Карат»")
	marker(root, "MarkSpire", Vector3(58, 0, 28.6), "Дом со шпилем")
	marker(root, "MarkWarehouses", Vector3(50, 0, 7.5), "Склады")
	_dress(Rect2(8, 2, 74, 78), 260)
	_clear_town(Rect2(7, 1, 76, 80))
	_finish("nyurba")


# ======================================================================
# КАНАЛИЗАЦИЯ — коллектор под Проходом: из люка во дворе бара вниз; на той стороне —
# скобы наверх в Чёрный район. В камере живут бичи, в насосной — чья-то заначка.
# ======================================================================
func _sewer() -> void:
	var rect := Rect2(0, 0, 56, 28)
	seed(5501)
	root = Node3D.new()
	root.name = "NyurbaSewer"
	root.set_script(load("res://scripts/locations/nyurba_sewer.gd"))
	root.set("location_id", "nyurba_sewer")
	root.set("title", "Нью-Рба · коллектор")
	root.set("map_rect", rect)
	root.set("camera_start", Vector3(10, 0, 5))
	var plain := func(c: String, rough: float, metal := 0.0) -> StandardMaterial3D:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(c)
		m.roughness = rough
		m.metallic = metal
		return m
	M["sw_floor"] = plain.call("34322c", 0.9)
	M["sw_wall"] = plain.call("5a564a", 0.95)
	M["sw_slime"] = plain.call("3e4a2c", 0.6)
	M["sw_water"] = plain.call("1c2420", 0.05, 0.3)
	_dark_env(Color("3a3a32"), 0.5)
	var v := group(root, "Village")
	_floor(v, rect.grow(0.3), "sw_floor")
	var main_t := Rect2(2, 11, 52, 6)
	var north := Rect2(8, 1, 4, 10)
	var chamber := Rect2(24, 2, 12, 9)
	var south := Rect2(44, 17, 4, 10)
	var pump := Rect2(17, 17, 12, 8)
	_room_walls(v, main_t, 1.4, "sw_wall", [[Vector2(10, 11), 4.0], [Vector2(30, 11), 4.0], [Vector2(46, 17), 4.0], [Vector2(23, 17), 3.0]])
	_room_walls(v, north, 1.4, "sw_wall", [[Vector2(10, 11), 4.0]])
	_room_walls(v, chamber, 1.4, "sw_wall", [[Vector2(30, 11), 4.0]])
	_room_walls(v, south, 1.4, "sw_wall", [[Vector2(46, 17), 4.0]])
	_room_walls(v, pump, 1.4, "sw_wall", [[Vector2(23, 17), 3.0]])
	# сток посередине коллектора: тёмная вода между бетонными бортиками, слизь по краям
	box(v, Vector3(52, 0.02, 1.5), Vector3(28, 0.03, 14), "sw_water").owner = root
	for zz in [13.2, 14.8]:
		box(v, Vector3(52, 0.08, 0.14), Vector3(28, 0.04, zz), "concrete").owner = root
		box(v, Vector3(52, 0.03, 0.3), Vector3(28, 0.02, zz + (0.25 if zz > 14 else -0.25)), "sw_slime").owner = root
	# трубы вдоль стен, вентили, потёки
	for zz in [11.35, 16.65]:
		cyl(v, 0.16, 0.16, 52, Vector3(28, 0.9, zz), "rust", Vector3(0, 0, PI / 2.0), 8).owner = root
		for x in [8.0, 20.0, 34.0, 50.0]:
			cyl(v, 0.22, 0.22, 0.12, Vector3(x, 0.9, zz), "metal_dark", Vector3(0, 0, PI / 2.0), 10).owner = root
	for x in [5.0, 16.0, 27.0, 39.0, 52.0]:
		box(v, Vector3(0.6, 1.2, 0.02), Vector3(x, 0.7, 11.03), "sw_slime").owner = root
	# скобы-лестницы наверх
	for pt in [[Vector3(10, 0, 1.1), 0.0], [Vector3(46, 0, 26.9), PI]]:
		for k in 6:
			box(v, Vector3(0.5, 0.04, 0.12), pt[0] + Vector3(0, 0.25 + k * 0.22, 0.1 if pt[1] == 0.0 else -0.1), "rust").owner = root
		var l := _lamp(v, "Shaft", pt[0] + Vector3(0, 2.6, 0.6 if pt[1] == 0.0 else -0.6), Color("c8d8ff"), 1.4, 5.0)
		l.shadow_enabled = false
	# камера бичей: бочка с огнём, матрасы, тряпьё, верёвка с бельём
	put(P.burn_barrel, v, Vector3(30, 0, 6.5), 0.0)
	for m in [[Vector3(26.2, 0, 3.6), 0.2], [Vector3(33.8, 0, 3.6), -0.1], [Vector3(26.0, 0, 8.8), 1.4]]:
		box(v, Vector3(1.9, 0.18, 0.9), m[0] + Vector3(0, 0.09, 0), "cloth_sack", Vector3(0, m[1], 0)).owner = root
	box(v, Vector3(1.0, 0.6, 0.6), Vector3(34.6, 0.3, 8.6), "planks_old").owner = root
	_own(collider(v, Vector3(1.0, 0.6, 0.6), Vector3(34.6, 0.3, 8.6)), root)
	box(v, Vector3(7.0, 0.02, 0.02), Vector3(30, 1.3, 2.4), "rope_mat").owner = root
	for i in 4:
		box(v, Vector3(0.4, 0.5, 0.02), Vector3(27.5 + i * 1.6, 1.05, 2.4), ["cloth_red", "paper", "cloth_sack", "cloth_red"][i]).owner = root
	_lamp(v, "Fire", Vector3(30, 1.4, 6.5), Color("ff9a4a"), 1.6, 7.5)
	# насосная: два мёртвых насоса, щит, вентиль
	for x in [20.0, 25.5]:
		box(v, Vector3(2.0, 1.2, 1.4), Vector3(x, 0.6, 22.5), "metal_dark").owner = root
		cyl(v, 0.35, 0.35, 1.6, Vector3(x, 0.7, 21.2), "rust", Vector3(PI / 2.0, 0, 0), 10).owner = root
		_own(collider(v, Vector3(2.0, 1.2, 1.4), Vector3(x, 0.6, 22.5)), root)
	box(v, Vector3(1.4, 1.0, 0.15), Vector3(28.5, 1.0, 20.0), "paint_green").owner = root
	cyl(v, 0.3, 0.3, 0.06, Vector3(18.2, 0.9, 18.2), "paint_red", Vector3(PI / 2.0, 0, 0), 12).owner = root
	# тусклые лампы в коллекторе: часть не горит
	var lamps := group(v, "Lamps")
	for x in [6.0, 18.0, 30.0, 42.0, 52.0]:
		if x != 42.0:
			_lamp(lamps, "Lamp", Vector3(x, 2.2, 14), Color("e8d49a"), 1.4, 8.0).shadow_enabled = false
		box(lamps, Vector3(0.3, 0.12, 0.3), Vector3(x, 1.45, 11.3), "glass").owner = root
	_lamp(lamps, "Pump", Vector3(23, 2.2, 21), Color("e8d49a"), 0.7, 6.0).shadow_enabled = false
	# мусор (можно порыться)
	var trash := group(v, "Trash")
	_junk(trash, "nr_junk_bags", Vector3(34.0, 0, 3.8), 0.4)
	_junk(trash, "nr_junk_scrap", Vector3(27.0, 0, 23.6), 1.0)
	_junk(trash, "nr_junk_furniture", Vector3(52.0, 0, 15.6), 0.2)
	_junk(trash, "nr_junk_tires", Vector3(4.2, 0, 15.6), 0.0)
	# люди
	var chars := group(root, "Characters")
	character(chars, "SewerKing", "town_old_m", Vector3(30.0, 0, 4.4), PI, {"display_name": "Дед Хабаров, «хозяин» коллектора", "start_pose": "sit"})
	character(chars, "SewerBum1", "nr_bum", Vector3(28.4, 0, 6.8), 1.6, {"display_name": "Бич у огня"})
	character(chars, "SewerBum2", "nr_bum", Vector3(26.2, 0, 8.8), 1.4, {"display_name": "Спит на матрасе", "start_pose": "sleep"})
	character(chars, "SewerBum3", "nr_bum", Vector3(32.2, 0, 7.4), -1.8, {"display_name": "Бич с кружкой", "start_pose": "sit"})
	character(chars, "PumpMan", "town_worker", Vector3(23.0, 0, 19.6), PI, {"display_name": "Слесарь водоканала"})
	var items := group(root, "Items")
	_junk_items(items)
	_use(items, "UpProxod", "Скобы наверх — в Проход", Vector3(10, 0, 1.8), Vector3(1.2, 2.4, 1.0))
	_use(items, "UpBlack", "Скобы наверх — в Чёрный район", Vector3(46, 0, 26.2), Vector3(1.2, 2.4, 1.0))
	_use(items, "Valve", "Вентиль", Vector3(18.4, 0, 18.4), Vector3(0.8, 1.4, 0.8))
	_use(items, "Pumps", "Насосы", Vector3(22.8, 0, 22.5), Vector3(7.0, 1.4, 1.6))
	_spawn("Start", Vector3(10, 0, 4.0))
	_spawn("FromProxod", Vector3(10, 0, 4.0))
	_spawn("FromBlack", Vector3(46, 0, 24.0))
	marker(root, "MarkCamp", Vector3(30, 0, 6), "Стоянка бичей")
	marker(root, "MarkPump", Vector3(23, 0, 21), "Насосная")
	_finish("nyurba_sewer")


# ---------------- общее для районов: сетка улиц, земля, стены ----------------
## Улицы как в Проходе: проспект z = 40, улица x = 44, переулки z = 16 и z = 64, x = 20
func _grid_streets(id: String, open_w: bool, open_e: bool) -> void:
	var d := "ground_dirt"
	strip(null, Vector2(-8, 40), Vector2(NR + 8, 40), AVE_W, d)
	strip(null, Vector2(44, -8), Vector2(44, NR + 8), AVE_W, d)
	for seg in [[Vector2(14, 16), Vector2(NR - 6, 16)], [Vector2(14, 64), Vector2(NR - 6, 64)], [Vector2(20, 12), Vector2(20, 68)], [Vector2(68, 12), Vector2(68, 68)]]:
		strip(null, seg[0], seg[1], LANE_W, d)
		road_segs.append([seg[0], seg[1], 1.8])
	if open_w:
		_street_out(Vector2(0, 40), -1.0)
	if open_e:
		_street_out(Vector2(NR, 40), 1.0)
	road_segs.append([Vector2(-8, 40), Vector2(NR + 8, 40), 3.3])
	road_segs.append([Vector2(44, -8), Vector2(44, NR + 8), 3.3])
	road_segs.append([Vector2(39, 35), Vector2(49, 45), 6.0])
	_clear.append(Rect2(-8, -8, NR + 16, NR + 16))


## Тротуары вдоль проспекта и улицы
func _walks(pav: Node) -> void:
	for r in [Rect2(8, 35.6, 32, 1.3), Rect2(48, 35.6, 34, 1.3), Rect2(8, 43.2, 32, 1.3), Rect2(48, 43.2, 34, 1.3),
			Rect2(39.8, 4, 1.2, 31), Rect2(47.2, 4, 1.2, 31), Rect2(39.8, 45, 1.2, 33), Rect2(47.2, 45, 1.2, 33)]:
		_walk(pav, r)


## Фонари, столбы, люки, ливнёвки — у всех районов похоже
func _street_dress(vil: Node, sew_open := Vector3.INF) -> void:
	_power_line(vil, [Vector3(10, 0, 36.2), Vector3(26, 0, 36.0), Vector3(40, 0, 36.0), Vector3(56, 0, 35.8), Vector3(72, 0, 36.0)])
	for p in [Vector3(18, 0, 44.2), Vector3(30, 0, 36.2), Vector3(52, 0, 44.2), Vector3(70, 0, 44.2), Vector3(40, 0, 26), Vector3(48, 0, 56)]:
		_lamp_post(vil, p)
	var sew := group(vil, "Sewer")
	sew.set_meta("no_xray", true)
	for m in [Vector3(30.0, 0, 40.0), Vector3(60.0, 0, 39.5), Vector3(44.0, 0, 26.0), Vector3(44.0, 0, 56.0)]:
		put(P.nr_manhole, sew, m, randf() * TAU)
	if sew_open != Vector3.INF:
		put(P.nr_manhole_open, sew, sew_open, 0.0, "HatchOpen")
	for dr in [Vector3(26.0, 0, 36.6), Vector3(58.0, 0, 36.6), Vector3(36.0, 0, 43.4), Vector3(64.0, 0, 43.4)]:
		put(P.nr_drain, sew, dr, 0.0)


# ======================================================================
# ЦЕНТР — верхушка города грехов: Дом правительства (палаты президента, кабинет
# казначея), казино в бывшем ДК, гостиница, казармы, арена кулачных боёв,
# салон «Бархат», ювелирный; радиолотерея на площади у «Первого алмаза»
# ======================================================================
func _center() -> void:
	var rect := Rect2(0, 0, NR, NR)
	_begin("nyurba_center", "Нью-Рба · Центр", rect, "res://scripts/locations/nyurba_center.gd")
	_grid_streets("nyurba_center", true, false)
	_no_edge.append(Rect2(-60, -60, NR + 120, 60))
	_no_edge.append(Rect2(-60, -10, 60, NR + 20))
	_ground_for("nyurba_center")
	var vil := group(root, "Village")
	var pav := group(vil, "Pavement")
	pav.set_meta("no_xray", true)
	_walks(pav)
	_walk(pav, Rect2(36, 32, 16, 16))
	# стена: восток и юг — край города
	var cw := group(root, "CityWall")
	_city_wall(cw, Vector2(NR + 0.6, -12), Vector2(NR + 0.6, NR + 0.6), [20.0, 62.0])
	_city_wall(cw, Vector2(-12, NR + 0.6), Vector2(NR + 0.6, NR + 0.6), [30.0, 66.0])
	put(P.nr_wall_tower, cw, Vector3(NR + 0.6, 0, NR + 0.6), 0.0, "CornerTower")
	# север проспекта: казино и Дом правительства — высокие, на северной стороне
	var cas := _bld(vil, "nr_casino", "Casino", Vector3(30.0, 0, 28.0))
	_sign_on(vil, cas, "КАЗИНО «СЕВЕРНОЕ СИЯНИЕ»", 6.4, Color("ffcf7a"))
	_neon(cas, "КАЗИНО", Vector3(0, 6.6, 6.1), 0.0, Color("ff3aa0"), 110, true)
	var gov := _bld(vil, "nr_gov", "GovHouse", Vector3(62.0, 0, 28.0))
	_sign_on(vil, gov, "ДОМ ПРАВИТЕЛЬСТВА НЬЮ-РБЫ", 6.8, Color("f0d890"))
	# за переулком z = 16: гостиница и казармы
	var hotel := _bld(vil, "nr_hotel", "Hotel", Vector3(30.0, 0, 7.5))
	_sign_on(vil, hotel, "ГОСТИНИЦА «АЛМАЗ»", 4.6, Color("f0d890"))
	var bar := _bld(vil, "nr_barracks", "Barracks", Vector3(60.0, 0, 7.5))
	_sign_on(vil, bar, "КАЗАРМЫ ОХРАНЫ", 3.8, Color("d8e0f0"))
	# юг проспекта: арена (открытая), салон «Бархат», ювелирный
	var arena := group(vil, "Arena")
	arena.position = Vector3(30, 0, 53)
	box(arena, Vector3(9.0, 0.3, 9.0), Vector3(0, 0.15, 0), "planks_old").owner = root
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			cyl(arena, 0.12, 0.12, 1.6, Vector3(sx * 4.3, 0.8, sz * 4.3), "paint_red").owner = root
	for k in 3:
		for side in 4:
			var horiz := side < 2
			var off := -4.3 if side % 2 == 0 else 4.3
			box(arena, Vector3(8.6, 0.04, 0.04) if horiz else Vector3(0.04, 0.04, 8.6),
				Vector3(0, 0.6 + k * 0.4, off) if horiz else Vector3(off, 0.6 + k * 0.4, 0), "cloth_red").owner = root
	_own(collider(arena, Vector3(9.0, 0.3, 9.0), Vector3(0, 0.15, 0)), root)
	for b in [[Vector3(22.5, 0, 53), PI / 2.0], [Vector3(37.5, 0, 53), -PI / 2.0], [Vector3(30, 0, 60.5), PI]]:
		put(P.nr_bench, vil, b[0], b[1])
	_signboard(vil, "АРЕНА · БОИ ПО СУББОТАМ", Vector3(30, 2.6, 46.8), PI, 4.4, Color("ffcf7a"))
	var salon := _bld(vil, "nr_labaz_row2", "Salon", Vector3(58.0, 0, 49.5), PI)
	_signboard(vil, "САЛОН «БАРХАТ»", _slot(salon, "sign"), PI, 3.6, Color("ff7ab0"))
	_neon(salon, "♥", Vector3(0, 4.6, 4.1), 0.0, Color("ff3a7a"), 120, true)
	var jew := _bld(vil, "nr_labaz", "Jeweler", Vector3(76.0, 0, 49.5), PI)
	_sign_on(vil, jew, "ЮВЕЛИРНЫЙ «БРИЛЛИАНТ»", 4.2, Color("e8f0ff"))
	# за переулком z = 64: дома побогаче
	_bld(vil, "nr_stalin4", "House1", Vector3(30.0, 0, 74.0), PI)
	_bld(vil, "nr_stalin3", "House2", Vector3(62.0, 0, 73.5), PI)
	# площадь: памятник «Первому алмазу», радиолотерея, скамейки
	var mon := group(vil, "Monument")
	mon.position = Vector3(44, 0, 40)
	box(mon, Vector3(2.4, 1.2, 2.4), Vector3(0, 0.6, 0), "stone_wall").owner = root
	box(mon, Vector3(1.8, 0.3, 1.8), Vector3(0, 1.35, 0), "plaster_white").owner = root
	prism(mon, Vector3(1.4, 1.4, 1.4), Vector3(0, 2.2, 0), "glass").owner = root
	prism(mon, Vector3(1.4, 1.0, 1.4), Vector3(0, 1.0 + 0.5, 0), "glass", Vector3(PI, 0, 0)).owner = root
	_own(collider(mon, Vector3(2.4, 2.6, 2.4), Vector3(0, 1.3, 0)), root)
	for b in [[Vector3(40.5, 0, 36.8), PI], [Vector3(47.5, 0, 36.8), PI], [Vector3(40.5, 0, 43.2), 0.0], [Vector3(47.5, 0, 43.2), 0.0],
			[Vector3(14.0, 0, 44.6), PI], [Vector3(66.5, 0, 44.6), PI], [Vector3(14.0, 0, 35.4), 0.0]]:
		put(P.nr_bench, vil, b[0], b[1])
	_bld(vil, "loudspeaker", "Loudspeaker", Vector3(48.8, 0, 46.0))
	_info_screen(vil, Vector3(39.2, 0, 46.2), PI, "РАДИОЛОТЕРЕЯ «АЛМАЗ»\nСегодня в 20:00\nДжекпот: 500 р.")
	_street_dress(vil)
	var trash := group(vil, "Trash")
	for j in [["nr_dumpster", Vector3(17.0, 0, 22.0), PI / 2.0], ["nr_junk_bags", Vector3(76.0, 0, 21.5), 0.4], ["nr_dumpster", Vector3(48.5, 0, 61.0), 0.0],
			["nr_junk_furniture", Vector3(16.0, 0, 70.0), 1.0]]:
		_junk(trash, j[0], j[1], j[2])
	_clutter(vil, [["car_wreck", 10.0, 50.0, 0.2], ["burn_barrel", 78.0, 60.0], ["trash_pile", 15.5, 60.0]])
	_edges(rect, [["W", 40.0]], [])
	var far := group(root, "FarNorth")
	far.set_meta("no_xray", true)
	for i in 3:
		put(P.nr_shack if i % 2 == 0 else P.st_barrack2, far, Vector3(16.0 + i * 26.0, 0, -12.0), 0.0)
	_woods(30)
	# --- люди ---
	var chars := group(root, "Characters")
	character(chars, "Artur", "nr_artur", _slot(gov, "artur"), 0.0, {"dialog": "nr_artur"})
	character(chars, "Garik", "nr_garik", _slot(gov, "garik"), PI / 2.0, {"dialog": "nr_garik"})
	character(chars, "Apovich", "nr_apovich", _slot(gov, "apovich"), 0.0, {"dialog": "nr_apovich"})
	character(chars, "Secretary", "town_f2", _slot(gov, "secretary"), PI / 2.0, {"display_name": "Секретарша президента"})
	character(chars, "GovGuard1", "nr_guard", _slot(gov, "guard"), PI, {"display_name": "Охрана Дома правительства", "armed": true})
	character(chars, "GovGuard2", "nr_guard", _slot(gov, "guard2"), 0.0, {"display_name": "Охрана палат", "armed": true})
	character(chars, "GovDoor1", "nr_guard", Vector3(58.5, 0, 35.2), 0.0, {"display_name": "Часовой у входа", "armed": true})
	character(chars, "GovDoor2", "nr_guard", Vector3(65.5, 0, 35.2), 0.0, {"display_name": "Часовой у входа", "armed": true})
	character(chars, "Croupier1", "nr_croupier", _slot(cas, "croupier1"), 0.0, {"display_name": "Крупье"})
	character(chars, "Croupier2", "nr_croupier", _slot(cas, "croupier2"), 0.0, {"display_name": "Крупье"})
	character(chars, "Player1", "nr_rich", _slot(cas, "player1"), PI, {"display_name": "Игрок в дорогом пальто"})
	character(chars, "Player2", "town_worker", _slot(cas, "player1a"), PI, {"display_name": "Шахтёр с получкой"})
	character(chars, "Player3", "town_f1", _slot(cas, "player2"), PI, {"display_name": "Игрок"})
	character(chars, "SlotPlayer", "town_old_m", _slot(cas, "slot1"), PI, {"display_name": "Старик у автомата"})
	character(chars, "SlotPlayer2", "nr_bum", _slot(cas, "slot2"), PI, {"display_name": "Проигрался в ноль"})
	character(chars, "Singer", "nr_singer", _slot(cas, "singer"), PI, {"display_name": "Певица Сардана"})
	character(chars, "CasinoBar", "nr_barman", _slot(cas, "barman"), -PI / 2.0, {"display_name": "Бармен казино"})
	character(chars, "Bouncer", "nr_guard", _slot(cas, "bouncer"), PI, {"display_name": "Вышибала", "armed": true})
	character(chars, "HotelKeeper", "town_f3", _slot(hotel, "keeper"), PI / 2.0, {"display_name": "Портье «Алмаза»"})
	character(chars, "HotelGuest", "nr_rich", _slot(hotel, "sofa"), PI, {"display_name": "Приезжий с востока", "start_pose": "sit"})
	character(chars, "BarrChief", "nr_guard", _slot(bar, "chief"), PI / 2.0, {"display_name": "Начальник охраны", "armed": true})
	character(chars, "BarrCop", "nr_guard", _slot(bar, "cop"), PI, {"display_name": "Дежурный", "armed": true})
	character(chars, "Fighter1", "nr_bandit_b", Vector3(28.5, 0.3, 52.0), PI / 2.0, {"display_name": "Боец в красном углу"})
	character(chars, "Fighter2", "town_worker", Vector3(31.5, 0.3, 54.0), -PI / 2.0, {"display_name": "Боец в синем углу"})
	character(chars, "Promoter", "nr_rich", Vector3(35.6, 0, 47.4), PI, {"display_name": "Устроитель боёв"})
	character(chars, "Crowd1", "town_m1", Vector3(23.4, 0, 49.4), PI / 2.0, {"display_name": "Зевака"})
	character(chars, "Crowd2", "town_m4", Vector3(36.6, 0, 56.6), -PI / 2.0, {"display_name": "Делает ставку"})
	character(chars, "Crowd3", "town_f2", Vector3(30.0, 0, 59.0), PI, {"display_name": "Зрительница", "start_pose": "sit"})
	character(chars, "SalonDoor", "nr_bandit", Vector3(58.0, 0, 44.6), PI, {"display_name": "Швейцар «Бархата»"})
	character(chars, "SalonGirl", "nr_singer", Vector3(55.6, 0, 44.4), PI, {"display_name": "Девушка у «Бархата»"})
	character(chars, "Jeweler", "nr_pawn", _slot(jew, "seller"), 0.0, {"display_name": "Ювелир Изя"})
	character(chars, "RichWalker1", "nr_rich", Vector3(30, 0, 39.0), PI / 2.0, {"display_name": "Господин в шубе",
		"patrol": PackedVector3Array([Vector3(30, 0, 39.0), Vector3(70, 0, 38.0), Vector3(44, 0, 30)]), "patrol_wait": 5.0})
	character(chars, "RichWalker2", "nr_singer", Vector3(60, 0, 42.0), -PI / 2.0, {"display_name": "Дама в мехах",
		"patrol": PackedVector3Array([Vector3(60, 0, 42.0), Vector3(20, 0, 41.5), Vector3(44, 0, 58)]), "patrol_wait": 6.0})
	character(chars, "Walker3", "town_m3", Vector3(45.5, 0, 20.0), 0.0, {"display_name": "Прохожий",
		"patrol": PackedVector3Array([Vector3(45.5, 0, 20.0), Vector3(45.5, 0, 62.0), Vector3(66, 0, 64)]), "patrol_wait": 4.0})
	character(chars, "Kid1", "kid", Vector3(42.0, 0, 44.5), 1.0, {"display_name": "Продаёт лотерейные билеты",
		"patrol": PackedVector3Array([Vector3(42.0, 0, 44.5), Vector3(20, 0, 41.0), Vector3(66, 0, 37.5)]), "patrol_wait": 3.0})
	character(chars, "Patrol1", "nr_guard", Vector3(24, 0, 41.0), PI / 2.0, {"display_name": "Патруль охраны", "armed": true,
		"patrol": PackedVector3Array([Vector3(24, 0, 41.0), Vector3(78, 0, 41.0), Vector3(44.5, 0, 62.0), Vector3(44.5, 0, 18.0)]), "patrol_wait": 4.0})
	var items := group(root, "Items")
	_junk_items(items)
	_exit(items, "ToProxod", "В Проход", Vector3(1.0, 0, 40.0), Vector3(1.6, 2.2, 5.0))
	_exit(items, "ToBlack", "В Чёрный район", Vector3(44.0, 0, 1.0), Vector3(5.0, 2.2, 1.6))
	_use(items, "Monument", "Памятник «Первому алмазу»", Vector3(44, 0, 42.4), Vector3(2.6, 3.0, 1.0))
	_use(items, "Lottery", "Экран радиолотереи", Vector3(39.2, 0, 45.6), Vector3(1.4, 3.6, 0.6))
	_use(items, "Roulette", "Рулетка", _slot(cas, "roulette") + Vector3(0, 0, 1.1), Vector3(1.6, 1.0, 1.6))
	_use(items, "Slots", "Однорукие бандиты", _slot(cas, "slot1") + Vector3(1.3, 0, -0.7), Vector3(4.0, 1.8, 0.8))
	_use(items, "Ring", "Ринг", Vector3(30, 0, 48.2), Vector3(9.0, 1.2, 1.0))
	_use(items, "Safe", "Сейф казначея", _slot(gov, "safe"), Vector3(1.2, 1.6, 0.8))
	_spawn("Start", Vector3(4.5, 0, 40.0))
	_spawn("FromProxod", Vector3(4.5, 0, 41.5))
	_spawn("FromBlack", Vector3(45.5, 0, 4.5))
	marker(root, "MarkGov", Vector3(62, 0, 28), "Дом правительства")
	marker(root, "MarkCasino", Vector3(30, 0, 28), "Казино")
	marker(root, "MarkHotel", Vector3(30, 0, 7.5), "Гостиница «Алмаз»")
	marker(root, "MarkBarracks", Vector3(60, 0, 7.5), "Казармы")
	marker(root, "MarkArena", Vector3(30, 0, 53), "Арена")
	marker(root, "MarkSalon", Vector3(58, 0, 49.5), "Салон «Бархат»")
	marker(root, "MarkJeweler", Vector3(76, 0, 49.5), "Ювелирный")
	_dress(Rect2(4, 2, 78, 78), 200)
	_clear_town(Rect2(2, 1, 80, 80))
	_finish("nyurba_center")


# ======================================================================
# ПРОМРАЙОН — цеха огранки и напыления, склады, котельная; владения Кеши.
# Здесь — первые доказательства аферы с палью
# ======================================================================
func _prom() -> void:
	var rect := Rect2(0, 0, NR, NR)
	_begin("nyurba_prom", "Нью-Рба · Промрайон", rect, "res://scripts/locations/nyurba_prom.gd")
	_grid_streets("nyurba_prom", false, true)
	_no_edge.append(Rect2(-60, NR - 2, NR + 120, 60))
	_mud.append(Rect2(8, 18, 12, 18))
	_mud.append(Rect2(70, 44, 12, 16))
	_ground_for("nyurba_prom")
	var vil := group(root, "Village")
	var pav := group(vil, "Pavement")
	pav.set_meta("no_xray", true)
	_walks(pav)
	# стена: запад и север — край города
	var cw := group(root, "CityWall")
	_city_wall(cw, Vector2(6, -0.6), Vector2(6, NR + 12), [24.0, 60.0])
	_city_wall(cw, Vector2(6, -0.6), Vector2(NR + 12, -0.6), [30.0, 62.0])
	put(P.nr_wall_tower, cw, Vector3(6, 0, -0.6), 0.0, "CornerTower")
	# север проспекта: цеха (высокие, с трубами)
	var fac := _bld(vil, "nr_factory", "Factory", Vector3(28.0, 0, 26.5))
	_sign_on(vil, fac, "ЦЕХ № 1 · ОГРАНКА И НАПЫЛЕНИЕ", 6.4, Color("e8e0c8"))
	var fac2 := _bld(vil, "nr_factory_b", "Factory2", Vector3(62.0, 0, 27.5))
	_signboard(vil, "ЦЕХ № 2 · ПРИЁМКА СЫРЬЯ · ВХОД ПО ПРОПУСКАМ", Vector3(62.0, 5.2, 33.6), 0.0, 6.8, Color("e8c060"))
	_bld(vil, "boiler_house", "Boiler", Vector3(14.0, 0, 8.0))
	_bld(vil, "water_tower", "WaterTower", Vector3(78.0, 0, 8.0))
	_bld(vil, "nr_warehouse", "Warehouse1", Vector3(44.0, 0, 7.0))
	# юг проспекта: столовая завода, склады, профком
	var cant := _bld(vil, "st_canteen", "Canteen", Vector3(30.0, 0, 49.5), PI)
	_sign_on(vil, cant, "СТОЛОВАЯ ЗАВОДА", 3.6, Color("f0e0c0"))
	var wh := _bld(vil, "nr_warehouse_in", "Warehouse2", Vector3(60.0, 0, 50.5), PI)
	_sign_on(vil, wh, "СКЛАД ГОТОВОЙ ПРОДУКЦИИ", 4.4, Color("e8e0c8"))
	_bld(vil, "garages", "Garages", Vector3(30.0, 0, 70.0), PI)
	_bld(vil, "st_obshaga", "Obshaga", Vector3(62.0, 0, 74.0), PI)
	# теплотрасса над улицами, узкоколейка с вагонеткой, шлак
	_pipes(vil, "high", Vector3(8.0, 0, 14.0), Vector3(82.0, 0, 14.0))
	_pipes(vil, "high", Vector3(41.0, 0, 46.0), Vector3(41.0, 0, 62.0))
	for x in range(10, 82, 2):
		box(vil, Vector3(0.2, 0.06, 1.6), Vector3(x, 0.03, 34.6), "planks_old").owner = root
	for zz in [34.0, 35.2]:
		box(vil, Vector3(72, 0.06, 0.08), Vector3(46, 0.08, zz), "metal_dark").owner = root
	var cart := group(vil, "Cart")
	cart.position = Vector3(50, 0, 34.6)
	box(cart, Vector3(1.6, 0.8, 1.0), Vector3(0, 0.7, 0), "rust").owner = root
	add_rocks(cart)
	_own(collider(cart, Vector3(1.6, 1.0, 1.0), Vector3(0, 0.5, 0)), root)
	_street_dress(vil)
	var trash := group(vil, "Trash")
	for j in [["nr_junk_scrap", Vector3(14.0, 0, 30.0), 0.4], ["nr_junk_scrap", Vector3(76.0, 0, 56.0), 1.2], ["nr_junk_tires", Vector3(16.0, 0, 50.0), 0.0],
			["nr_dumpster", Vector3(38.0, 0, 58.0), PI], ["nr_junk_scrap", Vector3(52.0, 0, 20.5), 2.0]]:
		_junk(trash, j[0], j[1], j[2])
	_clutter(vil, [["rubble", 12.0, 24.0], ["rubble", 74.0, 50.0], ["car_wreck", 80.0, 62.0, 0.6], ["burn_barrel", 22.0, 58.0], ["paz_wreck", 10.0, 66.0, PI / 2.0]])
	for b in [[Vector3(16.0, 0, 44.6), PI], [Vector3(76.0, 0, 44.6), PI]]:
		put(P.nr_bench, vil, b[0], b[1])
	_edges(rect, [["E", 40.0]], [])
	var far := group(root, "FarSouth")
	far.set_meta("no_xray", true)
	_woods(30)
	# --- люди ---
	var chars := group(root, "Characters")
	character(chars, "Kesha", "nr_kesha", _slot(fac, "kesha"), PI, {"dialog": "nr_kesha"})
	var k := 0
	for sl in ["m00", "m02", "m10", "m11", "m13"]:
		character(chars, "Worker%d" % k, "nr_worker", _slot(fac, sl), PI, {"display_name": ["Огранщик", "Шлифовщик", "Токарь", "Напыльщик", "Ученик огранщика"][k]})
		k += 1
	character(chars, "Foreman", "town_m4", _slot(fac, "bench"), 0.0, {"display_name": "Мастер смены"})
	character(chars, "GateG1", "nr_guard", Vector3(57.0, 0, 35.4), 0.0, {"display_name": "Охрана приёмки", "armed": true})
	character(chars, "GateG2", "nr_guard", Vector3(67.0, 0, 35.4), 0.0, {"display_name": "Охрана приёмки", "armed": true})
	character(chars, "Cook", "town_f3", _slot(cant, "cook"), 0.0, {"display_name": "Повариха заводской столовой"})
	character(chars, "Eater1", "nr_worker", _slot(cant, "t1"), 0.0, {"display_name": "Обедает после смены"})
	character(chars, "Eater2", "nr_worker", _slot(cant, "t3"), 0.0, {"display_name": "Обедает после смены"})
	character(chars, "Storekeeper", "town_m2", _slot(wh, "keeper"), PI, {"display_name": "Кладовщик готовой продукции"})
	character(chars, "Porter", "nr_worker", _slot(wh, "porter"), 1.0, {"display_name": "Грузчик"})
	character(chars, "Smoker1", "nr_worker", Vector3(20.5, 0, 35.0), PI, {"display_name": "Курит у цеха"})
	character(chars, "Smoker2", "nr_worker", Vector3(22.0, 0, 35.4), -2.6, {"display_name": "Курит у цеха"})
	character(chars, "Scrapper", "nr_bum", Vector3(15.0, 0, 31.6), 0.4, {"display_name": "Собирает лом"})
	character(chars, "Walker1", "nr_worker", Vector3(44.5, 0, 70.0), PI, {"display_name": "Идёт на смену",
		"patrol": PackedVector3Array([Vector3(44.5, 0, 70.0), Vector3(43.5, 0, 38.0), Vector3(30, 0, 36.0)]), "patrol_wait": 5.0})
	character(chars, "Walker2", "town_f1", Vector3(70, 0, 42.0), -PI / 2.0, {"display_name": "Работница",
		"patrol": PackedVector3Array([Vector3(70, 0, 42.0), Vector3(14, 0, 41.5), Vector3(44, 0, 60)]), "patrol_wait": 6.0})
	var items := group(root, "Items")
	_junk_items(items)
	_exit(items, "ToProxod", "В Проход", Vector3(44.0, 0, NR - 1.0), Vector3(5.0, 2.2, 1.6))
	_exit(items, "ToBlack", "В Чёрный район", Vector3(NR - 1.0, 0, 40.0), Vector3(1.6, 2.2, 5.0))
	_use(items, "Cutters", "Ящик с резцами", _slot(fac, "bench") + Vector3(0, 0, 0.8), Vector3(2.0, 1.0, 0.8))
	_use(items, "Cart", "Вагонетка", Vector3(50, 0, 36.0), Vector3(1.8, 1.2, 1.2))
	_spawn("Start", Vector3(45.5, 0, NR - 4.5))
	_spawn("FromProxod", Vector3(45.5, 0, NR - 4.5))
	_spawn("FromBlack", Vector3(NR - 4.5, 0, 41.5))
	marker(root, "MarkFactory", Vector3(28, 0, 26.5), "Цех № 1")
	marker(root, "MarkFactory2", Vector3(62, 0, 27.5), "Цех № 2 · приёмка")
	marker(root, "MarkCanteen", Vector3(30, 0, 49.5), "Столовая завода")
	marker(root, "MarkWarehouse", Vector3(60, 0, 50.5), "Склад продукции")
	_dress(Rect2(8, 2, 74, 78), 200)
	_clear_town(Rect2(7, 1, 76, 80))
	_finish("nyurba_prom")


## Камни в вагонетке
func add_rocks(parent: Node) -> void:
	for i in 5:
		sphere(parent, 0.25, Vector3(-0.5 + i * 0.25, 1.15, randf_range(-0.2, 0.2)), "stone_wall").owner = root


# ======================================================================
# ЧЁРНЫЙ РАЙОН — дно: самострой, барахолка, ночлежка, рюмочная, где пьёт Боотур.
# Люк — в коллектор под Проходом
# ======================================================================
func _black() -> void:
	var rect := Rect2(0, 0, NR, NR)
	_begin("nyurba_black", "Нью-Рба · Чёрный район", rect, "res://scripts/locations/nyurba_black.gd")
	_grid_streets("nyurba_black", true, false)
	_no_edge.append(Rect2(-60, NR - 2, NR + 120, 60))
	_no_edge.append(Rect2(-60, -10, 60, NR + 20))
	_mud.append(Rect2(10, 46, 26, 14))
	_mud.append(Rect2(52, 18, 24, 14))
	_mud.append(Rect2(50, 66, 28, 12))
	_ground_for("nyurba_black")
	var vil := group(root, "Village")
	var pav := group(vil, "Pavement")
	pav.set_meta("no_xray", true)
	# стена: север и восток — край города
	var cw := group(root, "CityWall")
	_city_wall(cw, Vector2(-12, -0.6), Vector2(NR + 0.6, -0.6), [24.0, 58.0])
	_city_wall(cw, Vector2(NR + 0.6, -0.6), Vector2(NR + 0.6, NR + 12), [30.0, 62.0])
	put(P.nr_wall_tower, cw, Vector3(NR + 0.6, 0, -0.6), 0.0, "CornerTower")
	# север проспекта: ночлежка, полуразрушенный барак, рюмочная
	var noch := _bld(vil, "nr_nochlezhka", "Nochlezhka", Vector3(30.0, 0, 29.5))
	_sign_on(vil, noch, "НОЧЛЕЖКА · 1 р. НОЧЬ", 3.8, Color("e8e0c8"))
	var ryu := _bld(vil, "nr_ryumka", "Ryumka", Vector3(60.0, 0, 30.5))
	_sign_on(vil, ryu, "РЮМОЧНАЯ", 2.8, Color("ffb23a"))
	_neon(ryu, "24 ЧАСА", Vector3(0, 3.2, 4.1), 0.0, Color("ff5a3a"), 64, true)
	_bld(vil, "st_barrack2", "Barrack1", Vector3(30.0, 0, 8.5))
	_bld(vil, "st_block2", "Block1", Vector3(62.0, 0, 8.5))
	# барахолка на перекрёстке: лотки, бочки с огнём
	var mk := group(vil, "Market")
	var cl := ["cloth_sack", "cloth_red", "cloth_sack", "cloth_red"]
	var i := 0
	for p in [Vector3(51.0, 0, 46.5), Vector3(57.0, 0, 46.5), Vector3(63.0, 0, 46.5), Vector3(69.0, 0, 46.5)]:
		_stall(mk, "Stall%d" % i, p, PI, cl[i])
		i += 1
	_signboard(vil, "БАРАХОЛКА", Vector3(60.0, 3.2, 44.2), PI, 3.6)
	# самострой: лачуги кучами
	var sh := group(vil, "Shacks")
	for spec in [[Vector3(14.0, 0, 50.0), 0.2, 0], [Vector3(20.5, 0, 52.0), -0.1, 1], [Vector3(26.0, 0, 50.5), 0.15, 0], [Vector3(33.0, 0, 52.5), 0.0, 1],
			[Vector3(16.0, 0, 57.5), 3.0, 1], [Vector3(24.0, 0, 58.5), 3.2, 0], [Vector3(31.0, 0, 58.0), 3.1, 1],
			[Vector3(54.0, 0, 70.0), 3.1, 0], [Vector3(60.0, 0, 71.0), 3.0, 1], [Vector3(66.0, 0, 70.5), 3.2, 0], [Vector3(73.0, 0, 71.0), 3.1, 1],
			[Vector3(56.0, 0, 22.0), 0.1, 1], [Vector3(62.5, 0, 21.5), 0.0, 0], [Vector3(69.0, 0, 22.0), -0.1, 1]]:
		put(P.nr_shack if spec[2] == 0 else P.nr_shack_b, sh, spec[0], spec[1])
	_bld(vil, "burnt_shed", "Burnt1", Vector3(78.0, 0, 22.0))
	_bld(vil, "st_barrack2", "Barrack2", Vector3(26.0, 0, 74.5), PI)
	_street_dress(vil, Vector3(76.0, 0, 58.0))
	var trash := group(vil, "Trash")
	for j in [["nr_junk_bags", Vector3(38.0, 0, 50.0), 0.3], ["nr_junk_furniture", Vector3(12.0, 0, 44.6 + 1.6), 1.0], ["nr_junk_tires", Vector3(79.0, 0, 34.0), 0.0],
			["nr_dumpster", Vector3(48.5, 0, 22.0), PI / 2.0], ["nr_junk_bags", Vector3(72.0, 0, 62.0), 2.0], ["nr_junk_scrap", Vector3(36.0, 0, 64.0 + 4.0), 0.8],
			["nr_junk_bags", Vector3(14.0, 0, 24.0), 1.0], ["trash_pile", Vector3(52.0, 0, 58.0), 0.0], ["trash_pile_b", Vector3(80.0, 0, 46.0), 0.0],
			["nr_junk_furniture", Vector3(70.0, 0, 34.5), 2.2]]:
		_junk(trash, j[0], j[1], j[2])
	_clutter(vil, [["burn_barrel", 54.0, 44.2], ["burn_barrel", 22.0, 46.0], ["burn_barrel", 64.0, 66.0], ["car_wreck", 12.0, 36.0, 0.4],
		["rubble", 76.0, 14.0], ["rubble", 34.0, 20.0], ["paz_wreck", 80.0, 76.0, 0.0]])
	for b in [[Vector3(40.5, 0, 36.8), PI], [Vector3(47.5, 0, 43.2), 0.0]]:
		put(P.nr_bench, vil, b[0], b[1])
	_graffiti(vil, "ДОЛГИ ПЛАТЯТ ВСЕ", Vector3(22.97, 1.6, 29.5), -PI / 2.0)
	_graffiti(vil, "АПОВИЧ ВСЁ ВИДИТ", Vector3(54.97, 1.5, 30.5), -PI / 2.0, Color("1c1c1c"))
	_edges(rect, [["W", 40.0]], [])
	_woods(30)
	# --- люди ---
	var chars := group(root, "Characters")
	character(chars, "Bootur", "nr_bootur", _slot(ryu, "t1"), PI, {"dialog": "nr_bootur", "start_pose": "sit"})
	character(chars, "RyuBarman", "nr_barman", _slot(ryu, "barman"), PI / 2.0, {"display_name": "Наливайка Зоя"})
	character(chars, "RyuDrunk", "nr_bum", _slot(ryu, "t2"), PI, {"display_name": "Пьёт с утра", "start_pose": "sit"})
	character(chars, "NochKeeper", "town_old_f", _slot(noch, "keeper"), PI, {"display_name": "Хозяйка ночлежки"})
	character(chars, "NochSleeper1", "nr_bum", _slot(noch, "bunk"), 0.0, {"display_name": "Спит на нарах", "start_pose": "sleep"})
	character(chars, "NochSleeper2", "nr_bum", _slot(noch, "bunk2"), 0.0, {"display_name": "Спит на нарах", "start_pose": "sleep"})
	character(chars, "Fence", "nr_fence", Vector3(57.0, 0, 45.0), PI, {"display_name": "Скупщик краденого Мотя"})
	character(chars, "Seller1", "nr_bum", Vector3(51.0, 0, 45.0), PI, {"display_name": "Торгует всяким"})
	character(chars, "Seller2", "villager_f", Vector3(63.0, 0, 45.0), PI, {"display_name": "Продаёт самогон"})
	character(chars, "Seller3", "town_old_m", Vector3(69.0, 0, 45.0), PI, {"display_name": "Меняет вещи на еду"})
	character(chars, "Collector1", "nr_bandit", Vector3(44.5, 0, 50.0), PI, {"display_name": "Сборщик долгов казначея"})
	character(chars, "Collector2", "nr_bandit_b", Vector3(46.0, 0, 51.5), -2.6, {"display_name": "Сборщик долгов казначея"})
	character(chars, "Bum1", "nr_bum", Vector3(22.8, 0, 46.8), -2.4, {"display_name": "Бич у бочки"})
	character(chars, "Bum2", "nr_bum", Vector3(54.8, 0, 43.2), 0.8, {"display_name": "Греет руки"})
	character(chars, "Bum3", "nr_bum", Vector3(19.0, 0, 55.0), 0.0, {"display_name": "Сидит у лачуги", "start_pose": "sit"})
	character(chars, "Woman1", "villager_f", Vector3(27.0, 0, 55.0), PI, {"display_name": "Стирает в тазу"})
	character(chars, "Kid1", "kid", Vector3(30.0, 0, 41.0), 1.0, {"display_name": "Чумазый мальчишка",
		"patrol": PackedVector3Array([Vector3(30.0, 0, 41.0), Vector3(66, 0, 41.0), Vector3(44.5, 0, 60.0)]), "patrol_wait": 3.0})
	character(chars, "Thug1", "nr_bandit", Vector3(70.0, 0, 41.0), -PI / 2.0, {"display_name": "Шпана",
		"patrol": PackedVector3Array([Vector3(70.0, 0, 41.0), Vector3(14, 0, 40.0), Vector3(44.5, 0, 20.0)]), "patrol_wait": 5.0})
	var items := group(root, "Items")
	_junk_items(items)
	_exit(items, "ToProm", "В Промрайон", Vector3(1.0, 0, 40.0), Vector3(1.6, 2.2, 5.0))
	_exit(items, "ToCenter", "В Центр", Vector3(44.0, 0, NR - 1.0), Vector3(5.0, 2.2, 1.6))
	_use(items, "Hatch", "Открытый люк", Vector3(76.0, 0, 58.0), Vector3(1.2, 0.6, 1.2))
	_spawn("Start", Vector3(4.5, 0, 40.0))
	_spawn("FromProm", Vector3(4.5, 0, 41.5))
	_spawn("FromCenter", Vector3(45.5, 0, NR - 4.5))
	_spawn("FromSewer", Vector3(77.3, 0, 59.4))
	marker(root, "MarkNoch", Vector3(30, 0, 29.5), "Ночлежка")
	marker(root, "MarkRyumka", Vector3(60, 0, 30.5), "Рюмочная")
	marker(root, "MarkMarket", Vector3(60, 0, 46.5), "Барахолка")
	_dress(Rect2(4, 2, 78, 78), 260)
	_clear_town(Rect2(2, 1, 80, 80))
	_finish("nyurba_black")
