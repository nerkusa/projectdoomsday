extends Location
## Пролог: деревня Нахарро.
## Фазы (флаг "phase"): morning — утро и обучение, raid — деревня горит, after — после смерти деда.
## Узлы с группой phase_morning видны только утром, phase_raid — во время и после налёта.

const NEED_FOOD := 5
## Где кончается северный лес: выйдя из него во время налёта, герой видит пожар
const FOREST_EDGE_Z := 26.0

var _kpk_busy := false
var _volley_t := 2.0


func _ready() -> void:
	location_id = "nakharro"
	title = "Нахарро"
	Game.hero_changed.connect(_on_hero_changed)


func _exit_tree() -> void:
	if Game.hero_changed.is_connected(_on_hero_changed):
		Game.hero_changed.disconnect(_on_hero_changed)


func phase() -> String:
	return str(Game.flag_value("phase", "morning"))


func on_new_game() -> void:
	Game.set_flag("phase", "morning")
	_apply_phase()
	await get_tree().create_timer(0.6).timeout
	main.say("thoughts", "wake")


func on_world_state_applied() -> void:
	_apply_phase()


func on_enter() -> void:
	_apply_phase()


func _apply_phase() -> void:
	var raid := phase() != "morning"
	for n in get_tree().get_nodes_in_group("phase_morning"):
		_set_on(n, not raid)
	for n in get_tree().get_nodes_in_group("phase_raid"):
		_set_on(n, raid)
	var env := get_node_or_null("Env/WorldEnvironment") as WorldEnvironment
	var sun := get_node_or_null("Env/Sun") as DirectionalLight3D
	if env and env.environment:
		env.environment.fog_light_color = Color("7a5a3c") if raid else Color("b3a07c")
		env.environment.fog_density = 0.01 if raid else 0.004
		env.environment.adjustment_saturation = 0.75 if raid else 0.95
	if sun:
		sun.light_energy = 0.7 if raid else 1.05
		sun.light_color = Color("ffb27a") if raid else Color("fff1d6")
	var ded := character("DedRaid")
	if ded and Game.flag("ded_dead"):
		ded.pose = "dead"
	elif ded and Game.flag("ded_shot"):
		ded.pose = "down"


func _set_on(n: Node, on: bool) -> void:
	if n is Character:
		var ch := n as Character
		if ws().misc.has("gone_" + ch.uid()):
			on = false
		ch.visible = on
		ch.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED
	elif n is Interactable:
		(n as Interactable).set_active(on and not ws().picked.has((n as Interactable).uid()))
	elif n is Node3D:
		(n as Node3D).visible = on


func status_line() -> String:
	return "2062 · конец лета" if phase() == "morning" else "2062 · пожар"


func food_count() -> int:
	return Game.item_count("mushroom") + Game.item_count("berries") + int(Game.flag_value("food_given", 0))


func objective() -> String:
	var ph := phase()
	if ph == "morning":
		if Game.quest_stage("chores") == 0:
			return "Найти деда — он у своей избы."
		if Game.quest_stage("chores") == 1:
			return "%s Степан: принести доски от поленницы\n%s Варвара: отнести корзину из избы деда в амбар" % [
				"[x]" if Game.flag("fence_done") else "[ ]", "[x]" if Game.flag("basket_done") else "[ ]"]
		if Game.quest_stage("chores") == 2:
			return "Вернуться к деду."
		if Game.quest_stage("forest") == 1:
			return "Грибы и ягоды: %d/%d — лес к северу, за полем." % [mini(food_count(), NEED_FOOD), NEED_FOOD]
		return ""
	if not Game.flag("ded_dead"):
		if Game.quest_stage("fire") <= 1:
			return "Нахарро горит. Найти деда."
		return "Помочь деду у амбара!"
	var pack := pack_line()
	if not Game.flag("kpk"):
		var need := []
		if Game.item_count("minicomputer") <= 0:
			need.append("коробочку с экраном")
		return "Обыскать тела нападавших%s. Потом — на запад, к старой черте.%s" % [(": найти " + ", ".join(need)) if not need.is_empty() else "", pack]
	return "Идти на запад по старой просеке, к старой черте." + pack


# ---------------- сборы в дорогу ----------------
## Что нужно взять за черту: категория -> подпись. Еды — FOOD_NEED порций.
const PACK := {"water": "вода", "fire": "спички", "sleep": "одеяло", "rope": "верёвка"}
const FOOD_NEED := 2


func food_portions() -> int:
	var n := 0
	for k in DB.items:
		if DB.items[k] is Dictionary and DB.items[k].get("travel", "") == "food":
			n += Game.item_count(k)
	return n


func has_travel(cat: String) -> bool:
	for k in DB.items:
		if DB.items[k] is Dictionary and DB.items[k].get("travel", "") == cat and Game.item_count(k) > 0:
			return true
	return false


