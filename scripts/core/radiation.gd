extends Node
## Радиация (автозагрузка Rad). Накопленная доза — Game.hero.rad (рады).
## Фон даёт место (мёртвые пятна на встречах, руины, места взрывов на карте мира)
## и радиационная буря под открытым небом. Пока фон есть — доза растёт, нет —
## медленно спадает. С 100 рад под фоном снимается 1 ХП раз в 8 с; с 300 —
## лучевая болезнь: 1 ХП раз в 4 с даже без фона, пока не выпьешь антирадин.
## В интерфейсе — строка «☢» под строкой состояния.

const SICK := 100.0
const ILL := 300.0

var main: Node
var _t := 0.0
var _hp_t := 0.0
var _warned := 0


func setup(m: Node) -> void:
	main = m


func level() -> float:
	return float(Game.hero.get("rad", 0.0))


func add(v: float) -> void:
	Game.hero["rad"] = clampf(level() + v, 0.0, 1000.0)
	_warn()


## Фон прямо сейчас (рад в секунду)
func exposure() -> float:
	if main == null or main.location == null:
		return 0.0
	var r := 0.0
	if Weather.info().get("rad", false) and Weather.outdoor():
		r += 3.0
	if main.location.has_method("rad_level"):
		r += float(main.location.rad_level())
	return r


func tier() -> String:
	var l := level()
	if l >= ILL:
		return "лучевая болезнь"
	if l >= SICK:
		return "облучение"
	if l > 0.5:
		return "доза"
	return ""


func text() -> String:
	var e := exposure()
	if level() < 0.5 and e <= 0.0:
		return ""
	var s := "☢ %d рад" % int(level())
	if tier() in ["облучение", "лучевая болезнь"]:
		s += " · " + tier()
	if e > 0.0:
		s += " · фон %s" % ("высокий" if e >= 2.5 else "есть")
	return s


func _warn() -> void:
	if main == null:
		return
	var l := level()
	if l >= ILL and _warned < 2:
		_warned = 2
		Game.log_line("Тошнит, во рту металл. Лучевая болезнь — нужен антирадин.", "", "miss")
	elif l >= SICK and _warned < 1:
		_warned = 1
		Game.log_line("Голова кружится. Облучение — уходи с фона.", "", "miss")
	elif l < SICK:
		_warned = 0


func _process(delta: float) -> void:
	if main == null or main.location == null or main.combat.on or main.ui_blocked():
		return
	tick(delta)


## Шаг времени (для игры и автотеста)
func tick(delta: float) -> void:
	var e := exposure()
	_t += delta
	while _t >= 1.0:
		_t -= 1.0
		if e > 0.0:
			add(e)
			if Game.item_count("dosimeter") > 0 and randf() < 0.25:
				main.sfx("geiger", -12.0)
		elif level() > 0.0:
			add(-0.4)
	var l := level()
	var period := 0.0
	if l >= ILL:
		period = 4.0
	elif l >= SICK and e > 0.0:
		period = 8.0
	if period <= 0.0:
		_hp_t = 0.0
	else:
		_hp_t += delta
		if _hp_t >= period:
			_hp_t = 0.0
			if Game.hero_hp() > 1:
				Game.set_hero_hp(Game.hero_hp() - 1)
				Game.log_line("Радиация: −1 ХП (%s)." % tier(), "", "miss")
	if main.hud and main.hud.get("_rad"):
		var lbl: Label = main.hud._rad
		lbl.text = text()
		lbl.visible = lbl.text != ""
		lbl.add_theme_color_override("font_color", UITheme.RED if l >= SICK else (UITheme.AMBER if e > 0.0 else UITheme.GREEN_DIM))
