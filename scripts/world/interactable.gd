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


var _glow: MeshInstance3D
var _glow_mode := ""


## Слабая подсветка вещи на земле: «free» — можно взять, «theft» — чужое, «» — нет
func set_glow(mode: String) -> void:
	if mode == _glow_mode:
		return
	_glow_mode = mode
	if mode == "":
		if _glow:
			_glow.visible = false
		return
	if _glow == null:
		_glow = MeshInstance3D.new()
		_glow.name = "Glow"
		_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var r := maxf(0.5, maxf(pick_size.x, pick_size.z) * 0.8)
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var n := 28
		for i in n:
			var a0 := TAU * i / n
			var a1 := TAU * (i + 1) / n
			var o0 := Vector3(sin(a0), 0, cos(a0))
			var o1 := Vector3(sin(a1), 0, cos(a1))
			# кольцо: снаружи прозрачное, ближе к центру ярче — мягкое пятно
			st.set_color(Color(1, 1, 1, 0.0))
			st.add_vertex(o0 * r)
			st.set_color(Color(1, 1, 1, 0.0))
			st.add_vertex(o1 * r)
			st.set_color(Color(1, 1, 1, 1.0))
			st.add_vertex(o1 * r * 0.55)
			st.set_color(Color(1, 1, 1, 0.0))
			st.add_vertex(o0 * r)
			st.set_color(Color(1, 1, 1, 1.0))
			st.add_vertex(o1 * r * 0.55)
			st.set_color(Color(1, 1, 1, 1.0))
			st.add_vertex(o0 * r * 0.55)
			st.set_color(Color(1, 1, 1, 0.35))
			st.add_vertex(Vector3.ZERO)
			st.set_color(Color(1, 1, 1, 1.0))
			st.add_vertex(o0 * r * 0.55)
			st.set_color(Color(1, 1, 1, 1.0))
			st.add_vertex(o1 * r * 0.55)
		_glow.mesh = st.commit()
		_glow.position = Vector3(0, 0.04, 0)
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.vertex_color_use_as_albedo = true
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_glow.material_override = m
		add_child(_glow)
	var mat := _glow.material_override as StandardMaterial3D
	mat.albedo_color = Color(1.0, 0.3, 0.2, 0.6) if mode == "theft" else Color(0.7, 1.0, 0.55, 0.5)
	_glow.visible = true
