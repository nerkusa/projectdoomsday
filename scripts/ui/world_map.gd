class_name WorldMap
extends Control
## Карта мира как в Fallout: по картинке (data/world.json → image) герой ходит сам,
## куда кликнешь. Время в пути идёт, точки рядом с дорогой открываются сами,
## по дороге случаются встречи (data/world.json → encounters, тексты — data/dialogs/road.json).
## Клик по точке — выбрать; «Идти» или двойной клик — дойти и войти. Клик по пустому
## месту — просто идти туда. Правая кнопка — стоп.
## Где герой на карте — Game.hero.flags["wm_pos"]; время в пути идёт по общим часам (Clock).

signal closed
## Дошёл до точки и вошёл в неё (или началась встреча)
signal arrived

## Скорость значка героя: пикселей картинки в секунду
const SPEED := 55.0
## Приближение карты: камера ходит за героем. Колесо мыши, +/− — ближе / дальше
const ZOOM_MIN := 1.0
const ZOOM_MAX := 4.0
const ZOOM_START := 2.6
## Насколько близко к точке надо подойти, чтобы считалось «на месте»
const NEAR := 12.0
## Радиус открытия точек по умолчанию (пиксели картинки)
const REVEAL_R := 45.0

var main: Node
var data: Dictionary = {}
var img_size := Vector2(1935, 812)
## Точка, где стоит герой ("" — посреди тайги)
var at := ""
var sel := ""
var pos := Vector2.ZERO
var target := Vector2.ZERO
var moving := false
## Можно выключить встречи (автотест)
var encounters_on := true
var _enter_on_arrive := ""
var _start := Vector2.ZERO
var _trail: Array = []
var _acc := 0.0
var _paused := false
var _entering := false
var _hover := Vector2(-1, -1)
var _t := 0.0
var zoom := ZOOM_START
var _view: Control

var _tex: TextureRect
var _canvas: Control
var _time: Label
var _name: Label
var _desc: Label
var _info: Label
var _go: Button
var _back: Button


func setup(m: Node) -> void:
	main = m
	data = DB._load("res://data/world.json")
	var sz: Array = data.get("size", [1935, 812])
	img_size = Vector2(float(sz[0]), float(sz[1]))
	UITheme.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.035, 0.02, 0.96)
	UITheme.full_rect(bg)
	add_child(bg)
	var body := UITheme.panel(UITheme.plastic(12))
	body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body.offset_left = 24
	body.offset_right = -24
	body.offset_top = 16
	body.offset_bottom = -16
	add_child(body)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	body.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	head.add_child(UITheme.label("КАРТА · ТАЙГА ЗА ЧЕРТОЙ", 15, UITheme.INK_2, true))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	_time = UITheme.label("", 14, UITheme.INK_2, true)
	head.add_child(_time)
	v.add_child(UITheme.stripe(4))
	# окно карты: картинка крупнее окна, камера держит героя в центре
	_view = Control.new()
	_view.clip_contents = true
	_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_view.mouse_filter = Control.MOUSE_FILTER_PASS
	v.add_child(_view)
	_view.resized.connect(_layout)
	_tex = TextureRect.new()
	_tex.texture = load(str(data.get("image", "res://assets/textures/world_map.jpg")))
	_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_tex.stretch_mode = TextureRect.STRETCH_SCALE
	_view.add_child(_tex)
	_canvas = Control.new()
	UITheme.full_rect(_canvas)
	_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	_canvas.draw.connect(_draw_map)
	_canvas.gui_input.connect(_on_canvas_input)
	_canvas.mouse_exited.connect(func(): _hover = Vector2(-1, -1))
	_tex.add_child(_canvas)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 12)
	bar.custom_minimum_size = Vector2(0, 104)
	v.add_child(bar)
	var info := UITheme.panel(UITheme.screen(true, 10))
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(info)
	var iv := VBoxContainer.new()
	iv.add_theme_constant_override("separation", 2)
	info.add_child(iv)
	_name = UITheme.label("", 16, UITheme.GREEN_HI, true)
	iv.add_child(_name)
	_desc = UITheme.label("", 13, UITheme.GREEN)
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	iv.add_child(_desc)
	_info = UITheme.label("", 12, UITheme.GREEN_DIM)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	iv.add_child(_info)
	var bv := VBoxContainer.new()
	bv.custom_minimum_size = Vector2(220, 0)
	bv.add_theme_constant_override("separation", 6)
	bar.add_child(bv)
	_go = UITheme.key("Идти  [Enter]", "primary", 13)
	_go.pressed.connect(func(): go_node(sel))
	bv.add_child(_go)
	var stop := UITheme.key("Стоп  [ПКМ]", "normal", 13)
	stop.pressed.connect(halt)
	bv.add_child(stop)
	_back = UITheme.key("Вернуться  [Esc]", "warn", 13)
	_back.pressed.connect(close)
	bv.add_child(_back)
	visible = false


