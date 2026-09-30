class_name Rules
extends RefCounted
## Правила игры: характеристики, навыки, броски, бой — по дизайн-документу (docs/design.md):
## 6 характеристик 1..10, 19 навыков 0..10, бросок d10 + характеристика + навык против сложности
## (на 10 кубик взрывается, на 1 — провал). Бой — из прототипа «Недострой».
## Меняй числа здесь, если хочешь поменять баланс — всё остальное читает их отсюда.

# ---------- характеристики (дизайн-документ: 1..10) ----------
const STATS := [
	{"key": "BODY", "full": "Тело", "hint": "Сила, выносливость, здоровье: ХП, ближний бой, вес, яды и болезни"},
	{"key": "REF", "full": "Реакция", "hint": "Скорость и ловкость рук: ОД в бою, стрельба, уклонение, скрытность, воровство"},
	{"key": "PRC", "full": "Восприятие", "hint": "Внимание и чутьё: ловушки, тайники, следы, свидетели, ложь"},
	{"key": "INT", "full": "Разум", "hint": "Ум и техническая смекалка: терминалы, ремонт, медицина, знания"},
	{"key": "CHA", "full": "Характер", "hint": "Обаяние: убеждение, обман, цены, первое впечатление"},
	{"key": "WILL", "full": "Воля", "hint": "Стойкость духа: страх, радиация, зависимости, паника, допросы"},
]

## Старые характеристики (прототип «Недострой») -> новые
const OLD_STATS := {"DEX": "REF", "EMP": "CHA", "CRA": "INT"}

# ---------- навыки (0..10), по характеристикам ----------
const SKILLS := {
	"BODY": ["Ближний бой", "Атлетика", "Запугивание"],
	"REF": ["Огнестрел", "Метание", "Уклонение", "Скрытность", "Воровство"],
	"PRC": ["Внимательность", "Выживание", "Проницательность"],
	"INT": ["Техника", "Механика", "Медицина", "Знания"],
	"CHA": ["Убеждение", "Обман", "Торг"],
	"WILL": ["Выдержка"],
}

## Старые навыки -> новые (сохранения, шаблоны, старые диалоги). Чего нет ни здесь,
## ни в SKILLS — навык убран, его очки пропадают.
const OLD_SKILLS := {
	"Боевое оружие": "Ближний бой", "Простое оружие": "Ближний бой", "Рукопашный бой": "Ближний бой",
	"Огнестрельное оружие": "Огнестрел", "Стрельба": "Огнестрел", "Дальний бой": "Огнестрел",
	"Метательное оружие": "Метание",
	"Ловкость рук": "Воровство", "Взлом замков": "Воровство", "Слежка": "Скрытность",
	"Акробатика": "Атлетика", "Сопротивление": "Выдержка", "Самообладание": "Выдержка",
	"Стойкость": "Выдержка", "Сопротивление страху": "Выдержка",
	"Расследование": "Внимательность", "Навигация": "Выживание",
	"Азартные игры": "Торг", "Выступление": "Убеждение", "Обольщение": "Убеждение",
	"Первая помощь": "Медицина", "Химия": "Медицина", "Алхимия": "Медицина",
	"Наука": "Знания", "Слесарное дело": "Механика", "Кузнечное дело": "Механика",
}

## Тип оружия -> навык
const WEAPON_SKILL := {
	"Battle": "Ближний бой",
	"Simple": "Ближний бой",
	"Brawl": "Ближний бой",
	"Guns": "Огнестрел",
	"Archery": "Метание",
	"Thrown": "Метание",
}

# ---------- молва ----------
## Одна общая шкала −100..100: что о герое знают люди. Меняется от поступков, но только
## при свидетелях (большие поступки — всегда). В финале даёт имя героя.
const REP_LEVELS := [
	[60, "Легенда"],
	[25, "Добрая слава"],
	[-24, "Никто не знает"],
	[-59, "Дурная слава"],
	[-100, "Чудовище"],
]


