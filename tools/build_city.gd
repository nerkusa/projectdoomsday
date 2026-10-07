extends "res://tools/build_props.gd"
## Каменный Сунгар (бывший посёлок городского типа): дома в 2–4 этажа из штукатурки
## и кирпича, балконы, подъезды; магазины, бар, гостиница, игорный зал на первых этажах —
## туда можно войти (как в избу: верх дома прячется). Плюс то, без чего ПГТ на севере
## не узнать: теплотрасса на опорах, котельная с трубой, водонапорная башня, гаражи,
## ларьки, автобусная остановка, бетонный забор, мёртвый ПАЗик.
## Запуск: godot --headless --path . res://tools/build_city.tscn
## Пишет только эти постройки (scenes/props/st_*.tscn и др.) и свои материалы.

## Высота этажа
const FH := 3.0
## Ширина двери: через проём проходит гекс при любом повороте
const DOOR_W := 1.9
## Ширина проёма во внутренних перегородках: уже 1,9 м гекс может не пролезть
const GAP_W := 1.9


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(MESH_DIR)
	for n in ["trim", "metal_roof", "planks_old", "stone_wall", "metal_dark", "log_weathered", "cloth_sack", "cloth_red",
			"tin", "paper", "rope_mat", "glass", "whitewash", "brass", "tire", "hay", "bread", "fish", "herb", "paint_faded", "paint_white"]:
		M[n] = load(MAT_DIR + n + ".tres")
	M["window"] = load(MAT_DIR + "window.tres")
	M["rust"] = load(MAT_DIR + "rust.tres")
	_city_materials()
	var only := ""
	for a in OS.get_cmdline_user_args():
		only = a
	# дома: [имя, параметры]
	var houses := {
		# гостиница «Вилюй»: вестибюль с конторкой, лестница наверх
		"st_hotel": {"w": 14.0, "d": 9.0, "floors": 3, "mat": "plaster_yellow", "enter": "lobby", "roof": "pitch", "balconies": true},
		# универмаг: торговый зал на первом этаже
		"st_store": {"w": 12.0, "d": 8.0, "floors": 2, "mat": "brick", "enter": "shop", "roof": "flat", "shopfront": true},
		# жилой дом в четыре этажа: подъезд и две квартиры внизу, лестница наверх
		"st_res4": {"w": 16.0, "d": 9.0, "floors": 4, "mat": "plaster_pink", "enter": "stairwell", "roof": "pitch", "balconies": true},
		# общежитие: вахта, красный уголок, лестница
		"st_obshaga": {"w": 12.0, "d": 8.5, "floors": 4, "mat": "brick_white", "enter": "obshaga", "roof": "flat", "balconies": true},
		# бар в кирпичном доме
		"st_bar": {"w": 10.0, "d": 8.0, "floors": 2, "mat": "brick", "enter": "bar", "roof": "flat", "shopfront": true},
		# столовая
		"st_canteen": {"w": 12.0, "d": 8.0, "floors": 2, "mat": "plaster_green", "enter": "canteen", "roof": "pitch", "shopfront": true},
		# Дом культуры: колонны, игорный зал внизу
		"st_dk": {"w": 16.0, "d": 10.0, "floors": 2, "mat": "plaster_yellow", "enter": "hall", "roof": "flat", "portico": true, "fh": 3.4},
		# контора: кирпич, три этажа, флагшток
		"st_office": {"w": 11.0, "d": 7.0, "floors": 3, "mat": "brick", "roof": "flat", "flag": true, "bars": true},
		# глухие жилые дома (в них не войти): разные цвета, этажность, на сваях
		"st_block3a": {"w": 14.0, "d": 8.0, "floors": 3, "mat": "plaster_blue", "roof": "pitch", "balconies": true, "entries": [-3.5, 3.5]},
		"st_block3b": {"w": 12.0, "d": 8.0, "floors": 3, "mat": "plaster_yellow", "roof": "flat", "balconies": true, "entries": [0.0], "piles": true},
		"st_block4": {"w": 18.0, "d": 9.0, "floors": 4, "mat": "brick_white", "roof": "flat", "balconies": true, "entries": [-4.5, 4.5]},
		"st_block4b": {"w": 14.0, "d": 9.0, "floors": 4, "mat": "plaster_pink", "roof": "pitch", "balconies": true, "entries": [0.0], "piles": true},
		"st_block2": {"w": 10.0, "d": 7.0, "floors": 2, "mat": "brick", "roof": "pitch", "entries": [2.0], "shopfront": true},
		"st_block2b": {"w": 9.0, "d": 7.0, "floors": 2, "mat": "plaster_green", "roof": "pitch", "entries": [0.0], "piles": true},
		"st_barrack2": {"w": 14.0, "d": 7.0, "floors": 2, "mat": "brick", "roof": "pitch", "entries": [-3.0, 3.0]},
	}
	for n in houses:
		if only == "" or n == only:
			stone_block(n, houses[n])
	if only == "" or only == "misc":
		heat_pipes()
		boiler_house()
		water_tower()
		garages()
		kiosk()
		bus_stop()
		conc_fence()
		paz_wreck()
		bins()
		furniture()
	print("Город собран.")
	get_tree().quit()


# ---------------- материалы ----------------
func _city_materials() -> void:
	_tex_mat("plaster_yellow", "plaster", 0.3, 0.95, 0.0, Color("d6b47a"))
	_tex_mat("plaster_pink", "plaster", 0.3, 0.95, 0.0, Color("c99a8c"))
	_tex_mat("plaster_blue", "plaster", 0.3, 0.95, 0.0, Color("9eafb6"))
	_tex_mat("plaster_white", "plaster", 0.3, 0.95, 0.0, Color("d6d2c6"))
	_tex_mat("plaster_green", "plaster", 0.3, 0.95, 0.0, Color("a9b88e"))
	_tex_mat("brick", "brick", 0.32, 0.95)
	_tex_mat("brick_white", "brick", 0.32, 0.95, 0.0, Color("e0d8c8"))
	_tex_mat("concrete", "concrete", 0.25, 0.95)
	_tex_mat("tiles", "tiles", 0.7, 0.6)
	_tex_mat("wallpaper", "wallpaper", 0.7, 0.95)
	_tex_mat("wallpaper_b", "wallpaper", 0.7, 0.95, 0.0, Color("b8c8b0"))
	_plain_mat("glass_city", Color("1d2428"), 0.15)
	_plain_mat("frame_white", Color("cbc6ba"), 0.7)
	_plain_mat("paint_green", Color("4c6650"), 0.7)
	_plain_mat("paint_blue", Color("44587a"), 0.7)
	_plain_mat("paint_red", Color("8a3428"), 0.7)
	_plain_mat("paint_door", Color("5a3a2a"), 0.7)
	_plain_mat("metal_green", Color("3c5444"), 0.6)
	_plain_mat("linoleum", Color("553a28"), 0.85)
	_plain_mat("linoleum_b", Color("44503f"), 0.85)
	_plain_mat("felt", Color("2c5638"), 1.0)
	_plain_mat("tar", Color("2a2826"), 0.9)
	_plain_mat("coal", Color("161514"), 0.95)
	_plain_mat("bottle", Color("2c4a30"), 0.2)
	_plain_mat("sofa", Color("6a3a30"), 1.0)
	_plain_mat("enamel", Color("d8d4c8"), 0.35)
	_plain_mat("plant", Color("3e5a2c"), 1.0)
	_plain_mat("flag_red", Color("8a2a24"), 0.9)
	# окно с тёплым светом изнутри — ночью видно, что в доме живут
	var lit := StandardMaterial3D.new()
	lit.resource_name = "window_lit"
	lit.albedo_color = Color("3a2c1a")
	lit.roughness = 0.3
	lit.emission_enabled = true
	lit.emission = Color("ffb35a")
	lit.emission_energy_multiplier = 0.9
	ResourceSaver.save(lit, MAT_DIR + "window_lit.tres")
	M["window_lit"] = load(MAT_DIR + "window_lit.tres")
	# окно «в небо» для комнат верхних этажей (интерьеры)
	var sky := StandardMaterial3D.new()
	sky.resource_name = "window_sky"
	sky.albedo_color = Color("7a8ea0")
	sky.roughness = 0.2
	sky.emission_enabled = true
	sky.emission = Color("9fb4c8")
	sky.emission_energy_multiplier = 0.35
	ResourceSaver.save(sky, MAT_DIR + "window_sky.tres")
	M["window_sky"] = load(MAT_DIR + "window_sky.tres")


