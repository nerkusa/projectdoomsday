extends Node3D
## Главный узел игры: камера, загрузка локаций, ввод мышью, окна интерфейса.

const LOCATIONS := {
	"nakharro": "res://scenes/locations/nakharro.tscn",
}
const CAM_DIR := Vector3(1, 1, 1)
## Камера ортогональная: расстояние не меняет картинку, но от него зависит
## качество теней (чем дальше, тем грубее каскад теней солнца)
const CAM_DIST := 32.0
## Скорость героя вне боя (м/с) и до какого расстояния он идёт шагом, а не бежит
const WALK_SPEED := 1.8
const RUN_SPEED := 4.2
const SNEAK_SPEED := 1.4
const WALK_MAX_DIST := 5.0

var location: Location
var player: Character
var camera: Camera3D
var cam_target := Vector3.ZERO
var zoom := 19.0
var combat: CombatManager
var overlay: HexOverlay
var ui: CanvasLayer
var hud: HUD
var dialog: DialogBox
var kpk: KPK
var sheet: CharSheet
var menu: GameMenu
var slides: GameMenu.Slides
var attack_mode := false

var _pending: Dictionary = {}
var _aggro_t := 0.0
var _hover: Object = null
var _intro_pending := false
var _loading := false
var _xray: Array = []
var _xray_t := 0.0


func _ready() -> void:
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = zoom
	camera.near = 1.0
	camera.far = 200.0
	add_child(camera)
	overlay = HexOverlay.new()
	add_child(overlay)
	combat = CombatManager.new()
	combat.name = "Combat"
	add_child(combat)
	combat.setup(self)
	_build_ui()
	menu.open("main")


func _build_ui() -> void:
	ui = CanvasLayer.new()
	ui.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(ui)
	var root := Control.new()
	root.theme = UITheme.build_theme()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UITheme.full_rect(root)
	ui.add_child(root)
	hud = HUD.new()
	root.add_child(hud)
	hud.setup(self, combat)
	hud.action.connect(_on_hud_action)
	hud.zone_chosen.connect(combat.zone_picked)
	hud.visible = false
	dialog = DialogBox.new()
	root.add_child(dialog)
	dialog.setup()
	dialog.action.connect(_on_dialog_action)
	dialog.closed.connect(_on_dialog_closed)
	kpk = KPK.new()
	root.add_child(kpk)
	kpk.setup(self)
	kpk.use_item.connect(combat.use_med)
	sheet = CharSheet.new()
	root.add_child(sheet)
	sheet.setup()
	sheet.closed.connect(_on_sheet_closed)
	slides = GameMenu.Slides.new()
	root.add_child(slides)
	slides.setup()
	slides.finished.connect(_on_slides_done)
	menu = GameMenu.new()
	root.add_child(menu)
	menu.setup()
	menu.chosen.connect(_on_menu)


func space() -> PhysicsDirectSpaceState3D:
	return get_world_3d().direct_space_state


func ui_blocked() -> bool:
	return dialog.visible or kpk.visible or sheet.visible or menu.visible or slides.visible or _loading


# ---------------- меню и запуск ----------------
func _on_menu(id: String) -> void:
	match id:
		"new":
			menu.visible = false
			get_tree().paused = false
			_unload()
			Game.new_hero()
			_intro_pending = true
			sheet.open()
		"continue":
			_load_slot("auto")
		"load_quick":
			_load_slot("quick")
		"save_quick":
			quicksave()
			menu.visible = false
			get_tree().paused = false
		"resume":
			menu.visible = false
			get_tree().paused = false
		"to_main":
			get_tree().paused = false
			_unload()
			menu.open("main")
		"quit":
			get_tree().quit()


func _load_slot(slot: String) -> void:
	menu.visible = false
	get_tree().paused = false
	if not Game.load_game(slot):
		menu.open("main")
		return
	hud.clear_log()
	var h := Game.hero
	var pos = null
	if h.pos is Array and h.pos.size() == 2:
		pos = Vector3(float(h.pos[0]), 0, float(h.pos[1]))
	await load_location(str(h.get("location", "nakharro")), "Start", pos)
	Game.log_line("Загружено.")


func _on_sheet_closed() -> void:
	if _intro_pending:
		_intro_pending = false
		var lines: Array = DB.intro.get("prologue", ["Прошло пятьдесят лет."])
		slides.play(lines)
	hud.refresh()


func _on_slides_done() -> void:
	hud.clear_log()
	await load_location("nakharro", "Start")
	location.on_new_game()


