class_name Tutor
extends Node
## Утро в Нахарро: друг детства водит героя и учит — ходить, говорить, брать вещи,
## смотреть в сумку, красться, подкрадываться со спины, воровать, драться, понимать проверки. Шаг — в Game.world["_tut"].
## Не нужно — «Отстань, я сам» (флаг tut_skip). Друг того же пола, что и герой.

## [id, реплика друга над головой, карточка с клавишей]
const STEPS := [
	["walk", "Дед у своей избы — топай за мной!", "ЛКМ по земле — идти.  Далеко — герой сам перейдёт на бег."],
	["ded", "Вот он. Поговори с ним — кликни по деду.", "ЛКМ по человеку — поговорить.  Цифры 1–9 — выбрать ответ."],
	["pick", "Степан доски просил — вон, у его забора. Бери!", "ЛКМ по вещи — взять.  Зелёное пятно — можно, красное — чужое (воровство)."],
	["bag", "Глянь, что в сумке.", "I — сумка: вещи, оружие в руках, что можно съесть или надеть."],
	["sneak", "Мелкие в прятки играют. Пригнись — подкрадёмся!", "Z — красться: тише и медленнее.  Жёлтые конусы — куда смотрят люди."],
	["stalk", "Спорим, не подкрадёшься к {who} со спины?", "Крадучись (Z) подойди к {who} сзади — ближе двух шагов, не попадая в жёлтый конус."],
	["steal", "А теперь — стащи что-нибудь чужое, пока не видят. Или струсишь? Кликни по мне, если не будешь.", "Красное пятно — чужая вещь. Бери, когда на тебя никто не смотрит.  Заметят — молва упадёт вдвое."],
	["spar", "А теперь — на кулаках, как в детстве! Кликни по мне.", "ЛКМ по другу → «Давай на кулаках»."],
	["fight", "", "Бой идёт по ходам.  ОД — очки действия: шаг и удар их тратят.\nЛКМ по противнику — ударить  ·  Пробел — закончить ход."],
	["check", "Запомни: в разговоре бывает «[Убеждение 60%]» — это шанс. Попытка одна!", "Проверка навыка: процент — шанс на успех. Провалил — второй попытки нет."],
]
const FOLLOW_DIST := 3.2

var loc: Node
var main: Node
var _t := 0.0
var _step_t := 0.0
var _start_pos := Vector3.ZERO
var _shown := -1
var _who: Character = null
var _caught_t := 0.0


func setup(l: Node) -> void:
	loc = l
	main = l.main


func active() -> bool:
	return Game.flag("tut_on") and not Game.flag("tut_done") and not Game.flag("tut_skip") \
		and str(loc.call("phase")) == "morning"


func step() -> int:
	return int(Game.world.get("_tut", 0))


func friend() -> Character:
	return loc.character("FriendF" if Game.hero.get("female", false) else "Friend")


func start() -> void:
	Game.world["_tut"] = 0
	_start_pos = loc.main.player.global_position
	_shown = -1


func skip() -> void:
	loc.main.hud.tutor_card("")
	var f := friend()
	if f:
		f.stop()


func _process(delta: float) -> void:
	if loc == null:
		loc = get_parent()
	main = loc.main
	if main == null or main.location != loc:
		return
	# ещё не начали и не отказались: друг зовёт — «кликни по мне»
	if not Game.flag("tut_on") and not Game.flag("tut_skip") and not Game.flag("tut_done") and str(loc.call("phase")) == "morning":
		if _shown != -3 and not main.dialog.visible and main.hud:
			_shown = -3
			var f := friend()
			if f:
				f.bark(main.dialog._subst("Эй, соня! Иди сюда!"))
			main.hud.tutor_card("ЛКМ по другу — поговорить.")
		return
	if not active():
		if _shown != -2 and main.hud:
			main.hud.tutor_card("")
			_shown = -2
		return
	_t -= delta
	_step_t += delta
	if _t > 0.0:
		return
	_t = 0.25
	var i := step()
	if i >= STEPS.size():
		_finish()
		return
	if _shown != i:
		_shown = i
		_step_t = 0.0
		var f := friend()
		if STEPS[i][0] == "stalk":
			_who = _pick_target()
		var who := _who.display_name if _who else "кому-нибудь"
		if f and str(STEPS[i][1]) != "":
			f.bark(main.dialog._subst(str(STEPS[i][1]).replace("{who}", _dat(who))))
		main.hud.tutor_card(str(STEPS[i][2]).replace("{who}", _dat(who)))
		if STEPS[i][0] == "spar":
			Game.set_flag("tut_spar_ready")
	if _done(str(STEPS[i][0])):
		Game.world["_tut"] = i + 1
		return
	_follow(str(STEPS[i][0]))


