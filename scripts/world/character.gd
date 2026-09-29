@tool
class_name Character
extends Node3D
## Персонаж на локации: герой, жители, враги, звери.
## Поставь его в сцену локации и заполни поля в инспекторе справа.

## Ключ шаблона в data/characters.json (характеристики, оружие, внешность)
@export var char_id := "":
	set(v):
		char_id = v
		if Engine.is_editor_hint() and is_inside_tree():
			_rebuild_preview()
## Имя над головой. Пусто — берётся из шаблона.
@export var display_name := ""
## Файл диалога в data/dialogs/ (без .json). Пусто — поговорить нельзя.
@export var dialog := ""
## С какого узла диалога начинать (обычно start)
@export var dialog_node := "start"
## Враг: нападает сам, если заметит героя
@export var hostile := false
## С какого расстояния враг замечает героя (0 — не замечает сам)
@export var aggro_radius := 0.0
## Группа врагов: все из одной группы вступают в бой вместе
@export var squad := ""
## Лежит мёртвым с начала (труп, который можно обыскать)
@export var start_dead := false
## Держит оружие из шаблона, даже если не враг (часовые, защитники)
@export var armed := false
## Маршрут прогулки (точки в мире, по кругу); пусто — стоит на месте.
## Между точками идёт по прямой, так что ставь их вдоль улиц.
@export var patrol := PackedVector3Array()
## Сколько секунд постоять в каждой точке
@export var patrol_wait := 4.0
## Поза с начала: "", "sit", "down", "yield"
@export var start_pose := ""
## Показывать героя моделью из hero.glb
@export var use_hero_model := false
## Манекен из Universal Animation Library с готовыми анимациями
## (ходьба, удар, выстрел, смерть...). Главнее, чем use_hero_model.
## Выключи, чтобы вернуть процедурного человечка из брусков.
@export var use_anim_model := true:
	set(v):
		use_anim_model = v
		if Engine.is_editor_hint() and is_inside_tree():
			_rebuild_preview()

signal arrived

var tpl: Dictionary = {}
var body: Node3D
var rig: Node3D
var pose := ""
var path: Array = []
var speed := 3.2
var moving := false
var _on_arrive: Callable
var _walk_ph := 0.0
var _t := 0.0
var _act: Dictionary = {}
var _held_key := ""
var _held_node: Node3D
var _flash: OmniLight3D
var _pick_area: Area3D
var fighter: Fighter = null
var _patrol_i := 0
var _patrol_t := 1.0
var is_player := false
var aim_pose := false
## Браслет на левом запястье (у героя — когда собран КПК)
var _bracelet: Node3D
## Подключение компьютера к браслету: сам компьютер, кабель и надпись
var _plug_dev: Node3D
var _plug_cable: Array = []
var _plug_label: Label3D
## Отметки: силуэт сквозь препятствия, кружок под ногами, полупрозрачность в стелсе
var _body_meshes: Array = []
var _ring: MeshInstance3D
var _mark := ""
var _mark_t := 0.0
var _see_through := 0.0
static var _mats := {}

## Цвета отметок: силуэт (с прозрачностью) и кружок.
## Зелёные — свои и дружелюбные, жёлтые — нейтральные, красные — враги.
const MARKS := {
	"hero": [Color(0.75, 0.85, 0.95, 0.45), Color(0, 0, 0, 0)],
	"enemy": [Color(1.0, 0.32, 0.25, 0.5), Color(1.0, 0.3, 0.2, 0.75)],
	"friend": [Color(0.45, 0.9, 0.45, 0.16), Color(0.4, 0.88, 0.4, 0.28)],
	"neutral": [Color(1.0, 0.85, 0.35, 0.2), Color(1.0, 0.82, 0.3, 0.35)],
	"corpse": [Color(0.75, 0.75, 0.75, 0.35), Color(0, 0, 0, 0)],
	"none": [Color(0, 0, 0, 0), Color(0, 0, 0, 0)],
}

## Отношение к герою: friend | neutral | enemy. Пусто — само: враг, если hostile,
## нейтральный, если в шаблоне "neutral": true, иначе свой.
@export var attitude := ""


func _ready() -> void:
	if Engine.is_editor_hint():
		_rebuild_preview()
		return
	add_to_group("characters")
	tpl = DB.characters.get(char_id, {})
	if display_name == "":
		display_name = tpl.get("name", char_id)
	_build_visual()
	_pick_area = Area3D.new()
	_pick_area.collision_layer = 2
	_pick_area.collision_mask = 0
	_pick_area.monitoring = false
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.45
	cap.height = 1.9
	cs.shape = cap
	cs.position = Vector3(0, 0.95, 0)
	_pick_area.add_child(cs)
	add_child(_pick_area)
	_pick_area.set_meta("character", self)
	if start_dead:
		pose = "dead"
	elif start_pose != "":
		pose = start_pose
	if not is_player and tpl.has("weapon") and pose == "":
		set_held(tpl.weapon if hostile or armed else "")


func uid() -> String:
	return String(name)


