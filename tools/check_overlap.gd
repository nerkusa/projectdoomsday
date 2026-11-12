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
		# без аргументов — все локации из scripts/main.gd
		var re := RegEx.new()
		re.compile("scenes/locations/([a-z0-9_]+)[.]tscn")
		for m in re.search_all(FileAccess.get_file_as_string("res://scripts/main.gd")):
			if not m.get_string(1) in locs:
				locs.append(m.get_string(1))
	var total := 0
	for l in locs:
		var ps: PackedScene = load("res://scenes/locations/%s.tscn" % l)
		var root: Node3D = ps.instantiate()
		add_child(root)
		var boxes := []
		# предметы — готовые пропсы и узлы с деталями; группы («Мусор», «Война», «Праздник») разбираются на части
		var units := []
		for gname in ["Village", "Yard"]:
			var g := root.get_node_or_null(gname)
			if g != null:
				for c in g.get_children():
					_collect(c, units)
		for c in units:
			if _skip(String(c.name)) or (c.get_parent() and _skip(String(c.get_parent().name))):
				continue
			var bb := _aabb(c)
			if bb.size.length() < 0.5 or bb.size.x * bb.size.z > 2500.0:
				continue
			# у дома считаем сруб по стенам, без свесов крыши и крыльца: под свесом вещи стоять могут
			var inn = c.get("inner")
			if inn is Vector2 and inn != Vector2.ZERO:
				bb = (c as Node3D).global_transform * AABB(Vector3(-inn.x / 2.0 - 0.2, 0, -inn.y / 2.0 - 0.2), Vector3(inn.x + 0.4, bb.size.y, inn.y + 0.4))
			elif c.scene_file_path != "" and bb.size.y > 2.4:
				bb = bb.grow(-0.3)
			# сравниваем только с постройками: крупный готовый пропс выше 2,4 м
			var bld: bool = c.scene_file_path != "" and bb.size.y > 2.4 and bb.size.x * bb.size.z > 12.0
			boxes.append([String(root.get_path_to(c)), bb, bld])
			if listing:
				print("%s: %s  x %.1f..%.1f  z %.1f..%.1f  h %.1f" % [l, c.name, bb.position.x, bb.end.x, bb.position.z, bb.end.z, bb.end.y])
		for i in boxes.size():
			for j in range(i + 1, boxes.size()):
				if not boxes[i][2] and not boxes[j][2]:
					continue
				var a: AABB = boxes[i][1]
				var b: AABB = boxes[j][1]
				var x := a.intersection(b)
				# лёгкое касание — не беда; считаем, если залезли больше чем на 0,4 м по обеим осям
				# вещь целиком внутри постройки (мебель, утварь в избе) — не пересечение
				var inner := a.grow(-0.25)
				var inner_b := b.grow(-0.25)
				var inside := (inner.position.x <= b.position.x and inner.end.x >= b.end.x and inner.position.z <= b.position.z and inner.end.z >= b.end.z) \
					or (inner_b.position.x <= a.position.x and inner_b.end.x >= a.end.x and inner_b.position.z <= a.position.z and inner_b.end.z >= a.end.z)
				if not inside and x.size.x > 0.4 and x.size.z > 0.4 and x.size.y > 0.2:
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


func _collect(n: Node, out: Array) -> void:
	if not (n is Node3D) or not (n as Node3D).visible:
		return
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
