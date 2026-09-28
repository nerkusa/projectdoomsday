extends SceneTree
## Собирает модели оружия из загруженных файлов в assets/models/weapons/<ключ>/
## в готовые сцены scenes/weapons/<ключ>.tscn, которые персонаж берёт в руку.
##
## Каждая сцена приведена к одному виду: ствол/лезвие смотрит вдоль +Z, верх — +Y,
## точка хвата (где кисть) — в начале координат, размер — настоящий, в метрах.
## Для винтовки добавлены метки Foregrip (цевьё — левая рука) и Bolt (затвор).
##
## Запуск: godot --headless --path . -s res://tools/build_weapons.gd

const SRC := "res://assets/models/weapons/"
const OUT := "res://scenes/weapons/"

## rot — поворот исходника в градусах (x, y, z), чтобы длинная сторона легла вдоль +Z.
## length — длина в метрах. grip — где хват: доля длины от заднего конца и доля высоты снизу.
## flip — развернуть на 180° вокруг Y (если перёд оказался сзади).
## up — перевернуть на 180° вокруг Z (если верх оказался снизу).
const W := {
	# у пистолета текстура из сотен мелких кусков — после упрощения она рассыпается,
	# поэтому красим по частям: металл и накладки рукояти (зона рукояти — доли габаритов)
	"pistol": {"file": "pistol/pistol_mesh.res", "rot": Vector3(0, 90, 0), "length": 0.21, "grip": Vector2(0.22, 0.3),
		"paint": {"base": Color(0.13, 0.13, 0.14), "zone": Rect2(0.0, 0.0, 0.42, 0.62), "zone_color": Color(0.07, 0.07, 0.07)},
		"metal": 0.7, "rough": 0.4},
	"father_pistol": {"same": "pistol",
		"paint": {"base": Color(0.2, 0.19, 0.18), "zone": Rect2(0.0, 0.0, 0.42, 0.62), "zone_color": Color(0.36, 0.2, 0.1)},
		"metal": 0.55, "rough": 0.6},
	"rifle": {"file": "rifle/rifle.fbx", "rot": Vector3(0, 0, 0), "flip": true, "length": 1.15, "grip": Vector2(0.3, 0.45),
		"tex": {"albedo": "enfield.png"}, "foregrip": 0.62, "bolt": 0.42},
	"oyun": {"file": "knife/knife.obj", "rot": Vector3(0, 90, 0), "length": 0.3, "grip": Vector2(0.18, 0.5),
		"tex": {"albedo": "knife.png", "normal": "knife_normal.png"}},
	"knife": {"same": "oyun"},
	"axe": {"file": "axe/axe.obj", "rot": Vector3(-90, 0, 0), "flip": true, "up": true, "length": 0.62, "grip": Vector2(0.12, 0.8),
		"tex": {"albedo": "axe_albedo.png", "normal": "axe_normal.png", "rough": "axe_rough.png", "metal": "axe_metal.png"}},
	"crowbar": {"file": "crowbar/crowbar.fbx", "rot": Vector3(-90, 0, 0), "flip": true, "length": 0.75, "grip": Vector2(0.12, 0.5),
		"tex": {"albedo": "crowbar_albedo.png"}},
	"machete": {"file": "machete/machete.fbx", "rot": Vector3(0, 0, 0), "length": 0.6, "grip": Vector2(0.12, 0.5),
		"tex": {"albedo": "machete_albedo.png", "normal": "machete_normal.png", "rough": "machete_rough.png", "metal": "machete_metal.png"}},
}


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	for k in W:
		_build(k)
	print("Оружие собрано.")
	quit()


func _cfg(k: String) -> Dictionary:
	var c: Dictionary = W[k].duplicate()
	if c.has("same"):
		var base: Dictionary = W[c.same].duplicate()
		for kk in c:
			if kk != "same":
				base[kk] = c[kk]
		base["src_key"] = c.same
		return base
	c["src_key"] = k
	return c


## Сетки исходника вместе с их положением
func _source_meshes(c: Dictionary) -> Array:
	var path: String = SRC + c.file
	var res = load(path)
	var out := []
	if res is Mesh:
		out.append([res, Transform3D.IDENTITY])
	elif res is PackedScene:
		var n: Node = res.instantiate()
		for mi in n.find_children("*", "MeshInstance3D", true, false):
			var t := Transform3D.IDENTITY
			var p: Node = mi
			while p != null and p != n:
				if p is Node3D:
					t = (p as Node3D).transform * t
				p = p.get_parent()
			out.append([(mi as MeshInstance3D).mesh, t])
		n.free()
	return out


