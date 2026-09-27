class_name CombatManager
extends Node
## Пошаговый бой на гексах. Правила и ИИ перенесены из прототипа «Недострой»:
##  ОД = 5 + ⌊(REF+DEX)/4⌋ (−1 если ранен ниже 50%)
##  атака d10 + хар-ка + навык + бонус − прицел − дальность − очередь
##  против уклонения d10 + DEX + Уклонение + оборона
##  несъеденные ОД в конце хода -> оборона (+ половина к уклонению)

signal changed
signal ended(result: String, kind: String)

var main: Node
var on := false
var kind := "fight"
var units: Array = []
var order: Array = []
var turn := 0
var round_n := 1
var busy := false
var aim := false
var burst := false
var pending: Dictionary = {}
var reach: Dictionary = {}
var hero_f: Fighter
var hero_init := 0


func setup(m: Node) -> void:
	main = m


func grid() -> HexGrid:
	return main.location.grid


func clog(h: String, d := "", cls := "") -> void:
	Game.log_line(h, d, cls)


# ---------------- состояние ----------------
func whose_turn() -> Fighter:
	if order.is_empty():
		return hero_f
	return order[turn]


func my_turn() -> bool:
	return on and not busy and whose_turn() == hero_f


func enemies() -> Array:
	var out := []
	if not on:
		return out
	for u in units:
		if not u.is_hero and u.active():
			out.append(u)
	return out


func occ(except: Fighter = null) -> Dictionary:
	var s := {}
	for u in units:
		if u != except and u.active() and u.has_hex:
			s[u.hex] = true
	return s


func mode_cost(w: Dictionary) -> int:
	if burst and w.has("burst"):
		return int(w.burst.ap)
	return int(w.ap) + (1 if aim else 0)


func mode_name() -> String:
	return "aim" if aim else ("burst" if burst else "single")


func cycle_mode() -> void:
	var w := Game.hero_weapon()
	var lst := ["single", "burst", "aim"] if w.has("burst") else ["single", "aim"]
	var n: String = lst[(lst.find(mode_name()) + 1) % lst.size()]
	aim = n == "aim"
	burst = n == "burst"
	changed.emit()


# ---------------- начало боя ----------------
## opts: kind ("fight" | "spar"), ambush (герой первый), enemy_first
func start(foe_chars: Array, opts := {}) -> void:
	if on:
		return
	var foes := []
	for ch in foe_chars:
		if not is_instance_valid(ch) or ch.pose == "dead":
			continue
		if ch.fighter == null:
			ch.fighter = Fighter.for_npc(ch, ch.tpl)
		var f: Fighter = ch.fighter
		if f.alive and not f.fled:
			foes.append(f)
	if foes.is_empty():
		return
	on = true
	busy = true
	reach = {}
	kind = opts.get("kind", "fight")
	aim = false
	burst = false
	pending = {}
	main.on_combat_start()
	round_n = 1
	turn = 0
	hero_f = Fighter.for_hero(main.player)
	main.player.fighter = hero_f
	units = [hero_f]
	units.append_array(foes)
	Game.hero.sneak = false
	for f in foes:
		f.node.set_held(f.wkey)
		f.node.pose = ""
		f.node.aim_pose = true
		f.db = 0
		f.ap = 0
		f.think = 0
		f.node.stop()
	main.player.aim_pose = true
	main.player.stop()
	var taken := {}
	for u in units:
		var hx := grid().nearest_free(u.node.global_position, taken)
		u.hex = hx
		u.has_hex = true
		taken[hx] = true
		u.node.move_along([grid().to_world(hx)])
	match kind:
		"spar":
			clog("——— Тренировочный бой ———")
		_:
			clog("——— БОЙ ———")
	var ini := []
	for u in units:
		var r := Rules.roll_hit()
		ini.append({"u": u, "v": r.d + int(u.stats.get("REF", 0)), "d": r.d})
	ini.sort_custom(func(a, b): return a.v > b.v)
	order = []
	for x in ini:
		order.append(x.u)
	if opts.get("ambush", false):
		order.erase(hero_f)
		order.push_front(hero_f)
	elif opts.get("enemy_first", false):
		order.erase(hero_f)
		order.push_back(hero_f)
	var parts := []
	for x in ini:
		if x.u == hero_f:
			hero_init = x.v
		parts.append("%s: d10(%d) + REF(%d) = %d" % [x.u.name, x.d, x.u.stats.get("REF", 0), x.v])
	var head: String = "Инициатива: первым ходит " + str(order[0].name)
	if opts.get("ambush", false):
		head = "Внезапность: ты ходишь первым"
	elif opts.get("enemy_first", false):
		head = "Тебя застали врасплох"
	clog(head, " · ".join(parts))
	main.overlay.visible = true
	changed.emit()
	await get_tree().create_timer(0.45, false).timeout
	begin_turn()