# ---------------- детали фасада ----------------
## Окно на фасаде: тёмное стекло (или со светом), белые рамы, подоконник.
## pos — центр на поверхности стены, yaw — поворот стены (0 — фасад +Z)
func swin(pos: Vector3, yaw: float, kind := "") -> void:
	var b := Basis.from_euler(Vector3(0, yaw, 0))
	var r := Vector3(0, yaw, 0)
	var at := func(l: Vector3) -> Vector3: return pos + b * l
	if kind == "boarded":
		box("glass_city", Vector3(1.1, 1.4, 0.04), at.call(Vector3(0, 0, 0.02)), r)
		box("planks_old", Vector3(1.3, 0.22, 0.05), at.call(Vector3(0, 0.3, 0.06)), r + Vector3(0, 0, 0.3))
		box("planks_old", Vector3(1.3, 0.22, 0.05), at.call(Vector3(0, -0.3, 0.07)), r + Vector3(0, 0, -0.25))
	else:
		box("window_lit" if kind == "lit" else "glass_city", Vector3(1.1, 1.4, 0.04), at.call(Vector3(0, 0, 0.02)), r)
	box("frame_white", Vector3(1.24, 0.07, 0.08), at.call(Vector3(0, 0.72, 0.03)), r)
	box("frame_white", Vector3(0.07, 1.44, 0.08), at.call(Vector3(-0.59, 0, 0.03)), r)
	box("frame_white", Vector3(0.07, 1.44, 0.08), at.call(Vector3(0.59, 0, 0.03)), r)
	box("frame_white", Vector3(0.05, 1.4, 0.06), at.call(Vector3(0.1, 0, 0.03)), r)
	box("frame_white", Vector3(1.1, 0.05, 0.06), at.call(Vector3(0, 0.3, 0.03)), r)
	box("concrete", Vector3(1.4, 0.07, 0.22), at.call(Vector3(0, -0.75, 0.08)), r)
	if kind == "bars":
		for i in 5:
			box("metal_dark", Vector3(0.03, 1.4, 0.03), at.call(Vector3(-0.44 + i * 0.22, 0, 0.1)), r)


## Балкон: плита, решётка или застеклённый щит, иногда бельё и хлам
func balcony(pos: Vector3, yaw: float, style: int) -> void:
	var b := Basis.from_euler(Vector3(0, yaw, 0))
	var r := Vector3(0, yaw, 0)
	var at := func(l: Vector3) -> Vector3: return pos + b * l
	box("concrete", Vector3(1.9, 0.12, 0.95), at.call(Vector3(0, 0, 0.47)), r)
	if style == 0:
		box("metal_dark", Vector3(1.9, 0.05, 0.05), at.call(Vector3(0, 1.0, 0.92)), r)
		for i in 8:
			box("metal_dark", Vector3(0.03, 0.95, 0.03), at.call(Vector3(-0.9 + i * 0.257, 0.5, 0.92)), r)
		for sx in [-1, 1]:
			box("metal_dark", Vector3(0.05, 0.05, 0.9), at.call(Vector3(sx * 0.93, 1.0, 0.47)), r)
	elif style == 1:
		# заколочен досками до перил, сверху — рамы
		box("planks_old", Vector3(1.9, 1.0, 0.05), at.call(Vector3(0, 0.55, 0.92)), r)
		for sx in [-1, 1]:
			box("planks_old", Vector3(0.05, 1.0, 0.9), at.call(Vector3(sx * 0.93, 0.55, 0.47)), r)
		box("frame_white", Vector3(1.9, 0.06, 0.06), at.call(Vector3(0, 2.2, 0.92)), r)
		box("glass_city", Vector3(1.8, 1.1, 0.03), at.call(Vector3(0, 1.62, 0.92)), r)
		box("metal_roof", Vector3(2.0, 0.04, 1.0), at.call(Vector3(0, 2.3, 0.47)), r)
	else:
		box("concrete", Vector3(1.9, 1.0, 0.07), at.call(Vector3(0, 0.55, 0.92)), r)
		for sx in [-1, 1]:
			box("concrete", Vector3(0.07, 1.0, 0.9), at.call(Vector3(sx * 0.93, 0.55, 0.47)), r)
	if _rng.randf() < 0.45:
		box("rope_mat", Vector3(1.7, 0.02, 0.02), at.call(Vector3(0, 1.6, 0.6)), r)
		for i in 3:
			box(["cloth_red", "paper", "cloth_sack"][i], Vector3(0.38, 0.5, 0.02), at.call(Vector3(-0.5 + i * 0.5, 1.32, 0.6)), r)
	if _rng.randf() < 0.4:
		box("planks_old", Vector3(0.5, 0.4, 0.4), at.call(Vector3(0.55, 0.32, 0.45)), r + Vector3(0, 0.3, 0))
	if _rng.randf() < 0.3:
		# «тарелка» — антенна на перилах
		cyl("tin", 0.28, 0.05, 0.08, at.call(Vector3(-0.6, 1.3, 0.95)), r + Vector3(1.2, 0, 0), 12)


## Дверь подъезда: железная створка, козырёк, ступени, лампочка
func entry(x: float, front: float, base: float, open := false) -> void:
	box("concrete", Vector3(2.4, maxf(0.12, base), 1.2), Vector3(x, maxf(0.12, base) / 2.0, front + 0.6))
	if base > 0.3:
		for i in int(base / 0.18):
			box("concrete", Vector3(1.6, 0.18, 0.32), Vector3(x, base - 0.09 - i * 0.18, front + 1.35 + i * 0.3))
	if not open:
		box("paint_door", Vector3(1.2, 2.1, 0.08), Vector3(x, base + 1.05, front + 0.04))
		box("metal_dark", Vector3(0.08, 0.3, 0.06), Vector3(x + 0.4, base + 1.0, front + 0.1))
	box("frame_white", Vector3(1.5, 0.1, 0.1), Vector3(x, base + 2.2, front + 0.04))
	box("concrete", Vector3(2.6, 0.14, 1.5), Vector3(x, base + 2.7, front + 0.72))
	box("glass", Vector3(0.18, 0.18, 0.18), Vector3(x, base + 2.5, front + 0.12))


## Открытая двустворчатая дверь: створки распахнуты до упора и лежат вдоль фасада —
## проём остаётся во всю ширину
func open_door(x: float, front: float, width := DOOR_W) -> void:
	var lw := width / 2.0 - 0.06
	for sx in [-1, 1]:
		box("paint_door", Vector3(lw, 2.1, 0.07), Vector3(x + sx * (width / 2.0 + 0.08 + lw / 2.0), 1.05, front + 0.06))
		box("metal_dark", Vector3(0.06, 0.25, 0.05), Vector3(x + sx * (width / 2.0 + 0.08 + lw * 0.85), 1.0, front + 0.11))
	box("frame_white", Vector3(0.1, 2.3, 0.1), Vector3(x - width / 2.0 - 0.05, 1.15, front + 0.03))
	box("frame_white", Vector3(0.1, 2.3, 0.1), Vector3(x + width / 2.0 + 0.05, 1.15, front + 0.03))


