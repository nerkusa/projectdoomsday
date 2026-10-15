extends NyurbaDistrict
## Нью-Рба, Промрайон — цеха огранки и напыления, приёмка сырья под охраной, склад
## продукции, заводская столовая. Здесь хозяин — промышленник Кеша; здесь видно, что
## алмазный порошок в цех приходит «не тот».


func _ready() -> void:
	location_id = "nyurba_prom"
	title = "Нью-Рба · Промрайон"
	links = {"ToProxod": ["nyurba", "FromProm", "Проход"], "ToBlack": ["nyurba_black", "FromProm", "Чёрный район"]}
	arrive_thought = "Промрайон. Гудят станки, из труб валит дым, пахнет горелым металлом. Город держится на этих цехах."
	super._ready()


func on_interact(it: Interactable) -> bool:
	match String(it.name):
		"Cutters":
			if Game.flag("nr_kesha_pal"):
				main.think("Резцы «с алмазным напылением». Провёл ногтем — напыление сыплется, как сахар. Кеша прав: это паль.")
			else:
				main.think("Ящик резцов с клеймом «НР — алмазное напыление». Блестят. Один, правда, уже со сколом.")
			return true
		"Cart":
			main.think("Вагонетка с породой. Камни серые, пустые — из таких алмазов не выйдет.")
			return true
		"Ledger":
			_ledger()
			return true
	return super.on_interact(it)


## Журнал приёмки у кладовщика: днём — стащить (Воровство), ночью — склад пуст
func _ledger() -> void:
	if Game.item_count("pal_ledger") > 0:
		main.think("Журнал приёмки. Нужный лист уже у меня.")
		return
	var keeper := character("Storekeeper")
	var watched: bool = keeper != null and keeper.visible and not Clock.is_night()
	if int(ws().misc.get("ledger_caught", -1)) == Clock.day():
		main.think("Кладовщик теперь глаз с журнала не сводит. Не сегодня.")
		return
	if watched and not Game.skill_check("Воровство", "REF", "Воровство", 13, 2 if Game.hero.get("sneak", false) else 0):
		ws().misc["ledger_caught"] = Clock.day()
		Game.change_rep(-3, "полез в журнал склада")
		main.think("Кладовщик захлопнул журнал у меня перед носом. «Руки! Это казначейская отчётность!»")
		return
	Game.add_item("pal_ledger")
	main.think("Вырвал лист из журнала приёмки. «Сорт II — стекло молотое». Подпись: А. П. Вот она, паль.")
	Game.grant_xp(80)
	got_evidence()


func on_dialog_action(a: String, sp: Character) -> bool:
	if a == "nr_coup":
		Game.set_flag("nr_resolved")
		Game.set_flag("nr_coup")
		Game.add_note("Нью-Рба: Кеша остановил цеха и повёл рабочих к Дому правительства. Город теперь его — или ничей.")
		return true
	return super.on_dialog_action(a, sp)


func describe(it: Interactable) -> String:
	match String(it.name):
		"Cutters":
			return "Ящик с готовыми резцами на верстаке."
		"Cart":
			return "Ржавая вагонетка на узкоколейке."
		"Ledger":
			return "Толстый журнал приёмки на столе кладовщика."
	return super.describe(it)