## Масштаб и сдвиг картинки: при zoom 1 карта целиком, дальше — крупнее, герой в центре
func _layout() -> void:
	if _view == null or _view.size.x < 2.0:
		return
	var base := minf(_view.size.x / img_size.x, _view.size.y / img_size.y)
	var k := base * zoom
	var sz := img_size * k
	_tex.size = sz
	var p := _view.size * 0.5 - pos * k
	for i in 2:
		if sz[i] <= _view.size[i]:
			p[i] = (_view.size[i] - sz[i]) * 0.5
		else:
			p[i] = clampf(p[i], _view.size[i] - sz[i], 0.0)
	_tex.position = p


func set_zoom(z: float) -> void:
	zoom = clampf(z, ZOOM_MIN, ZOOM_MAX)
	_layout()
	_canvas.queue_redraw()


# ---------------- данные ----------------
func nodes() -> Dictionary:
	return data.get("nodes", {})


func node_pos(id: String) -> Vector2:
	var p: Array = nodes().get(id, {}).get("pos", [0, 0])
	return Vector2(float(p[0]), float(p[1]))


func known(id: String) -> bool:
	var kn: Dictionary = Game.hero.flags.get("map_known", {})
	return nodes().get(id, {}).get("known", false) or kn.has(id)


## Отметить точку на карте (слух, записка, разговор)
static func reveal(id: String) -> void:
	var kn: Dictionary = Game.hero.flags.get("map_known", {})
	if kn.has(id):
		return
	var all: Dictionary = DB._load("res://data/world.json").get("nodes", {})
	if not all.has(id):
		return
	kn[id] = true
	Game.hero.flags["map_known"] = kn
	Game.log_line("Новая точка на карте: " + str(all[id].get("name", id)), "", "hit")


## Можно ли войти: точка известна и открыта
func can_go(id: String) -> bool:
	var n: Dictionary = nodes().get(id, {})
	if n.is_empty() or not known(id):
		return false
	if n.has("end"):
		# в Сунгар через болота не дойти, пока не узнаешь дорогу
		return Game.quest_stage("bootur") >= 5
	return n.has("loc") and not n.get("burned", false)


## Часы игры (общие с локациями)
func hours() -> float:
	return Clock.hours()


func time_text() -> String:
	return Clock.text()


func hours_to(p: Vector2) -> float:
	return pos.distance_to(p) / 100.0 * float(data.get("hours_per_100px", 2.5))


# ---------------- открыть / закрыть ----------------
## from_id — точка, откуда вышли; "" или неизвестная (встреча) — с того места, где стояли
func open(from_id: String) -> void:
	if nodes().has(from_id):
		at = from_id
		pos = node_pos(from_id)
	else:
		at = ""
		var wp = Game.hero.flags.get("wm_pos", null)
		pos = Vector2(float(wp[0]), float(wp[1])) if wp is Array and wp.size() == 2 else node_pos("nakharro")
	_start = pos
	target = pos
	moving = false
	_paused = false
	_entering = false
	_enter_on_arrive = ""
	_trail.clear()
	sel = at if at != "" else ""
	_save_pos()
	_reveal_near()
	visible = true
	_layout()
	_refresh()


