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
## С какого расстояния часовой у северных ворот замечает героя и зовёт на помощь
const GATE_SCENE_R := 5.5

var _kpk_busy := false
var _volley_t := 2.0
var _shot_t := 1.0
## Засада в лесу: "" | approach | search | leave
var _prowl := ""
var _prowl_t := 0.0
var _prowl_pts: Array = []
var _barn_t := -1.0
var _ded_round := -1
var _exec_round := -1


func _ready() -> void:
	location_id = "nakharro"
	title = "Нахарро"
	Game.hero_changed.connect(_on_hero_changed)


func _exit_tree() -> void:
	if Game.hero_changed.is_connected(_on_hero_changed):
		Game.hero_changed.disconnect(_on_hero_changed)


func phase() -> String:
	return str(Game.flag_value("phase", "morning"))


## Вступление: герой рассматривает отцовский пистолет. Камера близко, мысли
## идут одна за другой; если игрок пошёл — сцена обрывается.
const INTRO := [
	"Отцовский пистолет. Каждое утро одно и то же: проверить, протереть, пересчитать патроны. Восемь. Больше не будет.",
	"Отец ушёл в тайгу за соболем и не вернулся к ночи. Нашли его утром — изодранного, будто медведь поработал. Только медведь так не рвёт.",
	"«Чучуна», — сказали старики. Лесной человек. Никто его не видел — ни тогда, ни после. А отец, кажется, видел.",
	"Он умирал три дня. На третий сунул мне в руку пистолет: «Теперь твой». Больше ничего не сказал.",
]


func on_new_game() -> void:
	Game.set_flag("phase", "morning")
	_apply_phase()
	var pl: Character = main.player
	var z: float = main.zoom
	main.zoom = 6.0
	pl.aim_pose = true
	pl.set_held(Game.hero_wkey())
	Game.add_note("Отец погиб в тайге: его задрал чучуна — лесной человек, которого никто никогда не видел. Перед смертью он отдал мне свой пистолет.")
	await get_tree().create_timer(0.6).timeout
	for line in INTRO:
		if pl.moving or main.combat.on:
			break
		main.think(line)
		var t := 0.0
		var dur: float = 2.5 + line.length() * 0.045
		while t < dur and not pl.moving:
			await get_tree().create_timer(0.1).timeout
			t += 0.1
	pl.aim_pose = false
	if main.zoom == 6.0:
		main.zoom = z
	main.say("thoughts", "wake")


func on_world_state_applied() -> void:
	_apply_phase()
	_apply_sacred()


## на лиственнице — новая сэлэ с лентами, если герой её повесил
func _apply_sacred() -> void:
	var t := get_node_or_null("Village/SacredTree")
	if t:
		t.get_node("Ribbons").visible = Game.flag("salama_tied")
		t.get_node("OldRags").visible = not Game.flag("salama_tied")


func on_enter() -> void:
	# сцена у ворот идёт на таймерах; после загрузки её уже нет — бой начнётся у ворот сам
	Game.set_flag("gate_scene_running", false)
	_apply_phase()
	_apply_sacred()