func begin_turn() -> void:
	if not on:
		return
	var u := whose_turn()
	if not u.active():
		end_turn(true)
		return
	u.ap = Rules.ap_for(u.stats, u.hp, u.max_hp if not u.is_hero else Game.hero_max())
	u.ap_max = u.ap
	u.db = 0
	u.think = 0
	aim = false
	burst = burst and u.is_hero and Game.hero_weapon().has("burst")
	pending = {}
	main.hud.hide_zones()
	var mx := u.max_hp if not u.is_hero else Game.hero_max()
	clog("Ход: %s · %d ОД" % [u.name, u.ap], "5 + (REF %d + DEX %d) / 4, с округлением вниз%s" % [u.stats.get("REF", 0), u.stats.get("DEX", 0), " − 1 (ранен)" if u.hp < mx * 0.5 else ""])
	main.location.on_combat_round(round_n)
	if not on:
		return
	if u.is_hero:
		busy = false
		after_hero_action()
	else:
		busy = true
		paint()
		changed.emit()
		await get_tree().create_timer(0.65, false).timeout
		ai_turn(u)


func end_turn(skip := false) -> void:
	if not on:
		return
	var u := whose_turn()
	if not skip and u.active():
		u.db = int(floor(u.ap / 2.0))
		if u.db:
			clog("%s держит оборону: +%d к Уклонению (%d ОД не потрачено)" % [u.name, u.db, u.ap])
		u.ap = 0
	main.hud.hide_tip()
	if check_end():
		return
	var guard := 0
	while true:
		turn += 1
		if turn >= order.size():
			turn = 0
			round_n += 1
			clog("— Раунд %d —" % round_n)
		guard += 1
		if order[turn].active() or guard > 20:
			break
	begin_turn()


func after_hero_action() -> void:
	reach = grid().bfs(hero_f.hex, occ(hero_f), hero_f.ap)
	paint()
	changed.emit()
	if on and my_turn() and hero_f.ap <= 0:
		await get_tree().create_timer(0.45, false).timeout
		if my_turn() and hero_f.ap <= 0:
			end_turn()


# ---------------- подсветка гексов ----------------
func paint(hover_path: Array = [], hover_u: Fighter = null) -> void:
	var cells := []
	if on:
		var on_path := {}
		for h in hover_path:
			on_path[h] = true
		if my_turn() and not reach.is_empty():
			for h in reach.dist:
				var d: int = reach.dist[h]
				if d > 0 and d <= hero_f.ap and not on_path.has(h):
					cells.append([h, "reach"])
		for h in hover_path:
			cells.append([h, "path"])
		cells.append([hero_f.hex, "self"])
		for e in enemies():
			cells.append([e.hex, "target" if e == hover_u else "far"])
	main.overlay.show_cells(grid(), cells, units_center())


func units_center() -> Array:
	var hs := []
	for u in units:
		if u.active() and u.has_hex:
			hs.append(u.hex)
	return hs


# ---------------- ввод героя ----------------
func best_adj(t: Fighter) -> Variant:
	var best = null
	var bd := 1 << 30
	var o := occ(hero_f)
	for n in grid().neighbors(t.hex):
		if n == hero_f.hex:
			return n
		if o.has(n):
			continue
		if reach.dist.has(n) and reach.dist[n] < bd:
			bd = reach.dist[n]
			best = n
	return best


