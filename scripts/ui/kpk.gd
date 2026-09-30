class_name KPK
extends Control
## Карманный компьютер на браслете. Пока браслета нет — просто «Сумка».
## С браслетом — полный КПК: инвентарь, «Дело» (лист персонажа), карта, задания, записи.

signal closed
signal use_item(id: String)

var main: Node
var tab := "inv"
var _sel := ""
var _screen: VBoxContainer
var _tabs: VBoxContainer
var _title: Label
var _brand: Label
var _map: Control


func setup(m: Node) -> void:
	main = m
	UITheme.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.02, 0.01, 0.45)
	UITheme.full_rect(dim)
	dim.gui_input.connect(func(e): if e is InputEventMouseButton and e.pressed: close())
	add_child(dim)
	var body := UITheme.panel(UITheme.plastic(10))
	body.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	body.offset_left = -460
	body.offset_right = 460
	body.offset_top = -330
	body.offset_bottom = 250
	add_child(body)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	body.add_child(v)
	var top := HBoxContainer.new()
	v.add_child(top)
	_brand = UITheme.label("CT14 inc.", 13, UITheme.INK_2, true)
	top.add_child(_brand)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(sp)
	var x := UITheme.key("Закрыть [Esc]", "warn", 11)
	x.pressed.connect(close)
	top.add_child(x)
	v.add_child(UITheme.stripe(5))
	var hb := HBoxContainer.new()
	hb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hb.add_theme_constant_override("separation", 12)
	v.add_child(hb)
	_tabs = VBoxContainer.new()
	_tabs.custom_minimum_size = Vector2(130, 0)
	_tabs.add_theme_constant_override("separation", 6)
	hb.add_child(_tabs)
	var scr := UITheme.panel(UITheme.screen(true, 14))
	scr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(scr)
	var sv := VBoxContainer.new()
	scr.add_child(sv)
	_title = UITheme.label("", 12, UITheme.GREEN_DIM, true)
	sv.add_child(_title)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sv.add_child(scroll)
	_screen = VBoxContainer.new()
	_screen.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_screen.add_theme_constant_override("separation", 4)
	scroll.add_child(_screen)
	visible = false
	Game.hero_changed.connect(func(): if visible: render())


func open(t := "") -> void:
	if t != "":
		tab = t
	visible = true
	render()


func close() -> void:
	visible = false
	closed.emit()


func has_tab(t: String) -> bool:
	if Game.flag("kpk"):
		return t in ["inv", "stat", "cas", "map", "quests", "notes"]
	return t in ["inv", "quests"]


func render() -> void:
	var kpk := Game.flag("kpk")
	_brand.text = "CT14 INC. · КПК НА БРАСЛЕТЕ" if kpk else "СУМКА"
	for c in _tabs.get_children():
		c.queue_free()
	var names := {"inv": "Инвентарь", "stat": "Дело", "cas": "Кассеты", "map": "Карта", "quests": "Задания", "notes": "Записи"}
	if not has_tab(tab):
		tab = "inv" if has_tab("inv") else ("stat" if has_tab("stat") else "quests")
	for t in ["inv", "stat", "cas", "map", "quests", "notes"]:
		if not has_tab(t):
			continue
		var b := UITheme.key(names[t], "sel" if t == tab else "normal", 12)
		b.pressed.connect(func():
			tab = t
			render())
		_tabs.add_child(b)
	for c in _screen.get_children():
		c.queue_free()
	_title.text = names[tab].to_upper()
	match tab:
		"inv":
			_render_inv()
		"stat":
			_render_stat()
		"cas":
			_render_cas()
		"map":
			_render_map()
		"quests":
			_render_quests()
		"notes":
			_render_notes()


