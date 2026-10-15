class_name NyurbaDistrict
extends Act1Location
## Общее для районов Нью-Рбы: переходы между районами по улицам (To* → другая локация).
## С карты мира попадаешь только в Проход (через ворота).

## имя выхода → [локация, точка появления, подпись]
var links := {}


func status_line() -> String:
	return "2062 · Нью-Рба"


func on_interact(it: Interactable) -> bool:
	var n := String(it.name)
	if links.has(n):
		main.load_location(str(links[n][0]), str(links[n][1]))
		return true
	return super.on_interact(it)


func item_actions(it: Interactable) -> Array:
	var n := String(it.name)
	if links.has(n):
		return [["Перейти: " + str(links[n][2]), "use"]]
	return super.item_actions(it)


func describe(it: Interactable) -> String:
	var n := String(it.name)
	if links.has(n):
		return "Улица ведёт дальше — %s." % str(links[n][2]).to_lower()
	return ""
