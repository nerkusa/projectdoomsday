extends Node
## Часы игры и смена дня и ночи.
## Время — Game.hero.flags["clock"]: часы от полуночи первого дня (старт — 8:00).
## Сутки длятся DAY_MINUTES реальных минут. Часы стоят в разговорах, меню, бою и на карте
## мира (там время идёт по пройденному пути). Свет локации (Env/Sun, Env/WorldEnvironment)
## подстраивается под время суток. Жители из data/schedules.json днём на своих местах,
## ночью уходят домой.

signal hour_changed(hour: int)

## Реальных минут в игровых сутках
const DAY_MINUTES := 30.0
const START_HOUR := 8.0

var main: Node
## Часы идут сами (автотест может остановить)
var running := true
## Всегда день — для автотеста: расписание и свет как в полдень
var force_day := false
var _last_hour := -1
var _sched_t := 0.0


func hours() -> float:
	if Game.hero.is_empty():
		return START_HOUR
	return float(Game.hero.flags.get("clock", START_HOUR))


func set_hours(h: float) -> void:
	Game.hero.flags["clock"] = h
	_tick_hour()


func advance(dh: float) -> void:
	if dh <= 0.0:
		return
	set_hours(hours() + dh)


func hour_of_day() -> float:
	if force_day:
		return 12.0
	return fmod(hours(), 24.0)


func day() -> int:
	return int(hours() / 24.0) + 1


## Ночь: с 21 до 5
func is_night() -> bool:
	var h := hour_of_day()
	return h >= 21.0 or h < 5.0


func text() -> String:
	var h := hours()
	return "ДЕНЬ %d · %02d:%02d" % [day(), int(fmod(h, 24.0)), int(fmod(h * 60.0, 60.0))]


## Сколько часов до ближайшего часа h (0..24)
func until(h: float) -> float:
	var now := fmod(hours(), 24.0)
	var d := h - now
	if d <= 0.0:
		d += 24.0
	return d


func _process(delta: float) -> void:
	if main == null or main.location == null or main.player == null:
		return
	if running and not main.ui_blocked() and not main.combat.on:
		advance(delta * 24.0 / (DAY_MINUTES * 60.0))
	_sched_t -= delta
	if _sched_t <= 0.0:
		_sched_t = 1.0
		apply_light(main.location)
		update_schedules(false)
		if main.hud and main.hud._status:
			main.hud._status.text = main.status_text()


func _tick_hour() -> void:
	var h := int(fmod(hours(), 24.0))
	if h != _last_hour:
		_last_hour = h
		hour_changed.emit(h)


# ---------------- свет ----------------
## Насколько светло: 0 — ночь, 1 — день; рассвет 4:30–7, закат 18:30–21
func daylight() -> float:
	var h := hour_of_day()
	if h < 4.5 or h >= 21.0:
		return 0.0
	if h < 7.0:
		return smoothstep(4.5, 7.0, h)
	if h < 18.5:
		return 1.0
	return 1.0 - smoothstep(18.5, 21.0, h)


## Тёплый тон у горизонта: утро и вечер
func dusk_tint() -> float:
	var h := hour_of_day()
	if h <= 4.0 or h >= 21.5:
		return 0.0
	return clampf(maxf(1.0 - absf(h - 6.0) / 1.6, 1.0 - absf(h - 19.5) / 1.8), 0.0, 1.0)


func apply_light(loc: Node) -> void:
	if loc == null:
		return
	if loc.has_method("uses_clock_light") and not loc.uses_clock_light():
		return
	var sun := loc.get_node_or_null("Env/Sun") as DirectionalLight3D
	var we := loc.get_node_or_null("Env/WorldEnvironment") as WorldEnvironment
	if sun == null:
		return  # подвал, бункер — свой свет
	if not sun.has_meta("base_energy"):
		sun.set_meta("base_energy", sun.light_energy)
		sun.set_meta("base_color", sun.light_color)
		sun.set_meta("base_rot", sun.rotation)
		if we and we.environment:
			var e := we.environment
			we.set_meta("amb", e.ambient_light_energy)
			we.set_meta("amb_col", e.ambient_light_color)
			we.set_meta("bg", e.background_color)
			we.set_meta("fog", e.fog_light_color)
	var k := daylight()
	var t := dusk_tint()
	var base_rot: Vector3 = sun.get_meta("base_rot")
	var h := hour_of_day()
	# солнце идёт с востока на запад; ночью вместо него — луна, холодная и слабая
	var sun_h := clampf((h - 5.0) / 16.0, 0.0, 1.0)
	sun.rotation = Vector3(deg_to_rad(-lerpf(18.0, 55.0, sin(sun_h * PI))) if k > 0.0 else deg_to_rad(-40.0),
		base_rot.y + deg_to_rad(lerpf(70.0, -70.0, sun_h)), base_rot.z)
	var moon := Color(0.55, 0.65, 0.95)
	var day_col: Color = sun.get_meta("base_color")
	sun.light_color = moon.lerp(day_col.lerp(Color("ffb27a"), t * 0.8), k)
	sun.light_energy = lerpf(0.38, float(sun.get_meta("base_energy")), k)
	if we and we.environment and we.has_meta("amb"):
		var e := we.environment
		e.ambient_light_energy = float(we.get_meta("amb")) * lerpf(0.7, 1.0, k)
		e.ambient_light_color = Color(0.42, 0.48, 0.72).lerp(we.get_meta("amb_col"), k)
		e.background_color = Color(0.04, 0.05, 0.09).lerp(we.get_meta("bg"), k)
		e.fog_light_color = Color(0.12, 0.14, 0.22).lerp((we.get_meta("fog") as Color).lerp(Color("c08a5a"), t * 0.5), k)


