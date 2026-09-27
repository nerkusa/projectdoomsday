class_name Interactable
extends Node3D
## Предмет или место, по которому можно кликнуть: подобрать, обыскать, выйти.
## Внешний вид — любые дочерние узлы (коробки, модели). Кликабельная зона
## создаётся сама вокруг узла.

## item — подобрать предмет; use — действие локации; exit — переход/выход
@export_enum("item", "use", "exit") var kind := "item"
## Ключ предмета из data/items.json или data/weapons.json
@export var item_id := ""
@export var count := 1
## Подпись при наведении. Пусто — название предмета.
@export var label := ""
## Размер кликабельной зоны
@export var pick_size := Vector3(0.7, 0.6, 0.7)
## Как близко надо подойти, чтобы взаимодействовать (в гексах)
@export var reach := 1

var _area: Area3D


func _ready() -> void:
	add_to_group("interactables")
	_area = Area3D.new()
	_area.collision_layer = 4
	_area.collision_mask = 0
	_area.monitoring = false
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = pick_size
	cs.shape = b
	cs.position = Vector3(0, pick_size.y / 2.0, 0)
	_area.add_child(cs)
	add_child(_area)
	_area.set_meta("interactable", self)


func uid() -> String:
	return String(name)


func title() -> String:
	if label != "":
		return label
	if item_id != "":
		return DB.item_name(item_id)
	return String(name)


func set_active(v: bool) -> void:
	visible = v
	_area.collision_layer = 4 if v else 0
