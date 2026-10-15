extends Act1Location
## Вилюйская ГЭС (Акт III). Подступы заминированы всеми фракциями: в минное поле лучше не
## заходить — крадучись есть шанс заметить мину. На гребне плотины — снайпер. У дороги —
## портфель прежнего начальника отдела ф. м.: пропуск «Горизонта». «Смена» пускает только
## с допуском (пропуск или браслет Эллэя). Начальник смены отдаёт ток тому, на чью сторону
## встал герой в Мирном. На пульте — журнал дежурств, терминал (взлом браслета) и аварийный
## рубильник (уничтожить плотину — конец игры).

## Минные поля — как в сборщике (GES_MINES)
const MINES := [Rect2(8, 12, 26, 13), Rect2(8, 41, 26, 16)]
var _safe := Vector3.INF


func _ready() -> void:
	location_id = "ges"
	title = "Вилюйская ГЭС"
	arrive_thought = "Плотина. Бетон, ржавые затворы, таблички с черепами по обе стороны дороги. Под ногами — чужие мины, на гребне — чей-то прицел."
	super._ready()
	if Game.flag("ges_in"):
		var t := get_node_or_null("Village/Turnstile")
		if t:
			t.free()


func status_line() -> String:
	return "2062 · Вилюйская ГЭС"


func on_enter() -> void:
	super.on_enter()
	if Game.quest_stage("act3") == 4:
		Game.set_quest("act3", 5)
	main.hud.refresh_objective()


func objective() -> String:
	match Game.quest_stage("act3"):
		5:
			return "Пройти к проходной станции. Нужен допуск: портфель у дороги — или браслет Эллэя."
		6:
			return "Начальник смены — в машинном зале, у турбины. Решить, кому пойдёт ток."
	return ""


func on_hero_moved(pos: Vector3) -> void:
	super.on_hero_moved(pos)
	var in_mines := false
	for i in MINES.size():
		var r: Rect2 = MINES[i]
		if not r.has_point(Vector2(pos.x, pos.z)):
			continue
		in_mines = true
		var cell := "mine_%d_%d_%d" % [i, int(pos.x / 3.0), int(pos.z / 3.0)]
		if ws().misc.has(cell):
			continue
		ws().misc[cell] = true
		if randf() > 0.35:
			continue
		main.player.stop()
		if Game.hero.get("sneak", false) and Game.skill_check("Внимательность", "PRC", "Внимательность", 11):
			main.think("Под подошвой — тонкая проволока. Мина. Замер… и медленно назад.")
		else:
			var dmg := randi_range(6, 10)
			Game.set_hero_hp(maxi(1, Game.hero_hp() - dmg))
			main.sfx("shot_near", 0.0, 0.6)
			main.hud.refresh()
			Game.log_line("Мина! −%d ХП" % dmg, "", "miss")
			main.think("Грохот, земля встала дыбом. Мина. В ушах звенит — но живой.")
		if _safe != Vector3.INF:
			main.player.global_position = _safe
		return
	if not in_mines:
		_safe = pos


func on_dialog_action(a: String, sp: Character) -> bool:
	match a:
		"ges_enter":
			Game.set_flag("ges_in")
			_open_turnstile()
			return true
		"ges_decide":
			main.dialog.closed.connect(_act3_end, CONNECT_ONE_SHOT)
			return true
		"ges_destroy":
			Game.set_flag("ges_destroyed")
			main.dialog.close()
			main.sfx("thunder", 0.0, 0.5)
			main.show_end("end_ges_destroyed")
			return true
	return super.on_dialog_action(a, sp)


## Турникет отъезжает в сторону, проход свободен
func _open_turnstile() -> void:
	var t := get_node_or_null("Village/Turnstile") as Node3D
	if t:
		var tw := create_tween()
		tw.tween_property(t, "position:z", 2.6, 0.8)
		await tw.finished
		t.queue_free()
	await get_tree().physics_frame
	await get_tree().physics_frame
	grid.build(get_world_3d().direct_space_state, map_rect, 1)


## Конец Акта III: ток решён, впереди — Рубикон и Якутск
func _act3_end() -> void:
	if Game.flag("act4"):
		return
	Game.set_flag("act4")
	Game.add_note("ГЭС: ток передан — %s. Все нити ведут в Якутск: комплекс «Горизонта» под ГРЭС-2. По дороге — Рубикон, мёртвый Вилюйск." % str(Game.flag_value("ges_owner", "")))
	for id in ["vilyuysk", "gorny", "yakutsk"]:
		WorldMap.reveal(id)
	main.autosave()
	main.slides.play(DB.intro.get("act3_end", ["Конец третьего акта."]))


