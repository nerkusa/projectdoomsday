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
const HAND_BONE_L := "DEF-hand.L"

var skel: Skeleton3D
var anim: AnimationPlayer
var current := ""
var _hand: Node3D
var _hand_l: Node3D


## look — цвета из шаблона персонажа: top красит тело манекена, pants — суставы.
func build(look := {}) -> bool:
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
	if skel.find_bone(HAND_BONE_L) >= 0:
		var att_l := BoneAttachment3D.new()
		skel.add_child(att_l)
		att_l.bone_name = HAND_BONE_L
		_hand_l = Node3D.new()
		_hand_l.name = "HandL"
		att_l.add_child(_hand_l)
	for mi in _meshes(inst):
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		if look.has("skin_mesh") and ResourceLoader.exists(str(look.skin_mesh)):
			_skin(mi, look)
		else:
			_tint(mi, look)
	return true


## Своя сетка с развёрткой и запечённой текстурой (герой: tools/bake_hero_skin.py).
## Кости те же, что у манекена, так что скелет и анимации остаются прежними.
func _skin(mi: MeshInstance3D, look: Dictionary) -> void:
	mi.mesh = load(str(look.skin_mesh))
	# свои пропорции рук: модификатор скелета — первым, до IK рук
	var rig_path := str(look.skin_mesh).replace("_mesh.res", "_rig.json")
	if FileAccess.file_exists(rig_path) and skel.get_node_or_null("ArmLength") == null:
		var cfg = JSON.parse_string(FileAccess.get_file_as_string(rig_path))
		if cfg is Dictionary and cfg.has("arm_k"):
			var al := ArmLength.new()
			al.name = "ArmLength"
			al.k = float(cfg.arm_k)
			skel.add_child(al)
			skel.move_child(al, 0)
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(str(look.skin_tex))
	m.roughness = 0.85
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mi.set_surface_override_material(0, m)


func _tint(mi: MeshInstance3D, look: Dictionary) -> void:
	if mi.mesh == null:
		return
	for i in mi.mesh.get_surface_count():
		var src := mi.mesh.surface_get_material(i)
		var joints := src != null and src.resource_name.contains("Joints")
		var key := "pants" if joints else "top"
		if not look.has(key):
			continue
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(look[key])
		m.roughness = 0.8
		mi.set_surface_override_material(i, m)


func hand() -> Node3D:
	return _hand


func hand_l() -> Node3D:
	return _hand_l


## Как оружие лежит в кисти. Ось Y кости кисти идёт вдоль ладони к пальцам,
## ось Z — в сторону большого пальца. Оружие строится стволом/лезвием по +Z, верхом по +Y.
## swing — во время удара холодное оружие смотрит вперёд из кулака;
## в остальное время опущено головкой вниз, вдоль ноги.
func grip(gun: bool, swing := false, short := false) -> Transform3D:
	if gun:
		# ствол вдоль ладони, рукоять вниз
		return Transform3D(Basis(Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 0)), Vector3(0, 0.07, 0))
	# рукоять зажата в кулаке, лезвие торчит со стороны большого пальца
	var t := Transform3D(Basis(Vector3(-1, 0, 0), Vector3(0, -1, 0), Vector3(0, 0, 1)), Vector3(0, 0.07, 0))
	if swing:
		return t
	# нож держат прямым хватом: лезвие вперёд и чуть вниз; топор, мачете — вниз вдоль ноги
	return t * Transform3D(Basis(Vector3.RIGHT, deg_to_rad(22.0 if short else 78.0)), Vector3.ZERO)


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