## Крыша: плоская (рубероид, парапет, вентшахты, антенны) или скатная из профнастила
func roof(w: float, d: float, top: float, kind: String) -> void:
	if kind == "flat":
		box("tar", Vector3(w, 0.12, d), Vector3(0, top + 0.06, 0))
		for sz in [-1, 1]:
			box("concrete", Vector3(w + 0.1, 0.5, 0.18), Vector3(0, top + 0.25, sz * (d / 2.0 - 0.04)))
		for sx in [-1, 1]:
			box("concrete", Vector3(0.18, 0.5, d), Vector3(sx * (w / 2.0 - 0.04), top + 0.25, 0))
		for i in 2 + int(w / 7.0):
			var p := Vector3(_rng.randf_range(-w / 2.0 + 1.2, w / 2.0 - 1.2), top, _rng.randf_range(-d / 2.0 + 1.2, d / 2.0 - 1.2))
			box("brick", Vector3(0.9, 0.9, 0.7), p + Vector3(0, 0.45, 0))
			box("concrete", Vector3(1.1, 0.08, 0.9), p + Vector3(0, 0.95, 0))
		# антенны «ёлкой»
		for i in 2:
			var a := Vector3(_rng.randf_range(-w / 2.0 + 1, w / 2.0 - 1), top, _rng.randf_range(-d / 3.0, d / 3.0))
			cyl("metal_dark", 0.03, 0.03, 2.6, a + Vector3(0, 1.3, 0), Vector3.ZERO, 5)
			for k in 4:
				box("metal_dark", Vector3(1.0 - k * 0.18, 0.025, 0.025), a + Vector3(0, 1.6 + k * 0.3, 0))
	else:
		var h := minf(2.4, d * 0.28)
		prism("metal_roof", Vector3(d + 0.8, h, w + 0.5), Vector3(0, top + h / 2.0, 0), Vector3(0, PI / 2.0, 0))
		box("metal_roof", Vector3(w + 0.6, 0.12, 0.3), Vector3(0, top + h + 0.02, 0), Vector3(PI / 4.0, 0, 0))
		for sx in [-1, 1]:
			prism(roof_gable_mat, Vector3(d - 0.1, h - 0.05, 0.1), Vector3(sx * (w / 2.0 - 0.06), top + h / 2.0, 0), Vector3(0, PI / 2.0, 0))
		# слуховое окно и печные трубы
		box("planks_old", Vector3(1.0, 0.8, 0.7), Vector3(w * 0.2, top + h * 0.35, d / 4.0 + 0.2))
		box("glass_city", Vector3(0.6, 0.45, 0.05), Vector3(w * 0.2, top + h * 0.35, d / 4.0 + 0.56))
		for cx in [-w / 3.0, w / 4.0]:
			box("brick", Vector3(0.6, 1.6, 0.6), Vector3(cx, top + h * 0.6 + 0.5, -0.8))


var roof_gable_mat := "plaster_white"


## Каменный дом. opts: w, d, floors, mat, roof (flat|pitch), enter (тип первого этажа или ""),
## door_x, entries (x глухих подъездов), balconies, shopfront, portico, piles, flag, bars, fh
func stone_block(n: String, o: Dictionary) -> void:
	begin()
	_rng.seed = hash(n)
	var w: float = o.get("w", 12.0)
	var d: float = o.get("d", 8.0)
	var floors: int = o.get("floors", 3)
	var fh: float = o.get("fh", FH)
	var mat: String = o.get("mat", "plaster_yellow")
	var enter: String = o.get("enter", "")
	var door_x: float = o.get("door_x", 0.0)
	var piles: bool = o.get("piles", false) and enter == ""
	roof_gable_mat = mat
	var base := 0.9 if piles else 0.0
	var top := base + floors * fh
	var hx := w / 2.0
	var hz := d / 2.0
	if enter != "":
		cut_y = 1.15
		inner = Vector2(w - 0.7, d - 0.7)
		door_local = Vector3(door_x, 0, hz)
		_shell(w, d, top, mat, door_x)
		_interior(enter, w, d, door_x)
		wall_colliders(w - 0.2, d - 0.2, door_x, DOOR_W, 3.0)
		open_door(door_x, hz)
		entry(door_x, hz, 0.0, true)
		slots["sign"] = Vector3(door_x, 3.35 if floors > 1 else 2.6, hz + 0.12)
	else:
		# глухой дом: короб стен, внутри пусто
		box(mat, Vector3(w, top - base, d), Vector3(0, (base + top) / 2.0, 0))
		solid(Vector3(w + 0.2, 3.0, d + 0.2), Vector3(0, 1.5, 0))
		var ents: Array = o.get("entries", [0.0])
		for ex in ents:
			entry(ex, hz, base)
		if not ents.is_empty():
			slots["sign"] = Vector3(float(ents[0]), base + 3.35, hz + 0.12)
	# цоколь / сваи
	if piles:
		box("concrete", Vector3(w - 0.4, 0.1, d - 0.4), Vector3(0, base - 0.05, 0))
		for ix in int(w / 2.0) + 1:
			for iz in 3:
				cyl("concrete", 0.16, 0.16, base, Vector3(-hx + 0.4 + ix * (w - 0.8) / int(w / 2.0), base / 2.0, -hz + 0.5 + iz * (d - 1.0) / 2.0), Vector3.ZERO, 6)
		box("planks_old", Vector3(w * 0.4, base * 0.7, 0.05), Vector3(-hx * 0.4, base * 0.4, hz - 0.3))
	else:
		for sz in [-1, 1]:
			box("concrete", Vector3(w + 0.12, 0.45, 0.08), Vector3(0, 0.22, sz * (hz + 0.02)))
		for sx in [-1, 1]:
			box("concrete", Vector3(0.08, 0.45, d + 0.12), Vector3(sx * (hx + 0.02), 0.22, 0))
	# межэтажные пояски
	for f in range(1, floors):
		box("concrete", Vector3(w + 0.14, 0.14, d + 0.14), Vector3(0, base + f * fh, 0))
	box("concrete", Vector3(w + 0.3, 0.2, d + 0.3), Vector3(0, top - 0.1, 0))
	# окна: пролёты по 2,6 м, по всем этажам; первый этаж — витрины или окна с решёткой
	var bays := maxi(2, int((w - 1.0) / 2.6))
	var step := (w - 1.6) / float(bays - 1) if bays > 1 else 0.0
	var ent_x: Array = [door_x] if enter != "" else o.get("entries", [0.0])
	var bal_row := _rng.randi() % 3
	for f in floors:
		var y := base + f * fh + fh * 0.55
		for i in bays:
			var x := -hx + 0.8 + i * step
			var near_door := false
			for ex in ent_x:
				if absf(x - float(ex)) < 1.5:
					near_door = true
			# фасад (+Z)
			if f == 0:
				if near_door:
					pass
				elif o.get("shopfront", false):
					_shop_window(Vector3(x, base + 1.45, hz + 0.01))
				else:
					swin(Vector3(x, y, hz + 0.01), 0.0, "bars" if o.get("bars", false) else _wkind())
			elif near_door:
				# окно лестничной клетки между этажами
				swin(Vector3(x, y - fh * 0.5 + 0.1, hz + 0.01), 0.0, _wkind())
			else:
				swin(Vector3(x, y, hz + 0.01), 0.0, _wkind())
				if o.get("balconies", false) and f >= 1 and (i + f + bal_row) % 3 == 0:
					balcony(Vector3(x, base + f * fh, hz + 0.01), 0.0, (i + f) % 3)
			# двор (-Z)
			swin(Vector3(x, y, -hz - 0.01), PI, "bars" if f == 0 and o.get("bars", false) else _wkind())
		# торцы
		for sx in [-1, 1]:
			if d > 7.5:
				swin(Vector3(sx * (hx + 0.01), y, 0), sx * PI / 2.0, _wkind())
	if o.get("portico", false):
		_portico(w, d, top, base)
	roof(w, d, top, o.get("roof", "flat"))
	if o.get("flag", false):
		cyl("metal_dark", 0.05, 0.05, 4.0, Vector3(hx - 1.0, top + 2.0, hz - 1.0), Vector3.ZERO, 6)
		box("flag_red", Vector3(1.4, 0.8, 0.03), Vector3(hx - 0.25, top + 3.5, hz - 1.0))
	# водосточные трубы по углам фасада, ящики кондиционеров… здесь — электрощит
	for sx in [-1, 1]:
		cyl("tin", 0.08, 0.08, top - 0.3, Vector3(sx * (hx - 0.1), (top - 0.3) / 2.0, hz + 0.12), Vector3.ZERO, 6)
	box("metal_dark", Vector3(0.6, 0.8, 0.2), Vector3(-hx + 1.6, 1.4 + base, -hz - 0.1))
	finish(n, n.to_pascal_case())


