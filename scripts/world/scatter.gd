@tool
class_name Scatter
extends MultiMeshInstance3D
## Россыпь одинаковых мелочей (трава, камыш, кочки, лужи) — одна отрисовка на всех.
## Положения хранятся в transforms: сам MultiMesh в сцене не сохраняет их надёжно,
## поэтому он собирается заново при загрузке.

@export var mesh: Mesh
@export var transforms: Array[Transform3D] = []


func _ready() -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
	multimesh = mm
	# трава и камыш рисуются в прозрачном проходе: они не попадают в буфер глубины,
	# по которому строится силуэт героя, — иначе травинка у ноги давала голубое пятно
	var am := mesh as ArrayMesh
	if am == null:
		return
	var copy: ArrayMesh = null
	for i in am.get_surface_count():
		var m := am.surface_get_material(i) as BaseMaterial3D
		if m == null or m.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
			continue
		if copy == null:
			copy = am.duplicate() as ArrayMesh
		var t := m.duplicate() as BaseMaterial3D
		t.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		t.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS
		copy.surface_set_material(i, t)
	if copy:
		mm.mesh = copy
