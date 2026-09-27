extends Node3D
## Превью одного пропа: тот же свет, что в деревне, изометрическая камера.
## Запуск (нужен рендер, не --headless):
##   godot --path . res://tools/preview_prop.tscn -- out.png res://scenes/props/izba.tscn 11 [поворот]
## 11 — размер кадра в метрах, поворот — в радианах.
func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	var loc: Node = load("res://scenes/locations/nakharro.tscn").instantiate()
	var env: Node = loc.get_node("Env").duplicate()
	loc.free()
	add_child(env)
	var g := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(40, 40); g.mesh = pm
	g.material_override = load("res://assets/materials/dirt.tres"); add_child(g)
	var h: Node3D = load(a[1]).instantiate(); add_child(h)
	h.rotation.y = float(a[3]) if a.size() > 3 else 0.0
	var cam := Camera3D.new(); add_child(cam)
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL; cam.size = float(a[2])
	cam.position = Vector3(1, 1, 1).normalized() * 32.0 + Vector3(0, 1.5, 0)
	cam.look_at(Vector3(0, 1.5, 0))
	await get_tree().create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(a[0])
	get_tree().quit()
