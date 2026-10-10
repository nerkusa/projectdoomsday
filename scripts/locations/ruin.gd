extends Act1Location
## База на Сытыгане — довоенный объект. Весной здесь сожгли стоянку оборванцев,
## а «отдел безопасности» вывез бумаги. Карта на стене показывает закономерность:
## Нахарро и Сытыган зачёркнуты, следующий — Мар-Кун.


func _ready() -> void:
	location_id = "ruin"
	title = "База на Сытыгане"
	arrive_thought = "ruin_arrive"
	super._ready()


func on_interact(it: Interactable) -> bool:
	match String(it.name):
		"WallMap":
			main.say("thoughts", "ruin_map")
			if not Game.flag("ruin_map"):
				Game.set_flag("ruin_map")
				if Game.quest_stage("who") < 4:
					Game.set_quest("who", 4)
				WorldMap.reveal("markun")
				Game.add_note("База на Сытыгане: карта района с карандашными пометками. Нахарро — зачёркнуто, стоянка у Сытыгана — зачёркнута, Мар-Кун — обведён дважды. Рядом: «ждать проводника».")
				Game.grant_xp(80)
			return true
		"Terminal":
			if Game.flag("ruin_terminal"):
				main.say("thoughts", "ruin_terminal_again")
			elif Game.skill_check("Техника", "INT", "Техника", 12) or Game.flag("ruin_terminal_try"):
				Game.set_flag("ruin_terminal")
				main.say("thoughts", "ruin_terminal")
				Game.add_note("Терминал на Сытыгане: «Отдел безопасности. Изъятие документации завершено 14.04.2062. Объект списан». Внизу экрана: «Сотрудников на объекте: 0. Уволить сотрудника? [Д/Н]».")
				Game.grant_xp(40)
			else:
				Game.set_flag("ruin_terminal_try")
				main.think("Экран мигает зелёным и гаснет. Надо понять, как он включается.")
			return true
		"BunkerGate":
			if Game.flag("bunker_gate_open"):
				main.load_location("ruin_bunker", "Gate")
			elif Game.item_count("crowbar") > 0 and (Game.skill_check("Атлетика", "BODY", "Атлетика", 12) or Game.flag("gate_pry_try")):
				Game.set_flag("bunker_gate_open")
				Game.grant_xp(30)
				_apply_gate()
				main.think("Вогнал монтировку в щель, навалился всем весом. Диск скрежетнул — и пополз в сторону. Из темноты пахнуло холодом и машинным маслом.")
			elif Game.item_count("crowbar") > 0:
				Game.set_flag("gate_pry_try")
				main.think("Монтировка соскочила. Щель шире на палец. Ещё раз — и пойдёт.")
			else:
				main.think("Гермоворота «Сытыган-14». Заклинило: щель в ладонь. Монтировкой бы поддеть. Или открыть изнутри — если там есть ток.")
			return true
		"ContainerUse":
			main.think("Пустой контейнер. На двери бирка: «Сдать: отдел безопасности. Опись прилагается». Описи нет.")
			return true
		"Papers":
			if not Game.flag("ruin_papers"):
				Game.set_flag("ruin_papers")
				main.say("thoughts", "ruin_papers")
			else:
				main.think("Обгорелые листы. Ничего больше не разобрать.")
			return true
		"Burnt":
			main.say("thoughts", "ruin_burnt")
			return true
		"Shaft":
			if Game.flag("shaft_rope") and String(it.get_meta("act", "")) == "untie":
				Game.set_flag("shaft_rope", false)
				Game.add_item("rope")
				Game.log_line("Отвязал верёвку.", "", "hit")
			elif Game.flag("shaft_rope"):
				main.load_location("ruin_bunker", "Down")
			elif Game.item_count("rope") > 0:
				Game.set_flag("shaft_rope")
				Game.remove_item("rope")
				Game.log_line("Верёвка привязана к решётке шахты.", "", "hit")
				main.think("Сорвал ржавую решётку, обвязал верёвку за скобу. Внизу — темнота и красный отсвет. Аварийный свет? Через пятьдесят лет?")
				_descend_later()
			else:
				main.think("Шахта уходит вниз, метров на пять. Без верёвки — только сломать ноги.")
			return true
	return super.on_interact(it)


func on_world_state_applied() -> void:
	super.on_world_state_applied()
	_apply_gate()


func on_enter() -> void:
	super.on_enter()
	_apply_gate()


## Гермоворота на пандусе: открыты или закрыты
func _apply_gate() -> void:
	var g := get_node_or_null("Village/BunkerPortal")
	if g:
		g.get_node("GateOpen").visible = Game.flag("bunker_gate_open")
		g.get_node("GateClosed").visible = not Game.flag("bunker_gate_open")


## спуск чуть погодя, чтобы успеть прочесть мысль (on_interact сам ждать не должен)
func _descend_later() -> void:
	await get_tree().create_timer(1.2, false).timeout
	if main.location == self and not main.combat.on:
		main.load_location("ruin_bunker", "Down")


func on_combat_end(res: String, _kind: String) -> void:
	if res == "win" and squad_cleared("diggers") and not Game.flag("ruin_clear"):
		Game.set_flag("ruin_clear")
		main.think("Копатели. Рылись в том, что не успели увезти другие.")


func item_actions(it: Interactable) -> Array:
	match String(it.name):
		"WallMap":
			return [["Рассмотреть карту", "use"]]
		"Terminal":
			return [["Включить терминал", "use"]]
		"ContainerUse", "Papers", "Burnt":
			return [["Осмотреть", "use"]]
		"BunkerGate":
			if Game.flag("bunker_gate_open"):
				return [["Спуститься в бункер", "use"]]
			return [["Поддеть монтировкой" if Game.item_count("crowbar") > 0 else "Открыть (нужна монтировка)", "use"]]
		"Shaft":
			if Game.flag("shaft_rope"):
				return [["Спуститься по верёвке", "use"], ["Отвязать верёвку", "use:untie"]]
			return [["Обвязать верёвку и спуститься" if Game.item_count("rope") > 0 else "Спуститься (нужна верёвка)", "use"]]
	return super.item_actions(it)


func describe(it: Interactable) -> String:
	match String(it.name):
		"WallMap":
			return "Под навесом у двери — карта района, приколотая ржавыми кнопками."
		"Terminal":
			return "Довоенный терминал в нише стены. Экран целый."
		"BunkerGate":
			return "Пандус уходит вниз, к круглым гермоворотам. " + ("Ворота открыты." if Game.flag("bunker_gate_open") else "Закрыты, но не до конца: щель в ладонь.")
		"ContainerUse":
			return "Морской контейнер, двери нараспашку."
		"Papers":
			return "Ветер гоняет по двору обгорелые листы."
		"Burnt":
			return "Пепелище за оградой — круги от палаток."
		"Shaft":
			return "Вентиляционная шахта бункера. " + ("Моя верёвка уходит вниз." if Game.flag("shaft_rope") else "Решётка проржавела.")
		"WestExit":
			return "Дорога назад."
	return ""


func objective() -> String:
	if not squad_cleared("diggers"):
		return "Во дворе копатели — злые и вооружённые."
	if not Game.flag("ruin_map"):
		return "Осмотреть базу: что здесь искали?"
	return ""