func _rebuild_preview() -> void:
	for c in get_children():
		if c.name == "_Preview":
			c.queue_free()
	var t: Dictionary = {}
	if FileAccess.file_exists("res://data/characters.json"):
		var d = JSON.parse_string(FileAccess.get_file_as_string("res://data/characters.json"))
		if d is Dictionary:
			t = d.get(char_id, {})
	var holder := Node3D.new()
	holder.name = "_Preview"
	add_child(holder)
	if use_anim_model:
		var ab := AnimBody.new()
		holder.add_child(ab)
		if ab.build(t.get("look", {})):
			if start_dead:
				ab.play("Death01", 0.0, 1.0, false, true)
			elif start_pose in ["sit", "down"]:
				ab.play("Sitting_Idle", 0.0)
			return
		ab.queue_free()
	var hb := HumanBody.new()
	holder.add_child(hb)
	hb.build(t.get("look", {}))
	var a := {}
	if start_dead:
		holder.rotation.x = -1.45
		holder.position.y = 0.18
	hb.apply(a)


func _build_visual() -> void:
	rig = Node3D.new()
	rig.name = "Rig"
	add_child(rig)
	if tpl.get("dummy", false):
		var tb := TargetBody.new()
		rig.add_child(tb)
		tb.build()
		body = tb
	if body == null and use_anim_model:
		var ab := AnimBody.new()
		rig.add_child(ab)
		if ab.build(tpl.get("look", {})):
			body = ab
		else:
			ab.queue_free()
	if body == null and use_hero_model:
		var hb := HeroBody.new()
		rig.add_child(hb)
		if hb.build():
			body = hb
		else:
			hb.queue_free()
	if body == null:
		var h := HumanBody.new()
		rig.add_child(h)
		h.build(tpl.get("look", {}))
		body = h
	var sc := float(tpl.get("scale", 1.0))
	rig.scale = Vector3.ONE * sc
	_collect_meshes(rig)
	_flash = OmniLight3D.new()
	_flash.light_color = Color("ffc46b")
	_flash.omni_range = 5.0
	_flash.light_energy = 0.0
	_flash.position = Vector3(0, 1.4, 0.6)
	add_child(_flash)


# ---------------- движение ----------------
func move_along(points: Array, cb := Callable(), spd := 3.2) -> void:
	path = points.duplicate()
	speed = spd
	_on_arrive = cb
	moving = not path.is_empty()
	if not moving and cb.is_valid():
		cb.call()


func stop() -> void:
	path.clear()
	moving = false
	_on_arrive = Callable()


func face_towards(p: Vector3) -> void:
	var d := p - global_position
	if d.length_squared() > 0.0001:
		rotation.y = atan2(d.x, d.z)


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or body == null:
		return
	_t += delta
	if moving and not path.is_empty():
		var tgt: Vector3 = path[0]
		var g := global_position
		var d := Vector2(tgt.x - g.x, tgt.z - g.z)
		var st := speed * delta
		if d.length() <= st:
			global_position = Vector3(tgt.x, 0, tgt.z)
			path.pop_front()
			if path.is_empty():
				moving = false
				var cb := _on_arrive
				_on_arrive = Callable()
				arrived.emit()
				if cb.is_valid():
					cb.call()
		else:
			var dn := d.normalized()
			global_position += Vector3(dn.x, 0, dn.y) * st
			rotation.y = lerp_angle(rotation.y, atan2(dn.x, dn.y), 0.3)
	_patrol(delta)
	_mark_t -= delta
	if _mark_t <= 0.0:
		_mark_t = 0.25
		_update_marks()
	if body is AnimBody:
		_animate_clips(delta)
		_update_two_hands()
	else:
		_animate(delta)


## Прогулка по маршруту patrol: только вне боя и разговоров
func _patrol(delta: float) -> void:
	if patrol.is_empty() or moving or pose != "" or not _act.is_empty() or not visible or fighter != null:
		return
	var loc := get_tree().get_first_node_in_group("location")
	if loc == null or loc.main == null or loc.main.dialog.visible or loc.main.combat.on:
		return
	_patrol_t -= delta
	if _patrol_t > 0.0:
		return
	_patrol_i = (_patrol_i + 1) % patrol.size()
	move_along([patrol[_patrol_i]], func(): _patrol_t = patrol_wait + randf() * 2.0, 1.4)


# ---------------- действия (анимации с обратным вызовом) ----------------
## type: swing | fire | hit | pickup | wave | reload | shoot_burst
func act(type: String, cb := Callable(), extra := {}) -> void:
	_act = {"type": type, "t": 0.0, "cb": cb, "done": false, "extra": extra}


## Короткие клинки держат иначе, чем топор или мачете
const SHORT_BLADES := ["knife", "oyun"]


func set_held(wkey: String) -> void:
	if wkey == _held_key:
		return
	_held_key = wkey
	if _held_node:
		_held_node.queue_free()
		_held_node = null
	if wkey == "" or wkey == "fists" or body == null or not body.has_method("hand"):
		return
	var hnd: Node3D = body.hand()
	if hnd == null:
		return
	_held_node = _make_weapon_mesh(wkey)
	if body is AnimBody:
		_held_node.transform = body.grip(DB.is_gun(wkey), false, wkey in SHORT_BLADES)
	hnd.add_child(_held_node)
	_setup_two_hands()


