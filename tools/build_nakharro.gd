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
## Ров вокруг частокола: от 2,5 до 5,5 м снаружи, глубина 0,9 м; мосты у ворот
const DITCH_IN := 2.5
const DITCH_OUT := 5.5
const DITCH_DEPTH := 0.9

var roads: Array = []  # Rect2 дорог — чтобы не сыпать на них траву
var road_segs: Array = []  # [начало, конец, полуширина] — для карты смешивания
var ground_mat: ShaderMaterial
var _nz := FastNoiseLite.new()  # крупный шум: пятна луга, изгибы рва
var _nf := FastNoiseLite.new()  # мелкий шум: рваные края, комья

## Карта смешивания земли покрывает всю локацию, 2 пикселя на метр
const SPLAT_RECT := Rect2(-25, -26, 170, 160)
const SPLAT_PPM := 2.0
const PLAZA := Rect2(53, 53, 18, 14)
## Болота на лугу у опушки и разбитая колея перед северным мостом
const SWAMPS := [Rect2(82, 20, 20, 7.5), Rect2(24, 20, 22, 7.5)]
const GATE_MUD := Rect2(58, 18, 8, 10)
## Пять находок в лесу: последняя запускает засаду. Рядом с каждой — густой куст-укрытие.
const FOOD := [["Mushroom1", Vector3(44, 0, 6)], ["Berries1", Vector3(55, 0, -3)], ["Mushroom2", Vector3(71, 0, -8)],
	["Berries2", Vector3(84, 0, 1)], ["Mushroom3", Vector3(60, 0, -14)]]
const HIDE_OFF := Vector2(2.6, 1.8)
## Лесные тропинки (без деревьев)
const TRAILS := [[Vector2(62, 22), Vector2(56, 4)], [Vector2(56, 4), Vector2(46, 8)], [Vector2(56, 4), Vector2(60, -12)],
	[Vector2(56, 4), Vector2(72, -6)], [Vector2(72, -6), Vector2(84, 2)], [Vector2(50, 20), Vector2(78, 20)]]


func _ready() -> void:
	for n in ["grass", "grass_dry", "dirt", "field", "log", "log_dark", "plank", "roof", "roof_moss", "stone", "metal",
			"rust", "paint_orange", "paint_white", "bark_birch", "bark", "leaves", "leaves_dark", "needles", "window",
			"cabbage", "ash", "mushroom_cap", "mushroom_leg", "berry", "cloth",
			"ground_grass", "ground_meadow", "ground_dirt", "planks_old", "log_weathered", "mud_tex", "water"]:
		M[n] = load(MAT_DIR + n + ".tres")
	for n in ["izba", "izba_long", "izba_tall", "izba_lean", "izba_small", "hall", "tower", "barn", "shed", "workshop",
			"palisade", "gate", "barricade", "greenhouse", "wind_turbine", "spruce", "pine", "birch", "dead_tree", "bush",
			"rock", "fire", "well", "woodpile", "table", "tractor", "garden", "fence", "fence_broken", "fence_gate", "border_post", "sign",
			"planks", "basket", "mushroom", "berries", "bandage",
			"item_flask", "item_matches", "item_blanket", "item_rope", "item_compass", "item_rusks",
			"item_dried_fish", "item_canned", "item_herbs", "item_screwdriver", "item_hairpin", "junk", "locked_box",
			"spruce_b", "pine_b", "birch_b", "rock_small", "rock_big", "palisade_boarded", "palisade_patched",
			"barrel", "crates", "cart", "bench", "hay_bale", "stump", "log_fallen", "table_long"]:
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
	root.set("map_rect", Rect2(2, -22, 116, 128))
	root.set("camera_start", Vector3(44, 0, 47))
	_env()
	_ground()
	_village()
	_forest()
	_raid()
	_characters()
	_items()
	_details()
	_clear_overlaps()
	_fence_mend()
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
	# в изометрии камера далеко (~32 м): плотный туман выцвечивал всю картинку
	env.fog_density = 0.001
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
	_nz.seed = 2062
	_nz.frequency = 0.06
	_nz.fractal_octaves = 3
	_nf.seed = 77
	_nf.frequency = 0.35
	_nf.fractal_octaves = 2
	# дороги: от северных ворот в лес, главная улица, проулки, к западной черте.
	# Их не кладём полосами — они рисуются в карту смешивания земли с рваным краем.
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
	roads.append(PLAZA)
	ground_mat = _ground_material()
	# земля кусками: внутри рва и рамка снаружи, а в щели — сам ров
	var ro := PAL.grow(DITCH_OUT)
	var ri := PAL.grow(DITCH_IN)
	var big := SPLAT_RECT
	for r in [ri, Rect2(big.position.x, big.position.y, big.size.x, ro.position.y - big.position.y),
			Rect2(big.position.x, ro.end.y, big.size.x, big.end.y - ro.end.y),
			Rect2(big.position.x, ro.position.y, ro.position.x - big.position.x, ro.size.y),
			Rect2(ro.end.x, ro.position.y, big.end.x - ro.end.x, ro.size.y)]:
		var gp := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = r.size
		gp.mesh = pm
		gp.material_override = ground_mat
		gp.position = Vector3(r.get_center().x, 0, r.get_center().y)
		ground.add_child(gp)
		gp.owner = root
	# за краем карты земля продолжается (иначе по краям видна пустота)
	var far := MeshInstance3D.new()
	far.name = "FarGround"
	var fpm := PlaneMesh.new()
	fpm.size = Vector2(700, 700)
	far.mesh = fpm
	far.material_override = ground_mat
	far.position = Vector3(60, -0.03, 54)
	ground.add_child(far)
	far.owner = root
	_moat()


## Дорожка-полоса. Земляные дороги только запоминаем — их рисует карта смешивания.
func strip(parent: Node, a: Vector2, b: Vector2, w: float, mat: String, y := 0.012) -> void:
	if mat == "ground_dirt":
		road_segs.append([a, b, w / 2.0])
	else:
		super.strip(parent, a, b, w, mat, y)
	roads.append(Rect2(minf(a.x, b.x) - w / 2.0, minf(a.y, b.y) - w / 2.0, absf(b.x - a.x) + w, absf(b.y - a.y) + w))


