class_name WorldMap
extends Control
## Карта мира на экране КПК (data/world.json): куда можно дойти отсюда.
## Выбрать точку → «Идти». По дороге иногда случается что-нибудь (проверка навыка).
## Открытые точки — Game.hero.flags["map_known"], где стоишь — flags["map_at"].

signal closed

var main: Node
var data: Dictionary = {}
var at := ""
var sel := ""
var _canvas: Control
var _name: Label
var _desc: Label
var _info: Label
var _go: Button
var _back: Button
var _t := 0.0


func setup(m: Node) -> void:
	main = m
	data = DB._load("res://data/world.json")
	UITheme.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.035, 0.02, 0.92)
	UITheme.full_rect(bg)
	add_child(bg)
	var body := UITheme.panel(UITheme.plastic(12))
	body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body.offset_left = 60
	body.offset_right = -60
	body.offset_top = 40
	body.offset_bottom = -40
	add_child(body)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	body.add_child(v)
	var head := UITheme.label("КАРТА · ТАЙГА ЗА ЧЕРТОЙ", 15, UITheme.INK_2, true)
	v.add_child(head)
	v.add_child(UITheme.stripe(5))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(h)
	var scr := UITheme.panel(UITheme.screen(true, 6))
	scr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scr.size_flags_stretch_ratio = 3.0
	h.add_child(scr)
	_canvas = Control.new()
	_canvas.clip_contents = true
	_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	_canvas.draw.connect(_draw_map)
	_canvas.gui_input.connect(_on_canvas_input)
	scr.add_child(_canvas)
	var side := UITheme.panel(UITheme.screen(true, 12))
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(side)
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 10)
	side.add_child(sv)
	_name = UITheme.label("", 18, UITheme.GREEN_HI, true)
	_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sv.add_child(_name)
	_desc = UITheme.label("", 14, UITheme.GREEN)
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sv.add_child(_desc)
	_info = UITheme.label("", 13, UITheme.GREEN_DIM)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sv.add_child(_info)
	_go = UITheme.key("Идти  [Enter]", "primary", 13)
	_go.pressed.connect(func(): travel(sel))
	sv.add_child(_go)
	_back = UITheme.key("Остаться  [Esc]", "warn", 13)
	_back.pressed.connect(close)
	sv.add_child(_back)
	visible = false


func nodes() -> Dictionary:
	return data.get("nodes", {})


func known(id: String) -> bool:
	var kn: Dictionary = Game.hero.flags.get("map_known", {})
	return nodes().get(id, {}).get("known", false) or kn.has(id)


## Отметить точку на карте (слух, записка, разговор)
static func reveal(id: String) -> void:
	var kn: Dictionary = Game.hero.flags.get("map_known", {})
	if kn.has(id):
		return
	kn[id] = true
	Game.hero.flags["map_known"] = kn
	var nm: String = DB._load("res://data/world.json").get("nodes", {}).get(id, {}).get("name", id)
	Game.log_line("Новая точка на карте: " + nm, "", "hit")


## Можно ли уйти отсюда туда: точка известна, открыта и есть дорога
func can_go(id: String) -> bool:
	var n: Dictionary = nodes().get(id, {})
	if id == at or not known(id) or n.is_empty():
		return false
	# конец сборки: в Сунгар можно, когда известно, что Боотур ушёл туда
	if n.has("end") and Game.quest_stage("bootur") >= 2:
		return _road(at, id)
	if not n.has("loc"):
		return false
	return _road(at, id)


func _road(a: String, b: String) -> bool:
	for r in data.get("roads", []):
		if (r[0] == a and r[1] == b) or (r[0] == b and r[1] == a):
			return true
	return false


## Часы пути: по расстоянию на карте
func hours(a: String, b: String) -> int:
	var pa := _np(a)
	var pb := _np(b)
	return maxi(2, roundi(pa.distance_to(pb) * 28.0))


func _np(id: String) -> Vector2:
	var p: Array = nodes().get(id, {}).get("pos", [0.5, 0.5])
	return Vector2(float(p[0]), float(p[1]))


func open(from_id: String) -> void:
	at = from_id
	Game.hero.flags["map_at"] = from_id
	sel = ""
	for id in nodes():
		if can_go(id):
			sel = id
			break
	visible = true
	_refresh()


func select(id: String) -> void:
	if not known(id):
		return
	sel = id
	_refresh()


func _refresh() -> void:
	var n: Dictionary = nodes().get(sel, {})
	if sel == "":
		_name.text = "Карта"
		_desc.text = "Отсюда пока некуда идти."
		_info.text = ""
		_go.disabled = true
		_canvas.queue_redraw()
		return
	_name.text = str(n.get("name", sel)).to_upper()
	_desc.text = str(n.get("desc", ""))
	if sel == at:
		_info.text = "Ты здесь."
	elif can_go(sel):
		_info.text = "Дорога: около %d ч пешком." % hours(at, sel)
		if Game.flag("visited_" + sel):
			_info.text += "\nУже бывал."
	elif n.has("locked"):
		_info.text = str(n.locked)
	elif not _road(at, sel):
		_info.text = "Отсюда напрямую не дойти."
	_go.disabled = not can_go(sel)
	_back.visible = at != "nakharro" or Game.flag("visited_kresty")
	_canvas.queue_redraw()


