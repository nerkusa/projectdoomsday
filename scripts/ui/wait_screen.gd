class_name WaitScreen
extends Control
## Пропуск времени. Сначала — выбор, сколько ждать (час, три, шесть, до вечера,
## до утра). Потом экран темнеет, на середине — циферблат с бегущими стрелками
## и табло в стиле КПК; мир под затемнением меняет свет, жители расходятся.
## В конце экран снова светлеет.

signal picked(hours: float, label: String)

var main: Node
var running := false
var _ask: PanelContainer
var _dim: ColorRect
var _dial: Control
var _clock_lbl: Label
var _what_lbl: Label
var _shown_h := 0.0
var _keys := []


func setup(m: Node) -> void:
	main = m
	UITheme.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_dim = ColorRect.new()
	_dim.color = Color(0.0, 0.0, 0.02, 0.0)
	UITheme.full_rect(_dim)
	_dim.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed and _ask.visible:
			_close_ask())
	add_child(_dim)
	# --- выбор ---
	_ask = UITheme.panel(UITheme.plastic(10))
	_ask.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_ask.offset_left = -190
	_ask.offset_right = 190
	_ask.offset_top = -170
	_ask.offset_bottom = 150
	add_child(_ask)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	_ask.add_child(v)
	v.add_child(UITheme.label("ПОДОЖДАТЬ", 16, UITheme.INK_2, true))
	v.add_child(UITheme.stripe(5))
	_what_lbl = UITheme.label("", 12, UITheme.INK)
	v.add_child(_what_lbl)
	for i in 5:
		var b := UITheme.key("", "normal", 12)
		b.pressed.connect(_choose.bind(i))
		v.add_child(b)
		_keys.append(b)
	var x := UITheme.key("Отмена  [Esc]", "warn", 12)
	x.pressed.connect(_close_ask)
	v.add_child(x)
	# --- анимация ---
	_dial = Control.new()
	_dial.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_dial.offset_left = -110
	_dial.offset_right = 110
	_dial.offset_top = -150
	_dial.offset_bottom = 70
	_dial.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dial.draw.connect(_draw_dial)
	add_child(_dial)
	_clock_lbl = UITheme.label("", 22, UITheme.AMBER, true)
	_clock_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_clock_lbl.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_clock_lbl.offset_left = -220
	_clock_lbl.offset_right = 220
	_clock_lbl.offset_top = 84
	_clock_lbl.offset_bottom = 140
	add_child(_clock_lbl)


## Варианты: [часов, подпись]
func options() -> Array:
	return [
		[1.0, "Час"],
		[3.0, "Три часа"],
		[6.0, "Шесть часов"],
		[Clock.until(20.0), "До вечера (20:00)"],
		[Clock.until(8.0), "До утра (8:00)"],
	]


func ask() -> void:
	if running:
		return
	var ops := options()
	for i in ops.size():
		(_keys[i] as Button).text = "%d. %s" % [i + 1, ops[i][1]]
	_what_lbl.text = "Сейчас: " + Clock.text().to_lower()
	visible = true
	_ask.visible = true
	_dial.visible = false
	_clock_lbl.visible = false
	_dim.color.a = 0.45


func _close_ask() -> void:
	_ask.visible = false
	if not running:
		visible = false


func _choose(i: int) -> void:
	var ops := options()
	_close_ask()
	picked.emit(float(ops[i][0]), str(ops[i][1]))


func _unhandled_key_input(e: InputEvent) -> void:
	if not visible or not _ask.visible or not (e is InputEventKey) or not e.pressed:
		return
	if e.keycode == KEY_ESCAPE:
		_close_ask()
		get_viewport().set_input_as_handled()
	elif e.keycode >= KEY_1 and e.keycode <= KEY_5:
		_choose(e.keycode - KEY_1)
		get_viewport().set_input_as_handled()


