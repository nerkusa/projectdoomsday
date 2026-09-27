extends "res://tools/build_scenes.gd"
## Генератор большой деревни Нахарро (по референсу «Нахарра», ~40 человек):
## частокол с воротами и вышками, площадь с домом собраний, улицы с дворами,
## огороды, теплицы, ветряк, мастерская; хвойный лес вокруг.
## Во время налёта: пожары, баррикады у ворот, защитники, тела нападавших,
## мародёры по дворам и «чистильщики» у амбара.
##
## Постройки собирает tools/build_props.gd (запусти его первым).
## Запуск: godot --headless --path . res://tools/build_nakharro.tscn
## ВНИМАНИЕ: перезаписывает scenes/locations/nakharro.tscn.

## Частокол: прямоугольник x 24..100, z 34..92
const PAL := Rect2(24, 34, 76, 58)
const N_GATE_X := 62.0
const W_GATE_Z := 60.0


func _ready() -> void:
	for n in ["grass", "grass_dry", "dirt", "field", "log", "log_dark", "plank", "roof", "roof_moss", "stone", "metal",
			"rust", "paint_orange", "paint_white", "bark_birch", "bark", "leaves", "leaves_dark", "needles", "window",
			"cabbage", "ash", "mushroom_cap", "mushroom_leg", "berry", "cloth",
			"ground_grass", "ground_meadow", "ground_dirt"]:
		M[n] = load(MAT_DIR + n + ".tres")
	for n in ["izba", "izba_long", "izba_tall", "izba_lean", "izba_small", "hall", "tower", "barn", "shed", "workshop",
			"palisade", "gate", "barricade", "greenhouse", "wind_turbine", "spruce", "pine", "birch", "dead_tree", "bush",
			"rock", "fire", "well", "woodpile", "table", "tractor", "garden", "fence", "fence_broken", "border_post", "sign",
			"planks", "basket", "mushroom", "berries", "bandage"]:
		P[n] = load(PROP_DIR + n + ".tscn")
	_build()
	print("Деревня собрана.")
	get_tree().quit()


func _build() -> void:
	seed(20620)
	root = Node3D.new()
	root.name = "Nakharro"
	root.set_script(load("res://scripts/locations/nakharro.gd"))
	root.set("location_id", "nakharro")
	root.set("title", "Нахарро")
	root.set("map_rect", Rect2(2, 2, 116, 104))
	root.set("camera_start", Vector3(44, 0, 47))
	_env()
	_ground()
	_village()
	_forest()
	_raid()
	_characters()
	_items()
	var ps := PackedScene.new()
	var err := ps.pack(root)
	if err != OK:
		push_error("pack failed %d" % err)
	ResourceSaver.save(ps, "res://scenes/locations/nakharro.tscn")
	root.free()


# ---------------- свет ----------------
func _env() -> void:
	var env_g := group(root, "Env")
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("6f6a55")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("a8a488")
	env.ambient_light_energy = 0.38
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color("b3a07c")
	env.fog_density = 0.004
	env.fog_sky_affect = 0.0
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_bloom = 0.05
	env.adjustment_enabled = true
	env.adjustment_saturation = 0.95
	env.adjustment_contrast = 1.1
	we.environment = env
	env_g.add_child(we)
	we.owner = root
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = Color("fff1d6")
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 0.8
	sun.shadow_blur = 0.6
	sun.directional_shadow_blend_splits = true
	sun.directional_shadow_max_distance = 70.0
	sun.rotation = Vector3(deg_to_rad(-48), deg_to_rad(-120), 0)
	env_g.add_child(sun)
	sun.owner = root


