class_name ArmLength
extends SkeletonModifier3D
## Укорачивает (или удлиняет) руки скелета UAL для модели с другими пропорциями:
## локальные смещения предплечья и кисти умножаются на k после анимации — анимации
## остаются общими для всех, меняется только длина костей. Коэффициент считает
## tools/rig_hero_model.py (assets/models/*_rig.json → "arm_k").

@export var k := 1.0
var _bones: PackedInt32Array = []


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null or is_equal_approx(k, 1.0):
		return
	if _bones.is_empty():
		for n in ["DEF-forearm.L", "DEF-hand.L", "DEF-forearm.R", "DEF-hand.R"]:
			var i := sk.find_bone(n)
			if i >= 0:
				_bones.append(i)
	for i in _bones:
		sk.set_bone_pose_position(i, sk.get_bone_pose_position(i) * k)