## Материал земли: шейдер смешивает траву, луг, дорогу и грязь по карте смешивания
func _ground_material() -> ShaderMaterial:
	var tex := ImageTexture.create_from_image(_paint_splat())
	ResourceSaver.save(tex, "res://assets/textures/nakharro_splat.res")
	var m := ShaderMaterial.new()
	m.shader = load("res://assets/shaders/ground_blend.gdshader")
	var t := "res://assets/textures/"
	for pair in [["grass", "grass_dark"], ["meadow", "meadow"], ["dirt", "dirt_road"], ["mud", "mud"]]:
		m.set_shader_parameter(pair[0] + "_tex", load(t + pair[1] + ".png"))
		m.set_shader_parameter(pair[0] + "_n", load(t + pair[1] + "_n.png"))
	m.set_shader_parameter("splat", load("res://assets/textures/nakharro_splat.res"))
	m.set_shader_parameter("splat_rect", Vector4(SPLAT_RECT.position.x, SPLAT_RECT.position.y, SPLAT_RECT.size.x, SPLAT_RECT.size.y))
	ResourceSaver.save(m, MAT_DIR + "ground_nakharro.tres")
	return load(MAT_DIR + "ground_nakharro.tres")


## Карта смешивания: R — выгоревший луг, G — дорога, B — грязь.
## Все границы — с шумом, поэтому трава переходит в луг и грязь пятнами, а не по линейке.
func _paint_splat() -> Image:
	var w := int(SPLAT_RECT.size.x * SPLAT_PPM)
	var h := int(SPLAT_RECT.size.y * SPLAT_PPM)
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	var ro := PAL.grow(DITCH_OUT)
	var meadow := Rect2(12, 19.5, 100, ro.position.y - 19.5)
	var ri := PAL.grow(DITCH_IN)
	for j in h:
		for i in w:
			var p := SPLAT_RECT.position + Vector2(i + 0.5, j + 0.5) / SPLAT_PPM
			var n := _nz.get_noise_2dv(p)
			var f := _nf.get_noise_2dv(p)
			# луг перед воротами и выгоревшие пятна снаружи частокола
			var m := smoothstep(-2.5, 3.0, _sd_rect(p, meadow) + n * 4.0 + f * 1.2)
			if not ri.has_point(p):
				m = maxf(m, smoothstep(0.15, 0.45, n) * 0.85)
			# дороги
			var d := 1.0 - smoothstep(-0.9, 0.9, -_sd_rect(p, PLAZA) + f * 0.8)
			for sg in road_segs:
				var dist := _seg_dist(p, sg[0], sg[1]) - float(sg[2])
				d = maxf(d, 1.0 - smoothstep(-0.6, 0.8, dist + f * 0.7 + n * 0.3))
			# грязь: ров и вывороченная земля по его краям, болота, разбитая колея у ворот
			var u := 0.0
			var cd := _ring_dist(p)
			if cd > 0.0:
				u = 1.0 - smoothstep(0.0, 1.4, maxf(DITCH_IN - cd, cd - DITCH_OUT) + f * 0.7 + n * 0.4)
			for z in SWAMPS:
				u = maxf(u, smoothstep(-1.5, 2.0, _sd_rect(p, z) + n * 3.0) * smoothstep(-0.2, 0.35, f + n * 0.5))
			u = maxf(u, smoothstep(-1.0, 2.0, _sd_rect(p, GATE_MUD) + n * 2.0) * smoothstep(-0.1, 0.4, f))
			img.set_pixel(i, j, Color(m, d, u))
	return img


## Расстояние со знаком до края прямоугольника: внутри > 0, снаружи < 0
func _sd_rect(p: Vector2, r: Rect2) -> float:
	var dx := minf(p.x - r.position.x, r.end.x - p.x)
	var dz := minf(p.y - r.position.y, r.end.y - p.y)
	if dx >= 0.0 and dz >= 0.0:
		return minf(dx, dz)
	return -Vector2(minf(dx, 0.0), minf(dz, 0.0)).length()


func _seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return p.distance_to(a + ab * t)


## Насколько точка отстоит от частокола наружу (квадратное кольцо, как у рва); внутри — 0
func _ring_dist(p: Vector2) -> float:
	var dx := maxf(maxf(PAL.position.x - p.x, p.x - PAL.end.x), 0.0)
	var dz := maxf(maxf(PAL.position.y - p.y, p.y - PAL.end.y), 0.0)
	return maxf(dx, dz)


## Высота земли во рву: неровный, будто выкопанный вручную профиль
func _ditch_h(x: float, z: float) -> float:
	var t := (_ring_dist(Vector2(x, z)) - DITCH_IN) / (DITCH_OUT - DITCH_IN)
	if t <= 0.0 or t >= 1.0:
		return 0.0
	var n := _nz.get_noise_2d(x * 3.0, z * 3.0)
	var f := _nf.get_noise_2d(x * 1.5, z * 1.5)
	var tt := t + n * 0.08
	var shape := smoothstep(0.0, 0.42, tt) * (1.0 - smoothstep(0.58, 1.0, tt))
	var edge := smoothstep(0.0, 0.06, t) * (1.0 - smoothstep(0.94, 1.0, t))
	var lumps := (f * 0.13 + n * 0.06) * sin(t * PI)
	return (-DITCH_DEPTH * shape + lumps) * edge


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
	put(P.table_long, vil, Vector3(55, 0, 57), 0.3, "SquareTable")
	# хозяйство
	put(P.barn, vil, Vector3(80, 0, 61), -PI / 2.0, "Barn")
	put(P.workshop, vil, Vector3(32, 0, 64), PI / 2.0, "Workshop")
	put(P.tractor, vil, Vector3(34, 0, 70), 0.6, "Tractor")
	put(P.greenhouse, vil, Vector3(56, 0, 86), 0.0, "Greenhouse1")
	put(P.greenhouse, vil, Vector3(63.5, 0, 86), 0.0, "Greenhouse2")
	put(P.wind_turbine, vil, Vector3(96, 0, 62), 0.4, "WindTurbine")
	for p in [Vector3(28, 0, 37.5), Vector3(66.5, 0, 41), Vector3(97, 0, 46.5), Vector3(40, 0, 88.5), Vector3(96, 0, 88)]:
		put(P.shed, vil, p, randf_range(-0.2, 0.2))
	put(P.woodpile, vil, Vector3(78, 0, 35.7), 0.05, "Woodpile")
	put(P.woodpile, vil, Vector3(40.8, 0, 37.8), -0.2)
	put(P.table, vil, Vector3(41.5, 0, 44.2), 0.0, "TableDed")
	# огороды за домами и поле на юге
	for p in [Vector3(36, 0, 37), Vector3(88, 0, 36.8), Vector3(42.5, 0, 55), Vector3(92, 0, 56), Vector3(50, 0, 65),
			Vector3(89.5, 0, 66.5), Vector3(46, 0, 88)]:
		put(P.garden, vil, p, 0.0)
	for gx in range(4):
		for gz in range(2):
			put(P.garden, vil, Vector3(72 + gx * 5.5, 0, 84.5 + gz * 3.8), 0.0)
	# забор Степана вдоль улицы перед его двором: целые пролёты и дыра
	# (перед дверью избы, x ≈ 73.9, — проход)
	put(P.fence, vil, Vector3(70.4, 0, 44.1), 0.0, "Fence1")
	put(P.fence_gate, vil, Vector3(73.9, 0, 44.1), 0.0, "FenceGate")
	put(P.fence_broken, vil, Vector3(77.4, 0, 44.1), 0.0, "FenceGap")
	put(P.fence, vil, Vector3(81.2, 0, 44.1), 0.0, "Fence3")
	# частокол с воротами (север и запад) и вышками
	var pal := group(root, "Palisade")
	var x := PAL.position.x + 2.0
	while x < PAL.end.x:
		if absf(x - N_GATE_X) > 2.6:
			put(_pal(), pal, Vector3(x, 0, PAL.position.y), 0.0)
		put(_pal(), pal, Vector3(x, 0, PAL.end.y), PI)
		x += 4.0
	var zs := []
	var z := PAL.position.y + 2.0
	while z < PAL.end.y - 2.5:
		zs.append(z)
		z += 4.0
	zs.append(PAL.end.y - 2.0)
	for zz in zs:
		if absf(zz - W_GATE_Z) > 2.6:
			put(_pal(), pal, Vector3(PAL.position.x, 0, zz), PI / 2.0)
		put(_pal(), pal, Vector3(PAL.end.x, 0, zz), -PI / 2.0)
	put(P.gate, pal, Vector3(N_GATE_X, 0, PAL.position.y), 0.0, "GateNorth")
	put(P.gate, pal, Vector3(PAL.position.x, 0, W_GATE_Z), PI / 2.0, "GateWest")
	put(P.tower, pal, Vector3(54.5, 0, 36.5), 0.0, "TowerNorth")
	put(P.tower, pal, Vector3(97.5, 0, 36.5), 0.0, "TowerNE")
	put(P.tower, pal, Vector3(26.5, 0, 52.5), 0.0, "TowerWest")
	put(P.tower, pal, Vector3(26.5, 0, 89.5), 0.0, "TowerSW")
	# кусты и берёзы во дворах
	for p in [Vector3(58, 0, 51), Vector3(69, 0, 50), Vector3(55, 0, 74), Vector3(70, 0, 78), Vector3(30, 0, 72), Vector3(97, 0, 78)]:
		put(P.bush, vil, p, randf() * TAU)
	for p in [Vector3(57, 0, 47.5), Vector3(72.5, 0, 67.5), Vector3(42, 0, 64)]:
		put(P.birch, vil, p, randf() * TAU, "", 1.1)
	# граница на западе
	var border := group(root, "Border")
	for zz in [W_GATE_Z - 5.0, W_GATE_Z - 2.5, W_GATE_Z + 2.5, W_GATE_Z + 5.0]:
		put(P.border_post, border, Vector3(5.2, 0, zz))
	put(P.sign, border, Vector3(6.5, 0, W_GATE_Z - 2.8), PI / 2.0 - 0.15, "Sign")


