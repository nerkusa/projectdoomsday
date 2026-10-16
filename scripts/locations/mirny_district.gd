class_name MirnyDistrict
extends NyurbaDistrict
## Мирный (Акт III) — город контрастов из пяти частей: в середине ничейная земля с мёртвым
## карьером и промзоной ГОК «Мир», по углам — районы четырёх фракций («Кимберлит», совет
## республиканцев с йегерями, рабочие, рейдеры). Переходы — по улицам (To* → район).
## Общее: задание Акта III, таймер суда йегерей (идёт, где бы ни был герой), кто где после сюжета.

## Через сколько часов после прихода йегеря казнят Петра, если никто не вмешается
const TRIAL_HOURS := 6.0

## Фоновая война: до следующей далёкой очереди, сек
var _war_t := 6.0


func status_line() -> String:
	return "2062 · Мирный"


func on_enter() -> void:
	super.on_enter()
	if Game.quest_stage("act3") <= 1:
		Game.set_quest("act3", 2)
	# «Спуститься первым» откроется, когда в игре появится защитный костюм
	if Game.quest_stage("mr_trial") == 0:
		Game.set_quest("mr_trial", 1)
		Game.world["mr_arrived"] = Clock.hours()
	_apply_story()
	main.hud.refresh_objective()


## Суд, покупатель: кто жив, кто ушёл — по флагам (персонажи есть только в своём районе)
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
			return "Мирный: обойти районы фракций, поговорить с лидерами и встать на чью-то сторону в споре за ГЭС."
		4:
			return "Идти на плотину ГЭС — из центра города на восток (карта мира)."
	return ""


## Город воюет: то тут, то там — далёкие выстрелы, очереди, редкий разрыв
func _process(delta: float) -> void:
	if main == null or main.combat.on:
		return
	_war_t -= delta
	if _war_t > 0.0:
		return
	_war_t = randf_range(10.0, 30.0)
	_burst(1 if randf() < 0.5 else randi_range(2, 5))


func _burst(n: int) -> void:
	for i in n:
		main.sfx("shot_far_%d" % randi_range(1, 3), randf_range(-16.0, -8.0), randf_range(0.9, 1.1))
		await get_tree().create_timer(randf_range(0.08, 0.3), false).timeout
	if randf() < 0.15:
		main.sfx("thunder", -14.0, 0.55)


func on_hero_moved(pos: Vector3) -> void:
	super.on_hero_moved(pos)
	if Game.quest_stage("mr_trial") in [1, 2] and not Game.flag("mr_trial_done"):
		var t0 := float(Game.world.get("mr_arrived", Clock.hours()))
		if Clock.hours() - t0 >= TRIAL_HOURS:
			_execute()


## Йегеря не дождались — Петра казнят на площади суда
func _execute() -> void:
	Game.set_flag("mr_trial_done")
	Game.set_flag("mr_executed")
	Game.set_quest("mr_trial", 3)
	var a := character("Accused")
	if a:
		a.pose = "dead"
		ws().dead[a.uid()] = true
		main.think("Сухой выстрел у помоста. Йегеря закончили суд. Пётр больше не встанет.")
	else:
		main.think("Где-то в районе совета сухо щёлкнул выстрел. Йегеря закончили суд — без меня.")
