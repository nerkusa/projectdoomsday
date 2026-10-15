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
	for n in ["cloth_sack", "cloth_red", "rope_mat", "rust", "metal_dark", "tin", "hay", "bark_dark", "planks_old",
			"stone_wall", "tire", "paper", "metal_roof", "glass", "paint_faded", "paint_white", "cloth", "water", "log_dark",
			"log_weathered", "ground_dirt", "concrete", "coal", "soot", "manure"]:
		M[n] = load(MAT_DIR + n + ".tres")
	for n in ["screen_green", "screen_amber", "plastic_beige", "flag_red", "window_sky", "plaster_yellow", "plaster_pink", "plaster_white",
			"plaster_ochre", "plaster_cream", "brick", "brick_white", "paint_green", "paint_blue", "tar", "felt", "frame_white"]:
		M[n] = load(MAT_DIR + n + ".tres")
	for n in ["nr_stalin3", "nr_stalin4", "nr_stalin4b", "nr_stalin_spire", "nr_bank", "nr_hotel", "nr_labaz", "nr_labaz_bar",
			"nr_labaz_pawn", "nr_labaz_row", "nr_labaz_row2", "nr_warehouse",
			"st_block3a", "st_block3b", "st_block4", "st_block4b", "st_block2", "st_block2b", "st_barrack2",
			"heat_pipe_low", "heat_pipe_high", "heat_pipe_riser", "boiler_house", "water_tower", "garages", "kiosk", "kiosk_b",
			"bus_stop", "conc_fence", "paz_wreck", "bins", "cf_info_screen", "loudspeaker", "power_pole", "sandbags", "checkpoint",
			"notice_board", "trash_pile", "trash_pile_b", "rubble", "car_wreck", "burnt_shed", "burn_barrel", "boardwalk"]:
		P[n] = load(PROP_DIR + n + ".tscn")
	_proxod()


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
	_wall(vil, Vector2(6, 0), Vector2(6, NR), [[34.5, 45.5]])
	put(P.tower, vil, Vector3(6.6, 0, 34.0), 0.0, "GateTowerN")
	put(P.tower, vil, Vector3(6.6, 0, 46.0), 0.0, "GateTowerS")
	box(vil, Vector3(0.14, 0.14, 6.4), Vector3(9.0, 1.05, 40.0), "paint_white").owner = root
	for i in 4:
		box(vil, Vector3(0.15, 0.15, 0.8), Vector3(9.0, 1.06, 37.2 + i * 1.6), "flag_red").owner = root
	for zz in [36.6, 43.4]:
		cyl(vil, 0.09, 0.09, 1.2, Vector3(9.0, 0.6, zz), "metal_dark").owner = root
	_signboard(vil, "НЬЮ-РБА", Vector3(5.2, 4.4, 40.0), -PI / 2.0, 4.2, Color("f0d890"))
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
	_bld(vil, "nr_warehouse", "Warehouse1", Vector3(31.0, 0, 7.5))
	_bld(vil, "nr_warehouse", "Warehouse2", Vector3(68.0, 0, 7.5))
	_graffiti(vil, "ПАЛЬ", Vector3(42.03, 1.8, 7.5), PI / 2.0)
	# --- южная сторона проспекта ---
	# бар «Забой» (квартал 22–40 × 44–62)
	var bar := _bld(vil, "nr_labaz_bar", "Bar", Vector3(31.0, 0, 49.0), PI)
	_sign_on(vil, bar, "БАР «ЗАБОЙ»", 3.6, Color("ffcf7a"))
	_neon(bar, "ЗАБОЙ", Vector3(0, 4.6, 4.6), 0.0, Color("ffb23a"), 96, true)
	# торговые ряды в одноэтажном лабазе
	var row := _bld(vil, "nr_labaz_row", "ShopsRow", Vector3(57.0, 0, 48.5), PI)
	_signboard(vil, "ТОВАРЫ · СОЛЬ · ПАТРОНЫ", _slot(row, "sign"), PI, 5.2, Color("e8d8a8"))
	var lab2 := _bld(vil, "nr_labaz_row2", "Shops2", Vector3(76.5, 0, 49.5), PI)
	_signboard(vil, "ОБМЕН · ВАЛЮТА · ТАЛОНЫ", _slot(lab2, "sign"), PI, 4.6, Color("e8e0c8"))
	# жилые сталинки за переулком z = 64
	_bld(vil, "nr_stalin3", "House1", Vector3(32.0, 0, 72.0), PI)
	_bld(vil, "nr_stalin4", "House2", Vector3(64.0, 0, 73.0), PI)
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
	for b in [Vector3(39.5, 0, 36.2), Vector3(48.5, 0, 43.8)]:
		put(P.bench, vil, b, 0.0 if b.z < 40 else PI)
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
	_graffiti(vil, "АПОВИЧ — ВОР", Vector3(22.97, 1.6, 29.0), -PI / 2.0)
	_graffiti(vil, "ЗАБОЙ — НАШ", Vector3(23.97, 1.5, 49.0), -PI / 2.0, Color("1c1c1c"))
	var det := group(root, "Yard")
	for dd in [["crates", Vector3(26, 0, 59)], ["crates", Vector3(36, 0, 57.5)], ["barrel", Vector3(54, 0, 59)],
			["crates", Vector3(68, 0, 36.6 - 2.0)], ["barrel", Vector3(62, 0, 21.5)], ["crates", Vector3(16, 0, 20)]]:
		put(P[dd[0]], det, dd[1], randf() * TAU)
	_edges(rect, [["E", 40.0]], ["S"])
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
	character(chars, "RowSeller1", "villager", Vector3(52.0, 0, 43.4), PI, {"display_name": "Торговец солью"})
	character(chars, "RowSeller2", "villager_f", Vector3(62.0, 0, 43.4), PI, {"display_name": "Торговка патронами"})
	character(chars, "Changer", "town_m4", Vector3(76.5, 0, 44.2), PI, {"display_name": "Меняла"})
	# бар «Забой»
	character(chars, "Barman", "nr_barman", _slot(bar, "barman"), PI / 2.0, {"display_name": "Бармен Жора"})
	character(chars, "Drinker1", "town_worker", _slot(bar, "t1"), PI, {"display_name": "Шахтёр после смены"})
	character(chars, "Drinker2", "town_m4", _slot(bar, "t2"), PI, {"display_name": "Пьёт в долг"})
	character(chars, "Drinker3", "nr_bandit", _slot(bar, "t3"), PI, {"display_name": "Хмурый в кепке"})
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
	_use(items, "Fountain", "Сухой фонтан", Vector3(44, 0, 42.2), Vector3(3.6, 2.4, 1.2))
	_use(items, "InfoScreen", "Экран у ворот", Vector3(13.5, 0, 46.3), Vector3(1.4, 3.6, 0.6))
	_spawn("Start", Vector3(2.5 + 2.0, 0, 40.0))
	_spawn("Road", Vector3(2.5 + 2.0, 0, 40.0))
	_spawn("FromCenter", Vector3(NR - 4.5, 0, 41.5))
	_spawn("FromProm", Vector3(45.5, 0, 4.5))
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
