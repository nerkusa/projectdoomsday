extends Node
## Генератор жилого дома в стиле референса «Нахарра»: сруб из потемневших брёвен
## с выпусками на углах, каменный фундамент, крыша из ржавого профнастила,
## дощатые фронтоны, окна с наличниками, крыльцо с навесом, печная труба.
##
## Текстуры делает tools/gen_textures.py. Детали собираются из примитивов и
## сливаются в одну сетку на материал (меньше вызовов отрисовки).
## Запуск: godot --headless --path . res://tools/build_house.tscn
## Перезаписывает scenes/props/izba.tscn (все избы деревни — её копии).

const MAT_DIR := "res://assets/materials/"
const TEX_DIR := "res://assets/textures/"
const MESH_DIR := "res://assets/models/houses/"

## Размеры сруба (по осям бревна — до выпусков на углах)
const W := 5.0      # вдоль X, по конёк
const D := 4.2      # вдоль Z, дверь смотрит в +Z
const LOG_R := 0.15
const LOGS := 9
const BASE_H := 0.45
const WALL_TOP := BASE_H + LOGS * LOG_R * 2.0 * 0.92
const ROOF_H := 1.7
const EAVE := 0.45  # свес крыши

var M: Dictionary = {}
var parts: Dictionary = {}  # материал -> [[mesh, transform]]


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(MESH_DIR)
	_materials()
	_build()
	var root := Node3D.new()
	root.name = "Izba"
	for m in parts:
		var mi := MeshInstance3D.new()
		mi.name = "Mesh_" + m
		mi.mesh = _merge(parts[m], MESH_DIR + "izba_" + m + ".res")
		mi.material_override = M[m]
		root.add_child(mi)
		mi.owner = root
	var body := StaticBody3D.new()
	body.name = "Collision"
	body.collision_mask = 0
	body.position = Vector3(0, 1.4, 0.15)
	root.add_child(body)
	body.owner = root
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(W + 0.6, 2.8, D + 0.9)
	cs.shape = bs
	body.add_child(cs)
	cs.owner = root
	var ps := PackedScene.new()
	ps.pack(root)
	ResourceSaver.save(ps, "res://scenes/props/izba.tscn")
	root.free()
	print("Дом собран: scenes/props/izba.tscn")
	get_tree().quit()


# ---------------- материалы ----------------
func _tex_mat(n: String, tex: String, scale: float, rough := 0.95, metal := 0.0, tint := Color.WHITE) -> void:
	var m := StandardMaterial3D.new()
	m.resource_name = n
	m.albedo_texture = load(TEX_DIR + tex + ".png")
	m.albedo_color = tint
	m.normal_enabled = true
	m.normal_texture = load(TEX_DIR + tex + "_n.png")
	m.normal_scale = 1.0
	m.roughness = rough
	m.metallic = metal
	# трипланарная проекция в координатах объекта: UV примитивов не важны,
	# рисунок не тянется и одинаков на всех деталях
	m.uv1_triplanar = true
	m.uv1_triplanar_sharpness = 4.0
	m.uv1_scale = Vector3.ONE * scale
	ResourceSaver.save(m, MAT_DIR + n + ".tres")
	M[n] = load(MAT_DIR + n + ".tres")


func _materials() -> void:
	_tex_mat("log_weathered", "log_weathered", 0.45)
	_tex_mat("metal_roof", "metal_roof", 0.8, 0.7, 0.35, Color("a8a49c"))
	_tex_mat("planks_old", "planks_old", 0.8)
	_tex_mat("stone_wall", "stone_wall", 0.6)
	_tex_mat("trim", "planks_old", 1.6, 0.9, 0.0, Color("c9bfa8"))
	M["window"] = load(MAT_DIR + "window.tres")


# ---------------- детали ----------------
func add(mat: String, mesh: Mesh, pos: Vector3, rot := Vector3.ZERO) -> void:
	if not parts.has(mat):
		parts[mat] = []
	parts[mat].append([mesh, Transform3D(Basis.from_euler(rot), pos)])


func box(mat: String, size: Vector3, pos: Vector3, rot := Vector3.ZERO) -> void:
	var b := BoxMesh.new()
	b.size = size
	add(mat, b, pos, rot)


func cyl(mat: String, r: float, h: float, pos: Vector3, rot := Vector3.ZERO, seg := 10) -> void:
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = h
	c.radial_segments = seg
	c.rings = 1
	add(mat, c, pos, rot)


