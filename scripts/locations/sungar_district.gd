class_name SungarDistrict
extends Act1Location
## Общее для трёх районов Сунгара: переходы между районами (To* → другая локация),
## деньги в разговорах (условие rub_N), след Боотура. С карты мира попадаешь только
## к воротам (sungar); центр и жилой квартал — по улицам.

## имя выхода → [локация, точка появления, подпись]; четвёртое поле "up" — это лестница
## на верхние этажи дома (сцена SungarHouse)
var links := {}


func status_line() -> String:
	return "2062 · Сунгар"


func on_enter() -> void:
	super.on_enter()
	if Game.quest_stage("bootur") == 5:
		Game.set_quest("bootur", 6)
		main.hud.refresh_objective()


func on_interact(it: Interactable) -> bool:
	var n := String(it.name)
	if links.has(n):
		if _is_stairs(n) and not stairs_allowed(n):
			return true
		main.load_location(str(links[n][0]), str(links[n][1]))
		return true
	if n == "InfoScreen":
		main.think(["Экран «Сунгар-информ»: янтарные буквы ползут слева направо. Курс соли, комендантский час, «долги — в контору». Довоенная техника, а работает.",
			"«Сунгар-информ». Под сводками — мигающая строка: «ВНИМАНИЕ: ПОЖАРНАЯ БЕЗОПАСНОСТЬ — ДОЛГ КАЖДОГО». Кто-то нацарапал внизу: «и долг конторе»."][randi() % 2])
		return true
	return super.on_interact(it)


## Можно ли подняться по этой лестнице (наследник проверяет охрану)
func stairs_allowed(_n: String) -> bool:
	return true


## Патрули проверяют документы: раз в сутки, если у героя нет прописки
func cop_check(pos: Vector3) -> void:
	if not Game.flag("sg_entered") or Game.flag("sg_permit") or main.combat.on or main.ui_blocked():
		return
	if int(Game.flag_value("sg_docs_day", -1)) == Clock.day():
		return
	for n in get_tree().get_nodes_in_group("cops"):
		var c := n as Character
		if c == null or not c.visible or c.pose != "" or c.hostile or not is_ancestor_of(c):
			continue
		if c.global_position.distance_to(pos) < 4.5 and grid.line_clear(c.global_position, pos, main.space()):
			Game.set_flag("sg_docs_day", Clock.day())
			main.player.stop()
			main.talk_to(c, "check")
			return


func on_hero_moved(pos: Vector3) -> void:
	cop_check(pos)


func item_actions(it: Interactable) -> Array:
	var n := String(it.name)
	if n == "InfoScreen":
		return [["Прочитать", "use"]]
	if links.has(n):
		if _is_stairs(n):
			return [["Подняться на второй этаж", "use"]]
		return [["Перейти: " + str(links[n][2]), "use"]]
	return super.item_actions(it)


func _is_stairs(n: String) -> bool:
	return links.has(n) and (links[n] as Array).size() > 3 and str(links[n][3]) == "up"


func describe(it: Interactable) -> String:
	var n := String(it.name)
	if n == "InfoScreen":
		return "Уличный экран на столбе: ЭЛТ в железном коробе, янтарные буквы."
	if _is_stairs(n):
		return "%s: лестница на второй этаж. Ступени бетонные, перила в краске." % str(links[n][2])
	if links.has(n):
		return "Улица ведёт дальше — %s." % str(links[n][2]).to_lower()
	return ""


## Общая подсказка про Боотура — в любом районе
func bootur_objective() -> String:
	match Game.quest_stage("bootur"):
		6:
			return "Найти, где Боотур проиграл всё: «Счастливая лодка» — в центре города, у реки."
		7:
			return "Узнать в конторе «отдела ф. м.» (центр), куда увели Боотура."
		8:
			return "След ведёт в Мар-Кун — следующая точка «списка Б». Идти туда с карты мира."
	return ""