# ---------------- винтовка: приклад в плечо, руки на оружии ----------------
## Когда целится (или стреляет, перезаряжается) — винтовка упирается прикладом в правое
## плечо, а обе руки тянутся к ней (TwoBoneIK3D): правая к рукоятке, левая к цевью.
## Иначе — просто в правой руке.
## Где лежит винтовка у плеча (в координатах тела; тело смотрит вдоль +Z)
const SHOULDER := Vector3(-0.15, 1.42, 0.24)
var _ik: TwoBoneIK3D
var _ik_left: Node3D
var _ik_right: Node3D
var _shouldered := false
var _hold := ""
## Оружие наготове, но не у плеча: перед телом, ствол вниз-влево, обе руки на нём
var _chest: BoneAttachment3D
## Положение грудной кости в позе покоя, в координатах rig
var _chest_offset := Transform3D.IDENTITY


func _chest_attach() -> BoneAttachment3D:
	if _chest and is_instance_valid(_chest):
		return _chest
	var sk: Skeleton3D = (body as AnimBody).skel if body is AnimBody else null
	if sk == null:
		return null
	var bi := sk.find_bone("DEF-spine.003")
	if bi < 0:
		return null
	_chest = BoneAttachment3D.new()
	_chest.bone_name = "DEF-spine.003"
	sk.add_child(_chest)
	_chest_offset = rig.global_transform.affine_inverse() * sk.global_transform * sk.get_bone_global_rest(bi)
	return _chest


const LOW_READY := Transform3D(Basis(Vector3.UP, 0.45) * Basis(Vector3.RIGHT, 0.55), Vector3(-0.12, 1.0, 0.24))


func _two_handed() -> bool:
	return _held_node != null and _held_node.get_node_or_null("Foregrip") != null


func _setup_two_hands() -> void:
	_shouldered = false
	_hold = ""
	if not (body is AnimBody):
		return
	var sk: Skeleton3D = (body as AnimBody).skel
	if sk == null:
		return
	if _ik == null and _two_handed():
		_ik_left = Node3D.new()
		_ik_left.name = "LeftHandTarget"
		_ik_left.top_level = true
		add_child(_ik_left)
		_ik_right = Node3D.new()
		_ik_right.name = "RightHandTarget"
		_ik_right.top_level = true
		add_child(_ik_right)
		var pole_l := Node3D.new()
		pole_l.name = "LeftElbowPole"
		pole_l.position = Vector3(0.6, 0.5, 0.0)
		rig.add_child(pole_l)
		var pole_r := Node3D.new()
		pole_r.name = "RightElbowPole"
		pole_r.position = Vector3(-0.7, 0.6, -0.1)
		rig.add_child(pole_r)
		_ik = TwoBoneIK3D.new()
		_ik.name = "ArmsIK"
		sk.add_child(_ik)
		_ik.setting_count = 2
		for i in 2:
			var side := "L" if i == 0 else "R"
			_ik.set_root_bone_name(i, "DEF-upper_arm." + side)
			_ik.set_middle_bone_name(i, "DEF-forearm." + side)
			_ik.set_end_bone_name(i, "DEF-hand." + side)
		_ik.set_target_node(0, _ik.get_path_to(_ik_left))
		_ik.set_pole_node(0, _ik.get_path_to(pole_l))
		_ik.set_target_node(1, _ik.get_path_to(_ik_right))
		_ik.set_pole_node(1, _ik.get_path_to(pole_r))
	if _ik:
		_ik.active = false


func _update_two_hands() -> void:
	if _ik == null or _held_node == null:
		return
	var typ: String = _act.get("type", "")
	# у плеча — когда целится, стреляет, перезаряжает; иначе стоя или на ходу — «наготове» двумя руками
	var hold := ""
	if _two_handed() and pose == "":
		hold = "shoulder" if not moving and (aim_pose or typ in ["fire", "reload"]) else "low"
	var want := hold != ""
	if hold != _hold:
		_hold = hold
		_shouldered = hold == "shoulder"
		var hnd: Node3D = (body as AnimBody).hand()
		if want:
			if _held_node.get_parent() != rig:
				_held_node.reparent(rig, false)
			_held_node.transform = Transform3D(Basis.IDENTITY, SHOULDER) if _shouldered else LOW_READY
		else:
			_held_node.reparent(hnd, false)
			_held_node.transform = (body as AnimBody).grip(true)
	_ik.active = want
	if not want:
		return
	# оружие идёт за грудью: смещается вместе с корпусом (на бегу, при покачивании),
	# наклон корпуса берёт лишь отчасти — иначе на бегу ствол смотрел бы в землю
	var chest := _chest_attach()
	if chest:
		var in_rig := Transform3D(Basis.IDENTITY, SHOULDER) if _shouldered else LOW_READY
		var follow: Transform3D = chest.global_transform * (_chest_offset.affine_inverse() * in_rig)
		var base: Transform3D = rig.global_transform * in_rig
		var b := base.basis.orthonormalized().slerp(follow.basis.orthonormalized(), 0.35)
		_held_node.global_transform = Transform3D(b, follow.origin)
	var fg: Node3D = _held_node.get_node("Foregrip")
	var lp: Vector3 = fg.global_position
	if typ == "reload" and _held_node.get_node_or_null("Bolt"):
		var bolt: Node3D = _held_node.get_node("Bolt")
		var k: float = clampf(float(_act.t) / 1.2, 0.0, 1.0)
		# к затвору → оттянуть назад → дослать → обратно на цевьё
		var back: Vector3 = _held_node.global_transform.basis.z.normalized() * -0.09
		var bp: Vector3 = bolt.global_position
		if k < 0.25:
			lp = lp.lerp(bp, k / 0.25)
		elif k < 0.5:
			lp = bp.lerp(bp + back, (k - 0.25) / 0.25)
		elif k < 0.7:
			lp = (bp + back).lerp(bp, (k - 0.5) / 0.2)
		else:
			lp = bp.lerp(fg.global_position, (k - 0.7) / 0.3)
	_ik_left.global_position = lp
	_ik_right.global_position = _held_node.global_position


