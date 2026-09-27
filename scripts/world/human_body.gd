@tool
class_name HumanBody
extends Node3D
## Процедурный человечек из брусков (как makeHuman в прототипе).
## Суставы совпадают с костями модели героя, поэтому анимация общая.
## Смотрит вдоль +Z.

const J := {"hipY": .774, "hipX": .117, "kneeY": .414, "neckY": 1.512, "shX": .216, "shY": 1.386}
const L1 := 0.232

var joints: Dictionary = {}
var _hand: Node3D
var look: Dictionary = {}


func build(lk: Dictionary) -> void:
	look = lk
	var skin := _col("skin", Color("c49a74"))
	var top := _col("top", Color("4b5142"))
	var pants := _col("pants", Color("3a4552"))
	var boots := _col("boots", Color("2a2520"))
	var hair := _col("hair", Color("1c1612"))
	var root := _pivot("root", self, Vector3(0, J.hipY, 0))
	var spine := _pivot("spine", root, Vector3.ZERO)
	_box(spine, Vector3(0.34, 0.2, 0.2), Vector3(0, 0.06, 0), pants)
	_box(spine, Vector3(0.4, 0.56, 0.24), Vector3(0, 0.42, 0), top)
	if lk.has("vest"):
		_box(spine, Vector3(0.42, 0.4, 0.26), Vector3(0, 0.46, 0), _col("vest", Color.BROWN))
	var head := _pivot("head", spine, Vector3(0, J.neckY - J.hipY, 0))
	_box(head, Vector3(0.1, 0.08, 0.1), Vector3(0, 0.02, 0), skin)
	_box(head, Vector3(0.22, 0.26, 0.24), Vector3(0, 0.17, 0), skin)
	_box(head, Vector3(0.24, 0.08, 0.26), Vector3(0, 0.3, -0.01), hair)
	if lk.has("cap"):
		_box(head, Vector3(0.26, 0.07, 0.28), Vector3(0, 0.33, 0), _col("cap", Color.DIM_GRAY))
		_box(head, Vector3(0.22, 0.02, 0.1), Vector3(0, 0.3, 0.16), _col("cap", Color.DIM_GRAY))
	if lk.has("helmet"):
		_box(head, Vector3(0.28, 0.14, 0.3), Vector3(0, 0.32, 0), _col("helmet", Color.DIM_GRAY))
	if lk.has("beard"):
		_box(head, Vector3(0.2, 0.1, 0.06), Vector3(0, 0.08, 0.11), _col("beard", Color.SADDLE_BROWN))
	if lk.get("glasses", false):
		_box(head, Vector3(0.2, 0.04, 0.03), Vector3(0, 0.19, 0.125), Color("151515"))
	if lk.get("mask", false):
		_box(head, Vector3(0.18, 0.1, 0.05), Vector3(0, 0.11, 0.12), Color("2a2d2a"))
	for s in [1, -1]:
		var n := "R" if s > 0 else "L"
		var sh := _pivot("sh" + n, spine, Vector3(s * J.shX, J.shY - J.hipY, 0))
		_box(sh, Vector3(0.12, L1 + 0.04, 0.13), Vector3(0, -L1 / 2.0, 0), top)
		var el := _pivot("el" + n, sh, Vector3(0, -L1, 0))
		_box(el, Vector3(0.1, L1, 0.11), Vector3(0, -L1 / 2.0, 0), top)
		_box(el, Vector3(0.09, 0.09, 0.09), Vector3(0, -L1 - 0.04, 0), skin)
		if n == "R":
			_hand = Node3D.new()
			_hand.name = "Hand"
			_hand.position = Vector3(0, -L1 - 0.05, 0.02)
			el.add_child(_hand)
		var th := _pivot("th" + n, root, Vector3(s * J.hipX, 0, 0))
		_box(th, Vector3(0.15, J.hipY - J.kneeY, 0.16), Vector3(0, -(J.hipY - J.kneeY) / 2.0, 0), pants)
		var kn := _pivot("kn" + n, th, Vector3(0, J.kneeY - J.hipY, 0))
		_box(kn, Vector3(0.13, J.kneeY - 0.06, 0.14), Vector3(0, -(J.kneeY - 0.06) / 2.0, 0), pants)
		_box(kn, Vector3(0.14, 0.08, 0.24), Vector3(0, -J.kneeY + 0.04, 0.04), boots)


func hand() -> Node3D:
	return _hand


func apply(a: Dictionary) -> void:
	for k in joints:
		var v = a.get(k, Vector3.ZERO)
		joints[k].rotation = v
	joints.root.position = Vector3(0, J.hipY, 0) + a.get("root_off", Vector3.ZERO)


func _col(k: String, def: Color) -> Color:
	var v = look.get(k, null)
	if v == null:
		return def
	return Color(str(v))


func _pivot(n: String, parent: Node3D, pos: Vector3) -> Node3D:
	var p := Node3D.new()
	p.name = n
	p.position = pos
	parent.add_child(p)
	joints[n] = p
	return p


static var _mats: Dictionary = {}


func _box(parent: Node3D, size: Vector3, pos: Vector3, c: Color) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	m.mesh = b
	var key := c.to_html()
	if not _mats.has(key):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = c
		mat.roughness = 0.9
		_mats[key] = mat
	m.material_override = _mats[key]
	m.position = pos
	parent.add_child(m)
	return m
