extends MirnyDistrict
## Мирный · совет республиканцев и штаб йегерей. Площадь суда с помостом: Судья в тигриной
## шкуре, Пётр по доносу Гоши. Слепцова в здании совета.


func _ready() -> void:
	location_id = "mirny_republic"
	title = "Мирный · совет и йегеря"
	links = {"ToCenter": ["mirny", "FromRepublic", "Центр"]}
	arrive_thought = "Район совета. Синие флаги, на стенах — «Выборы — людям». А посреди площади — помост с верёвкой, и йегеря вокруг."
	super._ready()


func on_dialog_action(a: String, sp: Character) -> bool:
	if a == "mr_free":
		Game.set_flag("mr_trial_done")
		Game.set_flag("mr_freed")
		main.dialog.closed.connect(func():
			var p := character("Accused")
			if p:
				p.start_pose = ""
				p.pose = ""
				p.move_along(Clock._route(self, p.global_position, spawn_point("FromCenter")), func(): _hide_ch("Accused"), 3.0)
			_hide_ch("Gosha")
			main.think("Пётр спрыгнул с помоста и побежал к своим, в рабочий посёлок, не оглядываясь. Гошу увели йегеря."), CONNECT_ONE_SHOT)
		return true
	return super.on_dialog_action(a, sp)


func on_interact(it: Interactable) -> bool:
	match String(it.name):
		"Scaffold":
			main.think("Помост из свежих досок, столб, верёвка. Под помостом — тёмные пятна. Суд Полиса работает быстро.")
			return true
		"Lists":
			main.think("«Списки пособников „Горизонта“». Фамилии, адреса, приписки от руки: «со слов соседа», «видели с дружинником». Половина зачёркнута. Красным.")
			return true
	return super.on_interact(it)


func item_actions(it: Interactable) -> Array:
	match String(it.name):
		"Scaffold", "Lists":
			return [["Осмотреть", "use"]]
	return super.item_actions(it)


func describe(it: Interactable) -> String:
	match String(it.name):
		"Scaffold":
			return "Помост для суда йегерей."
		"Lists":
			return "Доска со списками на стене штаба."
	return super.describe(it)