func on_interact(it: Interactable) -> bool:
	match String(it.name):
		"WestRoad":
			main.world_map.open(location_id)
			return true
		"Briefcase":
			if Game.flag("ges_briefcase"):
				main.think("Портфель пуст.")
			else:
				Game.set_flag("ges_briefcase")
				Game.add_item("ges_pass")
				Game.add_item("dead_briefcase_docs")
				main.think("Кожаный портфель, рядом — то, что осталось от хозяина. Внутри: пропуск «Горизонта» — «допуск: все объекты» — и договор на плотину. Прежний начальник отдела не дошёл.")
			return true
		"Turnstile":
			if Game.flag("ges_in"):
				return true
			var w := character("Watch")
			if w and w.visible and w.pose != "dead":
				main.talk_to(w)
			else:
				main.think("Турникет заклинен трубой. Перелезть можно — но тогда вся Смена будет знать, что пришёл посторонний.")
			return true
		"Journal":
			main.think("«Журнал дежурств. 20.11.2012 — смену принял. 21.11.2012 — смену принял…» И так — пятьдесят лет, разными почерками. Последняя запись — сегодняшняя: «смену принял. Посторонних нет»." )
			return true
		"Terminal":
			_terminal()
			return true
		"Overload":
			_overload()
			return true
	return super.on_interact(it)


## Взлом закрытого раздела браслета (необязательно)
func _terminal() -> void:
	if Game.flag("bracelet_decoded"):
		main.think("Раздел браслета уже открыт. Перечитывать не хочется.")
		return
	if not Game.flag("kpk"):
		main.think("Терминал ЭВМ. Мигает курсор: «ВСТАВЬТЕ НОСИТЕЛЬ».")
		return
	if Game.flag("bracelet_try"):
		main.think("Терминал больше не принимает браслет: «ДОСТУП ЗАБЛОКИРОВАН». Одна попытка — и та ушла.")
		return
	Game.set_flag("bracelet_try")
	if Game.skill_check("Техника", "INT", "Техника", 14):
		Game.set_flag("bracelet_decoded")
		Game.grant_xp(300)
		Game.add_note("Браслет Эллэя, закрытый раздел: «Проект „Возрождение“. Оцифровка личности. Ключ шифрования — ЭЛ-1». Кирш хочет загрузить себя в машину под ГРЭС-2 — а ключ на моей руке. И ещё: отчёт отца Кирша с ошибкой, из-за которой началась война, — с его подписью.")
		main.think("Кабель к браслету, команды наугад — и экран вдруг заполняется текстом. «Проект „Возрождение“. Оцифровка личности». Ключ — мой браслет. Дед, что же ты носил всю жизнь…")
	else:
		main.think("Экран мигнул: «ОШИБКА КЛЮЧА. ДОСТУП ЗАБЛОКИРОВАН». Не вышло. Правду придётся узнавать в Якутске.")


## Аварийный рубильник: перегрузить турбину — плотина рухнет, ток не достанется никому
func _overload() -> void:
	if not Game.flag("ges_in"):
		main.think("До рубильника не дотянуться — Смена не пустила.")
		return
	main.dialog.open_data({"speaker": "Рубильник", "title": "Аварийный рубильник", "nodes": {"start": {
		"text": "Красная ручка, табличка: «Сброс. Только по распоряжению главного инженера». Если дёрнуть — турбина пойдёт вразнос, плотина не выдержит. Ток не достанется никому. Никогда.",
		"options": [{"text": "[Дёрнуть рубильник — уничтожить ГЭС]", "next": null, "action": "ges_destroy"}, {"text": "[Отойти]", "next": null}]}}}, "start", null)


func item_actions(it: Interactable) -> Array:
	match String(it.name):
		"Briefcase":
			return [["Открыть портфель", "use"]]
		"Terminal":
			return [["Подключить браслет", "use"]]
		"Journal":
			return [["Прочитать", "use"]]
		"Overload":
			return [["Осмотреть", "use"]]
	return super.item_actions(it)


func describe(it: Interactable) -> String:
	match String(it.name):
		"Briefcase":
			return "Кожаный портфель в траве у дороги."
		"Turnstile":
			return "Турникет проходной, перекрытый трубой."
		"Journal":
			return "Толстый журнал на пульте."
		"Terminal":
			return "Терминал ЭВМ с разъёмом под носитель."
		"Overload":
			return "Аварийный рубильник с красной ручкой."
	return ""
