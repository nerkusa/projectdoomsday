extends Node
## Генератор стартовых сцен: материалы, пропсы (избы, амбар, деревья…),
## локация «Нахарро» и главная сцена. Запускать НЕ нужно — сцены уже лежат в проекте.
## Пригодится, если захочешь пересобрать деревню с нуля:
##   godot --headless --path . res://tools/build.tscn
## ВНИМАНИЕ: перезапишет scenes/locations/nakharro.tscn и scenes/props/*.
## УСТАРЕЛ для деревни и построек: их теперь собирают tools/build_props.gd и
## tools/build_nakharro.gd (этот файл нужен им как набор помощников и для мелких
## пропов — колодец, стол, трактор, грибы и т. п.).

const MAT_DIR := "res://assets/materials/"
const PROP_DIR := "res://scenes/props/"

var M: Dictionary = {}


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(MAT_DIR)
	DirAccess.make_dir_recursive_absolute(PROP_DIR)
	DirAccess.make_dir_recursive_absolute("res://scenes/locations")
	_materials()
	_props()
	_main_scene()
	_nakharro()
	print("Сцены собраны.")
	get_tree().quit()


# ---------------- материалы ----------------
func _mat(n: String, c: String, rough := 0.9, metal := 0.0, emit := "", emit_e := 0.0) -> void:
	var m := StandardMaterial3D.new()
	m.resource_name = n
	m.albedo_color = Color(c)
	m.roughness = rough
	m.metallic = metal
	if emit != "":
		m.emission_enabled = true
		m.emission = Color(emit)
		m.emission_energy_multiplier = emit_e
	ResourceSaver.save(m, MAT_DIR + n + ".tres")
	M[n] = load(MAT_DIR + n + ".tres")


func _materials() -> void:
	_mat("grass", "#5f6a3c")
	_mat("grass_dry", "#7d7a4c")
	_mat("dirt", "#6e5a40")
	_mat("field", "#5e4a34")
	_mat("log", "#7a5a38")
	_mat("log_dark", "#4e3a26")
	_mat("plank", "#8f7550")
	_mat("roof", "#4a4034")
	_mat("roof_moss", "#5a5a3a")
	_mat("stone", "#8a8478")
	_mat("metal", "#6b6a64", 0.5, 0.6)
	_mat("rust", "#8a4a2a", 0.8, 0.3)
	_mat("paint_orange", "#d9622b", 0.6)
	_mat("paint_white", "#d8d0bb", 0.8)
	_mat("bark_birch", "#d8d4c8")
	_mat("bark", "#4a3a2a")
	_mat("leaves", "#5f7a3a")
	_mat("leaves_dark", "#3f5a2e")
	_mat("needles", "#3e5236")
	_mat("window", "#2a2418", 0.3, 0.0, "#ffb347", 0.6)
	_mat("cabbage", "#7a9a5a")
	_mat("ash", "#2a2622")
	_mat("mushroom_cap", "#8a5a2a")
	_mat("mushroom_leg", "#e8e0cc")
	_mat("berry", "#a8202a", 0.5)
	_mat("cloth", "#b8a88a")


# ---------------- помощники ----------------
func _own(n: Node, root: Node) -> void:
	n.owner = root
	for c in n.get_children():
		_own(c, root)


func box(parent: Node, size: Vector3, pos: Vector3, mat: String, rot := Vector3.ZERO, nm := "") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = M[mat]
	mi.position = pos
	mi.rotation = rot
	if nm != "":
		mi.name = nm
	parent.add_child(mi)
	return mi


func cyl(parent: Node, r_top: float, r_bot: float, h: float, pos: Vector3, mat: String, rot := Vector3.ZERO, seg := 10) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = r_top
	c.bottom_radius = r_bot
	c.height = h
	c.radial_segments = seg
	c.rings = 1
	mi.mesh = c
	mi.material_override = M[mat]
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


