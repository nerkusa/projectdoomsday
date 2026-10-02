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
	# уговорил того, кто сторонился, — дальше говорит как обычно
	if id == "start" and node_id == "__avoid" and speaker:
		Game.set_flag("heard_" + speaker.uid())
	var n: Dictionary
	if id == "start" and _avoids():
		id = "__avoid"
		n = _avoid_node()
	elif id == "__avoid_no":
		n = {"text": _greet_line("avoid_no", AVOID_NO), "options": [{"text": "[Уйти]", "next": null}]}
	elif nodes.has(id):
		n = nodes[id]
	else:
		push_warning("Нет узла диалога: " + id)
		close()
		return
	node_id = id
	# эффекты узла: quest / set_flags / xp / note прямо в узле или в "on_enter"
	_apply_effects(n)
	_apply_effects(n.get("on_enter", {}))
	var who: String = n.get("speaker", data.get("speaker", speaker.display_name if speaker else ""))
	var title: String = n.get("title", data.get("title", who)) if not n.has("speaker") else n.get("title", who)
	_who.text = title.to_upper()
	_face.text = who.left(1).to_upper() if who != "" else "…"
	_full = _subst(_rep_greet(id, n) + _node_text(n))
	_chars = 0.0
	var d: float = DELAY.get(Game.settings.get("text_speed", "normal"), 0.028)
	_typing = d > 0.0
	_text.text = _full
	_text.visible_characters = 0 if _typing else -1
	_build_options(n.get("options", []))
	if n.has("action"):
		action.emit(n.action, speaker)


## Текст узла. "sakha" — реплика на старом языке: с Разумом герой понимает
## и видит перевод (text), без него — только звучание и text_nosakha.
func _node_text(n: Dictionary) -> String:
	var t := _pick_text(n)
	if not n.has("sakha"):
		return t
	if Game.knows_sakha():
		_sakha_noticed()
		return "«%s»\n— %s" % [n.sakha, t]
	return "«%s»\n%s" % [n.sakha, n.get("text_nosakha", "(Говорит на старом языке — саха тыла. Ты ловишь отдельные слова, но смысл ускользает.)")]


func _sakha_noticed() -> void:
	if not Game.flag("sakha_noticed"):
		Game.set_flag("sakha_noticed")
		Game.log_line("[Разум] Старый язык: понимаешь, о чём говорят.", "", "hit")


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
		# ответить на старом языке может только тот, кто его понимает
		if o.has("sakha") and not Game.knows_sakha():
			continue
		_visible_opts.append(o)
	if _visible_opts.is_empty():
		_visible_opts.append({"text": "[Дальше]", "next": null})
	for i in _visible_opts.size():
		var o: Dictionary = _visible_opts[i]
		var b := Button.new()
		var ot := _subst(o.get("text", "…"))
		if o.has("sakha"):
			ot = "[Саха] «%s» (%s)" % [o.sakha, ot]
		b.text = "%d. %s" % [i + 1, ot]
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
	if o.get("give_trinket", false):
		var tk := _a_trinket()
		if tk != "":
			Game.remove_item(tk)
			Game.log_line("Отдано: %s" % DB.item_name(tk))
	var nxt = o.get("next", null)
	if o.has("check"):
		var c: Dictionary = o.check
		var bonus := int(c.get("bonus", 0))
		if c.get("bonus_gun", 0) and DB.is_gun(Game.hero_wkey()):
			bonus += int(c.bonus_gun)
		var ok := Game.skill_check(c.get("label", c.get("skill", "")), c.get("stat", "CHA"), c.get("skill", ""), int(c.get("dc", 12)), bonus)
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
	# урон без боя (дорожные случаи): не убивает, оставляет 1 ХП
	if o.has("hurt"):
		Game.set_hero_hp(maxi(1, Game.hero_hp() - int(o.hurt)))
		Game.log_line("−%d ХП" % int(o.hurt), "", "miss")
	if o.has("reveal"):
		WorldMap.reveal(str(o.reveal))
	# молва: собеседник — свидетель
	if o.has("rep"):
		Game.change_rep(int(o.rep), str(o.get("rep_why", "")))