static func rep_label(v: int) -> String:
	for lv in REP_LEVELS:
		if v >= int(lv[0]):
			return lv[1]
	return REP_LEVELS[-1][1]


## Имя, под которым запомнят героя (финальный слайд)
static func rep_title(v: int) -> String:
	if v >= 30:
		return "Эллэй-Боотур"
	if v <= -30:
		return "Моҕус"
	return "Боотур"


## Бартер: во сколько раз торговец завышает свои вещи (x) и занижает твои (y).
## Помогают Характер и Торг; добрая молва — скидка, дурная — наценка.
static func trade_mults(cha: int, torg: int, rep: int) -> Vector2:
	var k := (cha + torg - 6) * 0.025
	if rep >= 30:
		k += 0.08
	elif rep <= -30:
		k -= 0.1
	return Vector2(clampf(1.2 - k, 1.0, 1.5), clampf(0.8 + k, 0.5, 0.95))


const ZONES := [
	{"r": 1, "name": "Голова", "mult": 3, "slot": "head", "ignore_armor": false},
	{"r": 2, "name": "Шея", "mult": 2, "slot": "head", "ignore_armor": false},
	{"r": 3, "name": "Торс", "mult": 1, "slot": "body", "ignore_armor": false},
	{"r": 4, "name": "Руки", "mult": 1, "slot": "body", "ignore_armor": false},
	{"r": 5, "name": "Пах", "mult": 2, "slot": "body", "ignore_armor": true},
	{"r": 6, "name": "Ноги", "mult": 1, "slot": "body", "ignore_armor": false},
]
## Атака из скрытности (бой начат, пока герой крался): первая атака героя
## умножает модификатор попадания и урон
const SNEAK_MULT := 5
const AIM_PEN := {"Голова": 6, "Шея": 4, "Пах": 4, "Торс": 2, "Руки": 2, "Ноги": 2}

## Уровней 10. За уровень — очки навыков; характеристики с уровнем не растут (только кассеты).
const LEVEL_REWARDS := {
	2: {"stat": 0, "skill": 3}, 3: {"stat": 0, "skill": 3}, 4: {"stat": 0, "skill": 3},
	5: {"stat": 0, "skill": 3}, 6: {"stat": 0, "skill": 3}, 7: {"stat": 0, "skill": 3},
	8: {"stat": 0, "skill": 3}, 9: {"stat": 0, "skill": 3}, 10: {"stat": 0, "skill": 4},
}
const MAX_LEVEL := 10
## Создание героя: очки характеристик (6 × 1..8) и навыков
const STAT_POOL := 30
const SKILL_POOL := 24

const DMG_TYPE_NAMES := {"Д": "дробящий", "Р": "режущий", "К": "колющий", "П": "пуля"}


static func all_skills() -> Array:
	var out := []
	for k in SKILLS:
		for n in SKILLS[k]:
			out.append({"name": n, "stat": k})
	return out


static func stat_name(key: String) -> String:
	for x in STATS:
		if x.key == key:
			return x.full
	return key


static func norm_stat(key: String) -> String:
	return OLD_STATS.get(key, key)


static func norm_skill(n: String) -> String:
	return OLD_SKILLS.get(n, n)


## Характеристики из шаблона или сохранения: старые ключи -> новые (берётся большее),
## недостающие — 1
static func normalize_stats(src: Dictionary) -> Dictionary:
	var out := empty_stats()
	var seen := {}
	for k in src:
		var n := norm_stat(String(k))
		if out.has(n):
			out[n] = int(src[k]) if not seen.has(n) else maxi(int(out[n]), int(src[k]))
			seen[n] = true
	for k in out:
		out[k] = clampi(int(out[k]), 1, 10)
	return out


## Навыки из шаблона или сохранения: старые имена переводятся в новые,
## убранные навыки выкидываются, недостающие заполняются нулями.
static func normalize_skills(src: Dictionary) -> Dictionary:
	var out := empty_skills()
	for k in src:
		var n: String = OLD_SKILLS.get(k, k)
		if out.has(n):
			out[n] = mini(10, maxi(int(out[n]), int(src[k])))
	return out


