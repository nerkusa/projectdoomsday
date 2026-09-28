class_name TargetBody
extends Node3D
## Мишень для стрельбы: столб и соломенный щит с кругами.
## Ставится вместо человечка персонажам с "dummy": true в шаблоне.


func build() -> void:
	var post := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.06
	c.bottom_radius = 0.07
	c.height = 1.6
	post.mesh = c
	post.position = Vector3(0, 0.8, -0.05)
	post.material_override = load("res://assets/materials/log_weathered.tres")
	add_child(post)
	var rings := [[0.45, "7a6c3a"], [0.32, "d8d0bb"], [0.2, "7a2e24"], [0.08, "d8d0bb"]]
	for i in rings.size():
		var d := MeshInstance3D.new()
		var cy := CylinderMesh.new()
		cy.top_radius = rings[i][0]
		cy.bottom_radius = rings[i][0]
		cy.height = 0.08 + i * 0.01
		cy.radial_segments = 16
		d.mesh = cy
		d.rotation.x = PI / 2.0
		d.position = Vector3(0, 1.35, 0.02 + i * 0.006)
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(rings[i][1])
		m.roughness = 1.0
		d.material_override = m
		add_child(d)


func apply(_a: Dictionary) -> void:
	pass


func hand() -> Node3D:
	return null
