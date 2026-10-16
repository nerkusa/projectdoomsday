extends Act1Location
## Мар-Кун — финал Акта I. У ручья ждут проводника чистильщики. Исходы:
##  • убедить начальника участка (бумаги про «список Б», Убеждение, Знания или слово Инструктора)
##    и увести людей тропой на юг — или держаться вместе: сменные стреляют в бою;
##  • прокрасться к палатке и стащить список целей (Воровство);
##  • ничего не делать — через пару часов серые идут на участок сами.
## Когда серых нет (перебиты или ушли), Акт I кончается: список ведёт в Нью-Рбу.

## Через сколько часов после прихода серые теряют терпение
const PATIENCE := 2.0
## Сколько урона за раунд даёт сменный при обороне
const HUNTER_DMG := Vector2i(2, 4)
const PROOF_ITEMS := ["list_b", "ledger_page", "archive_printout", "merc_order", "target_list"]
const FOLK := ["Chief", "Instructor", "Hunter1", "Hunter2", "Hunter3", "Woman1", "Woman2", "Woman3", "Old1", "Herder", "Kid1"]


func _ready() -> void:
	location_id = "markun"
	title = "Мар-Кун"
	arrive_thought = "Мар-Кун. Ржавые контейнеры вместо изб, дым над землянками, мох да камень. А у ручья — серые палатки. Те самые."
	super._ready()


func status_line() -> String:
	return "2062 · Мар-Кун"


func on_enter() -> void:
	super.on_enter()
	if Game.quest_stage("markun") == 0:
		Game.set_quest("markun", 1)
		Game.world["mk_arrived"] = Clock.hours()
	_check_proof()
	_apply_state()
	main.hud.refresh_objective()


func _check_proof() -> void:
	for k in PROOF_ITEMS:
		if Game.item_count(k) > 0:
			Game.set_flag("mk_proof")


## Положение дел после загрузки: ушедшие жители спрятаны, серые — враги, если уже идут
func _apply_state() -> void:
	if Game.flag("mk_evac") and not Game.flag("mk_done"):
		for n in FOLK:
			_hide(character(n))
	if Game.flag("mk_attack") and not Game.flag("mk_done"):
		_cleaners_hostile()
	if Game.flag("mk_gone"):
		for ch in characters():
			if ch.squad == "mk_cleaners" and ch.pose != "dead":
				_hide(ch)


func _hide(ch: Character) -> void:
	if ch == null:
		return
	ch.stop()
	ch.visible = false
	ch.process_mode = Node.PROCESS_MODE_DISABLED


func _cleaners_hostile() -> void:
	for ch in characters():
		if ch.squad == "mk_cleaners" and ch.pose != "dead" and ch.visible:
			ch.hostile = true
			ch.aggro_radius = 9.0


func objective() -> String:
	match Game.quest_stage("markun"):
		1:
			return "Предупредить Мар-Кун: начальник участка — у огня планёрки."
		2:
			return "Доказать начальнику участка, что серые пришли убивать: бумаги, слово Инструктора — или стащить их список из палатки."
		3:
			return "Начальник ждёт решения: увести людей тропой или держаться вместе."
		4:
			return "Серые идут на участок."
	if Game.flag("act2"):
		return "Идти в Нью-Рбу — через мост на Вилюе (карта мира)."
	return ""


func on_dialog_action(a: String, sp: Character) -> bool:
	match a:
		"mk_evacuate":
			Game.set_flag("mk_evac")
			Game.change_rep(4, "увёл людей Мар-Куна от серых")
			main.dialog.closed.connect(_evacuate, CONNECT_ONE_SHOT)
			return true
		"mk_defend":
			Game.set_flag("mk_defend")
			main.dialog.closed.connect(func(): _attack("Сменные встали за контейнерами, ружья наготове. От ручья поднялись серые."), CONNECT_ONE_SHOT)
			return true
	return super.on_dialog_action(a, sp)


## Люди уходят цепочкой к тропе на юг и пропадают из виду; серые идут на пустой участок
func _evacuate() -> void:
	var trail := spawn_point("Trail")
	for n in FOLK:
		var ch := character(n)
		if ch == null or not ch.visible:
			continue
		ch.patrol = PackedVector3Array()
		var c := ch
		ch.move_along(Clock._route(self, ch.global_position, trail), func(): _hide(c), 3.2)
	main.think("Мар-Кун уходит молча: дети, старики, сменные с ружьями. Инструктор несёт лист в раме, как икону.")
	await get_tree().create_timer(6.0, false).timeout
	_attack("От ручья поднялись серые — идут на пустой участок.")


func _attack(thought: String) -> void:
	if Game.flag("mk_attack") or Game.flag("mk_done"):
		return
	Game.set_flag("mk_attack")
	Game.set_quest("markun", 4)
	_cleaners_hostile()
	var fire := Vector3(50, 0, 44)
	for ch in characters():
		if ch.squad == "mk_cleaners" and ch.pose != "dead" and ch.visible:
			ch.move_along(Clock._route(self, ch.global_position, fire + Vector3(randf_range(-4, 4), 0, randf_range(-4, 4))), Callable(), 2.6)
	main.think(thought)
	main.hud.refresh_objective()


func on_hero_moved(pos: Vector3) -> void:
	super.on_hero_moved(pos)
	if Game.flag("mk_done") or Game.flag("mk_attack"):
		_maybe_leave()
		return
	# серые теряют терпение
	var t0 := float(Game.world.get("mk_arrived", Clock.hours()))
	if Clock.hours() - t0 >= PATIENCE:
		_attack("Серые не дождались проводника. Поднялись от ручья — и пошли на участок.")


