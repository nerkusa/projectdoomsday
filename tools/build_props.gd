extends Node
## Генератор построек и растительности в стиле референса «Нахарра».
## Текстуры делает tools/gen_textures.py. Каждый проп собирается из примитивов,
## детали сливаются в одну сетку на материал (меньше вызовов отрисовки),
## сетки лежат в assets/models/props/, сцены — в scenes/props/.
##
## Запуск: godot --headless --path . res://tools/build_props.tscn
## Перезаписывает сцены, перечисленные в _ready().

const MAT_DIR := "res://assets/materials/"
const TEX_DIR := "res://assets/textures/"
const MESH_DIR := "res://assets/models/props/"
const PROP_DIR := "res://scenes/props/"

var M: Dictionary = {}
var parts: Dictionary = {}   # материал -> [[mesh, transform]]
var shapes: Array = []       # [size, pos, rot_y] — коробки коллизии текущего пропа
## Дом, в который можно войти: всё, что выше cut_y (крыша, верх стен, окна),
## попадает в узел Upper и прячется, пока герой внутри (scripts/world/house.gd).
var cut_y := INF
var inner := Vector2.ZERO    # внутренний размер для house.gd; ноль — войти нельзя
var door_local := Vector3.ZERO
var slots: Dictionary = {}   # имя -> позиция: куда класть вещи (Marker3D Slot_*)
var _force_up := false       # деталь целиком в верхний слой (окна с наличниками)
var root_props: Dictionary = {}  # предмет: свойства Interactable (item_id, label, pick_size)
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(MESH_DIR)
	_materials()
	# жилые дома: базовая изба и варианты
	house("izba", {})
	house("izba_long", {"w": 7.4, "d": 4.4, "windows_front": 3, "chimney": Vector2(-2.2, -0.8), "porch_x": -0.6})
	house("izba_tall", {"w": 5.4, "d": 4.6, "floors": 2, "roof_h": 2.0, "windows_front": 2, "porch_x": 1.2})
	house("izba_lean", {"w": 5.0, "d": 4.2, "lean": true, "porch_x": 0.9, "patches": 3})
	house("izba_small", {"w": 4.0, "d": 3.6, "logs": 8, "roof_h": 1.4, "windows_front": 1, "porch_x": 0.2, "chimney": Vector2(-0.9, -0.5)})
	hall()
	tower()
	barn()
	shed()
	workshop()
	palisade()
	gate()
	barricade()
	greenhouse()
	wind_turbine()
	spruce()
	pine()
	travel_items()
	junk()
	locked_box()
	print("Постройки собраны.")
	get_tree().quit()


# ---------------- материалы ----------------
func _tex_mat(n: String, tex: String, scale: float, rough := 0.95, metal := 0.0, tint := Color.WHITE, world := false) -> void:
	var m := StandardMaterial3D.new()
	m.resource_name = n
	m.albedo_texture = load(TEX_DIR + tex + ".png")
	m.albedo_color = tint
	m.normal_enabled = true
	m.normal_texture = load(TEX_DIR + tex + "_n.png")
	m.roughness = rough
	m.metallic = metal
	# трипланарная проекция: UV примитивов не важны, рисунок не тянется
	m.uv1_triplanar = true
	m.uv1_world_triplanar = world
	m.uv1_triplanar_sharpness = 4.0
	m.uv1_scale = Vector3.ONE * scale
	ResourceSaver.save(m, MAT_DIR + n + ".tres")
	M[n] = load(MAT_DIR + n + ".tres")


func _plain_mat(n: String, c: Color, rough := 0.8, alpha := false) -> void:
	var m := StandardMaterial3D.new()
	m.resource_name = n
	m.albedo_color = c
	m.roughness = rough
	if alpha:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	ResourceSaver.save(m, MAT_DIR + n + ".tres")
	M[n] = load(MAT_DIR + n + ".tres")


func _materials() -> void:
	_tex_mat("log_weathered", "log_weathered", 0.45)
	_tex_mat("metal_roof", "metal_roof", 0.8, 0.7, 0.35, Color("a8a49c"))
	_tex_mat("planks_old", "planks_old", 0.8)
	_tex_mat("stone_wall", "stone_wall", 0.6)
	_tex_mat("trim", "planks_old", 1.6, 0.9, 0.0, Color("c9bfa8"))
	_tex_mat("needles_tex", "needles", 0.9, 1.0)
	_tex_mat("bark_dark", "bark_dark", 1.2)
	_tex_mat("metal_dark", "metal_roof", 1.5, 0.6, 0.5, Color("6a6a66"))
	# земля: мировая проекция, чтобы соседние куски стыковались
	_tex_mat("ground_grass", "grass_dark", 0.18, 1.0, 0.0, Color.WHITE, true)
	_tex_mat("ground_meadow", "meadow", 0.15, 1.0, 0.0, Color.WHITE, true)
	_tex_mat("ground_dirt", "dirt_road", 0.3, 1.0, 0.0, Color.WHITE, true)
	_plain_mat("film", Color(0.85, 0.9, 0.85, 0.35), 0.2, true)
	_plain_mat("cloth_sack", Color("7a6a4a"), 1.0)
	_plain_mat("blade", Color("b8b0a0"), 0.6)
	_plain_mat("cloth_red", Color("7a2e24"), 1.0)
	_plain_mat("hay", Color("6e6232"), 1.0)
	_plain_mat("whitewash", Color("8c8678"), 0.95)
	_plain_mat("tin", Color("a7a49a"), 0.4)
	_plain_mat("paper", Color("c9b98a"), 0.9)
	_plain_mat("bread", Color("7a5230"), 1.0)
	_plain_mat("fish", Color("8a7a52"), 0.7)
	_plain_mat("herb", Color("4d6a34"), 1.0)
	_plain_mat("rope_mat", Color("a08a5a"), 1.0)
	_plain_mat("brass", Color("b08a3a"), 0.4)
	M["window"] = load(MAT_DIR + "window.tres")
	M["rust"] = load(MAT_DIR + "rust.tres")


# ---------------- сборка пропа ----------------
func begin() -> void:
	parts = {}
	shapes = []
	cut_y = INF
	inner = Vector2.ZERO
	door_local = Vector3.ZERO
	slots = {}
	root_props = {}


func add(mat: String, mesh: Mesh, pos: Vector3, rot := Vector3.ZERO) -> void:
	var key := mat + ("@up" if pos.y > cut_y or (_force_up and cut_y < INF) else "")
	if not parts.has(key):
		parts[key] = []
	parts[key].append([mesh, Transform3D(Basis.from_euler(rot), pos)])


func box(mat: String, size: Vector3, pos: Vector3, rot := Vector3.ZERO) -> void:
	var b := BoxMesh.new()
	b.size = size
	add(mat, b, pos, rot)


