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
	gate()
	barricade()
	greenhouse()
	wind_turbine()
	spruce()
	pine()
	birch()
	bush()
	dead_tree()
	rocks()
	tractor()
	palisades()
	small_props()
	scatter_meshes()
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
	_tex_mat("birch_bark", "birch_bark", 1.6)
	_tex_mat("leaves_tex", "leaves_tex", 1.0, 1.0)
	_tex_mat("leaves_dark", "leaves_tex", 1.0, 1.0, 0.0, Color("8a9a80"))
	_tex_mat("needles_b", "needles", 0.9, 1.0, 0.0, Color("c8d0b0"))
	_tex_mat("rock_tex", "rock", 0.7, 0.95, 0.0, Color("9a968c"))
	_tex_mat("moss", "grass_dark", 1.2, 1.0, 0.0, Color("b0c090"))
	_tex_mat("mud_tex", "mud", 0.35, 0.35, 0.0, Color.WHITE, true)
	_tex_mat("paint_faded", "planks_old", 2.0, 0.8, 0.1, Color("c86a30"))
	_tex_mat("metal_dark", "metal_roof", 1.5, 0.6, 0.5, Color("6a6a66"))
	# земля: мировая проекция, чтобы соседние куски стыковались
	_tex_mat("ground_grass", "grass_dark", 0.18, 1.0, 0.0, Color.WHITE, true)
	_tex_mat("ground_meadow", "meadow", 0.15, 1.0, 0.0, Color("8c8672"), true)
	_tex_mat("ground_dirt", "dirt_road", 0.3, 1.0, 0.0, Color.WHITE, true)
	_plain_mat("film", Color(0.85, 0.9, 0.85, 0.35), 0.2, true)
	_plain_mat("cloth_sack", Color("7a6a4a"), 1.0)
	_plain_mat("blade", Color("b8b0a0"), 0.6)
	_plain_mat("cloth_red", Color("7a2e24"), 1.0)
	_plain_mat("tire", Color("1c1b1a"), 0.9)
	_plain_mat("glass", Color(0.25, 0.3, 0.3, 0.55), 0.1, true)
	_plain_mat("wire", Color("5a5550"), 0.5)
	_plain_mat("grass_blade", Color("6a6a38"), 1.0)
	_plain_mat("grass_green", Color("3e4e26"), 1.0)
	_plain_mat("reed", Color("7a7040"), 1.0)
	_plain_mat("cattail", Color("4a3020"), 1.0)
	var water := StandardMaterial3D.new()
	water.resource_name = "water"
	water.albedo_color = Color(0.06, 0.07, 0.04, 0.92)
	water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water.roughness = 0.25
	water.metallic = 0.0
	water.metallic_specular = 0.35
	ResourceSaver.save(water, MAT_DIR + "water.tres")
	M["water"] = load(MAT_DIR + "water.tres")
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


func add(mat: String, mesh: Mesh, pos: Vector3, rot := Vector3.ZERO, scl := Vector3.ONE) -> void:
	var key := mat + ("@up" if pos.y > cut_y or (_force_up and cut_y < INF) else "")
	if not parts.has(key):
		parts[key] = []
	parts[key].append([mesh, Transform3D(Basis.from_euler(rot) * Basis.from_scale(scl), pos)])


## Неровный примитив: вершины сдвинуты шумом от центра, грани плоские (low-poly).
## Сдвиг зависит только от положения вершины — швы примитива не расходятся.
func rough(prim: PrimitiveMesh, amount: float, seed_: int, freq := 1.5, squash_y := 1.0) -> ArrayMesh:
	var arr := prim.get_mesh_arrays()
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var nz := FastNoiseLite.new()
	nz.seed = seed_
	nz.frequency = freq
	for i in verts.size():
		var v := verts[i]
		var dir := Vector3(v.x, v.y * squash_y, v.z)
		if dir.length() < 0.001:
			continue
		verts[i] = v + dir.normalized() * nz.get_noise_3dv(v) * amount
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = null
	arr[Mesh.ARRAY_TANGENT] = null
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var st := SurfaceTool.new()
	st.create_from(am, 0)
	st.deindex()
	st.generate_normals()
	return st.commit()