func _unload() -> void:
	if combat.on:
		combat.on = false
	overlay.visible = false
	dialog.visible = false
	kpk.visible = false
	hud.visible = false
	_xray.clear()
	if location:
		if player and player.get_parent() == location:
			location.remove_child(player)
		location.queue_free()
		location = null


func load_location(id: String, spawn := "Start", pos = null) -> void:
	_loading = true
	_unload()
	var path: String = LOCATIONS.get(id, "")
	if path == "":
		push_error("Нет локации: " + id)
		_loading = false
		return
	var ps: PackedScene = load(path)
	location = ps.instantiate()
	add_child(location)
	location.add_to_group("location")
	if player == null:
		player = Character.new()
		player.name = "Player"
		player.use_hero_model = true
		player.use_anim_model = true
		player.is_player = true
		player.char_id = "hero"
	location.add_child(player)
	player.display_name = Game.hero.name
	player.pose = ""
	var p: Vector3 = pos if pos != null else location.spawn_point(spawn)
	player.global_position = Vector3(p.x, 0, p.z)
	player.set_held(Game.hero_wkey())
	cam_target = player.global_position
	await location.setup(self)
	Game.hero.location = id
	_loading = false
	hud.visible = true
	hud.refresh()
	hud.refresh_objective()
	location.on_enter()


func autosave() -> void:
	if location == null or combat.on:
		return
	Game.hero.pos = [snappedf(player.global_position.x, 0.01), snappedf(player.global_position.z, 0.01)]
	Game.save_game("auto")


func quicksave() -> void:
	if location == null or combat.on:
		hud.flash_tip("В бою сохраняться нельзя")
		return
	Game.hero.pos = [snappedf(player.global_position.x, 0.01), snappedf(player.global_position.z, 0.01)]
	Game.save_game("quick")
	hud.toast("Сохранено")


func show_game_over() -> void:
	menu.open("dead")


func show_end(mode := "end_prologue") -> void:
	autosave()
	menu.open(mode)


# ---------------- интерфейс ----------------
func status_text() -> String:
	if location == null:
		return ""
	return "%s · %s" % [location.title, location.status_line() if location.has_method("status_line") else ""]


func objective_text() -> String:
	if location and location.has_method("objective"):
		var o: String = location.objective()
		if o != "":
			return o
	for id in Game.hero.q:
		var q: Dictionary = DB.quests.get(id, {})
		var st := int(Game.hero.q[id])
		if st > 0 and st < int(q.get("done_stage", 999)):
			return q.get("stages", {}).get(str(st), "")
	return ""


func _on_hud_action(a: String) -> void:
	if menu.visible or slides.visible:
		return
	match a:
		"menu":
			_open_pause()
		"zin":
			zoom = clampf(zoom / 1.2, 7.0, 32.0)
		"zout":
			zoom = clampf(zoom * 1.2, 7.0, 32.0)
		"mode":
			if combat.my_turn():
				combat.cycle_mode()
		"swap":
			_swap_hands()
		"kpk":
			open_kpk()
		"sheet":
			if not combat.on:
				sheet.open()
		"reload":
			combat.reload()
		"sneak":
			if not combat.on:
				Game.hero.sneak = not Game.hero.get("sneak", false)
				var r := _sneak_radius(9.0)
				Game.log_line("Крадёшься. Враги заметят тебя примерно с %.1f м (DEX + Скрытность)." % r if Game.hero.sneak else "Идёшь обычным шагом.")
				Game.hero_changed.emit()
		"give":
			combat.give_up()
		"end":
			if combat.on:
				if combat.my_turn():
					combat.end_turn()
			else:
				attack_mode = not attack_mode
				Game.log_line("Режим атаки: кликни по цели." if attack_mode else "Режим атаки выключен.")
				hud.refresh()


func open_kpk(t := "") -> void:
	if combat.on and not combat.my_turn():
		return
	kpk.open(t)


func _swap_hands() -> void:
	if combat.on and not combat.my_turn():
		return
	Game.hero.active = 1 - int(Game.hero.active)
	combat.aim = false
	combat.burst = false
	player.set_held(Game.hero_wkey())
	Game.hero_changed.emit()
	if combat.on:
		combat.after_hero_action()


func _open_pause() -> void:
	if location == null:
		return
	menu.open("pause")
	get_tree().paused = true


