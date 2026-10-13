extends SungarDistrict
## Сунгар, центр: торговые ряды (купчиха Дария и её соперник Хоточчу),
## клуб в Доме культуры, бюро Полиса — йегеря взяли город «под защиту».
## «Список Б», снятый с убитого чистильщика, можно выведать у писаря — или ночью залезть в окно.


func _ready() -> void:
	location_id = "sungar_center"
	title = "Сунгар · центр"
	links = {"ToGate": ["sungar", "FromCenter", "К воротам и рынку"], "ToQuarter": ["sungar_quarter", "FromCenter", "В жилой квартал"],
		"DomStairs": ["sungar_dom", "F2Below", "Дом на площади", "up"], "AdminStairs": ["sungar_admin", "F2Below", "Администрация", "up"]}
	super._ready()


func on_interact(it: Interactable) -> bool:
	match String(it.name):
		"OfficeWindow":
			_window()
			return true
		"Monument":
			main.think("Бронзовый мужик в беретке — тот самый, что на всех купюрах. Кто он — в Сунгаре не знает никто. Табличку давно сдали в лом.")
			return true
		"HonorBoard":
			main.think("«Доска почёта». Под стеклом — выцветшие лица: доярки, бурильщики, учитель года. Одно фото кто-то заменил вырезкой из журнала: человек в пальто. Подпись: «Отдел ф. м. — лучший работник».")
			return true
		"Projector":
			main.think(["Киноаппарат «Украина». Бобины пустые, лента давно ушла на заплатки. Киномеханик всё равно протирает его каждый день.",
				"Киномеханик шепчет: «Раньше тут „Чапаева“ крутили. Весь Сунгар приходил». Теперь в зале — домино и шашки."][randi() % 2])
			return true
	return super.on_interact(it)


## Окно бюро: ночью, пока писаря нет, — Воровство
func _window() -> void:
	if Game.item_count("ledger_page") > 0 or Game.quest_stage("sg_power") >= 2:
		main.think("Окно бюро. Всё, что мне было нужно, я уже знаю.")
		return
	var clerk := character("Clerk")
	var closed: bool = clerk == null or not clerk.visible or Clock.is_night()
	if not closed:
		main.think("Днём? Писарь за столом, йегерь в трёх шагах. Ночью — другое дело.")
		return
	if Game.skill_check("Воровство", "REF", "Воровство", 12, 2 if Game.hero.get("sneak", false) else 0) or Game.flag("window_try"):
		Game.add_item("ledger_page")
		Game.set_quest("bootur", 8)
		WorldMap.reveal("markun")
		WorldMap.reveal("mir")
		Game.add_note(str(DB.items.get("ledger_page", {}).get("read", "")))
		Game.grant_xp(150)
		Game.set_flag("cl_list_got")
		main.think("Ножом поддел шпингалет. Внутри — тихо, пахнет чернилами и оружейным маслом. Реестр на столе, а в нём — мятый «список Б». Вырвал лист вместе с ним.")
		main.hud.refresh_objective()
	else:
		Game.set_flag("window_try")
		main.think("Рама скрипит. Замер, прислушался — тихо. Ещё раз, осторожнее.")


func item_actions(it: Interactable) -> Array:
	match String(it.name):
		"OfficeWindow":
			return [["Влезть в окно", "use"]]
		"Monument", "HonorBoard":
			return [["Рассмотреть", "use"]]
		"Projector":
			return [["Рассмотреть", "use"]]
	return super.item_actions(it)


func describe(it: Interactable) -> String:
	match String(it.name):
		"OfficeWindow":
			return "Окно бюро Полиса, выходит в проулок. Шпингалет хлипкий."
		"Monument":
			return "Памятник на площади: толстый мужик в беретке."
		"HonorBoard":
			return "Доска почёта у площади. Стекло в трещинах."
		"Projector":
			return "Довоенный киноаппарат на тумбе. Две пустые бобины."
	return super.describe(it)


func objective() -> String:
	return bootur_objective()


## Наверх в администрацию — только с пропиской (или если охранник «не видел»)
func stairs_allowed(n: String) -> bool:
	if n != "AdminStairs" or Game.flag("sg_permit") or Game.flag("sg_admin_pass"):
		return true
	var g := character("AdminGuard")
	if g == null or not g.visible or g.pose == "dead":
		return true
	main.talk_to(g, "stairs")
	return false