func hover(target_ch: Character, ground_hex: Variant) -> void:
	if not on:
		return
	if not my_turn() or reach.is_empty():
		main.hud.hide_tip()
		return
	var w := Game.hero_weapon()
	var k := Game.hero_wkey()
	var t: Fighter = null
	if target_ch and target_ch.fighter and target_ch.fighter in enemies():
		t = target_ch.fighter
	if t:
		var dist := grid().distance(hero_f.hex, t.hex)
		var cost := mode_cost(w)
		var is_burst := burst and w.has("burst")
		var A := Rules.atk_mods(hero_f, w, "Торс" if aim else null, dist, int(w.burst.pen) if is_burst else 0)
		var D := Rules.def_mods(t)
		var ch := roundi(Rules.hit_chance(A.total, D.total) * 100)
		var extra := ""
		var path := []
		if int(w.range) == 1 and dist > 1:
			var best = best_adj(t)
			if best != null:
				path = grid().path_to(reach, best)
				extra = " · подойти %d ОД" % path.size()
				if path.size() + cost > hero_f.ap:
					extra += " — не хватит ОД"
			else:
				extra = " · не подойти"
		if int(w.range) > 1 and dist > int(w.range):
			extra = " · слишком далеко"
		if DB.is_gun(k) and int(Game.hero.mag.get(k, 0)) <= 0:
			extra = " · магазин пуст (R)"
		var txt := "%s · %s · %s%d ОД · шанс %d%%%s%s%s%s" % [t.name, w.name,
			("очередь ×%d · " % int(w.burst.n)) if is_burst else "", cost, ch,
			" на пулю" if is_burst else "", " (торс)" if aim else "",
			(" · дальность −%d" % A.rp) if A.rp else "", extra]
		main.hud.show_tip(txt)
		paint(path, t)
		return
	if ground_hex != null:
		var h: Vector2i = ground_hex
		if grid().is_free(h) and reach.dist.has(h) and h != hero_f.hex:
			main.hud.show_tip("Идти: %d ОД" % reach.dist[h])
			paint(grid().path_to(reach, h))
			return
		if grid().is_free(h) and h != hero_f.hex and not occ(hero_f).has(h):
			main.hud.show_tip("Далеко: не хватит ОД (%d)" % hero_f.ap)
			paint()
			return
	main.hud.hide_tip()
	paint()


func click(target_ch: Character, ground_hex: Variant) -> void:
	if not my_turn() or reach.is_empty():
		return
	var w := Game.hero_weapon()
	var k := Game.hero_wkey()
	var t: Fighter = null
	if target_ch and target_ch.fighter and target_ch.fighter in enemies():
		t = target_ch.fighter
	if t:
		var dist := grid().distance(hero_f.hex, t.hex)
		var cost := mode_cost(w)
		if DB.is_gun(k):
			if int(Game.hero.mag.get(k, 0)) <= 0:
				clog("Щёлк! Магазин пуст — перезарядись (R, 2 ОД).", "", "miss")
				return
			if dist > int(w.range):
				main.hud.flash_tip("Слишком далеко")
				return
			if not grid().line_clear(grid().to_world(hero_f.hex), grid().to_world(t.hex), main.space()):
				main.hud.flash_tip("Нет линии огня")
				return
			if hero_f.ap < cost:
				main.hud.flash_tip("Не хватает ОД")
				return
			do_attack(cost, dist, t)
			return
		if dist == 1:
			if hero_f.ap < cost:
				main.hud.flash_tip("Не хватает ОД")
				return
			do_attack(cost, 1, t)
			return
		var best = best_adj(t)
		if best == null:
			main.hud.flash_tip("Не подойти")
			return
		var path := grid().path_to(reach, best)
		if path.size() + cost > hero_f.ap:
			main.hud.flash_tip("Не хватает ОД, чтобы подойти и ударить")
			return
		hero_f.ap -= path.size()
		hero_f.hex = best
		busy = true
		paint()
		changed.emit()
		var on_arrive := func():
			busy = false
			do_attack(cost, 1, t)
		main.player.move_along(_world_path(path), on_arrive)
		return
	if ground_hex == null:
		return
	var h: Vector2i = ground_hex
	if not reach.dist.has(h):
		return
	var d: int = reach.dist[h]
	if d <= 0:
		return
	if d > hero_f.ap:
		main.hud.flash_tip("Не хватает ОД")
		return
	hero_f.ap -= d
	hero_f.hex = h
	busy = true
	main.hud.hide_tip()
	paint()
	changed.emit()
	var arrived := func():
		busy = false
		after_hero_action()
	main.player.move_along(_world_path(grid().path_to(reach, h)), arrived)