func _make_weapon_mesh(wkey: String) -> Node3D:
	# готовая модель из scenes/weapons (собирает tools/build_weapons.gd)
	var sp := "res://scenes/weapons/%s.tscn" % wkey
	if ResourceLoader.exists(sp):
		return (load(sp) as PackedScene).instantiate()
	var n := Node3D.new()
	var w := DB.weapon(wkey)
	var dark := Color("2b2925")
	var add := func(size: Vector3, pos: Vector3, c: Color) -> void:
		var m := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = size
		m.mesh = b
		var mat := StandardMaterial3D.new()
		mat.albedo_color = c
		mat.metallic = 0.4
		mat.roughness = 0.5
		m.material_override = mat
		m.position = pos
		n.add_child(m)
	match w.get("type", ""):
		"Guns":
			if w.get("two", false):
				add.call(Vector3(0.06, 0.1, 0.8), Vector3(0, 0, 0.25), dark)
				add.call(Vector3(0.05, 0.06, 0.25), Vector3(0, -0.02, -0.2), Color("5a3a22"))
			else:
				add.call(Vector3(0.05, 0.08, 0.24), Vector3(0, 0.03, 0.08), dark)
				add.call(Vector3(0.045, 0.12, 0.06), Vector3(0, -0.03, 0), dark)
				add.call(Vector3(0.052, 0.02, 0.16), Vector3(0, 0.075, 0.09), Color("d9622b"))
		"Battle", "Simple":
			var ln := 0.6 if w.get("type", "") == "Battle" else 0.45
			if wkey in ["knife", "oyun"]:
				ln = 0.2
			add.call(Vector3(0.04, 0.04, ln), Vector3(0, 0, ln / 2.0 - 0.05), Color("8a8a84") if wkey != "crowbar" else Color("8a2a1e"))
		_:
			pass
	return n


func muzzle_flash() -> void:
	# звук выстрела: чем дальше от героя, тем тише
	var loc := get_tree().get_first_node_in_group("location")
	if loc and loc.main and loc.main.player:
		var d: float = global_position.distance_to(loc.main.player.global_position)
		loc.main.sfx("shot_near" if d < 25.0 else "shot_far_%d" % randi_range(1, 3), clampf(-3.0 - d * 0.35, -30.0, -3.0), randf_range(0.92, 1.08))
	_flash.light_energy = 6.0
	var tw := create_tween()
	tw.tween_property(_flash, "light_energy", 0.0, 0.12)