## Люди ушли, а серые, обшарив пустой участок, уходят сами, если герой не попался
func _maybe_leave() -> void:
	if Game.flag("mk_done") or not Game.flag("mk_evac") or main.combat.on:
		return
	var t := float(Game.world.get("mk_search", -1.0))
	if t < 0.0:
		Game.world["mk_search"] = Clock.hours()
		return
	if Clock.hours() - t >= 1.0:
		Game.set_flag("mk_gone")
		for ch in characters():
			if ch.squad == "mk_cleaners" and ch.pose != "dead":
				_hide(ch)
		main.think("Серые обшарили пустые контейнеры, постреляли собак — и ушли на восток. Мар-Кун цел: люди живы.")
		_resolve()


func on_combat_round(r: int) -> void:
	if not Game.flag("mk_defend"):
		return
	for n in ["Hunter1", "Hunter2", "Hunter3"]:
		var h := character(n)
		if h == null or not h.visible or h.pose == "dead":
			continue
		var es: Array = main.combat.enemies()
		if es.is_empty():
			return
		var tgt = es[randi() % es.size()]
		main.combat.ally_hit(tgt, randi_range(HUNTER_DMG.x, HUNTER_DMG.y), h.display_name)


func on_combat_end(res: String, kind: String) -> void:
	super.on_combat_end(res, kind)
	if res == "win" and squad_cleared("mk_cleaners") and not Game.flag("mk_done"):
		main.think("Тихо. Только огонь трещит. Серых больше нет.")
		_resolve()


func _resolve() -> void:
	if Game.flag("mk_done"):
		return
	Game.set_flag("mk_done")
	Game.set_quest("markun", 5)
	Game.grant_xp(300)
	Game.change_rep(8, "отстоял Мар-Кун")
	Game.add_note("Мар-Кун: серых больше нет. В их бумагах — «список Б»: Нахарро сдал проводник «Б.», платили через казначейство Нью-Рбы, «А. П.». Следующий этап у них — Нью-Рба, встреча с покупателем.")
	await get_tree().create_timer(2.5, false).timeout
	_end_act()


## Конец Акта I: слайды, Нью-Рба открывается на карте
func _end_act() -> void:
	if Game.flag("act2"):
		return
	Game.set_flag("act2")
	Game.set_quest("act2", 1)
	WorldMap.reveal("nyurba")
	main.hud.refresh_objective()
	main.autosave()
	main.slides.play(DB.intro.get("act1_end", ["Конец первого акта."]))


func on_interact(it: Interactable) -> bool:
	match String(it.name):
		"WestExit":
			main.world_map.open(location_id)
			return true
		"Shrine":
			main.think("«Инструкция по технике безопасности. Пункт 1. Посторонним вход воспрещён. Пункт 2. При угрозе — эвакуация по утверждённому плану…» Лист пожелтел, буквы обведены углём много раз.")
			return true
		"Tent":
			_tent()
			return true
		"Radio":
			if Game.flag("mk_radio"):
				main.think("Рация молчит. Лампа выдрана — я постарался.")
			elif Game.flag("mk_attack") or Game.skill_check("Механика", "INT", "Механика", 12, 2 if Game.hero.get("sneak", false) else 0):
				Game.set_flag("mk_radio")
				main.think("Выкрутил лампу из рации. Подмогу серые теперь не позовут.")
			else:
				main.think("Рация гудит, на шкале пляшет стрелка. Не понять, что тут крутить, — а часовой рядом.")
			return true
	return super.on_interact(it)


## Палатка серых: пока они не всполошились — стащить список целей
func _tent() -> void:
	if Game.flag("mk_tent"):
		main.think("В палатке пусто — всё, что было нужно, у меня.")
		return
	if Game.flag("mk_attack"):
		Game.set_flag("mk_tent")
		Game.add_item("target_list")
		Game.set_flag("mk_proof")
		main.think("Пока серые на участке, обшарил палатку. Планшет в чехле — их список целей.")
		return
	var sneak: bool = Game.hero.get("sneak", false)
	if Game.skill_check("Воровство", "REF", "Воровство", 13, 2 if sneak else -2):
		Game.set_flag("mk_tent")
		Game.add_item("target_list")
		Game.set_flag("mk_proof")
		main.think("Отогнул полог, нашарил планшет — и назад, к камням. Никто не обернулся. Теперь начальнику участка будет что показать.")
		Game.grant_xp(80)
	else:
		main.think("Полог зашуршал. «Кто там?!» — серые вскочили.")
		_attack("Меня заметили у палатки. Серые схватились за оружие.")


func item_actions(it: Interactable) -> Array:
	match String(it.name):
		"Tent":
			return [["Пошарить в палатке", "use"]]
		"Radio":
			return [["Испортить рацию", "use"]]
		"Shrine":
			return [["Прочитать", "use"]]
	return super.item_actions(it)


func describe(it: Interactable) -> String:
	match String(it.name):
		"Shrine":
			return "Лист в раме на столбе, вокруг — амулеты из радиоплат."
		"Tent":
			return "Серая армейская палатка, у входа ящики."
		"Radio":
			return "Полевая рация на треноге, светится шкала."
		"WestExit":
			return "Дорога обратно на тракт."
	return ""