func cyl(mat: String, r_top: float, r_bot: float, h: float, pos: Vector3, rot := Vector3.ZERO, seg := 10) -> void:
	var c := CylinderMesh.new()
	c.top_radius = r_top
	c.bottom_radius = r_bot
	c.height = h
	c.radial_segments = seg
	c.rings = 1
	add(mat, c, pos, rot)


func prism(mat: String, size: Vector3, pos: Vector3, rot := Vector3.ZERO) -> void:
	var p := PrismMesh.new()
	p.size = size
	add(mat, p, pos, rot)


func solid(size: Vector3, pos: Vector3, rot_y := 0.0) -> void:
	shapes.append([size, pos, rot_y])


func finish(n: String, root_name := "") -> void:
	var root := Node3D.new()
	root.name = root_name if root_name != "" else n.to_pascal_case()
	var upper: Node3D = null
	for key in parts:
		var up: bool = key.ends_with("@up")
		var m: String = key.trim_suffix("@up")
		var mi := MeshInstance3D.new()
		mi.name = "Mesh_" + m
		mi.mesh = _merge(parts[key], MESH_DIR + n + "_" + m + ("_up" if up else "") + ".res")
		mi.material_override = M[m]
		if up:
			if upper == null:
				upper = Node3D.new()
				upper.name = "Upper"
				root.add_child(upper)
				upper.owner = root
			upper.add_child(mi)
		else:
			root.add_child(mi)
		mi.owner = root
	if not root_props.is_empty():
		root.set_script(load("res://scripts/world/interactable.gd"))
		for k in root_props:
			root.set(k, root_props[k])
	if inner != Vector2.ZERO:
		root.set_script(load("res://scripts/world/house.gd"))
		root.set("inner", inner)
		root.set("door", door_local)
	for k in slots:
		var mk := Marker3D.new()
		mk.name = "Slot_" + k
		mk.position = slots[k]
		root.add_child(mk)
		mk.owner = root
	if not shapes.is_empty():
		var body := StaticBody3D.new()
		body.name = "Collision"
		body.collision_mask = 0
		root.add_child(body)
		body.owner = root
		for s in shapes:
			var cs := CollisionShape3D.new()
			var bs := BoxShape3D.new()
			bs.size = s[0]
			cs.shape = bs
			cs.position = s[1]
			cs.rotation.y = s[2]
			body.add_child(cs)
			cs.owner = root
	var ps := PackedScene.new()
	ps.pack(root)
	ResourceSaver.save(ps, PROP_DIR + n + ".tscn")
	root.free()
	print("  ", n)


func _merge(list: Array, path: String) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for it in list:
		var mesh: Mesh = it[0]
		for s in mesh.get_surface_count():
			st.append_from(mesh, s, it[1])
	st.generate_tangents()
	var am := st.commit()
	ResourceSaver.save(am, path)
	return load(path)


# ---------------- общие детали ----------------
## Сруб: брёвна вперевязку с выпусками на углах. Возвращает высоту верха стен.
## door_w > 0 — в передней стене (+Z) проём шириной door_w у x = door_x, высотой door_h.
func log_walls(w: float, d: float, base: float, logs: int, r := 0.15, door_x := 0.0, door_w := 0.0, door_h := 2.0) -> float:
	var step := r * 2.0 * 0.92
	for i in logs:
		var y := base + r + i * step
		var jitter := 0.004 * ((i * 7) % 5)
		for sz in [-1, 1]:
			if sz > 0 and door_w > 0.0 and y < base + door_h:
				var l0 := -w / 2.0 - 0.3
				var l1 := door_x - door_w / 2.0
				var r0 := door_x + door_w / 2.0
				var r1 := w / 2.0 + 0.3
				cyl("log_weathered", r + jitter, r + jitter, l1 - l0, Vector3((l0 + l1) / 2.0, y, d / 2.0), Vector3(0, 0, PI / 2.0))
				cyl("log_weathered", r + jitter, r + jitter, r1 - r0, Vector3((r0 + r1) / 2.0, y, d / 2.0), Vector3(0, 0, PI / 2.0))
				continue
			cyl("log_weathered", r + jitter, r + jitter, w + 0.6, Vector3(0, y, sz * d / 2.0), Vector3(0, 0, PI / 2.0))
		if i < logs - 1:
			for sx in [-1, 1]:
				cyl("log_weathered", r, r, d + 0.6, Vector3(sx * w / 2.0, y + step / 2.0, 0), Vector3(PI / 2.0, 0, 0))
	return base + logs * step


## Двускатная крыша из профнастила с коньком вдоль X и заплатами. Фронтоны из досок.
func gable_roof(w: float, d: float, top: float, h: float, eave := 0.45, patches := 2, gable_window := true) -> void:
	var hx := w / 2.0
	var hz := d / 2.0
	for sx in [-1, 1]:
		prism("planks_old", Vector3(d + 0.1, h, 0.12), Vector3(sx * (hx - 0.02), top + h / 2.0, 0), Vector3(0, PI / 2.0, 0))
		if gable_window:
			box("window", Vector3(0.06, 0.4, 0.4), Vector3(sx * (hx + 0.05), top + h * 0.35, 0))
			box("trim", Vector3(0.05, 0.52, 0.06), Vector3(sx * (hx + 0.08), top + h * 0.35, 0.23))
			box("trim", Vector3(0.05, 0.52, 0.06), Vector3(sx * (hx + 0.08), top + h * 0.35, -0.23))
	var run := hz + eave
	var ang := atan2(h, hz)
	var drop := eave * tan(ang)
	var slope := Vector2(run, h + drop).length()
	var ridge_y := top + h + 0.06
	for sz in [-1, 1]:
		var mid := Vector3(0, ridge_y - (h + drop) / 2.0, sz * run / 2.0)
		var rot := Vector3(sz * ang, 0, 0)
		box("metal_roof", Vector3(w + 1.0, 0.05, slope), mid, rot)
		# заплаты — листы поменьше поверх ската (смещение в плоскости ската)
		var rb := Basis.from_euler(rot)
		for k in patches:
			var fx := (_rng.randf() - 0.5) * (w - 1.5)
			var fz := (_rng.randf() - 0.5) * slope * 0.5
			var pw := _rng.randf_range(0.8, 1.5)
			box("metal_roof", Vector3(pw, 0.05, slope * _rng.randf_range(0.3, 0.55)), mid + rb * Vector3(fx, 0.05, sz * fz), rot)
	box("metal_roof", Vector3(w + 1.05, 0.12, 0.3), Vector3(0, ridge_y + 0.04, 0), Vector3(PI / 4.0, 0, 0))


## Окно с наличником и ставнями. pos — центр на стене, rot — поворот стены.
func window(pos: Vector3, rot: Vector3, shutters := true) -> void:
	_force_up = true
	_window(pos, rot, shutters)
	_force_up = false