## Выполнен ли шаг
func _done(id: String) -> bool:
	var p: Vector3 = main.player.global_position
	match id:
		"walk":
			var ded: Character = loc.character("Ded")
			return p.distance_to(_start_pos) > 5.0 or (ded != null and p.distance_to(ded.global_position) < 5.0)
		"ded":
			return Game.quest_stage("chores") >= 1
		"pick":
			return Game.item_count("planks") > 0 or Game.flag("fence_done")
		"bag":
			return main.kpk.visible
		"sneak":
			if not Game.hero.get("sneak", false):
				_step_t = 0.0
			return _step_t > 1.5
		"stalk":
			return _stalked(p)
		"steal":
			return Game.flag("tut_stole") or Game.flag("tut_caught") or Game.flag("tut_steal_skip")
		"spar":
			return main.combat.on and main.combat.kind == "spar"
		"fight":
			return not main.combat.on and Game.flag("tut_spar_done")
		"check":
			return _step_t > 9.0
	return true


## Кого выследить: ближайший мирный житель (не друг и не дед)
func _pick_target() -> Character:
	var p: Vector3 = main.player.global_position
	var best: Character = null
	for ch in loc.characters():
		# стоит на месте, со своим именем (не прохожий в обходе)
		if ch == main.player or not ch.visible or ch.hostile or ch.pose != "" or ch.char_id.begins_with("friend") \
				or ch.char_id in ["ded", "target", "sick", "villager", "villager_f"] or ch.is_in_group("range_targets") \
				or not ch.patrol.is_empty() or ch.dialog == "":
			continue
		if best == null or ch.global_position.distance_to(p) < best.global_position.distance_to(p):
			best = ch
	return best


## «Стёпе» — дательный падеж для подсказки (простое правило: а/я → е, иначе +у)
static func _dat(n: String) -> String:
	var w := n.split(" ")[0]
	if w.ends_with("ий") or w.ends_with("ый"):
		return w.left(w.length() - 2) + "ему"
	if w.ends_with("ой"):
		return w.left(w.length() - 2) + "ому"
	if w.ends_with("а") or w.ends_with("я"):
		return w.left(w.length() - 1) + "е"
	if w.ends_with("й") or w.ends_with("ь"):
		return w.left(w.length() - 1) + "ю"
	return w + "у"


## Подкрался со спины: крадучись, ближе 2 м, а цель не видит (слух не в счёт).
## Попался на глаза — цель оборачивается, пробуй снова.
func _stalked(p: Vector3) -> bool:
	if _who == null or not is_instance_valid(_who) or not _who.visible:
		_who = _pick_target()
		return _who == null
	var d := _who.global_position.distance_to(p)
	var sneak: bool = Game.hero.get("sneak", false)
	var r: float = main._sneak_radius(9.0)
	if d < 6.0 and _who.in_view(p, r, 1.2) and Time.get_ticks_msec() / 1000.0 - _caught_t > 4.0:
		_caught_t = Time.get_ticks_msec() / 1000.0
		_who.face_towards(p)
		_who.bark("Ага! Вижу тебя!")
		var f := friend()
		if f:
			f.bark("Эх, заметили! Заходи со спины, и пригнись.")
		return false
	return sneak and d < 2.0 and not _who.in_view(p, r, 0.0)


## Друг держится рядом; на первом шаге — ведёт к деду
func _follow(id: String) -> void:
	var f := friend()
	if f == null or not f.visible or main.combat.on or main.dialog.visible or f.moving:
		return
	var p: Vector3 = main.player.global_position
	var tgt := p
	if id == "walk":
		var ded: Character = loc.character("Ded")
		if ded:
			tgt = ded.global_position + Vector3(1.6, 0, 1.2)
	if f.global_position.distance_to(tgt) <= FOLLOW_DIST:
		return
	var back := (f.global_position - tgt)
	back.y = 0.0
	var to: Vector3 = tgt + back.normalized() * 1.8
	f.move_along(Clock._route(loc, f.global_position, to), Callable(), 3.8 if id != "walk" else 3.0)


func _finish() -> void:
	Game.set_flag("tut_done")
	main.hud.tutor_card("")
	var f := friend()
	if f:
		f.bark(main.dialog._subst("Всё, учитель из меня кончился! Осмотрись по деревне, пройдись по домам — может, кому помощь нужна. А вечером — у костра!"))
		main.hud.toast("Загляни к соседям: у многих найдётся дело для тебя.", 6.0)
		Game.log_line("Обучение пройдено.", "", "hit")
