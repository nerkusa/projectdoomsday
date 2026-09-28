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
