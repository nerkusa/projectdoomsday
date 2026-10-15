extends Act1Location
## ГРЭС-2 у Якутска (Акт IV): кратер, мёртвые трубы, пост «Горизонта» и будка лифта.
## С пропуском «все объекты» пост пропускает — иначе пробиваться. Лифт ведёт вниз, в комплекс.


func _ready() -> void:
	location_id = "yakutsk"
	title = "ГРЭС-2"
	arrive_thought = "ГРЭС-2. Три трубы в красно-белых кольцах — мёртвые, ни дымка. А под ногами гудит: внизу что-то работает. У будки лифта — пост «Горизонта»."
	super._ready()


func status_line() -> String:
	return "2062 · Якутск, ГРЭС-2"


func on_enter() -> void:
	super.on_enter()
	if Game.quest_stage("act4") in [2, 3]:
		Game.set_quest("act4", 3)
	# пропуск «все объекты»: охрана поста не стреляет
	if Game.item_count("ges_pass") > 0 and not Game.flag("yk_alarm"):
		for ch in characters():
			if ch.squad == "yk_gate":
				ch.hostile = false
	main.hud.refresh_objective()


func objective() -> String:
	if Game.quest_stage("act4") <= 3:
		if Game.item_count("ges_pass") > 0:
			return "Пройти пост «Горизонта» по пропуску и спуститься на лифте."
		return "Пробиться через пост «Горизонта» к лифту."
	return ""


func on_interact(it: Interactable) -> bool:
	match String(it.name):
		"WestExit":
			main.world_map.open(location_id)
			return true
		"Lift":
			if Game.quest_stage("act4") < 4:
				Game.set_quest("act4", 4)
			main.think("Двери лифта сходятся. Из динамика — тихая музыка, что-то из старого кино. Вниз долго.")
			main.load_location("complex", "FromLift")
			return true
	return super.on_interact(it)


func on_combat_end(res: String, kind: String) -> void:
	super.on_combat_end(res, kind)
	Game.set_flag("yk_alarm")


func item_actions(it: Interactable) -> Array:
	if String(it.name) == "Lift":
		return [["Спуститься", "use"]]
	return super.item_actions(it)


func describe(it: Interactable) -> String:
	match String(it.name):
		"Lift":
			return "Будка лифта, над дверью горит зелёная лампа."
		"WestExit":
			return "Тракт назад, к Горному."
	return ""
