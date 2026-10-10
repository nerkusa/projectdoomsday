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
			"enamel", "paint_red", "paint_blue", "metal_green", "flag_red", "trash_black", "tar", "window"]:
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
	# пожарная вышка: решётчатые ноги, лестница, будка наверху
	begin()
	var hgt := 12.0
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			var bot := Vector3(sx * 1.6, 0, sz * 1.6)
			var top := Vector3(sx * 0.9, hgt, sz * 0.9)
			var mid := (bot + top) / 2.0
			var d := top - bot
			box("metal_dark", Vector3(0.12, d.length(), 0.12), mid, Vector3(-atan2(d.z, d.y), 0, atan2(d.x, d.y)))
	for k in 5:
		var y := 1.5 + k * 2.2
		var w := 1.6 - (1.6 - 0.9) * (y / hgt)
		for e in [[Vector3(0, y, w), 0.0], [Vector3(0, y, -w), 0.0], [Vector3(w, y, 0), PI / 2.0], [Vector3(-w, y, 0), PI / 2.0]]:
			box("metal_dark", Vector3(w * 2.0, 0.06, 0.06), e[0], Vector3(0, e[1], 0))
			box("metal_dark", Vector3(w * 2.4, 0.04, 0.04), e[0] + Vector3(0, 1.1, 0), Vector3(0, e[1], 0.75))
	for k in 24:
		box("metal_dark", Vector3(0.5, 0.03, 0.04), Vector3(0, 0.4 + k * 0.48, 1.62 - (0.7 * (0.4 + k * 0.48) / hgt)))
	box("planks_old", Vector3(2.4, 0.1, 2.4), Vector3(0, hgt, 0))
	box("planks_old", Vector3(2.2, 1.0, 2.2), Vector3(0, hgt + 0.55, 0))
	box("glass_city", Vector3(2.25, 0.6, 2.25), Vector3(0, hgt + 1.35, 0))
	prism("metal_roof", Vector3(2.8, 0.8, 2.8), Vector3(0, hgt + 2.05, 0))
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			solid(Vector3(0.4, 2.0, 0.4), Vector3(sx * 1.55, 1.0, sz * 1.55))
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


