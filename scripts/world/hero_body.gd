class_name HeroBody
extends Node3D
## Модель героя (assets/models/hero.glb) со скелетом.
## Кости названы как суставы процедурного человечка: root, spine, head,
## shR/elR (правая рука), shL/elL, thR/knR (правая нога), thL/knL.

const MODEL := "res://assets/models/hero.glb"

var skel: Skeleton3D
var bones: Dictionary = {}
var root_rest := Vector3.ZERO
var _hand: Node3D


func build() -> bool:
	if not ResourceLoader.exists(MODEL):
		return false
	var ps: PackedScene = load(MODEL)
	if ps == null:
		return false
	var inst := ps.instantiate()
	add_child(inst)
	skel = _find_skeleton(inst)
	if skel == null:
		return false
	for i in skel.get_bone_count():
		bones[skel.get_bone_name(i)] = i
	if bones.has("root"):
		root_rest = skel.get_bone_rest(bones.root).origin
	if bones.has("elR"):
		var att := BoneAttachment3D.new()
		skel.add_child(att)
		att.bone_name = "elR"
		_hand = Node3D.new()
		_hand.name = "Hand"
		_hand.position = Vector3(0, -0.27, 0.02)
		att.add_child(_hand)
	for mi in _meshes(inst):
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return true


func hand() -> Node3D:
	return _hand


func apply(a: Dictionary) -> void:
	if skel == null:
		return
	for k in bones:
		var v = a.get(k, Vector3.ZERO)
		skel.set_bone_pose_rotation(bones[k], Quaternion.from_euler(v))
	if bones.has("root"):
		skel.set_bone_pose_position(bones.root, root_rest + a.get("root_off", Vector3.ZERO))


func _find_skeleton(n: Node) -> Skeleton3D:
	if n is Skeleton3D:
		return n
	for c in n.get_children():
		var s := _find_skeleton(c)
		if s:
			return s
	return null


func _meshes(n: Node) -> Array:
	var out := []
	if n is MeshInstance3D:
		out.append(n)
	for c in n.get_children():
		out.append_array(_meshes(c))
	return out
