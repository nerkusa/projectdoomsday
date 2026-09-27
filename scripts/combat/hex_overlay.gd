class_name HexOverlay
extends Node3D
## Подсветка гексов в бою: куда можно дойти, путь, цели, контур поля боя.

const COLORS := {
	"reach": Color(1.0, 0.7, 0.28, 0.16),
	"path": Color(1.0, 0.7, 0.28, 0.5),
	"target": Color(1.0, 0.35, 0.23, 0.45),
	"self": Color(0.5, 0.86, 0.48, 0.4),
	"far": Color(0.48, 0.42, 0.33, 0.32),
}

var _mm: MultiMeshInstance3D
var _lines: MeshInstance3D
var _last_center := Vector2i(99999, 99999)


func _ready() -> void:
	var disc := CylinderMesh.new()
	disc.top_radius = HexGrid.HEX * 0.9
	disc.bottom_radius = HexGrid.HEX * 0.9
	disc.height = 0.01
	disc.radial_segments = 6
	disc.rings = 1
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.no_depth_test = false
	mat.render_priority = 1
	disc.material = mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = disc
	mm.instance_count = 700
	mm.visible_instance_count = 0
	_mm = MultiMeshInstance3D.new()
	_mm.multimesh = mm
	_mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mm)
	_lines = MeshInstance3D.new()
	var lm := StandardMaterial3D.new()
	lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	lm.albedo_color = Color(1.0, 0.7, 0.28, 0.22)
	_lines.material_override = lm
	_lines.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_lines)
	visible = false


## cells: [[Vector2i, "reach"|"path"|...], ...]
func show_cells(grid: HexGrid, cells: Array, unit_hexes: Array) -> void:
	var mm := _mm.multimesh
	var n := mini(cells.size(), mm.instance_count)
	# поворот на 30°, чтобы шестиугольник лёг «острым верхом»
	var basis := Basis(Vector3.UP, PI / 6.0)
	for i in n:
		var h: Vector2i = cells[i][0]
		var w := grid.to_world(h)
		mm.set_instance_transform(i, Transform3D(basis, w + Vector3(0, 0.03 + 0.001 * (i % 3), 0)))
		mm.set_instance_color(i, COLORS.get(cells[i][1], Color.WHITE))
	mm.visible_instance_count = n
	_rebuild_outline(grid, unit_hexes)


func _rebuild_outline(grid: HexGrid, hs: Array) -> void:
	if hs.is_empty():
		return
	var cq := 0.0
	var cr := 0.0
	for h in hs:
		cq += h.x
		cr += h.y
	var c := Vector2i(roundi(cq / hs.size()), roundi(cr / hs.size()))
	var far := 0
	for h in hs:
		far = maxi(far, grid.distance(h, c))
	var rad := maxi(13, far + 9)
	var key := Vector2i(c.x * 1000 + rad, c.y)
	if key == _last_center:
		return
	_last_center = key
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	for dq in range(-rad, rad + 1):
		for dr in range(maxi(-rad, -dq - rad), mini(rad, -dq + rad) + 1):
			var h := Vector2i(c.x + dq, c.y + dr)
			if not grid.is_free(h):
				continue
			var w := grid.to_world(h)
			for i in 6:
				var a1 := PI / 6.0 + i * PI / 3.0
				var a2 := a1 + PI / 3.0
				im.surface_add_vertex(Vector3(w.x + HexGrid.HEX * cos(a1), 0.035, w.z + HexGrid.HEX * sin(a1)))
				im.surface_add_vertex(Vector3(w.x + HexGrid.HEX * cos(a2), 0.035, w.z + HexGrid.HEX * sin(a2)))
	im.surface_end()
	_lines.mesh = im


func reset() -> void:
	_last_center = Vector2i(99999, 99999)
	_mm.multimesh.visible_instance_count = 0