## Вернуться в локацию, откуда вышли (если ещё не ушёл с места)
func close() -> void:
	if not visible or not _back.visible:
		return
	visible = false
	closed.emit()


func _can_back() -> bool:
	return at != "" and pos.distance_to(_start) < 1.0 and main.location != null \
		and main.location.location_id == at and not nodes().get(at, {}).get("burned", false)


# ---------------- движение ----------------
## Идти в точку и войти в неё
func go_node(id: String) -> void:
	if not can_go(id):
		return
	sel = id
	_enter_on_arrive = id
	_go_to(node_pos(id))


## Дойти до точки и войти (для сюжета и автотеста): ждёт, пока локация загрузится
func travel(id: String) -> void:
	if not can_go(id):
		return
	go_node(id)
	if pos.distance_to(target) < NEAR:
		_arrive()
	await arrived


func _go_to(p: Vector2) -> void:
	target = Vector2(clampf(p.x, 4, img_size.x - 4), clampf(p.y, 4, img_size.y - 4))
	moving = true
	_paused = false
	at = ""
	_refresh()


func halt() -> void:
	moving = false
	_enter_on_arrive = ""
	_refresh()


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	if moving and not _paused and not _entering and not main.dialog.visible:
		var step := SPEED * delta
		var d := pos.distance_to(target)
		if step >= d:
			step = d
		pos = pos.move_toward(target, step)
		Clock.advance(step / 100.0 * float(data.get("hours_per_100px", 2.5)))
		if _trail.is_empty() or (_trail[-1] as Vector2).distance_to(pos) > 9.0:
			_trail.append(pos)
			if _trail.size() > 300:
				_trail.pop_front()
		_reveal_near()
		_acc += step
		if _acc >= 100.0:
			_acc -= 100.0
			if _roll_encounter():
				_save_pos()
				_canvas.queue_redraw()
				return
		if pos.distance_to(target) < 0.5:
			_arrive()
		_save_pos()
		_refresh_time()
		_layout()
	_canvas.queue_redraw()


func _save_pos() -> void:
	Game.hero.flags["wm_pos"] = [snappedf(pos.x, 0.1), snappedf(pos.y, 0.1)]


func _arrive() -> void:
	moving = false
	at = ""
	for id in nodes():
		if known(id) and pos.distance_to(node_pos(id)) < NEAR:
			at = id
			break
	var e := _enter_on_arrive
	_enter_on_arrive = ""
	if e != "" and e == at:
		enter(e)
	else:
		_refresh()


func _reveal_near() -> void:
	for id in nodes():
		var n: Dictionary = nodes()[id]
		if not known(id) and pos.distance_to(node_pos(id)) < float(n.get("radius", REVEAL_R)):
			reveal(id)
			sel = id
			_refresh()


## Войти в точку: локация или экран конца сборки
func enter(id: String) -> void:
	var n: Dictionary = nodes().get(id, {})
	if not can_go(id) or _entering:
		return
	_entering = true
	Game.log_line("На месте: %s. %s" % [n.get("name", id), time_text().to_lower()])
	if n.has("end"):
		visible = false
		_entering = false
		main.show_end(str(n.end))
		closed.emit()
		arrived.emit()
		return
	visible = false
	Game.set_flag("visited_" + id)
	Game.hero.flags["map_at"] = id
	Game.hero.pos = []
	await main.load_location(str(n.loc), str(n.get("spawn", "Start")))
	main.autosave()
	_entering = false
	closed.emit()
	arrived.emit()


