extends "res://tools/build_city.gd"
## Деревня и дорога: постройки и вещи для Крестов (баня, часовня, коптильня, нужник,
## будка, курятник, колодец-журавль, сэргэ, личные вещи — самовар, вёдра, сапоги,
## удочки, санки, лошадка, чугунок, коромысло, вешала с рыбой, навоз) и детальные
## остатки старого мира для случайных встреч: Ан-2, Ми-8, пожарная вышка,
## вагон узкоколейки, балаган, брошенная стоянка.
## Запуск: godot --headless --path . res://tools/build_rural.tscn


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(MESH_DIR)
	for n in ["trim", "metal_roof", "planks_old", "stone_wall", "metal_dark", "log_weathered", "cloth_sack", "cloth_red",
			"tin", "paper", "rope_mat", "glass", "whitewash", "brass", "tire", "hay", "bread", "fish", "herb", "paint_faded",
			"paint_white", "reed", "berry", "concrete", "coal", "soot", "rust", "plastic_dark", "frame_white", "glass_city",
			"enamel", "paint_red", "paint_blue", "metal_green", "flag_red", "trash_black", "tar", "window", "screen_amber", "screen_green"]:
		if ResourceLoader.exists(MAT_DIR + n + ".tres"):
			M[n] = load(MAT_DIR + n + ".tres")
	_plain_mat("an_paint", Color("5e6458"), 0.75)
	_plain_mat("wagon_brown", Color("4a3226"), 0.9)
	_plain_mat("an_red", Color("8a2a22"), 0.7)
	_plain_mat("an_fabric", Color("5c5844"), 1.0)
	_plain_mat("mi_olive", Color("4a5236"), 0.8)
	_plain_mat("manure", Color("3a2c1c"), 1.0)
	_plain_mat("copper", Color("a8643a"), 0.35)
	_plain_mat("ribbon_blue", Color("3a6aa8"), 0.9)
	_plain_mat("ribbon_white", Color("e0dcd0"), 0.9)
	_plain_mat("earth", Color("4a3f2c"), 1.0)
	_plain_mat("grass_roof", Color("3e4224"), 1.0)
	# техника «Горизонта» и поздних лет: светлый композит, оранжевые полосы, тёмные панели
	_plain_mat("hz_white", Color("a8a497"), 0.6)
	_plain_mat("hz_orange", Color("c4622a"), 0.55)
	_plain_mat("hz_panel", Color("2e3236"), 0.35)
	_plain_mat("hz_metal", Color("858a8e"), 0.3)
	_plain_mat("hz_grey", Color("5d6266"), 0.5)
	village_props()
	personal_items()
	wreck_props()
	print("Деревня и дорога собраны.")
	get_tree().quit()


# ---------------- постройки деревни ----------------
func village_props() -> void:
	# баня по-чёрному: сруб, низкая крыша, дым из-под стрехи, вёдра и веники
	begin()
	log_walls(3.6, 3.0, 0.2, 7, 0.14, 0.6, 0.0)
	gable_roof(3.6, 3.0, 2.15, 1.1, 0.4, 1, false)
	box("planks_old", Vector3(0.8, 1.6, 0.06), Vector3(0.6, 0.95, 1.65))
	box("soot", Vector3(3.8, 0.4, 0.05), Vector3(0, 2.0, 1.68))
	box("planks_old", Vector3(1.6, 0.08, 0.35), Vector3(-0.9, 0.45, 2.0))
	for x in [-1.5, -0.3]:
		box("planks_old", Vector3(0.08, 0.42, 0.3), Vector3(x, 0.22, 2.0))
	cyl("planks_old", 0.3, 0.28, 0.6, Vector3(1.6, 0.3, 2.0), Vector3.ZERO, 10)
	for i in 3:
		box("herb", Vector3(0.16, 0.45, 0.12), Vector3(-1.2 + i * 0.3, 1.5, 1.72), Vector3(0, 0, 0.2))
	solid(Vector3(3.9, 2.4, 3.3), Vector3(0, 1.2, 0))
	finish("banya", "Banya")
	# часовня: сруб, крутая крыша, луковка с крестом
	begin()
	log_walls(3.2, 3.2, 0.2, 9, 0.14)
	gable_roof(3.2, 3.2, 2.7, 2.2, 0.4, 1, false)
	cyl("planks_old", 0.35, 0.45, 0.8, Vector3(0, 5.1, 0), Vector3.ZERO, 10)
	add("metal_roof", rsphere(0.5, 10, 6), Vector3(0, 5.75, 0), Vector3.ZERO, Vector3(1.0, 1.2, 1.0))
	cyl("metal_roof", 0.0, 0.25, 0.5, Vector3(0, 6.35, 0), Vector3.ZERO, 8)
	box("metal_dark", Vector3(0.05, 0.9, 0.05), Vector3(0, 6.9, 0))
	box("metal_dark", Vector3(0.45, 0.05, 0.05), Vector3(0, 7.05, 0))
	box("metal_dark", Vector3(0.3, 0.05, 0.05), Vector3(0, 6.75, 0), Vector3(0, 0, 0.3))
	box("planks_old", Vector3(0.9, 1.8, 0.06), Vector3(0, 1.1, 1.75))
	box("trim", Vector3(1.1, 0.12, 0.08), Vector3(0, 2.1, 1.78))
	cyl("whitewash", 0.04, 0.05, 0.12, Vector3(0.65, 1.0, 1.78), Vector3.ZERO, 6)
	solid(Vector3(3.6, 2.6, 3.6), Vector3(0, 1.3, 0))
	finish("chapel", "Chapel")
	# коптильня: дощатый ящик на камнях, труба, рыба внутри видна сквозь щели
	begin()
	box("stone_wall", Vector3(1.4, 0.4, 1.2), Vector3(0, 0.2, 0))
	box("planks_old", Vector3(1.2, 1.4, 1.0), Vector3(0, 1.1, 0))
	box("soot", Vector3(1.22, 0.4, 1.02), Vector3(0, 1.65, 0))
	box("metal_roof", Vector3(1.5, 0.05, 1.3), Vector3(0, 1.85, 0), Vector3(0.15, 0, 0))
	cyl("metal_dark", 0.08, 0.08, 0.8, Vector3(0.4, 2.2, -0.3), Vector3.ZERO, 6)
	for i in 4:
		box("fish", Vector3(0.08, 0.35, 0.03), Vector3(-0.4 + i * 0.25, 1.1, 0.52))
	solid(Vector3(1.5, 1.9, 1.3), Vector3(0, 0.95, 0))
	finish("smokehouse", "Smokehouse")
	# нужник с сердечком
	begin()
	box("planks_old", Vector3(1.0, 2.0, 1.0), Vector3(0, 1.0, 0))
	box("metal_roof", Vector3(1.3, 0.05, 1.3), Vector3(0, 2.08, 0), Vector3(-0.2, 0, 0))
	box("planks_old", Vector3(0.7, 1.7, 0.05), Vector3(0, 0.9, 0.53))
	box("soot", Vector3(0.12, 0.12, 0.02), Vector3(0, 1.55, 0.56), Vector3(0, 0, PI / 4.0))
	solid(Vector3(1.1, 2.0, 1.1), Vector3(0, 1.0, 0))
	finish("outhouse", "Outhouse")
	# собачья будка с цепью и миской
	begin()
	box("planks_old", Vector3(0.9, 0.7, 1.0), Vector3(0, 0.35, 0))
	prism("planks_old", Vector3(1.0, 0.4, 1.05), Vector3(0, 0.9, 0))
	box("soot", Vector3(0.35, 0.4, 0.02), Vector3(0, 0.3, 0.51))
	for i in 6:
		box("metal_dark", Vector3(0.05, 0.03, 0.12), Vector3(0.1 + i * 0.1, 0.03, 0.7 + i * 0.12), Vector3(0, i * 0.8, 0))
	cyl("tin", 0.13, 0.11, 0.08, Vector3(-0.5, 0.04, 0.8), Vector3.ZERO, 10)
	solid(Vector3(1.0, 0.9, 1.1), Vector3(0, 0.45, 0))
	finish("kennel", "Kennel")
	# курятник с выгулом из жердей
	begin()
	box("planks_old", Vector3(1.8, 1.3, 1.4), Vector3(0, 0.65, -0.8))
	box("metal_roof", Vector3(2.1, 0.05, 1.7), Vector3(0, 1.38, -0.8), Vector3(-0.2, 0, 0))
	box("planks_old", Vector3(0.3, 0.06, 1.0), Vector3(0.4, 0.3, 0.2), Vector3(-0.5, 0, 0))
	for sx in [-1, 1]:
		box("log_weathered", Vector3(0.06, 0.8, 2.0), Vector3(sx * 1.0, 0.4, 0.9))
	box("log_weathered", Vector3(2.0, 0.8, 0.06), Vector3(0, 0.4, 1.9))
	for i in 3:
		add("paper", rsphere(0.12, 6, 4), Vector3(-0.5 + i * 0.45, 0.13, 0.8 + (i % 2) * 0.4), Vector3.ZERO, Vector3(1.2, 1.0, 1.4))
	solid(Vector3(2.1, 1.3, 3.0), Vector3(0, 0.65, 0.2))
	finish("coop", "Coop")
	# колодец-журавль: стойка-рогатина, длинный рычаг, шест с ведром
	begin()
	box("log_weathered", Vector3(1.1, 0.7, 1.1), Vector3(0, 0.35, 0))
	box("planks_old", Vector3(1.2, 0.08, 1.2), Vector3(0, 0.74, 0))
	cyl("log_weathered", 0.12, 0.15, 3.6, Vector3(-2.2, 1.8, 0), Vector3.ZERO, 8)
	box("log_weathered", Vector3(6.0, 0.12, 0.12), Vector3(-1.1, 3.4, 0), Vector3(0, 0, -0.32))
	box("stone_wall", Vector3(0.4, 0.4, 0.3), Vector3(-4.0, 2.45, 0))
	box("log_weathered", Vector3(0.05, 2.8, 0.05), Vector3(0.6, 2.75, 0))
	cyl("planks_old", 0.18, 0.15, 0.3, Vector3(0.6, 1.25, 0), Vector3.ZERO, 8)
	solid(Vector3(1.2, 0.8, 1.2), Vector3(0, 0.4, 0))
	solid(Vector3(0.4, 2.0, 0.4), Vector3(-2.2, 1.0, 0))
	finish("well_crane", "WellCrane")
	# сэргэ — резной столб-коновязь
	begin()
	cyl("log_weathered", 0.13, 0.16, 2.4, Vector3(0, 1.2, 0), Vector3.ZERO, 10)
	for y in [1.4, 1.75, 2.05]:
		cyl("log_weathered", 0.17, 0.17, 0.08, Vector3(0, y, 0), Vector3.ZERO, 10)
	add("log_weathered", rsphere(0.18, 8, 5), Vector3(0, 2.5, 0), Vector3.ZERO, Vector3(0.9, 1.4, 0.9))
	box("log_weathered", Vector3(0.12, 0.12, 0.35), Vector3(0, 2.62, 0.15), Vector3(-0.4, 0, 0))
	for i in 3:
		box(["ribbon_white", "ribbon_blue", "cloth_red"][i], Vector3(0.05, 0.45, 0.015), Vector3(0.17 * cos(i * 2.1), 1.5, 0.17 * sin(i * 2.1)), Vector3(0, i * 2.1, 0.1))
	solid(Vector3(0.4, 2.0, 0.4), Vector3(0, 1.0, 0))
	finish("serge", "Serge")
	# навозная куча
	begin()
	add("manure", rough(rsphere(1.0, 9, 5), 0.25, 3, 1.2, 1.0), Vector3(0, -0.35, 0), Vector3.ZERO, Vector3(1.4, 0.7, 1.1))
	add("hay", rough(rsphere(0.4, 7, 4), 0.1, 4), Vector3(0.6, 0.25, 0.3), Vector3.ZERO, Vector3(1.2, 0.5, 1.0))
	solid(Vector3(2.2, 0.7, 1.8), Vector3(0, 0.35, 0))
	finish("manure", "Manure")
	# вешала с рыбой (юкола)
	begin()
	for x in [-1.2, 1.2]:
		cyl("log_weathered", 0.05, 0.06, 1.8, Vector3(x, 0.9, 0), Vector3.ZERO, 6)
	box("log_weathered", Vector3(2.6, 0.06, 0.06), Vector3(0, 1.75, 0))
	for i in 9:
		box("fish", Vector3(0.1, 0.4, 0.03), Vector3(-1.0 + i * 0.25, 1.48, 0), Vector3(0, i * 0.3, 0))
	solid(Vector3(2.6, 1.8, 0.3), Vector3(0, 0.9, 0))
	finish("fish_rack", "FishRack")
	# камыш у воды
	begin()
	for i in 22:
		var a := _rng.randf() * TAU
		var r := _rng.randf() * 0.7
		var h := _rng.randf_range(0.8, 1.5)
		box("reed", Vector3(0.03, h, 0.03), Vector3(cos(a) * r, h / 2.0, sin(a) * r), Vector3(_rng.randf_range(-0.2, 0.2), 0, _rng.randf_range(-0.2, 0.2)))
		if i % 4 == 0:
			cyl("soot", 0.03, 0.03, 0.18, Vector3(cos(a) * r, h + 0.05, sin(a) * r), Vector3.ZERO, 5)
	finish("reeds", "Reeds")