func _wkind() -> String:
	var r := _rng.randf()
	if r < 0.14:
		return "boarded"
	if r < 0.32:
		return "lit"
	return ""


## Витрина первого этажа: большое стекло, рама, подоконник
func _shop_window(pos: Vector3) -> void:
	box("glass_city" if _rng.randf() > 0.2 else "window_lit", Vector3(2.0, 1.9, 0.05), pos + Vector3(0, 0, 0.02))
	box("frame_white", Vector3(2.16, 0.09, 0.1), pos + Vector3(0, 0.98, 0.03))
	box("frame_white", Vector3(2.16, 0.09, 0.1), pos + Vector3(0, -0.98, 0.03))
	box("frame_white", Vector3(0.09, 1.96, 0.1), pos + Vector3(-1.04, 0, 0.03))
	box("frame_white", Vector3(0.09, 1.96, 0.1), pos + Vector3(1.04, 0, 0.03))
	box("frame_white", Vector3(0.06, 1.9, 0.08), pos + Vector3(0, 0, 0.03))
	if _rng.randf() < 0.25:
		box("planks_old", Vector3(2.1, 0.25, 0.05), pos + Vector3(0, 0.2, 0.08), Vector3(0, 0, 0.2))


## Колоннада ДК: колонны, антаблемент, широкая лестница
func _portico(w: float, d: float, top: float, base: float) -> void:
	var hz := d / 2.0
	var ch := top - base - 0.6
	for cx in [-6.4, -4.0, -1.6, 1.6, 4.0, 6.4]:
		if absf(cx) > w / 2.0 - 0.3:
			continue
		cyl("plaster_white", 0.28, 0.32, ch, Vector3(cx, base + ch / 2.0, hz + 1.8), Vector3.ZERO, 12)
		box("concrete", Vector3(0.8, 0.2, 0.8), Vector3(cx, base + 0.1, hz + 1.8))
		box("concrete", Vector3(0.75, 0.2, 0.75), Vector3(cx, base + ch - 0.1, hz + 1.8))
		solid(Vector3(0.7, 2.0, 0.7), Vector3(cx, 1.0, hz + 1.8))
	box("plaster_white", Vector3(w * 0.9, 0.8, 2.4), Vector3(0, top - 0.2, hz + 1.2))
	prism("plaster_white", Vector3(w * 0.9, 1.4, 0.3), Vector3(0, top + 0.9, hz + 2.25))
	box("concrete", Vector3(w * 0.85, 0.12, 2.6), Vector3(0, 0.06, hz + 1.3))


## Стены дома с входом: нижний пояс (до cut_y) остаётся, верх уходит в Upper
func _shell(w: float, d: float, top: float, mat: String, door_x: float) -> void:
	var hx := w / 2.0
	var hz := d / 2.0
	var t := 0.3
	var cut := cut_y - 0.02
	for band in [[0.0, cut], [cut_y + 0.02, top]]:
		var y0: float = band[0]
		var y1: float = band[1]
		var h := y1 - y0
		var yc := (y0 + y1) / 2.0
		box(mat, Vector3(w, h, t), Vector3(0, yc, -hz + t / 2.0))
		box(mat, Vector3(t, h, d - 2 * t), Vector3(-hx + t / 2.0, yc, 0))
		box(mat, Vector3(t, h, d - 2 * t), Vector3(hx - t / 2.0, yc, 0))
		var l0 := -hx
		var l1 := door_x - DOOR_W / 2.0
		var r0 := door_x + DOOR_W / 2.0
		var r1 := hx
		box(mat, Vector3(l1 - l0, h, t), Vector3((l0 + l1) / 2.0, yc, hz - t / 2.0))
		box(mat, Vector3(r1 - r0, h, t), Vector3((r0 + r1) / 2.0, yc, hz - t / 2.0))
	# перемычка над дверью
	box(mat, Vector3(DOOR_W, top - 2.3, t), Vector3(door_x, (top + 2.3) / 2.0, hz - t / 2.0))


## Нижняя внутренняя отделка стен и пол
func _lining(w: float, d: float, wall_mat: String, floor_mat: String, door_x: float) -> void:
	var hx := w / 2.0 - 0.31
	var hz := d / 2.0 - 0.31
	var h := cut_y - 0.06
	box(floor_mat, Vector3(w - 0.6, 0.04, d - 0.6), Vector3(0, 0.02, 0))
	box(wall_mat, Vector3(w - 0.62, h, 0.02), Vector3(0, h / 2.0, -hz))
	box(wall_mat, Vector3(0.02, h, d - 0.62), Vector3(-hx, h / 2.0, 0))
	box(wall_mat, Vector3(0.02, h, d - 0.62), Vector3(hx, h / 2.0, 0))
	var l1 := door_x - DOOR_W / 2.0
	var r0 := door_x + DOOR_W / 2.0
	box(wall_mat, Vector3(l1 + hx, h, 0.02), Vector3((-hx + l1) / 2.0, h / 2.0, hz))
	box(wall_mat, Vector3(hx - r0, h, 0.02), Vector3((r0 + hx) / 2.0, h / 2.0, hz))


## Лестничный марш, уходящий вверх к задней стене (верх марша прячется вместе с этажами)
func stair_flight(x: float, z_back: float, width := 1.3) -> void:
	for i in 10:
		var y := 0.09 + i * 0.18
		box("concrete", Vector3(width, 0.18, 0.3), Vector3(x, y, z_back + 2.9 - i * 0.3))
		box("concrete", Vector3(width, y, 0.3), Vector3(x, y / 2.0, z_back + 2.9 - i * 0.3))
	for sx in [-1, 1]:
		box("metal_dark", Vector3(0.04, 0.04, 3.2), Vector3(x + sx * width / 2.0, 1.4, z_back + 1.5), Vector3(0.55, 0, 0))
		for k in 4:
			box("metal_dark", Vector3(0.03, 0.9, 0.03), Vector3(x + sx * width / 2.0, 0.45 + k * 0.42 + 0.3, z_back + 2.8 - k * 0.8))
	solid(Vector3(width + 0.1, 2.0, 3.0), Vector3(x, 1.0, z_back + 1.55))
	slots["stairs"] = Vector3(x, 0, z_back + 3.6)


## Перегородка вдоль Z на x с проёмом в точке gz
func partition_z(x: float, z0: float, z1: float, gz: float, mat: String) -> void:
	var h := cut_y - 0.04
	for seg in [[z0, gz - GAP_W / 2.0], [gz + GAP_W / 2.0, z1]]:
		var a: float = seg[0]
		var b: float = seg[1]
		if b - a < 0.05:
			continue
		box(mat, Vector3(0.14, h, b - a), Vector3(x, h / 2.0, (a + b) / 2.0))
		box(mat, Vector3(0.14, 3.0 - h, b - a), Vector3(x, h + (3.0 - h) / 2.0 + 0.04, (a + b) / 2.0))
		solid(Vector3(0.3, 2.6, b - a), Vector3(x, 1.3, (a + b) / 2.0))


func _table(x: float, z: float, mat := "planks_old", chairs := 2, cloth := "") -> void:
	box(mat, Vector3(1.1, 0.06, 0.75), Vector3(x, 0.76, z))
	if cloth != "":
		box(cloth, Vector3(1.15, 0.02, 0.8), Vector3(x, 0.8, z))
	for lx in [-0.48, 0.48]:
		for lz in [-0.3, 0.3]:
			box(mat, Vector3(0.06, 0.74, 0.06), Vector3(x + lx, 0.37, z + lz))
	for i in chairs:
		var cz := z + (0.7 if i % 2 == 0 else -0.7)
		var cx := x + (0.3 if i >= 2 else 0.0) * (1 if i % 2 == 0 else -1)
		box("planks_old", Vector3(0.42, 0.05, 0.42), Vector3(cx, 0.45, cz))
		box("planks_old", Vector3(0.42, 0.45, 0.05), Vector3(cx, 0.7, cz + (0.2 if i % 2 == 0 else -0.2)))
		for lx in [-0.18, 0.18]:
			box("metal_dark", Vector3(0.03, 0.44, 0.03), Vector3(cx + lx, 0.22, cz))
	solid(Vector3(1.1, 0.8, 0.75), Vector3(x, 0.4, z))


