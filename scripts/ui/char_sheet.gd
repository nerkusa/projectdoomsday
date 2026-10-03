class_name CharSheet
extends Control
## «Дело» — лист персонажа. Новая игра начинается с выбора одного из четырёх готовых
## героев (data/presets.json): портреты сняты с самой модели. После выбора — слева
## характеристики и навыки (до начала игры их можно перераскидать), справа модель крутится.
## Потом очки — только за уровни.

signal closed

var _name: LineEdit
var _pools: Label
var _stats_box: VBoxContainer
var _skills_box: VBoxContainer
var _derived: Label
var _done: Button
var _rand: Button
var _back: Button
var _main: Control
var _pick: Control
var _view: ModelView
var _title: Label


func setup() -> void:
	UITheme.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.02, 0.01, 0.55)
	UITheme.full_rect(dim)
	add_child(dim)
	var body := UITheme.panel(UITheme.plastic(10))
	body.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	body.offset_left = -640
	body.offset_right = 640
	body.offset_top = -390
	body.offset_bottom = 390
	add_child(body)
	_main = body
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	body.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	v.add_child(head)
	var paper := UITheme.panel(UITheme.paper())
	paper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(paper)
	var ph := HBoxContainer.new()
	ph.add_theme_constant_override("separation", 10)
	paper.add_child(ph)
	ph.add_child(UITheme.label("ДЕЛО", 22, UITheme.INK_2, true))
	var pv := VBoxContainer.new()
	pv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ph.add_child(pv)
	var nh := HBoxContainer.new()
	pv.add_child(nh)
	nh.add_child(UITheme.label("Имя: ", 13, UITheme.INK))
	_name = LineEdit.new()
	_name.custom_minimum_size = Vector2(240, 0)
	_name.max_length = 24
	_name.add_theme_font_override("font", UITheme.head())
	_name.add_theme_font_size_override("font_size", 16)
	_name.text_changed.connect(func(t): Game.hero.name = t if t.strip_edges() != "" else "Безымянный")
	nh.add_child(_name)
	_title = UITheme.label("", 12, UITheme.INK)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pv.add_child(_title)
	pv.add_child(UITheme.stripe(7))
	var pp := UITheme.panel(UITheme.screen(false, 10))
	pp.custom_minimum_size = Vector2(260, 0)
	head.add_child(pp)
	_pools = UITheme.label("", 13, UITheme.AMBER)
	pp.add_child(_pools)
	var cols := HBoxContainer.new()
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_theme_constant_override("separation", 12)
	v.add_child(cols)
	var lp := UITheme.panel(UITheme.screen(false, 12))
	lp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(lp)
	var lv := VBoxContainer.new()
	lp.add_child(lv)
	lv.add_child(UITheme.label("ХАРАКТЕРИСТИКИ", 11, UITheme.AMBER_DIM, true))
	_stats_box = VBoxContainer.new()
	lv.add_child(_stats_box)
	_derived = UITheme.label("", 13, UITheme.AMBER_HOT)
	_derived.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lv.add_child(_derived)
	var rp := UITheme.panel(UITheme.screen(false, 12))
	rp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rp.size_flags_stretch_ratio = 1.4
	cols.add_child(rp)
	var rv := VBoxContainer.new()
	rp.add_child(rv)
	rv.add_child(UITheme.label("НАВЫКИ", 11, UITheme.AMBER_DIM, true))
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rv.add_child(sc)
	_skills_box = VBoxContainer.new()
	_skills_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(_skills_box)
	# справа — сам герой, крутится на месте
	var mp := UITheme.panel(UITheme.screen(false, 6))
	mp.custom_minimum_size = Vector2(300, 0)
	cols.add_child(mp)
	_view = ModelView.new()
	_view.setup(Vector2i(290, 560), false, true)
	mp.add_child(_view)
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 10)
	v.add_child(foot)
	_back = UITheme.key("← Другой герой", "normal")
	_back.pressed.connect(_show_pick)
	foot.add_child(_back)
	_rand = UITheme.key("Случайно", "warn")
	_rand.pressed.connect(_randomize)
	foot.add_child(_rand)
	var note := UITheme.label("До начала игры очки можно раскидать как угодно. Потом — только за уровни.", 12, UITheme.INK)
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	foot.add_child(note)
	_done = UITheme.key("Готово", "primary")
	_done.pressed.connect(close)
	foot.add_child(_done)
	_build_pick()
	visible = false


