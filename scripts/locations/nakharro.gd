extends Location
## Пролог: деревня Нахарро.
## Фазы (флаг "phase"): morning — день и обучение (к вечеру темнеет), raid — налёт,
## after — после смерти деда.
## Узлы с группой phase_morning видны только днём, phase_raid — во время и после налёта.
##
## Ход пролога: дела по деревне → дед посылает в лес → пять находок (без счётчика;
## с третьей темнеет, лесные жители уходят домой) → последняя находка: выстрелы в деревне
## и засада нападавшего с монтировкой (проверка Внимательности: удар сзади или шорох и
## укрытие в кустах) → казнь на улице → дед у амбара (бой вместе с ним или ждать в тени)
## → дед отдаёт браслет и компьютер → модули на телах → раненый у черты → черта.

const NEED_FOOD := 5
## С какой находки вечереет и лесные жители уходят домой
const DUSK_AT := 3
## Где кончается северный лес: выйдя из него во время налёта, герой видит пожар
const FOREST_EDGE_Z := 26.0
## Где стоит дед во время налёта и откуда видна казнь
const BARN_SCENE_R := 20.0
const EXEC_SCENE_R := 17.0

var _kpk_busy := false
var _volley_t := 2.0
var _shot_t := 1.0
## Засада в лесу: "" | approach | search | leave
var _prowl := ""
var _prowl_t := 0.0
var _prowl_pts: Array = []
var _barn_t := -1.0
var _ded_round := -1


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
	_apply_light()
	# лесные жители, ушедшие домой к вечеру
	if Game.flag("dusk"):
		for n in get_tree().get_nodes_in_group("forest_folk"):
			_set_on(n, false)
	var ded := character("DedRaid")
	if ded and Game.flag("ded_dead"):
		ded.pose = "dead"
	elif ded and Game.flag("ded_shot"):
		ded.pose = "down"
	elif ded and raid:
		ded.aim_pose = true
	if ded:
		# пока дед отстреливается, с ним не поговорить
		ded.dialog = "ded" if Game.flag("ded_shot") else ""
	# засада: нападавший с монтировкой
	var pr := character("Prowler")
	if pr:
		var on: bool = Game.flag("ambush_on") and not Game.flag("ambush_done") and not ws().dead.has(pr.uid())
		pr.visible = on or ws().dead.has(pr.uid())
		pr.process_mode = Node.PROCESS_MODE_INHERIT if pr.visible else Node.PROCESS_MODE_DISABLED
		if on and _prowl == "":
			# после загрузки — просто враг, который ищет героя
			pr.hostile = true
			pr.aggro_radius = 7.0
			pr.set_held("crowbar")
	# после казни — тела на улице
	if Game.flag("exec_done"):
		for n in ["Doomed1", "Doomed2"]:
			var v := character(n)
			if v:
				v.pose = "dead"
	# ушедшие «чистильщики»
	if Game.flag("cleaners_left"):
		for ch in characters():
			if ch.squad == "cleaners" and ch.pose != "dead":
				ch.visible = false
				ch.process_mode = Node.PROCESS_MODE_DISABLED
	_update_exit_guard()


