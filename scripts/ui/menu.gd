class_name GameMenu
extends Control
## Меню на весь экран в стиле ЭЛТ: главное, пауза, смерть, конец пролога.

signal chosen(id: String)

var _box: VBoxContainer
var _title: Label
var _sub: Label
var _list: VBoxContainer
var _foot: Label
var mode := "main"
var _prev := "main"


func setup() -> void:
	UITheme.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Color("060301")
	UITheme.full_rect(bg)
	add_child(bg)
	var lines := ColorRect.new()
	UITheme.full_rect(lines)
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = "shader_type canvas_item;\nvoid fragment(){ float l = step(0.5, fract(FRAGCOORD.y / 3.0)); vec2 v = UV - 0.5; COLOR = vec4(0.0, 0.0, 0.0, 0.18 * l + dot(v, v) * 0.9); }"
	var mat := ShaderMaterial.new()
	mat.shader = sh
	lines.material = mat
	var c := CenterContainer.new()
	UITheme.full_rect(c)
	add_child(c)
	add_child(lines)
	var p := UITheme.panel(UITheme.screen(false, 30))
	p.custom_minimum_size = Vector2(640, 0)
	c.add_child(p)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 14)
	p.add_child(_box)
	_title = UITheme.label("НАХАРРО", 52, UITheme.AMBER_HOT, true)
	_box.add_child(_title)
	var st := UITheme.stripe(8)
	st.custom_minimum_size = Vector2(320, 8)
	st.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_box.add_child(st)
	_sub = UITheme.label("", 14, UITheme.AMBER_DIM)
	_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_box.add_child(_sub)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 2)
	_box.add_child(_list)
	_foot = UITheme.label("", 12, UITheme.AMBER_DIM)
	_foot.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_box.add_child(_foot)
	visible = false


func open(m: String) -> void:
	mode = m
	visible = true
	for x in _list.get_children():
		x.queue_free()
	var items := []
	_title.add_theme_color_override("font_color", UITheme.AMBER_HOT)
	match m:
		"main":
			_title.text = "НАХАРРО"
			_sub.text = "Якутия, 2062 год. Пятьдесят лет после конца света."
			var info := Game.save_info("auto")
			if not info.is_empty():
				items.append(["continue", "Продолжить", "%s · ур. %d · %s" % [info.name, info.level, info.time]])
			items.append(["new", "Новая игра", ""])
			if Game.has_save("quick"):
				items.append(["load_quick", "Загрузить быстрое сохранение", "F9"])
			items.append(["settings", "Настройки", ""])
			items.append(["quit", "Выход", ""])
			_foot.text = "Мышь — ходить и действовать · I — КПК · C — дело · Пробел — конец хода · F5/F9 — быстрое сохранение/загрузка"
		"pause":
			_title.text = "ПАУЗА"
			_sub.text = ""
			items = [["resume", "Вернуться", "Esc"], ["save_quick", "Быстрое сохранение", "F5"], ["load_quick", "Загрузить", "F9"], ["settings", "Настройки", ""], ["to_main", "В главное меню", ""]]
			_foot.text = ""
		"dead":
			_title.text = "ЛЕНТА ОБОРВАЛАСЬ"
			_title.add_theme_color_override("font_color", Color("ff7a4a"))
			_sub.text = "Ты погиб."
			if Game.has_save("auto"):
				items.append(["continue", "Загрузить автосохранение", ""])
			items.append(["to_main", "В главное меню", ""])
			_foot.text = ""
		"end_prologue":
			_title.text = "КОНЕЦ ПРОЛОГА"
			_sub.text = "Ты переступил черту, за которую никто из Нахарро не ходил пятьдесят лет.\n\nДальше — первый акт: соседнее поселение, след Боотура и те, кто пришёл в деревню с довоенной техникой."
			items = [["to_main", "В главное меню", ""], ["quit", "Выход", ""]]
			_foot.text = "Спасибо, что прошёл пролог. Это первая сборка на Godot."
		"end_act1":
			_title.text = "ДОРОГА НА МАР-КУН"
			_sub.text = "Боотур проиграл в Сунгаре всё — и расплатился сведениями о Нахарро. Их купил казначей Нью-Рбы, а самого Боотура угнали в Промзону МИР.\n\nСледующая точка «списка Б» — Мар-Кун. Он — в следующей сборке."
			items = [["to_main", "В главное меню", ""], ["quit", "Выход", ""]]
			_foot.text = "Спасибо, что играешь. Сохранение сделано — продолжить можно из меню."
		"settings":
			_title.text = "НАСТРОЙКИ"
			_sub.text = ""
			var sp: String = Game.settings.get("text_speed", "normal")
			var names := {"slow": "медленно", "normal": "обычно", "fast": "быстро", "instant": "сразу"}
			items.append(["speed", "Скорость текста: " + names.get(sp, sp), "клик — сменить"])
			items.append(["rolls", "Показывать броски в журнале: " + ("да" if Game.settings.get("show_rolls", false) else "нет"), "клик — сменить"])
			items.append(["graphics", "Графика", ""])
			items.append(["back", "Назад", ""])
			_foot.text = ""
		"graphics":
			_title.text = "ГРАФИКА"
			_sub.text = "Если игра тормозит — поставь качество «быстро» или уменьши масштаб картинки."
			for g in Graphics.OPTIONS:
				items.append(["gfx:" + g.id, "%s: %s" % [g.name, Graphics.value_name(g.id)], "клик — сменить"])
			items.append(["gfx_back", "Назад", ""])
			_foot.text = ""
	for it in items:
		_list.add_child(_item(it[0], it[1], it[2]))


