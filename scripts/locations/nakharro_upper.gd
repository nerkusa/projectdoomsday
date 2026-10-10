extends Location
## Вторые этажи двухэтажных изб Нахарро. Светёлки лежат в одной сцене рядом
## (tools/build_act1.gd, _upper), видна только та, где стоит герой.
## Izba5 — Туйгун с самодельным приёмником (задание «Эфир»),
## Izba9 — бабушкина светёлка со станком (там прячется Кюннэй, «Прятки»),
## Izba13 — учительница Айыына и книги («Четвёртый том»).

const ROOMS := {"Izba5": Rect2(0, 0, 5.4, 4.6), "Izba9": Rect2(12, 0, 5.4, 4.6), "Izba13": Rect2(24, 0, 7.4, 4.4)}
const NAMES := {"Izba5": "светёлка Туйгуна", "Izba9": "бабушкина светёлка", "Izba13": "светёлка учительницы"}

var cur := ""


func _ready() -> void:
	location_id = "nakharro_upper"
	title = "Нахарро · светёлка"


func room_at(p: Vector3) -> String:
	for k in ROOMS:
		if (ROOMS[k] as Rect2).grow(1.0).has_point(Vector2(p.x, p.z)):
			return k
	return "Izba5"


func status_line() -> String:
	return "2062 · конец лета · " + str(NAMES.get(cur, "светёлка"))


func uses_clock_light() -> bool:
	return false


func on_world_state_applied() -> void:
	if main and main.player:
		_show(room_at(main.player.global_position))


func on_enter() -> void:
	_show(room_at(main.player.global_position))


## Показать светёлку k: её стены, вещи и людей; остальные спрятать
func _show(k: String) -> void:
	cur = k
	var vil := get_node_or_null("Village")
	if vil:
		for c in vil.get_children():
			(c as Node3D).visible = String(c.name) == "Room_" + k
	for it in items():
		var mine := room_at(it.global_position) == k
		it.visible = mine and not ws().picked.has(it.uid())
		it.set_active(it.visible)
	for ch in characters():
		if ch == main.player:
			continue
		var on := room_at(ch.global_position) == k and _allowed(ch)
		ch.visible = on
		ch.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED
	if main and main.hud:
		main.hud._status.text = main.status_text()


## Кюннэй сидит за станком, только пока идут прятки и её не нашли
func _allowed(ch: Character) -> bool:
	if ws().misc.has("gone_" + ch.uid()):
		return false
	if ch.name == "HideKid3":
		return Game.quest_stage("hide_seek") == 1 and not Game.flag("hs_3")
	return true


func on_dialog_action(a: String, sp: Character) -> bool:
	if a == "hs_leave" and sp:
		ws().misc["gone_" + sp.uid()] = true
		sp.visible = false
		sp.process_mode = Node.PROCESS_MODE_DISABLED
		main.think("Кюннэй шмыгает мимо и топочет вниз по стремянке.")
		return true
	return false


func on_interact(it: Interactable) -> bool:
	var n := String(it.name)
	if n.begins_with("Down_"):
		main.load_location("nakharro", "FromUp_" + n.substr(5))
		return true
	match n:
		"RoofWindow":
			_antenna()
		"Receiver":
			if Game.flag("radio_fixed"):
				main.think("Лампы светятся зелёным. В наушниках — шип и далёкий треск, как дождь по крыше.")
			else:
				main.think("Три приёмника в одном ящике, лампы, катушки, батарея от трактора. Без антенны — только шип.")
		"Loom":
			main.think("Ткацкий станок. На нём — недотканый половик: красные, белые, синие полосы, как на сэлэ.")
		"Dowry":
			main.think("Сундук, окованный медью. Приданое — бабушка копит внучкам. Не моё.")
		"HerbRack":
			if Game.flag("upper_herbs"):
				main.think("Травы сохнут дальше. Больше брать не стану.")
			else:
				Game.set_flag("upper_herbs")
				Game.add_item("herbs")
				Game.log_line("Взял: Сушёные травы", "", "hit")
				main.think("Пучок тысячелистника и иван-чая. Бабушка не обеднеет — у неё тут на всю деревню.")
		"Globe":
			main.think("Глобус, выцветший до бежевого. Якутия — жёлтое пятно, исчерканное карандашом. Нахарро на нём нет. Моря — много.")
		"Blackboard":
			main.think("«2062. Август. Жи — ши пиши с буквой и». Ниже — детские каракули: самолёт и человечек с ружьём.")
		"Shelves":
			main.think("Книги до потолка: учебники, «Справочник фельдшера», «Тракторы ДТ-75», сказки, Пушкин без обложки. На одной полке — пустое место для четвёртого тома.")
		_:
			return false
	return true


## Слуховое окно: поправить мачту антенны (нужна проволока от мастера Тимира)
func _antenna() -> void:
	if Game.flag("radio_fixed"):
		main.think("Мачта стоит прямо. Ветер гудит в растяжках.")
		return
	if Game.quest_stage("radio") < 1:
		main.think("Слуховое окно. За ним — скат крыши и мачта антенны, завалившаяся набок.")
		return
	if Game.item_count("copper_wire") == 0:
		main.think("Мачта висит на одной растяжке. Без проволоки не закрепить — у мастера Тимира был моток.")
		return
	if not Game.flag("antenna_try") and not Game.skill_check("Механика", "INT", "Механика", 10):
		Game.set_flag("antenna_try")
		main.think("Проволока соскользнула с крюка, чуть не уехал с крыши сам. Ещё раз — аккуратнее.")
		return
	Game.remove_item("copper_wire")
	Game.set_flag("radio_fixed")
	Game.set_quest("radio", 2)
	Game.grant_xp(30)
	main.think("Вылез на скат, поднял мачту, притянул растяжками к коньку. Туйгун внизу орёт: «Есть! Есть сигнал!»")
	main.hud.refresh_objective()


func item_actions(it: Interactable) -> Array:
	var n := String(it.name)
	if n.begins_with("Down_"):
		return [["Спуститься вниз", "use"]]
	match n:
		"RoofWindow":
			if Game.quest_stage("radio") >= 1 and not Game.flag("radio_fixed"):
				return [["Починить антенну (проволока)" if Game.item_count("copper_wire") > 0 else "Починить антенну (нужна проволока)", "use"]]
			return [["Выглянуть", "use"]]
		"HerbRack":
			return [["Взять пучок", "use"]] if not Game.flag("upper_herbs") else [["Осмотреть", "use"]]
	return [["Осмотреть", "use"]]


func describe(it: Interactable) -> String:
	match String(it.name):
		"RoofWindow":
			return "Слуховое окно. Через него — на крышу, к мачте антенны."
		"Receiver":
			return "Самодельный приёмник Туйгуна: ящик, лампы, шкала со стрелкой."
		"Loom":
			return "Ткацкий станок бабушки."
		"Dowry":
			return "Сундук с приданым."
		"HerbRack":
			return "Пучки трав на верёвке под потолком."
		"Globe":
			return "Довоенный глобус на латунной ножке."
		"Blackboard":
			return "Школьная доска, исписанная мелом."
		"Shelves":
			return "Полки с книгами основателей."
	if String(it.name).begins_with("Down_"):
		return "Люк вниз. Стремянка скрипит."
	return ""