func pack_ready() -> bool:
	for c in PACK:
		if not has_travel(c):
			return false
	return food_portions() >= FOOD_NEED


## Строка для цели на экране, пока задание «Собраться в дорогу» не выполнено
func pack_line() -> String:
	if Game.quest_stage("pack") != 1:
		return ""
	var parts := []
	for c in PACK:
		parts.append("%s %s" % ["[x]" if has_travel(c) else "[ ]", PACK[c]])
	parts.append("%s еда %d/%d" % ["[x]" if food_portions() >= FOOD_NEED else "[ ]", mini(food_portions(), FOOD_NEED), FOOD_NEED])
	return "\nВ дорогу: " + " · ".join(parts)


func _check_pack() -> void:
	if Game.quest_stage("pack") == 1 and pack_ready():
		Game.set_quest("pack", 2)
		Game.add_note("Собрался в дорогу: вода, огонь, одеяло, верёвка, еда. Дед бы одобрил — «в тайгу без спичек не ходят».")


# ---------------- перестрелка у ворот ----------------
## Пока «чистильщики» у амбара живы, защитники у ворот отстреливаются
## от остатков нападавших в лесу: вспышки и выстрелы то тут, то там.
func _process(delta: float) -> void:
	if main == null or phase() != "raid" or Game.flag("ded_shot") or main.combat.on:
		return
	_volley_t -= delta
	if _volley_t > 0.0:
		return
	_volley_t = randf_range(0.8, 2.6)
	var shooters := []
	for n in get_tree().get_nodes_in_group("defenders"):
		var ch := n as Character
		if ch and ch.visible and ch.pose == "" and not ch.moving:
			ch.aim_pose = true
			shooters.append(ch)
	if shooters.is_empty():
		return
	var ch: Character = shooters.pick_random()
	ch.act("fire", Callable(), {"n": randi_range(1, 2)})


# ---------------- события ----------------
func on_hero_moved(pos: Vector3) -> void:
	if phase() == "raid" and not Game.flag("fire_seen") and pos.z > FOREST_EDGE_Z:
		Game.set_flag("fire_seen")
		Game.set_quest("forest", 3)
		Game.set_quest("fire", 1)
		main.player.stop()
		main.say("thoughts", "fire")
		main.hud.refresh_objective()
	if phase() == "raid" and Game.flag("fire_seen") and not Game.flag("strangers_seen"):
		for ch in characters():
			if ch.visible and ch.start_dead and ch.char_id.begins_with("raider_dead") and ch.global_position.distance_to(pos) < 4.0:
				Game.set_flag("strangers_seen")
				main.player.stop()
				main.say("thoughts", "strangers")
				break


func can_pick(it: Interactable) -> bool:
	if it.item_id in ["mushroom", "berries"] and Game.quest_stage("forest") != 1:
		main.hud.flash_tip("Дед ещё не посылал за грибами")
		return false
	return true


func on_picked(it: Interactable) -> void:
	if it.item_id in ["mushroom", "berries"]:
		main.hud.refresh_objective()
		if phase() == "morning" and food_count() >= NEED_FOOD:
			_start_raid()
	else:
		_check_pack()
		main.hud.refresh_objective()


func _start_raid() -> void:
	await get_tree().create_timer(1.2, false).timeout
	Game.set_flag("phase", "raid")
	Game.set_quest("forest", 2)
	_apply_phase()
	main.hud.refresh_objective()
	main.player.stop()
	main.say("thoughts", "shots")
	main.autosave()


func on_looted(ch: Character) -> void:
	if ch.char_id == "raider_dead_1" and not Game.flag("minicomp_seen"):
		Game.set_flag("minicomp_seen")
		main.say("thoughts", "minicomp")
	main.hud.refresh_objective()


func on_noticed(ch: Character) -> bool:
	if ch.squad == "cleaners" and not Game.flag("barn_started"):
		Game.set_flag("barn_started")
		main.say("thoughts", "ded_seen")
		return true
	return false


func on_interact(it: Interactable) -> bool:
	if it.name == "BorderExit":
		if phase() == "morning":
			main.say("thoughts", "law_border")
		elif not Game.flag("ded_dead"):
			main.say("thoughts", "not_yet")
		else:
			main.say("thoughts", "border_final")
		return true
	return false


