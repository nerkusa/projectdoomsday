class_name PostFX
extends CanvasLayer
## Фильтр картинки поверх 3D (под интерфейсом): режимы из настроек графики — «нет», «Кино»,
## «Плёнка». Шейдер — assets/shaders/post_fx.gdshader.

const MODES := {
	# тёплый, сочный: золотистый свет, чуть синеватые тени
	"film": {"sharpen": 0.3, "contrast": 1.12, "saturation": 1.12, "exposure": 1.02,
		"shadow_tint": Vector3(-0.02, 0.0, 0.035), "light_tint": Vector3(1.06, 1.0, 0.9), "vignette": 0.38, "grain": 0.03},
	# выцветшая плёнка: холоднее, приглушённые цвета, сильнее зерно — мир после конца
	"bleak": {"sharpen": 0.3, "contrast": 1.15, "saturation": 0.72, "exposure": 1.0,
		"shadow_tint": Vector3(0.0, 0.02, 0.04), "light_tint": Vector3(1.04, 1.02, 0.94), "vignette": 0.45, "grain": 0.05},
}

var _rect: ColorRect
var _mat: ShaderMaterial


func _ready() -> void:
	layer = -1
	add_to_group("post_fx")
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://assets/shaders/post_fx.gdshader")
	_rect.material = _mat
	add_child(_rect)
	visible = false


func set_mode(mode: String) -> void:
	if not MODES.has(mode):
		visible = false
		return
	for k in MODES[mode]:
		_mat.set_shader_parameter(k, MODES[mode][k])
	visible = true
