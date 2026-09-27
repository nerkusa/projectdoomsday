class_name MapView
extends Control
## Карта локации на экране КПК: проходимые места, ты, люди, отметки.

var main: Node


func _draw() -> void:
	if main == null or main.location == null:
		return
	var loc: Location = main.location
	var r := loc.map_rect
	var sc := minf(size.x / r.size.x, size.y / r.size.y)
	var off := Vector2((size.x - r.size.x * sc) / 2.0, (size.y - r.size.y * sc) / 2.0)
	var to_px := func(p: Vector3) -> Vector2:
		return off + Vector2(p.x - r.position.x, p.z - r.position.y) * sc
	draw_rect(Rect2(off, r.size * sc), Color(UITheme.GREEN, 0.05))
	var blocked := Color(UITheme.GREEN, 0.55)
	for h in loc.grid.free:
		if not loc.grid.free[h]:
			draw_rect(Rect2(to_px.call(loc.grid.to_world(h)) - Vector2(1.2, 1.2), Vector2(2.4, 2.4)), blocked)
	for m in loc.get_tree().get_nodes_in_group("map_marker"):
		if m is Node3D and m.is_visible_in_tree():
			var p: Vector2 = to_px.call(m.global_position)
			draw_colored_polygon(PackedVector2Array([p + Vector2(0, -6), p + Vector2(6, 0), p + Vector2(0, 6), p + Vector2(-6, 0)]), UITheme.S2)
			var t: String = m.get_meta("label", "")
			if t != "":
				draw_string(UITheme.mono(), p + Vector2(8, 4), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UITheme.GREEN_HI)
	for ch in loc.characters():
		if ch.visible and ch.pose != "dead":
			draw_circle(to_px.call(ch.global_position), 3.0, UITheme.GREEN_HI if not ch.hostile else Color("ff7a4a"))
	var pp: Vector2 = to_px.call(main.player.global_position)
	draw_rect(Rect2(pp - Vector2(4, 4), Vector2(8, 8)), UITheme.AMBER_HOT)


func _process(_d: float) -> void:
	queue_redraw()