## Сама промотка: затемнение, часы бегут, свет меняется, затем светлеет
func play(dh: float, step: Callable) -> void:
	running = true
	visible = true
	_ask.visible = false
	_dial.visible = true
	_clock_lbl.visible = true
	_shown_h = Clock.hours()
	_dial.modulate.a = 0.0
	_clock_lbl.modulate.a = 0.0
	_update_lbl()
	var tw := create_tween().set_parallel()
	tw.tween_property(_dim, "color:a", 0.86, 0.35)
	tw.tween_property(_dial, "modulate:a", 1.0, 0.35)
	tw.tween_property(_clock_lbl, "modulate:a", 1.0, 0.35)
	await tw.finished
	var dur := clampf(0.9 + dh * 0.13, 1.0, 2.8)
	var t := 0.0
	var done := 0.0
	while t < dur:
		var dt := get_process_delta_time()
		t = minf(t + dt, dur)
		var k := ease(t / dur, -1.8)
		var want := dh * k
		if want > done:
			step.call(want - done)
			done = want
		_shown_h = Clock.hours()
		_update_lbl()
		_dial.queue_redraw()
		await get_tree().process_frame
	if done < dh:
		step.call(dh - done)
	_shown_h = Clock.hours()
	_update_lbl()
	_dial.queue_redraw()
	await get_tree().create_timer(0.25).timeout
	var tw2 := create_tween().set_parallel()
	tw2.tween_property(_dim, "color:a", 0.0, 0.45)
	tw2.tween_property(_dial, "modulate:a", 0.0, 0.3)
	tw2.tween_property(_clock_lbl, "modulate:a", 0.0, 0.3)
	await tw2.finished
	visible = false
	running = false


func _update_lbl() -> void:
	var h := fmod(_shown_h, 24.0)
	_clock_lbl.text = "%02d:%02d  ·  ДЕНЬ %d" % [int(h), int(fmod(_shown_h * 60.0, 60.0)), int(_shown_h / 24.0) + 1]


## Циферблат: корпус из пластика, янтарная шкала, луна или солнце
func _draw_dial() -> void:
	var c := Vector2(110, 110)
	var r := 96.0
	var h := fmod(_shown_h, 24.0)
	var day := h >= 6.0 and h < 20.0
	_dial.draw_circle(c, r + 10, UITheme.PLASTIC_LO)
	_dial.draw_circle(c, r + 6, UITheme.PLASTIC)
	_dial.draw_circle(c, r, UITheme.CRT)
	# небо в окошке: день — солнце, ночь — месяц
	var sky := Vector2(c.x, c.y + 40)
	if day:
		_dial.draw_circle(sky, 11, UITheme.AMBER_HOT)
		for i in 8:
			var a := i * TAU / 8.0 + _shown_h
			_dial.draw_line(sky + Vector2(cos(a), sin(a)) * 14, sky + Vector2(cos(a), sin(a)) * 19, UITheme.AMBER, 2.0)
	else:
		_dial.draw_circle(sky, 11, UITheme.AMBER_DIM)
		_dial.draw_circle(sky + Vector2(5, -3), 10, UITheme.CRT)
	for i in 12:
		var a := i * TAU / 12.0 - PI / 2.0
		var d := Vector2(cos(a), sin(a))
		_dial.draw_line(c + d * (r - 14 if i % 3 == 0 else r - 8), c + d * (r - 3), UITheme.AMBER if i % 3 == 0 else UITheme.AMBER_DIM, 3.0 if i % 3 == 0 else 1.5)
	var ha := fmod(h, 12.0) / 12.0 * TAU - PI / 2.0
	var ma := fmod(_shown_h, 1.0) * TAU - PI / 2.0
	_dial.draw_line(c, c + Vector2(cos(ha), sin(ha)) * (r * 0.5), UITheme.AMBER_HOT, 5.0, true)
	_dial.draw_line(c, c + Vector2(cos(ma), sin(ma)) * (r * 0.78), UITheme.AMBER, 3.0, true)
	_dial.draw_circle(c, 6, UITheme.S1)
