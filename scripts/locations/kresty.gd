extends Act1Location
## Кресты — первое живое поселение за чертой.
## Задания: «Псы у выгона» (староста), «Порванные сети» (рыбак, след ведёт в лагерь
## оборванцев), след Боотура (староста, пивовар), бартер (торговка, пивовар).


func _ready() -> void:
	location_id = "kresty"
	title = "Кресты"
	arrive_thought = "kresty_arrive"
	super._ready()


func on_world_state_applied() -> void:
	_apply_dogs()


func on_enter() -> void:
	_apply_dogs()
	super.on_enter()


## Псы на выгоне появляются, когда староста попросит, и пропадают, когда перебиты
func _apply_dogs() -> void:
	var on := Game.quest_stage("kr_dogs") == 1
	for d in get_tree().get_nodes_in_group("kr_dogs"):
		var ch := d as Character
		if ch == null:
			continue
		var gone: bool = ws().dead.has(ch.uid()) or ws().misc.has("gone_" + ch.uid())
		ch.visible = (on and not gone) or ws().dead.has(ch.uid())
		ch.process_mode = Node.PROCESS_MODE_INHERIT if ch.visible else Node.PROCESS_MODE_DISABLED


func _dogs_left() -> int:
	var n := 0
	for d in get_tree().get_nodes_in_group("kr_dogs"):
		var ch := d as Character
		if ch and ch.visible and ch.pose != "dead" and not ws().misc.has("gone_" + ch.uid()):
			n += 1
	return n


func on_dialog_action(a: String, sp: Character) -> bool:
	match a:
		"dogs_start":
			_apply_dogs()
			main.hud.refresh_objective()
			return true
	return super.on_dialog_action(a, sp)


func on_combat_end(res: String, _kind: String) -> void:
	if res == "win" and Game.quest_stage("kr_dogs") == 1 and _dogs_left() == 0:
		Game.set_quest("kr_dogs", 2)
		main.think("Выгон чист. Надо сказать Прокопию.")
		main.hud.refresh_objective()


func on_interact(it: Interactable) -> bool:
	match String(it.name):
		"NetTracks":
			_tracks()
			return true
		"Cemetery":
			main.say("thoughts", "kresty_cemetery")
			return true
		"OldLarch":
			if Game.flag("larch_dug"):
				main.think("Яма под корнями. Пусто.")
			elif Game.quest_stage("son_gun") >= 1 or Game.skill_check("Внимательность", "PRC", "Внимательность", 13):
				Game.set_flag("larch_dug")
				Game.add_item("carbine")
				Game.set_quest("son_gun", 2)
				Game.grant_xp(30)
				main.think("Под корнями, в промасленной мешковине — карабин. На прикладе вырезано: «Ыйылаан». Чистый. Кто-то его берёг.")
			else:
				main.think("Старая лиственница. Под корнями земля чуть просела — или кажется.")
			return true
	return super.on_interact(it)


## Следы у сушилки: Внимательность — видно, куда ведут
func _tracks() -> void:
	var st := Game.quest_stage("kr_nets")
	if st == 0:
		main.think("Сушилки для сетей. Земля вокруг истоптана.")
		return
	if st >= 2:
		main.think("Следы уходят к реке и дальше на юг — к лесопилке.")
		return
	var ok := Game.skill_check("Внимательность", "PRC", "Внимательность", 11)
	if ok or Game.flag("tracks_try"):
		Game.set_quest("kr_nets", 2)
		Game.set_flag("kr_knows_camp")
		WorldMap.reveal("camp")
		main.say("thoughts", "kresty_tracks")
		main.hud.refresh_objective()
	else:
		# со второго раза найдёт и так — просто дольше
		Game.set_flag("tracks_try")
		main.think("Истоптано всё. Надо присмотреться получше.")


func item_actions(it: Interactable) -> Array:
	match String(it.name):
		"NetTracks":
			return [["Осмотреть следы", "use"]]
		"Cemetery":
			return [["Постоять у крестов", "use"]]
		"OldLarch":
			return [["Раскопать под корнями", "use"]] if Game.quest_stage("son_gun") == 1 and not Game.flag("larch_dug") else [["Осмотреть", "use"]]
	return super.item_actions(it)


func describe(it: Interactable) -> String:
	match String(it.name):
		"NetTracks":
			return "Вокруг сушилки для сетей натоптано."
		"Cemetery":
			return "Старый погост у западного въезда. Кресты серые, покосившиеся, на некоторых — вырезанные имена."
		"WestExit":
			return "Дорога на запад — к черте, к пепелищу."
		"EastExit":
			return "Дорога на восток. Говорят, к Сунгару."
		"OldLarch":
			return "Одинокая лиственница у восточной дороги. Ветки у самой земли обломаны."
	return ""


## Доверие Крестов: про Боотура чужому не расскажут, пока не поможешь
func dialog_cond(id: String) -> bool:
	match id:
		"kr_trust":
			# староста: выгон от псов, или сети рыбака, или добрая слава
			return Game.quest_stage("kr_dogs") >= 3 or Game.quest_stage("kr_nets") >= 6 or Game.rep() >= 25
		"brewer_trust":
			# пивовар: вернул бочонок (или честно сказал, где он), или принёс хмель
			return Game.quest_stage("barrel") >= 4 or Game.flag("keg_left") or Game.quest_stage("hops") >= 3
	return super.dialog_cond(id)


func objective() -> String:
	match Game.quest_stage("bootur"):
		1:
			return "Расспросить в Крестах про Боотура. Староста живёт на площади."
		2:
			if not dialog_cond("kr_trust"):
				return "Прокопий не расскажет про Боотура чужаку. Помочь Крестам — например, с псами на выгоне."
			return "Кресты мне теперь верят. Спросить Прокопия про Боотура."
		3:
			if not dialog_cond("brewer_trust"):
				return "Дьулусу не до Боотура: у него пропал бочонок и кончился хмель. Помочь ему."
			return "Спросить пивовара Дьулуса, куда ушёл Боотур."
		4:
			return "Сэмэн провожал Боотура — разговорить его (пиво, долг, безделушка или кулак)."
	if Game.quest_stage("kr_dogs") == 1:
		return "Перебить или отогнать псов на выгоне (северо-восток)."
	if Game.quest_stage("kr_dogs") == 2:
		return "Сказать старосте Прокопию, что выгон свободен."
	if Game.quest_stage("kr_nets") == 1:
		return "Осмотреть сушилки для сетей у реки."
	return ""
