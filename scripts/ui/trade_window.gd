class_name TradeWindow
extends Control
## Бартер: денег в первом акте нет, меняют вещь на вещь.
## Слева — твоё, справа — у торговца. Клик по строке кладёт одну штуку на обмен,
## клик по строке в «На обмен» — убирает. Торговец свои вещи ценит выше,
## твои — ниже (см. Rules.trade_mults: Характер, Торг, молва). Сдачи нет.

signal closed

## Памятные вещи — не на обмен
const KEEP := ["father_pistol", "oyun", "fists"]

var main: Node
var _title: Label
var _rate: Label
var _mine_l: VBoxContainer
var _theirs_l: VBoxContainer
var _give_l: VBoxContainer
var _take_l: VBoxContainer
var _sum: Label
var _ok: Button
var _stock: Dictionary = {}
var _give: Dictionary = {}
var _take: Dictionary = {}
var _mult := Vector2(1.3, 0.7)
var _on_done := Callable()


func setup(m: Node) -> void:
	main = m
	UITheme.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.02, 0.01, 0.45)
	UITheme.full_rect(dim)
	add_child(dim)
	var body := UITheme.panel(UITheme.plastic(10))
	body.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	body.offset_left = -460
	body.offset_right = 460
	body.offset_top = -300
	body.offset_bottom = 290
	add_child(body)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	body.add_child(v)
	_title = UITheme.label("", 15, UITheme.INK_2, true)
	v.add_child(_title)
	_rate = UITheme.label("", 12, UITheme.INK)
	v.add_child(_rate)
	v.add_child(UITheme.stripe(5))
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 10)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(cols)
	var left := _column(cols, "ТВОЁ")
	_mine_l = left[0]
	_give_l = left[1]
	var right := _column(cols, "У ТОРГОВЦА")
	_theirs_l = right[0]
	_take_l = right[1]
	_sum = UITheme.label("", 14, UITheme.INK_2)
	_sum.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_sum)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	v.add_child(row)
	_ok = UITheme.key("Обменять  [E]", "primary", 12)
	_ok.pressed.connect(exchange)
	row.add_child(_ok)
	var clr := UITheme.key("Сбросить", "normal", 12)
	clr.pressed.connect(func():
		_give.clear()
		_take.clear()
		_render())
	row.add_child(clr)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(sp)
	var x := UITheme.key("Закрыть  [Esc]", "warn", 12)
	x.pressed.connect(close)
	row.add_child(x)
	visible = false


## Колонка: список вещей сверху, «На обмен» снизу
func _column(parent: Node, head: String) -> Array:
	var c := VBoxContainer.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.add_theme_constant_override("separation", 6)
	parent.add_child(c)
	c.add_child(UITheme.label(head, 12, UITheme.INK, true))
	var lists := []
	for i in 2:
		if i == 1:
			c.add_child(UITheme.label("НА ОБМЕН", 12, UITheme.INK, true))
		var scr := UITheme.panel(UITheme.screen(true, 8))
		scr.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scr.size_flags_stretch_ratio = 2.0 if i == 0 else 1.0
		c.add_child(scr)
		var sc := ScrollContainer.new()
		sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scr.add_child(sc)
		var l := VBoxContainer.new()
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.add_theme_constant_override("separation", 2)
		sc.add_child(l)
		lists.append(l)
	return lists


## stock — {ключ: сколько} у торговца; on_done(новый запас) — когда окно закрыто
func open(title: String, stock: Dictionary, on_done := Callable()) -> void:
	_title.text = ("Обмен · " + title).to_upper()
	_stock = stock.duplicate()
	_give.clear()
	_take.clear()
	_on_done = on_done
	_mult = Rules.trade_mults(Game.hero_stat("CHA"), int(Game.effective_skills().get("Торг", 0)), Game.rep())
	_rate.text = "Твоё здесь идёт по %d%% цены, чужое — по %d%%. Цену двигают Характер, Торг и молва. Сдачи нет." % [
		roundi(_mult.y * 100.0), roundi(_mult.x * 100.0)]
	visible = true
	_render()


## Что у героя можно поменять: {ключ: сколько}
func mine() -> Dictionary:
	var out := {}
	for k in Game.hero.items:
		if DB.item_value(k) > 0 and int(Game.hero.items[k]) > 0:
			out[k] = int(Game.hero.items[k])
	for k in ["ammo9", "ammo762"]:
		if Game.item_count(k) > 0:
			out[k] = Game.item_count(k)
	for k in Game.hero.owned:
		if not KEEP.has(k) and DB.item_value(k) > 0:
			out[k] = 1
	return out


func stock() -> Dictionary:
	return _stock


func give_value() -> int:
	return floori(_sum_of(_give) * _mult.y)


func take_value() -> int:
	return ceili(_sum_of(_take) * _mult.x)


func _sum_of(d: Dictionary) -> float:
	var s := 0.0
	for k in d:
		s += DB.item_value(k) * int(d[k])
	return s


