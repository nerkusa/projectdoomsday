class_name Social
extends Node
## Жизнь вокруг героя: жители сами бросают реплики, с ними можно поболтать
## и подружиться, драку можно отговорить, а нападение на мирных поднимает
## всё поселение — вооружённые бьются, остальные бегут, и место пустеет навсегда.

const BARK_EVERY := 3.5
const BARK_COOLDOWN := 45.0
const BARK_DIST := 8.0
const PAL := 5
const FRIEND := 10

var main: Node
## Выключается в автотесте сюжета: там бои должны начинаться сразу
var parley_enabled := true
## Жители без дела бродят рядом со своим местом (в автотесте выключено)
var idle_enabled := true
var _idle_t := 0.0
var _bark_t := 0.0
var _said := {}
var _parley_with: Character = null


func setup(m: Node) -> void:
	main = m


# ---------------- общее ----------------
func _st() -> Dictionary:
	if not Game.world.has("_social"):
		Game.world["_social"] = {"aff": {}, "chat_day": {}, "rewarded": {}}
	return Game.world["_social"]


func key(ch: Character) -> String:
	return "%s/%s" % [main.location.location_id, ch.uid()]


func affinity(ch: Character) -> int:
	return int(_st().aff.get(key(ch), 0))


## Подпись к имени при наведении
func tier_text(ch: Character) -> String:
	var a := affinity(ch)
	if a >= FRIEND:
		return " · друг"
	if a >= PAL:
		return " · приятель"
	return ""


## Человек ли это (с ним можно говорить): не зверь, не мишень, не чучело
static func talks(ch: Character) -> bool:
	var t: Dictionary = ch.tpl
	if t.get("static", false) or t.get("dummy", false):
		return false
	if str(t.get("weapon", "")) in ["bite", "claws"]:
		return false
	return int(t.get("stats", {}).get("INT", 3)) >= 2


## Может ли взять оружие и драться (детей и безоружных стариков — нет)
static func can_fight(ch: Character) -> bool:
	if ch.char_id.contains("kid") or ch.char_id.contains("old"):
		return false
	if ch.armed or ch.hostile:
		return true
	return not (str(ch.tpl.get("weapon", "fists")) in ["", "fists"])


func _pick(arr: Array) -> String:
	return str(arr[randi() % arr.size()]) if not arr.is_empty() else "…"


func _barks() -> Dictionary:
	var b: Dictionary = DB._load("res://data/barks.json")
	# в Нахарро все свои: свои реплики вместо «чужак», «ходок» и «ты не местный»
	if main and main.location and str(main.location.location_id).begins_with("nakharro") and b.has("nakharro"):
		b = b.duplicate()
		b.merge(b.nakharro, true)
	return b


func _peaceful(ch: Character) -> bool:
	return is_instance_valid(ch) and ch.visible and ch.pose != "dead" and not ch.hostile and not ch.is_player \
		and not ch.is_in_group("range_targets") and talks(ch)


# ---------------- фоновые реплики ----------------
func _process(delta: float) -> void:
	if main == null or main.location == null or main.player == null or main.combat.on or main.ui_blocked():
		return
	_idle_t -= delta
	if _idle_t <= 0.0:
		_idle_t = 2.0
		if idle_enabled:
			_idle_step()
	_bark_t -= delta
	if _bark_t > 0.0:
		return
	_bark_t = BARK_EVERY
	var now := Time.get_ticks_msec() / 1000.0
	var cands := []
	for ch in main.location.characters():
		if not _peaceful(ch) or ch.pose == "sleep" or ch.barking():
			continue
		# друг детства говорит своё (обучение), фоновые реплики ему ни к чему
		if ch.char_id.begins_with("friend"):
			continue
		if ch.global_position.distance_to(main.player.global_position) > BARK_DIST:
			continue
		if now - float(_said.get(ch.get_instance_id(), -999.0)) < BARK_COOLDOWN:
			continue
		cands.append(ch)
	if cands.is_empty() or randf() > 0.45:
		return
	var ch: Character = cands[randi() % cands.size()]
	_said[ch.get_instance_id()] = now
	ch.bark(ambient_line(ch))