## Экран выбора: четыре готовых героя с портретами
func _build_pick() -> void:
	var panel := UITheme.panel(UITheme.plastic(12))
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -700
	panel.offset_right = 700
	panel.offset_top = -330
	panel.offset_bottom = 330
	add_child(panel)
	_pick = panel
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	var paper := UITheme.panel(UITheme.paper())
	v.add_child(paper)
	var hv := VBoxContainer.new()
	paper.add_child(hv)
	hv.add_child(UITheme.label("КТО ТЫ?", 22, UITheme.INK_2, true))
	hv.add_child(UITheme.label("Четверо внуков деда Уйбаана. Выбери, кем начнёшь, — потом очки можно перераскидать.", 13, UITheme.INK))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(row)
	for p in presets():
		var card := UITheme.panel(UITheme.screen(false, 8))
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(card)
		var cv := VBoxContainer.new()
		cv.add_theme_constant_override("separation", 6)
		card.add_child(cv)
		var mv := ModelView.new()
		mv.setup(Vector2i(300, 300), true, false)
		mv.name = "Portrait_" + str(p.id)
		cv.add_child(mv)
		mv.show_skin(str(p.skin))
		cv.add_child(UITheme.label(str(p.name).to_upper(), 20, UITheme.AMBER_HOT, true))
		cv.add_child(UITheme.label(str(p.title), 13, UITheme.AMBER_DIM, true))
		var d := UITheme.label(str(p.desc), 12, UITheme.AMBER)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.size_flags_vertical = Control.SIZE_EXPAND_FILL
		cv.add_child(d)
		var b := UITheme.key("Выбрать", "primary")
		b.pressed.connect(pick.bind(str(p.id)))
		cv.add_child(b)


static func presets() -> Array:
	return DB._load("res://data/presets.json").get("list", [])


## Взять готового героя: имя, характеристики, навыки, одежда
func pick(id: String) -> void:
	for p in presets():
		if str(p.id) != id:
			continue
		var h := Game.hero
		h.name = str(p.name)
		h.preset = id
		h.skin = str(p.skin)
		h.stats = (p.stats as Dictionary).duplicate()
		var sk := {}
		for k in Rules.all_skills():
			sk[k.name] = int(p.skills.get(k.name, 0))
		h.skills = sk
		_show_main()
		return


func _show_pick() -> void:
	if Game.hero.locked:
		return
	_pick.visible = true
	_main.visible = false


func _show_main() -> void:
	_pick.visible = false
	_main.visible = true
	_name.text = Game.hero.name
	_name.editable = not Game.hero.locked
	_view.show_skin(str(Game.hero.get("skin", "res://assets/models/hero_model.png")))
	render()


func open() -> void:
	visible = true
	# новая игра — сначала выбор героя; потом лист открывается сразу
	if not Game.hero.locked and not Game.hero.has("preset"):
		_show_pick()
	else:
		_show_main()


func close() -> void:
	var h := Game.hero
	if not h.locked:
		h.locked = true
		h.cur_hp = -1
	h.locked_stats = h.stats.duplicate()
	h.locked_skills = h.skills.duplicate()
	visible = false
	Game.hero_changed.emit()
	closed.emit()


func _randomize() -> void:
	if Game.hero.locked:
		return
	var c := Rules.random_core(Game.stat_pool(), Game.skill_pool(), Game.stat_cap())
	Game.hero.stats = c.stats
	Game.hero.skills = c.skills
	render()


func can_s(k: String, d: int) -> bool:
	var h := Game.hero
	var v := int(h.stats[k])
	if h.locked:
		if d < 0:
			return v > int(h.locked_stats.get(k, 1))
		return int(h.stat_pts) >= 1 and v < 10
	if d < 0:
		return v > 1
	return v < Game.stat_cap() and Rules.sum_stats(h.stats) < Game.stat_pool()


func can_k(n: String, d: int) -> bool:
	var h := Game.hero
	var v := int(h.skills.get(n, 0))
	if h.locked:
		if d < 0:
			return v > int(h.locked_skills.get(n, 0))
		return int(h.skill_pts) >= 1 and v < 10
	if d < 0:
		return v > 0
	return v < 10 and Rules.sum_skill_points(h.skills) < Game.skill_pool()


func ch_stat(k: String, d: int) -> void:
	if not can_s(k, d):
		return
	Game.hero.stats[k] = int(Game.hero.stats[k]) + d
	if Game.hero.locked:
		Game.hero.stat_pts = int(Game.hero.stat_pts) - d
	render()


