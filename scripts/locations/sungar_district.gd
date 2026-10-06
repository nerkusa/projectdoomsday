class_name SungarDistrict
extends Act1Location
## Общее для трёх районов Сунгара: переходы между районами (To* → другая локация),
## деньги в разговорах (условие rub_N), след Боотура. С карты мира попадаешь только
## к воротам (sungar); центр и жилой квартал — по улицам.

## имя выхода → [локация, точка появления, подпись]
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
	if links.has(String(it.name)):
		return [["Перейти: " + str(links[String(it.name)][2]), "use"]]
	return super.item_actions(it)


func describe(it: Interactable) -> String:
	if links.has(String(it.name)):
		return "Улица ведёт дальше — %s." % str(links[String(it.name)][2]).to_lower()
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