## Житель без дела: отойти на пару шагов и вернуться, оглядеться, переминаться.
## Только стоящие на своём месте (не в обходе, не сидят, не заняты) и рядом с героем.
func _idle_step() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	for ch in main.location.characters():
		if not _peaceful(ch) or ch.moving or ch.pose != "" or not ch.patrol.is_empty() or ch.barking() or ch.char_id.begins_with("friend"):
			continue
		if ch.global_position.distance_to(main.player.global_position) > 24.0:
			continue
		if main.dialog.visible and main.dialog.speaker == ch:
			continue
		var next_t := float(ch.get_meta("idle_next", 0.0))
		if next_t == 0.0:
			ch.set_meta("idle_next", now + randf_range(8.0, 25.0))
			continue
		if now < next_t:
			continue
		ch.set_meta("idle_next", now + randf_range(18.0, 40.0))
		var home: Vector3 = ch.get_meta("idle_home", ch.global_position)
		# расписание увело на другое место — бродить уже вокруг нового
		if not ch.has_meta("idle_home") or ch.global_position.distance_to(home) > 5.0:
			ch.set_meta("idle_home", ch.global_position)
			continue
		if ch.global_position.distance_to(home) > 0.6:
			# вернуться на место и встать как стоял
			var rot: float = ch.get_meta("idle_rot", ch.rotation.y)
			ch.move_along([home], func(): ch.rotation.y = rot, 1.2)
			return
		ch.set_meta("idle_rot", ch.rotation.y)
		if randf() < 0.4:
			ch.face_towards(ch.global_position + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)))
			return
		var g: HexGrid = main.location.grid
		for t in 6:
			var q := home + Vector3(randf_range(-3.0, 3.0), 0, randf_range(-3.0, 3.0))
			if g.is_free(g.from_world(q)) and main.location.grid.line_clear(home + Vector3(0, 0.5, 0), q + Vector3(0, 0.5, 0), main.space()):
				ch.move_along([q], Callable(), 1.1)
				return
		return


## Что скажет житель сам по себе: страх, раны героя, дружба, время суток, свой тип
func ambient_line(ch: Character) -> String:
	var b := _barks()
	if main.location.ws().misc.get("hostile", false):
		return _pick(b.get("fear", []))
	if Game.hero_hp() < Game.hero_max() * 0.4 and randf() < 0.6:
		return _pick(b.get("hurt", []))
	var wl: Array = b.get("weather", {}).get(Weather.kind(), [])
	if not wl.is_empty() and Weather.outdoor() and randf() < 0.5:
		return _pick(wl)
	var a := affinity(ch)
	if a >= FRIEND and randf() < 0.7:
		return _pick(b.get("friend", []))
	if a >= PAL and randf() < 0.6:
		return _pick(b.get("pal", []))
	var h := fmod(Clock.hours(), 24.0)
	if randf() < 0.2:
		if h >= 5.0 and h < 10.0:
			return _pick(b.get("morning", []))
		if h >= 18.0:
			return _pick(b.get("evening", []))
	var tl: Array = b.get("temper", {}).get(temper(ch), [])
	if not tl.is_empty() and randf() < 0.3:
		return _pick(tl)
	var amb: Dictionary = b.get("ambient", {})
	return _pick(amb.get(archetype(ch), amb.get("man", [])))


## Характер жителя (characters.json → temper). В Нахарро все свои — книжные внуки учёных.
static func temper(ch: Character) -> String:
	if ch == null:
		return "simple"
	var loc = ch.get_tree().get_first_node_in_group("location") if ch.is_inside_tree() else null
	if loc and str(loc.location_id).begins_with("nakharro") and not ch.hostile:
		return "intel"
	return str(ch.tpl.get("temper", "simple"))