# ---------------- лес ----------------
func _forest() -> void:
	var forest := group(root, "Forest")
	var trees := [P.spruce, P.spruce_b, P.spruce, P.spruce_b, P.pine, P.pine_b, P.birch, P.birch_b, P.dead_tree]
	var moat_zone := PAL.grow(DITCH_OUT + 1.0)
	var keep := [Vector2(92, 10)]
	for f in FOOD:
		keep.append(Vector2(f[1].x, f[1].z))
		keep.append(Vector2(f[1].x, f[1].z) + HIDE_OFF)
	var n := 0
	for i in 8000:
		var x := randf_range(3, 117)
		var z := randf_range(-20, 105)
		var north := z < 23.5
		var edge := x < 19 or x > 105 or z > 97
		if not (north or edge):
			continue
		# тропа в лес и дорога к черте
		if absf(x - N_GATE_X) < 2.8 and z > 14:
			continue
		# лесные тропинки, по которым ходят стража и жители
		var on_trail := false
		for tr in TRAILS:
			if _seg_dist(Vector2(x, z), tr[0], tr[1]) < 1.6:
				on_trail = true
		if on_trail:
			continue
		if Vector2(x, z).distance_to(Vector2(64, 8)) < 3.0 or (z < 16 and absf(x - (N_GATE_X + (16 - z) * 0.25)) < 2.0):
			continue
		if absf(z - W_GATE_Z) < 3.0 and x < 26:
			continue
		var ok := Vector2(x, z).distance_to(Vector2(92, 10)) > 6.5  # поляна пса
		ok = ok and Vector2(x, z).distance_to(Vector2(46, 16)) > 5.0  # поляна охотника
		ok = ok and not (x > 66 and x < 84 and z > 16.0)  # стрельбище за воротами
		ok = ok and not moat_zone.has_point(Vector2(x, z))  # у рва — голо
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
		if n > 950:
			break
	for i in 30:
		put([P.rock, P.rock_big, P.rock][i % 3], forest, Vector3(randf_range(6, 114), 0, randf_range(-18, 21)), randf() * TAU, "", randf_range(0.7, 1.2))
	_forest_edge()