# ---------------- процедурная анимация ----------------
func _animate(delta: float) -> void:
	var a := {}
	var v0 := Vector3.ZERO
	for k in ["spine", "head", "shR", "elR", "shL", "elL", "thR", "knR", "thL", "knL"]:
		a[k] = v0
	a["root_off"] = Vector3.ZERO
	var rig_rot_x := 0.0
	var rig_y := 0.0
	# дыхание
	a.spine = Vector3(sin(_t * 1.6) * 0.02, 0, 0)
	a.shR = Vector3(0, 0, 0.06)
	a.shL = Vector3(0, 0, -0.06)
	a.elR = Vector3(-0.12, 0, 0)
	a.elL = Vector3(-0.12, 0, 0)
	if moving:
		_walk_ph += delta * speed * 3.2
		var s := sin(_walk_ph)
		var c := cos(_walk_ph)
		a.thR = Vector3(-s * 0.55, 0, 0)
		a.thL = Vector3(s * 0.55, 0, 0)
		a.knR = Vector3(maxf(0.0, c) * 0.7, 0, 0)
		a.knL = Vector3(maxf(0.0, -c) * 0.7, 0, 0)
		a.shR = Vector3(s * 0.45, 0, 0.06)
		a.shL = Vector3(-s * 0.45, 0, -0.06)
		a.elR = Vector3(-0.35, 0, 0)
		a.elL = Vector3(-0.35, 0, 0)
		a.root_off = Vector3(0, absf(sin(_walk_ph)) * 0.035, 0)
	var gun := _held_key != "" and DB.is_gun(_held_key)
	if aim_pose and gun and not moving:
		a.shR = Vector3(-1.45, 0, 0.1)
		a.elR = Vector3(0, 0, 0)
		if DB.weapon(_held_key).get("two", false):
			a.shL = Vector3(-1.3, 0, -0.45)
			a.elL = Vector3(-0.4, 0, 0)
	match pose:
		"dead":
			rig_rot_x = -1.45
			rig_y = 0.18
			a.shR = Vector3(0, 0, 0.5)
			a.shL = Vector3(0, 0, -0.4)
		"yield":
			a.shR = Vector3(0, 0, 2.8)
			a.shL = Vector3(0, 0, -2.8)
			a.elR = Vector3(0, 0, 0.3)
			a.elL = Vector3(0, 0, -0.3)
		"down", "sit":
			a.thR = Vector3(-1.4, 0, 0.1)
			a.thL = Vector3(-1.4, 0, -0.1)
			a.knR = Vector3(1.5, 0, 0)
			a.knL = Vector3(1.5, 0, 0)
			a.root_off = Vector3(0, -0.42, 0)
			a.spine = Vector3(-0.15 if pose == "sit" else 0.35, 0, 0)
			if pose == "down":
				a.head = Vector3(0.4, 0, 0)
	if not _act.is_empty():
		_act.t += delta
		var t: float = _act.t
		match _act.type:
			"swing":
				var k := 0.0
				if t < 0.18:
					k = t / 0.18
					a.shR = Vector3(lerpf(0, -2.5, k), 0, 0.2)
					a.elR = Vector3(-0.6 * k, 0, 0)
				elif t < 0.32:
					k = (t - 0.18) / 0.14
					a.shR = Vector3(lerpf(-2.5, -0.5, k), 0, 0.2)
					a.spine = Vector3(-0.2 * k, 0.3 * k, 0)
					_fire_cb_once()
				elif t < 0.55:
					a.shR = Vector3(-0.5, 0, 0.2)
				else:
					_end_act()
			"fire":
				var n := int(_act.extra.get("n", 1))
				a.shR = Vector3(-1.45, 0, 0.1)
				a.elR = Vector3.ZERO
				if DB.weapon(_held_key).get("two", false):
					a.shL = Vector3(-1.3, 0, -0.45)
					a.elL = Vector3(-0.4, 0, 0)
				var shots_done := int(_act.get("shots", 0))
				var next_at := 0.2 + shots_done * 0.14
				if shots_done < n and t >= next_at:
					_act["shots"] = shots_done + 1
					muzzle_flash()
					a.shR.x -= 0.15
					var per: Callable = _act.extra.get("per_shot", Callable())
					if per.is_valid():
						per.call(shots_done)
				if shots_done >= n and t > next_at + 0.25:
					_end_act()
			"hit":
				a.spine = Vector3(0.28 * maxf(0, 1.0 - t / 0.3), 0, 0)
				a.head = Vector3(0.3 * maxf(0, 1.0 - t / 0.3), 0, 0)
				if t > 0.3:
					_end_act()
			"pickup":
				var k2 := sin(clampf(t / 0.7, 0, 1) * PI)
				a.spine = Vector3(-0.9 * k2, 0, 0)
				a.thR = Vector3(-0.5 * k2, 0, 0)
				a.thL = Vector3(-0.5 * k2, 0, 0)
				a.knR = Vector3(0.9 * k2, 0, 0)
				a.knL = Vector3(0.9 * k2, 0, 0)
				a.root_off = Vector3(0, -0.18 * k2, 0)
				a.shR = Vector3(-0.9 * k2, 0, 0)
				if t > 0.35:
					_fire_cb_once()
				if t > 0.7:
					_end_act()
			"wave":
				a.shR = Vector3(0, 0, 2.5)
				a.elR = Vector3(0, 0, 0.5 + sin(t * 14.0) * 0.4)
				if t > 0.9:
					_end_act()
			"reload":
				a.shR = Vector3(-0.9, 0, 0.1)
				a.elR = Vector3(-0.9, 0, 0)
				a.shL = Vector3(-0.9, 0, -0.1)
				a.elL = Vector3(-1.0 - sin(t * 12) * 0.2, 0, 0)
				if t > 0.6:
					_end_act()
	rig.rotation.x = rig_rot_x
	rig.position.y = rig_y
	body.apply(a)


# ---------------- готовые анимации (AnimBody) ----------------
## Скорость (м/с), с которой клип ходьбы/бега/крадучись выглядит естественно
const WALK_CLIP_SPEED := 1.4
const JOG_CLIP_SPEED := 3.4
const CROUCH_CLIP_SPEED := 1.2
var _clip_started := false


