class_name DialogBox
extends Control
## Окно разговора. Реплики берутся из data/dialogs/<файл>.json.
## Формат описан в README.md (раздел «Как писать диалоги»).

signal action(name: String, speaker: Character)
signal closed

const DELAY := {"slow": 0.045, "normal": 0.028, "fast": 0.01, "instant": 0.0}

var data: Dictionary = {}
var speaker: Character
var node_id := ""
var _panel: PanelContainer
var _who: Label
var _face: Label
var _text: RichTextLabel
var _opts: VBoxContainer
var _typing := false
var _full := ""
var _chars := 0.0
var _visible_opts: Array = []


func setup() -> void:
	UITheme.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.02, 0.01, 0.35)
	UITheme.full_rect(dim)
	add_child(dim)
	_panel = UITheme.panel(UITheme.plastic(8))
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_panel.offset_left = -470
	_panel.offset_right = 470
	_panel.offset_top = -470
	_panel.offset_bottom = -175
	add_child(_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	_panel.add_child(v)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	top.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(top)
	var face := UITheme.panel(UITheme.screen(false, 6))
	face.custom_minimum_size = Vector2(150, 150)
	top.add_child(face)
	_face = UITheme.label("?", 64, UITheme.AMBER, true)
	_face.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_face.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	face.add_child(_face)
	var reply := UITheme.panel(UITheme.screen(false, 14))
	reply.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(reply)
	var rv := VBoxContainer.new()
	reply.add_child(rv)
	_who = UITheme.label("", 12, UITheme.AMBER_DIM, true)
	rv.add_child(_who)
	_text = RichTextLabel.new()
	_text.bbcode_enabled = false
	_text.fit_content = false
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.add_theme_font_override("normal_font", UITheme.mono())
	_text.add_theme_font_size_override("normal_font_size", 16)
	_text.add_theme_color_override("default_color", UITheme.AMBER)
	_text.gui_input.connect(_on_text_click)
	rv.add_child(_text)
	var op := UITheme.panel(UITheme.screen(false, 8))
	v.add_child(op)
	_opts = VBoxContainer.new()
	_opts.add_theme_constant_override("separation", 2)
	op.add_child(_opts)
	visible = false


func open(dialog_id: String, start_node: String, who: Character) -> void:
	data = DB.dialog(dialog_id)
	if data.is_empty():
		push_warning("Диалог не найден: " + dialog_id)
		return
	speaker = who
	visible = true
	show_node(start_node if start_node != "" else "start")


func close() -> void:
	visible = false
	_typing = false
	closed.emit()


func show_node(id: String) -> void:
	var nodes: Dictionary = data.get("nodes", {})
	if not nodes.has(id):
		push_warning("Нет узла диалога: " + id)
		close()
		return
	node_id = id
	var n: Dictionary = nodes[id]
	# эффекты узла: quest / set_flags / xp / note прямо в узле или в "on_enter"
	_apply_effects(n)
	_apply_effects(n.get("on_enter", {}))
	var who: String = n.get("speaker", data.get("speaker", speaker.display_name if speaker else ""))
	var title: String = n.get("title", data.get("title", who)) if not n.has("speaker") else n.get("title", who)
	_who.text = title.to_upper()
	_face.text = who.left(1).to_upper() if who != "" else "…"
	_full = _subst(_pick_text(n))
	_chars = 0.0
	var d: float = DELAY.get(Game.settings.get("text_speed", "normal"), 0.028)
	_typing = d > 0.0
	_text.text = _full
	_text.visible_characters = 0 if _typing else -1
	_build_options(n.get("options", []))
	if n.has("action"):
		action.emit(n.action, speaker)


func _pick_text(n: Dictionary) -> String:
	for alt in n.get("text_if", []):
		if _cond_ok(alt.get("if", {})):
			return alt.get("text", "")
	return n.get("text", "")


func _build_options(opts: Array) -> void:
	for c in _opts.get_children():
		c.queue_free()
	_visible_opts = []
	for o in opts:
		if not _cond_ok(o.get("if", {})):
			continue
		_visible_opts.append(o)
	if _visible_opts.is_empty():
		_visible_opts.append({"text": "[Дальше]", "next": null})
	for i in _visible_opts.size():
		var o: Dictionary = _visible_opts[i]
		var b := Button.new()
		b.text = "%d. %s" % [i + 1, _subst(o.get("text", "…"))]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_override("font", UITheme.mono())
		b.add_theme_font_size_override("font_size", 15)
		var e := StyleBoxEmpty.new()
		e.set_content_margin_all(5)
		var hv := StyleBoxFlat.new()
		hv.bg_color = Color(UITheme.AMBER, 0.12)
		hv.set_content_margin_all(5)
		hv.set_corner_radius_all(3)
		b.add_theme_stylebox_override("normal", e)
		b.add_theme_stylebox_override("hover", hv)
		b.add_theme_stylebox_override("pressed", hv)
		b.add_theme_stylebox_override("focus", e)
		b.add_theme_color_override("font_color", UITheme.AMBER)
		b.add_theme_color_override("font_hover_color", UITheme.AMBER_HOT)
		b.add_theme_color_override("font_pressed_color", UITheme.AMBER_HOT)
		b.pressed.connect(_choose.bind(i))
		_opts.add_child(b)


func _choose(i: int) -> void:
	if i < 0 or i >= _visible_opts.size():
		return
	if _typing:
		_finish_typing()
	var o: Dictionary = _visible_opts[i]
	_apply_effects(o)
	var nxt = o.get("next", null)
	if o.has("check"):
		var c: Dictionary = o.check
		var bonus := int(c.get("bonus", 0))
		if c.get("bonus_gun", 0) and DB.is_gun(Game.hero_wkey()):
			bonus += int(c.bonus_gun)
		var ok := Game.skill_check(c.get("label", c.get("skill", "")), c.get("stat", "EMP"), c.get("skill", ""), int(c.get("dc", 12)), bonus)
		nxt = o.get("success") if ok else o.get("fail")
		if ok and o.has("xp_success"):
			var note := Game.grant_xp(int(o.xp_success))
			Game.log_line("Опыт +%d" % int(o.xp_success), note.strip_edges())
	if o.has("action"):
		action.emit(o.action, speaker)
		if not visible:
			return
	if nxt == null or nxt == "":
		close()
	else:
		show_node(str(nxt))


func _apply_effects(o: Dictionary) -> void:
	var sf: Dictionary = o.get("set_flags", {})
	for k in sf:
		Game.set_flag(k, sf[k])
	if o.has("quest"):
		var q: Dictionary = o.quest
		Game.set_quest(q.id, int(q.stage))
	var give: Dictionary = o.get("give", {})
	for k in give:
		Game.add_item(k, int(give[k]))
		Game.log_line("Получено: %s%s" % [DB.item_name(k), (" ×%d" % int(give[k])) if int(give[k]) > 1 else ""], "", "hit")
	var take: Dictionary = o.get("take", {})
	for k in take:
		Game.remove_item(k, int(take[k]))
		Game.log_line("Отдано: %s" % DB.item_name(k))
	if o.has("xp"):
		var note := Game.grant_xp(int(o.xp))
		Game.log_line("Опыт +%d" % int(o.xp), note.strip_edges())
	if o.has("note"):
		Game.add_note(o.note)
	if o.has("humanity"):
		Game.change_humanity(int(o.humanity))


## Условия показа: {"flag": "...", "not_flag": "...", "flags": [...], "not_flags": [...], "quest": "id", "stage_min": 1,
## "stage_max": 2, "item": "ключ", "no_item": "ключ", "humanity_min": 50, "humanity_max": 30,
## "cond": "имя проверки в скрипте локации"}
func _cond_ok(c: Dictionary) -> bool:
	if c.is_empty():
		return true
	if c.has("flag") and not Game.flag(c.flag):
		return false
	if c.has("not_flag") and Game.flag(c.not_flag):
		return false
	for f in c.get("flags", []):
		if not Game.flag(f):
			return false
	for f in c.get("not_flags", []):
		if Game.flag(f):
			return false
	if c.has("quest"):
		var st := Game.quest_stage(c.quest)
		if c.has("stage_min") and st < int(c.stage_min):
			return false
		if c.has("stage_max") and st > int(c.stage_max):
			return false
		if c.has("stage") and st != int(c.stage):
			return false
	if c.has("item") and Game.item_count(c.item) <= 0:
		return false
	if c.has("no_item") and Game.item_count(c.no_item) > 0:
		return false
	if c.has("hurt") and Game.hero_hp() >= Game.hero_max():
		return false
	if c.has("humanity_min") and Game.humanity() < int(c.humanity_min):
		return false
	if c.has("humanity_max") and Game.humanity() > int(c.humanity_max):
		return false
	if c.has("cond"):
		var loc = get_tree().get_first_node_in_group("location")
		if loc and loc.has_method("dialog_cond") and not loc.dialog_cond(c.cond):
			return false
	return true


func _subst(s: String) -> String:
	return s.replace("{hero}", str(Game.hero.name))


func _finish_typing() -> void:
	_typing = false
	_text.visible_characters = -1


func _on_text_click(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and _typing:
		_finish_typing()


func _process(delta: float) -> void:
	if not visible or not _typing:
		return
	var d: float = DELAY.get(Game.settings.get("text_speed", "normal"), 0.028)
	_chars += delta / maxf(d, 0.001) * 2.0
	_text.visible_characters = int(_chars)
	if _chars >= _full.length():
		_finish_typing()


func _unhandled_key_input(e: InputEvent) -> void:
	if not visible:
		return
	if e is InputEventKey and e.pressed and not e.echo:
		var k: int = e.keycode
		if k >= KEY_1 and k <= KEY_9:
			_choose(k - KEY_1)
			get_viewport().set_input_as_handled()
		elif k == KEY_SPACE or k == KEY_ENTER:
			if _typing:
				_finish_typing()
			elif _visible_opts.size() == 1:
				_choose(0)
			get_viewport().set_input_as_handled()