func _g(text: String, size := 14, col := UITheme.GREEN) -> Label:
	var l := UITheme.label(text, size, col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _item_btn(text: String, key: String) -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", UITheme.mono())
	b.add_theme_font_size_override("font_size", 14)
	var e := StyleBoxEmpty.new()
	e.set_content_margin_all(3)
	var s := StyleBoxFlat.new()
	s.bg_color = UITheme.GREEN if key == _sel else Color(UITheme.GREEN, 0.12)
	s.set_content_margin_all(3)
	b.add_theme_stylebox_override("normal", s if key == _sel else e)
	b.add_theme_stylebox_override("hover", s)
	b.add_theme_stylebox_override("pressed", s)
	var fc := UITheme.GREEN_BG if key == _sel else UITheme.GREEN
	b.add_theme_color_override("font_color", fc)
	b.add_theme_color_override("font_hover_color", fc if key == _sel else UITheme.GREEN_HI)
	b.pressed.connect(func():
		_sel = key
		render())
	return b


func _render_inv() -> void:
	var h := Game.hero
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 18)
	_screen.add_child(cols)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(left)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = 1.2
	cols.add_child(right)
	left.add_child(_g("ОРУЖИЕ", 11, UITheme.GREEN_DIM))
	var any := false
	for k in h.owned:
		var hand := ""
		if h.hands[0] == k:
			hand = " [П]"
		elif h.hands[1] == k:
			hand = " [Л]"
		left.add_child(_item_btn(DB.item_name(k) + hand, k))
		any = true
	if not any:
		left.add_child(_g("— только кулаки", 13, UITheme.GREEN_DIM))
	left.add_child(_g("ПАТРОНЫ", 11, UITheme.GREEN_DIM))
	left.add_child(_g("9 мм: %d   ·   7,62: %d" % [int(h.ammo.get("9мм", 0)), int(h.ammo.get("7.62", 0))], 13))
	left.add_child(_g("ВЕЩИ", 11, UITheme.GREEN_DIM))
	if h.items.is_empty():
		left.add_child(_g("— пусто", 13, UITheme.GREEN_DIM))
	for k in h.items:
		left.add_child(_item_btn("%s ×%d" % [DB.item_name(k), int(h.items[k])], k))
	# карточка
	if _sel == "" or (not h.owned.has(_sel) and not h.items.has(_sel)):
		right.add_child(_g("Выбери предмет слева.", 13, UITheme.GREEN_DIM))
		return
	right.add_child(_g(DB.item_name(_sel), 17, UITheme.GREEN_HI))
	if DB.weapons.has(_sel):
		var w := DB.weapon(_sel)
		var rows := [
			["Тип", Rules.WEAPON_SKILL.get(w.type, w.type)],
			["Урон", "%s%s %s" % [w.dmg, ("+%d" % int(w.bonus)) if int(w.get("bonus", 0)) else "", Rules.DMG_TYPE_NAMES.get(w.dmg_type, "")]],
			["ОД на удар", str(w.ap)],
			["Дальность", "вплотную" if int(w.range) <= 1 else "%d гекс. (без штрафа до %d)" % [int(w.range), int(w.get("eff_range", 6))]],
		]
		if DB.is_gun(_sel):
			rows.append(["Магазин", "%d/%d · %s" % [int(h.mag.get(_sel, 0)), int(w.mag), w.ammo]])
		if w.has("burst"):
			rows.append(["Очередь", "×%d, %d ОД, −%d к попаданию" % [int(w.burst.n), int(w.burst.ap), int(w.burst.pen)]])
		var sk: String = Rules.WEAPON_SKILL[w.type]
		rows.append(["Навык", "%s %d" % [sk, int(h.skills.get(sk, 0))]])
		for r in rows:
			right.add_child(_g("%s: %s" % r, 13))
		if w.has("desc"):
			right.add_child(_g(w.desc, 12, UITheme.GREEN_DIM))
		var bb := HBoxContainer.new()
		right.add_child(bb)
		var b1 := UITheme.key("В правую руку", "normal", 11)
		b1.pressed.connect(func(): _equip(0))
		bb.add_child(b1)
		var b2 := UITheme.key("В левую руку", "normal", 11)
		b2.pressed.connect(func(): _equip(1))
		bb.add_child(b2)
	else:
		var it: Dictionary = DB.items.get(_sel, {})
		right.add_child(_g(it.get("desc", ""), 13))
		if it.has("heal"):
			right.add_child(_g("Лечит · %d ОД в бою" % int(it.get("ap", 2)), 13))
			var b := UITheme.key("Использовать", "primary", 11)
			b.pressed.connect(func(): use_item.emit(_sel))
			right.add_child(b)


