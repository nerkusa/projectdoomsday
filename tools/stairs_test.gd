extends Node
## Проверка лестниц «как игрок»: герой идёт к лестнице кликом издалека, поднимается, спускается.
## Ловит телепорт «непонятно куда»: после перехода герой должен стоять внутри карты на свободном месте.
## Запуск: godot --headless --path . res://tools/stairs_test.tscn
var main: Node
var fails := 0


func ok(c: bool, what: String) -> void:
	print("  ok  " if c else "  FAIL ", what)
	if not c:
		fails += 1


func frames(n := 2) -> void:
	for i in n:
		await get_tree().process_frame


func settle(sec := 2.0) -> void:
	while main._loading:
		await frames(2)
	await get_tree().create_timer(sec).timeout
	main.dialog.close()


func sane(tag: String) -> void:
	var loc = main.location
	var p: Vector3 = main.player.global_position
	var inside: bool = loc.map_rect.has_point(Vector2(p.x, p.z))
	var g = loc.grid
	var free: bool = g.is_free(g.from_world(p)) or g.to_world(g.nearest_free(p)).distance_to(p) < 1.6
	ok(inside and free, "%s: %s, герой на месте %s (в карте=%s, свободно=%s)" % [tag, loc.location_id, p.snapped(Vector3.ONE * 0.1), inside, free])


## Клик по предмету издалека, пока герой уже куда-то идёт
func click(name: String, from: Vector3) -> void:
	var loc = main.location
	var it = loc.item(name)
	if it == null:
		ok(false, "нет предмета " + name)
		return
	main.player.stop()
	main.player.global_position = from
	await frames(3)
	# сначала клик по земле в другую сторону, потом — по лестнице (как торопливый игрок)
	main._walk_to_hex(loc.grid.from_world(from + Vector3(6, 0, 6)))
	await frames(4)
	var id0: String = loc.location_id
	main._go_then(it, "use")
	var t := 0.0
	while main.location != null and main.location.location_id == id0 and not main._loading and t < 40.0:
		await frames(2)
		t += 0.1
	await settle()


func _ready() -> void:
	Engine.time_scale = 4.0
	Clock.running = false
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await frames(3)
	Game.new_hero()
	main.menu.visible = false
	get_tree().paused = false
	main.load_location("nakharro", "Start")
	await settle(1.0)
	for h in ["Izba5", "Izba9", "Izba13"]:
		var nk = main.location
		var st = nk.item("Stairs_" + h)
		main.player.stop()
		main.player.global_position = st.global_position + Vector3(4, 0, 5) if h != "Izba13" else st.global_position + Vector3(-4, 0, 5)
		await frames(3)
		main._walk_to_hex(nk.grid.from_world(main.player.global_position + Vector3(6, 0, 6)))
		await frames(4)
		main._go_then(st, "use")
		var t := 0.0
		while nk.up_cur != h and t < 40.0:
			await frames(2)
			t += 0.1
		await get_tree().create_timer(1.5).timeout
		ok(main.location.location_id == "nakharro" and nk.up_cur == h, h + ": поднялся в светёлку без перехода (высота %.1f)" % main.player.global_position.y)
		await sane(h + " наверху")
		ok(nk.get_node("Upper_" + h).visible, h + ": светёлка видна")
		await get_tree().create_timer(3.0).timeout
		await sane(h + " наверху, спустя время")
		main._go_then(nk.item("Down_" + h), "use")
		t = 0.0
		while nk.up_cur != "" and t < 40.0:
			await frames(2)
			t += 0.1
		await get_tree().create_timer(1.5).timeout
		ok(nk.up_cur == "" and main.player.global_position.y < 0.3, h + ": спустился (высота %.1f)" % main.player.global_position.y)
		await sane(h + " внизу")
		ok(not nk.get_node("Upper_" + h).visible, h + ": светёлка спрятана")
	for f in ["sg_entered", "sg_permit", "seen_sungar"]:
		Game.set_flag(f)
	for pair in [["sungar", "HotelStairs"], ["sungar_center", "DomStairs"], ["sungar_center", "AdminStairs"], ["sungar_quarter", "ObshagaStairs"]]:
		main.load_location(pair[0], "Start")
		await settle(1.0)
		var st2 = main.location.item(pair[1])
		if st2 == null:
			ok(false, "нет лестницы " + pair[1])
			continue
		await click(pair[1], st2.global_position + Vector3(3, 0, 4))
		ok(main.location.location_id != pair[0], pair[1] + ": поднялся")
		await sane(pair[1] + " наверху")
		await get_tree().create_timer(3.0).timeout
		await sane(pair[1] + " наверху, спустя время")
	print("=== ИТОГ: ошибок ", fails, " ===")
	get_tree().quit(1 if fails else 0)
