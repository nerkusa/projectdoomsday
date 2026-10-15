extends Act1Location
## Мирный — город контрастов (Акт III). Мёртвый карьер в центре, четыре района фракций:
## «Кимберлит» (Бельский, у него гостит покупатель), совет республиканцев (Слепцова) и
## йегеря с Судьёй, рабочие (Иванов), рейдеры (Шрам). Кому встать в союз — решает, кому
## пойдёт ток с ГЭС. Побочные: «Суд йегерей» (доносчик Гоша) и «Спуститься первым» (карьер).

## Через сколько часов после прихода йегеря казнят Петра, если никто не вмешается
const TRIAL_HOURS := 6.0


func _ready() -> void:
	location_id = "mirny"
	title = "Мирный"
	arrive_thought = "Мирный. Посреди города — воронка карьера, такая, что дна не видно. Вокруг флаги четырёх цветов, и на каждом углу кто-то с ружьём."
	super._ready()


func status_line() -> String:
	return "2062 · Мирный"


func on_enter() -> void:
	super.on_enter()
	if Game.quest_stage("act3") <= 1:
		Game.set_quest("act3", 2)
	if Game.quest_stage("mr_quarry") == 0:
		Game.set_quest("mr_quarry", 1)
	if Game.quest_stage("mr_trial") == 0:
		Game.set_quest("mr_trial", 1)
		Game.world["mr_arrived"] = Clock.hours()
	_apply_story()
	main.hud.refresh_objective()


func _hide_ch(n: String) -> void:
	var ch := character(n)
	if ch:
		ch.stop()
		ch.visible = false
		ch.process_mode = Node.PROCESS_MODE_DISABLED


func _apply_story() -> void:
	if Game.flag("mr_freed"):
		_hide_ch("Accused")
		_hide_ch("Gosha")
	elif Game.flag("mr_executed"):
		var a := character("Accused")
		if a:
			a.pose = "dead"
	if Game.flag("act4"):
		_hide_ch("Buyer")


func objective() -> String:
	match Game.quest_stage("act3"):
		2:
			return "Мирный: поговорить с лидерами фракций и встать на чью-то сторону в споре за ГЭС."
		4:
			return "Идти на плотину ГЭС — выход на восток (карта мира)."
	return ""


func on_hero_moved(pos: Vector3) -> void:
	super.on_hero_moved(pos)
	if Game.quest_stage("mr_trial") in [1, 2] and not Game.flag("mr_trial_done"):
		var t0 := float(Game.world.get("mr_arrived", Clock.hours()))
		if Clock.hours() - t0 >= TRIAL_HOURS:
			_execute()


func _execute() -> void:
	Game.set_flag("mr_trial_done")
	Game.set_flag("mr_executed")
	Game.set_quest("mr_trial", 3)
	var a := character("Accused")
	if a:
		a.pose = "dead"
		ws().dead[a.uid()] = true
	main.think("С площади донёсся сухой выстрел. Йегеря закончили суд. Пётр больше не встанет.")


func on_dialog_action(a: String, sp: Character) -> bool:
	if a == "mr_free":
		Game.set_flag("mr_trial_done")
		Game.set_flag("mr_freed")
		main.dialog.closed.connect(func():
			var p := character("Accused")
			if p:
				p.start_pose = ""
				p.pose = ""
				p.move_along(Clock._route(self, p.global_position, Vector3(26, 0, 90)), func(): _hide_ch("Accused"), 3.0)
			_hide_ch("Gosha")
			main.think("Пётр спрыгнул с помоста и побежал к баракам, не оглядываясь. Гошу увели йегеря."), CONNECT_ONE_SHOT)
		return true
	return super.on_dialog_action(a, sp)


func on_interact(it: Interactable) -> bool:
	match String(it.name):
		"WestRoad", "EastRoad":
			main.world_map.open(location_id)
			return true
		"ToQuarry":
			main.load_location("mirny_quarry", "FromTop")
			return true
		"Scaffold":
			main.think("Помост из свежих досок, столб, верёвка. Под помостом — тёмные пятна. Суд Полиса работает быстро.")
			return true
	return super.on_interact(it)


func item_actions(it: Interactable) -> Array:
	match String(it.name):
		"ToQuarry":
			return [["Спуститься в карьер", "use"]]
		"WestRoad", "EastRoad":
			return [["Уйти (карта мира)", "use"]]
	return super.item_actions(it)


func describe(it: Interactable) -> String:
	match String(it.name):
		"ToQuarry":
			return "Серпантин уходит вниз, в карьер. Ограждение здесь разобрано."
		"Scaffold":
			return "Помост для суда йегерей."
		"WestRoad":
			return "Тракт обратно на запад — к Нью-Рбе."
		"EastRoad":
			return "Дорога на восток — к плотине Вилюйской ГЭС."
	return ""
