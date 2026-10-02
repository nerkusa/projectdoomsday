extends Location
## Подпол избы деда — второй уровень Нахарро. Темно: свечу надо зажечь спичками.
## Здесь варенье для деда (задание «Подпол деда») и сундук прадеда — пропуск Эллэя.


func _ready() -> void:
	location_id = "nakharro_cellar"
	title = "Подпол деда"


func on_world_state_applied() -> void:
	_apply_light()


func _apply_light() -> void:
	var f := get_node_or_null("Items/Candle/Flame") as OmniLight3D
	if f:
		f.visible = Game.flag("cellar_lit")


func on_enter() -> void:
	_apply_light()
	if not Game.flag("cellar_lit"):
		main.think("Темно — хоть глаз выколи. На ящике у стены нащупал свечу в плошке. Зажечь бы.")


func status_line() -> String:
	return "2062 · конец лета · подпол"


func _lit() -> bool:
	return Game.flag("cellar_lit")


func on_interact(it: Interactable) -> bool:
	match String(it.name):
		"UpExit":
			main.load_location("nakharro", "FromCellar")
			return true
		"Candle":
			if _lit():
				main.think("Свеча коптит, но светит. Тени пляшут по банкам.")
			elif Game.item_count("matches") > 0:
				Game.set_flag("cellar_lit")
				_apply_light()
				Game.log_line("Зажёг свечу спичками.", "", "hit")
				main.think("Чиркнул спичкой — с третьего раза. Свеча занялась. Полки, банки, бочки… и сундук, которого я раньше не видел.")
			else:
				main.think("Нечем зажечь. Спички — на печи у деда.")
			return true
		"Jam":
			if not _lit():
				main.think("В темноте не разобрать, где варенье, а где грибы. Свечу бы.")
			elif Game.flag("jam_taken"):
				main.think("Остальное — на зиму. Дед не похвалит.")
			else:
				Game.set_flag("jam_taken")
				Game.add_item("jam")
				Game.log_line("Взял: Брусничное варенье", "", "hit")
				if Game.quest_stage("cellar") == 1:
					Game.set_quest("cellar", 2)
					main.hud.refresh_objective()
			return true
		"Trunk":
			if not _lit():
				main.think("Наткнулся в темноте на что-то угловатое. Сундук? Не видно.")
			elif Game.flag("trunk_open"):
				main.think("Пусто. Только запах старой бумаги.")
			else:
				Game.set_flag("trunk_open")
				main.loot_win.open("Сундук прадеда", [{"id": "pass_elley", "n": 1, "name": DB.item_name("pass_elley")},
					{"id": "t_photo", "n": 1, "name": DB.item_name("t_photo")}], func(e):
					Game.add_item(e.id, int(e.get("n", 1)))
					return true)
				main.think("Под тряпьём — пластиковая карточка с фотографией. Парень в очках. Похож на деда. Очень похож.")
			return true
	return false


func item_actions(it: Interactable) -> Array:
	match String(it.name):
		"UpExit":
			return [["Подняться наверх", "use"]]
		"Candle":
			return [["Зажечь свечу (спички)" if not _lit() else "Посмотреть на свечу", "use"]]
		"Jam":
			return [["Взять банку варенья", "use"]]
		"Trunk":
			return [["Открыть сундук", "use"]]
	return []


func describe(it: Interactable) -> String:
	match String(it.name):
		"Candle":
			return "Сальная свеча в глиняной плошке." + ("" if _lit() else " Не горит.")
		"Jam":
			return "Полка с банками: брусника, морошка, грибы." if _lit() else "Что-то стеклянное на полке. Темно."
		"Trunk":
			return "Окованный сундук. Дед говорил — прадедов." if _lit() else "Что-то угловатое в темноте."
		"UpExit":
			return "Лестница к люку. Наверху — светло."
	return ""


func objective() -> String:
	if Game.quest_stage("cellar") == 1:
		return "Найти в подполе варенье." if _lit() else "Зажечь свечу (спички) и найти варенье."
	return ""
