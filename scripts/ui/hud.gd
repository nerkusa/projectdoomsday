class_name HUD
extends Control
## Приборная панель внизу экрана (как в прототипе): журнал, герой, оружие, кнопки.

signal action(name: String)
signal zone_chosen(zone: String)

var main: Node
var _log: RichTextLabel
var _status: Label
var _name_lbl: Label
var _hp_bar: ProgressBar
var _hp_lbl: Label
var _ap_row: HBoxContainer
var _ap_lbl: Label
var _turn_lbl: Label
var _slot_main: Button
var _slot_other: Button
var _btns: Dictionary = {}
var _tip: Label
var _tip_timer := 0.0
var _zones: PanelContainer
var _zones_box: HFlowContainer
var _title_lbl: Label
var _obj_lbl: Label
var _toast: Label
var _hurt: ColorRect
var _floats: Control
var _combat: CombatManager
## Нижняя панель: появляется, когда собран КПК (браслет + компьютер).
## В бою видна всегда — без неё не видно ОД и кнопок хода.
var _bar: PanelContainer
## Этикетка с целью — тоже только с КПК; до него героя ведут его мысли
var _tape: PanelContainer
## До КПК интерфейс простой: только что в руке, и короткий журнал слева
var _hand: Button
var _mini_log: VBoxContainer
## Мысль над головой героя
var _thought: Label
var _thought_t := 0.0
## Alt — подписи над всем, что можно взять или обыскать
var _marks: Control
## Планка «меню / + / −» справа сверху
var _menu_bar: Control


func setup(m: Node, cm: CombatManager) -> void:
	main = m
	_combat = cm
	UITheme.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	Game.log_added.connect(_on_log)
	Game.hero_changed.connect(refresh)
	Game.quest_changed.connect(func(_id): refresh_objective())
	cm.changed.connect(refresh)
	refresh()