## Свет: день, к вечеру (после DUSK_AT находок) — низкое тёплое солнце, во время налёта — зарево
func _apply_light() -> void:
	var env := get_node_or_null("Env/WorldEnvironment") as WorldEnvironment
	var sun := get_node_or_null("Env/Sun") as DirectionalLight3D
	var k := 0.0
	if phase() != "morning":
		k = 1.0
	elif Game.flag("dusk"):
		k = lerpf(0.6, 0.9, clampf(float(food_count() - DUSK_AT), 0.0, 1.0))
	var raid := phase() != "morning"
	if env and env.environment:
		env.environment.fog_light_color = Color("7a5a3c") if raid else Color("b3a07c").lerp(Color("9a7650"), k)
		env.environment.fog_density = 0.01 if raid else lerpf(0.004, 0.008, k)
		env.environment.adjustment_saturation = 0.75 if raid else lerpf(0.95, 0.82, k)
	if sun:
		sun.light_energy = 0.7 if raid else lerpf(1.05, 0.72, k)
		sun.light_color = Color("ffb27a") if raid else Color("fff1d6").lerp(Color("ffbd84"), k)
		sun.rotation.x = deg_to_rad(lerpf(-48.0, -22.0, k))


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
	if phase() == "morning":
		return "2062 · конец лета · вечер" if Game.flag("dusk") else "2062 · конец лета"
	return "2062 · пожар"


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
			return "Набрать грибов и ягод в лесу к северу, за полем."
		return ""
	if not Game.flag("ded_dead"):
		if Game.quest_stage("fire") <= 1:
			return "Нахарро горит. Найти деда."
		return "Дед у амбара!"
	var pack := pack_line()
	var mods: Dictionary = Game.hero.flags.get("modules", {})
	var need := []
	if not mods.get("inventory", false):
		need.append("«Инвентарь»")
	if not mods.get("map", false):
		need.append("«Карта»")
	if not need.is_empty():
		return "Обыскать тела нападавших: найти модули %s. Потом — на запад, к старой черте.%s" % [" и ".join(need), pack]
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




# ---------------- звуки налёта и перестрелка у ворот ----------------
## Пока идёт налёт, из деревни слышны выстрелы и крики: чем ближе герой, тем громче.
## Защитники у ворот отстреливаются от остатков нападавших.
func _process(delta: float) -> void:
	if main == null:
		return
	_prowl_tick(delta)
	_barn_tick(delta)
	if phase() != "raid" or Game.flag("ded_dead"):
		return
	_shot_t -= delta
	if _shot_t <= 0.0 and not main.combat.on:
		_shot_t = randf_range(0.6, 2.8)
		var d: float = main.player.global_position.distance_to(Vector3(62, 0, 62))
		var vol := clampf(-4.0 - d * 0.22, -30.0, -8.0)
		main.sfx("shot_far_%d" % randi_range(1, 3), vol, randf_range(0.9, 1.1))
		if randf() < 0.12:
			main.sfx("scream_far", vol - 6.0, randf_range(0.85, 1.15))
	if Game.flag("ded_shot") or main.combat.on:
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
	var sh: Character = shooters.pick_random()
	sh.act("fire", Callable(), {"n": randi_range(1, 2)})


# ---------------- события ----------------
func on_hero_moved(pos: Vector3) -> void:
	if phase() != "raid":
		return
	if not Game.flag("fire_seen") and pos.z > FOREST_EDGE_Z:
		Game.set_flag("fire_seen")
		Game.set_quest("forest", 3)
		Game.set_quest("fire", 1)
		main.say("thoughts", "fire")
		main.hud.refresh_objective()
	if Game.flag("fire_seen") and not Game.flag("strangers_seen"):
		for ch in characters():
			if ch.visible and ch.start_dead and ch.char_id.begins_with("raider_dead") and ch.global_position.distance_to(pos) < 4.0:
				Game.set_flag("strangers_seen")
				main.say("thoughts", "strangers")
				break
	if not Game.flag("exec_done"):
		var ex := character("Executioner")
		if ex and ex.visible and ex.pose != "dead" and ex.global_position.distance_to(pos) < EXEC_SCENE_R:
			_execution()
	if not Game.flag("barn_started"):
		var ded := character("DedRaid")
		if ded and ded.global_position.distance_to(pos) < BARN_SCENE_R:
			Game.set_flag("barn_started")
			Game.set_quest("fire", 2)
			main.say("thoughts", "ded_seen")
			_barn_t = 10.0
			main.hud.refresh_objective()


func can_pick(it: Interactable) -> bool:
	if it.item_id in ["mushroom", "berries"] and Game.quest_stage("forest") != 1:
		main.hud.flash_tip("Дед ещё не посылал за грибами")
		return false
	return true


func on_picked(it: Interactable) -> void:
	if it.item_id in ["mushroom", "berries"]:
		var n := food_count()
		if n >= NEED_FOOD and phase() == "morning" and not Game.flag("ambush_on"):
			_start_ambush()
		elif n >= DUSK_AT and not Game.flag("dusk"):
			_dusk()
		elif n == 1:
			main.say("thoughts", "food_first")
		_apply_light()
		main.hud.refresh_objective()
	else:
		_check_pack()
		main.hud.refresh_objective()