func _world_path(hexes: Array) -> Array:
	var out := []
	for h in hexes:
		out.append(grid().to_world(h))
	return out


func do_attack(cost: int, dist: int, t: Fighter) -> void:
	if aim:
		pending = {"cost": cost, "dist": dist, "t": t}
		var rows := []
		var w := Game.hero_weapon()
		var D := Rules.def_mods(t)
		for z in Rules.ZONES:
			var A := Rules.atk_mods(hero_f, w, z.name, dist, 0)
			rows.append({"zone": z.name, "mult": z.mult, "pen": Rules.AIM_PEN[z.name], "chance": roundi(Rules.hit_chance(A.total, D.total) * 100)})
		main.hud.show_zones(rows)
		changed.emit()
		return
	exec_attack(cost, dist, "", t)


func zone_picked(zone: String) -> void:
	var p := pending
	pending = {}
	main.hud.hide_zones()
	if p.is_empty() or zone == "":
		changed.emit()
		return
	exec_attack(p.cost, p.dist, zone, p.t)


func exec_attack(cost: int, dist: int, zone: String, t: Fighter) -> void:
	var k := Game.hero_wkey()
	var w := Game.hero_weapon()
	if hero_f.ap < cost:
		main.hud.flash_tip("Не хватает ОД")
		return
	var is_burst := burst and w.has("burst") and zone == ""
	hero_f.ap -= cost
	busy = true
	aim = false
	main.hud.hide_tip()
	paint()
	main.player.face_towards(t.node.global_position)
	var after := func():
		await get_tree().create_timer(0.48, false).timeout
		busy = false
		if check_end():
			return
		after_hero_action()
	var z = zone if zone != "" else null
	if DB.is_gun(k):
		var n := mini(int(w.burst.n), int(Game.hero.mag.get(k, 0))) if is_burst else 1
		Game.hero.mag[k] = int(Game.hero.mag.get(k, 0)) - n
		changed.emit()
		var per_shot := func(i: int):
			if not on or not t.alive:
				return
			var pen := int(w.burst.pen) if is_burst else 0
			var nt := (" · пуля %d/%d" % [i + 1, n]) if is_burst else ""
			var r := resolve_attack(hero_f, t, w, z, dist, pen, nt)
			react(t, r)
			changed.emit()
		main.player.act("fire", after, {"n": n, "per_shot": per_shot})
	else:
		changed.emit()
		var impact := func():
			var r := resolve_attack(hero_f, t, w, z, dist, 0, "")
			react(t, r)
			changed.emit()
			after.call()
		main.player.act("swing", impact)


func reload() -> void:
	var k := Game.hero_wkey()
	if not DB.is_gun(k):
		return
	var w := DB.weapon(k)
	var have := int(Game.hero.ammo.get(w.ammo, 0))
	var need := int(w.mag) - int(Game.hero.mag.get(k, 0))
	if need <= 0:
		main.hud.flash_tip("Магазин полон")
		return
	if have <= 0:
		main.hud.flash_tip("Нет патронов " + str(w.ammo))
		return
	if on:
		if not my_turn():
			return
		if hero_f.ap < 2:
			main.hud.flash_tip("Не хватает ОД")
			return
		hero_f.ap -= 2
	var n := mini(need, have)
	Game.hero.mag[k] = int(Game.hero.mag.get(k, 0)) + n
	Game.hero.ammo[w.ammo] = have - n
	main.player.act("reload")
	clog("Перезарядка: %s %d/%d" % [w.name, Game.hero.mag[k], w.mag], "−2 ОД" if on else "")
	Game.hero_changed.emit()
	if on:
		after_hero_action()


func use_med(item_id: String) -> void:
	var c: Dictionary = DB.items.get(item_id, {})
	if c.is_empty() or not c.has("heal") or Game.item_count(item_id) <= 0:
		main.hud.flash_tip("Нет: " + (c.get("name", item_id) as String).to_lower())
		return
	if Game.hero_hp() >= Game.hero_max():
		main.hud.flash_tip("ХП и так полное")
		return
	var cost := int(c.get("ap", 2))
	if on:
		if not my_turn():
			return
		if hero_f.ap < cost:
			main.hud.flash_tip("Не хватает ОД")
			return
		hero_f.ap -= cost
	var rs := Rules.roll_dice(c.heal)
	var heal := Rules.sum_arr(rs) + int(c.get("plus", 0))
	var b := Game.hero_hp()
	Game.remove_item(item_id)
	Game.set_hero_hp(b + heal)
	main.player.act("reload")
	clog("%s: ХП %d, стало %d" % [c.name, b, Game.hero_hp()], "%s(%s) + %d = %d%s" % [c.heal, "+".join(rs.map(func(x): return str(x))), int(c.get("plus", 0)), heal, (" · −%d ОД" % cost) if on else ""])
	if on:
		after_hero_action()