func _apply_phase() -> void:
	var raid := phase() != "morning"
	for n in get_tree().get_nodes_in_group("phase_morning"):
		_set_on(n, not raid)
	for n in get_tree().get_nodes_in_group("phase_raid"):
		_set_on(n, raid)
	_apply_light()
	_apply_fence()
	# лесные жители, ушедшие домой к вечеру
	if Game.flag("dusk"):
		for n in get_tree().get_nodes_in_group("forest_folk"):
			_set_on(n, false)
	if phase() == "after":
		_nobody_left()
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
	# у ворот: после начала сцены нападавшие — враги
	if Game.flag("gate_started"):
		for n in ["Executioner", "GateRaider"]:
			var e := character(n)
			if e and e.pose != "dead":
				e.hostile = true
				e.aggro_radius = 8.0
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
		# камера далеко — даже малая плотность заметно выцвечивает; дым налёта чуть гуще
		env.environment.fog_density = 0.0035 if raid else lerpf(0.001, 0.0025, k)
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
		return "Дед ранен — подойти к нему." if Game.flag("ded_shot") else "Дед у амбара!"
	var pack := pack_line()
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
	_mark_t -= delta
	if _mark_t <= 0.0:
		_mark_t = 0.4
		_update_quest_marks()
	for m in _qmarks.values():
		if is_instance_valid(m) and m.visible:
			m.position.y = m.get_meta("y0") + sin(Time.get_ticks_msec() / 250.0) * 0.08
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
	_ded_near(pos)
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
	# сцена у ворот уже была (или Эрчима убили, пока герой шёл другой дорогой):
	# подошёл к воротам — бой, даже если крадёшься
	if Game.flag("gate_started") and not main.combat.on and not Game.flag("gate_scene_running"):
		for n in ["Executioner", "GateRaider", "GateGuard"]:
			var e := character(n)
			if e and e.global_position.distance_to(pos) < 9.0 and _gate_enemies_left():
				_gate_fight()
				break
	if Game.flag("fire_seen") and not Game.flag("gate_started"):
		var gg := character("GateGuard")
		if gg and gg.visible and gg.pose != "dead" and gg.global_position.distance_to(pos) < GATE_SCENE_R:
			_gate_scene()
		elif gg and gg.pose != "dead" and pos.z > 40.0 and gg.global_position.distance_to(pos) > 12.0:
			# герой вошёл в деревню другой дорогой — часового у ворот уже убили
			Game.set_flag("gate_started")
			_kill_npc(gg, false)
			for e in [character("Executioner"), character("GateRaider")]:
				if e and e.pose != "dead":
					e.hostile = true
					e.aggro_radius = 8.0
	if not Game.flag("barn_started"):
		var ded := character("DedRaid")
		if ded and ded.global_position.distance_to(pos) < BARN_SCENE_R:
			Game.set_flag("barn_started")
			Game.set_quest("fire", 2)
			main.say("thoughts", "ded_seen")
			_barn_t = 10.0
			main.hud.refresh_objective()
			if _alive_cleaner() == null:
				_barn_t = -1.0
				_ded_falls()


func can_pick(it: Interactable) -> bool:
	if it.item_id in ["mushroom", "berries"] and Game.quest_stage("forest") != 1:
		main.hud.flash_tip("Дед ещё не посылал за грибами")
		return false
	if _is_theft(it):
		return _steal(it)
	return true


# ---------------- воровство до налёта ----------------
## Пока деревня жива, чужое брать нельзя: всё, кроме грибов, ягод, корзины и досок
## для Степана, и кроме вещей из своей (дедовой) избы. Заметили — вещь остаётся
## на месте, отругают, молва падает вдвое сильнее; не видел никто — молва не меняется.
## После налёта брать можно.
const FREE_PICK := ["mushroom", "berries", "basket", "planks", "t_comb"]
const THEFT_H := 3
const WITNESS_R := 9.0
const SCOLD := ["Эй! Положи, где взял!", "Ты что творишь? А ну верни!", "Совсем стыд потерял? Не твоё — не трогай.",
	"Вот деду-то расскажу, чем внук занимается!"]


func _is_theft(it: Interactable) -> bool:
	if phase() != "morning" or it.item_id in FREE_PICK:
		return false
	return not String(it.name).begins_with("Take_IzbaDed")


## Кто из жителей видит героя: рядом, в сознании, не враг и ничто не заслоняет
func _witness() -> Character:
	var p: Vector3 = main.player.global_position
	var best: Character = null
	var bd := WITNESS_R
	for ch in characters():
		if ch == main.player or not ch.visible or ch.pose in ["dead", "down"] or ch.hostile:
			continue
		var d: float = ch.global_position.distance_to(p)
		if d < bd and grid.line_clear(ch.global_position, p, get_world_3d().direct_space_state):
			bd = d
			best = ch
	return best