# ---------------- земля и дороги ----------------
func _ground() -> void:
	var ground := group(root, "Ground")
	var gp := MeshInstance3D.new()
	gp.name = "Grass"
	var pm := PlaneMesh.new()
	pm.size = Vector2(170, 160)
	gp.mesh = pm
	gp.material_override = M.ground_grass
	gp.position = Vector3(60, 0, 54)
	ground.add_child(gp)
	gp.owner = root
	# выгоревший луг между лесом и частоколом
	box(ground, Vector3(100, 0.01, 10), Vector3(62, 0.006, 29), "ground_meadow").owner = root
	# дороги: от северных ворот в лес, главная улица, проулки, к западной черте
	var d := "ground_dirt"
	strip(ground, Vector2(N_GATE_X, 60), Vector2(N_GATE_X, 22), 3.2, d)
	strip(ground, Vector2(N_GATE_X, 22), Vector2(64, 8), 1.6, d)
	strip(ground, Vector2(4, W_GATE_Z), Vector2(62, W_GATE_Z), 3.2, d)
	strip(ground, Vector2(62, 60), Vector2(75, 60), 2.6, d)
	strip(ground, Vector2(30, 46), Vector2(96, 46), 2.4, d)
	strip(ground, Vector2(30, 76), Vector2(96, 76), 2.4, d)
	strip(ground, Vector2(38, 46), Vector2(38, 76), 1.8, d)
	strip(ground, Vector2(86, 46), Vector2(86, 76), 1.8, d)
	# площадь
	box(ground, Vector3(18, 0.02, 14), Vector3(62, 0.011, 60), d).owner = root