func rsphere(r: float, segs := 9, rings := 6) -> SphereMesh:
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = segs
	sm.rings = rings
	return sm


func rcone(r_bot: float, h: float, segs := 10) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = 0.0
	c.bottom_radius = r_bot
	c.height = h
	c.radial_segments = segs
	c.rings = 2
	return c


## Сохранить текущие детали как одну сетку (поверхность на материал) — для MultiMesh
func save_mesh(n: String) -> void:
	var am := ArrayMesh.new()
	for key in parts:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for it in parts[key]:
			var mesh: Mesh = it[0]
			for si in mesh.get_surface_count():
				st.append_from(mesh, si, it[1])
		st.generate_tangents()
		st.commit(am)
		am.surface_set_material(am.get_surface_count() - 1, M[String(key).trim_suffix("@up")])
	ResourceSaver.save(am, MESH_DIR + n + ".res")
	print("  ", n, " (сетка)")


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
	for v in 2:
		begin()
		_rng.seed = 100 + v
		var h := 8.0 + v * 1.5
		cyl("bark_dark", 0.07, 0.22, h, Vector3(0, h / 2.0, 0), Vector3.ZERO, 8)
		var tiers := 8 + v
		var needles := "needles_tex" if v == 0 else "needles_b"
		for i in tiers:
			var k := float(i) / tiers
			var rad := lerpf(2.3, 0.45, k) * _rng.randf_range(0.85, 1.1)
			var y := 1.2 + k * (h - 1.8)
			var off := Vector3(_rng.randf_range(-0.12, 0.12), 0, _rng.randf_range(-0.12, 0.12))
			add(needles, rough(rcone(rad, 1.5 - k * 0.5, 11), 0.22, 7 * i + v, 2.2), Vector3(0, y, 0) + off,
				Vector3(_rng.randf_range(-0.08, 0.08), _rng.randf() * TAU, _rng.randf_range(-0.08, 0.08)))
		add(needles, rough(rcone(0.35, 1.2, 7), 0.06, 99 + v), Vector3(0, h + 0.3, 0))
		# корни у земли
		for r in 3:
			var a := r * TAU / 3.0 + 0.4
			cyl("bark_dark", 0.02, 0.1, 0.9, Vector3(cos(a) * 0.3, 0.12, sin(a) * 0.3), Vector3(sin(a) * 1.3, 0, -cos(a) * 1.3), 5)
		solid(Vector3(0.6, 2.0, 0.6), Vector3(0, 1.0, 0))
		finish("spruce" if v == 0 else "spruce_b", "Spruce")


func pine() -> void:
	for v in 2:
		begin()
		_rng.seed = 200 + v
		var h := 9.5 + v
		# ствол чуть изогнут: два куска
		cyl("bark_dark", 0.15, 0.24, h * 0.55, Vector3(0, h * 0.275, 0), Vector3(0, 0, 0.03), 8)
		cyl("bark_dark", 0.08, 0.15, h * 0.5, Vector3(0.12, h * 0.78, 0), Vector3(0, 0, -0.04), 8)
		# сухие сучья по стволу
		for i in 5:
			var a := _rng.randf() * TAU
			var y := 2.5 + i * 0.9
			cyl("bark_dark", 0.01, 0.045, 1.0, Vector3(cos(a) * 0.4, y, sin(a) * 0.4), Vector3(sin(a) * 1.2, 0, -cos(a) * 1.2), 5)
		# крона из приплюснутых клочьев на ветках
		for i in 11:
			var a := i * 2.4 + _rng.randf() * 0.6
			var y := h * 0.6 + (i % 5) * 0.55 + _rng.randf() * 0.3
			var d := _rng.randf_range(0.6, 1.4) * (1.0 - (i % 5) * 0.12)
			var p := Vector3(cos(a) * d, y, sin(a) * d)
			cyl("bark_dark", 0.03, 0.06, d + 0.2, Vector3(p.x * 0.5, y - 0.2, p.z * 0.5), Vector3(sin(a) * 1.35, 0, -cos(a) * 1.35), 5)
			add("needles_tex", rough(rsphere(_rng.randf_range(0.9, 1.35), 10, 6), 0.3, 11 * i + v, 2.0), p, Vector3.ZERO, Vector3(1.0, 0.5, 1.0))
		add("needles_tex", rough(rsphere(0.9, 9, 6), 0.25, 5 + v), Vector3(0.12, h + 0.1, 0), Vector3.ZERO, Vector3(1, 0.6, 1))
		solid(Vector3(0.6, 2.0, 0.6), Vector3(0, 1.0, 0))
		finish("pine" if v == 0 else "pine_b", "Pine")