func _animate_clips(delta: float) -> void:
	var ab: AnimBody = body
	if not _act.is_empty():
		_act.t += delta
		_clip_act(ab, _act.t)
		if not _act.is_empty():
			return
	var gun := _held_key != "" and DB.is_gun(_held_key)
	var first := not _clip_started
	_clip_started = true
	match pose:
		"dead":
			# труп с начала уровня не должен падать у игрока на глазах
			ab.play("Death01", 0.25, 1.0, false, first)
		"sit":
			# сидит на скамейке или стуле (сиденье ставит генератор уровня)
			ab.play("Sitting_Idle", 0.3)
		"down":
			# раненый лежит на земле
			ab.play("Death01", 0.4, 1.0, false, first)
		"yield":
			ab.play("Crouch_Idle", 0.3)
		_:
			var sneak := is_player and bool(Game.hero.get("sneak", false))
			if sneak and moving:
				ab.play("Crouch_Fwd", 0.2, clampf(speed / CROUCH_CLIP_SPEED, 0.6, 1.8))
			elif sneak:
				ab.play("Crouch_Idle", 0.3)
			elif moving:
				if speed < 2.2:
					ab.play("Walk", 0.2, clampf(speed / WALK_CLIP_SPEED, 0.6, 1.8))
				else:
					ab.play("Jog_Fwd", 0.2, clampf(speed / JOG_CLIP_SPEED, 0.6, 1.8))
			elif aim_pose and gun:
				ab.play("Pistol_Idle", 0.25)
			else:
				ab.play("Idle", 0.3)


## Клип для действия: [имя, скорость, момент срабатывания (с), конец (с)]
func _act_clip(type: String) -> Array:
	match type:
		"swing":
			if _held_key == "" or _held_key == "fists":
				return ["Punch_Jab", 1.2, 0.3, 0.7]
			return ["Sword_Attack", 1.4, 0.45, 1.0]
		"hit":
			return ["Hit_Chest", 1.0, 0.35, 0.35]
		"pickup":
			return ["PickUp_Table", 1.0, 0.45, 0.8]
		"wave":
			return ["Interact", 1.3, 1.2, 1.2]
		"reload":
			return ["Pistol_Reload", 1.4, 1.15, 1.15]
	return []


func _clip_act(ab: AnimBody, t: float) -> void:
	if _act.type == "fire":
		var n := int(_act.extra.get("n", 1))
		var shots := int(_act.get("shots", 0))
		var next_at := 0.15 + shots * 0.28
		if shots < n and t >= next_at:
			_act["shots"] = shots + 1
			ab.play("Pistol_Shoot", 0.05, 1.3, true)
			muzzle_flash()
			var per: Callable = _act.extra.get("per_shot", Callable())
			if per.is_valid():
				per.call(shots)
		elif shots == 0:
			ab.play("Pistol_Idle", 0.1)
		if shots >= n and t > next_at + 0.3:
			_end_act()
		return
	if _act.type == "plug":
		_plug_tick(ab, t)
		return
	if _act.type == "reload" and _two_handed():
		ab.play("Pistol_Idle", 0.15)
		if t >= 0.6:
			_fire_cb_once()
		if t >= 1.2:
			_sound_bolt()
			_end_act()
		return
	var c := _act_clip(_act.type)
	# на время удара оружие — вперёд из кулака, потом снова вниз
	if _act.type == "swing" and _held_node and not DB.is_gun(_held_key) and not _act.has("swing_grip"):
		_act["swing_grip"] = true
		_held_node.transform = ab.grip(false, true)
	if c.is_empty() or not ab.has(c[0]):
		_fire_cb_once()
		_end_act()
		return
	if not _act.has("clip_on"):
		_act["clip_on"] = true
		ab.play(c[0], 0.1, c[1], true)
	if t >= c[2]:
		_fire_cb_once()
	if t >= c[3]:
		_end_act()


func _fire_cb_once() -> void:
	if _act.get("done", false):
		return
	_act.done = true
	var cb: Callable = _act.get("cb", Callable())
	if cb.is_valid() and _act.type != "fire":
		cb.call()


func _end_act() -> void:
	if _act.get("swing_grip", false) and _held_node and body is AnimBody:
		_held_node.transform = (body as AnimBody).grip(false, false, _held_key in SHORT_BLADES)
	var cb: Callable = _act.get("cb", Callable())
	var typ: String = _act.get("type", "")
	var was_done: bool = _act.get("done", false)
	_act = {}
	if typ == "fire" and cb.is_valid():
		cb.call()
	elif not was_done and cb.is_valid():
		cb.call()


# ---------------- браслет и подключение компьютера ----------------
func show_bracelet(on: bool) -> void:
	if not (body is AnimBody):
		return
	var hl: Node3D = (body as AnimBody).hand_l()
	if hl == null:
		return
	if _bracelet == null and on:
		_bracelet = Node3D.new()
		var band := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.042
		cm.bottom_radius = 0.046
		cm.height = 0.06
		band.mesh = cm
		band.material_override = _plain(Color("26241f"), 0.4, 0.5)
		_bracelet.add_child(band)
		var led := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.012
		sm.height = 0.024
		led.mesh = sm
		var lm := _plain(Color("ffb040"), 0.3)
		lm.emission_enabled = true
		lm.emission = Color("ffb040")
		lm.emission_energy_multiplier = 2.0
		led.material_override = lm
		led.position = Vector3(0, 0, 0.045)
		_bracelet.add_child(led)
		_bracelet.position = Vector3(0, -0.02, 0)
		hl.add_child(_bracelet)
	if _bracelet:
		_bracelet.visible = on


