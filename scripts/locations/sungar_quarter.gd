extends SungarDistrict
## Сунгар, жилой квартал: бараки, бар «Шалман» (кулачные бои за домом), оружейная,
## беглый подёнщик Аркадий и сборщики долгов, комната проводника.


func _ready() -> void:
	location_id = "sungar_quarter"
	title = "Сунгар · жилой квартал"
	links = {"ToCenter": ["sungar_center", "FromQuarter", "В центр города"], "ObshagaStairs": ["sungar_obshaga", "F2Below", "Общежитие", "up"]}
	super._ready()


func on_world_state_applied() -> void:
	_apply_people()
	# кочегара забрала полиция
	var st := character("Stoker")
	if st and Game.flag("stoker_arrested"):
		st.visible = false
		st.process_mode = Node.PROCESS_MODE_DISABLED


func on_enter() -> void:
	super.on_enter()
	_apply_people()


## Сборщики ходят по кварталу, пока ищут Аркадия; сам Аркадий — пока не ушёл
func _apply_people() -> void:
	var rq := Game.quest_stage("sg_runaway")
	var hunting := rq <= 1 and not Game.flag("collectors_left")
	for n in get_tree().get_nodes_in_group("collectors"):
		var c := n as Character
		if c and c.pose != "dead":
			_show(c, hunting and not ws().misc.has("gone_" + c.uid()))
	var r := character("Runaway")
	if r:
		_show(r, rq <= 1 or rq == 3)


## Чуть погодя — чтобы успели договорить; сам on_dialog_action ждать не должен
func _people_later(sec: float) -> void:
	await get_tree().create_timer(sec, false).timeout
	_apply_people()


func _show(c: Character, on: bool) -> void:
	c.visible = on
	c.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED


func on_dialog_action(a: String, sp: Character) -> bool:
	match a:
		"betray_runaway":
			main.dialog.close()
			Game.set_quest("sg_runaway", 4)
			Game.add_item("rubles", 30)
			Game.change_rep(-8, "сдал беглого подёнщика сборщикам")
			Game.set_flag("collectors_left")
			var r := character("Runaway")
			if r:
				r.bark("Будь ты проклят!..")
			main.think("Сборщики заломили Аркадию руки и увели. Тридцать рублей. Мятых, с мужиком в беретке.")
			_people_later(1.2)
			return true
		"collectors_leave":
			Game.set_flag("collectors_left")
			_people_later(0.8)
			return true
		"collectors_fight":
			main.dialog.close()
			for n in get_tree().get_nodes_in_group("collectors"):
				(n as Character).hostile = true
			main.start_fight([sp if sp else character("Collector1")])
			return true
	return super.on_dialog_action(a, sp)


func on_combat_end(res: String, kind: String) -> void:
	if kind == "spar" and Game.quest_stage("sg_fight") == 1:
		if res == "win":
			Game.set_quest("sg_fight", 2)
			Game.add_item("rubles", 40)
			main.think("Дьөгүөр сидит в пыли и смеётся разбитыми губами. Ньукуус отсчитывает сорок рублей.")
		else:
			Game.set_quest("sg_fight", 3)
			main.think("Небо, пыль, звон в ушах. Двадцать рублей остались у Ньукууса.")
		return
	if res == "win" and squad_cleared("collectors") and Game.quest_stage("sg_runaway") == 1:
		Game.set_flag("collectors_left")
		Game.set_quest("sg_runaway", 3)
		Game.change_rep(-2, "драка со сборщиками конторы")
		main.think("Сборщики лежат. Контора этого не забудет. Но Аркадий — пока свободен.")


func on_interact(it: Interactable) -> bool:
	var n := String(it.name)
	if n.begins_with("Scrap"):
		_scrap(n)
		return true
	if n == "GuideRoom":
		_guide_room()
		return true
	if n == "Chimney":
		main.think("Кирпичная труба котельной, метров двадцать. Скобы-лестница уходят в дым. Кочегар говорит: угля на месяц, а там — как хотите.")
		return true
	return super.on_interact(it)


## Хлам за бараками: в одной из куч — довоенная пружина
func _scrap(n: String) -> void:
	if ws().misc.has("searched_" + n):
		main.think("Перерыл уже. Ржавчина и тряпки.")
		return
	ws().misc["searched_" + n] = true
	main.player.act("pickup")
	if n == "ScrapC":
		Game.add_item("spring")
		if Game.quest_stage("sg_spring") == 1:
			Game.set_quest("sg_spring", 2)
		main.think("Под ржавым тазом — свёрток в промасленной тряпке. Пружина! Довоенная, живая.")
	elif n == "ScrapA":
		Game.add_item("rubles", 3)
		main.think("Ржавые гвозди, битое стекло… и три рубля, свёрнутые трубочкой. Чья-то заначка.")
	else:
		Game.add_item("t_button")
		main.think("Тряпьё, консервные банки, пуговица от шинели.")


## Каморка проводника в бараке: под половицей — записка
func _guide_room() -> void:
	if Game.quest_stage("sg_guide") >= 2:
		main.think("Пустая каморка. Голые нары. Он ушёл и не вернётся.")
		return
	if Game.quest_stage("sg_guide") == 1 or Game.skill_check("Внимательность", "PRC", "Внимательность", 14):
		Game.add_item("guide_note")
		Game.set_quest("sg_guide", 2)
		Game.add_note(str(DB.items.get("guide_note", {}).get("read", "")))
		Game.grant_xp(80)
		main.think("Каморка пустая — но одна половица ходит. Под ней — записка карандашом. Подпись: «Сэргэй». Проводник.")
	else:
		main.think("Каморка в бараке. Нары, гвоздь в стене, запах махорки. Чья — непонятно.")


func item_actions(it: Interactable) -> Array:
	var n := String(it.name)
	if n.begins_with("Scrap"):
		return [["Порыться в хламе", "use"]]
	if n == "GuideRoom":
		return [["Обыскать каморку", "use"]]
	if n == "Chimney":
		return [["Осмотреть", "use"]]
	return super.item_actions(it)


func describe(it: Interactable) -> String:
	var n := String(it.name)
	if n.begins_with("Scrap"):
		return "Куча хлама за бараками: ржавчина, тряпьё, битые ящики."
	if n == "GuideRoom":
		return "Каморка в конце барака, дверь на щеколде."
	if n == "Chimney":
		return "Труба котельной. Дымит — значит, зимой в бараках будет тепло."
	return super.describe(it)


func objective() -> String:
	if Game.quest_stage("sg_spring") == 1:
		return "Поискать боевую пружину в хламе за бараками."
	if Game.quest_stage("sg_runaway") == 1:
		return "Аркадий прячется за бараками. Помочь ему уйти за реку — или нет."
	return bootur_objective()