func _bed(x: float, z: float, yaw := 0.0) -> void:
	var b := Basis.from_euler(Vector3(0, yaw, 0))
	var r := Vector3(0, yaw, 0)
	box("metal_dark", Vector3(0.9, 0.35, 1.95), Vector3(x, 0.18, z), r)
	box("enamel", Vector3(0.85, 0.12, 1.85), Vector3(x, 0.42, z), r)
	box(["cloth_red", "cloth_sack", "paint_blue"][_rng.randi() % 3], Vector3(0.88, 0.06, 1.2), Vector3(x, 0.5, z) + b * Vector3(0, 0, 0.3), r)
	box("enamel", Vector3(0.6, 0.1, 0.35), Vector3(x, 0.52, z) + b * Vector3(0, 0, -0.72), r)
	box("metal_dark", Vector3(0.9, 0.6, 0.04), Vector3(x, 0.45, z) + b * Vector3(0, 0, -0.98), r)
	solid(Vector3(1.0, 0.6, 2.0), Vector3(x, 0.3, z), yaw)


func _wardrobe(x: float, z: float, yaw := 0.0) -> void:
	box("paint_door", Vector3(1.0, 1.1, 0.55), Vector3(x, 0.55, z), Vector3(0, yaw, 0))
	box("paint_door", Vector3(1.0, 1.0, 0.55), Vector3(x, 1.65, z), Vector3(0, yaw, 0))
	solid(Vector3(1.0, 2.0, 0.6), Vector3(x, 1.0, z), yaw)


func _counter(x: float, z: float, len_x: float, mat := "planks_old") -> void:
	box(mat, Vector3(len_x, 1.0, 0.6), Vector3(x, 0.5, z))
	box("frame_white", Vector3(len_x + 0.06, 0.05, 0.66), Vector3(x, 1.02, z))
	solid(Vector3(len_x, 1.0, 0.65), Vector3(x, 0.5, z))


func _shelf_goods(x: float, z: float, len_x: float, yaw := 0.0) -> void:
	var b := Basis.from_euler(Vector3(0, yaw, 0))
	var r := Vector3(0, yaw, 0)
	box("planks_old", Vector3(len_x, 2.1, 0.4), Vector3(x, 1.05, z), r)
	var goods := ["tin", "paper", "cloth_red", "bottle", "bread", "cloth_sack", "fish"]
	for lv in 3:
		for i in int(len_x / 0.3):
			if _rng.randf() < 0.3:
				continue
			var p := Vector3(x, 0.38 + lv * 0.62, z) + b * Vector3(-len_x / 2.0 + 0.2 + i * 0.3, 0, 0.12)
			box(goods[_rng.randi() % goods.size()], Vector3(0.18, 0.24, 0.18), p, r)
	solid(Vector3(len_x, 2.0, 0.45), Vector3(x, 1.0, z), yaw)


func _stove(x: float, z: float) -> void:
	cyl("metal_dark", 0.32, 0.32, 0.75, Vector3(x, 0.38, z), Vector3.ZERO, 10)
	cyl("metal_dark", 0.07, 0.07, 2.4, Vector3(x, 1.9, z - 0.15), Vector3.ZERO, 6)
	solid(Vector3(0.7, 0.8, 0.7), Vector3(x, 0.4, z))


func _rug(x: float, z: float, sx: float, sz: float, mat := "cloth_red") -> void:
	box(mat, Vector3(sx, 0.012, sz), Vector3(x, 0.05, z))


func _plant(x: float, z: float) -> void:
	cyl("paint_door", 0.22, 0.18, 0.4, Vector3(x, 0.2, z), Vector3.ZERO, 8)
	for i in 5:
		box("plant", Vector3(0.08, 0.6, 0.2), Vector3(x, 0.65, z), Vector3(0.3, i * 1.25, 0.25))
	solid(Vector3(0.45, 0.8, 0.45), Vector3(x, 0.4, z))