func _plain(c: Color, rough := 0.7, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	return m


## Компьютер в правой руке, кабель тянется к браслету на левой, щелчок — экран загорается.
## extra.dur — длительность (первый раз дольше).
func _plug_tick(ab: AnimBody, t: float) -> void:
	var dur: float = float(_act.extra.get("dur", 1.2))
	var hold := minf(0.5, dur * 0.3)
	if not _act.has("clip_on"):
		_act["clip_on"] = true
		# доводим клип до середины (руки у груди) ровно к моменту hold и держим
		ab.play("Pistol_Reload", 0.15, ab.length("Pistol_Reload") * 0.5 / hold, true)
		_plug_build(ab)
	if t >= hold and not _act.has("held"):
		_act["held"] = true
		ab.anim.speed_scale = 0.0
		ab.anim.seek(ab.length("Pistol_Reload") * 0.5, true)
	var k := clampf((t - hold) / maxf(0.01, dur - hold - 0.35), 0.0, 1.0)
	_plug_update(k)
	if k >= 0.6 and not _act.has("clicked"):
		_act["clicked"] = true
		_sound("plug", -4.0)
	if k >= 0.85 and not _act.has("beeped"):
		_act["beeped"] = true
		_sound("beep", -9.0)
	if t >= dur:
		ab.anim.speed_scale = 1.0
		_plug_clear()
		_fire_cb_once()
		_end_act()


func _sound(n: String, db: float) -> void:
	var loc := get_tree().get_first_node_in_group("location")
	if loc and loc.main:
		loc.main.sfx(n, db)


func _plug_build(ab: AnimBody) -> void:
	_plug_clear()
	show_bracelet(true)
	if _held_node:
		_held_node.visible = false
	var hr := ab.hand()
	if hr == null:
		return
	_plug_dev = Node3D.new()
	var case := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.11, 0.025, 0.08)
	case.mesh = bm
	case.material_override = _plain(Color("7a7466"), 0.6, 0.2)
	_plug_dev.add_child(case)
	var scr := MeshInstance3D.new()
	var sb := BoxMesh.new()
	sb.size = Vector3(0.085, 0.004, 0.055)
	scr.mesh = sb
	scr.name = "Screen"
	scr.material_override = _plain(Color("15201a"), 0.3)
	scr.position = Vector3(0, 0.014, 0)
	_plug_dev.add_child(scr)
	_plug_dev.position = Vector3(0, 0.08, 0.02)
	hr.add_child(_plug_dev)
	for i in 2:
		var seg := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.007
		cm.bottom_radius = 0.007
		cm.height = 1.0
		cm.radial_segments = 6
		seg.mesh = cm
		seg.material_override = _plain(Color("141210"), 0.5)
		seg.top_level = true
		add_child(seg)
		_plug_cable.append(seg)
	_plug_label = Label3D.new()
	_plug_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_plug_label.no_depth_test = true
	_plug_label.pixel_size = 0.004
	_plug_label.font_size = 32
	_plug_label.outline_size = 8
	_plug_label.modulate = Color("b8f0a8")
	_plug_label.text = ""
	_plug_label.top_level = true
	add_child(_plug_label)


func _plug_update(k: float) -> void:
	if _plug_dev == null or not is_instance_valid(_plug_dev) or _bracelet == null:
		return
	var port: Vector3 = _plug_dev.global_transform * Vector3(-0.06, 0, 0)
	var wrist: Vector3 = _bracelet.global_position
	var e := k * k * (3.0 - 2.0 * k)
	var tip := port.lerp(wrist, clampf(e * 1.7, 0.0, 1.0))
	var mid := (port + tip) / 2.0 - Vector3(0, 0.06 + 0.1 * (1.0 - e), 0)
	_seg(_plug_cable[0], port, mid)
	_seg(_plug_cable[1], mid, tip)
	var on := k >= 0.6
	var scr := _plug_dev.get_node("Screen") as MeshInstance3D
	var m := scr.material_override as StandardMaterial3D
	if on and not m.emission_enabled:
		m.albedo_color = Color("3f8a4a")
		m.emission_enabled = true
		m.emission = Color("5fd070")
		m.emission_energy_multiplier = 1.5
	_plug_label.global_position = _plug_dev.global_position + Vector3(0, 0.35, 0)
	_plug_label.text = ("CT14 inc.\n" + ("ПОДКЛЮЧЕНО" if k >= 0.85 else "СВЯЗЬ С НОСИТЕЛЕМ...")) if on else ""