## Попытка взять чужое. true — вещь ушла в сумку (никто не видел)
func _steal(_it: Interactable) -> bool:
	var w := _witness()
	if w:
		main.player.act("pickup")
		if w.pose == "":
			w.face_towards(main.player.global_position)
		var line: String = SCOLD[randi() % SCOLD.size()]
		main.hud.float_text(w.global_position + Vector3(0, 2.0, 0), line, "miss")
		Game.log_line("%s: «%s»" % [w.display_name if w.display_name != "" else "Житель", line], "", "miss")
		Game.change_rep(-THEFT_H * 2, "поймали на воровстве")
		main.think("Заметили... Стыдно-то как.")
		return false
	Game.change_rep(-THEFT_H, "взял чужое", false)
	if not Game.flag("theft_thought"):
		Game.set_flag("theft_thought")
		main.think("Никто не видел. Только на душе всё равно гадко.")
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
		if it.item_id == "t_comb" and Game.quest_stage("comb") == 1:
			Game.set_quest("comb", 2)
			main.think("Гребень Нюргуяны — в траве у опушки. Вернуть? Или… красивый.")
			main.hud.refresh_objective()
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


# ---------------- северные ворота: часовой, пленные, бой ----------------
## Часовой зовёт на помощь — его тут же застреливают. Начинается бой с двумя
## нападавшими; в первых раундах один из них расстреливает пленных, если его не остановить.
func _gate_enemies_left() -> bool:
	for n in ["Executioner", "GateRaider"]:
		var e := character(n)
		if e and e.visible and e.pose != "dead" and not ws().misc.has("gone_" + e.uid()):
			return true
	return false


func _gate_scene() -> void:
	Game.set_flag("gate_started")
	Game.set_flag("gate_scene_running")
	main.player.stop()
	var gg := character("GateGuard")
	var gr := character("GateRaider")
	var ex := character("Executioner")
	# часовой уже отстреливается — прибежал на помощь; кричит герою, не опуская винтовки
	if gr and gr.pose != "dead":
		gg.face_towards(gr.global_position)
	gg.aim_pose = true
	gg.act("fire", Callable(), {"n": 1})
	main.hud.float_text(gg.global_position + Vector3(0, 2.3, 0), "Напали! Помоги, они внутри!", "")
	Game.log_line("Эрчим: «Напали! Помоги, они внутри!»", "", "miss")
	await get_tree().create_timer(1.2, false).timeout
	if gr and gr.pose != "dead":
		gr.face_towards(gg.global_position)
		gr.aim_pose = true
		gr.act("fire", Callable(), {"n": 2})
	await get_tree().create_timer(0.7, false).timeout
	_kill_npc(gg, false)
	main.hud.float_text(gg.global_position + Vector3(0, 1.6, 0), "Эрчим!", "hit")
	main.say("thoughts", "gate_guard_dead")
	# казнь — сразу, как в катсцене: стрелок расстреливает обоих пленных
	for n in ["Doomed1", "Doomed2"]:
		await get_tree().create_timer(0.9, false).timeout
		var v := character(n)
		if ex == null or ex.pose == "dead" or v == null or v.pose != "yield":
			continue
		ex.face_towards(v.global_position)
		ex.aim_pose = true
		ex.act("fire", Callable(), {"n": 1})
		_kill_npc(v)
		Game.log_line("%s стреляет в пленного!" % ex.display_name, "", "hit")
		main.hud.float_text(v.global_position + Vector3(0, 1.4, 0), "Нет!", "hit")
	Game.set_flag("exec_done")
	main.say("thoughts", "execution_after")
	await get_tree().create_timer(1.0, false).timeout
	Game.set_flag("gate_scene_running", false)
	for e in [ex, gr]:
		if e and e.pose != "dead":
			e.hostile = true
			e.aggro_radius = 8.0
	_gate_fight()


## Бой у северных ворот: с тем, кто из двоих ещё жив (раньше бой начинался,
## только если жив стрелок над пленными)
func _gate_fight() -> void:
	if main.combat.on:
		return
	for n in ["Executioner", "GateRaider"]:
		var e := character(n)
		if e and e.visible and e.pose != "dead" and not ws().misc.has("gone_" + e.uid()):
			main.start_fight([e])
			return


## После налёта в деревне не остаётся живых: защитники у западных ворот, раненый,
## пленные, которых не успели спасти. Тела можно обыскать (винтовки, патроны).
func _nobody_left() -> void:
	for n in ["DefenderW1", "DefenderW2", "WoundedDefender", "GateGuard", "Doomed1", "Doomed2"]:
		var ch := character(n)
		if ch == null or ch.pose == "dead" or ws().misc.has("gone_" + ch.uid()) or not ch.visible:
			continue
		ch.stop()
		ch.patrol = PackedVector3Array()
		_kill_npc(ch, false)


