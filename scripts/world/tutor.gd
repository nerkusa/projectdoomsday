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
	["steal", "Спорим, стащишь у Варвары ключ от сундука в амбаре? Он у неё в кармане фартука. Пошли! (Не будешь — кликни по мне.)", "ПКМ по Варваре → «Обокрасть», пока она не смотрит.  Ключ откроет общий сундук в амбаре.  Заметит — молва упадёт."],
	["spar", "А теперь — на кулаках, как в детстве! Кликни по мне.", "ЛКМ по другу → «Давай на кулаках»."],
	["fight", "", "Бой идёт по ходам.  ОД — очки действия: шаг и удар их тратят.\nЛКМ по противнику — ударить  ·  Пробел — закончить ход."],
	["check", "Запомни: в разговоре бывает «[Убеждение 60%]» — это шанс. Попытка одна!", "Проверка навыка: процент — шанс на успех. Провалил — второй попытки нет."],
]
const FOLLOW_DIST := 3.2
## Сколько держится карточка с подсказкой
const CARD_SEC := 10.0

var loc: Node
var main: Node
var _t := 0.0
var _step_t := 0.0
var _start_pos := Vector3.ZERO
var _shown := -1
var _who: Character = null
var _card_t := 0.0
var _call_t := 0.0
var _say_t := 0.0
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
	Game.set_quest("lessons", STEPS.size() + 1)
	var f := friend()
	if f:
		f.stop()


func _process(delta: float) -> void:
	if loc == null:
		loc = get_parent()
	main = loc.main
	if main == null or main.location != loc:
		return
	# карточка гаснет сама через CARD_SEC секунд
	if _card_t > 0.0:
		_card_t -= delta
		if _card_t <= 0.0 and main.hud:
			main.hud.tutor_card("")
	_say_t -= delta
	# утро только началось: друг сам подходит и берёт героя «за ручку»
	if not Game.flag("tut_on") and not Game.flag("tut_skip") and not Game.flag("tut_done") and str(loc.call("phase")) == "morning":
		if not main.dialog.visible and not main.cutscene and not main.ui_blocked():
			Game.set_flag("tut_on")
			start()
			var f := friend()
			if f:
				f.bark(main.dialog._subst("Эй, соня! Проснул{g:ся|ась}? Пошли, дед ждёт — я провожу и всё покажу!"))
			_card("Друг ведёт тебя по деревне и учит.  Не нужно — ЛКМ по другу → «Отстань».")
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
		_card(str(STEPS[i][2]).replace("{who}", _dat(who)))
		Game.set_quest("lessons", i + 1)
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
			var vv: Character = loc.character("Varvara")
			return Game.item_count("chest_key") > 0 or Game.flag("tut_steal_skip") or Game.flag("box_open") \
				or (vv != null and loc.ws().misc.has("caught_" + vv.uid()))
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
	var lead = _lead(id)
	if lead != null:
		# ведёт «за ручку»: идёт к цели урока, ждёт там и зовёт, если отстали
		tgt = (lead as Vector3) + Vector3(1.4, 0, 1.0)
		if f.global_position.distance_to(tgt) <= 1.5:
			_call_t -= 0.25
			if p.distance_to(tgt) > 7.0 and _call_t <= 0.0:
				_call_t = 8.0
				f.face_towards(p)
				f.bark(main.dialog._subst(["Сюда, сюда!", "Ну, чего отстал{g:|а}? Сюда!", "Я тут! Иди за мной!"][randi() % 3]))
			return
	elif f.global_position.distance_to(tgt) <= FOLLOW_DIST:
		return
	var back := (f.global_position - tgt)
	back.y = 0.0
	var to: Vector3 = tgt + back.normalized() * 1.8
	f.move_along(Clock._route(loc, f.global_position, to), Callable(), 3.8 if id != "walk" else 3.0)


## Куда друг ведёт на этом уроке (null — просто держится рядом)
func _lead(id: String) -> Variant:
	match id:
		"walk", "ded":
			var ded: Character = loc.character("Ded")
			return ded.global_position if ded else null
		"pick":
			var pl = loc.item("Planks")
			return pl.global_position if pl and pl.visible else null
		"stalk":
			return null
		"steal":
			var vv: Character = loc.character("Varvara")
			return vv.global_position if vv and vv.visible else null
	return null


func _card(t: String) -> void:
	main.hud.tutor_card(t)
	_card_t = CARD_SEC


## Друг комментирует, что делает герой (раз в ~15 с, если рядом и жив)
const SAY := {
	"pick": ["Пригодится!", "Ого, что нашёл{g:|ла}!", "Бери-бери, в хозяйстве всё сгодится.", "Тяжёлое? Давай понесу. Шучу."],
	"steal": ["Тихо ты! (Озирается.) …Ловко!", "Вот это руки! Только деду не говори.", "Ох и влетит нам, если узнают…"],
	"caught": ["Ой, попались… Я тут ни при чём! (Отходит в сторону.)", "Ну вот. Теперь вся деревня знает."],
	"talk": ["Что сказал{g:|а}? Ладно, потом расскажешь.", "Ну как, договорились?", "Ты с ним поласковей — он добрый, только ворчит."],
	"talk_ded": ["Дед строгий, но справедливый. Слушайся его.", "Что дед велел? Пошли, помогу!"],
	"talk_varvara": ["Варвара всё помнит — и пироги, и обиды.", "Пирогом угостила? Нет? Жадина…"],
	"talk_stepan": ["Степан забор третью весну чинит. Помоги ему, а?"],
	"fight": ["Цел{g:|а}? Ух, страшно было!", "Ты где так драться научил{g:ся|ась}?"],
	"level": ["Растёшь! Скоро и Кэскила обставишь.", "Ого, а ты не промах!"],
	"house": ["Тут живут — не шарь без спроса!", "Дома у всех одинаковые, а пахнет по-разному."],
}


func comment(kind: String) -> void:
	if loc == null or main == null or _say_t > 0.0 or str(loc.call("phase")) != "morning" or Game.flag("friend_dead"):
		return
	var f := friend()
	if f == null or not f.visible or f.barking() or f.global_position.distance_to(main.player.global_position) > 15.0:
		return
	var pool: Array = SAY.get(kind, [])
	if pool.is_empty():
		return
	_say_t = 15.0
	f.bark(main.dialog._subst(str(pool[randi() % pool.size()])))


func _finish() -> void:
	Game.set_flag("tut_done")
	Game.set_quest("lessons", STEPS.size() + 1)
	main.hud.tutor_card("")
	var f := friend()
	if f:
		f.bark(main.dialog._subst("Всё, учитель из меня кончился! Осмотрись по деревне, пройдись по домам — может, кому помощь нужна. А вечером — у костра!"))
		main.hud.toast("Загляни к соседям: у многих найдётся дело для тебя.", 6.0)
		Game.log_line("Обучение пройдено.", "", "hit")