# ---------------- расписание жителей ----------------
## Работает ли житель сейчас (по его расписанию)
func on_duty(s: Dictionary) -> bool:
	# автотест: «вечный день» — все на местах, у кого бы какое расписание ни было
	if force_day:
		return true
	var h := hour_of_day()
	var a := float(s.get("from", 9))
	var b := float(s.get("to", 20))
	if b > 24.0:
		return h >= a or h < b - 24.0
	return h >= a and h < b


func schedule_for(loc_id: String, ch_name: String) -> Dictionary:
	var all: Dictionary = DB._load("res://data/schedules.json").get(loc_id, {})
	return all.get(ch_name, {})


## Разослать жителей по местам. instant — сразу (вход в локацию, ожидание);
## иначе те, кто рядом с героем, идут пешком, а дальние просто переставляются.
func update_schedules(instant: bool) -> void:
	var loc = main.location
	if loc == null or not loc.has_method("characters"):
		return
	var cfg: Dictionary = DB._load("res://data/schedules.json").get(loc.location_id, {})
	if cfg.is_empty():
		return
	for nm in cfg:
		var ch: Character = loc.character(nm)
		if ch == null or ch.pose == "dead" or ch.hostile or ch.fighter != null:
			continue
		if loc.has_method("schedule_active") and not loc.schedule_active(ch):
			continue
		var s: Dictionary = cfg[nm]
		if not ch.has_meta("work_pos"):
			ch.set_meta("work_pos", ch.global_position)
			ch.set_meta("work_rot", ch.rotation.y)
			ch.set_meta("work_patrol", ch.patrol)
		var home := _home_of(loc, ch, s)
		var duty := on_duty(s)
		var asleep: bool = ch.get_meta("asleep", false)
		if duty and asleep:
			_wake(loc, ch, home, instant)
		elif not duty and not asleep and not ch.get_meta("going_home", false):
			_send_home(loc, ch, home, instant)


func _home_of(loc: Node, ch: Character, s: Dictionary) -> Vector3:
	if s.has("home"):
		var hp: Array = s.home
		return Vector3(float(hp[0]), 0, float(hp[1]))
	if ch.has_meta("home_pos"):
		return ch.get_meta("home_pos")
	if s.has("home_node") and loc.get_node_or_null("Village/" + str(s.home_node)):
		var hn: Vector3 = (loc.get_node("Village/" + str(s.home_node)) as Node3D).global_position
		ch.set_meta("home_pos", hn)
		return hn
	# ближайшая изба / дом / шалаш
	var best := Vector3.INF
	var vil := loc.get_node_or_null("Village")
	var wp: Vector3 = ch.get_meta("work_pos")
	if vil:
		for b in vil.get_children():
			var n := String(b.name)
			if b is Node3D and (n.begins_with("Izba") or n.begins_with("House") or n.begins_with("Hut") or n.begins_with("Home")):
				if best == Vector3.INF or (b as Node3D).global_position.distance_to(wp) < best.distance_to(wp):
					best = (b as Node3D).global_position
	if best == Vector3.INF:
		best = wp
	ch.set_meta("home_pos", best)
	return best


func _near_hero(p: Vector3) -> bool:
	return main.player and main.player.global_position.distance_to(p) < 22.0


func _send_home(loc: Node, ch: Character, home: Vector3, instant: bool) -> void:
	ch.patrol = PackedVector3Array()
	if instant or not _near_hero(ch.global_position):
		_hide(ch, home)
		return
	ch.set_meta("going_home", true)
	ch.bark(["Пора домой.", "Темнеет. Домой.", "Всё, на сегодня хватит."][randi() % 3])
	ch.move_along(_route(loc, ch.global_position, home), func():
		ch.set_meta("going_home", false)
		_hide(ch, home), 1.4)


func _hide(ch: Character, home: Vector3) -> void:
	ch.stop()
	ch.global_position = home
	ch.set_meta("asleep", true)
	ch.set_meta("going_home", false)
	ch.visible = false
	ch.process_mode = Node.PROCESS_MODE_DISABLED


func _wake(loc: Node, ch: Character, home: Vector3, instant: bool) -> void:
	var wp: Vector3 = ch.get_meta("work_pos")
	ch.set_meta("asleep", false)
	ch.process_mode = Node.PROCESS_MODE_INHERIT
	ch.visible = true
	var done := func():
		ch.global_position = wp
		ch.rotation.y = float(ch.get_meta("work_rot"))
		ch.patrol = ch.get_meta("work_patrol")
	if instant or not _near_hero(home):
		done.call()
		return
	ch.global_position = home
	ch.move_along(_route(loc, home, wp), done, 1.4)


## Путь по сетке ходов (каждый третий гекс), чтобы не идти сквозь стены
func _route(loc: Node, from: Vector3, to: Vector3) -> Array:
	var g = loc.grid
	if g == null:
		return [to]
	var a: Vector2i = g.nearest_free(from)
	var b: Vector2i = g.nearest_free(to)
	var bf: Dictionary = g.bfs(a, {}, -1, 20000)
	var hexes: Array = g.path_to(bf, b)
	if hexes.is_empty():
		return [to]
	var pts := []
	for i in range(0, hexes.size(), 3):
		pts.append(g.to_world(hexes[i]))
	pts.append(to)
	return pts
