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


func shut() -> void:
	main.dialog.close()
	await frames(2)


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
				# не вышло ударить/выстрелить — может, кончился магазин
				main.combat.reload()
				await frames(2)
				if main.combat.my_turn() and main.combat.hero_f.ap == ap_before:
					main.combat.end_turn()
		await wait(0.02)
	if main.combat.on:
		var st := []
		for e in main.combat.enemies():
			st.append("%s ХП %d гекс %s" % [e.name, e.hp, e.hex])
		print("  !! бой не закончился: герой %s, гекс %s, оружие %s, патроны %s; враги: %s" % [Game.hero_hp(), main.combat.hero_f.hex, Game.hero_wkey(), Game.hero.ammo, ", ".join(st)])


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
	ok(main.kpk.visible and not main.plugging and main.kpk.tab == "inv" and not main.kpk.has_tab("stat"), "до КПК по [I] открывается сумка (только вещи и задания)")
	main.kpk.close()
	main.hud._bag.pressed.emit()
	await frames(2)
	ok(main.kpk.visible, "кнопка «Сумка» тоже открывает")
	main.kpk.close()
	await frames(1)
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
	# характеристики ограничены 1..10 и d10 взрывается на 10 — честный бросок мог пройти;
	# исход проверки задаём прямо
	Game.force_check = 1 if stealth else -1
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
	Game.force_check = 0
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
	ok(main.location.location_id == "nakharro", "после слайдов Нахарро не перезагружается")
	var wm: WorldMap = main.world_map
	# случайные встречи проверяются отдельно ниже
	wm.encounters_on = false
	ok(wm.visible and wm.at == "nakharro", "после черты — карта мира")
	ok(wm.can_go("kresty") and not wm.can_go("camp") and not wm.can_go("sungar"), "с карты можно только в Кресты")
	ok(wm.node_pos("kresty").x > wm.node_pos("nakharro").x and wm.node_pos("sungar").x > wm.node_pos("kresty").x and wm.node_pos("camp").y > wm.node_pos("kresty").y,
		"карта сходится с дизайн-доком: путь на восток — Нахарро, Кресты, Сунгар; лагерь к югу за рекой")

	# ======== АКТ I: Кресты ========
	await wm.travel("kresty")
	await frames(3)
	ok(main.location != null and main.location.location_id == "kresty" and not wm.visible, "пришёл в Кресты")
	main.dialog.close()
	var loc = main.location
	var head: Character = loc.character("KrHead")
	await tp(head.global_position + Vector3(0, 0, 1.5))
	main.talk_to(head)
	await frames(2)
	await choose(find_opt("Боотура"))
	await choose(0)
	ok(Game.quest_stage("bootur") == 2, "след Боотура: наградили пивом, ушёл в Сунгар")
	await shut()
	main.talk_to(head)
	await frames(2)
	await choose(find_opt("помочь"))
	await choose(0)
	await frames(2)
	ok(Game.quest_stage("kr_dogs") == 1 and loc.character("Dog1").visible, "староста просит про псов — псы на выгоне")
	var dog: Character = loc.character("Dog1")
	await tp(dog.global_position + Vector3(-3, 0, 0))
	if not main.combat.on:
		main.start_fight([dog])
	await frames(2)
	await fight()
	await wait(1.0)
	var dl := []
	for dn in ["Dog1", "Dog2", "Dog3"]:
		var dd: Character = loc.character(dn)
		dl.append("%s:%s/%s/%s" % [dn, dd.pose, dd.visible, loc.ws().misc.has("gone_" + dn)])
	ok(Game.quest_stage("kr_dogs") == 2, "псы перебиты или разбежались (%s, бой %s)" % [", ".join(dl), main.combat.on])
	main.talk_to(head)
	await frames(2)
	var fur0 := Game.item_count("fur")
	var rep0 := Game.rep()
	await choose(find_opt("Псы"))
	ok(Game.quest_stage("kr_dogs") == 3 and Game.item_count("fur") == fur0 + 1 and Game.rep() > rep0, "награда старосты и молва")
	await shut()
	# бартер
	var tr: Character = loc.character("Trader")
	main.open_trade(tr)
	await frames(2)
	var tw: TradeWindow = main.trade_win
	ok(tw.visible and tw.stock().has("salt"), "окно обмена с торговкой")
	tw.offer("salt", "take")
	ok(not tw.can_exchange(), "без встречного товара обмен не идёт")
	tw.offer("fur", "give")
	var extra := 0
	while not tw.can_exchange() and extra < 10:
		tw.offer("ammo9", "give")
		extra += 1
	var salt0 := Game.item_count("salt")
	ok(tw.can_exchange() and tw.exchange() and Game.item_count("salt") == salt0 + 1 and Game.item_count("fur") == fur0, "шкурку (и патроны: %d) — на соль" % extra)
	Game.add_item("knife")
	tw.offer("knife", "take")
	ok(tw.take_value() == 0, "второй такой же нож не купить")
	Game.remove_item("knife")
	tw.offer("father_pistol", "give")
	ok(not tw.mine().has("father_pistol") and not tw.mine().has("oyun"), "отцовский пистолет и «Ойун» не меняются")
	tw.close()
	await frames(2)
	ok(not tw.stock().has("fur") or loc.ws().misc.get("trade_Trader", {}).has("fur"), "запас торговки запомнен")
	# пивовар
	main.talk_to(loc.character("Brewer"))
	await frames(2)
	await choose(find_opt("Налей"))
	ok(Game.item_count("beer") >= 1 and Game.flag("kr_beer_drunk"), "пиво у Дьулуса")
	await shut()
	# рыбак и следы
	main.talk_to(loc.character("Fisher"))
	await frames(2)
	await choose(find_opt("случилось"))
	await choose(0)
	ok(Game.quest_stage("kr_nets") == 1, "задание рыбака")
	await shut()
	var tracks = loc.item("NetTracks")
	for i in 2:
		main.dialog.close()
		loc.on_interact(tracks)
		await frames(2)
	main.dialog.close()
	ok(Game.quest_stage("kr_nets") == 2 and wm.known("camp"), "следы ведут к лагерю — точка на карте")
	main.talk_to(loc.character("Fisher"))
	await frames(2)
	await choose(find_opt("лесопилке"))
	await shut()
	ok(Game.flag("fisher_son_told"), "рыбак рассказал про сына")
	# в лагерь
	loc.on_interact(loc.item("WestExit"))
	await frames(2)
	ok(wm.visible and wm.can_go("camp"), "с карты — в лагерь")
	await wm.travel("camp")
	await frames(3)
	loc = main.location
	ok(loc.location_id == "camp", "пришёл в лагерь оборванцев")
	main.dialog.close()
	Game.add_item("rusks", 5)
	var thug: Character = loc.character("Thug")
	await tp(thug.global_position + Vector3(1.0, 0, 0))
	loc.on_hero_moved(main.player.global_position)
	await frames(2)
	ok(main.dialog.visible and main.dialog.speaker == thug and main.player.global_position.x < thug.global_position.x, "Дуолан не пускает без платы")
	await choose(find_opt("Отдать 2 еды"))
	await shut()
	ok(Game.flag("camp_passed"), "заплатил едой — пропустили")
	main.talk_to(thug)
	await frames(2)
	ok(find_opt("Отдать 2 еды") < 0 and find_opt("возьми") < 0, "после прохода Дуолан плату не просит")
	await shut()
	var boss: Character = loc.character("Boss")
	await tp(boss.global_position + Vector3(1.2, 0, 0))
	main.talk_to(boss)
	await frames(2)
	await choose(find_opt("Нахарро"))
	await choose(0)
	await choose(0)
	await choose(0)
	ok(Game.quest_stage("who") == 3, "вожак видел тех же солдат и знак")
	await choose(0)
	ok(Game.flag("camp_boss_guide"), "про «проводника» в пальто")
	await shut()
	var ny: Character = loc.character("Nyurgun")
	main.talk_to(ny)
	await frames(2)
	await choose(find_opt("сети"))
	await choose(0)
	ok(Game.quest_stage("kr_nets") == 3, "рыбу таскает Нюргун, сын рыбака")
	await shut()
	main.talk_to(ny)
	await frames(2)
	await choose(find_opt("Передать"))
	await shut()
	ok(Game.quest_stage("kr_nets") == 5 and Game.item_count("camp_letter") == 1, "записка от Нюргуна")
	Game.add_item("medkit")
	main.talk_to(loc.character("Wounded"))
	await frames(2)
	await choose(find_opt("аптечку"))
	await shut()
	ok(Game.quest_stage("camp_wounded") == 2, "Туйаара спасена")
	# кашель в лагере
	main.dialog.close()
	main.talk_to(loc.character("Wounded"))
	await frames(2)
	await choose(find_opt("стряслось"))
	await choose(0)
	ok(Game.quest_stage("camp_cough") == 1, "в лагере кашляют дети — нужны травы")
	await shut()
	Game.add_item("herbs", 3)
	main.talk_to(loc.character("Wounded"))
	await frames(2)
	await choose(find_opt("3 пучка"))
	ok(Game.quest_stage("camp_cough") == 2, "травы отданы — детям легче")
	await shut()
	# реванш Дуолана на кулаках
	main.talk_to(loc.character("Thug"))
	await frames(2)
	await choose(find_opt("Чего смотришь"))
	await choose(find_opt("Давай"))
	await frames(3)
	ok(main.combat.on and main.combat.kind == "spar", "реванш: драка на кулаках")
	await fight(300)
	await wait(1.5)
	ok(main.dialog.visible and main.dialog.node_id in ["rematch_won", "rematch_lost"], "Дуолан после драки: " + main.dialog.node_id)
	await choose(0)
	await shut()
	ok(Game.quest_stage("rematch") == 2, "реванш состоялся")
	main.open_trade(loc.character("CampTrader"))
	await frames(2)
	ok(main.trade_win.stock().has("cas_reflex"), "у менялы — кассета")
	main.trade_win.close()
	# назад в Кресты — записку рыбаку
	loc.on_interact(loc.item("WestExit"))
	await frames(2)
	await wm.travel("kresty")
	await frames(3)
	loc = main.location
	main.dialog.close()
	main.talk_to(loc.character("Fisher"))
	await frames(2)
	await choose(find_opt("записку"))
	await choose(0)
	await shut()
	ok(Game.quest_stage("kr_nets") == 6 and Game.item_count("camp_letter") == 0, "записка отдана рыбаку")
	# --- описания: живое к телу не подставляется ---
	var dead_dog: Character = loc.character("Dog1")
	ok("Мёртв" in main._look_text(dead_dog), "мёртвый пёс описан мёртвым: " + main._look_text(dead_dog))

	# ======== случайная встреча в пути ========
	loc.on_interact(loc.item("EastExit"))
	await frames(2)
	var wpos := wm.pos
	ok(wm.visible and wm._can_back(), "карта открыта из Крестов — можно вернуться")
	wm._go_to(wm.pos + Vector2(60, -30))
	await wait(0.6)
	ok(wm.pos.distance_to(wpos) > 10.0 and wm.hours() > 0.0, "герой идёт по карте сам, время идёт (%s)" % wm.time_text())
	wm.halt()
	ok(not wm._can_back(), "ушёл с места — назад в локацию уже нельзя")
	wm.start_road_event("dogs")
	await frames(2)
	ok(main.dialog.visible and main.dialog.node_id == "dogs", "встреча в пути: псы")
	await choose(find_opt("Ударить первым"))
	while main._loading or wm._entering:
		await frames(2)
	await frames(3)
	loc = main.location
	ok(loc.location_id == "encounter" and loc.characters().size() == 3, "поляна встречи: три пса")
	var ed: Character = loc.characters()[0]
	await tp(ed.global_position + Vector3(-3, 0, 0))
	if not main.combat.on:
		main.start_fight([ed])
	await frames(2)
	await fight()
	await wait(1.0)
	ok(loc.squad_cleared("enc"), "псы перебиты")
	var mpos: Vector2 = wm.pos
	loc.on_interact(loc.item("WestExit"))
	await frames(2)
	ok(wm.visible and wm.at == "" and wm.pos.distance_to(mpos) < 1.0, "с поляны — обратно на карту, туда же, где был")
	# мирная встреча — торговец
	wm.start_road_event("trader")
	await frames(2)
	await choose(find_opt("Подойти"))
	while main._loading or wm._entering:
		await frames(2)
	await frames(3)
	loc = main.location
	var rt: Character = loc.characters()[0]
	ok(loc.location_id == "encounter" and rt.char_id == "road_trader" and not rt.hostile, "торговец у костра")
	main.talk_to(rt)
	await frames(2)
	await choose(find_opt("Боотура"))
	ok(Game.hero.notes.size() > 0 and "Счастливой лодке" in str(Game.hero.notes), "торговец рассказал про Боотура в Сунгаре")
	await shut()
	loc.on_interact(loc.item("EastExit"))
	await frames(2)

	# ======== генератор местности: все четыре вида ========
	for bio in ["field", "forest", "swamp", "dead"]:
		Game.hero.flags["enc"] = "refugees"
		Game.hero.flags["enc_mode"] = "peace"
		Game.hero.flags["enc_biome"] = bio
		wm.visible = false
		await main.load_location("encounter", "Start")
		await frames(2)
		loc = main.location
		var free_n := 0
		for hx in loc.grid.free:
			if loc.grid.free[hx]:
				free_n += 1
		ok(loc.biome == bio and free_n > 900 and free_n < loc.grid.free.size() and loc.grid.is_free(loc.grid.from_world(main.player.global_position)), "местность «%s»: проходимых гексов %d, герой в центре на свободном" % [bio, free_n])
	# ======== нападение: засада сразу ========
	Game.force_check = -1
	wm.open("encounter")
	Game.set_flag("visited_kresty")
	wm.encounters_on = true
	var old_ch: float = wm.data["encounter_chance"]
	wm.data["encounter_chance"] = 1.0
	var tries := 0
	while tries < 30:
		tries += 1
		var eid := wm.pick_encounter()
		if not wm.data["encounters"][eid].get("enemies", []).is_empty():
			# прогоняем ту же развилку, что и в пути
			Game.hero.flags["road_seen"] = []
			wm._roll_encounter_with(eid)
			break
	while main._loading or wm._entering:
		await frames(2)
	await frames(3)
	loc = main.location
	ok(loc.location_id == "encounter" and main.combat.on and main.combat.order[0] != main.combat.hero_f, "не заметил — засада: бой сразу, враги ходят первыми")
	await fight(300)
	await wait(1.0)
	Game.force_check = 1
	wm.data["encounter_chance"] = old_ch
	wm.encounters_on = false
	loc.on_interact(loc.item("NorthExit"))
	await frames(2)
	# ======== заметил первым: подкрасться ========
	wm.start_road_event("looters")
	await frames(2)
	ok(main.dialog.visible and find_opt("Подкрасться") >= 0 and find_opt("Залечь") >= 0 and find_opt("Ударить первым") >= 0, "заметил первым: ударить / подкрасться / залечь / обойти")
	await choose(find_opt("Подкрасться"))
	await choose(find_opt("[Подкрасться]"))
	while main._loading or wm._entering:
		await frames(2)
	await frames(4)
	loc = main.location
	ok(main.hidden and not main.combat.on and loc.foes().size() == 3, "подкрался: сидит в кустах, бандиты у костра не видят")
	loc.leave_hide()
	main.start_fight([loc.foes()[0]], {"ambush": true})
	await frames(2)
	ok(main.combat.on and main.combat.order[0] == main.combat.hero_f, "из кустов — первый удар")
	await fight(300)
	await wait(1.0)
	loc.on_interact(loc.item("SouthExit"))
	await frames(2)
	# залечь и переждать
	wm.start_road_event("wolves")
	await frames(2)
	await choose(find_opt("Залечь"))
	ok(main.dialog.node_id == "wolves_hide" and find_opt("Идти дальше") >= 0, "залёг — прошли мимо")
	await choose(find_opt("Идти дальше"))
	Game.force_check = 0

	# ======== суд йегерей: исходы ========
	Game.force_check = 1
	if not wm.visible:
		wm.open("encounter")
	wm.start_road_event("trial")
	await frames(2)
	await choose(find_opt("Подойти"))
	while main._loading or wm._entering:
		await frames(2)
	await frames(3)
	loc = main.location
	var acc: Character = null
	var jg: Character = null
	for c in loc.characters():
		if c.char_id == "accused":
			acc = c
		elif c.char_id == "jaeger":
			jg = c
	ok(acc != null and acc.pose == "yield" and jg != null, "суд: подсудимый на коленях, йегеря рядом")
	main.talk_to(acc)
	await frames(2)
	await choose(0)
	ok(Game.flag("trial_truth"), "подсудимый рассказал про долг «Горизонту»")
	main.talk_to(jg)
	await frames(2)
	var rep_t := Game.rep()
	await choose(find_opt("Убеждение +"))
	ok(Game.flag("trial_spared") and Game.rep() > rep_t, "уговорил йегерей пощадить вора (молва растёт)")
	await shut()
	loc.on_interact(loc.item("WestExit"))
	await frames(2)
	# мальчишка в лесу → Кресты
	wm.start_road_event("lost_kid")
	await frames(2)
	await choose(find_opt("Подойти"))
	while main._loading or wm._entering:
		await frames(2)
	await frames(3)
	loc = main.location
	main.talk_to(loc.characters()[0])
	await frames(2)
	await choose(find_opt("отведу"))
	ok(Game.quest_stage("lost_kid") == 1, "мальчишку отправил домой")
	await shut()
	# дезертир
	Game.set_quest("who", maxi(2, Game.quest_stage("who")))
	loc.on_interact(loc.item("WestExit"))
	await frames(2)
	Game.add_item("bandage")
	wm.start_road_event("deserter")
	await frames(2)
	await choose(find_opt("Подойти"))
	while main._loading or wm._entering:
		await frames(2)
	await frames(3)
	loc = main.location
	var des: Character = loc.characters()[0]
	ok(des.pose == "down", "раненый наёмник лежит")
	main.talk_to(des)
	await frames(2)
	await choose(find_opt("Отдать бинт"))
	await choose(0)
	ok(Game.flag("des_talked") and "списку Б" in str(Game.hero.notes), "дезертир рассказал про «список Б» и проводника")
	await shut()
	Game.force_check = 0
	loc.on_interact(loc.item("WestExit"))
	await frames(2)

	# ======== заимка: капканы и чучуна ========
	WorldMap.reveal("zaimka")
	await wm.travel("zaimka")
	await frames(3)
	loc = main.location
	ok(loc.location_id == "zaimka", "пришёл на заимку")
	main.dialog.close()
	var hermit: Character = loc.character("Hermit")
	ok(not loc.character("Chuchuna").visible, "чучуны не видно, пока не попросили")
	main.talk_to(hermit)
	await frames(2)
	await choose(find_opt("чучуну"))
	await shut()
	main.talk_to(hermit)
	await frames(2)
	await choose(find_opt("помощь"))
	await choose(0)
	ok(Game.quest_stage("traps") == 1, "Дьаакып просит проверить капканы")
	await shut()
	await tp(loc.item("Trap2").global_position + Vector3(-1.5, 0, 0))
	loc.on_interact(loc.item("Trap2"))
	await frames(2)
	ok(main.dialog.visible and loc.character("Chuchuna").visible, "у второго капкана — чучуна")
	await shut()
	await frames(3)
	await fight(300)
	await wait(1.5)
	main.dialog.close()
	ok(Game.quest_stage("traps") == 2, "чучуна мёртв (бой идёт: %s)" % main.combat.on)
	main.loot_win.close()
	main.loot(loc.character("Chuchuna"))
	await frames(3)
	main.loot_win.take_all()
	await frames(2)
	if Game.item_count("robe_scrap") == 0:
		Game.add_item("robe_scrap")
	main.talk_to(hermit)
	await frames(2)
	await choose(find_opt("робы"))
	ok(Game.quest_stage("traps") == 3 and Game.item_count("cas_tongue") >= 1, "Дьаакып узнал номер на робе, дал кассету")
	await shut()
	# дикий хмель для Дьулуса
	Game.set_quest("hops", 1)
	for hn in ["Take_Hops1", "Take_Hops2", "Take_Hops3"]:
		var hop: Interactable = loc.item(hn)
		await tp(hop.global_position + Vector3(0.8, 0, 0))
		main.interact(hop)
		await wait(1.0)
	ok(Game.item_count("hops") >= 3 and Game.quest_stage("hops") == 2, "хмель собран (%d)" % Game.item_count("hops"))

	# ======== ржавый конвой ========
	loc.on_interact(loc.item("WestExit"))
	await frames(2)
	WorldMap.reveal("convoy")
	Game.set_quest("caravan", 1)
	await wm.travel("convoy")
	await frames(3)
	loc = main.location
	ok(loc.location_id == "convoy", "ржавый конвой")
	main.dialog.close()
	var amb: Character = loc.character("Ambusher1")
	await tp(amb.global_position + Vector3(-3, 0, 0))
	if not main.combat.on:
		main.start_fight([amb])
	await frames(2)
	await fight()
	await wait(1.0)
	ok(loc.squad_cleared("ambush"), "засада у грузовиков перебита")
	var drv: Character = loc.character("Driver")
	await tp(drv.global_position + Vector3(-1.2, 0, 0))
	main.loot(drv)
	await frames(3)
	main.loot_win.take_all()
	await frames(2)
	ok(Game.item_count("waybill") == 1 and Game.quest_stage("caravan") == 2, "накладная у возчика")
	main.dialog.close()
	Game.set_flag("convoy_safe_try")
	loc.on_interact(loc.item("CabSafe"))
	await frames(2)
	main.loot_win.take_all()
	ok(Game.item_count("cas_surgeon") >= 1, "ящик в кабине: кассета «Хирург»")

	# ======== база на Сытыгане ========
	loc.on_interact(loc.item("WestExit"))
	await frames(2)
	WorldMap.reveal("ruin")
	await wm.travel("ruin")
	await frames(3)
	loc = main.location
	ok(loc.location_id == "ruin", "база на Сытыгане")
	main.dialog.close()
	var dg: Character = loc.character("Digger1")
	await tp(dg.global_position + Vector3(-3, 0, 0))
	if not main.combat.on:
		main.start_fight([dg])
	await frames(2)
	await fight(300)
	await wait(1.0)
	if not loc.squad_cleared("diggers") and not main.combat.on:
		# кто-то остался стоять в стороне — добиваем вторым боем
		for dn in ["Digger1", "Digger2", "Digger3"]:
			var dd: Character = loc.character(dn)
			print("  ", dn, ": ", dd.pose, " видим=", dd.visible, " бежал=", loc.ws().misc.has("gone_" + dn))
	ok(loc.squad_cleared("diggers"), "копатели перебиты")
	main.dialog.close()
	loc.on_interact(loc.item("WallMap"))
	await frames(2)
	ok(Game.quest_stage("who") == 4 and wm.known("markun"), "карта на стене: Нахарро в списке, следующий — Мар-Кун")
	await shut()
	Game.set_flag("ruin_terminal_try")
	loc.on_interact(loc.item("Terminal"))
	await frames(2)
	ok(Game.flag("ruin_terminal"), "терминал: «Уволить сотрудника?»")
	await shut()
	# назад в Кресты — накладную торговке
	loc.on_interact(loc.item("WestExit"))
	await frames(2)
	await wm.travel("kresty")
	await frames(3)
	loc = main.location
	main.dialog.close()
	main.talk_to(loc.character("Trader"))
	await frames(2)
	await choose(find_opt("накладную"))
	ok(Game.quest_stage("caravan") == 3, "Аграфена узнала про караван")
	await shut()
	# долг Сэмэна: заплатить самому
	main.talk_to(loc.character("Trader"))
	await frames(2)
	await choose(find_opt("помочь"))
	await choose(0)
	ok(Game.quest_stage("debt") == 1, "Аграфена просит стребовать долг Сэмэна")
	await shut()
	Game.add_item("salt")
	main.talk_to(loc.character("Trader"))
	await frames(2)
	await choose(find_opt("Отдать свою соль"))
	ok(Game.quest_stage("debt") == 3, "заплатил долг за Сэмэна сам")
	await shut()
	# хмель — Дьулусу: он вспоминает про Нью-Рбу
	main.talk_to(loc.character("Brewer"))
	await frames(2)
	await choose(find_opt("Отдать хмель"))
	ok(Game.quest_stage("hops") == 3 and "Нью-Рбе" in str(Game.hero.notes), "Дьулус: Боотур говорил про Нью-Рбу")
	await shut()
	# мальчишка дома
	main.talk_to(loc.character("KrVillager1"))
	await frames(2)
	await choose(find_opt("Мичээр"))
	ok(Game.quest_stage("lost_kid") == 2, "Кресты встречают мальчишку")
	await shut()

	# сохранение и загрузка в новой локации
	main.autosave()
	ok(Game.load_game("auto") and str(Game.hero.location) == "kresty", "сохранение в Крестах")
	# Сунгар — конец сборки
	loc.on_interact(loc.item("EastExit"))
	await frames(2)
	ok(wm.can_go("sungar"), "в Сунгар можно, когда известно про Боотура")
	await wm.travel("sungar")
	await frames(3)
	ok(main.menu.visible and main.menu.mode == "end_act1", "экран «Дорога на Сунгар»")
	print("Уровень героя: ", Game.hero.level, ", опыт: ", Game.hero.xp)
	print("=== ИТОГ: ошибок ", fails, " ===")
	get_tree().quit(1 if fails else 0)