func _build() -> void:
	_floats = Control.new()
	_floats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UITheme.full_rect(_floats)
	add_child(_floats)
	_hurt = ColorRect.new()
	_hurt.color = Color(0.7, 0.1, 0.05, 0.0)
	_hurt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UITheme.full_rect(_hurt)
	add_child(_hurt)

	# ---- этикетка кассеты (локация + текущая цель) ----
	var tape := UITheme.panel(UITheme.plastic(6))
	_tape = tape
	tape.position = Vector2(12, 12)
	tape.custom_minimum_size = Vector2(360, 0)
	tape.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tape)
	var paper := UITheme.panel(UITheme.paper())
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tape.add_child(paper)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	paper.add_child(hb)
	var side := UITheme.label("A", 24, UITheme.INK_2, true)
	hb.add_child(side)
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 3)
	hb.add_child(vb)
	_title_lbl = UITheme.label("НАХАРРО", 16, UITheme.INK_2, true)
	vb.add_child(_title_lbl)
	vb.add_child(UITheme.stripe(7))
	_obj_lbl = UITheme.label("", 12, UITheme.INK)
	_obj_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_obj_lbl.custom_minimum_size = Vector2(290, 0)
	vb.add_child(_obj_lbl)

	# ---- справа сверху: меню и масштаб ----
	# компактная пластиковая планка: меню и масштаб
	var pst := UITheme.plastic(6)
	pst.set_content_margin_all(5)
	pst.shadow_size = 6
	var tp := UITheme.panel(pst)
	tp.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	tp.offset_left = -150
	tp.offset_right = -12
	tp.offset_top = 12
	tp.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	add_child(tp)
	_menu_bar = tp
	var tr := HBoxContainer.new()
	tr.add_theme_constant_override("separation", 4)
	tp.add_child(tr)
	for pair in [["menu", "МЕНЮ", "Меню (Esc)"], ["zin", "+", "Приблизить (колесо мыши)"], ["zout", "−", "Отдалить (колесо мыши)"]]:
		var b := UITheme.key(pair[1], "warn" if pair[0] == "menu" else "normal", 11 if pair[0] == "menu" else 14)
		for st in ["normal", "hover", "pressed", "disabled"]:
			var sb := b.get_theme_stylebox(st).duplicate() as StyleBoxFlat
			sb.content_margin_left = 7
			sb.content_margin_right = 7
			sb.content_margin_top = 3 + (1 if st == "pressed" else 0)
			sb.content_margin_bottom = 2
			b.add_theme_stylebox_override(st, sb)
		b.custom_minimum_size = Vector2(52 if pair[0] == "menu" else 28, 26)
		b.tooltip_text = pair[2]
		b.pressed.connect(action.emit.bind(pair[0]))
		tr.add_child(b)

	# ---- тост по центру сверху ----
	_toast = UITheme.label("", 18, UITheme.AMBER_HOT, true)
	_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_toast.position.y = 70
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_toast.add_theme_constant_override("shadow_offset_y", 2)
	_toast.modulate.a = 0.0
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_toast)

	# ---- до КПК: что в руке и короткий журнал ----
	_hand = _make_slot()
	_hand.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_hand.offset_left = -130
	_hand.offset_right = 130
	_hand.offset_top = -74
	_hand.offset_bottom = -14
	_hand.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hand.tooltip_text = "Клик или Tab — сменить руку"
	_hand.pressed.connect(action.emit.bind("swap"))
	add_child(_hand)
	_mini_log = VBoxContainer.new()
	_mini_log.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_mini_log.offset_left = 16
	_mini_log.offset_right = 470
	_mini_log.offset_top = -260
	_mini_log.offset_bottom = -16
	_mini_log.alignment = BoxContainer.ALIGNMENT_END
	_mini_log.add_theme_constant_override("separation", 3)
	_mini_log.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_mini_log)
	_thought = Label.new()
	_thought.add_theme_font_override("font", UITheme.mono())
	_thought.add_theme_font_size_override("font_size", 14)
	_thought.add_theme_color_override("font_color", Color("e8eef2"))
	_thought.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	_thought.add_theme_constant_override("shadow_offset_y", 2)
	_thought.add_theme_constant_override("shadow_offset_x", 1)
	var tsb := StyleBoxFlat.new()
	tsb.bg_color = Color(0.05, 0.06, 0.07, 0.55)
	tsb.set_corner_radius_all(6)
	tsb.set_content_margin_all(7)
	_thought.add_theme_stylebox_override("normal", tsb)
	_thought.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_thought.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_thought.custom_minimum_size = Vector2(340, 0)
	_thought.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_thought.visible = false
	add_child(_thought)
	_marks = Control.new()
	_marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UITheme.full_rect(_marks)
	_marks.draw.connect(_draw_marks)
	add_child(_marks)

	# ---- нижняя панель ----
	var bar := UITheme.panel(UITheme.plastic(8))
	_bar = bar
	bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_left = 8
	bar.offset_right = -8
	bar.offset_top = -158
	bar.offset_bottom = -8
	bar.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bar)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	bar.add_child(col)
	col.add_child(UITheme.stripe(4))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(row)

	# журнал
	var logp := UITheme.panel(UITheme.screen(true, 8))
	logp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	logp.size_flags_stretch_ratio = 1.5
	row.add_child(logp)
	var lv := VBoxContainer.new()
	logp.add_child(lv)
	_status = UITheme.label("", 12, UITheme.GREEN_HI)
	_status.clip_text = true
	lv.add_child(_status)
	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.scroll_following = true
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log.add_theme_font_override("normal_font", UITheme.mono())
	_log.add_theme_font_size_override("normal_font_size", 12)
	_log.add_theme_color_override("default_color", UITheme.GREEN)
	lv.add_child(_log)

	# герой
	var me := VBoxContainer.new()
	me.custom_minimum_size = Vector2(170, 0)
	me.add_theme_constant_override("separation", 4)
	row.add_child(me)
	var np := UITheme.panel(UITheme.screen(false, 6))
	me.add_child(np)
	_name_lbl = UITheme.label("", 13, UITheme.AMBER, true)
	_name_lbl.clip_text = true
	np.add_child(_name_lbl)
	var hr := HBoxContainer.new()
	me.add_child(hr)
	hr.add_child(UITheme.label("ХП", 11, UITheme.INK, true))
	_hp_bar = ProgressBar.new()
	_hp_bar.show_percentage = false
	_hp_bar.custom_minimum_size = Vector2(90, 10)
	_hp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hp_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.24, 0.2, 0.16, 0.3)
	var fg := StyleBoxFlat.new()
	fg.bg_color = UITheme.RED
	_hp_bar.add_theme_stylebox_override("background", bg)
	_hp_bar.add_theme_stylebox_override("fill", fg)
	hr.add_child(_hp_bar)
	_hp_lbl = UITheme.label("", 11, UITheme.INK)
	hr.add_child(_hp_lbl)
	_turn_lbl = UITheme.label("", 11, UITheme.INK_2, true)
	me.add_child(_turn_lbl)
	_ap_row = HBoxContainer.new()
	_ap_row.add_theme_constant_override("separation", 3)
	me.add_child(_ap_row)
	_ap_lbl = UITheme.label("", 11, UITheme.INK)
	me.add_child(_ap_lbl)

	# оружие
	var slots := HBoxContainer.new()
	slots.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slots.size_flags_stretch_ratio = 1.2
	slots.add_theme_constant_override("separation", 8)
	row.add_child(slots)
	_slot_main = _make_slot()
	_slot_main.size_flags_stretch_ratio = 1.9
	_slot_main.pressed.connect(action.emit.bind("mode"))
	_slot_main.tooltip_text = "Клик — режим огня (одиночный / очередь / прицельно)"
	slots.add_child(_slot_main)
	_slot_other = _make_slot()
	_slot_other.pressed.connect(action.emit.bind("swap"))
	_slot_other.tooltip_text = "Клик — сменить руку (Tab)"
	slots.add_child(_slot_other)

	# кнопки
	var grid := GridContainer.new()
	grid.columns = 2
	grid.custom_minimum_size = Vector2(200, 0)
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	row.add_child(grid)
	for pair in [["kpk", "КПК  [I]"], ["reload", "Перезар. [R]"], ["sneak", "Красться [Z]"], ["give", "Сдаться"], ["end", "В бой"]]:
		var b := UITheme.key(pair[1], "primary" if pair[0] == "end" else "normal", 11)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.size_flags_vertical = Control.SIZE_EXPAND_FILL
		b.pressed.connect(action.emit.bind(pair[0]))
		grid.add_child(b)
		_btns[pair[0]] = b

	# ---- выбор зоны для прицельного удара ----
	_zones = UITheme.panel(UITheme.plastic(8))
	_zones.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_zones.offset_top = -330
	_zones.offset_bottom = -180
	_zones.offset_left = -300
	_zones.offset_right = 300
	_zones.visible = false
	add_child(_zones)
	var zv := VBoxContainer.new()
	_zones.add_child(zv)
	zv.add_child(UITheme.label("КУДА БИТЬ", 12, UITheme.INK_2, true))
	_zones_box = HFlowContainer.new()
	_zones_box.add_theme_constant_override("h_separation", 6)
	_zones_box.add_theme_constant_override("v_separation", 6)
	zv.add_child(_zones_box)

	# ---- подсказка у курсора ----
	_tip = Label.new()
	_tip.add_theme_font_override("font", UITheme.mono())
	_tip.add_theme_font_size_override("font_size", 13)
	_tip.add_theme_color_override("font_color", UITheme.AMBER_HOT)
	var ts := StyleBoxFlat.new()
	ts.bg_color = Color(0.07, 0.04, 0.02, 0.92)
	ts.border_color = Color("5a3b14")
	ts.set_border_width_all(1)
	ts.set_content_margin_all(5)
	_tip.add_theme_stylebox_override("normal", ts)
	_tip.visible = false
	_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip.z_index = 10
	add_child(_tip)