static func archetype(ch: Character) -> String:
	var id := ch.char_id
	for k in ["guard", "cop", "sentry", "defender", "jaeger", "merc", "chief"]:
		if id.contains(k):
			return "guard"
	if id.contains("kid"):
		return "kid"
	if id.contains("old") or id.contains("granny") or id == "ded":
		return "old"
	for k in ["trader", "merchant", "seller", "store", "butcher", "dealer", "barman", "innkeeper"]:
		if id.contains(k) or ch.display_name.to_lower().contains("торгов"):
			return "trader"
	for k in ["worker", "porter", "stoker", "fisher", "herder", "smith"]:
		if id.contains(k):
			return "worker"
	if ch.tpl.get("female", false) or id.ends_with("_f") or id.contains("_f1") or id.contains("_f2") or id.contains("_f3") or id.contains("woman"):
		return "woman"
	return "man"


# ---------------- переговоры ----------------
func can_parley(ch: Character) -> bool:
	if not parley_enabled or not talks(ch) or ch.tpl.get("no_parley", false):
		return false
	var lid: String = main.location.location_id
	if lid == "nakharro" or lid.begins_with("nakharro"):
		return false
	if main.location.has_method("allow_parley") and not main.location.allow_parley(ch):
		return false
	return not main.location.ws().misc.has("parley_" + ch.uid())


func _squad(ch: Character) -> Array:
	var out := [ch]
	if ch.squad != "":
		for o in main.location.characters():
			if o != ch and o.squad == ch.squad and o.pose != "dead" and o.visible:
				out.append(o)
	return out


## Враг заметил героя — до выстрелов можно договориться
func parley(ch: Character) -> void:
	_parley_with = ch
	main.location.ws().misc["parley_" + ch.uid()] = true
	var n := _squad(ch).size()
	var dc := clampi(11 + n - 1 + (3 if main.location.ws().misc.get("hostile", false) else 0), 10, 18)
	var price := 10 + 5 * n
	var b := _barks()
	var opts := [
		{"text": "[Убеждение] «Я не за вами. Разойдёмся — и никто не ляжет.»", "check": {"skill": "Убеждение", "stat": "CHA", "dc": dc}, "success": "ok", "fail": "fail", "xp_success": 30},
		{"text": "[Запугивание] «Посмотри на меня. Тебе правда это надо?»", "check": {"skill": "Запугивание", "stat": "BODY", "dc": dc + 1}, "success": "scare", "fail": "fail", "xp_success": 30},
		{"text": "[Обман] «Свои! Меня Кирк прислал — проверить посты.»", "check": {"skill": "Обман", "stat": "CHA", "dc": dc + 1}, "success": "ok", "fail": "fail", "xp_success": 30},
	]
	if Game.item_count("rubles") >= price:
		opts.append({"text": "Откупиться: %d ₽" % price, "action": "parley_pay:%d" % price, "next": "paid"})
	opts.append({"text": "[Напасть]", "action": "parley_fight"})
	var d := {"speaker": ch.display_name, "nodes": {
		"start": {"text": _pick(b.get("parley_open", [])), "options": opts},
		"ok": {"text": _pick(b.get("parley_ok", [])), "options": [{"text": "[Уйти своей дорогой]", "action": "parley_ok"}]},
		"scare": {"text": _pick(b.get("parley_scare", [])), "options": [{"text": "[Смотреть, как уходят]", "action": "parley_flee"}]},
		"paid": {"text": _pick(b.get("parley_paid", [])), "options": [{"text": "[Пройти]", "action": "parley_ok"}]},
		"fail": {"text": _pick(b.get("parley_fail", [])), "options": [{"text": "[Драться]", "action": "parley_fight"}]},
	}}
	main.player.face_towards(ch.global_position)
	ch.face_towards(main.player.global_position)
	main.dialog.open_data(d, "start", ch)


func _calm(ch: Character) -> void:
	for o in _squad(ch):
		o.hostile = false
		o.aggro_radius = 0.0
		o.attitude = "neutral"
		o.show_cone(false, 0.0)
		main.location.ws().misc["calm_" + o.uid()] = true


