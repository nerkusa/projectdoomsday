extends SungarDistrict
## Сунгар, район у ворот: платный въезд (стражник Уйгулаан), рынок, рыбная пристань.
## Мимо стражника без платы не пройти — разве что по берегу под обрывом (Скрытность).
## Рынок: смотритель Бахылай ищет обвесчика — гиря мясника Сэргэ с секретом.

const STOP_X := 12.6


func _ready() -> void:
	location_id = "sungar"
	title = "Сунгар · ворота и рынок"
	arrive_thought = "sungar_arrive"
	links = {"ToCenter": ["sungar_center", "FromGate", "В центр города"]}
	super._ready()


func on_world_state_applied() -> void:
	var b := character("Butcher")
	if b and Game.flag("butcher_banned"):
		b.visible = false
		b.process_mode = Node.PROCESS_MODE_DISABLED


func on_hero_moved(pos: Vector3) -> void:
	if Game.flag("sg_entered") or main.combat.on or main.ui_blocked():
		return
	var g := character("GateGuard")
	if g == null or not g.visible or g.pose == "dead":
		return
	var first := not Game.flag("sg_stopped") and pos.distance_to(g.global_position) < 6.0
	if first or pos.x > STOP_X:
		Game.set_flag("sg_stopped")
		if Game.quest_stage("sg_toll") == 0:
			Game.set_quest("sg_toll", 1)
		main.player.stop()
		if pos.x > STOP_X:
			main.player.global_position = Vector3(10.0, 0, clampf(pos.z, 28.5, 31.5))
		main.talk_to(g)


func on_interact(it: Interactable) -> bool:
	var n := String(it.name)
	if n == "BankPath":
		_bank_path()
		return true
	if n.begins_with("Stall"):
		_stall(n)
		return true
	return super.on_interact(it)


## Тропа под обрывом: мимо ворот, без платы
func _bank_path() -> void:
	if Game.flag("sg_entered"):
		main.think("Берег под обрывом. Отсюда видно и рынок, и пристань.")
		return
	if Game.skill_check("Скрытность", "REF", "Скрытность", 12) or Game.flag("bank_try"):
		Game.set_flag("sg_entered")
		Game.set_flag("sg_sneaked")
		Game.set_quest("sg_toll", 2)
		main.player.global_position = spawn_point("Bank")
		main.cam_target = main.player.global_position
		Game.grant_xp(30)
		main.think("По мокрым камням, держась за корни, — мимо стены. Никто не крикнул. Я в Сунгаре.")
	else:
		Game.set_flag("bank_try")
		main.think("Камни скользкие — чуть не ушёл в воду. Ещё раз, медленнее.")


## Весы на прилавках: у мясника Сэргэ — гиря с секретом
func _stall(n: String) -> void:
	var st := Game.quest_stage("sg_scales")
	if n != "Stall4":
		main.think("Весы как весы. Гири клеймёные, чашки ровные." if st >= 1 else "Весы, гири, товар. Торгуют.")
		return
	if st != 1:
		main.think("Мясной прилавок Сэргэ." if st == 0 else "Мясной прилавок. Гиря теперь честная — проверено.")
		return
	if Game.skill_check("Внимательность", "PRC", "Внимательность", 11) or Game.flag("scales_try"):
		Game.add_item("rigged_weight")
		Game.set_quest("sg_scales", 2)
		Game.grant_xp(40)
		main.think("Гиря на «кило» — а в руке легче, чем надо. Перевернул: снизу высверлено и залито воском. Вот он, обвесчик.")
		main.hud.refresh_objective()
	else:
		Game.set_flag("scales_try")
		main.think("Вроде честно… Но мясник как-то быстро убрал гирю. Глянуть ещё раз.")


func item_actions(it: Interactable) -> Array:
	var n := String(it.name)
	if n == "BankPath":
		return [["Пройти берегом", "use"]] if not Game.flag("sg_entered") else [["Осмотреть", "use"]]
	if n.begins_with("Stall"):
		return [["Проверить весы", "use"]]
	return super.item_actions(it)


func describe(it: Interactable) -> String:
	match String(it.name):
		"BankPath":
			return "Узкая полоса мокрых камней под обрывом, вдоль самой воды. Если осторожно — можно обойти стену."
		"WestExit":
			return "Дорога из Сунгара — на запад, к Крестам."
	if String(it.name).begins_with("Stall"):
		return "Прилавок с весами."
	return super.describe(it)


func objective() -> String:
	if not Game.flag("sg_entered"):
		return "Пройти в Сунгар: на воротах берут плату. Или поискать другой путь."
	if Game.quest_stage("sg_scales") == 1:
		return "Найти на рынке обвесчика — проверить весы на прилавках."
	if Game.quest_stage("sg_scales") == 2:
		return "Гиря мясника пустая: сказать Бахылаю — или поговорить с Сэргэ самому."
	return bootur_objective()