func _make_slot() -> Button:
	var b := Button.new()
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.size_flags_vertical = Control.SIZE_EXPAND_FILL
	b.focus_mode = Control.FOCUS_NONE
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.add_theme_font_override("font", UITheme.mono())
	b.add_theme_font_size_override("font_size", 12)
	var s := UITheme.screen(false, 8)
	var sh := s.duplicate()
	sh.border_color = Color("5a4320")
	b.add_theme_stylebox_override("normal", s)
	b.add_theme_stylebox_override("hover", sh)
	b.add_theme_stylebox_override("pressed", sh)
	b.add_theme_stylebox_override("disabled", s)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color"]:
		b.add_theme_color_override(c, UITheme.AMBER)
	return b


# ---------------- обновление ----------------
func refresh() -> void:
	if _name_lbl == null:
		return
	var h := Game.hero
	_name_lbl.text = "%s · ур. %d" % [h.name, h.level]
	_hp_bar.max_value = Game.hero_max()
	_hp_bar.value = Game.hero_hp()
	_hp_lbl.text = "%d/%d" % [Game.hero_hp(), Game.hero_max()]
	var on := _combat.on
	_bar.visible = on or Game.flag("kpk")
	_tape.visible = Game.flag("kpk")
	_hand.visible = not _bar.visible
	_mini_log.visible = not _bar.visible
	var hw := DB.weapon(Game.hero_wkey())
	_hand.text = "В РУКЕ: %s\n[Tab] другая рука: %s" % [hw.get("name", "—"), DB.weapon(str(h.hands[1 - int(h.active)])).get("name", "—")]
	for c in _ap_row.get_children():
		c.queue_free()
	if on:
		var u := _combat.whose_turn()
		var ap := u.ap
		var mx := maxi(u.ap_max, ap)
		for i in 10:
			var p := ColorRect.new()
			p.custom_minimum_size = Vector2(11, 11)
			if i < ap:
				p.color = UITheme.GREEN if u.is_hero else Color("ff7a4a")
			elif i < mx:
				p.color = Color("4d4232")
			else:
				p.color = Color("3a2f22")
			_ap_row.add_child(p)
		_ap_lbl.text = "%d/%d ОД · раунд %d" % [ap, mx, _combat.round_n]
		_turn_lbl.text = ("ТВОЙ ХОД" if _combat.my_turn() else "…") if u.is_hero else "ХОД: " + u.name.to_upper()
	else:
		_ap_lbl.text = "Крадёшься" if h.get("sneak", false) else ""
		_turn_lbl.text = ""
	# оружие
	var act := int(h.active)
	_slot_main.text = _slot_text(str(h.hands[act]), act, true)
	_slot_other.text = _slot_text(str(h.hands[1 - act]), 1 - act, false)
	# кнопки
	var my := _combat.my_turn()
	_btns.end.text = "Конец хода [Пробел]" if on else ("Атака: вкл" if main.attack_mode else "В бой")
	UITheme.style_key(_btns.end, "sel" if (not on and main.attack_mode) else "primary")
	_btns.end.disabled = on and not my
	_btns.give.visible = on
	_btns.sneak.visible = not on
	_btns.give.disabled = not my
	_btns.reload.disabled = not DB.is_gun(Game.hero_wkey()) or (on and not my)
	UITheme.style_key(_btns.sneak, "sel" if h.get("sneak", false) else "normal")
	# «Дело» (лист персонажа) живёт в КПК; точка — есть нераспределённые очки
	var pts := int(h.stat_pts) + int(h.skill_pts)
	_btns.kpk.text = ("КПК  [I]" + (" •" if pts > 0 else "")) if Game.flag("kpk") else "Сумка  [I]"
	_status.text = main.status_text() if main.has_method("status_text") else ""