# ---------------- деревня ----------------
func _village() -> void:
	var vil := group(root, "Village")
	# северный ряд (двери на юг, к улице z=46)
	put(P.izba, vil, Vector3(44, 0, 41), 0.0, "IzbaDed")
	put(P.izba_small, vil, Vector3(33, 0, 41), 0.05, "Izba2")
	put(P.izba_long, vil, Vector3(53, 0, 41), -0.04, "Izba3")
	put(P.izba_lean, vil, Vector3(73, 0, 41), 0.0, "IzbaStepan")
	put(P.izba_tall, vil, Vector3(83, 0, 40.5), 0.03, "Izba5")
	put(P.izba_small, vil, Vector3(93, 0, 41), -0.05, "Izba6")
	# южная сторона улицы z=46 (двери на север)
	put(P.izba_long, vil, Vector3(34, 0, 51.5), PI, "Izba7")
	put(P.izba, vil, Vector3(88, 0, 51.5), PI + 0.04, "Izba8")
	# ряд у улицы z=76
	put(P.izba_tall, vil, Vector3(46, 0, 70.5), 0.0, "Izba9")
	put(P.izba_lean, vil, Vector3(76, 0, 71), 0.0, "Izba10")
	put(P.izba_small, vil, Vector3(92, 0, 71), 0.04, "Izba11")
	put(P.izba, vil, Vector3(34, 0, 81.5), PI, "Izba12")
	put(P.izba_long, vil, Vector3(48, 0, 81.5), PI - 0.03, "Izba13")
	put(P.izba_small, vil, Vector3(78, 0, 81.5), PI, "Izba14")
	put(P.izba, vil, Vector3(90, 0, 81.5), PI + 0.05, "Izba15")
	# площадь: дом собраний (двери к площади), колодец, стол, костровище
	put(P.hall, vil, Vector3(62, 0, 69.5), PI, "Hall")
	put(P.well, vil, Vector3(68, 0, 56), 0.0, "Well")
	put(P.table, vil, Vector3(55, 0, 57), 0.3, "SquareTable")
	# хозяйство
	put(P.barn, vil, Vector3(80, 0, 61), -PI / 2.0, "Barn")
	put(P.workshop, vil, Vector3(32, 0, 64), PI / 2.0, "Workshop")
	put(P.tractor, vil, Vector3(34, 0, 70), 0.6, "Tractor")
	put(P.greenhouse, vil, Vector3(56, 0, 86), 0.0, "Greenhouse1")
	put(P.greenhouse, vil, Vector3(68, 0, 86), 0.0, "Greenhouse2")
	put(P.wind_turbine, vil, Vector3(96, 0, 62), 0.4, "WindTurbine")
	for p in [Vector3(28, 0, 37.5), Vector3(66.5, 0, 41), Vector3(97, 0, 46.5), Vector3(40, 0, 88.5), Vector3(96, 0, 88)]:
		put(P.shed, vil, p, randf_range(-0.2, 0.2))
	put(P.woodpile, vil, Vector3(78, 0, 37.5), 0.1, "Woodpile")
	put(P.woodpile, vil, Vector3(40.8, 0, 37.8), -0.2)
	put(P.table, vil, Vector3(41.5, 0, 45.2), 0.0, "TableDed")
	# огороды за домами и поле на юге
	for p in [Vector3(36, 0, 37), Vector3(88, 0, 36.8), Vector3(40, 0, 56), Vector3(92, 0, 56), Vector3(50, 0, 65),
			Vector3(86, 0, 66.5), Vector3(46, 0, 88)]:
		put(P.garden, vil, p, 0.0)
	for gx in range(4):
		for gz in range(2):
			put(P.garden, vil, Vector3(72 + gx * 5.5, 0, 84.5 + gz * 3.8), 0.0)
	# забор Степана: целые пролёты и дыра
	put(P.fence, vil, Vector3(67.8, 0, 35.8), PI / 2.0, "Fence1")
	put(P.fence_broken, vil, Vector3(67.8, 0, 39.6), PI / 2.0, "FenceGap")
	put(P.fence, vil, Vector3(67.8, 0, 43.2), PI / 2.0, "Fence3")
	# частокол с воротами (север и запад) и вышками
	var pal := group(root, "Palisade")
	var x := PAL.position.x + 2.0
	while x < PAL.end.x:
		if absf(x - N_GATE_X) > 2.6:
			put(P.palisade, pal, Vector3(x, 0, PAL.position.y), 0.0)
		put(P.palisade, pal, Vector3(x, 0, PAL.end.y), PI)
		x += 4.0
	var zs := []
	var z := PAL.position.y + 2.0
	while z < PAL.end.y - 2.5:
		zs.append(z)
		z += 4.0
	zs.append(PAL.end.y - 2.0)
	for zz in zs:
		if absf(zz - W_GATE_Z) > 2.6:
			put(P.palisade, pal, Vector3(PAL.position.x, 0, zz), PI / 2.0)
		put(P.palisade, pal, Vector3(PAL.end.x, 0, zz), -PI / 2.0)
	put(P.gate, pal, Vector3(N_GATE_X, 0, PAL.position.y), 0.0, "GateNorth")
	put(P.gate, pal, Vector3(PAL.position.x, 0, W_GATE_Z), PI / 2.0, "GateWest")
	put(P.tower, pal, Vector3(54.5, 0, 36.5), 0.0, "TowerNorth")
	put(P.tower, pal, Vector3(97.5, 0, 36.5), 0.0, "TowerNE")
	put(P.tower, pal, Vector3(26.5, 0, 52.5), 0.0, "TowerWest")
	put(P.tower, pal, Vector3(26.5, 0, 89.5), 0.0, "TowerSW")
	# кусты и берёзы во дворах
	for p in [Vector3(58, 0, 51), Vector3(69, 0, 50), Vector3(55, 0, 74), Vector3(70, 0, 78), Vector3(30, 0, 72), Vector3(97, 0, 78)]:
		put(P.bush, vil, p, randf() * TAU)
	for p in [Vector3(57, 0, 47.5), Vector3(67.5, 0, 69), Vector3(42, 0, 64)]:
		put(P.birch, vil, p, randf() * TAU, "", 1.1)
	# граница на западе
	var border := group(root, "Border")
	for zz in [W_GATE_Z - 5.0, W_GATE_Z - 2.5, W_GATE_Z + 2.5, W_GATE_Z + 5.0]:
		put(P.border_post, border, Vector3(5.2, 0, zz))
	put(P.sign, border, Vector3(6.5, 0, W_GATE_Z - 2.8), PI / 2.0 - 0.15, "Sign")


