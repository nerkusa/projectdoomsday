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

## Своя модель (look.model, напр. из Tripo + Mixamo): скелет приведён к «человеческому»
## скелету Godot (GeneralSkeleton), анимации — общая библиотека anim_humanoid.glb
const HUMANOID_ANIMS := "res://assets/models/anim_humanoid.glb"
## Кости манекена → «человеческие» имена (для своих моделей)
const HUMANOID_BONES := {"DEF-hand.R": "RightHand", "DEF-hand.L": "LeftHand", "DEF-spine.003": "UpperChest",
	"DEF-upper_arm.L": "LeftUpperArm", "DEF-upper_arm.R": "RightUpperArm", "DEF-forearm.L": "LeftLowerArm", "DEF-forearm.R": "RightLowerArm"}
static var _humanoid_lib: AnimationLibrary
static var _masked_libs := {}
const SPINE_BONES := ["Hips", "Spine", "Chest", "UpperChest", "Neck"]
const LEG_BONES := ["LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "LeftToes", "RightUpperLeg", "RightLowerLeg", "RightFoot", "RightToes"]

var skel: Skeleton3D
var anim: AnimationPlayer
## Своя модель на «человеческом» скелете
var humanoid := false
var current := ""
var _hand: Node3D
var _hand_l: Node3D


## look — цвета из шаблона персонажа: top красит тело манекена, pants — суставы.
func build(look := {}) -> bool:
	if look.has("model"):
		return _build_model(look)
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


## Своя модель с собственными текстурами: look.model — путь к .glb, look.model_scale — масштаб
## (Tripo отдаёт модели высотой около метра)
func _build_model(look: Dictionary) -> bool:
	var path := str(look.model)
	if not ResourceLoader.exists(path) or not ResourceLoader.exists(HUMANOID_ANIMS):
		return false
	var inst: Node3D = (load(path) as PackedScene).instantiate()
	inst.scale = Vector3.ONE * float(look.get("model_scale", 1.0))
	add_child(inst)
	skel = _find(inst, "Skeleton3D")
	if skel == null:
		return false
	humanoid = true
	anim = AnimationPlayer.new()
	anim.name = "AnimationPlayer"
	inst.add_child(anim)
	anim.root_node = NodePath("..")
	# look.anim_mask: "legs" — двигаются только ноги, "upright" — всё, кроме наклонов спины
	anim.add_animation_library("", humanoid_library(str(look.get("anim_mask", ""))))
	# look.own_weapon — оружие вылеплено в модели: в кисть ничего не вешаем
	for pair in [[bone(HAND_BONE), "Hand"], [bone(HAND_BONE_L), "HandL"]]:
		if skel.find_bone(pair[0]) >= 0 and not look.get("own_weapon", false):
			var att := BoneAttachment3D.new()
			skel.add_child(att)
			att.bone_name = pair[0]
			var h := Node3D.new()
			h.name = pair[1]
			att.add_child(h)
			if pair[1] == "Hand":
				_hand = h
			else:
				_hand_l = h
	for mi in _meshes(inst):
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return true


## Общая библиотека анимаций на «человеческом» скелете (грузится один раз).
## mask = "legs" — копия, где оставлены только ноги и таз;
## mask = "upright" — без наклонов таза, спины и шеи (модель с сутулой осанкой стоит прямо).
## Смерть всегда целиком.
static func humanoid_library(mask := "") -> AnimationLibrary:
	if _humanoid_lib == null:
		var a: Node = (load(HUMANOID_ANIMS) as PackedScene).instantiate()
		_humanoid_lib = (a.get_node("AnimationPlayer") as AnimationPlayer).get_animation_library("")
		a.free()
	if mask != "legs" and mask != "upright":
		return _humanoid_lib
	if _masked_libs.has(mask):
		return _masked_libs[mask]
	var lib := AnimationLibrary.new()
	for nm in _humanoid_lib.get_animation_list():
		var an: Animation = _humanoid_lib.get_animation(nm).duplicate(true)
		if not str(nm).begins_with("Death"):
			for t in range(an.get_track_count() - 1, -1, -1):
				var bone := str(an.track_get_path(t)).get_slice(":", 1)
				var pos := an.track_get_type(t) == Animation.TYPE_POSITION_3D
				var keep: bool
				if mask == "legs":
					keep = bone in LEG_BONES or (bone == "Hips" and pos)
				else:
					keep = not (bone in SPINE_BONES) or (bone == "Hips" and pos)
				if not keep:
					an.remove_track(t)
		lib.add_animation(nm, an)
	_masked_libs[mask] = lib
	return lib


## Имя кости для этого скелета: у своих моделей — «человеческое»
func bone(rigify_name: String) -> String:
	return str(HUMANOID_BONES.get(rigify_name, rigify_name)) if humanoid else rigify_name


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


## Одежда манекена: тело разбито на зоны (кожа, рубаха, жилет, штаны, сапоги, волосы…),
## каждая — своя поверхность со своим цветом из look. Материалы обычные (StandardMaterial3D),
## поэтому силуэт сквозь стены и полупрозрачность в стелсе работают как раньше.
const ZONES := ["skin", "top", "torso", "forearm", "pants", "boots", "hair", "jaw", "belt"]
static var _dressed: ArrayMesh
static var _zone_mats := {}


func _tint(mi: MeshInstance3D, look: Dictionary) -> void:
	if mi.mesh == null:
		return
	if _dressed == null and mi.skin != null and mi.mesh is ArrayMesh:
		_dressed = _dress_mesh(mi.mesh as ArrayMesh, mi.skin)
	if _dressed == null:
		return
	mi.mesh = _dressed
	var top := _col(look, ["top"], "#6b5a2e")
	var skin := _col(look, ["skin"], "#c49a74")
	var cols := {
		"skin": skin, "top": top, "torso": _col(look, ["vest", "top"], "#6b5a2e"),
		"forearm": skin if str(look.get("sleeves", "")) == "short" else top.darkened(0.06),
		"pants": _col(look, ["pants"], "#3a3a2e"), "boots": _col(look, ["boots"], "#2b2622"),
		"hair": _col(look, ["helmet", "cap", "hair"], "#1c1612"),
		"jaw": _col(look, ["mask", "beard", "skin"], "#c49a74"),
		"belt": Color("#2a2018"),
	}
	for i in _dressed.get_surface_count():
		var z := _dressed.surface_get_name(i)
		mi.set_surface_override_material(i, _zone_mat(cols.get(z, top), z))


## Цвет детали: первый из ключей, что есть в look. В данных встречается и просто «есть»
## (true) без цвета — тогда берётся обычный цвет такой вещи.
const ITEM_COLS := {"helmet": "#3a3f38", "cap": "#3b3226", "mask": "#26282a", "beard": "#3a2c20", "vest": "#4a4436", "boots": "#2b2622"}


static func _col(look: Dictionary, keys: Array, def: String) -> Color:
	for k in keys:
		if not look.has(k):
			continue
		var v = look[k]
		if v is String and Color.html_is_valid(v):
			return Color(v)
		if v is bool and v:
			return Color(str(ITEM_COLS.get(k, def)))
	return Color(def)


static func _zone_mat(c: Color, zone: String) -> StandardMaterial3D:
	var key := zone.left(1) + c.to_html(false) if zone in ["skin", "boots"] else c.to_html(false)
	if not _zone_mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = 0.6 if zone == "skin" else (0.5 if zone == "boots" else 0.92)
		_zone_mats[key] = m
	return _zone_mats[key]


## Зона вершины: по главной кости и месту в Т-позе (рост манекена 1,83 м, лицо смотрит в +Z)
static func _zone_of(bone: String, p: Vector3) -> String:
	if bone.contains("foot") or bone.contains("toe"):
		return "boots"
	if bone.contains("shin"):
		return "boots" if p.y < 0.34 else "pants"
	if bone.contains("thigh"):
		return "pants"
	if bone.contains("hips") or bone.contains("spine"):
		if p.y > 0.96 and p.y < 1.03:
			return "belt"
		return "torso" if p.y >= 1.03 else "pants"
	if bone.contains("shoulder"):
		return "torso"
	if bone.contains("upper_arm"):
		return "top"
	if bone.contains("forearm"):
		return "forearm"
	if bone.contains("head"):
		if p.y > 1.775 or (p.z < 0.015 and p.y > 1.63) or (p.z < 0.07 and p.y > 1.74):
			return "hair"
		if p.y < 1.64 and p.z > 0.03:
			return "jaw"
		return "skin"
	return "skin"


static func _dress_mesh(src: ArrayMesh, skin: Skin) -> ArrayMesh:
	var lists := {}
	for s in src.get_surface_count():
		var a := src.surface_get_arrays(s)
		var vs: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = a[Mesh.ARRAY_BONES]
		var wts: PackedFloat32Array = a[Mesh.ARRAY_WEIGHTS]
		var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
		var per := bones.size() / vs.size()
		var vz := PackedStringArray()
		vz.resize(vs.size())
		for v in vs.size():
			var best := 0
			for k in per:
				if wts[v * per + k] > wts[v * per + best]:
					best = k
			vz[v] = _zone_of(str(skin.get_bind_name(bones[v * per + best])), vs[v])
		# треугольник целиком уходит в зону большинства своих вершин
		for t in range(0, idx.size(), 3):
			var z := vz[idx[t]]
			if vz[idx[t + 1]] == vz[idx[t + 2]]:
				z = vz[idx[t + 1]]
			if not lists.has(z):
				lists[z] = []
			(lists[z] as Array).append([a, idx[t], idx[t + 1], idx[t + 2]])
	var out := ArrayMesh.new()
	for z in ZONES:
		if not lists.has(z):
			continue
		var st := {}  # (поверхность-источник, старая вершина) → новая
		var nv := PackedVector3Array()
		var nn := PackedVector3Array()
		var nb := PackedInt32Array()
		var nw := PackedFloat32Array()
		var ni := PackedInt32Array()
		for tri in lists[z]:
			var a: Array = tri[0]
			var vs: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			var per: int = (a[Mesh.ARRAY_BONES] as PackedInt32Array).size() / vs.size()
			for c in 3:
				var o: int = tri[c + 1]
				var key := [vs.size(), o]
				if not st.has(key):
					st[key] = nv.size()
					nv.append(vs[o])
					nn.append((a[Mesh.ARRAY_NORMAL] as PackedVector3Array)[o])
					for k in per:
						nb.append((a[Mesh.ARRAY_BONES] as PackedInt32Array)[o * per + k])
						nw.append((a[Mesh.ARRAY_WEIGHTS] as PackedFloat32Array)[o * per + k])
				ni.append(st[key])
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = nv
		arr[Mesh.ARRAY_NORMAL] = nn
		arr[Mesh.ARRAY_BONES] = nb
		arr[Mesh.ARRAY_WEIGHTS] = nw
		arr[Mesh.ARRAY_INDEX] = ni
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		out.surface_set_name(out.get_surface_count() - 1, z)
	return out


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