## Пояс тайги за границей карты: туда не пройти, но и чёрной пустоты не видно
func _forest_edge() -> void:
	var edge := group(root, "ForestEdge")
	edge.set_meta("no_xray", true)
	var mr: Rect2 = root.get("map_rect")
	var inner := mr.grow(0.5)
	var outer := mr.grow(30.0)
	var trees := [P.spruce, P.spruce_b, P.spruce, P.pine, P.pine_b, P.birch, P.spruce_b]
	var placed := 0
	for i in 5000:
		var x := randf_range(outer.position.x, outer.end.x)
		var z := randf_range(outer.position.y, outer.end.y)
		var p := Vector2(x, z)
		if inner.has_point(p):
			continue
		# просека к старой черте на западе остаётся открытой
		if x < inner.position.x and absf(z - W_GATE_Z) < 3.5:
			continue
		# у самой границы гуще, дальше — реже (там всё равно всё в дымке)
		var d := -_sd_rect(p, inner)
		if randf() < clampf(d / 40.0, 0.0, 0.6):
			continue
		put(trees[randi() % trees.size()], edge, Vector3(x, 0, z), randf() * TAU, "", randf_range(0.9, 1.4))
		placed += 1
		if placed >= 700:
			break


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
	character(chars, "Kid", "kid", Vector3(66.5, 0, 58.2), -0.8, {"dialog": "kid", "groups": M_,
		"patrol": PackedVector3Array([Vector3(66.5, 0, 58.2), Vector3(60.5, 0, 62.5), Vector3(58.5, 0, 60), Vector3(64, 0, 55.5)])})
	character(chars, "Wolf", "wolf", Vector3(92, 0, 10), 1.2, {"hostile": true, "aggro_radius": 7.0, "groups": M_})
	# жители утром: часовые, огородницы, мастер, старики на площади
	character(chars, "GuardN", "defender", Vector3(60.2, 0, 37.2), PI, {"display_name": "Часовой Эрчим", "dialog": "guard", "armed": true, "groups": M_})
	character(chars, "GuardW", "defender_f", Vector3(27.6, 0, W_GATE_Z - 1.6), -PI / 2.0, {"display_name": "Часовая Сардана", "armed": true, "groups": M_})
	character(chars, "Gardener1", "villager_f", Vector3(73.5, 0, 83.2), 0.6, {"display_name": "Огородница", "groups": M_})
	character(chars, "Gardener2", "villager_f", Vector3(84.5, 0, 87.2), -2.2, {"display_name": "Огородница", "groups": M_})
	character(chars, "Smith", "villager", Vector3(35.6, 0, 62.5), -PI / 2.0, {"display_name": "Мастер Тимир", "dialog": "smith", "groups": M_})
	# за длинным столом на площади: двое стариков с одной стороны, картёжник напротив
	var tbl: Node3D = root.get_node("Village/SquareTable")
	var s1 := _seat(tbl, -0.6, 1.0)
	var s2 := _seat(tbl, 0.6, 1.0)
	var s3 := _seat(tbl, 0.2, -1.0)
	character(chars, "Elder1", "elder", s1[0], s1[1], {"dialog": "elder", "start_pose": "sit", "groups": M_})
	character(chars, "Elder2", "villager_f", s2[0], s2[1], {"display_name": "Старуха", "start_pose": "sit", "groups": M_})
	# прохожие ходят по улицам и рассказывают слухи
	character(chars, "Villager3", "villager", Vector3(40, 0, 46.3), 1.4, {"display_name": "Прохожий", "dialog": "rumors", "groups": M_,
		"patrol": PackedVector3Array([Vector3(40, 0, 46.3), Vector3(90, 0, 46.3)])})
	character(chars, "Villager4", "villager_f", Vector3(88, 0, 76.4), -0.5, {"display_name": "Прохожая", "dialog": "rumors", "groups": M_,
		"patrol": PackedVector3Array([Vector3(88, 0, 76.4), Vector3(40, 0, 76.4)])})
	character(chars, "WaterCarrier", "villager", Vector3(67.5, 0, 58.6), 0.0, {"display_name": "Водонос", "dialog": "rumors", "groups": M_,
		"patrol_wait": 2.5, "patrol": PackedVector3Array([Vector3(67.5, 0, 58.6), Vector3(62, 0, 58.6), Vector3(62, 0, 47.2),
			Vector3(52, 0, 47.2), Vector3(62, 0, 47.2), Vector3(62, 0, 58.6)])})
	# начальные задания: разговоры, проверки навыков, драка, стрельбище
	character(chars, "Nyurguyana", "girl", Vector3(70.3, 0, 54.2), -0.9, {"dialog": "girl", "groups": M_})
	character(chars, "Gambler", "gambler", s3[0], s3[1], {"dialog": "gambler", "start_pose": "sit", "groups": M_})
	var F_ := ["phase_morning", "forest_folk"]
	character(chars, "Hunter", "hunter", Vector3(46, 0, 16), 0.5, {"dialog": "hunter", "groups": F_})
	character(chars, "Shooter", "shooter", Vector3(74, 0, 26.0), PI, {"dialog": "shooter", "armed": true, "groups": F_})
	# в лесу днём людно: стража обходит опушку, жители собирают ягоды и хворост.
	# К вечеру все уходят домой.
	character(chars, "ForestGuard1", "defender", Vector3(50, 0, 20), PI / 2.0, {"display_name": "Дозорный Айхал", "dialog": "rumors", "armed": true,
		"groups": F_, "patrol": PackedVector3Array([Vector3(50, 0, 20), Vector3(78, 0, 20)]), "patrol_wait": 6.0})
	character(chars, "ForestGuard2", "defender_f", Vector3(56, 0, 4), 0.0, {"display_name": "Дозорная Кэрэчээнэ", "dialog": "rumors", "armed": true,
		"groups": F_, "patrol": PackedVector3Array([Vector3(56, 0, 4), Vector3(60, 0, -11), Vector3(56, 0, 4), Vector3(72, 0, -6), Vector3(83, 0, 1.5)]), "patrol_wait": 5.0})
	character(chars, "Woodcutter", "villager", Vector3(47, 0, 8), 1.0, {"display_name": "Дровосек", "dialog": "rumors",
		"groups": F_, "patrol": PackedVector3Array([Vector3(47, 0, 8), Vector3(55, 0, 4.5)]), "patrol_wait": 8.0})
	character(chars, "BerryWoman", "villager_f", Vector3(79, 0, -3.5), -0.6, {"display_name": "Ягодница", "dialog": "rumors",
		"groups": F_, "patrol": PackedVector3Array([Vector3(79, 0, -3.5), Vector3(73, 0, -7), Vector3(68, 0, -4)]), "patrol_wait": 7.0})
	# засада: нападавший с монтировкой появится, когда герой возьмёт последнюю находку
	character(chars, "Prowler", "prowler", Vector3(100, 0, -18), 0.0, {"groups": ["ambush"]})
	var izba9: Node3D = root.get_node("Village/Izba9")
	# больная лежит на кровати головой к подушке (поза «лёжа» вытянута назад от точки ног)
	var bed: Vector3 = izba9.get_node("Slot_bed").position
	var sick_at: Vector3 = izba9.transform * Vector3(bed.x, 0.5, bed.z - 0.3 + 0.47)
	character(chars, "Sick", "sick", sick_at, izba9.rotation.y, {"dialog": "sick", "start_pose": "down", "groups": M_})
	var ti := 0
	for p in [Vector3(70.5, 0, 20.8), Vector3(74, 0, 20.2), Vector3(77.5, 0, 21.0)]:
		ti += 1
		character(chars, "Target%d" % ti, "target", p, 0.0, {"groups": ["phase_morning", "range_targets"]})
	# налёт: дед и «чистильщики» у амбара
	character(chars, "DedRaid", "ded_rifle", Vector3(75.0, 0, 61.5), -PI / 2.0, {"dialog": "ded", "dialog_node": "last", "armed": true, "groups": R_})
	character(chars, "SoldierA", "soldier_a", Vector3(72.0, 0, 58.2), PI * 0.2, {"hostile": true, "aggro_radius": 8.5, "squad": "cleaners", "groups": R_})
	character(chars, "SoldierB", "soldier_b", Vector3(72.8, 0, 64.4), -PI * 0.3, {"hostile": true, "aggro_radius": 8.5, "squad": "cleaners", "groups": R_})
	# защитники держат ворота
	character(chars, "DeadDefenderN", "defender_f", Vector3(58.2, 0, 40.6), 2.4, {"start_dead": true, "display_name": "Защитница", "groups": R_})
	for c in [["DefenderW1", "defender", Vector3(29.6, 0, W_GATE_Z - 2.4), -PI / 2.0], ["DefenderW2", "defender", Vector3(29.1, 0, W_GATE_Z + 2.0), -PI / 2.0 - 0.2]]:
		var ch := character(chars, c[0], c[1], c[2], c[3], {"dialog": "defender", "armed": true, "groups": R_})
		ch.add_to_group("defenders", true)
	character(chars, "WoundedDefender", "villager", Vector3(60.5, 0, 57.8), 1.0, {"display_name": "Раненый", "start_pose": "down", "groups": R_})
	# у северных ворот: часовой зовёт на помощь, пленные на коленях, двое нападавших
	var gg := character(chars, "GateGuard", "defender", Vector3(62.0, 0, 36.4), 0.45, {"display_name": "Часовой Эрчим", "armed": true, "groups": R_})
	gg.add_to_group("defenders", true)
	character(chars, "Doomed1", "villager", Vector3(60.9, 0, 43.2), PI, {"display_name": "Житель", "start_pose": "yield", "groups": R_})
	character(chars, "Doomed2", "villager_f", Vector3(63.2, 0, 43.5), PI + 0.2, {"display_name": "Жительница", "start_pose": "yield", "groups": R_})
	character(chars, "Executioner", "executioner", Vector3(62.1, 0, 45.6), PI, {"squad": "gate", "armed": true, "groups": R_})
	character(chars, "GateRaider", "raider_gun", Vector3(64.2, 0, 40.8), PI * 1.15, {"display_name": "Нападавший", "squad": "gate", "armed": true, "groups": R_})
	# у старой черты — раненый нападавший (появится, когда тела обысканы)
	character(chars, "ExitRaider", "exit_raider", Vector3(11.5, 0, W_GATE_Z + 2.2), -PI / 2.0, {"groups": ["exit_guard"]})
	# мародёры, которые ещё шарят по дворам (можно обойти крадучись или напасть первым)
	character(chars, "LooterA", "raider", Vector3(44.0, 0, 76.8), 0.8, {"hostile": true, "aggro_radius": 6.0, "squad": "looters", "groups": R_})
	character(chars, "LooterB", "raider", Vector3(47.2, 0, 77.4), -0.6, {"hostile": true, "aggro_radius": 6.0, "squad": "looters", "groups": R_})
	character(chars, "Gunman", "raider_gun", Vector3(94.5, 0, 67.8), PI, {"hostile": true, "aggro_radius": 6.5, "squad": "gunman", "groups": R_})
	# погибшие жители
	character(chars, "DeadStepan", "stepan", Vector3(70.5, 0, 46.3), 0.4, {"start_dead": true, "display_name": "Степан", "groups": R_})
	character(chars, "DeadVarvara", "varvara", Vector3(76.2, 0, 66.4), 2.2, {"start_dead": true, "display_name": "Тётка Варвара", "groups": R_})
	character(chars, "DeadVillager1", "villager", Vector3(52.5, 0, 55.5), 1.0, {"start_dead": true, "groups": R_})
	character(chars, "DeadVillager2", "villager_f", Vector3(36.5, 0, 73.4), -0.6, {"start_dead": true, "groups": R_})
	# нападавшие: сюжетные тела с модулями и те, кого положили у ворот
	character(chars, "Raider1", "raider_dead_1", Vector3(60.2, 0, 26.4), 2.6, {"start_dead": true, "groups": R_})
	character(chars, "Raider2", "raider_dead_2", Vector3(41.5, 0, 58.6), -1.4, {"start_dead": true, "groups": R_})
	character(chars, "Raider3", "raider_dead_3", Vector3(84.5, 0, 64.8), 0.9, {"start_dead": true, "groups": R_})
	character(chars, "Raider4", "raider_dead_4", Vector3(16.5, 0, 62.8), -2.1, {"start_dead": true, "groups": R_})
	var i := 5
	for p in [Vector3(64.8, 0, 26.8), Vector3(58.0, 0, 27.0), Vector3(67.5, 0, 27.5), Vector3(16.8, 0, 57.4),
			Vector3(15.2, 0, 64.6), Vector3(101.8, 0, 52.0), Vector3(54.5, 0, 26.2)]:
		character(chars, "Raider%d" % i, "raider_dead", p, randf() * TAU, {"start_dead": true, "groups": R_})
		i += 1