func _window(pos: Vector3, rot: Vector3, shutters: bool) -> void:
	var b := Basis.from_euler(rot)
	var at := func(local: Vector3) -> Vector3: return pos + b * local
	box("window", Vector3(0.7, 0.8, 0.05), at.call(Vector3.ZERO), rot)
	box("trim", Vector3(0.9, 0.12, 0.1), at.call(Vector3(0, 0.46, 0.04)), rot)
	box("trim", Vector3(0.95, 0.1, 0.16), at.call(Vector3(0, -0.46, 0.06)), rot)
	box("trim", Vector3(0.1, 0.9, 0.08), at.call(Vector3(-0.4, 0, 0.04)), rot)
	box("trim", Vector3(0.1, 0.9, 0.08), at.call(Vector3(0.4, 0, 0.04)), rot)
	box("trim", Vector3(0.05, 0.8, 0.06), at.call(Vector3(0, 0, 0.04)), rot)
	if shutters:
		box("planks_old", Vector3(0.36, 0.86, 0.05), at.call(Vector3(-0.66, 0, 0.03)), rot)
		box("planks_old", Vector3(0.36, 0.86, 0.05), at.call(Vector3(0.66, 0, 0.03)), rot)


## Дверной проём с наличником на фасаде (+Z); дверь распахнута внутрь
func door(x: float, base: float, front: float, width := 0.95) -> void:
	var hinge := Vector3(x - width / 2.0, base + 0.98, front - 0.15)
	var leaf_rot := Vector3(0, -1.75, 0)
	box("planks_old", Vector3(width - 0.1, 1.95, 0.08), hinge + Basis.from_euler(leaf_rot) * Vector3((width - 0.1) / 2.0, 0, 0), leaf_rot)
	box("trim", Vector3(0.12, 2.1, 0.1), Vector3(x - width / 2.0 - 0.06, base + 1.05, front + 0.02))
	box("trim", Vector3(0.12, 2.1, 0.1), Vector3(x + width / 2.0 + 0.06, base + 1.05, front + 0.02))
	box("trim", Vector3(width + 0.25, 0.14, 0.1), Vector3(x, base + 2.07, front + 0.02))


## Стены-коллизии дома с проёмом в передней стене (+Z)
func wall_colliders(w: float, d: float, door_x: float, door_w: float, h := 2.8) -> void:
	var t := 0.4
	solid(Vector3(w + 0.6, h, t), Vector3(0, h / 2.0, -d / 2.0))
	solid(Vector3(t, h, d + 0.6), Vector3(-w / 2.0, h / 2.0, 0))
	solid(Vector3(t, h, d + 0.6), Vector3(w / 2.0, h / 2.0, 0))
	var l0 := -w / 2.0 - 0.3
	var l1 := door_x - door_w / 2.0
	var r0 := door_x + door_w / 2.0
	var r1 := w / 2.0 + 0.3
	solid(Vector3(l1 - l0, h, t), Vector3((l0 + l1) / 2.0, h / 2.0, d / 2.0))
	solid(Vector3(r1 - r0, h, t), Vector3((r0 + r1) / 2.0, h / 2.0, d / 2.0))


## Фундамент-цоколь по периметру (внутри — дощатый пол на уровне земли)
func plinth(w: float, d: float, base: float) -> void:
	box("stone_wall", Vector3(w + 0.3, base, 0.45), Vector3(0, base / 2.0, -d / 2.0))
	box("stone_wall", Vector3(w + 0.3, base, 0.45), Vector3(0, base / 2.0, d / 2.0))
	box("stone_wall", Vector3(0.45, base, d + 0.3), Vector3(-w / 2.0, base / 2.0, 0))
	box("stone_wall", Vector3(0.45, base, d + 0.3), Vector3(w / 2.0, base / 2.0, 0))
	box("planks_old", Vector3(w - 0.2, 0.04, d - 0.2), Vector3(0, 0.02, 0))


## Обстановка избы: печь под трубой, кровать, стол с лавкой, сундук, половик.
## Ставит метки Slot_* для вещей и коллизии крупной мебели.
func izba_interior(w: float, d: float, ch: Vector2, door_x: float) -> void:
	var hx := w / 2.0
	var hz := d / 2.0
	# русская печь, беленая, под трубой
	var sx := clampf(ch.x, -hx + 0.8, hx - 0.8)
	var sz := clampf(ch.y, -hz + 0.8, hz - 0.8)
	box("whitewash", Vector3(1.2, 1.3, 1.3), Vector3(sx, 0.65, sz))
	box("stone_wall", Vector3(1.3, 0.12, 1.4), Vector3(sx, 1.36, sz))
	box("window", Vector3(0.45, 0.35, 0.04), Vector3(sx, 0.55, sz + 0.66))
	solid(Vector3(1.3, 1.4, 1.4), Vector3(sx, 0.7, sz))
	slots["stove"] = Vector3(sx + 0.25, 1.42, sz)
	# кровать вдоль правой стены у задней
	var bx := hx - 0.6
	var bz := -hz + 1.15
	box("planks_old", Vector3(0.95, 0.4, 1.95), Vector3(bx, 0.2, bz))
	box("cloth_red", Vector3(0.9, 0.08, 1.6), Vector3(bx, 0.44, bz + 0.15))
	box("cloth_sack", Vector3(0.6, 0.1, 0.35), Vector3(bx, 0.46, bz - 0.75))
	solid(Vector3(1.0, 0.6, 2.0), Vector3(bx, 0.3, bz))
	slots["bed"] = Vector3(bx, 0.5, bz + 0.3)
	# сундук у задней стены рядом с изголовьем (подальше от двери)
	var cx := bx - 1.25
	var cz := -hz + 0.45
	box("planks_old", Vector3(0.8, 0.45, 0.5), Vector3(cx, 0.23, cz))
	box("metal_dark", Vector3(0.83, 0.05, 0.53), Vector3(cx, 0.3, cz))
	solid(Vector3(0.8, 0.5, 0.55), Vector3(cx, 0.25, cz))
	slots["chest"] = Vector3(cx, 0.47, cz)
	# стол и лавка у передней стены слева от двери
	var tx := -hx + 1.1
	var tz := hz - 1.0
	if absf(tx - door_x) < 1.6:
		tx = door_x - 1.7
	box("planks_old", Vector3(1.2, 0.06, 0.8), Vector3(tx, 0.76, tz))
	for lx in [-0.5, 0.5]:
		for lz in [-0.32, 0.32]:
			box("planks_old", Vector3(0.07, 0.73, 0.07), Vector3(tx + lx, 0.37, tz + lz))
	box("planks_old", Vector3(1.3, 0.07, 0.3), Vector3(tx, 0.42, tz + 0.7))
	box("planks_old", Vector3(1.3, 0.07, 0.3), Vector3(tx, 0.42, tz - 0.7))
	solid(Vector3(1.2, 0.8, 0.8), Vector3(tx, 0.4, tz))
	slots["table"] = Vector3(tx + 0.2, 0.8, tz)
	# половик посередине
	box("cloth_sack", Vector3(1.4, 0.015, 0.9), Vector3(0.1, 0.05, -0.2))
	slots["floor"] = Vector3(0.1, 0.06, -0.2)


