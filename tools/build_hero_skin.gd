extends SceneTree
## Собирает сетку героя с новой развёрткой из assets/models/hero_skin_mesh.bin
## (его пишет tools/bake_hero_skin.py) в assets/models/hero_skin_mesh.res.
## Кости и веса те же, что у манекена UAL, поэтому все анимации работают как есть.
## Запуск: godot --headless --path . -s res://tools/build_hero_skin.gd

func _init() -> void:
	var f := FileAccess.open("res://assets/models/hero_skin_mesh.bin", FileAccess.READ)
	var nv := f.get_32()
	var nf := f.get_32()
	var pos := PackedVector3Array()
	var nrm := PackedVector3Array()
	var uv := PackedVector2Array()
	var bones := PackedInt32Array()
	var wts := PackedFloat32Array()
	var idx := PackedInt32Array()
	pos.resize(nv)
	nrm.resize(nv)
	uv.resize(nv)
	for i in nv:
		pos[i] = Vector3(f.get_float(), f.get_float(), f.get_float())
	for i in nv:
		nrm[i] = Vector3(f.get_float(), f.get_float(), f.get_float())
	for i in nv:
		uv[i] = Vector2(f.get_float(), f.get_float())
	for i in nv * 4:
		bones.append(f.get_32())
	for i in nv * 4:
		wts.append(f.get_float())
	for i in nf:
		var a := f.get_32()
		var b := f.get_32()
		var c := f.get_32()
		# у glTF лицевая сторона — против часовой, у Godot — по часовой
		idx.append_array([a, c, b])
	# проверка: номера костей совпадают с теми, что даёт импорт манекена
	var ps: PackedScene = load("res://assets/models/AnimationLibrary_Godot_Standard.glb")
	var inst := ps.instantiate()
	var mi: MeshInstance3D = inst.find_children("*", "MeshInstance3D", true, false)[0]
	var ref := mi.mesh.surface_get_arrays(0)
	var rp: PackedVector3Array = ref[Mesh.ARRAY_VERTEX]
	var rb: PackedInt32Array = ref[Mesh.ARRAY_BONES]
	var bad := 0
	for k in [0, 500, 1500, 3000]:
		var best := -1
		var bd := 1e9
		for j in rp.size():
			var d := rp[j].distance_squared_to(pos[k])
			if d < bd:
				bd = d
				best = j
		var a1 := [bones[k * 4], bones[k * 4 + 1], bones[k * 4 + 2], bones[k * 4 + 3]]
		var a2 := [rb[best * 4], rb[best * 4 + 1], rb[best * 4 + 2], rb[best * 4 + 3]]
		a1.sort()
		a2.sort()
		print("вершина %d: кости %s / импорт %s (расст. %.4f)" % [k, a1, a2, sqrt(bd)])
		if a1 != a2:
			bad += 1
	inst.free()
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = pos
	arr[Mesh.ARRAY_NORMAL] = nrm
	arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_BONES] = bones
	arr[Mesh.ARRAY_WEIGHTS] = wts
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	ResourceSaver.save(m, "res://assets/models/hero_skin_mesh.res")
	print("сетка героя собрана, несовпадений костей: ", bad)
	quit()