static func weapon_stat(type: String) -> String:
	return "BODY" if type in ["Brawl", "Battle", "Simple"] else "REF"


static func empty_stats() -> Dictionary:
	var s := {}
	for x in STATS:
		s[x.key] = 1
	return s


static func empty_skills() -> Dictionary:
	var s := {}
	for x in all_skills():
		s[x.name] = 0
	return s


static func sum_stats(s: Dictionary) -> int:
	var t := 0
	for v in s.values():
		t += int(v)
	return t


static func sum_skill_points(s: Dictionary) -> int:
	var t := 0
	for x in all_skills():
		t += int(s.get(x.name, 0))
	return t


# ---------- кубики ----------
static func r1(sides: int) -> int:
	return randi_range(1, sides)


static func roll_dice(expr: String) -> Array:
	## "2d6" -> [4, 1]
	var m := expr.split("d")
	var n := int(m[0])
	var s := int(m[1])
	var out := []
	for i in n:
		out.append(r1(s))
	return out


static func sum_arr(a: Array) -> int:
	var t := 0
	for v in a:
		t += int(v)
	return t


## d10: на 10 кубик взрывается (перебрасываем и складываем), на 1 — провал (1 минус ещё d10).
static func roll_hit() -> Dictionary:
	var base := r1(10)
	if base == 10:
		var total := 10
		while true:
			var n := r1(10)
			total += n
			if n != 10:
				break
		return {"d": total, "crit": true, "fumble": false}
	if base == 1:
		var n2 := r1(10)
		return {"d": 1 - n2, "crit": false, "fumble": true}
	return {"d": base, "crit": false, "fumble": false}


## ХП = Тело × 2 + Реакция × 2 + d10 (d10 бросается один раз и хранится)
static func max_hp(stats: Dictionary, hp_roll: int) -> int:
	return maxi(1, int(stats.get("BODY", 0)) * 2 + int(stats.get("REF", 0)) * 2 + hp_roll)


## ОД: 5 + ⌊Реакция / 2⌋, −1 если ранен ниже 50%
static func ap_for(stats: Dictionary, hp: int, mx: int) -> int:
	return 5 + int(floor(int(stats.get("REF", 0)) / 2.0)) - (1 if hp < mx * 0.5 else 0)


## Штраф раненого к урону: −3 ниже 70% ХП, −5 ниже 50%
static func wound_dmg_penalty(cur: int, mx: int) -> int:
	if mx <= 0:
		return 0
	var p := float(cur) / mx * 100.0
	return 5 if p < 50 else (3 if p < 70 else 0)


## Как броня делит урон: ad — урон броне, hd — урон ХП
static func calc_ae(armor_type: String, dmg_type: String, rd: int) -> Dictionary:
	if armor_type == "none":
		return {"ad": 0, "hd": rd, "desc": "без брони: ХП−%d" % rd}
	match dmg_type:
		"К":
			var a := int(floor(rd * 0.25))
			var h := int(floor(rd * 0.5))
			return {"ad": a, "hd": h, "desc": "К: бр−%d, ХП−%d" % [a, h]}
		"Р":
			var a2 := int(floor(rd * 0.5))
			var h2 := int(floor(rd * 0.5))
			return {"ad": a2, "hd": h2, "desc": "Р: бр−%d, ХП−%d" % [a2, h2]}
		"Д", "П":
			return {"ad": rd, "hd": rd, "desc": "%s: бр−%d, ХП−%d" % [dmg_type, rd, rd]}
	return {"ad": 0, "hd": rd, "desc": "ХП−%d" % rd}


static func level_reward(level: int) -> Dictionary:
	return LEVEL_REWARDS.get(level, LEVEL_REWARDS[10])


static func xp_for_level(level: int) -> int:
	var t := 0
	for i in range(1, level):
		t += i * 100
	return t


static func earned(level: int) -> Dictionary:
	var st := 0
	var sk := 0
	for l in range(2, level + 1):
		var r := level_reward(l)
		st += r.stat
		sk += r.skill
	return {"st": st, "sk": sk}


