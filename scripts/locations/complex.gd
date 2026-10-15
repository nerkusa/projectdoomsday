extends Act1Location
## Комплекс «Возрождение» под ГРЭС-2 — финал игры. Офис отдела, где пятьдесят лет «работают»:
## ЭЛТ, «Лучший сотрудник месяца», пальма. Кабинет и. о. генерального с архивом (отчёт отца
## Кирша — с ключ-картой или Техникой), лаборатория доктора Виктора, серверный зал с Киршем.
## Кирк стоит у двери серверной: убедить или убить. Охраны меньше, если ток ушёл рабочим или
## совету — тогда с героем ополченцы. Выбор у кресла Кирша — конец игры.

const ALLY_DMG := Vector2i(2, 5)


func _ready() -> void:
	location_id = "complex"
	title = "Комплекс «Возрождение»"
	arrive_thought = "Лифт открылся в коридор с ковровой дорожкой. Гудят лампы, пахнет бумагой и озоном. За стеклом — столы, ЭЛТ-мониторы… и люди за ними. Работают."
	super._ready()
	if Game.flag("kirk_done"):
		var d := get_node_or_null("Village/SrvDoor")
		if d:
			d.free()


func status_line() -> String:
	return "2062 · под ГРЭС-2"


func on_enter() -> void:
	super.on_enter()
	if Game.quest_stage("act4") < 5:
		Game.set_quest("act4", 5)
	var own := str(Game.flag_value("ges_owner", ""))
	var allies := own == "workers" or own == "republic"
	for i in 3:
		var a := character("Ally%d" % i)
		if a and not allies:
			_hide(a)
	# свой ток — меньше охраны: половина ушла на станцию
	if allies:
		for n in ["Guard2", "Guard3"]:
			var g := character(n)
			if g:
				_hide(g)
	# пропуск «все объекты»: охрана не трогает, пока не было тревоги
	if Game.item_count("ges_pass") > 0 and not Game.flag("cx_alarm"):
		for ch in characters():
			if ch.squad.begins_with("cx_guard"):
				ch.hostile = false
	if Game.flag("kirk_dead"):
		var k := character("Kirk")
		if k:
			_hide(k)
	main.hud.refresh_objective()


func _hide(ch: Character) -> void:
	ch.stop()
	ch.visible = false
	ch.process_mode = Node.PROCESS_MODE_DISABLED


func objective() -> String:
	if Game.flag("kirk_done"):
		return "Серверный зал открыт. Кирш — в кресле среди трубок."
	if Game.quest_stage("act4") == 5:
		return "Пройти через офис к серверной. У двери — Кирк."
	return ""


func on_combat_round(_r: int) -> void:
	for i in 3:
		var a := character("Ally%d" % i)
		if a == null or not a.visible or a.pose == "dead":
			continue
		var es: Array = main.combat.enemies()
		if es.is_empty():
			return
		var t = es[randi() % es.size()]
		main.combat.ally_hit(t, randi_range(ALLY_DMG.x, ALLY_DMG.y), a.display_name)


func on_combat_end(res: String, kind: String) -> void:
	super.on_combat_end(res, kind)
	Game.set_flag("cx_alarm")
	var k := character("Kirk")
	if res == "win" and k and k.pose == "dead" and not Game.flag("kirk_done"):
		Game.set_flag("kirk_dead")
		main.think("Кирк лёг у двери, не выпустив автомата. Карточка на его груди — «Начальник службы безопасности». Дверь серверной щёлкнула.")
		_open_door()


func on_dialog_action(a: String, sp: Character) -> bool:
	match a:
		"kirk_fight":
			main.dialog.closed.connect(_kirk_fight, CONNECT_ONE_SHOT)
			return true
		"kirk_spared":
			main.dialog.closed.connect(_kirk_spared, CONNECT_ONE_SHOT)
			return true
		"final_broken", "final_destroy", "final_archive", "final_unplug", "final_viktor", "final_self":
			Game.set_flag("final", a.trim_prefix("final_"))
			main.dialog.closed.connect(_finale, CONNECT_ONE_SHOT)
			return true
	return super.on_dialog_action(a, sp)


func _kirk_fight() -> void:
	var k := character("Kirk")
	if k == null:
		return
	k.hostile = true
	main.start_fight([k])


func _kirk_spared() -> void:
	var k := character("Kirk")
	if k:
		k.move_along(Clock._route(self, k.global_position, Vector3(47.0, 0, 15.0)), Callable(), 2.0)
	Game.grant_xp(200)
	_open_door()


## Дверь серверной уходит в стену, сетка проходимости пересобирается
func _open_door() -> void:
	if Game.flag("kirk_done"):
		return
	Game.set_flag("kirk_done")
	main.hud.refresh_objective()
	var d := get_node_or_null("Village/SrvDoor") as Node3D
	if d:
		var tw := create_tween()
		tw.tween_property(d, "position:y", -2.4, 1.0)
		await tw.finished
		d.queue_free()
	await get_tree().physics_frame
	await get_tree().physics_frame
	grid.build(get_world_3d().direct_space_state, map_rect, 1)


