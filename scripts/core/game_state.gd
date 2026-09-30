extends Node
## Автозагрузка Game: состояние героя и мира, журнал, сохранения.

signal log_added(head: String, detail: String, cls: String)
signal hero_changed
signal quest_changed(id: String)
signal flag_changed(id: String)
signal level_up(level: int)

const SAVE_DIR := "user://saves/"
const SETTINGS_PATH := "user://settings.json"

var hero: Dictionary = {}
## Состояние мира по локациям: {"nakharro": {"dead": {...}, "looted": {...}, "picked": {...}}}
var world: Dictionary = {}
## show_rolls — показывать ли броски и формулы в журнале (по умолчанию нет)
var settings := {"text_speed": "normal", "show_rolls": false}


func _ready() -> void:
	randomize()
	_load_settings()
	new_hero()


# ---------------- герой ----------------
func new_hero() -> void:
	var c := Rules.random_core()
	hero = {
		"name": "Безымянный",
		"level": 1, "xp": 0,
		"stats": c.stats, "skills": c.skills,
		"hp_roll": Rules.r1(10), "cur_hp": -1,
		"locked": false, "stat_pts": 0, "skill_pts": 0,
		"locked_stats": {}, "locked_skills": {},
		"owned": ["father_pistol"], "hands": ["father_pistol", "fists"], "active": 0,
		"mag": {"father_pistol": 8}, "ammo": {"9мм": 8, "7.62": 0},
		"items": {},
		"cassettes": [],
		"flags": {}, "q": {}, "notes": [],
		"sneak": false,
		"rep": 0,
		"location": "nakharro", "pos": [],
	}
	world = {}
	hero_changed.emit()


func hero_max() -> int:
	return Rules.max_hp(effective_stats(), int(hero.hp_roll))


## Характеристики с прибавками от кассет — для боя, ХП, ОД и проверок
func effective_stats() -> Dictionary:
	var out: Dictionary = hero.stats.duplicate()
	var b := stat_bonus()
	for k in b:
		out[k] = clampi(int(out.get(k, 1)) + int(b[k]), 1, 12)
	return out


func hero_hp() -> int:
	var c := int(hero.cur_hp)
	return hero_max() if c < 0 else mini(c, hero_max())


func set_hero_hp(v: int) -> void:
	hero.cur_hp = clampi(v, 0, hero_max())
	hero_changed.emit()


func rep() -> int:
	return int(hero.get("rep", 0))


## Поступок меняет молву — если его кто-то видел (seen) или он слишком велик, чтобы спрятать (big)
func change_rep(d: int, why := "", seen := true, big := false) -> void:
	if d == 0:
		return
	if not seen and not big:
		if why != "":
			log_line("Никто не видел: %s" % why, "молва не изменилась")
		return
	var old := rep()
	hero.rep = clampi(old + d, -100, 100)
	var head := "Молва %s%d" % ["+" if d > 0 else "−", absi(d)]
	if why != "":
		head += ": " + why
	log_line(head, "%d → %d (%s)" % [old, int(hero.rep), Rules.rep_label(int(hero.rep))], "hit" if d > 0 else "miss")
	hero_changed.emit()


func stat_pool() -> int:
	return Rules.STAT_POOL + Rules.earned(int(hero.level)).st


func skill_pool() -> int:
	return Rules.SKILL_POOL + Rules.earned(int(hero.level)).sk


func stat_cap() -> int:
	return 10 if int(hero.level) > 1 else 8


func grant_xp(n: int) -> String:
	hero.xp = int(hero.xp) + n
	var note := ""
	while int(hero.level) < Rules.MAX_LEVEL and int(hero.xp) >= Rules.xp_for_level(int(hero.level) + 1):
		hero.level = int(hero.level) + 1
		var rw := Rules.level_reward(int(hero.level))
		hero.skill_pts = int(hero.skill_pts) + rw.skill
		hero.locked_stats = hero.stats.duplicate()
		hero.locked_skills = hero.skills.duplicate()
		note += " Уровень %d: +%d очк. навыков — открой «Дело» в КПК." % [hero.level, rw.skill]
		level_up.emit(int(hero.level))
	hero_changed.emit()
	return note


# ---------------- журнал ----------------
func log_line(head: String, detail := "", cls := "") -> void:
	log_added.emit(head, detail, cls)


# ---------------- флаги и задания ----------------
func flag(id: String) -> bool:
	return bool(hero.flags.get(id, false))


func flag_value(id: String, def = null):
	return hero.flags.get(id, def)


func set_flag(id: String, v = true) -> void:
	hero.flags[id] = v
	flag_changed.emit(id)
	hero_changed.emit()


func quest_stage(id: String) -> int:
	return int(hero.q.get(id, 0))


