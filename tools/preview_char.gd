extends Node3D
## Превью персонажей по шаблонам (data/characters.json): стоят в ряд, каждый со своей анимацией.
## Запуск (нужен рендер): godot --path . res://tools/preview_char.tscn -- out.png "шаблон:клип,шаблон:клип" [размер кадра]
func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	var loc: Node = load("res://scenes/locations/nakharro.tscn").instantiate()
	var env: Node = loc.get_node("Env").duplicate()
	loc.free()
	add_child(env)
	var g := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(40, 40)
	g.mesh = pm
	g.material_override = load("res://assets/materials/dirt.tres")
	add_child(g)
	var specs: PackedStringArray = a[1].split(",")
	# формат: шаблон@клип или res://модель.glb@клип@масштаб[@маска legs|upright]
	var x := -(specs.size() - 1) * 0.9
	var bodies := []
	for sp in specs:
		var kv := sp.split("@")
		if kv[0].begins_with("res://"):
			var ab := AnimBody.new()
			add_child(ab)
			ab.position = Vector3(x, 0, 0)
			ab.rotation.y = 0.5
			ab.build({"model": kv[0], "model_scale": float(kv[2]) if kv.size() > 2 else 1.0, "anim_mask": kv[3] if kv.size() > 3 else ""})
			bodies.append([{"body": ab, "char_id": kv[0]}, kv[1] if kv.size() > 1 else "Idle"])
			x += 1.8
			continue
		var ch := Character.new()
		ch.char_id = kv[0]
		ch.armed = true
		add_child(ch)
		ch.position = Vector3(x, 0, 0)
		ch.rotation.y = 0.5
		bodies.append([ch, kv[1] if kv.size() > 1 else "Idle"])
		x += 1.8
	await get_tree().create_timer(0.4).timeout
	for b in bodies:
		var body = b[0].body if b[0] is Node else b[0]["body"]
		if body is AnimBody and b[1] == "ARM":
			body.anim.stop()
			body.skel.reset_bone_poses()
			for bn in ["RightUpperArm", "LeftUpperArm", "DEF-upper_arm.R", "DEF-upper_arm.L"]:
				var bi: int = body.skel.find_bone(bn)
				if bi >= 0:
					body.skel.set_bone_pose_rotation(bi, body.skel.get_bone_pose_rotation(bi) * Quaternion(Vector3.FORWARD, 1.4 if bn.contains("ight") or bn.ends_with(".R") else -1.4))
			var hb: int = body.skel.find_bone("Head") if body.skel.find_bone("Head") >= 0 else body.skel.find_bone("DEF-head")
			body.skel.set_bone_pose_rotation(hb, body.skel.get_bone_pose_rotation(hb) * Quaternion(Vector3.UP, 1.0))
		elif body is AnimBody and b[1] == "REST":
			body.anim.stop()
			body.skel.reset_bone_poses()
		elif body is AnimBody:
			body.play(b[1], 0.0)
	var cam := Camera3D.new()
	add_child(cam)
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = float(a[2]) if a.size() > 2 else 6.0
	cam.position = Vector3(1, 0.9, 1).normalized() * 30.0 + Vector3(0, 1.0, 0)
	cam.look_at(Vector3(0, 1.0, 0))
	await get_tree().create_timer(0.9).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(a[0])
	get_tree().quit()