## Крадучись — медленно; к близкой точке — шагом; далеко — бегом
func _move_speed(pts: Array) -> float:
	if Game.hero.get("sneak", false):
		return SNEAK_SPEED
	var dist := 0.0
	var prev := player.global_position
	for p in pts:
		dist += Vector2(p.x - prev.x, p.z - prev.z).length()
		prev = p
	return WALK_SPEED if dist <= WALK_MAX_DIST else RUN_SPEED


func _sneak_radius(base: float) -> float:
	if not Game.hero.get("sneak", false):
		return base
	var v := int(Game.hero.stats.get("DEX", 0)) + int(Game.hero.skills.get("Скрытность", 0))
	return maxf(2.5, base - 1.0 - v / 2.0)


func on_combat_start() -> void:
	attack_mode = false
	_pending = {}
	if dialog.visible:
		dialog.close()
	if kpk.visible:
		kpk.close()


# ---------------- диалоги ----------------
func talk_to(ch: Character, node := "") -> void:
	if ch.dialog == "":
		return
	player.face_towards(ch.global_position)
	ch.face_towards(player.global_position)
	dialog.open(ch.dialog, node if node != "" else ch.dialog_node, ch)


func say(dialog_id: String, node := "start", who: Character = null) -> void:
	dialog.open(dialog_id, node, who)


func _on_dialog_action(a: String, sp: Character) -> void:
	if location and location.on_dialog_action(a, sp):
		return
	match a:
		"fight":
			if sp:
				dialog.close()
				start_fight([sp])
		"spar":
			if sp:
				dialog.close()
				combat.start([sp], {"kind": "spar"})
		"heal_rest":
			var a1 := Rules.r1(6)
			var b1 := Rules.r1(6)
			var before := Game.hero_hp()
			Game.set_hero_hp(before + a1 + b1)
			Game.log_line("Короткий отдых: ХП %d, стало %d" % [before, Game.hero_hp()], "2d6 (%d+%d)" % [a1, b1])
		"end":
			dialog.close()


func _on_dialog_closed() -> void:
	hud.refresh()
	hud.refresh_objective()


func start_fight(chars: Array, opts := {}) -> void:
	var all := []
	for c in chars:
		if not all.has(c):
			all.append(c)
		if c.squad != "":
			for o in location.characters():
				if o.squad == c.squad and not all.has(o) and o.pose != "dead" and o.visible:
					all.append(o)
	combat.start(all, opts)


# ---------------- ввод ----------------
func _unhandled_input(e: InputEvent) -> void:
	if location == null or ui_blocked():
		return
	if e is InputEventMouseButton and e.pressed:
		match e.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				zoom = clampf(zoom / 1.1, 7.0, 32.0)
			MOUSE_BUTTON_WHEEL_DOWN:
				zoom = clampf(zoom * 1.1, 7.0, 32.0)
			MOUSE_BUTTON_LEFT:
				if not hud.mouse_over_ui():
					_click(e.position)
			MOUSE_BUTTON_RIGHT:
				if combat.on and not combat.pending.is_empty():
					combat.zone_picked("")
				elif not combat.on:
					player.stop()
					_pending = {}
	elif e is InputEventKey and e.pressed and not e.echo:
		match e.keycode:
			KEY_ESCAPE:
				if combat.on and not combat.pending.is_empty():
					combat.zone_picked("")
				elif attack_mode:
					attack_mode = false
					hud.refresh()
				else:
					_open_pause()
			KEY_I:
				open_kpk()
			KEY_C:
				if not combat.on:
					sheet.open()
			KEY_R:
				combat.reload()
			KEY_TAB:
				_swap_hands()
			KEY_SPACE:
				if combat.my_turn():
					combat.end_turn()
			KEY_A:
				if combat.my_turn():
					combat.aim = not combat.aim
					combat.burst = false
					combat.changed.emit()
			KEY_F5:
				quicksave()
			KEY_F9:
				_load_slot("quick")


func _pick(screen_pos: Vector2) -> Dictionary:
	var from := camera.project_ray_origin(screen_pos)
	var dir := camera.project_ray_normal(screen_pos)
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * 400.0, 2 | 4)
	q.collide_with_areas = true
	q.collide_with_bodies = false
	var res := {}
	var hit := space().intersect_ray(q)
	if not hit.is_empty():
		var col: Object = hit.collider
		if col.has_meta("character"):
			var ch: Character = col.get_meta("character")
			if ch != player and ch.visible:
				res.character = ch
		elif col.has_meta("interactable"):
			res.item = col.get_meta("interactable")
	var plane := Plane(Vector3.UP, 0.0)
	var g = plane.intersects_ray(from, dir)
	if g != null:
		res.ground = g
		res.hex = location.grid.from_world(g)
	return res