## Случайная раскладка: характеристики до cap, навыки до 6
static func random_core(s_pool := STAT_POOL, k_pool := SKILL_POOL, cap := 8) -> Dictionary:
	var st := empty_stats()
	var guard := 0
	while sum_stats(st) < s_pool and guard < 800:
		guard += 1
		var c := []
		for x in STATS:
			if st[x.key] < cap:
				c.append(x.key)
		if c.is_empty():
			break
		st[c.pick_random()] += 1
	var sk := empty_skills()
	var left := k_pool
	guard = 0
	var all := all_skills()
	while left > 0 and guard < 800:
		guard += 1
		var c2 := []
		for x in all:
			if sk[x.name] < 6:
				c2.append(x)
		if c2.is_empty():
			break
		var n: Dictionary = c2.pick_random()
		sk[n.name] += 1
		left -= 1
	return {"stats": st, "skills": sk}


# ---------- шанс попадания (для подсказки) ----------
static var _hit_dist: Array = []


static func _build_hit_dist() -> void:
	var m := {}
	var add := func(v: int, p: float) -> void:
		m[v] = m.get(v, 0.0) + p
	for b in range(2, 10):
		add.call(b, 0.1)
	for n in range(1, 11):
		add.call(1 - n, 0.01)
	var ex := func(self_ref: Callable, base: int, p: float, depth: int) -> void:
		for n in range(1, 11):
			if n == 10 and depth < 3:
				self_ref.call(self_ref, base + 10, p * 0.1, depth + 1)
			else:
				add.call(base + n, p * 0.1)
	ex.call(ex, 10, 0.1, 0)
	_hit_dist = []
	for k in m:
		_hit_dist.append([k, m[k]])


## Вероятность, что атака (d10 + A) превысит уклонение (d10 + D)
static func hit_chance(a_total: int, d_total: int) -> float:
	if _hit_dist.is_empty():
		_build_hit_dist()
	var s := 0.0
	for xa in _hit_dist:
		for yd in _hit_dist:
			if xa[0] + a_total > yd[0] + d_total:
				s += xa[1] * yd[1]
	return s


## Модификаторы атаки: характеристика + навык + бонус − прицел − дальность − очередь
static func atk_mods(att, w: Dictionary, aim, dist: int, extra := 0) -> Dictionary:
	var f: Dictionary = att.stats
	var s: Dictionary = att.skills
	var st_k := weapon_stat(w.type)
	var sk: String = WEAPON_SKILL[w.type]
	var eff := int(w.get("eff_range", 6))
	var rp := 0
	if int(w.range) > 1 and dist > eff:
		rp = int(ceil((dist - eff) / 2.0))
	var ap := 0
	if aim != null and aim != "":
		ap = AIM_PEN[aim]
		# кассета «Хирург» снижает штраф к прицельным ударам
		if att.is_hero and Game.cas_has_tag("surgeon"):
			ap = maxi(0, ap - 2)
	var rv := int(f.get(st_k, 0))
	var sv := int(s.get(sk, 0))
	var b := int(w.get("bonus", 0)) + int(w.get("hit_bonus", 0))
	return {"st_k": st_k, "sk": sk, "rv": rv, "sv": sv, "b": b, "ap": ap, "rp": rp, "ex": extra,
		"total": rv + sv + b - ap - rp - extra}


## Модификаторы защиты: Реакция + Уклонение + оборона (за несъеденные ОД)
static func def_mods(dfn) -> Dictionary:
	var f: Dictionary = dfn.stats
	var s: Dictionary = dfn.skills
	var db: int = dfn.db
	var dv := int(f.get("REF", 0))
	var dg := int(s.get("Уклонение", 0))
	return {"dv": dv, "dg": dg, "db": db, "total": dv + dg + db}


static func zone_by_name(n: String) -> Dictionary:
	for z in ZONES:
		if z.name == n:
			return z
	return ZONES[2]