# ---------------- вечер: лесные жители уходят домой ----------------
func _dusk() -> void:
	Game.set_flag("dusk")
	main.hud.toast("Прошло несколько часов", 3.0)
	main.say("thoughts", "dusk")
	for n in get_tree().get_nodes_in_group("forest_folk"):
		var ch := n as Character
		if ch == null or not ch.visible:
			continue
		ch.patrol = PackedVector3Array()
		ch.stop()
		var p := ch.global_position
		var path := []
		if p.z < 12.0:
			path.append(Vector3(56, 0, 4))
		path.append_array([Vector3(62, 0, 22), Vector3(62, 0, 37.5)])
		var c := ch
		ch.move_along(path, func(): _gone_home(c), 1.7)


func _gone_home(ch: Character) -> void:
	ch.visible = false
	ch.process_mode = Node.PROCESS_MODE_DISABLED
	ws().misc["gone_" + ch.uid()] = true


# ---------------- засада в лесу ----------------
## Последняя находка: выстрелы в деревне, а сзади подкрадывается нападавший.
## Проверка Внимательности: провал — удар монтировкой сзади и бой;
## успех — шорох издалека, можно затаиться в кустах и переждать или ударить в спину.
func _start_ambush() -> void:
	Game.set_flag("ambush_on")
	Game.set_quest("forest", 2)
	_prowl = "intro"
	await get_tree().create_timer(1.0, false).timeout
	Game.set_flag("phase", "raid")
	_apply_phase()
	main.player.stop()
	main.sfx("shot_far_1", -10.0)
	main.say("thoughts", "shots")
	main.hud.refresh_objective()
	await get_tree().create_timer(2.8, false).timeout
	if main.combat.on:
		return
	var pr := character("Prowler")
	if pr == null:
		_prowl = ""
		return
	pr.visible = true
	pr.process_mode = Node.PROCESS_MODE_INHERIT
	pr.set_held("crowbar")
	pr.hostile = true
	pr.aggro_radius = 0.0
	if Game.skill_check("Внимательность", "PRC", "Внимательность", 13):
		_ambush_heard(pr)
	else:
		_ambush_hit(pr)


## Точка за спиной героя (на свободном гексе)
func _behind(dist: float) -> Vector3:
	var hp: Character = main.player
	var fwd := Vector3(sin(hp.rotation.y), 0, cos(hp.rotation.y))
	return grid.to_world(grid.nearest_free(hp.global_position - fwd * dist))


func _ambush_hit(pr: Character) -> void:
	var hp: Character = main.player
	pr.global_position = _behind(1.2)
	pr.face_towards(hp.global_position)
	var strike := func():
		var dmg := mini(Rules.r1(6) + 2, Game.hero_hp() - 1)
		Game.set_hero_hp(Game.hero_hp() - dmg)
		main.sfx("hit_blunt", -2.0)
		main.hud.hurt_flash()
		main.hud.float_text(hp.global_position + Vector3(0, 2.0, 0), "−%d" % dmg, "hit")
		hp.act("hit")
		Game.log_line("Удар монтировкой сзади: −%d ХП" % dmg, "", "hit")
		Game.hero_changed.emit()
	pr.act("swing", strike)
	await get_tree().create_timer(1.1, false).timeout
	hp.face_towards(pr.global_position)
	main.say("thoughts", "ambush_hit")
	await get_tree().create_timer(1.4, false).timeout
	_prowl = ""
	if not main.combat.on and pr.pose != "dead":
		main.start_fight([pr])


func _ambush_heard(pr: Character) -> void:
	var hp: Character = main.player
	main.sfx("rustle", -3.0)
	pr.global_position = _behind(13.0)
	pr.face_towards(hp.global_position)
	main.say("thoughts", "ambush_heard")
	_prowl = "approach"
	_prowl_t = 0.0
	pr.move_along([hp.global_position], _prowl_arrived, 1.15)