func on_interact(it: Interactable) -> bool:
	match String(it.name):
		"LiftUp":
			main.load_location("yakutsk", "FromLift")
			return true
		"Archive":
			_archive()
			return true
		"Board":
			main.think("«Лучший сотрудник месяца». Двадцать фотографий, все пожелтели одинаково. Под последней дата — март 2013-го. Одна рамка пустая и закрашена углём.")
			return true
		"Palm":
			main.think("Пальма из фанеры, раскрашенная зелёнкой. Кто-то каждый день поливает кадку.")
			return true
	return super.on_interact(it)


## Архив кабинета: отчёт отца Кирша об ошибке, с которой началась война
func _archive() -> void:
	if Game.flag("cx_archive"):
		main.think("Ящики архива выпотрошены — всё нужное у меня.")
		return
	var ok := Game.item_count("keycard") > 0
	if not ok:
		if Game.flag("cx_archive_try"):
			main.think("Замок архива заклинило после прошлой попытки.")
			return
		Game.set_flag("cx_archive_try")
		ok = Game.skill_check("Техника", "INT", "Техника", 13)
	if ok:
		Game.set_flag("cx_archive")
		Game.add_item("kirsh_report")
		Game.grant_xp(150)
		main.think("Папка «Совершенно секретно. Экз. единственный». Отчёт главного инженера О. Кирша, 2012 год: ошибка в расчёте — и подпись. Война началась с этой страницы.")
	else:
		main.think("Электронный замок пискнул и погас. Без карты не открыть.")


## Финал: слайды по выбору у кресла и по всему, что было в пути, затем титры
func _finale() -> void:
	Game.set_quest("act4", 6)
	main.autosave()
	main.slides.play(final_lines())
	await main.slides.finished
	main.show_end("end_game")


## Строки финальных слайдов — из флагов всей игры
static func final_lines() -> Array:
	var L := []
	match str(Game.flag_value("final", "")):
		"broken":
			L.append("Кирш сам опустил рубильник. Архив «Горизонта» поднялся наверх — пусть считают сами.")
		"destroy":
			L.append("Машина под ГРЭС-2 сгорела вместе с Генеральным. Пятьдесят лет расчётов ушли дымом в трубы.")
		"archive":
			L.append("Кирш умер в своём кресле. Архив — тонны бумаги и лент — открыли людям.")
		"unplug":
			L.append("Загрузку отключили. Р. О. Кирш умер через месяц — стариком, в и. о.")
		"viktor":
			L.append("«Приоритет — Виктор». Доктор занял место в машине. Говорят, теперь она смотрит на север.")
		"self":
			L.append("Браслет щёлкнул в разъёме. Машина под ГРЭС-2 думает теперь голосом из Нахарро.")
	L.append("Нахарро так и осталась пеплом в тайге. " + ("Друг лежит у ворот." if Game.flag("friend_dead") else "Кто выжил — разошёлся по свету."))
	if Game.flag("bootur_dead"):
		L.append("Боотур, сдавший деревню, не дожил до весны.")
	elif Game.flag("bootur_rise"):
		L.append("Боотур вернулся в тайгу — искупать. О нём ещё споют.")
	elif Game.flag("bootur_spared"):
		L.append("Боотур остался в Нью-Рбе — пить и вспоминать.")
	if Game.flag("nr_coup"):
		L.append("В Нью-Рбе правит Кеша. Алмазы снова фальшивые — но уже свои.")
	elif Game.flag("nr_apovich_arrested"):
		L.append("Аповича увезли в Мирный. Нью-Рба впервые за годы считает казну сама.")
	elif Game.flag("nr_apovich_deal"):
		L.append("Апович откупился. Нью-Рба живёт как жила.")
	if Game.flag("mk_evac"):
		L.append("Мар-Кун ушёл тропой на юг — и выжил.")
	elif Game.flag("mk_done"):
		L.append("Мар-Кун отстоял свой участок. Инструкция на столбе обведена ещё раз.")
	var own := str(Game.flag_value("ges_owner", ""))
	var ges := {"workers": "Ток ГЭС пошёл рабочим кварталам Мирного.", "republic": "Ток ГЭС взял совет республиканцев — и йегеря.",
		"kimberlit": "Ток ГЭС достался «Кимберлиту». Карьер заработал снова.", "raiders": "Рейдеры сели на плотину. Ток теперь продают."}
	if ges.has(own):
		L.append(ges[own])
	var r := Game.rep()
	var who := "Моҕус — так о герое говорят у костров: тот, кто сжёг лишнее." if r < 0 else ("Эллэй-Боотур — так зовут героя в песнях." if r >= 40 else "Боотур — так зовут героя: просто боотур, без прозвищ.")
	L.append(who)
	return L


func item_actions(it: Interactable) -> Array:
	match String(it.name):
		"Archive":
			return [["Открыть архив", "use"]]
		"Board", "Palm":
			return [["Осмотреть", "use"]]
		"LiftUp":
			return [["Подняться", "use"]]
	return super.item_actions(it)


func describe(it: Interactable) -> String:
	match String(it.name):
		"Archive":
			return "Металлический шкаф с электронным замком."
		"Board":
			return "Доска почёта отдела."
		"Palm":
			return "Пальма в кадке."
		"LiftUp":
			return "Двери лифта."
	return ""