## Ан-2 «кукурузник»: гофрированный фюзеляж переломлен за крылом, звёздообразный мотор,
## погнутый винт, бипланная коробка с рваной обшивкой, хвост лежит в стороне
func _an2() -> void:
	begin()
	_rng.seed = 202
	var p := "an_paint"
	# передняя часть фюзеляжа — немного завалена на бок
	var tilt := Vector3(0, 0, 0.09)
	cyl(p, 0.85, 0.95, 4.6, Vector3(0, 1.0, 1.4), Vector3(PI / 2.0, 0, 0.09), 14)
	for k in 9:
		cyl(p, 0.96 - k * 0.006, 0.96 - k * 0.006, 0.04, Vector3(0, 1.0, -0.6 + k * 0.5), Vector3(PI / 2.0, 0, 0.09), 14)
	for k in 6:
		box("an_red", Vector3(0.02, 0.12, 4.4), Vector3(0.93 * cos(0.09), 0.85, 1.4), tilt)
	box("an_red", Vector3(0.03, 0.18, 4.5), Vector3(0.95, 1.05, 1.4), tilt)
	box("an_red", Vector3(0.03, 0.18, 4.5), Vector3(-0.95, 0.9, 1.4), tilt)
	# окна салона и дверь
	for k in 4:
		box("glass_city", Vector3(0.04, 0.3, 0.32), Vector3(0.93, 1.3, 0.0 + k * 0.7), tilt)
		box("glass_city", Vector3(0.04, 0.3, 0.32), Vector3(-0.96, 1.15, 0.0 + k * 0.7), tilt)
	box("soot", Vector3(0.05, 1.3, 0.75), Vector3(-0.97, 0.85, -0.4), tilt)
	box(p, Vector3(0.75, 1.3, 0.05), Vector3(-1.4, 0.65, -0.6), Vector3(0, 1.2, 0.0))
	# кабина: остекление с переплётом
	box("glass_city", Vector3(1.2, 0.55, 0.9), Vector3(0, 1.9, 3.0), Vector3(-0.45, 0, 0.09))
	for x in [-0.4, 0.0, 0.4]:
		box("metal_dark", Vector3(0.04, 0.6, 0.95), Vector3(x, 1.95, 3.0), Vector3(-0.45, 0, 0.09))
	# мотор АШ-62: капот, головки цилиндров по кругу, винт с погнутыми лопастями
	cyl(p, 0.78, 0.86, 0.9, Vector3(0, 1.0, 4.1), Vector3(PI / 2.0, 0, 0), 16)
	cyl("metal_dark", 0.6, 0.65, 0.3, Vector3(0, 1.0, 4.6), Vector3(PI / 2.0, 0, 0), 16)
	for k in 9:
		var a := k * TAU / 9.0
		cyl("metal_dark", 0.08, 0.1, 0.32, Vector3(cos(a) * 0.52, 1.0 + sin(a) * 0.52, 4.62), Vector3(PI / 2.0, 0, 0), 6)
	cyl("metal_dark", 0.0, 0.2, 0.4, Vector3(0, 1.0, 4.95), Vector3(PI / 2.0, 0, 0), 10)
	var bends := [0.0, 0.5, -0.7, 0.25]
	for k in 4:
		var a := k * TAU / 4.0 + 0.3
		var b: float = bends[k]
		box("metal_dark", Vector3(0.22, 1.5, 0.04), Vector3(cos(a) * 0.85, 1.0 + sin(a) * 0.85, 4.95 + b * 0.25), Vector3(b, 0, a - PI / 2.0))
	cyl("metal_dark", 0.05, 0.05, 1.0, Vector3(0.35, 0.6, 3.5), Vector3(0.3, 0, 0.6), 6)
	# бипланная коробка: верхнее крыло целое, нижнее правое отломано
	_wing(Vector3(0, 2.6, 2.0), 14.0, 2.2, 0.0, true)
	_wing(Vector3(-3.6, 0.55, 2.2), 6.5, 1.8, 0.04, false)
	_wing(Vector3(6.2, 0.2, -0.4), 5.0, 1.8, 0.35, false, Vector3(0.12, 0.6, 0.18))
	for x in [-3.2, 3.2]:
		box("metal_dark", Vector3(0.1, 2.0 if x < 0 else 1.0, 0.25), Vector3(x, 1.6 if x < 0 else 2.1, 2.1), Vector3(0, 0, -0.05))
	for x in [-3.2, 3.2]:
		box("metal_dark", Vector3(0.02, 0.02, 3.0), Vector3(x * 0.8, 1.6, 2.1), Vector3(0, 0.35 * signf(x), 0.6))
	# шасси: левое стоит, правое подломилось; хвостовое колесо
	box("metal_dark", Vector3(0.12, 1.0, 0.12), Vector3(-1.2, 0.35, 2.4), Vector3(0, 0, 0.5))
	cyl("tire", 0.42, 0.42, 0.28, Vector3(-1.5, 0.42, 2.4), Vector3(0, 0, PI / 2.0), 14)
	cyl("tire", 0.42, 0.42, 0.28, Vector3(1.7, 0.2, 2.9), Vector3(0.3, 0.6, PI / 2.0 - 1.2), 14)
	# хвостовая часть отломилась, лежит под углом; стабилизатор и киль с красной полосой
	var tr := Vector3(PI / 2.0 - 0.12, 0.35, 0)
	cyl(p, 0.45, 0.85, 4.6, Vector3(0.7, 0.75, -3.4), tr, 12)
	for k in 6:
		cyl(p, 0.87 - k * 0.07, 0.87 - k * 0.07, 0.04, Vector3(0.7 + sin(0.35) * (-0.5 - k * 0.7), 0.75 - k * 0.06, -3.4 + cos(0.35) * (1.6 - k * 0.7) - 1.6), tr, 12)
	box(p, Vector3(0.12, 1.8, 1.4), Vector3(1.6, 1.75, -5.4), Vector3(0, 0.35, 0.1))
	box("an_red", Vector3(0.13, 0.5, 1.42), Vector3(1.62, 2.2, -5.4), Vector3(0, 0.35, 0.1))
	box(p, Vector3(3.6, 0.08, 1.0), Vector3(1.55, 0.95, -5.3), Vector3(0, 0.35, 0.18))
	cyl("tire", 0.15, 0.15, 0.1, Vector3(1.8, 0.15, -5.9), Vector3(0, 0, PI / 2.0), 10)
	# обломки, кресла, чемодан, купол парашюта, гарь
	for k in 7:
		box(p if k % 2 else "rust", Vector3(_rng.randf_range(0.3, 0.9), 0.04, _rng.randf_range(0.3, 0.8)),
			Vector3(_rng.randf_range(-4, 4), 0.04, _rng.randf_range(-6, 6)), Vector3(_rng.randf_range(-0.3, 0.3), _rng.randf() * TAU, _rng.randf_range(-0.3, 0.3)))
	for k in 2:
		box("cloth_sack", Vector3(0.45, 0.45, 0.45), Vector3(-2.5 + k * 0.6, 0.23, -2.2), Vector3(0.3, k * 0.8, 0))
	box("cloth_red", Vector3(0.6, 0.35, 0.2), Vector3(2.4, 0.18, 1.0), Vector3(0, 0.6, 0.2))
	add("paper", rough(rsphere(1.0, 9, 5), 0.2, 9), Vector3(-4.5, 0.0, -3.5), Vector3.ZERO, Vector3(1.6, 0.2, 1.2))
	box("coal", Vector3(4.0, 0.02, 6.0), Vector3(0, 0.015, 2.0))
	solid(Vector3(2.0, 2.0, 5.0), Vector3(0, 1.0, 1.6))
	solid(Vector3(1.6, 1.6, 4.4), Vector3(0.7, 0.8, -3.4), 0.35)
	solid(Vector3(6.0, 0.6, 1.8), Vector3(-3.6, 0.3, 2.2))
	solid(Vector3(4.6, 0.6, 1.8), Vector3(6.2, 0.3, -0.4), 0.6)
	slots["cockpit"] = Vector3(-1.5, 0, 3.4)
	slots["tail"] = Vector3(3.0, 0, -5.2)
	finish("an2_wreck", "An2Wreck")