func _prowl_arrived() -> void:
	if _prowl != "approach":
		return
	var pr := character("Prowler")
	_prowl = "search"
	_prowl_t = 2.2
	main.hud.float_text(pr.global_position + Vector3(0, 2.2, 0), "Где ты, зверёк?..", "")
	main.sfx("rustle", -8.0)
	# обыскивает ближние кусты и поляну вокруг
	_prowl_pts = []
	var near: Interactable = null
	for it in items():
		if String(it.name).begins_with("HideBush") and (near == null or it.global_position.distance_to(pr.global_position) < near.global_position.distance_to(pr.global_position)):
			near = it
	if near:
		_prowl_pts.append(grid.to_world(grid.nearest_free(near.global_position + Vector3(1.4, 0, -1.2))))
	for i in 2:
		var a := randf() * TAU
		_prowl_pts.append(grid.to_world(grid.nearest_free(pr.global_position + Vector3(cos(a), 0, sin(a)) * 5.0)))


func _prowl_tick(delta: float) -> void:
	if _prowl in ["", "intro"] or main.combat.on or main.ui_blocked():
		return
	var pr := character("Prowler")
	if pr == null or pr.pose == "dead" or not pr.visible:
		_prowl = ""
		return
	_prowl_t -= delta
	# герой не спрятался и попался на глаза
	if not main.hidden and _prowl != "leave":
		var d: float = pr.global_position.distance_to(main.player.global_position)
		var sneak: bool = Game.hero.get("sneak", false)
		if d < (2.5 if sneak else 4.5) or (_prowl == "search" and not sneak and d < 8.0):
			_prowl = ""
			pr.stop()
			main.player.stop()
			main.say("thoughts", "ambush_spotted")
			main.start_fight([pr])
			return
	if _prowl == "search" and not pr.moving and _prowl_t <= 0.0:
		if _prowl_pts.is_empty():
			_prowl_leave(pr)
		else:
			pr.move_along([_prowl_pts.pop_front()], Callable(), 1.2)
			_prowl_t = 3.0


func _prowl_leave(pr: Character) -> void:
	_prowl = "leave"
	main.hud.float_text(pr.global_position + Vector3(0, 2.2, 0), "Ушёл, гадёныш. Ладно — в деревне веселее.", "")
	var path := []
	if pr.global_position.z < 12.0:
		path.append(Vector3(56, 0, 4))
	path.append_array([Vector3(62, 0, 22), Vector3(62, 0, 27)])
	pr.move_along(path, _prowl_gone, 2.4)


func _prowl_gone() -> void:
	var pr := character("Prowler")
	if pr == null or pr.pose == "dead" or main.combat.on:
		return
	pr.visible = false
	pr.process_mode = Node.PROCESS_MODE_DISABLED
	ws().misc["gone_" + pr.uid()] = true
	_prowl = ""
	Game.set_flag("ambush_done")
	main.say("thoughts", "prowler_gone")


## Герой вышел из укрытия (кликнул куда-то)
func leave_hide() -> void:
	main.hidden = false


# ---------------- казнь у площади ----------------
func _execution() -> void:
	Game.set_flag("exec_done")
	var ex := character("Executioner")
	main.say("thoughts", "execution")
	for n in ["Doomed1", "Doomed2"]:
		var v := character(n)
		if v == null or v.pose == "dead":
			continue
		await get_tree().create_timer(1.6, false).timeout
		if main.combat.on or ex.pose == "dead":
			return
		ex.face_towards(v.global_position)
		ex.aim_pose = true
		var shot := func(_k):
			v.pose = "dead"
			ws().dead[v.uid()] = true
			ws().looted[v.uid()] = true
		ex.act("fire", Callable(), {"n": 1, "per_shot": shot})
	await get_tree().create_timer(1.4, false).timeout
	if ex.pose != "dead" and not main.combat.on:
		ex.aim_pose = false
		main.say("thoughts", "execution_after")


# ---------------- дед у амбара ----------------
## Дед отстреливается от двоих. Если герой не вмешается, через несколько секунд
## деда ранят, и нападавшие уходят через северные ворота (путь в тени).
## Если вмешается — дед помогает огнём, но его всё равно ранят.
var _ded_fire_t := 1.0