# ---------------- болтовня и подарки ----------------
const GIFTS := {"pipe_tobacco": 3, "beer": 3, "jam": 3, "tea": 2, "canned": 2, "dried_fish": 2, "rusks": 1, "berries": 1, "salt": 2,
	"t_button": 3, "t_cross": 4, "t_lighter": 4, "t_photo": 4, "t_badge": 4, "t_whistle": 3, "t_elk": 4, "t_beads": 4, "t_coin": 3,
	"t_dice": 3, "t_harmonica": 5, "t_postcard": 3, "t_comb": 3, "t_ribbon": 4, "candle": 2}


func gifts_on_hand() -> Array:
	var out := []
	for k in GIFTS:
		if Game.item_count(k) > 0:
			out.append(k)
	return out


func can_chat(ch: Character) -> bool:
	return _peaceful(ch) and not main.location.ws().misc.get("hostile", false)


func chatted_today(ch: Character) -> bool:
	return int(_st().chat_day.get(key(ch), -1)) == int(Clock.hours() / 24.0)


func chat(ch: Character) -> void:
	var b := _barks()
	var st: Dictionary = b.get("smalltalk", {})
	var opts := []
	if not chatted_today(ch):
		opts.append({"text": "[Убеждение] Поддержать разговор", "check": {"skill": "Убеждение", "stat": "CHA", "dc": 10}, "success": "good", "fail": "meh"})
	opts.append({"text": "Что тут нового?", "next": "news"})
	if affinity(ch) >= FRIEND:
		opts.append({"text": "Можно у тебя передохнуть?", "next": "rest"})
	opts.append({"text": "[Уйти]", "next": null})
	var news := "Да ничего. Живём помаленьку."
	var lid: String = main.location.location_id
	var rumors: Array = b.get("rumors", {}).get("sungar" if lid.begins_with("sungar") else lid, [])
	var plain := rumors.filter(func(r): return not r.has("once"))
	if not plain.is_empty():
		news = str(plain[randi() % plain.size()].text)
	var d := {"speaker": ch.display_name, "nodes": {
		"start": {"text": _pick(st.get("open", [])) + _tier_note(ch), "options": opts},
		"good": {"text": _pick(st.get("good", [])), "action": "aff_chat:2", "options": [{"text": "[Дальше]", "next": "start"}]},
		"meh": {"text": _pick(st.get("meh", [])), "action": "aff_chat:0", "options": [{"text": "[Уйти]", "next": null}]},
		"news": {"text": news, "options": [{"text": "[Дальше]", "next": "start"}]},
		"rest": {"text": _pick(st.get("rest", [])), "options": [{"text": "[Отдохнуть пару часов]", "action": "heal_rest", "next": null}]},
	}}
	main.player.face_towards(ch.global_position)
	if ch.pose == "":
		ch.stop()
		ch.face_towards(main.player.global_position)
	main.dialog.open_data(d, "start", ch)


func _tier_note(ch: Character) -> String:
	var a := affinity(ch)
	if a >= FRIEND:
		return "\n(Вы — старые друзья.)"
	if a >= PAL:
		return "\n(Он тебе рад.)" if archetype(ch) != "woman" else "\n(Она тебе рада.)"
	return ""


func gift(ch: Character) -> void:
	var opts := []
	for k in gifts_on_hand().slice(0, 5):
		opts.append({"text": "Подарить: %s" % DB.item_name(k), "action": "gift:" + k, "next": null})
	opts.append({"text": "[Передумать]", "next": null})
	var d := {"speaker": ch.display_name, "nodes": {"start": {"text": "(Что подарить?)", "options": opts}}}
	main.dialog.open_data(d, "start", ch)


func _add_aff(ch: Character, n: int) -> void:
	var k := key(ch)
	var before := affinity(ch)
	var after := before + n
	_st().aff[k] = after
	if before < PAL and after >= PAL:
		Game.log_line("%s теперь тебе приятель." % ch.display_name, "", "hit")
		Game.grant_xp(20)
	if before < FRIEND and after >= FRIEND and not _st().rewarded.has(k):
		_st().rewarded[k] = true
		Game.log_line("%s теперь тебе друг." % ch.display_name, "", "hit")
		Game.grant_xp(50)
		var pool := ["medkit", "bandage", "canned", "ammo9", "t_coin", "tea", "rubles"]
		var it: String = pool[randi() % pool.size()]
		var cnt := 15 if it == "rubles" else (6 if it == "ammo9" else 1)
		Game.add_item(it, cnt)
		ch.bark(_pick(_barks().get("friend_gift", [])))
		Game.log_line("%s дарит: %s%s" % [ch.display_name, DB.item_name(it), (" ×%d" % cnt) if cnt > 1 else ""], "", "hit")