func _build() -> void:
	var hx := W / 2.0
	var hz := D / 2.0
	# фундамент
	box("stone_wall", Vector3(W + 0.3, BASE_H, D + 0.3), Vector3(0, BASE_H / 2.0, 0))
	# сруб: брёвна вперевязку, выпуски 0.3 м на углах, стены вдоль Z на полбревна выше
	var step := LOG_R * 2.0 * 0.92
	for i in LOGS:
		var y := BASE_H + LOG_R + i * step
		var jitter := (0.004 * ((i * 7) % 5))
		for sz in [-1, 1]:
			cyl("log_weathered", LOG_R + jitter, W + 0.6, Vector3(0, y, sz * hz), Vector3(0, 0, PI / 2.0))
		if i < LOGS - 1:
			for sx in [-1, 1]:
				cyl("log_weathered", LOG_R, D + 0.6, Vector3(sx * hx, y + step / 2.0, 0), Vector3(PI / 2.0, 0, 0))
	# фронтоны из досок (на торцах вдоль X)
	for sx in [-1, 1]:
		var p := PrismMesh.new()
		p.size = Vector3(D + 0.1, ROOF_H, 0.12)
		add("planks_old", p, Vector3(sx * (hx - 0.02), WALL_TOP + ROOF_H / 2.0, 0), Vector3(0, PI / 2.0, 0))
		# слуховое окошко
		box("window", Vector3(0.06, 0.4, 0.4), Vector3(sx * (hx + 0.05), WALL_TOP + 0.6, 0))
		box("trim", Vector3(0.05, 0.52, 0.06), Vector3(sx * (hx + 0.08), WALL_TOP + 0.6, 0.23))
		box("trim", Vector3(0.05, 0.52, 0.06), Vector3(sx * (hx + 0.08), WALL_TOP + 0.6, -0.23))
	# крыша: два ската профнастила + конёк
	var run := hz + EAVE
	var ang := atan2(ROOF_H, hz)
	var drop := EAVE * tan(ang)
	var slope := Vector2(run, ROOF_H + drop).length()
	var ridge_y := WALL_TOP + ROOF_H + 0.06
	for sz in [-1, 1]:
		var mid := Vector3(0, ridge_y - (ROOF_H + drop) / 2.0, sz * run / 2.0)
		box("metal_roof", Vector3(W + 1.0, 0.05, slope), mid, Vector3(sz * ang, 0, 0))
		# сверху лежат заплаты из листов поменьше — «латаная» крыша.
		# Смещение считается в плоскости ската: x — вдоль конька, z — вниз по скату
		var rb := Basis.from_euler(Vector3(sz * ang, 0, 0))
		var down: float = sz * slope
		box("metal_roof", Vector3(1.3, 0.05, slope * 0.5), mid + rb * Vector3(1.1 * sz, 0.05, down * 0.2), Vector3(sz * ang, 0.0, 0))
		box("metal_roof", Vector3(0.9, 0.05, slope * 0.35), mid + rb * Vector3(-1.6 * sz, 0.05, -down * 0.25), Vector3(sz * ang, 0.0, 0))
	box("metal_roof", Vector3(W + 1.05, 0.12, 0.3), Vector3(0, ridge_y + 0.04, 0), Vector3(PI / 4.0, 0, 0))
	# печная труба
	box("stone_wall", Vector3(0.6, 2.2, 0.6), Vector3(-1.3, WALL_TOP + 1.3, -0.8))
	box("stone_wall", Vector3(0.75, 0.15, 0.75), Vector3(-1.3, WALL_TOP + 2.45, -0.8))
	# дверь с наличником (+Z)
	var door_x := 0.9
	var front := hz + LOG_R + 0.02
	box("planks_old", Vector3(0.95, 1.95, 0.08), Vector3(door_x, BASE_H + 0.98, front))
	box("trim", Vector3(0.12, 2.1, 0.1), Vector3(door_x - 0.54, BASE_H + 1.05, front + 0.02))
	box("trim", Vector3(0.12, 2.1, 0.1), Vector3(door_x + 0.54, BASE_H + 1.05, front + 0.02))
	box("trim", Vector3(1.2, 0.14, 0.1), Vector3(door_x, BASE_H + 2.07, front + 0.02))
	# крыльцо: помост, две ступени, навес на кронштейнах
	box("planks_old", Vector3(1.8, 0.14, 1.0), Vector3(door_x, BASE_H - 0.07, front + 0.5))
	box("planks_old", Vector3(1.6, 0.14, 0.35), Vector3(door_x, 0.24, front + 1.15))
	box("planks_old", Vector3(1.6, 0.14, 0.35), Vector3(door_x, 0.08, front + 1.45))
	box("metal_roof", Vector3(1.9, 0.04, 1.25), Vector3(door_x, BASE_H + 2.45, front + 0.55), Vector3(0.28, 0, 0))
	for sx in [-1, 1]:
		box("planks_old", Vector3(0.08, 0.08, 1.1), Vector3(door_x + sx * 0.8, BASE_H + 2.1, front + 0.45), Vector3(-0.6, 0, 0))
	# окна с наличниками: два на фасаде, по одному на боку и сзади
	_window(Vector3(-1.4, BASE_H + 1.35, front), Vector3.ZERO)
	_window(Vector3(2.0, BASE_H + 1.35, front), Vector3.ZERO)
	_window(Vector3(hx + LOG_R + 0.02, BASE_H + 1.35, 0.6), Vector3(0, PI / 2.0, 0))
	_window(Vector3(0.4, BASE_H + 1.35, -front), Vector3(0, PI, 0))
	# завалинка из досок под окнами — немного деталей у земли
	box("planks_old", Vector3(0.9, 0.5, 0.35), Vector3(-hx - 0.35, 0.25, -1.2))


func _window(pos: Vector3, rot: Vector3) -> void:
	var b := Basis.from_euler(rot)
	var at := func(local: Vector3) -> Vector3: return pos + b * local
	box("window", Vector3(0.7, 0.8, 0.05), at.call(Vector3(0, 0, 0.0)), rot)
	box("trim", Vector3(0.9, 0.12, 0.1), at.call(Vector3(0, 0.46, 0.04)), rot)
	box("trim", Vector3(0.95, 0.1, 0.16), at.call(Vector3(0, -0.46, 0.06)), rot)
	box("trim", Vector3(0.1, 0.9, 0.08), at.call(Vector3(-0.4, 0, 0.04)), rot)
	box("trim", Vector3(0.1, 0.9, 0.08), at.call(Vector3(0.4, 0, 0.04)), rot)
	box("trim", Vector3(0.05, 0.8, 0.06), at.call(Vector3(0, 0, 0.04)), rot)
	# ставни
	box("planks_old", Vector3(0.36, 0.86, 0.05), at.call(Vector3(-0.66, 0, 0.03)), rot)
	box("planks_old", Vector3(0.36, 0.86, 0.05), at.call(Vector3(0.66, 0, 0.03)), rot)


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