func _barn_tick(delta: float) -> void:
	if _barn_t < 0.0 or main.combat.on or Game.flag("ded_shot") or main.ui_blocked():
		return
	var ded := character("DedRaid")
	if ded == null:
		return
	_barn_t -= delta
	_ded_fire_t -= delta
	if _ded_fire_t <= 0.0:
		_ded_fire_t = randf_range(1.6, 2.6)
		var foe := _alive_cleaner()
		if foe:
			ded.face_towards(foe.global_position)
			ded.aim_pose = true
			ded.act("fire", Callable(), {"n": 1})
			if randf() < 0.5:
				foe.face_towards(ded.global_position)
				foe.act("fire" if DB.is_gun(str(foe.tpl.get("weapon", ""))) else "swing", Callable(), {"n": 1})
	if _barn_t <= 0.0:
		_barn_t = -1.0
		var shooter := _alive_cleaner()
		if shooter:
			_shoot_ded(shooter)
			_cleaners_leave()


func _cleaners_leave() -> void:
	await get_tree().create_timer(2.5, false).timeout
	if main.combat.on:
		return
	main.say("thoughts", "cleaners_leave")
	var path := [Vector3(70, 0, 60.5), Vector3(66, 0, 58.5), Vector3(63.8, 0, 53), Vector3(63.8, 0, 36), Vector3(63.8, 0, 22)]
	for ch in characters():
		if ch.squad == "cleaners" and ch.visible and ch.pose != "dead":
			ch.aggro_radius = 3.0
			ch.aim_pose = false
			var c: Character = ch
			ch.move_along(path, func(): _cleaner_gone(c), 1.9)


func _cleaner_gone(ch: Character) -> void:
	if main.combat.on or ch.pose == "dead":
		return
	ch.visible = false
	ch.process_mode = Node.PROCESS_MODE_DISABLED
	ws().misc["gone_" + ch.uid()] = true
	if _alive_cleaner() == null and not Game.flag("cleaners_left"):
		Game.set_flag("cleaners_left")
		main.say("thoughts", "cleaners_gone")
		main.hud.refresh_objective()
		main.autosave()


func on_looted(ch: Character) -> void:
	var lt: Dictionary = ch.tpl.get("loot", {})
	for k in lt:
		if String(k).begins_with("module_") and not Game.flag("module_seen"):
			Game.set_flag("module_seen")
			main.say("thoughts", "module_found")
	main.hud.refresh_objective()


func on_interact(it: Interactable) -> bool:
	if String(it.name).begins_with("HideBush"):
		if _prowl in ["approach", "search"]:
			main.hidden = true
			Game.hero.sneak = true
			main.player.stop()
			main.player.global_position = it.global_position
			Game.hero_changed.emit()
			main.say("thoughts", "hide")
		else:
			main.hud.flash_tip("Густые кусты — в таких можно затаиться")
		return true
	if String(it.name).begins_with("Junk"):
		if Game.quest_stage("barn_junk") != 1:
			main.hud.flash_tip("Варвара не просила разбирать")
			return true
		ws().picked[it.uid()] = true
		it.set_active(false)
		main.player.act("pickup")
		var n := int(Game.flag_value("junk_n", 0)) + 1
		Game.set_flag("junk_n", n)
		Game.log_line("Хлам разобран: %d/3" % n)
		if n >= 3:
			Game.set_quest("barn_junk", 2)
		return true
	if it.name == "LockedBox":
		if Game.flag("box_open"):
			return true
		if Game.flag("box_jammed"):
			main.hud.flash_tip("Замок заклинило намертво")
			return true
		main.player.act("pickup")
		if Game.skill_check("Взлом замков", "DEX", "Взлом замков", 11):
			Game.set_flag("box_open")
			ws().picked[it.uid()] = true
			it.set_active(false)
			Game.add_item("ammo9", 6)
			Game.add_item("canned", 1)
			Game.log_line("В сундуке: патроны 9 мм ×6, консервы", "", "hit")
			Game.add_note("В старом сундуке в амбаре — довоенная коробка патронов. Кто-то когда-то спрятал «не на себя», а на чёрный день.")
			Game.grant_xp(25)
		else:
			Game.set_flag("box_jammed")
			Game.log_line("Отмычка хрустнула — замок заклинило.", "", "miss")
		return true
	if it.name == "BorderExit":
		if phase() == "morning":
			main.say("thoughts", "law_border")
		elif not Game.flag("ded_dead"):
			main.say("thoughts", "not_yet")
		elif _exit_guard_alive():
			main.say("thoughts", "exit_blocked")
		else:
			main.say("thoughts", "border_final")
		return true
	return false