func birch() -> void:
	for v in 2:
		begin()
		_rng.seed = 300 + v
		var h := 5.5 + v * 1.2
		cyl("birch_bark", 0.1, 0.17, h * 0.6, Vector3(0, h * 0.3, 0), Vector3(0.02, 0, 0.03), 8)
		cyl("birch_bark", 0.05, 0.1, h * 0.5, Vector3(-0.1, h * 0.82, 0.05), Vector3(-0.05, 0, -0.06), 7)
		for i in 4:
			var a := _rng.randf() * TAU
			var y := h * 0.55 + i * 0.45
			cyl("birch_bark", 0.02, 0.05, 1.2, Vector3(cos(a) * 0.35, y + 0.35, sin(a) * 0.35), Vector3(sin(a) * 0.9, 0, -cos(a) * 0.9), 5)
		for i in 12:
			var a := i * 2.1 + _rng.randf()
			var d := _rng.randf_range(0.3, 1.1)
			var p := Vector3(cos(a) * d, h * 0.55 + _rng.randf_range(0.0, h * 0.5), sin(a) * d)
			add("leaves_tex" if i % 3 else "leaves_dark", rough(rsphere(_rng.randf_range(0.7, 1.05), 9, 6), 0.28, 13 * i + v, 2.0), p, Vector3.ZERO, Vector3(1, 0.8, 1))
		solid(Vector3(0.5, 2.0, 0.5), Vector3(0, 1.0, 0))
		finish("birch" if v == 0 else "birch_b", "Birch")


func bush() -> void:
	begin()
	_rng.seed = 400
	for i in 5:
		var a := i * 1.3
		add("leaves_dark" if i % 2 else "leaves_tex", rough(rsphere(_rng.randf_range(0.45, 0.65), 8, 5), 0.18, 17 * i, 2.5),
			Vector3(cos(a) * 0.4, 0.4 + _rng.randf() * 0.2, sin(a) * 0.35), Vector3.ZERO, Vector3(1, 0.8, 1))
	finish("bush", "Bush")


func dead_tree() -> void:
	begin()
	_rng.seed = 450
	cyl("bark_dark", 0.06, 0.2, 5.0, Vector3(0, 2.5, 0), Vector3(0.03, 0, 0), 7)
	for i in 6:
		var a := _rng.randf() * TAU
		var y := 2.0 + i * 0.5
		var ln := _rng.randf_range(0.8, 1.6)
		cyl("bark_dark", 0.015, 0.05, ln, Vector3(cos(a) * ln * 0.35, y + ln * 0.25, sin(a) * ln * 0.35), Vector3(sin(a) * 0.9, 0, -cos(a) * 0.9), 5)
	solid(Vector3(0.5, 2.0, 0.5), Vector3(0, 1.0, 0))
	finish("dead_tree", "DeadTree")