func _material(c: Dictionary, key: String) -> StandardMaterial3D:
	var dir: String = SRC + c.file.get_base_dir() + "/"
	var tex: Dictionary = c.get("tex", {})
	var m := StandardMaterial3D.new()
	m.resource_name = key
	if c.has("paint"):
		m.vertex_color_use_as_albedo = true
		m.metallic = float(c.get("metal", 0.5))
		m.roughness = float(c.get("rough", 0.5))
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		var pp: String = OUT + key + "_mat.tres"
		ResourceSaver.save(m, pp)
		return load(pp)
	if tex.has("albedo"):
		m.albedo_texture = load(dir + tex.albedo)
	m.albedo_color = c.get("tint", Color.WHITE)
	if tex.has("normal"):
		m.normal_enabled = true
		m.normal_texture = load(dir + tex.normal)
	m.roughness = 1.0 if tex.has("rough") else 0.6
	if tex.has("rough"):
		m.roughness_texture = load(dir + tex.rough)
		m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	m.roughness = clampf(m.roughness + float(c.get("rough_add", 0.0)), 0.0, 1.0)
	if tex.has("metal"):
		m.metallic = 1.0
		m.metallic_texture = load(dir + tex.metal)
		m.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var p: String = OUT + key + "_mat.tres"
	ResourceSaver.save(m, p)
	return load(p)


func _build(k: String) -> void:
	var c := _cfg(k)
	var meshes := _source_meshes(c)
	if meshes.is_empty():
		push_error("нет сетки для " + k)
		return
	var r: Vector3 = c.rot
	var basis := Basis.from_euler(Vector3(deg_to_rad(r.x), deg_to_rad(r.y), deg_to_rad(r.z)))
	if c.get("flip", false):
		basis = Basis(Vector3.UP, PI) * basis
	if c.get("up", false):
		basis = Basis(Vector3.FORWARD, PI) * basis
	# габариты после поворота
	var ab := AABB()
	var first := true
	for mt in meshes:
		var bb: AABB = (Transform3D(basis, Vector3.ZERO) * mt[1]) * (mt[0] as Mesh).get_aabb()
		ab = bb if first else ab.merge(bb)
		first = false
	var s: float = float(c.length) / maxf(ab.size.z, 0.0001)
	var g: Vector2 = c.grip
	var grip := Vector3(ab.get_center().x, ab.position.y + ab.size.y * g.y, ab.position.z + ab.size.z * g.x) * s
	var root := Node3D.new()
	root.name = k.to_pascal_case()
	var mat := _material(c, k)
	var i := 0
	for mt in meshes:
		var mi := MeshInstance3D.new()
		mi.name = "Mesh%d" % i
		var mp: String = OUT + "%s_mesh%d.res" % [c.src_key, i]
		if c.has("paint"):
			mp = OUT + "%s_mesh%d.res" % [k, i]
			ResourceSaver.save(_painted(mt[0], c.paint, Transform3D(basis, Vector3.ZERO) * mt[1], ab), mp)
		elif not ResourceLoader.exists(mp) or c.src_key == k:
			ResourceSaver.save(mt[0], mp)
		mi.mesh = load(mp)
		mi.material_override = mat
		mi.transform = Transform3D(basis.scaled(Vector3.ONE * s), -grip) * mt[1]
		root.add_child(mi)
		mi.owner = root
		i += 1
	# метки для второй руки и затвора (винтовка)
	for pair in [["Foregrip", "foregrip"], ["Bolt", "bolt"]]:
		if not c.has(pair[1]):
			continue
		var mk := Marker3D.new()
		mk.name = pair[0]
		var z: float = (ab.position.z + ab.size.z * float(c[pair[1]])) * s - grip.z
		var y: float = (ab.position.y + ab.size.y * (0.55 if pair[1] == "foregrip" else 0.85)) * s - grip.y
		mk.position = Vector3(0, y, z)
		root.add_child(mk)
		mk.owner = root
	root.set_meta("length", c.length)
	var ps := PackedScene.new()
	ps.pack(root)
	ResourceSaver.save(ps, OUT + k + ".tscn")
	print("  %s: габариты %s, масштаб %.4f" % [k, ab.size * s, s])
	root.free()


## Раскраска по вершинам: всё — base, а вершины внутри zone (доли габаритов:
## x — вдоль длины от заднего конца, y — снизу вверх) — zone_color
func _painted(src: Mesh, paint: Dictionary, t: Transform3D, ab: AABB) -> ArrayMesh:
	var out := ArrayMesh.new()
	var zone: Rect2 = paint.zone
	for si in src.get_surface_count():
		var arr := src.surface_get_arrays(si)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var cols := PackedColorArray()
		cols.resize(v.size())
		for i in v.size():
			var p: Vector3 = t * v[i]
			var fz := (p.z - ab.position.z) / ab.size.z
			var fy := (p.y - ab.position.y) / ab.size.y
			cols[i] = paint.zone_color if zone.has_point(Vector2(fz, fy)) else paint.base
		arr[Mesh.ARRAY_COLOR] = cols
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return out
