extends Act1Location
## Ржавый конвой: разграбленный караван из Сунгара на старой дороге и засада.
## У убитого возчика — накладная (задание «Пропавший караван» для Аграфены).


func _ready() -> void:
	location_id = "convoy"
	title = "Ржавый конвой"
	arrive_thought = "convoy_arrive"
	super._ready()


func on_interact(it: Interactable) -> bool:
	match String(it.name):
		"CabSafe":
			if Game.flag("convoy_safe"):
				main.think("Пусто. Всё, что было, — у меня.")
			elif not squad_cleared("ambush"):
				main.think("Сначала — те, что за грузовиками.")
			else:
				var mech := Game.hero_stat("INT") + int(Game.effective_skills().get("Механика", 0))
				var thief := Game.hero_stat("REF") + int(Game.effective_skills().get("Воровство", 0))
				var ok := Game.skill_check("Механика", "INT", "Механика", 13) if mech >= thief else Game.skill_check("Воровство", "REF", "Воровство", 13)
				if ok or Game.flag("convoy_safe_try"):
					Game.set_flag("convoy_safe")
					main.loot_win.open("Ящик в кабине", [{"id": "medkit", "n": 1, "name": DB.item_name("medkit")},
						{"id": "ammo9", "n": 6, "name": DB.item_name("ammo9")}, {"id": "cas_surgeon", "n": 1, "name": DB.item_name("cas_surgeon")}],
						func(e):
							Game.add_item(e.id, int(e.get("n", 1)))
							return true)
				else:
					Game.set_flag("convoy_safe_try")
					main.think("Замок прикипел. Ещё раз — и поддастся.")
			return true
		"Cargo":
			if Game.flag("convoy_cargo"):
				main.think("Только щепки и рассыпанный чай.")
			else:
				Game.set_flag("convoy_cargo")
				Game.add_item("tea", 2)
				Game.add_item("salt", 1)
				Game.log_line("В разбитых ящиках: чай ×2, соль", "", "hit")
				main.say("thoughts", "convoy_cargo")
			return true
	return super.on_interact(it)


func on_looted(ch: Character) -> void:
	if ch.name == "Driver" and Game.quest_stage("caravan") in [0, 1]:
		Game.set_quest("caravan", 2)
		main.hud.refresh_objective()


func on_combat_end(res: String, _kind: String) -> void:
	if res == "win" and squad_cleared("ambush") and not Game.flag("convoy_clear"):
		Game.set_flag("convoy_clear")
		main.think("Двое. Сидели в засаде у чужого добра, как вороны.")


func item_actions(it: Interactable) -> Array:
	match String(it.name):
		"CabSafe":
			return [["Вскрыть ящик", "use"]]
		"Cargo":
			return [["Порыться", "use"]]
	return super.item_actions(it)


func describe(it: Interactable) -> String:
	match String(it.name):
		"CabSafe":
			return "Железный ящик под сиденьем, с навесным замком."
		"Cargo":
			return "Ящики разбиты топором. Растащили не всё."
		"WestExit":
			return "Дорога назад."
		"EastExit":
			return "Дорога дальше — к Сунгару."
	return ""


func objective() -> String:
	if not squad_cleared("ambush"):
		return "В засаде кто-то есть."
	if Game.quest_stage("caravan") == 1:
		return "Узнать, что с караваном: осмотреть убитого возчика."
	return ""
