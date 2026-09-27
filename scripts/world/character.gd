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
## Поза с начала: "", "sit", "down", "yield"
@export var start_pose := ""
## Показывать героя моделью из hero.glb
@export var use_hero_model := false

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
var is_player := false
var aim_pose := false


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
		set_held(tpl.weapon if hostile else "")


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
	if use_hero_model:
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
	_animate(delta)


# ---------------- действия (анимации с обратным вызовом) ----------------
## type: swing | fire | hit | pickup | wave | reload | shoot_burst
func act(type: String, cb := Callable(), extra := {}) -> void:
	_act = {"type": type, "t": 0.0, "cb": cb, "done": false, "extra": extra}


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
	hnd.add_child(_held_node)


func _make_weapon_mesh(wkey: String) -> Node3D:
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
			if wkey == "knife":
				ln = 0.2
			add.call(Vector3(0.04, 0.04, ln), Vector3(0, 0, ln / 2.0 - 0.05), Color("8a8a84") if wkey != "crowbar" else Color("8a2a1e"))
		_:
			pass
	return n


func muzzle_flash() -> void:
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


func _fire_cb_once() -> void:
	if _act.get("done", false):
		return
	_act.done = true
	var cb: Callable = _act.get("cb", Callable())
	if cb.is_valid() and _act.type != "fire":
		cb.call()


func _end_act() -> void:
	var cb: Callable = _act.get("cb", Callable())
	var typ: String = _act.get("type", "")
	var was_done: bool = _act.get("done", false)
	_act = {}
	if typ == "fire" and cb.is_valid():
		cb.call()
	elif not was_done and cb.is_valid():
		cb.call()