func _item(id: String, text: String, hint: String) -> Button:
	var b := Button.new()
	b.text = "  " + text + ("    · " + hint if hint != "" else "")
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_override("font", UITheme.mono())
	b.add_theme_font_size_override("font_size", 19)
	var e := StyleBoxEmpty.new()
	e.set_content_margin_all(8)
	var hv := StyleBoxFlat.new()
	hv.bg_color = Color(UITheme.AMBER, 0.13)
	hv.set_corner_radius_all(3)
	hv.set_content_margin_all(8)
	b.add_theme_stylebox_override("normal", e)
	b.add_theme_stylebox_override("hover", hv)
	b.add_theme_stylebox_override("focus", hv)
	b.add_theme_stylebox_override("pressed", hv)
	b.add_theme_color_override("font_color", UITheme.AMBER)
	b.add_theme_color_override("font_hover_color", UITheme.AMBER_HOT)
	b.add_theme_color_override("font_focus_color", UITheme.AMBER_HOT)
	b.pressed.connect(_on.bind(id))
	return b


func _on(id: String) -> void:
	match id:
		"settings":
			_prev = mode
			open("settings")
			return
		"back":
			open(_prev)
			return
		"speed":
			var order := ["slow", "normal", "fast", "instant"]
			var i := order.find(Game.settings.get("text_speed", "normal"))
			Game.settings.text_speed = order[(i + 1) % order.size()]
			Game.save_settings()
			open("settings")
			return
		"rolls":
			Game.settings.show_rolls = not Game.settings.get("show_rolls", false)
			Game.save_settings()
			open("settings")
			return
		"graphics":
			open("graphics")
			return
		"gfx_back":
			open("settings")
			return
	if id.begins_with("gfx:"):
		Graphics.cycle(id.substr(4))
		Graphics.apply(get_tree())
		open("graphics")
		return
	chosen.emit(id)


func _unhandled_key_input(e: InputEvent) -> void:
	if visible and mode == "pause" and e is InputEventKey and e.pressed and not e.echo and e.keycode == KEY_ESCAPE:
		chosen.emit("resume")
		get_viewport().set_input_as_handled()


## Слайды вступления: печатает строки по одной, клик — дальше
class Slides extends Control:
	signal finished
	var _lines: Array = []
	var _i := -1
	var _lbl: Label
	var _hint: Label
	var _chars := 0.0

	func setup() -> void:
		UITheme.full_rect(self)
		mouse_filter = Control.MOUSE_FILTER_STOP
		var bg := ColorRect.new()
		bg.color = UITheme.CRT
		UITheme.full_rect(bg)
		add_child(bg)
		var c := CenterContainer.new()
		UITheme.full_rect(c)
		add_child(c)
		_lbl = UITheme.label("", 22, UITheme.AMBER)
		_lbl.custom_minimum_size = Vector2(760, 0)
		_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		c.add_child(_lbl)
		_hint = UITheme.label("клик или пробел — дальше", 12, UITheme.AMBER_DIM)
		_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
		_hint.offset_top = -50
		_hint.offset_left = -120
		add_child(_hint)
		visible = false

	func play(lines: Array) -> void:
		_lines = lines
		_i = -1
		visible = true
		_next()

	func _next() -> void:
		if _i >= _lines.size():
			return
		if _i >= 0 and _chars < _lines[_i].length():
			_chars = 9999.0
			_lbl.visible_characters = -1
			return
		_i += 1
		if _i >= _lines.size():
			visible = false
			finished.emit()
			return
		_lbl.text = _lines[_i]
		_chars = 0.0
		_lbl.visible_characters = 0

	func _process(delta: float) -> void:
		if visible and _i >= 0 and _i < _lines.size() and _chars < _lines[_i].length():
			_chars += delta * 38.0
			_lbl.visible_characters = int(_chars)

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_next()

	func _unhandled_key_input(e: InputEvent) -> void:
		if visible and e is InputEventKey and e.pressed and not e.echo and (e.keycode == KEY_SPACE or e.keycode == KEY_ENTER or e.keycode == KEY_ESCAPE):
			_next()
			get_viewport().set_input_as_handled()