# ---------------- личные вещи ----------------
func personal_items() -> void:
	begin()
	cyl("copper", 0.13, 0.16, 0.32, Vector3(0, 0.16, 0), Vector3.ZERO, 10)
	cyl("copper", 0.05, 0.11, 0.12, Vector3(0, 0.38, 0), Vector3.ZERO, 8)
	cyl("metal_dark", 0.03, 0.03, 0.14, Vector3(0, 0.5, 0), Vector3.ZERO, 6)
	box("copper", Vector3(0.12, 0.03, 0.03), Vector3(0.18, 0.2, 0))
	box("plastic_dark", Vector3(0.05, 0.12, 0.05), Vector3(-0.16, 0.25, 0))
	finish("samovar", "Samovar")
	begin()
	for i in 2:
		cyl("tin", 0.14, 0.11, 0.3, Vector3(i * 0.35, 0.15, 0), Vector3.ZERO, 10)
		box("metal_dark", Vector3(0.26, 0.015, 0.015), Vector3(i * 0.35, 0.33, 0), Vector3(0, 0, 0.3))
	finish("buckets", "Buckets")
	begin()
	for sx in [-0.09, 0.09]:
		box("tire", Vector3(0.1, 0.3, 0.1), Vector3(sx, 0.15, 0))
		box("tire", Vector3(0.1, 0.07, 0.24), Vector3(sx, 0.035, 0.07))
	finish("boots", "Boots")
	begin()
	cyl("log_weathered", 0.3, 0.33, 0.45, Vector3(0, 0.22, 0), Vector3.ZERO, 10)
	box("planks_old", Vector3(0.04, 0.55, 0.04), Vector3(0.05, 0.62, 0), Vector3(0, 0, 0.5))
	box("metal_dark", Vector3(0.18, 0.12, 0.03), Vector3(-0.05, 0.5, 0), Vector3(0, 0, 0.5))
	for i in 3:
		cyl("log_weathered", 0.08, 0.08, 0.45, Vector3(0.45 + i * 0.12, 0.08, 0.2 * i - 0.2), Vector3(0, i * 0.7, PI / 2.0), 6)
	solid(Vector3(0.7, 0.5, 0.7), Vector3(0, 0.25, 0))
	finish("axe_stump", "AxeStump")
	begin()
	for i in 3:
		box("log_weathered", Vector3(0.025, 2.6, 0.025), Vector3(i * 0.15, 1.2, 0), Vector3(-0.35, 0, 0.05 * i))
	box("rope_mat", Vector3(0.01, 0.6, 0.01), Vector3(0.0, 1.9, 0.75))
	finish("fishing_rods", "FishingRods")
	begin()
	for sx in [-0.3, 0.3]:
		box("planks_old", Vector3(0.06, 0.1, 1.4), Vector3(sx, 0.08, 0))
		box("planks_old", Vector3(0.06, 0.2, 0.2), Vector3(sx, 0.22, 0.75), Vector3(0.6, 0, 0))
	box("planks_old", Vector3(0.7, 0.04, 1.1), Vector3(0, 0.28, -0.05))
	for z in [-0.4, 0.3]:
		box("planks_old", Vector3(0.06, 0.2, 0.06), Vector3(-0.3, 0.18, z))
		box("planks_old", Vector3(0.06, 0.2, 0.06), Vector3(0.3, 0.18, z))
	finish("sledge", "Sledge")
	begin()
	box("planks_old", Vector3(0.12, 0.2, 0.45), Vector3(0, 0.38, 0))
	box("planks_old", Vector3(0.1, 0.22, 0.12), Vector3(0, 0.55, 0.22), Vector3(0.4, 0, 0))
	for z in [-0.15, 0.15]:
		for sx in [-0.04, 0.04]:
			box("planks_old", Vector3(0.03, 0.28, 0.03), Vector3(sx, 0.14, z))
	box("cloth_red", Vector3(0.13, 0.03, 0.15), Vector3(0, 0.49, -0.02))
	finish("toy_horse", "ToyHorse")
	begin()
	add("soot", rsphere(0.17, 8, 5), Vector3(0, 0.16, 0), Vector3.ZERO, Vector3(1.0, 0.85, 1.0))
	cyl("soot", 0.12, 0.12, 0.04, Vector3(0, 0.31, 0), Vector3.ZERO, 10)
	cyl("planks_old", 0.02, 0.02, 0.4, Vector3(0.12, 0.4, 0), Vector3(0, 0, 0.5), 5)
	finish("pot", "Pot")
	begin()
	box("log_weathered", Vector3(1.4, 0.06, 0.06), Vector3(0, 0.03, 0), Vector3(0, 0.3, 0))
	for sx in [-0.62, 0.62]:
		cyl("tin", 0.13, 0.11, 0.28, Vector3(sx * cos(0.3), 0.14, -sx * sin(0.3)), Vector3.ZERO, 10)
	finish("yoke", "Yoke")
	begin()
	for i in 6:
		cyl("log_weathered", 0.07, 0.07, 0.6, Vector3((i % 3) * 0.15, 0.07 + int(i / 3) * 0.13, 0), Vector3(PI / 2.0, 0, 0), 6)
	box("rope_mat", Vector3(0.5, 0.02, 0.02), Vector3(0.15, 0.2, 0))
	finish("firewood", "Firewood")
	begin()
	box("cloth_red", Vector3(0.6, 0.08, 0.4), Vector3(0, 0.04, 0))
	box("paper", Vector3(0.2, 0.02, 0.28), Vector3(0.1, 0.09, 0), Vector3(0, 0.3, 0))
	box("planks_old", Vector3(0.24, 0.3, 0.02), Vector3(-0.15, 0.15, -0.18), Vector3(-0.25, 0, 0))
	box("brass", Vector3(0.16, 0.2, 0.01), Vector3(-0.15, 0.16, -0.17), Vector3(-0.25, 0, 0))
	finish("bundle", "Bundle")