## Место на скамейке длинного стола: x — вдоль стола, side — сторона (+1 / −1).
## Возвращает [позиция, поворот] так, чтобы сидящий смотрел на стол.
## SIT_FWD — насколько точка «ног» клипа Sitting_Idle впереди таза.
const SIT_FWD := 0.31


func _seat(table: Node3D, x: float, side: float) -> Array:
	var face := (table.transform.basis * Vector3(0, 0, -side)).normalized()
	var p: Vector3 = table.transform * Vector3(x, 0, side * 0.78) + face * SIT_FWD
	return [Vector3(p.x, 0, p.z), atan2(face.x, face.z)]


# ---------------- предметы и отметки ----------------
func _items() -> void:
	var items := group(root, "Items")
	item(items, P.planks, "Planks", Vector3(76.9, 0, 37.1), ["phase_morning"])
	var basket := item(items, P.basket, "Basket", Vector3(42.1, 0.84, 44.2), ["phase_morning"])
	basket.set("pick_size", Vector3(0.7, 0.9, 0.7))
	var hi := 0
	for f in FOOD:
		item(items, P.mushroom if String(f[0]).begins_with("Mushroom") else P.berries, f[0], f[1])
		# густой куст рядом — в нём можно спрятаться, когда начнётся
		hi += 1
		var hb := _item_base("HideBush%d" % hi)
		hb.set("kind", "use")
		hb.set("label", "Густые кусты")
		hb.set("pick_size", Vector3(1.8, 1.3, 1.8))
		hb.position = f[1] + Vector3(HIDE_OFF.x, 0, HIDE_OFF.y)
		items.add_child(hb)
		hb.owner = root
		for k in 3:
			put(P.bush, hb, Vector3(randf_range(-0.5, 0.5), 0, randf_range(-0.5, 0.5)), randf() * TAU, "", randf_range(1.2, 1.5))
	item(items, P.bandage, "BandageRaid", Vector3(61.5, 0, 58.8), ["phase_raid"])
	item(items, P.bandage, "BandageGate", Vector3(63.2, 0, 40.4), ["phase_raid"])
	# вещи в дорогу — по избам, в доме собраний и в амбаре (метки Slot_* внутри построек)
	for it in [["IzbaDed", "table", "flask"], ["IzbaDed", "stove", "matches"], ["IzbaDed", "bed", "blanket"],
			["IzbaDed", "chest", "compass"], ["Izba2", "table", "rusks"], ["Izba3", "chest", "rope"],
			["IzbaStepan", "table", "dried_fish"], ["Izba5", "chest", "canned"], ["Izba7", "table", "herbs"],
			["Izba8", "bed", "rusks"], ["Izba9", "floor", "rope"], ["Izba10", "table", "canned"],
			["Izba12", "chest", "dried_fish"], ["Izba13", "stove", "matches"], ["Izba15", "bed", "blanket"],
			["Hall", "table", "bandage"], ["Hall", "table2", "rusks"], ["Hall", "chest", "canned"],
			["Barn", "sacks", "rusks"], ["Barn", "chest", "canned"], ["Barn", "floor", "herbs"],
			["Izba7", "bed", "hairpin"], ["Izba12", "table", "hairpin"]]:
		var house: Node3D = root.get_node("Village/" + it[0])
		var slot: Node3D = house.get_node("Slot_" + it[1])
		var pos: Vector3 = house.transform * slot.position
		var ps: PackedScene = P.bandage if it[2] == "bandage" else P["item_" + it[2]]
		item(items, ps, "Take_%s_%s" % [it[0], it[1]], pos)
	# отвёртка у мастерской — вместе со шпилькой станет отмычкой для сундука
	var ws_: Node3D = root.get_node("Village/Workshop")
	item(items, P.item_screwdriver, "Take_Workshop", ws_.transform * Vector3(1.2, 0, 3.4))
	# амбар: три кучи хлама и запертый сундук
	var barn: Node3D = root.get_node("Village/Barn")
	var ji := 0
	for lp in [Vector3(-1.0, 0, 1.3), Vector3(1.6, 0, 0.9), Vector3(-2.9, 0, 1.6)]:
		ji += 1
		put(P.junk, items, barn.transform * lp, randf() * TAU, "Junk%d" % ji)
	put(P.locked_box, items, barn.transform * Vector3(0.8, 0, -2.2), barn.rotation.y, "LockedBox")
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
	marker(root, "MarkForest", Vector3(62, 0, 0), "Лес")
	marker(root, "MarkBorder", Vector3(6, 0, W_GATE_Z), "Черта")


