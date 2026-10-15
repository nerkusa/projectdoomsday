extends Act1Location
## Горный (Акт IV) — спокойный посёлок под «Горизонтом»: свет круглые сутки, талоны, порядок.
## Людей забирают «на работы в Якутск», и они не возвращаются. У северной ограды бродит
## Ушан в детской вязаной шапке — мать Айаала носит ему хлеб (задание gr_feeder).
## Отсюда тракт ведёт на восток, к ГРЭС-2.

## На каком расстоянии от Ушана герой узнаёт шапку
const USHAN_SEE := 7.0


func _ready() -> void:
	location_id = "gorny"
	title = "Горный"
	arrive_thought = "Горный. Фонари горят средь бела дня, побелённые дома, ровные улицы. Сытые дети. Плакат: «„Горизонт“ заботится о вас». Слишком чисто."
	super._ready()


func status_line() -> String:
	return "2062 · Горный"


func on_enter() -> void:
	super.on_enter()
	if Game.quest_stage("act4") == 2:
		Game.set_quest("act4", 3)
	if Game.flag("gr_ushan_dead"):
		var u := character("Ushan")
		if u:
			u.visible = false
			u.process_mode = Node.PROCESS_MODE_DISABLED
	main.hud.refresh_objective()


func objective() -> String:
	match Game.quest_stage("gr_feeder"):
		1:
			return "Узнать, кто кормит мутантов у северной ограды."
		2:
			return "Решить, что делать с тайной матери Айаала."
	if Game.quest_stage("act4") == 3:
		return "Дальше на восток — к ГРЭС-2: восточный выезд или карта мира."
	return ""


func on_hero_moved(pos: Vector3) -> void:
	super.on_hero_moved(pos)
	if Game.flag("gr_saw_ushan") or Game.flag("gr_ushan_dead"):
		return
	var u := character("Ushan")
	if u and u.visible and u.global_position.distance_to(pos) < USHAN_SEE:
		Game.set_flag("gr_saw_ushan")
		main.think("За оградой — Ушан. Длинные уши, серая кожа… и красная детская шапка, аккуратно связанная. Он не рычит. Смотрит на посёлок, будто ждёт кого-то.")


func on_dialog_action(a: String, sp: Character) -> bool:
	match a:
		"gr_tell":
			main.dialog.closed.connect(_hunt, CONNECT_ONE_SHOT)
			return true
	return super.on_dialog_action(a, sp)


## Охотники идут к ограде; к утру Ушана больше нет
func _hunt() -> void:
	Game.set_flag("gr_ushan_dead")
	Game.add_note("Горный: охотники застрелили Ушана у ограды. Шапку мать забрала себе.")
	var u := character("Ushan")
	for n in ["Hunter1", "Hunter2"]:
		var h := character(n)
		if h and u:
			h.patrol = PackedVector3Array()
			h.move_along(Clock._route(self, h.global_position, Vector3(31, 0, 8)), Callable(), 3.0)
	await get_tree().create_timer(5.0, false).timeout
	main.sfx("shot_near", 0.0, 0.6)
	if u:
		u.visible = false
		u.process_mode = Node.PROCESS_MODE_DISABLED
	main.think("Два выстрела у северной ограды. Потом тишина. И тихий-тихий плач.")


func on_interact(it: Interactable) -> bool:
	match String(it.name):
		"WestExit", "EastExit":
			main.world_map.open(location_id)
			return true
	return super.on_interact(it)


func describe(it: Interactable) -> String:
	match String(it.name):
		"WestExit":
			return "Тракт на запад, к Рубикону."
		"EastExit":
			return "Тракт на восток. Над лесом — трубы ГРЭС-2."
	return ""