# ---------------- остатки старого мира для встреч ----------------
func wreck_props() -> void:
	_an2()
	_mi8()
	_vtol()
	_drone()
	_jet()
	# пожарная вышка: четыре ноги на бетонных пятах, пояса и крестовые связи по граням,
	# наклонная лестница по южной грани, площадка с перилами и будка наверху.
	# Всё строится по точкам (beam) — ноги стоят на земле, связи сходятся в узлах.
	begin()
	var hgt := 12.0
	var lv := [0.0, 2.4, 4.8, 7.2, 9.6, hgt]
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			beam("metal_dark", _tw(sx, sz, -0.3, hgt), _tw(sx, sz, hgt, hgt), 0.16)
			box("concrete", Vector3(0.7, 0.45, 0.7), _tw(sx, sz, 0.12, hgt) * Vector3(1, 0, 1) + Vector3(0, 0.12, 0))
	for k in lv.size():
		var y: float = lv[k]
		if k > 0:
			# пояс по периметру
			var c := [_tw(-1, -1, y, hgt), _tw(1, -1, y, hgt), _tw(1, 1, y, hgt), _tw(-1, 1, y, hgt)]
			for e in 4:
				beam("metal_dark", c[e], c[(e + 1) % 4], 0.08)
		if k < lv.size() - 1:
			var y2: float = lv[k + 1]
			# крест на каждой грани
			for f in [[-1, -1, 1, -1], [1, -1, 1, 1], [1, 1, -1, 1], [-1, 1, -1, -1]]:
				beam("metal_dark", _tw(f[0], f[1], y, hgt), _tw(f[2], f[3], y2, hgt), 0.05)
				beam("metal_dark", _tw(f[2], f[3], y, hgt), _tw(f[0], f[1], y2, hgt), 0.05)
	# лестница: две тетивы вдоль южной грани в 0,25 м от неё, ступени через 0,35 м
	var off := 0.28
	for rx in [-0.3, 0.3]:
		beam("metal_dark", Vector3(rx, 0.0, _tw(1, 1, 0.0, hgt).z + off), Vector3(rx, hgt + 1.0, _tw(1, 1, hgt, hgt).z + off), 0.06)
	var steps := int(hgt / 0.35)
	for k in range(1, steps + 1):
		var y := k * 0.35
		var z := _tw(1, 1, y, hgt).z + off
		box("metal_dark", Vector3(0.6, 0.04, 0.05), Vector3(0, y, z))
	# площадка, перила, будка
	box("planks_old", Vector3(2.6, 0.12, 2.6), Vector3(0, hgt + 0.06, 0))
	for e in [[Vector3(0, hgt + 1.0, 1.25), 0.0], [Vector3(0, hgt + 1.0, -1.25), 0.0], [Vector3(1.25, hgt + 1.0, 0), PI / 2.0], [Vector3(-1.25, hgt + 1.0, 0), PI / 2.0]]:
		box("metal_dark", Vector3(2.5, 0.05, 0.05), e[0], Vector3(0, e[1], 0))
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			box("metal_dark", Vector3(0.06, 1.0, 0.06), Vector3(sx * 1.25, hgt + 0.5, sz * 1.25))
	box("planks_old", Vector3(1.8, 1.0, 1.8), Vector3(0, hgt + 0.62, -0.2))
	box("glass_city", Vector3(1.84, 0.6, 1.84), Vector3(0, hgt + 1.42, -0.2))
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			box("planks_old", Vector3(0.1, 0.62, 0.1), Vector3(sx * 0.88, hgt + 1.42, -0.2 + sz * 0.88))
	prism("metal_roof", Vector3(2.4, 0.7, 2.4), Vector3(0, hgt + 2.07, -0.2))
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			solid(Vector3(0.5, 2.0, 0.5), _tw(sx, sz, 0.0, hgt) + Vector3(0, 1.0, 0))
	slots["ladder"] = Vector3(0, 0, 2.4)
	finish("fire_tower", "FireTower")
	# узкоколейка: рельсы, шпалы, ржавый вагон-теплушка с приоткрытой дверью
	begin()
	for i in 14:
		box("log_weathered", Vector3(1.6, 0.1, 0.22), Vector3(0, 0.05, -6.5 + i * 1.0), Vector3(0, _rng.randf_range(-0.08, 0.08), 0))
	for sx in [-0.38, 0.38]:
		box("rust", Vector3(0.07, 0.1, 13.5), Vector3(sx, 0.14, 0))
	box("wagon_brown", Vector3(2.2, 2.1, 5.5), Vector3(0, 1.55, 0.5), Vector3(0, 0, 0.04))
	box("metal_roof", Vector3(2.3, 0.12, 5.7), Vector3(0, 2.66, 0.5), Vector3(0, 0, 0.04))
	box("planks_old", Vector3(0.06, 1.6, 1.4), Vector3(1.13, 1.4, 1.4), Vector3(0, 0, 0.04))
	box("soot", Vector3(0.04, 1.6, 0.6), Vector3(1.12, 1.4, 0.4))
	for z in [-1.4, 2.4]:
		for sx in [-0.4, 0.4]:
			cyl("rust", 0.3, 0.3, 0.12, Vector3(sx, 0.35, z), Vector3(0, 0, PI / 2.0), 10)
	box("paper", Vector3(0.02, 0.4, 0.6), Vector3(-1.12, 1.9, -1.0))
	solid(Vector3(2.3, 2.6, 5.6), Vector3(0, 1.3, 0.5))
	slots["door"] = Vector3(1.6, 0, 1.4)
	finish("rail_wagon", "RailWagon")
	# балаган: сруб со стенами наклонно внутрь, плоская земляная крыша, дерновина
	begin()
	var bw := 4.4
	var bd := 3.8
	for i in 9:
		var y := 0.15 + i * 0.26
		var k := 1.0 - i * 0.022
		for sz in [-1, 1]:
			cyl("log_weathered", 0.13, 0.13, bw * k, Vector3(0, y, sz * bd / 2.0 * k), Vector3(sz * 0.12, 0, PI / 2.0), 7)
		for sx in [-1, 1]:
			if sx == 1 and i < 6:
				continue
			cyl("log_weathered", 0.13, 0.13, bd * k, Vector3(sx * bw / 2.0 * k, y, 0), Vector3(PI / 2.0, 0, -sx * 0.12), 7)
	box("earth", Vector3(bw * 0.9, 0.35, bd * 0.9), Vector3(0, 2.6, 0))
	box("grass_roof", Vector3(bw * 0.92, 0.08, bd * 0.92), Vector3(0, 2.8, 0))
	box("planks_old", Vector3(0.06, 1.4, 0.9), Vector3(bw / 2.0 - 0.05, 0.8, 0.0), Vector3(0, 0.7, 0))
	box("glass", Vector3(0.4, 0.35, 0.04), Vector3(-0.8, 1.4, bd / 2.0 * 0.82))
	cyl("stone_wall", 0.25, 0.3, 0.9, Vector3(-1.0, 3.1, -0.6), Vector3.ZERO, 8)
	solid(Vector3(bw, 2.6, bd), Vector3(0, 1.3, 0))
	finish("balagan", "Balagan")
	# брошенная стоянка: палатка, кострище, бревно, котелок на треноге, рюкзак
	begin()
	prism("cloth_sack", Vector3(2.0, 1.3, 2.4), Vector3(0, 0.65, -1.2))
	box("soot", Vector3(0.5, 0.9, 0.02), Vector3(0, 0.45, 0.01))
	for i in 8:
		var a := i * TAU / 8.0
		add("stone_wall", rough(rsphere(0.14, 6, 4), 0.04, i), Vector3(1.8 + cos(a) * 0.5, 0.06, 0.8 + sin(a) * 0.5))
	box("coal", Vector3(0.7, 0.03, 0.7), Vector3(1.8, 0.02, 0.8))
	for k in 3:
		var a := k * TAU / 3.0
		box("log_weathered", Vector3(0.04, 1.2, 0.04), Vector3(1.8 + cos(a) * 0.3, 0.55, 0.8 + sin(a) * 0.3), Vector3(sin(a) * 0.25, 0, -cos(a) * 0.25))
	add("soot", rsphere(0.14, 7, 4), Vector3(1.8, 0.75, 0.8))
	cyl("log_weathered", 0.16, 0.16, 1.8, Vector3(1.8, 0.16, 2.1), Vector3(0, 0, PI / 2.0), 8)
	box("cloth_red", Vector3(0.45, 0.6, 0.3), Vector3(-1.4, 0.3, 0.6), Vector3(0, 0.5, 0.15))
	solid(Vector3(2.0, 1.3, 2.4), Vector3(0, 0.65, -1.2))
	solid(Vector3(1.8, 0.4, 0.4), Vector3(1.8, 0.2, 2.1))
	slots["pack"] = Vector3(-1.4, 0, 0.6)
	finish("camp_site", "CampSite")