# ---------------- нападение на мирных ----------------
## Герой напал на мирного: поселение поднимается. Вооружённые рядом — в бой,
## остальные бегут прочь и больше не вернутся; место запоминает резню.
func provoke(victim: Character, fighters: Array) -> void:
	var st: Dictionary = main.location.ws()
	if not st.misc.get("hostile", false):
		st.misc["hostile"] = true
		Game.change_rep(-15, "напал на мирных")
		Game.log_line("Поселение видело, что ты сделал.", "", "miss")
	victim.hostile = true
	var b := _barks()
	for o in main.location.characters():
		if o == victim or not _peaceful(o):
			continue
		var d: float = o.global_position.distance_to(main.player.global_position)
		if can_fight(o):
			o.hostile = true
			o.aggro_radius = 14.0
			o.set_held(str(o.tpl.get("weapon", "fists")))
			if d < 22.0 and not fighters.has(o):
				fighters.append(o)
		else:
			flee(o)
			if d < 12.0 and randf() < 0.5:
				o.bark(_pick(b.get("fear", [])))


## Бежать к ближнему краю карты и исчезнуть
func flee(o: Character) -> void:
	var r: Rect2 = main.location.map_rect
	var p: Vector3 = o.global_position
	var away: Vector3 = p - main.player.global_position
	away.y = 0
	var tgt := Vector3(r.position.x + 1.0 if away.x < 0 else r.end.x - 1.0, 0, clampf(p.z, r.position.y + 1, r.end.y - 1))
	if absf(away.z) > absf(away.x):
		tgt = Vector3(clampf(p.x, r.position.x + 1, r.end.x - 1), 0, r.position.y + 1.0 if away.z < 0 else r.end.y - 1.0)
	main.location.ws().misc["gone_" + o.uid()] = true
	o.pose = ""
	o.move_along([tgt], func(): o.visible = false, 4.2)


## При входе в место, где была резня: вооружённые встречают в штыки, остальных нет
func apply_hostile(loc: Node) -> void:
	if not loc.ws().misc.get("hostile", false):
		return
	for o in loc.characters():
		if o.pose == "dead" or not o.visible or o.is_player or not talks(o):
			continue
		if can_fight(o):
			o.hostile = true
			o.aggro_radius = 14.0
		else:
			o.visible = false
			loc.ws().misc["gone_" + o.uid()] = true


# ---------------- действия из разговоров ----------------
func on_action(a: String, sp: Character) -> bool:
	if a == "parley_ok" or a == "parley_flee":
		var ch: Character = sp if sp else _parley_with
		main.dialog.close()
		if ch:
			_calm(ch)
			if a == "parley_flee":
				for o in _squad(ch):
					flee(o)
			Game.log_line("Обошлось без крови.", "", "hit")
		return true
	if a.begins_with("parley_pay:"):
		Game.remove_item("rubles", int(a.get_slice(":", 1)))
		return true
	if a == "parley_fight":
		var ch2: Character = sp if sp else _parley_with
		main.dialog.close()
		if ch2:
			main.start_fight([ch2])
		return true
	if a.begins_with("aff_chat:"):
		if sp:
			_st().chat_day[key(sp)] = int(Clock.hours() / 24.0)
			_add_aff(sp, int(a.get_slice(":", 1)))
		return true
	if a.begins_with("gift:"):
		var it := a.get_slice(":", 1)
		if sp and Game.remove_item(it):
			Game.log_line("Подарено: %s" % DB.item_name(it))
			sp.bark(_pick(_barks().get("gift_thanks", [])))
			_add_aff(sp, int(GIFTS.get(it, 1)))
		return true
	return false