# ---------------- встречи ----------------
## Каждые 100 пикселей пути — шанс встречи. Первый переход до Крестов — без встреч.
## Враги: проверка Внимательности. Провал — засада, бой сразу (враги ходят первыми).
## Успех — заметил их первым: разговор-развилка (ударить первым / подкрасться /
## спрятаться и переждать / обойти).
func _roll_encounter() -> bool:
	if not encounters_on or not Game.flag("visited_kresty"):
		return false
	if randf() > float(data.get("encounter_chance", 0.2)):
		return false
	var id := pick_encounter()
	if id == "":
		return false
	_roll_encounter_with(id)
	return true


## Встреча началась: враги — сперва проверка, заметил ли герой их первым
func _roll_encounter_with(id: String) -> void:
	var e: Dictionary = data.get("encounters", {}).get(id, {})
	if not e.get("enemies", []).is_empty() and not e.get("always_notice", false):
		if not Game.skill_check("Внимательность", "PRC", "Внимательность", int(e.get("notice_dc", 12))):
			_mark_seen(id)
			Game.log_line("Засада! " + str(e.get("desc", "")), "", "miss")
			start_encounter(id, "caught")
			return
	start_road_event(id)


## Тип местности под точкой карты: сначала зоны из world.json (кратеры — мёртвый лес,
## болота), потом цвет самой картинки (синеватое — болото, бурое — поле, тёмное — лес)
var _img: Image = null


func biome_at(p: Vector2) -> String:
	for z in data.get("zones", []):
		var zp: Array = z.get("pos", [0, 0])
		if p.distance_to(Vector2(float(zp[0]), float(zp[1]))) < float(z.get("r", 50)):
			return str(z.get("type", "forest"))
	if _img == null and _tex.texture:
		_img = _tex.texture.get_image()
		if _img and _img.is_compressed():
			_img.decompress()
	var b := "forest"
	if _img:
		var q := Vector2i(clampi(int(p.x / img_size.x * _img.get_width()), 0, _img.get_width() - 1),
			clampi(int(p.y / img_size.y * _img.get_height()), 0, _img.get_height() - 1))
		var c := Color(0, 0, 0)
		var n := 0
		for dx in range(-6, 7, 3):
			for dy in range(-6, 7, 3):
				var qq := Vector2i(clampi(q.x + dx, 0, _img.get_width() - 1), clampi(q.y + dy, 0, _img.get_height() - 1))
				c += _img.get_pixelv(qq)
				n += 1
		c /= float(n)
		if c.b > c.r * 0.82 and c.b > c.g * 0.82:
			b = "swamp"
		elif c.r > c.g * 1.12:
			b = "field"
	# немного случайности: тайга пёстрая
	if randf() < 0.2:
		b = ["field", "forest", "swamp", "dead"][randi() % 4] if randf() < 0.3 else ("field" if b == "forest" else "forest")
	return b


func pick_encounter() -> String:
	var seen: Array = Game.hero.flags.get("road_seen", [])
	var pool := []
	var weights := {}
	var total := 0.0
	var encs: Dictionary = data.get("encounters", {})
	var here := biome_at(pos)
	for id in encs:
		var e: Dictionary = encs[id]
		if (e.get("text", false) or e.get("once", false)) and seen.has(id):
			continue
		if e.has("biomes") and not here in e.biomes and e.get("only_biomes", false):
			continue
		if e.has("flag") and not Game.flag(str(e.flag)):
			continue
		if e.has("not_flag") and Game.flag(str(e.not_flag)):
			continue
		if int(Game.hero.level) < int(e.get("min_level", 0)):
			continue
		match str(e.get("cond", "")):
			"who2":
				if Game.quest_stage("who") < 2:
					continue
			"kpk":
				if not Game.flag("kpk"):
					continue
		var w := float(e.get("weight", 1))
		if e.has("biomes") and here in e.biomes:
			w *= 2.5
		pool.append(id)
		weights[id] = w
		total += w
	var r := randf() * total
	for id in pool:
		r -= float(weights[id])
		if r <= 0.0:
			return id
	return pool[-1] if not pool.is_empty() else ""


## Начать встречу: разговор-развилка из road.json, дальше — действие enc_*
func _mark_seen(id: String) -> void:
	var seen: Array = Game.hero.flags.get("road_seen", [])
	if not seen.has(id):
		seen.append(id)
	Game.hero.flags["road_seen"] = seen


