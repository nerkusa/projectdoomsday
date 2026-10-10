class_name House
extends Node3D
## Дом, в который можно войти. Постройку собирает tools/build_props.gd:
## крыша, верх стен и окна лежат в дочернем узле Upper. Пока герой внутри,
## Upper спрятан — видно комнату, как в изометрических RPG.

## Внутренний размер комнаты (X, Z) в метрах, центр — в начале координат дома
@export var inner := Vector2(4.6, 3.8)
## Середина дверного проёма (в координатах дома)
@export var door := Vector3.ZERO

var inside := false
var _upper: Node3D
var _player: Node3D
var _t := 0.0
## Что ещё прячется вместе с верхом (вывески над входом: метка with_upper)
var _extra: Array = []


func _ready() -> void:
	add_to_group("houses")
	_upper = get_node_or_null("Upper")
	for c in get_children():
		if c.has_meta("with_upper"):
			_extra.append(c)


func _process(delta: float) -> void:
	if _upper == null:
		return
	# проверять десять раз в секунду хватает: домов на локации — десятки
	_t -= delta
	if _t > 0.0:
		return
	_t = 0.1
	if _player == null or not is_instance_valid(_player) or not _player.is_inside_tree():
		_player = get_tree().get_first_node_in_group("player") as Node3D
	var p := _player
	if p == null:
		return
	var l := to_local(p.global_position)
	var now := absf(l.x) < inner.x / 2.0 and absf(l.z) < inner.y / 2.0
	if now != inside:
		inside = now
		_upper.visible = not now
		for e in _extra:
			e.visible = not now
		# пока герой внутри, «рентген» main.gd не делает дом прозрачным
		set_meta("inside", now)


## Точка у двери снаружи (dist > 0) или внутри (dist < 0), в мировых координатах
func door_point(dist: float) -> Vector3:
	return to_global(door + Vector3(0, 0, dist))