func _slot_text(k: String, hand: int, is_main: bool) -> String:
	var w := DB.weapon(k)
	var t := "%s РУКА%s\n%s\n" % ["ПРАВАЯ" if hand == 0 else "ЛЕВАЯ", "" if not is_main else "  · " + {"single": "ОДИН.", "burst": "ОЧЕРЕДЬ", "aim": "ПРИЦЕЛ"}[_combat.mode_name()], w.get("name", "—")]
	t += "%s ОД · %s%s %s" % [w.get("ap", 0), w.get("dmg", ""), ("+%d" % int(w.bonus)) if int(w.get("bonus", 0)) else "", w.get("dmg_type", "")]
	if DB.is_gun(k):
		t += "\n%d/%d (+%d)" % [int(Game.hero.mag.get(k, 0)), int(w.mag), int(Game.hero.ammo.get(w.ammo, 0))]
	return t


func refresh_objective() -> void:
	_title_lbl.text = main.location.title.to_upper() if main.location else ""
	_obj_lbl.text = main.objective_text() if main.has_method("objective_text") else ""


# ---------------- журнал ----------------
func _on_log(head: String, detail: String, cls: String) -> void:
	var col := "#a9ec9a"
	if cls == "hit":
		col = "#ffb070"
	elif cls == "miss":
		col = "#d8e89a"
	elif cls == "thought":
		col = "#c8d6e2"
	elif cls == "look":
		col = "#e6d3a3"
	_log.append_text("[color=%s]%s[/color]\n" % [col, _esc(head)])
	_mini_line(head, col)
	if detail != "" and Game.settings.get("show_rolls", false):
		_log.append_text("[color=#5f9a58]   %s[/color]\n" % _esc(detail))


