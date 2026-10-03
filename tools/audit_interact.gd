extends Node
## Проверка: у каждого места в каждой локации каждое действие из меню даёт отклик
## (мысль, запись в журнале, разговор, окно обыска, переход). Молчаливые — в список.
## Запуск: godot --headless --path . res://tools/audit_interact.tscn

var main: Node
var logs := 0


func frames(n := 3) -> void:
	for i in n:
		await get_tree().process_frame


func _ready() -> void:
	Engine.time_scale = 8.0
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await frames(3)
	Game.new_hero()
	Game.hero.locked = true
	Game.log_added.connect(func(_a, _b, _c): logs += 1)
	Clock.running = false
	Clock.force_day = true
	var silent := []
	var total := 0
	for lid in main.LOCATIONS:
		await main.load_location(lid, "Start")
		await frames(4)
		main.dialog.close()
		var names := []
		for it in main.location.items():
			names.append(String(it.name))
		for nm in names:
			var loc = main.location
			if loc.location_id != lid:
				await main.load_location(lid, "Start")
				await frames(4)
				loc = main.location
			var it: Interactable = loc.item(nm)
			if it == null or not it.visible:
				continue
			var acts: Array = loc.item_actions(it) if loc.has_method("item_actions") else []
			if acts.is_empty():
				acts = [["Взять / использовать", "use"]]
			for a in acts:
				it = loc.item(nm)
				if it == null:
					break
				total += 1
				var before := logs
				var what: String = a[1]
				main.dialog.close()
				main.loot_win.close()
				main.world_map.visible = false
				if what.begins_with("use:"):
					it.set_meta("act", what.substr(4))
				main.interact(it)
				await frames(3)
				# подбирание — после анимации
				var tw := 0
				while logs == before and tw < 40 and main.player and not main.player._act.is_empty():
					await frames(1)
					tw += 1
				if is_instance_valid(it) and it.has_meta("act"):
					it.remove_meta("act")
				var ok: bool = logs > before or main.dialog.visible or main.loot_win.visible or main.world_map.visible \
					or main.trade_win.visible or main._loading or main.location == null or main.location != loc or main.hud.thought_visible() or main.player.has_meta("acting")
				if not ok:
					silent.append("%s / %s / %s" % [lid, nm, a[0]])
				main.hud._thought.visible = false
				while main._loading:
					await frames(2)
				main.dialog.close()
				main.loot_win.close()
				main.world_map.visible = false
				if main.location == null or main.location.location_id != lid:
					break
	print("Проверено действий: ", total)
	for s in silent:
		print("  МОЛЧИТ: ", s)
	print("=== молчаливых: %d ===" % silent.size())
	get_tree().quit()