## Крыльцо: помост, ступени, навес на кронштейнах
func porch(x: float, base: float, front: float) -> void:
	box("planks_old", Vector3(1.8, 0.14, 1.0), Vector3(x, base - 0.07, front + 0.5))
	var steps := int(ceil(base / 0.2))
	for i in steps:
		box("planks_old", Vector3(1.6, 0.14, 0.32), Vector3(x, base - 0.21 - i * 0.18, front + 1.1 + i * 0.3))
	box("metal_roof", Vector3(1.9, 0.04, 1.25), Vector3(x, base + 2.45, front + 0.55), Vector3(0.28, 0, 0))
	for sx in [-1, 1]:
		box("planks_old", Vector3(0.08, 0.08, 1.1), Vector3(x + sx * 0.8, base + 2.1, front + 0.45), Vector3(-0.6, 0, 0))


func chimney(x: float, z: float, top: float, h: float) -> void:
	box("stone_wall", Vector3(0.6, h, 0.6), Vector3(x, top + h / 2.0 - 0.6, z))
	box("stone_wall", Vector3(0.75, 0.15, 0.75), Vector3(x, top + h - 0.52, z))


# ---------------- жилые дома ----------------
## opts: w, d, logs, floors, roof_h, windows_front, porch_x, chimney (Vector2 x,z), lean, patches
func house(n: String, opts: Dictionary) -> void:
	begin()
	_rng.seed = hash(n)
	var w: float = opts.get("w", 5.0)
	var d: float = opts.get("d", 4.2)
	var floors: int = opts.get("floors", 1)
	var logs: int = opts.get("logs", 9) * floors + (1 if floors > 1 else 0)
	var roof_h: float = opts.get("roof_h", 1.7)
	var base := 0.2
	var hx := w / 2.0
	var hz := d / 2.0
	var r := 0.15
	var px: float = opts.get("porch_x", 0.9)
	# проём не уже 1,9 м: при любом повороте дома через него проходит хотя бы один гекс
	var door_w := 1.9
	cut_y = base + 0.95
	inner = Vector2(w - 0.3, d - 0.3)
	door_local = Vector3(px, 0, hz)
	plinth(w, d, base)
	var top := log_walls(w, d, base, logs, r, px, door_w, 2.0)
	gable_roof(w, d, top, roof_h, 0.45, opts.get("patches", 2))
	var ch: Vector2 = opts.get("chimney", Vector2(-1.3, -0.8))
	chimney(ch.x, ch.y, top + roof_h * (1.0 - absf(ch.y) / hz), 2.0)
	var front := hz + r + 0.02
	door(px, base, front, door_w)
	porch(px, base, front)
	# окна по фасаду — равномерно, в обход двери
	var nwin: int = opts.get("windows_front", 2)
	var slots := []
	for i in nwin + 1:
		slots.append(-hx + 0.9 + i * (w - 1.8) / maxf(1, nwin))
	var placed := 0
	for sx in slots:
		if placed >= nwin:
			break
		if absf(sx - px) < 2.0:
			continue
		for f in floors:
			window(Vector3(sx, base + 1.35 + f * 2.5, front), Vector3.ZERO)
		placed += 1
	for f in floors:
		window(Vector3(hx + r + 0.02, base + 1.35 + f * 2.5, 0.5), Vector3(0, PI / 2.0, 0))
		window(Vector3(-hx - r - 0.02, base + 1.35 + f * 2.5, -0.4), Vector3(0, -PI / 2.0, 0))
		window(Vector3(0.3, base + 1.35 + f * 2.5, -front), Vector3(0, PI, 0))
	if opts.get("lean", false):
		# дощатая пристройка-сени сбоку под односкатной крышей
		var lx := -hx - 1.35
		box("planks_old", Vector3(2.2, 2.3, d - 0.6), Vector3(lx, 1.15, 0))
		box("metal_roof", Vector3(2.8, 0.05, d + 0.2), Vector3(lx, 2.55, 0), Vector3(0, 0, 0.3))
		box("planks_old", Vector3(0.9, 1.8, 0.06), Vector3(lx, 0.9, (d - 0.6) / 2.0 + 0.03))
		solid(Vector3(2.4, 2.4, d - 0.4), Vector3(lx, 1.2, 0))
	# мелочи у стены: бочка и поленница под окном
	cyl("metal_dark", 0.3, 0.3, 0.85, Vector3(hx + 0.55, 0.43, hz - 0.3))
	for i in 3:
		cyl("log_weathered", 0.12, 0.12, 0.9, Vector3(-hx + 0.8 + i * 0.26, 0.12, -hz - 0.45), Vector3(0, 0, PI / 2.0), 7)
	izba_interior(w, d, ch, px)
	wall_colliders(w, d, px, door_w)
	finish(n, "Izba")


