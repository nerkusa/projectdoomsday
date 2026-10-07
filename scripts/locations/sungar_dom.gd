extends SungarHouse
## Дом на площади (ул. Ленина, 3), 2–4 этажи. Учительница Сахая учит старому языку;
## у Айталы болен сын; радиолюбитель Кеша слушает эфир — и слышал позывной «Кирк».


func _ready() -> void:
	location_id = "sungar_dom"
	title = "Дом на площади"
	super._ready()


func on_interact(it: Interactable) -> bool:
	if String(it.name) == "RadioSet":
		if Game.flag("sg_kesha_wire"):
			main.think("Рация гудит ровно. Кеша поднял антенну на крыше — и сидит, не дышит: слушает восток.")
		else:
			main.think("Самодельная рация: лампы, катушки, паяные провода. Из динамика — шипение и обрывки морзянки.")
		return true
	return super.on_interact(it)


func item_actions(it: Interactable) -> Array:
	if String(it.name) == "RadioSet":
		return [["Послушать", "use"]]
	return super.item_actions(it)


func describe(it: Interactable) -> String:
	if String(it.name) == "RadioSet":
		return "Рация радиолюбителя Кеши. Трогать не надо — он смотрит."
	return super.describe(it)


func on_dialog_action(a: String, sp: Character) -> bool:
	if a == "sakha_lesson":
		main.dialog.close()
		Clock.advance(3.0)
		Game.set_flag("sakha_learned")
		Game.set_quest("sg_lessons", 2)
		Game.grant_xp(40)
		main.hud.refresh()
		main.think("Три часа над тетрадкой. «Махтал», «дорообо», «билэбин»… Слова, которые говорил дед, — теперь понятно, что они значат.")
		return true
	return super.on_dialog_action(a, sp)


func objective() -> String:
	if Game.quest_stage("sg_medicine") == 1:
		return "Сыну Айталы (3 этаж) нужна аптечка или травы от жара."
	if Game.quest_stage("sg_lessons") == 1 and Game.quest_stage("sg_medicine") == 2:
		return "Сказать Сахае (2 этаж), что мальчику лучше."
	return bootur_objective()