func _kill_npc(ch: Character, looted := true) -> void:
	if ch == null or ch.pose == "dead":
		return
	ch.pose = "dead"
	ch.aim_pose = false
	ch.set_held("")
	ws().dead[ch.uid()] = true
	if looted:
		ws().looted[ch.uid()] = true


## В первых двух раундах боя у ворот стрелок расстреливает пленного (если ещё жив)
func _gate_round(r: int) -> void:
	if r == _exec_round or r > 2:
		return
	_exec_round = r
	var ex := character("Executioner")
	if ex == null or ex.pose == "dead" or (ex.fighter and not ex.fighter.active()):
		return
	for n in ["Doomed1", "Doomed2"]:
		var v := character(n)
		if v and v.visible and v.pose == "yield":
			ex.face_towards(v.global_position)
			ex.act("fire", Callable(), {"n": 1})
			_kill_npc(v)
			Game.log_line("%s стреляет в пленного!" % ex.display_name, "", "hit")
			main.hud.float_text(v.global_position + Vector3(0, 1.4, 0), "Нет!", "hit")
			if r == 2 or _doomed_alive() == 0:
				Game.set_flag("exec_done")
				main.say("thoughts", "execution_after")
			return


func _doomed_alive() -> int:
	var n := 0
	for k in ["Doomed1", "Doomed2"]:
		var v := character(k)
		if v and v.pose != "dead":
			n += 1
	return n


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
		else:
			_ded_falls()


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
	if it.name == "SacredTree":
		if Game.quest_stage("salama") == 1 and Game.item_count("salama") > 0:
			Game.remove_item("salama")
			Game.set_flag("salama_tied")
			Game.set_quest("salama", 2)
			Game.grant_xp(20)
			_apply_sacred()
			main.think("Обвязал ствол волосяной верёвкой, расправил ленты. Ветер шевелит их — красные, белые, синие. Будто дерево вздохнуло.")
		elif Game.flag("salama_tied"):
			main.think("Ленты треплет ветер. Красиво. И как-то спокойнее.")
		else:
			main.think("Старая лиственница, самая большая у опушки. На нижних ветках — истлевшие серые лоскуты. Кто-то когда-то их вешал.")
		return true
	if it.name == "CellarHatch":
		if phase() == "raid":
			main.think("Не до подпола. Там — дед.")
		else:
			main.load_location("nakharro_cellar", "Down")
		return true
	if it.name == "WellUse":
		if Game.quest_stage("well") == 1:
			if Game.item_count("rope") > 0:
				Game.add_item("bucket")
				Game.set_quest("well", 2)
				main.think("Привязал к верёвке крюк из гвоздя, опустил. Третий заход — зацепил. Вот оно, ведро.")
				main.hud.refresh_objective()
			else:
				main.think("Ведро видно — блестит на дне. Без верёвки не достать.")
		else:
			main.think("Вода в колодце чистая, холодная. Пахнет железом.")
		return true
	if it.name == "FenceMend":
		_mend_fence()
		return true
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
		_chest(it, String(it.get_meta("act", "")))
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
				ded.aim_pose = false
				ded.set_held("")
				ws().dead[ded.uid()] = true
			Game.set_flag("ded_dead")
			Game.set_flag("phase", "after")
			_nobody_left()
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
			if not DB.is_gun(Game.hero_wkey()):
				main._swap_hands()
			Game.set_flag("range_on")
			main.combat.start(targets, {"kind": "range"})
			return true
		"range_reward":
			Game.hero.skills["Огнестрел"] = mini(10, int(Game.hero.skills.get("Огнестрел", 0)) + 1)
			Game.log_line("Огнестрел +1 — урок Бэргэна.", "", "hit")
			Game.hero_changed.emit()
			return true
		"open_kpk":
			main.open_kpk.call_deferred("stat")
			return true
		"leave_village":
			main.dialog.close()
			Game.set_flag("act", 1)
			main.slides.finished.connect(func(): main.world_map.open("nakharro"), CONNECT_ONE_SHOT)
			main.slides.play(DB.intro.get("outro", []))
			return true
	return false


