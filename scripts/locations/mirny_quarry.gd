extends Act1Location
## Дно карьера «Мир»: брошенная техника, стая одичавших псов и лаборатория обогащения.
## В опечатанном ящике — настоящий алмазный порошок и журнал: «Спуститься первым».


func _ready() -> void:
	location_id = "mirny_quarry"
	title = "Мирный · дно карьера"
	arrive_thought = "Дно карьера. Небо — маленький серый круг далеко вверху. Пахнет сыростью и псиной."
	super._ready()


func status_line() -> String:
	return "2062 · карьер «Мир»"


func on_interact(it: Interactable) -> bool:
	match String(it.name):
		"UpRamp":
			main.load_location("mirny", "FromQuarry")
			return true
		"LabCrate":
			if Game.flag("quarry_crate"):
				main.think("Ящик пуст.")
			else:
				Game.set_flag("quarry_crate")
				Game.add_item("quarry_find")
				Game.set_quest("mr_quarry", 2)
				Game.grant_xp(200)
				main.think("Сорвал пломбу. Пробирки с порошком — настоящий алмаз, первый сорт. Журнал, перфолента. Я спустился первым. Теперь решать, кому это отдать.")
				main.hud.refresh_objective()
			return true
		"LabDesk":
			main.think("Журнал лаборатории, последняя запись — 2012: «Пробы трубки „Мир“ — в архив „Горизонта“, Якутск, ГРЭС-2. Персоналу — эвакуация». Даже здесь — «Горизонт».")
			if not Game.flag("quarry_desk"):
				Game.set_flag("quarry_desk")
				Game.add_note("Дно карьера «Мир»: пробы трубки в 2012 году ушли в архив «Горизонта» под ГРЭС-2, Якутск.")
			return true
	return super.on_interact(it)


func describe(it: Interactable) -> String:
	match String(it.name):
		"UpRamp":
			return "Серпантин наверх, в город."
		"LabCrate":
			return "Железный ящик с пломбой ГОК «Мирный»."
		"LabDesk":
			return "Стол с журналами в пыли."
	return ""
