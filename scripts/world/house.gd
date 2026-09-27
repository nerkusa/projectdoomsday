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


func _ready() -> void:
	add_to_group("houses")
	_upper = get_node_or_null("Upper")


func _process(_delta: float) -> void:
	if _upper == null:
		return
	var p := get_tree().get_first_node_in_group("player") as Node3D
	if p == null:
		return
	var l := to_local(p.global_position)
	var now := absf(l.x) < inner.x / 2.0 and absf(l.z) < inner.y / 2.0
	if now != inside:
		inside = now
		_upper.visible = not now
		# пока герой внутри, «рентген» main.gd не делает дом прозрачным
		set_meta("inside", now)


## Точка у двери снаружи (dist > 0) или внутри (dist < 0), в мировых координатах
func door_point(dist: float) -> Vector3:
	return to_global(door + Vector3(0, 0, dist))