# ---------------- бой ----------------
func on_combat_round(r: int) -> void:
	if _fighting_squad("gate"):
		_gate_round(r)
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
	_ded_falls()


## Нападавших у амбара больше нет (убиты или ушли) — дед падает раненым и зовёт внука.
## Вызывается после боя, при подходе к амбару и по таймеру сцены.
func _ded_falls() -> void:
	if Game.flag("ded_dead") or not Game.flag("barn_started") or _alive_cleaner() != null:
		return
	var dd := character("DedRaid")
	if dd == null:
		return
	dd.aim_pose = false
	if not Game.flag("ded_shot"):
		Game.set_flag("ded_shot")
		dd.pose = "down"
	Game.set_quest("fire", 3)
	var ded := character("DedRaid")
	ded.dialog = "ded"
	# разговор — только когда герой подойдёт сам (или кликнет по деду)
	main.hud.float_text(ded.global_position + Vector3(0, 1.2, 0), "Внучок...", "")
	main.think("Дед! Он ранен. Скорее к нему.")
	main.hud.refresh_objective()


## Дед лежит раненый — подошёл ближе 2,5 м: последний разговор
const DED_TALK_R := 2.5


func _ded_near(pos: Vector3) -> void:
	if not Game.flag("ded_shot") or Game.flag("ded_dead") or main.dialog.visible or main.combat.on:
		return
	var ded := character("DedRaid")
	if ded and ded.global_position.distance_to(pos) < DED_TALK_R:
		main.player.stop()
		main.player.face_towards(ded.global_position)
		main.talk_to(ded, "last")


func _fighting_cleaners() -> bool:
	return _fighting_squad("cleaners")


func _fighting_squad(sq: String) -> bool:
	if not main.combat.on:
		return false
	for u in main.combat.units:
		if not u.is_hero and u.node.squad == sq:
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


# ---------------- отметки над квестовыми вещами ----------------
var _mark_t := 0.0
var _qmarks := {}


## Нужна ли вещь прямо сейчас по заданию (доски, корзина, грибы, ягоды, дыра в заборе)
func _quest_item(it: Interactable) -> bool:
	if not it.visible:
		return false
	var ch := Game.quest_stage("chores") == 1 and phase() == "morning"
	match String(it.name):
		"Planks":
			return ch and not Game.flag("fence_done") and Game.item_count("planks") == 0
		"Basket":
			return ch and not Game.flag("basket_done") and Game.item_count("basket") == 0
		"FenceMend":
			return not Game.flag("fence_done") and Game.item_count("planks") > 0
	if it.item_id in ["mushroom", "berries"]:
		return Game.quest_stage("forest") == 1 and phase() == "morning"
	return false


func _update_quest_marks() -> void:
	var dd := character("DedRaid")
	if dd:
		var want := Game.flag("ded_shot") and not Game.flag("ded_dead")
		var dm: Label3D = _qmarks.get("DedRaid", null)
		if want and dm == null:
			dm = _mark_label(1.1)
			dd.add_child(dm)
			_qmarks["DedRaid"] = dm
		if dm:
			dm.visible = want
	for it in items():
		var on := _quest_item(it)
		var m: Label3D = _qmarks.get(it.name, null)
		if on and m == null:
			m = _mark_label(maxf(0.9, it.pick_size.y + 0.6))
			it.add_child(m)
			_qmarks[it.name] = m
		if m:
			m.visible = on


func _mark_label(y: float) -> Label3D:
	var m := Label3D.new()
	m.text = "▼"
	m.font_size = 64
	m.pixel_size = 0.006
	m.modulate = Color("ffb640")
	m.outline_modulate = Color(0.1, 0.05, 0.0, 0.9)
	m.outline_size = 10
	m.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	m.no_depth_test = true
	m.position = Vector3(0, y, 0)
	m.set_meta("y0", y)
	return m