# ---------------- забор Степана: дыра, которую можно заделать досками ----------------
## FenceFixed — целый пролёт на месте сломанного, до починки выключен (nakharro.gd);
## FenceMend — дыра, по клику на неё герой прибивает доски.
func _fence_mend() -> void:
	var gap: Node3D = root.get_node("Village/FenceGap")
	var fixed := put(P.fence, gap.get_parent(), gap.position, gap.rotation.y, "FenceFixed")
	fixed.visible = false
	var m := _item_base("FenceMend")
	m.set("kind", "use")
	m.set("label", "Дыра в заборе")
	m.set("pick_size", Vector3(1.7, 1.1, 0.35))
	m.position = gap.transform * Vector3(1.0, 0, 0)
	m.rotation.y = gap.rotation.y
	root.get_node("Items").add_child(m)
	m.owner = root


# ---------------- проверка: ничего не растёт внутри построек ----------------
## Убирает деревья, кусты и камни, попавшие в постройки (с запасом 1,5 м на крону),
## и предупреждает о персонажах, стоящих в стенах.
func _clear_overlaps() -> void:
	var boxes := []
	for grp in ["Village", "Palisade", "RaidFX"]:
		for b in root.get_node(grp).get_children():
			var sp := String(b.scene_file_path)
			if sp == "" or _is_plant(sp):
				continue
			var body := b.get_node_or_null("Collision")
			if body == null:
				continue
			for cs in body.get_children():
				if cs is CollisionShape3D and cs.shape is BoxShape3D:
					boxes.append([b.transform * body.transform * cs.transform, (cs.shape as BoxShape3D).size])
	var removed := 0
	for grp in ["Village", "Forest"]:
		for t in root.get_node(grp).get_children():
			if not _is_plant(String(t.scene_file_path)):
				continue
			if _inside(boxes, t.position, 1.5):
				t.get_parent().remove_child(t)
				t.free()
				removed += 1
	print("  убрано деревьев/кустов из построек: ", removed)
	var gone := []
	for f in root.get_node("Village").get_children():
		var fp := String(f.scene_file_path)
		if not (fp.ends_with("/fence.tscn") or fp.ends_with("/fence_broken.tscn")):
			continue
		# если пролёт задевает постройку — отодвигаем его от домов (вдоль его нормали)
		var ok := false
		var base: Vector3 = f.position
		for step in 12:
			f.position = base + f.transform.basis.z * (0.15 * step)
			var hit := false
			for dx in [-1.9, -1.0, 0.0, 1.0, 1.9]:
				if _inside(boxes, f.transform * Vector3(dx, 0, 0), 0.15):
					hit = true
					break
			if not hit:
				ok = true
				break
		if not ok:
			f.position = base
			push_warning("забор заходит в постройку: " + String(f.name))
		# пролёт напротив двери убираем — остаётся проход-калитка
		for h in root.get_node("Village").get_children():
			if not ("door" in h and "inner" in h):
				continue
			var dp: Vector3 = h.transform * (h.get("door") + Vector3(0, 0, 1.2))
			var a: Vector3 = f.transform * Vector3(-2.0, 0, 0)
			var b: Vector3 = f.transform * Vector3(2.0, 0, 0)
			var ab := b - a
			var t := clampf((dp - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
			if (a + ab * t).distance_to(dp) < 1.0:
				gone.append(f)
				break
	for f in gone:
		print("  пролёт забора перед дверью убран: ", f.name)
		f.get_parent().remove_child(f)
		f.free()
	for ch in root.get_node("Characters").get_children():
		if _inside(boxes, ch.position, 0.0) and ch.position.y < 0.2:
			push_warning("персонаж в стене: " + String(ch.name))
		var rd := _ring_dist(Vector2(ch.position.x, ch.position.z))
		if rd > DITCH_IN - 0.3 and rd < DITCH_OUT + 0.3:
			push_warning("персонаж во рву или на мосту: " + String(ch.name))


func _is_plant(path: String) -> bool:
	for k in ["birch", "bush", "spruce", "pine", "dead_tree", "larch", "rock"]:
		if path.ends_with("/" + k + ".tscn"):
			return true
	return false


func _inside(boxes: Array, p: Vector3, margin: float) -> bool:
	for bx in boxes:
		var l: Vector3 = (bx[0] as Transform3D).affine_inverse() * Vector3(p.x, 0.5, p.z)
		var h: Vector3 = bx[1] / 2.0 + Vector3(margin, 5.0, margin)
		if absf(l.x) < h.x and absf(l.z) < h.z:
			return true
	return false


func _pal() -> PackedScene:
	var r := randf()
	return P.palisade_boarded if r < 0.15 else (P.palisade_patched if r < 0.3 else P.palisade)


# ---------------- ров с мостами ----------------
## Ров — кольцо за частоколом: неровная выкопанная земля (сетка с шумом),
## на дне мутная вода. Поперёк — невидимая стена (слой препятствий), кроме мостов у ворот.
func _moat() -> void:
	var moat := group(root, "Moat")
	moat.set_meta("no_xray", true)
	var body := StaticBody3D.new()
	body.name = "Collision"
	body.collision_mask = 0
	moat.add_child(body)
	body.owner = root
	var ro := PAL.grow(DITCH_OUT)
	var ri := PAL.grow(DITCH_IN)
	var mid := (DITCH_IN + DITCH_OUT) / 2.0
	# сетка рва: север и юг во всю ширину (с углами), запад и восток — между ними
	var w := DITCH_OUT - DITCH_IN
	var parts := [Rect2(ro.position.x, ro.position.y, ro.size.x, w), Rect2(ro.position.x, ri.end.y, ro.size.x, w),
		Rect2(ro.position.x, ri.position.y, w, ri.size.y), Rect2(ri.end.x, ri.position.y, w, ri.size.y)]
	DirAccess.make_dir_recursive_absolute("res://assets/models/terrain")
	for k in parts.size():
		var mi := MeshInstance3D.new()
		mi.name = "Ditch%d" % k
		var path := "res://assets/models/terrain/nakharro_ditch_%d.res" % k
		ResourceSaver.save(_ditch_mesh(parts[k]), path)
		mi.mesh = load(path)
		mi.material_override = ground_mat
		moat.add_child(mi)
		mi.owner = root
	# вода на дне: по полосе на сторону; края прячутся под скатами
	var wy := -DITCH_DEPTH + 0.14
	for sd in [[PAL.position.y - mid, true], [PAL.end.y + mid, true], [PAL.position.x - mid, false], [PAL.end.x + mid, false]]:
		var sz := Vector3(PAL.size.x + 2.0 * mid + 1.3, 0.02, 1.3) if sd[1] else Vector3(1.3, 0.02, PAL.size.y + 2.0 * mid + 1.3)
		var pos := Vector3(PAL.get_center().x, wy, sd[0]) if sd[1] else Vector3(sd[0], wy + 0.004, PAL.get_center().y)
		box(moat, sz, pos, "water").owner = root
	# стены-препятствия и мосты
	var sides := [[PAL.position.y - mid, ro.position.x, ro.end.x, true], [PAL.end.y + mid, ro.position.x, ro.end.x, true],
		[PAL.position.x - mid, ro.position.y, ro.end.y, false], [PAL.end.x + mid, ro.position.y, ro.end.y, false]]
	var bridges := [[0, N_GATE_X], [2, W_GATE_Z]]
	for si in sides.size():
		var sd: Array = sides[si]
		var cuts := [[sd[1], sd[2]]]
		for br in bridges:
			if br[0] == si:
				cuts = [[sd[1], br[1] - 2.4], [br[1] + 2.4, sd[2]]]
				_bridge(moat, sd[0], br[1], sd[3])
		for c in cuts:
			var cs := CollisionShape3D.new()
			var bs := BoxShape3D.new()
			var ln: float = c[1] - c[0]
			var cc: float = (c[0] + c[1]) / 2.0
			bs.size = Vector3(ln, 1.4, w - 0.2) if sd[3] else Vector3(w - 0.2, 1.4, ln)
			cs.shape = bs
			cs.position = Vector3(cc, 0.7, sd[0]) if sd[3] else Vector3(sd[0], 0.7, cc)
			body.add_child(cs)
			cs.owner = root


## Сетка куска рва с шагом 0,25 м; высоты — _ditch_h, поэтому куски и углы стыкуются без щелей
func _ditch_mesh(r: Rect2) -> ArrayMesh:
	var step := 0.25
	var nx := int(round(r.size.x / step))
	var nz := int(round(r.size.y / step))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in nz + 1:
		for i in nx + 1:
			var x := r.position.x + i * step
			var z := r.position.y + j * step
			st.set_uv(Vector2(x, z))
			st.add_vertex(Vector3(x, _ditch_h(x, z), z))
	for j in nz:
		for i in nx:
			var a := j * (nx + 1) + i
			var b := a + 1
			var c := a + nx + 1
			var d := c + 1
			for idx in [a, b, c, b, d, c]:
				st.add_index(idx)
	st.generate_normals()
	st.generate_tangents()
	return st.commit()


## Мост через ров: настил, балки, перила
func _bridge(moat: Node3D, line: float, at: float, along_x: bool) -> void:
	var span := DITCH_OUT - DITCH_IN + 1.4
	var p := Vector3(at, 0.08, line) if along_x else Vector3(line, 0.08, at)
	var deck := Vector3(4.6, 0.12, span) if along_x else Vector3(span, 0.12, 4.6)
	box(moat, deck, p, "planks_old").owner = root
	for k in [-1.6, 0.0, 1.6]:
		var bp := p + (Vector3(k, -0.25, 0) if along_x else Vector3(0, -0.25, k))
		box(moat, Vector3(0.25, 0.3, span) if along_x else Vector3(span, 0.3, 0.25), bp, "log_weathered").owner = root
	for sgn in [-1, 1]:
		var rp := p + (Vector3(sgn * 2.2, 0.55, 0) if along_x else Vector3(0, 0.55, sgn * 2.2))
		box(moat, Vector3(0.1, 0.1, span) if along_x else Vector3(span, 0.1, 0.1), rp, "log_weathered").owner = root
		for q in [-1, 0, 1]:
			var pp := rp + (Vector3(0, -0.28, q * span * 0.45) if along_x else Vector3(q * span * 0.45, -0.28, 0))
			box(moat, Vector3(0.12, 0.6, 0.12), pp, "log_weathered").owner = root


# ---------------- мелочи: трава, болото, лужи, бочки, телеги, пни ----------------
func _multi(parent: Node, mesh: String, xf: Array, nm: String, shadow := false) -> void:
	var mmi := MultiMeshInstance3D.new()
	mmi.name = nm
	mmi.set_script(load("res://scripts/world/scatter.gd"))
	mmi.set("mesh", load("res://assets/models/props/" + mesh + ".res"))
	var t: Array[Transform3D] = []
	for x in xf:
		t.append(x)
	mmi.set("transforms", t)
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mmi)
	mmi.owner = root


func _xf(x: float, z: float, s: float, sy := -1.0) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, randf() * TAU).scaled(Vector3(s, s if sy < 0 else sy, s)), Vector3(x, 0.006, z))