func give_up() -> void:
	if not my_turn():
		return
	if kind != "spar":
		main.hud.flash_tip("Не отпустят. Беги или дерись.")
		return
	finish("lose", true)


# ---------------- ИИ ----------------
func ai_turn(u: Fighter) -> void:
	if not on:
		return
	if not u.active():
		end_turn(true)
		return
	u.think += 1
	if u.think > 9:
		end_turn()
		return
	var w := DB.weapon(u.wkey)
	var d := grid().distance(u.hex, hero_f.hex)
	if u.fleeing:
		ai_flee(u)
		return
	if int(w.range) > 1:
		if u.mag <= 0:
			if u.ammo_left > 0 and u.ap >= 2:
				u.ap -= 2
				var n := mini(int(w.mag), u.ammo_left)
				u.mag = n
				u.ammo_left -= n
				u.node.act("reload")
				clog("%s перезаряжает %s" % [u.name, w.name])
				changed.emit()
				await get_tree().create_timer(0.75, false).timeout
				ai_turn(u)
				return
			u.wkey = "fists"
			u.node.set_held("")
			clog("%s: патроны кончились — лезет с кулаками" % u.name)
			ai_turn(u)
			return
		var clear := grid().line_clear(grid().to_world(u.hex), grid().to_world(hero_f.hex), main.space())
		if d <= int(w.get("eff_range", 6)) + 3 and clear:
			if u.ap >= int(w.ap):
				ai_shoot(u, d)
				return
			end_turn()
			return
		ai_move(u, hero_f.hex, int(w.get("eff_range", 6)), int(w.ap), true)
		return
	if d == 1:
		if u.ap >= int(w.ap):
			ai_melee(u)
			return
		end_turn()
		return
	ai_move(u, hero_f.hex, 1, int(w.ap), false)


func ai_move(u: Fighter, target: Vector2i, rng: int, keep: int, need_los: bool) -> void:
	var o := occ(u)
	var b := grid().bfs(u.hex, o, -1, 12000)
	var best = null
	var bd := 1 << 30
	var tw := grid().to_world(target)
	for h in b.dist:
		if o.has(h):
			continue
		var dd: int = b.dist[h]
		if dd >= bd:
			continue
		if grid().distance(h, target) > rng:
			continue
		if need_los and not grid().line_clear(grid().to_world(h), tw, main.space()):
			continue
		bd = dd
		best = h
	if best == null or bd == 0:
		end_turn()
		return
	var path := grid().path_to(b, best)
	if path.size() > u.ap:
		path = path.slice(0, u.ap)
	if path.is_empty():
		end_turn()
		return
	u.ap -= path.size()
	u.hex = path[path.size() - 1]
	clog("%s %s: %d ОД" % [u.name, "подходит" if u.ap >= keep else "двигается", path.size()])
	changed.emit()
	var cont := func():
		paint()
		await get_tree().create_timer(0.22, false).timeout
		ai_turn(u)
	u.node.move_along(_world_path(path), cont, 2.8)


func ai_shoot(u: Fighter, d: int) -> void:
	var w := DB.weapon(u.wkey)
	u.ap -= int(w.ap)
	u.mag -= 1
	changed.emit()
	u.node.face_towards(hero_f.node.global_position)
	var done := func():
		await get_tree().create_timer(0.42, false).timeout
		if check_end():
			return
		ai_turn(u)
	var per_shot := func(_i: int):
		var r := resolve_attack(u, hero_f, w, null, d, 0, "")
		react(hero_f, r)
		changed.emit()
	u.node.act("fire", done, {"n": 1, "per_shot": per_shot})