## Ан-2Т «Буревестник» — поздний турбовинтовой наследник «кукурузника»: композитный
## фюзеляж с красной полосой, длинный капот турбины, пятилопастный саблевидный винт,
## биплан с законцовками и обтекателями колёс. Переломлен за крылом, хвост лежит в стороне
func _an2() -> void:
	begin()
	_rng.seed = 202
	var w := "hz_white"
	var fb := Basis.from_euler(Vector3(0, 0, 0.09))
	var fc := Vector3(0, 1.0, 1.4)
	var zx := (fb * Basis.from_euler(Vector3(PI / 2.0, 0, 0))).get_euler()
	# фюзеляж: гладкий цилиндр с поясами-стыками, днище темнее
	cyl(w, 0.9, 0.95, 4.6, fc, zx, 32)
	_bb("hz_grey", Vector3(1.4, 0.2, 4.5), fc, fb, Vector3(0, -0.82, 0))
	for k in 7:
		cyl("hz_grey", 0.965, 0.965, 0.03, fc + fb * Vector3(0, 0, -2.1 + k * 0.7), zx, 32)
	for sx in [-1, 1]:
		_bb("an_red", Vector3(0.03, 0.2, 4.6), fc, fb, Vector3(sx * 0.95, 0.12, 0))
		_bb("an_red", Vector3(0.03, 0.06, 4.6), fc, fb, Vector3(sx * 0.94, -0.05, 0))
		# иллюминаторы: круглые, в рамках
		for k in 4:
			var pz := -1.2 + k * 0.7
			cyl("hz_grey", 0.17, 0.17, 0.04, fc + fb * Vector3(sx * 0.95, 0.45, pz), (fb * Basis.from_euler(Vector3(0, 0, PI / 2.0))).get_euler(), 22)
			cyl("glass_city", 0.13, 0.13, 0.05, fc + fb * Vector3(sx * 0.96, 0.45, pz), (fb * Basis.from_euler(Vector3(0, 0, PI / 2.0))).get_euler(), 22)
		_rivets(fc, fb, sx * 0.955, 0.75, -2.2, 2.2, 18)
		_rivets(fc, fb, sx * 0.955, -0.45, -2.2, 2.2, 18)
	# дверь распахнута, внутри темно
	_bb("soot", Vector3(0.05, 1.2, 0.7), fc, fb, Vector3(-0.95, 0.0, -1.7))
	box(w, Vector3(0.7, 1.2, 0.05), Vector3(-1.45, 0.75, -0.25), Vector3(0, 1.1, 0.05))
	# кабина: остекление гранями, переплёт, козырёк
	for k in 4:
		var a := -0.75 + k * 0.5
		_bb("glass_city", Vector3(0.45, 0.42, 0.04), fc, fb, Vector3(sin(a) * 0.72, 0.68, 2.2 + cos(a) * 0.25), Vector3(-0.6, a, 0))
		_bb("hz_panel", Vector3(0.04, 0.46, 0.06), fc, fb, Vector3(sin(a + 0.25) * 0.74, 0.68, 2.2 + cos(a + 0.25) * 0.25), Vector3(-0.6, a, 0))
	_bb(w, Vector3(1.3, 0.12, 0.5), fc, fb, Vector3(0, 0.95, 2.0))
	# капот турбины: длинный, сужается к коку; выхлопные патрубки по бокам, воздухозаборник снизу
	cyl(w, 0.6, 0.88, 1.8, fc + fb * Vector3(0, 0, 3.2), zx, 32)
	cyl("hz_grey", 0.61, 0.61, 0.04, fc + fb * Vector3(0, 0, 3.6), zx, 32)
	_bb("hz_panel", Vector3(0.5, 0.25, 0.9), fc, fb, Vector3(0, -0.62, 3.2), Vector3(0.15, 0, 0))
	for sx in [-1, 1]:
		cyl("hz_metal", 0.12, 0.15, 0.5, fc + fb * Vector3(sx * 0.62, 0.05, 3.0), (fb * Basis.from_euler(Vector3(PI / 2.0 + 0.5, 0, sx * 0.6))).get_euler(), 18)
		_bb("soot", Vector3(0.02, 0.35, 1.4), fc, fb, Vector3(sx * 0.9, 0.05, 1.9))
	cyl(w, 0.0, 0.32, 0.7, fc + fb * Vector3(0, 0, 4.45), zx, 26)
	# пятилопастный саблевидный винт: две лопасти погнуты о землю
	var bends := [0.0, 0.25, -0.9, -0.6, 0.15]
	for k in 5:
		var a := k * TAU / 5.0 + 0.2
		var bd: float = bends[k]
		var d := Vector3(cos(a), sin(a), 0)
		_bb("hz_panel", Vector3(0.2, 1.25, 0.04), fc + fb * Vector3(0, 0, 4.25), fb, d * 0.75 + Vector3(0, 0, bd * 0.2), Vector3(bd, 0, a - PI / 2.0 + 0.25))
		_bb("an_red", Vector3(0.2, 0.12, 0.045), fc + fb * Vector3(0, 0, 4.25), fb, d * 1.32 + Vector3(0, 0, bd * 0.45), Vector3(bd, 0, a - PI / 2.0 + 0.25))
	# бипланная коробка: верхнее крыло целое с законцовками, нижнее правое отломано
	_cwing(Vector3(0, 2.6, 1.9), 13.6, 2.1, Vector3(0, 0, 0.02), true)
	_cwing(Vector3(-3.5, 0.55, 2.1), 6.3, 1.8, Vector3(0, 0, 0.06), false)
	_cwing(Vector3(6.0, 0.25, -0.5), 4.8, 1.8, Vector3(0.12, 0.6, 0.18), false)
	# стойки: обтекаемые, N-образные; растяжки
	for x in [-3.1]:
		for dz in [-0.5, 0.5]:
			box("hz_grey", Vector3(0.08, 2.05, 0.22), Vector3(x, 1.6, 2.1 + dz), Vector3(dz * 0.25, 0, -0.04))
	box("hz_grey", Vector3(0.08, 1.0, 0.22), Vector3(3.1, 2.1, 2.1), Vector3(0, 0, 0.3))
	for x in [-1.8, 1.8]:
		box("hz_metal", Vector3(0.02, 0.02, 2.9), Vector3(x, 1.7, 2.1), Vector3(0, 0.3 * signf(x), 0.6))
	# шасси: левое в обтекателе стоит, правое подломилось
	box("hz_grey", Vector3(0.14, 1.0, 0.25), Vector3(-1.25, 0.4, 2.4), Vector3(0, 0, 0.45))
	add(w, rsphere(0.5, 20, 12), Vector3(-1.55, 0.45, 2.4), Vector3.ZERO, Vector3(0.45, 0.9, 1.4))
	cyl("tire", 0.38, 0.38, 0.22, Vector3(-1.55, 0.38, 2.4), Vector3(0, 0, PI / 2.0), 26)
	add(w, rsphere(0.5, 20, 12), Vector3(1.75, 0.25, 2.9), Vector3(0.3, 0.6, 1.0), Vector3(0.45, 0.9, 1.4))
	cyl("tire", 0.38, 0.38, 0.22, Vector3(2.1, 0.2, 3.3), Vector3(0.3, 0.6, PI / 2.0 - 1.2), 26)
	# хвост: отломан и развёрнут; киль стреловидный с полосой, стабилизатор
	var tb := Basis.from_euler(Vector3(-0.1, 0.35, 0.05))
	var tc := Vector3(0.7, 0.8, -3.4)
	cyl(w, 0.4, 0.9, 4.6, tc, (tb * Basis.from_euler(Vector3(PI / 2.0, 0, 0))).get_euler(), 28)
	cyl("soot", 0.88, 0.88, 0.04, tc + tb * Vector3(0, 0, 2.3), (tb * Basis.from_euler(Vector3(PI / 2.0, 0, 0))).get_euler(), 28)
	for sx in [-1, 1]:
		_bb("an_red", Vector3(0.03, 0.18, 4.4), tc, tb, Vector3(sx * 0.68, 0.12, 0))
	_bb(w, Vector3(0.12, 1.9, 1.5), tc, tb, Vector3(0, 1.3, -1.8), Vector3(-0.35, 0, 0))
	_bb("an_red", Vector3(0.13, 0.55, 1.52), tc, tb, Vector3(0, 1.75, -2.0), Vector3(-0.35, 0, 0))
	_bb("hz_grey", Vector3(0.13, 0.9, 0.4), tc, tb, Vector3(0, 1.1, -2.6), Vector3(-0.35, 0, 0))
	_bb(w, Vector3(3.8, 0.08, 1.0), tc, tb, Vector3(0, 0.25, -2.0), Vector3(0, 0, 0.12))
	cyl("tire", 0.15, 0.15, 0.1, Vector3(1.8, 0.15, -5.9), Vector3(0, 0, PI / 2.0), 18)
	# салон высыпался: кресла, тюки, чемодан, купол парашюта
	for k in 3:
		box("hz_grey", Vector3(0.5, 0.5, 0.5), Vector3(-2.3 + k * 0.6, 0.25, -1.9 - k * 0.3), Vector3(0.2, k * 0.7, 0))
		box("an_red", Vector3(0.5, 0.08, 0.45), Vector3(-2.3 + k * 0.6, 0.52, -1.9 - k * 0.3), Vector3(0.2, k * 0.7, 0))
	for k in 2:
		box("cloth_sack", Vector3(0.45, 0.45, 0.45), Vector3(-3.0 + k * 0.6, 0.23, -3.0), Vector3(0.3, k * 0.8, 0))
	box("cloth_red", Vector3(0.6, 0.35, 0.2), Vector3(2.4, 0.18, 1.0), Vector3(0, 0.6, 0.2))
	add("paper", rough(rsphere(1.0, 18, 10), 0.2, 9), Vector3(-4.5, 0.0, -3.5), Vector3.ZERO, Vector3(1.6, 0.2, 1.2))
	_scorch(Vector3(0, 0, 1.6), 2.4, 3.6)
	_grime(fc, 0.95, 4.0, 0.09)
	for k in 9:
		box(["hz_white", "hz_grey", "an_red"][k % 3], Vector3(_rng.randf_range(0.3, 0.8), 0.04, _rng.randf_range(0.2, 0.7)),
			Vector3(_rng.randf_range(-4, 4), 0.04, _rng.randf_range(-6, 6)), Vector3(_rng.randf_range(-0.3, 0.3), _rng.randf() * TAU, _rng.randf_range(-0.3, 0.3)))
	solid(Vector3(2.0, 2.0, 5.0), Vector3(0, 1.0, 1.6))
	solid(Vector3(1.6, 1.6, 4.4), Vector3(0.7, 0.8, -3.4), 0.35)
	solid(Vector3(6.0, 0.6, 1.8), Vector3(-3.5, 0.3, 2.1))
	solid(Vector3(4.6, 0.6, 1.8), Vector3(6.0, 0.3, -0.5), 0.6)
	slots["cockpit"] = Vector3(-1.5, 0, 3.4)
	slots["tail"] = Vector3(3.0, 0, -5.2)
	finish("an2_wreck", "An2Wreck")


## Композитное крыло: обшивка, стыки панелей, тёмная передняя кромка, элероны, законцовки
func _cwing(c: Vector3, span: float, chord: float, rot: Vector3, tips: bool) -> void:
	var b := Basis.from_euler(rot)
	_bb("hz_white", Vector3(span, 0.12, chord), c, b, Vector3.ZERO)
	_bb("hz_grey", Vector3(span, 0.13, 0.16), c, b, Vector3(0, 0, chord / 2.0 - 0.06))
	var n := int(span / 1.1)
	for i in n + 1:
		_bb("hz_grey", Vector3(0.025, 0.125, chord), c, b, Vector3(-span / 2.0 + i * span / n, 0.005, 0))
	for sx in [-1, 1]:
		_bb("an_red", Vector3(span * 0.28, 0.13, 0.35), c, b, Vector3(sx * span * 0.32, 0, -chord / 2.0 + 0.16))
		_bb("hz_panel", Vector3(span * 0.28, 0.02, 0.02), c, b, Vector3(sx * span * 0.32, 0.07, -chord / 2.0 + 0.34))
		if tips:
			_bb("hz_white", Vector3(0.08, 0.6, chord * 0.7), c, b, Vector3(sx * span / 2.0, 0.25, -0.1), Vector3(0.3, 0, -sx * 0.3))
			_bb("an_red", Vector3(0.09, 0.15, chord * 0.7), c, b, Vector3(sx * (span / 2.0 + 0.05), 0.48, -0.15), Vector3(0.3, 0, -sx * 0.3))
	# прорехи: куски обшивки сорваны
	for k in 3:
		_bb("hz_panel", Vector3(_rng.randf_range(0.4, 0.9), 0.14, _rng.randf_range(0.4, 0.9)), c, b, Vector3(_rng.randf_range(-span / 2.0 + 0.6, span / 2.0 - 0.6), 0.002, _rng.randf_range(-0.3, 0.3)))