# ---------------- дом собраний ----------------
func hall() -> void:
	begin()
	_rng.seed = 11
	var w := 14.0
	var d := 7.0
	var base := 0.2
	var r := 0.17
	var door_w := 2.2
	cut_y = base + 1.0
	inner = Vector2(w - 0.4, d - 0.4)
	door_local = Vector3(0, 0, d / 2.0)
	plinth(w, d, base)
	var top := log_walls(w, d, base, 11, r, 0.0, door_w, 2.6)
	gable_roof(w, d, top, 2.6, 0.7, 5)
	var front := d / 2.0 + r + 0.02
	# двустворчатые ворота распахнуты внутрь
	for sx in [-1, 1]:
		var hinge := Vector3(sx * door_w / 2.0, base + 1.3, front - 0.2)
		var rot := Vector3(0, sx * 1.7, 0)
		box("planks_old", Vector3(door_w / 2.0, 2.6, 0.1), hinge + Basis.from_euler(rot) * Vector3(-sx * door_w / 4.0, 0, 0), rot)
	box("trim", Vector3(2.6, 0.18, 0.12), Vector3(0, base + 2.7, front + 0.03))
	box("trim", Vector3(0.14, 2.8, 0.12), Vector3(-1.2, base + 1.4, front + 0.03))
	box("trim", Vector3(0.14, 2.8, 0.12), Vector3(1.2, base + 1.4, front + 0.03))
	# веранда во всю длину фасада на столбах
	box("planks_old", Vector3(w, 0.16, 2.2), Vector3(0, base - 0.08, front + 1.1))
	box("planks_old", Vector3(3.0, 0.14, 0.34), Vector3(0, 0.07, front + 2.35))
	box("metal_roof", Vector3(w + 0.4, 0.05, 2.7), Vector3(0, base + 3.0, front + 1.2), Vector3(0.22, 0, 0))
	for i in 6:
		var x := -w / 2.0 + 0.4 + i * (w - 0.8) / 5.0
		cyl("log_weathered", 0.12, 0.13, 3.0, Vector3(x, base + 1.4, front + 2.1), Vector3.ZERO, 8)
	for sx in [-5.4, -3.2, 3.2, 5.4]:
		window(Vector3(sx, base + 1.5, front), Vector3.ZERO)
	for sx in [-5.0, -1.8, 1.8, 5.0]:
		window(Vector3(sx, base + 1.5, -front), Vector3(0, PI, 0))
	window(Vector3(w / 2.0 + r + 0.02, base + 1.5, 0), Vector3(0, PI / 2.0, 0))
	window(Vector3(-w / 2.0 - r - 0.02, base + 1.5, 0), Vector3(0, -PI / 2.0, 0))
	chimney(-4.0, -1.2, top + 2.6 * (1.0 - 1.2 / 3.5), 2.4)
	chimney(4.5, -1.0, top + 2.6 * (1.0 - 1.0 / 3.5), 2.4)
	box("trim", Vector3(3.2, 0.5, 0.06), Vector3(0, top + 0.5, front + 0.02))
	# внутри: длинный общий стол с лавками, две печи, лари с припасами
	box("planks_old", Vector3(7.0, 0.08, 1.2), Vector3(0, 0.78, -0.4))
	for lx in [-3.2, 0.0, 3.2]:
		box("planks_old", Vector3(0.12, 0.75, 1.0), Vector3(lx, 0.38, -0.4))
	for bz in [-1.35, 0.55]:
		box("planks_old", Vector3(7.0, 0.08, 0.35), Vector3(0, 0.44, bz))
	solid(Vector3(7.0, 0.8, 1.2), Vector3(0, 0.4, -0.4))
	for c in [Vector2(-4.0, -2.4), Vector2(4.5, -2.4)]:
		box("whitewash", Vector3(1.3, 1.3, 1.3), Vector3(c.x, 0.65, c.y))
		box("stone_wall", Vector3(1.4, 0.12, 1.4), Vector3(c.x, 1.36, c.y))
		solid(Vector3(1.4, 1.4, 1.4), Vector3(c.x, 0.7, c.y))
	for i in 3:
		box("planks_old", Vector3(0.9, 0.6, 0.6), Vector3(-6.0 + i * 1.0, 0.3, 2.6))
	solid(Vector3(3.0, 0.6, 0.7), Vector3(-5.0, 0.3, 2.6))
	slots["table"] = Vector3(1.2, 0.83, -0.4)
	slots["table2"] = Vector3(-2.0, 0.83, -0.5)
	slots["chest"] = Vector3(-5.0, 0.62, 2.6)
	slots["floor"] = Vector3(5.0, 0.06, 1.8)
	wall_colliders(w, d, 0.0, door_w, 3.2)
	finish("hall", "Hall")


# ---------------- сторожевая вышка ----------------
func tower() -> void:
	begin()
	var s := 1.3   # половина расстояния между столбами
	var hgt := 6.0
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			cyl("log_weathered", 0.13, 0.16, hgt + 1.4, Vector3(sx * s, (hgt + 1.4) / 2.0, sz * s), Vector3(sz * 0.04, 0, -sx * 0.04), 8)
	# раскосы крест-накрест на двух ярусах
	for y in [1.6, 3.8]:
		for side in 4:
			var rot := Vector3(0, side * PI / 2.0, 0)
			var b := Basis.from_euler(rot)
			var pos := b * Vector3(0, y, s)
			box("planks_old", Vector3(2.9, 0.1, 0.08), pos, rot + Vector3(0, 0, 0.62))
			box("planks_old", Vector3(2.9, 0.1, 0.08), pos, rot + Vector3(0, 0, -0.62))
	# площадка с бортом из досок
	box("planks_old", Vector3(3.3, 0.14, 3.3), Vector3(0, hgt, 0))
	for side in 4:
		var rot := Vector3(0, side * PI / 2.0, 0)
		var b := Basis.from_euler(rot)
		box("planks_old", Vector3(3.3, 0.9, 0.08), b * Vector3(0, hgt + 0.5, 1.62), rot)
	# четырёхскатная крыша-шатёр
	var roof := CylinderMesh.new()
	roof.top_radius = 0.02
	roof.bottom_radius = 2.6
	roof.height = 1.3
	roof.radial_segments = 4
	roof.rings = 1
	add("metal_roof", roof, Vector3(0, hgt + 2.1, 0), Vector3(0, PI / 4.0, 0))
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			cyl("log_weathered", 0.07, 0.07, 1.4, Vector3(sx * 1.55, hgt + 0.8, sz * 1.55), Vector3.ZERO, 6)
	# лестница
	for i in 16:
		box("planks_old", Vector3(0.6, 0.06, 0.08), Vector3(0, 0.3 + i * 0.37, s + 0.55 - i * 0.03))
	for sx in [-1, 1]:
		box("planks_old", Vector3(0.08, 6.2, 0.1), Vector3(sx * 0.32, 3.0, s + 0.35), Vector3(-0.08, 0, 0))
	solid(Vector3(2.9, 3.0, 2.9), Vector3(0, 1.5, 0))
	finish("tower", "Tower")


