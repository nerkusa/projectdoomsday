extends Node
## Автотест пролога: проходит всю цепочку без участия человека и печатает, что сломалось.
## Запуск: godot --headless --path . res://tools/smoke_test.tscn
## Ветки: по умолчанию — «бой» (засада бьёт сзади, бой у амбара вместе с дедом);
## -- stealth — «тень» (шорох, укрытие в кустах, ждать у амбара, пока нападавшие уйдут).

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
	Game.hero.skills["Огнестрел"] = 5
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
	# ров: через мосты можно пройти в лес и к черте, а мимо мостов — нет
	var inside_v := grid.nearest_free(Vector3(62, 0, 42))
	ok(not grid.explore_path(inside_v, grid.nearest_free(Vector3(62, 0, 14))).is_empty(), "в лес — через северный мост")
	ok(not grid.explore_path(inside_v, grid.nearest_free(Vector3(8, 0, 60))).is_empty(), "к черте — через западный мост")
	ok(not grid.is_free(grid.from_world(Vector3(40, 0, 30))), "ров непроходим")
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
	ok(main.hud.thought_visible() and not main.dialog.visible, "мысли при пробуждении — над головой")
	ok(Game.hero.owned.has("father_pistol") and not Game.hero.owned.has("oyun"), "с начала только отцовский пистолет")
	ok(not main.hud._bar.visible and not main.hud._tape.visible and main.hud._hand.visible, "до КПК: только слот «в руке»")
	main.open_kpk()
	await frames(2)
	ok(not main.kpk.visible and not main.plugging, "до КПК сумку не открыть")
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
	ok(Game.hero.owned.has("oyun"), "дед подарил нож «Ойун»")
	await choose(0)
	ok(Game.quest_stage("chores") == 1, "задание «Утро» взято")
	ok(main.hud._log.get_parsed_text().contains("Вы видите:"), "в журнале «Вы видите: …»")
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
	await wait(0.3)
	var fixed: Node3D = main.location.get_node("Village/FenceFixed")
	var gap: Node3D = main.location.get_node("Village/FenceGap")
	ok(fixed.visible and not gap.visible, "сломанный пролёт заменён целым")
	# воровство до налёта: на глазах у Степана чужое не взять, человечность −6
	var stp: Character = main.location.character("Stepan")
	await tp(stp.global_position + Vector3(1.2, 0, 0.8))
	var hum0 := Game.rep()
	var loot: Interactable = main.location.item("Take_Izba2_table")
	ok(main.location._is_theft(loot) and not main.location.can_pick(loot) and Game.rep() == hum0 - 6,
		"воровство на глазах: вещь не взята, молва %d → %d" % [hum0, Game.rep()])
	ok(not main.location._is_theft(main.location.item("Basket")), "корзину брать можно")
	Game.change_rep(hum0 - Game.rep())
	await wait(1.0)
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
	ok(not Game.flag("box_open"), "сундук без ключа и отмычки не открыть")
	ok(main.location.item_actions(main.location.item("LockedBox")).size() == 2, "у сундука два действия: ключом и взломать")
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
	for who in [["Smith", "Что у тебя", "[Знания]"], ["GuardN", "[Обман]", ""], ["Nyurguyana", "[Убеждение]", ""], ["Gambler", "[Внимательность]", ""], ["Sick", "[Медицина]", ""]]:
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
	ok(Game.flag("range_done") and int(Game.hero.skills.get("Огнестрел", 0)) >= 6, "урок стрельбы пройден (Огнестрел %d)" % int(Game.hero.skills.get("Огнестрел", 0)))
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
	ok(main.hud.thought_visible() and main.hud._thought.text.contains("Закон"), "закон не пускает за черту")

	# --- волк ---
	var wolf: Character = main.location.character("Wolf")
	await tp(wolf.global_position + Vector3(-4, 0, 3))
	await wait(0.8)
	ok(main.combat.on, "пёс заметил героя — бой")
	await fight()
	ok(not main.combat.on, "бой с псом окончен")
	ok(wolf.pose == "dead" or not wolf.visible, "пёс убит или сбежал")
	await close_dialogs()

	# --- грибы: пять находок, с третьей вечереет ---
	var stealth := "stealth" in OS.get_cmdline_user_args()
	print("  ветка: ", "тень" if stealth else "бой")
	var folk: Character = main.location.character("ForestGuard1")
	ok(folk.visible and not folk.patrol.is_empty(), "в лесу ходит дозорный")
	var foods := []
	for it in main.location.items():
		if it.item_id in ["mushroom", "berries"]:
			foods.append(it)
	ok(foods.size() == 5, "в лесу пять находок")
	for k in 4:
		await tp(foods[k].global_position + Vector3(0.9, 0, 0))
		main.interact(foods[k])
		await wait(0.8)
	ok(Game.flag("dusk") and main.location.phase() == "morning", "после третьей находки — вечер")
	ok(not main.objective_text().contains("/"), "цель без счётчика: " + main.objective_text())
	await wait(24.0)
	ok(not folk.visible, "дозорный ушёл домой")
	# Внимательность решает, как начнётся засада
	Game.hero.stats.PRC = 30 if stealth else -30
	Game.hero.skills["Внимательность"] = 5 if stealth else 0
	var hp0 := Game.hero_hp()
	await tp(foods[4].global_position + Vector3(0.9, 0, 0))
	main.interact(foods[4])
	await wait(2.0)
	ok(Game.flag_value("phase") == "raid", "начался налёт")
	var prowler: Character = main.location.character("Prowler")
	if stealth:
		await wait(3.0)
		ok(prowler.visible and main.location._prowl == "approach", "шорох: нападавший подкрадывается издалека")
		var bush: Interactable = null
		for it in main.location.items():
			if String(it.name).begins_with("HideBush") and (bush == null or it.global_position.distance_to(main.player.global_position) < bush.global_position.distance_to(main.player.global_position)):
				bush = it
		main.interact(bush)
		await frames(2)
		ok(main.hidden, "спрятался в кустах")
		var tw := 0.0
		while not Game.flag("ambush_done") and tw < 90.0 and not main.combat.on:
			await wait(0.5)
			tw += 0.5
		ok(Game.flag("ambush_done") and not main.combat.on and not prowler.visible, "нападавший поискал и ушёл")
		main.location.leave_hide()
	else:
		var ta := 0.0
		while not main.combat.on and ta < 20.0:
			await wait(0.5)
			ta += 0.5
		ok(Game.hero_hp() < hp0, "удар монтировкой сзади (ХП %d → %d)" % [hp0, Game.hero_hp()])
		ok(main.combat.on, "бой с нападавшим")
		await fight()
		ok(prowler.pose == "dead" and Game.flag("ambush_done"), "нападавший с монтировкой убит")
	Game.hero.stats.PRC = 5
	await tp(Vector3(62, 0, 26.6))
	await wait(0.6)
	ok(Game.flag("fire_seen"), "увидел пожар")
	# --- северные ворота: часовой зовёт на помощь, бой, пленные ---
	ok(not Game.flag("gate_started"), "с моста сцену у ворот ещё не видно")
	await tp(Vector3(62, 0, 31.5))
	await wait(0.5)
	ok(Game.flag("gate_started"), "часовой у ворот зовёт на помощь")
	var tg := 0.0
	while not main.combat.on and tg < 10.0:
		await wait(0.25)
		tg += 0.25
	ok(main.location.character("GateGuard").pose == "dead", "часового застрелили")
	ok(main.combat.on, "бой у ворот")
	await fight()
	var gate_ok := true
	for n in ["Executioner", "GateRaider"]:
		var e: Character = main.location.character(n)
		print("  ", n, ": ", "убит" if e.pose == "dead" else ("сбежал" if not e.visible else "жив"))
		if e.pose != "dead" and e.visible:
			gate_ok = false
	ok(gate_ok and not main.combat.on, "нападавшие у ворот побеждены или сбежали")
	await wait(1.0)
	var saved := 0
	for n in ["Doomed1", "Doomed2"]:
		if main.location.character(n).pose != "dead":
			saved += 1
	print("  пленных спасено: ", saved, " из 2")
	ok(saved == 0, "пленных расстреляли сразу, в сцене у ворот")
	var r1: Character = main.location.character("Raider1")
	await tp(r1.global_position + Vector3(1.2, 0, 0))
	main.loot(r1)
	main.loot_win.take_all()
	await wait(0.3)
	ok(not main.hud._bar.visible, "панели всё ещё нет — КПК не собран")
	Game.hero.hands = ["father_pistol", "oyun"]
	Game.hero.active = 0
	Game.auto_reload()
	main.player.set_held("father_pistol")

	# --- дед у амбара ---
	if stealth:
		Game.hero.sneak = true
		await tp(Vector3(60, 0, 66))
		await wait(0.5)
		ok(Game.flag("barn_started"), "увидел деда у амбара")
		var tb := 0.0
		while not Game.flag("cleaners_left") and tb < 40.0 and not main.combat.on:
			await wait(0.5)
			tb += 0.5
		ok(Game.flag("ded_shot"), "деда ранили")
		ok(Game.flag("cleaners_left") and not main.combat.on, "нападавшие ушли, не заметив героя")
		Game.hero.sneak = false
		main.talk_to(main.location.character("DedRaid"))
		await frames(2)
	else:
		await tp(Vector3(65.5, 0, 60.0))
		await wait(1.0)
		ok(Game.flag("barn_started") and main.combat.on, "бой у амбара начался")
		await fight(120)
		ok(not main.combat.on, "бой у амбара окончен")
		print("  ХП героя после боя у амбара: ", Game.hero_hp(), "/", Game.hero_max())
		if "fair" in OS.get_cmdline_user_args():
			print("=== ЧЕСТНЫЙ БОЙ: ", "победа" if Game.hero_hp() > 0 else "смерть", " ===")
			get_tree().quit()
			return
		ok(Game.flag("ded_shot"), "деда ранили по сюжету")
		await wait(2.0)
		ok(not main.dialog.visible, "издалека разговор с дедом не начинается")
		var dr: Character = main.location.character("DedRaid")
		await tp(dr.global_position + Vector3(1.5, 0, 0.5))
		main.location.on_hero_moved(main.player.global_position)
		await frames(3)
	ok(main.dialog.visible and main.dialog.node_id == "last", "последний разговор с дедом")
	var guard := 0
	while main.dialog.visible and main.dialog.node_id != "kpk_on" and guard < 12:
		await choose(0)
		await frames(3)
		guard += 1
	ok(Game.flag("ded_dead"), "дед умер")
	var dw: Character = main.location.character("DefenderW1")
	ok(dw.pose == "dead" and not main.location.ws().looted.has(dw.uid()), "после налёта защитники у западных ворот мертвы, их можно обыскать")
	ok(main._body_entries(dw).any(func(e): return e.id == "rifle"), "у тела защитника есть винтовка")
	ok(Game.quest_stage("bootur") == 1, "задание «Найти Боотура»")
	ok(Game.flag("kpk"), "браслет + компьютер деда = КПК")
	ok(main.dialog.visible and main.dialog.node_id == "kpk_on", "мысль: подключить кабель")
	await choose(0)
	await frames(4)
	ok(main.plugging, "анимация подключения к браслету")
	var tk := 0.0
	while not main.kpk.visible and tk < 8.0:
		await wait(0.25)
		tk += 0.25
	ok(main.kpk.visible and main.kpk.tab == "stat", "КПК открылся: «Состояние»")
	ok(main.kpk.has_tab("inv") and main.kpk.has_tab("map") and main.kpk.has_tab("stat"), "КПК сразу полный: инвентарь, «Дело», карта")
	ok(not main.hud._btns.has("sheet"), "кнопки «Дело» на панели нет — оно в КПК")
	main.kpk.close()
	ok(main.hud._bar.visible and main.hud._tape.visible, "с КПК появился полный интерфейс")
	main.open_kpk("quests")
	await frames(3)
	ok(main.plugging, "подключение каждый раз при открытии")
	tk = 0.0
	while not main.kpk.visible and tk < 4.0:
		await wait(0.25)
		tk += 0.25
	ok(main.kpk.visible, "КПК открыт повторно")
	main.kpk.close()

	# --- тела нападавших ---
	for n in ["Raider2", "Raider3", "Raider4"]:
		var r: Character = main.location.character(n)
		await tp(r.global_position + Vector3(1.2, 0, 0))
		main.loot(r)
		await wait(0.3)
		main.loot_win.take_all()
		if main.combat.on:
			await fight()
		await close_dialogs()
	var eg: Character = main.location.character("ExitRaider")
	ok(eg.visible and (eg.hostile or eg.pose == "dead"), "у черты появился раненый нападавший")
	if eg.pose != "dead":
		main.interact(main.location.item("BorderExit"))
		await frames(2)
		ok(not main.dialog.visible and main.hud.thought_visible(), "к черте не пройти, пока он жив")
		await tp(eg.global_position + Vector3(3.5, 0, 0))
		await wait(1.0)
		ok(main.combat.on, "бой с раненым у черты")
		await fight()
	else:
		print("  раненый напал сам, пока обыскивал соседнее тело")
	await close_dialogs()
	ok(eg.pose == "dead", "раненый у черты побеждён")
	await tp(eg.global_position + Vector3(1.2, 0, 0))
	main.loot(eg)
	await wait(0.4)
	main.loot_win.take_all()
	var mods: Dictionary = Game.hero.flags.get("modules", {})
	ok(mods.get("radio", false), "модуль «Связь» с раненого")
	ok(Game.flag("knows_kirk") and Game.quest_stage("who") == 2, "из модуля «Связь» герой узнаёт про Кирка")
	for tb in ["inv", "stat", "cas", "map", "quests", "notes"]:
		main.kpk.open(tb)
		await frames(2)
		ok(main.kpk.tab == tb, "вкладка КПК: " + tb)
	main.kpk.close()

	# --- кассеты ---
	ok(Game.cas_working() == clampi(1 + int(Game.hero.level), 2, 10), "рабочих слотов кассет: %d (уровень %d)" % [Game.cas_working(), Game.hero.level])
	ok(Game.item_count("cas_witness") == 1, "кассета «Свидетель» с тела нападавшего")
	var sk0 := int(Game.effective_skills().get("Скрытность", 0))
	ok(Game.cas_insert("cas_witness") and int(Game.effective_skills().get("Скрытность", 0)) == sk0 + 2 and Game.cas_has_tag("witness"), "кассета вставлена: +2 Скрытность")
	Game.hero.cassettes = ["cas_body", "cas_body", "cas_witness"]
	var lv0 := int(Game.hero.level)
	Game.hero.level = 1
	ok(not Game.cas_has_tag("witness"), "кассета в закрытом слоте не работает")
	Game.hero.level = lv0
	Game.hero.cassettes = ["cas_witness"]
	main.kpk.open("cas")
	await frames(2)
	ok(main.kpk.tab == "cas", "вкладка «Кассеты»")
	main.kpk.close()

	# --- ключ с тела Варвары, сундук в амбаре, автомат «Буран» ---
	var dv: Character = main.location.character("DeadVarvara")
	await tp(dv.global_position + Vector3(1.2, 0, 0))
	main.loot(dv)
	await wait(0.3)
	ok(main.loot_win.visible, "окно обыска открылось")
	main.loot_win.take_all()
	ok(Game.item_count("chest_key") == 1, "ключ от сундука с тела Варвары")
	var box: Interactable = main.location.item("LockedBox")
	await tp(Vector3(box.global_position.x + 0.8, 0, box.global_position.z + 0.8))
	main.interact(box)
	await wait(0.4)
	ok(Game.flag("box_open") and main.loot_win.visible, "сундук открыт ключом")
	main.loot_win.take_all()
	ok(Game.hero.owned.has("buran"), "автомат «Буран» взят из сундука")

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

	# --- навыки, характеристики и молва ---
	var old := Rules.normalize_skills({"Простое оружие": 2, "Боевое оружие": 4, "Этикет": 3, "Ловкость рук": 1})
	ok(old.get("Ближний бой") == 4 and old.get("Воровство") == 1 and not old.has("Этикет"), "старые навыки переводятся в новые")
	var hum := Game.rep()
	Game.change_rep(-15, "проверка")
	ok(Game.rep() == hum - 15, "молва меняется при свидетелях")
	Game.change_rep(-15, "тайком", false)
	ok(Game.rep() == hum - 15, "без свидетелей молва не меняется")
	Game.change_rep(-15, "большое дело", false, true)
	ok(Game.rep() == hum - 30, "большие поступки молва видит всегда")
	Game.change_rep(30)
	ok(Rules.rep_title(40) == "Эллэй-Боотур" and Rules.rep_title(0) == "Боотур" and Rules.rep_title(-40) == "Моҕус", "имя героя по молве")
	var st := Rules.normalize_stats({"DEX": 7, "REF": 4, "EMP": 6, "CRA": 3, "INT": 5})
	ok(st.REF == 7 and st.CHA == 6 and st.INT == 5 and not st.has("DEX"), "старые характеристики переводятся в новые")
	ok(Rules.ap_for({"REF": 7}, 10, 10) == 8, "ОД = 5 + ⌊Реакция/2⌋")

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
