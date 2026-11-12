extends Node3D
## Лист превью: несколько пропсов в ряд, два кадра — спереди и сзади (поворот на 180°).
## Запуск (нужен рендер): godot --path . res://tools/prop_sheet.tscn -- /путь/префикс izba hall st_dk …
## → префикс_a.png (как стоит), префикс_b.png (развёрнуто). Имена — файлы из scenes/props без .tscn.
func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	var loc: Node = load("res://scenes/locations/nakharro.tscn").instantiate()
	var env: Node = loc.get_node("Env").duplicate()
	loc.free()
	add_child(env)
	var g := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(400, 400)
	g.mesh = pm
	g.material_override = load("res://assets/materials/dirt.tres")
	add_child(g)
	var nodes := []
	var x := 0.0
	var maxh := 3.0
	for i in range(1, a.size()):
		var h: Node3D = load("res://scenes/props/%s.tscn" % a[i]).instantiate()
		add_child(h)
		var bb := _aabb(h)
		var r := maxf(bb.size.x, bb.size.z) * 0.5 + 0.6
		x += r
		# по диагонали экрана: слева направо
		h.position = Vector3(x, 0, -x)
		x += r
		maxh = maxf(maxh, bb.size.y)
		nodes.append(h)
		var l := Label3D.new()
		l.text = a[i]
		l.font_size = 96
		l.pixel_size = 0.012
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		l.outline_size = 24
		l.position = h.position + Vector3(0, bb.size.y + 1.2, 0)
		add_child(l)
	var cam := Camera3D.new()
	add_child(cam)
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = maxf(x * 1.42 * 9.0 / 16.0 + 2.0, maxh * 1.3 + 5.0)
	var c := Vector3(x / 2.0, maxh * 0.4, -x / 2.0)
	cam.position = c + Vector3(1, 1, 1).normalized() * 120.0
	cam.far = 400.0
	cam.look_at(c)
	for pass_i in 2:
		for h in nodes:
			(h as Node3D).rotation.y = PI * pass_i
		await get_tree().create_timer(0.5).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s_%s.png" % [a[0], "ab"[pass_i]])
	get_tree().quit()


func _aabb(n: Node) -> AABB:
	var out := AABB()
	var first := true
	for v in n.find_children("*", "MeshInstance3D", true, false):
		var b: AABB = (v as MeshInstance3D).global_transform * (v as MeshInstance3D).get_aabb()
		out = b if first else out.merge(b)
		first = false
	return out
