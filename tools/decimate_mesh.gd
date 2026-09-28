extends SceneTree
## Упрощает тяжёлую модель: берёт первую сетку из .glb/.fbx, строит уровни детализации
## и сохраняет самый подходящий (не больше target треугольников) как .res без лишних вершин.
## Запуск: godot --headless --path . -s res://tools/decimate_mesh.gd -- <вход.glb> <выход.res> <треугольников>

func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var src: String = a[0]
	var dst: String = a[1]
	var target := int(a[2])
	var ps: PackedScene = load(src)
	var root := ps.instantiate()
	var mi: MeshInstance3D = root.find_children("*", "MeshInstance3D", true, false)[0]
	var arr := mi.mesh.surface_get_arrays(0)
	var im := ImporterMesh.new()
	im.add_surface(Mesh.PRIMITIVE_TRIANGLES, arr)
	im.generate_lods(25.0, 60.0, [])
	# после generate_lods вершины могут быть переупорядочены — индексы уровней ссылаются на новые массивы
	arr = im.get_surface_arrays(0)
	var best: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	for i in im.get_surface_lod_count(0):
		var idx := im.get_surface_lod_indices(0, i)
		print("уровень %d: %d треугольников" % [i, idx.size() / 3])
		if idx.size() / 3 <= target:
			best = idx
			break
		best = idx
	# оставляем только используемые вершины
	var remap := {}
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var tans := PackedFloat32Array()
	var sv: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var sn: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var su: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
	var st = arr[Mesh.ARRAY_TANGENT]
	var out := PackedInt32Array()
	for i in best:
		if not remap.has(i):
			remap[i] = verts.size()
			verts.append(sv[i])
			norms.append(sn[i])
			uvs.append(su[i])
			if st:
				for k in 4:
					tans.append(st[i * 4 + k])
		out.append(remap[i])
	var na := []
	na.resize(Mesh.ARRAY_MAX)
	na[Mesh.ARRAY_VERTEX] = verts
	na[Mesh.ARRAY_NORMAL] = norms
	na[Mesh.ARRAY_TEX_UV] = uvs
	if st:
		na[Mesh.ARRAY_TANGENT] = tans
	na[Mesh.ARRAY_INDEX] = out
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, na)
	ResourceSaver.save(m, dst)
	print("сохранено: %s — %d треугольников, %d вершин" % [dst, out.size() / 3, verts.size()])
	quit()
