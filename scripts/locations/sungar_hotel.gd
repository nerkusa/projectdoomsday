extends SungarHouse
## Гостиница «Вилюй», 2–3 этажи. Номер 6 — герою, если заплатил дежурной (выспаться
## до утра). Номер 9 — бывший номер Боотура: под половицей его записка (сказал старый
## Арчылан — по-старому; или найти самому, если знаешь, где искать).


func _ready() -> void:
	location_id = "sungar_hotel"
	title = "Гостиница «Вилюй»"
	super._ready()


func on_interact(it: Interactable) -> bool:
	match String(it.name):
		"HotelBed":
			_bed()
			return true
		"LooseBoard":
			_board()
			return true
	return super.on_interact(it)


## Выспаться в своём номере: до утра, здоровье — полное
func _bed() -> void:
	if not Game.flag("sg_room"):
		main.think("Чужой номер. Дежурная внизу сдаёт такие по десять рублей.")
		return
	main.wait_time(true)
	Game.set_hero_hp(Game.hero_max())
	main.hud.refresh()
	main.think("Проспал как убитый. Ни налёта, ни леса — ничего не снилось. Впервые за долгое время.")


## Половица в девятом номере
func _board() -> void:
	var st := Game.quest_stage("sg_note")
	if st >= 3:
		main.think("Половица на месте. Под ней теперь только пыль.")
		return
	var knows := st >= 2
	if not knows:
		if st < 1:
			main.think("Пустой номер. Кровать без белья, на подоконнике — дохлые мухи.")
			return
		# знаешь, что Боотур жил здесь, — можно поискать самому
		if not (Game.skill_check("Внимательность", "PRC", "Внимательность", 13) or Game.flag("board_try")):
			Game.set_flag("board_try")
			main.think("Номер Боотура. Пусто. Хотя… одна половица у кровати скрипит иначе. Глянуть ещё раз.")
			return
	Game.add_item("bootur_note")
	Game.set_quest("sg_note", 3)
	Game.grant_xp(50)
	Game.add_note(str(DB.items.get("bootur_note", {}).get("read", "")))
	main.think("Поддел половицу ножом. Под ней — листок из школьной тетради. Почерк Боотура, ни с чем не спутаешь.")
	main.hud.refresh_objective()


func item_actions(it: Interactable) -> Array:
	match String(it.name):
		"HotelBed":
			return [["Лечь спать" if Game.flag("sg_room") else "Осмотреть", "use"]]
		"LooseBoard":
			return [["Осмотреть пол", "use"]]
	return super.item_actions(it)


func describe(it: Interactable) -> String:
	match String(it.name):
		"HotelBed":
			return "Железная кровать с панцирной сеткой. Номер шесть."
		"LooseBoard":
			return "Крашеные половицы, местами просевшие."
	return super.describe(it)


func objective() -> String:
	if Game.quest_stage("sg_note") in [1, 2]:
		return "Номер 9 (3 этаж): Боотур что-то оставил." if Game.quest_stage("sg_note") == 2 else "Номер 9 (3 этаж) — бывший номер Боотура. Поговорить с Арчыланом или поискать самому."
	if Game.quest_stage("sg_suitcase") == 1:
		return "Найти чемодан Ньургуна: спросить дежурную внизу."
	return bootur_objective()