## Крыло биплана: лонжерон, нервюры, полотно с прорехами
func _wing(c: Vector3, span: float, chord: float, tilt: float, ailerons: bool, rot := Vector3.ZERO) -> void:
	var b := Basis.from_euler(rot if rot != Vector3.ZERO else Vector3(0, 0, tilt))
	var r := rot if rot != Vector3.ZERO else Vector3(0, 0, tilt)
	var n := int(span / 0.55)
	for i in n:
		var x := -span / 2.0 + (i + 0.5) * span / n
		box("an_paint", Vector3(0.04, 0.1, chord), c + b * Vector3(x, 0, 0), r)
		if _rng.randf() > 0.18:
			box("an_fabric", Vector3(span / n - 0.04, 0.03, chord - 0.08), c + b * Vector3(x, 0.03, 0), r)
	box("an_paint", Vector3(span, 0.12, 0.12), c + b * Vector3(0, 0, chord / 2.0 - 0.05), r)
	box("an_paint", Vector3(span, 0.06, 0.06), c + b * Vector3(0, 0, -chord / 2.0 + 0.03), r)
	if ailerons:
		box("an_red", Vector3(span * 0.3, 0.05, 0.4), c + b * Vector3(span * 0.32, 0.02, -chord / 2.0 - 0.15), r)
		box("an_red", Vector3(span * 0.3, 0.05, 0.4), c + b * Vector3(-span * 0.32, 0.02, -chord / 2.0 - 0.15), r)