# ---------------- камни ----------------
func rocks() -> void:
	for spec in [["rock_small", 0.35, 1, false], ["rock", 0.7, 2, true], ["rock_big", 1.2, 3, true]]:
		begin()
		_rng.seed = hash(spec[0])
		var r: float = spec[1]
		for i in spec[2]:
			var rr := r * (1.0 if i == 0 else _rng.randf_range(0.45, 0.7))
			var p := Vector3(0, rr * 0.35, 0) if i == 0 else Vector3(_rng.randf_range(-1, 1) * r, rr * 0.3, _rng.randf_range(-1, 1) * r)
			var sc := Vector3(_rng.randf_range(1.0, 1.4), _rng.randf_range(0.6, 0.85), _rng.randf_range(0.9, 1.2))
			add("rock_tex", rough(rsphere(rr, 9, 6), rr * 0.35, 31 * i + int(r * 10), 2.2 / rr), p, Vector3(0, _rng.randf() * TAU, 0), sc)
			if i == 0 and r > 0.5:
				# мох на макушке
				add("moss", rough(rsphere(rr * 0.6, 8, 4), rr * 0.15, 7), p + Vector3(0.1, rr * 0.5, 0), Vector3.ZERO, Vector3(1.2, 0.25, 1.0))
		if spec[3]:
			solid(Vector3(r * 2.4, r * 1.1, r * 2.0), Vector3(0, r * 0.5, 0))
		finish(spec[0], "Rock")


# ---------------- трактор ----------------
## Довоенный колёсный трактор: выцветшая оранжевая краска, ржавчина, кабина с рамой.
## Длина вдоль Z (перёд — +Z).
func tractor() -> void:
	begin()
	# рама и двигатель под капотом
	box("metal_dark", Vector3(0.9, 0.35, 3.2), Vector3(0, 0.75, 0.1))
	box("paint_faded", Vector3(1.0, 0.75, 1.6), Vector3(0, 1.2, 0.95))
	box("rust", Vector3(1.02, 0.3, 0.8), Vector3(0, 1.45, 0.8))
	# решётка радиатора
	for i in 6:
		box("metal_dark", Vector3(0.05, 0.6, 0.06), Vector3(-0.35 + i * 0.14, 1.15, 1.78))
	box("metal_dark", Vector3(0.95, 0.08, 0.1), Vector3(0, 1.5, 1.78))
	for sx in [-1, 1]:
		cyl("window", 0.09, 0.09, 0.08, Vector3(sx * 0.38, 1.35, 1.8), Vector3(PI / 2.0, 0, 0), 10)
	# выхлопная труба с колпачком
	cyl("rust", 0.06, 0.06, 1.3, Vector3(0.3, 2.1, 1.25), Vector3.ZERO, 8)
	cyl("metal_dark", 0.09, 0.07, 0.12, Vector3(0.3, 2.78, 1.25), Vector3.ZERO, 8)
	# кабина: пол, стойки, крыша, заднее стекло
	box("metal_dark", Vector3(1.4, 0.1, 1.3), Vector3(0, 1.1, -0.65))
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			box("paint_faded", Vector3(0.07, 1.4, 0.07), Vector3(sx * 0.66, 1.85, -0.65 + sz * 0.6))
	box("paint_faded", Vector3(1.5, 0.08, 1.45), Vector3(0, 2.58, -0.65))
	box("glass", Vector3(1.25, 0.8, 0.03), Vector3(0, 2.05, -1.25))
	box("glass", Vector3(1.25, 0.7, 0.03), Vector3(0, 2.05, -0.06), Vector3(-0.15, 0, 0))
	# сиденье и руль
	box("cloth_sack", Vector3(0.5, 0.12, 0.45), Vector3(0, 1.45, -0.85))
	box("cloth_sack", Vector3(0.5, 0.45, 0.1), Vector3(0, 1.7, -1.08))
	var wheel := TorusMesh.new()
	wheel.inner_radius = 0.16
	wheel.outer_radius = 0.2
	wheel.rings = 12
	wheel.ring_segments = 5
	add("metal_dark", wheel, Vector3(0, 1.75, -0.35), Vector3(-0.9, 0, 0))
	cyl("metal_dark", 0.02, 0.02, 0.5, Vector3(0, 1.55, -0.28), Vector3(-0.9, 0, 0), 6)
	# большие задние колёса с грунтозацепами и крыльями
	for sx in [-1, 1]:
		var c := Vector3(sx * 0.95, 0.8, -0.65)
		cyl("tire", 0.8, 0.8, 0.45, c, Vector3(0, 0, PI / 2.0), 16)
		cyl("rust", 0.38, 0.38, 0.47, c, Vector3(0, 0, PI / 2.0), 10)
		for k in 14:
			var a := k * TAU / 14.0
			box("tire", Vector3(0.46, 0.12, 0.1), c + Vector3(0, sin(a) * 0.8, cos(a) * 0.8), Vector3(-a, 0, 0))
		box("paint_faded", Vector3(0.5, 0.05, 1.3), Vector3(sx * 0.95, 1.7, -0.65), Vector3(0, 0, 0))
		# передние колёса
		var f := Vector3(sx * 0.72, 0.45, 1.35)
		cyl("tire", 0.45, 0.45, 0.28, f, Vector3(0, 0, PI / 2.0), 14)
		cyl("rust", 0.2, 0.2, 0.3, f, Vector3(0, 0, PI / 2.0), 8)
	# сцепка сзади и забытый плуг
	box("metal_dark", Vector3(0.3, 0.15, 0.6), Vector3(0, 0.6, -1.7))
	box("rust", Vector3(1.4, 0.1, 0.15), Vector3(0, 0.35, -2.4))
	for sx in [-0.45, 0.0, 0.45]:
		box("rust", Vector3(0.08, 0.45, 0.35), Vector3(sx, 0.2, -2.45), Vector3(0.5, 0, 0))
	solid(Vector3(2.4, 2.4, 3.4), Vector3(0, 1.2, 0))
	solid(Vector3(1.5, 0.6, 0.5), Vector3(0, 0.3, -2.4))
	finish("tractor", "Tractor")


