class_name UITheme
extends RefCounted
## Кассетный футуризм: бежевый пластик, янтарные и зелёные ЭЛТ-экраны.
## Все цвета и шрифты интерфейса — здесь.

const PLASTIC := Color("cdc4ad")
const PLASTIC_HI := Color("e4dcc6")
const PLASTIC_LO := Color("a79d85")
const PLASTIC_EDGE := Color("6f6754")
const INK := Color("3b352b")
const INK_2 := Color("2f2a22")
const PAPER := Color("ece3cb")
const CRT := Color("120b04")
const AMBER := Color("ffb347")
const AMBER_DIM := Color("a8702a")
const AMBER_HOT := Color("ffd9a0")
const GREEN_BG := Color("07100a")
const GREEN := Color("8fe08a")
const GREEN_HI := Color("c9f2b8")
const GREEN_DIM := Color("5f9a58")
const S1 := Color("d9622b")
const S2 := Color("e39b2f")
const S3 := Color("3f6f73")
const RED := Color("b8442a")
const HIT := Color("ff8a5a")
const MISS := Color("d8e89a")

static var _mono: FontFile
static var _head: FontFile


static func mono() -> Font:
	if _mono == null:
		_mono = _font("pt-mono", ["latin", "latin-ext", "cyrillic", "cyrillic-ext"])
	return _mono


static func head() -> Font:
	if _head == null:
		_head = _font("russo-one", ["latin", "cyrillic"])
		if _head == null:
			return mono()
	return _head


static func _font(fam: String, subsets: Array) -> FontFile:
	var files := []
	for s in subsets:
		var p := "res://assets/fonts/%s-%s-400-normal.woff2" % [fam, s]
		if ResourceLoader.exists(p):
			files.append(load(p))
	if files.is_empty():
		return null
	var main: FontFile = (files[0] as FontFile).duplicate()
	var fb: Array[Font] = []
	for i in range(1, files.size()):
		fb.append(files[i])
	# если какого-то значка нет в шрифте — берём из системного
	var sys := SystemFont.new()
	sys.font_names = PackedStringArray(["Segoe UI Symbol", "DejaVu Sans", "Noto Sans Symbols", "Arial Unicode MS", "Arial"])
	fb.append(sys)
	main.fallbacks = fb
	return main


static func build_theme() -> Theme:
	var t := Theme.new()
	t.default_font = mono()
	t.default_font_size = 15
	t.set_color("font_color", "Label", AMBER)
	t.set_color("font_color", "RichTextLabel", AMBER)
	t.set_color("default_color", "RichTextLabel", AMBER)
	# полосы прокрутки
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.25)
	sb.set_corner_radius_all(3)
	var gr := StyleBoxFlat.new()
	gr.bg_color = Color(AMBER_DIM, 0.7)
	gr.set_corner_radius_all(3)
	for cls in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", cls, sb)
		t.set_stylebox("grabber", cls, gr)
		t.set_stylebox("grabber_highlight", cls, gr)
		t.set_stylebox("grabber_pressed", cls, gr)
	# поле ввода
	var le := StyleBoxFlat.new()
	le.bg_color = Color(0, 0, 0, 0)
	le.border_color = Color("9d9072")
	le.border_width_bottom = 1
	t.set_stylebox("normal", "LineEdit", le)
	t.set_stylebox("focus", "LineEdit", le)
	t.set_color("font_color", "LineEdit", INK_2)
	t.set_color("caret_color", "LineEdit", INK_2)
	# всплывающие подсказки
	var tp := StyleBoxFlat.new()
	tp.bg_color = Color(0.07, 0.04, 0.02, 0.94)
	tp.border_color = Color("5a3b14")
	tp.set_border_width_all(1)
	tp.set_content_margin_all(6)
	t.set_stylebox("panel", "TooltipPanel", tp)
	t.set_color("font_color", "TooltipLabel", AMBER_HOT)
	return t


# ---------- панели ----------
static func plastic(radius := 8) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = PLASTIC
	s.set_corner_radius_all(radius)
	s.border_color = PLASTIC_EDGE
	s.border_width_bottom = 3
	s.shadow_color = Color(0.08, 0.05, 0.02, 0.4)
	s.shadow_size = 10
	s.shadow_offset = Vector2(0, 4)
	s.set_content_margin_all(12)
	return s


static func screen(green := false, margin := 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = GREEN_BG if green else CRT
	s.set_corner_radius_all(9)
	s.border_color = Color("2a2419")
	s.set_border_width_all(3)
	s.set_content_margin_all(margin)
	return s


static func paper() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = PAPER
	s.set_corner_radius_all(3)
	s.set_content_margin_all(8)
	return s


static func panel(style: StyleBox) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", style)
	return p


static func label(text: String, size := 15, color := AMBER, heading := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", head() if heading else mono())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


## Кнопка-клавиша. kind: normal | primary | warn | sel | ghost
static func key(text: String, kind := "normal", size := 13) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", head())
	b.add_theme_font_size_override("font_size", size)
	style_key(b, kind)
	return b


static func style_key(b: Button, kind := "normal") -> void:
	var base := Color("d8d0ba")
	var fg := INK_2
	match kind:
		"primary":
			base = Color("d9703f")
			fg = Color("fff3e2")
		"warn":
			base = Color("726b5d")
			fg = Color("efe6cf")
		"sel":
			base = Color("f0b862")
		"ghost":
			base = Color(0, 0, 0, 0)
			fg = AMBER
	var mk := func(c: Color, press: bool) -> StyleBoxFlat:
		var s := StyleBoxFlat.new()
		s.bg_color = c
		s.set_corner_radius_all(4)
		if kind != "ghost":
			s.border_color = PLASTIC_EDGE
			s.border_width_bottom = 1 if press else 3
		s.content_margin_left = 10
		s.content_margin_right = 10
		s.content_margin_top = 7 + (2 if press else 0)
		s.content_margin_bottom = 5
		return s
	b.add_theme_stylebox_override("normal", mk.call(base, false))
	b.add_theme_stylebox_override("hover", mk.call(base.lightened(0.08) if kind != "ghost" else Color(AMBER, 0.12), false))
	b.add_theme_stylebox_override("pressed", mk.call(base.darkened(0.08), true))
	b.add_theme_stylebox_override("disabled", mk.call(Color(base, 0.45), false))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for st in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(st, fg if kind != "ghost" or st == "font_color" else AMBER_HOT)
	b.add_theme_color_override("font_disabled_color", Color(fg, 0.5))


## Трёхцветная полоска, как на кассетных этикетках
static func stripe(h := 6) -> Control:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 0)
	hb.custom_minimum_size = Vector2(0, h)
	for c in [S1, S2, S3]:
		var r := ColorRect.new()
		r.color = c
		r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.custom_minimum_size = Vector2(0, h)
		hb.add_child(r)
	return hb


static func full_rect(c: Control) -> void:
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