func _equip(hand: int) -> void:
	if main.combat.on and not main.combat.my_turn():
		return
	var h := Game.hero
	var other := 1 - hand
	if h.hands[other] == _sel:
		h.hands[other] = h.hands[hand]
	h.hands[hand] = _sel
	h.active = hand
	main.player.set_held(Game.hero_wkey())
	Game.hero_changed.emit()


func _render_stat() -> void:
	var h := Game.hero
	_screen.add_child(_g("%s · уровень %d" % [h.name, h.level], 17, UITheme.GREEN_HI))
	var pts := int(h.stat_pts) + int(h.skill_pts)
	var eb := UITheme.key("Распределить очки: %d" % pts if pts > 0 else "Характеристики и навыки", "primary" if pts > 0 else "normal", 11)
	eb.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	eb.pressed.connect(_open_sheet)
	_screen.add_child(eb)
	_screen.add_child(_g("ХП %d/%d · опыт %d/%d" % [Game.hero_hp(), Game.hero_max(), h.xp, Rules.xp_for_level(int(h.level) + 1)], 14))
	var pb := ProgressBar.new()
	pb.max_value = Rules.xp_for_level(int(h.level) + 1) - Rules.xp_for_level(int(h.level))
	pb.value = int(h.xp) - Rules.xp_for_level(int(h.level))
	pb.show_percentage = false
	pb.custom_minimum_size = Vector2(0, 8)
	var f := StyleBoxFlat.new()
	f.bg_color = UITheme.GREEN
	var b := StyleBoxFlat.new()
	b.bg_color = Color(UITheme.GREEN, 0.15)
	pb.add_theme_stylebox_override("fill", f)
	pb.add_theme_stylebox_override("background", b)
	_screen.add_child(pb)
	var g := GridContainer.new()
	g.columns = 3
	g.add_theme_constant_override("h_separation", 10)
	g.add_theme_constant_override("v_separation", 8)
	_screen.add_child(g)
	for s in Rules.STATS:
		var p := UITheme.panel(UITheme.screen(true, 6))
		p.custom_minimum_size = Vector2(120, 0)
		var vb := VBoxContainer.new()
		p.add_child(vb)
		var l1 := _g(s.full, 11, UITheme.GREEN_DIM)
		l1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(l1)
		var l2 := UITheme.label(str(Game.hero_stat(s.key)), 22, UITheme.GREEN_HI, true)
		p.tooltip_text = s.hint
		l2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(l2)
		g.add_child(p)
	var ap := Rules.ap_for(Game.effective_stats(), Game.hero_hp(), Game.hero_max())
	_screen.add_child(_g("ОД в бою: %d" % ap, 13))
	_screen.add_child(_g("Молва: %+d — %s" % [Game.rep(), Rules.rep_label(Game.rep())], 13))
	var top := []
	for k in h.skills:
		if int(h.skills[k]) > 0:
			top.append([k, int(h.skills[k])])
	top.sort_custom(func(a, bb): return a[1] > bb[1])
	var txt := []
	for x in top:
		txt.append("%s %d" % [x[0], x[1]])
	_screen.add_child(_g("Навыки: " + (", ".join(txt) if not txt.is_empty() else "нет"), 13))


## Полный лист персонажа поверх КПК; после закрытия — обратно в «Дело»
func _open_sheet() -> void:
	if main.combat.on:
		return
	close()
	main.sheet.closed.connect(func(): open("stat"), CONNECT_ONE_SHOT)
	main.sheet.open()


