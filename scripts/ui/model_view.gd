class_name ModelView
extends SubViewportContainer
## Окошко с 3D-моделью героя: портрет (голова и плечи) или в полный рост, крутится на месте.
## Своя маленькая сцена (свет, камера) — не зависит от локации.

var vp: SubViewport
var body: AnimBody
var turn := false
var _holder: Node3D
var _cam: Camera3D
var _skin := ""


func setup(size_px: Vector2i, portrait: bool, spin: bool) -> void:
	stretch = true
	custom_minimum_size = Vector2(size_px)
	mouse_filter = Control.MOUSE_FILTER_PASS
	turn = spin
	vp = SubViewport.new()
	vp.size = size_px
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_4X
	add_child(vp)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("b8b09a")
	e.ambient_light_energy = 0.55
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	vp.add_child(env)
	var key := DirectionalLight3D.new()
	key.light_color = Color("fff0d8")
	key.light_energy = 1.2
	key.rotation = Vector3(deg_to_rad(-30), deg_to_rad(35), 0)
	vp.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.light_color = Color("9fb6d8")
	rim.light_energy = 0.6
	rim.rotation = Vector3(deg_to_rad(-15), deg_to_rad(200), 0)
	vp.add_child(rim)
	_holder = Node3D.new()
	vp.add_child(_holder)
	_cam = Camera3D.new()
	_cam.fov = 26.0 if portrait else 30.0
	vp.add_child(_cam)
	if portrait:
		_cam.position = Vector3(0.0, 1.62, 1.15)
		_cam.look_at_from_position(_cam.position, Vector3(0, 1.56, 0))
	else:
		_cam.position = Vector3(0.0, 1.05, 4.2)
		_cam.look_at_from_position(_cam.position, Vector3(0, 0.92, 0))
	_cam.current = true


## Показать героя с этой текстурой одежды
func show_skin(skin: String) -> void:
	if skin == _skin and body != null:
		return
	_skin = skin
	if body:
		body.queue_free()
	body = AnimBody.new()
	_holder.add_child(body)
	var look: Dictionary = DB.characters.get("hero", {}).get("look", {}).duplicate()
	look["skin_tex"] = skin
	body.build(look)
	body.play("Idle", 0.0)


func _process(delta: float) -> void:
	if turn and is_visible_in_tree() and _holder:
		_holder.rotation.y += delta * 0.6