func _free_spot(boxes: Array, x: float, z: float, margin := 0.4) -> bool:
	if _inside(boxes, Vector3(x, 0, z), margin):
		return false
	for r in roads:
		if (r as Rect2).grow(0.3).has_point(Vector2(x, z)):
			return false
	return not PAL.grow(DITCH_OUT + 0.3).has_point(Vector2(x, z)) or PAL.grow(DITCH_IN - 0.3).has_point(Vector2(x, z))


func _details() -> void:
	var det := group(root, "Details")
	var boxes := _building_boxes()
	# --- болота на лугу у опушки: грязь, лужи, камыш, кочки, сухие деревья ---
	var pud := []
	var reeds := []
	var hum := []
	for zone in SWAMPS:
		# сама топь — плоская заплата с водой в окнах и рваным краем
		var sp := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(zone.size.x + 4, zone.size.y + 3)
		sp.mesh = pm
		sp.material_override = load("res://assets/materials/swamp_patch.tres")
		sp.position = Vector3(zone.get_center().x, 0.014, zone.get_center().y)
		sp.rotation.y = PI if randf() < 0.5 else 0.0
		sp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		det.add_child(sp)
		sp.owner = root
		for i in 3:
			pud.append(_xf(randf_range(zone.position.x - 2, zone.end.x + 2), randf_range(zone.position.y - 1, zone.end.y + 1), randf_range(0.6, 1.3), 1.0))
		for i in 70:
			reeds.append(_xf(randf_range(zone.position.x - 1, zone.end.x + 1), randf_range(zone.position.y - 1, zone.end.y + 0.5), randf_range(0.7, 1.2)))
		for i in 35:
			hum.append(_xf(randf_range(zone.position.x, zone.end.x), randf_range(zone.position.y, zone.end.y), randf_range(0.7, 1.3)))
		for i in 3:
			put(P.dead_tree, det, Vector3(randf_range(zone.position.x, zone.end.x), 0, randf_range(zone.position.y, zone.end.y)), randf() * TAU, "", randf_range(0.7, 1.0))
		put(P.log_fallen, det, Vector3(zone.get_center().x + randf_range(-5, 5), 0, zone.get_center().y), randf() * TAU)
	# лужи в колеях у дороги к лесу и перед мостом
	for i in 7:
		pud.append(_xf(N_GATE_X + randf_range(-2.2, 2.2), randf_range(18, 27.5), randf_range(0.5, 1.0), 1.0))
	# лужи на улицах деревни
	for i in 8:
		var r: Rect2 = roads[randi() % roads.size()]
		pud.append(_xf(randf_range(r.position.x, r.end.x), randf_range(r.position.y, r.end.y), randf_range(0.3, 0.7), 1.0))
	# камыш и кочки на дне рва
	var ro := PAL.grow(DITCH_OUT)
	var mid := (DITCH_IN + DITCH_OUT) / 2.0
	for i in 160:
		var t := randf()
		var side := randi() % 4
		var x: float
		var z: float
		if side < 2:
			x = lerpf(ro.position.x, ro.end.x, t)
			z = (PAL.position.y - mid) if side == 0 else (PAL.end.y + mid)
			if side == 0 and absf(x - N_GATE_X) < 3.0:
				continue
			z += randf_range(-0.5, 0.5)
		else:
			z = lerpf(ro.position.y, ro.end.y, t)
			x = (PAL.position.x - mid) if side == 2 else (PAL.end.x + mid)
			if side == 2 and absf(z - W_GATE_Z) < 3.0:
				continue
			x += randf_range(-0.5, 0.5)
		var xf := _xf(x, z, randf_range(0.6, 1.0))
		xf.origin.y = -DITCH_DEPTH + 0.05
		(reeds if i % 3 else hum).append(xf)
	_multi(det, "scatter_puddle", pud, "Puddles")
	_multi(det, "scatter_reeds", reeds, "Reeds", true)
	_multi(det, "scatter_hummock", hum, "Hummocks", true)
	# --- пучки травы по лугу и дворам ---
	var tufts := []
	var guard := 0
	while tufts.size() < 1600 and guard < 20000:
		guard += 1
		var x := randf_range(8, 112)
		var z := randf_range(16, 100)
		if _free_spot(boxes, x, z):
			tufts.append(_xf(x, z, randf_range(0.7, 1.4)))
	_multi(det, "scatter_tuft", tufts, "Tufts")
	# --- в лесу: пни, валежник, мелкие камни ---
	for i in 60:
		var x := randf_range(4, 116)
		var z := randf_range(3, 17)
		if absf(x - N_GATE_X) < 3.0:
			continue
		var kind := i % 4
		var ps: PackedScene = [P.stump, P.log_fallen, P.rock_small, P.rock_small][kind]
		put(ps, det, Vector3(x, 0, z), randf() * TAU, "", randf_range(0.8, 1.2))
	# --- во дворах: бочки, ящики, телеги, скамьи, сено ---
	for d in [["barrel", Vector3(35.6, 0, 67.2)], ["barrel", Vector3(36.3, 0, 67.9)], ["crates", Vector3(84.4, 0, 57.4)],
			["barrel", Vector3(76.8, 0, 56.2)], ["cart", Vector3(72.5, 0, 52.6)], ["hay_bale", Vector3(83.6, 0, 55.4)],
			["hay_bale", Vector3(82.2, 0, 55.2)], ["bench", Vector3(56.2, 0, 62.6)], ["bench", Vector3(68.4, 0, 63.0)],
			["crates", Vector3(57.4, 0, 40.8)], ["cart", Vector3(29.5, 0, 72.5)], ["barrel", Vector3(94.8, 0, 75.4)],
			["crates", Vector3(47.2, 0, 85.2)], ["bench", Vector3(40.6, 0, 43.2)], ["barrel", Vector3(89.6, 0, 43.4)],
			["hay_bale", Vector3(70.2, 0, 90.6)], ["crates", Vector3(97.8, 0, 58.2)]]:
		put(P[d[0]], det, d[1], randf() * TAU)


func _building_boxes() -> Array:
	var boxes := []
	for grp in ["Village", "Palisade"]:
		for b in root.get_node(grp).get_children():
			var sp := String(b.scene_file_path)
			if sp == "" or _is_plant(sp):
				continue
			var bd := b.get_node_or_null("Collision")
			if bd == null:
				continue
			for cs in bd.get_children():
				if cs is CollisionShape3D and cs.shape is BoxShape3D:
					boxes.append([b.transform * bd.transform * cs.transform, (cs.shape as BoxShape3D).size])
		# в дома можно войти — коллизия только по стенам, а занят весь пол
		for b in root.get_node(grp).get_children():
			var inn = b.get("inner")
			if inn is Vector2 and inn != Vector2.ZERO:
				boxes.append([b.transform, Vector3(inn.x + 1.0, 3.0, inn.y + 1.0)])
		# огороды без коллизии — тоже место занято
		for b in root.get_node(grp).get_children():
			if String(b.scene_file_path).ends_with("/garden.tscn"):
				boxes.append([b.transform, Vector3(5, 1, 3)])
	return boxes