# ---------------- обстановка первых этажей ----------------
func _interior(kind: String, w: float, d: float, door_x: float) -> void:
	var hx := w / 2.0 - 0.3
	var hz := d / 2.0 - 0.3
	match kind:
		"lobby":
			_lining(w, d, "wallpaper", "linoleum", door_x)
			# конторка дежурной слева, за ней ячейки с ключами
			_counter(-hx + 2.4, -0.6, 2.6)
			box("planks_old", Vector3(0.6, 1.0, 2.6), Vector3(-hx + 1.0, 0.5, -0.6))
			for i in 8:
				box("brass", Vector3(0.04, 0.12, 0.04), Vector3(-hx + 0.72, 0.85, -1.7 + i * 0.3))
			solid(Vector3(0.6, 1.0, 2.6), Vector3(-hx + 1.0, 0.5, -0.6))
			slots["keeper"] = Vector3(-hx + 1.7, 0, -0.6)
			# диван и кресла, ковёр, фикус
			box("sofa", Vector3(2.2, 0.45, 0.8), Vector3(1.0, 0.23, -hz + 0.5))
			box("sofa", Vector3(2.2, 0.55, 0.2), Vector3(1.0, 0.6, -hz + 0.15))
			solid(Vector3(2.2, 0.8, 0.9), Vector3(1.0, 0.4, -hz + 0.45))
			for cx in [-0.6, 2.6]:
				box("sofa", Vector3(0.75, 0.45, 0.75), Vector3(cx, 0.23, -hz + 1.6))
				solid(Vector3(0.75, 0.8, 0.75), Vector3(cx, 0.4, -hz + 1.6))
			_rug(1.0, -hz + 1.8, 3.0, 1.8)
			_plant(-hx + 0.4, hz - 0.4)
			stair_flight(hx - 1.0, -hz)
			slots["sofa"] = Vector3(1.0, 0, -hz + 1.2)
		"shop":
			_lining(w, d, "paint_green", "tiles", door_x)
			_counter(0, -hz + 1.7, w - 4.4)
			_shelf_goods(0, -hz + 0.25, w - 2.0)
			_shelf_goods(-hx + 0.25, 0.4, 3.2, PI / 2.0)
			_shelf_goods(hx - 0.25, 0.4, 3.2, -PI / 2.0)
			box("metal_dark", Vector3(0.4, 0.25, 0.35), Vector3(-1.5, 1.15, -hz + 1.7))
			for i in 4:
				box(["bread", "fish", "tin", "cloth_sack"][i], Vector3(0.3, 0.15, 0.3), Vector3(0.0 + i * 0.6, 1.1, -hz + 1.7))
			slots["seller"] = Vector3(0.5, 0, -hz + 0.95)
			slots["seller2"] = Vector3(-2.5, 0, -hz + 0.95)
			slots["buyer"] = Vector3(0.6, 0, -hz + 2.6)
			for i in 3:
				box("cloth_sack", Vector3(0.5, 0.5, 0.4), Vector3(hx - 0.7, 0.25, hz - 0.6 - i * 0.5), Vector3(0, i * 0.4, 0))
			solid(Vector3(0.6, 0.5, 1.5), Vector3(hx - 0.7, 0.25, hz - 1.1))
		"bar":
			_lining(w, d, "wallpaper_b", "planks_old", door_x)
			_counter(-hx + 1.6, -0.8, 0.6)
			box("planks_old", Vector3(0.6, 1.0, 3.6), Vector3(-hx + 1.6, 0.5, -0.8))
			solid(Vector3(0.65, 1.0, 3.6), Vector3(-hx + 1.6, 0.5, -0.8))
			box("planks_old", Vector3(0.4, 2.1, 3.6), Vector3(-hx + 0.25, 1.05, -0.8))
			for i in 10:
				cyl("bottle", 0.05, 0.05, 0.3, Vector3(-hx + 0.4, 1.25 + (i % 2) * 0.55, -2.4 + i * 0.35), Vector3.ZERO, 6)
			for i in 3:
				cyl("planks_old", 0.3, 0.3, 0.6, Vector3(-hx + 0.5, 0.3, 1.6 + i * 0.6), Vector3(PI / 2.0, 0, 0), 10)
			slots["barman"] = Vector3(-hx + 0.9, 0, -0.8)
			_table(1.0, -hz + 1.2, "planks_old", 2)
			_table(hx - 1.4, -hz + 1.2, "planks_old", 2)
			_table(hx - 1.4, 0.9, "planks_old", 2)
			slots["t1"] = Vector3(1.0, 0, -hz + 1.9)
			slots["t2"] = Vector3(hx - 1.4, 0, -hz + 1.9)
			slots["t3"] = Vector3(hx - 1.4, 0, 1.6)
			_stove(1.2, hz - 0.8)
			_rug(-0.4, 0.4, 1.6, 2.4, "cloth_sack")
		"canteen":
			_lining(w, d, "paint_green", "tiles", door_x)
			_counter(0, -hz + 1.4, w - 3.0, "enamel")
			for i in 3:
				cyl("tin", 0.3, 0.3, 0.4, Vector3(-3.0 + i * 1.4, 1.22, -hz + 0.6), Vector3.ZERO, 10)
			box("metal_dark", Vector3(w - 1.0, 0.9, 0.6), Vector3(0, 0.45, -hz + 0.35))
			slots["cook"] = Vector3(0.6, 0, -hz + 0.85)
			var k := 1
			for tx in [-3.4, 0.0, 3.4]:
				_table(tx, 1.2, "enamel", 2)
				slots["t%d" % k] = Vector3(tx, 0, 1.9)
				k += 1
		"hall":
			_lining(w, d, "wallpaper", "planks_old", door_x)
			# сцена у задней стены с занавесом
			box("planks_old", Vector3(w - 2.0, 0.35, 2.0), Vector3(0, 0.18, -hz + 1.0))
			box("cloth_red", Vector3(w - 2.4, 1.0, 0.08), Vector3(0, 0.85, -hz + 0.1))
			solid(Vector3(w - 2.0, 0.5, 2.0), Vector3(0, 0.25, -hz + 1.0))
			# столы с зелёным сукном
			var k := 1
			for tp in [Vector2(-4.5, 0.2), Vector2(0.0, 1.0), Vector2(4.5, 0.2)]:
				_table(tp.x, tp.y, "planks_old", 4, "felt")
				slots["t%d" % k] = Vector3(tp.x, 0, tp.y - 0.75)
				k += 1
			# колесо фортуны на стойке
			cyl("paint_red", 0.6, 0.6, 0.06, Vector3(hx - 0.7, 1.0, -0.5), Vector3(0, 0, PI / 2.0), 16)
			box("planks_old", Vector3(0.3, 0.7, 0.3), Vector3(hx - 0.7, 0.35, -0.5))
			solid(Vector3(0.5, 1.4, 1.3), Vector3(hx - 0.7, 0.7, -0.5))
			slots["croupier"] = Vector3(hx - 1.4, 0, -0.5)
			_rug(0, hz - 1.2, 2.0, 1.2)
		"stairwell", "obshaga":
			_lining(w, d, "paint_green" if kind == "stairwell" else "paint_blue", "linoleum" if kind == "stairwell" else "linoleum_b", door_x)
			# середина — подъезд с лестницей; слева и справа — квартиры (или вахта и красный уголок)
			partition_z(-2.2, -hz, hz, 0.6, "wallpaper")
			partition_z(2.2, -hz, hz, 0.6, "wallpaper_b")
			stair_flight(0.0, -hz)
			box("paint_blue", Vector3(0.06, 0.8, 1.6), Vector3(-2.05, 0.8, -1.8))
			for i in 8:
				box("metal_dark", Vector3(0.03, 0.1, 0.15), Vector3(-2.0, 0.55 + (i % 2) * 0.35, -2.4 + int(i / 2) * 0.35))
			if kind == "stairwell":
				# левая квартира: кровать, шкаф, стол, буржуйка
				_bed(-hx + 0.7, -hz + 1.2)
				_wardrobe(-hx + 0.4, hz - 1.0, PI / 2.0)
				_table(-4.5, 1.0, "planks_old", 2)
				_rug(-4.6, -0.8, 2.0, 1.4)
				slots["flatL"] = Vector3(-4.6, 0, -0.6)
				# правая: кухня — плита, буфет, стол, детская кроватка
				box("enamel", Vector3(0.7, 0.85, 0.6), Vector3(hx - 0.5, 0.43, -hz + 0.5))
				solid(Vector3(0.7, 0.9, 0.6), Vector3(hx - 0.5, 0.45, -hz + 0.5))
				_wardrobe(hx - 1.6, -hz + 0.35)
				_table(4.6, 0.6, "enamel", 2, "paper")
				_bed(hx - 0.7, hz - 1.4, PI)
				slots["flatR"] = Vector3(4.2, 0, -0.9)
			else:
				# вахта: стол за стеклом, вертушка
				_table(-3.6, -1.2, "planks_old", 1)
				box("glass", Vector3(0.05, 1.0, 2.6), Vector3(-2.7, 1.5, -1.0))
				box("metal_dark", Vector3(0.6, 0.06, 0.06), Vector3(-1.4, 0.9, 1.4))
				slots["watch"] = Vector3(-3.6, 0, -2.0)
				_wardrobe(-hx + 0.4, hz - 1.0, PI / 2.0)
				_rug(-4.0, 1.0, 1.4, 1.4, "cloth_sack")
				slots["flatL"] = Vector3(-4.2, 0, 1.2)
				# красный уголок: стол, скамьи, «телевизор», доска с объявлениями
				_table(4.4, -0.6, "planks_old", 4, "cloth_red")
				box("paint_door", Vector3(0.7, 0.55, 0.5), Vector3(hx - 0.4, 0.95, 1.8))
				box("glass_city", Vector3(0.05, 0.4, 0.45), Vector3(hx - 0.66, 0.97, 1.8))
				box("planks_old", Vector3(0.6, 0.65, 0.5), Vector3(hx - 0.4, 0.33, 1.8))
				solid(Vector3(0.6, 1.2, 0.6), Vector3(hx - 0.4, 0.6, 1.8))
				box("paper", Vector3(1.4, 0.8, 0.03), Vector3(4.4, 0.75, -hz + 0.05))
				slots["flatR"] = Vector3(4.4, 0, 0.5)
			box("metal_dark", Vector3(1.0, 0.5, 0.1), Vector3(1.4, 0.4, hz - 0.1))