func _esc(s: String) -> String:
	return s.replace("[", "[lb]")


func clear_log() -> void:
	_log.clear()
	for c in _mini_log.get_children():
		c.queue_free()


## Строка в коротком журнале слева: живёт несколько секунд и гаснет
func _mini_line(text: String, col: String) -> void:
	var l := UITheme.label(text, 13, Color(col), false)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(440, 0)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	l.add_theme_constant_override("shadow_offset_y", 1)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mini_log.add_child(l)
	while _mini_log.get_child_count() > 7:
		var old := _mini_log.get_child(0)
		_mini_log.remove_child(old)
		old.queue_free()
	var tw := l.create_tween()
	tw.tween_interval(7.0 + text.length() * 0.05)
	tw.tween_property(l, "modulate:a", 0.0, 1.5)
	tw.tween_callback(l.queue_free)


# ---------------- мысли героя ----------------
## Мысль всплывает над головой и остаётся в журнале
func think(text: String) -> void:
	Game.log_line(text, "", "thought")
	_thought.text = text
	_thought.visible = true
	_thought.modulate.a = 1.0
	_thought.size = Vector2.ZERO
	_thought_t = 3.0 + text.length() * 0.05


func thought_visible() -> bool:
	return _thought.visible


func _place_thought(delta: float) -> void:
	if not _thought.visible:
		return
	_thought_t -= delta
	if _thought_t <= 0.0:
		_thought.modulate.a = maxf(0.0, _thought.modulate.a - delta * 2.0)
		if _thought.modulate.a <= 0.0:
			_thought.visible = false
			return
	var pl: Node3D = main.player
	var cam: Camera3D = main.camera
	if pl == null or cam == null:
		return
	var p := cam.unproject_position(pl.global_position + Vector3(0, 2.3, 0))
	_thought.position = p - Vector2(_thought.size.x / 2.0, _thought.size.y)


