extends Node
## Автотест пролога: проходит всю цепочку без участия человека и печатает, что сломалось.
## Запуск: godot --headless --path . res://tools/smoke_test.tscn

var main: Node
var fails := 0


func ok(cond: bool, what: String) -> void:
	if cond:
		print("  ok  ", what)
	else:
		print("  FAIL ", what)
		fails += 1


func wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func frames(n := 2) -> void:
	for i in n:
		await get_tree().process_frame


func close_dialogs() -> void:
	var guard := 0
	while main.dialog.visible and guard < 20:
		main.dialog._finish_typing()
		main.dialog._choose(0)
		await frames(2)
		guard += 1


func choose(i: int) -> void:
	main.dialog._finish_typing()
	main.dialog._choose(i)
	await frames(2)


func opt_texts() -> Array:
	var out := []
	for o in main.dialog._visible_opts:
		out.append(o.get("text", ""))
	return out


func find_opt(sub: String) -> int:
	var t := opt_texts()
	for i in t.size():
		if sub in t[i]:
			return i
	return -1


func tp(pos: Vector3) -> void:
	main.player.stop()
	main.player.global_position = pos
	main.cam_target = pos
	await frames(3)


func fight(max_turns := 80) -> void:
	var guard := 0
	while main.combat.on and guard < max_turns * 20:
		guard += 1
		await frames(1)
		if main.combat.my_turn():
			if not "fair" in OS.get_cmdline_user_args():
				Game.set_hero_hp(Game.hero_max())
			var target: Fighter = null
			var bd := 999
			for e in main.combat.enemies():
				var d: int = main.location.grid.distance(main.combat.hero_f.hex, e.hex)
				if d < bd:
					bd = d
					target = e
			if target == null:
				continue
			var ap_before: int = main.combat.hero_f.ap
			main.combat.click(target.node, null)
			await frames(2)
			if main.combat.my_turn() and main.combat.hero_f.ap == ap_before:
				main.combat.end_turn()
		await wait(0.02)


