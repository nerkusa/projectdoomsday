class_name SungarHouse
extends SungarDistrict
## Верхние этажи каменного дома Сунгара. Первый этаж — в самом районе (туда входишь
## с улицы, как в избу); по лестнице поднимаешься сюда. Этажи лежат в одной сцене
## рядом друг с другом (через FLOOR_DX по X), виден только тот, где стоит герой:
## остальные этажи и их жильцы спрятаны.
## Предметы-лестницы: Up<n> — наверх с этажа n, Down<n> — вниз (с нижнего — на улицу).
## Точки появления: F<n>Below — у лестницы снизу, F<n>Above — у лестницы сверху.

## Номер нижнего этажа в этой сцене (обычно 2)
@export var first_floor := 2
@export var floor_count := 2
@export var floor_dx := 60.0
## Куда ведёт лестница с нижнего этажа: локация и точка появления
@export var exit_loc := "sungar"
@export var exit_spawn := "Start"
## Подпись дома для журнала: «гостиница», «общежитие»…
@export var house_name := "дом"

var cur_floor := 0


func status_line() -> String:
	return "2062 · Сунгар · %s, %d этаж" % [house_name, maxi(cur_floor, first_floor)]


func uses_clock_light() -> bool:
	return false


func floor_at(p: Vector3) -> int:
	return first_floor + clampi(int(floor((p.x + floor_dx * 0.25) / floor_dx)), 0, floor_count - 1)


func on_world_state_applied() -> void:
	if main and main.player:
		show_floor(floor_at(main.player.global_position))


func on_enter() -> void:
	super.on_enter()
	show_floor(floor_at(main.player.global_position))


## Показать этаж f: его стены и жильцов; остальные спрятать
func show_floor(f: int) -> void:
	cur_floor = f
	var vil := get_node_or_null("Village")
	if vil:
		for c in vil.get_children():
			var n := String(c.name)
			if n.begins_with("Floor"):
				(c as Node3D).visible = n == "Floor%d" % f
	for ch in characters():
		if ch == main.player:
			continue
		var here := floor_at(ch.global_position) == f
		if here and ch.get_meta("floor_hidden", false):
			ch.set_meta("floor_hidden", false)
			ch.visible = true
			ch.process_mode = Node.PROCESS_MODE_INHERIT
		elif not here and ch.visible:
			ch.set_meta("floor_hidden", true)
			ch.visible = false
			ch.process_mode = Node.PROCESS_MODE_DISABLED
	if main and main.hud:
		main.hud._status.text = main.status_text()


## Перейти на этаж f к точке появления sp
func go_floor(f: int, sp: String) -> void:
	main.player.stop()
	main.player.global_position = spawn_point(sp)
	main.cam_target = main.player.global_position
	show_floor(f)
	main.sfx("rustle", -12.0, 0.8)
	main.hud.flash_tip("%d этаж" % f)


func on_interact(it: Interactable) -> bool:
	var n := String(it.name)
	if n.begins_with("Up"):
		var f := int(n.substr(2))
		go_floor(f + 1, "F%dBelow" % (f + 1))
		return true
	if n.begins_with("Down"):
		var f := int(n.substr(4))
		if f <= first_floor:
			main.load_location(exit_loc, exit_spawn)
		else:
			go_floor(f - 1, "F%dAbove" % (f - 1))
		return true
	return super.on_interact(it)


func item_actions(it: Interactable) -> Array:
	var n := String(it.name)
	if n.begins_with("Up"):
		return [["Подняться на %d этаж" % (int(n.substr(2)) + 1), "use"]]
	if n.begins_with("Down"):
		var f := int(n.substr(4))
		return [["Спуститься на улицу" if f <= first_floor else "Спуститься на %d этаж" % (f - 1), "use"]]
	return super.item_actions(it)


func describe(it: Interactable) -> String:
	var n := String(it.name)
	if n.begins_with("Up"):
		return "Лестница наверх. Ступени стёрты посередине, перила липкие."
	if n.begins_with("Down"):
		return "Лестница вниз. Пахнет кошками и сыростью."
	return super.describe(it)
