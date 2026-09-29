class_name LootWindow
extends Control
## Окно обыска: что лежит в теле, сундуке или чужом кармане. Каждую вещь можно
## взять отдельно или всё сразу; то, что взять нельзя, показано серым с причиной.
## Запись: {"id": ключ, "n": сколько, "name": подпись, "ok": можно ли взять, "why": почему нельзя}

signal closed

var main: Node
var _title: Label
var _list: VBoxContainer
var _all: Button
var _entries: Array = []
var _on_take := Callable()
var _on_close := Callable()


func setup(m: Node) -> void:
	main = m
	UITheme.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.02, 0.01, 0.35)
	UITheme.full_rect(dim)
	dim.gui_input.connect(func(e): if e is InputEventMouseButton and e.pressed: close())
	add_child(dim)
	var body := UITheme.panel(UITheme.plastic(10))
	body.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	body.offset_left = -250
	body.offset_right = 250
	body.offset_top = -220
	body.offset_bottom = 200
	add_child(body)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	body.add_child(v)
	_title = UITheme.label("", 15, UITheme.INK_2, true)
	v.add_child(_title)
	v.add_child(UITheme.stripe(5))
	var scr := UITheme.panel(UITheme.screen(true, 10))
	scr.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(scr)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scr.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_list)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	v.add_child(row)
	_all = UITheme.key("Взять всё  [E]", "primary", 12)
	_all.pressed.connect(take_all)
	row.add_child(_all)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(sp)
	var x := UITheme.key("Закрыть  [Esc]", "warn", 12)
	x.pressed.connect(close)
	row.add_child(x)
	visible = false


## on_take(entry) -> bool: забрать вещь (true — ушла в сумку); on_close(оставшиеся записи)
func open(title: String, entries: Array, on_take: Callable, on_close := Callable()) -> void:
	_title.text = title.to_upper()
	_entries = entries.duplicate(true)
	_on_take = on_take
	_on_close = on_close
	visible = true
	_render()


func entries() -> Array:
	return _entries


func _render() -> void:
	for c in _list.get_children():
		c.queue_free()
	var any_ok := false
	if _entries.is_empty():
		_list.add_child(UITheme.label("Пусто.", 14, UITheme.GREEN_DIM))
	for i in _entries.size():
		var e: Dictionary = _entries[i]
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 8)
		_list.add_child(hb)
		var txt: String = e.get("name", DB.item_name(str(e.id)))
		if int(e.get("n", 1)) > 1:
			txt += " ×%d" % int(e.n)
		var ok: bool = e.get("ok", true)
		var l := UITheme.label(txt, 14, UITheme.GREEN if ok else UITheme.GREEN_DIM)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hb.add_child(l)
		if ok:
			any_ok = true
			var b := UITheme.key("Взять", "normal", 11)
			var idx := i
			b.pressed.connect(func(): take(idx))
			hb.add_child(b)
		else:
			hb.add_child(UITheme.label(str(e.get("why", "")), 12, UITheme.GREEN_DIM))
	_all.disabled = not any_ok


func take(i: int) -> void:
	if i < 0 or i >= _entries.size():
		return
	var e: Dictionary = _entries[i]
	if not e.get("ok", true):
		return
	if _on_take.is_valid() and _on_take.call(e):
		_entries.remove_at(i)
	if visible:
		_render()


func take_all() -> void:
	var i := 0
	while i < _entries.size():
		var n := _entries.size()
		if _entries[i].get("ok", true):
			take(i)
		if _entries.size() == n:
			i += 1
	close()


func close() -> void:
	if not visible:
		return
	visible = false
	if _on_close.is_valid():
		_on_close.call(_entries)
	closed.emit()


func _unhandled_key_input(e: InputEvent) -> void:
	if not visible or not (e is InputEventKey) or not e.pressed or e.echo:
		return
	if e.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()
	elif e.keycode == KEY_E:
		take_all()
		get_viewport().set_input_as_handled()