# ---------------- теплотрасса ----------------
## Две трубы в обмотке. low — на низких опорах, сквозь не пройти;
## high — П-образные опоры, под трубой пройти можно (коллизия только у стоек)
func heat_pipes() -> void:
	for kind in ["low", "high", "riser"]:
		begin()
		var y := 0.85 if kind == "low" else 3.4
		if kind != "riser":
			for k in 2:
				var z := -0.28 + k * 0.56
				cyl("tin" if k == 0 else "tar", 0.24, 0.24, 6.0, Vector3(0, y, z), Vector3(0, 0, PI / 2.0), 10)
				for i in 4:
					cyl("rope_mat", 0.255, 0.255, 0.08, Vector3(-2.4 + i * 1.6, y, z), Vector3(0, 0, PI / 2.0), 10)
				if _rng.randf() < 0.6:
					# порванная обмотка — торчит вата
					box("paper", Vector3(0.5, 0.18, 0.18), Vector3(_rng.randf_range(-2.0, 2.0), y + 0.12, z + 0.08), Vector3(0.3, 0, 0.2))
			for sx in [-2.6, 2.6]:
				if kind == "low":
					box("concrete", Vector3(0.3, y - 0.2, 1.1), Vector3(sx, (y - 0.2) / 2.0, 0))
				else:
					for sz in [-0.6, 0.6]:
						box("metal_dark", Vector3(0.18, y, 0.18), Vector3(sx, y / 2.0, sz))
						solid(Vector3(0.3, 2.0, 0.3), Vector3(sx, 1.0, sz))
					box("metal_dark", Vector3(0.2, 0.16, 1.4), Vector3(sx, y - 0.32, 0))
			if kind == "low":
				solid(Vector3(6.0, 1.3, 1.2), Vector3(0, 0.65, 0))
		else:
			# подъём: низкая труба уходит вверх на высокие опоры (2,5 м вдоль X)
			for k in 2:
				var z := -0.28 + k * 0.56
				var m := "tin" if k == 0 else "tar"
				cyl(m, 0.24, 0.24, 1.3, Vector3(-0.65, 0.85, z), Vector3(0, 0, PI / 2.0), 10)
				cyl(m, 0.24, 0.24, 2.8, Vector3(0.0, 2.1, z), Vector3.ZERO, 10)
				cyl(m, 0.24, 0.24, 1.3, Vector3(0.65, 3.4, z), Vector3(0, 0, PI / 2.0), 10)
			box("concrete", Vector3(0.3, 0.65, 1.1), Vector3(-1.1, 0.33, 0))
			box("metal_dark", Vector3(0.2, 3.3, 0.2), Vector3(0.0, 1.65, 0.7))
			solid(Vector3(1.6, 3.6, 1.2), Vector3(-0.2, 1.8, 0))
		finish("heat_pipe_" + kind, "HeatPipe")


# ---------------- котельная ----------------
func boiler_house() -> void:
	begin()
	var w := 10.0
	var d := 8.0
	box("brick", Vector3(w, 5.0, d), Vector3(0, 2.5, 0))
	box("tar", Vector3(w + 0.3, 0.2, d + 0.3), Vector3(0, 5.1, 0))
	for i in 3:
		swin(Vector3(-3.2 + i * 3.2, 3.4, d / 2.0 + 0.01), 0.0, "boarded" if i == 1 else "lit")
	box("metal_green", Vector3(3.0, 3.0, 0.1), Vector3(2.5, 1.5, d / 2.0 + 0.05))
	# труба 20 м с поясами и скобами-лестницей
	var cx := -w / 2.0 - 1.8
	cyl("brick", 0.6, 1.0, 20.0, Vector3(cx, 10.0, -1.0), Vector3.ZERO, 14)
	for y in [5.0, 10.0, 15.0, 19.5]:
		cyl("metal_dark", 0.92 - y * 0.018, 0.92 - y * 0.018, 0.2, Vector3(cx, y, -1.0), Vector3.ZERO, 14)
	for k in 16:
		box("metal_dark", Vector3(0.4, 0.03, 0.05), Vector3(cx + 0.35, 1.0 + k * 1.1, -0.1 - k * 0.02))
	# куча угля и тачка
	add("coal", rough(rsphere(2.2, 10, 6), 0.4, 3, 1.2, 1.0), Vector3(2.0, -0.9, -d / 2.0 - 2.6), Vector3.ZERO, Vector3(1.6, 0.8, 1.0))
	add("coal", rough(rsphere(1.4, 9, 5), 0.3, 4, 1.4, 1.0), Vector3(-1.5, -0.6, -d / 2.0 - 2.0), Vector3.ZERO, Vector3(1.4, 0.8, 1.0))
	box("metal_dark", Vector3(0.7, 0.4, 1.0), Vector3(4.6, 0.4, -d / 2.0 - 1.4), Vector3(0.1, 0.4, 0))
	solid(Vector3(w + 0.2, 3.0, d + 0.2), Vector3(0, 1.5, 0))
	solid(Vector3(2.0, 3.0, 2.0), Vector3(cx, 1.5, -1.0))
	solid(Vector3(6.4, 1.6, 2.6), Vector3(1.0, 0.8, -d / 2.0 - 2.4))
	finish("boiler_house", "BoilerHouse")


func water_tower() -> void:
	begin()
	cyl("brick", 1.5, 1.7, 11.0, Vector3(0, 5.5, 0), Vector3.ZERO, 14)
	cyl("metal_dark", 2.6, 2.4, 3.2, Vector3(0, 12.6, 0), Vector3.ZERO, 16)
	cyl("rust", 2.65, 2.65, 0.15, Vector3(0, 11.6, 0), Vector3.ZERO, 16)
	cyl("metal_roof", 0.2, 2.9, 1.4, Vector3(0, 14.9, 0), Vector3.ZERO, 16)
	box("paint_door", Vector3(1.0, 2.0, 0.1), Vector3(0, 1.0, 1.66))
	for y in [4.0, 7.5]:
		box("glass_city", Vector3(0.4, 0.8, 0.06), Vector3(0, y, 1.56))
	solid(Vector3(3.4, 3.0, 3.4), Vector3(0, 1.5, 0))
	finish("water_tower", "WaterTower")


func garages() -> void:
	begin()
	var cols := ["metal_green", "paint_blue", "rust", "paint_red"]
	for i in 4:
		var x := -4.5 + i * 3.0
		box("brick" if i % 2 else "concrete", Vector3(3.0, 2.6, 6.0), Vector3(x, 1.3, 0))
		box(cols[i], Vector3(2.4, 2.1, 0.06), Vector3(x, 1.05, 3.02))
		box("metal_dark", Vector3(0.05, 2.1, 0.07), Vector3(x, 1.05, 3.05))
		box("tar", Vector3(3.1, 0.12, 6.4), Vector3(x, 2.66, 0.1))
	box("tire", Vector3(0.7, 0.25, 0.7), Vector3(-5.8, 0.13, 3.6))
	cyl("tire", 0.35, 0.35, 0.25, Vector3(5.4, 0.13, 3.8), Vector3.ZERO, 12)
	solid(Vector3(12.2, 2.8, 6.2), Vector3(0, 1.4, 0))
	finish("garages", "Garages")


func kiosk() -> void:
	for v in 2:
		begin()
		var m := "paint_blue" if v == 0 else "paint_red"
		box(m, Vector3(2.4, 2.2, 1.8), Vector3(0, 1.1, 0))
		box("glass_city" if v == 0 else "window_lit", Vector3(1.6, 0.9, 0.04), Vector3(0, 1.5, 0.92))
		box("planks_old", Vector3(1.8, 0.06, 0.4), Vector3(0, 1.0, 1.05))
		box("metal_roof", Vector3(2.8, 0.06, 2.3), Vector3(0, 2.28, 0.15), Vector3(-0.08, 0, 0))
		for i in 4:
			box(["bottle", "paper", "tin", "cloth_red"][i], Vector3(0.12, 0.2, 0.12), Vector3(-0.6 + i * 0.4, 1.12, 1.0))
		solid(Vector3(2.4, 2.2, 1.9), Vector3(0, 1.1, 0))
		slots["sign"] = Vector3(0, 2.55, 0.95)
		slots["seller"] = Vector3(0, 0, -1.4)
		finish("kiosk" if v == 0 else "kiosk_b", "Kiosk")


func bus_stop() -> void:
	begin()
	box("concrete", Vector3(4.0, 2.4, 0.15), Vector3(0, 1.2, -0.8))
	for sx in [-1, 1]:
		box("concrete", Vector3(0.15, 2.4, 1.6), Vector3(sx * 1.95, 1.2, 0))
	box("concrete", Vector3(4.4, 0.15, 2.0), Vector3(0, 2.45, -0.1))
	# мозаика на задней стене: солнце и олень
	box("paint_blue", Vector3(3.0, 1.2, 0.04), Vector3(0, 1.5, -0.7))
	cyl("brass", 0.3, 0.3, 0.05, Vector3(-0.8, 1.7, -0.67), Vector3(PI / 2.0, 0, 0), 12)
	box("paint_red", Vector3(0.9, 0.35, 0.05), Vector3(0.6, 1.35, -0.66))
	box("planks_old", Vector3(3.0, 0.08, 0.4), Vector3(0, 0.45, -0.45))
	box("metal_dark", Vector3(0.06, 2.4, 0.06), Vector3(2.6, 1.2, 0.8))
	box("paper", Vector3(0.5, 0.5, 0.04), Vector3(2.6, 2.3, 0.82))
	solid(Vector3(4.2, 2.4, 0.4), Vector3(0, 1.2, -0.8))
	solid(Vector3(0.3, 2.4, 1.6), Vector3(-1.95, 1.2, 0))
	solid(Vector3(0.3, 2.4, 1.6), Vector3(1.95, 1.2, 0))
	finish("bus_stop", "BusStop")