# ---------------- сундук в амбаре ----------------
## Заперт. Открыть: ключом (он у тётки Варвары — стащить из кармана или снять с тела)
## или отмычкой из отвёртки и шпильки. До налёта это воровство. Внутри — автомат «Буран».
func _chest(it: Interactable, act: String) -> void:
	if Game.flag("box_open"):
		_open_chest(it)
		return
	var has_key := Game.item_count("chest_key") > 0
	var tools := Game.item_count("screwdriver") > 0 and Game.item_count("hairpin") > 0
	if act == "":
		act = "key" if has_key else ("pick" if tools else "")
	match act:
		"key":
			if not has_key:
				main.hud.flash_tip("Ключа нет. Он у тётки Варвары — в кармане фартука")
				return
			if phase() == "morning" and not _steal(it):
				return
			main.player.act("pickup")
			Game.log_line("Ключ повернулся с хрустом. Сундук открыт.", "", "hit")
		"pick":
			if not tools:
				main.hud.flash_tip("Нужны отвёртка и шпилька")
				return
			if phase() == "morning" and not _steal(it):
				return
			main.player.act("pickup")
			if not Game.skill_check("Воровство", "REF", "Воровство", 11, 2):
				Game.remove_item("hairpin")
				Game.log_line("Шпилька сломалась в замке. Нужна другая.", "", "miss")
				return
			Game.log_line("Отвёртка вместо рычага, шпилька — щуп. Щелчок — открыто.", "", "hit")
			Game.grant_xp(25)
		_:
			main.hud.flash_tip("Заперт. Ключ — у тётки Варвары. Или отвёртка со шпилькой")
			return
	Game.set_flag("box_open")
	Game.add_note("В общем сундуке в амбаре — довоенный автомат, завёрнутый в мешковину. Кто-то берёг его «на чёрный день». Чёрный день настал.")
	_open_chest(it)


func _open_chest(it: Interactable) -> void:
	var gen := func() -> Array:
		return [{"id": "buran", "n": 1, "ok": not Game.hero.owned.has("buran"), "why": "уже есть"},
			{"id": "ammo762", "n": 30, "ok": true}, {"id": "canned", "n": 1, "ok": true}, {"id": "cas_body", "n": 1, "ok": true}]
	main.open_loot("LockedBox", "Сундук в амбаре", gen)


## Действия по правой кнопке для вещей и мест этой локации
func item_actions(it: Interactable) -> Array:
	var n := String(it.name)
	if n == "SacredTree":
		if Game.quest_stage("salama") == 1 and Game.item_count("salama") > 0:
			return [["Повесить сэлэ", "use"]]
		return [["Осмотреть", "use"]]
	if n.begins_with("Junk"):
		return [["Разобрать", "use"]]
	if n == "LockedBox":
		if Game.flag("box_open"):
			return [["Открыть", "use"]]
		return [["Открыть ключом", "use:key"], ["Взломать (отвёртка + шпилька)", "use:pick"]]
	if n.begins_with("HideBush"):
		return [["Спрятаться", "use"]]
	if n == "FenceMend":
		return [["Заделать досками", "use"]]
	if n == "CellarHatch":
		return [["Спуститься в подпол", "use"]]
	if n == "WellUse":
		if Game.quest_stage("well") == 1:
			return [["Достать ведро (верёвка)" if Game.item_count("rope") > 0 else "Достать ведро (нужна верёвка)", "use"]]
		return [["Заглянуть в колодец", "use"]]
	if n == "BorderExit":
		return [["Перейти черту", "use"]]
	if it.kind == "item":
		if _is_theft(it):
			# кассета «Свидетель» подсказывает, видят ли тебя
			if Game.cas_has_tag("witness"):
				return [["Взять (воровство — тебя видят!)" if _witness() else "Взять (воровство, никто не видит)", "use"]]
			return [["Взять (это воровство)", "use"]]
		return [["Взять", "use"]]
	return []