## Кассеты: 10 слотов КПК; рабочих — сколько принял браслет Эллэя (2 + уровень − 1)
func _render_cas() -> void:
	var work := Game.cas_working()
	var c: Array = Game.hero.get("cassettes", [])
	_screen.add_child(_g("Браслет принял слотов: %d из %d. Кассета грузится из КПК в браслет и меняет тебя самого." % [work, Game.CAS_SLOTS], 12, UITheme.GREEN_DIM))
	var in_fight: bool = main.combat.on
	for i in Game.CAS_SLOTS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		_screen.add_child(row)
		var locked := i >= work
		var txt := "%2d · " % (i + 1)
		if i < c.size():
			txt += DB.item_name(c[i]) + ("   [память закрыта]" if locked else "")
		else:
			txt += "ЗАБЛОКИРОВАНО" if locked else "— пусто —"
		var l := _g(txt, 14, UITheme.GREEN_DIM if locked else UITheme.GREEN)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if i < c.size():
			l.tooltip_text = str(DB.items.get(c[i], {}).get("desc", ""))
			l.mouse_filter = Control.MOUSE_FILTER_PASS
		row.add_child(l)
		if i < c.size():
			var b := UITheme.key("Вынуть", "normal", 11)
			b.disabled = in_fight
			var idx := i
			b.pressed.connect(func(): Game.cas_eject(idx))
			row.add_child(b)
	var spare := []
	for k in Game.hero.items:
		if Game.is_cassette(k):
			spare.append(k)
	_screen.add_child(_g("В СУМКЕ", 11, UITheme.GREEN_DIM))
	if spare.is_empty():
		_screen.add_child(_g("— кассет нет. Их находят, получают за дела, покупают.", 13, UITheme.GREEN_DIM))
	for k in spare:
		var row2 := HBoxContainer.new()
		_screen.add_child(row2)
		var l2 := _g("%s — %s" % [DB.item_name(k), DB.items[k].get("desc", "")], 13)
		l2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row2.add_child(l2)
		var b2 := UITheme.key("Вставить", "primary", 11)
		b2.disabled = in_fight or c.size() >= Game.CAS_SLOTS
		var key: String = k
		b2.pressed.connect(func(): Game.cas_insert(key))
		row2.add_child(b2)
	if in_fight:
		_screen.add_child(_g("В бою кассеты не меняют.", 12, UITheme.GREEN_DIM))


func _render_map() -> void:
	var loc: Location = main.location
	_screen.add_child(_g(loc.title, 15, UITheme.GREEN_HI))
	_map = MapView.new()
	_map.custom_minimum_size = Vector2(520, 380)
	_map.main = main
	_screen.add_child(_map)
	_screen.add_child(_g("Жёлтый квадрат — ты, точки — люди (красные — враги), ромбы — отметки", 12, UITheme.GREEN_DIM))


func _render_quests() -> void:
	var any := false
	for id in Game.hero.q:
		var st := int(Game.hero.q[id])
		var q: Dictionary = DB.quests.get(id, {})
		if q.is_empty() or st <= 0:
			continue
		any = true
		var done := st >= int(q.get("done_stage", 999))
		_screen.add_child(_g(("[x] " if done else "> ") + q.get("title", id), 15, UITheme.GREEN_DIM if done else UITheme.GREEN_HI))
		var txt: String = q.get("stages", {}).get(str(st), "")
		if txt != "":
			_screen.add_child(_g("   " + txt, 13, UITheme.GREEN_DIM if done else UITheme.GREEN))
	if not any:
		_screen.add_child(_g("Заданий нет.", 13, UITheme.GREEN_DIM))


func _render_notes() -> void:
	if Game.hero.notes.is_empty():
		_screen.add_child(_g("Лента пуста.", 13, UITheme.GREEN_DIM))
	for n in Game.hero.notes:
		var p := UITheme.panel(UITheme.screen(true, 8))
		p.add_child(_g(n, 13))
		_screen.add_child(p)


func _unhandled_key_input(e: InputEvent) -> void:
	if visible and e is InputEventKey and e.pressed and not e.echo and (e.keycode == KEY_ESCAPE or e.keycode == KEY_I):
		close()
		get_viewport().set_input_as_handled()