# ---------------- частокол: колючка, заплаты, заколоченные дыры ----------------
func palisades() -> void:
	for kind in ["palisade", "palisade_boarded", "palisade_patched"]:
		begin()
		_rng.seed = hash(kind)
		var n := 13
		for i in n:
			var x := -2.0 + 0.15 + i * (4.0 - 0.3) / (n - 1)
			var h := _rng.randf_range(2.2, 2.6)
			if kind == "palisade_boarded" and (i == 5 or i == 6):
				h = _rng.randf_range(0.9, 1.3)  # бревна подгнили — дыру заколотили
			cyl("log_weathered", 0.14, 0.15, h, Vector3(x, h / 2.0, 0), Vector3.ZERO, 7)
			cyl("log_weathered", 0.0, 0.14, 0.35, Vector3(x, h + 0.17, 0), Vector3.ZERO, 7)
		for y in [0.6, 1.8]:
			box("planks_old", Vector3(4.0, 0.14, 0.1), Vector3(0, y, -0.2))
		if kind == "palisade_boarded":
			# доски крест-накрест и поперёк поверх дыры
			box("planks_old", Vector3(1.6, 0.2, 0.05), Vector3(0.0, 1.6, 0.2), Vector3(0, 0, 0.5))
			box("planks_old", Vector3(1.6, 0.2, 0.05), Vector3(0.0, 1.6, 0.21), Vector3(0, 0, -0.5))
			for y in [1.3, 1.95, 2.3]:
				box("planks_old", Vector3(1.3, 0.18, 0.05), Vector3(_rng.randf_range(-0.1, 0.1), y, 0.18), Vector3(0, 0, _rng.randf_range(-0.12, 0.12)))
		if kind == "palisade_patched":
			# ржавый лист, прибитый поверх брёвен
			box("metal_roof", Vector3(1.4, 1.1, 0.04), Vector3(_rng.randf_range(-0.8, 0.8), 1.1, 0.19), Vector3(0, 0, 0.06))
		# колючая проволока: две нитки на скобах и спираль поверх остриёв
		for x in [-1.6, 0.0, 1.6]:
			box("wire", Vector3(0.03, 0.6, 0.03), Vector3(x, 2.55, 0.22))
		for y in [2.45, 2.75]:
			cyl("wire", 0.008, 0.008, 4.0, Vector3(0, y, 0.22), Vector3(0, 0, PI / 2.0), 4)
			for k in 12:
				var bx := -1.85 + k * 0.33
				box("wire", Vector3(0.012, 0.09, 0.012), Vector3(bx, y, 0.22), Vector3(0.7, 0, 0.7))
		for k in 9:
			var coil := TorusMesh.new()
			coil.inner_radius = 0.24
			coil.outer_radius = 0.26
			coil.rings = 14
			coil.ring_segments = 3
			add("wire", coil, Vector3(-1.8 + k * 0.45, 2.85, 0.05), Vector3(0, 0, PI / 2.0 + 0.35))
		solid(Vector3(4.0, 2.4, 0.5), Vector3(0, 1.2, 0))
		finish(kind, "Palisade")