func describe(it: Interactable) -> String:
	var n := String(it.name)
	if n == "SacredTree":
		return "Аар Луук Мас — так старики зовут эту лиственницу. Самая старая у опушки." + (" На ней — новая сэлэ с лентами." if Game.flag("salama_tied") else "")
	if n == "LockedBox":
		return "Тяжёлый общий сундук с навесным замком. Ключ носит тётка Варвара." if not Game.flag("box_open") else "Сундук открыт."
	if n.begins_with("Junk"):
		return "Куча хлама: битые ящики, тряпьё, гнутые гвозди. Варвара просила разобрать."
	if n.begins_with("HideBush"):
		return "Густые кусты. Если присесть — снаружи не видно."
	if n == "FenceMend":
		return "Дыра в заборе Степана: штакетник выломан, жердь висит. Пара досок — и будет как новый."
	if n == "BorderExit":
		return "Старая черта: дальше за неё жителям ходить запрещено."
	if n == "CellarHatch":
		return "Люк в подпол. Дед хранит там соленья и старьё."
	if n == "WellUse":
		return "Колодец с воротом. Цепь оборвана — ведро ушло на дно." if Game.quest_stage("well") == 1 else "Колодец с воротом."
	return ""


# ---------------- забор Степана ----------------
var _fence_fixed := false
var _fence_init := false


## Герой сам прибивает доски в дыру забора (или это сделал Степан в разговоре)
func _mend_fence() -> void:
	if Game.flag("fence_done"):
		return
	if Game.item_count("planks") <= 0:
		main.hud.flash_tip("Нужны доски — Степан говорил, лежат у поленницы")
		return
	Game.remove_item("planks", 1)
	main.player.act("pickup")
	for k in 3:
		get_tree().create_timer(0.35 + k * 0.3).timeout.connect(func(): main.sfx("hit_blunt", -6.0, 1.4))
	if Game.skill_check("Механика", "INT", "Механика", 10):
		Game.log_line("Доски прибиты ровно — забор Степана снова цел.", "", "hit")
		Game.grant_xp(25)
	else:
		Game.log_line("Доски встали кое-как, палец отбит — но дыры больше нет.", "", "miss")
	Game.set_flag("fence_done")
	var st := character("Stepan")
	if st and st.visible and st.pose != "dead":
		main.hud.float_text(st.global_position + Vector3(0, 2.0, 0), "Ишь ты, сам управился! Спасибо.", "thought")
		Game.log_line("Степан: «Ишь ты, сам управился! Спасибо, парень».")


## Сломанный пролёт или целый: видимость, коллизия и сетка проходимости
func _apply_fence() -> void:
	var done := Game.flag("fence_done")
	if done == _fence_fixed and _fence_init:
		return
	var rebuild := _fence_init
	_fence_init = true
	_fence_fixed = done
	var gap := get_node_or_null("Village/FenceGap") as Node3D
	var fixed := get_node_or_null("Village/FenceFixed") as Node3D
	if gap == null or fixed == null:
		return
	_set_solid(gap, not done)
	_set_solid(fixed, done)
	var mend := get_node_or_null("Items/FenceMend") as Interactable
	if mend:
		mend.set_active(not done)
	if not rebuild and not done:
		return
	await get_tree().physics_frame
	grid.build(get_world_3d().direct_space_state, map_rect, 1)


func _set_solid(n: Node3D, on: bool) -> void:
	n.visible = on
	for b in n.find_children("*", "CollisionObject3D", true, false):
		(b as CollisionObject3D).collision_layer = 1 if on else 0


# ---------------- КПК: браслет деда + его компьютер ----------------
func _on_hero_changed() -> void:
	if _kpk_busy or main == null:
		return
	if Game.flag("fence_done") and not _fence_fixed:
		_apply_fence()
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
	Game.add_note("На браслете деда — знак: треугольник в круге. Такой же был на нашивках нападавших. Отец деда работал на них?")
	# «Носитель» (состояние владельца) встроен в сам компьютер
	var mods: Dictionary = Game.hero.flags.get("modules", {})
	for m in ["carrier", "inventory", "map"]:
		mods[m] = true
	Game.hero.flags["modules"] = mods
	_absorb_modules()
	_update_exit_guard()
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
				Game.add_note("Обрывок переговоров (модуль «Связь»): «…Кирк — второму: проводник сказал, их там человек сорок. Старшего взять живым, остальных — по списку. Всё довоенное — в контейнер…» Кирк. Так зовут того, кто командовал.")
				Game.set_flag("knows_kirk")
				if Game.quest_stage("who") == 1:
					Game.set_quest("who", 2)
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