## Ми-8: лежит на брюхе, хвостовая балка переломлена, лопасти обвисли, задние створки открыты
func _mi8() -> void:
	begin()
	_rng.seed = 808
	var o := "mi_olive"
	box(o, Vector3(2.3, 2.0, 7.0), Vector3(0, 1.2, 0))
	for sx in [-1, 1]:
		box(o, Vector3(0.5, 1.6, 7.0), Vector3(sx * 1.2, 1.15, 0), Vector3(0, 0, sx * 0.35))
	box(o, Vector3(2.0, 0.6, 6.4), Vector3(0, 2.35, 0), Vector3(0, 0, 0))
	add(o, rsphere(1.15, 12, 7), Vector3(0, 1.2, 3.6), Vector3.ZERO, Vector3(1.0, 0.9, 1.0))
	box("glass_city", Vector3(1.8, 0.8, 0.6), Vector3(0, 1.6, 4.2), Vector3(-0.6, 0, 0))
	for k in 5:
		add("glass_city", rsphere(0.22, 8, 5), Vector3(1.16, 1.5, -2.0 + k * 0.85), Vector3.ZERO, Vector3(0.3, 1.0, 1.0))
		add("glass_city", rsphere(0.22, 8, 5), Vector3(-1.16, 1.5, -2.0 + k * 0.85), Vector3.ZERO, Vector3(0.3, 1.0, 1.0))
	# двигатели и редуктор сверху
	for sx in [-0.5, 0.5]:
		cyl(o, 0.4, 0.45, 2.6, Vector3(sx, 2.85, 1.4), Vector3(PI / 2.0, 0, 0), 12)
		cyl("soot", 0.3, 0.3, 0.1, Vector3(sx, 2.85, 0.05), Vector3(PI / 2.0, 0, 0), 12)
	cyl("metal_dark", 0.3, 0.4, 0.6, Vector3(0, 3.3, 0.2), Vector3.ZERO, 10)
	# обвисшие лопасти: пять, одна сломана
	for k in 5:
		var a := k * TAU / 5.0 + 0.2
		var ln := 7.5 if k != 2 else 3.0
		var droop := 0.12 + _rng.randf() * 0.1
		var d := Vector3(cos(a), 0, sin(a))
		box("metal_dark", Vector3(ln, 0.06, 0.5), Vector3(0, 3.5, 0.2) + d * (ln / 2.0) - Vector3(0, ln * droop * 0.5, 0), Vector3(0, -a, -droop))
	box("metal_dark", Vector3(2.6, 0.06, 0.5), Vector3(-5.5, 0.05, 3.5), Vector3(0, 0.8, 0))
	# задние створки распахнуты, внутри ящики
	for sx in [-1, 1]:
		box(o, Vector3(0.08, 1.8, 1.2), Vector3(sx * 1.6, 1.0, -3.9), Vector3(0, sx * 0.8, 0))
	box("soot", Vector3(1.9, 1.7, 0.05), Vector3(0, 1.1, -3.45))
	for k in 3:
		box("metal_green", Vector3(0.7, 0.45, 0.5), Vector3(-0.4 + k * 0.45, 0.45 + (k % 2) * 0.3, -2.8), Vector3(0, k * 0.4, 0))
	box("paint_white", Vector3(0.5, 0.5, 0.02), Vector3(0.0, 1.95, -3.44))
	box("an_red", Vector3(0.16, 0.5, 0.025), Vector3(0.0, 1.95, -3.43))
	box("an_red", Vector3(0.5, 0.16, 0.025), Vector3(0.0, 1.95, -3.43))
	# хвостовая балка переломлена, хвостовой винт
	cyl(o, 0.3, 0.55, 4.0, Vector3(0.4, 1.4, -5.6), Vector3(PI / 2.0 + 0.1, 0.15, 0), 10)
	cyl(o, 0.2, 0.3, 3.0, Vector3(1.6, 0.5, -8.8), Vector3(PI / 2.0 - 0.25, 0.6, 0.2), 10)
	box(o, Vector3(0.1, 1.4, 1.0), Vector3(2.4, 0.9, -10.0), Vector3(0, 0.6, 0.3))
	for k in 3:
		box("metal_dark", Vector3(0.08, 1.4, 0.18), Vector3(2.6, 0.9, -10.0), Vector3(k * TAU / 3.0, 0.6, 0))
	for sx in [-1.4, 1.4]:
		cyl("tire", 0.38, 0.38, 0.3, Vector3(sx, 0.25, 1.8), Vector3(0, 0, PI / 2.0), 12)
	box("coal", Vector3(5.0, 0.02, 9.0), Vector3(0.3, 0.015, -1.0))
	solid(Vector3(2.8, 2.6, 8.2), Vector3(0, 1.3, 0.3))
	solid(Vector3(1.2, 1.4, 6.0), Vector3(1.1, 0.7, -7.6), 0.4)
	slots["cargo"] = Vector3(0, 0, -5.0)
	finish("mi8_wreck", "Mi8Wreck")