func _click(sp: Vector2) -> void:
	var p := _pick(sp)
	if combat.on:
		combat.click(p.get("character", null), p.get("hex", null))
		return
	var ch: Character = p.get("character", null)
	if ch:
		if ch.pose == "dead":
			_go_then(ch, "loot")
			return
		if attack_mode or ch.hostile:
			attack_mode = false
			start_fight([ch], {"ambush": Game.hero.get("sneak", false)})
			return
		if ch.dialog != "":
			_go_then(ch, "talk")
			return
		hud.flash_tip(ch.display_name)
		return
	var it: Interactable = p.get("item", null)
	if it:
		_go_then(it, "use")
		return
	if p.has("hex"):
		_walk_to_hex(p.hex)


func _walk_to_hex(h: Vector2i, cb := Callable()) -> bool:
	var g := location.grid
	var from := g.from_world(player.global_position)
	var target := h
	if not g.is_free(target):
		target = g.nearest_free(g.to_world(h))
	var blocked := {}
	for c in location.characters():
		if c.visible and c.pose != "dead":
			blocked[g.from_world(c.global_position)] = true
	var path := g.explore_path(from, target, blocked)
	if path.is_empty() and from != target:
		hud.flash_tip("Туда не пройти")
		return false
	var pts := []
	for x in path:
		pts.append(g.to_world(x))
	player.move_along(pts, cb, _move_speed(pts))
	return true


func _go_then(target: Node3D, what: String) -> void:
	var g := location.grid
	var th := g.from_world(target.global_position)
	var reach := 1
	if target is Interactable:
		reach = (target as Interactable).reach
	var ph := g.from_world(player.global_position)
	var act := func(): _do_pending(target, what)
	if g.distance(ph, th) <= reach:
		act.call()
		return
	# ищем ближайший свободный гекс рядом с целью
	var best = null
	var bd := 1e9
	for rr in range(1, reach + 2):
		for dq in range(-rr, rr + 1):
			for dr in range(maxi(-rr, -dq - rr), mini(rr, -dq + rr) + 1):
				var h := Vector2i(th.x + dq, th.y + dr)
				if not g.is_free(h) or g.distance(h, th) > reach:
					continue
				var d := g.to_world(h).distance_to(player.global_position)
				if d < bd:
					bd = d
					best = h
		if best != null:
			break
	if best == null:
		hud.flash_tip("Не подойти")
		return
	_walk_to_hex(best, act)


func _do_pending(target: Node3D, what: String) -> void:
	if combat.on or not is_instance_valid(target):
		return
	player.face_towards(target.global_position)
	match what:
		"talk":
			talk_to(target as Character)
		"loot":
			loot(target as Character)
		"use":
			interact(target as Interactable)


func interact(it: Interactable) -> void:
	if location.on_interact(it):
		return
	if it.kind != "item" or it.item_id == "":
		return
	if not location.can_pick(it):
		return
	var take := func():
		location.ws().picked[it.uid()] = true
		it.set_active(false)
		Game.add_item(it.item_id, it.count)
		var nm := it.title()
		Game.log_line("Подобрано: %s%s" % [nm, (" ×%d" % it.count) if it.count > 1 else ""])
		hud.float_text(it.global_position + Vector3(0, 1.4, 0), "+ " + nm, "miss")
		player.set_held(Game.hero_wkey())
		location.on_picked(it)
		autosave()
	player.act("pickup", take)


func loot(ch: Character) -> void:
	var st := location.ws()
	if st.looted.has(ch.uid()):
		hud.flash_tip("Уже обыскан")
		return
	st.looted[ch.uid()] = true
	var got := []
	var tpl := ch.tpl
	var wk: String = tpl.get("weapon", "")
	var f: Fighter = ch.fighter
	if wk != "" and DB.weapons.has(wk):
		var w := DB.weapon(wk)
		if DB.is_gun(wk):
			var n := (f.mag + f.ammo_left) if f else int(tpl.get("mag", w.mag)) + int(tpl.get("ammo", 0))
			if n > 0:
				Game.add_item("ammo9" if w.ammo == "9мм" else "ammo762", n)
				got.append("%d патр. %s" % [n, w.ammo])
		if not Game.hero.owned.has(wk) and tpl.get("drop_weapon", true) and wk != "fists" and not w.get("natural", false):
			Game.add_item(wk)
			got.append(w.name)
	var lt: Dictionary = tpl.get("loot", {})
	for k in lt:
		Game.add_item(k, int(lt[k]))
		got.append("%s ×%d" % [DB.item_name(k), int(lt[k])] if int(lt[k]) > 1 else DB.item_name(k))
	player.act("pickup")
	player.set_held(Game.hero_wkey())
	Game.log_line("Обыскал: %s" % ch.display_name, ", ".join(got) if not got.is_empty() else "пусто")
	location.on_looted(ch)
	autosave()