func ai_melee(u: Fighter) -> void:
	var w := DB.weapon(u.wkey)
	var aim_z = "Торс" if (u.ap >= int(w.ap) + 1 and randf() < 0.2) else null
	u.ap -= int(w.ap) + (1 if aim_z != null else 0)
	changed.emit()
	u.node.face_towards(hero_f.node.global_position)
	var impact := func():
		var r := resolve_attack(u, hero_f, w, aim_z, 1, 0, "")
		react(hero_f, r)
		changed.emit()
		await get_tree().create_timer(0.65, false).timeout
		if check_end():
			return
		ai_turn(u)
	u.node.act("swing", impact)


func ai_flee(u: Fighter) -> void:
	var o := occ(u)
	var b := grid().bfs(u.hex, o, u.ap, 4000)
	var best: Vector2i = u.hex
	var bd := -1
	for h in b.dist:
		if o.has(h):
			continue
		var dh := grid().distance(h, hero_f.hex)
		if dh > bd:
			bd = dh
			best = h
	var path := grid().path_to(b, best)
	clog("%s бежит!" % u.name, "", "miss")
	u.ap = 0
	u.hex = best
	var gone := func():
		u.fled = true
		main.location.ws().misc["gone_" + u.node.uid()] = true
		u.node.visible = false
		clog("%s скрылся." % u.name)
		if not check_end():
			end_turn(true)
	u.node.move_along(_world_path(path), gone, 3.4)


# ---------------- расчёт атаки ----------------
func resolve_attack(att: Fighter, dfn: Fighter, w: Dictionary, aim_z, dist: int, extra: int, note: String) -> Dictionary:
	var R := Rules.roll_hit()
	var A := Rules.atk_mods(att, w, aim_z, dist, extra)
	var D := Rules.def_mods(dfn)
	var t: int = R.d + A.total
	var show: bool = Game.settings.get("show_rolls", true)
	clog("%s: %s%s%s%s" % [att.name, w.name, (" » " + aim_z) if aim_z != null else "", note, " · КРИТ" if R.crit else (" · ПРОВАЛ" if R.fumble else "")],
		"атака d10(%d) + %s(%d) + %s(%d)%s%s%s%s = %d" % [R.d, A.st_k, A.rv, A.sk, A.sv,
		(" + бонус(%d)" % A.b) if A.b else "", (" − прицел(%d)" % A.ap) if A.ap else "",
		(" − дальность(%d)" % A.rp) if A.rp else "", (" − очередь(%d)" % A.ex) if A.ex else "", t] if show else "")
	var Q := Rules.roll_hit()
	var dt: int = Q.d + D.total
	clog("%s уклоняется%s" % [dfn.name, " · КРИТ" if Q.crit else (" · ПРОВАЛ" if Q.fumble else "")],
		"d10(%d) + DEX(%d) + Уклонение(%d)%s = %d" % [Q.d, D.dv, D.dg, (" + оборона(%d)" % D.db) if D.db else "", dt] if show else "")
	if dt >= t:
		clog("» Мимо: уклонение %d не меньше атаки %d" % [dt, t], "", "miss")
		return {"hit": false}
	var zr := 0
	var z: Dictionary
	if aim_z != null:
		z = Rules.zone_by_name(aim_z)
	else:
		zr = Rules.r1(6)
		z = Rules.ZONES[zr - 1]
	var dice := Rules.roll_dice(w.dmg)
	var mx := Game.hero_max() if att.is_hero else att.max_hp
	var wp := Rules.wound_dmg_penalty(att.hp, mx)
	var raw := maxi(0, Rules.sum_arr(dice) + int(w.get("bonus", 0)) - wp)
	var mul := int(floor(raw * float(z.mult)))
	var armor_type := "none"
	if not dfn.armor.is_empty() and z.slot == "body":
		armor_type = dfn.armor.get("type", "none")
	var ae: Dictionary
	if z.ignore_armor:
		ae = {"ad": 0, "hd": mul, "desc": "игнор брони: ХП−%d" % mul}
	elif armor_type != "none" and dfn.arm <= 0:
		ae = {"ad": 0, "hd": mul, "desc": "броня пробита: ХП−%d" % mul}
	else:
		ae = Rules.calc_ae(armor_type, w.dmg_type, mul)
	var armor_note := ""
	if ae.ad > 0 and armor_type != "none":
		var o := dfn.arm
		dfn.arm = maxi(0, dfn.arm - int(ae.ad))
		armor_note = " · %s %d, стало %d" % [dfn.armor.get("name", "броня"), o, dfn.arm]
	var before := dfn.hp
	dfn.hp = maxi(0, before - int(ae.hd))
	var after := dfn.hp
	clog("» Попадание: %s ×%d, −%d ХП" % [z.name, z.mult, ae.hd],
		"%s · урон %s(%s)%s%s = %d ×%d = %d · %s%s · ХП %d, стало %d" % ["прицельно" if aim_z != null else "зона 1d6=%d" % zr, w.dmg,
		"+".join(dice.map(func(x): return str(x))), (" + %d" % int(w.bonus)) if int(w.get("bonus", 0)) else "",
		(" − раны(%d)" % wp) if wp else "", raw, z.mult, mul, ae.desc, armor_note, before, after] if show else "", "hit")
	if not dfn.is_hero:
		if dfn.hp <= 0 and dfn.lethal:
			kill(dfn)
		elif not dfn.lethal and dfn.hp <= int(ceil(dfn.max_hp * 0.25)):
			dfn.yielded = true
			dfn.node.pose = "yield"
			clog("%s поднимает руки: «Хватит, хватит!»" % dfn.name)
		elif dfn.lethal and dfn.hp < dfn.max_hp * dfn.flee_threshold and not dfn.fleeing:
			var W := Rules.roll_hit()
			var wv := int(dfn.stats.get("WILL", 0))
			var fear := int(dfn.skills.get("Сопротивление страху", 0))
			var v: int = W.d + wv + fear
			if v < dfn.will_dc:
				dfn.fleeing = true
				clog("%s дрогнул" % dfn.name, "воля d10(%d) + WILL(%d) + Сопротивление страху(%d) = %d < %d" % [W.d, wv, fear, v, dfn.will_dc])
	return {"hit": true, "dmg": ae.hd, "zone": z.name}


