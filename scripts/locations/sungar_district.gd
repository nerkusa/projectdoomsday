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
		main.load_location(str(links[n][0]), str(links[n][1]))
		return true
	return super.on_interact(it)


func item_actions(it: Interactable) -> Array:
	var n := String(it.name)
	if links.has(n):
		if _is_stairs(n):
			return [["Подняться на второй этаж", "use"]]
		return [["Перейти: " + str(links[n][2]), "use"]]
	return super.item_actions(it)


func _is_stairs(n: String) -> bool:
	return links.has(n) and (links[n] as Array).size() > 3 and str(links[n][3]) == "up"


func describe(it: Interactable) -> String:
	var n := String(it.name)
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