func start_road_event(id: String) -> void:
	_paused = true
	Game.hero.flags["enc"] = id
	_mark_seen(id)
	main.dialog.open("road", id, null)
	if not main.dialog.closed.is_connected(_on_dialog_closed):
		main.dialog.closed.connect(_on_dialog_closed)


func _on_dialog_closed() -> void:
	if visible and _paused and not _entering:
		_paused = false


## Действия из road.json:
##   enc_fight — бой (обычная инициатива), enc_first — ударить первым, enc_caught — заметили,
##   враги ходят первыми, enc_sneak — подкрасться (герой в кустах у края), enc_go — мирная
##   встреча, enc_skip — идти дальше
func on_action(a: String) -> void:
	var id := str(Game.hero.flags.get("enc", "dogs"))
	match a:
		"enc_fight":
			start_encounter(id, "fight")
		"enc_first":
			start_encounter(id, "first")
		"enc_caught":
			start_encounter(id, "caught")
		"enc_sneak":
			start_encounter(id, "sneak")
		"enc_go":
			start_encounter(id, "peace")
		"enc_skip":
			_paused = false


func start_encounter(id: String, mode := "fight") -> void:
	Game.hero.flags["enc_mode"] = mode
	Game.hero.flags["enc_biome"] = biome_at(pos)
	_entering = true
	moving = false
	_enter_on_arrive = ""
	_save_pos()
	Game.hero.flags["enc"] = id
	Game.hero.pos = []
	visible = false
	main.dialog.close()
	await main.load_location("encounter", "Start")
	_entering = false
	closed.emit()
	arrived.emit()


# ---------------- интерфейс ----------------
func select(id: String) -> void:
	if not known(id):
		return
	sel = id
	_refresh()


func _refresh_time() -> void:
	_time.text = time_text()


func _refresh() -> void:
	_refresh_time()
	_back.visible = _can_back()
	var n: Dictionary = nodes().get(sel, {})
	if sel == "" or n.is_empty():
		_name.text = "ТАЙГА" if at == "" else ""
		_desc.text = "Кликни по карте — пойдёшь туда. Кликни по отметке — узнаешь, что там. Колесо мыши или +/− — приблизить / отдалить."
		_info.text = "В пути. До цели около %.0f ч." % hours_to(target) if moving else ""
		_go.disabled = true
		return
	_name.text = str(n.get("name", sel)).to_upper()
	_desc.text = str(n.get("desc", ""))
	if sel == at and pos.distance_to(node_pos(sel)) < NEAR:
		_info.text = "Ты здесь." + ("" if can_go(sel) else " " + str(n.get("locked", "")))
	elif can_go(sel):
		_info.text = "Дорога: около %.0f ч пешком." % maxf(1.0, hours_to(node_pos(sel)))
		if Game.flag("visited_" + sel):
			_info.text += " Уже бывал."
	else:
		_info.text = str(n.get("locked", "Туда пока не дойти."))
	_go.disabled = not can_go(sel) or (_enter_on_arrive == sel and moving)
	_go.text = "Войти  [Enter]" if sel == at else "Идти  [Enter]"


func _to_px(p: Vector2) -> Vector2:
	return p / img_size * _canvas.size


func _from_px(p: Vector2) -> Vector2:
	return p / _canvas.size * img_size