# ---------------- амбар ----------------
func barn() -> void:
	begin()
	_rng.seed = 7
	var w := 9.0
	var d := 6.0
	var door_w := 2.8
	var cut := 1.3
	cut_y = cut
	inner = Vector2(w - 0.3, d - 0.3)
	door_local = Vector3(0, 0, d / 2.0)
	# дощатые стены на каркасе, двумя поясами: нижний остаётся, верхний прячется
	box("stone_wall", Vector3(w + 0.2, 0.2, 0.3), Vector3(0, 0.1, -d / 2.0))
	box("stone_wall", Vector3(0.3, 0.2, d + 0.2), Vector3(-w / 2.0, 0.1, 0))
	box("stone_wall", Vector3(0.3, 0.2, d + 0.2), Vector3(w / 2.0, 0.1, 0))
	for band in [[0.2, cut - 0.05], [cut + 0.05, 3.6]]:
		var h: float = band[1] - band[0]
		var y: float = (band[0] + band[1]) / 2.0
		box("planks_old", Vector3(w, h, 0.14), Vector3(0, y, -d / 2.0))
		box("planks_old", Vector3(0.14, h, d), Vector3(w / 2.0, y, 0))
		box("planks_old", Vector3(0.14, h, d), Vector3(-w / 2.0, y, 0))
		var side := (w - door_w) / 2.0
		for sx in [-1, 1]:
			box("planks_old", Vector3(side, h, 0.14), Vector3(sx * (door_w / 2.0 + side / 2.0), y, d / 2.0))
	box("planks_old", Vector3(door_w, 0.6, 0.14), Vector3(0, 3.3, d / 2.0))
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			box("log_weathered", Vector3(0.3, 3.4, 0.3), Vector3(sx * w / 2.0, 1.9, sz * d / 2.0))
	gable_roof(w, d, 3.6, 2.2, 0.55, 4, false)
	# широкие ворота распахнуты наружу, створки с раскосами
	for sx in [-1, 1]:
		var rot := Vector3(0, -sx * 1.4, 0)
		var hinge := Vector3(sx * door_w / 2.0, 1.55, d / 2.0 + 0.1)
		var bb := Basis.from_euler(rot)
		box("planks_old", Vector3(1.4, 2.7, 0.1), hinge + bb * Vector3(sx * 0.7, 0, 0), rot)
		box("trim", Vector3(1.4, 0.12, 0.06), hinge + bb * Vector3(sx * 0.7, 0, 0.07), rot + Vector3(0, 0, sx * 0.9))
	box("planks_old", Vector3(1.0, 0.8, 0.08), Vector3(0, 4.4, d / 2.0 + 0.04))
	# мешки и ящики у входа снаружи
	for i in 3:
		box("cloth_sack", Vector3(0.55, 0.35, 0.4), Vector3(-3.4 + i * 0.5, 0.18, d / 2.0 + 0.5), Vector3(0, i * 0.3, 0))
	box("planks_old", Vector3(0.8, 0.7, 0.8), Vector3(3.3, 0.35, d / 2.0 + 0.6))
	# внутри: сено, мешки с зерном, ящики, лари
	box("hay", Vector3(2.8, 1.0, 2.2), Vector3(-2.9, 0.5, -1.6))
	box("hay", Vector3(1.8, 0.6, 1.4), Vector3(-2.6, 1.3, -1.8))
	solid(Vector3(2.8, 1.0, 2.2), Vector3(-2.9, 0.5, -1.6))
	for i in 6:
		box("cloth_sack", Vector3(0.6, 0.4, 0.45), Vector3(2.4 + (i % 3) * 0.62, 0.2 + int(i / 3) * 0.4, -2.3), Vector3(0, i * 0.2, 0))
	solid(Vector3(2.0, 0.8, 0.6), Vector3(3.0, 0.4, -2.3))
	for i in 3:
		box("planks_old", Vector3(0.8, 0.7, 0.8), Vector3(3.6, 0.35, -0.6 + i * 0.9), Vector3(0, i * 0.15, 0))
	solid(Vector3(0.9, 0.7, 2.7), Vector3(3.6, 0.35, 0.3))
	slots["floor"] = Vector3(0.6, 0.02, -1.4)
	slots["chest"] = Vector3(3.6, 0.72, 0.3)
	slots["sacks"] = Vector3(3.0, 0.82, -2.3)
	wall_colliders(w, d, 0.0, door_w, 3.4)
	finish("barn", "Barn")


# ---------------- сарай / хозпостройка ----------------
func shed() -> void:
	begin()
	var w := 3.6
	var d := 2.8
	box("planks_old", Vector3(w, 2.3, d), Vector3(0, 1.15, 0))
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			box("log_weathered", Vector3(0.18, 2.5, 0.18), Vector3(sx * w / 2.0, 1.25, sz * d / 2.0))
	box("metal_roof", Vector3(w + 0.7, 0.05, d + 0.9), Vector3(0, 2.55, 0), Vector3(-0.22, 0, 0))
	box("planks_old", Vector3(1.0, 1.9, 0.06), Vector3(-0.8, 0.95, d / 2.0 + 0.03))
	box("trim", Vector3(1.0, 0.1, 0.05), Vector3(-0.8, 0.95, d / 2.0 + 0.07), Vector3(0, 0, 0.9))
	solid(Vector3(w + 0.3, 2.5, d + 0.3), Vector3(0, 1.25, 0))
	finish("shed", "Shed")


func workshop() -> void:
	begin()
	var w := 6.0
	var d := 4.4
	box("stone_wall", Vector3(w + 0.2, 0.3, d + 0.2), Vector3(0, 0.15, 0))
	var top := log_walls(w, d, 0.3, 7, 0.15)
	# плоская односкатная крыша из профнастила на балках
	box("metal_roof", Vector3(w + 1.2, 0.06, d + 1.4), Vector3(0, top + 0.45, 0.1), Vector3(-0.18, 0, 0))
	# большие ворота (+Z) и верстак под навесом
	box("metal_dark", Vector3(2.4, 2.2, 0.1), Vector3(-1.2, 1.4, d / 2.0 + 0.17))
	box("trim", Vector3(2.6, 0.14, 0.12), Vector3(-1.2, 2.55, d / 2.0 + 0.2))
	window(Vector3(1.6, 1.6, d / 2.0 + 0.17), Vector3.ZERO, false)
	# труба-буржуйка
	cyl("metal_dark", 0.12, 0.12, 2.4, Vector3(2.2, top + 1.0, -1.2), Vector3.ZERO, 8)
	# бочки и железо у стены
	for i in 3:
		cyl("metal_dark", 0.3, 0.3, 0.85, Vector3(w / 2.0 + 0.5, 0.43, -1.2 + i * 0.7))
	box("metal_dark", Vector3(1.2, 0.8, 0.7), Vector3(-w / 2.0 - 0.7, 0.4, 0.8))
	solid(Vector3(w + 1.6, 2.8, d + 0.6), Vector3(0.2, 1.4, 0))
	finish("workshop", "Workshop")


# ---------------- частокол, ворота, баррикада ----------------
## Пролёт частокола 4 м вдоль X: заострённые брёвна и поперечины
func palisade() -> void:
	begin()
	_rng.seed = 3
	var n := 13
	for i in n:
		var x := -2.0 + 0.15 + i * (4.0 - 0.3) / (n - 1)
		var h := _rng.randf_range(2.2, 2.6)
		cyl("log_weathered", 0.14, 0.15, h, Vector3(x, h / 2.0, 0), Vector3.ZERO, 7)
		cyl("log_weathered", 0.0, 0.14, 0.35, Vector3(x, h + 0.17, 0), Vector3.ZERO, 7)
	for y in [0.6, 1.8]:
		box("planks_old", Vector3(4.0, 0.14, 0.1), Vector3(0, y, -0.2))
	solid(Vector3(4.0, 2.4, 0.5), Vector3(0, 1.2, 0))
	finish("palisade", "Palisade")