## Ряд заклёпок вдоль борта (x — сторона, y — высота, от z0 до z1)
func _rivets(c: Vector3, b: Basis, x: float, y: float, z0: float, z1: float, n: int) -> void:
	for k in n:
		_bb("hz_grey", Vector3(0.025, 0.035, 0.035), c, b, Vector3(x, y, z0 + (z1 - z0) * k / float(n - 1)))


## Ми-Х «Стриж» — поздний скоростной винтокрыл на базе Ми-8: соосные винты, крылышки,
## толкающий винт в кольце на хвосте. Лежит на брюхе, хвостовая балка переломлена,
## правое крыло оторвано, сдвижная дверь открыта, груз высыпался
func _mi8() -> void:
	begin()
	_rng.seed = 808
	var o := "mi_olive"
	var fb := Basis.from_euler(Vector3(0.03, 0, 0.06))
	var c := Vector3(0, 1.2, 0)
	var zx := (fb * Basis.from_euler(Vector3(PI / 2.0, 0, 0))).get_euler()
	# фюзеляж: короб с фасками, днище, гаргрот
	_bb(o, Vector3(2.3, 1.9, 7.0), c, fb, Vector3.ZERO)
	for sx in [-1, 1]:
		_bb(o, Vector3(0.45, 1.5, 6.9), c, fb, Vector3(sx * 1.13, 0.0, 0), Vector3(0, 0, sx * 0.35))
		_bb(o, Vector3(0.45, 0.45, 6.6), c, fb, Vector3(sx * 0.98, 0.95, -0.1), Vector3(0, 0, -sx * 0.6))
	_bb("hz_grey", Vector3(2.0, 0.25, 6.8), c, fb, Vector3(0, -1.0, 0))
	_bb(o, Vector3(1.7, 0.7, 4.2), c, fb, Vector3(0, 1.25, 0.6))
	_bb("hz_grey", Vector3(1.72, 0.06, 4.2), c, fb, Vector3(0, 1.05, 0.6))
	# два турбовальных двигателя сверху: заборники с решётками, выхлопы вбок с копотью
	for sx in [-1, 1]:
		var ep := Vector3(sx * 0.62, 1.55, 1.2)
		cyl(o, 0.42, 0.42, 2.8, c + fb * ep, zx, 26)
		cyl("hz_panel", 0.36, 0.36, 0.05, c + fb * (ep + Vector3(0, 0, 1.41)), zx, 26)
		for k in 4:
			_bb("hz_metal", Vector3(0.7, 0.03, 0.04), c, fb, ep + Vector3(0, -0.24 + k * 0.16, 1.43))
		cyl("hz_metal", 0.3, 0.36, 0.6, c + fb * (ep + Vector3(sx * 0.25, 0, -1.6)), (fb * Basis.from_euler(Vector3(PI / 2.0, sx * 0.6, 0))).get_euler(), 22)
		cyl("soot", 0.28, 0.28, 0.04, c + fb * (ep + Vector3(sx * 0.42, 0, -1.85)), (fb * Basis.from_euler(Vector3(PI / 2.0, sx * 0.6, 0))).get_euler(), 22)
		_bb("soot", Vector3(0.02, 0.8, 2.6), c, fb, Vector3(sx * 1.17, 0.45, -2.6))
	# соосные винты: мачта, две ступицы, по четыре лопасти, обвисли; две сломаны
	cyl("hz_metal", 0.16, 0.2, 1.4, c + fb * Vector3(0, 2.2, 0.4), fb.get_euler(), 18)
	cyl("hz_grey", 0.35, 0.45, 0.4, c + fb * Vector3(0, 1.75, 0.4), fb.get_euler(), 22)
	_rotor("hz_panel", c + fb * Vector3(0, 2.35, 0.4), 4, 7.0, 0.42, 0.13, 0.3, 2)
	_rotor("hz_panel", c + fb * Vector3(0, 2.85, 0.4), 4, 7.0, 0.42, 0.09, 1.05, 0)
	box("hz_panel", Vector3(3.2, 0.05, 0.42), Vector3(-5.6, 0.05, 3.6), Vector3(0, 0.8, 0.05))
	# нос: скошенный, остекление гранями с переплётом, турель-датчик, фара, ПВД
	_bb(o, Vector3(2.1, 1.4, 1.3), c, fb, Vector3(0, -0.2, 4.05), Vector3(0.2, 0, 0))
	add(o, rsphere(0.85, 28, 14), c + fb * Vector3(0, -0.45, 4.7), fb.get_euler(), Vector3(1.2, 0.75, 0.9))
	for k in 4:
		var a := -0.8 + k * 0.53
		_bb("glass_city", Vector3(0.55, 0.62, 0.04), c, fb, Vector3(sin(a) * 0.95, 0.5, 4.0 + cos(a) * 0.35), Vector3(-0.55, a, 0))
		_bb("hz_panel", Vector3(0.05, 0.66, 0.07), c, fb, Vector3(sin(a + 0.26) * 0.97, 0.5, 4.0 + cos(a + 0.26) * 0.35), Vector3(-0.55, a, 0))
	for sx in [-1, 1]:
		_bb("glass_city", Vector3(0.04, 0.5, 0.7), c, fb, Vector3(sx * 1.16, 0.45, 3.3))
	add("hz_panel", rsphere(0.26, 20, 12), c + fb * Vector3(0.5, -1.0, 4.3))
	add("screen_amber", rsphere(0.08, 12, 8), c + fb * Vector3(0.5, -1.05, 4.55))
	cyl("hz_metal", 0.15, 0.2, 0.2, c + fb * Vector3(-0.5, -1.05, 4.4), zx, 18)
	for sx in [-1, 1]:
		cyl("hz_metal", 0.015, 0.025, 1.1, c + fb * Vector3(sx * 0.7, -0.1, 5.2), zx, 6)
	# борт: иллюминаторы-капли, стыки панелей, заклёпки, номер-панель, красный крест на двери
	for sx in [-1, 1]:
		for k in 5:
			add("glass_city", rsphere(0.2, 16, 10), c + fb * Vector3(sx * 1.16, 0.35, -2.2 + k * 0.85), fb.get_euler(), Vector3(0.25, 1.0, 1.0))
		for k in 6:
			_bb("hz_grey", Vector3(0.02, 1.7, 0.03), c, fb, Vector3(sx * 1.155, 0.0, -3.0 + k * 1.2))
		_rivets(c, fb, sx * 1.16, 0.75, -3.3, 3.3, 22)
		_rivets(c, fb, sx * 1.16, -0.55, -3.3, 3.3, 22)
		_bb("hz_panel", Vector3(0.03, 0.4, 1.2), c, fb, Vector3(sx * 1.16, -0.3, 1.5))
	_bb("soot", Vector3(0.05, 1.5, 1.4), c, fb, Vector3(-1.16, -0.05, -1.5))
	box(o, Vector3(0.08, 1.5, 1.4), Vector3(-1.4, 1.1, -3.1), Vector3(0, 0, -0.02))
	box("paint_white", Vector3(0.02, 0.5, 0.5), Vector3(-1.45, 1.4, -3.1))
	box("an_red", Vector3(0.025, 0.5, 0.16), Vector3(-1.46, 1.4, -3.1))
	box("an_red", Vector3(0.025, 0.16, 0.5), Vector3(-1.46, 1.4, -3.1))
	# крылышки: левое с подвесным баком, правое оторвано и лежит
	_bb(o, Vector3(2.6, 0.16, 1.3), c, fb, Vector3(-2.4, -0.2, 0.3), Vector3(0, 0, -0.08))
	_bb("hz_grey", Vector3(2.6, 0.17, 0.15), c, fb, Vector3(-2.4, -0.2, 0.92), Vector3(0, 0, -0.08))
	cyl(o, 0.28, 0.28, 2.0, c + fb * Vector3(-2.9, -0.65, 0.3), zx, 22)
	add(o, rsphere(0.28, 20, 12), c + fb * Vector3(-2.9, -0.65, 1.3), fb.get_euler(), Vector3(1.0, 1.0, 1.6))
	box(o, Vector3(2.4, 0.16, 1.3), Vector3(3.3, 0.15, 2.4), Vector3(0.1, 0.9, 0.22))
	# сдвижная дверь отъехала, ящики вывалились
	for k in 4:
		box("metal_green", Vector3(0.7, 0.45, 0.5), Vector3(-1.9 - k * 0.35, 0.25 + (k % 2) * 0.2, -1.8 + k * 0.4), Vector3(0, k * 0.5, 0.1 * k))
	box("hz_orange", Vector3(0.7, 0.05, 0.5), Vector3(-2.2, 0.72, -1.4), Vector3(0, 0.5, 0))
	# хвостовая балка: целый кусок и отломанный с Н-оперением и толкающим винтом в кольце
	cyl(o, 0.32, 0.55, 3.6, c + fb * Vector3(0.2, 0.25, -5.3), (fb * Basis.from_euler(Vector3(PI / 2.0 + 0.08, 0.1, 0))).get_euler(), 22)
	cyl("soot", 0.32, 0.32, 0.04, c + fb * Vector3(0.38, 0.1, -7.1), (fb * Basis.from_euler(Vector3(PI / 2.0 + 0.08, 0.1, 0))).get_euler(), 22)
	var tb := Basis.from_euler(Vector3(-0.15, 0.6, 0.2))
	var tc := Vector3(1.7, 0.55, -8.6)
	cyl(o, 0.22, 0.32, 2.6, tc, (tb * Basis.from_euler(Vector3(PI / 2.0, 0, 0))).get_euler(), 22)
	for sx in [-1, 1]:
		_bb(o, Vector3(0.1, 1.4, 0.9), tc, tb, Vector3(sx * 1.0, 0.4, -1.0))
		_bb("an_red", Vector3(0.11, 0.3, 0.92), tc, tb, Vector3(sx * 1.0, 0.95, -1.0))
	_bb(o, Vector3(2.1, 0.08, 0.7), tc, tb, Vector3(0, 0.2, -1.0))
	_duct(tc + tb * Vector3(0, 0.35, -1.9), (tb * Basis.from_euler(Vector3(PI / 2.0, 0, 0))).get_euler(), true)
	# шасси подломилось; гарь, обломки
	for sx in [-1.3, 1.3]:
		cyl("tire", 0.36, 0.36, 0.28, Vector3(sx, 0.25, 1.8), Vector3(0, 0, PI / 2.0), 26)
		box("hz_metal", Vector3(0.1, 0.6, 0.1), Vector3(sx * 0.85, 0.4, 1.8), Vector3(0, 0, sx * 0.5))
	_scorch(Vector3(0.3, 0, -1.0), 3.0, 5.0)
	_grime(c, 1.16, 6.0, 0.06)
	for k in 10:
		box([o, "hz_grey", "hz_metal"][k % 3], Vector3(_rng.randf_range(0.3, 0.8), 0.04, _rng.randf_range(0.2, 0.7)),
			Vector3(_rng.randf_range(-5, 5), 0.04, _rng.randf_range(-9, 6)), Vector3(_rng.randf_range(-0.3, 0.3), _rng.randf() * TAU, _rng.randf_range(-0.3, 0.3)))
	solid(Vector3(2.8, 2.6, 8.2), Vector3(0, 1.3, 0.3))
	solid(Vector3(1.2, 1.4, 6.0), Vector3(1.1, 0.7, -7.6), 0.4)
	slots["cargo"] = Vector3(0, 0, -5.0)
	finish("mi8_wreck", "Mi8Wreck")