# ---------------- мелочи: бочки, ящики, телега, скамья, сено, пни ----------------
func small_props() -> void:
	begin()
	cyl("metal_dark", 0.3, 0.3, 0.88, Vector3(0, 0.44, 0), Vector3.ZERO, 12)
	for y in [0.12, 0.44, 0.76]:
		cyl("rust", 0.31, 0.31, 0.06, Vector3(0, y, 0), Vector3.ZERO, 12)
	solid(Vector3(0.6, 0.9, 0.6), Vector3(0, 0.45, 0))
	finish("barrel", "Barrel")

	begin()
	box("planks_old", Vector3(0.7, 0.6, 0.6), Vector3(0, 0.3, 0))
	box("planks_old", Vector3(0.6, 0.5, 0.55), Vector3(0.15, 0.85, 0.02), Vector3(0, 0.3, 0))
	box("planks_old", Vector3(0.5, 0.4, 0.5), Vector3(0.75, 0.2, 0.1), Vector3(0, -0.2, 0))
	for p in [Vector3(0, 0.3, 0.31), Vector3(0.15, 0.85, 0.3)]:
		box("metal_dark", Vector3(0.6, 0.04, 0.02), p)
	solid(Vector3(1.4, 1.0, 0.8), Vector3(0.3, 0.5, 0))
	finish("crates", "Crates")

	begin()
	box("planks_old", Vector3(1.3, 0.08, 2.2), Vector3(0, 0.75, 0))
	for sx in [-1, 1]:
		box("planks_old", Vector3(0.06, 0.35, 2.2), Vector3(sx * 0.65, 0.95, 0))
		cyl("planks_old", 0.5, 0.5, 0.1, Vector3(sx * 0.75, 0.5, -0.3), Vector3(0, 0, PI / 2.0), 12)
		cyl("rust", 0.1, 0.1, 0.12, Vector3(sx * 0.75, 0.5, -0.3), Vector3(0, 0, PI / 2.0), 8)
		box("planks_old", Vector3(0.07, 0.07, 1.8), Vector3(sx * 0.35, 0.55, 1.9), Vector3(0.28, 0, 0))
	box("hay", Vector3(1.1, 0.35, 1.2), Vector3(0, 1.0, -0.3))
	solid(Vector3(1.6, 1.2, 2.4), Vector3(0, 0.6, 0))
	finish("cart", "Cart")

	begin()
	box("planks_old", Vector3(1.8, 0.07, 0.35), Vector3(0, 0.45, 0))
	for sx in [-0.7, 0.7]:
		box("log_weathered", Vector3(0.12, 0.42, 0.3), Vector3(sx, 0.21, 0))
	finish("bench", "Bench")

	begin()
	cyl("hay", 0.55, 0.55, 1.1, Vector3(0, 0.55, 0), Vector3(0, 0, PI / 2.0), 12)
	for x in [-0.3, 0.3]:
		cyl("rope_mat", 0.56, 0.56, 0.04, Vector3(x, 0.55, 0), Vector3(0, 0, PI / 2.0), 12)
	solid(Vector3(1.2, 1.1, 1.1), Vector3(0, 0.55, 0))
	finish("hay_bale", "HayBale")

	begin()
	cyl("bark_dark", 0.3, 0.36, 0.45, Vector3(0, 0.22, 0), Vector3.ZERO, 9)
	cyl("planks_old", 0.29, 0.29, 0.02, Vector3(0, 0.455, 0), Vector3.ZERO, 9)
	add("moss", rough(rsphere(0.2, 7, 4), 0.05, 3), Vector3(0.2, 0.25, 0.2), Vector3.ZERO, Vector3(1, 0.4, 1))
	finish("stump", "Stump")

	begin()
	cyl("bark_dark", 0.22, 0.26, 4.0, Vector3(0, 0.24, 0), Vector3(0, 0, PI / 2.0), 9)
	cyl("bark_dark", 0.03, 0.06, 0.9, Vector3(0.8, 0.5, 0.2), Vector3(0.5, 0, 0.3), 5)
	add("moss", rough(rsphere(0.3, 7, 4), 0.06, 5), Vector3(-0.9, 0.42, 0), Vector3.ZERO, Vector3(1.6, 0.35, 0.8))
	solid(Vector3(4.0, 0.5, 0.5), Vector3(0, 0.25, 0))
	finish("log_fallen", "LogFallen")