## Ворота в частоколе: проём 4 м, столбы, перекладина, распахнутые створки
func gate() -> void:
	begin()
	for sx in [-1, 1]:
		cyl("log_weathered", 0.2, 0.22, 4.2, Vector3(sx * 2.2, 2.1, 0), Vector3.ZERO, 8)
		# створка распахнута внутрь (-Z)
		var leaf_rot := Vector3(0, -sx * 1.2, 0)
		var b := Basis.from_euler(leaf_rot)
		for k in 6:
			cyl("log_weathered", 0.1, 0.1, 2.3, Vector3(sx * 2.05, 1.2, 0) + b * Vector3(-sx * (0.12 + k * 0.3), 0, 0), Vector3.ZERO, 6)
		box("planks_old", Vector3(1.9, 0.12, 0.08), Vector3(sx * 2.05, 1.6, 0) + b * Vector3(-sx * 0.95, 0, -0.12), leaf_rot)
		solid(Vector3(0.6, 4.0, 0.6), Vector3(sx * 2.2, 2.0, 0))
	box("log_weathered", Vector3(5.2, 0.35, 0.35), Vector3(0, 4.0, 0))
	box("trim", Vector3(2.0, 0.45, 0.06), Vector3(0, 3.55, 0.2))
	finish("gate", "Gate")


## Баррикада: ящики, мешки, брёвна, перевёрнутая бочка
func barricade() -> void:
	begin()
	box("planks_old", Vector3(0.9, 0.9, 0.9), Vector3(-1.2, 0.45, 0), Vector3(0, 0.2, 0))
	box("planks_old", Vector3(0.8, 0.8, 0.8), Vector3(-1.1, 1.25, 0.05), Vector3(0, -0.3, 0))
	for i in 5:
		box("cloth_sack", Vector3(0.6, 0.3, 0.42), Vector3(-0.3 + i * 0.5, 0.15, 0.1), Vector3(0, i * 0.4, 0))
	for i in 4:
		box("cloth_sack", Vector3(0.6, 0.3, 0.42), Vector3(-0.05 + i * 0.5, 0.45, 0.05), Vector3(0, i * 0.7, 0))
	for i in 2:
		cyl("log_weathered", 0.17, 0.17, 3.2, Vector3(0.4, 0.75 + i * 0.3, -0.35), Vector3(0.05, 0, PI / 2.0), 8)
	cyl("metal_dark", 0.3, 0.3, 0.85, Vector3(1.9, 0.3, 0.2), Vector3(PI / 2.0, 0, 0.4))
	solid(Vector3(3.8, 1.3, 1.0), Vector3(0.3, 0.65, 0))
	finish("barricade", "Barricade")


# ---------------- теплица и ветряк: деревня живёт не впроголодь ----------------
func greenhouse() -> void:
	begin()
	var w := 6.0
	var d := 3.2
	box("planks_old", Vector3(w, 0.4, d), Vector3(0, 0.2, 0))
	for i in 5:
		var x := -w / 2.0 + i * w / 4.0
		for sz in [-1, 1]:
			box("planks_old", Vector3(0.08, 1.6, 0.08), Vector3(x, 1.2, sz * d / 2.0))
			# стропила по скатам
			box("planks_old", Vector3(0.07, 0.07, 1.9), Vector3(x, 2.33, sz * 0.8), Vector3(sz * 0.6, 0, 0))
	# плёнка: стены и двускатная крыша
	for sz in [-1, 1]:
		box("film", Vector3(w, 1.6, 0.02), Vector3(0, 1.2, sz * d / 2.0))
		box("film", Vector3(w, 0.02, 1.9), Vector3(0, 2.3, sz * 0.8), Vector3(sz * 0.6, 0, 0))
	for sx in [-1, 1]:
		prism("film", Vector3(d, 0.9, 0.02), Vector3(sx * w / 2.0, 2.45, 0), Vector3(0, PI / 2.0, 0))
		box("film", Vector3(0.02, 1.6, d), Vector3(sx * w / 2.0, 1.2, 0))
	# грядки с зеленью внутри
	for sz in [-0.8, 0.8]:
		box("needles_tex", Vector3(w - 0.6, 0.25, 0.8), Vector3(0, 0.52, sz))
	solid(Vector3(w, 2.0, d), Vector3(0, 1.0, 0))
	finish("greenhouse", "Greenhouse")


func wind_turbine() -> void:
	begin()
	# ферма-мачта из труб
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			cyl("metal_dark", 0.05, 0.08, 9.0, Vector3(sx * 0.35, 4.5, sz * 0.35), Vector3(sz * 0.035, 0, -sx * 0.035), 6)
	for y in [1.5, 3.5, 5.5, 7.5]:
		for side in 4:
			var rot := Vector3(0, side * PI / 2.0, 0)
			box("metal_dark", Vector3(0.8, 0.04, 0.04), Basis.from_euler(rot) * Vector3(0, y, 0.33), rot)
	# гондола, хвост, винт из трёх досок
	box("metal_dark", Vector3(0.5, 0.45, 1.1), Vector3(0, 9.2, 0))
	box("planks_old", Vector3(0.05, 0.9, 1.3), Vector3(0, 9.3, -1.1))
	cyl("metal_dark", 0.12, 0.12, 0.3, Vector3(0, 9.2, 0.65), Vector3(PI / 2.0, 0, 0), 8)
	for k in 3:
		var a := k * TAU / 3.0 + 0.3
		box("blade", Vector3(0.22, 2.4, 0.04), Vector3(sin(a) * 1.25, 9.2 + cos(a) * 1.25, 0.8), Vector3(0, 0, -a))
	# ящик-аккумуляторная у подножия
	box("metal_dark", Vector3(1.0, 1.0, 0.7), Vector3(1.2, 0.5, 0))
	solid(Vector3(1.2, 3.0, 1.2), Vector3(0, 1.5, 0))
	finish("wind_turbine", "WindTurbine")


# ---------------- хвойные деревья ----------------
func spruce() -> void:
	begin()
	cyl("bark_dark", 0.08, 0.2, 7.5, Vector3(0, 3.75, 0), Vector3.ZERO, 7)
	for i in 6:
		var rad := 2.0 - i * 0.3
		cyl("needles_tex", 0.0, rad, 2.0, Vector3(0, 1.4 + i * 1.05, 0), Vector3(0, i * 0.7, 0), 9)
	solid(Vector3(0.6, 2.0, 0.6), Vector3(0, 1.0, 0))
	finish("spruce", "Spruce")


func pine() -> void:
	begin()
	cyl("bark_dark", 0.1, 0.22, 9.0, Vector3(0, 4.5, 0), Vector3(0, 0, 0.02), 7)
	# крона наверху: несколько приплюснутых ярусов
	for i in 5:
		var rad := 2.3 - i * 0.35
		cyl("needles_tex", rad * 0.4, rad, 1.1, Vector3(0.15 * (i % 2), 5.2 + i * 0.85, 0.1 * ((i + 1) % 2)), Vector3.ZERO, 8)
	cyl("needles_tex", 0.0, 0.7, 1.0, Vector3(0, 9.6, 0), Vector3.ZERO, 7)
	# пара сухих сучьев ниже кроны
	cyl("bark_dark", 0.02, 0.05, 1.2, Vector3(0.4, 3.8, 0), Vector3(0, 0, -1.0), 5)
	cyl("bark_dark", 0.02, 0.05, 1.0, Vector3(-0.3, 4.5, 0.2), Vector3(0.3, 0, 1.1), 5)
	solid(Vector3(0.6, 2.0, 0.6), Vector3(0, 1.0, 0))
	finish("pine", "Pine")