func on_dialog_action(a: String, _sp: Character) -> bool:
	match a:
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
			main.dialog.closed.connect(_assemble_kpk, CONNECT_ONE_SHOT)
			return true
		"hunter_spar":
			var hunter := character("Hunter")
			main.dialog.close()
			Game.set_flag("hunter_spar")
			main.combat.start([hunter], {"kind": "spar"})
			return true
		"range_start":
			main.dialog.close()
			var targets := []
			for ch in characters():
				if ch.is_in_group("range_targets") and ch.pose != "dead":
					targets.append(ch)
			if targets.is_empty():
				return true
			if Game.hero_wkey() == "knife" or Game.hero_wkey() == "fists":
				main._swap_hands()
			Game.set_flag("range_on")
			main.combat.start(targets, {"kind": "range"})
			return true
		"range_reward":
			Game.hero.skills["Дальний бой"] = int(Game.hero.skills.get("Дальний бой", 0)) + 1
			Game.log_line("Дальний бой +1 — урок Бэргэна.", "", "hit")
			Game.hero_changed.emit()
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


# ---------------- бой ----------------
func on_combat_round(r: int) -> void:
	if not _fighting_cleaners() or Game.flag("ded_shot") or r == _ded_round:
		return
	_ded_round = r
	if r >= 3:
		var shooter := _alive_cleaner()
		if shooter:
			_shoot_ded(shooter)
		return
	_ded_shoot()


## Дед стреляет из ружья по одному из нападавших (раз в раунд, пока не ранен)
func _ded_shoot() -> void:
	var ded := character("DedRaid")
	var targets := []
	for u in main.combat.units:
		if not u.is_hero and u.active() and u.node.squad == "cleaners":
			targets.append(u)
	if ded == null or targets.is_empty():
		return
	var t: Fighter = targets.pick_random()
	ded.face_towards(t.node.global_position)
	ded.aim_pose = true
	ded.act("fire", Callable(), {"n": 1})
	if randf() < 0.55:
		main.combat.ally_hit(t, maxi(2, Rules.sum_arr(Rules.roll_dice(DB.weapon("rifle").dmg)) / 2), "Дед Уйбаан")
	else:
		Game.log_line("Дед Уйбаан стреляет — мимо.", "", "miss")
		main.hud.float_text(t.node.global_position + Vector3(0, 2.0, 0), "мимо", "miss")


func on_fighter_down(f: Fighter) -> void:
	if f.node.squad == "cleaners" and not Game.flag("ded_shot"):
		var shooter := _alive_cleaner()
		_shoot_ded(shooter if shooter else f.node, shooter == null)


