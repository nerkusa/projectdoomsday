extends SungarHouse
## Общежитие № 2, 2–4 этажи. На четвёртом — Сенька-Кепка и его каморка с краденым:
## чемодан торговца Ньургуна под кроватью. Отдаст сам (запугать, уговорить, выкупить)
## или полезет с заточкой.


func _ready() -> void:
	location_id = "sungar_obshaga"
	title = "Общежитие № 2"
	super._ready()


func _thief_blocks() -> bool:
	var t := character("Thief")
	return t != null and t.visible and t.pose == "" and not t.hostile and not Game.flag("sg_thief_gave")


func on_interact(it: Interactable) -> bool:
	if String(it.name) == "Suitcase":
		_suitcase()
		return true
	return super.on_interact(it)


func _suitcase() -> void:
	if Game.item_count("suitcase") > 0 or Game.quest_stage("sg_suitcase") >= 4:
		main.think("Под кроватью теперь только пыль и пустые бутылки.")
		return
	if Game.quest_stage("sg_suitcase") < 1:
		main.think("Под кроватью — кожаный чемодан с застёжками. Не похоже на вещь Сеньки. Но и не моя.")
		return
	if _thief_blocks():
		var t := character("Thief")
		t.bark("Положь! Моё!")
		main.think("Сенька вскочил. В руке — заточка.")
		_fight()
		return
	Game.add_item("suitcase")
	Game.set_quest("sg_suitcase", 3)
	Game.log_line("Взял: Чемодан торговца", "", "hit")
	main.think("Тяжёлый. Внутри что-то глухо звякает — проволока, что ли. Отнести Ньургуну в гостиницу.")
	main.hud.refresh_objective()


func _fight() -> void:
	var t := character("Thief")
	if t == null:
		return
	main.dialog.close()
	main.start_fight([t])


func on_dialog_action(a: String, sp: Character) -> bool:
	if a == "thief_fight":
		_fight()
		return true
	return super.on_dialog_action(a, sp)


func on_combat_end(res: String, _kind: String) -> void:
	if res == "win":
		Game.set_flag("sg_thief_gave")
		if Game.quest_stage("sg_suitcase") in [1, 2]:
			Game.set_quest("sg_suitcase", 3)
		main.think("Сенька сидит у стены, держится за челюсть. Заточка под кроватью, рядом — чемодан.")


func item_actions(it: Interactable) -> Array:
	if String(it.name) == "Suitcase":
		return [["Вытащить чемодан", "use"]]
	return super.item_actions(it)


func describe(it: Interactable) -> String:
	if String(it.name) == "Suitcase":
		return "Под кроватью что-то есть — угол кожаного чемодана."
	return super.describe(it)


func objective() -> String:
	match Game.quest_stage("sg_suitcase"):
		2:
			return "Найти Сеньку-Кепку (4 этаж) и забрать чемодан Ньургуна."
		3:
			return "Забрать чемодан из каморки Сеньки и отнести Ньургуну (гостиница, 2 этаж)." if Game.item_count("suitcase") == 0 else "Отнести чемодан Ньургуну (гостиница «Вилюй», 2 этаж)."
	return bootur_objective()