func sphere(parent: Node, r: float, pos: Vector3, mat: String, sc := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2
	s.radial_segments = 8
	s.rings = 5
	mi.mesh = s
	mi.material_override = M[mat]
	mi.position = pos
	mi.scale = sc
	parent.add_child(mi)
	return mi


func prism(parent: Node, size: Vector3, pos: Vector3, mat: String, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var p := PrismMesh.new()
	p.size = size
	mi.mesh = p
	mi.material_override = M[mat]
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


func collider(parent: Node, size: Vector3, pos: Vector3, rot_y := 0.0) -> StaticBody3D:
	var sb := StaticBody3D.new()
	sb.name = "Collision"
	sb.collision_layer = 1
	sb.collision_mask = 0
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size
	cs.shape = b
	sb.add_child(cs)
	sb.position = pos
	sb.rotation.y = rot_y
	parent.add_child(sb)
	return sb


func save_prop(root: Node3D, n: String) -> PackedScene:
	for c in root.get_children():
		_own(c, root)
	var ps := PackedScene.new()
	ps.pack(root)
	ResourceSaver.save(ps, PROP_DIR + n + ".tscn")
	root.free()
	return load(PROP_DIR + n + ".tscn")


# ---------------- пропсы ----------------
var P: Dictionary = {}


func _props() -> void:
	P.izba = _izba()
	P.barn = _barn()
	P.shed = _shed()
	P.fence = _fence()
	P.fence_broken = _fence(true)
	P.well = _well()
	P.woodpile = _woodpile()
	P.birch = _birch()
	P.larch = _larch()
	P.pine_dead = _dead_tree()
	P.bush = _bush()
	P.border_post = _border_post()
	P.sign = _sign()
	P.tractor = _tractor()
	P.table = _table()
	P.garden = _garden()
	P.fire = _fire()
	P.mushroom = _mushroom()
	P.berries = _berries()
	P.planks = _planks_item()
	P.basket = _basket()
	P.bandage = _bandage()
	P.rock = _rock()


func _izba() -> PackedScene:
	var r := Node3D.new()
	r.name = "Izba"
	var w := 5.0
	var d := 4.2
	for i in 7:
		box(r, Vector3(w, 0.36, d), Vector3(0, 0.18 + i * 0.36, 0), "log" if i % 2 == 0 else "log_dark")
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			box(r, Vector3(0.34, 2.6, 0.34), Vector3(sx * (w / 2.0 + 0.05), 1.3, sz * (d / 2.0 + 0.05)), "log_dark")
	prism(r, Vector3(d + 0.9, 1.7, w + 0.6), Vector3(0, 2.52 + 0.85, 0), "roof", Vector3(0, PI / 2.0, 0))
	box(r, Vector3(0.9, 1.8, 0.1), Vector3(0.9, 0.9, d / 2.0 + 0.02), "log_dark")
	box(r, Vector3(0.7, 0.6, 0.08), Vector3(-1.3, 1.5, d / 2.0 + 0.02), "window")
	box(r, Vector3(0.9, 0.12, 0.14), Vector3(-1.3, 1.16, d / 2.0 + 0.07), "paint_white")
	box(r, Vector3(0.08, 0.6, 0.7), Vector3(w / 2.0 + 0.02, 1.5, 0), "window")
	box(r, Vector3(0.5, 1.3, 0.5), Vector3(-1.4, 3.6, -0.6), "stone")
	box(r, Vector3(1.6, 0.18, 0.9), Vector3(0.9, 0.09, d / 2.0 + 0.45), "plank")
	collider(r, Vector3(w + 0.4, 2.6, d + 0.4), Vector3(0, 1.3, 0))
	return save_prop(r, "izba")


func _barn() -> PackedScene:
	var r := Node3D.new()
	r.name = "Barn"
	var w := 7.0
	var d := 5.0
	for i in 14:
		box(r, Vector3(0.48, 3.0, d), Vector3(-w / 2.0 + 0.25 + i * 0.5, 1.5, 0), "plank" if i % 2 == 0 else "log")
	box(r, Vector3(w, 3.0, 0.1), Vector3(0, 1.5, -d / 2.0), "plank")
	box(r, Vector3(w, 3.0, 0.1), Vector3(0, 1.5, d / 2.0), "log")
	box(r, Vector3(2.2, 2.4, 0.12), Vector3(0, 1.2, d / 2.0 + 0.04), "log_dark", Vector3.ZERO, "Door")
	box(r, Vector3(0.12, 2.4, 0.14), Vector3(0, 1.2, d / 2.0 + 0.1), "rust")
	prism(r, Vector3(d + 1.0, 1.9, w + 0.8), Vector3(0, 3.95, 0), "roof_moss", Vector3(0, PI / 2.0, 0))
	box(r, Vector3(1.2, 0.3, 0.02), Vector3(0, 2.75, d / 2.0 + 0.1), "paint_white")
	collider(r, Vector3(w + 0.3, 3.0, d + 0.3), Vector3(0, 1.5, 0))
	return save_prop(r, "barn")


func _shed() -> PackedScene:
	var r := Node3D.new()
	r.name = "Workshop"
	box(r, Vector3(4.0, 2.4, 3.4), Vector3(0, 1.2, 0), "plank")
	box(r, Vector3(4.6, 0.15, 4.0), Vector3(0, 2.5, 0.1), "rust", Vector3(0.12, 0, 0))
	box(r, Vector3(1.6, 2.0, 0.1), Vector3(-0.6, 1.0, 1.72), "log_dark")
	box(r, Vector3(0.6, 0.5, 0.06), Vector3(1.2, 1.5, 1.72), "window")
	box(r, Vector3(0.9, 0.9, 0.7), Vector3(2.4, 0.45, 0.6), "metal")
	box(r, Vector3(0.5, 0.3, 0.02), Vector3(2.4, 0.7, 0.96), "paint_orange")
	collider(r, Vector3(4.4, 2.4, 3.8), Vector3(0.2, 1.2, 0))
	return save_prop(r, "workshop")


func _fence(broken := false) -> PackedScene:
	var r := Node3D.new()
	r.name = "FenceBroken" if broken else "Fence"
	var ln := 4.0
	for i in 3:
		var x := -ln / 2.0 + i * ln / 2.0
		box(r, Vector3(0.14, 1.2, 0.14), Vector3(x, 0.6, 0), "log_dark")
	for y in [0.4, 0.9]:
		if broken and y == 0.9:
			box(r, Vector3(ln / 2.0, 0.08, 0.06), Vector3(-ln / 4.0, y, 0), "plank")
			box(r, Vector3(ln / 2.2, 0.08, 0.06), Vector3(ln / 4.0, 0.1, 0.4), "plank", Vector3(0, 0.4, 0.1))
		else:
			box(r, Vector3(ln, 0.08, 0.06), Vector3(0, y, 0), "plank")
	collider(r, Vector3(ln, 1.2, 0.3), Vector3(0, 0.6, 0))
	return save_prop(r, "fence_broken" if broken else "fence")


func _well() -> PackedScene:
	var r := Node3D.new()
	r.name = "Well"
	cyl(r, 0.8, 0.85, 0.8, Vector3(0, 0.4, 0), "stone", Vector3.ZERO, 12)
	cyl(r, 0.62, 0.62, 0.82, Vector3(0, 0.42, 0), "ash", Vector3.ZERO, 12)
	for sx in [-1, 1]:
		box(r, Vector3(0.12, 1.8, 0.12), Vector3(sx * 0.75, 0.9, 0), "log_dark")
	cyl(r, 0.1, 0.1, 1.6, Vector3(0, 1.4, 0), "log", Vector3(0, 0, PI / 2.0))
	prism(r, Vector3(1.8, 0.6, 1.3), Vector3(0, 2.1, 0), "roof", Vector3(0, PI / 2.0, 0))
	collider(r, Vector3(1.7, 1.2, 1.7), Vector3(0, 0.6, 0))
	return save_prop(r, "well")


func _woodpile() -> PackedScene:
	var r := Node3D.new()
	r.name = "Woodpile"
	for row in 3:
		for i in 6 - row:
			cyl(r, 0.14, 0.14, 1.2, Vector3(-0.75 + i * 0.3 + row * 0.15, 0.14 + row * 0.26, 0), "log", Vector3(PI / 2.0, 0, 0), 7)
	box(r, Vector3(1.0, 0.5, 0.6), Vector3(1.4, 0.25, 0.2), "log_dark")
	collider(r, Vector3(2.6, 1.0, 1.3), Vector3(0.3, 0.5, 0))
	return save_prop(r, "woodpile")


func _birch() -> PackedScene:
	var r := Node3D.new()
	r.name = "Birch"
	cyl(r, 0.1, 0.16, 4.2, Vector3(0, 2.1, 0), "bark_birch", Vector3.ZERO, 7)
	sphere(r, 1.3, Vector3(0, 4.3, 0), "leaves", Vector3(1, 1.3, 1))
	sphere(r, 0.9, Vector3(0.6, 3.6, 0.3), "leaves_dark")
	collider(r, Vector3(0.5, 2, 0.5), Vector3(0, 1, 0))
	return save_prop(r, "birch")


func _larch() -> PackedScene:
	var r := Node3D.new()
	r.name = "Larch"
	cyl(r, 0.08, 0.2, 5.5, Vector3(0, 2.75, 0), "bark", Vector3.ZERO, 7)
	for i in 4:
		cyl(r, 0.0, 1.5 - i * 0.3, 1.8, Vector3(0, 2.3 + i * 1.05, 0), "needles", Vector3.ZERO, 8)
	collider(r, Vector3(0.6, 2, 0.6), Vector3(0, 1, 0))
	return save_prop(r, "larch")


func _dead_tree() -> PackedScene:
	var r := Node3D.new()
	r.name = "DeadTree"
	cyl(r, 0.06, 0.18, 4.5, Vector3(0, 2.25, 0), "ash", Vector3.ZERO, 6)
	cyl(r, 0.03, 0.06, 1.4, Vector3(0.4, 3.2, 0), "ash", Vector3(0, 0, -0.8), 5)
	cyl(r, 0.03, 0.06, 1.1, Vector3(-0.3, 2.6, 0.1), "ash", Vector3(0.2, 0, 0.9), 5)
	collider(r, Vector3(0.5, 2, 0.5), Vector3(0, 1, 0))
	return save_prop(r, "dead_tree")


func _bush() -> PackedScene:
	var r := Node3D.new()
	r.name = "Bush"
	sphere(r, 0.6, Vector3(0, 0.45, 0), "leaves_dark", Vector3(1.3, 0.8, 1.1))
	sphere(r, 0.45, Vector3(0.5, 0.4, 0.2), "leaves")
	return save_prop(r, "bush")


func _border_post() -> PackedScene:
	var r := Node3D.new()
	r.name = "BorderPost"
	for i in 5:
		box(r, Vector3(0.2, 0.36, 0.2), Vector3(0, 0.18 + i * 0.36, 0), "paint_white" if i % 2 == 0 else "paint_orange")
	collider(r, Vector3(0.4, 1.8, 0.4), Vector3(0, 0.9, 0))
	return save_prop(r, "border_post")


func _sign() -> PackedScene:
	var r := Node3D.new()
	r.name = "Sign"
	box(r, Vector3(0.12, 2.2, 0.12), Vector3(-0.9, 1.1, 0), "metal")
	box(r, Vector3(0.12, 2.2, 0.12), Vector3(0.9, 1.1, 0), "metal")
	box(r, Vector3(2.2, 0.7, 0.06), Vector3(0, 1.9, 0), "paint_white")
	box(r, Vector3(0.9, 0.22, 0.05), Vector3(0.62, 1.66, 0.06), "plank", Vector3(0, 0, -0.1))
	var l := Label3D.new()
	l.text = "НАХААРА"
	l.font_size = 64
	l.pixel_size = 0.005
	l.modulate = Color("2f2a22")
	l.outline_size = 0
	l.position = Vector3(-0.1, 1.95, 0.04)
	fit_label(l, 2.0, 0.45)
	r.add_child(l)
	var l2 := Label3D.new()
	l2.text = "РО"
	l2.font_size = 48
	l2.pixel_size = 0.005
	l2.modulate = Color("2f2a22")
	l2.outline_size = 0
	l2.position = Vector3(0.64, 1.67, 0.09)
	l2.rotation.z = -0.1
	r.add_child(l2)
	collider(r, Vector3(2.2, 2.0, 0.3), Vector3(0, 1.0, 0))
	return save_prop(r, "sign")


func _tractor() -> PackedScene:
	var r := Node3D.new()
	r.name = "Tractor"
	box(r, Vector3(1.4, 1.0, 2.6), Vector3(0, 1.0, 0.2), "rust")
	box(r, Vector3(1.3, 1.3, 1.2), Vector3(0, 1.9, -0.6), "paint_orange")
	box(r, Vector3(1.1, 0.7, 0.05), Vector3(0, 2.1, 0.02), "window")
	cyl(r, 0.9, 0.9, 0.5, Vector3(0.95, 0.9, -0.6), "ash", Vector3(0, 0, PI / 2.0), 12)
	cyl(r, 0.9, 0.9, 0.5, Vector3(-0.95, 0.9, -0.6), "ash", Vector3(0, 0, PI / 2.0), 12)
	cyl(r, 0.5, 0.5, 0.35, Vector3(0.85, 0.5, 1.2), "ash", Vector3(0, 0, PI / 2.0), 10)
	box(r, Vector3(0.4, 0.3, 0.3), Vector3(-1.2, 0.15, 1.5), "metal")
	collider(r, Vector3(2.4, 2.4, 3.2), Vector3(0, 1.2, 0))
	return save_prop(r, "tractor")


func _table() -> PackedScene:
	var r := Node3D.new()
	r.name = "Table"
	box(r, Vector3(1.4, 0.08, 0.8), Vector3(0, 0.8, 0), "plank")
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			box(r, Vector3(0.08, 0.8, 0.08), Vector3(sx * 0.6, 0.4, sz * 0.32), "log_dark")
	box(r, Vector3(1.4, 0.06, 0.3), Vector3(0, 0.45, 0.6), "plank")
	collider(r, Vector3(1.5, 0.9, 0.9), Vector3(0, 0.45, 0))
	return save_prop(r, "table")


func _garden() -> PackedScene:
	var r := Node3D.new()
	r.name = "Garden"
	box(r, Vector3(5, 0.06, 3), Vector3(0, 0.03, 0), "field")
	for i in 4:
		for j in 6:
			sphere(r, 0.22, Vector3(-2.0 + j * 0.8, 0.18, -1.0 + i * 0.66), "cabbage", Vector3(1, 0.7, 1))
	return save_prop(r, "garden")


func _fire() -> PackedScene:
	var r := Node3D.new()
	r.name = "Fire"
	r.set_script(load("res://scripts/world/fire_fx.gd"))
	return save_prop(r, "fire")


func _item_base(n: String) -> Node3D:
	var r := Node3D.new()
	r.name = n
	r.set_script(load("res://scripts/world/interactable.gd"))
	return r


func _mushroom() -> PackedScene:
	var r := _item_base("Mushroom")
	r.set("item_id", "mushroom")
	r.set("label", "Грибы")
	for p in [Vector3(0, 0, 0), Vector3(0.2, 0, 0.1), Vector3(-0.15, 0, 0.15)]:
		cyl(r, 0.03, 0.04, 0.16, p + Vector3(0, 0.08, 0), "mushroom_leg", Vector3.ZERO, 6)
		sphere(r, 0.1, p + Vector3(0, 0.17, 0), "mushroom_cap", Vector3(1, 0.55, 1))
	return save_prop(r, "mushroom")


func _berries() -> PackedScene:
	var r := _item_base("Berries")
	r.set("item_id", "berries")
	r.set("label", "Брусника")
	sphere(r, 0.35, Vector3(0, 0.22, 0), "leaves_dark", Vector3(1.2, 0.6, 1.2))
	for i in 9:
		var a := i * 0.7
		sphere(r, 0.045, Vector3(cos(a) * 0.25, 0.36, sin(a) * 0.22), "berry")
	return save_prop(r, "berries")


func _planks_item() -> PackedScene:
	var r := _item_base("Planks")
	r.set("item_id", "planks")
	r.set("label", "Доски для забора")
	for i in 3:
		box(r, Vector3(1.8, 0.05, 0.18), Vector3(0, 0.03 + i * 0.05, i * 0.04 - 0.04), "plank", Vector3(0, i * 0.08, 0))
	return save_prop(r, "planks")


func _basket() -> PackedScene:
	var r := _item_base("Basket")
	r.set("item_id", "basket")
	r.set("label", "Корзина с едой")
	cyl(r, 0.24, 0.18, 0.26, Vector3(0, 0.13, 0), "plank", Vector3.ZERO, 10)
	sphere(r, 0.18, Vector3(0, 0.27, 0), "cloth", Vector3(1, 0.4, 1))
	cyl(r, 0.2, 0.2, 0.03, Vector3(0, 0.36, 0), "log_dark", Vector3(PI / 2.0, 0, 0), 12)
	return save_prop(r, "basket")


func _bandage() -> PackedScene:
	var r := _item_base("Bandage")
	r.set("item_id", "bandage")
	cyl(r, 0.08, 0.08, 0.1, Vector3(0, 0.05, 0), "paint_white", Vector3(0, 0, PI / 2.0), 10)
	return save_prop(r, "bandage")


func _rock() -> PackedScene:
	var r := Node3D.new()
	r.name = "Rock"
	sphere(r, 0.7, Vector3(0, 0.3, 0), "stone", Vector3(1.3, 0.7, 1))
	collider(r, Vector3(1.6, 0.8, 1.2), Vector3(0, 0.4, 0))
	return save_prop(r, "rock")


# ---------------- главная сцена ----------------
func _main_scene() -> void:
	var r := Node3D.new()
	r.name = "Main"
	r.set_script(load("res://scripts/main.gd"))
	var ps := PackedScene.new()
	ps.pack(r)
	ResourceSaver.save(ps, "res://scenes/main.tscn")
	r.free()


# ---------------- локация Нахарро ----------------
var root: Node3D


## Подогнать надпись под вывеску w×h метров (pad — доля под текст, остальное — поля):
## меряет текст тем же шрифтом, что рисует Label3D, и уменьшает pixel_size, пока не влезет.
## С переносом строк (autowrap) ширина строки пересчитывается под новый масштаб.
func fit_label(l: Label3D, w: float, h: float, pad := 0.86) -> void:
	var wrap := l.autowrap_mode != TextServer.AUTOWRAP_OFF
	var hi := l.pixel_size
	if not _label_fits(l, w, h, pad, hi, wrap):
		# наибольший масштаб, при котором текст ещё влезает (с переносом — строки перестраиваются)
		var lo := 0.0003
		for i in 24:
			var mid := (lo + hi) / 2.0
			if _label_fits(l, w, h, pad, mid, wrap):
				lo = mid
			else:
				hi = mid
		hi = lo
	l.pixel_size = hi
	if wrap:
		l.width = w * pad / hi
	if hi < 0.003:
		print("  ВНИМАНИЕ: мелкая надпись (%.4f): %s" % [hi, l.text.replace("\n", " / ")])


func _label_fits(l: Label3D, w: float, h: float, pad: float, px: float, wrap: bool) -> bool:
	var f: Font = l.font if l.font else ThemeDB.fallback_font
	var wpx := w * pad / px
	var sz := f.get_multiline_string_size(l.text, HORIZONTAL_ALIGNMENT_CENTER, wpx if wrap else -1.0, l.font_size,
		-1, TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND)
	sz += Vector2.ONE * float(l.outline_size) * 2.0
	return sz.x <= wpx + 0.5 and sz.y * px <= h * pad


func put(ps: PackedScene, parent: Node, pos: Vector3, rot_y := 0.0, nm := "", sc := 1.0) -> Node3D:
	var n: Node3D = ps.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	if nm != "":
		n.name = nm
	parent.add_child(n, true)
	n.owner = root
	n.position = pos
	n.rotation.y = rot_y
	if sc != 1.0:
		n.scale = Vector3.ONE * sc
	return n


func group(parent: Node, nm: String) -> Node3D:
	var g := Node3D.new()
	g.name = nm
	parent.add_child(g)
	g.owner = root
	return g


func character(parent: Node, nm: String, char_id: String, pos: Vector3, rot_y: float, opts := {}) -> Node3D:
	var c := Node3D.new()
	c.name = nm
	c.set_script(load("res://scripts/world/character.gd"))
	c.set("char_id", char_id)
	for k in opts:
		if k == "groups":
			for g in opts[k]:
				c.add_to_group(g, true)
		else:
			c.set(k, opts[k])
	c.position = pos
	c.rotation.y = rot_y
	parent.add_child(c)
	c.owner = root
	return c


func item(parent: Node, ps: PackedScene, nm: String, pos: Vector3, groups := []) -> Node3D:
	var n := put(ps, parent, pos, randf() * TAU, nm)
	for g in groups:
		n.add_to_group(g, true)
	return n


func marker(parent: Node, nm: String, pos: Vector3, label: String) -> void:
	var m := Marker3D.new()
	m.name = nm
	m.position = pos
	m.add_to_group("map_marker", true)
	m.set_meta("label", label)
	parent.add_child(m)
	m.owner = root


func strip(parent: Node, a: Vector2, b: Vector2, w: float, mat: String, y := 0.012) -> void:
	var d := b - a
	var mi := box(parent, Vector3(w, 0.02, d.length()), Vector3((a.x + b.x) / 2.0, y, (a.y + b.y) / 2.0), mat, Vector3(0, atan2(d.x, d.y), 0))
	mi.owner = root


func _nakharro() -> void:
	seed(20620)
	root = Node3D.new()
	root.name = "Nakharro"
	root.set_script(load("res://scripts/locations/nakharro.gd"))
	root.set("location_id", "nakharro")
	root.set("title", "Нахарро")
	root.set("map_rect", Rect2(2, 2, 60, 60))
	root.set("camera_start", Vector3(30, 0, 38))

	# ---- свет и атмосфера ----
	var env_g := group(root, "Env")
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("a89777")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("b8a888")
	env.ambient_light_energy = 0.32
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
	sun.light_energy = 1.05
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 80.0
	sun.rotation = Vector3(deg_to_rad(-48), deg_to_rad(-120), 0)
	env_g.add_child(sun)
	sun.owner = root

	# ---- земля ----
	var ground := group(root, "Ground")
	var gp := MeshInstance3D.new()
	gp.name = "Grass"
	var pm := PlaneMesh.new()
	pm.size = Vector2(90, 90)
	gp.mesh = pm
	gp.material_override = M.grass
	gp.position = Vector3(32, 0, 32)
	ground.add_child(gp)
	gp.owner = root
	# сухой луг между лесом и деревней
	var meadow := box(ground, Vector3(58, 0.01, 8), Vector3(32, 0.006, 24), "grass_dry")
	meadow.owner = root
	# дороги
	strip(ground, Vector2(30, 38), Vector2(3, 38), 2.2, "dirt")
	strip(ground, Vector2(30, 38), Vector2(38, 38), 3.0, "dirt")
	strip(ground, Vector2(34, 38), Vector2(34, 20), 1.6, "dirt")
	strip(ground, Vector2(34, 20), Vector2(36, 8), 1.2, "dirt")
	strip(ground, Vector2(34, 38), Vector2(38, 47), 2.4, "dirt")
	strip(ground, Vector2(30, 38), Vector2(25, 48), 1.6, "dirt")
	strip(ground, Vector2(38, 38), Vector2(44, 48), 1.6, "dirt")
	strip(ground, Vector2(28, 36), Vector2(22, 32), 1.6, "dirt")
	var square := box(ground, Vector3(9, 0.02, 7), Vector3(34, 0.011, 39.5), "dirt")
	square.owner = root

	# ---- деревня ----
	var vil := group(root, "Village")
	put(P.izba, vil, Vector3(30, 0, 33.5), 0.0, "IzbaDed")
	put(P.izba, vil, Vector3(41, 0, 32), -0.12, "IzbaStepan")
	put(P.izba, vil, Vector3(24, 0, 42.5), PI / 2.0, "Izba3")
	put(P.izba, vil, Vector3(26, 0, 51), 0.25, "Izba4")
	put(P.izba, vil, Vector3(45.5, 0, 50.5), -0.3, "Izba5")
	put(P.barn, vil, Vector3(38, 0, 45), PI, "Barn")
	put(P.shed, vil, Vector3(21.5, 0, 33.5), 0.1, "Workshop")
	put(P.tractor, vil, Vector3(22.5, 0, 28.5), 0.6, "Tractor")
	put(P.well, vil, Vector3(34, 0, 40), 0.0, "Well")
	put(P.woodpile, vil, Vector3(45, 0, 29.5), 0.4, "Woodpile")
	put(P.table, vil, Vector3(32, 0, 37), 0.0, "TableDed")
	put(P.garden, vil, Vector3(24, 0, 37), 0.0, "Garden1")
	put(P.garden, vil, Vector3(47, 0, 42), 0.3, "Garden2")
	put(P.garden, vil, Vector3(31, 0, 48.5), 0.0, "Garden3")
	# забор Степана: целые пролёты и дыра
	put(P.fence, vil, Vector3(38, 0, 36.2), 0.0, "Fence1")
	put(P.fence_broken, vil, Vector3(42, 0, 36.2), 0.0, "FenceGap")
	put(P.fence, vil, Vector3(46, 0, 36.2), 0.0, "Fence3")
	put(P.fence, vil, Vector3(48.2, 0, 34.0), PI / 2.0, "Fence4")
	put(P.fence, vil, Vector3(48.2, 0, 30.0), PI / 2.0, "Fence5")
	for i in 4:
		put(P.bush, vil, Vector3(28 + i * 5.5 + randf(), 0, 55 + randf() * 2), randf() * TAU)

	# ---- граница на западе ----
	var border := group(root, "Border")
	for z in [33.0, 35.5, 40.5, 43.0]:
		put(P.border_post, border, Vector3(5.2, 0, z))
	put(P.sign, border, Vector3(6.5, 0, 35.2), PI / 2.0 - 0.15, "Sign")

	# ---- лес ----
	var forest := group(root, "Forest")
	var trees := [P.birch, P.larch, P.larch, P.birch, P.pine_dead]
	var clear := [Vector2(36, 8), Vector2(34, 14), Vector2(34, 20)]
	var n := 0
	for i in 420:
		var x := randf_range(3, 61)
		var z := randf_range(3, 61)
		var in_forest := z < 20.5
		var edge := x < 11 or x > 55 or z > 56
		if not (in_forest or edge):
			continue
		if abs(z - 38) < 2.2 and x < 20:
			continue
		var ok := true
		for c in clear:
			if Vector2(x, z).distance_to(c) < 2.4:
				ok = false
		for p in [Vector2(20, 14), Vector2(28, 10), Vector2(36, 16), Vector2(44, 12), Vector2(50, 8), Vector2(30, 5), Vector2(41, 5), Vector2(47, 10)]:
			if Vector2(x, z).distance_to(p) < 1.6:
				ok = false
		if not ok:
			continue
		put(trees[randi() % trees.size()], forest, Vector3(x, 0, z), randf() * TAU, "", randf_range(0.8, 1.25))
		n += 1
		if n > 170:
			break
	for i in 12:
		put(P.rock, forest, Vector3(randf_range(6, 58), 0, randf_range(4, 19)), randf() * TAU, "", randf_range(0.6, 1.3))

	# ---- огонь и дым (только во время налёта) ----
	var fx := group(root, "RaidFX")
	fx.add_to_group("phase_raid", true)
	for p in [Vector3(41, 2.5, 32), Vector3(24, 2.2, 42.5), Vector3(21.5, 1.8, 33.5), Vector3(40.5, 2.8, 44), Vector3(45.5, 2.4, 50.5), Vector3(36.5, 0.2, 38.5)]:
		put(P.fire, fx, p)
	# пепел на месте огорода
	var ash := box(fx, Vector3(5, 0.03, 3), Vector3(24, 0.07, 37), "ash")
	ash.owner = root

	# ---- персонажи ----
	var chars := group(root, "Characters")
	character(chars, "Ded", "ded", Vector3(31, 0, 37.3), PI, {"dialog": "ded", "groups": ["phase_morning"]})
	character(chars, "Stepan", "stepan", Vector3(42.5, 0, 37.6), PI * 0.9, {"dialog": "stepan", "groups": ["phase_morning"]})
	character(chars, "Varvara", "varvara", Vector3(40.6, 0, 41.2), PI, {"dialog": "varvara", "groups": ["phase_morning"]})
	character(chars, "Kid", "kid", Vector3(32.4, 0, 41.8), -0.8, {"dialog": "kid", "groups": ["phase_morning"]})
	character(chars, "Wolf", "wolf", Vector3(47, 0, 9), 1.2, {"hostile": true, "aggro_radius": 7.0, "groups": ["phase_morning"]})
	character(chars, "DedRaid", "ded", Vector3(39.4, 0, 41.3), PI, {"dialog": "ded", "dialog_node": "last", "groups": ["phase_raid"]})
	character(chars, "SoldierA", "soldier_a", Vector3(36.6, 0, 38.2), PI * 0.2, {"hostile": true, "aggro_radius": 8.5, "squad": "cleaners", "groups": ["phase_raid"]})
	character(chars, "SoldierB", "soldier_b", Vector3(41.4, 0, 39.4), -PI * 0.2, {"hostile": true, "aggro_radius": 8.5, "squad": "cleaners", "groups": ["phase_raid"]})
	character(chars, "DeadStepan", "stepan", Vector3(43.2, 0, 38.6), 0.4, {"start_dead": true, "display_name": "Степан", "groups": ["phase_raid"]})
	character(chars, "DeadVarvara", "varvara", Vector3(42.6, 0, 41.8), 2.2, {"start_dead": true, "display_name": "Тётка Варвара", "groups": ["phase_raid"]})
	character(chars, "DeadVillager1", "villager", Vector3(26.5, 0, 46.5), 1.0, {"start_dead": true, "groups": ["phase_raid"]})
	character(chars, "DeadVillager2", "villager_f", Vector3(29.5, 0, 44.2), -0.6, {"start_dead": true, "groups": ["phase_raid"]})
	character(chars, "Raider1", "raider_dead_1", Vector3(32.6, 0, 26.2), 2.6, {"start_dead": true, "groups": ["phase_raid"]})
	character(chars, "Raider2", "raider_dead_2", Vector3(27.2, 0, 38.8), -1.4, {"start_dead": true, "groups": ["phase_raid"]})
	character(chars, "Raider3", "raider_dead_3", Vector3(46.6, 0, 45.2), 0.9, {"start_dead": true, "groups": ["phase_raid"]})
	character(chars, "Raider4", "raider_dead_4", Vector3(20.2, 0, 37.2), -2.1, {"start_dead": true, "groups": ["phase_raid"]})

	# ---- предметы ----
	var items := group(root, "Items")
	item(items, P.planks, "Planks", Vector3(44.4, 0, 31.2), ["phase_morning"])
	var basket := item(items, P.basket, "Basket", Vector3(31.6, 0.84, 37.0), ["phase_morning"])
	basket.set("pick_size", Vector3(0.7, 0.9, 0.7))
	var mi := 0
	for p in [Vector3(20, 0, 14), Vector3(28, 0, 10), Vector3(36, 0, 16), Vector3(50, 0, 8), Vector3(41, 0, 5)]:
		mi += 1
		item(items, P.mushroom, "Mushroom%d" % mi, p)
	var bi := 0
	for p in [Vector3(44, 0, 12), Vector3(30, 0, 5), Vector3(47, 0, 10.5)]:
		bi += 1
		item(items, P.berries, "Berries%d" % bi, p)
	item(items, P.bandage, "BandageRaid", Vector3(29.2, 0, 36.8), ["phase_raid"])
	var ex := _item_base("BorderExit")
	ex.set("kind", "use")
	ex.set("label", "Старая черта")
	ex.set("pick_size", Vector3(1.6, 2.2, 6.0))
	ex.set("reach", 2)
	ex.position = Vector3(5.5, 0, 38)
	items.add_child(ex)
	ex.owner = root

	# ---- точки появления и отметки карты ----
	var sp := group(root, "Spawns")
	var st := Marker3D.new()
	st.name = "Start"
	st.position = Vector3(30, 0, 38.8)
	sp.add_child(st)
	st.owner = root
	marker(root, "MarkBarn", Vector3(38, 0, 45), "Амбар")
	marker(root, "MarkDed", Vector3(30, 0, 33.5), "Изба деда")
	marker(root, "MarkForest", Vector3(36, 0, 11), "Лес")
	marker(root, "MarkBorder", Vector3(6, 0, 38), "Черта")

	var ps := PackedScene.new()
	var err := ps.pack(root)
	if err != OK:
		push_error("pack failed %d" % err)
	ResourceSaver.save(ps, "res://scenes/locations/nakharro.tscn")
	root.free()