## Гарь под обломками: рваное пятно из сплющенных комков (не ровный прямоугольник)
func _scorch(c: Vector3, rx: float, rz: float) -> void:
	for k in 9:
		var p := c + Vector3(_rng.randf_range(-rx, rx) * 0.7, 0.0, _rng.randf_range(-rz, rz) * 0.7)
		add("coal" if k % 3 else "soot", rough(rsphere(1.0, 18, 8), 0.3, 500 + k), p, Vector3(0, _rng.randf() * TAU, 0),
			Vector3(_rng.randf_range(0.6, 1.0) * rx * 0.6, 0.02, _rng.randf_range(0.6, 1.0) * rz * 0.5))


## Грязь и копоть на борту: тёмные потёки по обе стороны корпуса радиуса r, длины ln
func _grime(c: Vector3, r: float, ln: float, roll: float) -> void:
	var b := Basis.from_euler(Vector3(0, 0, roll))
	for sx in [-1, 1]:
		for k in 5:
			var z := _rng.randf_range(-ln / 2.0, ln / 2.0)
			var hgt := _rng.randf_range(0.5, 1.2)
			_bb("soot", Vector3(0.02, hgt, _rng.randf_range(0.3, 1.0)), c, b, Vector3(sx * (r + 0.02), -r * 0.3 + hgt * 0.2, z))


## Ящик, повёрнутый по базису b вокруг точки c (локальная позиция l)
func _bb(mat: String, size: Vector3, c: Vector3, b: Basis, l: Vector3, extra := Vector3.ZERO) -> void:
	var rot := (b * Basis.from_euler(extra)).get_euler()
	var m := minf(size.x, minf(size.y, size.z))
	if m >= 0.1:
		# скруглённые рёбра — корпус гладкий, а не «из коробок»
		add(mat, _rbox_mesh(size, minf(m * 0.45, 0.45)), c + b * l, rot)
	else:
		box(mat, size, c + b * l, rot)


var _rbox_cache := {}


## Ящик со скруглёнными рёбрами и углами: сфера, «растянутая» по осям до размера ящика.
## Нормали — от сферы, поэтому скругления затенены плавно
func _rbox_mesh(size: Vector3, r: float) -> ArrayMesh:
	var key := "%.3f|%.3f|%.3f|%.3f" % [size.x, size.y, size.z, r]
	if _rbox_cache.has(key):
		return _rbox_cache[key]
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.radial_segments = 24
	sm.rings = 12
	var arr := sm.get_mesh_arrays()
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var inner := (size / 2.0 - Vector3(r, r, r)).max(Vector3.ZERO)
	for i in verts.size():
		var v := verts[i]
		var sh := Vector3(signf(v.x) if absf(v.x) > 1e-4 else 0.0, signf(v.y) if absf(v.y) > 1e-4 else 0.0, signf(v.z) if absf(v.z) > 1e-4 else 0.0)
		verts[i] = v * r + sh * inner
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_TANGENT] = null
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	_rbox_cache[key] = am
	return am


## Ступица с лопастями: n лопастей длины ln, обвисание droop, сломанная — короче
func _rotor(mat: String, hub: Vector3, n: int, ln: float, w: float, droop: float, phase: float, broken := -1, axis_rot := Vector3.ZERO) -> void:
	var b := Basis.from_euler(axis_rot)
	cyl("hz_metal", 0.18, 0.24, 0.35, hub, axis_rot, 18)
	for k in n:
		var a := phase + k * TAU / n
		var l := ln * (0.35 if k == broken else 1.0)
		var d := Vector3(cos(a), 0, sin(a))
		var dr := droop * (1.0 + 0.4 * sin(a * 3.0))
		_bb(mat, Vector3(l, 0.05, w), hub, b, d * (l / 2.0 + 0.15) - Vector3(0, l * dr * 0.5, 0), Vector3(0, -a, -dr))


