extends Node
## Поиск «летающих» объектов: всё, что висит над землёй (низ выше 15 см) и при этом
## ни на чём не стоит и ни к чему не прикреплено (не касается габаритов другого объекта).
## Запуск: $G --headless --path . res://tools/audit_float.tscn [-- локация …]   (без аргументов — все локации)
## Внутри домов не ищет: вещь на столе в избе касается габарита самой избы.

const SKIP_GROUPS := ["Env", "Spawns", "Characters", "Ground", "Water"]
const SKIP := ["Smoke", "Spark", "Flame", "Fire", "Wire", "Garland", "Flag", "Banner", "Rope", "Cable", "Fog", "Gas", "Cloud", "Bird", "Light", "Glow", "Beam"]
const GAP := 0.15


func _ready() -> void:
	var locs: PackedStringArray = OS.get_cmdline_user_args()
	if locs.is_empty():
		var main_src := FileAccess.get_file_as_string("res://scripts/main.gd")
		var re := RegEx.new()
		re.compile("scenes/locations/([a-z0-9_]+)[.]tscn")
		for m in re.search_all(main_src):
			if not m.get_string(1) in locs:
				locs.append(m.get_string(1))
	var total := 0
	for l in locs:
		var path := "res://scenes/locations/%s.tscn" % l
		if not ResourceLoader.exists(path):
			continue
		var root: Node3D = (load(path) as PackedScene).instantiate()
		root.set_script(null)
		add_child(root)
		var units := []
		for g in root.get_children():
			if g is Node3D and not String(g.name) in SKIP_GROUPS:
				_collect(g, units)
		var boxes := []
		for u in units:
			var bb := _aabb(u)
			if bb.size.length() > 0.05:
				boxes.append([u, bb])
		print("# %s: объектов %d" % [l, boxes.size()])
		for i in boxes.size():
			var a: AABB = boxes[i][1]
			var n: Node = boxes[i][0]
			if a.position.y <= GAP or _skip(n):
				continue
			# провода между столбами: длинные, тонкие, провисают дугой
			if n is MeshInstance3D and a.size.y < 0.8 and minf(a.size.x, a.size.z) < 0.6 and maxf(a.size.x, a.size.z) > 3.0 and a.position.y > 3.0:
				continue
			var held := false
			var ag := a.grow(0.12)
			for j in boxes.size():
				var o: AABB = boxes[j][1]
				# опора — что-то рядом, что само стоит ниже и доходит до нашего низа; огромные
				# габариты (частокол кольцом, лес, дороги) опорой не считаются
				if j != i and o.size.x * o.size.z < 900.0 and ag.intersects(o) and o.position.y < a.position.y - 0.02 and o.end.y > a.position.y - 0.12:
					held = true
					break
			if not held:
				total += 1
				print("%s: %s  низ %.2f м, у (%.1f, %.1f), размер %s" % [l, root.get_path_to(n), a.position.y, a.get_center().x, a.get_center().z, str(a.size.snapped(Vector3.ONE * 0.1))])
		root.queue_free()
		await get_tree().process_frame
	print("=== летающих: %d ===" % total)
	get_tree().quit()


func _skip(n: Node) -> bool:
	var p := String(n.name)
	if n.get_parent():
		p += "/" + String(n.get_parent().name)
	for s in SKIP:
		if p.contains(s):
			return true
	return false


## Объект — готовый пропс, отдельная деталь или узел с деталями прямо внутри
func _collect(n: Node, out: Array) -> void:
	if not (n is Node3D) or not (n as Node3D).visible:
		return
	# узел, внутри которого только детали (без вложенных групп) — один предмет
	var geo := 0
	var other := 0
	for c in n.get_children():
		if c is GeometryInstance3D or c is CollisionObject3D or c is Light3D:
			geo += 1
		elif c is Node3D:
			other += 1
	if n is GeometryInstance3D or n.scene_file_path != "" or (geo > 0 and other == 0):
		out.append(n)
		return
	for c in n.get_children():
		_collect(c, out)


func _aabb(n: Node) -> AABB:
	var out := AABB()
	var first := true
	var all: Array = n.find_children("*", "GeometryInstance3D", true, false)
	if n is GeometryInstance3D:
		all.append(n)
	for v in all:
		if not (v as Node3D).is_visible_in_tree() or v is GPUParticles3D or v is CPUParticles3D:
			continue
		var b: AABB = (v as VisualInstance3D).global_transform * (v as VisualInstance3D).get_aabb()
		out = b if first else out.merge(b)
		first = false
	return out