func react(dfn: Fighter, r: Dictionary) -> void:
	var pos: Vector3 = dfn.node.global_position + Vector3(0, 2.0, 0)
	if r.hit:
		if dfn.alive or dfn.is_hero:
			dfn.node.act("hit")
		main.hud.float_text(pos, "−%d %s" % [r.dmg, r.zone], "hit")
		if dfn.is_hero:
			main.hud.hurt_flash()
	else:
		main.hud.float_text(pos, "мимо", "miss")


func kill(u: Fighter) -> void:
	u.alive = false
	u.dead = true
	u.node.pose = "dead"
	u.node.aim_pose = false
	u.node.set_held("")
	main.location.ws().dead[u.node.uid()] = true
	clog("%s погибает." % u.name, "", "hit")
	var note := Game.grant_xp(u.xp)
	clog("Опыт +%d" % u.xp, note.strip_edges())
	main.location.on_fighter_down(u)


func check_end() -> bool:
	if not on:
		return true
	if Game.hero_hp() <= 0:
		game_over()
		return true
	if kind == "spar" and Game.hero_hp() <= int(ceil(Game.hero_max() * 0.25)):
		finish("lose")
		return true
	if enemies().is_empty():
		finish("win")
		return true
	return false


func finish(res: String, gave_up := false) -> void:
	busy = true
	main.hud.hide_tip()
	changed.emit()
	var win := res == "win"
	if kind == "spar":
		clog("Бой окончен: %s" % ("ты победил" if win else ("ты сдался" if gave_up else "ты еле стоишь")), "", "hit" if win else "miss")
	else:
		clog("Бой окончен. Можно обыскать тела." if win else "Ты отступил.", "", "hit" if win else "miss")
	await get_tree().create_timer(1.4, false).timeout
	on = false
	main.overlay.visible = false
	main.player.aim_pose = false
	for u in units:
		if not u.is_hero and u.alive and not u.fled:
			u.node.aim_pose = false
			if u.yielded:
				u.yielded = false
				u.node.pose = ""
				u._hp = u.max_hp
	Game.auto_reload()
	changed.emit()
	ended.emit(res, kind)
	main.location.on_combat_end(res, kind)
	main.autosave()


func game_over() -> void:
	busy = true
	main.player.pose = "dead"
	clog("%s погибает." % Game.hero.name, "", "hit")
	await get_tree().create_timer(1.6, false).timeout
	on = false
	main.overlay.visible = false
	changed.emit()
	main.show_game_over()
