extends SungarDistrict
## Сунгар, центр: торговые ряды (купчиха Дария и её соперник Хоточчу),
## «Счастливая лодка» (хозяйка Сардаана, банкомёт Валера), контора «отдела ф. м.».
## Долговую книгу можно выведать у конторщика — или ночью залезть в окно.


func _ready() -> void:
	location_id = "sungar_center"
	title = "Сунгар · центр"
	links = {"ToGate": ["sungar", "FromCenter", "К воротам и рынку"], "ToQuarter": ["sungar_quarter", "FromCenter", "В жилой квартал"]}
	super._ready()


func on_interact(it: Interactable) -> bool:
	match String(it.name):
		"OfficeWindow":
			_window()
			return true
		"Monument":
			main.think("Бронзовый мужик в беретке — тот самый, что на всех купюрах. Кто он — в Сунгаре не знает никто. Табличку давно сдали в лом.")
			return true
	return super.on_interact(it)


## Окно конторы: ночью, пока конторщика нет, — Воровство
func _window() -> void:
	if Game.quest_stage("bootur") >= 8:
		main.think("Окно конторы. Всё, что мне было нужно, я уже знаю.")
		return
	var clerk := character("Clerk")
	var closed: bool = clerk == null or not clerk.visible or Clock.is_night()
	if not closed:
		main.think("Днём? Конторщик за столом, охранник в трёх шагах. Ночью — другое дело.")
		return
	if Game.skill_check("Воровство", "REF", "Воровство", 12, 2 if Game.hero.get("sneak", false) else 0) or Game.flag("window_try"):
		Game.add_item("ledger_page")
		Game.set_quest("bootur", 8)
		WorldMap.reveal("markun")
		WorldMap.reveal("mir")
		Game.add_note(str(DB.items.get("ledger_page", {}).get("read", "")))
		Game.grant_xp(150)
		main.think("Ножом поддел шпингалет. Внутри — тихо, пахнет чернилами. Книга должников на столе. Нашёл «Боотур» — и вырвал лист.")
		main.hud.refresh_objective()
	else:
		Game.set_flag("window_try")
		main.think("Рама скрипит. Замер, прислушался — тихо. Ещё раз, осторожнее.")


func item_actions(it: Interactable) -> Array:
	match String(it.name):
		"OfficeWindow":
			return [["Влезть в окно", "use"]]
		"Monument":
			return [["Рассмотреть", "use"]]
	return super.item_actions(it)


func describe(it: Interactable) -> String:
	match String(it.name):
		"OfficeWindow":
			return "Окно конторы, выходит в проулок. Шпингалет хлипкий."
		"Monument":
			return "Памятник на площади: толстый мужик в беретке."
	return super.describe(it)


func objective() -> String:
	return bootur_objective()