func _seg(mi: MeshInstance3D, a: Vector3, b: Vector3) -> void:
	var d := b - a
	var ln := maxf(0.001, d.length())
	var up := d / ln
	var side := up.cross(Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	var fwd := side.cross(up)
	mi.global_transform = Transform3D(Basis(side, up * ln, fwd), (a + b) / 2.0)


func _plug_clear() -> void:
	if _plug_dev and is_instance_valid(_plug_dev):
		_plug_dev.queue_free()
	_plug_dev = null
	for c in _plug_cable:
		if is_instance_valid(c):
			c.queue_free()
	_plug_cable.clear()
	if _plug_label and is_instance_valid(_plug_label):
		_plug_label.queue_free()
	_plug_label = null
	if _held_node:
		_held_node.visible = true


# ---------------- отметки: силуэт, кружок, стелс ----------------
func _collect_meshes(n: Node) -> void:
	if n is MeshInstance3D:
		_body_meshes.append(n)
	for c in n.get_children():
		_collect_meshes(c)


func _mark_kind() -> String:
	if tpl.get("dummy", false) or not visible:
		return "none"
	if is_player:
		return "hero"
	if pose == "dead":
		var loc := get_tree().get_first_node_in_group("location")
		if loc and not loc.ws().looted.has(uid()):
			return "corpse"
		return "none"
	if pose in ["sit", "down"] and not hostile:
		# сидящих за столом и лежащих на кровати видно и так;
		# кружок и силуэт пробивались бы сквозь скамейку или кровать
		return "none"
	if hostile or attitude == "enemy":
		return "enemy"
	if attitude == "neutral" or (attitude == "" and tpl.get("neutral", false)):
		return "neutral"
	return "friend"


func _update_marks() -> void:
	var k := _mark_kind()
	if k != _mark:
		_mark = k
		var sil: Color = MARKS[k][0]
		var ov: Material = null if sil.a <= 0.0 else _sil_mat(sil)
		for m in _body_meshes:
			if is_instance_valid(m):
				(m as MeshInstance3D).material_overlay = ov
				if ov:
					_stencil_write(m)
		var rc: Color = MARKS[k][1]
		if rc.a > 0.0:
			if _ring == null:
				_ring = MeshInstance3D.new()
				var tm := TorusMesh.new()
				tm.inner_radius = 0.38
				tm.outer_radius = 0.43
				tm.rings = 24
				tm.ring_segments = 4
				_ring.mesh = tm
				_ring.scale = Vector3(1, 0.08, 1)
				_ring.position = Vector3(0, 0.03, 0)
				_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				add_child(_ring)
			_ring.material_override = _ring_mat(rc)
			_ring.visible = true
		elif _ring:
			_ring.visible = false
	# герой крадётся или прячется — становится полупрозрачным
	if is_player:
		var sneak := bool(Game.hero.get("sneak", false))
		var target := 0.5 if sneak else 0.0
		if target != _see_through:
			_see_through = target
			_set_ghost(sneak)


## Полупрозрачность: подменяем материалы тела копиями с прозрачностью
## (работает на любом рендерере), при выходе из стелса возвращаем исходные.
var _ghost_saved := {}


func _set_ghost(on: bool) -> void:
	for m in _body_meshes:
		if not is_instance_valid(m):
			continue
		var mi := m as MeshInstance3D
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var key := "%d/%d" % [mi.get_instance_id(), i]
			if on:
				var src := mi.get_surface_override_material(i)
				_ghost_saved[key] = src
				var base: Material = src if src else mi.mesh.surface_get_material(i)
				if base is BaseMaterial3D:
					var g := (base as BaseMaterial3D).duplicate() as BaseMaterial3D
					g.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
					g.albedo_color.a = 0.45
					mi.set_surface_override_material(i, g)
			elif _ghost_saved.has(key):
				mi.set_surface_override_material(i, _ghost_saved[key])
	if not on:
		_ghost_saved.clear()


## Материалы тела пишут 1 в трафарет: по нему силуэт отличает «тело видно» от «тело заслонено»
func _stencil_write(mi: MeshInstance3D) -> void:
	if mi.mesh == null:
		return
	for i in mi.mesh.get_surface_count():
		var src := mi.get_surface_override_material(i)
		var base: Material = src if src else mi.mesh.surface_get_material(i)
		if not base is BaseMaterial3D or (base as BaseMaterial3D).stencil_mode == BaseMaterial3D.STENCIL_MODE_CUSTOM:
			continue
		var key := "st%d" % base.get_instance_id()
		if not _mats.has(key):
			var m := (base as BaseMaterial3D).duplicate() as BaseMaterial3D
			m.stencil_mode = BaseMaterial3D.STENCIL_MODE_CUSTOM
			m.stencil_flags = BaseMaterial3D.STENCIL_FLAG_WRITE
			m.stencil_compare = BaseMaterial3D.STENCIL_COMPARE_ALWAYS
			m.stencil_reference = 1
			_mats[key] = m
		mi.set_surface_override_material(i, _mats[key])


static func _sil_mat(c: Color, ghost := 0.0) -> ShaderMaterial:
	var key := "s" + c.to_html() + str(ghost)
	if not _mats.has(key):
		var m := ShaderMaterial.new()
		m.shader = load("res://assets/shaders/xray_silhouette.gdshader")
		m.set_shader_parameter("color", c)
		m.set_shader_parameter("ghost", ghost)
		_mats[key] = m
	return _mats[key]


static func _ring_mat(c: Color) -> StandardMaterial3D:
	var key := "r" + c.to_html()
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = c
		m.no_depth_test = false
		_mats[key] = m
	return _mats[key]


func _sound_bolt() -> void:
	_sound("plug", -8.0)