func _text(c: Control, p: Vector2, s: String, size: int, col: Color) -> void:
	var f := UITheme.mono()
	c.draw_string(f, p + Vector2(1, 1), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0, 0, 0, 0.85))
	c.draw_string(f, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func _draw_map() -> void:
	var c := _canvas
	# след: красные точки, как в Fallout
	for q in _trail:
		c.draw_circle(_to_px(q), 2.2, Color("c0392b"))
	if moving:
		c.draw_dashed_line(_to_px(pos), _to_px(target), Color(UITheme.AMBER, 0.8), 1.5, 6.0)
		c.draw_arc(_to_px(target), 6.0, 0, TAU, 16, UITheme.AMBER, 1.5)
	for id in nodes():
		if not known(id):
			continue
		var n: Dictionary = nodes()[id]
		var p := _to_px(node_pos(id))
		var open_ := can_go(id)
		var col := UITheme.AMBER if open_ else Color("c9b48a")
		if n.get("burned", false):
			col = UITheme.RED
			c.draw_line(p + Vector2(-7, -7), p + Vector2(7, 7), col, 3.0)
			c.draw_line(p + Vector2(-7, 7), p + Vector2(7, -7), col, 3.0)
		else:
			c.draw_circle(p, 8.0, Color(0, 0, 0, 0.6))
			c.draw_circle(p, 6.0, col)
			if not Game.flag("visited_" + id):
				c.draw_circle(p, 2.5, Color(0, 0, 0, 0.8))
		if id == sel:
			c.draw_arc(p, 13.0, 0, TAU, 32, UITheme.GREEN_HI, 2.0)
		_text(c, p + Vector2(11, -9), str(n.get("name", id)), 14, col)
	# герой
	var hp := _to_px(pos)
	var r := 9.0 + sin(_t * 5.0) * 2.0
	c.draw_arc(hp, r, 0, TAU, 24, UITheme.GREEN_HI, 2.0)
	c.draw_circle(hp, 4.0, UITheme.GREEN_HI)
	# координаты под курсором — чтобы расставлять точки в world.json
	if _hover.x >= 0:
		var ip := _from_px(_hover)
		# в углу видимой части окна, а не всей (увеличенной) картинки
		_text(c, -_tex.position + Vector2(10, _view.size.y - 10), "X %d · Y %d" % [roundi(ip.x), roundi(ip.y)], 12, Color("e8dcc0"))


func _node_at(local: Vector2) -> String:
	var best := ""
	var bd := 16.0
	for id in nodes():
		if not known(id):
			continue
		var d: float = _to_px(node_pos(id)).distance_to(local)
		if d < bd:
			bd = d
			best = id
	return best


func _on_canvas_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion:
		_hover = e.position
		return
	if not (e is InputEventMouseButton) or not e.pressed:
		return
	if e.button_index == MOUSE_BUTTON_WHEEL_UP:
		set_zoom(zoom * 1.15)
		return
	if e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		set_zoom(zoom / 1.15)
		return
	if _entering or main.dialog.visible:
		return
	if e.button_index == MOUSE_BUTTON_RIGHT:
		halt()
		return
	if e.button_index != MOUSE_BUTTON_LEFT:
		return
	var id := _node_at(e.position)
	if id != "":
		if e.double_click or (id == sel and id == at):
			if id == at and pos.distance_to(node_pos(id)) < NEAR:
				enter(id)
			else:
				go_node(id)
		else:
			select(id)
		return
	# пустое место — идти туда
	sel = ""
	_enter_on_arrive = ""
	_go_to(_from_px(e.position))


func _unhandled_key_input(e: InputEvent) -> void:
	if not visible or not (e is InputEventKey) or not e.pressed or e.echo or main.dialog.visible:
		return
	if e.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()
	elif e.keycode == KEY_ENTER or e.keycode == KEY_KP_ENTER:
		if sel != "" and sel == at and pos.distance_to(node_pos(sel)) < NEAR:
			enter(sel)
		else:
			go_node(sel)
		get_viewport().set_input_as_handled()
	elif e.keycode == KEY_SPACE:
		halt()
		get_viewport().set_input_as_handled()
	elif e.keycode in [KEY_EQUAL, KEY_PLUS, KEY_KP_ADD]:
		set_zoom(zoom * 1.25)
		get_viewport().set_input_as_handled()
	elif e.keycode in [KEY_MINUS, KEY_KP_SUBTRACT]:
		set_zoom(zoom / 1.25)
		get_viewport().set_input_as_handled()