func ch_skill(n: String, d: int) -> void:
	if not can_k(n, d):
		return
	Game.hero.skills[n] = int(Game.hero.skills.get(n, 0)) + d
	if Game.hero.locked:
		Game.hero.skill_pts = int(Game.hero.skill_pts) - d
	render()


func _pm(txt: String, enabled: bool, cb: Callable) -> Button:
	var b := Button.new()
	b.text = txt
	b.disabled = not enabled
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(26, 22)
	var s := StyleBoxFlat.new()
	s.bg_color = Color(UITheme.AMBER, 0.1)
	s.set_corner_radius_all(3)
	var s2 := s.duplicate()
	s2.bg_color = Color(UITheme.AMBER, 0.24)
	b.add_theme_stylebox_override("normal", s)
	b.add_theme_stylebox_override("hover", s2)
	b.add_theme_stylebox_override("pressed", s2)
	b.add_theme_stylebox_override("disabled", StyleBoxEmpty.new())
	b.add_theme_color_override("font_color", UITheme.AMBER)
	b.add_theme_color_override("font_disabled_color", Color(UITheme.AMBER, 0.2))
	b.pressed.connect(cb)
	return b


func render() -> void:
	var h := Game.hero
	var L: bool = h.locked
	if L:
		_pools.text = "Уровень %d/%d · опыт %d/%d\nОчки навыков: %d\nХарактеристики растут только через кассеты" % [h.level, Rules.MAX_LEVEL, h.xp, Rules.xp_for_level(int(h.level) + 1), h.skill_pts]
	else:
		_pools.text = "Характеристики: %d/%d\nНавыки: %d/%d\nПотолок характеристики: %d" % [Rules.sum_stats(h.stats), Game.stat_pool(), Rules.sum_skill_points(h.skills), Game.skill_pool(), Game.stat_cap()]
	_rand.visible = not L
	_back.visible = not L
	var pr := ""
	for p in presets():
		if str(p.id) == str(h.get("preset", "")):
			pr = "%s. %s" % [p.title, p.desc]
	_title.text = pr
	_done.text = "Закрыть" if L else "Готово — начать"
	for c in _stats_box.get_children():
		c.queue_free()
	for s in Rules.STATS:
		var row := HBoxContainer.new()
		var nm := UITheme.label(s.full, 14)
		nm.tooltip_text = s.hint
		nm.mouse_filter = Control.MOUSE_FILTER_PASS
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(nm)
		row.add_child(_pm("−", can_s(s.key, -1), ch_stat.bind(s.key, -1)))
		var bonus := int(Game.stat_bonus().get(s.key, 0))
		var val := UITheme.label(str(h.stats[s.key]) + ("+%d" % bonus if bonus else ""), 14, UITheme.AMBER_HOT)
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(_fixed(val, 30))
		row.add_child(_pm("+", can_s(s.key, 1), ch_stat.bind(s.key, 1)))
		_stats_box.add_child(row)
	var mx := Game.hero_max()
	_derived.text = "Здоровье: %d\nОчки действия в бою: %d\nМолва: %+d — %s" % [mx, Rules.ap_for(Game.effective_stats(), mx, mx), Game.rep(), Rules.rep_label(Game.rep())]
	for c in _skills_box.get_children():
		c.queue_free()
	for s in Rules.STATS:
		var hdr := UITheme.label(s.full.to_upper(), 11, UITheme.AMBER_DIM, true)
		_skills_box.add_child(hdr)
		for sk in Rules.SKILLS[s.key]:
			var n: String = sk
			var row := HBoxContainer.new()
			var nm := UITheme.label("  " + n, 13)
			nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(nm)
			row.add_child(_pm("−", can_k(n, -1), ch_skill.bind(n, -1)))
			var val := UITheme.label(str(h.skills.get(n, 0)), 13, UITheme.AMBER_HOT)
			val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			row.add_child(_fixed(val, 30))
			row.add_child(_pm("+", can_k(n, 1), ch_skill.bind(n, 1)))
			_skills_box.add_child(row)


func _fixed(c: Control, w: float) -> Control:
	c.custom_minimum_size = Vector2(w, 0)
	return c


func _unhandled_key_input(e: InputEvent) -> void:
	if visible and e is InputEventKey and e.pressed and not e.echo and e.keycode == KEY_ESCAPE and Game.hero.locked:
		close()
		get_viewport().set_input_as_handled()