## Пролёт бетонного забора (плиты с узором «ромбы») 4 м вдоль X
func conc_fence() -> void:
	begin()
	box("concrete", Vector3(4.0, 2.2, 0.16), Vector3(0, 1.1, 0))
	for i in 4:
		box("concrete", Vector3(0.5, 0.5, 0.05), Vector3(-1.5 + i * 1.0, 1.4, 0.09), Vector3(0, 0, PI / 4.0))
	box("concrete", Vector3(0.3, 2.4, 0.3), Vector3(2.0, 1.2, 0))
	solid(Vector3(4.0, 2.2, 0.4), Vector3(0, 1.1, 0))
	finish("conc_fence", "ConcFence")


## Мёртвый автобус: кузов без колёс, окна выбиты
func paz_wreck() -> void:
	begin()
	box("paint_faded", Vector3(7.2, 1.2, 2.3), Vector3(0, 0.95, 0), Vector3(0, 0, 0.02))
	box("paint_white", Vector3(7.2, 0.9, 2.3), Vector3(0, 2.0, 0), Vector3(0, 0, 0.02))
	box("metal_roof", Vector3(7.0, 0.1, 2.2), Vector3(0, 2.5, 0))
	for i in 6:
		for sz in [-1, 1]:
			box("glass_city", Vector3(0.9, 0.7, 0.04), Vector3(-2.8 + i * 1.1, 2.0, sz * 1.16))
	box("glass_city", Vector3(0.04, 0.9, 2.0), Vector3(3.62, 1.95, 0))
	box("rust", Vector3(1.2, 0.4, 2.2), Vector3(3.2, 0.5, 0))
	for x in [-2.5, 2.3]:
		cyl("tire", 0.45, 0.45, 0.3, Vector3(x, 0.4, 1.15), Vector3(PI / 2.0, 0, 0), 12)
	add("rust", rough(rsphere(0.4, 7, 5), 0.1, 9), Vector3(-2.5, 0.2, -1.2))
	solid(Vector3(7.4, 2.6, 2.5), Vector3(0, 1.3, 0))
	finish("paz_wreck", "PazWreck")


func bins() -> void:
	begin()
	for i in 3:
		box(["metal_green", "rust", "metal_green"][i], Vector3(1.0, 1.1, 0.8), Vector3(-1.1 + i * 1.1, 0.55, 0))
		box("metal_dark", Vector3(1.05, 0.05, 0.85), Vector3(-1.1 + i * 1.1, 1.12, -0.05), Vector3(-0.15 * i, 0, 0))
	add("cloth_sack", rough(rsphere(0.3, 7, 5), 0.06, 4), Vector3(1.8, 0.25, 0.4))
	box("paper", Vector3(0.4, 0.3, 0.3), Vector3(-1.9, 0.15, 0.5), Vector3(0, 0.6, 0))
	solid(Vector3(3.4, 1.2, 0.9), Vector3(0, 0.6, 0))
	finish("bins", "Bins")


## Мебель для комнат верхних этажей (ставится в интерьерах)
func furniture() -> void:
	begin()
	_bed(0, 0)
	finish("f_bed", "Bed")
	begin()
	_wardrobe(0, 0)
	finish("f_wardrobe", "Wardrobe")
	begin()
	_table(0, 0, "planks_old", 2)
	finish("f_table", "Table")
	begin()
	_table(0, 0, "enamel", 2, "paper")
	finish("f_table_kitchen", "KitchenTable")
	begin()
	_table(0, 0, "planks_old", 4, "felt")
	finish("f_card_table", "CardTable")
	begin()
	_stove(0, 0)
	finish("f_stove", "Stove")
	begin()
	box("enamel", Vector3(0.7, 0.85, 0.6), Vector3(0, 0.43, 0))
	box("metal_dark", Vector3(0.6, 0.02, 0.5), Vector3(0, 0.87, 0))
	for c in [Vector2(-0.15, -0.12), Vector2(0.15, 0.12)]:
		cyl("metal_dark", 0.1, 0.1, 0.02, Vector3(c.x, 0.88, c.y), Vector3.ZERO, 10)
	cyl("tin", 0.14, 0.12, 0.2, Vector3(0.15, 0.98, 0.12), Vector3.ZERO, 10)
	solid(Vector3(0.7, 0.9, 0.6), Vector3(0, 0.45, 0))
	finish("f_kitchen_stove", "KitchenStove")
	begin()
	box("sofa", Vector3(2.0, 0.45, 0.8), Vector3(0, 0.23, 0))
	box("sofa", Vector3(2.0, 0.5, 0.2), Vector3(0, 0.6, -0.32))
	solid(Vector3(2.0, 0.8, 0.8), Vector3(0, 0.4, 0))
	finish("f_sofa", "Sofa")
	begin()
	_shelf_goods(0, 0, 2.0)
	finish("f_shelf", "Shelf")
	begin()
	box("enamel", Vector3(0.6, 0.8, 0.5), Vector3(0, 0.4, 0))
	box("enamel", Vector3(0.45, 0.06, 0.35), Vector3(0, 0.83, 0))
	cyl("tin", 0.02, 0.02, 0.3, Vector3(0, 1.0, -0.2), Vector3.ZERO, 5)
	solid(Vector3(0.6, 0.9, 0.5), Vector3(0, 0.45, 0))
	finish("f_sink", "Sink")
	begin()
	box("paint_door", Vector3(0.7, 0.55, 0.5), Vector3(0, 0.95, 0))
	box("glass_city", Vector3(0.45, 0.4, 0.05), Vector3(0, 0.97, 0.26))
	box("planks_old", Vector3(0.6, 0.65, 0.5), Vector3(0, 0.33, 0))
	solid(Vector3(0.6, 1.2, 0.6), Vector3(0, 0.6, 0))
	finish("f_tv", "Tv")
	begin()
	_plant(0, 0)
	finish("f_plant", "Plant")
	begin()
	box("metal_dark", Vector3(1.2, 1.4, 0.5), Vector3(0, 0.7, 0))
	for i in 6:
		cyl("tin", 0.06, 0.06, 0.1, Vector3(-0.4 + (i % 3) * 0.4, 0.5 + int(i / 3) * 0.5, 0.26), Vector3(PI / 2.0, 0, 0), 8)
	box("glass_city", Vector3(0.5, 0.3, 0.04), Vector3(0.25, 1.2, 0.26))
	cyl("metal_dark", 0.015, 0.015, 1.0, Vector3(-0.45, 1.9, 0), Vector3.ZERO, 4)
	solid(Vector3(1.2, 1.4, 0.55), Vector3(0, 0.7, 0))
	finish("f_radio", "Radio")
	begin()
	_stair_piece()
	finish("f_stairs", "Stairs")


## Марш лестницы для интерьеров: вверх к -Z, ступени и перила (без коллизии на подходе)
func _stair_piece() -> void:
	for i in 8:
		var y := 0.09 + i * 0.18
		box("concrete", Vector3(1.3, y + 0.09, 0.3), Vector3(0, (y + 0.09) / 2.0, 1.05 - i * 0.3))
	for sx in [-1, 1]:
		box("metal_dark", Vector3(0.04, 0.04, 2.5), Vector3(sx * 0.66, 1.25, 0.0), Vector3(0.6, 0, 0))
		for k in 3:
			box("metal_dark", Vector3(0.03, 0.8, 0.03), Vector3(sx * 0.66, 0.6 + k * 0.38, 0.8 - k * 0.8))
	solid(Vector3(1.4, 1.6, 2.4), Vector3(0, 0.8, 0))