# ---------------- сетки для россыпи (MultiMesh): трава, камыш, кочки, лужи ----------------
func scatter_meshes() -> void:
	begin()
	_rng.seed = 501
	for i in 7:
		var a := _rng.randf() * TAU
		var d := _rng.randf() * 0.15
		cyl("grass_blade" if i % 3 else "grass_green", 0.0, 0.025, _rng.randf_range(0.3, 0.55),
			Vector3(cos(a) * d, 0.18, sin(a) * d), Vector3(_rng.randf_range(-0.35, 0.35), 0, _rng.randf_range(-0.35, 0.35)), 3)
	save_mesh("scatter_tuft")

	begin()
	_rng.seed = 502
	for i in 9:
		var a := _rng.randf() * TAU
		var d := _rng.randf() * 0.25
		var h := _rng.randf_range(1.0, 1.7)
		var tilt := Vector3(_rng.randf_range(-0.15, 0.15), 0, _rng.randf_range(-0.15, 0.15))
		cyl("reed", 0.008, 0.02, h, Vector3(cos(a) * d, h / 2.0, sin(a) * d), tilt, 4)
		if i % 3 == 0:
			cyl("cattail", 0.03, 0.03, 0.18, Vector3(cos(a) * d + tilt.z * -h * 0.45, h * 0.88, sin(a) * d + tilt.x * h * 0.45), tilt, 6)
	save_mesh("scatter_reeds")

	begin()
	add("moss", rough(rsphere(0.35, 8, 5), 0.08, 9), Vector3(0, 0.05, 0), Vector3.ZERO, Vector3(1.0, 0.55, 1.0))
	for i in 5:
		var a := i * 1.25
		cyl("grass_blade", 0.0, 0.03, 0.4, Vector3(cos(a) * 0.15, 0.3, sin(a) * 0.15), Vector3(sin(a) * 0.4, 0, -cos(a) * 0.4), 3)
	save_mesh("scatter_hummock")

	begin()
	var pool := CylinderMesh.new()
	pool.top_radius = 1.0
	pool.bottom_radius = 1.0
	pool.height = 0.02
	pool.radial_segments = 14
	pool.rings = 1
	add("water", rough(pool, 0.25, 21, 1.2, 0.0), Vector3(0, 0.02, 0))
	save_mesh("scatter_puddle")

	begin()
	var disk := CylinderMesh.new()
	disk.top_radius = 1.0
	disk.bottom_radius = 1.0
	disk.height = 0.02
	disk.radial_segments = 14
	disk.rings = 1
	add("mud_tex", rough(disk, 0.3, 23, 1.0, 0.0), Vector3(0, 0.01, 0))
	save_mesh("scatter_mud")


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