# ---------------- Alt: подсветка вещей ----------------
func _draw_marks() -> void:
	if not Input.is_key_pressed(KEY_ALT) or main.location == null or main.ui_blocked():
		return
	var cam: Camera3D = main.camera
	var font := UITheme.mono()
	var pts := []
	for it in main.location.items():
		if it.visible and it.is_inside_tree():
			pts.append([it.global_position + Vector3(0, 0.6, 0), it.title(), UITheme.AMBER_HOT])
	for ch in main.location.characters():
		if ch.visible and ch.pose == "dead" and not main.location.ws().looted.has(ch.uid()):
			pts.append([ch.global_position + Vector3(0, 0.6, 0), ch.display_name + " · обыскать", Color("e8a080")])
	for p in pts:
		if cam.is_position_behind(p[0]):
			continue
		var sp := cam.unproject_position(p[0])
		if not Rect2(Vector2.ZERO, size).grow(-10).has_point(sp):
			continue
		var tw := font.get_string_size(p[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		_marks.draw_rect(Rect2(sp + Vector2(-tw / 2.0 - 6, -30), Vector2(tw + 12, 20)), Color(0.05, 0.03, 0.02, 0.8))
		_marks.draw_string(font, sp + Vector2(-tw / 2.0, -15), p[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, p[2])
		_marks.draw_colored_polygon(PackedVector2Array([sp + Vector2(0, -8), sp + Vector2(5, -3), sp + Vector2(0, 2), sp + Vector2(-5, -3)]), p[2])


# ---------------- подсказки ----------------
func show_tip(t: String) -> void:
	_tip.text = t
	_tip.visible = true
	_tip_timer = 0.0


func hide_tip() -> void:
	if _tip:
		_tip.visible = false


func flash_tip(t: String) -> void:
	show_tip(t)
	_tip_timer = 1.3


func toast(t: String, dur := 2.5) -> void:
	_toast.text = t
	_toast.size.x = 0
	_toast.position.x = (size.x - _toast.get_minimum_size().x) / 2.0
	var tw := create_tween()
	_toast.modulate.a = 1.0
	tw.tween_interval(dur)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.6)


func hurt_flash() -> void:
	_hurt.color.a = 0.28
	var tw := create_tween()
	tw.tween_property(_hurt, "color:a", 0.0, 0.4)


func float_text(world_pos: Vector3, text: String, cls := "") -> void:
	var cam: Camera3D = main.camera
	if cam == null or cam.is_position_behind(world_pos):
		return
	var l := UITheme.label(text, 16, UITheme.HIT if cls == "hit" else (UITheme.MISS if cls == "miss" else UITheme.AMBER_HOT), true)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("shadow_offset_y", 1)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_floats.add_child(l)
	var p := cam.unproject_position(world_pos)
	l.position = p - Vector2(l.get_minimum_size().x / 2.0, 0)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y - 40, 1.1)
	tw.tween_property(l, "modulate:a", 0.0, 1.1).set_delay(0.4)
	tw.chain().tween_callback(l.queue_free)


func show_zones(rows: Array) -> void:
	for c in _zones_box.get_children():
		c.queue_free()
	for r in rows:
		var b := UITheme.key("%s ×%d\n−%d · шанс %d%%" % [r.zone, r.mult, r.pen, r.chance], "normal", 12)
		b.custom_minimum_size = Vector2(130, 0)
		b.pressed.connect(zone_chosen.emit.bind(r.zone))
		_zones_box.add_child(b)
	var cancel := UITheme.key("Отмена", "warn", 12)
	cancel.pressed.connect(zone_chosen.emit.bind(""))
	_zones_box.add_child(cancel)
	_zones.visible = true


func hide_zones() -> void:
	if _zones:
		_zones.visible = false


func _process(delta: float) -> void:
	_place_thought(delta)
	_marks.queue_redraw()
	if _tip.visible:
		var mp := get_viewport().get_mouse_position()
		_tip.position = mp + Vector2(16, 16)
		_tip.size = Vector2.ZERO
		if _tip.position.x + _tip.size.x > size.x:
			_tip.position.x = size.x - _tip.size.x - 8
		if _tip_timer > 0:
			_tip_timer -= delta
			if _tip_timer <= 0:
				_tip.visible = false


## Над панелью ли мышь (чтобы клики не уходили в мир)
func mouse_over_ui() -> bool:
	var mp := get_viewport().get_mouse_position()
	if _hand.visible and _hand.get_global_rect().has_point(mp):
		return true
	return (_bar.visible and mp.y > size.y - 166) or (_zones.visible and _zones.get_global_rect().has_point(mp)) or _menu_bar.get_global_rect().has_point(mp)
