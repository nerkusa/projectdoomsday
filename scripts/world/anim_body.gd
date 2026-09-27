@tool
class_name AnimBody
extends Node3D
## Манекен из Universal Animation Library (Quaternius, CC0) с готовыми анимациями.
## Файл: assets/models/AnimationLibrary_Godot_Standard.glb. Смотрит вдоль +Z.
## Клипы: Idle, Walk, Jog_Fwd, Sprint, Sword_Attack, Punch_Jab, Pistol_Idle,
## Pistol_Shoot, Pistol_Reload, Hit_Chest, Death01, PickUp_Table, Sitting_Idle,
## Crouch_Idle, Interact и др. (полный список — в AnimationPlayer модели).
## Godot при импорте отрезает от имён суффикс _Loop и сам зацикливает такие клипы.

const MODEL := "res://assets/models/AnimationLibrary_Godot_Standard.glb"
const HAND_BONE := "DEF-hand.R"

var skel: Skeleton3D
var anim: AnimationPlayer
var current := ""
var _hand: Node3D


func build() -> bool:
	if not ResourceLoader.exists(MODEL):
		return false
	var ps: PackedScene = load(MODEL)
	if ps == null:
		return false
	var inst := ps.instantiate()
	add_child(inst)
	skel = _find(inst, "Skeleton3D")
	anim = _find(inst, "AnimationPlayer")
	if skel == null or anim == null:
		return false
	if skel.find_bone(HAND_BONE) >= 0:
		var att := BoneAttachment3D.new()
		skel.add_child(att)
		att.bone_name = HAND_BONE
		_hand = Node3D.new()
		_hand.name = "Hand"
		att.add_child(_hand)
	for mi in _meshes(inst):
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return true


func hand() -> Node3D:
	return _hand


## Как оружие лежит в кисти. Ось Y кости кисти идёт вдоль ладони к пальцам,
## ось Z — в сторону большого пальца. Оружие строится стволом/лезвием по +Z, верхом по +Y.
func grip(gun: bool) -> Transform3D:
	if gun:
		# ствол вдоль ладони, рукоять вниз
		return Transform3D(Basis(Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 0)), Vector3(0, 0.07, 0))
	# рукоять зажата в кулаке, лезвие торчит со стороны большого пальца
	return Transform3D(Basis(Vector3(-1, 0, 0), Vector3(0, -1, 0), Vector3(0, 0, 1)), Vector3(0, 0.07, 0))


func has(clip: String) -> bool:
	return anim != null and anim.has_animation(clip)


func length(clip: String) -> float:
	return anim.get_animation(clip).length if has(clip) else 0.0


## Включить клип. blend — время плавного перехода, restart — начать заново,
## если этот клип уже играет, at_end — сразу показать последний кадр.
func play(clip: String, blend := 0.2, speed := 1.0, restart := false, at_end := false) -> void:
	if not has(clip):
		if clip != current:
			current = clip
			push_warning("AnimBody: нет анимации " + clip)
		return
	anim.speed_scale = speed
	if clip == current and not restart:
		return
	current = clip
	anim.play(clip, blend)
	if at_end:
		anim.seek(length(clip), true)
	elif restart:
		anim.seek(0.0, true)


func _find(n: Node, cls: String) -> Node:
	if n.is_class(cls):
		return n
	for c in n.get_children():
		var f := _find(c, cls)
		if f:
			return f
	return null


func _meshes(n: Node) -> Array:
	var out := []
	if n is MeshInstance3D:
		out.append(n)
	for c in n.get_children():
		out.append_array(_meshes(c))
	return out
