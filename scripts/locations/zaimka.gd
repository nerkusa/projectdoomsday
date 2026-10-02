extends Act1Location
## Заимка охотника Дьаакыпа. Задание «Капканы»: на севере что-то ломает капканы —
## это чучуна. У второго капкана оно выходит из чащи.


func _ready() -> void:
	location_id = "zaimka"
	title = "Заимка Дьаакыпа"
	arrive_thought = "zaimka_arrive"
	super._ready()


func on_world_state_applied() -> void:
	_apply_beast()


func on_enter() -> void:
	_apply_beast()
	super.on_enter()


## Чучуна появляется, только когда Дьаакып попросил проверить капканы и ты дошёл до второго
func _apply_beast() -> void:
	var c := character("Chuchuna")
	if c == null:
		return
	var dead: bool = ws().dead.has(c.uid())
	var on: bool = Game.flag("beast_out") and not ws().misc.has("gone_" + c.uid())
	c.visible = on or dead
	c.process_mode = Node.PROCESS_MODE_INHERIT if c.visible else Node.PROCESS_MODE_DISABLED


func on_interact(it: Interactable) -> bool:
	match String(it.name):
		"Trap1":
			if not Game.flag("trap1_seen"):
				Game.set_flag("trap1_seen")
				Game.add_item("trap_part")
				main.say("thoughts", "zaimka_trap1")
			else:
				main.think("Пустая цепь. Капкан я уже забрал.")
			return true
		"Trap2":
			if Game.quest_stage("traps") == 1 and not Game.flag("beast_out"):
				Game.set_flag("beast_out")
				_apply_beast()
				var c := character("Chuchuna")
				if c:
					main.dialog.closed.connect(func():
						if not main.combat.on and c.pose != "dead":
							main.start_fight([c]), CONNECT_ONE_SHOT)
				main.say("thoughts", "zaimka_trap2")
			elif Game.quest_stage("traps") == 0:
				main.think("Капкан сорван с цепи. Цепь перекушена. Зубами?..")
			else:
				main.think("Здесь всё и случилось.")
			return true
	return super.on_interact(it)


## Дикий хмель для Дьулуса
func on_picked(it: Interactable) -> void:
	if String(it.name).begins_with("Take_Hops") and Game.item_count("hops") >= 3 and Game.quest_stage("hops") == 1:
		Game.set_quest("hops", 2)
		main.hud.refresh_objective()


func on_combat_end(res: String, _kind: String) -> void:
	var c := character("Chuchuna")
	if res == "win" and c and (c.pose == "dead" or ws().misc.has("gone_" + c.uid())) and Game.quest_stage("traps") == 1:
		Game.set_quest("traps", 2)
		main.say("thoughts", "zaimka_beast_dead")
		main.hud.refresh_objective()


func item_actions(it: Interactable) -> Array:
	if String(it.name).begins_with("Trap"):
		return [["Осмотреть капкан", "use"]]
	return super.item_actions(it)


func describe(it: Interactable) -> String:
	match String(it.name):
		"Trap1", "Trap2":
			return "Капкан Дьаакыпа на звериной тропе."
		"WestExit":
			return "Тропа обратно на большую дорогу."
	return ""


func objective() -> String:
	match Game.quest_stage("traps"):
		1:
			return "Проверить капканы Дьаакыпа к северу от заимки."
		2:
			return "Вернуться к Дьаакыпу."
	return ""
