class_name Fighter
extends RefCounted
## Участник боя: герой или NPC. Хранит всё, что нужно правилам.

var id := ""
var name := ""
var is_hero := false
var node: Character = null
var stats: Dictionary = {}
var skills: Dictionary = {}
var hp_roll := 0
var max_hp := 1
var _hp := 1
## Броня тела: {"type": "light", "max": 8, "name": "ватник"} или пусто
var armor: Dictionary = {}
var arm := 0
var ap := 0
var ap_max := 0
var db := 0
var hex := Vector2i.ZERO
var has_hex := false
var wkey := "fists"
var wkey0 := "fists"
var mag := 0
var ammo_left := 0
var lethal := true
var alive := true
var dead := false
var fled := false
var yielded := false
var fleeing := false
var think := 0
var xp := 50
var loot: Dictionary = {}
var flee_threshold := 0.3
var will_dc := 13
## Мишень: не ходит и не бьёт, просто стоит
var static_target := false

var hp: int:
	get:
		return Game.hero_hp() if is_hero else _hp
	set(v):
		if is_hero:
			Game.set_hero_hp(v)
		else:
			_hp = maxi(0, v)


static func for_hero(n: Character) -> Fighter:
	var f := Fighter.new()
	f.id = "hero"
	f.is_hero = true
	f.node = n
	f.name = Game.hero.name
	f.stats = Game.hero.stats
	f.skills = Game.hero.skills
	f.max_hp = Game.hero_max()
	f.lethal = true
	return f


## NPC по шаблону из data/characters.json
static func for_npc(n: Character, tpl: Dictionary) -> Fighter:
	var f := Fighter.new()
	f.id = n.uid()
	f.node = n
	f.name = n.display_name if n.display_name != "" else tpl.get("name", "?")
	f.stats = tpl.get("stats", Rules.empty_stats()).duplicate()
	for k in Rules.STATS:
		if not f.stats.has(k.key):
			f.stats[k.key] = 1
		f.stats[k.key] = int(f.stats[k.key])
	f.skills = Rules.normalize_skills(tpl.get("skills", {}))
	f.hp_roll = int(tpl.get("hp_roll", 5))
	f.max_hp = Rules.max_hp(f.stats, f.hp_roll)
	f._hp = int(round(f.max_hp * float(tpl.get("hp_frac", 1.0))))
	f.armor = tpl.get("armor", {})
	f.arm = int(f.armor.get("max", 0)) if not f.armor.is_empty() else 0
	f.wkey = tpl.get("weapon", "fists")
	f.wkey0 = f.wkey
	var w := DB.weapon(f.wkey)
	if DB.is_gun(f.wkey):
		f.mag = int(tpl.get("mag", w.mag))
		f.ammo_left = int(tpl.get("ammo", w.mag))
	f.lethal = bool(tpl.get("lethal", true))
	f.xp = int(tpl.get("xp", 50))
	f.loot = tpl.get("loot", {})
	f.flee_threshold = float(tpl.get("flee_below", 0.3))
	f.will_dc = int(tpl.get("will_dc", 13))
	f.static_target = bool(tpl.get("static", false))
	return f


func active() -> bool:
	return is_hero or (alive and not fled and not yielded)


func weapon() -> Dictionary:
	if is_hero:
		return Game.hero_weapon()
	return DB.weapon(wkey)