func on_combat_end(res: String, kind: String) -> void:
	if kind == "spar" and Game.flag("hunter_spar") and not Game.flag("hunter_done"):
		await get_tree().create_timer(0.6, false).timeout
		main.talk_to(character("Hunter"), "won" if res == "win" else "lost")
		return
	if kind == "range" and Game.flag("range_on"):
		Game.set_flag("range_on", false)
		await get_tree().create_timer(0.6, false).timeout
		main.talk_to(character("Shooter"), "done")
		return
	if res != "win":
		return
	var pr := character("Prowler")
	if pr and pr.pose == "dead" and Game.flag("ambush_on") and not Game.flag("ambush_done"):
		Game.set_flag("ambush_done")
		_prowl = ""
		main.say("thoughts", "prowler_dead")
		return
	var ex := character("Executioner")
	if ex and ex.pose == "dead" and not Game.flag("doomed_fled"):
		Game.set_flag("doomed_fled")
		for n in ["Doomed1", "Doomed2"]:
			var v := character(n)
			if v and v.pose == "yield":
				v.pose = ""
				var c := v
				v.move_along([Vector3(v.global_position.x + 6, 0, 56), Vector3(84, 0, 56)], func(): _gone_home(c), 3.4)
				main.say("thoughts", "doomed_saved")
	if Game.flag("ded_dead") or not Game.flag("barn_started") or _alive_cleaner() != null:
		return
	if not Game.flag("ded_shot"):
		Game.set_flag("ded_shot")
		character("DedRaid").pose = "down"
	Game.set_quest("fire", 3)
	var ded := character("DedRaid")
	ded.dialog = "ded"
	await get_tree().create_timer(0.8, false).timeout
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
	ded.dialog = "ded"
	shooter.face_towards(ded.global_position)
	Game.log_line(("Падая, %s успевает ударить деда!" if dying else "%s бьёт по деду!") % shooter.display_name, "", "hit")
	var hit := func():
		ded.pose = "down"
		ded.aim_pose = false
		main.hud.float_text(ded.global_position + Vector3(0, 1.6, 0), "Дед!", "hit")
	if DB.is_gun(shooter.fighter.wkey if shooter.fighter else str(shooter.tpl.get("weapon", ""))):
		shooter.act("fire", Callable(), {"n": 1, "per_shot": func(_i): hit.call()})
	else:
		shooter.act("swing", hit)
	main.say("thoughts", "ded_shot")


# ---------------- КПК: браслет деда + его компьютер ----------------
func _on_hero_changed() -> void:
	if _kpk_busy or main == null:
		return
	if phase() == "morning" and Game.quest_stage("chores") == 1 and Game.flag("fence_done") and Game.flag("basket_done"):
		Game.set_quest("chores", 2)
		main.hud.refresh_objective()
	if Game.flag("kpk"):
		_kpk_busy = true
		_absorb_modules()
		_kpk_busy = false


## После смерти деда: надеть браслет и подключить компьютер кабелем
func _assemble_kpk() -> void:
	if Game.flag("kpk") or Game.item_count("bracelet") <= 0 or Game.item_count("minicomputer") <= 0:
		return
	_kpk_busy = true
	Game.remove_item("bracelet")
	Game.remove_item("minicomputer")
	Game.set_flag("kpk")
	# «Носитель» (состояние владельца) встроен в сам компьютер
	var mods: Dictionary = Game.hero.flags.get("modules", {})
	mods["carrier"] = true
	Game.hero.flags["modules"] = mods
	_absorb_modules()
	_kpk_busy = false
	main.player.show_bracelet(true)
	main.hud.refresh()
	main.hud.refresh_objective()
	main.say("thoughts", "kpk_on")
	main.autosave()


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
			main.sfx("plug", -6.0)
			if k == "module_radio":
				Game.add_note("Обрывок переговоров (модуль «Связь»): «…проводник сказал, их там человек сорок. Старшего взять живым, остальных — по списку. Всё довоенное — в контейнер…»")
	if changed:
		Game.hero.flags["modules"] = mods
		Game.hero_changed.emit()
		_update_exit_guard()
		main.hud.refresh_objective()


# ---------------- раненый у старой черты ----------------
## Появляется, когда в компьютере есть «Инвентарь» и «Карта». При нём — модуль «Связь».
func _update_exit_guard() -> void:
	var g := character("ExitRaider")
	if g == null:
		return
	var mods: Dictionary = Game.hero.flags.get("modules", {})
	var dead: bool = ws().dead.has(g.uid())
	var on: bool = Game.flag("kpk") and mods.get("inventory", false) and mods.get("map", false)
	g.visible = on or dead
	g.process_mode = Node.PROCESS_MODE_INHERIT if g.visible else Node.PROCESS_MODE_DISABLED
	if on and not dead:
		g.hostile = true
		g.aggro_radius = 7.0
		g.set_held("pistol")
		if not Game.flag("exit_guard_seen") and main:
			Game.set_flag("exit_guard_seen")
			main.say("thoughts", "exit_guard")


func _exit_guard_alive() -> bool:
	var g := character("ExitRaider")
	return g != null and g.visible and g.pose != "dead"