## Конвертоплан «Горизонта» Гр-14: светлый композит, оранжевая полоса, гондолы на концах
## крыла. Сел жёстко: левая гондола стоит, правое крыло обломилось, гондола лежит на земле,
## хвост V-образный, рампа открыта; бортовые огни ещё тлеют
func _vtol() -> void:
	begin()
	_rng.seed = 1414
	var w := "hz_white"
	var tilt := Basis.from_euler(Vector3(0.04, 0, -0.07))
	var c := Vector3(0, 1.25, 0)
	# фюзеляж: короб с фасками, днище, верхний гребень
	_bb(w, Vector3(2.4, 1.9, 8.4), c, tilt, Vector3(0, 0, 0))
	for sx in [-1, 1]:
		_bb(w, Vector3(0.5, 1.5, 8.2), c, tilt, Vector3(sx * 1.2, 0.05, 0), Vector3(0, 0, sx * 0.4))
		_bb(w, Vector3(0.5, 0.5, 8.0), c, tilt, Vector3(sx * 1.05, 0.95, 0), Vector3(0, 0, -sx * 0.6))
	_bb("hz_grey", Vector3(2.2, 0.25, 8.2), c, tilt, Vector3(0, -1.0, 0))
	_bb(w, Vector3(1.6, 0.5, 6.0), c, tilt, Vector3(0, 1.15, -0.2))
	# оранжевая полоса и номер-панель, линии стыков панелей
	for sx in [-1, 1]:
		_bb("hz_orange", Vector3(0.03, 0.22, 8.3), c, tilt, Vector3(sx * 1.22, 0.1, 0))
		_bb("hz_panel", Vector3(0.03, 0.5, 1.4), c, tilt, Vector3(sx * 1.22, 0.55, 2.0))
		for k in 7:
			_bb("hz_grey", Vector3(0.02, 1.7, 0.03), c, tilt, Vector3(sx * 1.215, 0.0, -3.6 + k * 1.2))
		# иллюминаторы — узкие щели
		for k in 4:
			_bb("hz_panel", Vector3(0.04, 0.22, 0.55), c, tilt, Vector3(sx * 1.22, 0.55, -2.4 + k * 0.9))
	# нос и кабина: остекление обёрткой, переплёт, датчики
	_bb(w, Vector3(2.2, 1.5, 1.6), c, tilt, Vector3(0, -0.15, 4.8), Vector3(0.25, 0, 0))
	_bb("hz_panel", Vector3(2.0, 0.75, 1.2), c, tilt, Vector3(0, 0.55, 4.4), Vector3(-0.55, 0, 0))
	for x in [-0.6, 0.0, 0.6]:
		_bb(w, Vector3(0.05, 0.8, 1.25), c, tilt, Vector3(x, 0.57, 4.4), Vector3(-0.55, 0, 0))
	add(w, rsphere(0.75, 24, 12), c + tilt * Vector3(0, -0.25, 5.6), Vector3.ZERO, Vector3(1.3, 0.8, 1.0))
	add("hz_panel", rsphere(0.22, 20, 12), c + tilt * Vector3(0, -0.85, 5.3))
	cyl("hz_metal", 0.02, 0.03, 1.2, c + tilt * Vector3(0.4, -0.1, 6.3), Vector3(PI / 2.0, 0, 0), 6)
	# крыло сверху: левая половина целая, правая обломана у корня
	var wy := 1.55
	_bb(w, Vector3(5.4, 0.22, 2.0), c, tilt, Vector3(-2.9, wy, 0.4))
	_bb("hz_orange", Vector3(5.4, 0.23, 0.25), c, tilt, Vector3(-2.9, wy, 1.32))
	_bb(w, Vector3(1.4, 0.22, 2.0), c, tilt, Vector3(0.9, wy, 0.4))
	for k in 5:
		_bb("hz_metal", Vector3(0.05, 0.3, _rng.randf_range(0.2, 0.6)), c, tilt, Vector3(1.6, wy + 0.05, -0.4 + k * 0.4), Vector3(0, 0, _rng.randf_range(-0.5, 0.5)))
	# левая гондола: стоит вертикально, винт обвис
	var nl := c + tilt * Vector3(-5.6, wy, 0.4)
	cyl(w, 0.55, 0.6, 2.6, nl + Vector3(0, 0.2, 0), Vector3.ZERO, 26)
	cyl("hz_orange", 0.61, 0.61, 0.25, nl + Vector3(0, -0.7, 0), Vector3.ZERO, 26)
	cyl("hz_panel", 0.45, 0.45, 0.1, nl + Vector3(0, -1.12, 0), Vector3.ZERO, 26)
	cyl("hz_metal", 0.2, 0.35, 0.5, nl + Vector3(0, 1.7, 0), Vector3.ZERO, 22)
	_rotor("hz_grey", nl + Vector3(0, 2.0, 0), 3, 4.2, 0.45, 0.16, 0.4)
	# правая гондола: вырвана, лежит на боку у фюзеляжа; лопасти погнуты
	var nr := Vector3(5.2, 0.6, -1.2)
	var nrb := Vector3(PI / 2.0 - 0.2, 0.9, 0.1)
	cyl(w, 0.55, 0.6, 2.6, nr, nrb, 26)
	cyl("hz_orange", 0.61, 0.61, 0.25, nr + Basis.from_euler(nrb) * Vector3(0, -0.7, 0), nrb, 26)
	cyl("soot", 0.5, 0.5, 0.05, nr + Basis.from_euler(nrb) * Vector3(0, -1.32, 0), nrb, 26)
	_rotor("hz_grey", nr + Basis.from_euler(nrb) * Vector3(0, 1.5, 0), 3, 3.4, 0.45, 0.4, 1.1, 1, nrb)
	# обломок правого крыла
	_bb(w, Vector3(3.6, 0.2, 1.9), Vector3(3.6, 0.35, 1.4), Basis.from_euler(Vector3(0.1, 0.5, 0.18)), Vector3.ZERO)
	_bb("hz_orange", Vector3(3.6, 0.21, 0.25), Vector3(3.6, 0.35, 1.4), Basis.from_euler(Vector3(0.1, 0.5, 0.18)), Vector3(0, 0, 0.85))
	# V-хвост и рампа
	for sx in [-1, 1]:
		_bb(w, Vector3(0.14, 2.0, 1.4), c, tilt, Vector3(sx * 0.7, 1.6, -4.0), Vector3(-0.3, 0, sx * 0.7))
		_bb("hz_orange", Vector3(0.15, 0.4, 1.42), c, tilt, Vector3(sx * 1.25, 2.2, -4.2), Vector3(-0.3, 0, sx * 0.7))
	_bb("hz_grey", Vector3(2.0, 0.12, 2.4), c, tilt, Vector3(0, -1.2, -5.0), Vector3(0.45, 0, 0))
	_bb("hz_panel", Vector3(2.0, 1.6, 0.05), c, tilt, Vector3(0, -0.1, -4.18))
	for k in 3:
		box("metal_green", Vector3(0.7, 0.5, 0.55), Vector3(-0.5 + k * 0.5, 0.3 + (k % 2) * 0.2, -5.8 - k * 0.3), Vector3(0, k * 0.5, 0))
	# шасси подломлено; бортовые огни ещё тлеют
	for sx in [-1, 1]:
		box("hz_metal", Vector3(0.12, 0.7, 0.12), c + tilt * Vector3(sx * 1.0, -1.25, 1.8), Vector3(0.6, 0, sx * 0.4))
		cyl("tire", 0.3, 0.3, 0.22, c + tilt * Vector3(sx * 1.3, -1.45, 2.3), Vector3(0, 0, PI / 2.0), 22)
	add("screen_amber", rsphere(0.07, 12, 8), c + tilt * Vector3(-5.6, wy + 0.1, 1.4))
	add("screen_green", rsphere(0.07, 12, 8), c + tilt * Vector3(0, 1.45, -4.5))
	# гарь, обломки панелей
	_scorch(Vector3(0.6, 0, 0.0), 2.6, 4.6)
	_grime(Vector3(0, 1.25, 0), 1.25, 8.0, 0.04)
	for k in 9:
		box(["hz_white", "hz_grey", "hz_orange"][k % 3], Vector3(_rng.randf_range(0.3, 0.9), 0.04, _rng.randf_range(0.2, 0.7)),
			Vector3(_rng.randf_range(-4.5, 5.5), 0.04, _rng.randf_range(-6, 6)), Vector3(_rng.randf_range(-0.3, 0.3), _rng.randf() * TAU, _rng.randf_range(-0.3, 0.3)))
	solid(Vector3(2.8, 2.6, 10.0), Vector3(0, 1.3, 0.3))
	solid(Vector3(1.4, 1.4, 3.0), Vector3(5.0, 0.7, -1.2), 0.9)
	solid(Vector3(1.4, 3.0, 1.4), Vector3(-5.6, 1.5, 0.4))
	slots["cockpit"] = Vector3(-1.6, 0, 4.8)
	slots["cargo"] = Vector3(0, 0, -6.5)
	finish("vtol_wreck", "VtolWreck")


## Грузовой дрон-тяжеловоз «Шмель»: центральная капсула, четыре фермы с винтами в кольцах,
## одна ферма оторвана; контейнер сорвался с подвеса; датчики, кабели, антенны
func _drone() -> void:
	begin()
	_rng.seed = 4040
	var w := "hz_grey"
	var c := Vector3(0, 1.0, 0)
	var tb := Basis.from_euler(Vector3(0.12, 0.3, 0.08))
	# капсула
	_bb(w, Vector3(2.6, 1.0, 3.6), c, tb, Vector3.ZERO)
	_bb(w, Vector3(2.0, 0.5, 3.0), c, tb, Vector3(0, 0.7, 0))
	_bb("hz_panel", Vector3(1.4, 0.06, 2.2), c, tb, Vector3(0, 0.96, 0))
	_bb("hz_orange", Vector3(2.62, 0.18, 0.4), c, tb, Vector3(0, 0.1, 1.6))
	_bb("hz_orange", Vector3(2.62, 0.18, 0.4), c, tb, Vector3(0, 0.1, -1.6))
	for k in 5:
		_bb("hz_panel", Vector3(0.03, 0.6, 0.03), c, tb, Vector3(1.31, 0.0, -1.4 + k * 0.7))
	# датчики: шар-камера, антенны
	add("hz_panel", rsphere(0.35, 24, 14), c + tb * Vector3(0, -0.6, 1.4))
	add("screen_amber", rsphere(0.1, 16, 10), c + tb * Vector3(0, -0.65, 1.72))
	for x in [-0.6, 0.6]:
		cyl("hz_metal", 0.015, 0.02, 1.0, c + tb * Vector3(x, 1.4, -1.0), Vector3.ZERO, 5)
	# фермы с винтами: три целые, одна оторвана
	var arms := [Vector2(1, 1), Vector2(-1, 1), Vector2(-1, -1), Vector2(1, -1)]
	for i in arms.size():
		var a: Vector2 = arms[i]
		var dir := Vector3(a.x, 0, a.y).normalized()
		if i == 3:
			continue
		_bb(w, Vector3(0.3, 0.25, 2.6), c, tb, dir * 2.4 + Vector3(0, 0.2, 0), Vector3(0, atan2(dir.x, dir.z), 0))
		_duct(c + tb * (dir * 3.8 + Vector3(0, 0.3, 0)), tb.get_euler(), i == 1)
	# оторванная ферма с винтом лежит поодаль
	_bb(w, Vector3(0.3, 0.25, 2.2), Vector3(5.2, 0.2, -3.4), Basis.from_euler(Vector3(0.1, 1.9, 0.3)), Vector3.ZERO)
	_duct(Vector3(6.4, 0.75, -4.4), Vector3(1.2, 0.4, 0.2), true)
	for k in 4:
		box("hz_metal", Vector3(0.03, 0.03, _rng.randf_range(0.6, 1.4)), Vector3(2.2 + k * 0.2, 0.9, -1.8), Vector3(_rng.randf_range(-0.6, 0.6), _rng.randf() * TAU, 0))
	# контейнер сорвался с подвеса: лежит, крышка открыта, внутри ящики
	box("metal_green", Vector3(2.0, 1.2, 1.4), Vector3(-2.6, 0.6, -2.8), Vector3(0, 0.5, 0.05))
	box("metal_green", Vector3(2.0, 0.08, 1.4), Vector3(-2.3, 1.45, -3.6), Vector3(1.0, 0.5, 0))
	box("hz_orange", Vector3(2.02, 0.15, 1.42), Vector3(-2.6, 0.95, -2.8), Vector3(0, 0.5, 0.05))
	for k in 6:
		box("rope_mat", Vector3(0.04, 0.04, 0.6), Vector3(-1.6 + k * 0.25, 0.5 + k * 0.08, -1.6 + k * 0.2), Vector3(0.3, 0.4 + k * 0.1, 0.2))
	_scorch(Vector3(0.6, 0, -0.6), 3.0, 3.0)
	for k in 7:
		box(["hz_grey", "hz_panel", "hz_orange"][k % 3], Vector3(_rng.randf_range(0.2, 0.6), 0.04, _rng.randf_range(0.2, 0.5)),
			Vector3(_rng.randf_range(-4, 5), 0.04, _rng.randf_range(-5, 4)), Vector3(_rng.randf_range(-0.3, 0.3), _rng.randf() * TAU, _rng.randf_range(-0.3, 0.3)))
	solid(Vector3(3.0, 2.0, 4.0), Vector3(0, 1.0, 0), 0.3)
	solid(Vector3(2.2, 1.3, 1.6), Vector3(-2.6, 0.65, -2.8), 0.5)
	solid(Vector3(2.2, 1.4, 2.2), Vector3(6.4, 0.7, -4.4))
	slots["cargo"] = Vector3(-2.6, 0, -1.6)
	finish("drone_wreck", "DroneWreck")


