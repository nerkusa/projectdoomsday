extends SceneTree
## Карты костей для переноса анимаций (retarget) на «человеческий» скелет Godot:
## Rigify (DEF-… из Universal Animation Library) и Mixamo (mixamorig:…).
## Запуск: godot --headless --path . --script tools/make_bonemaps.gd

const SIDES := {"Left": "L", "Right": "R"}


func _init() -> void:
	var rig := {"Hips": "DEF-hips", "Spine": "DEF-spine.001", "Chest": "DEF-spine.002", "UpperChest": "DEF-spine.003",
		"Neck": "DEF-neck", "Head": "DEF-head"}
	var mix := {"Hips": "mixamorig_Hips", "Spine": "mixamorig_Spine", "Chest": "mixamorig_Spine1", "UpperChest": "mixamorig_Spine2",
		"Neck": "mixamorig_Neck", "Head": "mixamorig_Head"}
	for side in SIDES:
		var s: String = SIDES[side]
		rig[side + "Shoulder"] = "DEF-shoulder." + s
		rig[side + "UpperArm"] = "DEF-upper_arm." + s
		rig[side + "LowerArm"] = "DEF-forearm." + s
		rig[side + "Hand"] = "DEF-hand." + s
		rig[side + "UpperLeg"] = "DEF-thigh." + s
		rig[side + "LowerLeg"] = "DEF-shin." + s
		rig[side + "Foot"] = "DEF-foot." + s
		rig[side + "Toes"] = "DEF-toe." + s
		mix[side + "Shoulder"] = "mixamorig_%sShoulder" % side
		mix[side + "UpperArm"] = "mixamorig_%sArm" % side
		mix[side + "LowerArm"] = "mixamorig_%sForeArm" % side
		mix[side + "Hand"] = "mixamorig_%sHand" % side
		mix[side + "UpperLeg"] = "mixamorig_%sUpLeg" % side
		mix[side + "LowerLeg"] = "mixamorig_%sLeg" % side
		mix[side + "Foot"] = "mixamorig_%sFoot" % side
		mix[side + "Toes"] = "mixamorig_%sToeBase" % side
		var thumb := ["ThumbMetacarpal", "ThumbProximal", "ThumbDistal"]
		for i in 3:
			rig[side + thumb[i]] = "DEF-thumb.0%d.%s" % [i + 1, s]
			mix[side + thumb[i]] = "mixamorig_%sHandThumb%d" % [side, i + 1]
		for f in [["Index", "f_index", "Index"], ["Middle", "f_middle", "Middle"], ["Ring", "f_ring", "Ring"], ["Little", "f_pinky", "Pinky"]]:
			var parts := ["Proximal", "Intermediate", "Distal"]
			for i in 3:
				rig[side + f[0] + parts[i]] = "DEF-%s.0%d.%s" % [f[1], i + 1, s]
				mix[side + f[0] + parts[i]] = "mixamorig_%sHand%s%d" % [side, f[2], i + 1]
	for spec in [["res://assets/models/bonemap_rigify.tres", rig], ["res://assets/models/bonemap_mixamo.tres", mix]]:
		var bm := BoneMap.new()
		bm.profile = SkeletonProfileHumanoid.new()
		var d: Dictionary = spec[1]
		for k in d:
			bm.set_skeleton_bone_name(StringName(k), StringName(d[k]))
		ResourceSaver.save(bm, spec[0])
		print("Сохранено: ", spec[0], " костей ", d.size())
	quit()