# ---------------- кадр ----------------
func _process(delta: float) -> void:
	if location == null or player == null:
		return
	# камера
	var tgt := player.global_position
	cam_target = cam_target.lerp(tgt, minf(1.0, delta * 5.0))
	camera.size = lerpf(camera.size, zoom, minf(1.0, delta * 8.0))
	camera.global_position = cam_target + CAM_DIR.normalized() * CAM_DIST
	camera.look_at(cam_target, Vector3.UP)
	_xray_t -= delta
	if _xray_t <= 0.0:
		_xray_t = 0.1
		_update_xray()
	if ui_blocked():
		return
	# наведение
	var mp := get_viewport().get_mouse_position()
	if hud.mouse_over_ui():
		if not combat.on:
			hud.hide_tip()
	else:
		var p := _pick(mp)
		if combat.on:
			combat.hover(p.get("character", null), p.get("hex", null))
		else:
			var ch: Character = p.get("character", null)
			var it: Interactable = p.get("item", null)
			if ch:
				var t := ch.display_name
				if ch.pose == "dead":
					t += " · мёртв" + ("" if location.ws().looted.has(ch.uid()) else " · обыскать")
				elif ch.hostile or attack_mode:
					t += " · атаковать"
				elif ch.dialog != "":
					t += " · поговорить"
				hud.show_tip(t)
			elif it:
				hud.show_tip(it.title())
			elif _hover != null:
				hud.hide_tip()
			_hover = ch if ch else it
	# враги замечают героя
	if not combat.on:
		_aggro_t -= delta
		if _aggro_t <= 0:
			_aggro_t = 0.25
			_check_aggro()
		location.on_hero_moved(player.global_position)


## Дома и деревья между камерой и героем становятся полупрозрачными
func _update_xray() -> void:
	var hits := []
	var from := camera.global_position
	var side := camera.global_basis.x.normalized()
	var targets := [player.global_position + Vector3(0, 1.6, 0), player.global_position + Vector3(0, 0.3, 0),
		player.global_position + side * 1.2 + Vector3(0, 0.8, 0), player.global_position - side * 1.2 + Vector3(0, 0.8, 0)]
	if combat.on:
		for e in combat.enemies():
			targets.append(e.node.global_position + Vector3(0, 1.0, 0))
	for to in targets:
		var excl: Array[RID] = []
		for i in 6:
			var q := PhysicsRayQueryParameters3D.create(from, to, 1)
			q.exclude = excl
			var r := space().intersect_ray(q)
			if r.is_empty():
				break
			var col: Object = r.collider
			excl.append(r.rid)
			var prop: Node = (col as Node).get_parent()
			if prop and prop != location and not hits.has(prop):
				hits.append(prop)
	for p in _xray:
		if is_instance_valid(p) and not hits.has(p):
			_set_alpha(p, 0.0)
	for p in hits:
		if not _xray.has(p):
			_set_alpha(p, 0.72)
	_xray = hits


func _set_alpha(n: Node, a: float) -> void:
	if n is GeometryInstance3D:
		(n as GeometryInstance3D).transparency = a
	for c in n.get_children():
		_set_alpha(c, a)


func _check_aggro() -> void:
	for ch in location.characters():
		if not ch.hostile or ch.aggro_radius <= 0 or ch.pose == "dead" or not ch.visible:
			continue
		var d := Vector2(ch.global_position.x - player.global_position.x, ch.global_position.z - player.global_position.z).length()
		if d <= _sneak_radius(ch.aggro_radius) and location.grid.line_clear(ch.global_position, player.global_position, space()):
			player.stop()
			if location.has_method("on_noticed") and location.on_noticed(ch):
				return
			Game.log_line("%s замечает тебя!" % ch.display_name, "", "miss")
			start_fight([ch])
			return