## Винт в кольце (импеллер): обечайка, решётка, ступица, лопасти
func _duct(pos: Vector3, rot: Vector3, bent: bool) -> void:
	var b := Basis.from_euler(rot)
	var t := TorusMesh.new()
	t.inner_radius = 1.05
	t.outer_radius = 1.3
	t.rings = 32
	t.ring_segments = 12
	add("hz_grey", t, pos, rot, Vector3(1.0, 1.6, 1.0))
	add("hz_orange", _ring_mesh(1.31, 0.12), pos + b * Vector3(0, 0.12, 0), rot)
	cyl("hz_metal", 0.22, 0.22, 0.3, pos, rot, 18)
	for k in 4:
		var a := k * TAU / 4.0
		_bb("hz_metal", Vector3(2.1, 0.04, 0.05), pos, b, Vector3.ZERO, Vector3(0, a, 0))
	for k in 5:
		var a := k * TAU / 5.0 + 0.3
		var d := Vector3(cos(a), 0, sin(a))
		_bb("hz_panel", Vector3(0.95, 0.04, 0.22), pos, b, d * 0.55 + Vector3(0, 0.08, 0), Vector3(0.35 if not bent or k != 2 else 1.0, -a, 0.1 if not bent else 0.4))


## Плоское кольцо (полоса по краю обечайки)
func _ring_mesh(r: float, h: float) -> CylinderMesh:
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = h
	cm.radial_segments = 32
	cm.rings = 1
	cm.cap_top = false
	cm.cap_bottom = false
	return cm


## Реактивный транспортник поздних лет (Ту/Ил-подобный, «обтекаемый»): фюзеляж
## переломлен надвое, стреловидное крыло, двигатели над крылом, Т-хвост с полосой
func _jet() -> void:
	begin()
	_rng.seed = 7700
	var w := "hz_white"
	# носовая часть: целая, лежит на брюхе с креном
	var fb := Basis.from_euler(Vector3(0.03, 0.0, 0.1))
	var fc := Vector3(0, 1.3, 2.4)
	_bb(w, Vector3(0.1, 0.1, 0.1), fc, fb, Vector3.ZERO)
	cyl(w, 1.35, 1.35, 6.0, fc, (fb * Basis.from_euler(Vector3(PI / 2.0, 0, 0))).get_euler(), 32)
	add(w, rsphere(1.35, 36, 18), fc + fb * Vector3(0, -0.1, 3.0), fb.get_euler(), Vector3(1.0, 0.95, 1.6))
	# кабина: остекление «клювом»
	for k in 4:
		_bb("hz_panel", Vector3(0.42, 0.32, 0.05), fc, fb, Vector3(-0.66 + k * 0.44, 0.75, 4.15), Vector3(-0.8, (k - 1.5) * -0.35, 0))
	# полоса, иллюминаторы, дверь, линии стыков
	for sx in [-1, 1]:
		_bb("hz_orange", Vector3(0.04, 0.25, 6.0), fc, fb, Vector3(sx * 1.33, 0.15, 0))
		for k in 7:
			_bb("hz_panel", Vector3(0.04, 0.2, 0.16), fc, fb, Vector3(sx * 1.33, 0.55, -2.4 + k * 0.7))
		_bb("hz_grey", Vector3(0.04, 1.3, 0.75), fc, fb, Vector3(sx * 1.34, 0.1, 2.3))
	for k in 6:
		cyl("hz_grey", 1.37, 1.37, 0.03, fc + fb * Vector3(0, 0, -2.8 + k * 1.1), (fb * Basis.from_euler(Vector3(PI / 2.0, 0, 0))).get_euler(), 32)
	# рваный край слома
	for k in 10:
		var a := k * TAU / 10.0
		_bb(["hz_white", "hz_metal", "soot"][k % 3], Vector3(0.6, 0.5, _rng.randf_range(0.3, 0.9)), fc, fb, Vector3(cos(a) * 1.2, sin(a) * 1.2, -3.1), Vector3(_rng.randf_range(-0.4, 0.4), 0, a))
	cyl("soot", 1.25, 1.25, 0.05, fc + fb * Vector3(0, 0, -3.05), (fb * Basis.from_euler(Vector3(PI / 2.0, 0, 0))).get_euler(), 32)
	# хвостовая часть: отдельно, развёрнута, с крылом, двигателями и Т-хвостом
	var tb := Basis.from_euler(Vector3(-0.05, 0.55, -0.12))
	var tc := Vector3(1.4, 1.3, -5.6)
	cyl(w, 1.0, 1.35, 6.5, tc, (tb * Basis.from_euler(Vector3(PI / 2.0, 0, 0))).get_euler(), 32)
	cyl("soot", 1.3, 1.3, 0.05, tc + tb * Vector3(0, 0, 3.25), (tb * Basis.from_euler(Vector3(PI / 2.0, 0, 0))).get_euler(), 32)
	for sx in [-1, 1]:
		_bb("hz_orange", Vector3(0.04, 0.25, 6.0), tc, tb, Vector3(sx * 1.2, 0.15, 0))
		# стреловидное крыло (левое целое, правое — обрубок)
		var span := 6.5 if sx < 0 else 2.6
		_bb(w, Vector3(span, 0.2, 2.4), tc, tb, Vector3(sx * (1.0 + span / 2.0), -0.6, 1.6 - span * 0.25), Vector3(0, sx * 0.45, 0))
		_bb("hz_grey", Vector3(span, 0.21, 0.3), tc, tb, Vector3(sx * (1.0 + span / 2.0), -0.6, 0.4 - span * 0.25), Vector3(0, sx * 0.45, 0))
		# двигатель над крылом у фюзеляжа
		var ep := Vector3(sx * 1.9, 0.9, -1.0)
		cyl("hz_grey", 0.65, 0.6, 2.6, tc + tb * ep, (tb * Basis.from_euler(Vector3(PI / 2.0, 0, 0))).get_euler(), 28)
		cyl("hz_panel", 0.5, 0.5, 0.06, tc + tb * (ep + Vector3(0, 0, 1.31)), (tb * Basis.from_euler(Vector3(PI / 2.0, 0, 0))).get_euler(), 28)
		cyl("hz_metal", 0.12, 0.2, 0.3, tc + tb * (ep + Vector3(0, 0, 1.3)), (tb * Basis.from_euler(Vector3(PI / 2.0, 0, 0))).get_euler(), 18)
		cyl("soot", 0.48, 0.48, 0.06, tc + tb * (ep + Vector3(0, 0, -1.31)), (tb * Basis.from_euler(Vector3(PI / 2.0, 0, 0))).get_euler(), 28)
		_bb("hz_grey", Vector3(0.25, 0.6, 1.4), tc, tb, Vector3(sx * 1.45, 0.45, -1.0))
	# Т-хвост
	_bb(w, Vector3(0.18, 2.6, 2.0), tc, tb, Vector3(0, 1.9, -2.6), Vector3(-0.45, 0, 0))
	_bb("hz_orange", Vector3(0.19, 0.5, 2.0), tc, tb, Vector3(0, 2.6, -2.9), Vector3(-0.45, 0, 0))
	_bb(w, Vector3(4.6, 0.14, 1.3), tc, tb, Vector3(0, 3.2, -3.3), Vector3(0, 0, 0.08))
	# обломок правого крыла отдельно, с законцовкой
	var wb := Basis.from_euler(Vector3(0.15, -0.6, 0.25))
	_bb(w, Vector3(4.2, 0.18, 2.0), Vector3(6.2, 0.4, 1.6), wb, Vector3.ZERO)
	_bb("hz_orange", Vector3(0.6, 0.5, 1.6), Vector3(6.2, 0.4, 1.6), wb, Vector3(2.1, 0.25, 0), Vector3(0, 0, 1.2))
	add("screen_amber", rsphere(0.08, 12, 8), Vector3(6.2, 0.4, 1.6) + wb * Vector3(2.4, 0.4, 0))
	# шасси, гарь, полоса пропаханной земли, обломки
	cyl("tire", 0.45, 0.45, 0.35, Vector3(-2.2, 0.45, -1.5), Vector3(0.2, 0.4, PI / 2.0), 26)
	cyl("tire", 0.45, 0.45, 0.35, Vector3(-2.7, 0.45, -1.0), Vector3(0.2, 0.4, PI / 2.0), 26)
	# пропаханная борозда: комья земли вдоль
	for k in 14:
		add("earth", rough(rsphere(0.6, 14, 8), 0.25, 300 + k), Vector3(_rng.randf_range(-1.6, 1.4), 0.0, 5.6 + k * 0.55), Vector3(0, _rng.randf() * TAU, 0),
			Vector3(_rng.randf_range(0.8, 1.6), _rng.randf_range(0.25, 0.5), _rng.randf_range(0.6, 1.2)))
	_scorch(Vector3(1.0, 0, -1.0), 3.6, 6.0)
	_grime(Vector3(0, 1.3, 2.4), 1.37, 6.0, 0.1)
	for k in 12:
		box(["hz_white", "hz_grey", "hz_metal", "hz_orange"][k % 4], Vector3(_rng.randf_range(0.3, 1.0), 0.04, _rng.randf_range(0.2, 0.8)),
			Vector3(_rng.randf_range(-5, 6), 0.04, _rng.randf_range(-8, 7)), Vector3(_rng.randf_range(-0.3, 0.3), _rng.randf() * TAU, _rng.randf_range(-0.3, 0.3)))
	solid(Vector3(2.8, 2.6, 7.0), Vector3(0, 1.3, 2.4), 0.0)
	solid(Vector3(2.8, 2.6, 7.0), Vector3(1.4, 1.3, -5.6), 0.55)
	solid(Vector3(7.0, 0.8, 3.0), Vector3(-2.5, 0.4, -5.0), 0.55)
	solid(Vector3(4.2, 0.8, 2.0), Vector3(6.2, 0.4, 1.6), -0.6)
	slots["cockpit"] = Vector3(-1.9, 0, 5.0)
	slots["tail"] = Vector3(3.2, 0, -8.0)
	finish("jet_wreck", "JetWreck")


## Узел вышки: угол (sx, sz) на высоте y — ноги сходятся от 1,6 м у земли к 0,9 м наверху
func _tw(sx: float, sz: float, y: float, hgt: float) -> Vector3:
	var w := 1.6 - 0.7 * clampf(y, 0.0, hgt) / hgt
	return Vector3(sx * w, y, sz * w)


## Брус от точки a до точки b (квадратное сечение t)
func beam(mat: String, a: Vector3, b: Vector3, t: float) -> void:
	var d := b - a
	var y := d.normalized()
	var x := y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
	var z := x.cross(y).normalized()
	box(mat, Vector3(t, d.length(), t), (a + b) / 2.0, Basis(x, y, z).get_euler())
