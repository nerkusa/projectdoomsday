extends Act1Location
## Кресты — первое живое поселение за чертой.
## Задания: «Псы у выгона» (староста), «Порванные сети» (рыбак, след ведёт в лагерь
## оборванцев), след Боотура (староста, пивовар), бартер (торговка, пивовар),
## «Баня по-чёрному» (дрова с поленниц), «Железо для кузни» (лом с дорог),
## «Жетон лётчика» (бабка Мотрёна, самолёт в тайге), «Письмо в Кресты» (почтальон в пути).
## Жители живут по распорядку (data/schedules.json): днём — дела, ночью спят по избам.


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
	_kid_home()


## Привёл мальчишку из леса — Кресты встречают его сами, без расспросов
func _kid_home() -> void:
	if Game.quest_stage("lost_kid") != 1:
		return
	Game.set_quest("lost_kid", 2)
	Game.add_item("dried_fish", 2)
	Game.add_item("beer")
	Game.grant_xp(80)
	Game.change_rep(10, "вернул мальчишку в Кресты")
	main.think("«Мичээр? Нашёлся?! Анна! Анна, сын твой!..» Через минуту на площади — женщина в слезах, мальчишка у неё на шее. Мне суют в руки вяленую рыбу и кружку пива.")


## Псы на выгоне появляются, когда староста попросит, и пропадают, когда перебиты
func _apply_dogs() -> void:
	var on := Game.quest_stage("kr_dogs") == 1
	# пастух на выгон не ходит, пока там псы
	var hd := character("Herder")
	if hd:
		hd.visible = not on
		hd.process_mode = Node.PROCESS_MODE_INHERIT if not on else Node.PROCESS_MODE_DISABLED
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
		"banya_steam":
			main.dialog.close()
			_steam()
			return true
	return super.on_dialog_action(a, sp)


func on_combat_end(res: String, _kind: String) -> void:
	if res == "win" and Game.quest_stage("kr_dogs") == 1 and _dogs_left() == 0:
		Game.set_quest("kr_dogs", 2)
		main.think("Выгон чист. Надо сказать Прокопию.")
		main.hud.refresh_objective()


func on_interact(it: Interactable) -> bool:
	if on_interact_extra(String(it.name)):
		return true
	match String(it.name):
		"NetTracks":
			_tracks()
			return true
		"Cemetery":
			main.say("thoughts", "kresty_cemetery")
			return true
		"Banya":
			if Game.quest_stage("kr_banya") >= 2:
				_steam()
			else:
				main.think("Чёрная от сажи баня у самой воды. Холодная. Банщица говорит — дров нет.")
			return true
		"Chapel":
			main.think("Часовня: сруб, луковка, медный крест. Внутри — лампадка и икона, тёмная до черноты. Кто-то недавно поставил свечу." +
				(" Странники, наверное, дошли." if Game.flag("pilgrims_fed") else ""))
			return true
		"Anvil":
			main.think("Наковальня, сбитая до блеска. Рядом — молоты, клещи, кадка с водой. В кадке — обломок крыла с красной полосой." if Game.quest_stage("kr_iron") >= 2
				else "Наковальня на дубовом чурбаке. Железа рядом — ни куска.")
			return true
		"HeadPhoto":
			main.think("Фотография в рамке: молодой Прокопий в форме речника, у парохода «Сунтар». Под стеклом — засушенный цветок.")
			return true
		"KidStash":
			main.think("Под крыльцом — тайник Уйгуна: перо сокола, гильза, вырезка из журнала с самолётом, стёклышко. Сокровища. Положил как было.")
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
## Поленницы: охапка дров для бани — по одной с каждой
func _woodpile(n: String) -> void:
	if Game.quest_stage("kr_banya") != 1:
		main.think("Поленница. Чужие дрова без спросу не трогают.")
		return
	if ws().misc.has("wood_" + n):
		main.think("Отсюда я уже брал. Хозяин и так косится.")
		return
	ws().misc["wood_" + n] = true
	Game.add_item("firewood")
	Game.log_line("Взял: Охапка дров", "", "hit")
	main.think("Охапка берёзовых поленьев. Сухие, звонкие. Для бани." if Game.item_count("firewood") < 3 else "Три охапки. Хватит — нести банщице.")
	main.hud.refresh_objective()


## Баня: раз в сутки — здоровье полностью, час времени
func _steam() -> void:
	if int(Game.flag_value("steamed_day", -1)) == Clock.day():
		main.think("Сегодня я уже парился. Второй раз — сердце выскочит.")
		return
	Game.set_flag("steamed_day", Clock.day())
	Clock.advance(1.0)
	Game.set_hero_hp(Game.hero_max())
	main.hud.refresh()
	main.think("Жар по-чёрному, дым под потолком, берёзовый веник. Потом — в реку, и обратно. Вышел другим человеком.")


func on_interact_extra(n: String) -> bool:
	if n.begins_with("Woodpile"):
		_woodpile(n)
		return true
	return false


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
	if String(it.name).begins_with("Woodpile"):
		return [["Взять охапку дров", "use"]] if Game.quest_stage("kr_banya") == 1 else [["Осмотреть", "use"]]
	match String(it.name):
		"NetTracks":
			return [["Осмотреть следы", "use"]]
		"Cemetery":
			return [["Постоять у крестов", "use"]]
		"Banya":
			return [["Попариться", "use"]] if Game.quest_stage("kr_banya") >= 2 else [["Осмотреть", "use"]]
		"Chapel", "Anvil", "HeadPhoto":
			return [["Осмотреть", "use"]]
		"KidStash":
			return [["Заглянуть под крыльцо", "use"]]
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
		"Banya":
			return "Баня по-чёрному у самой реки: сруб в саже, кадка, веники под стрехой."
		"Chapel":
			return "Старая часовня у погоста. Луковка из жести, крест восьмиконечный."
		"Anvil":
			return "Наковальня у кузницы Мэхээлэ."
		"HeadPhoto":
			return "В избе старосты на стене — фотография в рамке."
		"KidStash":
			return "Под крыльцом что-то спрятано — щель заложена дощечкой."
	if String(it.name).begins_with("Woodpile"):
		return "Поленница у избы, дрова берёзовые."
	return ""


## Доверие Крестов: про Боотура чужому не расскажут, пока не поможешь
func dialog_cond(id: String) -> bool:
	match id:
		"kr_trust":
			# староста: выгон от псов, или сети рыбака, или добрая слава
			return Game.quest_stage("kr_dogs") >= 3 or Game.quest_stage("kr_nets") >= 6 or Game.rep() >= 25
		"scrap3":
			return Game.item_count("scrap_iron") >= 3
		"wood3":
			return Game.item_count("firewood") >= 3
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
	if Game.quest_stage("kr_banya") == 1:
		return "Набрать дров для бани: по охапке с поленниц у изб (%d из 3)." % Game.item_count("firewood")
	if Game.quest_stage("kr_letter") == 1:
		return "Отдать письмо Аграфене — торговке на площади."
	if Game.quest_stage("kr_pilot") == 1 and Game.item_count("pilot_tag") > 0:
		return "Отнести жетон лётчика бабке Мотрёне."
	return ""