# ---------------- лес ----------------
func _forest() -> void:
	var forest := group(root, "Forest")
	var trees := [P.spruce, P.spruce, P.spruce, P.pine, P.pine, P.birch, P.dead_tree]
	var keep := [Vector2(40, 14), Vector2(52, 10), Vector2(64, 16), Vector2(76, 8), Vector2(88, 14),
		Vector2(70, 12), Vector2(58, 6), Vector2(84, 10), Vector2(92, 10)]
	var n := 0
	for i in 5000:
		var x := randf_range(3, 117)
		var z := randf_range(3, 105)
		var north := z < 23.5
		var edge := x < 19 or x > 105 or z > 97
		if not (north or edge):
			continue
		# тропа в лес и дорога к черте
		if absf(x - N_GATE_X) < 2.8 and z > 14:
			continue
		if Vector2(x, z).distance_to(Vector2(64, 8)) < 3.0 or (z < 16 and absf(x - (N_GATE_X + (16 - z) * 0.25)) < 2.0):
			continue
		if absf(z - W_GATE_Z) < 3.0 and x < 26:
			continue
		var ok := Vector2(x, z).distance_to(Vector2(92, 10)) > 6.5  # поляна пса
		for c in keep:
			if Vector2(x, z).distance_to(c) < 2.2:
				ok = false
				break
		if not ok:
			continue
		# у опушки реже
		if north and z > 18 and randf() < 0.55:
			continue
		put(trees[randi() % trees.size()], forest, Vector3(x, 0, z), randf() * TAU, "", randf_range(0.8, 1.3))
		n += 1
		if n > 620:
			break
	for i in 20:
		put(P.rock, forest, Vector3(randf_range(6, 114), 0, randf_range(4, 21)), randf() * TAU, "", randf_range(0.6, 1.4))


# ---------------- налёт ----------------
func _raid() -> void:
	var fx := group(root, "RaidFX")
	fx.add_to_group("phase_raid", true)
	# горят несколько дворов, но не вся деревня — её отстояли
	for p in [Vector3(73, 2.8, 41), Vector3(83, 4.4, 40.5), Vector3(33, 2.4, 41), Vector3(92, 2.6, 71),
			Vector3(32, 2.4, 64), Vector3(57.8, 1.2, 38.0), Vector3(40, 1.6, 88.5), Vector3(90, 2.5, 81.5)]:
		var f := put(P.fire, fx, p)
		f.set("strength", 1.3 if p.y < 2.0 else 2.3)
	box(fx, Vector3(5, 0.03, 3), Vector3(38, 0.07, 36.8), "ash").owner = root
	box(fx, Vector3(4, 0.03, 4), Vector3(92, 0.07, 56), "ash").owner = root
	# баррикады у ворот (с проходом)
	put(P.barricade, fx, Vector3(58.5, 0, 38.0), 0.05, "BarricadeN1")
	put(P.barricade, fx, Vector3(66.5, 0, 38.2), -0.1, "BarricadeN2")
	put(P.barricade, fx, Vector3(28.2, 0, W_GATE_Z - 4.0), PI / 2.0, "BarricadeW1")
	put(P.barricade, fx, Vector3(28.4, 0, W_GATE_Z + 4.4), PI / 2.0 + 0.1, "BarricadeW2")