func set_quest(id: String, stage: int) -> void:
	if quest_stage(id) == stage:
		return
	hero.q[id] = stage
	var q: Dictionary = DB.quests.get(id, {})
	var st: Dictionary = q.get("stages", {})
	var txt: String = st.get(str(stage), "")
	var title: String = q.get("title", id)
	if stage >= int(q.get("done_stage", 999)):
		log_line("Задание «%s» выполнено." % title, "", "hit")
	elif txt != "":
		log_line("Задание «%s»: %s" % [title, txt], "", "hit")
	quest_changed.emit(id)
	hero_changed.emit()


func add_note(text: String) -> void:
	if not hero.notes.has(text):
		hero.notes.append(text)
		log_line("Новая запись на ленте.", text.left(60) + ("…" if text.length() > 60 else ""))
		hero_changed.emit()


# ---------------- инвентарь ----------------
func item_count(id: String) -> int:
	if DB.weapons.has(id):
		return hero.owned.count(id)
	if id == "ammo9":
		return int(hero.ammo.get("9мм", 0))
	if id == "ammo762":
		return int(hero.ammo.get("7.62", 0))
	return int(hero.items.get(id, 0))


func add_item(id: String, n := 1) -> void:
	if DB.weapons.has(id):
		if not hero.owned.has(id):
			hero.owned.append(id)
			if hero.hands[hero.active] == "fists":
				hero.hands[hero.active] = id
			elif hero.hands[1 - int(hero.active)] == "fists":
				hero.hands[1 - int(hero.active)] = id
	elif id == "ammo9":
		hero.ammo["9мм"] = int(hero.ammo.get("9мм", 0)) + n
	elif id == "ammo762":
		hero.ammo["7.62"] = int(hero.ammo.get("7.62", 0)) + n
	else:
		hero.items[id] = int(hero.items.get(id, 0)) + n
	auto_reload()
	hero_changed.emit()


func remove_item(id: String, n := 1) -> bool:
	if DB.weapons.has(id):
		if not hero.owned.has(id):
			return false
		hero.owned.erase(id)
		for i in 2:
			if hero.hands[i] == id:
				hero.hands[i] = "fists"
		hero_changed.emit()
		return true
	var have := item_count(id)
	if have < n:
		return false
	if id == "ammo9":
		hero.ammo["9мм"] = have - n
	elif id == "ammo762":
		hero.ammo["7.62"] = have - n
	else:
		hero.items[id] = have - n
		if int(hero.items[id]) <= 0:
			hero.items.erase(id)
	hero_changed.emit()
	return true


func hero_wkey() -> String:
	return str(hero.hands[int(hero.active)])


func hero_weapon() -> Dictionary:
	return DB.weapon(hero_wkey())


## Вне боя магазины добиваются патронами сами (как в прототипе)
func auto_reload() -> void:
	for k in hero.owned:
		if not DB.is_gun(k):
			continue
		var w := DB.weapon(k)
		var have := int(hero.ammo.get(w.ammo, 0))
		var need := int(w.mag) - int(hero.mag.get(k, 0))
		var n := mini(need, have)
		if n > 0:
			hero.mag[k] = int(hero.mag.get(k, 0)) + n
			hero.ammo[w.ammo] = have - n


# ---------------- мир ----------------
func wstate(loc: String) -> Dictionary:
	if not world.has(loc):
		world[loc] = {"dead": {}, "looted": {}, "picked": {}, "misc": {}}
	return world[loc]


# ---------------- проверки навыков ----------------
## Бросок d10 + характеристика + навык против сложности (на 10 взрывается, на 1 — провал).
## Старые имена (DEX, «Взлом замков»…) переводятся в новые.
func skill_check(label: String, stat: String, skill: String, dc: int, bonus := 0) -> bool:
	stat = Rules.norm_stat(stat)
	skill = Rules.norm_skill(skill)
	label = Rules.norm_skill(label)
	var r := Rules.roll_hit()
	var sv := int(hero_stat(stat))
	var kv := int(effective_skills().get(skill, 0))
	var t: int = r.d + sv + kv + bonus
	var ok: bool = t >= dc and not r.fumble
	log_line("[%s] %s" % [label, "успех" if ok else "провал"],
		"d10(%d) + %s(%d) + %s(%d)%s = %d против %d" % [r.d, Rules.stat_name(stat), sv, skill, kv,
		(" + бонус(%d)" % bonus) if bonus else "", t, dc], "hit" if ok else "miss")
	return ok


## Характеристика героя с учётом кассет (+1 к характеристике)
func hero_stat(key: String) -> int:
	key = Rules.norm_stat(key)
	return clampi(int(hero.stats.get(key, 1)) + int(stat_bonus().get(key, 0)), 1, 12)


# ---------------- кассеты ----------------
## КПК: 10 слотов. Браслет Эллэя поначалу держит только 2 рабочих, +1 за уровень.
const CAS_SLOTS := 10


func cas_working() -> int:
	return clampi(1 + int(hero.level), 2, CAS_SLOTS)


