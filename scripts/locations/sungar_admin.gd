extends SungarHouse
## Администрация ПГТ Сунгар, 2–3 этажи. Глава посёлка Аграфена Семёновна воюет
## с конторой; на третьем — машинный зал ЭВМ «Искра-1030» и оператор Люда: если
## починить лентопротяжку (Техника), в архиве — перепись, долги и копия «списка Б».


func _ready() -> void:
	location_id = "sungar_admin"
	title = "Администрация ПГТ Сунгар"
	super._ready()


func on_interact(it: Interactable) -> bool:
	match String(it.name):
		"Mainframe":
			_mainframe()
			return true
		"ArchiveTerminal":
			_terminal()
			return true
	return super.on_interact(it)


## Лентопротяжка ЭВМ зажевала ленту
func _mainframe() -> void:
	if Game.flag("sg_mainframe_fixed"):
		main.think("Бобины крутятся, лампочки бегут зелёной змейкой. «Искра» думает.")
		return
	if Game.quest_stage("sg_archive") < 1:
		main.think("ЭВМ «Искра-1030»: три шкафа с бобинами. Одна бобина стоит — лента намотана на ролик комом.")
		return
	var bonus := 2 if Game.item_count("screwdriver") > 0 else 0
	if Game.skill_check("Техника", "INT", "Техника", 12, bonus) or Game.flag("mainframe_try"):
		Game.set_flag("sg_mainframe_fixed")
		Game.grant_xp(40)
		main.think("Снял крышку, вытянул зажёванную ленту, подклеил — подтянул ремень привода. Щёлк, и бобины пошли. Шкаф загудел, как живой.")
		main.hud.refresh_objective()
	else:
		Game.set_flag("mainframe_try")
		main.think("Лента намотана на ролик, ремень привода ослаб. Как всё это разобрать — не сразу понятно. Попробовать ещё.")


## Терминал архива: распечатка — долги конторы и копия «списка Б»
func _terminal() -> void:
	if Game.quest_stage("sg_archive") < 2:
		main.think("Терминал: зелёный курсор мигает на пустом экране. «НЕТ СВЯЗИ С ЭВМ».")
		return
	if Game.quest_stage("sg_archive") >= 3:
		main.think("«АРХИВ СУНГАР. ВВЕДИТЕ ЗАПРОС». Всё, что мне было нужно, я уже распечатал.")
		return
	Game.add_item("archive_printout")
	Game.set_quest("sg_archive", 3)
	Game.grant_xp(60)
	Game.add_note(str(DB.items.get("archive_printout", {}).get("read", "")))
	main.think("Матричный принтер визжит минуту. Длинная лента бумаги: перепись, должники — и копия списка, который я уже где-то видел. «Список Б».")
	main.hud.refresh_objective()


func item_actions(it: Interactable) -> Array:
	match String(it.name):
		"Mainframe":
			return [["Осмотреть ЭВМ", "use"]]
		"ArchiveTerminal":
			return [["Сесть за терминал", "use"]]
	return super.item_actions(it)


func describe(it: Interactable) -> String:
	match String(it.name):
		"Mainframe":
			return "ЭВМ «Искра-1030»: шкафы с магнитными бобинами, ряды мигающих лампочек."
		"ArchiveTerminal":
			return "Терминал с ЭЛТ: зелёные буквы, клавиатура в жирных пятнах."
	return super.describe(it)


func objective() -> String:
	match Game.quest_stage("sg_archive"):
		1:
			return "Починить лентопротяжку ЭВМ (машинный зал, 3 этаж)." if not Game.flag("sg_mainframe_fixed") else "Сказать Люде, что ЭВМ работает."
		2:
			return "Сесть за терминал архива (3 этаж)."
	if Game.quest_stage("sg_power") == 1:
		return "Глава посёлка ждёт лист из долговой книги конторы."
	return bootur_objective()