# ---------------- персонажи ----------------
func _characters() -> void:
	var chars := group(root, "Characters")
	var M_ := ["phase_morning"]
	var R_ := ["phase_raid"]
	# сюжетные — утро
	character(chars, "Ded", "ded", Vector3(46.8, 0, 46.4), PI, {"dialog": "ded", "groups": M_})
	character(chars, "Stepan", "stepan", Vector3(74.5, 0, 46.2), PI * 0.9, {"dialog": "stepan", "groups": M_})
	character(chars, "Varvara", "varvara", Vector3(75.5, 0, 59.5), -PI / 2.0, {"dialog": "varvara", "groups": M_})
	character(chars, "Kid", "kid", Vector3(66.5, 0, 58.2), -0.8, {"dialog": "kid", "groups": M_})
	character(chars, "Wolf", "wolf", Vector3(92, 0, 10), 1.2, {"hostile": true, "aggro_radius": 7.0, "groups": M_})
	# жители утром: часовые, огородницы, мастер, старики на площади
	character(chars, "GuardN", "defender", Vector3(60.2, 0, 37.2), PI, {"display_name": "Часовой Эрчим", "armed": true, "groups": M_})
	character(chars, "GuardW", "defender_f", Vector3(27.6, 0, W_GATE_Z - 1.6), -PI / 2.0, {"display_name": "Часовая Сардана", "armed": true, "groups": M_})
	character(chars, "Gardener1", "villager_f", Vector3(73.5, 0, 83.2), 0.6, {"display_name": "Огородница", "groups": M_})
	character(chars, "Gardener2", "villager_f", Vector3(84.5, 0, 87.2), -2.2, {"display_name": "Огородница", "groups": M_})
	character(chars, "Smith", "villager", Vector3(35.6, 0, 62.5), -PI / 2.0, {"display_name": "Мастер Тимир", "groups": M_})
	character(chars, "Elder1", "villager", Vector3(54.4, 0, 55.4), 0.3, {"display_name": "Старик", "start_pose": "sit", "groups": M_})
	character(chars, "Elder2", "villager_f", Vector3(53.4, 0, 58.2), 2.8, {"display_name": "Старуха", "start_pose": "sit", "groups": M_})
	character(chars, "Villager3", "villager", Vector3(89.5, 0, 57.5), 1.4, {"display_name": "Житель", "groups": M_})
	character(chars, "Villager4", "villager", Vector3(64.0, 0, 88.5), -0.5, {"display_name": "Житель", "groups": M_})
	# налёт: дед и «чистильщики» у амбара
	character(chars, "DedRaid", "ded", Vector3(75.0, 0, 61.5), -PI / 2.0, {"dialog": "ded", "dialog_node": "last", "groups": R_})
	character(chars, "SoldierA", "soldier_a", Vector3(72.0, 0, 58.2), PI * 0.2, {"hostile": true, "aggro_radius": 8.5, "squad": "cleaners", "groups": R_})
	character(chars, "SoldierB", "soldier_b", Vector3(72.8, 0, 64.4), -PI * 0.3, {"hostile": true, "aggro_radius": 8.5, "squad": "cleaners", "groups": R_})
	# защитники держат ворота
	for c in [["DefenderN1", "defender", Vector3(59.6, 0, 39.4), PI], ["DefenderN2", "defender_f", Vector3(65.4, 0, 39.6), PI + 0.2],
			["DefenderW1", "defender", Vector3(29.6, 0, W_GATE_Z - 2.4), -PI / 2.0], ["DefenderW2", "defender", Vector3(29.8, 0, W_GATE_Z + 2.2), -PI / 2.0 - 0.2]]:
		var ch := character(chars, c[0], c[1], c[2], c[3], {"dialog": "defender", "armed": true, "groups": R_})
		ch.add_to_group("defenders", true)
	character(chars, "WoundedDefender", "villager", Vector3(60.5, 0, 57.8), 1.0, {"display_name": "Раненый", "start_pose": "down", "groups": R_})
	# мародёры, которые ещё шарят по дворам (можно обойти крадучись или напасть первым)
	character(chars, "LooterA", "raider", Vector3(44.0, 0, 76.8), 0.8, {"hostile": true, "aggro_radius": 6.0, "squad": "looters", "groups": R_})
	character(chars, "LooterB", "raider", Vector3(47.2, 0, 77.4), -0.6, {"hostile": true, "aggro_radius": 6.0, "squad": "looters", "groups": R_})
	character(chars, "Gunman", "raider_gun", Vector3(94.5, 0, 67.8), PI, {"hostile": true, "aggro_radius": 6.5, "squad": "gunman", "groups": R_})
	# погибшие жители
	character(chars, "DeadStepan", "stepan", Vector3(70.5, 0, 46.3), 0.4, {"start_dead": true, "display_name": "Степан", "groups": R_})
	character(chars, "DeadVarvara", "varvara", Vector3(77.0, 0, 65.0), 2.2, {"start_dead": true, "display_name": "Тётка Варвара", "groups": R_})
	character(chars, "DeadVillager1", "villager", Vector3(52.5, 0, 55.5), 1.0, {"start_dead": true, "groups": R_})
	character(chars, "DeadVillager2", "villager_f", Vector3(36.5, 0, 73.4), -0.6, {"start_dead": true, "groups": R_})
	# нападавшие: сюжетные тела с модулями и те, кого положили у ворот
	character(chars, "Raider1", "raider_dead_1", Vector3(61.4, 0, 29.0), 2.6, {"start_dead": true, "groups": R_})
	character(chars, "Raider2", "raider_dead_2", Vector3(41.5, 0, 58.6), -1.4, {"start_dead": true, "groups": R_})
	character(chars, "Raider3", "raider_dead_3", Vector3(84.5, 0, 64.8), 0.9, {"start_dead": true, "groups": R_})
	character(chars, "Raider4", "raider_dead_4", Vector3(21.5, 0, 62.8), -2.1, {"start_dead": true, "groups": R_})
	var i := 5
	for p in [Vector3(64.5, 0, 30.6), Vector3(58.2, 0, 31.2), Vector3(66.8, 0, 32.4), Vector3(20.8, 0, 57.2),
			Vector3(19.6, 0, 64.6), Vector3(101.8, 0, 52.0), Vector3(55.0, 0, 28.0)]:
		character(chars, "Raider%d" % i, "raider_dead", p, randf() * TAU, {"start_dead": true, "groups": R_})
		i += 1