func cas_info(id: String) -> Dictionary:
	return DB.items.get(id, {}).get("cassette", {})


func is_cassette(id: String) -> bool:
	return DB.items.has(id) and DB.items[id].has("cassette")


## Вставленные и работающие (в рабочих слотах) кассеты
func cas_active() -> Array:
	var c: Array = hero.get("cassettes", [])
	return c.slice(0, cas_working())


func cas_has_tag(tag: String) -> bool:
	for id in cas_active():
		if tag in cas_info(id).get("tags", []):
			return true
	return false


func cas_insert(id: String) -> bool:
	var c: Array = hero.get("cassettes", [])
	if c.size() >= CAS_SLOTS or item_count(id) <= 0:
		return false
	hero.items[id] = int(hero.items[id]) - 1
	if int(hero.items[id]) <= 0:
		hero.items.erase(id)
	c.append(id)
	hero.cassettes = c
	log_line("Кассета вставлена: %s" % DB.item_name(id), "" if c.size() <= cas_working() else "слот заблокирован — браслет ещё не принял её", "hit")
	hero_changed.emit()
	return true


func cas_eject(i: int) -> void:
	var c: Array = hero.get("cassettes", [])
	if i < 0 or i >= c.size():
		return
	var id: String = c[i]
	c.remove_at(i)
	hero.cassettes = c
	hero.items[id] = int(hero.items.get(id, 0)) + 1
	log_line("Кассета вынута: %s" % DB.item_name(id))
	hero_changed.emit()


## Прибавки к характеристикам от работающих кассет
func stat_bonus() -> Dictionary:
	var out := {}
	for id in cas_active():
		var st: Dictionary = cas_info(id).get("stats", {})
		for k in st:
			out[k] = int(out.get(k, 0)) + int(st[k])
	return out


func skill_bonus() -> Dictionary:
	var out := {}
	for id in cas_active():
		var sk: Dictionary = cas_info(id).get("skills", {})
		for k in sk:
			out[k] = int(out.get(k, 0)) + int(sk[k])
	return out


## Навыки с прибавками от кассет — для боя и проверок
func effective_skills() -> Dictionary:
	var out: Dictionary = hero.skills.duplicate()
	var b := skill_bonus()
	for k in b:
		out[k] = mini(12, int(out.get(k, 0)) + int(b[k]))
	return out


# ---------------- сохранения ----------------
func save_game(slot := "auto", extra := {}) -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var data := {"version": 1, "time": Time.get_datetime_string_from_system(false, true),
		"hero": hero, "world": world}
	data.merge(extra)
	var f := FileAccess.open(SAVE_DIR + slot + ".json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "\t"))


func has_save(slot := "auto") -> bool:
	return FileAccess.file_exists(SAVE_DIR + slot + ".json")


func save_info(slot := "auto") -> Dictionary:
	if not has_save(slot):
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(SAVE_DIR + slot + ".json"))
	if not d is Dictionary:
		return {}
	var h: Dictionary = d.get("hero", {})
	return {"time": d.get("time", ""), "name": h.get("name", ""), "level": int(h.get("level", 1))}


func load_game(slot := "auto") -> bool:
	if not has_save(slot):
		return false
	var d = JSON.parse_string(FileAccess.get_file_as_string(SAVE_DIR + slot + ".json"))
	if not d is Dictionary or not d.has("hero"):
		return false
	hero = _fix_numbers(d.hero)
	world = d.get("world", {})
	# ключи, которых могло не быть в старых сохранениях
	var base := hero.duplicate()
	new_hero()
	for k in hero:
		if not base.has(k):
			base[k] = hero[k]
	hero = base
	hero.stats = Rules.normalize_stats(hero.stats)
	hero.skills = Rules.normalize_skills(hero.skills)
	hero.locked_stats = Rules.normalize_stats(hero.locked_stats) if not hero.locked_stats.is_empty() else {}
	hero.locked_skills = Rules.normalize_skills(hero.locked_skills)
	hero.stat_pts = 0
	world = d.get("world", {})
	hero_changed.emit()
	return true


## JSON превращает целые числа в дробные — возвращаем как было
func _fix_numbers(v):
	if v is Dictionary:
		var out := {}
		for k in v:
			out[k] = _fix_numbers(v[k])
		return out
	if v is Array:
		var a := []
		for x in v:
			a.append(_fix_numbers(x))
		return a
	if v is float and is_equal_approx(v, round(v)):
		return int(v)
	return v


func _load_settings() -> void:
	if FileAccess.file_exists(SETTINGS_PATH):
		var d = JSON.parse_string(FileAccess.get_file_as_string(SETTINGS_PATH))
		if d is Dictionary:
			settings.merge(d, true)
			# раньше броски показывались по умолчанию — прячем один раз
			if not d.has("rolls_v2"):
				settings.show_rolls = false
				settings["rolls_v2"] = true


func save_settings() -> void:
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(settings))
