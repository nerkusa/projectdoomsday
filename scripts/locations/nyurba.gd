extends NyurbaDistrict
## Нью-Рба, Проход — вход в город и низы: ворота с охраной, Алмазный банк, ломбард,
## бар «Забой», лавки в лабазах, склады. Бичи у бочек, «забойские» во дворе за баром.


func _ready() -> void:
	location_id = "nyurba"
	title = "Нью-Рба · Проход"
	links = {"ToCenter": ["nyurba_center", "FromProxod", "Центр"], "ToProm": ["nyurba_prom", "FromProxod", "Промрайон"],
		"Hatch": ["nyurba_sewer", "FromProxod", "Люк в канализацию"]}
	arrive_thought = "Нью-Рба. Бетонная стена, автоматчики на вышках, над воротами — шпиль с часами. Город, где продаётся всё."
	super._ready()


# ---------------- ворота ----------------
## Створки открываются, когда герой подходит днём; ночью (комендантский час) закрыты.
const GATE := Vector3(6.0, 0, 40.0)
const GATE_NEAR := 11.0
## Угол распахнутой створки (наружу, к тракту)
const GATE_ANGLE := deg_to_rad(92.0)
var gate_open := false
var _gate_busy := false


func _leaves() -> Array:
	return [get_node_or_null("CityWall/GateLeafN"), get_node_or_null("CityWall/GateLeafS")]


## Ворота открыты днём, ночью закрыты (с 23 до 6)
func gate_hours() -> bool:
	var h := Clock.hour_of_day()
	return h >= 6.0 and h < 23.0


func on_enter() -> void:
	super.on_enter()
	# герой уже в городе и днём — створки распахнуты сразу, без анимации
	var inside: bool = main != null and main.player != null and main.player.global_position.x > GATE.x + 1.0
	_set_gate(gate_hours() and inside, false)


## Открыть ворота (для катсцен и скриншотов)
func open_gate() -> void:
	_set_gate(true)


func _set_gate(open: bool, animate := true) -> void:
	if open == gate_open and animate:
		return
	gate_open = open
	var lv := _leaves()
	var targets := [-GATE_ANGLE if open else 0.0, GATE_ANGLE if open else 0.0]
	if not animate:
		for i in 2:
			if lv[i]:
				(lv[i] as Node3D).rotation.y = targets[i]
		_rebuild_grid()
		return
	_gate_busy = true
	main.sfx("gate_creak", -3.0, 0.95 if open else 0.85)
	var tw := create_tween().set_parallel(true)
	for i in 2:
		if lv[i]:
			tw.tween_property(lv[i], "rotation:y", targets[i], 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tw.finished
	_gate_busy = false
	_rebuild_grid()


func _rebuild_grid() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	grid.build(get_world_3d().direct_space_state, map_rect, 1)


func on_hero_moved(pos: Vector3) -> void:
	super.on_hero_moved(pos)
	if _gate_busy:
		return
	var near := Vector2(pos.x, pos.z).distance_to(Vector2(GATE.x, GATE.z)) < GATE_NEAR
	if gate_hours():
		if near and not gate_open:
			var g := character("GateGuard1")
			if g and g.visible:
				g.bark("Проходи. Пошлина — у будки.")
			_set_gate(true)
	elif gate_open and not near:
		_set_gate(false)
	elif near and not gate_open and pos.x < GATE.x and not Game.flag("nr_curfew_told"):
		Game.set_flag("nr_curfew_told")
		main.think("Ворота закрыты. С вышки кричат: «Комендантский час! До шести — никого!» Придётся ждать утра.")


func on_interact(it: Interactable) -> bool:
	match String(it.name):
		"ToRoad":
			main.world_map.open(location_id)
			return true
		"Fountain":
			main.think("Фонтан сухой лет двадцать. На дне — окурки, битое стекло и одна монета: её никто не берёт — говорят, к удаче.")
			return true
		"InfoScreen":
			main.think("Экран у ворот: «Вход — 5 р. с носа. Оружие — в чехол. Алмазный банк: вклады под 3 % в месяц». Внизу бегущая строка: «Нью-Рба — город возможностей».")
			return true
	return super.on_interact(it)


func describe(it: Interactable) -> String:
	match String(it.name):
		"Hatch":
			return "Крышка люка сдвинута. Вниз уходят ржавые скобы, тянет сыростью."
		"Fountain":
			return "Каменная чаша с колонной посередине, воды нет."
		"InfoScreen":
			return "Уличный экран на столбе, янтарные буквы."
	return super.describe(it)