func on_dialog_action(a: String, _sp: Character) -> bool:
	match a:
		"barn_fight":
			Game.set_quest("fire", 2)
			var foes := []
			for ch in characters():
				if ch.squad == "cleaners" and ch.visible and ch.pose != "dead":
					foes.append(ch)
			main.dialog.close()
			main.start_fight(foes)
			return true
		"ded_dies":
			var ded := character("DedRaid")
			if ded:
				ded.pose = "dead"
				ws().dead[ded.uid()] = true
				ws().looted[ded.uid()] = true
			Game.set_flag("ded_dead")
			Game.set_flag("phase", "after")
			Game.set_quest("bootur", 1)
			Game.set_quest("who", 1)
			Game.set_quest("pack", 1)
			_check_pack()
			Game.log_line("Дед Уйбаан умер.", "", "miss")
			main.hud.refresh_objective()
			_check_kpk()
			main.autosave()
			return true
		"open_kpk":
			main.open_kpk.call_deferred("stat")
			return true
		"leave_village":
			main.dialog.close()
			main.slides.finished.connect(func(): main.show_end("end_prologue"), CONNECT_ONE_SHOT)
			main.slides.play(DB.intro.get("outro", []))
			return true
	return false


func on_combat_round(r: int) -> void:
	if r >= 2 and _fighting_cleaners() and not Game.flag("ded_shot"):
		var shooter := _alive_cleaner()
		if shooter:
			_shoot_ded(shooter)


func on_fighter_down(f: Fighter) -> void:
	if f.node.squad == "cleaners" and not Game.flag("ded_shot"):
		var shooter := _alive_cleaner()
		_shoot_ded(shooter if shooter else f.node, shooter == null)


func on_combat_end(res: String, _kind: String) -> void:
	if res != "win" or Game.flag("ded_dead") or not Game.flag("barn_started"):
		return
	if _alive_cleaner() != null:
		return
	if not Game.flag("ded_shot"):
		Game.set_flag("ded_shot")
		character("DedRaid").pose = "down"
	Game.set_quest("fire", 3)
	await get_tree().create_timer(0.8, false).timeout
	var ded := character("DedRaid")
	main.player.face_towards(ded.global_position)
	main.talk_to(ded, "last")


func _fighting_cleaners() -> bool:
	if not main.combat.on:
		return false
	for u in main.combat.units:
		if not u.is_hero and u.node.squad == "cleaners":
			return true
	return false


func _alive_cleaner() -> Character:
	for ch in characters():
		if ch.squad == "cleaners" and ch.visible and ch.pose != "dead" and (ch.fighter == null or ch.fighter.active()):
			return ch
	return null


func _shoot_ded(shooter: Character, dying := false) -> void:
	Game.set_flag("ded_shot")
	var ded := character("DedRaid")
	if ded == null:
		return
	shooter.face_towards(ded.global_position)
	Game.log_line(("Падая, %s успевает ударить деда!" if dying else "%s бьёт по деду!") % shooter.display_name, "", "hit")
	var hit := func():
		ded.pose = "down"
		main.hud.float_text(ded.global_position + Vector3(0, 1.6, 0), "Дед!", "hit")
	if DB.is_gun(shooter.fighter.wkey if shooter.fighter else ""):
		shooter.act("fire", Callable(), {"n": 1, "per_shot": func(_i): hit.call()})
	else:
		shooter.act("swing", hit)


# ---------------- КПК из браслета и коробочки ----------------
func _on_hero_changed() -> void:
	if _kpk_busy or main == null:
		return
	if phase() == "morning" and Game.quest_stage("chores") == 1 and Game.flag("fence_done") and Game.flag("basket_done"):
		Game.set_quest("chores", 2)
		main.hud.refresh_objective()
	_check_kpk()


func _check_kpk() -> void:
	_kpk_busy = true
	if not Game.flag("kpk") and Game.item_count("bracelet") > 0 and Game.item_count("minicomputer") > 0:
		Game.remove_item("bracelet")
		Game.remove_item("minicomputer")
		Game.set_flag("kpk")
		_absorb_modules()
		if main.dialog.visible:
			main.dialog.closed.connect(func(): main.say("thoughts", "kpk_on"), CONNECT_ONE_SHOT)
		else:
			main.say("thoughts", "kpk_on")
		main.hud.refresh()
		main.hud.refresh_objective()
	elif Game.flag("kpk"):
		_absorb_modules()
	_kpk_busy = false


func _absorb_modules() -> void:
	var mods: Dictionary = Game.hero.flags.get("modules", {})
	var names := {"module_carrier": "carrier", "module_inventory": "inventory", "module_map": "map", "module_radio": "radio"}
	var changed := false
	for k in names:
		if Game.item_count(k) > 0:
			Game.remove_item(k)
			mods[names[k]] = true
			changed = true
			Game.log_line("Модуль вставлен: %s" % DB.item_name(k), "", "hit")
			if k == "module_radio":
				Game.add_note("Обрывок переговоров (модуль «Связь»): «…проводник сказал, их там человек сорок. Старшего взять живым, остальных — по списку. Всё довоенное — в контейнер…»")
	if changed:
		Game.hero.flags["modules"] = mods
		Game.hero_changed.emit()