# ---------------- предметы и отметки ----------------
func _items() -> void:
	var items := group(root, "Items")
	item(items, P.planks, "Planks", Vector3(76.6, 0, 39.4), ["phase_morning"])
	var basket := item(items, P.basket, "Basket", Vector3(42.1, 0.84, 45.2), ["phase_morning"])
	basket.set("pick_size", Vector3(0.7, 0.9, 0.7))
	var mi := 0
	for p in [Vector3(40, 0, 14), Vector3(52, 0, 10), Vector3(64, 0, 16), Vector3(88, 0, 14), Vector3(76, 0, 8)]:
		mi += 1
		item(items, P.mushroom, "Mushroom%d" % mi, p)
	var bi := 0
	for p in [Vector3(70, 0, 12), Vector3(58, 0, 6), Vector3(84, 0, 10)]:
		bi += 1
		item(items, P.berries, "Berries%d" % bi, p)
	item(items, P.bandage, "BandageRaid", Vector3(61.5, 0, 58.8), ["phase_raid"])
	item(items, P.bandage, "BandageGate", Vector3(63.2, 0, 40.4), ["phase_raid"])
	var ex := _item_base("BorderExit")
	ex.set("kind", "use")
	ex.set("label", "Старая черта")
	ex.set("pick_size", Vector3(1.6, 2.2, 6.0))
	ex.set("reach", 2)
	ex.position = Vector3(5.5, 0, W_GATE_Z)
	items.add_child(ex)
	ex.owner = root

	var sp := group(root, "Spawns")
	var st := Marker3D.new()
	st.name = "Start"
	st.position = Vector3(44, 0, 48.0)
	sp.add_child(st)
	st.owner = root
	marker(root, "MarkBarn", Vector3(80, 0, 61), "Амбар")
	marker(root, "MarkDed", Vector3(44, 0, 41), "Изба деда")
	marker(root, "MarkHall", Vector3(62, 0, 69.5), "Дом собраний")
	marker(root, "MarkForest", Vector3(64, 0, 12), "Лес")
	marker(root, "MarkBorder", Vector3(6, 0, W_GATE_Z), "Черта")