## Уйти в выбранную точку: дорожный случай, потом загрузка локации
func travel(id: String) -> void:
	if not can_go(id):
		return
	var n: Dictionary = nodes()[id]
	var h := hours(at, id)
	visible = false
	Game.log_line("Дорога: %s → %s, около %d ч." % [nodes()[at].get("name", at), n.get("name", id), h])
	if n.has("end"):
		main.show_end(str(n.end))
		closed.emit()
		return
	_road_event()
	Game.set_flag("visited_" + id)
	Game.hero.flags["map_at"] = id
	Game.hero.pos = []
	await main.load_location(str(n.loc), str(n.get("spawn", "Start")))
	main.autosave()
	closed.emit()


## Случай по дороге: примерно каждый второй переход
func _road_event() -> void:
	var evs: Array = data.get("events", [])
	if evs.is_empty() or randf() > 0.5:
		return
	var seen: Array = Game.hero.flags.get("road_seen", [])
	var pool := []
	for i in evs.size():
		if not seen.has(i):
			pool.append(i)
	if pool.is_empty():
		return
	var i: int = pool.pick_random()
	seen.append(i)
	Game.hero.flags["road_seen"] = seen
	var e: Dictionary = evs[i]
	Game.log_line("В пути: " + str(e.text))
	if Game.skill_check(str(e.skill), str(e.stat), str(e.skill), int(e.dc)):
		Game.log_line(str(e.ok), "", "hit")
		var g: Dictionary = e.get("give", {})
		for k in g:
			Game.add_item(k, int(g[k]))
	else:
		Game.log_line(str(e.fail), "", "miss")
		if e.has("hurt"):
			Game.set_hero_hp(maxi(1, Game.hero_hp() - int(e.hurt)))


func close() -> void:
	if not visible or not _back.visible:
		return
	visible = false
	closed.emit()


func _process(delta: float) -> void:
	if visible:
		_t += delta
		_canvas.queue_redraw()


# ---------------- рисунок ----------------
func _to_px(p: Vector2) -> Vector2:
	return p * _canvas.size


func _draw_map() -> void:
	var c := _canvas
	var sz := c.size
	var dim := Color(UITheme.GREEN_DIM, 0.35)
	# тайга: штриховка ёлочками по сетке с шумом
	var rng := RandomNumberGenerator.new()
	rng.seed = 2062
	for i in 420:
		var p := Vector2(rng.randf(), rng.randf()) * sz
		var s := rng.randf_range(4.0, 8.0)
		c.draw_line(p, p + Vector2(-s * 0.5, s), dim, 1.0)
		c.draw_line(p, p + Vector2(s * 0.5, s), dim, 1.0)
	# болота
	for i in 40:
		var p := Vector2(rng.randf_range(0.38, 0.56), rng.randf_range(0.12, 0.3)) * sz
		c.draw_line(p, p + Vector2(10, 0), Color(UITheme.S3, 0.7), 1.0)
	# реки
	for r in data.get("rivers", []):
		var pts := PackedVector2Array()
		for q in r:
			pts.append(_to_px(Vector2(float(q[0]), float(q[1]))))
		c.draw_polyline(pts, Color("4f8f96"), 3.0, true)
	# дороги между известными точками
	for r in data.get("roads", []):
		if not (known(r[0]) and known(r[1])):
			continue
		var a := _to_px(_np(r[0]))
		var b := _to_px(_np(r[1]))
		var open_road: bool = (r[0] == at or r[1] == at) and (can_go(r[0]) or can_go(r[1]))
		c.draw_dashed_line(a, b, UITheme.GREEN if open_road else UITheme.GREEN_DIM, 2.0 if open_road else 1.0, 8.0)
	# точки
	var f := UITheme.mono()
	for id in nodes():
		if not known(id):
			continue
		var n: Dictionary = nodes()[id]
		var p := _to_px(_np(id))
		var col := UITheme.GREEN if n.has("loc") or can_go(id) else UITheme.GREEN_DIM
		if n.get("burned", false):
			col = UITheme.RED
			c.draw_line(p + Vector2(-7, -7), p + Vector2(7, 7), col, 3.0)
			c.draw_line(p + Vector2(-7, 7), p + Vector2(7, -7), col, 3.0)
		else:
			c.draw_circle(p, 7.0, col)
			c.draw_circle(p, 3.0, UITheme.GREEN_BG)
		if id == sel:
			c.draw_arc(p, 14.0, 0, TAU, 32, UITheme.AMBER, 2.0)
		if id == at:
			var r := 18.0 + sin(_t * 4.0) * 3.0
			c.draw_arc(p, r, 0, TAU, 32, UITheme.GREEN_HI, 1.5)
		c.draw_string(f, p + Vector2(12, -10), str(n.get("name", id)), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, UITheme.GREEN_HI if id == sel else col)
	c.draw_string(f, Vector2(12, sz.y - 12), "ЛКМ — выбрать точку", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UITheme.GREEN_DIM)


func _on_canvas_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		var best := ""
		var bd := 26.0
		for id in nodes():
			if not known(id):
				continue
			var d: float = _to_px(_np(id)).distance_to(e.position)
			if d < bd:
				bd = d
				best = id
		if best != "":
			select(best)
		if e.double_click and best != "" and can_go(best):
			travel(best)


func _unhandled_key_input(e: InputEvent) -> void:
	if not visible or not (e is InputEventKey) or not e.pressed or e.echo:
		return
	if e.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()
	elif e.keycode == KEY_ENTER or e.keycode == KEY_KP_ENTER:
		travel(sel)
		get_viewport().set_input_as_handled()
