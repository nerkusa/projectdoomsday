class_name Location
extends Node3D
## Корневой скрипт любой локации.
## В сцене локации должны быть узлы:
##   Characters — персонажи (Character)
##   Items      — предметы (Interactable)
##   Spawns     — точки появления (Marker3D), главная — "Start"
## Сюжет конкретной локации пишется в наследнике (см. nakharro.gd).

@export var location_id := "location"
@export var title := "Локация"
## Границы карты в метрах (X, Z, ширина, глубина)
@export var map_rect := Rect2(0, 0, 64, 64)
## Центр карты для камеры в начале
@export var camera_start := Vector3(32, 0, 32)

var grid := HexGrid.new()
var main: Node = null


## Вызывается из main.gd после загрузки
func setup(m: Node) -> void:
	main = m
	await get_tree().physics_frame
	await get_tree().physics_frame
	grid.build(get_world_3d().direct_space_state, map_rect, 1)
	_apply_world_state()


func spawn_point(n := "Start") -> Vector3:
	var s := get_node_or_null("Spawns/" + n)
	if s is Node3D:
		return (s as Node3D).global_position
	return camera_start


func characters() -> Array:
	var out := []
	var c := get_node_or_null("Characters")
	if c:
		for x in c.get_children():
			if x is Character:
				out.append(x)
	return out


func character(n: String) -> Character:
	return get_node_or_null("Characters/" + n) as Character


func items() -> Array:
	var out := []
	var c := get_node_or_null("Items")
	if c:
		for x in c.get_children():
			if x is Interactable:
				out.append(x)
	return out


func item(n: String) -> Interactable:
	return get_node_or_null("Items/" + n) as Interactable


func ws() -> Dictionary:
	return Game.wstate(location_id)


func _apply_world_state() -> void:
	var st := ws()
	for it in items():
		if st.picked.has(it.uid()):
			it.set_active(false)
	for ch in characters():
		if st.dead.has(ch.uid()):
			ch.pose = "dead"
			ch.start_dead = true
			ch.set_held("")
		elif st.misc.has("gone_" + ch.uid()):
			ch.visible = false
	on_world_state_applied()


# ---------- крючки для сюжета (переопредели в наследнике) ----------
func on_world_state_applied() -> void:
	pass


func on_enter() -> void:
	pass


func on_hero_moved(_pos: Vector3) -> void:
	pass


## Вернуть true, если действие обработано здесь
func on_dialog_action(_action: String, _speaker: Character) -> bool:
	return false


## Вернуть true, если клик по предмету обработан здесь (иначе — обычный подбор)
func on_interact(_it: Interactable) -> bool:
	return false


## Можно ли поднять предмет прямо сейчас
func can_pick(_it: Interactable) -> bool:
	return true


func on_picked(_it: Interactable) -> void:
	pass


func on_looted(_ch: Character) -> void:
	pass


func on_combat_round(_round: int) -> void:
	pass


func on_fighter_down(_f: Fighter) -> void:
	pass


func on_combat_end(_result: String, _kind: String) -> void:
	pass


## Условие для вариантов диалога {"cond": "..."}
func dialog_cond(_id: String) -> bool:
	return true