# ---------------- вещи в дорогу ----------------
## Каждая — сцена scenes/props/item_<ключ>.tscn со скриптом Interactable.
func travel_items() -> void:
	_item("flask", Vector3(0.4, 0.4, 0.4), func():
		cyl("metal_dark", 0.08, 0.09, 0.24, Vector3(0, 0.12, 0), Vector3.ZERO, 10)
		cyl("tin", 0.03, 0.03, 0.05, Vector3(0, 0.27, 0), Vector3.ZERO, 8)
		box("cloth_sack", Vector3(0.02, 0.3, 0.19), Vector3(0.09, 0.13, 0)))
	_item("matches", Vector3(0.35, 0.3, 0.35), func():
		box("paper", Vector3(0.11, 0.035, 0.07), Vector3(0, 0.02, 0))
		box("paper", Vector3(0.11, 0.035, 0.07), Vector3(0.03, 0.055, 0.01), Vector3(0, 0.4, 0))
		box("bread", Vector3(0.1, 0.005, 0.02), Vector3(0, 0.038, 0.036)))
	_item("blanket", Vector3(0.6, 0.35, 0.5), func():
		box("cloth_red", Vector3(0.55, 0.14, 0.38), Vector3(0, 0.07, 0))
		box("cloth_sack", Vector3(0.56, 0.02, 0.1), Vector3(0, 0.1, 0.08))
		box("cloth_red", Vector3(0.5, 0.1, 0.34), Vector3(0.02, 0.19, 0), Vector3(0, 0.1, 0)))
	_item("rope", Vector3(0.45, 0.3, 0.45), func():
		for i in 3:
			var t := TorusMesh.new()
			t.inner_radius = 0.1
			t.outer_radius = 0.16
			t.rings = 12
			t.ring_segments = 6
			add("rope_mat", t, Vector3(0.01 * i, 0.03 + i * 0.045, 0)))
	_item("compass", Vector3(0.3, 0.25, 0.3), func():
		cyl("brass", 0.06, 0.065, 0.025, Vector3(0, 0.013, 0), Vector3.ZERO, 12)
		cyl("tin", 0.05, 0.05, 0.004, Vector3(0, 0.027, 0), Vector3.ZERO, 12)
		box("cloth_red", Vector3(0.008, 0.004, 0.08), Vector3(0, 0.031, 0), Vector3(0, 0.5, 0)))
	_item("rusks", Vector3(0.45, 0.4, 0.45), func():
		box("cloth_sack", Vector3(0.28, 0.24, 0.22), Vector3(0, 0.12, 0), Vector3(0, 0.2, 0))
		cyl("cloth_sack", 0.05, 0.1, 0.1, Vector3(0, 0.28, 0), Vector3.ZERO, 7)
		for i in 3:
			box("bread", Vector3(0.1, 0.04, 0.06), Vector3(0.2 + i * 0.03, 0.02 + i * 0.03, 0.1), Vector3(0, i * 0.7, 0)))
	_item("dried_fish", Vector3(0.5, 0.3, 0.4), func():
		for i in 3:
			box("fish", Vector3(0.34, 0.035, 0.09), Vector3(0, 0.02 + i * 0.035, -0.08 + i * 0.08), Vector3(0, 0.15 * (i - 1), 0))
		box("rope_mat", Vector3(0.012, 0.012, 0.3), Vector3(0.16, 0.08, 0)))
	_item("canned", Vector3(0.4, 0.3, 0.4), func():
		for p in [Vector3(0, 0.055, 0), Vector3(0.12, 0.055, 0.03), Vector3(0.05, 0.165, 0.01)]:
			cyl("tin", 0.05, 0.05, 0.11, p, Vector3.ZERO, 10)
			cyl("rust", 0.051, 0.051, 0.04, p, Vector3.ZERO, 10))
	_item("herbs", Vector3(0.45, 0.3, 0.4), func():
		for i in 5:
			cyl("herb", 0.015, 0.05, 0.32, Vector3(-0.02 + i * 0.01, 0.04 + (i % 2) * 0.02, 0), Vector3(0, i * 0.3, PI / 2.0 + (i - 2) * 0.06), 6)
		box("rope_mat", Vector3(0.02, 0.1, 0.1), Vector3(0.09, 0.05, 0)))


func _item(id: String, pick: Vector3, build: Callable) -> void:
	begin()
	root_props = {"item_id": id, "pick_size": pick}
	build.call()
	finish("item_" + id, "Item")


# ---------------- хлам и запертый сундук (амбар) ----------------
func junk() -> void:
	begin()
	root_props = {"kind": "use", "label": "Хлам — разобрать", "pick_size": Vector3(1.2, 0.8, 1.0)}
	box("planks_old", Vector3(1.1, 0.06, 0.18), Vector3(0, 0.05, 0), Vector3(0, 0.4, 0.1))
	box("planks_old", Vector3(0.9, 0.06, 0.16), Vector3(0.1, 0.12, 0.1), Vector3(0, -0.7, -0.15))
	box("planks_old", Vector3(0.7, 0.05, 0.14), Vector3(-0.2, 0.2, -0.1), Vector3(0.2, 1.3, 0.2))
	box("cloth_sack", Vector3(0.5, 0.14, 0.4), Vector3(0.25, 0.08, -0.25), Vector3(0, 0.5, 0))
	box("cloth_red", Vector3(0.35, 0.06, 0.3), Vector3(-0.3, 0.05, 0.3), Vector3(0, 1.1, 0))
	for p in [Vector3(0.4, 0.05, 0.3), Vector3(-0.45, 0.05, -0.2)]:
		cyl("rust", 0.05, 0.05, 0.1, p, Vector3(PI / 2.0, 0, 0.6), 8)
	finish("junk", "Junk")


func locked_box() -> void:
	begin()
	root_props = {"kind": "use", "label": "Запертый сундук", "pick_size": Vector3(1.0, 0.8, 0.7)}
	box("planks_old", Vector3(0.9, 0.5, 0.55), Vector3(0, 0.25, 0))
	cyl("planks_old", 0.28, 0.28, 0.9, Vector3(0, 0.5, 0), Vector3(0, 0, PI / 2.0), 10)
	for x in [-0.3, 0.3]:
		box("metal_dark", Vector3(0.06, 0.62, 0.6), Vector3(x, 0.33, 0))
	box("brass", Vector3(0.12, 0.14, 0.04), Vector3(0, 0.42, 0.29))
	finish("locked_box", "LockedBox")