## Положить одну штуку на обмен: side = "give" (твоё) или "take" (его)
func offer(id: String, side: String, n := 1) -> void:
	# второе такое же оружие не нужно: в руках и так есть
	if side == "take" and DB.weapons.has(id) and Game.hero.owned.has(id):
		_sum.text = "%s у тебя уже есть." % DB.item_name(id)
		return
	var src: Dictionary = mine() if side == "give" else _stock
	var dst: Dictionary = _give if side == "give" else _take
	var left := int(src.get(id, 0)) - int(dst.get(id, 0))
	n = mini(n, left)
	if n <= 0:
		return
	dst[id] = int(dst.get(id, 0)) + n
	_render()


func withdraw(id: String, side: String) -> void:
	var dst: Dictionary = _give if side == "give" else _take
	if not dst.has(id):
		return
	dst[id] = int(dst[id]) - 1
	if int(dst[id]) <= 0:
		dst.erase(id)
	_render()


func can_exchange() -> bool:
	return not _take.is_empty() and give_value() >= take_value()


func exchange() -> bool:
	if not can_exchange():
		return false
	var gave := []
	var got := []
	for k in _give:
		var n := int(_give[k])
		Game.remove_item(k, n)
		_stock[k] = int(_stock.get(k, 0)) + n
		gave.append(_line(k, n))
	for k in _take:
		var n := int(_take[k])
		Game.add_item(k, n)
		_stock[k] = int(_stock[k]) - n
		if int(_stock[k]) <= 0:
			_stock.erase(k)
		got.append(_line(k, n))
	main.player.set_held(Game.hero_wkey())
	Game.log_line("Обмен: %s" % ", ".join(got), "отдано: " + (", ".join(gave) if gave else "ничего"), "hit")
	main.sfx("pickup", -8.0)
	_give.clear()
	_take.clear()
	_render()
	return true


func _line(k: String, n: int) -> String:
	return DB.item_name(k) + (" ×%d" % n if n > 1 else "")


func _render() -> void:
	var my := mine()
	_fill(_mine_l, my, _give, "give", false)
	_fill(_theirs_l, _stock, _take, "take", false)
	_fill(_give_l, _give, {}, "give", true)
	_fill(_take_l, _take, {}, "take", true)
	var g := give_value()
	var t := take_value()
	var txt := "Отдаёшь на %d · берёшь на %d" % [g, t]
	if _take.is_empty():
		txt += "\nВыбери, что хочешь взять."
	elif g < t:
		txt += "\nНе хватает %d — добавь что-нибудь." % (t - g)
	elif g > t + 2:
		txt += "\nЛишние %d уйдут даром." % (g - t)
	_sum.text = txt
	_ok.disabled = not can_exchange()


func _fill(list: VBoxContainer, src: Dictionary, used: Dictionary, side: String, basket: bool) -> void:
	for c in list.get_children():
		c.queue_free()
	var any := false
	var keys := src.keys()
	keys.sort_custom(func(a, b): return DB.item_name(a) < DB.item_name(b))
	for k in keys:
		var n := int(src[k]) - int(used.get(k, 0))
		if n <= 0:
			continue
		any = true
		var b := Button.new()
		b.text = "%s%s   · %d" % [DB.item_name(k), (" ×%d" % n) if n > 1 else "", DB.item_value(k)]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.focus_mode = Control.FOCUS_NONE
		b.tooltip_text = str(DB.items.get(k, DB.weapons.get(k, {})).get("desc", ""))
		b.add_theme_font_override("font", UITheme.mono())
		b.add_theme_font_size_override("font_size", 13)
		var e := StyleBoxEmpty.new()
		e.set_content_margin_all(3)
		var hv := StyleBoxFlat.new()
		hv.bg_color = Color(UITheme.GREEN, 0.14)
		hv.set_content_margin_all(3)
		b.add_theme_stylebox_override("normal", e)
		b.add_theme_stylebox_override("hover", hv)
		b.add_theme_stylebox_override("pressed", hv)
		b.add_theme_color_override("font_color", UITheme.GREEN)
		b.add_theme_color_override("font_hover_color", UITheme.GREEN_HI)
		var key := str(k)
		if basket:
			b.pressed.connect(func(): withdraw(key, side))
		else:
			b.pressed.connect(func(): offer(key, side))
		list.add_child(b)
	if not any:
		list.add_child(UITheme.label("—", 13, UITheme.GREEN_DIM))


func close() -> void:
	if not visible:
		return
	visible = false
	if _on_done.is_valid():
		_on_done.call(_stock)
	closed.emit()


func _unhandled_key_input(e: InputEvent) -> void:
	if not visible or not (e is InputEventKey) or not e.pressed or e.echo:
		return
	if e.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()
	elif e.keycode == KEY_E:
		exchange()
		get_viewport().set_input_as_handled()