func _ready() -> void:
	Engine.time_scale = 4.0
	print("=== СМОУК-ТЕСТ ПРОЛОГА ===")
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await frames(3)
	ok(main.menu.visible, "главное меню открыто")
	main._on_menu("new")
	await frames(2)
	ok(main.sheet.visible, "лист персонажа открыт")
	Game.hero.name = "Тестер"
	Game.hero.stats.REF = 7
	Game.hero.stats.DEX = 6
	Game.hero.skills["Дальний бой"] = 5
	Game.hero.skills["Ближний бой"] = 4
	main.sheet.close()
	await frames(2)
	ok(main.slides.visible, "вступление показывается")
	var g := 0
	while main.slides.visible and g < 50:
		main.slides._next()
		main.slides._next()
		await frames(1)
		g += 1
	var t := 0.0
	while (main.location == null or main._loading) and t < 10.0:
		await wait(0.1)
		t += 0.1
	ok(main.location != null, "локация загружена")
	var grid: HexGrid = main.location.grid
	var free := 0
	for h in grid.free:
		if grid.free[h]:
			free += 1
	print("  гексов: ", grid.free.size(), ", проходимых: ", free)
	ok(free > 5000, "сетка проходимости построена")
	ok(not grid.is_free(grid.from_world(Vector3(44, 0, 38.6))), "стена избы деда непроходима")
	# в каждую постройку можно войти через дверь
	var closed := []
	for hs in get_tree().get_nodes_in_group("houses"):
		var a := grid.nearest_free(hs.door_point(1.5))
		var reach := false
		for h in grid.free:
			if not grid.free[h]:
				continue
			var l: Vector3 = hs.to_local(grid.to_world(h))
			if absf(l.x) < hs.inner.x / 2.0 and absf(l.z) < hs.inner.y / 2.0 and not grid.explore_path(a, h).is_empty():
				reach = true
				break
		if not reach:
			closed.append(String(hs.name))
	ok(closed.is_empty() and get_tree().get_nodes_in_group("houses").size() >= 17, "во все дома можно войти (%d; закрыты: %s)" % [get_tree().get_nodes_in_group("houses").size(), closed])
	await wait(1.0)
	ok(main.dialog.visible, "мысли при пробуждении")
	await close_dialogs()
	ok(Game.hero.owned.has("pistol") and Game.hero.owned.has("knife"), "с начала есть пистолет и нож")
	ok(not main.hud._bar.visible, "нижней панели нет до мини-компьютера")
	# свободная ходьба: герой встаёт ровно в точку клика, а не в центр гекса
	var start: Vector3 = main.player.global_position
	var spot := start + Vector3(1.37, 0, 0.61)
	main._walk_to_hex(grid.from_world(spot), Callable(), spot)
	await wait(1.5)
	ok(main.player.global_position.distance_to(spot) < 0.05, "свободная ходьба в точку клика")
	# зайти в избу деда: крыша прячется
	var izba: House = main.location.get_node("Village/IzbaDed")
	main._walk_to_hex(grid.from_world(izba.door_point(-1.2)), Callable(), izba.door_point(-1.2))
	await wait(4.0)
	ok(izba.inside and not izba.get_node("Upper").visible, "вошёл в избу — крыша спрятана")
	main._walk_to_hex(grid.from_world(izba.door_point(3.0)), Callable(), izba.door_point(3.0))
	await wait(4.0)
	ok(not izba.inside and izba.get_node("Upper").visible, "вышел — крыша на месте")

	# --- дед: утренние дела ---
	main.talk_to(main.location.character("Ded"))
	await frames(2)
	ok(main.dialog.visible, "разговор с дедом")
	await choose(find_opt("Что нужно"))
	await choose(0)
	ok(Game.quest_stage("chores") == 1, "задание «Утро» взято")
	ok(main.objective_text().contains("Степан"), "цель на экране: " + main.objective_text().replace("\n", " / "))
	main.interact(main.location.item("Planks"))
	await wait(1.0)
	ok(Game.item_count("planks") == 1, "доски подобраны")
	main.talk_to(main.location.character("Stepan"))
	await frames(2)
	await choose(find_opt("Вот доски"))
	await choose(1)
	await close_dialogs()
	ok(Game.flag("fence_done"), "забор починен")
	main.interact(main.location.item("Basket"))
	await wait(1.0)
	main.talk_to(main.location.character("Varvara"))
	await frames(2)
	await choose(find_opt("Вот корзина"))
	await close_dialogs()
	ok(Game.flag("basket_done"), "корзина отдана")
	ok(Game.quest_stage("chores") == 2, "утренние дела готовы")
	main.talk_to(main.location.character("Ded"))
	await frames(2)
	await choose(find_opt("Всё сделал"))
	await choose(0)
	await close_dialogs()
	ok(Game.quest_stage("chores") == 3, "дед отправил в лес")
	ok(Game.quest_stage("forest") == 1, "задание «Лес» взято")

	# --- побочные задания утром ---
	# хлам в амбаре и запертый сундук
	main.talk_to(main.location.character("Varvara"))
	await frames(2)
	await choose(find_opt("Чем ещё"))
	await close_dialogs()
	ok(Game.quest_stage("barn_junk") == 1, "Варвара дала задание про хлам")
	for n in ["Junk1", "Junk2", "Junk3", "LockedBox"]:
		var jt: Interactable = main.location.item(n)
		await tp(Vector3(jt.global_position.x + 0.8, 0, jt.global_position.z + 0.8))
		main.interact(jt)
		await wait(0.4)
	ok(Game.quest_stage("barn_junk") == 2, "хлам разобран")
	ok(Game.flag("box_open") or Game.flag("box_jammed"), "сундук: взлом попробован (%s)" % ("открыт" if Game.flag("box_open") else "заклинило"))
	main.talk_to(main.location.character("Varvara"))
	await frames(2)
	await choose(find_opt("Хлам разобрал"))
	await close_dialogs()
	ok(Game.quest_stage("barn_junk") == 3, "награда за хлам")
	# разговоры с проверками навыков
	main.talk_to(main.location.character("Elder1"))
	await frames(2)
	await choose(find_opt("Расскажи"))
	await choose(find_opt("[Убеждение]"))
	var guard2 := 0
	while main.dialog.visible and guard2 < 6:
		await choose(0)
		guard2 += 1
	ok(Game.quest_stage("elder") >= 1, "старик: убеждение (%s)" % ("рассказал" if Game.flag("elder_told") else "не уговорил"))
	for who in [["Smith", "Что у тебя", "[Наука]"], ["GuardN", "[Обман]", ""], ["Nyurguyana", "[Обольщение]", ""], ["Gambler", "[Внимательность]", ""], ["Sick", "[Медицина]", ""]]:
		main.talk_to(main.location.character(who[0]))
		await frames(2)
		await choose(find_opt(who[1]))
		if who[2] != "":
			await choose(find_opt(who[2]))
		await close_dialogs()
	ok(Game.flag("guard_lied") and (Game.flag("flirt_ok") or Game.flag("flirt_fail")) and Game.flag("gambler_caught") and Game.flag("sick_seen"), "проверки навыков в разговорах прошли")
	# жители ходят
	var walker: Character = main.location.character("Villager3")
	var wp0 := walker.global_position
	await wait(4.0)
	ok(walker.global_position.distance_to(wp0) > 1.0, "прохожий гуляет по улице")
	# стрельбище: три мишени
	var shooter: Character = main.location.character("Shooter")
	await tp(shooter.global_position + Vector3(0, 0, 1.5))
	main.talk_to(shooter)
	await frames(2)
	await choose(find_opt("Покажи"))
	await choose(find_opt("Начинаю"))
	await wait(0.6)
	ok(main.combat.on and main.combat.kind == "range", "стрельбище: бой по мишеням")
	await fight(60)
	await wait(1.5)
	ok(Game.flag("range_done") and int(Game.hero.skills.get("Дальний бой", 0)) >= 6, "урок стрельбы пройден (Дальний бой %d)" % int(Game.hero.skills.get("Дальний бой", 0)))
	await close_dialogs()
	# охотник в лесу: драка на кулаках
	var hunter: Character = main.location.character("Hunter")
	await tp(hunter.global_position + Vector3(1.5, 0, 1.5))
	main.talk_to(hunter)
	await frames(2)
	await choose(find_opt("Давай"))
	await wait(0.8)
	ok(main.combat.on and main.combat.kind == "spar", "драка с охотником началась")
	await fight(60)
	await wait(1.5)
	ok(Game.flag("hunter_done"), "охотник: проверка пройдена")
	await close_dialogs()

	# --- граница утром ---
	main.interact(main.location.item("BorderExit"))
	await frames(2)
	ok(main.dialog.visible and main.dialog.node_id == "law_border", "закон не пускает за черту")
	await close_dialogs()

	# --- волк ---
	var wolf: Character = main.location.character("Wolf")
	await tp(wolf.global_position + Vector3(-4, 0, 3))
	await wait(0.8)
	ok(main.combat.on, "пёс заметил героя — бой")
	await fight()
	ok(not main.combat.on, "бой с псом окончен")
	ok(wolf.pose == "dead" or not wolf.visible, "пёс убит или сбежал")
	await close_dialogs()

	# --- грибы ---
	var picked := 0
	for it in main.location.items():
		if it.item_id in ["mushroom", "berries"] and picked < 5:
			await tp(it.global_position + Vector3(0.9, 0, 0))
			main.interact(it)
			await wait(0.6)
			picked += 1
	ok(main.location.food_count() >= 5, "набрано еды: %d" % main.location.food_count())
	await wait(2.0)
	ok(Game.flag_value("phase") == "raid", "начался налёт")
	ok(main.dialog.visible and main.dialog.node_id == "shots", "мысли: выстрелы")
	await close_dialogs()
	await tp(Vector3(62, 0, 28))
	await wait(0.6)
	ok(Game.flag("fire_seen"), "увидел пожар")
	await close_dialogs()

	# --- первое тело: пистолет и коробочка ---
	var r1: Character = main.location.character("Raider1")
	await tp(r1.global_position + Vector3(1.2, 0, 0))
	main.loot(r1)
	await wait(0.3)
	await close_dialogs()
	ok(Game.item_count("minicomputer") == 1, "мини-компьютер найден")
	ok(main.hud._bar.visible, "нижняя панель появилась с мини-компьютером")
	ok(Game.hero.owned.has("pistol"), "пистолет найден")
	Game.hero.hands = ["pistol", "knife"]
	Game.hero.active = 0
	Game.auto_reload()
	main.player.set_held("pistol")
	print("  патроны: магазин ", Game.hero.mag.get("pistol", 0), ", запас ", Game.hero.ammo)

	# --- бой у амбара ---
	await tp(Vector3(65.5, 0, 60.0))
	await wait(0.8)
	ok(main.dialog.visible and main.dialog.node_id == "ded_seen", "увидел деда у амбара (%s, бой=%s)" % [main.dialog.node_id, main.combat.on])
	await choose(0)
	await wait(0.6)
	ok(main.combat.on, "бой у амбара начался")
	await fight(120)
	ok(not main.combat.on, "бой у амбара окончен")
	print("  ХП героя после боя у амбара: ", Game.hero_hp(), "/", Game.hero_max())
	if "fair" in OS.get_cmdline_user_args():
		print("=== ЧЕСТНЫЙ БОЙ: ", "победа" if Game.hero_hp() > 0 else "смерть", " ===")
		get_tree().quit()
		return
	ok(Game.flag("ded_shot"), "деда ранили по сюжету")
	await wait(2.0)
	ok(main.dialog.visible and main.dialog.node_id == "last", "последний разговор с дедом")
	main.dialog.close()
	for n in ["Raider2", "Raider3", "Raider4"]:
		var r: Character = main.location.character(n)
		await tp(r.global_position + Vector3(1.2, 0, 0))
		main.loot(r)
		await wait(0.3)
		await close_dialogs()
		if main.combat.on:
			await fight()
			await close_dialogs()
	ok(Game.item_count("module_carrier") == 1, "модуль носителя найден")
	main.talk_to(main.location.character("DedRaid"), "last")
	await frames(2)
	var guard := 0
	while main.dialog.visible and main.dialog.node_id != "kpk_on" and guard < 10:
		await choose(0)
		guard += 1
	ok(Game.flag("ded_dead"), "дед умер")
	ok(Game.quest_stage("pack") == 1, "задание «Собраться в дорогу»")
	ok(Game.quest_stage("bootur") == 1, "задание «Найти Боотура»")
	ok(Game.flag("kpk"), "КПК собран из браслета и коробочки")
	var mods: Dictionary = Game.hero.flags.get("modules", {})
	ok(mods.get("carrier", false) and mods.get("map", false) and mods.get("radio", false) and mods.get("inventory", false), "все модули вставлены")
	await close_dialogs()
	await frames(3)
	ok(main.kpk.visible, "КПК открылся")
	for tb in ["inv", "stat", "map", "quests", "notes"]:
		main.kpk.open(tb)
		await frames(2)
		ok(main.kpk.tab == tb, "вкладка КПК: " + tb)
	main.kpk.close()

	# --- сборы в дорогу ---
	for n in ["Take_IzbaDed_table", "Take_IzbaDed_stove", "Take_IzbaDed_bed", "Take_Izba3_chest", "Take_Izba2_table", "Take_Hall_table2"]:
		var it: Interactable = main.location.item(n)
		await tp(Vector3(it.global_position.x + 0.5, 0, it.global_position.z + 0.5))
		main.interact(it)
		await wait(2.0)
		await close_dialogs()
	ok(Game.quest_stage("pack") == 2, "собрался в дорогу (%s)" % main.location.pack_line())

	# --- сохранение и загрузка ---
	main.autosave()
	var lvl: int = Game.hero.level
	var ok_load: bool = Game.load_game("auto")
	ok(ok_load and Game.flag("kpk") and int(Game.hero.level) == lvl, "сохранение/загрузка")

	# --- навыки и человечность ---
	var old := Rules.normalize_skills({"Простое оружие": 2, "Боевое оружие": 4, "Этикет": 3, "Ловкость рук": 1})
	ok(old.get("Ближний бой") == 4 and old.get("Воровство") == 1 and not old.has("Этикет"), "старые навыки переводятся в новые")
	var hum := Game.humanity()
	Game.change_humanity(-15, "проверка")
	ok(Game.humanity() == hum - 15, "человечность меняется")
	Game.change_humanity(15)

	# --- уход ---
	main.interact(main.location.item("BorderExit"))
	await frames(2)
	ok(main.dialog.visible and main.dialog.node_id == "border_final", "финальная мысль у черты")
	await choose(0)
	await frames(2)
	ok(main.slides.visible, "финальные слайды")
	g = 0
	while main.slides.visible and g < 20:
		main.slides._next()
		main.slides._next()
		await frames(1)
		g += 1
	await frames(2)
	ok(main.menu.visible and main.menu.mode == "end_prologue", "экран «Конец пролога»")
	print("Уровень героя: ", Game.hero.level, ", опыт: ", Game.hero.xp)
	print("=== ИТОГ: ошибок ", fails, " ===")
	get_tree().quit(1 if fails else 0)
