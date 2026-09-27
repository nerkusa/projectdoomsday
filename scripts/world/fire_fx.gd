@tool
class_name FireFX
extends Node3D
## Огонь: мерцающий свет, языки пламени и столб дыма.

@export var strength := 1.0

var _light: OmniLight3D
var _t := 0.0


func _ready() -> void:
	_light = OmniLight3D.new()
	_light.light_color = Color("ff8a3a")
	_light.omni_range = 7.0 * strength
	_light.light_energy = 2.5
	_light.shadow_enabled = false
	_light.position = Vector3(0, 0.8, 0)
	add_child(_light)
	add_child(_particles(false))
	add_child(_particles(true))


func _particles(smoke: bool) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 26 if smoke else 40
	p.lifetime = 4.0 if smoke else 0.9
	p.preprocess = 2.0
	var m := ParticleProcessMaterial.new()
	m.direction = Vector3(0, 1, 0)
	m.spread = 12.0 if smoke else 18.0
	m.initial_velocity_min = 0.8 if smoke else 1.0
	m.initial_velocity_max = 1.4 if smoke else 2.2
	m.gravity = Vector3(0.25, 0.3, 0.1) if smoke else Vector3(0, 0.5, 0)
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = 0.7 * strength
	m.scale_min = 0.8 if smoke else 0.5
	m.scale_max = 1.8 if smoke else 1.1
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.3 if smoke else 1.0))
	curve.add_point(Vector2(1, 1.6 if smoke else 0.1))
	var ct := CurveTexture.new()
	ct.curve = curve
	m.scale_curve = ct
	var g := Gradient.new()
	if smoke:
		g.set_color(0, Color(0.16, 0.14, 0.12, 0.55))
		g.set_color(1, Color(0.3, 0.28, 0.26, 0.0))
	else:
		g.set_color(0, Color(1.0, 0.7, 0.3, 0.85))
		g.set_color(1, Color(0.8, 0.2, 0.05, 0.0))
	var gt := GradientTexture1D.new()
	gt.gradient = g
	m.color_ramp = gt
	p.process_material = m
	var q := QuadMesh.new()
	q.size = Vector2(1.2, 1.2) if smoke else Vector2(0.6, 0.8)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = _soft_dot()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	if not smoke:
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	q.material = mat
	p.draw_pass_1 = q
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if smoke:
		p.position = Vector3(0, 1.0, 0)
	return p


static var _dot: GradientTexture2D


static func _soft_dot() -> GradientTexture2D:
	if _dot == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		_dot = GradientTexture2D.new()
		_dot.gradient = g
		_dot.fill = GradientTexture2D.FILL_RADIAL
		_dot.fill_from = Vector2(0.5, 0.5)
		_dot.fill_to = Vector2(0.5, 0.0)
		_dot.width = 64
		_dot.height = 64
	return _dot


func _process(delta: float) -> void:
	if _light == null or not is_visible_in_tree():
		return
	_t += delta
	_light.light_energy = 2.2 + sin(_t * 11.0) * 0.3 + sin(_t * 23.0 + 1.3) * 0.25
