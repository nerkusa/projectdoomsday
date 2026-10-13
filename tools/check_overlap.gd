extends Node
## Проверка расстановки: какие постройки и крупные пропсы залезают друг в друга.
## Запуск: $G --headless --path . res://tools/check_overlap.tscn -- sungar sungar_center …
## Сравниваются габариты (AABB) верхних узлов групп Village и Yard: постройки — между собой
## и с крупными пропсами. Мелочь (мусор, фонари, провода, трубы) не считается.

const SKIP := ["Fire", "Palisade", "Pavement", "Power", "Wire", "Pipe", "Lamp", "Graffiti", "Sign", "Neon", "Label", "Road", "Strip", "Mud",
	"Puddle", "Trash", "Rubble", "Crack", "Pothole", "Grass", "Bush", "Tree", "Fence", "Edge", "Wall", "Boardwalk", "Plank"]


func _ready() -> void:
	var locs: PackedStringArray = OS.get_cmdline_user_args()
	# «list» первым аргументом — просто перечислить габариты (x0..x1, z0..z1) всего, что проверяется
	var listing := not locs.is_empty() and locs[0] == "list"
	if listing:
		locs.remove_at(0)
	if locs.is_empty():
		locs = PackedStringArray(["sungar", "sungar_center", "sungar_quarter"])
	var total := 0
	for l in locs:
		var ps: PackedScene = load("res://scenes/locations/%s.tscn" % l)
		var root: Node3D = ps.instantiate()
		add_child(root)
		var boxes := []
		for gname in ["Village", "Yard"]:
			var g := root.get_node_or_null(gname)
			if g == null:
				continue
			for c in g.get_children():
				if not c is Node3D or _skip(String(c.name)):
					continue
				var bb := _aabb(c)
				if bb.size.length() < 0.5:
					continue
				boxes.append([String(c.name), bb])
				if listing:
					print("%s: %s  x %.1f..%.1f  z %.1f..%.1f  h %.1f" % [l, c.name, bb.position.x, bb.end.x, bb.position.z, bb.end.z, bb.end.y])
		for i in boxes.size():
			for j in range(i + 1, boxes.size()):
				var a: AABB = boxes[i][1]
				var b: AABB = boxes[j][1]
				var x := a.intersection(b)
				# лёгкое касание — не беда; считаем, если залезли больше чем на 0,4 м по обеим осям
				if x.size.x > 0.4 and x.size.z > 0.4 and x.size.y > 0.2:
					print("%s: %s ⟷ %s  (%.1f × %.1f м, у %s)" % [l, boxes[i][0], boxes[j][0], x.size.x, x.size.z, str(Vector2(x.get_center().x, x.get_center().z).snapped(Vector2(0.1, 0.1)))])
					total += 1
		root.queue_free()
	print("=== пересечений: %d ===" % total)
	get_tree().quit()


func _skip(n: String) -> bool:
	for s in SKIP:
		if n.contains(s):
			return true
	return false


func _aabb(n: Node) -> AABB:
	var out := AABB()
	var first := true
	for v in n.find_children("*", "GeometryInstance3D", true, false):
		if not (v as Node3D).is_visible_in_tree():
			continue
		var b: AABB = (v as VisualInstance3D).global_transform * (v as VisualInstance3D).get_aabb()
		if first:
			out = b
			first = false
		else:
			out = out.merge(b)
	if n is GeometryInstance3D:
		var b2: AABB = (n as VisualInstance3D).global_transform * (n as VisualInstance3D).get_aabb()
		out = b2 if first else out.merge(b2)
	return out