## Условия показа: {"flag": "...", "not_flag": "...", "flags": [...], "not_flags": [...], "quest": "id", "stage_min": 1,
## "stage_max": 2, "item": "ключ", "no_item": "ключ", "rep_min": 10, "rep_max": -10,
## "cond": "имя проверки в скрипте локации", "sakha": true — герой понимает старый язык,
## "trinket": true — в сумке есть безделушка}
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
	if c.has("sakha") and bool(c.sakha) != Game.knows_sakha():
		return false
	if c.has("trinket") and (_a_trinket() != "") != bool(c.trinket):
		return false
	if c.has("rep_min") and Game.rep() < int(c.rep_min):
		return false
	if c.has("rep_max") and Game.rep() > int(c.rep_max):
		return false
	if c.has("cond"):
		var loc = get_tree().get_first_node_in_group("location")
		if loc and loc.has_method("dialog_cond") and not loc.dialog_cond(c.cond):
			return false
	return true


func _subst(s: String) -> String:
	return s.replace("{hero}", str(Game.hero.name)).replace("{addr}", addr())


## Ступень молвы: hero / good / plain / bad / monster
static func rep_tier() -> String:
	var r := Game.rep()
	if r >= 30:
		return "hero"
	if r >= 10:
		return "good"
	if r <= -30:
		return "monster"
	if r <= -10:
		return "bad"
	return "plain"


## Как к герою обращаются. Прозвищ по молве нет: добрая слава — «парень»,
## дурная — «чужак», даже если свой.
static func addr() -> String:
	return str(DB._load("res://data/rep_greet.json").get("addr", {}).get(rep_tier(), "парень"))


const AVOID_NO := "(Отворачивается.) Не о чем нам говорить."


## Своя строка собеседника из "greet" его разговора, иначе — общая
func _greet_line(key: String, fallback: String) -> String:
	var own = data.get("greet", {}).get(key, null)
	var lines: Array = []
	if own is Array:
		lines = own
	elif own != null:
		lines = [own]
	else:
		lines = DB._load("res://data/rep_greet.json").get(key, [])
	if lines.is_empty():
		return fallback
	var seed := (speaker.uid() if speaker else "") + str(data.get("speaker", ""))
	return str(lines[absi(hash(seed)) % lines.size()])


## Сторонится ли собеседник героя: при очень дурной молве люди не хотят говорить —
## пока не уговоришь, не запугаешь или не задобришь. Сюжетно важные — говорят всегда.
func _avoids() -> bool:
	if speaker == null or speaker.hostile or data.get("must_talk", false):
		return false
	if speaker.char_id in ["accused", "lost_kid", "target"] or speaker.pose in ["down", "yield", "dead"]:
		return false
	if rep_tier() != "monster" or Game.flag("heard_" + speaker.uid()):
		return false
	return true


func _avoid_node() -> Dictionary:
	return {"text": _greet_line("avoid", "(Отводит глаза и отходит.) Иди своей дорогой."), "options": [
		{"text": "[Убеждение] Выслушай. Про меня врут.", "check": {"stat": "CHA", "skill": "Убеждение", "dc": 14}, "success": "start", "fail": "__avoid_no"},
		{"text": "[Запугивание] Говорить будешь, когда спрашивают.", "check": {"stat": "BODY", "skill": "Запугивание", "dc": 13}, "success": "start", "fail": "__avoid_no", "rep": -2, "rep_why": "запугал человека"},
		{"text": "[Отдать безделушку] Держи. Просто так.", "if": {"trinket": true}, "give_trinket": true, "next": "start"},
		{"text": "[Уйти]", "next": null}]}


func _a_trinket() -> String:
	for k in Game.hero.items:
		if DB.items.get(k, {}).get("trinket", false) and int(Game.hero.items[k]) > 0:
			return str(k)
	return ""


## Приветствие по молве перед первой репликой — если у разговора нет своего
## варианта по молве. Мысли, дорожные случаи и чужие тут не здороваются.
func _rep_greet(id: String, n: Dictionary) -> String:
	if id != "start" or speaker == null or not visible:
		return ""
	if speaker.hostile or speaker.char_id in ["accused", "lost_kid", "target"]:
		return ""
	for alt in n.get("text_if", []):
		var c: Dictionary = alt.get("if", {})
		if c.has("rep_min") or c.has("rep_max"):
			return ""
	var tier := rep_tier()
	if tier == "plain":
		return ""
	var key := "good" if tier in ["hero", "good"] else "bad"
	var loc = get_tree().get_first_node_in_group("location")
	var generic := key
	if loc and loc.location_id == "nakharro":
		generic = "village_" + key
	# свой голос у собеседника важнее общих строк
	var own = data.get("greet", {}).get(key, null)
	if own != null:
		return _greet_line(key, "") + "\n"
	var line := _greet_line(generic, "")
	return (line + "\n") if line != "" else ""


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
